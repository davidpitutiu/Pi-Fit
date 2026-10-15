import 'models.dart';
import 'external_exercise_catalog.dart';

/// Complete English catalog; stable IDs keep existing journals compatible.
const List<Exercise> exerciseCatalog = externalExerciseCatalog;

const List<Routine> routineTemplates = [
  Routine(
    id: 'push',
    name: 'Push day',
    subtitle: 'Chest · Shoulders · Triceps',
    estimatedMinutes: 55,
    category: 'Push / Pull / Legs',
    exercises: [
      RoutineExercise(exerciseId: 'bench_press', sets: 4, reps: 8),
      RoutineExercise(exerciseId: 'incline_dumbbell_press', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'dumbbell_shoulder_press', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'lateral_raise', sets: 3, reps: 15),
      RoutineExercise(exerciseId: 'triceps_pushdown', sets: 3, reps: 12),
    ],
  ),
  Routine(
    id: 'pull',
    name: 'Pull day',
    subtitle: 'Back · Rear delts · Biceps',
    estimatedMinutes: 50,
    category: 'Push / Pull / Legs',
    exercises: [
      RoutineExercise(exerciseId: 'lat_pulldown', sets: 4, reps: 10),
      RoutineExercise(exerciseId: 'seated_cable_row', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'dumbbell_row', sets: 3, reps: 12),
      RoutineExercise(exerciseId: 'face_pull', sets: 3, reps: 15),
      RoutineExercise(exerciseId: 'dumbbell_curl', sets: 3, reps: 12),
    ],
  ),
  Routine(
    id: 'legs',
    name: 'Leg day',
    subtitle: 'Quads · Hamstrings · Calves',
    estimatedMinutes: 60,
    category: 'Push / Pull / Legs',
    exercises: [
      RoutineExercise(exerciseId: 'squat', sets: 4, reps: 8),
      RoutineExercise(exerciseId: 'romanian_deadlift', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'leg_press', sets: 3, reps: 12),
      RoutineExercise(exerciseId: 'leg_curl', sets: 3, reps: 12),
      RoutineExercise(exerciseId: 'standing_calf_raise', sets: 4, reps: 15),
    ],
  ),
  Routine(
    id: 'full_body',
    name: 'Full body',
    subtitle: 'One workout. Your whole body.',
    estimatedMinutes: 45,
    category: 'Beginner',
    exercises: [
      RoutineExercise(exerciseId: 'goblet_squat', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'chest_press', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'lat_pulldown', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'romanian_deadlift', sets: 2, reps: 10),
      RoutineExercise(exerciseId: 'dead_bug', sets: 2, reps: 12),
    ],
  ),
  Routine(
    id: 'upper',
    name: 'Upper body',
    subtitle: 'Upper-body strength and balance',
    estimatedMinutes: 55,
    category: 'Upper / Lower',
    exercises: [
      RoutineExercise(exerciseId: 'dumbbell_press', sets: 3, reps: 8),
      RoutineExercise(exerciseId: 'chest_supported_row', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'dumbbell_shoulder_press', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'lat_pulldown', sets: 3, reps: 12),
      RoutineExercise(exerciseId: 'hammer_curl', sets: 2, reps: 12),
      RoutineExercise(exerciseId: 'triceps_pushdown', sets: 2, reps: 12),
    ],
  ),
  Routine(
    id: 'lower',
    name: 'Lower body',
    subtitle: 'Strong legs, steady progress',
    estimatedMinutes: 50,
    category: 'Upper / Lower',
    exercises: [
      RoutineExercise(exerciseId: 'leg_press', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'romanian_deadlift', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'bulgarian_split_squat', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'seated_leg_curl', sets: 3, reps: 12),
      RoutineExercise(exerciseId: 'seated_calf_raise', sets: 3, reps: 15),
    ],
  ),
  Routine(
    id: 'glutes',
    name: 'Glute focus',
    subtitle: 'Glutes · Posterior chain · Stability',
    estimatedMinutes: 45,
    category: 'Hypertrophy',
    exercises: [
      RoutineExercise(exerciseId: 'hip_thrust', sets: 4, reps: 10),
      RoutineExercise(exerciseId: 'romanian_deadlift', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'bulgarian_split_squat', sets: 3, reps: 10),
      RoutineExercise(exerciseId: 'cable_kickback', sets: 3, reps: 12),
      RoutineExercise(exerciseId: 'hip_abduction', sets: 3, reps: 15),
    ],
  ),
  Routine(
    id: 'home',
    name: 'Home essentials',
    subtitle: 'No machines. Just you and your progress.',
    estimatedMinutes: 25,
    category: 'Home',
    exercises: [
      RoutineExercise(exerciseId: 'push_up', sets: 3, reps: 8),
      RoutineExercise(exerciseId: 'glute_bridge', sets: 3, reps: 15),
      RoutineExercise(exerciseId: 'crunch', sets: 3, reps: 12),
      RoutineExercise(exerciseId: 'bird_dog', sets: 2, reps: 12),
      RoutineExercise(exerciseId: 'dead_bug', sets: 2, reps: 12),
    ],
  ),
];

/// A safe lookup for screens and imported histories that may reference an
/// exercise removed from a future catalogue version.
Exercise? exerciseById(String id) {
  for (final exercise in exerciseCatalog) {
    if (exercise.id == id) return exercise;
  }
  return null;
}
