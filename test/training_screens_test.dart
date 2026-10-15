import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_fit/domain/models.dart';
import 'package:pi_fit/state/app_store.dart';
import 'package:pi_fit/services/workout_clock.dart';
import 'package:pi_fit/ui/theme.dart';
import 'package:pi_fit/ui/exercise_image.dart';
import 'package:pi_fit/ui/training_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> disposeWorkout(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    WorkoutClock.instance.unbind();
  }

  Finder workoutField(String label) => find.descendant(
    of: find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label,
    ),
    matching: find.byType(TextField),
  );

  Future<void> revealWorkout(WidgetTester tester, Finder target) async {
    final list = find.byType(ListView).first;
    final scrollable = find
        .descendant(of: list, matching: find.byType(Scrollable))
        .first;
    if (target.evaluate().isEmpty) {
      // Lazy workout sections may not exist until their scroll position is
      // reached. Rebuild from the top, then reveal the specific labeled control.
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(target, 180, scrollable: scrollable);
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<AppStore> newStore() async {
    SharedPreferences.setMockInitialValues({});
    return AppStore(await SharedPreferences.getInstance());
  }

  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'exercise search supports accents and English aliases with an offline icon detail',
    (tester) async {
      phoneSize(tester);
      final store = await newStore();
      await tester.pumpWidget(
        MaterialApp(
          theme: piTheme(Brightness.dark),
          home: ExercisesScreen(store: store),
        ),
      );
      await tester.enterText(find.byType(TextField), 'impins la banca');
      await tester.pumpAndSettle();
      expect(find.text('Barbell Bench Press - Medium Grip'), findsOneWidget);
      expect(find.text('Incline Dumbbell Press'), findsNothing);
      await tester.enterText(find.byType(TextField), 'bench press');
      await tester.pumpAndSettle();
      expect(find.text('Barbell Bench Press - Medium Grip'), findsOneWidget);
      await tester.tap(find.text('Barbell Bench Press - Medium Grip'));
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsNothing);
      expect(
        find.text(
          'Exercise icon. Follow the written instructions for technique.',
        ),
        findsOneWidget,
      );
      expect(find.text(exerciseIconCredit), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('Secondary muscles'), findsOneWidget);
      expect(find.text('Shoulders, Triceps'), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('How to perform'), findsOneWidget);
      await tester.tap(find.text('Tips'));
      await tester.pumpAndSettle();
      expect(find.text('Details make the difference'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('equipment, level and category filters combine and clear', (
    tester,
  ) async {
    phoneSize(tester);
    final store = await newStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: piTheme(Brightness.light),
        home: ExercisesScreen(store: store),
      ),
    );
    await tester.tap(find.byTooltip('Filter by equipment'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Dumbbells').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dumbbells').last);
    await tester.pumpAndSettle();
    expect(find.text('Barbell Bench Press - Medium Grip'), findsNothing);
    expect(find.text('Incline Dumbbell Press'), findsOneWidget);

    await tester.tap(find.byTooltip('Filter by level'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Intermediate').last);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('exercise-filters')),
      const Offset(-220, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filter by category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strength').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Chest'),
      180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('exercise-muscles')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Chest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chest'));
    await tester.pumpAndSettle();
    final count = store.exercises
        .where(
          (exercise) =>
              exercise.equipment == 'Dumbbells' &&
              exercise.difficulty == 'Intermediate' &&
              exercise.category == 'Strength' &&
              exercise.muscle == 'Chest',
        )
        .length;
    expect(
      find.text('$count ${count == 1 ? 'exercise' : 'exercises'}'),
      findsOneWidget,
    );
    expect(find.text('Clear filters · 4'), findsOneWidget);
    await tester.tap(find.text('Clear filters · 4'));
    await tester.pumpAndSettle();
    expect(find.text('${store.exercises.length} exercises'), findsOneWidget);
    expect(find.text('Barbell Bench Press - Medium Grip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('favorites filter persists and survives rebuilding the browser', (
    tester,
  ) async {
    phoneSize(tester);
    final store = await newStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: piTheme(Brightness.dark),
        home: ExercisesScreen(store: store),
      ),
    );
    await tester.tap(
      find.byTooltip('Add to favorites: Barbell Bench Press - Medium Grip'),
    );
    await tester.pumpAndSettle();
    expect(store.favoriteExerciseIds, contains('bench_press'));
    await tester.drag(
      find.byKey(const ValueKey('exercise-filters')),
      const Offset(-240, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favorites-filter')));
    await tester.pumpAndSettle();
    expect(find.text('1 exercise'), findsOneWidget);
    expect(find.text('Incline Dumbbell Press'), findsNothing);
    final reopened = AppStore(await SharedPreferences.getInstance());
    await reopened.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: piTheme(Brightness.light),
        home: ExercisesScreen(store: reopened),
      ),
    );
    await tester.pumpAndSettle();
    expect(reopened.favoriteExerciseIds, contains('bench_press'));
    expect(
      find.byTooltip(
        'Remove from favorites: Barbell Bench Press - Medium Grip',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byTooltip(
        'Remove from favorites: Barbell Bench Press - Medium Grip',
      ),
    );
    await tester.pumpAndSettle();
    expect(reopened.favoriteExerciseIds, isEmpty);
    expect(tester.takeException(), isNull);
  });

  Future<void> pickerFilter(
    WidgetTester tester,
    String label,
    String value,
  ) async {
    await tester.tap(find.byTooltip('Filter by $label'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(value).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(value).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'starting a workout selects the searched exercise through all four filters with keyboard open',
    (tester) async {
      phoneSize(tester);
      addTearDown(tester.view.resetViewInsets);
      final store = await newStore();
      await tester.pumpWidget(
        MaterialApp(
          theme: piTheme(Brightness.dark),
          home: RoutinesScreen(store: store),
        ),
      );
      await tester.tap(find.text('Start empty workout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add exercise'));
      await tester.pumpAndSettle();
      await pickerFilter(tester, 'muscle', 'Chest');
      await pickerFilter(tester, 'equipment', 'Dumbbells');
      await pickerFilter(tester, 'level', 'Beginner');
      await tester.drag(
        find.byKey(const ValueKey('picker-filters')),
        const Offset(-220, 0),
      );
      await tester.pumpAndSettle();
      await pickerFilter(tester, 'category', 'Strength');
      await tester.enterText(
        find.byKey(const ValueKey('picker-search')),
        'incline dumbbell press',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('picker-exercise-incline_dumbbell_press')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('picker-exercise-bench_press')),
        findsNothing,
      );
      expect(store.activeSession!.exercises, isEmpty);
      await tester.tap(
        find.byKey(const ValueKey('picker-exercise-incline_dumbbell_press')),
      );
      await tester.pumpAndSettle();
      expect(
        store.activeSession!.exercises.single.exerciseId,
        'incline_dumbbell_press',
      );
      expect(find.byKey(const ValueKey('picker-search')), findsNothing);
      expect(tester.takeException(), isNull);
      await disposeWorkout(tester);
    },
  );

  testWidgets(
    'clearing incompatible workout filters preserves the changed search and adds its exact result',
    (tester) async {
      phoneSize(tester);
      final store = await newStore();
      await store.startEmptyWorkout();
      await tester.pumpWidget(
        MaterialApp(
          theme: piTheme(Brightness.light),
          home: ActiveWorkoutScreen(store: store),
        ),
      );
      await tester.tap(find.text('Add exercise'));
      await tester.pumpAndSettle();
      await pickerFilter(tester, 'equipment', 'Dumbbells');
      await tester.enterText(
        find.byKey(const ValueKey('picker-search')),
        'barbell bench press medium grip',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('picker-exercise-bench_press')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('picker-search-without-filters')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('picker-search')))
            .controller!
            .text,
        'barbell bench press medium grip',
      );
      expect(
        find.byKey(const ValueKey('picker-exercise-bench_press')),
        findsOneWidget,
      );
      expect(store.activeSession!.exercises, isEmpty);
      await tester.tap(
        find.byKey(const ValueKey('picker-exercise-bench_press')),
      );
      await tester.pumpAndSettle();
      expect(store.activeSession!.exercises.single.exerciseId, 'bench_press');
      expect(tester.takeException(), isNull);
      await disposeWorkout(tester);
    },
  );

  testWidgets(
    'routine builder keeps multiple choices across favorites and different queries',
    (tester) async {
      phoneSize(tester);
      final store = await newStore();
      await store.setExerciseFavorite('bench_press', true);
      await tester.pumpWidget(
        MaterialApp(
          theme: piTheme(Brightness.dark),
          home: RoutinesScreen(store: store),
        ),
      );
      await tester.tap(find.byTooltip('Create routine'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Selecție multiplă');
      tester.testTextInput.hide();
      await tester.tap(find.text('Add exercise'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('picker-filters')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('picker-favorites')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('picker-exercise-bench_press')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('picker-exercise-incline_dumbbell_press')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const ValueKey('picker-search')),
        'bench press',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('picker-exercise-bench_press')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('picker-favorites')));
      await tester.enterText(
        find.byKey(const ValueKey('picker-search')),
        'incline dumbbell press',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('picker-exercise-incline_dumbbell_press')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();
      expect(
        store.customRoutines.single.exercises.map(
          (exercise) => exercise.exerciseId,
        ),
        ['bench_press', 'incline_dumbbell_press'],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a custom routine is created from the exercise picker', (
    tester,
  ) async {
    phoneSize(tester);
    final store = await newStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: piTheme(Brightness.light),
        home: RoutinesScreen(store: store),
      ),
    );
    await tester.tap(find.byTooltip('Create routine'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Planul meu');
    tester.testTextInput.hide();
    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barbell Bench Press - Medium Grip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barbell Bench Press - Medium Grip'));
    await tester.pumpAndSettle();
    final prescriptionFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(prescriptionFields.at(0), '4');
    await tester.enterText(prescriptionFields.at(1), '12');
    await tester.enterText(prescriptionFields.at(2), '25,5');
    tester.testTextInput.hide();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();
    expect(store.customRoutines, hasLength(1));
    expect(store.customRoutines.single.name, 'Planul meu');
    expect(
      store.customRoutines.single.exercises.single.exerciseId,
      'bench_press',
    );
    expect(store.customRoutines.single.exercises.single.sets, 4);
    expect(store.customRoutines.single.exercises.single.reps, 12);
    expect(store.customRoutines.single.exercises.single.weight, 25.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'live logging updates completed metrics and genuine same-exercise records, then removes them after edits',
    (tester) async {
      phoneSize(tester);
      final store = await newStore();
      final now = DateTime.now();
      store.history = [
        WorkoutSession(
          id: 'previous',
          routineName: 'Anterior',
          startedAt: now.subtract(const Duration(days: 2)),
          finishedAt: now.subtract(const Duration(days: 2, hours: -1)),
          exercises: const [
            WorkoutExercise(
              exerciseId: 'bench_press',
              sets: [
                WorkoutSet(weight: 60, reps: 8, completed: true),
                WorkoutSet(weight: 500, reps: 10),
              ],
            ),
            WorkoutExercise(
              exerciseId: 'deadlift',
              sets: [WorkoutSet(weight: 300, reps: 5, completed: true)],
            ),
          ],
        ),
        WorkoutSession(
          id: 'future',
          routineName: 'Viitor',
          startedAt: now.add(const Duration(days: 2)),
          finishedAt: now.add(const Duration(days: 2, hours: 1)),
          exercises: const [
            WorkoutExercise(
              exerciseId: 'bench_press',
              sets: [WorkoutSet(weight: 1000, reps: 10, completed: true)],
            ),
          ],
        ),
        WorkoutSession(
          id: 'unfinished',
          routineName: 'Nefinalizat',
          startedAt: now.subtract(const Duration(days: 1)),
          exercises: const [
            WorkoutExercise(
              exerciseId: 'bench_press',
              sets: [WorkoutSet(weight: 400, reps: 10, completed: true)],
            ),
          ],
        ),
      ];
      await store.startWorkout(
        const Routine(
          id: 'live',
          name: 'Progres în timp real',
          subtitle: '',
          estimatedMinutes: 10,
          category: 'Custom',
          exercises: [
            RoutineExercise(
              exerciseId: 'bench_press',
              sets: 2,
              reps: 10,
              weight: 60,
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: piTheme(Brightness.dark),
          home: ActiveWorkoutScreen(store: store),
        ),
      );
      String metric(String key) =>
          tester.widget<Text>(find.byKey(ValueKey(key))).data!;
      Future<void> summary() async {
        tester.testTextInput.hide();
        await revealWorkout(
          tester,
          find.byKey(const ValueKey('live-completed-sets')),
        );
      }

      expect(find.byKey(const ValueKey('rate-effort-0')), findsNothing);
      expect(metric('live-completed-sets'), '0/2');
      expect(metric('live-reps'), '0');
      expect(metric('live-volume'), '0');
      expect(metric('live-duration'), matches(RegExp(r'^\d{2,}:\d{2}$')));
      expect(
        metric('live-previous-bench_press'),
        contains('1 set · 8 reps · 480 kg'),
      );
      expect(find.byKey(const ValueKey('live-pr-bench_press')), findsNothing);

      final weight = workoutField('Set 1 weight, kg');
      final reps = workoutField('Set 1 reps');
      await revealWorkout(tester, reps);
      await tester.enterText(reps, '10');
      tester.testTextInput.hide();
      await revealWorkout(tester, find.byTooltip('Mark set complete').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mark set complete').first);
      await tester.pumpAndSettle();
      await summary();
      expect(metric('live-completed-sets'), '1/2');
      expect(metric('live-reps'), '10');
      expect(metric('live-volume'), '600');
      expect(metric('live-1rm-bench_press'), 'Estimated 1RM · 80 kg');
      expect(
        metric('live-pr-bench_press'),
        'Estimated 1RM record · +4 kg versus 76 kg',
      );
      await revealWorkout(tester, find.byKey(const ValueKey('rate-effort-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rate-effort-0')));
      await tester.pumpAndSettle();
      expect(find.text('How hard was your last set?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, '8'));
      await tester.pumpAndSettle();
      expect(store.activeSession!.exercises.first.sets.first.rpe, 8);
      expect(find.text('RPE 8/10'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rate-effort-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear effort rating'));
      await tester.pumpAndSettle();
      expect(store.activeSession!.exercises.first.sets.first.rpe, isNull);

      // A high-repetition edit still counts actual reps/volume but cannot create
      // an Epley estimate outside the explicitly supported 1–12 repetition range.
      await revealWorkout(tester, reps);
      await tester.enterText(reps, '13');
      await tester.pumpAndSettle();
      await summary();
      expect(metric('live-reps'), '13');
      expect(metric('live-volume'), '780');
      expect(find.byKey(const ValueKey('live-1rm-bench_press')), findsNothing);
      expect(find.byKey(const ValueKey('live-pr-bench_press')), findsNothing);

      // A genuinely heavier external load can be a weight record even when
      // repetition count makes an estimated 1RM ineligible.
      await revealWorkout(tester, weight);
      await tester.enterText(weight, '61');
      await tester.pumpAndSettle();
      await summary();
      expect(metric('live-volume'), '793');
      expect(find.byKey(const ValueKey('live-1rm-bench_press')), findsNothing);
      expect(
        metric('live-pr-bench_press'),
        'Weight record · 61 kg (previous 60 kg)',
      );

      await revealWorkout(tester, reps);
      await tester.enterText(reps, '0');
      await tester.pumpAndSettle();
      await summary();
      expect(metric('live-completed-sets'), '0/2');
      expect(metric('live-reps'), '0');
      expect(metric('live-volume'), '0');
      await revealWorkout(tester, find.text('Add set').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add set').first);
      await tester.pumpAndSettle();
      await summary();
      expect(metric('live-completed-sets'), '0/3');
      expect(metric('live-reps'), '0');
      expect(
        metric('live-planned-completed'),
        '0 of 3 sets completed · 3 remaining',
      );
      expect(tester.takeException(), isNull);
      await disposeWorkout(tester);
    },
  );

  testWidgets(
    'rest controls stay synchronized with the shared notification clock',
    (tester) async {
      phoneSize(tester);
      final store = await newStore();
      await store.startEmptyWorkout();
      await tester.pumpWidget(
        MaterialApp(
          theme: piTheme(Brightness.dark),
          home: ActiveWorkoutScreen(store: store),
        ),
      );
      await tester.tap(find.byTooltip('Start rest'));
      await tester.pumpAndSettle();
      expect(WorkoutClock.instance.remaining, inInclusiveRange(88, 90));
      expect(find.byTooltip('Skip rest'), findsOneWidget);
      WorkoutClock.instance.skipRest();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Start rest'), findsOneWidget);
      await tester.tap(find.byTooltip('Rest duration'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('60s'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Start rest'));
      await tester.pumpAndSettle();
      expect(WorkoutClock.instance.remaining, inInclusiveRange(58, 60));
      await tester.tap(find.text('+30s'));
      await tester.pumpAndSettle();
      expect(WorkoutClock.instance.remaining, inInclusiveRange(88, 90));
      expect(WorkoutClock.instance.restSeconds, 60);
      WorkoutClock.instance.skipRest();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Start rest'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeWorkout(tester);
    },
  );

  testWidgets(
    'live external volume and 1RM exclude bodyweight and cardio even when a weight is entered',
    (tester) async {
      phoneSize(tester);
      final store = await newStore();
      await store.startWorkout(
        const Routine(
          id: 'mixed',
          name: 'Mixt',
          subtitle: '',
          estimatedMinutes: 10,
          category: 'Custom',
          exercises: [
            RoutineExercise(
              exerciseId: 'push_up',
              sets: 1,
              reps: 12,
              weight: 20,
            ),
            RoutineExercise(
              exerciseId: 'treadmill',
              sets: 1,
              reps: 15,
              weight: 50,
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: piTheme(Brightness.light),
          home: ActiveWorkoutScreen(store: store),
        ),
      );
      await store.updateSet(0, 0, completed: true);
      await store.updateSet(1, 0, completed: true);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('live-completed-sets')))
            .data,
        '2/2',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('live-reps'))).data,
        '27',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('live-volume'))).data,
        '0',
      );
      expect(find.byKey(const ValueKey('live-1rm-push_up')), findsNothing);
      expect(find.byKey(const ValueKey('live-1rm-treadmill')), findsNothing);
      expect(tester.takeException(), isNull);
      await disposeWorkout(tester);
    },
  );

  testWidgets(
    'workout logs actual values, rejects invalid sets and saves completion',
    (tester) async {
      phoneSize(tester);
      final store = await newStore();
      await store.startWorkout(
        const Routine(
          id: 'test',
          name: 'Sesiune de test',
          subtitle: '',
          estimatedMinutes: 5,
          category: 'Custom',
          exercises: [RoutineExercise(exerciseId: 'bench_press', sets: 1)],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: piTheme(Brightness.dark),
          home: ActiveWorkoutScreen(store: store),
        ),
      );
      await tester.tap(find.text('Finish'));
      await tester.pump();
      expect(store.history, isEmpty);
      expect(
        find.text('Complete at least one set before saving.'),
        findsOneWidget,
      );

      final weight = workoutField('Set 1 weight, kg');
      final reps = workoutField('Set 1 reps');
      await revealWorkout(tester, weight);
      await tester.enterText(weight, '62,5');
      await tester.pump();
      await tester.enterText(reps, '8');
      await tester.pump();
      tester.testTextInput.hide();
      await revealWorkout(tester, find.byTooltip('Mark set complete').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mark set complete').first);
      await tester.pump();
      expect(store.activeSession!.completedSets, 1);
      expect(store.activeSession!.volume, 500);
      expect(find.byKey(const ValueKey('live-pr-bench_press')), findsNothing);
      await revealWorkout(tester, find.text('Breathe. Come back stronger.'));
      expect(find.text('Breathe. Come back stronger.'), findsOneWidget);

      await revealWorkout(tester, reps);
      await tester.enterText(reps, '0');
      await tester.pump();
      expect(store.activeSession!.completedSets, 0);
      await tester.enterText(reps, '8');
      await tester.pump();
      tester.testTextInput.hide();
      await revealWorkout(tester, find.byTooltip('Mark set complete').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mark set complete').first);
      await tester.pump();
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Mișcare controlată.',
      );
      tester.testTextInput.hide();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.activeSession, isNull);
      expect(store.history.single.volume, 500);
      expect(store.history.single.notes, 'Mișcare controlată.');
      expect(tester.takeException(), isNull);
      // Dispose the local rest timer at the end of the test.
      await disposeWorkout(tester);
    },
  );
}
