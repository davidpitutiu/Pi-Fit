import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pi_fit/domain/coach_plan.dart';
import 'package:pi_fit/domain/models.dart';
import 'package:pi_fit/domain/user_profile.dart';
import 'package:pi_fit/services/coach_plan_service.dart';
import 'package:pi_fit/services/coach_service.dart';
import 'package:pi_fit/services/firebase_gateway.dart';
import 'package:pi_fit/state/app_store.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'alice';
}

class _Gateway extends Fake implements FirebaseGateway {
  @override
  User get currentUser => _User();
}

class _Remote extends CoachService {
  _Remote(this.result) : super(endpoint: 'https://coach.example.invalid');
  final Future<CoachReply> result;
  String? sentContext;
  @override
  Future<CoachReply> replyDetailed(
    String message, {
    required String context,
    String? localContext,
    List<Map<String, String>> history = const [],
    bool allowRemote = true,
  }) {
    sentContext = context;
    return result;
  }
}

Future<AppStore> _store({UserProfile? profile}) async {
  SharedPreferences.setMockInitialValues({});
  final store = AppStore(await SharedPreferences.getInstance());
  await store.updateUserProfile(
    profile ?? UserProfile(equipment: ['Bodyweight'], sessionMinutes: 30),
  );
  return store;
}

const _routine = Routine(
  id: 'mine',
  name: 'My routine',
  subtitle: 'Test',
  estimatedMinutes: 30,
  category: 'Custom',
  exercises: [
    RoutineExercise(exerciseId: 'push_up', sets: 2, reps: 10, weight: 20),
  ],
);

