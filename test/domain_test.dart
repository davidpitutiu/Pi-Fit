import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_fit/domain/exercise_catalog.dart';
import 'package:pi_fit/domain/models.dart';

Map<String, dynamic> persisted(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  group('Exercise catalog', () {
    test('has a full external catalog and original coaching instructions', () {
      expect(exerciseCatalog.length, 878);
      expect(
        exerciseCatalog.map((exercise) => exercise.id).toSet().length,
        exerciseCatalog.length,
      );
      for (final exercise in exerciseCatalog) {
        expect(exercise.id, isNotEmpty, reason: exercise.name);
        expect(exercise.muscle, isNotEmpty, reason: exercise.name);
        expect(exercise.equipment, isNotEmpty, reason: exercise.name);
        expect(exercise.description, isNotEmpty, reason: exercise.name);
        expect(exercise.steps, isNotEmpty, reason: exercise.name);
        if (exercise.instructionLanguage == 'ro') {
          expect(
            exercise.steps.length,
            greaterThanOrEqualTo(3),
            reason: exercise.name,
          );
        }
        expect(exercise.instructionLanguage, isIn(['ro', 'en']));
        expect(exercise.tips, isNotEmpty, reason: exercise.name);
        expect(
          exercise.difficulty,
          isIn(['Începător', 'Intermediar', 'Avansat']),
          reason: exercise.name,
        );
        expect(
          exercise.category,
          isIn(['Forță', 'Cardio', 'Mobilitate', 'Pliometrie']),
          reason: exercise.name,
        );
        expect(exercise.movement, isNotEmpty, reason: exercise.name);
        expect(exercise.aliases, isNotEmpty, reason: exercise.name);
        expect(exercise.sourceName, isNotEmpty, reason: exercise.name);
      }
    });

    test(
      'images are bundled or pinned remote assets, with honest missing states',
      () {
        const missingSourcePhotos = {
          'Kettlebell_Halo',
          'Kettlebell_Halo_With_Overhead_Extension',
          'Kettlebell_Overhead_Triceps_Extension',
        };
        const photoBase =
            'https://raw.githubusercontent.com/yuhonas/free-exercise-db/f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5/exercises/';
        for (final exercise in exerciseCatalog) {
          if (exercise.imageAsset.isNotEmpty) {
            expect(exercise.imageAsset, startsWith('assets/exercises/'));
            expect(
              File(exercise.imageAsset).existsSync(),
              isTrue,
              reason: exercise.name,
            );
          } else if (exercise.imageUrl.isNotEmpty) {
            expect(exercise.imageUrl, startsWith(photoBase));
            expect(Uri.parse(exercise.imageUrl).scheme, 'https');
            expect(exercise.secondaryImageUrl, startsWith(photoBase));
          } else {
            expect(
              missingSourcePhotos,
              contains(exercise.sourceId),
              reason: exercise.name,
            );
          }
          if (exercise.secondaryImageAsset.isNotEmpty) {
            expect(
              File(exercise.secondaryImageAsset).existsSync(),
              isTrue,
              reason: '${exercise.name}: ${exercise.secondaryImageAsset}',
            );
            expect(exercise.secondaryImageAsset, isNot(exercise.imageAsset));
          }
        }
        expect(
          exerciseCatalog
              .where((exercise) => exercise.imageAsset.isNotEmpty)
              .length,
          216,
        );
        expect(
          exerciseCatalog
              .where((exercise) => exercise.imageUrl.isNotEmpty)
              .length,
          659,
        );
      },
    );

    test(
      'covers every pinned source record once and retains English source instructions',
      () {
        final snapshot =
            jsonDecode(
                  File('assets/exercise-data/catalog.json').readAsStringSync(),
                )
                as Map<String, dynamic>;
        final source = snapshot['source'] as Map<String, dynamic>;
        final records = (snapshot['exercises'] as List)
            .cast<Map<String, dynamic>>();
        expect(records.length, 876);
        expect(source['revision'], 'f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5');
        expect(source['license'], 'Unlicense');
        expect((source['sourceSha256'] as String).length, 64);
        expect((source['canonicalSha256'] as String).length, 64);
        final sourced = exerciseCatalog
            .where((exercise) => exercise.sourceId.isNotEmpty)
            .toList();
        expect(sourced.length, records.length);
        expect(
          sourced.map((exercise) => exercise.sourceId).toSet(),
          records.map((record) => record['id']).toSet(),
        );
        final bySource = {
          for (final exercise in sourced) exercise.sourceId: exercise,
        };
        for (final record in records) {
          final exercise = bySource[record['id']]!;
          if (exercise.instructionLanguage == 'en') {
            expect(
              exercise.steps,
              (record['instructions'] as List)
                  .cast<String>()
                  .where((step) => step.trim().isNotEmpty)
                  .toList(),
              reason: exercise.name,
            );
          }
        }
        expect(
          sourced
              .where((exercise) => exercise.instructionLanguage == 'en')
              .length,
          660,
        );
      },
    );

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
    test(
      'all exercises retain coaching and image metadata after JSON serialization',
      () {
        for (final original in exerciseCatalog) {
          final restored = Exercise.fromJson(persisted(original.toJson()));
          expect(restored.toJson(), original.toJson(), reason: original.name);
        }
      },
    );

    test('old custom exercises remain readable without new image metadata', () {
      final restored = Exercise.fromJson({
        'id': 'custom-old',
        'name': 'Exercițiul meu',
        'muscle': 'Piept',
        'equipment': 'Gantere',
      });
      expect(restored.id, 'custom-old');
      expect(restored.imageAsset, isEmpty);
      expect(restored.secondaryImageAsset, isEmpty);
      expect(restored.imageUrl, isEmpty);
      expect(restored.secondaryImageUrl, isEmpty);
      expect(restored.instructionLanguage, 'ro');
      expect(restored.sourceId, isEmpty);
      expect(restored.difficulty, 'Intermediar');
      expect(restored.category, 'Forță');
      expect(restored.aliases, isEmpty);
      expect(
        Exercise.fromJson(persisted(restored.toJson())).toJson(),
        restored.toJson(),
      );
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

    test(
      'copyWith preserves an existing finish date and never yields negative duration',
      () {
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
      },
    );
  });
}
