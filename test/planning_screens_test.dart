import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_fit/domain/models.dart';
import 'package:pi_fit/state/app_store.dart';
import 'package:pi_fit/ui/planning_screens.dart';
import 'package:pi_fit/ui/theme.dart';
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
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: piTheme(Brightness.dark), home: screen),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Single scheduling saves one future session without reminders', (
    tester,
  ) async {
    await showScreen(tester, CalendarScreen(store: store), width: 320);
    await tester.tap(find.text('Programează antrenamente'));
    await tester.pumpAndSettle();
    final save = find.text('Adaugă 1 sesiune');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(store.schedule, hasLength(1));
    expect(store.schedule.single.date.isAfter(DateTime.now()), isTrue);
    expect(store.schedule.single.reminder, isFalse);
    expect(find.text('1 antrenament salvat în calendar.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bulk scheduling previews and persists all 28 selected dates', (
    tester,
  ) async {
    await showScreen(tester, CalendarScreen(store: store));
    await tester.tap(find.text('Programează antrenamente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('În serie'));
    await tester.pumpAndSettle();

    for (final day in ['Lu', 'Ma', 'Mi', 'Jo', 'Vi', 'Sâ', 'Du']) {
      final chip = find.widgetWithText(FilterChip, day);
      await tester.ensureVisible(chip);
      if (!tester.widget<FilterChip>(chip).selected) {
        await tester.tap(chip);
        await tester.pumpAndSettle();
      }
    }
    final save = find.text('Adaugă 28 sesiuni');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(store.schedule, hasLength(28));
    expect(store.schedule.map((event) => event.date).toSet(), hasLength(28));
    expect(
      store.schedule.every((event) => event.date.isAfter(DateTime.now())),
      isTrue,
    );
    expect(find.text('28 antrenamente salvate în calendar.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Progress ignores unchecked sets in volume and records', (
    tester,
  ) async {
    final start = DateTime.now().subtract(const Duration(hours: 2));
    store.history.add(
      WorkoutSession(
        id: 'test-session',
        routineName: 'Sesiune verificată',
        startedAt: start,
        finishedAt: start.add(const Duration(minutes: 35)),
        notes: 'Tehnică bună',
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
    expect(find.text('200'), findsOneWidget);
    final record = find.text('20 kg');
    await tester.ensureVisible(record);
    expect(record, findsOneWidget);
    expect(find.text('80 kg'), findsNothing);
    final history = find.text('Sesiune verificată');
    await tester.ensureVisible(history);
    await tester.tap(history);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 seturi'), findsOneWidget);
    expect(find.text('20 kg × 10'), findsOneWidget);
    expect(find.text('80 kg × 10'), findsOneWidget);
    await tester.ensureVisible(find.text('Tehnică bună'));
    expect(find.text('Tehnică bună'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
