import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_fit/domain/models.dart';
import 'package:pi_fit/state/app_store.dart';
import 'package:pi_fit/ui/planning_screens.dart';
import 'package:pi_fit/ui/theme.dart';
import 'package:pi_fit/ui/training_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AppStore(await SharedPreferences.getInstance());
  });

  Future<void> showScreen(
    WidgetTester tester,
    Widget screen, {
    double width = 390,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: piTheme(Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Single scheduling saves one future session without reminders', (
    tester,
  ) async {
    await showScreen(tester, CalendarScreen(store: store), width: 320);
    await tester.tap(find.text('Schedule workouts'));
    await tester.pumpAndSettle();
    final save = find.text('Add 1 session');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(store.schedule, hasLength(1));
    expect(store.schedule.single.date.isAfter(DateTime.now()), isTrue);
    expect(store.schedule.single.reminder, isFalse);
    expect(find.text('1 saved workout in your calendar.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bulk scheduling previews and persists all 28 selected dates', (
    tester,
  ) async {
    await showScreen(tester, CalendarScreen(store: store));
    await tester.tap(find.text('Schedule workouts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repeat'));
    await tester.pumpAndSettle();

    for (final day in ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']) {
      final chip = find.widgetWithText(FilterChip, day);
      await tester.ensureVisible(chip);
      if (!tester.widget<FilterChip>(chip).selected) {
        await tester.tap(chip);
        await tester.pumpAndSettle();
      }
    }
    final save = find.text('Add 28 sessions');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(store.schedule, hasLength(28));
    expect(store.schedule.map((event) => event.date).toSet(), hasLength(28));
    expect(
      store.schedule.every((event) => event.date.isAfter(DateTime.now())),
      isTrue,
    );
    expect(find.text('28 saved workouts in your calendar.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Progress ignores unchecked sets in volume and records', (
    tester,
  ) async {
    final start = DateTime.now().subtract(const Duration(hours: 2));
    store.history.add(
      WorkoutSession(
        id: 'test-session',
        routineName: 'Verified session',
        startedAt: start,
        finishedAt: start.add(const Duration(minutes: 35)),
        notes: 'Good form',
        exercises: [
          WorkoutExercise(
            exerciseId: store.exercises.first.id,
            sets: const [
              WorkoutSet(reps: 10, weight: 20, completed: true),
              WorkoutSet(reps: 10, weight: 80, completed: false),
            ],
          ),
        ],
      ),
    );
    await showScreen(tester, ProgressScreen(store: store));

    expect(store.totalVolume, 200);
    expect(find.text('200'), findsNWidgets(2));
    final record = find.text('20 kg × 10');
    await tester.ensureVisible(record);
    expect(record, findsOneWidget);
    expect(find.text('80 kg × 10'), findsNothing);
    final history = find.text('Verified session');
    await tester.ensureVisible(history);
    await tester.tap(history);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 sets'), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('20 kg × 10'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Estimated 1RM · 26.7 kg'),
      ),
      findsOneWidget,
    );
    expect(find.text('80 kg × 10'), findsOneWidget);
    await tester.ensureVisible(find.text('Good form'));
    expect(find.text('Good form'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Score explains capped weights and counts unique active days', (
    tester,
  ) async {
    final now = DateTime.now();
    void addSession(String id, int daysAgo) {
      final date = DateTime(now.year, now.month, now.day - daysAgo);
      store.history.add(
        WorkoutSession(
          id: id,
          routineName: 'Session $id',
          startedAt: date,
          finishedAt: date.add(const Duration(minutes: 30)),
          exercises: [
            WorkoutExercise(
              exerciseId: store.exercises.first.id,
              sets: const [WorkoutSet(reps: 10, weight: 20, completed: true)],
            ),
          ],
        ),
      );
    }

    addSession('a', 1);
    addSession('b', 1);
    addSession('c', 2);
    addSession('d', 3);
    addSession('e', 8);

    await showScreen(
      tester,
      ProgressScreen(store: store),
      width: 320,
      textScale: 1.3,
    );
    expect(find.text('4 / 12 active days'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
    await tester.ensureVisible(find.text('See the calculation'));
    await tester.tap(find.text('See the calculation'));
    await tester.pumpAndSettle();
    expect(find.text('How your score is calculated'), findsOneWidget);
    expect(find.text('4 / 12 · 23.3 of 70 points'), findsOneWidget);
    expect(find.text('1 / 4 · 7.5 of 30 points'), findsOneWidget);
    final formula = find.textContaining('Score = 70');
    await tester.ensureVisible(formula);
    expect(formula, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('28 day summary excludes old, unfinished and future sessions', (
    tester,
  ) async {
    final now = DateTime.now();
    WorkoutSession session(String id, int daysAgo, {bool finished = true}) {
      final date = DateTime(now.year, now.month, now.day - daysAgo);
      return WorkoutSession(
        id: id,
        routineName: 'Session $id',
        startedAt: date,
        finishedAt: finished ? date.add(const Duration(minutes: 20)) : null,
        exercises: [
          WorkoutExercise(
            exerciseId: store.exercises.first.id,
            sets: const [
              WorkoutSet(reps: 10, weight: 20, completed: true),
              WorkoutSet(reps: 10, weight: 99, completed: false),
            ],
          ),
        ],
      );
    }

    store.history.addAll([
      session('recent', 1),
      session('old', 35),
      session('future', -2),
      session('unfinished', 2, finished: false),
    ]);
    await showScreen(tester, ProgressScreen(store: store));
    Finder metric(String label, String value) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(PiCard)),
      matching: find.text(value),
    );
    for (final label in ['saved workouts', 'completed sets', 'active days']) {
      await tester.ensureVisible(find.text(label));
      expect(metric(label, '1'), findsOneWidget);
    }
    await tester.ensureVisible(find.text('kg · external volume'));
    expect(metric('kg · external volume', '200'), findsOneWidget);
    await tester.ensureVisible(find.text('Sets by primary muscle'));
    expect(find.text('1 primary set'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Empty progress has no invented score and opens routine selection',
    (tester) async {
      await showScreen(
        tester,
        ProgressScreen(store: store),
        width: 320,
        textScale: 1.3,
      );
      expect(find.text('no data'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      final choose = find.text('Choose a workout');
      await tester.ensureVisible(choose);
      await tester.tap(choose);
      await tester.pumpAndSettle();
      expect(find.byType(RoutinesScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Progress and detailed journal fit narrow accessible screens', (
    tester,
  ) async {
    final start = DateTime.now().subtract(const Duration(days: 1));
    store.history.add(
      WorkoutSession(
        id: 'narrow',
        routineName: 'A workout with a long description',
        startedAt: start,
        finishedAt: start.add(const Duration(minutes: 45)),
        notes: 'Two-minute rests between sets.',
        exercises: [
          WorkoutExercise(
            exerciseId: store.exercises.first.id,
            sets: const [
              WorkoutSet(reps: 10, weight: 20, completed: true),
              WorkoutSet(reps: 10, weight: 40, completed: false),
            ],
          ),
        ],
      ),
    );
    await showScreen(
      tester,
      ProgressScreen(store: store),
      width: 320,
      textScale: 1.3,
    );
    for (final title in [
      'Your last 28 days',
      'Training over time',
      'Sets by primary muscle',
      'Personal records',
      'A workout with a long description',
    ]) {
      await tester.ensureVisible(find.text(title));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('A workout with a long description'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Completed set'), findsOneWidget);
    expect(find.byTooltip('Planned set, not completed'), findsOneWidget);
    await tester.ensureVisible(find.text('Two-minute rests between sets.'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Period and metric controls show actual values and chart details',
    (tester) async {
      final now = DateTime.now();
      for (final item in [(1, 20.0, 20), (35, 30.0, 30)]) {
        final start = DateTime(now.year, now.month, now.day - item.$1);
        store.history.add(
          WorkoutSession(
            id: 'period-${item.$1}',
            routineName: 'Sesiune ${item.$1}',
            startedAt: start,
            finishedAt: start.add(Duration(minutes: item.$3)),
            exercises: [
              WorkoutExercise(
                exerciseId: store.exercises.first.id,
                sets: [WorkoutSet(reps: 10, weight: item.$2, completed: true)],
              ),
            ],
          ),
        );
      }
      await showScreen(
        tester,
        ProgressScreen(store: store),
        width: 320,
        textScale: 1.3,
      );
      final period = find.byKey(const ValueKey('period-90'));
      await tester.ensureVisible(period);
      await tester.tap(period);
      await tester.pumpAndSettle();
      expect(find.text('Your last 90 days'), findsOneWidget);
      final total = find.byKey(const ValueKey('trend-total'));
      await tester.ensureVisible(total);
      expect(tester.widget<Text>(total).data, '500');
      for (final item in [
        ('sets', '2'),
        ('sessions', '2'),
        ('minutes', '50'),
      ]) {
        final chip = find.byKey(ValueKey('metric-${item.$1}'));
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(total).data, item.$2);
      }
      final values = find.text('View values');
      await tester.ensureVisible(values);
      await tester.tap(values);
      await tester.pumpAndSettle();
      expect(find.text('Minutes · chart values'), findsOneWidget);
      expect(find.text('20 min'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Exercise chart uses logged points and exposes estimated values',
    (tester) async {
      final now = DateTime.now();
      for (final item in [(1, 30.0), (8, 20.0)]) {
        final start = DateTime(now.year, now.month, now.day - item.$1);
        store.history.add(
          WorkoutSession(
            id: 'point-${item.$1}',
            routineName: 'Progress',
            startedAt: start,
            finishedAt: start.add(const Duration(minutes: 30)),
            exercises: [
              WorkoutExercise(
                exerciseId: store.exercises.first.id,
                sets: [WorkoutSet(reps: 10, weight: item.$2, completed: true)],
              ),
            ],
          ),
        );
      }
      await showScreen(
        tester,
        ProgressScreen(store: store),
        width: 320,
        textScale: 1.3,
      );
      final value = find.byKey(const ValueKey('exercise-chart-value'));
      await tester.ensureVisible(value);
      expect(tester.widget<Text>(value).data, '30 kg');
      final slider = find.byKey(const ValueKey('exercise-progress-slider'));
      await tester.ensureVisible(slider);
      tester.widget<Slider>(slider).onChanged!(0);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(value).data, '20 kg');
      final estimated = find.widgetWithText(ChoiceChip, 'Estimated 1RM');
      await tester.ensureVisible(estimated);
      await tester.tap(estimated);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(value).data, '40 kg');
      expect(find.textContaining('Epley, using sets of 1–12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Weekly streak shows the real goal and explains week boundaries',
    (tester) async {
      final now = DateTime.now();
      final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
      for (var week = 1; week <= 2; week++) {
        for (var day = 0; day < 3; day++) {
          final start = DateTime(
            monday.year,
            monday.month,
            monday.day - week * 7 + day,
          );
          store.history.add(
            WorkoutSession(
              id: 'streak-$week-$day',
              routineName: 'Serie',
              startedAt: start,
              finishedAt: start.add(const Duration(minutes: 20)),
              exercises: [
                WorkoutExercise(
                  exerciseId: store.exercises.first.id,
                  sets: const [
                    WorkoutSet(reps: 10, weight: 20, completed: true),
                  ],
                ),
              ],
            ),
          );
        }
      }
      await showScreen(
        tester,
        ProgressScreen(store: store),
        width: 320,
        textScale: 1.3,
      );
      final title = find.text('Show up. Build. Repeat.');
      await tester.ensureVisible(title);
      final streakCard = find.ancestor(
        of: title,
        matching: find.byType(PiCard),
      );
      expect(
        find.descendant(of: streakCard, matching: find.text('2')),
        findsNWidgets(2),
      );
      expect(find.text('This week · 0 / 3 days'), findsOneWidget);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(find.text('How your streak works'), findsOneWidget);
      expect(
        find.textContaining('Current goal: 3 active days'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Progress refreshes after saving a workout without reopening', (
    tester,
  ) async {
    await showScreen(tester, ProgressScreen(store: store));
    final total = find.byKey(const ValueKey('trend-total'));
    expect(tester.widget<Text>(total).data, '0');
    await store.startWorkout(store.routines.first);
    await store.updateSet(0, 0, reps: 10, weight: 20, completed: true);
    await store.finishWorkout();
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(total).data, '200');
    expect(find.text('1 / 12 active days'), findsOneWidget);
    expect(find.text('no data'), findsNothing);
    await store.updateUserProfile(store.profile.copyWith(sessionsPerWeek: 4));
    await tester.pumpAndSettle();
    expect(find.text('1 / 16 active days'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Muscle shares follow the period and keep secondary work separate',
    (tester) async {
      final now = DateTime.now();
      void add(
        String id,
        String exerciseId,
        int daysAgo,
        List<WorkoutSet> sets,
      ) {
        final start = DateTime(now.year, now.month, now.day - daysAgo);
        store.history.add(
          WorkoutSession(
            id: id,
            routineName: id,
            startedAt: start,
            finishedAt: start.add(const Duration(minutes: 30)),
            exercises: [WorkoutExercise(exerciseId: exerciseId, sets: sets)],
          ),
        );
      }

      add('chest', 'bench_press', 1, const [
        WorkoutSet(weight: 20, reps: 10, completed: true),
        WorkoutSet(weight: 20, reps: 10, completed: true),
        WorkoutSet(weight: 80, reps: 10, completed: false),
        WorkoutSet(weight: 200, reps: 0, completed: true),
      ]);
      add('shoulders', 'lateral_raise', 9, const [
        WorkoutSet(weight: 8, reps: 10, completed: true),
      ]);
      final calves = store.exercises.firstWhere(
        (exercise) =>
            exercise.muscle == 'Calves' && exercise.category == 'Strength',
      );
      add('calves', calves.id, 35, const [
        WorkoutSet(weight: 20, reps: 10, completed: true),
      ]);
      await showScreen(
        tester,
        ProgressScreen(store: store),
        width: 320,
        textScale: 1.3,
      );
      String share(String muscle) => tester
          .widget<Text>(find.byKey(ValueKey('muscle-focus-percent-$muscle')))
          .data!;
      expect(share('Chest'), '66.7%');
      expect(share('Shoulders'), '33.3%');
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('muscle-focus-total')))
            .data,
        '3 completed strength sets · last 28 days',
      );
      final shoulder = find.byKey(
        const ValueKey('muscle-focus-group-Shoulders'),
      );
      await tester.ensureVisible(shoulder);
      await tester.tap(shoulder);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('muscle-detail-primary')))
            .data,
        '1 primary set',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('muscle-detail-secondary')))
            .data,
        '2 secondary mentions',
      );
      expect(find.text('0 primary · 2 secondary'), findsOneWidget);
      final close = find.text('Close breakdown');
      await tester.ensureVisible(close);
      await tester.tap(close);
      await tester.pumpAndSettle();
      for (final period in [7, 90]) {
        final chip = find.byKey(ValueKey('period-$period'));
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(share('Chest'), period == 7 ? '100.0%' : '50.0%');
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('muscle-focus-total')))
              .data,
          period == 7
              ? '2 completed strength sets · last 7 days'
              : '4 completed strength sets · last 90 days',
        );
      }
      expect(share('Shoulders'), '25.0%');
      expect(share('Calves'), '25.0%');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Every trained muscle appears without a top-six cutoff', (
    tester,
  ) async {
    final byMuscle = <String, Exercise>{};
    for (final exercise in store.exercises) {
      if (exercise.category == 'Strength' && exercise.muscle != 'Cardio') {
        byMuscle.putIfAbsent(exercise.muscle, () => exercise);
      }
    }
    final chosen = byMuscle.values.take(7).toList();
    final start = DateTime.now().subtract(const Duration(days: 1));
    store.history.add(
      WorkoutSession(
        id: 'all-groups',
        routineName: 'Varied training',
        startedAt: start,
        finishedAt: start.add(const Duration(minutes: 40)),
        exercises: [
          for (final exercise in chosen)
            WorkoutExercise(
              exerciseId: exercise.id,
              sets: const [WorkoutSet(reps: 10, weight: 20, completed: true)],
            ),
        ],
      ),
    );
    await showScreen(
      tester,
      ProgressScreen(store: store),
      width: 320,
      textScale: 1.3,
    );
    for (final exercise in chosen) {
      final row = find.byKey(ValueKey('muscle-focus-group-${exercise.muscle}'));
      expect(row, findsOneWidget);
      await tester.ensureVisible(row);
      expect(
        tester
            .widget<Text>(
              find.byKey(ValueKey('muscle-focus-percent-${exercise.muscle}')),
            )
            .data,
        '14.3%',
      );
    }
    final jump = find.byKey(const ValueKey('jump-muscle-focus'));
    await tester.ensureVisible(jump);
    await tester.tap(jump);
    await tester.pumpAndSettle();
    expect(find.text('Sets by primary muscle'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'No-data focus exposes every catalog group without invented percentages',
    (tester) async {
      await showScreen(
        tester,
        ProgressScreen(store: store),
        width: 320,
        textScale: 1.3,
      );
      expect(find.text('Your next set starts the picture.'), findsOneWidget);
      final explore = find.byKey(const ValueKey('show-zero-muscle-groups'));
      await tester.ensureVisible(explore);
      await tester.tap(explore);
      await tester.pumpAndSettle();
      for (final muscle in [
        'Abs',
        'Adductors',
        'Back',
        'Biceps',
        'Calves',
        'Chest',
        'Forearms',
        'Glutes',
        'Hamstrings',
        'Neck',
        'Quadriceps',
        'Shoulders',
        'Triceps',
      ]) {
        final row = find.byKey(ValueKey('muscle-focus-group-$muscle'));
        expect(row, findsOneWidget);
        expect(
          tester
              .widget<Text>(
                find.byKey(ValueKey('muscle-focus-percent-$muscle')),
              )
              .data,
          '—',
        );
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('muscle-focus-group-Triceps')),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('An open muscle breakdown clears previous-account activity', (
    tester,
  ) async {
    final start = DateTime.now().subtract(const Duration(days: 1));
    store.history.add(
      WorkoutSession(
        id: 'private-set',
        routineName: 'My training',
        startedAt: start,
        finishedAt: start.add(const Duration(minutes: 20)),
        exercises: [
          WorkoutExercise(
            exerciseId: 'bench_press',
            sets: const [WorkoutSet(weight: 30, reps: 10, completed: true)],
          ),
        ],
      ),
    );
    await showScreen(
      tester,
      ProgressScreen(store: store),
      width: 320,
      textScale: 1.3,
    );
    final row = find.byKey(const ValueKey('muscle-focus-group-Chest'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('muscle-detail-primary')), findsOneWidget);
    await tester.runAsync(() => store.switchAccount('another-athlete'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('muscle-detail-primary')), findsNothing);
    expect(find.text(store.exerciseById('bench_press').name), findsNothing);
    expect(
      find.text(
        'Your account changed. Close this breakdown to view the current profile.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
