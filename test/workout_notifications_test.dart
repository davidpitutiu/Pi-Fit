import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pi_fit/services/firebase_gateway.dart';
import 'package:pi_fit/services/notification_service.dart';
import 'package:pi_fit/services/workout_clock.dart';
import 'package:pi_fit/state/app_store.dart';
import 'package:pi_fit/ui/workout_notification_coordinator.dart';
import 'package:pi_fit/ui/workout_shortcuts_card.dart';

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
}

class _Gateway extends Fake implements FirebaseGateway {
  User? user;
  final changes = StreamController<User?>.broadcast(sync: true);
  @override
  User? get currentUser => user;
  @override
  Stream<User?> get authStateChanges => changes.stream;
  void emit(String? uid) {
    user = uid == null ? null : _User(uid);
    changes.add(user);
  }
}

class _Notifications extends Fake implements NotificationService {
  final listeners = ChangeNotifier();
  final actions = StreamController<WorkoutNotificationAction>.broadcast(
    sync: true,
  );
  final shown = <WorkoutNotificationPayload>[];
  final pending = <WorkoutNotificationAction>[];
  int cancelled = 0, permissions = 0;
  Completer<void>? publicationHold;
  Completer<bool>? permissionHold;
  @override
  bool get supported => true;
  @override
  bool get mobilePlatform => true;
  @override
  String? workoutError;
  @override
  int workoutPreferencesRevision = 0;
  @override
  void addListener(VoidCallback listener) => listeners.addListener(listener);
  @override
  void removeListener(VoidCallback listener) =>
      listeners.removeListener(listener);
  @override
  Stream<WorkoutNotificationAction> get workoutActions => actions.stream;
  @override
  Future<void> initialize() async {}
  @override
  List<WorkoutNotificationAction> takePendingWorkoutActions() {
    final result = [...pending];
    pending.clear();
    return result;
  }

  @override
  Future<void> showWorkout({
    required WorkoutNotificationPayload payload,
    required String routineName,
    String? nextExerciseName,
  }) async {
    final hold = publicationHold;
    publicationHold = null;
    if (hold != null) await hold.future;
    shown.add(payload);
  }

  @override
  Future<void> cancelWorkout() async {
    cancelled++;
  }

  @override
  void reportWorkoutError(String? value) {
    workoutError = value;
    listeners.notifyListeners();
  }

  @override
  void workoutPreferencesChanged() {
    workoutPreferencesRevision++;
    listeners.notifyListeners();
  }

  @override
  Future<bool> requestWorkoutPermission() async {
    permissions++;
    return permissionHold?.future ?? true;
  }

