import 'dart:math' as math;

import 'models.dart';
import 'user_profile.dart';

class ScoreComponent {
  const ScoreComponent({
    required this.label,
    required this.value,
    required this.target,
    required this.points,
    required this.maxPoints,
    required this.explanation,
  });
  final String label;
  final int value;
  final int target;
  final double points;
  final double maxPoints;
  final String explanation;
}

class WeeklyActivity {
  const WeeklyActivity({
    required this.start,
    required this.end,
    required this.activeDays,
    required this.workoutCount,
    required this.completedSets,
    required this.volume,
  });
  final DateTime start;

  /// Exclusive upper date boundary; future sessions are always excluded.
  final DateTime end;
  final int activeDays;
  final int workoutCount;
  final int completedSets;
  final double volume;
}

class MuscleVolume {
  const MuscleVolume({
    required this.muscle,
    required this.completedSets,
    required this.volume,
  });
  final String muscle;
  final int completedSets;
  final double volume;
}

class ExerciseRecord {
  const ExerciseRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.estimatedOneRepMax,
    required this.date,
  });
  final String exerciseId;
  final String exerciseName;
  final double weight;
  final int reps;

  /// Epley estimate, only for strength exercises and 1–12 repetitions.
  final double? estimatedOneRepMax;
  final DateTime date;
}

class TrainingStreak {
  const TrainingStreak({
    required this.currentWeeks,
    required this.bestWeeks,
    required this.activeDaysThisWeek,
    required this.targetDaysPerWeek,
    required this.currentWeekStart,
  });
  final int currentWeeks;
  final int bestWeeks;
  final int activeDaysThisWeek;
  final int targetDaysPerWeek;
  final DateTime currentWeekStart;
  String get explanation =>
      'O săptămână contează când ai cel puțin $targetDaysPerWeek zile distincte '
      'cu antrenamente finalizate, de luni până duminică. Săptămâna curentă '
      'încă în desfășurare nu întrerupe seria precedentă. Obiectivul actual '
      'din profil este aplicat întregului istoric; schimbarea lui recalculează seria.';
}

class DailyTrainingActivity {
  const DailyTrainingActivity({
    required this.date,
    required this.workoutCount,
    required this.activeDays,
    required this.completedSets,
    required this.volume,
    required this.durationMinutes,
  });
  final DateTime date;
  final int workoutCount;

  /// Always zero or one, even when several sessions were logged that day.
  final int activeDays;
  final int completedSets;
  final double volume;

  /// Logged elapsed time between starting and finishing, including pauses.
  final double durationMinutes;
}

class TrainingSeries {
  TrainingSeries({
    required this.days,
    required this.start,
    required this.asOf,
    required List<DailyTrainingActivity> points,
    required List<MuscleVolume> muscles,
  }) : points = List.unmodifiable(points),
       muscles = List.unmodifiable(muscles);
  final int days;
  final DateTime start;
  final DateTime asOf;
  final List<DailyTrainingActivity> points;
  final List<MuscleVolume> muscles;
  int get workoutCount =>
      points.fold(0, (sum, point) => sum + point.workoutCount);
  int get activeDays => points.fold(0, (sum, point) => sum + point.activeDays);
  int get completedSets =>
      points.fold(0, (sum, point) => sum + point.completedSets);
  double get volume => points.fold(0.0, (sum, point) => sum + point.volume);
  double get durationMinutes =>
      points.fold(0.0, (sum, point) => sum + point.durationMinutes);
  List<DateTime> get activeDates => List.unmodifiable(
    points.where((point) => point.activeDays > 0).map((point) => point.date),
  );
  String get explanation =>
      'Ultimele $days zile calendaristice, inclusiv azi. '
      'Numai sesiuni finalizate până acum și seturi bifate valide. Zilele fără '
      'date au valoarea zero; durata este timpul înregistrat, inclusiv pauzele.';
}

class ExerciseProgressPoint {
  const ExerciseProgressPoint({
    required this.date,
    required this.topWeight,
    required this.topWeightReps,
    required this.estimatedOneRepMax,
    required this.completedSets,
    required this.volume,
  });
  final DateTime date;
  final double topWeight;
  final int topWeightReps;

  /// Best eligible Epley estimate that day. It may come from another set than
  /// the heaviest actual load. Null means no eligible set with 1–12 reps.
  final double? estimatedOneRepMax;
  final int completedSets;
  final double volume;
}

