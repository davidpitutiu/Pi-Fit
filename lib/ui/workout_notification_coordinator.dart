import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/training_analytics.dart';
import '../services/firebase_gateway.dart';
import '../services/notification_service.dart';
import '../services/workout_clock.dart';
import '../state/app_store.dart';

class _NextSet {
  const _NextSet(this.exerciseIndex, this.setIndex, this.exerciseId, this.set);
  final int exerciseIndex, setIndex;
  final String exerciseId;
  final WorkoutSet set;
}

_NextSet? _nextSet(WorkoutSession session) {
  for (
    var exerciseIndex = 0;
    exerciseIndex < session.exercises.length;
    exerciseIndex++
  ) {
    final exercise = session.exercises[exerciseIndex];
    for (var setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
      final set = exercise.sets[setIndex];
      if (set.completed) continue;
      // Never leap over an invalid unchecked set to mark a later set instead.
      return isValidCompletedSet(set.copyWith(completed: true))
          ? _NextSet(exerciseIndex, setIndex, exercise.exerciseId, set)
          : null;
    }
  }
  return null;
}

/// Foreground-only action coordinator. Authentication, session identity, the
/// next set snapshot, and replay tokens are checked before a single mutation.
class WorkoutNotificationController {
  WorkoutNotificationController({
    required this.store,
    NotificationService? notifications,
    WorkoutClock? clock,
    FirebaseGateway? gateway,
    this.onOpenWorkout,
  }) : notifications = notifications ?? NotificationService.instance,
       clock = clock ?? WorkoutClock.instance,
       gateway = gateway ?? FirebaseGateway.instance;
  final AppStore store;
  final NotificationService notifications;
  final WorkoutClock clock;
  final FirebaseGateway gateway;
  final VoidCallback? onOpenWorkout;
  StreamSubscription<WorkoutNotificationAction>? _actionsSubscription;
  StreamSubscription<dynamic>? _authSubscription;
  final List<WorkoutNotificationAction> _waitingActions = [];
  final Set<String> _processed = {};
  Future<void> _publication = Future.value(), _action = Future.value();
  bool _disposed = false, _syncing = false, _started = false;
  bool _authStreamHealthy = true;
  int _generation = 0, _token = 0, _preferenceRevision = 0;
  String? _signature;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _preferenceRevision = notifications.workoutPreferencesRevision;
    store.addListener(_changed);
    clock.addListener(_changed);
    notifications.addListener(_notificationChanged);
    _actionsSubscription = notifications.workoutActions.listen((event) {
      _waitingActions.add(event);
      _changed();
    });
    _authSubscription = gateway.authStateChanges.listen(
      (_) {
        _authStreamHealthy = true;
        _changed();
      },
      onError: (Object _) {
        _authStreamHealthy = false;
        _changed();
      },
    );
    final wasSupported = notifications.supported;
    _changed();
    await notifications.initialize();
    if (_disposed) return;
    _waitingActions.addAll(notifications.takePendingWorkoutActions());
    _sync(force: !wasSupported);
  }

  void _notificationChanged() {
    final changed =
        _preferenceRevision != notifications.workoutPreferencesRevision;
    _preferenceRevision = notifications.workoutPreferencesRevision;
    _sync(force: changed);
  }

  void _changed() => _sync();
  void refresh() => _sync(force: true);
  bool get _scopeReady =>
      _authStreamHealthy && gateway.currentUser?.uid == store.accountId;
  bool get _enabled =>
      store.preferences.getBool(
        NotificationService.workoutPreferenceKey(store.accountId),
      ) ??
      false;

  void _sync({bool force = false}) {
    if (_disposed || _syncing) return;
    _syncing = true;
    try {
      final session = store.activeSession;
      if (_scopeReady && session != null) {
        clock.bind(
          sessionId: session.id,
          startedAt: session.startedAt,
          accountId: store.accountId,
          preferences: store.preferences,
        );
      } else {
        clock.unbind();
      }
      // A cold launch can arrive before AuthScopeGate loads this user's data.
      // Keep its action until the authenticated local scope is coherent.
      if (_scopeReady && _waitingActions.isNotEmpty) {
        final pending = List<WorkoutNotificationAction>.from(_waitingActions);
        _waitingActions.clear();
        for (final event in pending) {
          _action = _action.then((_) => _perform(event)).catchError((Object _) {
            notifications.reportWorkoutError(
              'The shortcut could not update your workout. Open Pi Fit and try again.',
            );
          });
        }
      }
      if (!_scopeReady ||
          session == null ||
          !_enabled ||
          !notifications.supported) {
        _publish(null, force: force);
        return;
      }
      final next = _nextSet(session);
      final rest = clock.remaining > 0 ? clock.restEndsAt : null;
      final payload = WorkoutNotificationPayload(
        accountId: store.accountId,
        sessionId: session.id,
        startedAt: session.startedAt,
        token: '${DateTime.now().microsecondsSinceEpoch}-${_token++}',
        exerciseIndex: next?.exerciseIndex,
        setIndex: next?.setIndex,
        exerciseId: next?.exerciseId,
        reps: next?.set.reps,
        weight: next?.set.weight,
        restEndsAt: rest,
      );
      _publish(
        payload,
        routineName: session.routineName,
        nextName: next == null
            ? null
            : store.exerciseById(next.exerciseId).name,
        force: force,
      );
    } finally {
      _syncing = false;
    }
  }

  void _publish(
    WorkoutNotificationPayload? payload, {
    String? routineName,
    String? nextName,
    bool force = false,
  }) {
    final content = payload == null
        ? 'cancel'
        : jsonEncode({
            ...jsonDecode(payload.encode()) as Map,
            'token': '',
            'routineName': routineName,
            'nextName': nextName,
          });
    if (!force && content == _signature) return;
    _signature = content;
    final generation = ++_generation;
    _publication = _publication.then((_) async {
      if (_disposed || generation != _generation) return;
      try {
        if (payload == null) {
          await notifications.cancelWorkout();
        } else {
          await notifications.showWorkout(
            payload: payload,
            routineName: routineName!,
            nextExerciseName: nextName,
          );
          // Serialize cleanup before the next account's queued publication.
          if (_disposed || generation != _generation) {
            await notifications.cancelWorkout();
          }
        }
      } catch (_) {
        notifications.reportWorkoutError(
          'Workout shortcuts could not be updated. Your workout remains in the app.',
        );
      }
    });
  }

  bool _matchesSession(WorkoutNotificationPayload payload) {
    final session = store.activeSession;
    return !_disposed &&
        _scopeReady &&
        payload.accountId == store.accountId &&
        session != null &&
        session.id == payload.sessionId &&
        session.startedAt == payload.startedAt;
  }

  String _replayKey(WorkoutNotificationPayload payload) =>
      '${NotificationService.workoutPreferenceKey(payload.accountId)}.actions.${payload.sessionId}';
  Future<void> _perform(WorkoutNotificationAction event) async {
    final payload = event.payload;
    if (!_matchesSession(payload)) return;
    if (event.actionId.isEmpty) {
      onOpenWorkout?.call();
      return;
    }
    if (!_enabled) return;
    final actionKey =
        '${payload.accountId ?? 'guest'}/${payload.sessionId}/${payload.token}/${event.actionId}';
    final preferenceKey = _replayKey(payload);
    final saved =
        store.preferences.getStringList(preferenceKey) ?? const <String>[];
    if (_processed.contains(actionKey) || saved.contains(actionKey)) return;
    if (event.actionId == NotificationService.checkSetAction) {
      final next = _nextSet(store.activeSession!);
      if (next == null ||
          next.exerciseIndex != payload.exerciseIndex ||
          next.setIndex != payload.setIndex ||
          next.exerciseId != payload.exerciseId ||
          next.set.reps != payload.reps ||
          next.set.weight != payload.weight) {
        return;
      }
      _processed.add(actionKey);
      try {
        await store.updateSet(
          next.exerciseIndex,
          next.setIndex,
          completed: true,
        );
      } catch (_) {
        _processed.remove(actionKey);
        rethrow;
      }
      if (_matchesSession(payload)) clock.startRest();
    } else if (event.actionId == NotificationService.skipRestAction) {
      if (payload.restEndsAt == null ||
          clock.restEndsAt != payload.restEndsAt ||
          clock.remaining <= 0) {
        return;
      }
      _processed.add(actionKey);
      clock.skipRest();
    } else {
      return;
    }
    final retained = [...saved, actionKey];
    final success = await store.preferences.setStringList(
      preferenceKey,
      retained.length > 64 ? retained.sublist(retained.length - 64) : retained,
    );
    if (!success) {
      notifications.reportWorkoutError(
        'Your shortcut was applied, but its replay protection could not be saved.',
      );
    }
    if (_matchesSession(payload)) onOpenWorkout?.call();
  }

  @visibleForTesting
  Future<void> flush() async {
    await _action;
    await _publication;
  }

  void dispose() {
    _disposed = true;
    _generation++;
    store.removeListener(_changed);
    clock.removeListener(_changed);
    notifications.removeListener(_notificationChanged);
    _actionsSubscription?.cancel();
    _authSubscription?.cancel();
  }
}

