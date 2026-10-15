import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_fit/domain/exercise_catalog.dart';
import 'package:pi_fit/domain/models.dart';

Map<String, dynamic> persisted(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  group('Exercise catalog', () {
    test('has unique IDs and actionable original coaching instructions', () {
      expect(exerciseCatalog.length, greaterThanOrEqualTo(50));
      expect(
        exerciseCatalog.map((exercise) => exercise.id).toSet().length,
        exerciseCatalog.length,
      );
      for (final exercise in exerciseCatalog) {
        expect(exercise.id, isNotEmpty, reason: exercise.name);
        expect(exercise.muscle, isNotEmpty, reason: exercise.name);
        expect(exercise.equipment, isNotEmpty, reason: exercise.name);
        expect(exercise.description, isNotEmpty, reason: exercise.name);
        expect(
          exercise.steps.length,
          greaterThanOrEqualTo(3),
          reason: exercise.name,
        );
        expect(exercise.tips, isNotEmpty, reason: exercise.name);
      }
    });

    test(
      'every template references known exercises and has valid set targets',
      () {
        final exerciseIds = exerciseCatalog
            .map((exercise) => exercise.id)
            .toSet();
        expect(routineTemplates.length, greaterThanOrEqualTo(6));
        expect(
          routineTemplates.map((routine) => routine.id).toSet().length,
          routineTemplates.length,
        );
        for (final routine in routineTemplates) {
          expect(routine.estimatedMinutes, greaterThan(0));
          expect(routine.exercises, isNotEmpty);
          for (final exercise in routine.exercises) {
            expect(
              exerciseIds,
              contains(exercise.exerciseId),
              reason: routine.name,
            );
            expect(exercise.sets, greaterThan(0));
            expect(exercise.reps, greaterThan(0));
            expect(exercise.weight, greaterThanOrEqualTo(0));
          }
        }
      },
    );

    test('unknown exercise IDs can be handled without throwing', () {
      expect(exerciseById('missing'), isNull);
      expect(exerciseById('bench_press')?.muscle, 'Piept');
    });
  });

  group('Persistence', () {
    test('exercise retains steps and tips after JSON serialization', () {
      final original = exerciseCatalog.first;
      final restored = Exercise.fromJson(persisted(original.toJson()));
      expect(restored.toJson(), original.toJson());
    });

    test('routine retains all set prescriptions after JSON serialization', () {
      final original = routineTemplates.first.copyWith(
        id: 'custom-1',
        name: 'Rutina mea',
        exercises: [
          const RoutineExercise(
            exerciseId: 'bench_press',
            sets: 4,
            reps: 8,
            weight: 42.5,
          ),
        ],
      );
      final restored = Routine.fromJson(persisted(original.toJson()));
      expect(restored.toJson(), original.toJson());
      expect(restored.totalSets, 4);
      expect(restored.exercises.single.weight, 42.5);
    });

    test('scheduled reminders retain exact dates and enabled state', () {
      final date = DateTime.utc(2026, 11, 7, 18, 30);
      final original = ScheduledWorkout(
        id: 'schedule-1',
        routineId: 'push',
        date: date,
        reminder: false,
      );
      final restored = ScheduledWorkout.fromJson(persisted(original.toJson()));
      expect(restored.toJson(), original.toJson());
      expect(restored.date, date);
      expect(restored.reminder, isFalse);
    });

    test(
      'session preserves notes, dates, all sets, and fractional weights',
      () {
        final start = DateTime.utc(2026, 10, 15, 9);
        final original = WorkoutSession(
          id: 'session-1',
          routineName: 'Push day',
          startedAt: start,
          finishedAt: start.add(const Duration(minutes: 42)),
          notes: 'Control mai bun la ultima serie.',
          exercises: const [
            WorkoutExercise(
              exerciseId: 'bench_press',
              sets: [
                WorkoutSet(reps: 8, weight: 42.5, completed: true),
                WorkoutSet(reps: 8, weight: 42.5),
              ],
            ),
          ],
        );
        final restored = WorkoutSession.fromJson(persisted(original.toJson()));
        expect(restored.toJson(), original.toJson());
        expect(restored.duration, const Duration(minutes: 42));
        expect(restored.exercises.single.sets.first.weight, 42.5);
        expect(restored.completedSets, 1);
        expect(restored.volume, 340);
      },
    );

    test('weights encoded as integer JSON numbers restore as doubles', () {
      final set = WorkoutSet.fromJson({
        'reps': 10,
        'weight': 20,
        'completed': true,
      });
      expect(set.weight, 20.0);
      final prescription = RoutineExercise.fromJson({
        'exerciseId': 'bench_press',
        'sets': 3,
        'reps': 10,
        'weight': 20,
      });
      expect(prescription.weight, 20.0);
    });
  });

  group('Training calculations', () {
    test('only completed sets contribute to workout volume and completion', () {
      final session = WorkoutSession(
        id: 'volume-1',
        routineName: 'Test',
        startedAt: DateTime.utc(2026, 10, 15),
        exercises: const [
          WorkoutExercise(
            exerciseId: 'bench_press',
            sets: [
              WorkoutSet(reps: 8, weight: 50, completed: true),
              WorkoutSet(reps: 6, weight: 55, completed: true),
              WorkoutSet(reps: 10, weight: 100),
            ],
          ),
          WorkoutExercise(
            exerciseId: 'push_up',
            sets: [WorkoutSet(reps: 12, completed: true)],
          ),
        ],
      );
      expect(session.volume, 730);
      expect(session.completedSets, 3);
      expect(session.totalSets, 4);
    });

    test('starting from a routine creates separate, unfinished sets', () {
      final routine = routineTemplates.first;
      final start = DateTime.utc(2026, 10, 15);
      final session = WorkoutSession.fromRoutine(routine, startedAt: start);
      expect(session.routineName, routine.name);
      expect(session.startedAt, start);
      expect(session.finishedAt, isNull);
      expect(session.isFinished, isFalse);
      expect(session.totalSets, routine.totalSets);
      expect(session.completedSets, 0);
      expect(session.volume, 0);
      final firstSet = session.exercises.first.sets.first;
      final updated = firstSet.copyWith(weight: 25, completed: true);
      expect(updated.volume, routine.exercises.first.reps * 25);
      expect(firstSet.completed, isFalse);
      expect(firstSet.weight, routine.exercises.first.weight);
    });

    test('copyWith preserves an existing finish date and never yields negative duration', () {
      final start = DateTime.utc(2026, 10, 15, 10);
      final finish = start.add(const Duration(minutes: 35));
      final session = WorkoutSession(
        id: 'finish-1',
        routineName: 'Test',
        startedAt: start,
        finishedAt: finish,
        exercises: const [],
      );
      expect(session.copyWith(notes: 'Done').finishedAt, finish);
      expect(
        session
            .copyWith(finishedAt: start.subtract(const Duration(seconds: 1)))
            .duration,
        Duration.zero,
      );
    });
  });
}