class TrainingAnalytics {
  const TrainingAnalytics({
    required this.score,
    required this.activeDaysLast28,
    required this.completedSetsLast28,
    required this.volumeLast28,
    required this.workoutCountLast28,
    required this.targetDaysLast28,
    required this.targetSessionsPerWeek,
    required this.components,
    required this.weeks,
    required this.muscles,
    required this.records,
    required this.windowStart,
    required this.asOf,
    required this.formula,
    required this.windowExplanation,
    required this.streak,
  });

  /// Training consistency relative to the user's goal. Not a fitness or health
  /// assessment. Null means no usable completed training data has been logged.
  final double? score;
  final int activeDaysLast28;
  final int completedSetsLast28;
  final double volumeLast28;
  final int workoutCountLast28;
  final int targetDaysLast28;
  final int targetSessionsPerWeek;
  final List<ScoreComponent> components;
  final List<WeeklyActivity> weeks;
  final List<MuscleVolume> muscles;

  /// All-time records, not restricted to the 28-day score window.
  final List<ExerciseRecord> records;
  final DateTime windowStart;
  final DateTime asOf;
  final String formula;
  final String windowExplanation;
  final TrainingStreak streak;
  int get currentStreakWeeks => streak.currentWeeks;
  int get bestStreakWeeks => streak.bestWeeks;
  String get scoreLabel => 'Scor de consecvență';
  String get scoreExplanation =>
      'Măsoară respectarea obiectivului de zile de antrenament, nu sănătatea, '
      'nivelul fizic sau calitatea tehnicii. Obiectivul este configurabil în profil.';
  String get volumeExplanation =>
      'Volum extern = kg × repetări pentru seturile bifate de forță. '
      'Nu include greutatea corpului, cardio sau mobilitatea; aparatele și '
      'exercițiile diferite nu se compară direct.';
  String get recordsExplanation =>
      'Recorduri din tot istoricul finalizat: cea mai mare estimare Epley '
      '(kg × (1 + repetări / 30), numai 1–12 repetări). Estimarea 1RM nu '
      'este o recomandare de greutate. Dacă lipsesc seturi eligibile, este '
      'afișat cel mai greu set fără estimare.';
}

