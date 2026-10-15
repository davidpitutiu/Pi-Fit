import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pi_fit/domain/user_profile.dart';
import 'package:pi_fit/state/app_store.dart';
import 'package:pi_fit/services/firebase_gateway.dart';
import 'package:pi_fit/ui/account_coach.dart';
import 'package:pi_fit/ui/health_screen.dart';
import 'package:pi_fit/ui/theme.dart';

Future<AppStore> newStore() async {
  SharedPreferences.setMockInitialValues({});
  return AppStore(await SharedPreferences.getInstance());
}

Future<void> pumpPhone(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(theme: piTheme(Brightness.dark), home: child),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login remains visible without Firebase and validates inputs', (
    tester,
  ) async {
    final store = await newStore();
    await pumpPhone(tester, AuthScreen(store: store));
    expect(find.byKey(const Key('auth-email')), findsOneWidget);
    expect(find.byKey(const Key('auth-password')), findsOneWidget);
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Conectează-te'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Conectează-te'));
    await tester.pumpAndSettle();
    expect(find.text('Introdu o adresă de email validă.'), findsOneWidget);
    expect(find.text('Introdu parola.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signup asks for a name and matching strong passwords', (
    tester,
  ) async {
    final store = await newStore();
    await pumpPhone(tester, AuthScreen(store: store, initialRegister: true));
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'david@example.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), '123');
    await tester.enterText(
      find.byKey(const Key('auth-confirmation')),
      'different',
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Creează cont'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Creează cont'));
    await tester.pumpAndSettle();
    expect(find.text('Introdu numele tău.'), findsOneWidget);
    expect(
      find.text('Parola trebuie să aibă cel puțin 8 caractere.'),
      findsOneWidget,
    );
    expect(find.text('Parolele trebuie să coincidă.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'valid login shows actionable configuration error in local mode',
    (tester) async {
      final store = await newStore();
      await pumpPhone(tester, AuthScreen(store: store));
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'david@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        '12345678',
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Conectează-te'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Conectează-te'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth-error')), findsOneWidget);
      expect(find.textContaining('Configurația este inclusă'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile tab has direct login and signup entries on a narrow phone',
    (tester) async {
      final store = await newStore();
      await pumpPhone(tester, AccountScreen(store: store, embedded: true));
      expect(find.text('Conectează-te'), findsOneWidget);
      expect(find.text('Creează un cont'), findsOneWidget);
      await tester.ensureVisible(find.text('Creează un cont'));
      await tester.tap(find.text('Creează un cont'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth-confirmation')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile opens health from its visible card on a narrow phone', (
    tester,
  ) async {
    final store = await newStore();
    await pumpPhone(tester, AccountScreen(store: store, embedded: true));
    final healthEntry = find.text('Activitate și sănătate');
    expect(healthEntry.hitTestable(), findsOneWidget);
    expect(find.text('Citire locală · doar cu permisiunea ta'), findsOneWidget);
    await tester.tap(healthEntry);
    await tester.pumpAndSettle();
    expect(find.byType(HealthScreen), findsOneWidget);
    expect(store.accountId, isNull);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.linux}));

  testWidgets(
    'profile editor saves name and optional details atomically and persists',
    (tester) async {
      final store = await newStore();
      await pumpPhone(tester, AccountScreen(store: store));
      await tester.ensureVisible(find.text('Editează'));
      await tester.tap(find.text('Editează'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('profile-name')), 'David');
      await tester.ensureVisible(find.byKey(const Key('profile-weight')));
      await tester.enterText(find.byKey(const Key('profile-weight')), '82,5');
      await tester.ensureVisible(find.byKey(const Key('profile-height')));
      await tester.enterText(find.byKey(const Key('profile-height')), '181');
      await tester.tap(find.byKey(const Key('save-training-profile')));
      await tester.pumpAndSettle();
      expect(store.name, 'David');
      expect(store.profile.weightKg, 82.5);
      expect(store.profile.heightCm, 181);
      final reloaded = AppStore(store.preferences);
      await reloaded.load();
      expect(reloaded.name, 'David');
      expect(reloaded.profile.weightKg, 82.5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile editor rejects invalid measurements without saving', (
    tester,
  ) async {
    final store = await newStore();
    await pumpPhone(tester, AccountScreen(store: store));
    await tester.ensureVisible(find.text('Editează'));
    await tester.tap(find.text('Editează'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-name')), 'Changed');
    await tester.ensureVisible(find.byKey(const Key('profile-age')));
    await tester.enterText(find.byKey(const Key('profile-age')), '9');
    await tester.tap(find.byKey(const Key('save-training-profile')));
    await tester.pumpAndSettle();
    expect(
      find.text('Introdu un număr întreg între 13 și 100.'),
      findsOneWidget,
    );
    expect(store.name, 'Atlet');
    expect(store.profile.age, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'coach exposes real profile details and accepts a local conversation',
    (tester) async {
      final store = await newStore();
      await store.updateUserProfile(
        UserProfile(
          sessionsPerWeek: 5,
          sessionMinutes: 30,
          equipment: ['Gantere'],
        ),
      );
      await pumpPhone(tester, CoachScreen(store: store));
      expect(find.text('Coach local · adaptat profilului'), findsOneWidget);
      expect(find.text('5 zile / săpt.'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('coach-message')),
        'Fă-mi un program pentru profilul meu.',
      );
      await tester.tap(find.byTooltip('Trimite'));
      await tester.pumpAndSettle();
      final reply = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((w) => w.data ?? '')
          .firstWhere((text) => text.contains('Sugestie locală'));
      expect(reply, contains('5 ședințe/săptămână'));
      expect(reply, contains('30 min/ședință'));
      expect(reply, contains('Gantere'));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('coach-message')))
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile view follows isolated account data and restores the guest',
    (tester) async {
      final store = await newStore();
      await store.updateProfile('Vizitator', store.goal);
      await pumpPhone(tester, AccountScreen(store: store, embedded: true));
      expect(find.text('Vizitator'), findsOneWidget);
      await store.switchAccount('user-one');
      await store.updateProfile('David', store.goal);
      await tester.pumpAndSettle();
      expect(find.text('David'), findsOneWidget);
      expect(find.text('Vizitator'), findsNothing);
      await store.switchAccount(null);
      await tester.pumpAndSettle();
      expect(find.text('Vizitator'), findsOneWidget);
      expect(find.text('David'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'coach discards the previous account conversation on an account change',
    (tester) async {
      final store = await newStore();
      await pumpPhone(tester, CoachScreen(store: store));
      await tester.enterText(
        find.byKey(const Key('coach-message')),
        'Vreau un program doar pentru mine.',
      );
      await tester.tap(find.byTooltip('Trimite'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsWidgets);
      await store.switchAccount('another-user');
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsNothing);
      expect(find.text('Un plan care\nține cont de tine.'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('coach-message')))
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'local coach acknowledges limitations while online consent stays off',
    (tester) async {
      final store = await newStore();
      await store.updateUserProfile(
        UserProfile(limitations: 'Prefer exercițiile fără sărituri.'),
      );
      await pumpPhone(tester, CoachScreen(store: store));
      expect(find.text('Coach local · adaptat profilului'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('coach-message')),
        'Fă-mi un program săptămânal adaptat profilului.',
      );
      await tester.tap(find.byTooltip('Trimite'));
      await tester.pumpAndSettle();
      final reply = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((w) => w.data ?? '')
          .firstWhere((text) => text.contains('Sugestie locală'));
      expect(reply, contains('Prefer exercițiile fără sărituri.'));
      expect(store.profile.coachConsent, isFalse);
      await tester.pumpWidget(
        MaterialApp(
          theme: piTheme(Brightness.dark),
          home: AccountScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a delayed cloud restore cannot write into a different account or show an old toast',
    (tester) async {
      final store = await newStore();
      await store.switchAccount('account-a');
      await store.updateProfile('Account A', store.goal);
      final backupA = {...store.exportData(), 'name': 'Restored account A'};
      final gateway = _DelayedGateway('account-a');
      addTearDown(gateway.dispose);
      await pumpPhone(tester, AccountScreen(store: store, gateway: gateway));
      await tester.ensureVisible(find.text('Restaurează din cloud'));
      await tester.tap(find.text('Restaurează din cloud'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Restaurează'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(gateway.loadCalls, 1);
      gateway.setUser('account-b');
      await store.switchAccount('account-b');
      await store.updateProfile('Account B', store.goal);
      gateway.backup.complete(backupA);
      await tester.pumpAndSettle();
      expect(store.accountId, 'account-b');
      expect(store.name, 'Account B');
      expect(find.text('Restored account A'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cloud backup refuses to export data when auth and storage scopes differ',
    (tester) async {
      final store = await newStore();
      await store.switchAccount('account-b');
      final gateway = _DelayedGateway('account-a');
      addTearDown(gateway.dispose);
      await pumpPhone(tester, AccountScreen(store: store, gateway: gateway));
      await tester.ensureVisible(find.text('Salvează backup în cloud'));
      await tester.tap(find.text('Salvează backup în cloud'));
      await tester.pumpAndSettle();
      expect(gateway.saveCalls, 0);
      expect(
        find.textContaining('Contul nu este încă pregătit'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _FakeUser implements User {
  _FakeUser(this.uid);
  @override
  final String uid;
  @override
  String get email => '$uid@example.invalid';
  @override
  bool get emailVerified => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedGateway implements FirebaseGateway {
  _DelayedGateway(String uid) : _user = _FakeUser(uid);
  User? _user;
  final _changes = StreamController<User?>.broadcast();
  final backup = Completer<Map<String, dynamic>?>();
  int loadCalls = 0, saveCalls = 0;
  void setUser(String uid) {
    _user = _FakeUser(uid);
    _changes.add(_user);
  }

  Future<void> dispose() => _changes.close();
  @override
  bool get configured => true;
  @override
  User? get currentUser => _user;
  @override
  Stream<User?> get authStateChanges => _changes.stream;
  @override
  Future<Map<String, dynamic>?> loadBackup() {
    loadCalls++;
    return backup.future;
  }

  @override
  Future<void> saveBackup(Map<String, dynamic> data) async {
    saveCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
