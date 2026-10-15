import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Live samples are received from Pi Fit's paired watchOS workout session, not
/// from HealthKit's historical queries. Nothing here is persisted or uploaded.
enum LiveHeartRateStatus {
  unsupported,
  checking,
  notPaired,
  notInstalled,
  ready,
  starting,
  streaming,
  stale,
  disconnected,
  stopped,
  error,
}

class LiveHeartRateSample {
  const LiveHeartRateSample({
    required this.bpm,
    required this.measuredAt,
    required this.source,
    required this.sessionId,
  });
  final double bpm;
  final DateTime measuredAt;
  final String source;
  final String sessionId;
  Duration ageAt(DateTime now) => now.difference(measuredAt);
}

abstract interface class LiveHeartRateBridge {
  Stream<Map<String, dynamic>> get events;
  Future<Map<String, dynamic>> initialize();
  Future<void> startWatchWorkout();
  Future<void> stopWatchWorkout();
}

class NativeLiveHeartRateBridge implements LiveHeartRateBridge {
  static const _methods = MethodChannel(
    'com.pifit.app/live-heart-rate/methods',
  );
  static const _events = EventChannel('com.pifit.app/live-heart-rate/events');
  @override
  Stream<Map<String, dynamic>> get events => _events
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .map((event) => Map<String, dynamic>.from(event as Map));
  @override
  Future<Map<String, dynamic>> initialize() async => Map<String, dynamic>.from(
    await _methods.invokeMethod<Map>('initialize') ?? const {},
  );
  @override
  Future<void> startWatchWorkout() => _methods.invokeMethod<void>('start');
  @override
  Future<void> stopWatchWorkout() => _methods.invokeMethod<void>('stop');
}

