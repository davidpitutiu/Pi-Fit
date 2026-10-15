import '../domain/models.dart';
import '../domain/training_analytics.dart';

class WorkoutAdvice {
  const WorkoutAdvice({
    required this.title,
    required this.text,
    required this.exerciseIndex,
    required this.exerciseId,
    this.setIndex,
    this.nextSetIndex,
    this.restSeconds,
    this.suggestedWeight,
  });
  final String title, text, exerciseId;
  final int exerciseIndex;
  final int? setIndex, nextSetIndex, restSeconds;
  final double? suggestedWeight;
}

/// Immediate, deterministic feedback from actual logged sets and optional RPE.
/// This does not diagnose fatigue or automatically change a workout.
WorkoutAdvice? workoutAdvice({
  required WorkoutSession session,
  required List<Exercise> catalog,
  required List<WorkoutSession> history,
  int? focusedExerciseIndex,
}) {
  if (session.exercises.isEmpty) return null;
  var exerciseIndex = session.exercises.indexWhere(
    (e) => e.sets.any((s) => !s.completed),
  );
  if (exerciseIndex < 0) exerciseIndex = session.exercises.length - 1;
  // Old sessions have no per-set timestamps. Use the last exercised position as
  // a fallback; the screen supplies the actual exercise changed during logging.
  for (var i = session.exercises.length - 1; i >= 0; i--) {
    if (session.exercises[i].sets.any(isValidCompletedSet)) {
      exerciseIndex = i;
      break;
    }
  }
  if (focusedExerciseIndex != null &&
      focusedExerciseIndex >= 0 &&
      focusedExerciseIndex < session.exercises.length) {
    exerciseIndex = focusedExerciseIndex;
  }
  final item = session.exercises[exerciseIndex];
  final exercise = catalog.where((e) => e.id == item.exerciseId).firstOrNull;
  final completed = item.sets.indexed
      .where((e) => isValidCompletedSet(e.$2))
      .toList();
  final next = item.sets.indexWhere((s) => !s.completed);
  if (completed.isEmpty) {
    return WorkoutAdvice(
      title: 'Start with control',
      text:
          'Use a comfortable warm-up load for ${exercise?.name ?? 'this exercise'}. Log a set and its effort to get feedback that fits your session.',
      exerciseIndex: exerciseIndex,
      exerciseId: item.exerciseId,
    );
  }
  final latest = completed.last;
  final set = latest.$2;
  final rawRpe = set.rpe;
  final rpe = rawRpe != null && rawRpe.isFinite && rawRpe >= 1 && rawRpe <= 10
      ? rawRpe
      : null;
  WorkoutAdvice advice(String title, String text, {int? rest, double? load}) =>
      WorkoutAdvice(
        title: title,
        text: text,
        exerciseIndex: exerciseIndex,
        exerciseId: item.exerciseId,
        setIndex: latest.$1,
        nextSetIndex: next < 0 ? null : next,
        restSeconds: rest,
        suggestedWeight: load,
      );
  if (rpe == null) {
    return advice(
      'How hard was that set?',
      'You logged ${set.reps} reps${set.weight > 0 ? ' at ${set.weight} kg' : ''}. Add an effort rating from 1–10 to personalize your next-set advice. A longer rest is fine if your technique needs it.',
    );
  }
  if (rpe >= 9.5) {
    final candidate = (set.weight * .95 * 2).round() / 2;
    final load =
        exercise != null &&
            isWeightedStrengthExercise(exercise) &&
            candidate > 0 &&
            candidate < set.weight &&
            next >= 0
        ? candidate
        : null;
    return advice(
      'Give yourself more room',
      'RPE ${_n(rpe)} means this felt near your limit. Rest longer and keep the next set controlled${load == null ? '.' : '; consider about ${_n(load)} kg if that is practical for your equipment.'} Stop a movement that causes pain.',
      rest: 150,
      load: load,
    );
  }
  if (rpe >= 8) {
    return advice(
      'Keep the quality',
      'RPE ${_n(rpe)} is a challenging set. Keep a manageable load, rest about two minutes and aim to repeat controlled reps. Reduce the load if technique or reps start falling.',
      rest: 120,
    );
  }
  final prior = completedTrainingSessions(history)
      .where((s) => s.startedAt.isBefore(session.startedAt))
      .expand((s) => s.exercises)
      .where((e) => e.exerciseId == item.exerciseId)
      .expand((e) => e.sets)
      .where((s) => isValidCompletedSet(s) && s.rpe != null)
      .toList();
  return advice(
    'Steady progress',
    'RPE ${_n(rpe)} suggests this set felt manageable. Keep the planned reps and technique; consider a small progression only after you meet your targets consistently.${prior.isEmpty ? ' More effort ratings will make comparisons more useful.' : ' Your history has ${prior.length} rated sets for this exercise.'}',
    rest: 90,
  );
}

String _n(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
