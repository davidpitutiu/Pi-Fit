import 'dart:convert';

import 'package:http/http.dart' as http;

import 'firebase_gateway.dart';

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
  }) async {
    final question = message.trim();
    if (question.isEmpty) {
      throw ArgumentError('Scrie o întrebare pentru antrenor.');
    }
    if (question.length > 3000) {
      throw ArgumentError('Întrebarea poate avea cel mult 3.000 de caractere.');
    }
    final turns = boundedHistory(history);
    if (!remoteConfigured || !allowRemote) {
      return localSuggestion(
        question,
        // This additional private context is never included in an HTTP body.
        context: localContext ?? context,
        history: turns,
        label: remoteConfigured
            ? 'Sugestie locală · răspuns fără AI online\n\n'
            : null,
      );
    }
    if (context.length > 24000) {
      throw ArgumentError('Contextul este prea mare. Redu istoricul transmis.');
    }
    final endpoint = Uri.tryParse(_url);
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        endpoint.host.isEmpty) {
      throw StateError('AI_COACH_URL trebuie să fie o adresă HTTPS validă.');
    }
    final user = FirebaseGateway.instance.currentUser;
    if (user == null) {
      throw StateError('Autentifică-te pentru a discuta cu antrenorul AI.');
    }
    final token = await user.getIdToken();
    if (token == null) {
      throw StateError('Sesiunea a expirat. Autentifică-te din nou.');
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
      throw StateError(
        'Ai trimis multe mesaje. Încearcă din nou în câteva minute.',
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError(
        'Sesiunea AI nu este autorizată. Autentifică-te din nou.',
      );
    }
    if (response.statusCode != 200) {
      throw StateError(
        'Antrenorul AI nu este disponibil acum. Încearcă din nou.',
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map ||
        body['reply'] is! String ||
        (body['reply'] as String).trim().isEmpty) {
      throw StateError('Răspunsul antrenorului AI nu este valid.');
    }
    return body['reply'] as String;
  }

  /// Recent conversation is bounded on both sides of the API boundary.
  static List<Map<String, String>> boundedHistory(
    List<Map<String, String>> history,
  ) {
    final result = <Map<String, String>>[];
    var size = 0;
    for (final turn in history.reversed.take(12)) {
      final role = turn['role'];
      final text = turn['content']?.trim() ?? '';
      if (role != 'user' && role != 'assistant') {
        throw ArgumentError('Rol de conversație nevalid.');
      }
      if (text.isEmpty) continue;
      final content = text.length > 3000 ? text.substring(0, 3000) : text;
      if (size + content.length > 18000) break;
      size += content.length;
      result.insert(0, {'role': role!, 'content': content});
    }
    return result;
  }

  /// Deterministic local rules use actual preferences and logs. They are
  /// explicitly labeled and never presented as a language model response.
  static String localSuggestion(
    String message, {
    String context = '',
    List<Map<String, String>> history = const [],
    String? label,
  }) {
    final prefix =
        label ?? 'Sugestie locală · AI-ul online nu este configurat\n\n';
    final snapshot = _CoachSnapshot.parse(context);
    var query = _normalize(message);
    // A short follow-up can refer to the last user topic, rather than restart.
    if (query.length < 45 &&
        RegExp(
          r'^(da|si |dar |cum |mai |detali|contin|de ce|ce fac|asta)',
        ).hasMatch(query)) {
      for (final turn in history.reversed) {
        if (turn['role'] == 'user' && turn['content'] != message) {
          query = '$query ${_normalize(turn['content'] ?? '')}';
          break;
        }
      }
    }
    if (RegExp(r'durer|durere|accident|doare|amet').hasMatch(query)) {
      return '${prefix}Oprește exercițiul care provoacă durere. Nu încerca să '
          'treci peste o durere ascuțită sau neobișnuită. Dacă persistă, discută '
          'cu un medic sau fizioterapeut înainte de a relua antrenamentul. '
          'Pentru durere în piept, leșin sau dificultăți de respirație, cere '
          'ajutor medical imediat. Nu pot stabili cauza din profil sau jurnal.';
    }
    final intro = snapshot.summary;
    final limitation = snapshot.limitations.isEmpty
        ? ''
        : '\n\nAi notat limite sau preferințe: „${_short(snapshot.limitations, 240)}”. '
              'Recomandarea locală nu le poate evalua medical. Evită mișcările '
              'care provoacă simptome și discută adaptările cu un specialist.';
    if (RegExp(r'slab|calor|nutri|manc|diet|prote').hasMatch(query)) {
      final target = snapshot.frequency == null
          ? 'Frecvența ta nu este completată; alege întâi câte zile poți susține.'
          : 'Păstrează obiectivul tău de ${snapshot.frequency} ședințe pe săptămână, '
                'fără să adaugi antrenamente ca să compensezi mesele.';
      return '$prefix$intro\n\n$target Mese regulate, surse de proteine, legume '
          'și hidratare sunt un punct de plecare. '
          '${snapshot.goal.contains('greut') ? 'Pentru controlul greutății urmărește tendințe pe mai multe săptămâni, nu variații zilnice. ' : ''}'
          'Nu pot calcula un necesar caloric corect doar din jurnal; lipsesc '
          'activitatea zilnică și contextul alimentar. Pentru un plan individual, '
          'lucrează cu un dietetician.$limitation';
    }
    if (RegExp(r'odih|pauz|recup|somn|obosit').hasMatch(query)) {
      return '$prefix$intro\n\nLa exerciții compuse solicitante încearcă 2–3 minute '
          'între seturi; la accesorii 60–90 de secunde, prelungind pauza dacă '
          'tehnica sau repetările scad. Alternează grupele sau lasă aproximativ '
          '48 de ore înainte să le antrenezi intens din nou. '
          '${snapshot.frequency != null && snapshot.frequency! >= 5 ? 'Cu ${snapshot.frequency} zile disponibile, alternează efortul; nu transforma toate zilele în sesiuni grele. ' : ''}'
          'Dacă recuperarea scade, redu întâi 1 set pe exercițiu pentru o '
          'săptămână și reevaluează. Jurnalul nu măsoară somnul sau oboseala; '
          'câte ore ai dormit și cum te simți azi?$limitation';
    }
    if (RegExp(
      r'incep|prim|program|plan|full|rutina|saptamana',
    ).hasMatch(query)) {
      return '$prefix$intro\n\n${snapshot.plan}$limitation';
    }
    return '$prefix$intro\n\n${snapshot.progression(query)}$limitation';
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
  Map<String, dynamic> get statistics => _map(data['statistics']);
  String get goal => data['goal'] is String ? data['goal'] as String : '';
  String get experience =>
      profile['experience'] is String ? profile['experience'] as String : '';
  String get limitations =>
      profile['limitations'] is String ? profile['limitations'] as String : '';
  int? get frequency {
    final value = profile['sessionsPerWeek'];
    return value is int && value >= 1 && value <= 7 ? value : null;
  }

  int? get minutes {
    final value = profile['sessionMinutes'];
    return value is int && value >= 15 && value <= 180 ? value : null;
  }

  List<String> get equipment =>
      _list(profile['equipment']).whereType<String>().toList();

  String get summary {
    if (profile.isEmpty) {
      return 'Nu am încă preferințe structurate sau seturi din jurnal. '
          'Completează Profilul sportiv pentru recomandări locale adaptate.';
    }
    final pieces = <String>[
      if (goal.isNotEmpty) 'obiectiv „$goal”',
      if (experience.isNotEmpty) 'nivel ${experience.toLowerCase()}',
      if (frequency != null) '$frequency ședințe/săptămână',
      if (minutes != null) '$minutes min/ședință',
      if (equipment.isNotEmpty) 'echipament: ${equipment.join(', ')}',
    ];
    final count = statistics['workoutCount'];
    return 'Din profilul tău: ${pieces.join(' · ')}.'
        '${count is num ? ' Jurnalul conține ${count.toInt()} antrenamente în ultimele 28 de zile.' : ''}';
  }

  String get plan {
    final days = frequency;
    if (days == null) {
      return 'Câte zile pe săptămână și câte minute pe ședință ai disponibile? '
          'Setează aceste preferințe în Profil. Până atunci, la o ședință alege '
          'o mișcare pentru picioare, o împingere, un tras și abdomen: '
          '2 seturi de 8–12 repetări, cu aproximativ 2 repetări în rezervă. '
          'Nu pot alege o frecvență personală fără aceste detalii.';
    }
    final split = switch (days) {
      1 => '1 ședință full body, pentru toate grupele principale',
      2 => '2 ședințe full body, separate de cel puțin o zi de recuperare',
      3 => '3 ședințe full body, alternând exercițiile și o zi de recuperare',
      4 =>
        '4 ședințe: partea superioară / inferioară / pauză / superioară / inferioară',
      5 =>
        '5 ședințe: 2 pentru partea superioară, 2 pentru partea inferioară și 1 ușoară de condiție sau tehnică',
      6 =>
        '6 ședințe: împins / tras / picioare repetat, cu efort moderat în a doua rotație',
      _ =>
        '7 zile disponibile, dar numai 4 ședințe de forță; folosește 3 zile pentru mers, mobilitate sau recuperare',
    };
    final novice = _normalize(experience).contains('incep');
    final sets = novice ? '2' : '2–3';
    final strength = _normalize(goal).contains('forta');
    final repRange = strength && !novice
        ? '4–6 la mișcarea principală și 8–12 la accesorii'
        : '8–12';
    final exerciseCount = (minutes ?? 60) <= 30
        ? 3
        : (minutes ?? 60) <= 45
        ? 4
        : 5;
    return 'Propunere pentru $split.\n\n'
        'La fiecare ședință: $exerciseCount exerciții, $sets seturi de lucru, '
        '$repRange repetări, cu 2 repetări în rezervă. '
        '${_exerciseChoices(exerciseCount)} '
        'Încălzire 5–8 minute plus seturi ușoare de acomodare; '
        'pauze 2–3 minute la mișcări compuse și 60–90 secunde la accesorii. '
        '${minutes != null && minutes! <= 30 ? 'În timpul tău de $minutes minute, păstrează 2 seturi și alternează grupele ca să eviți graba. ' : ''}'
        'Înregistrează seturile și reevaluează după 2–4 săptămâni. '
        'Aceasta este o propunere; nu am adăugat nimic în calendar.';
  }

  String _exerciseChoices(int count) {
    final available = _normalize(equipment.join(' '));
    if (available.isEmpty) {
      return 'Nu ai selectat echipamentul; alege variantele disponibile din catalog '
          'pentru genuflexiune, împingere, tras${count >= 4 ? ' și extensia șoldului' : ''}.';
    }
    if (!RegExp(r'ganter|haltera|aparat|scrip|bara').hasMatch(available)) {
      return 'Cu echipamentul indicat: genuflexiune la scaun, flotări la perete '
          'sau înclinate și pod fesier${count >= 4 ? ', apoi dead bug' : ''}. '
          'Pentru o mișcare de tras ai nevoie de o bandă sau un suport sigur; '
          'nu improviza ancorări nesigure.';
    }
    if (available.contains('ganter')) {
      return 'Cu gantere: goblet squat, împins cu gantere și ramat cu o ganteră'
          '${count >= 4 ? ', apoi îndreptări românești cu gantere' : ''}'
          '${count >= 5 ? ' și dead bug' : ''}. '
          'Distribuie aceste tipare după grupele din ziua aleasă.';
    }
    return 'Selectează din catalog variante pentru picioare, împins și tras '
        'compatibile cu ${equipment.join(', ')}; distribuie-le după grupele zilei.';
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
                : 'Exercițiul salvat',
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
      return 'Nu există seturi finalizate în context pentru o comparație reală. '
          'Înregistrează greutatea și repetările la fiecare set. Păstrează '
          'aproximativ 2 repetări în rezervă. Când atingi limita intervalului '
          'la toate seturile, cu tehnică stabilă, poți încerca cel mai mic '
          'increment disponibil. Despre ce exercițiu vrei să vorbim?';
    }
    final named = available
        .where((log) => query.contains(_normalize(log.name)))
        .toList();
    final selected = named.isEmpty ? available.first : named.first;
    final comparable = available.where((log) => log.id == selected.id).toList();
    final latest = comparable.first;
    final observation =
        '${latest.name}: ultima ședință din ${latest.date.day}.${latest.date.month} '
        'are ${latest.sets.length} seturi finalizate; la greutatea maximă '
        '${_number(latest.weight)} kg ai ${latest.repsAtTopWeight} repetări în cel mai bun set.';
    if (comparable.length < 2) {
      return '$observation Am o singură ședință pentru acest exercițiu, deci nu '
          'pot stabili o tendință sau recomanda o greutate personală mai mare. '
          'Repetă încă o ședință cu aceleași condiții și urmărește repetările și tehnica.';
    }
    final before = comparable[1];
    if (latest.weight == before.weight &&
        latest.repsAtTopWeight > before.repsAtTopWeight) {
      return '$observation Față de ședința anterioară ai crescut de la '
          '${before.repsAtTopWeight} la ${latest.repsAtTopWeight} repetări la '
          '${_number(latest.weight)} kg. Păstrează greutatea până când toate '
          'seturile ating ținta de repetări cu 1–2 repetări în rezervă; apoi '
          'încearcă cel mai mic increment disponibil, orientativ 2–5% dacă '
          'echipamentul permite. Jurnalul nu confirmă tehnica sau efortul perceput.';
    }
    if (latest.weight > before.weight) {
      return '$observation Greutatea maximă a crescut de la '
          '${_number(before.weight)} la ${_number(latest.weight)} kg. '
          'Aceasta descrie încărcarea, nu dovedește singură un câștig de forță. '
          'Menține noua greutate și verifică tehnica, repetările și 1–2 repetări '
          'în rezervă înainte de următoarea creștere.';
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
      return '$observation În ultimele 3 ședințe, greutatea, cel mai bun set '
          'și numărul de seturi au rămas identice. Acest lucru nu dovedește '
          'un platou fiziologic. Încearcă mai întâi o repetare în plus într-un '
          'singur set, cu tehnică și efort comparabile. Dacă oboseala este mare, '
          'redu temporar volumul în loc să crești greutatea.';
    }
    return '$observation În ședința anterioară ai avut '
        '${_number(before.weight)} kg × ${before.repsAtTopWeight} în cel mai '
        'bun set. Condițiile diferă, deci nu presupun progres sau regres din '
        'două valori. Compară aceleași seturi și aceeași tehnică; adaugă '
        'repetări înainte de greutate. Cum s-au simțit ultimele seturi?';
  }
}

class _LoggedExercise {
  _LoggedExercise(this.date, this.id, this.name, this.sets);
  final DateTime date;
  final String id;
  final String name;
  final List<Map<String, dynamic>> sets;
  num get weight =>
      sets.map((set) => set['weight'] as num).reduce((a, b) => a > b ? a : b);
  int get repsAtTopWeight => sets
      .where((set) => set['weight'] == weight)
      .map((set) => (set['reps'] as num).toInt())
      .reduce((a, b) => a > b ? a : b);
}