/// Four consecutive seven-calendar-day blocks, including today, in the device's
/// local timezone. A session counts on its start day only after it is finished.
TrainingAnalytics analyzeTraining({
  required List<WorkoutSession> history,
  required List<Exercise> exercises,
  required UserProfile profile,
  DateTime? now,
}) {
  final asOf = (now ?? DateTime.now()).toLocal();
  final today = DateTime(asOf.year, asOf.month, asOf.day);
  final windowStart = DateTime(today.year, today.month, today.day - 27);
  final catalog = {for (final exercise in exercises) exercise.id: exercise};
  final completed = _completedSessions(history, asOf);
  final recent = completed
      .where((session) => !session.startedAt.toLocal().isBefore(windowStart))
      .toList();
  final weeks = <WeeklyActivity>[];
  for (var index = 0; index < 4; index++) {
    final start = DateTime(
      windowStart.year,
      windowStart.month,
      windowStart.day + index * 7,
    );
    final end = DateTime(start.year, start.month, start.day + 7);
    final sessions = recent
        .where(
          (session) =>
              !session.startedAt.toLocal().isBefore(start) &&
              session.startedAt.toLocal().isBefore(end),
        )
        .toList();
    weeks.add(
      WeeklyActivity(
        start: start,
        end: end,
        activeDays: sessions
            .map((session) => _dayKey(session.startedAt))
            .toSet()
            .length,
        workoutCount: sessions.length,
        completedSets: _sets(sessions),
        volume: _volume(sessions, catalog),
      ),
    );
  }
  final activeDays = recent
      .map((session) => _dayKey(session.startedAt))
      .toSet()
      .length;
  final target = profile.sessionsPerWeek * 4;
  final adherencePoints = 70.0 * math.min(activeDays / target, 1.0);
  final consistentWeeks = weeks
      .where((week) => week.activeDays >= profile.sessionsPerWeek)
      .length;
  final consistencyPoints = 30.0 * consistentWeeks / 4;
  final byMuscleSets = <String, int>{};
  final byMuscleVolume = <String, double>{};
  for (final session in recent) {
    for (final item in session.exercises) {
      final exercise = catalog[item.exerciseId];
      final muscle = exercise?.muscle ?? 'Altele';
      for (final set in item.sets.where(_validSet)) {
        byMuscleSets[muscle] = (byMuscleSets[muscle] ?? 0) + 1;
        byMuscleVolume[muscle] =
            (byMuscleVolume[muscle] ?? 0) +
            (_weightedExercise(exercise) ? set.weight * set.reps : 0);
      }
    }
  }
  final muscles =
      byMuscleSets.entries
          .map(
            (entry) => MuscleVolume(
              muscle: entry.key,
              completedSets: entry.value,
              volume: byMuscleVolume[entry.key] ?? 0,
            ),
          )
          .toList()
        ..sort((a, b) => b.completedSets.compareTo(a.completedSets));
  final records = <String, ExerciseRecord>{};
  for (final session in completed) {
    for (final item in session.exercises) {
      final exercise = catalog[item.exerciseId];
      if (!_weightedExercise(exercise)) continue;
      for (final set in item.sets.where(_validSet)) {
        if (set.weight <= 0) continue;
        final estimate = estimateOneRepMax(exercise!, set);
        final previous = records[item.exerciseId];
        // An eligible estimated record takes precedence over an ineligible
        // high-repetition set. Otherwise compare the actual external weight.
        final better =
            previous == null ||
            (estimate != null &&
                (previous.estimatedOneRepMax == null ||
                    estimate > previous.estimatedOneRepMax!)) ||
            (estimate == null &&
                previous.estimatedOneRepMax == null &&
                set.weight > previous.weight);
        if (better) {
          records[item.exerciseId] = ExerciseRecord(
            exerciseId: item.exerciseId,
            exerciseName: exercise.name,
            weight: set.weight,
            reps: set.reps,
            estimatedOneRepMax: estimate,
            date: session.startedAt.toLocal(),
          );
        }
      }
    }
  }
  final sortedRecords = records.values.toList()
    ..sort((a, b) => a.exerciseName.compareTo(b.exerciseName));
  return TrainingAnalytics(
    score: completed.isEmpty ? null : adherencePoints + consistencyPoints,
    activeDaysLast28: activeDays,
    completedSetsLast28: _sets(recent),
    volumeLast28: _volume(recent, catalog),
    workoutCountLast28: recent.length,
    targetDaysLast28: target,
    targetSessionsPerWeek: profile.sessionsPerWeek,
    components: List.unmodifiable([
      ScoreComponent(
        label: 'Zile de antrenament',
        value: activeDays,
        target: target,
        points: adherencePoints,
        maxPoints: 70,
        explanation:
            '70 × min(zile active / $target, 1). Mai multe sesiuni în '
            'aceeași zi contează o singură dată.',
      ),
      ScoreComponent(
        label: 'Săptămâni consecvente',
        value: consistentWeeks,
        target: 4,
        points: consistencyPoints,
        maxPoints: 30,
        explanation:
            '30 × săptămâni cu cel puțin ${profile.sessionsPerWeek} '
            'zile active / 4.',
      ),
    ]),
    weeks: List.unmodifiable(weeks),
    muscles: List.unmodifiable(muscles),
    records: List.unmodifiable(sortedRecords),
    windowStart: windowStart,
    asOf: asOf,
    streak: _trainingStreak(completed, profile, asOf),
    formula:
        'Scor = 70 × min(zile active / (4 × obiectiv săptămânal), 1) + '
        '30 × săptămâni care ating obiectivul / 4.',
    windowExplanation:
        'Ultimele 28 de zile calendaristice, inclusiv azi, '
        'împărțite în 4 intervale consecutive de 7 zile. Sunt incluse doar '
        'sesiuni finalizate până acum, cu cel puțin un set bifat valid. '
        'Grupele musculare primesc seturi numai pentru mușchiul principal, '
        'fără dublarea mușchilor secundari.',
  );
}

