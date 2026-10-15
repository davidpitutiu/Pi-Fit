import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import '../domain/exercise_catalog.dart';
import '../domain/training_analytics.dart';
import '../domain/user_profile.dart';
import '../domain/body_measurement.dart';
import '../domain/coach_plan.dart';
import '../services/notification_service.dart';

class AppStore extends ChangeNotifier {
  static const profileGoals = [
    'Strength and muscle',
    'General fitness',
    'Weight management',
    'Mobility and recovery',
  ];
  static const _legacyGoals = {
    'Forță și masă musculară': 'Strength and muscle',
    'Condiție fizică': 'General fitness',
    'Controlul greutății': 'Weight management',
    'Mobilitate și recuperare': 'Mobility and recovery',
  };
  final SharedPreferences preferences;
  AppStore(this.preferences);
  String? _accountId;
  int _scopeRevision = 0;
  String? get accountId => _accountId;
  Future<void> _accountSwitchQueue = Future.value();
  ThemeMode themeMode = ThemeMode.dark;
  String name = 'Athlete';
  String goal = 'Strength and muscle';
  UserProfile _profile = UserProfile();
  UserProfile get profile => _profile;
  List<BodyMeasurement> _bodyMeasurements = [];
  List<BodyMeasurement> get bodyMeasurements =>
      List.unmodifiable(_bodyMeasurements);
  Set<String> _appliedCoachProposalIds = {};
  Set<String> get appliedCoachProposalIds =>
      Set.unmodifiable(_appliedCoachProposalIds);
  int get totalCompletedWorkouts => completedTrainingSessions(history).length;
  Set<String> _favoriteExerciseIds = {};
  Set<String> get favoriteExerciseIds => Set.unmodifiable(_favoriteExerciseIds);
  TrainingAnalytics get analytics =>
      analyzeTraining(history: history, exercises: exercises, profile: profile);
  List<Routine> customRoutines = [];
  List<WorkoutSession> history = [];
  List<ScheduledWorkout> schedule = [];
  WorkoutSession? activeSession;
  String? persistenceError;
  List<Exercise> get exercises => exerciseCatalog;
  List<Routine> get routines => [...customRoutines, ...routineTemplates];
  Exercise exerciseById(String id) {
    for (final exercise in exercises) {
      if (exercise.id == id) return exercise;
    }
    // A historical backup may reference a previously available exercise. Keep
    // its ID and training records instead of crashing or silently deleting it.
    return Exercise(
      id: id,
      name: 'Saved exercise',
      muscle: 'Other',
      equipment: 'Unspecified',
      description:
          'This exercise is unavailable in the current catalog. '
          'Your sets and progress have been preserved.',
    );
  }

  Routine? routineById(String id) {
    for (final routine in routines) {
      if (routine.id == id) return routine;
    }
    return null;
  }

  String get _scopePrefix =>
      _accountId == null ? 'pifit' : 'pifit.account.$_accountId';
  String get _storageKey =>
      _accountId == null ? 'pifit.local.v1' : '$_scopePrefix.v1';
  String get _corruptKey => '$_scopePrefix.recovery.v1';

