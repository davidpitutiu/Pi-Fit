import 'dart:convert';

import 'package:http/http.dart' as http;

import 'firebase_gateway.dart';

class CoachReply {
  const CoachReply(this.message, {this.proposal});
  final String message;

  /// Untrusted structured output. CoachPlanService validates it against the
  /// captured catalog, custom routine revisions and account before use.
  final Map<String, dynamic>? proposal;
}

/// Provider credentials stay on the authenticated server, never in the app.
class CoachService {
  static const _endpoint = String.fromEnvironment('AI_COACH_URL');
  CoachService({String? endpoint}) : _url = endpoint ?? _endpoint;
  final String _url;
  bool get remoteConfigured => _url.isNotEmpty;

  Future<String> reply(
    String message, {
    required String context,
    String? localContext,
    List<Map<String, String>> history = const [],
    bool allowRemote = true,
  }) async => (await replyDetailed(
    message,
    context: context,
    localContext: localContext,
    history: history,
    allowRemote: allowRemote,
  )).message;

  Future<CoachReply> replyDetailed(
    String message, {
    required String context,
    String? localContext,
    List<Map<String, String>> history = const [],
    bool allowRemote = true,
  }) async {
    final question = message.trim();
    if (question.isEmpty) {
      throw ArgumentError('Write a question for your coach.');
    }
    if (question.length > 3000) {
      throw ArgumentError('Questions can contain up to 3,000 characters.');
    }
    final turns = boundedHistory(history);
    if (!remoteConfigured || !allowRemote) {
      return CoachReply(
        localSuggestion(
          question,
          context: localContext ?? context,
          history: turns,
          label: remoteConfigured
              ? 'Local suggestion · no online AI used\n\n'
              : null,
        ),
      );
    }
    if (context.length > 24000) {
      throw ArgumentError('The training context is too large.');
    }
    final endpoint = Uri.tryParse(_url);
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        endpoint.host.isEmpty) {
      throw StateError('AI_COACH_URL must be a valid HTTPS URL.');
    }
    final user = FirebaseGateway.instance.currentUser;
    if (user == null) throw StateError('Sign in to use the online AI coach.');
    final requestedUid = user.uid;
    final token = await user.getIdToken();
    if (token == null) throw StateError('Your session expired. Sign in again.');
    if (!tokenMatchesUser(
      token,
      requestedUid: requestedUid,
      currentUid: FirebaseGateway.instance.currentUser?.uid,
    )) {
      throw StateError(
        'The session could not be matched to your account. Sign in again.',
      );
    }
    final response = await http
        .post(
          endpoint,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'message': question,
            'context': context,
            'history': turns,
          }),
        )
        .timeout(const Duration(seconds: 45));
    if (response.statusCode == 429) {
      throw StateError('Too many messages. Try again in a few minutes.');
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('This AI session is not authorized. Sign in again.');
    }
    if (response.statusCode != 200) {
      throw StateError('The online coach is unavailable. Try again later.');
    }
    final body = jsonDecode(response.body);
    if (body is! Map ||
        body['reply'] is! String ||
        (body['reply'] as String).trim().isEmpty ||
        (body['proposal'] != null && body['proposal'] is! Map)) {
      throw StateError('The coach returned an invalid response.');
    }
    return CoachReply(
      body['reply'] as String,
      proposal: body['proposal'] is Map
          ? Map<String, dynamic>.from(body['proposal'] as Map)
          : null,
    );
  }

  static List<Map<String, String>> boundedHistory(
    List<Map<String, String>> history,
  ) {
    final result = <Map<String, String>>[];
    var size = 0;
    for (final turn in history.reversed.take(12)) {
      final role = turn['role'];
      final text = turn['content']?.trim() ?? '';
      if (role != 'user' && role != 'assistant') {
        throw ArgumentError('Invalid conversation role.');
      }
      if (text.isEmpty) continue;
      final content = text.length > 3000 ? text.substring(0, 3000) : text;
      if (size + content.length > 18000) break;
      size += content.length;
      result.insert(0, {'role': role!, 'content': content});
    }
    return result;
  }

  /// A privacy binding check, not JWT authentication. The server separately
  /// verifies the token signature, expiry and revocation. Native FlutterFire
  /// retrieves the current native user's token even from an older Dart User.
  static bool tokenMatchesUser(
    String token, {
    required String requestedUid,
    required String? currentUid,
  }) {
    if (requestedUid.isEmpty ||
        currentUid != requestedUid ||
        token.isEmpty ||
        token.length > 16384) {
      return false;
    }
    final parts = token.split('.');
    if (parts.length != 3 || parts.any((part) => part.isEmpty)) return false;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map &&
          payload['sub'] == requestedUid &&
          (payload['user_id'] == null || payload['user_id'] == requestedUid);
    } catch (_) {
      return false;
    }
  }

  /// Transparent deterministic advice, grounded in the profile and real logs.
  static String localSuggestion(
    String message, {
    String context = '',
    List<Map<String, String>> history = const [],
    String? label,
  }) {
    final prefix =
        label ?? 'Local suggestion · online AI is not configured\n\n';
    final snapshot = _CoachSnapshot.parse(context);
    var query = _normalize(message);
    if (query.length < 45 &&
        RegExp(
          r'^(yes|and |but |how |more |why|what now|da|si |dar |cum |mai |de ce)',
        ).hasMatch(query)) {
      for (final turn in history.reversed) {
        if (turn['role'] == 'user' && turn['content'] != message) {
          query = '$query ${_normalize(turn['content'] ?? '')}';
          break;
        }
      }
    }
    if (RegExp(
      r'pain|hurt|injur|faint|dizz|durer|accident|doare|amet',
    ).hasMatch(query)) {
      return '${prefix}Stop the exercise that causes pain. Do not push through sharp '
          'or unusual pain. If it persists, speak with a doctor or physiotherapist '
          'before resuming. For chest pain, fainting or severe breathing difficulty, '
          'seek urgent medical help. Your profile and workout log cannot establish a diagnosis.';
    }
    final intro = snapshot.summary;
    final activeAdvice = snapshot.activeAdvice(query);
    if (activeAdvice != null) return '$prefix$intro\n\n$activeAdvice';
    final limits = snapshot.limitations.isEmpty
        ? ''
        : '\n\nYour stated limitations: '
              '“${_short(snapshot.limitations, 240)}”. Local rules cannot assess these medically. '
              'Avoid movements that trigger symptoms and discuss adaptations with a qualified professional.';
    if (RegExp(
      r'calor|nutri|diet|protein|food|weight loss|slab|manc',
    ).hasMatch(query)) {
      return '$prefix$intro\n\n${snapshot.frequency == null ? 'Set a sustainable weekly training target first.' : 'Keep your chosen ${snapshot.frequency} sessions per week rather than exercising to compensate for meals.'} '
          'Start with regular meals, protein sources, vegetables and hydration. '
          'Follow trends over several weeks. A workout log alone cannot determine '
          'your calorie requirements; daily activity and dietary context are missing. '
          'A dietitian can help with an individual nutrition plan.$limits';
    }
    if (RegExp(
      r'rest|recover|sleep|tired|fatigue|odih|pauz|recup|somn|obosit',
    ).hasMatch(query)) {
      return '$prefix$intro\n\nRest 2–3 minutes after demanding compound sets and '
          '60–90 seconds after accessories, extending rest if technique or reps decline. '
          'Alternate muscle groups or allow roughly 48 hours before training the same '
          'muscles hard again. With ${snapshot.frequency ?? 'your chosen'} weekly sessions, '
          'alternate effort rather than making every day hard. If fatigue builds, '
          'reduce one set per exercise for a week and reassess. '
          'Your log does not measure sleep: how did you sleep and how do you feel today?$limits';
    }
    if (RegExp(
      r'begin|first|program|plan|full|routine|week|incep|prim|rutina|saptamana',
    ).hasMatch(query)) {
      return '$prefix$intro\n\n${snapshot.plan}$limits';
    }
    return '$prefix$intro\n\n${snapshot.progression(query)}$limits';
  }
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll('ă', 'a')
    .replaceAll('â', 'a')
    .replaceAll('î', 'i')
    .replaceAll('ș', 's')
    .replaceAll('ş', 's')
    .replaceAll('ț', 't')
    .replaceAll('ţ', 't');