class WorkoutNotificationCoordinator extends StatefulWidget {
  const WorkoutNotificationCoordinator({
    super.key,
    required this.store,
    required this.child,
    this.onOpenWorkout,
    this.notifications,
    this.clock,
    this.gateway,
  });
  final AppStore store;
  final Widget child;
  final VoidCallback? onOpenWorkout;
  final NotificationService? notifications;
  final WorkoutClock? clock;
  final FirebaseGateway? gateway;
  @override
  State<WorkoutNotificationCoordinator> createState() =>
      _WorkoutNotificationCoordinatorState();
}

class _WorkoutNotificationCoordinatorState
    extends State<WorkoutNotificationCoordinator>
    with WidgetsBindingObserver {
  late WorkoutNotificationController _controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _controller = WorkoutNotificationController(
      store: widget.store,
      notifications: widget.notifications,
      clock: widget.clock,
      gateway: widget.gateway,
      onOpenWorkout: widget.onOpenWorkout,
    );
    unawaited(_controller.start());
  }

  @override
  void didUpdateWidget(covariant WorkoutNotificationCoordinator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store ||
        oldWidget.notifications != widget.notifications ||
        oldWidget.clock != widget.clock ||
        oldWidget.gateway != widget.gateway) {
      _controller.dispose();
      _start();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
