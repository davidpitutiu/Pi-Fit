import 'dart:convert';

import 'models.dart';
import 'user_profile.dart';

enum CoachProposalSource { local, online }

/// A preview, never a command. AppStore validates the current account/revisions
/// again before atomically applying a proposal selected by the user.
class CoachProposal {
  CoachProposal._({
    required this.accountId,
    required this.baseRevision,
    required this.title,
    required this.summary,
    required this.source,
    required List<CoachRoutineDraft> routines,
    required this.schedule,
    required List<Exercise> catalog,
    required List<Routine> customRoutines,
  }) : routines = List.unmodifiable(routines),
       _catalog = List.unmodifiable(catalog),
       _customRoutines = List.unmodifiable(customRoutines) {
    validate(catalog: catalog, customRoutines: customRoutines);
    id =
        'cp_${_fingerprint(jsonEncode({'accountId': accountId, 'baseRevision': baseRevision, ...toWireJson()}))}';
  }

  factory CoachProposal.fromWireJson(
    Map<String, dynamic> json, {
    required String? accountId,
    required String baseRevision,
    required CoachProposalSource source,
    required List<Exercise> catalog,
    required List<Routine> customRoutines,
  }) {
    _keys(json, {'schemaVersion', 'title', 'summary', 'routines', 'schedule'});
    if (json['schemaVersion'] != 1) _invalid('Unsupported plan version.');
    return CoachProposal._(
      accountId: accountId,
      baseRevision: baseRevision,
      title: _text(json['title'], 100),
      summary: _text(json['summary'], 1200),
      source: source,
      routines: _array(
        json['routines'],
        1,
        7,
      ).map((item) => CoachRoutineDraft.fromJson(_object(item))).toList(),
      schedule: json['schedule'] == null
          ? null
          : CoachScheduleDraft.fromJson(_object(json['schedule'])),
      catalog: catalog,
      customRoutines: customRoutines,
    );
  }

  late final String id;
  final String? accountId;
  final String baseRevision;
  final String title;
  final String summary;
  final CoachProposalSource source;
  final List<CoachRoutineDraft> routines;
  final CoachScheduleDraft? schedule;
  final List<Exercise> _catalog;
  final List<Routine> _customRoutines;

  void validate({
    required List<Exercise> catalog,
    required List<Routine> customRoutines,
  }) {
    _text(title, 100);
    _text(summary, 1200);
    if (baseRevision.isEmpty || routines.isEmpty || routines.length > 7) {
      _invalid('Invalid plan.');
    }
    final ids = catalog.map((item) => item.id).toSet();
    final custom = {for (final routine in customRoutines) routine.id: routine};
    final targets = <String>{};
    for (final draft in routines) {
      draft.validate();
      if (draft.exercises.any(
        (exercise) => !ids.contains(exercise.exerciseId),
      )) {
        _invalid('The plan contains an exercise outside the catalog.');
      }
      final target = draft.targetRoutineId;
      if (target != null) {
        final existing = custom[target];
        if (existing == null ||
            !targets.add(target) ||
            draft.expectedRevision != coachRoutineRevision(existing)) {
          _invalid('The target routine changed or is not a custom routine.');
        }
      } else if (draft.expectedRevision != null) {
        _invalid('A new routine cannot replace a previous revision.');
      }
    }
    final scheduling = schedule;
    if (scheduling != null) {
      scheduling.validate();
      if (scheduling.routineIndex >= routines.length) {
        _invalid('Invalid scheduled routine.');
      }
    }
  }

  Map<String, dynamic> toWireJson() => {
    'schemaVersion': 1,
    'title': title,
    'summary': summary,
    'routines': routines.map((item) => item.toJson()).toList(),
    'schedule': schedule?.toJson(),
  };

  CoachProposal copyWith({
    String? title,
    String? summary,
    List<CoachRoutineDraft>? routines,
    CoachScheduleDraft? schedule,
    bool clearSchedule = false,
  }) => CoachProposal._(
    accountId: accountId,
    baseRevision: baseRevision,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    source: source,
    routines: routines ?? this.routines,
    schedule: clearSchedule ? null : schedule ?? this.schedule,
    catalog: _catalog,
    customRoutines: _customRoutines,
  );
}

