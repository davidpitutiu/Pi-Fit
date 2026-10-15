import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

/// A snapshot, never an instruction to advance past a changed set. Nullable set
/// fields mean there is no valid next unchecked set to offer an action for.
class WorkoutNotificationPayload {
  const WorkoutNotificationPayload({
    required this.accountId,
    required this.sessionId,
    required this.startedAt,
    required this.token,
    this.exerciseIndex,
    this.setIndex,
    this.exerciseId,
    this.reps,
    this.weight,
    this.restEndsAt,
  });
  final String? accountId;
  final String sessionId;
  final DateTime startedAt;
  final String token;
  final int? exerciseIndex, setIndex, reps;
  final String? exerciseId;
  final double? weight;
  final DateTime? restEndsAt;
  bool get hasNextSet => exerciseIndex != null;
  String encode() => jsonEncode({
    'schema': 1,
    'kind': 'workout',
    'accountId': accountId,
    'sessionId': sessionId,
    'startedAt': startedAt.toIso8601String(),
    'token': token,
    'exerciseIndex': exerciseIndex,
    'setIndex': setIndex,
    'exerciseId': exerciseId,
    'reps': reps,
    'weight': weight,
    'restEndsAt': restEndsAt?.millisecondsSinceEpoch,
  });
  static WorkoutNotificationPayload? decode(String? raw) {
    if (raw == null || raw.length > 3000) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map ||
          value['schema'] != 1 ||
          value['kind'] != 'workout' ||
          !value.containsKey('accountId')) {
        return null;
      }
      final account = value['accountId'];
      if (account != null &&
          (account is! String || account.isEmpty || account.length > 128)) {
        return null;
      }
      final session = value['sessionId'];
      final token = value['token'];
      if (session is! String ||
          session.isEmpty ||
          session.length > 200 ||
          token is! String ||
          token.isEmpty ||
          token.length > 120) {
        return null;
      }
      final started = DateTime.parse(value['startedAt'] as String);
      int? integer(String key, int min, int max) {
        final entry = value[key];
        if (entry == null) return null;
        if (entry is! int || entry < min || entry > max) {
          throw const FormatException();
        }
        return entry;
      }

      final exercise = integer('exerciseIndex', 0, 999);
      final set = integer('setIndex', 0, 999);
      final reps = integer('reps', 1, 1000);
      final weight = value['weight'];
      final exerciseId = value['exerciseId'];
      final allAbsent = [
        exercise,
        set,
        reps,
        weight,
        exerciseId,
      ].every((item) => item == null);
      if (!allAbsent &&
          (exercise == null ||
              set == null ||
              reps == null ||
              weight is! num ||
              !weight.isFinite ||
              weight < 0 ||
              weight > 2000 ||
              exerciseId is! String ||
              exerciseId.isEmpty ||
              exerciseId.length > 200)) {
        return null;
      }
      final deadline = integer('restEndsAt', 0, 8640000000000000);
      return WorkoutNotificationPayload(
        accountId: account as String?,
        sessionId: session,
        startedAt: started,
        token: token,
        exerciseIndex: exercise,
        setIndex: set,
        exerciseId: exerciseId as String?,
        reps: reps,
        weight: (weight as num?)?.toDouble(),
        restEndsAt: deadline == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(deadline),
      );
    } catch (_) {
      return null;
    }
  }
}

class WorkoutNotificationAction {
  const WorkoutNotificationAction({
    required this.actionId,
    required this.payload,
  });
  final String actionId;
  final WorkoutNotificationPayload payload;
}

