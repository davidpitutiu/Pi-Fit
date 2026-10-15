/// Domain objects are independent of Flutter and Firebase. Dates use ISO 8601
/// strings so the same payload works with local storage and Firestore.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.muscle,
    required this.equipment,
    required this.description,
    this.steps = const [],
    this.tips = const [],
    this.secondaryMuscles = '',
    this.imageAsset = '',
    this.secondaryImageAsset = '',
    this.imageUrl = '',
    this.secondaryImageUrl = '',
    this.instructionLanguage = 'en',
    this.sourceId = '',
    this.difficulty = 'Intermediate',
    this.category = 'Strength',
    this.movement = '',
    this.sourceName = '',
    this.aliases = const <String>[],
  });

  final String id;
  final String name;
  final String muscle;
  final String equipment;
  final String description;
  final List<String> steps;
  final List<String> tips;
  final String secondaryMuscles;
  final String imageAsset;
  final String secondaryImageAsset;
  final String imageUrl;
  final String secondaryImageUrl;
  final String instructionLanguage;
  final String sourceId;
  final String difficulty;
  final String category;
  final String movement;
  final String sourceName;
  final List<String> aliases;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscle': muscle,
    'equipment': equipment,
    'description': description,
    'steps': steps,
    'tips': tips,
    'secondaryMuscles': secondaryMuscles,
    'imageAsset': imageAsset,
    'secondaryImageAsset': secondaryImageAsset,
    'imageUrl': imageUrl,
    'secondaryImageUrl': secondaryImageUrl,
    'instructionLanguage': instructionLanguage,
    'sourceId': sourceId,
    'difficulty': difficulty,
    'category': category,
    'movement': movement,
    'sourceName': sourceName,
    'aliases': aliases,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] as String,
    name: json['name'] as String,
    muscle: json['muscle'] as String,
    equipment: json['equipment'] as String,
    description: json['description'] as String? ?? '',
    steps: List<String>.from(json['steps'] as List? ?? const []),
    tips: List<String>.from(json['tips'] as List? ?? const []),
    secondaryMuscles: json['secondaryMuscles'] as String? ?? '',
    imageAsset: json['imageAsset'] as String? ?? '',
    secondaryImageAsset: json['secondaryImageAsset'] as String? ?? '',
    imageUrl: json['imageUrl'] as String? ?? '',
    secondaryImageUrl: json['secondaryImageUrl'] as String? ?? '',
    instructionLanguage: json['instructionLanguage'] as String? ?? 'en',
    sourceId: json['sourceId'] as String? ?? '',
    difficulty: json['difficulty'] as String? ?? 'Intermediate',
    category: json['category'] as String? ?? 'Strength',
    movement: json['movement'] as String? ?? '',
    sourceName: json['sourceName'] as String? ?? '',
    aliases: List<String>.from(json['aliases'] as List? ?? const []),
  );
}

class RoutineExercise {
  const RoutineExercise({
    required this.exerciseId,
    this.sets = 3,
    this.reps = 10,
    this.weight = 0,
  });

  final String exerciseId;
  final int sets;
  final int reps;
  final double weight;

  RoutineExercise copyWith({
    String? exerciseId,
    int? sets,
    int? reps,
    double? weight,
  }) => RoutineExercise(
    exerciseId: exerciseId ?? this.exerciseId,
    sets: sets ?? this.sets,
    reps: reps ?? this.reps,
    weight: weight ?? this.weight,
  );

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'sets': sets,
    'reps': reps,
    'weight': weight,
  };

  factory RoutineExercise.fromJson(Map<String, dynamic> json) =>
      RoutineExercise(
        exerciseId: json['exerciseId'] as String,
        sets: (json['sets'] as num?)?.toInt() ?? 3,
        reps: (json['reps'] as num?)?.toInt() ?? 10,
        weight: (json['weight'] as num?)?.toDouble() ?? 0,
      );
}

class Routine {
  const Routine({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.exercises,
    required this.estimatedMinutes,
    required this.category,
  });

  final String id;
  final String name;
  final String subtitle;
  final List<RoutineExercise> exercises;
  final int estimatedMinutes;
  final String category;

  int get totalSets =>
      exercises.fold(0, (total, exercise) => total + exercise.sets);

  Routine copyWith({
    String? id,
    String? name,
    String? subtitle,
    List<RoutineExercise>? exercises,
    int? estimatedMinutes,
    String? category,
  }) => Routine(
    id: id ?? this.id,
    name: name ?? this.name,
    subtitle: subtitle ?? this.subtitle,
    exercises: exercises ?? this.exercises,
    estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    category: category ?? this.category,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'subtitle': subtitle,
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
    'estimatedMinutes': estimatedMinutes,
    'category': category,
  };

  factory Routine.fromJson(Map<String, dynamic> json) => Routine(
    id: json['id'] as String,
    name: json['name'] as String,
    subtitle: json['subtitle'] as String? ?? '',
    exercises: (json['exercises'] as List? ?? const [])
        .map(
          (item) =>
              RoutineExercise.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt() ?? 45,
    category: json['category'] as String? ?? 'Custom',
  );
}

class WorkoutSet {
  const WorkoutSet({
    this.reps = 10,
    this.weight = 0,
    this.completed = false,
    this.rpe,
  }) : assert(rpe == null || (rpe >= 1 && rpe <= 10));