String _short(String value, int max) =>
    value.length > max ? '${value.substring(0, max)}…' : value;
String _number(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<dynamic> _list(Object? value) => value is List ? value : [];

class _CoachSnapshot {
  _CoachSnapshot(this.data);
  final Map<String, dynamic> data;
  factory _CoachSnapshot.parse(String context) {
    try {
      return _CoachSnapshot(_map(jsonDecode(context)));
    } catch (_) {
      return _CoachSnapshot({});
    }
  }
  Map<String, dynamic> get profile => _map(data['profile']);
  String get goal => data['goal'] is String ? data['goal'] as String : '';
  String get limitations =>
      profile['limitations'] is String ? profile['limitations'] as String : '';
  int? get frequency => profile['sessionsPerWeek'] is int
      ? profile['sessionsPerWeek'] as int
      : null;
  int? get minutes => profile['sessionMinutes'] is int
      ? profile['sessionMinutes'] as int
      : null;
  List<String> get equipment =>
      _list(profile['equipment']).whereType<String>().toList();
  String get summary {
    if (profile.isEmpty) {
      return 'I do not have structured preferences or completed sets yet. '
          'Complete your training profile for more specific local suggestions.';
    }
    final count = _map(data['statistics'])['workoutCount'];
    return 'Your profile: ${goal.isEmpty ? '' : '$goal · '}${profile['experience'] ?? 'experience not set'}'
        '${frequency == null ? '' : ' · $frequency sessions/week'}${minutes == null ? '' : ' · $minutes min/session'}'
        '${equipment.isEmpty ? '' : ' · equipment: ${equipment.join(', ')}'}.'
        '${count is num ? ' Your log contains ${count.toInt()} workouts in the last 28 days.' : ''}';
  }

  String get plan {
    final days = frequency;
    if (days == null) {
      return 'How many days per week and minutes per session can you sustain? '
          'Set these in Profile. For one introductory session, choose a squat, a push, '
          'a pull and a core movement: 2 sets of 8–12 reps, keeping about 2 reps in reserve. '
          'I cannot choose a personal weekly frequency without your availability.';
    }
    final split = switch (days) {
      1 => '1 full-body session',
      2 => '2 full-body sessions, with at least one recovery day between them',
      3 => '3 full-body sessions, alternating movements and recovery days',
      4 => '4 sessions: upper / lower / recovery / upper / lower',
      5 =>
        '5 sessions: two upper, two lower and one light conditioning or technique session',
      _ =>
        '$days available days: up to 6 push / pull / legs sessions, with easier effort in the second rotation and a recovery day',
    };
    final novice = RegExp(
      r'beginner|incep',
    ).hasMatch(_normalize('${profile['experience']}'));
    final count = (minutes ?? 60) <= 30
        ? 3
        : (minutes ?? 60) <= 45
        ? 4
        : 5;
    return 'Suggested split: $split.\n\nFor each session: $count exercises, '
        '${novice ? '2' : '2–3'} working sets, 8–12 reps and about 2 reps in reserve. '
        '${equipment.any((item) => RegExp(r'dumbbell|ganter').hasMatch(_normalize(item))) ? 'With dumbbells: goblet squat, a suitable press and one-arm row; add a hip hinge and dead bug when time allows.' : 'Choose catalog movements that match your available equipment: a squat, push, pull and hip hinge.'} '
        'Warm up for 5–8 minutes plus lighter practice sets. Rest 2–3 minutes for '
        'compound lifts and 60–90 seconds for accessories. '
        '${minutes != null && minutes! <= 30 ? 'Within your $minutes minutes, keep 2 sets and avoid rushing. ' : ''}'
        'Log the results and reassess after 2–4 weeks. This is a suggestion; nothing was added to your calendar.';
  }

  String? activeAdvice(String query) {
    if (!RegExp(
      r'active|next set|current workout|rpe|effort',
    ).hasMatch(query)) {
      return null;
    }
    final active = _map(data['activeWorkout'] ?? data['activeSession']);
    final id = data['currentExerciseId'];
    final exercises = _list(active['exercises']).map(_map).toList();
    if (id == null || exercises.isEmpty) return null;
    final matching = exercises.where((item) => item['exerciseId'] == id);
    if (matching.isEmpty) return null;
    final exercise = matching.first;
    final sets = _list(
      exercise['sets'],
    ).map(_map).where((item) => item['completed'] == true).toList();
    if (sets.isEmpty) {
      return 'Log a completed set for the selected exercise first. Effort ratings are subjective and should not be guessed.';
    }
    final set = sets.last;
    final rpe = set['rpe'];
    if (rpe is! num || !rpe.isFinite || rpe < 1 || rpe > 10) {
      return 'Add a subjective effort rating from 1–10 to your last completed set. '
          'Until then, keep a manageable load and controlled technique; the log cannot establish your effort.';
    }
    final name = exercise['name'] is String
        ? exercise['name'] as String
        : 'Your selected exercise';
    if (rpe >= 9.5) {
      return '$name: you reported RPE ${_number(rpe)}/10 for the last listed completed set. '
          'That is near your reported limit. Take a longer rest and avoid increasing the next-set load. '
          'Use a smaller available load if controlled reps are no longer possible. Stop a movement that causes pain.';
    }
    return '$name: you reported RPE ${_number(rpe)}/10 for the last listed completed set. '
        'Keep the planned reps and controlled technique. A single effort rating does not establish a progression trend; '
        'increase load only after meeting your targets consistently with reserve.';
  }

  List<_LoggedExercise> get logs {
    final result = <_LoggedExercise>[];
    for (final rawSession in _list(data['recentSessions'])) {
      final session = _map(rawSession);
      final date = DateTime.tryParse('${session['startedAt'] ?? ''}');
      if (date == null) continue;
      for (final rawExercise in _list(session['exercises'])) {
        final exercise = _map(rawExercise);
        final sets = _list(exercise['sets'])
            .map(_map)
            .where(
              (set) =>
                  set['completed'] == true &&
                  set['weight'] is num &&
                  (set['weight'] as num).isFinite &&
                  (set['weight'] as num) >= 0 &&
                  set['reps'] is num &&
                  (set['reps'] as num).isFinite &&
                  (set['reps'] as num) > 0,
            )
            .toList();
        if (sets.isEmpty || exercise['exerciseId'] is! String) continue;
        result.add(
          _LoggedExercise(
            date,
            exercise['exerciseId'] as String,
            exercise['name'] is String
                ? exercise['name'] as String
                : 'Saved exercise',
            sets,
          ),
        );
      }
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  String progression(String query) {
    final available = logs;
    if (available.isEmpty) {
      return 'There are no completed sets in this context for a real comparison. '
          'Log load and reps for each set, keeping about 2 reps in reserve. Once every '
          'set reaches the top of your rep range with controlled technique, consider the '
          'smallest available increment. Which exercise would you like to discuss?';
    }
    final named = available
        .where((log) => query.contains(_normalize(log.name)))
        .toList();
    final selected = named.isEmpty ? available.first : named.first;
    final comparable = available.where((log) => log.id == selected.id).toList();
    final latest = comparable.first;
    final observation =
        '${latest.name}: on ${latest.date.day}/${latest.date.month}, '
        '${latest.sets.length} completed sets; at the highest load of ${_number(latest.weight)} kg, '
        'your best set had ${latest.repsAtTopWeight} reps.'
        '${latest.lastRpe == null ? '' : ' Your last set reports RPE ${_number(latest.lastRpe!)}/10 (subjective effort).'}';
    if (latest.lastRpe != null && latest.lastRpe! >= 9.5) {
      return '$observation Avoid increasing load after a set this close to your reported limit. '
          'Prioritize rest and controlled reps, and reduce the load or volume if technique or recovery declines.';
    }
    if (comparable.length < 2) {
      return '$observation I have only one session for this exercise, '
          'so I cannot establish a trend or choose a heavier personal training load. '
          'Repeat another comparable session and track reps and technique.';
    }
    final before = comparable[1];
    if (latest.weight == before.weight &&
        latest.repsAtTopWeight > before.repsAtTopWeight) {
      return '$observation You increased from ${before.repsAtTopWeight} to ${latest.repsAtTopWeight} '
          'reps at ${_number(latest.weight)} kg. Keep that load until every set reaches '
          'your rep target with 1–2 reps in reserve. Then try the smallest practical '
          'increment, roughly 2–5% if available. The log does not confirm technique or perceived effort.';
    }
    if (latest.weight > before.weight) {
      return '$observation Your highest load increased from '
          '${_number(before.weight)} to ${_number(latest.weight)} kg. Load alone does not '
          'prove a strength gain. Maintain it and check reps, technique and 1–2 reps '
          'in reserve before progressing again.';
    }
    final unchanged =
        comparable.length >= 3 &&
        comparable
            .take(3)
            .every(
              (log) =>
                  log.weight == latest.weight &&
                  log.repsAtTopWeight == latest.repsAtTopWeight &&
                  log.sets.length == latest.sets.length,
            );
    if (unchanged) {
      return '$observation In the last 3 sessions, the highest load, best '
          'set and number of sets stayed unchanged. This does not establish a physiological '
          'plateau. First try one more rep in one set with comparable technique and effort. '
          'If fatigue is high, temporarily reduce volume rather than adding weight.';
    }
    return '$observation Previously: ${_number(before.weight)} kg × ${before.repsAtTopWeight} '
        'in your best set. These conditions differ, so two values alone do not establish '
        'progress or regression. Compare the same sets and technique; add reps before load. '
        'How did the last sets feel?';
  }
}

class _LoggedExercise {
  _LoggedExercise(this.date, this.id, this.name, this.sets);
  final DateTime date;
  final String id;
  final String name;
  final List<Map<String, dynamic>> sets;
  num? get lastRpe {
    final value = sets.last['rpe'];
    return value is num && value.isFinite && value >= 1 && value <= 10
        ? value
        : null;
  }

  num get weight =>
      sets.map((set) => set['weight'] as num).reduce((a, b) => a > b ? a : b);
  int get repsAtTopWeight => sets
      .where((set) => set['weight'] == weight)
      .map((set) => (set['reps'] as num).toInt())
      .reduce((a, b) => a > b ? a : b);
}
