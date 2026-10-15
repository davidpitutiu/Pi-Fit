import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_fit/domain/models.dart';
import 'package:pi_fit/state/app_store.dart';
import 'package:pi_fit/ui/theme.dart';
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
    'exercise search ignores Romanian accents and exposes technique',
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
      await tester.tap(find.text('Împins la bancă cu bara'));
      await tester.pumpAndSettle();
      expect(find.text('Mușchi secundari'), findsOneWidget);
      expect(find.text('Triceps, umeri anteriori'), findsOneWidget);
      expect(find.text('Cum execuți'), findsOneWidget);
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
      await tester.tap(find.byTooltip('Marchează setul efectuat'));
      await tester.pump();
      expect(store.activeSession!.completedSets, 1);
      expect(store.activeSession!.volume, 500);
      expect(find.text('Respiră. Revino mai puternic.'), findsOneWidget);

      await tester.enterText(fields.at(1), '0');
      await tester.pump();
      expect(store.activeSession!.completedSets, 0);
      await tester.enterText(fields.at(1), '8');
      await tester.pump();
      tester.testTextInput.hide();
      await tester.tap(find.byTooltip('Marchează setul efectuat'));
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
