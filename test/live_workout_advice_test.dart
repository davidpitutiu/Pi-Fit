import 'package:flutter_test/flutter_test.dart';
import 'package:pi_fit/domain/models.dart';
import 'package:pi_fit/services/live_workout_advice.dart';

const _barbell = Exercise(
  id: 'bench',
  name: 'Bench press',
  muscle: 'Chest',
  equipment: 'Barbell',
  category: 'Strength',
  description: '',
);
const _row = Exercise(
  id: 'row',
  name: 'Cable row',
  muscle: 'Back',
  equipment: 'Cable',
  category: 'Strength',
  description: '',
);
const _bodyweight = Exercise(
  id: 'push-up',
  name: 'Push-up',
  muscle: 'Chest',
  equipment: 'Bodyweight',
  category: 'Strength',
  description: '',
);
const _cardio = Exercise(
  id: 'bike',
  name: 'Bike',
  muscle: 'Cardio',
  equipment: 'Machine',
  category: 'Cardio',
  description: '',
);
const _catalog = [_barbell, _row, _bodyweight, _cardio];

WorkoutSession _session(
  List<WorkoutExercise> exercises, {
  String id = 'active',
  DateTime? start,
  bool finished = false,
}) {
  final began = start ?? DateTime.now().subtract(const Duration(minutes: 10));
  return WorkoutSession(
    id: id,
    routineName: 'Live workout',
    startedAt: began,
    finishedAt: finished ? began.add(const Duration(minutes: 5)) : null,
    exercises: exercises,
  );
}

WorkoutExercise _exercise({
  String id = 'bench',
  double? rpe,
  double weight = 100,
  int reps = 8,
  bool next = true,
}) => WorkoutExercise(
  exerciseId: id,
  sets: [
    WorkoutSet(reps: reps, weight: weight, completed: true, rpe: rpe),
    if (next) WorkoutSet(reps: reps, weight: weight),
  ],
);

class _InvalidRatedSet extends Fake implements WorkoutSet {
  _InvalidRatedSet(this.rpe);
  @override
  final double rpe;
  @override
  bool get completed => true;
  @override
  int get reps => 8;
  @override
  double get weight => 100;
}

