import 'dart:convert';

import '../domain/coach_plan.dart';
import '../domain/models.dart';
import '../domain/user_profile.dart';
import '../state/app_store.dart';
import 'coach_service.dart';
import 'firebase_gateway.dart';

class CoachPlanResponse {
  const CoachPlanResponse({
    required this.message,
    this.proposal,
    required this.source,
  });
  final String message;
  final CoachProposal? proposal;
  final CoachProposalSource source;
}

/// Produces a validated preview. This service never writes routines or dates.
class CoachPlanService {
  CoachPlanService({CoachService? coach, FirebaseGateway? gateway})
    : _coach = coach ?? CoachService(),
      _gateway = gateway ?? FirebaseGateway.instance;
  final CoachService _coach;
  final FirebaseGateway _gateway;

  static bool isPlanRequest(String message) {
    final q = _normal(message);
    if (_sensitive(q)) return false;
    return RegExp(
          r'creat|build|generat|design|make|i want|would like|vreau|creeaz|fa-mi|fa un|add |include |replace |swap |remove |edit |modify |change |schedule |adauga|inlocui|schimba|programeaz',
        ).hasMatch(q) &&
        RegExp(
          r'plan|program|workout|routine|split|exercise|day|session|antrenament|rutina|exercit|zile',
        ).hasMatch(q);
  }

  Future<CoachPlanResponse> reply(
    String message, {
    required AppStore store,
    List<Map<String, String>> history = const [],
    String? targetRoutineId,
  }) async {
    final question = message.trim();
    if (question.isEmpty || question.length > 3000) {
      throw ArgumentError('Write a question of up to 3,000 characters.');
    }
    // Capture before awaiting anything: a response for account A stays bound to A.
    final accountId = store.accountId;
    final profile = store.profile;
    final goal = store.goal;
    final catalog = List<Exercise>.of(store.exercises);
    final customs = store.customRoutines
        .map((item) => Routine.fromJson(item.toJson()))
        .toList();
    final revision = coachPlanningRevision(
      profile: profile,
      goal: goal,
      routines: customs,
    );
    final remoteContext = store.coachContext;
    final localContext = store.localCoachContext;
    var action = isPlanRequest(question);
    Routine? target;
    if (targetRoutineId != null) {
      for (final routine in customs) {
        if (routine.id == targetRoutineId) target = routine;
      }
    } else {
      for (final routine in customs) {
        if (_normal(question).contains(_normal(routine.name))) target = routine;
      }
      if (target == null && _editIntent(question) && customs.length == 1) {
        target = customs.single;
      }
    }
    action =
        action ||
        (target != null &&
            _editIntent(question) &&
            !_sensitive(_normal(question)));
    final allowed = _available(catalog, profile);
    final planningCatalog = [
      ...catalog.where(
        (item) =>
            target?.exercises.any((entry) => entry.exerciseId == item.id) ??
            false,
      ),
      ...allowed,
    ];
    final planning = action
        ? _planningContext(question, planningCatalog, target)
        : null;
    if (_coach.remoteConfigured &&
        profile.coachConsent &&
        accountId != null &&
        _gateway.currentUser?.uid == accountId) {
      try {
        final data = Map<String, dynamic>.from(
          jsonDecode(remoteContext) as Map,
        );
        if (planning != null) data['planning'] = planning;
        // Bounded context stays valid JSON; discard older sessions first.
        while (jsonEncode(data).length > 24000 &&
            (data['recentSessions'] as List? ?? []).isNotEmpty) {
          (data['recentSessions'] as List).removeLast();
        }
        final response = await _coach.replyDetailed(
          question,
          context: jsonEncode(data),
          localContext: localContext,
          history: history,
          allowRemote: true,
        );
        final raw = response.proposal;
        final proposal = raw == null || !action
            ? null
            : CoachProposal.fromWireJson(
                raw,
                accountId: accountId,
                baseRevision: revision,
                source: CoachProposalSource.online,
                catalog: catalog,
                customRoutines: customs,
              );
        return CoachPlanResponse(
          message: response.message,
          proposal: proposal,
          source: CoachProposalSource.online,
        );
      } catch (_) {
        final fallback = _local(
          question,
          action,
          target,
          targetRoutineId,
          profile,
          goal,
          catalog,
          customs,
          accountId,
          revision,
          localContext,
          history,
        );
        return CoachPlanResponse(
          message: 'The online coach is unavailable. ${fallback.message}',
          proposal: fallback.proposal,
          source: CoachProposalSource.local,
        );
      }
    }
    return _local(
      question,
      action,
      target,
      targetRoutineId,
      profile,
      goal,
      catalog,
      customs,
      accountId,
      revision,
      localContext,
      history,
    );
  }

