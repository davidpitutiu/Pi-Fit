import 'package:flutter_test/flutter_test.dart';
import 'package:pi_fit/domain/models.dart';
import 'package:pi_fit/domain/training_analytics.dart';
import 'package:pi_fit/domain/user_profile.dart';

const barbell = Exercise(
  id: 'squat',
  name: 'Genuflexiuni',
  muscle: 'Cvadricepși',
  equipment: 'Bară',
  description: '',
);
const bodyweight = Exercise(
  id: 'pushup',
  name: 'Flotări',
  muscle: 'Piept',
  equipment: 'Greutatea corpului',
  description: '',
);
const cardio = Exercise(
  id: 'cycle',
  name: 'Bicicletă',
  muscle: 'Cardio',
  equipment: 'Aparat',
  description: '',
  category: 'Cardio',
);

WorkoutSession workout(
  String id,
  DateTime date, {
  DateTime? finishedAt,
  List<WorkoutSet>? sets,
  String exerciseId = 'squat',
}) => WorkoutSession(
  id: id,
  routineName: 'Forță',
  startedAt: date,
  finishedAt: finishedAt ?? date.add(const Duration(minutes: 30)),
  exercises: [
    WorkoutExercise(
      exerciseId: exerciseId,
      sets: sets ?? const [WorkoutSet(reps: 10, weight: 80, completed: true)],
    ),
  ],
);

