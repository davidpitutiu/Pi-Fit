import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pi_fit/services/firebase_gateway.dart';
import 'package:pi_fit/state/app_store.dart';
import 'package:pi_fit/ui/auth_scope_gate.dart';

class _FakeUser extends Fake implements User {
  _FakeUser(this.uid, this.displayName);
  @override
  final String uid;
  @override
  final String? displayName;
}

class _FakeGateway extends Fake implements FirebaseGateway {
  final _changes = StreamController<User?>.broadcast(sync: true);
  User? _user;
  int signOutCalls = 0;
  @override
  User? get currentUser => _user;
  @override
  Stream<User?> get authStateChanges => _changes.stream;
  void emit(User? user) {
    _user = user;
    _changes.add(user);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    emit(null);
  }

  Future<void> close() => _changes.close();
}

class _DelayedStore extends AppStore {
  _DelayedStore(super.preferences);
  final holds = <String, Completer<void>>{};
  String? heldName;
  Completer<void>? profileHold;
  @override
  Future<void> updateProfile(String newName, String newGoal) async {
    if (newName == heldName) await profileHold!.future;
    await super.updateProfile(newName, newGoal);
  }

  @override
  Future<void> switchAccount(String? uid) async {
    final hold = holds[uid];
    if (hold != null) await hold.future;
    await super.switchAccount(uid);
  }
}

Future<_DelayedStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  final store = _DelayedStore(await SharedPreferences.getInstance());
  await store.updateProfile('Guest private journal', store.goal);
  return store;
}

Future<void> _account(_DelayedStore store, String uid, String name) async {
  final data = {...store.exportData(), 'name': name};
  await store.preferences.setString('pifit.account.$uid.v1', jsonEncode(data));
}

Widget _host(
  _DelayedStore store,
  _FakeGateway gateway,
  GlobalKey<NavigatorState> navigatorKey,
) => MaterialApp(
  navigatorKey: navigatorKey,
  builder: (context, child) => AuthScopeGate(
    store: store,
    gateway: gateway,
    navigatorKey: navigatorKey,
    child: child!,
  ),
  home: AnimatedBuilder(
    animation: store,
    builder: (context, _) =>
        Scaffold(body: Center(child: Text('Private: ${store.name}'))),
  ),
);