  CoachPlanResponse _local(
    String message,
    bool action,
    Routine? target,
    String? requestedTarget,
    UserProfile profile,
    String goal,
    List<Exercise> catalog,
    List<Routine> customs,
    String? accountId,
    String revision,
    String localContext,
    List<Map<String, String>> history,
  ) {
    if (!action) {
      return CoachPlanResponse(
        message: CoachService.localSuggestion(
          message,
          context: localContext,
          history: history,
        ),
        source: CoachProposalSource.local,
      );
    }
    if ((requestedTarget != null || _editIntent(message)) && target == null) {
      return const CoachPlanResponse(
        message:
            'Local planner · choose the custom routine you want to change. '
            'Built-in templates are kept intact; create a custom copy first.',
        source: CoachProposalSource.local,
      );
    }
    final available = _available(catalog, profile);
    if (available.isEmpty) {
      return const CoachPlanResponse(
        message:
            'Local planner · no compatible '
            'catalog exercises were found. Check your equipment preferences.',
        source: CoachProposalSource.local,
      );
    }
    final drafts = <CoachRoutineDraft>[];
    if (target != null && _editIntent(message)) {
      final changed = _edit(message, target, available, catalog, profile);
      if (changed == null) {
        return const CoachPlanResponse(
          message:
              'Local planner · tell me the exercise '
              'to add, remove or replace, using its library name, or request a specific number of sets/reps. '
              'No routine was changed.',
          source: CoachProposalSource.local,
        );
      }
      drafts.add(changed);
    } else {
      final requested = RegExp(
        r'\b([1-7])\s*(?:day|days|session|sessions|zile|zilele)\b',
      ).firstMatch(_normal(message));
      final days = requested == null
          ? profile.sessionsPerWeek
          : int.parse(requested.group(1)!);
      final duration = RegExp(
        r'\b(\d{2,3})\s*(?:min|minute|minutes)\b',
      ).firstMatch(_normal(message));
      final minutes = duration == null
          ? profile.sessionMinutes
          : int.parse(duration.group(1)!).clamp(15, 180);
      final count = minutes <= 20
          ? 2
          : minutes <= 35
          ? 3
          : minutes <= 50
          ? 4
          : 5;
      final beginner =
          profile.experience == 'Beginner' ||
          _normal(profile.experience).contains('incep');
      final sets = beginner || minutes <= 35 ? 2 : 3;
      final reps = goal.toLowerCase().contains('strength') && !beginner
          ? 8
          : 10;
      for (var day = 0; day < days; day++) {
        final patterns = _patterns(days, day);
        final selected = <Exercise>[];
        for (var slot = 0; slot < count; slot++) {
          final pattern = patterns[slot % patterns.length];
          final exercise = _choose(
            available,
            pattern,
            selected.map((item) => item.id).toSet(),
            day ~/ 2,
          );
          if (exercise != null) selected.add(exercise);
        }
        if (selected.isEmpty) continue;
        final light =
            (days == 7 && day == 6) || (beginner && days >= 5 && day >= 3);
        drafts.add(
          CoachRoutineDraft(
            name: _routineName(days, day),
            subtitle: light
                ? 'Easy technique day; stay well below fatigue.'
                : '$goal · ${profile.experience} · keep about 2 reps in reserve',
            estimatedMinutes: minutes,
            exercises: selected
                .map(
                  (item) => RoutineExercise(
                    exerciseId: item.id,
                    sets: light ? 1 : sets,
                    reps: reps,
                    weight: 0,
                  ),
                )
                .toList(),
          ),
        );
      }
    }
    if (drafts.isEmpty) {
      return const CoachPlanResponse(
        message:
            'Local planner · adjust your equipment '
            'preferences before creating this routine.',
        source: CoachProposalSource.local,
      );
    }
    final schedule =
        RegExp(
          r'schedule|calendar|bulk|programeaz|programare',
        ).hasMatch(_normal(message))
        ? _schedule(message, profile)
        : null;
    final summary =
        'Built from your ${profile.experience.toLowerCase()} profile, ${drafts.first.estimatedMinutes}-minute '
        'availability and ${profile.equipment.isEmpty ? 'bodyweight only (equipment is not set)' : profile.equipment.join(', ')}. '
        'Zero load means choose and log an appropriate starting load; no lifting weight was invented. '
        'Warm up and leave about 2 reps in reserve.${profile.limitations.isEmpty ? '' : ' Your limitations need an individual review; this planner cannot assess them medically.'}'
        '${schedule == null ? '' : ' The optional bulk schedule applies only to the selected routine; review its dates and time.'}';
    final proposal = CoachProposal.fromWireJson(
      {
        'schemaVersion': 1,
        'title': target == null
            ? 'Your ${drafts.length}-session program'
            : 'Update ${target.name}',
        'summary': summary,
        'routines': drafts.map((item) => item.toJson()).toList(),
        'schedule': schedule?.toJson(),
      },
      accountId: accountId,
      baseRevision: revision,
      source: CoachProposalSource.local,
      catalog: catalog,
      customRoutines: customs,
    );
    return CoachPlanResponse(
      message:
          'Local planner · this is a reviewable proposal, not an online AI response. '
          'Review the exercises and load, then choose Apply. Nothing has been saved or scheduled yet.',
      proposal: proposal,
      source: CoachProposalSource.local,
    );
  }