/// Daily points include empty days so chart spacing always represents time.
TrainingSeries buildTrainingSeries({
  required List<WorkoutSession> history,
  required List<Exercise> exercises,
  int days = 28,
  DateTime? now,
}) {
  _validateSeriesDays(days);
  final asOf = (now ?? DateTime.now()).toLocal();
  final start = DateTime(asOf.year, asOf.month, asOf.day - days + 1);
  final catalog = {for (final exercise in exercises) exercise.id: exercise};
  final byDay = <String, List<WorkoutSession>>{};
  for (final session in _completedSessions(history, asOf)) {
    if (session.startedAt.toLocal().isBefore(start)) continue;
    byDay.putIfAbsent(_dayKey(session.startedAt), () => []).add(session);
  }
  final points = <DailyTrainingActivity>[];
  for (var index = 0; index < days; index++) {
    final date = DateTime(start.year, start.month, start.day + index);
    final sessions = byDay[_dayKey(date)] ?? const <WorkoutSession>[];
    points.add(
      DailyTrainingActivity(
        date: date,
        workoutCount: sessions.length,
        activeDays: sessions.isEmpty ? 0 : 1,
        completedSets: _sets(sessions),
        volume: _volume(sessions, catalog),
        durationMinutes: sessions.fold(
          0.0,
          (sum, session) =>
              sum +
              session.finishedAt!.difference(session.startedAt).inMilliseconds /
                  Duration.millisecondsPerMinute,
        ),
      ),
    );
  }
  final muscleSets = <String, int>{};
  final muscleVolume = <String, double>{};
  for (final sessions in byDay.values) {
    for (final session in sessions) {
      for (final item in session.exercises) {
        final exercise = catalog[item.exerciseId];
        final muscle = exercise?.muscle ?? 'Altele';
        for (final set in item.sets.where(_validSet)) {
          muscleSets[muscle] = (muscleSets[muscle] ?? 0) + 1;
          muscleVolume[muscle] =
              (muscleVolume[muscle] ?? 0) +
              (_weightedExercise(exercise) ? set.weight * set.reps : 0);
        }
      }
    }
  }
  final muscles =
      muscleSets.entries
          .map(
            (entry) => MuscleVolume(
              muscle: entry.key,
              completedSets: entry.value,
              volume: muscleVolume[entry.key] ?? 0,
            ),
          )
          .toList()
        ..sort((a, b) => b.completedSets.compareTo(a.completedSets));
  return TrainingSeries(
    days: days,
    start: start,
    asOf: asOf,
    points: points,
    muscles: muscles,
  );
}

/// One point per day with actual weighted strength work, without fabricated
/// points for rest days or interpolated records. Bodyweight/cardio return empty.
List<ExerciseProgressPoint> buildExerciseProgression({
  required List<WorkoutSession> history,
  required Exercise exercise,
  int days = 90,
  DateTime? now,
}) {
  _validateSeriesDays(days);
  if (!_weightedExercise(exercise)) return const [];
  final asOf = (now ?? DateTime.now()).toLocal();
  final start = DateTime(asOf.year, asOf.month, asOf.day - days + 1);
  final byDay = <DateTime, List<WorkoutSet>>{};
  for (final session in _completedSessions(history, asOf)) {
    final local = session.startedAt.toLocal();
    if (local.isBefore(start)) continue;
    final date = DateTime(local.year, local.month, local.day);
    for (final item in session.exercises.where(
      (item) => item.exerciseId == exercise.id,
    )) {
      final sets = item.sets.where((set) => _validSet(set) && set.weight > 0);
      if (sets.isNotEmpty) byDay.putIfAbsent(date, () => []).addAll(sets);
    }
  }
  final dates = byDay.keys.toList()..sort();
  return List.unmodifiable(
    dates.map((date) {
      final sets = byDay[date]!;
      var heaviest = sets.first;
      double? bestEstimate;
      var volume = 0.0;
      for (final set in sets) {
        if (set.weight > heaviest.weight ||
            (set.weight == heaviest.weight && set.reps > heaviest.reps)) {
          heaviest = set;
        }
        final estimate = estimateOneRepMax(exercise, set);
        if (estimate != null &&
            (bestEstimate == null || estimate > bestEstimate)) {
          bestEstimate = estimate;
        }
        volume += set.weight * set.reps;
      }
      return ExerciseProgressPoint(
        date: date,
        topWeight: heaviest.weight,
        topWeightReps: heaviest.reps,
        estimatedOneRepMax: bestEstimate,
        completedSets: sets.length,
        volume: volume,
      );
    }),
  );
}

TrainingStreak analyzeTrainingStreak({
  required List<WorkoutSession> history,
  required UserProfile profile,
  DateTime? now,
}) {
  final asOf = (now ?? DateTime.now()).toLocal();
  return _trainingStreak(_completedSessions(history, asOf), profile, asOf);
}