void main() {
  final now = DateTime(2026, 10, 28, 20);
  final profile = UserProfile(sessionsPerWeek: 3);
  TrainingAnalytics analyze(List<WorkoutSession> history) => analyzeTraining(
    history: history,
    exercises: [barbell, bodyweight, cardio],
    profile: profile,
    now: now,
  );

  test(
    'score is absent without completed data and zero for inactive history',
    () {
      expect(analyze([]).score, isNull);
      expect(analyze([workout('old', DateTime(2026, 9, 1))]).score, 0);
      expect(analyze([]).weeks.length, 4);
    },
  );

  test(
    'exact four-week adherence gives 100 without volume or body metrics points',
    () {
      final history = [
        for (final day in [1, 3, 5, 8, 10, 12, 15, 17, 19, 22, 24, 26])
          workout('day-$day', DateTime(2026, 10, day, 12)),
      ];
      final result = analyze(history);
      expect(result.score, 100);
      expect(result.activeDaysLast28, 12);
      expect(result.workoutCountLast28, 12);
      expect(result.completedSetsLast28, 12);
      expect(result.volumeLast28, 9600);
      expect(result.components[0].points, 70);
      expect(result.components[1].points, 30);
      expect(result.muscles.single.completedSets, 12);
      expect(result.muscles.single.volume, 9600);
      final otherMeasurements = analyzeTraining(
        history: history,
        exercises: [barbell],
        profile: profile.copyWith(age: 68, weightKg: 140),
        now: now,
      );
      expect(otherMeasurements.score, result.score);
    },
  );

  test(
    'formula distinguishes spread-out adherence from one concentrated week',
    () {
      final spread = analyze([
        for (final day in [1, 3, 5, 8, 10, 12])
          workout('$day', DateTime(2026, 10, day, 12)),
      ]);
      final concentrated = analyze([
        for (final day in [1, 2, 3, 4, 5, 6])
          workout('$day', DateTime(2026, 10, day, 12)),
      ]);
      expect(spread.score, 50);
      expect(concentrated.score, 42.5);
      expect(concentrated.components[1].value, 1);
    },
  );

  test('two sessions on one day never earn extra score points', () {
    final first = workout('first', DateTime(2026, 10, 10, 9));
    final second = workout('second', DateTime(2026, 10, 10, 18));
    final one = analyze([first]);
    final two = analyze([first, second]);
    expect(two.score, one.score);
    expect(two.activeDaysLast28, 1);
    expect(two.workoutCountLast28, 2);
    expect(two.completedSetsLast28, 2);
    expect(two.volumeLast28, 1600);
  });

  test(
    '28-calendar-day boundary includes midnight and excludes future and unfinished',
    () {
      final atStart = DateTime(2026, 10, 1);
      final history = [
        workout('boundary', atStart),
        workout('old', atStart.subtract(const Duration(seconds: 1))),
        workout('future', now.add(const Duration(seconds: 1))),
        workout(
          'future-end',
          now.subtract(const Duration(minutes: 5)),
          finishedAt: now.add(const Duration(seconds: 1)),
        ),
        WorkoutSession(
          id: 'unfinished',
          routineName: 'Test',
          startedAt: now,
          exercises: const [
            WorkoutExercise(
              exerciseId: 'squat',
              sets: [WorkoutSet(reps: 10, weight: 80, completed: true)],
            ),
          ],
        ),
        workout('exact-now', now, finishedAt: now),
      ];
      final result = analyze(history);
      expect(result.windowStart, atStart);
      expect(result.workoutCountLast28, 2);
      expect(result.activeDaysLast28, 2);
      expect(result.weeks.first.activeDays, 1);
      expect(result.weeks.last.activeDays, 1);
      expect(result.records.single.date.isAfter(now), isFalse);
    },
  );

  test('invalid or unchecked sets do not inflate statistics or records', () {
    final result = analyze([
      workout(
        'mixed',
        DateTime(2026, 10, 10),
        sets: [
          const WorkoutSet(reps: 8, weight: 50, completed: true),
          const WorkoutSet(reps: 12, weight: 300, completed: false),
          const WorkoutSet(reps: 0, weight: 999, completed: true),
          const WorkoutSet(reps: 8, weight: -5, completed: true),
          const WorkoutSet(reps: 8, weight: double.nan, completed: true),
          const WorkoutSet(reps: 100000, weight: 100000, completed: true),
        ],
      ),
    ]);
    expect(result.completedSetsLast28, 1);
    expect(result.volumeLast28, 400);
    expect(result.records.single.weight, 50);
    expect(
      result.records.single.estimatedOneRepMax,
      closeTo(50 * (1 + 8 / 30), 0.0001),
    );
  });

  test(
    'records are all-time Epley estimates, excluding bodyweight and cardio',
    () {
      final result = analyze([
        workout(
          'old-record',
          DateTime(2026, 9, 1),
          sets: const [WorkoutSet(reps: 5, weight: 100, completed: true)],
        ),
        workout(
          'recent',
          DateTime(2026, 10, 10),
          sets: const [WorkoutSet(reps: 10, weight: 80, completed: true)],
        ),
        workout('body', DateTime(2026, 10, 11), exerciseId: 'pushup'),
        workout('cardio', DateTime(2026, 10, 12), exerciseId: 'cycle'),
      ]);
      expect(result.records.length, 1);
      expect(result.records.single.weight, 100);
      expect(result.records.single.date.month, 9);
      expect(
        result.records.single.estimatedOneRepMax,
        closeTo(116.666667, 0.0001),
      );
      expect(result.completedSetsLast28, 3);
      expect(result.volumeLast28, 800);
      expect(
        result.muscles
            .map((muscle) => muscle.completedSets)
            .reduce((a, b) => a + b),
        3,
      );
    },
  );

  test(
    'high repetition sets show actual weight without inventing an estimate',
    () {
      final result = analyze([
        workout(
          'high',
          DateTime(2026, 10, 2),
          sets: const [WorkoutSet(reps: 20, weight: 40, completed: true)],
        ),
      ]);
      expect(result.records.single.weight, 40);
      expect(result.records.single.estimatedOneRepMax, isNull);
    },
  );

  test('profile JSON validation and immutability preserve optional values', () {
    final equipment = ['Gantere'];
    final days = [2, 4];
    final value = UserProfile(
      age: 34,
      heightCm: 180,
      weightKg: 83.5,
      equipment: equipment,
      preferredDays: days,
    );
    equipment.add('Cablu');
    days.add(6);
    expect(value.equipment, ['Gantere']);
    expect(value.preferredDays, [2, 4]);
    expect(() => value.equipment.add('Aparat'), throwsUnsupportedError);
    expect(UserProfile.fromJson(value.toJson()).toJson(), value.toJson());
    expect(value.copyWith(clearWeightKg: true).weightKg, isNull);
    for (final invalid in [
      {'age': 10},
      {'heightCm': double.nan},
      {'weightKg': -20},
      {'sessionsPerWeek': 0},
      {'sessionsPerWeek': 2.5},
      {
        'preferredDays': [0],
      },
      {
        'equipment': ['Gantere', 'Gantere'],
      },
      {'coachConsent': 'true'},
      {'experience': 'Expert magic'},
    ]) {
      expect(() => UserProfile.fromJson(invalid), throwsFormatException);
    }
  });
  test(
    'weekly streak survives a partial week and extends only after target',
    () {
      final history = [
        for (final day in [5, 7, 9, 12, 14, 16, 19, 21, 23, 26])
          workout('s-$day', DateTime(2026, 10, day, 12)),
      ];
      final partial = analyze(history).streak;
      expect(partial.currentWeeks, 3);
      expect(partial.bestWeeks, 3);
      expect(partial.activeDaysThisWeek, 1);
      expect(partial.currentWeekStart, DateTime(2026, 10, 26));
      final duplicate = analyze([
        ...history,
        workout('same-day', DateTime(2026, 10, 26, 18)),
      ]);
      expect(duplicate.streak.activeDaysThisWeek, 1);
      expect(duplicate.currentStreakWeeks, 3);
      final extended = analyze([
        ...history,
        workout('tue', DateTime(2026, 10, 27, 12)),
        workout('wed', DateTime(2026, 10, 28, 12)),
      ]);
      expect(extended.currentStreakWeeks, 4);
      expect(extended.bestStreakWeeks, 4);
      final higherTarget = analyzeTrainingStreak(
        history: history,
        profile: UserProfile(sessionsPerWeek: 4),
        now: now,
      );
      expect(higherTarget.currentWeeks, 0);
      expect(higherTarget.bestWeeks, 0);
      expect(partial.explanation, contains('Obiectivul actual'));
    },
  );

  test('a missed completed week resets current streak but preserves best', () {
    final history = [
      for (final day in [5, 7, 9, 12, 14, 16, 19, 21, 26])
        workout('s-$day', DateTime(2026, 10, day, 12)),
    ];
    final result = analyze(history).streak;
    expect(result.currentWeeks, 0);
    expect(result.bestWeeks, 2);
    expect(analyze([]).streak.currentWeeks, 0);
    expect(analyze([]).streak.bestWeeks, 0);
    final onePerWeek = analyzeTrainingStreak(
      history: [
        workout('sun', DateTime(2026, 10, 25, 12)),
        workout('mon', DateTime(2026, 10, 26, 12)),
        workout('future', DateTime(2026, 11, 2, 12)),
      ],
      profile: UserProfile(sessionsPerWeek: 1),
      now: now,
    );
    expect(onePerWeek.currentWeeks, 2);
    expect(onePerWeek.bestWeeks, 2);
  });

  test(
    'daily chart has exact calendar bounds, zero days and distinct active days',
    () {
      final first = workout('first', DateTime(2026, 10, 22, 9));
      final history = [
        first,
        first,
        workout('second', DateTime(2026, 10, 22, 18)),
        workout('body', DateTime(2026, 10, 23, 12), exerciseId: 'pushup'),
        workout('outside', DateTime(2026, 10, 21, 12)),
        workout('future', DateTime(2026, 10, 29, 12)),
        WorkoutSession(
          id: 'active',
          routineName: 'Active',
          startedAt: DateTime(2026, 10, 24),
          exercises: const [
            WorkoutExercise(
              exerciseId: 'squat',
              sets: [WorkoutSet(reps: 10, weight: 80, completed: true)],
            ),
          ],
        ),
      ];
      final series = buildTrainingSeries(
        history: history,
        exercises: [barbell, bodyweight],
        days: 7,
        now: now,
      );
      expect(series.points.length, 7);
      expect(series.start, DateTime(2026, 10, 22));
      expect(series.points.last.date, DateTime(2026, 10, 28));
      expect(series.workoutCount, 3);
      expect(series.activeDays, 2);
      expect(series.completedSets, 3);
      expect(series.volume, 1600);
      expect(series.durationMinutes, 90);
      expect(series.points.first.workoutCount, 2);
      expect(series.points.first.activeDays, 1);
      expect(series.points[2].volume, 0);
      expect(series.points[2].activeDays, 0);
      expect(series.activeDates, [
        DateTime(2026, 10, 22),
        DateTime(2026, 10, 23),
      ]);
      expect(series.muscles.first.completedSets, 2);
      expect(
        series.muscles
            .map((item) => item.completedSets)
            .reduce((a, b) => a + b),
        3,
      );
      expect(() => series.points.clear(), throwsUnsupportedError);
    },
  );

  test('7, 28 and 90-day series include only their own real history', () {
    final history = [
      workout('sept', DateTime(2026, 9, 1, 12)),
      workout('early-oct', DateTime(2026, 10, 1, 12)),
      workout('late-oct', DateTime(2026, 10, 27, 12)),
    ];
    for (final days in [7, 28, 90]) {
      final result = buildTrainingSeries(
        history: history,
        exercises: [barbell],
        days: days,
        now: now,
      );
      expect(result.points.length, days);
      expect(
        result.workoutCount,
        days == 7
            ? 1
            : days == 28
            ? 2
            : 3,
      );
      expect(result.volume, result.workoutCount * 800);
    }
    expect(
      () => buildTrainingSeries(
        history: history,
        exercises: [barbell],
        days: 30,
        now: now,
      ),
      throwsArgumentError,
    );
  });

  test(
    'exercise chart keeps independent actual load and estimate with real gaps',
    () {
      final history = [
        workout(
          'first',
          DateTime(2026, 10, 22, 12),
          sets: const [
            WorkoutSet(reps: 1, weight: 100, completed: true),
            WorkoutSet(reps: 10, weight: 90, completed: true),
            WorkoutSet(reps: 5, weight: 999, completed: false),
          ],
        ),
        workout(
          'second',
          DateTime(2026, 10, 22, 18),
          sets: const [WorkoutSet(reps: 12, weight: 80, completed: true)],
        ),
        workout(
          'high-reps',
          DateTime(2026, 10, 25, 12),
          sets: const [WorkoutSet(reps: 20, weight: 40, completed: true)],
        ),
        workout('outside', DateTime(2026, 10, 21, 12)),
        workout('future', DateTime(2026, 10, 29, 12)),
      ];
      final points = buildExerciseProgression(
        history: history,
        exercise: barbell,
        days: 7,
        now: now,
      );
      expect(points.length, 2);
      expect(points.first.date, DateTime(2026, 10, 22));
      expect(points.first.topWeight, 100);
      expect(points.first.topWeightReps, 1);
      expect(points.first.estimatedOneRepMax, 120);
      expect(points.first.completedSets, 3);
      expect(points.first.volume, 1960);
      expect(points.last.estimatedOneRepMax, isNull);
      expect(points.last.topWeight, 40);
      expect(
        buildExerciseProgression(
          history: history,
          exercise: bodyweight,
          now: now,
        ),
        isEmpty,
      );
      expect(
        isValidCompletedSet(
          const WorkoutSet(reps: 0, weight: 5, completed: true),
        ),
        isFalse,
      );
      expect(isWeightedStrengthExercise(cardio), isFalse);
      expect(
        estimateOneRepMax(
          cardio,
          const WorkoutSet(reps: 10, weight: 50, completed: true),
        ),
        isNull,
      );
      expect(
        estimateOneRepMax(
          barbell,
          const WorkoutSet(reps: 10, weight: 50, completed: false),
        ),
        isNull,
      );
    },
  );
}