  final int reps;
  final double weight;
  final bool completed;

  /// User-reported effort, never inferred from load or used as health points.
  final double? rpe;

  double get volume => completed ? reps * weight : 0;

  WorkoutSet copyWith({
    int? reps,
    double? weight,
    bool? completed,
    double? rpe,
    bool clearRpe = false,
  }) => WorkoutSet(
    reps: reps ?? this.reps,
    weight: weight ?? this.weight,
    completed: completed ?? this.completed,
    rpe: clearRpe ? null : rpe ?? this.rpe,
  );

  Map<String, dynamic> toJson() => {
    'reps': reps,
    'weight': weight,
    'completed': completed,
    if (rpe != null) 'rpe': rpe,
  };

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    final rpe = json['rpe'];
    if (rpe != null && (rpe is! num || !rpe.isFinite || rpe < 1 || rpe > 10)) {
      throw const FormatException('Effort must be a number from 1 to 10.');
    }
    return WorkoutSet(
      reps: (json['reps'] as num?)?.toInt() ?? 0,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      completed: json['completed'] as bool? ?? false,
      rpe: (rpe as num?)?.toDouble(),
    );
  }
}

class WorkoutExercise {
  const WorkoutExercise({required this.exerciseId, required this.sets});

  final String exerciseId;
  final List<WorkoutSet> sets;

  double get volume => sets.fold(0, (total, set) => total + set.volume);
  int get completedSets => sets.where((set) => set.completed).length;

  WorkoutExercise copyWith({String? exerciseId, List<WorkoutSet>? sets}) =>
      WorkoutExercise(
        exerciseId: exerciseId ?? this.exerciseId,
        sets: sets ?? this.sets,
      );

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'sets': sets.map((set) => set.toJson()).toList(),
  };

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) =>
      WorkoutExercise(
        exerciseId: json['exerciseId'] as String,
        sets: (json['sets'] as List? ?? const [])
            .map(
              (item) =>
                  WorkoutSet.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
      );
}

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.routineName,
    required this.startedAt,
    this.finishedAt,
    required this.exercises,
    this.notes = '',
  });

  final String id;
  final String routineName;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<WorkoutExercise> exercises;
  final String notes;

  double get volume =>
      exercises.fold(0, (total, exercise) => total + exercise.volume);
  int get completedSets =>
      exercises.fold(0, (total, exercise) => total + exercise.completedSets);
  int get totalSets =>
      exercises.fold(0, (total, exercise) => total + exercise.sets.length);
  bool get isFinished => finishedAt != null;
  Duration get duration {
    final difference = (finishedAt ?? DateTime.now()).difference(startedAt);
    return difference.isNegative ? Duration.zero : difference;
  }

  WorkoutSession copyWith({
    String? id,
    String? routineName,
    DateTime? startedAt,
    DateTime? finishedAt,
    List<WorkoutExercise>? exercises,
    String? notes,
  }) => WorkoutSession(
    id: id ?? this.id,
    routineName: routineName ?? this.routineName,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
    exercises: exercises ?? this.exercises,
    notes: notes ?? this.notes,
  );

  factory WorkoutSession.fromRoutine(Routine routine, {DateTime? startedAt}) {
    final start = startedAt ?? DateTime.now();
    return WorkoutSession(
      id: start.microsecondsSinceEpoch.toString(),
      routineName: routine.name,
      startedAt: start,
      exercises: routine.exercises
          .map(
            (exercise) => WorkoutExercise(
              exerciseId: exercise.exerciseId,
              sets: List.generate(
                exercise.sets,
                (_) => WorkoutSet(reps: exercise.reps, weight: exercise.weight),
              ),
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'routineName': routineName,
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
    'notes': notes,
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
    id: json['id'] as String,
    routineName: json['routineName'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String),
    finishedAt: json['finishedAt'] == null
        ? null
        : DateTime.parse(json['finishedAt'] as String),
    exercises: (json['exercises'] as List? ?? const [])
        .map(
          (item) =>
              WorkoutExercise.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    notes: json['notes'] as String? ?? '',
  );
}

class ScheduledWorkout {
  const ScheduledWorkout({
    required this.id,
    required this.routineId,
    required this.date,
    this.reminder = true,
  });

  final String id;
  final String routineId;
  final DateTime date;
  final bool reminder;

  ScheduledWorkout copyWith({
    String? id,
    String? routineId,
    DateTime? date,
    bool? reminder,
  }) => ScheduledWorkout(
    id: id ?? this.id,
    routineId: routineId ?? this.routineId,
    date: date ?? this.date,
    reminder: reminder ?? this.reminder,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'routineId': routineId,
    'date': date.toIso8601String(),
    'reminder': reminder,
  };

  factory ScheduledWorkout.fromJson(Map<String, dynamic> json) =>
      ScheduledWorkout(
        id: json['id'] as String,
        routineId: json['routineId'] as String,
        date: DateTime.parse(json['date'] as String),
        reminder: json['reminder'] as bool? ?? true,
      );
}
