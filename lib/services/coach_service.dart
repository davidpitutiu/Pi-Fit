import 'dart:convert';

import 'package:http/http.dart' as http;

import 'firebase_gateway.dart';

/// Calls our authenticated backend; provider credentials never enter the app.
class CoachService {
  static const _endpoint = String.fromEnvironment('AI_COACH_URL');

  bool get remoteConfigured => _endpoint.isNotEmpty;

  Future<String> reply(String message, {required String context}) async {
    final question = message.trim();
    if (question.isEmpty) {
      throw ArgumentError('Scrie o întrebare pentru antrenor.');
    }
    if (!remoteConfigured) return localSuggestion(question);
    if (question.length > 3000) {
      throw ArgumentError('Întrebarea poate avea cel mult 3.000 de caractere.');
    }
    final endpoint = Uri.tryParse(_endpoint);
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
            'context': context.length > 12000
                ? context.substring(0, 12000)
                : context,
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
    if (body is! Map || body['reply'] is! String) {
      throw StateError('Răspunsul antrenorului AI nu este valid.');
    }
    return body['reply'] as String;
  }

  /// Deliberately labeled, curated advice, not a simulated AI conversation.
  static String localSuggestion(String message) {
    final query = message.toLowerCase();
    const label = 'Sugestie locală · AI-ul online nu este configurat\n\n';
    if (RegExp(r'durer|durere|accident|doare|ameț|amet').hasMatch(query)) {
      return '${label}Oprește exercițiul care provoacă durere. Nu încerca să '
          'treci peste o durere ascuțită sau neobișnuită. Dacă persistă, discută '
          'cu un medic sau fizioterapeut înainte de a relua antrenamentul. '
          'Pentru durere în piept, leșin sau dificultăți de respirație, cere '
          'ajutor medical imediat.';
    }
    if (RegExp(r'slăb|slab|calor|nutri|mânc|manc|diet').hasMatch(query)) {
      return '${label}Pentru controlul greutății, începe cu obiceiuri sustenabile: '
          'mese regulate, proteine la fiecare masă, legume și hidratare. '
          'Combină 2–3 antrenamente de forță pe săptămână cu mers zilnic. '
          'Urmărește tendința pe câteva săptămâni și evită dietele drastice. '
          'Pentru un plan alimentar personalizat, lucrează cu un dietetician.';
    }
    if (RegExp(r'încep|incep|prim|program|plan|full').hasMatch(query)) {
      return '${label}Un început simplu: 3 ședințe full body pe săptămână, '
          'cu o zi de pauză între ele. Alege câte o genuflexiune, o împingere, '
          'un ramat, o mișcare pentru șold și un exercițiu pentru abdomen. '
          'Începe cu 2–3 serii de 8–12 repetări, păstrând 2 repetări în rezervă. '
          'Încălzește-te 5–10 minute și adaugă serii ușoare înainte de greutăți.';
    }
    if (RegExp(r'odih|pauz|recup|somn|obosit').hasMatch(query)) {
      return '${label}Lasă aproximativ 48 de ore între ședințele intense pentru '
          'aceeași grupă musculară. Încearcă să dormi 7–9 ore și ajustează '
          'volumul când recuperarea scade. Între seriile grele, odihnește-te '
          '2–3 minute; la accesorii, 60–90 de secunde pot fi suficiente.';
    }
    return '${label}Pentru progres constant, notează greutatea și repetările '
        'fiecărei serii. Când atingi limita superioară a intervalului de '
        'repetări la toate seriile, cu tehnică bună și 1–2 repetări în rezervă, '
        'crește greutatea cu cel mai mic increment disponibil. Nu forța '
        'progresia dacă tehnica sau recuperarea se deteriorează. '
        'Poți întreba despre un program de început, recuperare sau alimentație.';
  }
}