TrainingStreak _trainingStreak(
  List<WorkoutSession> completed,
  UserProfile profile,
  DateTime asOf,
) {
  final currentMonday = DateTime(
    asOf.year,
    asOf.month,
    asOf.day - asOf.weekday + 1,
  );
  final byWeek = <DateTime, Set<String>>{};
  for (final session in completed) {
    final local = session.startedAt.toLocal();
    final monday = DateTime(
      local.year,
      local.month,
      local.day - local.weekday + 1,
    );
    byWeek.putIfAbsent(monday, () => {}).add(_dayKey(local));
  }
  final qualified =
      byWeek.entries
          .where((entry) => entry.value.length >= profile.sessionsPerWeek)
          .map((entry) => entry.key)
          .toList()
        ..sort();
  var best = 0;
  var run = 0;
  DateTime? previous;
  for (final week in qualified) {
    run =
        previous != null &&
            week == DateTime(previous.year, previous.month, previous.day + 7)
        ? run + 1
        : 1;
    if (run > best) best = run;
    previous = week;
  }
  final qualifiedSet = qualified.toSet();
  var anchor = currentMonday;
  // An unfinished current calendar week gets a grace period through Sunday.
  // It counts only after meeting the target, and cannot hide a missed past week.
  if (!qualifiedSet.contains(anchor)) {
    anchor = DateTime(anchor.year, anchor.month, anchor.day - 7);
  }
  var current = 0;
  while (qualifiedSet.contains(anchor)) {
    current++;
    anchor = DateTime(anchor.year, anchor.month, anchor.day - 7);
  }
  return TrainingStreak(
    currentWeeks: current,
    bestWeeks: best,
    activeDaysThisWeek: byWeek[currentMonday]?.length ?? 0,
    targetDaysPerWeek: profile.sessionsPerWeek,
    currentWeekStart: currentMonday,
  );
}

void _validateSeriesDays(int days) {
  if (!const {7, 28, 90}.contains(days)) {
    throw ArgumentError.value(days, 'days', 'Alege 7, 28 sau 90 de zile.');
  }
}

List<WorkoutSession> _completedSessions(
  List<WorkoutSession> history,
  DateTime asOf,
) {
  final ids = <String>{};
  return history
      .where(
        (session) =>
            session.finishedAt != null &&
            !session.startedAt.isAfter(asOf) &&
            !session.finishedAt!.isAfter(asOf) &&
            !session.finishedAt!.isBefore(session.startedAt) &&
            session.exercises.any((exercise) => exercise.sets.any(_validSet)) &&
            ids.add(session.id),
      )
      .toList();
}

/// Shared with live workout displays so totals and historical charts agree.
bool isValidCompletedSet(WorkoutSet set) => _validSet(set);
bool isWeightedStrengthExercise(Exercise? exercise) =>
    _weightedExercise(exercise);
double? estimateOneRepMax(Exercise exercise, WorkoutSet set) =>
    _weightedExercise(exercise) &&
        _validSet(set) &&
        set.weight > 0 &&
        set.reps <= 12
    ? set.weight * (1 + set.reps / 30)
    : null;

String _dayKey(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month}-${local.day}';
}

// Defensively ignore unusable legacy/imported values instead of letting one
// invalid set produce NaN, negative volume, or an inflated record.
bool _validSet(WorkoutSet set) =>
    set.completed &&
    set.reps >= 1 &&
    set.reps <= 1000 &&
    set.weight.isFinite &&
    set.weight >= 0 &&
    set.weight <= 2000;

bool _weightedExercise(Exercise? exercise) =>
    exercise != null &&
    exercise.category == 'Forță' &&
    const {
      'Bară',
      'Gantere',
      'Cablu',
      'Aparat',
      'Bară EZ',
      'Kettlebell',
      'Smith',
      'Disc',
    }.contains(exercise.equipment);

int _sets(List<WorkoutSession> sessions) => sessions.fold(
  0,
  (sum, session) =>
      sum +
      session.exercises.fold(
        0,
        (count, exercise) => count + exercise.sets.where(_validSet).length,
      ),
);

double _volume(List<WorkoutSession> sessions, Map<String, Exercise> catalog) =>
    sessions.fold(
      0.0,
      (sum, session) =>
          sum +
          session.exercises.fold(
            0.0,
            (exerciseSum, item) =>
                exerciseSum +
                (_weightedExercise(catalog[item.exerciseId])
                    ? item.sets
                          .where(_validSet)
                          .fold(
                            0.0,
                            (total, set) => total + set.weight * set.reps,
                          )
                    : 0),
          ),
    );
