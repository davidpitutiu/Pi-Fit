import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_fit/firebase_options.dart';
import 'package:pi_fit/services/firebase_gateway.dart';

class _FakeFirebaseApp extends Fake implements FirebaseApp {}

class _FakeCredential extends Fake implements UserCredential {
  _FakeCredential(this.user);
  @override
  final User user;
}

class _FakeAuthUser extends Fake implements User {
  _FakeAuthUser(this.uid);
  @override
  final String uid;
  @override
  String? displayName;
  final nameStarted = Completer<void>();
  final verificationStarted = Completer<void>();
  Completer<void>? nameHold;
  Completer<void>? verificationHold;
  int verificationCalls = 0;

  @override
  Future<void> updateDisplayName(String? name) async {
    displayName = name;
    nameStarted.complete();
    if (nameHold != null) await nameHold!.future;
  }

  @override
  Future<void> sendEmailVerification([ActionCodeSettings? settings]) async {
    verificationCalls++;
    verificationStarted.complete();
    if (verificationHold != null) await verificationHold!.future;
  }
}

class _FakeAuth extends Fake implements FirebaseAuth {
  User? activeUser;
  late UserCredential credential;
  int signOutCalls = 0;
  @override
  User? get currentUser => activeUser;
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async => credential;
  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    activeUser = credential.user;
    return credential;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    activeUser = null;
  }
}