void main() {
  testWidgets(
    'account loading removes the previous profile from paint and accessibility',
    (tester) async {
      final store = await _store();
      await _account(store, 'alice', 'Alice private journal');
      final gateway = _FakeGateway();
      addTearDown(gateway.close);
      final navigatorKey = GlobalKey<NavigatorState>();
      final hold = Completer<void>();
      store.holds['alice'] = hold;
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_host(store, gateway, navigatorKey));
        final navigatorBefore = navigatorKey.currentState;
        expect(find.text('Private: Guest private journal'), findsOneWidget);

        gateway.emit(_FakeUser('alice', 'Alice'));
        await tester.pump();
        expect(find.text('Opening your profile…'), findsOneWidget);
        expect(find.text('Private: Guest private journal'), findsNothing);
        expect(
          find.bySemanticsLabel('Private: Guest private journal'),
          findsNothing,
        );
        // Keeping the same Navigator offstage preserves its state while locked.
        expect(
          find.text('Private: Guest private journal', skipOffstage: false),
          findsOneWidget,
        );
        expect(navigatorKey.currentState, same(navigatorBefore));
        expect(store.accountId, isNull);

        hold.complete();
        await tester.pumpAndSettle();
        expect(store.accountId, 'alice');
        expect(find.text('Private: Alice private journal'), findsOneWidget);
        expect(find.text('Private: Guest private journal'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'malformed account remains hidden and signing out recovers unchanged guest data',
    (tester) async {
      final store = await _store();
      const corrupt = '{"broken":true}';
      await store.preferences.setString('pifit.account.broken.v1', corrupt);
      final guestBefore = jsonEncode(store.exportData());
      final storedGuestBefore = store.preferences.getString('pifit.local.v1');
      final gateway = _FakeGateway();
      addTearDown(gateway.close);
      await tester.pumpWidget(
        _host(store, gateway, GlobalKey<NavigatorState>()),
      );

      gateway.emit(_FakeUser('broken', 'Broken'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Your profile could not be opened.'),
        findsOneWidget,
      );
      expect(find.text('Private: Guest private journal'), findsNothing);
      expect(
        find.text('Private: Guest private journal', skipOffstage: false),
        findsOneWidget,
      );
      expect(store.accountId, isNull);
      expect(jsonEncode(store.exportData()), guestBefore);
      expect(store.preferences.getString('pifit.account.broken.v1'), corrupt);

      await tester.tap(find.text('Return to guest profile'));
      await tester.pumpAndSettle();
      expect(gateway.signOutCalls, 1);
      expect(gateway.currentUser, isNull);
      expect(find.text('Private: Guest private journal'), findsOneWidget);
      expect(
        find.textContaining('Your profile could not be opened.'),
        findsNothing,
      );
      expect(jsonEncode(store.exportData()), guestBefore);
      expect(store.preferences.getString('pifit.local.v1'), storedGuestBefore);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a fast second account event keeps the intermediate profile hidden',
    (tester) async {
      final store = await _store();
      await _account(store, 'alice', 'Alice private journal');
      await _account(store, 'bob', 'Bob private journal');
      final aliceHold = Completer<void>();
      final bobHold = Completer<void>();
      store.holds.addAll({'alice': aliceHold, 'bob': bobHold});
      final gateway = _FakeGateway();
      addTearDown(gateway.close);
      await tester.pumpWidget(
        _host(store, gateway, GlobalKey<NavigatorState>()),
      );
      gateway.emit(_FakeUser('alice', 'Alice'));
      await tester.pump();
      gateway.emit(_FakeUser('bob', 'Bob'));
      await tester.pump();

      aliceHold.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Private: Guest private journal'), findsNothing);
      expect(find.text('Private: Alice private journal'), findsNothing);
      expect(find.text('Opening your profile…'), findsOneWidget);
      bobHold.complete();
      await tester.pumpAndSettle();
      expect(store.accountId, 'bob');
      expect(find.text('Private: Bob private journal'), findsOneWidget);
      expect(find.text('Private: Alice private journal'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an older display-name continuation cannot reset routes for a newer event',
    (tester) async {
      final store = await _store();
      store.heldName = 'Alice';
      store.profileHold = Completer<void>();
      final bobHold = Completer<void>();
      store.holds['bob'] = bobHold;
      final gateway = _FakeGateway();
      addTearDown(gateway.close);
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_host(store, gateway, navigatorKey));
      final pendingRoute = MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Pending account screen')),
      );
      unawaited(navigatorKey.currentState!.push(pendingRoute));
      await tester.pumpAndSettle();

      gateway.emit(_FakeUser('alice', 'Alice'));
      await tester.pump();
      await tester.pump();
      expect(store.accountId, 'alice');
      gateway.emit(_FakeUser('bob', 'Bob'));
      await tester.pump();
      store.profileHold!.complete();
      await tester.pump();
      await tester.pump();
      expect(pendingRoute.isCurrent, isTrue);
      expect(find.text('Opening your profile…'), findsOneWidget);

      bobHold.complete();
      await tester.pumpAndSettle();
      expect(store.accountId, 'bob');
      expect(pendingRoute.isCurrent, isFalse);
      expect(find.text('Private: Bob'), findsOneWidget);
      expect(navigatorKey.currentState!.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disposing a gate with a pending profile load does not update disposed state',
    (tester) async {
      final store = await _store();
      final hold = Completer<void>();
      store.holds['alice'] = hold;
      final gateway = _FakeGateway();
      addTearDown(gateway.close);
      await tester.pumpWidget(
        _host(store, gateway, GlobalKey<NavigatorState>()),
      );
      gateway.emit(_FakeUser('alice', 'Alice'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      hold.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
