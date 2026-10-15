import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pi_fit/services/firebase_gateway.dart';
import 'package:pi_fit/state/app_store.dart';
import 'package:pi_fit/ui/account_coach.dart';
import 'package:pi_fit/ui/auth_scope_gate.dart';

class _User extends Fake implements User {
  _User(this.uid, [this.displayName]);
  @override
  final String uid;
  @override
  final String? displayName;
}

class _Gateway extends Fake implements FirebaseGateway {
  final changes = StreamController<User?>.broadcast(sync: true);
  final completion = Completer<String>();
  User? user;
  String? setupWarning;
  int requests = 0;

  @override
  bool get configured => true;
  @override
  User? get currentUser => user;
  @override
  Stream<User?> get authStateChanges => changes.stream;

  void emit(User? value) {
    user = value;
    changes.add(value);
  }

  @override
  Future<String> signUp(String email, String password, String name) {
    requests++;
    emit(_User('alice'));
    return completion.future;
  }

  @override
  Future<String> signIn(String email, String password) {
    requests++;
    emit(_User('alice'));
    return completion.future;
  }

  // This API also lets the UI report optional setup failure after its route
  // has been dismissed by the auth coordinator.
  @override
  String? registrationWarningFor(String uid) => setupWarning;
}

class _NavigationLog extends NavigatorObserver {
  final popped = <Route<dynamic>>[];
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popped.add(route);
  }
}

Future<AppStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  final store = AppStore(await SharedPreferences.getInstance());
  await store.updateProfile('Guest journal', store.goal);
  return store;
}

Widget _host(
  AppStore store,
  _Gateway gateway,
  GlobalKey<NavigatorState> navigatorKey,
  _NavigationLog observer,
) => MaterialApp(
  navigatorKey: navigatorKey,
  navigatorObservers: [observer],
  builder: (context, child) => AuthScopeGate(
    store: store,
    gateway: gateway,
    navigatorKey: navigatorKey,
    child: child!,
  ),
  home: AnimatedBuilder(
    animation: store,
    builder: (context, _) => Scaffold(
      body: Text('Home: ${store.accountId ?? 'guest'} / ${store.name}'),
    ),
  ),
);

Future<void> _fill(WidgetTester tester, {required bool register}) async {
  if (register) {
    await tester.enterText(find.byKey(const Key('auth-name')), 'Alice');
  }
  await tester.enterText(
    find.byKey(const Key('auth-email')),
    'alice@example.invalid',
  );
  await tester.enterText(
    find.byKey(const Key('auth-password')),
    'test-password',
  );
  if (register) {
    await tester.enterText(
      find.byKey(const Key('auth-confirmation')),
      'test-password',
    );
  }
  final submit = find.widgetWithText(
    FilledButton,
    register ? 'Create account' : 'Sign in',
  );
  await tester.ensureVisible(submit);
  await tester.tap(submit);
}