  CoachRoutineDraft? _edit(
    String message,
    Routine target,
    List<Exercise> available,
    List<Exercise> catalog,
    UserProfile profile,
  ) {
    final q = _normal(message);
    final duration = RegExp(
      r'\b(\d{2,3})\s*(?:min|minute|minutes)\b',
    ).firstMatch(q);
    final plannedMinutes = duration == null
        ? target.estimatedMinutes.clamp(15, 180)
        : int.parse(duration.group(1)!).clamp(15, 180);
    final existing = target.exercises
        .map(
          (item) => item.copyWith(
            sets: item.sets.clamp(1, 8),
            reps: item.reps.clamp(1, 50),
            weight: item.weight.clamp(0, 1000),
          ),
        )
        .toList();
    final byId = {for (final exercise in catalog) exercise.id: exercise};
    if (RegExp(r'replace|swap|inlocui').hasMatch(q)) {
      final parts = q.split(RegExp(r'\s+(?:with|for|cu)\s+'));
      if (parts.length != 2) return null;
      final old = _lookup(
        parts.first,
        existing
            .map((item) => byId[item.exerciseId])
            .whereType<Exercise>()
            .toList(),
      );
      final replacement = _lookup(parts.last, available);
      if (old == null ||
          replacement == null ||
          old.id == replacement.id ||
          existing.any((item) => item.exerciseId == replacement.id)) {
        return null;
      }
      final index = existing.indexWhere((item) => item.exerciseId == old.id);
      existing[index] = existing[index].copyWith(
        exerciseId: replacement.id,
        weight: 0,
      );
    } else if (RegExp(r'add |include |adauga').hasMatch(q)) {
      var exercise = _lookup(
        q,
        available
            .where((item) => !existing.any((old) => old.exerciseId == item.id))
            .toList(),
      );
      if (exercise == null &&
          RegExp(r'(?:add|include) (?:an?|another|one) exercise').hasMatch(q)) {
        final used = existing.map((item) => item.exerciseId).toSet();
        for (final pattern in [
          'pull',
          'squat',
          'hinge',
          'push',
          'core',
          'shoulder',
        ]) {
          final represented = existing.any(
            (item) => (_muscles[pattern] ?? []).any(
              (muscle) =>
                  _normal(byId[item.exerciseId]?.muscle ?? '').contains(muscle),
            ),
          );
          if (!represented) {
            exercise = _choose(available, pattern, used, 0);
            if (exercise != null) break;
          }
        }
      }
      if (exercise == null || existing.length >= 12) return null;
      existing.add(
        RoutineExercise(
          exerciseId: exercise.id,
          sets: profile.experience == 'Beginner' ? 2 : 3,
          reps: 10,
        ),
      );
    } else if (RegExp(r'remove |delete |elimina|scoate').hasMatch(q)) {
      final exercise = _lookup(
        q,
        existing
            .map((item) => byId[item.exerciseId])
            .whereType<Exercise>()
            .toList(),
      );
      if (exercise == null || existing.length <= 1) return null;
      existing.removeWhere((item) => item.exerciseId == exercise.id);
    } else {
      final sets = RegExp(r'\b([1-8])\s*sets?\b').firstMatch(q);
      final reps = RegExp(r'\b(\d{1,2})\s*reps?\b').firstMatch(q);
      if (RegExp(r'shorter|less time|mai scurt').hasMatch(q) &&
          existing.length > 1) {
        existing.removeLast();
      } else if (sets != null || reps != null || duration != null) {
        if (duration != null) {
          final count = plannedMinutes <= 20
              ? 2
              : plannedMinutes <= 35
              ? 3
              : plannedMinutes <= 50
              ? 4
              : 5;
          if (existing.length > count) {
            existing.removeRange(count, existing.length);
          }
        }
        for (var index = 0; index < existing.length; index++) {
          existing[index] = existing[index].copyWith(
            sets: sets == null ? null : int.parse(sets.group(1)!),
            reps: reps == null ? null : int.parse(reps.group(1)!).clamp(1, 50),
          );
        }
      } else if (!RegExp(r'schedule|calendar|bulk|programare').hasMatch(q)) {
        return null;
      }
    }
    return CoachRoutineDraft(
      targetRoutineId: target.id,
      expectedRevision: coachRoutineRevision(target),
      name: target.name,
      subtitle: 'Updated for your current training preferences.',
      estimatedMinutes: plannedMinutes,
      exercises: existing,
    );
  }
}