class CoachRoutineDraft {
  CoachRoutineDraft({
    this.targetRoutineId,
    this.expectedRevision,
    required this.name,
    required this.subtitle,
    required this.estimatedMinutes,
    required List<RoutineExercise> exercises,
  }) : exercises = List.unmodifiable(exercises) {
    validate();
  }

  factory CoachRoutineDraft.fromJson(Map<String, dynamic> json) {
    _keys(json, {
      'targetRoutineId',
      'expectedRevision',
      'name',
      'subtitle',
      'estimatedMinutes',
      'exercises',
    });
    final target = json['targetRoutineId'];
    final revision = json['expectedRevision'];
    if ((target != null && target is! String) ||
        (revision != null && revision is! String)) {
      _invalid('Invalid routine target.');
    }
    return CoachRoutineDraft(
      targetRoutineId: target as String?,
      expectedRevision: revision as String?,
      name: _text(json['name'], 80),
      subtitle: _text(json['subtitle'], 240, allowEmpty: true),
      estimatedMinutes: _integer(json['estimatedMinutes'], 15, 180),
      exercises: _array(json['exercises'], 1, 12).map((item) {
        final exercise = _object(item);
        _keys(exercise, {'exerciseId', 'sets', 'reps', 'weight'});
        final weight = exercise['weight'];
        if (weight is! num || !weight.isFinite || weight < 0 || weight > 1000) {
          _invalid('Invalid load.');
        }
        return RoutineExercise(
          exerciseId: _text(exercise['exerciseId'], 120),
          sets: _integer(exercise['sets'], 1, 8),
          reps: _integer(exercise['reps'], 1, 50),
          weight: (weight).toDouble(),
        );
      }).toList(),
    );
  }

  final String? targetRoutineId;
  final String? expectedRevision;
  final String name;
  final String subtitle;
  final int estimatedMinutes;
  final List<RoutineExercise> exercises;

