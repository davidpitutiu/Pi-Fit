import 'models.dart';
import 'training_analytics.dart';

class MuscleFocusExercise {
  const MuscleFocusExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.primarySets,
    required this.secondarySets,
  });
  final String exerciseId;
  final String exerciseName;
  final int primarySets;
  final int secondarySets;
}

class MuscleFocusGroup {
  MuscleFocusGroup({
    required this.muscle,
    required this.primarySets,
    required this.secondarySets,
    required this.share,
    required List<MuscleFocusExercise> exercises,
  }) : exercises = List.unmodifiable(exercises);
  final String muscle;
  final int primarySets;

  /// Supplementary catalog involvement, never added to primary shares.
  final int secondarySets;

  /// Fraction of attributed primary strength sets, from zero to one.
  final double share;
  double get percentage => share * 100;
  final List<MuscleFocusExercise> exercises;
}

class MuscleFocusSummary {
  MuscleFocusSummary({
    required this.days,
    required this.start,
    required this.asOf,
    required this.totalPrimarySets,
    required this.unattributedSets,
    required List<MuscleFocusGroup> groups,
  }) : groups = List.unmodifiable(groups);
  final int days;
  final DateTime start;
  final DateTime asOf;
  final int totalPrimarySets;

  /// Valid sets with no catalog match or no recognized primary muscle. They
  /// are reported separately and never assigned to a guessed muscle group.
  final int unattributedSets;
  final List<MuscleFocusGroup> groups;
  String get explanation =>
      'Completed strength sets in the last $days calendar days, including today. '
      'Each set counts once toward its catalog primary muscle. Shares use only '
      'attributed primary sets; secondary involvement is listed separately and '
      'does not change the percentages. Cardio, mobility and plyometrics are '
      'excluded. Unmatched exercises or missing primary muscles are unattributed. '
      'Set share describes your logged training, not measured muscle activation '
      'or a recovery assessment.';
}

class _ExerciseCounts {
  _ExerciseCounts(this.exercise);
  final Exercise exercise;
  int primary = 0;
  int secondary = 0;
}

class _GroupCounts {
  _GroupCounts(this.muscle);
  final String muscle;
  int primary = 0;
  int secondary = 0;
  final exercises = <String, _ExerciseCounts>{};
  void add(Exercise exercise, int sets, {required bool direct}) {
    final counts = exercises.putIfAbsent(
      exercise.id,
      () => _ExerciseCounts(exercise),
    );
    if (direct) {
      primary += sets;
      counts.primary += sets;
    } else {
      secondary += sets;
      counts.secondary += sets;
    }
  }
}

/// All catalog primary groups remain present, even when they have zero sets.
/// Secondary names are matched to those canonical groups after trimming and
/// case normalization. Only the catalog's Strength/legacy Forță category adds
/// focus; an exercise missing from the catalog is kept as unattributed instead.
MuscleFocusSummary buildMuscleFocus({
  required List<WorkoutSession> history,
  required List<Exercise> exercises,
  int days = 28,
  DateTime? now,
}) {
  if (!const {7, 28, 90}.contains(days)) {
    throw ArgumentError.value(days, 'days', 'Choose 7, 28 or 90 days.');
  }
  final asOf = (now ?? DateTime.now()).toLocal();
  final start = DateTime(asOf.year, asOf.month, asOf.day - days + 1);
  final catalog = {for (final exercise in exercises) exercise.id: exercise};
  final groups = <String, _GroupCounts>{};
  for (final exercise in exercises) {
    final name = exercise.muscle.trim();
    if (_recognizedName(name)) {
      groups.putIfAbsent(name.toLowerCase(), () => _GroupCounts(name));
    }
  }
  var unattributed = 0;
  var totalPrimary = 0;
  final sessions = completedTrainingSessions(
    history,
    now: asOf,
  ).where((session) => !session.startedAt.toLocal().isBefore(start));
  for (final session in sessions) {
    for (final item in session.exercises) {
      final sets = item.sets.where(isValidCompletedSet).length;
      if (sets == 0) continue;
      final exercise = catalog[item.exerciseId];
      if (exercise == null) {
        unattributed += sets;
        continue;
      }
      if (!const {'Strength', 'Forță'}.contains(exercise.category)) continue;
      final primaryKey = exercise.muscle.trim().toLowerCase();
      final primary = groups[primaryKey];
      if (primary == null) {
        unattributed += sets;
      } else {
        primary.add(exercise, sets, direct: true);
        totalPrimary += sets;
      }
      final secondaryKeys = exercise.secondaryMuscles
          .split(',')
          .map((name) => name.trim().toLowerCase())
          .where((name) => name.isNotEmpty && name != primaryKey)
          .toSet();
      for (final key in secondaryKeys) {
        groups[key]?.add(exercise, sets, direct: false);
      }
    }
  }
  final sorted = groups.values.toList()
    ..sort((a, b) => a.muscle.toLowerCase().compareTo(b.muscle.toLowerCase()));
  return MuscleFocusSummary(
    days: days,
    start: start,
    asOf: asOf,
    totalPrimarySets: totalPrimary,
    unattributedSets: unattributed,
    groups: sorted.map((group) {
      final detail =
          group.exercises.values
              .map(
                (counts) => MuscleFocusExercise(
                  exerciseId: counts.exercise.id,
                  exerciseName: counts.exercise.name,
                  primarySets: counts.primary,
                  secondarySets: counts.secondary,
                ),
              )
              .toList()
            ..sort((a, b) {
              final name = a.exerciseName.toLowerCase().compareTo(
                b.exerciseName.toLowerCase(),
              );
              return name == 0 ? a.exerciseId.compareTo(b.exerciseId) : name;
            });
      return MuscleFocusGroup(
        muscle: group.muscle,
        primarySets: group.primary,
        secondarySets: group.secondary,
        share: totalPrimary == 0 ? 0 : group.primary / totalPrimary,
        exercises: detail,
      );
    }).toList(),
  );
}

bool _recognizedName(String name) =>
    name.isNotEmpty &&
    !const {
      'cardio',
      'other',
      'altele',
      'unspecified',
      'nespecificat',
      'unknown',
    }.contains(name.toLowerCase());
