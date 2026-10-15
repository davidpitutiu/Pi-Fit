import 'package:flutter_test/flutter_test.dart';
import 'package:pi_fit/domain/models.dart';
import 'package:pi_fit/domain/muscle_focus.dart';

const bench = Exercise(
  id: 'bench',
  name: 'Bench press',
  muscle: 'Chest',
  equipment: 'Barbell',
  description: '',
  secondaryMuscles: 'Triceps, Shoulders, triceps, Chest, Other, ',
);
const squat = Exercise(
  id: 'squat',
  name: 'Squat',
  muscle: 'Quadriceps',
  equipment: 'Barbell',
  description: '',
  secondaryMuscles: 'Glutes',
);
const triceps = Exercise(
  id: 'extension',
  name: 'Extension',
  muscle: 'Triceps',
  equipment: 'Cable',
  description: '',
);
const shoulders = Exercise(
  id: 'press',
  name: 'Press',
  muscle: 'Shoulders',
  equipment: 'Dumbbells',
  description: '',
);
const glutes = Exercise(
  id: 'bridge',
  name: 'Bridge',
  muscle: 'Glutes',
  equipment: 'Bodyweight',
  description: '',
);
const calves = Exercise(
  id: 'stretch',
  name: 'Calf stretch',
  muscle: 'Calves',
  equipment: 'Bodyweight',
  description: '',
  category: 'Mobility',
);
const cardio = Exercise(
  id: 'run',
  name: 'Run',
  muscle: 'Cardio',
  equipment: 'Bodyweight',
  description: '',
  category: 'Cardio',
);
const jump = Exercise(
  id: 'jump',
  name: 'Jump',
  muscle: 'Quadriceps',
  equipment: 'Bodyweight',
  description: '',
  category: 'Plyometrics',
);
const missing = Exercise(
  id: 'missing',
  name: 'Unclassified strength',
  muscle: '',
  equipment: 'Dumbbells',
  description: '',
);
const other = Exercise(
  id: 'other',
  name: 'Other strength',
  muscle: 'Other',
  equipment: 'Dumbbells',
  description: '',
);
const catalog = [
  bench,
  squat,
  triceps,
  shoulders,
  glutes,
  calves,
  cardio,
  jump,
  missing,
  other,
];

WorkoutSession session(
  String id,
  DateTime date, {
  String exerciseId = 'bench',
  int sets = 1,
  List<WorkoutSet>? values,
  DateTime? finishedAt,
}) => WorkoutSession(
  id: id,
  routineName: 'Training',
  startedAt: date,
  finishedAt: finishedAt ?? date.add(const Duration(minutes: 30)),
  exercises: [
    WorkoutExercise(
      exerciseId: exerciseId,
      sets:
          values ??
          List.generate(
            sets,
            (_) => const WorkoutSet(reps: 8, weight: 50, completed: true),
          ),
    ),
  ],
);