void main() {
  test(
    'RPE 9.5 recommends controlled reduced load and longer rest without mutation',
    () {
      final session = _session([_exercise(rpe: 9.5)]);
      final advice = workoutAdvice(
        session: session,
        catalog: _catalog,
        history: [],
      )!;
      expect(advice.title, 'Give yourself more room');
      expect(advice.restSeconds, 150);
      expect(advice.suggestedWeight, 95);
      expect(advice.exerciseId, 'bench');
      expect(advice.setIndex, 0);
      expect(advice.nextSetIndex, 1);
      expect(session.exercises.single.sets.last.weight, 100);
      expect(session.exercises.single.sets.last.completed, isFalse);
    },
  );

  test(
    'RPE 8 keeps load under user control and an unrated set prompts effort',
    () {
      final challenging = workoutAdvice(
        session: _session([_exercise(rpe: 8)]),
        catalog: _catalog,
        history: [],
      )!;
      expect(challenging.title, 'Keep the quality');
      expect(challenging.restSeconds, 120);
      expect(challenging.suggestedWeight, isNull);
      final unrated = workoutAdvice(
        session: _session([_exercise()]),
        catalog: _catalog,
        history: [],
      )!;
      expect(unrated.title, 'How hard was that set?');
      expect(unrated.suggestedWeight, isNull);
      expect(unrated.restSeconds, isNull);
      expect(unrated.text, contains('Add an effort rating'));
    },
  );

  test(
    'Bodyweight, cardio, unknown exercises and a final set never receive weighted prescriptions',
    () {
      for (final id in ['push-up', 'bike', 'missing']) {
        final advice = workoutAdvice(
          session: _session([_exercise(id: id, rpe: 10)]),
          catalog: _catalog,
          history: [],
        )!;
        expect(advice.suggestedWeight, isNull, reason: id);
        expect(advice.restSeconds, 150);
      }
      final finalSet = workoutAdvice(
        session: _session([_exercise(rpe: 10, next: false)]),
        catalog: _catalog,
        history: [],
      )!;
      expect(finalSet.nextSetIndex, isNull);
      expect(finalSet.suggestedWeight, isNull);
    },
  );

  test(
    'Current completed exercise takes priority over an earlier rated exercise',
    () {
      final session = _session([
        _exercise(rpe: 10, next: false),
        _exercise(id: 'row', rpe: null, weight: 40),
      ]);
      final advice = workoutAdvice(
        session: session,
        catalog: _catalog,
        history: [],
      )!;
      expect(advice.exerciseIndex, 1);
      expect(advice.exerciseId, 'row');
      expect(advice.title, 'How hard was that set?');
      expect(advice.suggestedWeight, isNull);
    },
  );

  test(
    'Low effort compares only completed earlier sets for the same exercise',
    () {
      final now = DateTime.now();
      final session = _session([_exercise(rpe: 6)], start: now);
      final advice = workoutAdvice(
        session: session,
        catalog: _catalog,
        history: [
          _session(
            [_exercise(rpe: 7)],
            id: 'prior',
            start: now.subtract(const Duration(days: 1)),
            finished: true,
          ),
          _session(
            [_exercise(rpe: 7)],
            id: 'prior',
            start: now.subtract(const Duration(days: 1)),
            finished: true,
          ),
          _session(
            [_exercise(id: 'row', rpe: 7)],
            id: 'other',
            start: now.subtract(const Duration(days: 2)),
            finished: true,
          ),
          _session(
            [_exercise(rpe: 7)],
            id: 'unfinished',
            start: now.subtract(const Duration(days: 1)),
          ),
          _session(
            [_exercise(rpe: 7)],
            id: 'future',
            start: now.add(const Duration(days: 1)),
            finished: true,
          ),
        ],
      )!;
      expect(advice.title, 'Steady progress');
      expect(advice.restSeconds, 90);
      expect(advice.text, contains('history has 1 rated'));
      expect(advice.suggestedWeight, isNull);
    },
  );

  test('Invalid checked values do not become personalized load advice', () {
    final advice = workoutAdvice(
      session: _session([_exercise(rpe: 10, weight: double.nan)]),
      catalog: _catalog,
      history: [],
    )!;
    expect(advice.title, 'Start with control');
    expect(advice.suggestedWeight, isNull);
    expect(advice.setIndex, isNull);
    expect(
      workoutAdvice(session: _session([]), catalog: _catalog, history: []),
      isNull,
    );
  });
  test('Explicit focus supports returning to an earlier exercise', () {
    final advice = workoutAdvice(
      session: _session([
        _exercise(rpe: 8, weight: 40),
        _exercise(id: 'row', rpe: 10, weight: 80),
      ]),
      catalog: _catalog,
      history: [],
      focusedExerciseIndex: 0,
    )!;
    expect(advice.exerciseId, 'bench');
    expect(advice.exerciseIndex, 0);
    expect(advice.title, 'Keep the quality');
    expect(advice.suggestedWeight, isNull);
  });

  test(
    'Invalid effort ratings prompt a valid rating rather than inventing feedback',
    () {
      for (final rpe in [0.0, 10.5, double.nan, double.infinity]) {
        final advice = workoutAdvice(
          session: _session([
            WorkoutExercise(
              exerciseId: 'bench',
              sets: [
                _InvalidRatedSet(rpe),
                const WorkoutSet(weight: 100, reps: 8),
              ],
            ),
          ]),
          catalog: _catalog,
          history: [],
        )!;
        expect(advice.title, 'How hard was that set?', reason: '$rpe');
        expect(advice.suggestedWeight, isNull);
        expect(advice.restSeconds, isNull);
      }
    },
  );

  test(
    'Rounding never recommends zero or an unchanged load as a reduction',
    () {
      for (final weight in [0.1, 0.5, 2.5, 5.0]) {
        final advice = workoutAdvice(
          session: _session([_exercise(rpe: 10, weight: weight)]),
          catalog: _catalog,
          history: [],
        )!;
        expect(advice.suggestedWeight, isNull, reason: '$weight kg');
      }
    },
  );
}
