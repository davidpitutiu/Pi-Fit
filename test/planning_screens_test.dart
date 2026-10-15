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
    expect(find.text('200'), findsNWidgets(2));
    final record = find.text('20 kg × 10');
    await tester.ensureVisible(record);
    expect(record, findsOneWidget);
    expect(find.text('80 kg × 10'), findsNothing);
    final history = find.text('Sesiune verificată');
    await tester.ensureVisible(history);
    await tester.tap(history);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 seturi'), findsNWidgets(2));
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
        matching: find.text('1RM estimat · 26.7 kg'),
      ),
      findsOneWidget,
    );
    expect(find.text('80 kg × 10'), findsOneWidget);
    await tester.ensureVisible(find.text('Tehnică bună'));
    expect(find.text('Tehnică bună'), findsOneWidget);
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
          routineName: 'Sesiune $id',
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
    expect(find.text('4 / 12 zile active'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
    await tester.ensureVisible(find.text('Vezi calculul complet'));
    await tester.tap(find.text('Vezi calculul complet'));
    await tester.pumpAndSettle();
    expect(find.text('Cum se calculează scorul'), findsOneWidget);
    expect(find.text('4 / 12 · 23.3 din 70 puncte'), findsOneWidget);
    expect(find.text('1 / 4 · 7.5 din 30 puncte'), findsOneWidget);
    final formula = find.textContaining('Scor = 70');
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
        routineName: 'Sesiune $id',
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
    for (final label in [
      'antrenamente salvate',
      'seturi completate',
      'zile active',
    ]) {
      await tester.ensureVisible(find.text(label));
      expect(metric(label, '1'), findsOneWidget);
    }
    await tester.ensureVisible(find.text('kg · volum extern'));
    expect(metric('kg · volum extern', '200'), findsOneWidget);
    await tester.ensureVisible(find.text('Seturi pe grupa principală'));
    expect(find.text('1 set'), findsOneWidget);
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
      expect(find.text('fără date'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      final choose = find.text('Alege un antrenament');
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
        routineName: 'Antrenament cu descriere lungă',
        startedAt: start,
        finishedAt: start.add(const Duration(minutes: 45)),
        notes: 'Pauze de două minute între seturi.',
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
      'Ultimele 28 de zile',
      'Evoluția antrenamentelor',
      'Seturi pe grupa principală',
      'Recorduri personale',
      'Antrenament cu descriere lungă',
    ]) {
      await tester.ensureVisible(find.text(title));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Antrenament cu descriere lungă'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Set completat'), findsOneWidget);
    expect(find.byTooltip('Set planificat, neefectuat'), findsOneWidget);
    await tester.ensureVisible(find.text('Pauze de două minute între seturi.'));
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
      expect(find.text('Ultimele 90 de zile'), findsOneWidget);
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
      final values = find.text('Vezi valorile');
      await tester.ensureVisible(values);
      await tester.tap(values);
      await tester.pumpAndSettle();
      expect(find.text('Minute · valorile graficului'), findsOneWidget);
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
            routineName: 'Progres',
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
      final estimated = find.widgetWithText(ChoiceChip, '1RM estimat');
      await tester.ensureVisible(estimated);
      await tester.tap(estimated);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(value).data, '40 kg');
      expect(
        find.textContaining('Epley, numai seturi de 1–12'),
        findsOneWidget,
      );
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
      final title = find.text('Revii. Construiești. Repeți.');
      await tester.ensureVisible(title);
      final streakCard = find.ancestor(
        of: title,
        matching: find.byType(PiCard),
      );
      expect(
        find.descendant(of: streakCard, matching: find.text('2')),
        findsNWidgets(2),
      );
      expect(find.text('Săptămâna aceasta · 0 / 3 zile'), findsOneWidget);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(find.text('Cum funcționează seria'), findsOneWidget);
      expect(
        find.textContaining('Obiectivul curent: 3 zile active'),
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
    expect(find.text('1 / 12 zile active'), findsOneWidget);
    expect(find.text('fără date'), findsNothing);
    await store.updateUserProfile(store.profile.copyWith(sessionsPerWeek: 4));
    await tester.pumpAndSettle();
    expect(find.text('1 / 16 zile active'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
