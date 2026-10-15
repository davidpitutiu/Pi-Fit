import 'package:flutter_test/flutter_test.dart';
import 'package:pi_fit/services/workout_clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  late SharedPreferences preferences;
  late WorkoutClock clock;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    now = DateTime(2026, 10, 15, 10);
    clock = WorkoutClock.forTesting(now: () => now);
  });
  tearDown(() => clock.dispose());

  void bind({String account = 'athlete-a', String session = 'session-1'}) =>
      clock.bind(
        sessionId: session,
        startedAt: DateTime(2026, 10, 15, 9, 55),
        accountId: account,
        preferences: preferences,
      );

  test(
    'Rest uses a persisted deadline rather than decrementing on rebuilds',
    () {
      bind();
      expect(clock.elapsed, const Duration(minutes: 5));
      clock.startRest();
      final deadline = clock.restEndsAt;
      expect(clock.remaining, 90);
      for (var index = 0; index < 20; index++) {
        clock.tick();
      }
      clock.bind(
        sessionId: 'session-1',
        startedAt: DateTime(2026, 10, 15, 9, 55),
        accountId: 'athlete-a',
        preferences: preferences,
      );
      expect(clock.remaining, 90);
      expect(clock.restEndsAt, deadline);
      now = now.add(const Duration(seconds: 22, milliseconds: 250));
      clock.tick();
      expect(clock.remaining, 68);
      expect(
        clock.elapsed,
        const Duration(minutes: 5, seconds: 22, milliseconds: 250),
      );
      expect(
        preferences.getInt('pifit.workout.clock.athlete-a.session-1.deadline'),
        deadline!.millisecondsSinceEpoch,
      );
    },
  );

  test(
    'A new clock resumes saved rest duration and remaining background time',
    () {
      bind();
      clock.selectRestSeconds(150);
      clock.startRest();
      now = now.add(const Duration(seconds: 70));
      final resumed = WorkoutClock.forTesting(now: () => now);
      addTearDown(resumed.dispose);
      resumed.bind(
        sessionId: 'session-1',
        startedAt: DateTime(2026, 10, 15, 9, 55),
        accountId: 'athlete-a',
        preferences: preferences,
      );
      expect(resumed.restSeconds, 150);
      expect(resumed.remaining, 80);
      expect(resumed.elapsed, const Duration(minutes: 6, seconds: 10));
      resumed.unbind();
      expect(resumed.sessionId, isNull);
      expect(resumed.remaining, 0);
      now = now.add(const Duration(seconds: 15));
      resumed.bind(
        sessionId: 'session-1',
        startedAt: DateTime(2026, 10, 15, 9, 55),
        accountId: 'athlete-a',
        preferences: preferences,
      );
      expect(resumed.remaining, 65);
    },
  );

  test('Account and session scopes keep their own timers and settings', () {
    bind();
    clock.selectRestSeconds(120);
    clock.startRest();
    now = now.add(const Duration(seconds: 15));
    bind(account: 'athlete-b');
    expect(clock.restSeconds, 90);
    expect(clock.remaining, 0);
    clock.selectRestSeconds(60);
    clock.startRest();
    bind(session: 'session-2');
    expect(clock.remaining, 0);
    expect(clock.restSeconds, 90);
    bind();
    expect(clock.restSeconds, 120);
    expect(clock.remaining, 105);
    bind(account: 'athlete-b');
    expect(clock.restSeconds, 60);
    expect(clock.remaining, 60);
  });

  test(
    'Extend adds to a running deadline and starts from now after expiry',
    () {
      bind();
      clock.startRest();
      now = now.add(const Duration(seconds: 20));
      clock.extendRest(30);
      expect(clock.remaining, 100);
      expect(clock.restEndsAt, DateTime(2026, 10, 15, 10, 2));
      clock.selectRestSeconds(180);
      expect(
        clock.remaining,
        100,
        reason: 'Changing the next duration does not reset this rest.',
      );
      now = DateTime(2026, 10, 15, 10, 3);
      expect(clock.remaining, 0);
      clock.extendRest(30);
      expect(clock.remaining, 30);
      expect(clock.restEndsAt, DateTime(2026, 10, 15, 10, 3, 30));
      clock.extendRest(-10);
      clock.extendRest(601);
      expect(clock.remaining, 30);
    },
  );

  test(
    'Skip persists, subsecond rest rounds up, and elapsed never goes negative',
    () async {
      bind();
      clock.startRest();
      now = clock.restEndsAt!.subtract(const Duration(milliseconds: 1));
      expect(clock.remaining, 1);
      now = now.add(const Duration(milliseconds: 1));
      expect(clock.remaining, 0);
      clock.startRest();
      clock.skipRest();
      await Future<void>.delayed(Duration.zero);
      expect(
        preferences.containsKey(
          'pifit.workout.clock.athlete-a.session-1.deadline',
        ),
        isFalse,
      );
      clock.unbind();
      bind();
      expect(clock.remaining, 0);
      now = DateTime(2026, 10, 15, 9);
      expect(clock.elapsed, Duration.zero);
      expect(() => clock.selectRestSeconds(14), throwsArgumentError);
      expect(() => clock.selectRestSeconds(601), throwsArgumentError);
    },
  );
}