  void emit(String action, WorkoutNotificationPayload payload) => actions.add(
    WorkoutNotificationAction(actionId: action, payload: payload),
  );
  Future<void> close() async {
    await actions.close();
    listeners.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppStore store;
  late _Notifications notifications;
  late _Gateway gateway;
  late WorkoutClock clock;
  late DateTime now;
  late WorkoutNotificationController controller;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AppStore(await SharedPreferences.getInstance());
    await store.startWorkout(store.routines.first);
    await store.updateSet(0, 0, reps: 8, weight: 40);
    now = DateTime.now();
    clock = WorkoutClock.forTesting(now: () => now);
    notifications = _Notifications();
    gateway = _Gateway();
    controller = WorkoutNotificationController(
      store: store,
      notifications: notifications,
      clock: clock,
      gateway: gateway,
    );
  });
  tearDown(() async {
    controller.dispose();
    clock.dispose();
    await notifications.close();
    await gateway.changes.close();
  });
  Future<void> enable([String? account]) async {
    await store.preferences.setBool(
      NotificationService.workoutPreferenceKey(account),
      true,
    );
    notifications.workoutPreferencesChanged();
  }

  test(
    'opt-in controls publication and shared clock avoids per-second notification posts',
    () async {
      await controller.start();
      await controller.flush();
      expect(notifications.shown, isEmpty);
      expect(clock.sessionId, store.activeSession!.id);
      await enable();
      await controller.flush();
      expect(notifications.shown, hasLength(1));
      final started = store.activeSession!.startedAt;
      expect(notifications.shown.last.startedAt, started);
      clock.startRest();
      await controller.flush();
      expect(notifications.shown.last.restEndsAt, clock.restEndsAt);
      final updates = notifications.shown.length;
      now = now.add(const Duration(seconds: 5));
      clock.tick();
      await controller.flush();
      expect(clock.remaining, 85);
      expect(notifications.shown.length, updates);
      now = now.add(const Duration(seconds: 90));
      clock.tick();
      await controller.flush();
      expect(notifications.shown.last.restEndsAt, isNull);
      expect(clock.remaining, 0);
    },
  );

  test('check set validates exact next set and applies one set once', () async {
    await enable();
    await controller.start();
    await controller.flush();
    final old = notifications.shown.last;
    await store.updateSet(0, 0, reps: 12);
    await controller.flush();
    notifications.emit(NotificationService.checkSetAction, old);
    await controller.flush();
    expect(store.activeSession!.completedSets, 0);
    final current = notifications.shown.last;
    notifications.emit(NotificationService.checkSetAction, current);
    await controller.flush();
    expect(store.activeSession!.completedSets, 1);
    expect(store.activeSession!.exercises.first.sets.first.completed, isTrue);
    expect(store.activeSession!.exercises.first.sets[1].completed, isFalse);
    expect(clock.remaining, 90);
    notifications.emit(NotificationService.checkSetAction, current);
    await controller.flush();
    expect(store.activeSession!.completedSets, 1);
  });

  test('skip rest only changes the captured current shared deadline', () async {
    await enable();
    await controller.start();
    clock.startRest();
    await controller.flush();
    final old = notifications.shown.last;
    now = now.add(const Duration(seconds: 2));
    clock.startRest();
    await controller.flush();
    notifications.emit(NotificationService.skipRestAction, old);
    await controller.flush();
    expect(clock.remaining, 90);
    notifications.emit(
      NotificationService.skipRestAction,
      notifications.shown.last,
    );
    await controller.flush();
    expect(clock.remaining, 0);
    expect(clock.restEndsAt, isNull);
    expect(store.activeSession!.completedSets, 0);
  });

  test(
    'old-account payloads cannot mutate a different account or expose notifications during transition',
    () async {
      await enable();
      await controller.start();
      await controller.flush();
      final guestPayload = notifications.shown.last;
      final cancelBefore = notifications.cancelled;
      gateway.emit('alice');
      await controller.flush();
      expect(notifications.cancelled, greaterThan(cancelBefore));
      await store.switchAccount('alice');
      await store.startWorkout(store.routines.first);
      await enable('alice');
      await controller.flush();
      final alice = store.exportData();
      notifications.emit(NotificationService.checkSetAction, guestPayload);
      await controller.flush();
      expect(store.exportData(), alice);
      expect(notifications.shown.last.accountId, 'alice');
      await store.discardWorkout();
      await controller.flush();
      expect(clock.sessionId, isNull);
      expect(notifications.cancelled, greaterThan(cancelBefore));
    },
  );

  test(
    'cold launch actions wait for matching account data before marking a set',
    () async {
      final session = store.activeSession!;
      await store.preferences.setString(
        'pifit.account.alice.v1',
        jsonEncode(store.exportData()),
      );
      await enable('alice');
      gateway.user = _User('alice');
      notifications.pending.add(
        WorkoutNotificationAction(
          actionId: NotificationService.checkSetAction,
          payload: WorkoutNotificationPayload(
            accountId: 'alice',
            sessionId: session.id,
            startedAt: session.startedAt,
            token: 'cold-1',
            exerciseIndex: 0,
            setIndex: 0,
            exerciseId: session.exercises.first.exerciseId,
            reps: 8,
            weight: 40,
          ),
        ),
      );
      await controller.start();
      await controller.flush();
      expect(store.accountId, isNull);
      expect(store.activeSession!.completedSets, 0);
      await store.switchAccount('alice');
      await controller.flush();
      expect(store.accountId, 'alice');
      expect(store.activeSession!.completedSets, 1);
      expect(clock.remaining, 90);
    },
  );

  test(
    'persisted replay tokens protect an undone set after coordinator restart',
    () async {
      await enable();
      await controller.start();
      await controller.flush();
      final payload = notifications.shown.last;
      notifications.emit(NotificationService.checkSetAction, payload);
      await controller.flush();
      await store.updateSet(0, 0, completed: false);
      await controller.flush();
      controller.dispose();
      controller = WorkoutNotificationController(
        store: store,
        notifications: notifications,
        clock: clock,
        gateway: gateway,
      );
      await controller.start();
      await controller.flush();
      notifications.emit(NotificationService.checkSetAction, payload);
      await controller.flush();
      expect(store.activeSession!.completedSets, 0);
    },
  );

  test(
    'late old notification publication is cleaned before current scope publication',
    () async {
      await enable();
      await controller.start();
      await controller.flush();
      final hold = Completer<void>();
      notifications.publicationHold = hold;
      clock.startRest();
      await Future<void>.delayed(Duration.zero);
      gateway.emit('alice');
      await store.switchAccount('alice');
      await store.startWorkout(store.routines.first);
      await enable('alice');
      hold.complete();
      await controller.flush();
      expect(notifications.shown.last.accountId, 'alice');
      expect(notifications.cancelled, greaterThan(0));
    },
  );

  test(
    'authentication stream errors cancel shortcuts and reject pending actions',
    () async {
      await enable();
      await controller.start();
      await controller.flush();
      final payload = notifications.shown.last;
      final before = notifications.cancelled;
      gateway.changes.addError(StateError('auth unavailable'));
      await controller.flush();
      expect(notifications.cancelled, greaterThan(before));
      notifications.emit(NotificationService.checkSetAction, payload);
      await controller.flush();
      expect(store.activeSession!.completedSets, 0);
      expect(clock.sessionId, isNull);
    },
  );

  test(
    'payload parsing rejects partial or malformed set snapshots and reminders',
    () {
      final payload = WorkoutNotificationPayload(
        accountId: null,
        sessionId: 's',
        startedAt: now,
        token: 't',
        exerciseIndex: 0,
        setIndex: 0,
        exerciseId: 'bench',
        reps: 8,
        weight: 50,
      );
      expect(WorkoutNotificationPayload.decode(payload.encode())!.weight, 50);
      final raw = jsonDecode(payload.encode()) as Map<String, dynamic>;
      for (final changed in [
        {...raw, 'schema': 2},
        {...raw, 'accountId': 42},
        {...raw, 'exerciseIndex': -1},
        {...raw, 'setIndex': null},
        {...raw, 'weight': -1},
        {...raw, 'reps': 0},
        {...raw, 'startedAt': 'broken'},
        {...raw, 'token': ''},
      ]) {
        expect(WorkoutNotificationPayload.decode(jsonEncode(changed)), isNull);
      }
      expect(
        WorkoutNotificationPayload.decode('account/alice/calendar-event'),
        isNull,
      );
    },
  );

  test(
    'native notification details use foreground actions and system chronometer timestamps',
    () {
      final payload = WorkoutNotificationPayload(
        accountId: null,
        sessionId: 's',
        startedAt: now,
        token: 't',
        exerciseIndex: 0,
        setIndex: 0,
        exerciseId: 'bench',
        reps: 8,
        weight: 50,
        restEndsAt: now.add(const Duration(seconds: 90)),
      );
      final details = NotificationService.workoutDetails(payload);
      expect(details.android!.ongoing, isTrue);
      expect(details.android!.usesChronometer, isTrue);
      expect(details.android!.chronometerCountDown, isTrue);
      expect(details.android!.when, payload.restEndsAt!.millisecondsSinceEpoch);
      expect(details.android!.actions!.map((action) => action.title), [
        'Skip rest',
        'Check set',
      ]);
      expect(
        details.android!.actions!.every((action) => action.showsUserInterface),
        isTrue,
      );
      expect(details.iOS!.categoryIdentifier, 'pi_fit_workout_both');
      for (final category in NotificationService.workoutCategories) {
        expect(
          category.actions.every(
            (action) => action.options.contains(
              DarwinNotificationActionOption.foreground,
            ),
          ),
          isTrue,
        );
      }
      final elapsed = NotificationService.workoutDetails(
        WorkoutNotificationPayload(
          accountId: null,
          sessionId: 's',
          startedAt: now,
          token: 't',
        ),
      );
      expect(elapsed.android!.chronometerCountDown, isFalse);
      expect(elapsed.android!.when, now.millisecondsSinceEpoch);
      expect(elapsed.android!.actions, isEmpty);
    },
  );

  test(
    'native initialization registers cold launch action without requesting notification permission',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const native = MethodChannel('dexterous.com/flutter/local_notifications');
      const zone = MethodChannel('flutter_timezone');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final payload = WorkoutNotificationPayload(
        accountId: null,
        sessionId: 's',
        startedAt: now,
        token: 'cold',
      );
      final calls = <String>[];
      messenger.setMockMethodCallHandler(zone, (_) async => 'UTC');
      messenger.setMockMethodCallHandler(native, (call) async {
        calls.add(call.method);
        if (call.method == 'initialize') return true;
        if (call.method == 'getNotificationAppLaunchDetails') {
          return {
            'notificationLaunchedApp': true,
            'notificationResponse': {
              'notificationId': NotificationService.workoutNotificationId,
              'notificationResponseType': 1,
              'actionId': NotificationService.skipRestAction,
              'payload': payload.encode(),
            },
          };
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(zone, null);
        messenger.setMockMethodCallHandler(native, null);
      });
      final service = NotificationService.forTesting();
      addTearDown(service.dispose);
      await service.initialize();
      expect(service.supported, isTrue);
      expect(calls, isNot(contains('requestNotificationsPermission')));
      final pending = service.takePendingWorkoutActions();
      expect(pending, hasLength(1));
      expect(pending.single.actionId, NotificationService.skipRestAction);
      expect(pending.single.payload.token, 'cold');
      expect(service.takePendingWorkoutActions(), isEmpty);
      service.handleResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'calendar-event',
        ),
      );
      expect(service.takePendingWorkoutActions(), isEmpty);
    },
  );

  testWidgets(
    'shortcut control requests permission only after explicit user action',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutShortcutsCard(
              store: store,
              notifications: notifications,
            ),
          ),
        ),
      );
      expect(notifications.permissions, 0);
      expect(
        store.preferences.getBool(
          NotificationService.workoutPreferenceKey(null),
        ),
        isNull,
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(notifications.permissions, 1);
      expect(
        store.preferences.getBool(
          NotificationService.workoutPreferenceKey(null),
        ),
        isTrue,
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(notifications.permissions, 1);
      expect(
        store.preferences.getBool(
          NotificationService.workoutPreferenceKey(null),
        ),
        isFalse,
      );
    },
  );
}
