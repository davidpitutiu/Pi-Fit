import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:pi_fit/services/live_heart_rate_service.dart';

class FakeLiveBridge implements LiveHeartRateBridge {
  final controller = StreamController<Map<String, dynamic>>.broadcast(
    sync: true,
  );
  int initializations = 0;
  int starts = 0;
  int stops = 0;
  Object? stopError;
  @override
  Stream<Map<String, dynamic>> get events => controller.stream;
  @override
  Future<Map<String, dynamic>> initialize() async {
    initializations++;
    return {
      'kind': 'status',
      'state': 'ready',
      'paired': true,
      'installed': true,
      'reachable': true,
    };
  }

  @override
  Future<void> startWatchWorkout() async {
    starts++;
  }

  @override
  Future<void> stopWatchWorkout() async {
    stops++;
    if (stopError != null) throw stopError!;
  }

  void sample(DateTime at, {double bpm = 128, String session = 'session-1'}) =>
      controller.add({
        'kind': 'sample',
        'state': 'running',
        'running': true,
        'paired': true,
        'installed': true,
        'reachable': true,
        'bpm': bpm,
        'timestamp': at.millisecondsSinceEpoch / 1000,
        'source': 'Apple Watch · Pi Fit workout',
        'sessionId': session,
      });
}

void main() {
  test(
    'unsupported platforms do not open native channels or pretend to stream',
    () async {
      final bridge = FakeLiveBridge();
      final service = LiveHeartRateService(bridge: bridge, supported: false);
      addTearDown(service.dispose);
      addTearDown(bridge.controller.close);
      await service.initialize();
      await service.startWatchWorkout();
      expect(service.status, LiveHeartRateStatus.unsupported);
      expect(service.isFresh, isFalse);
      expect(bridge.initializations, 0);
      expect(bridge.starts, 0);
    },
  );

  test(
    'launching Watch never counts as a live sample; real sensor events do',
    () async {
      final bridge = FakeLiveBridge();
      final now = DateTime(2026, 10, 15, 12);
      final service = LiveHeartRateService(
        bridge: bridge,
        supported: true,
        now: () => now,
      );
      addTearDown(service.dispose);
      addTearDown(bridge.controller.close);
      await service.initialize();
      expect(service.status, LiveHeartRateStatus.ready);
      await service.startWatchWorkout();
      expect(service.status, LiveHeartRateStatus.starting);
      expect(service.sample, isNull);
      expect(service.isFresh, isFalse);
      bridge.sample(now);
      expect(service.status, LiveHeartRateStatus.streaming);
      expect(service.sample!.bpm, 128);
      expect(service.sample!.measuredAt, now);
      expect(service.isFresh, isTrue);
      bridge.controller.add({
        'kind': 'status',
        'state': 'running',
        'sessionId': 'session-1',
        'reachable': false,
      });
      expect(service.status, LiveHeartRateStatus.disconnected);
      expect(service.isFresh, isFalse);
    },
  );

  testWidgets(
    'a formerly fresh measurement becomes stale after 15 seconds without new sensor data',
    (tester) async {
      final bridge = FakeLiveBridge();
      var now = DateTime(2026, 10, 15, 12);
      final service = LiveHeartRateService(
        bridge: bridge,
        supported: true,
        now: () => now,
      );
      await service.initialize();
      bridge.sample(now);
      now = now.add(const Duration(seconds: 16));
      await tester.pump(const Duration(seconds: 16));
      expect(service.status, LiveHeartRateStatus.stale);
      expect(service.isFresh, isFalse);
      service.dispose();
      await bridge.controller.close();
    },
  );

  test(
    'old, future and ended-session packets cannot become a fake live stream',
    () async {
      final bridge = FakeLiveBridge();
      final now = DateTime(2026, 10, 15, 12);
      final service = LiveHeartRateService(
        bridge: bridge,
        supported: true,
        now: () => now,
      );
      addTearDown(service.dispose);
      addTearDown(bridge.controller.close);
      await service.initialize();
      bridge.sample(now);
      bridge.sample(now.subtract(const Duration(seconds: 2)), bpm: 190);
      expect(service.sample!.bpm, 128);
      bridge.sample(now.add(const Duration(minutes: 5)), bpm: 200);
      expect(service.sample!.bpm, 128);
      bridge.controller.add({
        'kind': 'status',
        'state': 'stopped',
        'sessionId': 'session-1',
      });
      bridge.sample(now, bpm: 160);
      expect(service.status, LiveHeartRateStatus.stopped);
      expect(service.sample, isNull);
      expect(service.isFresh, isFalse);
    },
  );
  test(
    'account reset clears immediately and rejects old or unsolicited watch sessions even if stopping fails',
    () async {
      final bridge = FakeLiveBridge()
        ..stopError = PlatformException(
          code: 'WATCH_UNREACHABLE',
          message: 'Stop the earlier session on Apple Watch.',
        );
      final now = DateTime(2026, 10, 15, 12);
      final service = LiveHeartRateService(
        bridge: bridge,
        supported: true,
        now: () => now,
      );
      addTearDown(service.dispose);
      addTearDown(bridge.controller.close);
      await Future.wait([service.initialize(), service.initialize()]);
      expect(bridge.initializations, 1);
      bridge.sample(now, session: 'account-a');
      expect(service.isFresh, isTrue);
      final reset = service.resetForAccountChange();
      expect(service.sample, isNull);
      expect(service.workoutRunning, isFalse);
      expect(service.isFresh, isFalse);
      await reset;
      expect(service.message, contains('Stop the earlier session'));
      bridge.sample(now, session: 'account-a');
      bridge.controller.add({
        'kind': 'status',
        'state': 'running',
        'sessionId': 'account-a',
      });
      expect(service.sample, isNull);
      expect(service.workoutRunning, isFalse);
      bridge.sample(now, session: 'unsolicited-between-accounts');
      expect(service.sample, isNull);
      await service.startWatchWorkout();
      bridge.sample(now, session: 'account-a');
      expect(service.sample, isNull);
      bridge.sample(now, session: 'account-b');
      expect(service.sample!.sessionId, 'account-b');
      expect(service.isFresh, isTrue);
      expect(bridge.initializations, 1);
    },
  );
  test('explicit ready status removes an earlier live sensor state', () async {
    final bridge = FakeLiveBridge();
    final now = DateTime(2026, 10, 15, 12);
    final service = LiveHeartRateService(
      bridge: bridge,
      supported: true,
      now: () => now,
    );
    addTearDown(service.dispose);
    addTearDown(bridge.controller.close);
    await service.initialize();
    bridge.sample(now);
    expect(service.isFresh, isTrue);
    bridge.controller.add({
      'kind': 'status',
      'state': 'ready',
      'running': false,
    });
    expect(service.workoutRunning, isFalse);
    expect(service.sample, isNull);
    expect(service.isFresh, isFalse);
  });

  test(
    'starting a different watch session retires old samples until new sensor data arrives',
    () async {
      final bridge = FakeLiveBridge();
      final now = DateTime(2026, 10, 15, 12);
      final service = LiveHeartRateService(
        bridge: bridge,
        supported: true,
        now: () => now,
      );
      addTearDown(service.dispose);
      addTearDown(bridge.controller.close);
      await service.initialize();
      bridge.sample(now, session: 'old');
      bridge.controller.add({
        'kind': 'status',
        'state': 'starting',
        'running': false,
        'sessionId': 'new',
      });
      expect(service.sample, isNull);
      expect(service.workoutRunning, isFalse);
      expect(service.status, LiveHeartRateStatus.starting);
      bridge.sample(now, session: 'old');
      expect(service.sample, isNull);
      bridge.sample(now, session: 'new');
      expect(service.sample!.sessionId, 'new');
      expect(service.isFresh, isTrue);
    },
  );
}