  void validate() {
    _text(name, 80);
    _text(subtitle, 240, allowEmpty: true);
    _integer(estimatedMinutes, 15, 180);
    if (targetRoutineId != null) _text(targetRoutineId, 120);
    if (expectedRevision != null) _text(expectedRevision, 120);
    if (exercises.isEmpty || exercises.length > 12) {
      _invalid('Choose 1–12 exercises.');
    }
    final seen = <String>{};
    for (final exercise in exercises) {
      if (!seen.add(exercise.exerciseId)) {
        _invalid('Duplicate exercise in a routine.');
      }
      _integer(exercise.sets, 1, 8);
      _integer(exercise.reps, 1, 50);
      if (!exercise.weight.isFinite ||
          exercise.weight < 0 ||
          exercise.weight > 1000) {
        _invalid('Invalid load.');
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'targetRoutineId': targetRoutineId,
    'expectedRevision': expectedRevision,
    'name': name,
    'subtitle': subtitle,
    'estimatedMinutes': estimatedMinutes,
    'exercises': exercises.map((item) => item.toJson()).toList(),
  };

  CoachRoutineDraft copyWith({
    String? name,
    String? subtitle,
    int? estimatedMinutes,
    List<RoutineExercise>? exercises,
  }) => CoachRoutineDraft(
    targetRoutineId: targetRoutineId,
    expectedRevision: expectedRevision,
    name: name ?? this.name,
    subtitle: subtitle ?? this.subtitle,
    estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    exercises: exercises ?? this.exercises,
  );
}

class CoachScheduleDraft {
  CoachScheduleDraft({
    required this.routineIndex,
    required this.weeks,
    required List<int> weekdays,
    required DateTime startDate,
    this.hour = 18,
    this.minute = 0,
    this.reminder = false,
  }) : weekdays = List.unmodifiable(weekdays),
       startDate = DateTime(startDate.year, startDate.month, startDate.day) {
    validate();
  }

  factory CoachScheduleDraft.fromJson(Map<String, dynamic> json) {
    _keys(json, {
      'routineIndex',
      'weeks',
      'weekdays',
      'startDate',
      'hour',
      'minute',
      'reminder',
    });
    final rawDate = json['startDate'];
    if (rawDate is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawDate)) {
      _invalid('Invalid schedule date.');
    }
    final date = DateTime.tryParse(rawDate);
    if (date == null || _date(date) != rawDate) {
      _invalid('Invalid schedule date.');
    }
    if (json['reminder'] is! bool) _invalid('Invalid reminder setting.');
    return CoachScheduleDraft(
      routineIndex: _integer(json['routineIndex'], 0, 6),
      weeks: _integer(json['weeks'], 1, 12),
      weekdays: _array(
        json['weekdays'],
        1,
        7,
      ).map((item) => _integer(item, 1, 7)).toList(),
      startDate: date,
      hour: _integer(json['hour'], 0, 23),
      minute: _integer(json['minute'], 0, 59),
      reminder: json['reminder'] as bool,
    );
  }
  final int routineIndex;
  final int weeks;
  final List<int> weekdays;
  final DateTime startDate;
  final int hour;
  final int minute;
  final bool reminder;
  void validate() {
    _integer(routineIndex, 0, 6);
    _integer(weeks, 1, 12);
    _integer(hour, 0, 23);
    _integer(minute, 0, 59);
    if (weekdays.isEmpty ||
        weekdays.length > 7 ||
        weekdays.toSet().length != weekdays.length ||
        weekdays.any((day) => day < 1 || day > 7) ||
        startDate.year < 2000 ||
        startDate.year > 2100) {
      _invalid('Invalid schedule.');
    }
  }

  Map<String, dynamic> toJson() => {
    'routineIndex': routineIndex,
    'weeks': weeks,
    'weekdays': weekdays,
    'startDate': _date(startDate),
    'hour': hour,
    'minute': minute,
    'reminder': reminder,
  };
  CoachScheduleDraft copyWith({
    int? routineIndex,
    int? weeks,
    List<int>? weekdays,
    DateTime? startDate,
    int? hour,
    int? minute,
    bool? reminder,
  }) => CoachScheduleDraft(
    routineIndex: routineIndex ?? this.routineIndex,
    weeks: weeks ?? this.weeks,
    weekdays: weekdays ?? this.weekdays,
    startDate: startDate ?? this.startDate,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    reminder: reminder ?? this.reminder,
  );
}

String coachRoutineRevision(Routine routine) =>
    _fingerprint(jsonEncode(routine.toJson()));
String coachPlanningRevision({
  required UserProfile profile,
  required String goal,
  required List<Routine> routines,
}) {
  final ordered = [...routines]..sort((a, b) => a.id.compareTo(b.id));
  return _fingerprint(
    jsonEncode({
      'profile': profile.toJson(),
      'goal': goal,
      'routines': ordered.map((item) => item.toJson()).toList(),
    }),
  );
}

String _fingerprint(String text) {
  var left = 0x811c9dc5;
  var right = 0x9e3779b9;
  for (final unit in text.codeUnits) {
    left = ((left ^ unit) * 31) & 0xffffffff;
    right = ((right ^ unit) * 131) & 0xffffffff;
  }
  return left.toRadixString(16).padLeft(8, '0') +
      right.toRadixString(16).padLeft(8, '0');
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
Never _invalid(String message) => throw FormatException(message);
Map<String, dynamic> _object(Object? value) {
  if (value is! Map) _invalid('Expected an object.');
  try {
    return Map<String, dynamic>.from(value);
  } catch (_) {
    _invalid('Invalid object.');
  }
}

List<dynamic> _array(Object? value, int min, int max) {
  if (value is! List || value.length < min || value.length > max) {
    _invalid('Invalid list size.');
  }
  return value;
}

String _text(Object? value, int max, {bool allowEmpty = false}) {
  if (value is! String ||
      value.length > max ||
      (!allowEmpty && value.trim().isEmpty)) {
    _invalid('Invalid plan text.');
  }
  return (value).trim();
}

int _integer(Object? value, int min, int max) {
  if (value is! num ||
      !value.isFinite ||
      value != value.roundToDouble() ||
      value < min ||
      value > max) {
    _invalid('Invalid plan number.');
  }
  return (value).toInt();
}

void _keys(Map<String, dynamic> value, Set<String> allowed) {
  if (value.keys.any((key) => !allowed.contains(key)) ||
      allowed.any((key) => !value.containsKey(key))) {
    _invalid('Unexpected or missing plan fields.');
  }
}
