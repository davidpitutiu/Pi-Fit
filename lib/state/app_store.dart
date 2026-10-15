import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import '../domain/exercise_catalog.dart';
import '../services/notification_service.dart';

class AppStore extends ChangeNotifier {
  static const profileGoals = [
    'Forță și masă musculară',
    'Condiție fizică',
    'Controlul greutății',
    'Mobilitate și recuperare',
  ];
  final SharedPreferences preferences;
  AppStore(this.preferences);
  ThemeMode themeMode = ThemeMode.dark;
  String name = 'Atlet';
  String goal = 'Forță și masă musculară';
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
      name: 'Exercițiu salvat',
      muscle: 'Altele',
      equipment: 'Nespecificat',
      description:
          'Acest exercițiu nu este disponibil în catalogul curent. '
          'Seturile și progresul tău au fost păstrate.',
    );
  }

  Routine? routineById(String id) {
    for (final routine in routines) {
      if (routine.id == id) return routine;
    }
    return null;
  }

  String get _storageKey => 'pifit.local.v1';
  String get _corruptKey => 'pifit.recovery.v1';
  Future<void> load() async {
    final raw = preferences.getString(_storageKey);
    if (raw == null) return;
    try {
      _restore(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      persistenceError = null;
    } catch (_) {
      final existing = preferences.getString(_corruptKey);
      final key = existing == null || existing == raw
          ? _corruptKey
          : '$_corruptKey.${DateTime.now().microsecondsSinceEpoch}';
      final preserved = await preferences.setString(key, raw);
      persistenceError = preserved
          ? 'Datele locale nu au putut fi citite. O copie de recuperare a fost păstrată.'
          : 'Datele locale nu au putut fi citite. Datele originale nu au fost modificate.';
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
    final loadedTheme = ThemeMode.values.firstWhere(
      (t) => t.name == data['theme'],
      orElse: () => ThemeMode.dark,
    );
    // Parsing and normalization must all succeed before replacing any state.
    name = loadedName;
    goal = loadedGoal;
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
    'theme': themeMode.name,
    'routines': customRoutines.map((r) => r.toJson()).toList(),
    'history': history.map((r) => r.toJson()).toList(),
    'schedule': schedule.map((r) => r.toJson()).toList(),
    'active': activeSession?.toJson(),
  };
  Future<void> restoreBackup(Map<String, dynamic> data) async {
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
      'pifit.before_restore.v1',
      jsonEncode(before),
    );
    if (!recoverySaved) {
      throw StateError('Copia locală de recuperare nu a putut fi salvată.');
    }
    await _writeLocal(jsonEncode(imported.exportData()));
    _restore(imported.exportData());
    persistenceError = null;
    notifyListeners();
    // Reconcile reminders only after the imported calendar is safely stored.
    Object? cancellationError;
    for (final event in oldReminders) {
      try {
        await NotificationService.instance.cancel(event.id);
      } catch (error) {
        cancellationError ??= error;
      }
    }
    await _scheduleReminders(requested);
    if (cancellationError != null) {
      throw StateError(
        'Backupul a fost restaurat. Unele remindere vechi nu '
        'au putut fi anulate: $cancellationError',
      );
    }
  }

  String _profileName(String value) =>
      value.trim().isEmpty ? 'Atlet' : value.trim();
  String _profileGoal(String value) =>
      profileGoals.contains(value.trim()) ? value.trim() : profileGoals.first;

  Future<void> _commit(void Function() change) async {
    final before = exportData();
    try {
      change();
      await _save();
    } catch (_) {
      _restore(before);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _scheduleReminders(List<ScheduledWorkout> requested) async {
    if (requested.isEmpty) return;
    Object? failure;
    for (final event in requested) {
      try {
        await NotificationService.instance.schedule(
          event.id,
          event.date,
          routineById(event.routineId)?.name ?? 'Antrenament',
        );
        final index = schedule.indexWhere((item) => item.id == event.id);
        if (index >= 0) {
          schedule[index] = schedule[index].copyWith(reminder: true);
        }
      } catch (error) {
        failure = error;
        // Do not repeatedly prompt for permission or retry an unsupported
        // platform for each date in a bulk plan.
        break;
      }
    }
    await _save();
    if (failure != null) {
      throw StateError(
        'Antrenamentele sunt salvate în calendar. Unele remindere '
        'nu au putut fi programate: $failure',
      );
    }
  }

  Future<void> _save() async {
    await _writeLocal(jsonEncode(exportData()));
    notifyListeners();
  }

  Future<void> _writeLocal(String value) async {
    final previous = preferences.getString(_storageKey);
    try {
      if (await preferences.setString(_storageKey, value)) return;
    } catch (_) {
      // Restore the preferences cache too: the legacy preferences API updates
      // its cache before the platform confirms a successful disk write.
    }
    try {
      if (previous == null) {
        await preferences.remove(_storageKey);
      } else {
        await preferences.setString(_storageKey, previous);
      }
    } catch (_) {
      // The in-memory AppStore transaction still rolls back, and a recovery
      // copy is retained before a cloud restore replaces any local data.
    }
    throw StateError('Salvarea locală a eșuat.');
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

  Future<void> saveRoutine(Routine routine) async {
    _validateRoutine(routine.toJson());
    if (routineTemplates.any((item) => item.id == routine.id)) {
      throw ArgumentError(
        'Salvează rutina personalizată cu un identificator nou.',
      );
    }
    await _commit(() {
      customRoutines.removeWhere((r) => r.id == routine.id);
      customRoutines.insert(0, routine);
    });
  }

  Future<void> startEmptyWorkout() => startWorkout(
    Routine(
      id: 'free',
      name: 'Antrenament liber',
      subtitle: 'Construiește în ritmul tău',
      exercises: [],
      estimatedMinutes: 0,
      category: 'Personalizat',
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
      throw ArgumentError('Selectează un exercițiu din catalog.');
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
  }) async {
    if (activeSession == null) return;
    if ((reps != null && (reps < 1 || reps > 100000)) ||
        (weight != null &&
            (!weight.isFinite || weight < 0 || weight > 100000))) {
      throw ArgumentError(
        'Repetările trebuie să fie pozitive, iar greutatea validă și cel puțin zero.',
      );
    }
    final exercises = [...activeSession!.exercises];
    final exercise = exercises[exerciseIndex];
    final sets = [...exercise.sets];
    sets[setIndex] = sets[setIndex].copyWith(
      reps: reps,
      weight: weight,
      completed: completed,
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
      sets: [...exercise.sets, last.copyWith(completed: false)],
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
      throw StateError('Bifează cel puțin un set înainte de salvare.');
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
      throw ArgumentError('Selectează o rutină, zilele și 1–12 săptămâni.');
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
    await _commit(() => schedule.removeWhere((e) => e.id == id));
    await NotificationService.instance.cancel(id);
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

  String get coachContext =>
      'Obiectiv: $goal. Antrenamente în această săptămână: $weeklyCount. Total antrenamente: ${history.length}. Ultimele rutine: ${history.take(3).map((s) => s.routineName).join(', ')}. Nu presupune informații medicale sau greutăți optime.';
}

Never _invalidBackup() => throw const FormatException(
  'Backupul este incomplet sau conține date de antrenament nevalide. '
  'Datele de pe acest dispozitiv au fost păstrate.',
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