class NotificationService extends ChangeNotifier {
  NotificationService._({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  @visibleForTesting
  factory NotificationService.forTesting({
    FlutterLocalNotificationsPlugin? plugin,
  }) => NotificationService._(plugin: plugin);
  static final NotificationService instance = NotificationService._();
  static const checkSetAction = 'pi_fit_check_set';
  static const skipRestAction = 'pi_fit_skip_rest';
  static final workoutNotificationId = stableId('pi_fit_active_workout');
  final FlutterLocalNotificationsPlugin _plugin;
  final _actions = StreamController<WorkoutNotificationAction>.broadcast(
    sync: true,
  );
  final List<WorkoutNotificationAction> _pendingActions = [];
  Stream<WorkoutNotificationAction> get workoutActions => _actions.stream;
  List<WorkoutNotificationAction> takePendingWorkoutActions() {
    final result = List<WorkoutNotificationAction>.from(_pendingActions);
    _pendingActions.clear();
    return result;
  }

  static String workoutPreferenceKey(String? accountId) =>
      'pifit.workout.shortcuts.${accountId == null ? 'guest' : 'account.$accountId'}.v1';
  int workoutPreferencesRevision = 0;
  void workoutPreferencesChanged() {
    workoutPreferencesRevision++;
    notifyListeners();
  }

  void reportWorkoutError(String? message) => _setWorkoutError(message);
  bool _initialized = false;
  Future<void>? _initializing;
  String? lastError;
  String? workoutError;
  bool get mobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  bool get supported => mobilePlatform && _initialized;

  static List<DarwinNotificationCategory> get workoutCategories {
    DarwinNotificationAction action(String id, String title) =>
        DarwinNotificationAction.plain(
          id,
          title,
          options: {DarwinNotificationActionOption.foreground},
        );
    final check = action(checkSetAction, 'Check set');
    final skip = action(skipRestAction, 'Skip rest');
    return [
      DarwinNotificationCategory('pi_fit_workout_both', actions: [skip, check]),
      DarwinNotificationCategory('pi_fit_workout_check', actions: [check]),
      DarwinNotificationCategory('pi_fit_workout_rest', actions: [skip]),
      const DarwinNotificationCategory('pi_fit_workout_open'),
    ];
  }

  Future<void> initialize() {
    if (_initialized || !mobilePlatform) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    try {
      timezone_data.initializeTimeZones();
      final deviceZone = await FlutterTimezone.getLocalTimezone();
      timezone.setLocalLocation(timezone.getLocation(deviceZone.identifier));
      final result = await _plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
            notificationCategories: workoutCategories,
          ),
        ),
        onDidReceiveNotificationResponse: _handleResponse,
      );
      _initialized = result != false;
      if (!_initialized) {
        lastError = 'Notifications could not be initialized.';
        return;
      }
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true &&
          launch?.notificationResponse != null) {
        _handleResponse(launch!.notificationResponse!);
      }
      lastError = null;
    } on MissingPluginException {
      lastError = 'Notifications require the installed Android or iOS app.';
    } on PlatformException catch (error) {
      lastError = 'Notification initialization failed: ${error.code}.';
    } on ArgumentError {
      lastError = 'The device timezone is not recognized.';
    } catch (_) {
      lastError = 'Notifications could not be initialized on this device.';
    }
  }

  void _handleResponse(NotificationResponse response) {
    final payload = WorkoutNotificationPayload.decode(response.payload);
    final action = response.actionId ?? '';
    if (payload == null ||
        !{'', checkSetAction, skipRestAction}.contains(action)) {
      return;
    }
    final event = WorkoutNotificationAction(actionId: action, payload: payload);
    if (_actions.hasListener) {
      _actions.add(event);
    } else {
      _pendingActions.add(event);
    }
  }

  @visibleForTesting
  void handleResponse(NotificationResponse response) =>
      _handleResponse(response);

  Future<bool> requestWorkoutPermission() async {
    await initialize();
    if (!supported) {
      throw UnsupportedError(
        lastError ?? 'Workout shortcuts are available on Android and iOS.',
      );
    }
    final allowed = defaultTargetPlatform == TargetPlatform.android
        ? await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission()
        : await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true);
    if (allowed != true) {
      throw StateError(
        'Allow notifications for Pi Fit in your device settings.',
      );
    }
    return true;
  }

  @visibleForTesting
  static NotificationDetails workoutDetails(
    WorkoutNotificationPayload payload,
  ) {
    final resting = payload.restEndsAt != null;
    final actions = <AndroidNotificationAction>[
      if (resting)
        const AndroidNotificationAction(
          skipRestAction,
          'Skip rest',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      if (payload.hasNextSet)
        const AndroidNotificationAction(
          checkSetAction,
          'Check set',
          showsUserInterface: true,
          cancelNotification: false,
        ),
    ];
    final category = resting
        ? (payload.hasNextSet ? 'both' : 'rest')
        : (payload.hasNextSet ? 'check' : 'open');
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'pi_fit_active_workout',
        'Workout shortcuts',
        channelDescription:
            'Your active workout, shared rest timer and set shortcuts.',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        playSound: false,
        enableVibration: false,
        showWhen: true,
        usesChronometer: true,
        chronometerCountDown: resting,
        when: (payload.restEndsAt ?? payload.startedAt).millisecondsSinceEpoch,
        category: AndroidNotificationCategory.workout,
        actions: actions,
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: 'pi_fit_workout_$category',
        presentAlert: false,
        presentSound: false,
        presentBanner: false,
        presentList: true,
      ),
    );
  }

  Future<void> showWorkout({
    required WorkoutNotificationPayload payload,
    required String routineName,
    String? nextExerciseName,
  }) async {
    if (!supported) return;
    final resting = payload.restEndsAt != null;
    final deadline = payload.restEndsAt?.toLocal();
    final time = deadline == null
        ? null
        : '${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}';
    final next = payload.hasNextSet
        ? 'Next: ${nextExerciseName ?? 'exercise'} · ${payload.reps} × ${payload.weight!.toStringAsFixed(payload.weight! % 1 == 0 ? 0 : 1)} kg'
        : 'Open Pi Fit to review or finish your workout.';
    try {
      await _plugin.show(
        id: workoutNotificationId,
        title: resting ? 'Rest · $routineName' : routineName,
        body: time == null ? next : 'Rest until $time · $next',
        notificationDetails: workoutDetails(payload),
        payload: payload.encode(),
      );
      _setWorkoutError(null);
    } catch (_) {
      _setWorkoutError(
        'Workout shortcuts could not be updated. Your workout is saved in the app.',
      );
      rethrow;
    }
  }

  Future<void> cancelWorkout() async {
    if (!supported) return;
    try {
      await _plugin.cancel(id: workoutNotificationId);
      _setWorkoutError(null);
    } catch (_) {
      _setWorkoutError(
        'The workout notification could not be removed. Open Pi Fit to check your current workout.',
      );
      rethrow;
    }
  }

  void _setWorkoutError(String? value) {
    if (workoutError == value) return;
    workoutError = value;
    notifyListeners();
  }

  Future<void> schedule(String id, DateTime date, String title) async {
    await initialize();
    if (!supported) {
      throw UnsupportedError(
        lastError ?? 'Reminders are available in the Android and iOS app.',
      );
    }
    if (!date.isAfter(DateTime.now())) {
      throw ArgumentError('Schedule the reminder for a future date.');
    }
    await requestWorkoutPermission();
    final notificationId = stableId(id);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final pending = await _plugin.pendingNotificationRequests();
      if (pending.length >= 60 &&
          !pending.any((item) => item.id == notificationId)) {
        throw StateError(
          'iOS limits pending reminders. Schedule no more than 60 sessions with reminders at once.',
        );
      }
    }
    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'Time for $title',
      body: 'Your workout is ready. Let’s make progress! ⚡',
      scheduledDate: timezone.TZDateTime.from(date, timezone.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'pi_fit_workouts',
          'Scheduled workouts',
          channelDescription: 'Reminders for your Pi Fit workouts.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: id,
    );
  }

  Future<void> cancel(String id) async {
    if (supported) await _plugin.cancel(id: stableId(id));
  }

  @visibleForTesting
  static int stableId(String id) {
    var hash = 0x811c9dc5;
    for (final unit in id.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  @override
  void dispose() {
    _actions.close();
    super.dispose();
  }
}