void main() {
  test(
    'a different active auth account cannot receive the stored profile context',
    () async {
      final store = await _store();
      await store.switchAccount('bob');
      await store.updateUserProfile(
        UserProfile(coachConsent: true, equipment: ['Bodyweight']),
      );
      final remote = _Remote(Completer<CoachReply>().future);
      // The injected Auth identity is Alice while the loaded local scope is Bob.
      final response = await CoachPlanService(
        coach: remote,
        gateway: _Gateway(),
      ).reply('Create a 2 day workout program', store: store);
      expect(remote.sentContext, isNull);
      expect(response.source, CoachProposalSource.local);
      expect(response.proposal!.accountId, 'bob');
    },
  );

  test(
    'the suggested add-exercise and fit-duration prompts produce actionable custom edits',
    () async {
      final store = await _store();
      await store.saveRoutine(_routine);
      final added = (await CoachPlanService().reply(
        'Add an exercise to this routine.',
        store: store,
        targetRoutineId: 'mine',
      )).proposal!;
      expect(added.routines.single.exercises, hasLength(2));
      final large = _routine.copyWith(
        estimatedMinutes: 60,
        exercises: const [
          RoutineExercise(exerciseId: 'push_up'),
          RoutineExercise(exerciseId: 'dead_bug'),
          RoutineExercise(exerciseId: 'bodyweight_squat'),
          RoutineExercise(exerciseId: 'superman'),
          RoutineExercise(exerciseId: 'glute_bridge'),
        ],
      );
      await store.saveRoutine(large);
      final shorter = (await CoachPlanService().reply(
        'Modify this routine to fit 20 minutes.',
        store: store,
        targetRoutineId: 'mine',
      )).proposal!;
      expect(shorter.routines.single.estimatedMinutes, 20);
      expect(shorter.routines.single.exercises, hasLength(2));
      expect(store.customRoutines.single.exercises, hasLength(5));
    },
  );

  test(
    'declining remote sharing uses local equipment and literal limitations without a network call',
    () async {
      final store = await _store(
        profile: UserProfile(
          equipment: ['Full gym'],
          sessionMinutes: 45,
          limitations: 'No overhead movements',
          coachConsent: false,
        ),
      );
      final remote = _Remote(Completer<CoachReply>().future);
      final response = await CoachPlanService(
        coach: remote,
        gateway: _Gateway(),
      ).reply('Create a 4 day workout program', store: store);
      expect(remote.sentContext, isNull);
      expect(response.source, CoachProposalSource.local);
      expect(store.coachContext, isNot(contains('No overhead movements')));
      final ids = response.proposal!.routines
          .expand((routine) => routine.exercises)
          .map((item) => item.exerciseId);
      expect(ids, isNot(contains('overhead_press')));
      expect(ids, isNot(contains('dumbbell_shoulder_press')));
      await store.saveRoutine(_routine);
      final rejected = await CoachPlanService().reply(
        'Add overhead press exercise to my routine',
        store: store,
        targetRoutineId: 'mine',
      );
      expect(rejected.proposal, isNull);
    },
  );

  test(
    'local program respects requested frequency, time and equipment without writing data',
    () async {
      final store = await _store(
        profile: UserProfile(
          sessionsPerWeek: 5,
          sessionMinutes: 30,
          equipment: ['Dumbbells'],
        ),
      );
      final before = jsonEncode(store.exportData());
      final response = await CoachPlanService().reply(
        'Create a 3 day workout program',
        store: store,
      );
      final proposal = response.proposal!;
      expect(response.source, CoachProposalSource.local);
      expect(proposal.routines, hasLength(3));
      expect(
        proposal.routines.every(
          (routine) =>
              routine.estimatedMinutes == 30 && routine.exercises.length <= 3,
        ),
        isTrue,
      );
      for (final routine in proposal.routines) {
        for (final exercise in routine.exercises) {
          final actual = store.exerciseById(exercise.exerciseId);
          expect(
            {
              'Dumbbells',
              'Bodyweight',
              'Gantere',
              'Greutatea corpului',
            }.contains(actual.equipment),
            isTrue,
          );
          expect(exercise.weight, 0);
        }
      }
      expect(jsonEncode(store.exportData()), before);
      expect(response.message, contains('Nothing has been saved'));
    },
  );

  test(
    'a reviewed proposal applies once and duplicate application is idempotent',
    () async {
      final store = await _store();
      final proposal = (await CoachPlanService().reply(
        'Create a 2 day program',
        store: store,
      )).proposal!;
      await store.applyCoachProposal(proposal);
      expect(store.customRoutines, hasLength(2));
      await store.applyCoachProposal(proposal);
      expect(store.customRoutines, hasLength(2));
      expect(store.appliedCoachProposalIds, contains(proposal.id));
    },
  );

  test(
    'add and replace target a custom routine revision and reset replacement load',
    () async {
      final store = await _store();
      await store.saveRoutine(_routine);
      final add = (await CoachPlanService().reply(
        'Add dead bug exercise to my routine',
        store: store,
        targetRoutineId: 'mine',
      )).proposal!;
      expect(add.routines.single.targetRoutineId, 'mine');
      expect(
        add.routines.single.expectedRevision,
        coachRoutineRevision(_routine),
      );
      expect(
        add.routines.single.exercises.map((item) => item.exerciseId),
        contains('dead_bug'),
      );
      expect(store.customRoutines.single.exercises, hasLength(1));
      final replacement = (await CoachPlanService().reply(
        'Replace push up with dead bug in my routine',
        store: store,
        targetRoutineId: 'mine',
      )).proposal!;
      expect(
        replacement.routines.single.exercises.single.exerciseId,
        'dead_bug',
      );
      expect(replacement.routines.single.exercises.single.weight, 0);
      await store.applyCoachProposal(replacement);
      expect(store.customRoutines.single.id, 'mine');
      expect(
        store.customRoutines.single.exercises.single.exerciseId,
        'dead_bug',
      );
      await expectLater(store.applyCoachProposal(add), throwsStateError);
    },
  );

  test(
    'pain, nutrition and general questions do not create action proposals',
    () async {
      final store = await _store();
      for (final message in [
        'Create a workout plan but my knee hurts',
        'Create a diet plan',
        'How much rest between sets?',
      ]) {
        final response = await CoachPlanService().reply(message, store: store);
        expect(response.proposal, isNull);
      }
      expect(store.customRoutines, isEmpty);
    },
  );

  test(
    'unknown catalog IDs and non-custom edit targets are rejected',
    () async {
      final store = await _store();
      final proposal = (await CoachPlanService().reply(
        'Create a 1 day workout program',
        store: store,
      )).proposal!;
      final wire =
          jsonDecode(jsonEncode(proposal.toWireJson())) as Map<String, dynamic>;
      ((wire['routines'] as List).first['exercises'] as List)
              .first['exerciseId'] =
          'invented';
      expect(
        () => CoachProposal.fromWireJson(
          wire,
          accountId: null,
          baseRevision: proposal.baseRevision,
          source: CoachProposalSource.online,
          catalog: store.exercises,
          customRoutines: store.customRoutines,
        ),
        throwsFormatException,
      );
      final editTemplate = await CoachPlanService().reply(
        'Add dead bug exercise',
        store: store,
        targetRoutineId: store.routines.last.id,
      );
      expect(editTemplate.proposal, isNull);
    },
  );

  test(
    'schedule preview is editable, changes proposal ID and does not schedule until apply',
    () async {
      final store = await _store();
      final proposal = (await CoachPlanService().reply(
        'Create a 3 day program and schedule bulk for 2 weeks at 18:30',
        store: store,
      )).proposal!;
      expect(proposal.schedule!.weeks, 2);
      expect(proposal.schedule!.hour, 18);
      expect(proposal.schedule!.minute, 30);
      expect(store.schedule, isEmpty);
      final edited = proposal.copyWith(
        schedule: proposal.schedule!.copyWith(hour: 19),
      );
      expect(edited.id, isNot(proposal.id));
      await store.applyCoachProposal(edited);
      expect(store.schedule, isNotEmpty);
      expect(store.schedule.every((item) => item.date.hour == 19), isTrue);
    },
  );

  test(
    'remote response stays bound to the captured account across an account switch',
    () async {
      final store = await _store();
      await store.switchAccount('alice');
      await store.updateUserProfile(
        UserProfile(coachConsent: true, equipment: ['Bodyweight']),
      );
      final local = (await CoachPlanService().reply(
        'Create a 2 day program',
        store: store,
      )).proposal!;
      final pending = Completer<CoachReply>();
      final remote = _Remote(pending.future);
      final request = CoachPlanService(
        coach: remote,
        gateway: _Gateway(),
      ).reply('Create a 2 day program', store: store);
      expect(remote.sentContext, contains('planning'));
      await store.switchAccount('bob');
      pending.complete(
        CoachReply('Review this plan.', proposal: local.toWireJson()),
      );
      final response = await request;
      expect(response.proposal!.accountId, 'alice');
      await expectLater(
        store.applyCoachProposal(response.proposal!),
        throwsStateError,
      );
      expect(store.customRoutines, isEmpty);
    },
  );
}