bool _sensitive(String query) => RegExp(
  r'pain|hurt|injur|faint|dizz|calori|nutrition|diet|durer|doare|accident|slab|amet',
).hasMatch(query);
bool _editIntent(String message) =>
    !RegExp(r'create|build|generat|design|creeaz').hasMatch(_normal(message)) &&
    RegExp(
      r'add |include |replace |swap |remove |delete |edit |modify |change |schedule |adauga|inlocui|schimba|programeaz',
    ).hasMatch(_normal(message));
String _normal(String value) => value
    .toLowerCase()
    .replaceAll('ă', 'a')
    .replaceAll('â', 'a')
    .replaceAll('î', 'i')
    .replaceAll('ș', 's')
    .replaceAll('ț', 't')
    .replaceAll('_', ' ')
    .replaceAll('-', ' ');
String _equipment(String value) {
  final q = _normal(UserProfile.normalizeEquipment(value));
  if (q.contains('body') || q.contains('corp') || q == 'none') {
    return 'bodyweight';
  }
  if (q.contains('dumbbell') || q.contains('ganter')) return 'dumbbells';
  if (q.contains('barbell') || q == 'bara' || q.contains('ez bar')) {
    return 'barbell';
  }
  if (q.contains('machine') || q.contains('aparat')) return 'machines';
  if (q.contains('cable') || q.contains('cablu')) return 'cable';
  if (q.contains('band') || q.contains('elastic')) return 'bands';
  return q;
}