class LiveHeartRateService extends ChangeNotifier {
  LiveHeartRateService({
    LiveHeartRateBridge? bridge,
    bool? supported,
    DateTime Function()? now,
    this.freshness = const Duration(seconds: 15),
  }) : _bridge = bridge ?? NativeLiveHeartRateBridge(),
       supported =
           supported ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS),
       _now = now ?? DateTime.now {
    status = this.supported
        ? LiveHeartRateStatus.checking
        : LiveHeartRateStatus.unsupported;
  }
  final LiveHeartRateBridge _bridge;
  final DateTime Function() _now;
  final bool supported;
  final Duration freshness;
  late LiveHeartRateStatus status;
  LiveHeartRateSample? sample;
  String? message;
  bool paired = false;
  bool watchInstalled = false;
  bool reachable = false;
  bool workoutRunning = false;
  bool _disposed = false;
  bool _initialized = false;
  bool _acceptingSession = true;
  bool _requiresNewSession = false;
  int _operation = 0;
  String? _sessionId;
  final _endedSessions = <String>{};
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _freshnessTimer;

  bool get isAvailable => supported && paired && watchInstalled;
  bool get isFresh {
    final value = sample;
    if (value == null || !workoutRunning || !reachable) return false;
    final age = value.ageAt(_now());
    return age >= const Duration(seconds: -5) && age <= freshness;
  }

  Future<void> initialize() async {
    if (_disposed || _initialized || !supported) return;
    _initialized = true;
    _subscription = _bridge.events.listen(
      _handleEvent,
      onError: (Object _) {
        if (_disposed) return;
        status = LiveHeartRateStatus.error;
        message = 'The Apple Watch connection could not be opened.';
        notifyListeners();
      },
    );
    try {
      _handleEvent(await _bridge.initialize());
      if (_disposed) return;
      _freshnessTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _updateFreshness(),
      );
    } catch (_) {
      if (_disposed) return;
      status = LiveHeartRateStatus.error;
      message =
          'Apple Watch live heart rate requires the iPhone app with its watch companion installed.';
      notifyListeners();
    }
  }

  Future<void> startWatchWorkout() async {
    if (_disposed || !supported) return;
    final operation = ++_operation;
    await initialize();
    if (_disposed || operation != _operation) return;
    if (!isAvailable) {
      message = !paired
          ? 'Pair an Apple Watch with this iPhone first.'
          : 'Install Pi Fit on your paired Apple Watch first.';
      notifyListeners();
      return;
    }
    _acceptingSession = true;
    sample = null;
    status = LiveHeartRateStatus.starting;
    message = _requiresNewSession
        ? 'Start a new session on Apple Watch. If the previous session is still running, stop it on the watch first.'
        : 'Opening Pi Fit on Apple Watch. Allow workout and heart-rate access on the watch.';
    notifyListeners();
    try {
      await _bridge.startWatchWorkout();
    } catch (error) {
      if (_disposed || operation != _operation) return;
      status = LiveHeartRateStatus.error;
      message = error is PlatformException && error.message != null
          ? error.message
          : 'The watch workout could not be started. Open Pi Fit on Apple Watch and tap Start.';
      notifyListeners();
    }
  }

  Future<void> stopWatchWorkout() => resetSession();

  /// Clears data synchronously before the first await. Account/workout scope
  /// changes must never wait for a reachable watch before hiding old readings.
  Future<void> resetForAccountChange() => resetSession();

  Future<void> resetSession() async {
    if (_disposed) return;
    final operation = ++_operation;
    final previousSession = _sessionId ?? sample?.sessionId;
    final shouldStop =
        supported &&
        _initialized &&
        (workoutRunning ||
            sample != null ||
            status == LiveHeartRateStatus.starting);
    if (previousSession != null) _endedSessions.add(previousSession);
    if (sample != null) _endedSessions.add(sample!.sessionId);
    _acceptingSession = false;
    _requiresNewSession = true;
    _sessionId = null;
    sample = null;
    workoutRunning = false;
    message = shouldStop
        ? 'Live readings cleared. Sending the stop command to Apple Watch…'
        : null;
    status = supported
        ? LiveHeartRateStatus.ready
        : LiveHeartRateStatus.unsupported;
    notifyListeners();
    if (!shouldStop) return;
    try {
      await _bridge.stopWatchWorkout();
      if (_disposed || operation != _operation) return;
      status = LiveHeartRateStatus.stopped;
      message = 'The stop command was delivered to Apple Watch.';
      notifyListeners();
    } catch (error) {
      if (_disposed || operation != _operation) return;
      message = error is PlatformException && error.message != null
          ? error.message
          : 'The watch is unreachable. Stop the session in Pi Fit on Apple Watch.';
      status = LiveHeartRateStatus.disconnected;
      reachable = false;
      notifyListeners();
    }
  }

  void _handleEvent(Map<String, dynamic> event) {
    if (_disposed) return;
    if (event['paired'] is bool) paired = event['paired'] as bool;
    if (event['installed'] is bool) watchInstalled = event['installed'] as bool;
    if (event['reachable'] is bool) reachable = event['reachable'] as bool;
    final eventState = event['state'] as String?;
    final sessionId = event['sessionId'] as String?;
    if (!_acceptingSession ||
        sessionId != null && _endedSessions.contains(sessionId)) {
      if (!_acceptingSession && sessionId != null) {
        _endedSessions.add(sessionId);
      }
      // Availability flags may change, but an earlier scope's sample, status
      // and message must not reactivate or identify its workout in this scope.
      notifyListeners();
      return;
    }
    if (eventState == 'stopped') {
      if (sessionId != null) _endedSessions.add(sessionId);
      workoutRunning = false;
      status = LiveHeartRateStatus.stopped;
      sample = null;
    } else if (eventState == 'running') {
      if (sessionId != null && !_endedSessions.contains(sessionId)) {
        _sessionId = sessionId;
        workoutRunning = true;
        _requiresNewSession = false;
        status = LiveHeartRateStatus.starting;
      }
    } else if (eventState == 'error') {
      workoutRunning = false;
      status = LiveHeartRateStatus.error;
    } else if (eventState == 'starting') {
      if (_sessionId != null && _sessionId != sessionId) {
        _endedSessions.add(_sessionId!);
      }
      _sessionId = sessionId;
      sample = null;
      workoutRunning = false;
      status = LiveHeartRateStatus.starting;
    } else if (eventState == 'checking') {
      if (event['running'] == false) {
        sample = null;
        workoutRunning = false;
      }
      status = LiveHeartRateStatus.checking;
    } else if (eventState == 'ready') {
      sample = null;
      workoutRunning = false;
      status = LiveHeartRateStatus.ready;
    } else if (eventState == 'disconnected' && event['running'] == false) {
      sample = null;
      workoutRunning = false;
      status = LiveHeartRateStatus.disconnected;
    } else if (eventState == 'paused') {
      workoutRunning = false;
      status = LiveHeartRateStatus.stale;
    }
    final nativeMessage = event['message'];
    if (nativeMessage is String && nativeMessage.isNotEmpty) {
      message = nativeMessage;
    }
    if (event['kind'] == 'sample') {
      final bpm = event['bpm'];
      final timestamp = event['timestamp'];
      if (bpm is num &&
          timestamp is num &&
          bpm.isFinite &&
          timestamp.isFinite &&
          timestamp > 0 &&
          timestamp <=
              _now().add(const Duration(seconds: 5)).millisecondsSinceEpoch /
                  1000 &&
          bpm > 0 &&
          bpm <= 350 &&
          sessionId != null &&
          sessionId.isNotEmpty &&
          !_endedSessions.contains(sessionId)) {
        final measuredAt = DateTime.fromMillisecondsSinceEpoch(
          (timestamp * 1000).round(),
        ).toLocal();
        if (!measuredAt.isAfter(_now().add(const Duration(seconds: 5))) &&
            (sample == null || !measuredAt.isBefore(sample!.measuredAt)) &&
            (_sessionId == null || _sessionId == sessionId)) {
          _sessionId = sessionId;
          workoutRunning = event['running'] == true;
          sample = LiveHeartRateSample(
            bpm: bpm.toDouble(),
            measuredAt: measuredAt,
            source: event['source'] as String? ?? 'Apple Watch',
            sessionId: sessionId,
          );
        }
      }
    }
    _updateFreshness(notify: false);
    notifyListeners();
  }

  void _updateFreshness({bool notify = true}) {
    if (_disposed || !_acceptingSession) return;
    final previous = status;
    if (status == LiveHeartRateStatus.error) {
      // Preserve a native failure until a later explicit availability event.
    } else if (workoutRunning) {
      status = !reachable
          ? LiveHeartRateStatus.disconnected
          : sample == null
          ? LiveHeartRateStatus.starting
          : isFresh
          ? LiveHeartRateStatus.streaming
          : LiveHeartRateStatus.stale;
    } else if (!paired && status != LiveHeartRateStatus.checking) {
      status = LiveHeartRateStatus.notPaired;
    } else if (!watchInstalled && status != LiveHeartRateStatus.checking) {
      status = LiveHeartRateStatus.notInstalled;
    } else if (status == LiveHeartRateStatus.checking &&
        paired &&
        watchInstalled) {
      status = LiveHeartRateStatus.ready;
    } else if (status != LiveHeartRateStatus.starting &&
        status != LiveHeartRateStatus.error &&
        status != LiveHeartRateStatus.stopped &&
        status != LiveHeartRateStatus.stale &&
        status != LiveHeartRateStatus.disconnected) {
      status = LiveHeartRateStatus.ready;
    }
    if (notify && previous != status) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _freshnessTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