  Map<String, dynamic>? _guestJournal() {
    final raw = preferences.getString('pifit.local.v1');
    if (raw == null) return null;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      _validateBackup(data);
      return data;
    } catch (_) {
      return null;
    }
  }

  bool get hasGuestJournal {
    final guest = _guestJournal();
    if (guest == null) return false;
    return [
      'history',
      'routines',
      'schedule',
      'favoriteExerciseIds',
      'bodyMeasurements',
    ].any((key) => (guest[key] as List? ?? const []).isNotEmpty);
  }

  /// An explicit copy operation. Signing in never moves guest data silently.
  /// Current account preferences and its active workout remain untouched.
  Future<void> importGuestJournal() {
    final operation = _accountSwitchQueue.then((_) => _importGuestJournal());
    _accountSwitchQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _importGuestJournal() async {
    if (_accountId == null) {
      throw StateError('Sign in before importing the guest journal.');
    }
    final guest = _guestJournal();
    if (guest == null) {
      throw StateError('There is no valid guest journal to import.');
    }
    final merged = exportData();
    final mergedRoutines = [...customRoutines];
    final available = {for (final routine in routines) routine.id: routine};
    final routineIds = <String, String>{};
    String content(Routine routine) =>
        jsonEncode({...routine.toJson(), 'id': ''});
    for (final value in guest['routines'] as List) {
      final routine = Routine.fromJson(_object(value));
      final originalId = routine.id;
      var id = originalId;
      if (available[id] != null &&
          content(available[id]!) != content(routine)) {
        // Stable 32-bit content fingerprint: repeated imports find the same
        // copied routine. Multiplication by 31 is exact on Dart native and web;
        // collisions are checked against the complete canonical content.
        var hash = 0x811c9dc5;
        for (final unit in content(routine).codeUnits) {
          hash = ((hash ^ unit) * 31) & 0xffffffff;
        }
        final base = 'guest-${hash.toRadixString(16)}';
        id = base;
        var suffix = 1;
        while (available[id] != null &&
            content(available[id]!) != content(routine)) {
          id = '$base-${suffix++}';
        }
      }
      routineIds[originalId] = id;
      if (!available.containsKey(id)) {
        final copied = routine.copyWith(id: id);
        mergedRoutines.add(copied);
        available[id] = copied;
      }
    }
    final mergedHistory = [...history];
    final historyIds = history.map((item) => item.id).toSet();
    // A current active workout also owns its ID; never replace it on import.
    if (activeSession != null) historyIds.add(activeSession!.id);
    for (final value in guest['history'] as List) {
      final session = WorkoutSession.fromJson(_object(value));
      if (historyIds.add(session.id)) mergedHistory.add(session);
    }
    mergedHistory.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final mergedSchedule = [...schedule];
    final scheduleIds = schedule.map((item) => item.id).toSet();
    for (final value in guest['schedule'] as List) {
      final event = ScheduledWorkout.fromJson(_object(value));
      if (scheduleIds.add(event.id)) {
        mergedSchedule.add(
          ScheduledWorkout(
            id: event.id,
            routineId: routineIds[event.routineId] ?? event.routineId,
            date: event.date,
            reminder: event.reminder,
          ),
        );
      }
    }
    mergedSchedule.sort((a, b) => a.date.compareTo(b.date));
    merged['routines'] = mergedRoutines.map((item) => item.toJson()).toList();
    merged['history'] = mergedHistory.map((item) => item.toJson()).toList();
    merged['schedule'] = mergedSchedule.map((item) => item.toJson()).toList();
    merged['favoriteExerciseIds'] = {
      ..._favoriteExerciseIds,
      ...List<String>.from(guest['favoriteExerciseIds'] as List? ?? const []),
    }.toList()..sort();
    final measurements = [..._bodyMeasurements];
    final measurementIds = measurements.map((item) => item.id).toSet();
    final sourceIds = measurements
        .where((item) => item.sourceRecordId != null)
        .map((item) => '${item.source}/${item.sourceRecordId}')
        .toSet();
    for (final value in guest['bodyMeasurements'] as List? ?? const []) {
      final measurement = BodyMeasurement.fromJson(_object(value));
      final sourceKey = measurement.sourceRecordId == null
          ? null
          : '${measurement.source}/${measurement.sourceRecordId}';
      if (measurementIds.contains(measurement.id) ||
          (sourceKey != null && sourceIds.contains(sourceKey))) {
        continue;
      }
      measurements.add(measurement);
      measurementIds.add(measurement.id);
      if (sourceKey != null) sourceIds.add(sourceKey);
    }
    measurements.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    merged['bodyMeasurements'] = measurements
        .map((item) => item.toJson())
        .toList();
    if (jsonEncode(merged) == jsonEncode(exportData())) return;
    await _restoreBackup(merged);
  }

  /// Each authenticated account has its own local document. Guest data is
  /// intentionally never imported automatically into a newly signed-in user.
  /// Calls are serialized because authentication can emit overlapping events.
  Future<void> switchAccount(String? uid) {
    if (uid != null && (uid.trim().isEmpty || uid.length > 128)) {
      return Future.error(ArgumentError('Invalid account identifier.'));
    }
    final operation = _accountSwitchQueue.then((_) => _switchAccount(uid));
    _accountSwitchQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _switchAccount(String? uid) async {
    if (uid == _accountId) return;
    final candidate = AppStore(preferences)
      .._accountId = uid
      ..themeMode = themeMode;
    final raw = preferences.getString(candidate._storageKey);
    if (raw != null) {
      try {
        candidate._restore(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {
        final preserved = await candidate._preserveRecovery(raw);
        throw FormatException(
          preserved
              ? 'This account could not be opened. A recovery copy has been preserved.'
              : 'This account could not be opened. Its original data has not been changed.',
        );
      }
    }
    final requested = candidate.schedule
        .where((event) => event.reminder && event.date.isAfter(DateTime.now()))
        .toList();
    candidate.schedule = candidate.schedule
        .map((event) => event.copyWith(reminder: false))
        .toList();
    // Prove that the new document can be persisted before replacing the live
    // scope. Failed writes leave both the previous user and target untouched.
    await candidate._writeLocal(jsonEncode(candidate.exportData()));
    final previousReminders = schedule
        .where((event) => event.reminder)
        .toList();
    final previousScope = _accountId;
    _accountId = uid;
    _scopeRevision++;
    _restore(candidate.exportData());
    persistenceError = null;
    notifyListeners();
    Object? reminderError;
    for (final event in previousReminders) {
      try {
        await _cancelReminder(event.id, previousScope);
      } catch (error) {
        reminderError ??= error;
      }
    }
    for (final event in requested) {
      try {
        await NotificationService.instance.cancel(event.id);
        await NotificationService.instance.schedule(
          _notificationId(uid, event.id),
          event.date,
          routineById(event.routineId)?.name ?? 'Workout',
        );
        await _commit(() {
          final index = schedule.indexWhere((item) => item.id == event.id);
          if (index >= 0) {
            schedule[index] = schedule[index].copyWith(reminder: true);
          }
        });
      } catch (error) {
        reminderError ??= error;
        // A scheduled notification whose enabled flag could not be persisted
        // must also be cancelled, keeping the visible state honest.
        try {
          await _cancelReminder(event.id, uid);
        } catch (_) {}
        break;
      }
    }
    if (reminderError != null) {
      persistenceError =
          'Your account is open. Some reminders could not be synchronized on this device.';
      notifyListeners();
    }
  }

  Future<bool> _preserveRecovery(String raw) async {
    final existing = preferences.getString(_corruptKey);
    final key = existing == null || existing == raw
        ? _corruptKey
        : '$_corruptKey.${DateTime.now().microsecondsSinceEpoch}';
    try {
      return await preferences.setString(key, raw);
    } catch (_) {
      return false;
    }
  }

  Future<void> load() async {
    final raw = preferences.getString(_storageKey);
    if (raw == null) return;
    try {
      _restore(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      persistenceError = null;
    } catch (_) {
      final preserved = await _preserveRecovery(raw);
      persistenceError = preserved
          ? 'Local data could not be read. A recovery copy has been preserved.'
          : 'Local data could not be read. Your original data has not been changed.';
    }
    notifyListeners();
  }

  void _restore(Map<String, dynamic> data) {
    _validateBackup(data);
    final loadedRoutines = (data['routines'] as List? ?? [])
        .map((r) => Routine.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
    final loadedHistory = (data['history'] as List? ?? [])
        .map(
          (r) => WorkoutSession.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
    final loadedSchedule = (data['schedule'] as List? ?? [])
        .map(
          (r) => ScheduledWorkout.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
    final loadedActive = data['active'] == null
        ? null
        : WorkoutSession.fromJson(
            Map<String, dynamic>.from(data['active'] as Map),
          );
    final loadedName = _profileName(data['name'] as String);
    final loadedGoal = _profileGoal(data['goal'] as String);
    final loadedProfile = data['profile'] == null
        ? UserProfile()
        : UserProfile.fromJson(_object(data['profile']));
    final loadedFavorites = Set<String>.from(
      data['favoriteExerciseIds'] as List? ?? const [],
    );
    final loadedMeasurements =
        (data['bodyMeasurements'] as List? ?? const [])
            .map((value) => BodyMeasurement.fromJson(_object(value)))
            .toList()
          ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    final loadedProposals = Set<String>.from(
      data['appliedCoachProposalIds'] as List? ?? const [],
    );
    final loadedTheme = ThemeMode.values.firstWhere(
      (t) => t.name == data['theme'],
      orElse: () => ThemeMode.dark,
    );
    // Parsing and normalization must all succeed before replacing any state.
    name = loadedName;
    goal = loadedGoal;
    _profile = loadedProfile;
    _favoriteExerciseIds = loadedFavorites;
    _bodyMeasurements = loadedMeasurements;
    _appliedCoachProposalIds = loadedProposals;
    themeMode = loadedTheme;
    customRoutines = loadedRoutines;
    history = loadedHistory;
    schedule = loadedSchedule;
    activeSession = loadedActive;
  }

  Map<String, dynamic> exportData() => {
    'version': 1,
    'name': name,
    'goal': goal,
    'profile': profile.toJson(),
    'favoriteExerciseIds': _favoriteExerciseIds.toList()..sort(),
    'bodyMeasurements': _bodyMeasurements.map((item) => item.toJson()).toList(),
    'appliedCoachProposalIds': _appliedCoachProposalIds.toList()..sort(),
    'theme': themeMode.name,
    'routines': customRoutines.map((r) => r.toJson()).toList(),
    'history': history.map((r) => r.toJson()).toList(),
    'schedule': schedule.map((r) => r.toJson()).toList(),
    'active': activeSession?.toJson(),
  };

  /// A network caller should pass the UID captured before fetching its backup.
  /// The scope is checked again after queued account changes have completed.
  /// Switches cannot run during the local recovery/write/reminder transaction.
  Future<void> restoreBackup(
    Map<String, dynamic> data, {
    String? expectedAccountId,
  }) {
    final scope = expectedAccountId ?? _accountId;
    final operation = _accountSwitchQueue.then((_) async {
      if (_accountId != scope) {
        throw StateError(
          'The account changed. Try restoring again in the intended account.',
        );
      }
      await _restoreBackup(data);
    });
    _accountSwitchQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _restoreBackup(Map<String, dynamic> data) async {
    final scope = _accountId;
    // Validate in a separate store so malformed imports and persistence errors
    // leave the live profile and active workout entirely untouched.
    final imported = AppStore(preferences).._restore(data);
    final requested = imported.schedule
        .where((event) => event.reminder && event.date.isAfter(DateTime.now()))
        .toList();
    imported.schedule = imported.schedule
        .map((event) => event.copyWith(reminder: false))
        .toList();
    final before = exportData();
    final oldReminders = schedule.where((event) => event.reminder).toList();
    final recoverySaved = await preferences.setString(
      '$_scopePrefix.before_restore.v1',
      jsonEncode(before),
    );
    if (!recoverySaved) {
      throw StateError('A local recovery copy could not be saved.');
    }
    await _writeLocal(jsonEncode(imported.exportData()));
    _restore(imported.exportData());
    persistenceError = null;
    notifyListeners();
    // Reconcile reminders only after the imported calendar is safely stored.
    Object? cancellationError;
    for (final event in oldReminders) {
      try {
        await _cancelReminder(event.id, scope);
      } catch (error) {
        cancellationError ??= error;
      }
    }
    await _scheduleReminders(requested);
    if (cancellationError != null) {
      throw StateError(
        'The backup was restored. Some previous reminders '
        'could not be cancelled: $cancellationError',
      );
    }
  }

  String _profileName(String value) =>
      value.trim().isEmpty || value.trim() == 'Atlet'
      ? 'Athlete'
      : value.trim();
  String _profileGoal(String value) {
    final normalized = _legacyGoals[value.trim()] ?? value.trim();
    return profileGoals.contains(normalized) ? normalized : profileGoals.first;
  }

  Future<void> _commit(void Function() change) async {
    final before = exportData();
    final scope = _accountId;
    try {
      change();
      await _save();
    } catch (_) {
      if (_accountId == scope) _restore(before);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _scheduleReminders(List<ScheduledWorkout> requested) async {
    if (requested.isEmpty) return;
    final scope = _accountId;
    final revision = _scopeRevision;
    bool sameScope() => _accountId == scope && _scopeRevision == revision;
    Object? failure;
    for (final event in requested) {
      if (!sameScope()) return;
      try {
        // Remove a notification from older app versions which used the bare
        // event ID. New notifications always include their owning profile.
        await NotificationService.instance.cancel(event.id);
        if (!sameScope()) return;
        await NotificationService.instance.schedule(
          _notificationId(scope, event.id),
          event.date,
          routineById(event.routineId)?.name ?? 'Workout',
        );
        if (!sameScope()) {
          // A permission sheet can outlive the signed-in profile. Remove its
          // late notification, and never update another account's calendar.
          try {
            await _cancelReminder(event.id, scope);
          } catch (_) {}
          return;
        }
        final index = schedule.indexWhere((item) => item.id == event.id);
        if (index >= 0) {
          schedule[index] = schedule[index].copyWith(reminder: true);
        }
      } catch (error) {
        if (!sameScope()) return;
        failure = error;
        // Do not repeatedly prompt for permission or retry an unsupported
        // platform for each date in a bulk plan.
        break;
      }
    }
    if (!sameScope()) return;
    await _save();
    if (failure != null) {
      throw StateError(
        'Your workouts are saved in the calendar. Some reminders '
        'could not be scheduled: $failure',
      );
    }
  }

  static String _notificationId(String? accountId, String eventId) =>
      accountId == null ? 'guest/$eventId' : 'account/$accountId/$eventId';

  Future<void> _cancelReminder(String eventId, String? scope) async {
    Object? failure;
    try {
      await NotificationService.instance.cancel(
        _notificationId(scope, eventId),
      );
    } catch (error) {
      failure = error;
    }
    try {
      await NotificationService.instance.cancel(eventId);
    } catch (error) {
      failure ??= error;
    }
    if (failure != null) throw failure;
  }

  Future<void> _save() async {
    await _writeLocal(jsonEncode(exportData()));
    notifyListeners();
  }

  Future<void> _writeLocal(String value) async {
    final storageKey = _storageKey;
    final previous = preferences.getString(storageKey);
    try {
      if (await preferences.setString(storageKey, value)) return;
    } catch (_) {
      // Restore the preferences cache too: the legacy preferences API updates
      // its cache before the platform confirms a successful disk write.
    }
    try {
      if (previous == null) {
        await preferences.remove(storageKey);
      } else {
        await preferences.setString(storageKey, previous);
      }
    } catch (_) {
      // The in-memory AppStore transaction still rolls back, and a recovery
      // copy is retained before a cloud restore replaces any local data.
    }
    throw StateError('Local storage failed.');
  }

  Future<void> setTheme(ThemeMode value) async {
    await _commit(() => themeMode = value);
  }

  Future<void> updateProfile(String newName, String newGoal) async {
    await _commit(() {
      name = _profileName(newName);
      goal = _profileGoal(newGoal);
    });
  }

  /// Save the complete account editor in one transaction, including name and
  /// goal, so failed persistence cannot leave only part of a profile updated.
  Future<void> updateUserProfile(
    UserProfile value, {
    String? newName,
    String? newGoal,
  }) async {
    final validated = UserProfile.fromJson(value.toJson());
    final changedWeight = validated.weightKg != profile.weightKg
        ? validated.weightKg
        : null;
    final changedHeight = validated.heightCm != profile.heightCm
        ? validated.heightCm
        : null;
    final measurement = changedWeight == null && changedHeight == null
        ? null
        : _newBodyMeasurement(weightKg: changedWeight, heightCm: changedHeight);
    await _commit(() {
      _profile = validated;
      if (measurement != null) {
        _bodyMeasurements = [measurement, ..._bodyMeasurements];
      }
      if (newName != null) name = _profileName(newName);
      if (newGoal != null) goal = _profileGoal(newGoal);
    });
  }

  BodyMeasurement _newBodyMeasurement({
    double? weightKg,
    double? heightCm,
    DateTime? measuredAt,
    String source = 'manual',
    String? sourceRecordId,
    String? sourceName,
  }) {
    final time = measuredAt ?? DateTime.now();
    return BodyMeasurement(
      id: '$source-${DateTime.now().microsecondsSinceEpoch}-${_bodyMeasurements.length}',
      measuredAt: time,
      weightKg: weightKg,
      heightCm: heightCm,
      source: source,
      sourceRecordId: sourceRecordId,
      sourceName: sourceName,
    );
  }

  Future<void> recordBodyMeasurement({
    double? weightKg,
    double? heightCm,
    DateTime? measuredAt,
    String source = 'manual',
    String? sourceRecordId,
    String? sourceName,
  }) async {
    final measurement = _newBodyMeasurement(
      weightKg: weightKg,
      heightCm: heightCm,
      measuredAt: measuredAt,
      source: source,
      sourceRecordId: sourceRecordId,
      sourceName: sourceName,
    );
    if (measurement.sourceRecordId != null &&
        _bodyMeasurements.any(
          (item) =>
              item.source == measurement.source &&
              item.sourceRecordId == measurement.sourceRecordId,
        )) {
      return;
    }
    DateTime? latest(bool weight) {
      for (final item in _bodyMeasurements) {
        if (weight ? item.weightKg != null : item.heightCm != null) {
          return item.measuredAt;
        }
      }
      return null;
    }

    final weightDate = latest(true);
    final heightDate = latest(false);
    final updateWeight =
        weightKg != null &&
        (weightDate == null || !measurement.measuredAt.isBefore(weightDate));
    final updateHeight =
        heightCm != null &&
        (heightDate == null || !measurement.measuredAt.isBefore(heightDate));
    await _commit(() {
      _bodyMeasurements = [measurement, ..._bodyMeasurements]
        ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
      _profile = profile.copyWith(
        weightKg: updateWeight ? weightKg : null,
        heightCm: updateHeight ? heightCm : null,
      );
    });
  }

  Future<void> setExerciseFavorite(String id, bool value) async {
    if (value && !exercises.any((exercise) => exercise.id == id)) {
      throw ArgumentError('Choose an exercise from the catalog.');
    }
    await _commit(() {
      _favoriteExerciseIds = {..._favoriteExerciseIds};
      if (value) {
        _favoriteExerciseIds.add(id);
      } else {
        _favoriteExerciseIds.remove(id);
      }
    });
  }

  Future<void> saveRoutine(Routine routine) async {
    _validateRoutine(routine.toJson());
    if (routineTemplates.any((item) => item.id == routine.id)) {
      throw ArgumentError('Save the custom routine with a new identifier.');
    }
    await _commit(() {
      customRoutines.removeWhere((r) => r.id == routine.id);
      customRoutines.insert(0, routine);
    });
  }

  /// Apply a reviewed proposal as one local transaction. Generated text never
  /// bypasses current-account, revision, catalog, or routine validation.
  Future<void> applyCoachProposal(CoachProposal proposal) {
    final operation = _accountSwitchQueue.then(
      (_) => _applyCoachProposal(proposal),
    );
    _accountSwitchQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _applyCoachProposal(CoachProposal proposal) async {
    if (proposal.accountId != _accountId) {
      throw StateError(
        'The account changed. Generate a new plan for this account.',
      );
    }
    if (_appliedCoachProposalIds.contains(proposal.id)) return;
    if (proposal.baseRevision !=
        coachPlanningRevision(
          profile: profile,
          goal: goal,
          routines: customRoutines,
        )) {
      throw StateError(
        'Your training preferences or routines changed. Generate a new plan before applying it.',
      );
    }
    proposal.validate(catalog: exercises, customRoutines: customRoutines);
    final plannedRoutines = <Routine>[];
    for (var index = 0; index < proposal.routines.length; index++) {
      final draft = proposal.routines[index];
      final id = draft.targetRoutineId ?? 'coach-${proposal.id}-$index';
      if (draft.targetRoutineId == null && routineById(id) != null) {
        throw StateError(
          'A proposed routine already exists. Generate a new plan.',
        );
      }
      final routine = Routine(
        id: id,
        name: draft.name,
        subtitle: draft.subtitle,
        exercises: draft.exercises,
        estimatedMinutes: draft.estimatedMinutes,
        category: 'Custom',
      );
      _validateRoutine(routine.toJson());
      plannedRoutines.add(routine);
    }
    final created = <ScheduledWorkout>[];
    final planning = proposal.schedule;
    if (planning != null) {
      final routine = plannedRoutines[planning.routineIndex];
      var futureDates = 0;
      final now = DateTime.now();
      for (var offset = 0; offset < planning.weeks * 7; offset++) {
        final date = DateTime(
          planning.startDate.year,
          planning.startDate.month,
          planning.startDate.day + offset,
          planning.hour,
          planning.minute,
        );
        if (!planning.weekdays.contains(date.weekday) || !date.isAfter(now)) {
          continue;
        }
        futureDates++;
        if (schedule.any(
          (item) => item.routineId == routine.id && item.date == date,
        )) {
          continue;
        }
        final id = '${date.microsecondsSinceEpoch}-${routine.id}';
        if (schedule.any((item) => item.id == id)) {
          throw StateError(
            'A calendar entry already uses the proposed identifier.',
          );
        }
        created.add(
          ScheduledWorkout(
            id: id,
            routineId: routine.id,
            date: date,
            reminder: false,
          ),
        );
      }
      if (futureDates == 0) {
        throw StateError(
          'The selected schedule has no future dates. Choose a later start date.',
        );
      }
    }
    await _commit(() {
      final replacements = plannedRoutines.map((routine) => routine.id).toSet();
      customRoutines = [
        ...plannedRoutines,
        ...customRoutines.where(
          (routine) => !replacements.contains(routine.id),
        ),
      ];
      schedule = [...schedule, ...created]
        ..sort((a, b) => a.date.compareTo(b.date));
      _appliedCoachProposalIds = {..._appliedCoachProposalIds, proposal.id};
    });
    if (planning?.reminder == true) await _scheduleReminders(created);
  }

  Future<void> startEmptyWorkout() => startWorkout(
    Routine(
      id: 'free',
      name: 'Free workout',
      subtitle: 'Build your own session',
      exercises: [],
      estimatedMinutes: 0,
      category: 'Custom',
    ),
  );
  Future<void> startWorkout(Routine routine) async {
    if (activeSession != null) return;
    _validateRoutine(routine.toJson());
    await _commit(
      () => activeSession = WorkoutSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        routineName: routine.name,
        startedAt: DateTime.now(),
        exercises: routine.exercises
            .map(
              (e) => WorkoutExercise(
                exerciseId: e.exerciseId,
                sets: List.generate(
                  e.sets,
                  (_) => WorkoutSet(
                    reps: e.reps,
                    weight: e.weight,
                    completed: false,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> addExercise(String exerciseId) async {
    if (!exercises.any((exercise) => exercise.id == exerciseId)) {
      throw ArgumentError('Choose an exercise from the catalog.');
    }
    if (activeSession == null) return;
    await _commit(
      () => activeSession = activeSession!.copyWith(
        exercises: [
          ...activeSession!.exercises,
          WorkoutExercise(
            exerciseId: exerciseId,
            sets: List.generate(
              3,
              (_) => WorkoutSet(reps: 10, weight: 0, completed: false),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> updateSet(
    int exerciseIndex,
    int setIndex, {
    int? reps,
    double? weight,
    bool? completed,
    double? rpe,
    bool clearRpe = false,
  }) async {
    if (activeSession == null) return;
    if ((reps != null && (reps < 1 || reps > 100000)) ||
        (weight != null &&
            (!weight.isFinite || weight < 0 || weight > 100000)) ||
        (rpe != null && (!rpe.isFinite || rpe < 1 || rpe > 10))) {
      throw ArgumentError(
        'Repetitions must be positive and the weight must be valid and non-negative.',
      );
    }
    final exercises = [...activeSession!.exercises];
    final exercise = exercises[exerciseIndex];
    final sets = [...exercise.sets];
    sets[setIndex] = sets[setIndex].copyWith(
      reps: reps,
      weight: weight,
      completed: completed,
      rpe: rpe,
      clearRpe: clearRpe,
    );
    exercises[exerciseIndex] = WorkoutExercise(
      exerciseId: exercise.exerciseId,
      sets: sets,
    );
    await _commit(
      () => activeSession = activeSession!.copyWith(exercises: exercises),
    );
  }

  Future<void> addSet(int index) async {
    if (activeSession == null) return;
    final exercises = [...activeSession!.exercises];
    final exercise = exercises[index];
    final last = exercise.sets.isEmpty
        ? WorkoutSet(reps: 10, weight: 0, completed: false)
        : exercise.sets.last;
    exercises[index] = WorkoutExercise(
      exerciseId: exercise.exerciseId,
      sets: [...exercise.sets, last.copyWith(completed: false, clearRpe: true)],
    );
    await _commit(
      () => activeSession = activeSession!.copyWith(exercises: exercises),
    );
  }

  Future<void> removeSet(int exerciseIndex, int setIndex) async {
    if (activeSession == null) return;
    final exercises = [...activeSession!.exercises];
    final exercise = exercises[exerciseIndex];
    final sets = [...exercise.sets]..removeAt(setIndex);
    exercises[exerciseIndex] = WorkoutExercise(
      exerciseId: exercise.exerciseId,
      sets: sets,
    );
    await _commit(
      () => activeSession = activeSession!.copyWith(exercises: exercises),
    );
  }

  Future<void> finishWorkout({String notes = ''}) async {
    if (activeSession == null) return;
    if (activeSession!.completedSets == 0) {
      throw StateError('Complete at least one set before saving.');
    }
    final finished = activeSession!.copyWith(
      finishedAt: DateTime.now(),
      notes: notes,
    );
    await _commit(() {
      history.insert(0, finished);
      activeSession = null;
    });
  }

  Future<void> discardWorkout() async {
    await _commit(() => activeSession = null);
  }

  Future<int> scheduleBulk({
    required String routineId,
    required DateTime start,
    required int weeks,
    required Set<int> weekdays,
    required TimeOfDay time,
    required bool reminder,
  }) async {
    if (weeks < 1 ||
        weeks > 12 ||
        weekdays.isEmpty ||
        weekdays.any((day) => day < 1 || day > 7) ||
        routineById(routineId) == null) {
      throw ArgumentError('Choose a routine, weekdays and 1–12 weeks.');
    }
    var added = 0;
    final created = <ScheduledWorkout>[];
    for (var offset = 0; offset < weeks * 7; offset++) {
      final day = DateTime(
        start.year,
        start.month,
        start.day + offset,
        time.hour,
        time.minute,
      );
      if (!weekdays.contains(day.weekday) || !day.isAfter(DateTime.now())) {
        continue;
      }
      if (schedule.any((e) => e.routineId == routineId && e.date == day)) {
        continue;
      }
      final event = ScheduledWorkout(
        id: '${day.microsecondsSinceEpoch}-$routineId',
        routineId: routineId,
        date: day,
        reminder: false,
      );
      created.add(event);
      added++;
    }
    // Persist first so a permissions/platform failure never loses the plan.
    await _commit(() {
      schedule.addAll(created);
      schedule.sort((a, b) => a.date.compareTo(b.date));
    });
    if (reminder) await _scheduleReminders(created);
    return added;
  }

  Future<void> removeScheduled(String id) async {
    final scope = _accountId;
    await _commit(() => schedule.removeWhere((e) => e.id == id));
    await _cancelReminder(id, scope);
  }

  double get totalVolume => history.fold(0.0, (sum, s) => sum + s.volume);
  int get weeklyCount {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
    final nextMonday = DateTime(monday.year, monday.month, monday.day + 7);
    return history
        .where(
          (s) =>
              !s.startedAt.isBefore(monday) && s.startedAt.isBefore(nextMonday),
        )
        .length;
  }

  /// Structured context is also used by the on-device coach. The service must
  /// require explicit consent before transmitting any of it remotely. Free-text
  /// notes and limitations are excluded entirely until consent is given.
  String get coachContext =>
      _buildCoachContext(includePrivateText: profile.coachConsent);

  /// This context is exclusively for the on-device coach. Services must never
  /// attach it to an HTTP request when remote consent is disabled.
  String get localCoachContext => _buildCoachContext(includePrivateText: true);

  String _buildCoachContext({required bool includePrivateText}) {
    final now = DateTime.now();
    final stats = analytics;
    String bounded(String value, int max) =>
        value.length <= max ? value : value.substring(0, max);
    final profileData = profile.toJson()..remove('limitations');
    if (includePrivateText) {
      profileData['limitations'] = profile.limitations;
    }
    List<Map<String, dynamic>> sessionExercises(
      WorkoutSession session, {
      int max = 6,
    }) => session.exercises.take(max).map((item) {
      final exercise = exerciseById(item.exerciseId);
      final completed = item.sets.where(isValidCompletedSet).toList();
      final lastSets = completed.skip(
        completed.length > 4 ? completed.length - 4 : 0,
      );
      return <String, dynamic>{
        'exerciseId': bounded(item.exerciseId, 80),
        'name': bounded(exercise.name, 72),
        'muscle': bounded(exercise.muscle, 60),
        'equipment': bounded(exercise.equipment, 60),
        'sets': lastSets
            .map(
              (set) => {
                'reps': set.reps,
                'weight': set.weight,
                'completed': true,
                if (set.rpe != null) 'rpe': set.rpe,
              },
            )
            .toList(),
      };
    }).toList();
    final recent =
        history
            .where(
              (session) =>
                  session.finishedAt != null &&
                  !session.startedAt.isAfter(now) &&
                  !session.finishedAt!.isAfter(now) &&
                  !session.finishedAt!.isBefore(session.startedAt) &&
                  session.completedSets > 0,
            )
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final sessionData = recent
        .take(8)
        .map(
          (session) => <String, dynamic>{
            'startedAt': session.startedAt.toIso8601String(),
            'finishedAt': session.finishedAt!.toIso8601String(),
            'routineName': bounded(session.routineName, 72),
            'exercises': sessionExercises(session),
            if (includePrivateText && session.notes.isNotEmpty)
              'notes': bounded(session.notes, 400),
          },
        )
        .toList();
    final upcoming = schedule.where((item) => item.date.isAfter(now)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final context = <String, dynamic>{
      'schemaVersion': 2,
      'goal': goal,
      'profile': profileData,
      'statistics': {
        'windowDays': 28,
        'workoutCount': stats.workoutCountLast28,
        'activeDays': stats.activeDaysLast28,
        'targetActiveDays': stats.targetDaysLast28,
        'completedSets': stats.completedSetsLast28,
        'volumeKgReps': stats.volumeLast28,
        'consistencyScore': stats.score,
        'muscles': stats.muscles
            .take(10)
            .map(
              (item) => {
                'muscle': bounded(item.muscle, 60),
                'completedSets': item.completedSets,
                'volume': item.volume,
              },
            )
            .toList(),
        'weeks': stats.weeks
            .map(
              (week) => {
                'start': week.start.toIso8601String(),
                'activeDays': week.activeDays,
                'completedSets': week.completedSets,
                'volume': week.volume,
              },
            )
            .toList(),
      },
      'recentSessions': sessionData,
      if (activeSession != null)
        'activeSession': {
          'startedAt': activeSession!.startedAt.toIso8601String(),
          'routineName': bounded(activeSession!.routineName, 72),
          'exercises': sessionExercises(activeSession!, max: 4),
        },
      'upcomingWorkouts': upcoming
          .take(6)
          .map(
            (item) => {
              'date': item.date.toIso8601String(),
              'routineName': bounded(
                routineById(item.routineId)?.name ?? 'Workout',
                72,
              ),
            },
          )
          .toList(),
    };
    // Remove complete old sessions, never truncate encoded JSON mid-document.
    var encoded = jsonEncode(context);
    while (encoded.length > 10000 && sessionData.isNotEmpty) {
      sessionData.removeLast();
      encoded = jsonEncode(context);
    }
    return encoded;
  }
}

Never _invalidBackup() => throw const FormatException(
  'The backup is incomplete or contains invalid training data. '
  'Your data on this device has been preserved.',
);

Map<String, dynamic> _object(Object? value) {
  if (value is! Map) _invalidBackup();
  try {
    return Map<String, dynamic>.from(value);
  } catch (_) {
    _invalidBackup();
  }
}

List<dynamic> _list(Object? value) {
  if (value is! List) _invalidBackup();
  return value;
}

void _nonBlankString(Object? value) {
  if (value is! String || value.trim().isEmpty) _invalidBackup();
}

void _integer(Object? value, {int min = 0, int? max}) {
  if (value is! num ||
      !value.isFinite ||
      value < min ||
      value != value.roundToDouble() ||
      (max != null && value > max)) {
    _invalidBackup();
  }
}

void _weight(Object? value) {
  if (value is! num || !value.isFinite || value < 0 || value > 100000) {
    _invalidBackup();
  }
}

DateTime _date(Object? value) {
  if (value is! String) _invalidBackup();
  final date = DateTime.tryParse(value);
  if (date == null) _invalidBackup();
  return date;
}

void _validateRoutine(Map<String, dynamic> routine) {
  _nonBlankString(routine['id']);
  _nonBlankString(routine['name']);
  if (routine['subtitle'] is! String || routine['category'] is! String) {
    _invalidBackup();
  }
  _integer(routine['estimatedMinutes'], max: 1440);
  for (final item in _list(routine['exercises'])) {
    final exercise = _object(item);
    _nonBlankString(exercise['exerciseId']);
    _integer(exercise['sets'], min: 1, max: 100);
    _integer(exercise['reps'], min: 1, max: 100000);
    _weight(exercise['weight']);
  }
}

void _validateSession(Map<String, dynamic> session, {required bool finished}) {
  _nonBlankString(session['id']);
  _nonBlankString(session['routineName']);
  final start = _date(session['startedAt']);
  if (session['notes'] is! String) _invalidBackup();
  if (finished) {
    if (_date(session['finishedAt']).isBefore(start)) _invalidBackup();
  } else if (session['finishedAt'] != null) {
    _invalidBackup();
  }
  var completedSets = 0;
  for (final item in _list(session['exercises'])) {
    final exercise = _object(item);
    _nonBlankString(exercise['exerciseId']);
    for (final item in _list(exercise['sets'])) {
      final set = _object(item);
      _integer(set['reps'], min: 1, max: 100000);
      _weight(set['weight']);
      if (set['completed'] is! bool) _invalidBackup();
      final rpe = set['rpe'];
      if (rpe != null &&
          (rpe is! num || !rpe.isFinite || rpe < 1 || rpe > 10)) {
        _invalidBackup();
      }
      if (set['completed'] == true) completedSets++;
    }
  }
  if (finished && completedSets == 0) _invalidBackup();
}

void _uniqueId(Set<String> ids, Object? id) {
  _nonBlankString(id);
  if (!ids.add(id as String)) _invalidBackup();
}

void _validateBackup(Map<String, dynamic> data) {
  if (data['version'] != 1 ||
      data['name'] is! String ||
      data['goal'] is! String ||
      data['theme'] is! String ||
      !data.containsKey('active')) {
    _invalidBackup();
  }
  if (data['profile'] != null) {
    UserProfile.fromJson(_object(data['profile']));
  }
  if (data['favoriteExerciseIds'] != null) {
    final favorites = <String>{};
    for (final id in _list(data['favoriteExerciseIds'])) {
      _uniqueId(favorites, id);
    }
  }
  if (data['bodyMeasurements'] != null) {
    final ids = <String>{};
    final sourceIds = <String>{};
    for (final value in _list(data['bodyMeasurements'])) {
      final measurement = BodyMeasurement.fromJson(_object(value));
      _uniqueId(ids, measurement.id);
      if (measurement.sourceRecordId != null &&
          !sourceIds.add(
            '${measurement.source}/${measurement.sourceRecordId}',
          )) {
        _invalidBackup();
      }
    }
  }
  if (data['appliedCoachProposalIds'] != null) {
    final ids = <String>{};
    for (final id in _list(data['appliedCoachProposalIds'])) {
      _uniqueId(ids, id);
      if ((id as String).length > 256) _invalidBackup();
    }
  }
  final routineIds = routineTemplates.map((routine) => routine.id).toSet();
  for (final item in _list(data['routines'])) {
    final routine = _object(item);
    _validateRoutine(routine);
    _uniqueId(routineIds, routine['id']);
  }
  final sessionIds = <String>{};
  for (final item in _list(data['history'])) {
    final session = _object(item);
    _validateSession(session, finished: true);
    _uniqueId(sessionIds, session['id']);
  }
  if (data['active'] != null) {
    final session = _object(data['active']);
    _validateSession(session, finished: false);
    _uniqueId(sessionIds, session['id']);
  }
  final scheduleIds = <String>{};
  for (final item in _list(data['schedule'])) {
    final event = _object(item);
    _uniqueId(scheduleIds, event['id']);
    _nonBlankString(event['routineId']);
    _date(event['date']);
    if (event['reminder'] is! bool) _invalidBackup();
  }
}