List<Exercise> _available(List<Exercise> catalog, UserProfile profile) {
  final equipment = profile.equipment.map(_equipment).toSet();
  final all = equipment.contains('full gym');
  return catalog.where((exercise) {
    if (!all &&
        _equipment(exercise.equipment) != 'bodyweight' &&
        !equipment.contains(_equipment(exercise.equipment))) {
      return false;
    }
    final text = _normal('${exercise.name} ${exercise.sourceId}');
    final instructions = _normal(exercise.steps.join(' '));
    if (!all &&
        !equipment.contains('bench') &&
        (RegExp(r'bench|incline|decline').hasMatch(text) ||
            RegExp(r'bench|banca').hasMatch(instructions))) {
      return false;
    }
    if (!all &&
        !equipment.contains('pull up bar') &&
        RegExp(r'pullup|pull up|chinup|chin up|hanging').hasMatch(text)) {
      return false;
    }
    if (!all &&
        !equipment.contains('dip bars') &&
        RegExp(r'\bdips?\b').hasMatch(text) &&
        !text.contains('bench')) {
      return false;
    }
    if (profile.experience == 'Beginner' &&
        RegExp(r'advanced|avansat').hasMatch(_normal(exercise.difficulty))) {
      return false;
    }
    if (RegExp(
      r'stretch|cardio|plyometric|pliometric|olympic|strongman',
    ).hasMatch(_normal(exercise.category))) {
      return false;
    }
    final limits = _normal(profile.limitations);
    for (final restriction in [
      'barbell',
      'dumbbell',
      'machine',
      'cable',
      'band',
    ]) {
      if (RegExp('(?:no|avoid|without) ${restriction}s?').hasMatch(limits) &&
          _equipment(exercise.equipment).startsWith(restriction)) {
        return false;
      }
    }
    for (final movement in ['squat', 'lunge', 'deadlift', 'jump']) {
      if (RegExp('(?:no|avoid|without) ${movement}s?').hasMatch(limits) &&
          text.contains(movement)) {
        return false;
      }
    }
    if (RegExp(r'avoid overhead|no overhead|fara deasupra').hasMatch(limits) &&
        RegExp(r'overhead|military|shoulder press').hasMatch(text)) {
      return false;
    }
    if (RegExp(r'no jump|avoid jump|fara sarit').hasMatch(limits) &&
        text.contains('jump')) {
      return false;
    }
    return true;
  }).toList();
}

const _preferred = <String, List<String>>{
  'squat': ['goblet_squat', 'bodyweight_squat', 'leg_press', 'squat', 'lunge'],
  'hinge': ['glute_bridge', 'romanian_deadlift', 'dumbbell_rdl', 'hip_thrust'],
  'push': [
    'db_dumbbell_floor_press',
    'push_up',
    'bench_press',
    'dumbbell_press',
  ],
  'pull': [
    'dumbbell_row',
    'seated_cable_row',
    'superman',
    'lat_pulldown',
    'band_row',
  ],
  'shoulder': [
    'lateral_raise',
    'face_pull',
    'dumbbell_shoulder_press',
    'overhead_press',
  ],
  'core': ['dead_bug', 'bird_dog', 'crunch', 'reverse_crunch'],
  'arms': ['dumbbell_curl', 'hammer_curl', 'triceps_pushdown'],
};
const _muscles = <String, List<String>>{
  'squat': ['quad', 'cvadr', 'glute', 'fesier'],
  'hinge': ['hamstring', 'femural', 'glute', 'fesier'],
  'push': ['chest', 'piept', 'triceps'],
  'pull': ['back', 'spate', 'lat', 'biceps'],
  'shoulder': ['shoulder', 'umer', 'deltoid'],
  'core': ['abdom', 'core'],
  'arms': ['biceps', 'triceps'],
};
Exercise? _choose(
  List<Exercise> candidates,
  String pattern,
  Set<String> used,
  int variation,
) {
  final preferred = (_preferred[pattern] ?? [])
      .where(
        (id) => candidates.any((item) => item.id == id) && !used.contains(id),
      )
      .toList();
  if (preferred.isNotEmpty) {
    return candidates.firstWhere(
      (item) => item.id == preferred[variation % preferred.length],
    );
  }
  final matching = candidates
      .where(
        (item) =>
            !used.contains(item.id) &&
            (_muscles[pattern] ?? []).any(
              (muscle) => _normal(item.muscle).contains(muscle),
            ),
      )
      .toList();
  return matching.isEmpty ? null : matching[variation % matching.length];
}