void main() {
  final now = DateTime(2026, 10, 28, 20);
  MuscleFocusSummary focus(
    List<WorkoutSession> history, {
    int days = 28,
    List<Exercise> exercises = catalog,
  }) => buildMuscleFocus(
    history: history,
    exercises: exercises,
    days: days,
    now: now,
  );

  test(
    'empty history retains every distinct named primary catalog group alphabetically',
    () {
      final result = focus([]);
      expect(result.groups.map((group) => group.muscle), [
        'Calves',
        'Chest',
        'Glutes',
        'Quadriceps',
        'Shoulders',
        'Triceps',
      ]);
      expect(result.totalPrimarySets, 0);
      expect(result.unattributedSets, 0);
      expect(
        result.groups.every(
          (group) =>
              group.primarySets == 0 &&
              group.secondarySets == 0 &&
              group.share == 0,
        ),
        isTrue,
      );
      expect(result.groups.every((group) => group.exercises.isEmpty), isTrue);
      expect(() => result.groups.clear(), throwsUnsupportedError);
    },
  );

  test('compound secondary involvement never inflates main shares', () {
    final result = focus([
      session('bench', DateTime(2026, 10, 20), sets: 3),
      session('squat', DateTime(2026, 10, 21), exerciseId: 'squat', sets: 2),
    ]);
    final chest = result.groups.singleWhere((group) => group.muscle == 'Chest');
    final quads = result.groups.singleWhere(
      (group) => group.muscle == 'Quadriceps',
    );
    final tricepsGroup = result.groups.singleWhere(
      (group) => group.muscle == 'Triceps',
    );
    expect(result.totalPrimarySets, 5);
    expect(chest.primarySets, 3);
    expect(chest.secondarySets, 0);
    expect(chest.share, 0.6);
    expect(chest.percentage, 60);
    expect(quads.share, 0.4);
    expect(tricepsGroup.primarySets, 0);
    expect(tricepsGroup.share, 0);
    expect(
      tricepsGroup.secondarySets,
      3,
      reason: 'Duplicate secondary names count once per set.',
    );
    expect(tricepsGroup.exercises.single.exerciseId, 'bench');
    expect(tricepsGroup.exercises.single.primarySets, 0);
    expect(tricepsGroup.exercises.single.secondarySets, 3);
    expect(
      result.groups.fold<double>(0, (sum, group) => sum + group.share),
      closeTo(1, 1e-12),
    );
    expect(
      result.groups
          .singleWhere((group) => group.muscle == 'Glutes')
          .secondarySets,
      2,
    );
    expect(() => chest.exercises.clear(), throwsUnsupportedError);
  });

  test(
    'local calendar windows include midnight, exclude future and expose real 7/28/90 totals',
    () {
      final history = [
        session('ninety', DateTime(2026, 9, 1, 12)),
        session('twentyeight', DateTime(2026, 10, 1)),
        session('seven', DateTime(2026, 10, 22)),
        session('before-seven', DateTime(2026, 10, 21, 23, 59, 59)),
        session('future', now.add(const Duration(seconds: 1))),
        session(
          'future-finish',
          now.subtract(const Duration(minutes: 1)),
          finishedAt: now.add(const Duration(seconds: 1)),
        ),
        session('now', now, finishedAt: now),
      ];
      expect(focus(history, days: 7).totalPrimarySets, 2);
      expect(focus(history, days: 28).totalPrimarySets, 4);
      expect(focus(history, days: 90).totalPrimarySets, 5);
      expect(focus(history, days: 7).start, DateTime(2026, 10, 22));
      expect(() => focus(history, days: 30), throwsArgumentError);
    },
  );

  test(
    'duplicate sessions, unfinished sessions, unchecked and invalid sets are ignored',
    () {
      final complete = session(
        'one',
        DateTime(2026, 10, 20),
        values: const [
          WorkoutSet(reps: 8, weight: 40, completed: true),
          WorkoutSet(reps: 8, weight: 0, completed: true),
          WorkoutSet(reps: 8, weight: 40, completed: false),
          WorkoutSet(reps: 0, weight: 40, completed: true),
          WorkoutSet(reps: 8, weight: -1, completed: true),
          WorkoutSet(reps: 8, weight: double.nan, completed: true),
          WorkoutSet(reps: 100000, weight: 100000, completed: true),
        ],
      );
      final unfinished = WorkoutSession(
        id: 'active',
        routineName: 'Active',
        startedAt: DateTime(2026, 10, 20),
        exercises: const [
          WorkoutExercise(
            exerciseId: 'bench',
            sets: [WorkoutSet(completed: true)],
          ),
        ],
      );
      final result = focus([complete, complete, unfinished]);
      expect(
        result.totalPrimarySets,
        2,
        reason: 'Bodyweight/zero external load strength sets remain real sets.',
      );
      expect(
        result.groups
            .singleWhere((group) => group.muscle == 'Chest')
            .primarySets,
        2,
      );
    },
  );

  test(
    'known non-strength categories are excluded and unmatched primary data stays unattributed',
    () {
      final result = focus([
        session(
          'mobility',
          DateTime(2026, 10, 20),
          exerciseId: 'stretch',
          sets: 3,
        ),
        session('cardio', DateTime(2026, 10, 20), exerciseId: 'run', sets: 4),
        session('jump', DateTime(2026, 10, 20), exerciseId: 'jump', sets: 2),
        session(
          'unknown',
          DateTime(2026, 10, 20),
          exerciseId: 'removed',
          sets: 2,
        ),
        session(
          'missing',
          DateTime(2026, 10, 20),
          exerciseId: 'missing',
          sets: 1,
        ),
        session('other', DateTime(2026, 10, 20), exerciseId: 'other', sets: 1),
      ]);
      expect(result.totalPrimarySets, 0);
      expect(result.unattributedSets, 4);
      expect(
        result.groups.every(
          (group) => group.primarySets == 0 && group.secondarySets == 0,
        ),
        isTrue,
      );
      expect(result.explanation, contains('does not change the percentages'));
    },
  );

  test(
    'legacy strength category and canonical secondary names work without duplicate groups',
    () {
      const legacy = Exercise(
        id: 'legacy',
        name: 'Legacy press',
        muscle: ' Chest ',
        equipment: 'Bară',
        description: '',
        category: 'Forță',
        secondaryMuscles: ' TRICEPS, Triceps, chest ',
      );
      final result = focus(
        [session('legacy', DateTime(2026, 10, 20), exerciseId: 'legacy')],
        exercises: [...catalog, legacy],
      );
      expect(
        result.groups.where((group) => group.muscle.toLowerCase() == 'chest'),
        hasLength(1),
      );
      expect(result.totalPrimarySets, 1);
      expect(
        result.groups
            .singleWhere((group) => group.muscle == 'Chest')
            .primarySets,
        1,
      );
      expect(
        result.groups
            .singleWhere((group) => group.muscle == 'Triceps')
            .secondarySets,
        1,
      );
    },
  );
}
