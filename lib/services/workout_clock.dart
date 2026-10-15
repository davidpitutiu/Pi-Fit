import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The screen and notification actions share one deadline, including on resume.
class WorkoutClock extends ChangeNotifier {
  WorkoutClock._({DateTime Function()? now, bool ticking = true})
    : _now = now ?? DateTime.now,
      _ticking = ticking;
  static final instance = WorkoutClock._();
  @visibleForTesting
  factory WorkoutClock.forTesting({required DateTime Function() now}) =>
      WorkoutClock._(now: now, ticking: false);
  final DateTime Function() _now;
  final bool _ticking;
  Timer? _timer;
  String? _sessionId, _accountId;
  DateTime? _startedAt, _restEndsAt;
  SharedPreferences? _preferences;
  int restSeconds = 90;
  String? get sessionId => _sessionId;
  DateTime? get restEndsAt => _restEndsAt;
  int get remaining => _restEndsAt == null
      ? 0
      : math.max(
          0,
          (_restEndsAt!.difference(_now()).inMilliseconds / 1000).ceil(),
        );
  Duration get elapsed {
    final value = _startedAt == null
        ? Duration.zero
        : _now().difference(_startedAt!);
    return value.isNegative ? Duration.zero : value;
  }

  String get _key => 'pifit.workout.clock.${_accountId ?? 'guest'}.$_sessionId';

  void bind({
    required String sessionId,
    required DateTime startedAt,
    required String? accountId,
    required SharedPreferences preferences,
  }) {
    if (_sessionId == sessionId && _accountId == accountId) return;
    _timer?.cancel();
    _sessionId = sessionId;
    _accountId = accountId;
    _startedAt = startedAt;
    _preferences = preferences;
    restSeconds = preferences.getInt('$_key.duration') ?? 90;
    if (restSeconds < 15 || restSeconds > 600) restSeconds = 90;
    final saved = preferences.getInt('$_key.deadline');
    _restEndsAt = saved == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(saved);
    if (_ticking) {
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => notifyListeners(),
      );
    }
    notifyListeners();
  }

  void unbind() {
    if (_sessionId == null) return;
    _timer?.cancel();
    _timer = null;
    _sessionId = null;
    _accountId = null;
    _startedAt = null;
    _restEndsAt = null;
    _preferences = null;
    notifyListeners();
  }

  void selectRestSeconds(int seconds) {
    if (seconds < 15 || seconds > 600) {
      throw ArgumentError('Choose a rest between 15 and 600 seconds.');
    }
    restSeconds = seconds;
    _persist('$_key.duration', seconds);
    notifyListeners();
  }

  void startRest() {
    if (_sessionId == null) return;
    _restEndsAt = _now().add(Duration(seconds: restSeconds));
    _persist('$_key.deadline', _restEndsAt!.millisecondsSinceEpoch);
    notifyListeners();
  }

  void skipRest() {
    _restEndsAt = null;
    final preferences = _preferences;
    if (preferences != null) {
      unawaited(preferences.remove('$_key.deadline').catchError((_) => false));
    }
    notifyListeners();
  }

  void extendRest(int seconds) {
    if (_sessionId == null || seconds < 1 || seconds > 600) return;
    final base = _restEndsAt != null && _restEndsAt!.isAfter(_now())
        ? _restEndsAt!
        : _now();
    _restEndsAt = base.add(Duration(seconds: seconds));
    _persist('$_key.deadline', _restEndsAt!.millisecondsSinceEpoch);
    notifyListeners();
  }

  void _persist(String key, int value) {
    final preferences = _preferences;
    if (preferences != null) {
      unawaited(preferences.setInt(key, value).catchError((_) => false));
    }
  }

  @visibleForTesting
  void tick() => notifyListeners();
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
