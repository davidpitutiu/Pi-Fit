import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_fit/domain/models.dart';
import 'package:pi_fit/state/app_store.dart';
import 'package:pi_fit/ui/theme.dart';
import 'package:pi_fit/ui/exercise_image.dart';
import 'package:pi_fit/ui/training_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
    'exercise search supports accents and English aliases with offline pose gallery',
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
      expect(find.text('Împins la bancă cu bara'), findsOneWidget);
      expect(find.text('Împins înclinat cu gantere'), findsNothing);
      await tester.enterText(find.byType(TextField), 'bench press');
      await tester.pumpAndSettle();
      expect(find.text('Împins la bancă cu bara'), findsOneWidget);
      await tester.tap(find.text('Împins la bancă cu bara'));
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-320, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);
      expect(
        find.text('Imagini: ${store.exerciseById('bench_press').sourceName}'),
        findsOneWidget,
      );
      expect(find.text('Mușchi secundari'), findsOneWidget);
      expect(find.text('Triceps, umeri anteriori'), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('Cum execuți'), findsOneWidget);
      await tester.tap(find.text('Sfaturi'));
      await tester.pumpAndSettle();
      expect(find.text('Detaliile fac diferența'), findsOneWidget);
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
    await tester.tap(find.byTooltip('Filtrează după echipament'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Gantere').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gantere').last);
    await tester.pumpAndSettle();
    expect(find.text('Împins la bancă cu bara'), findsNothing);
    expect(find.text('Împins înclinat cu gantere'), findsOneWidget);

    await tester.tap(find.byTooltip('Filtrează după nivel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Intermediar').last);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('exercise-filters')),
      const Offset(-220, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filtrează după categorie'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forță').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Piept'),
      180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('exercise-muscles')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Piept'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Piept'));
    await tester.pumpAndSettle();
    final count = store.exercises
        .where(
          (exercise) =>
              exercise.equipment == 'Gantere' &&
              exercise.difficulty == 'Intermediar' &&
              exercise.category == 'Forță' &&
              exercise.muscle == 'Piept',
        )
        .length;
    expect(
      find.text('$count ${count == 1 ? 'exercițiu' : 'exerciții'}'),
      findsOneWidget,
    );
    expect(find.text('Șterge filtrele · 4'), findsOneWidget);
    await tester.tap(find.text('Șterge filtrele · 4'));
    await tester.pumpAndSettle();
    expect(find.text('${store.exercises.length} exerciții'), findsOneWidget);
    expect(find.text('Împins la bancă cu bara'), findsOneWidget);
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
      find.byTooltip('Adaugă la favorite: Împins la bancă cu bara'),
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
    expect(find.text('1 exercițiu'), findsOneWidget);
    expect(find.text('Împins înclinat cu gantere'), findsNothing);
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
      find.byTooltip('Elimină din favorite: Împins la bancă cu bara'),
      findsOneWidget,
    );
    await tester.tap(
      find.byTooltip('Elimină din favorite: Împins la bancă cu bara'),
    );
    await tester.pumpAndSettle();
    expect(reopened.favoriteExerciseIds, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'exercise images use offline asset providers and a deliberate empty state',
    (tester) async {
      final semantics = tester.ensureSemantics();
      const pictured = Exercise(
        id: 'asset',
        name: 'Exercițiu demonstrat',
        muscle: 'Piept',
        equipment: 'Bară',
        description: '',
        imageAsset: 'assets/fonts/Inter.ttf',
      );
      // A bad asset must display the neutral fallback rather than fetching the web.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ExerciseImage(exercise: pictured, width: 180, height: 160),
                const ExerciseImage(
                  exercise: Exercise(
                    id: 'no-image',
                    name: 'Fără fotografie',
                    muscle: 'Core',
                    equipment: 'Saltea',
                    description: '',
                  ),
                  width: 180,
                  height: 160,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final provider = tester.widget<Image>(find.byType(Image)).image;
      expect(
        provider is AssetImage ||
            provider is ResizeImage && provider.imageProvider is AssetImage,
        isTrue,
      );
      expect(find.text('Fotografie indisponibilă'), findsNWidgets(2));
      expect(
        find.bySemanticsLabel('Fără fotografie. Imagine indisponibilă.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  Future<void> pickerFilter(
    WidgetTester tester,
    String label,
    String value,
  ) async {
    await tester.tap(find.byTooltip('Filtrează după $label'));
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
      await tester.tap(find.text('Începe antrenament liber'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adaugă exercițiu'));
      await tester.pumpAndSettle();
      await pickerFilter(tester, 'grupă', 'Piept');
      await pickerFilter(tester, 'echipament', 'Gantere');
      await pickerFilter(tester, 'nivel', 'Începător');
      await tester.drag(
        find.byKey(const ValueKey('picker-filters')),
        const Offset(-220, 0),
      );
      await tester.pumpAndSettle();
      await pickerFilter(tester, 'categorie', 'Forță');
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
      await tester.pumpWidget(const SizedBox());
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
      await tester.tap(find.text('Adaugă exercițiu'));
      await tester.pumpAndSettle();
      await pickerFilter(tester, 'echipament', 'Gantere');
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
      await tester.pumpWidget(const SizedBox());
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
      await tester.tap(find.byTooltip('Creează rutină'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Selecție multiplă');
      tester.testTextInput.hide();
      await tester.tap(find.text('Adaugă exercițiu'));
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
      await tester.tap(find.text('Gata (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvează').first);
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
    await tester.tap(find.byTooltip('Creează rutină'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Planul meu');
    tester.testTextInput.hide();
    await tester.tap(find.text('Adaugă exercițiu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Împins la bancă cu bara'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gata (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Împins la bancă cu bara'));
    await tester.pumpAndSettle();
    final prescriptionFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(prescriptionFields.at(0), '4');
    await tester.enterText(prescriptionFields.at(1), '12');
    await tester.enterText(prescriptionFields.at(2), '25,5');
    tester.testTextInput.hide();
    await tester.tap(find.text('Aplică'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvează').first);
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
          category: 'Personalizat',
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
        await tester.drag(find.byType(ListView).first, const Offset(0, 900));
        await tester.pumpAndSettle();
      }

      expect(metric('live-completed-sets'), '0/2');
      expect(metric('live-reps'), '0');
      expect(metric('live-volume'), '0');
      expect(metric('live-duration'), matches(RegExp(r'^\d{2,}:\d{2}$')));
      expect(
        metric('live-previous-bench_press'),
        contains('1 set · 8 reps · 480 kg'),
      );
      expect(find.byKey(const ValueKey('live-pr-bench_press')), findsNothing);

      final fields = find.byType(TextField);
      await tester.ensureVisible(fields.at(1));
      await tester.enterText(fields.at(1), '10');
      tester.testTextInput.hide();
      await tester.ensureVisible(
        find.byTooltip('Marchează setul efectuat').first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Marchează setul efectuat').first);
      await tester.pumpAndSettle();
      await summary();
      expect(metric('live-completed-sets'), '1/2');
      expect(metric('live-reps'), '10');
      expect(metric('live-volume'), '600');
      expect(metric('live-1rm-bench_press'), '1RM estimat · 80 kg');
      expect(
        metric('live-pr-bench_press'),
        'Record estimat 1RM · +4 kg față de 76 kg',
      );

      // A high-repetition edit still counts actual reps/volume but cannot create
      // an Epley estimate outside the explicitly supported 1–12 repetition range.
      await tester.ensureVisible(fields.at(1));
      await tester.enterText(fields.at(1), '13');
      await tester.pumpAndSettle();
      await summary();
      expect(metric('live-reps'), '13');
      expect(metric('live-volume'), '780');
      expect(find.byKey(const ValueKey('live-1rm-bench_press')), findsNothing);
      expect(find.byKey(const ValueKey('live-pr-bench_press')), findsNothing);

      // A genuinely heavier external load can be a weight record even when
      // repetition count makes an estimated 1RM ineligible.
      await tester.ensureVisible(fields.at(0));
      await tester.enterText(fields.at(0), '61');
      await tester.pumpAndSettle();
      await summary();
      expect(metric('live-volume'), '793');
      expect(find.byKey(const ValueKey('live-1rm-bench_press')), findsNothing);
      expect(
        metric('live-pr-bench_press'),
        'Record de greutate · 61 kg (anterior 60 kg)',
      );

      await tester.ensureVisible(fields.at(1));
      await tester.enterText(fields.at(1), '0');
      await tester.pumpAndSettle();
      await summary();
      expect(metric('live-completed-sets'), '0/2');
      expect(metric('live-reps'), '0');
      expect(metric('live-volume'), '0');
      await tester.ensureVisible(find.text('Adaugă set').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adaugă set').first);
      await tester.pumpAndSettle();
      await summary();
      expect(metric('live-completed-sets'), '0/3');
      expect(metric('live-reps'), '0');
      expect(
        metric('live-planned-completed'),
        '0 din 3 seturi bifate · 3 rămase',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
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
          category: 'Personalizat',
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
      await tester.pumpWidget(const SizedBox());
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
          category: 'Personalizat',
          exercises: [RoutineExercise(exerciseId: 'bench_press', sets: 1)],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: piTheme(Brightness.dark),
          home: ActiveWorkoutScreen(store: store),
        ),
      );
      await tester.tap(find.text('Încheie'));
      await tester.pump();
      expect(store.history, isEmpty);
      expect(
        find.text('Bifează cel puțin un set efectuat înainte de a salva.'),
        findsOneWidget,
      );

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '62,5');
      await tester.pump();
      await tester.enterText(fields.at(1), '8');
      await tester.pump();
      tester.testTextInput.hide();
      await tester.ensureVisible(
        find.byTooltip('Marchează setul efectuat').first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Marchează setul efectuat').first);
      await tester.pump();
      expect(store.activeSession!.completedSets, 1);
      expect(store.activeSession!.volume, 500);
      expect(find.byKey(const ValueKey('live-pr-bench_press')), findsNothing);
      expect(find.text('Respiră. Revino mai puternic.'), findsOneWidget);

      await tester.enterText(fields.at(1), '0');
      await tester.pump();
      expect(store.activeSession!.completedSets, 0);
      await tester.enterText(fields.at(1), '8');
      await tester.pump();
      tester.testTextInput.hide();
      await tester.ensureVisible(
        find.byTooltip('Marchează setul efectuat').first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Marchează setul efectuat').first);
      await tester.pump();
      await tester.tap(find.text('Încheie'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'Mișcare controlată.',
      );
      tester.testTextInput.hide();
      await tester.tap(find.text('Salvează'));
      await tester.pumpAndSettle();
      expect(store.activeSession, isNull);
      expect(store.history.single.volume, 500);
      expect(store.history.single.notes, 'Mișcare controlată.');
      expect(tester.takeException(), isNull);
      // Dispose the local rest timer at the end of the test.
      await tester.pumpWidget(const SizedBox());
    },
  );
}
