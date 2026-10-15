import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_fit/domain/coach_plan.dart';
import 'package:pi_fit/domain/models.dart';
import 'package:pi_fit/domain/user_profile.dart';
import 'package:pi_fit/services/coach_plan_service.dart';
import 'package:pi_fit/state/app_store.dart';
import 'package:pi_fit/ui/coach_screen.dart';
import 'package:pi_fit/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DelayedPlanner extends CoachPlanService {
  final response = Completer<CoachPlanResponse>();
  @override
  Future<CoachPlanResponse> reply(
    String message, {
    required AppStore store,
    List<Map<String, String>> history = const [],
    String? targetRoutineId,
  }) => response.future;
}

void main() {
  late AppStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AppStore(await SharedPreferences.getInstance());
    await store.updateUserProfile(
      UserProfile(
        sessionsPerWeek: 2,
        sessionMinutes: 30,
        equipment: ['Bodyweight'],
      ),
    );
  });

  Future<void> show(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: piTheme(Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.3)),
          child: child!,
        ),
        home: screen,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> ask(WidgetTester tester, String message) async {
    final input = find.byKey(const Key('coach-message'));
    await tester.enterText(input, message);
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
  }

  Future<void> review(WidgetTester tester) async {
    final button = find.byKey(const Key('review-coach-plan'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> apply(WidgetTester tester) async {
    final button = find.byKey(const Key('apply-coach-plan'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'A real local program remains a preview until explicitly applied',
    (tester) async {
      final templatesBefore = jsonEncode(
        store.routines.map((r) => r.toJson()).toList(),
      );
      await show(tester, CoachScreen(store: store));
      await ask(
        tester,
        'Create a 2 day workout program for my bodyweight equipment.',
      );
      expect(store.customRoutines, isEmpty);
      expect(find.byKey(const Key('review-coach-plan')), findsOneWidget);
      await review(tester);
      expect(find.text('Your program preview'), findsOneWidget);
      expect(store.customRoutines, isEmpty);
      expect(find.text('LOCAL PROGRAM BUILDER'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Program title'), findsNothing);
      await apply(tester);
      expect(store.customRoutines, hasLength(2));
      expect(store.customRoutines.every((r) => r.exercises.isNotEmpty), isTrue);
      expect(store.history, isEmpty);
      expect(store.schedule, isEmpty);
      expect(
        jsonEncode(
          store.routines
              .where(
                (r) => !store.customRoutines.any((custom) => custom.id == r.id),
              )
              .map((r) => r.toJson())
              .toList(),
        ),
        templatesBefore,
      );
      expect(find.text('Applied to your routines'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('review-coach-plan')),
      );
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Prompt edits only the selected custom routine and preserves recorded training',
    (tester) async {
      final exercises = store.exercises
          .where(
            (item) =>
                item.equipment == 'Bodyweight' && item.category == 'Strength',
          )
          .take(2)
          .toList();
      Routine routine(String id, String name, String exerciseId) => Routine(
        id: id,
        name: name,
        subtitle: 'Saved by me',
        estimatedMinutes: 30,
        category: 'Custom',
        exercises: [RoutineExercise(exerciseId: exerciseId, sets: 2)],
      );
      final target = routine('target', 'Target routine', exercises.first.id);
      final other = routine('other', 'Other routine', exercises.last.id);
      await store.saveRoutine(target);
      await store.saveRoutine(other);
      final start = DateTime.now().subtract(const Duration(days: 1));
      store.history.add(
        WorkoutSession(
          id: 'recorded',
          routineName: target.name,
          startedAt: start,
          finishedAt: start.add(const Duration(minutes: 30)),
          exercises: [
            WorkoutExercise(
              exerciseId: exercises.first.id,
              sets: const [WorkoutSet(reps: 10, completed: true, rpe: 8)],
            ),
          ],
        ),
      );
      await store.startWorkout(target);
      final historyBefore = jsonEncode(
        store.history.map((item) => item.toJson()).toList(),
      );
      final activeBefore = jsonEncode(store.activeSession!.toJson());
      final otherBefore = jsonEncode(other.toJson());
      final templatesBefore = jsonEncode(
        store.routines
            .where((r) => r.id != target.id && r.id != other.id)
            .map((r) => r.toJson())
            .toList(),
      );
      await show(tester, CoachScreen(store: store));
      final dropdown = find.byWidgetPredicate(
        (widget) => widget is DropdownButtonFormField<String>,
      );
      await tester.scrollUntilVisible(
        dropdown,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit: Target routine').last);
      await tester.pumpAndSettle();
      await ask(tester, 'Modify this routine to use 4 sets per exercise.');
      expect(store.routineById('target')!.exercises.single.sets, 2);
      await review(tester);
      expect(
        find.text('4 sets × 10 reps · choose your own load'),
        findsOneWidget,
      );
      await apply(tester);
      expect(store.customRoutines, hasLength(2));
      expect(store.routineById('target')!.exercises.single.sets, 4);
      expect(jsonEncode(store.routineById('other')!.toJson()), otherBefore);
      expect(
        jsonEncode(store.history.map((item) => item.toJson()).toList()),
        historyBefore,
      );
      expect(jsonEncode(store.activeSession!.toJson()), activeBefore);
      expect(
        jsonEncode(
          store.routines
              .where((r) => r.id != target.id && r.id != other.id)
              .map((r) => r.toJson())
              .toList(),
        ),
        templatesBefore,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A changed planning revision is rejected before saving a reviewed plan',
    (tester) async {
      final proposal = (await CoachPlanService().reply(
        'Create a 2 day program',
        store: store,
      )).proposal!;
      await show(
        tester,
        CoachPlanReviewScreen(store: store, proposal: proposal),
      );
      await tester.runAsync(
        () =>
            store.updateUserProfile(store.profile.copyWith(sessionMinutes: 45)),
      );
      await tester.pumpAndSettle();
      await apply(tester);
      expect(store.customRoutines, isEmpty);
      final issue = find.text(
        'Your training preferences or routines changed. Generate a new plan before applying it.',
      );
      await tester.ensureVisible(issue);
      expect(issue, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('A reviewed plan cannot be applied to a different account', (
    tester,
  ) async {
    final proposal = (await CoachPlanService().reply(
      'Create a 2 day program',
      store: store,
    )).proposal!;
    await show(tester, CoachPlanReviewScreen(store: store, proposal: proposal));
    await tester.runAsync(() => store.switchAccount('new-account'));
    await tester.pumpAndSettle();
    expect(store.customRoutines, isEmpty);
    expect(find.byKey(const Key('apply-coach-plan')), findsNothing);
    expect(find.text('Your program preview'), findsNothing);
    expect(find.text(proposal.title), findsNothing);
    final issue = find.text(
      'Your account changed. Open Coach to create a plan for this profile.',
    );
    await tester.ensureVisible(issue);
    expect(issue, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'A delayed coach response is discarded after the account changes',
    (tester) async {
      final proposal = (await CoachPlanService().reply(
        'Create a 2 day program',
        store: store,
      )).proposal!;
      final planner = _DelayedPlanner();
      await show(tester, CoachScreen(store: store, service: planner));
      await tester.enterText(
        find.byKey(const Key('coach-message')),
        'Create a program',
      );
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      await tester.runAsync(() => store.switchAccount('new-account'));
      await tester.pumpAndSettle();
      planner.response.complete(
        CoachPlanResponse(
          message: 'A previous-account response',
          proposal: proposal,
          source: CoachProposalSource.local,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A previous-account response'), findsNothing);
      expect(find.byKey(const Key('review-coach-plan')), findsNothing);
      expect(store.customRoutines, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