List<String> _patterns(int days, int day) {
  if (days <= 3) {
    return day.isEven
        ? ['squat', 'push', 'pull', 'hinge', 'core']
        : ['hinge', 'pull', 'push', 'squat', 'core'];
  }
  if (days <= 5) {
    return day.isEven && day < 4
        ? ['push', 'pull', 'shoulder', 'arms', 'core']
        : ['squat', 'hinge', 'core', 'squat', 'hinge'];
  }
  return switch (day % 3) {
    0 => ['push', 'shoulder', 'arms', 'push', 'core'],
    1 => ['pull', 'arms', 'pull', 'core', 'shoulder'],
    _ => ['squat', 'hinge', 'core', 'squat', 'hinge'],
  };
}

String _routineName(int days, int day) => days == 7 && day == 6
    ? 'Day 7 · Easy technique'
    : 'Day ${day + 1} · ${days <= 3
          ? 'Full body ${String.fromCharCode(65 + day)}'
          : days <= 5
          ? (day.isEven && day < 4 ? 'Upper body' : 'Lower body')
          : ['Push', 'Pull', 'Legs'][day % 3]}';
Exercise? _lookup(String query, List<Exercise> catalog) {
  final q = _normal(query);
  final compact = q.replaceAll(RegExp(r'[^a-z0-9]'), '');
  final words = q
      .split(RegExp(r'[^a-z0-9]+'))
      .where(
        (word) =>
            word.length > 2 &&
            !{
              'add',
              'exercise',
              'routine',
              'replace',
              'with',
              'remove',
              'include',
              'please',
              'my',
              'the',
              'program',
            }.contains(word),
      )
      .toSet();
  Exercise? best;
  var bestScore = 0;
  for (final exercise in catalog) {
    final names = [
      exercise.name,
      exercise.sourceId,
      exercise.id,
      ...exercise.aliases,
    ];
    var score = 0;
    for (final name in names) {
      final n = _normal(name);
      final nCompact = n.replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (nCompact.length >= 5 && compact.contains(nCompact)) score = 100;
      final tokens = n.split(RegExp(r'[^a-z0-9]+')).toSet();
      final matches = words.where(tokens.contains).length;
      if (matches >= 2 && matches * 10 > score) score = matches * 10;
    }
    if (score > bestScore) {
      best = exercise;
      bestScore = score;
    }
  }
  return best;
}

CoachScheduleDraft _schedule(String message, UserProfile profile) {
  final weeks = RegExp(
    r'\b(\d{1,2})\s*(?:week|weeks|saptamani)\b',
  ).firstMatch(_normal(message));
  final clock = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)\b').firstMatch(message);
  final now = DateTime.now();
  final date = RegExp(r'\b\d{4}-\d{2}-\d{2}\b').firstMatch(message);
  return CoachScheduleDraft(
    routineIndex: 0,
    weeks: weeks == null ? 4 : int.parse(weeks.group(1)!).clamp(1, 12),
    weekdays: profile.preferredDays.isEmpty
        ? List.generate(
            profile.sessionsPerWeek,
            (index) => index * 7 ~/ profile.sessionsPerWeek + 1,
          )
        : profile.preferredDays,
    startDate: date == null
        ? DateTime(now.year, now.month, now.day + 1)
        : DateTime.tryParse(date.group(0)!) ??
              DateTime(now.year, now.month, now.day + 1),
    hour: clock == null ? 18 : int.parse(clock.group(1)!),
    minute: clock == null ? 0 : int.parse(clock.group(2)!),
  );
}

Map<String, dynamic> _planningContext(
  String message,
  List<Exercise> catalog,
  Routine? target,
) => {
  'intent': _editIntent(message)
      ? _normal(message).contains('replace') ||
                _normal(message).contains('swap')
            ? 'replace'
            : _normal(message).contains('add ')
            ? 'add'
            : 'edit'
      : 'create',
  'catalog': {for (final exercise in catalog) exercise.id: exercise}.values
      .take(100)
      .map(
        (item) => {
          'id': item.id,
          'name': item.name,
          'muscle': item.muscle,
          'equipment': item.equipment,
        },
      )
      .toList(),
  'customRoutines': target == null
      ? []
      : [
          {
            'id': target.id,
            'revision': coachRoutineRevision(target),
            'name': target.name,
            'exercises': target.exercises
                .take(12)
                .map((item) => item.toJson())
                .toList(),
          },
        ],
  'targetRoutineId': target?.id,
};