void main() {
  test(
    'bundled options match supplied Android and iOS public client files',
    () {
      final android =
          jsonDecode(
                File('android/app/google-services.json').readAsStringSync(),
              )
              as Map;
      final client = (android['client'] as List).single as Map;
      final info = client['client_info'] as Map;
      final project = android['project_info'] as Map;
      final options = DefaultFirebaseOptions.android;
      expect(options.projectId, project['project_id']);
      expect(options.messagingSenderId, '${project['project_number']}');
      expect(options.appId, info['mobilesdk_app_id']);
      expect(
        (info['android_client_info'] as Map)['package_name'],
        'com.pifit.app',
      );
      expect(
        options.apiKey ==
            ((client['api_key'] as List).first as Map)['current_key'],
        isTrue,
      );
      final iosFile = File(
        'ios/Runner/GoogleService-Info.plist',
      ).readAsStringSync();
      expect(iosFile.contains(DefaultFirebaseOptions.ios.appId), isTrue);
      expect(DefaultFirebaseOptions.ios.iosBundleId, 'com.pifit.app');
      expect(DefaultFirebaseOptions.ios.projectId, options.projectId);
    },
  );

  test('normal startup selects bundled options without Dart defines', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      final options = FirebaseGateway.resolveOptions(
        platform: platform,
        overrides: {},
      );
      expect(options, isNotNull);
      expect(options!.projectId, 'pi-fit-663f2');
      expect(
        options.appId,
        contains(platform == TargetPlatform.android ? ':android:' : ':ios:'),
      );
    }
    final web = FirebaseGateway.resolveOptions(
      platform: TargetPlatform.windows,
      isWeb: true,
      overrides: {},
    );
    expect(web!.appId, '1:942783822335:web:52e8ccf86e545c2ed28fca');
    expect(web.authDomain, 'pi-fit-663f2.firebaseapp.com');
    expect(web.apiKey.isNotEmpty, isTrue);
    expect(
      FirebaseGateway.resolveOptions(
        platform: TargetPlatform.linux,
        overrides: {},
      ),
      isNull,
    );
  });

  test(
    'partial explicit configuration is rejected instead of mixing projects',
    () {
      expect(
        () => FirebaseGateway.resolveOptions(
          platform: TargetPlatform.android,
          overrides: {'FIREBASE_PROJECT_ID': 'other-project'},
        ),
        throwsStateError,
      );
      expect(
        () => FirebaseGateway.resolveOptions(
          platform: TargetPlatform.android,
          overrides: {
            'FIREBASE_PROJECT_ID': 'other-project',
            'FIREBASE_API_KEY': 'replace-with-public-key',
            'FIREBASE_APP_ID': '1:123456:android:custom123',
            'FIREBASE_MESSAGING_SENDER_ID': '123456',
          },
        ),
        throwsStateError,
      );
    },
  );

  test(
    'complete overrides use the chosen platform and never reuse a native app ID for web',
    () {
      final explicit = {
        'FIREBASE_PROJECT_ID': 'custom-project',
        'FIREBASE_MESSAGING_SENDER_ID': '123456',
        'FIREBASE_API_KEY': 'common-public-key',
        'FIREBASE_WEB_API_KEY': 'web-public-key',
        'FIREBASE_WEB_APP_ID': '1:123456:web:custom123',
      };
      final options = FirebaseGateway.resolveOptions(
        isWeb: true,
        overrides: explicit,
      )!;
      expect(options.projectId, 'custom-project');
      expect(options.apiKey, 'web-public-key');
      expect(options.authDomain, 'custom-project.firebaseapp.com');
      expect(options.storageBucket, isNull);
      expect(options.iosBundleId, isNull);
      expect(
        () => FirebaseGateway.resolveOptions(
          isWeb: true,
          overrides: {
            ...explicit,
            'FIREBASE_WEB_APP_ID': '1:123456:android:custom123',
          },
        ),
        throwsStateError,
      );
      expect(
        () => FirebaseGateway.resolveOptions(
          isWeb: true,
          overrides: {...explicit, 'FIREBASE_MESSAGING_SENDER_ID': '999999'},
        ),
        throwsStateError,
      );
    },
  );

  group('account identity remains tied to the credential result', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test(
      'sign in returns the credential UID instead of a newer active account',
      () async {
        final auth = _FakeAuth()
          ..credential = _FakeCredential(_FakeAuthUser('alice'))
          ..activeUser = _FakeAuthUser('bob');
        final gateway = FirebaseGateway.forTesting(
          initializer: (_) async => _FakeFirebaseApp(),
          auth: auth,
        );
        await gateway.initialize();
        expect(
          await gateway.signIn('alice@example.invalid', 'test-password'),
          'alice',
        );
        expect(gateway.currentUser!.uid, 'bob');
        await gateway.signOut();
        expect(auth.signOutCalls, 1);
        expect(gateway.currentUser, isNull);
      },
    );

    test(
      'sign up returns its created UID if account changes while verification completes',
      () async {
        final alice = _FakeAuthUser('alice')
          ..verificationHold = Completer<void>();
        final auth = _FakeAuth()..credential = _FakeCredential(alice);
        final gateway = FirebaseGateway.forTesting(
          initializer: (_) async => _FakeFirebaseApp(),
          auth: auth,
        );
        await gateway.initialize();
        final signup = gateway.signUp(
          'alice@example.invalid',
          'test-password',
          'Alice',
        );
        await alice.verificationStarted.future;
        auth.activeUser = _FakeAuthUser('bob');
        alice.verificationHold!.complete();
        expect(await signup, 'alice');
        expect(gateway.currentUser!.uid, 'bob');
      },
    );

    test(
      'a changed account during display-name setup stops subsequent verification',
      () async {
        final alice = _FakeAuthUser('alice')..nameHold = Completer<void>();
        final bob = _FakeAuthUser('bob');
        final auth = _FakeAuth()..credential = _FakeCredential(alice);
        final gateway = FirebaseGateway.forTesting(
          initializer: (_) async => _FakeFirebaseApp(),
          auth: auth,
        );
        await gateway.initialize();
        final signup = gateway.signUp(
          'alice@example.invalid',
          'test-password',
          'Alice',
        );
        final checked = expectLater(
          signup,
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('the active account changed'),
            ),
          ),
        );
        await alice.nameStarted.future;
        auth.activeUser = bob;
        alice.nameHold!.complete();
        await checked;
        expect(alice.verificationCalls, 0);
        expect(bob.verificationCalls, 0);
        expect(bob.displayName, isNull);
      },
    );
  });

  group('bounded SDK initialization', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test(
      'initializes once from bundled options without a remote SDK in tests',
      () async {
        var calls = 0;
        final gateway = FirebaseGateway.forTesting(
          initializer: (options) async {
            calls++;
            expect(options.appId, DefaultFirebaseOptions.android.appId);
            return _FakeFirebaseApp();
          },
        );
        await gateway.initialize();
        await gateway.initialize();
        expect(gateway.configured, isTrue);
        expect(gateway.configurationIssue, isNull);
        expect(calls, 1);
      },
    );

    test(
      'a timeout keeps local mode even when the SDK completes late',
      () async {
        final pending = Completer<FirebaseApp>();
        final gateway = FirebaseGateway.forTesting(
          initializer: (_) => pending.future,
          initializationTimeout: const Duration(milliseconds: 10),
        );
        await expectLater(
          gateway.initialize(),
          throwsA(isA<TimeoutException>()),
        );
        expect(gateway.configured, isFalse);
        expect(
          gateway.configurationIssue,
          contains('Configuration is bundled'),
        );
        pending.complete(_FakeFirebaseApp());
        await Future<void>.delayed(Duration.zero);
        expect(gateway.configured, isFalse);
      },
    );
  });
}