void main() {
  for (final register in [true, false]) {
    testWidgets(
      '${register ? 'signup' : 'login'} completing while auth route exits preserves the home route',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = await _store();
        final gateway = _Gateway();
        addTearDown(gateway.changes.close);
        final navigatorKey = GlobalKey<NavigatorState>();
        final observer = _NavigationLog();
        await tester.pumpWidget(_host(store, gateway, navigatorKey, observer));
        final authRoute = MaterialPageRoute<void>(
          builder: (_) => AuthScreen(
            store: store,
            gateway: gateway,
            initialRegister: register,
          ),
        );
        unawaited(navigatorKey.currentState!.push(authRoute));
        await tester.pumpAndSettle();
        await _fill(tester, register: register);
        await tester.pump();
        await tester.pump();

        expect(store.accountId, 'alice');
        expect(authRoute.isCurrent, isFalse);
        // Do not settle the exit animation: mounted alone used to permit a
        // second pop here, which removed the only remaining (home) route.
        expect(find.byType(AuthScreen, skipOffstage: false), findsOneWidget);
        gateway.completion.complete('alice');
        await tester.pump();
        await tester.pumpAndSettle();
        // Rebuilding a Navigator after its root was accidentally removed used
        // to raise the same `_history.isNotEmpty` assertion seen on reload.
        await tester.pumpWidget(_host(store, gateway, navigatorKey, observer));
        await tester.pumpAndSettle();

        expect(gateway.requests, 1);
        expect(navigatorKey.currentState!.canPop(), isFalse);
        expect(observer.popped, [authRoute]);
        expect(
          find.text('Home: alice / ${register ? 'Alice' : 'Athlete'}'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'optional signup setup warning reaches home after the auth screen is disposed',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await _store();
      final gateway = _Gateway()
        ..setupWarning =
            'Account created. Verification could not finish; resend from Profile.';
      addTearDown(gateway.changes.close);
      final navigatorKey = GlobalKey<NavigatorState>();
      final observer = _NavigationLog();
      await tester.pumpWidget(_host(store, gateway, navigatorKey, observer));
      unawaited(
        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => AuthScreen(
              store: store,
              gateway: gateway,
              initialRegister: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _fill(tester, register: true);
      await tester.pumpAndSettle();
      expect(find.byType(AuthScreen, skipOffstage: false), findsNothing);
      expect(find.text('Home: alice / Athlete'), findsOneWidget);

      gateway.completion.complete('alice');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Home: alice / Alice'), findsOneWidget);
      expect(find.text(gateway.setupWarning!), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(observer.popped, hasLength(1));
      expect(navigatorKey.currentState!.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late signup completion cannot rename another account or dismiss its route',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await _store();
      await store.preferences.setString(
        'pifit.account.bob.v1',
        jsonEncode({...store.exportData(), 'name': 'Bob journal'}),
      );
      final guestBefore = store.preferences.getString('pifit.local.v1');
      final gateway = _Gateway();
      addTearDown(gateway.changes.close);
      final navigatorKey = GlobalKey<NavigatorState>();
      final observer = _NavigationLog();
      await tester.pumpWidget(_host(store, gateway, navigatorKey, observer));
      unawaited(
        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => AuthScreen(
              store: store,
              gateway: gateway,
              initialRegister: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _fill(tester, register: true);
      await tester.pumpAndSettle();
      gateway.emit(_User('bob', 'Bob'));
      await tester.pumpAndSettle();
      final bobRoute = MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Bob account details')),
      );
      unawaited(navigatorKey.currentState!.push(bobRoute));
      await tester.pumpAndSettle();
      final popsBefore = observer.popped.length;

      gateway.completion.complete('alice');
      await tester.pumpAndSettle();

      expect(store.accountId, 'bob');
      expect(store.name, 'Bob journal');
      expect(store.preferences.getString('pifit.local.v1'), guestBefore);
      expect(bobRoute.isCurrent, isTrue);
      expect(find.text('Bob account details'), findsOneWidget);
      expect(find.textContaining('Account created.'), findsNothing);
      expect(observer.popped.length, popsBefore);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'restored auth and repeated initial events retain one usable home route',
    (tester) async {
      final store = await _store();
      await store.preferences.setString(
        'pifit.account.alice.v1',
        jsonEncode({...store.exportData(), 'name': 'Saved Alice'}),
      );
      final gateway = _Gateway()..user = _User('alice', 'Alice');
      addTearDown(gateway.changes.close);
      final navigatorKey = GlobalKey<NavigatorState>();
      final observer = _NavigationLog();
      await tester.pumpWidget(_host(store, gateway, navigatorKey, observer));
      expect(find.text('Opening your profile…'), findsOneWidget);
      gateway.emit(gateway.user);
      await tester.pumpAndSettle();
      gateway.emit(gateway.user);
      gateway.emit(gateway.user);
      await tester.pumpAndSettle();

      expect(store.accountId, 'alice');
      expect(find.text('Home: alice / Saved Alice'), findsOneWidget);
      expect(observer.popped, isEmpty);
      expect(navigatorKey.currentState!.canPop(), isFalse);

      unawaited(
        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Account details')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Home: alice / Saved Alice'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
