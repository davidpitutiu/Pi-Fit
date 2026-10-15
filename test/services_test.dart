import 'package:flutter_test/flutter_test.dart';
import 'package:pi_fit/services/coach_service.dart';
import 'package:pi_fit/services/firebase_gateway.dart';

void main() {
  test(
    'local coach clearly identifies advice without a configured AI',
    () async {
      final coach = CoachService();
      expect(coach.remoteConfigured, isFalse);
      final reply = await coach.reply(
        'Vreau un program pentru începători.',
        context: 'Niciun antrenament înregistrat.',
      );
      expect(
        reply.startsWith(
          'Sugestie locală · AI-ul online nu este configurat\n\n',
        ),
        isTrue,
      );
      expect(reply, contains('3 ședințe full body'));
      expect(reply, contains('repetări în rezervă'));
    },
  );

  test(
    'local pain advice recommends stopping rather than progression',
    () async {
      final reply = await CoachService().reply(
        'Mă doare genunchiul la genuflexiuni.',
        context: '',
      );
      expect(reply, contains('Sugestie locală'));
      expect(reply, contains('Oprește exercițiul'));
      expect(reply, contains('medic sau fizioterapeut'));
    },
  );

  test('unconfigured Firebase never creates a fake account', () async {
    final gateway = FirebaseGateway.instance;
    await gateway.initialize();
    expect(gateway.configured, isFalse);
    expect(gateway.currentUser, isNull);
    await expectLater(
      gateway.authStateChanges,
      emitsInOrder([null, emitsDone]),
    );
    await expectLater(
      gateway.signIn('demo@example.com', 'test-password'),
      throwsStateError,
    );
  });
}
