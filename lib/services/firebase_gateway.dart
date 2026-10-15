import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Firebase is optional for local workouts. An absent configuration never
/// creates a pretend user or marks local data as synchronized.
class FirebaseGateway {
  FirebaseGateway._({
    Future<FirebaseApp> Function(FirebaseOptions)? initializer,
    FirebaseAuth? authOverride,
    Duration initializationTimeout = const Duration(seconds: 10),
  }) : _initializer = initializer ?? _initializeSdk,
       _authOverride = authOverride,
       _initializationTimeout = initializationTimeout;

  @visibleForTesting
  factory FirebaseGateway.forTesting({
    required Future<FirebaseApp> Function(FirebaseOptions) initializer,
    FirebaseAuth? auth,
    Duration initializationTimeout = const Duration(seconds: 10),
  }) => FirebaseGateway._(
    initializer: initializer,
    authOverride: auth,
    initializationTimeout: initializationTimeout,
  );

  static final FirebaseGateway instance = FirebaseGateway._();
  final Future<FirebaseApp> Function(FirebaseOptions) _initializer;
  final FirebaseAuth? _authOverride;
  final Duration _initializationTimeout;
  FirebaseApp? _app;
  String? _configurationIssue;

  bool get configured => _app != null;
  String? get configurationIssue => _configurationIssue;
  FirebaseAuth get _auth {
    final app = _requireApp();
    return _authOverride ?? FirebaseAuth.instanceFor(app: app);
  }

  FirebaseFirestore get _database =>
      FirebaseFirestore.instanceFor(app: _requireApp());
  User? get currentUser => configured ? _auth.currentUser : null;
  Stream<User?> get authStateChanges =>
      configured ? _auth.authStateChanges() : Stream<User?>.value(null);

  static Future<FirebaseApp> _initializeSdk(FirebaseOptions options) =>
      Firebase.initializeApp(options: options);

  /// Complete explicit Dart defines replace the bundled project configuration.
  /// Partial overrides fail rather than silently mixing two Firebase projects.
  @visibleForTesting
  static FirebaseOptions? resolveOptions({
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
    Map<String, String>? overrides,
  }) {
    final target = platform ?? defaultTargetPlatform;
    final defaults = DefaultFirebaseOptions.forPlatform(target, isWeb: isWeb);
    if (defaults == null) return null;
    const environment = {
      'FIREBASE_API_KEY': String.fromEnvironment('FIREBASE_API_KEY'),
      'FIREBASE_ANDROID_API_KEY': String.fromEnvironment(
        'FIREBASE_ANDROID_API_KEY',
      ),
      'FIREBASE_IOS_API_KEY': String.fromEnvironment('FIREBASE_IOS_API_KEY'),
      'FIREBASE_WEB_API_KEY': String.fromEnvironment('FIREBASE_WEB_API_KEY'),
      'FIREBASE_PROJECT_ID': String.fromEnvironment('FIREBASE_PROJECT_ID'),
      'FIREBASE_MESSAGING_SENDER_ID': String.fromEnvironment(
        'FIREBASE_MESSAGING_SENDER_ID',
      ),
      'FIREBASE_APP_ID': String.fromEnvironment('FIREBASE_APP_ID'),
      'FIREBASE_ANDROID_APP_ID': String.fromEnvironment(
        'FIREBASE_ANDROID_APP_ID',
      ),
      'FIREBASE_IOS_APP_ID': String.fromEnvironment('FIREBASE_IOS_APP_ID'),
      'FIREBASE_WEB_APP_ID': String.fromEnvironment('FIREBASE_WEB_APP_ID'),
      'FIREBASE_STORAGE_BUCKET': String.fromEnvironment(
        'FIREBASE_STORAGE_BUCKET',
      ),
      'FIREBASE_IOS_BUNDLE_ID': String.fromEnvironment(
        'FIREBASE_IOS_BUNDLE_ID',
      ),
      'FIREBASE_AUTH_DOMAIN': String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    };
    final values = overrides ?? environment;
    if (!values.values.any((value) => value.isNotEmpty)) return defaults;
    String read(String key) => values[key]?.trim() ?? '';
    final platformName = isWeb
        ? 'web'
        : target == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    final platformPrefix = 'FIREBASE_${platformName.toUpperCase()}';
    final platformKey = read('${platformPrefix}_API_KEY');
    final apiKey = platformKey.isNotEmpty
        ? platformKey
        : read('FIREBASE_API_KEY');
    final platformApp = read('${platformPrefix}_APP_ID');
    final appId = platformApp.isNotEmpty
        ? platformApp
        : read('FIREBASE_APP_ID');
    final projectId = read('FIREBASE_PROJECT_ID');
    final senderId = read('FIREBASE_MESSAGING_SENDER_ID');
    if ([
      apiKey,
      appId,
      projectId,
      senderId,
    ].any((value) => value.isEmpty || value.startsWith('replace-with'))) {
      throw StateError(
        'Configurarea Firebase explicită este incompletă pentru $platformName. '
        'Furnizează cheia publică, ID-ul aplicației, proiectul și expeditorul '
        'sau pornește fără aceste override-uri pentru configurația inclusă.',
      );
    }
    if (!RegExp(r'^\d+$').hasMatch(senderId) ||
        !RegExp(
          '^1:${RegExp.escape(senderId)}:$platformName:[A-Za-z0-9]+\$',
        ).hasMatch(appId)) {
      throw StateError(
        'ID-ul aplicației Firebase nu corespunde platformei $platformName '
        'sau expeditorului configurat.',
      );
    }
    final bundleId = read('FIREBASE_IOS_BUNDLE_ID');
    if (platformName == 'ios' &&
        bundleId.isNotEmpty &&
        bundleId != 'com.pifit.app') {
      throw StateError('Bundle ID Firebase iOS trebuie să fie com.pifit.app.');
    }
    final authDomain = read('FIREBASE_AUTH_DOMAIN');
    final storageBucket = read('FIREBASE_STORAGE_BUCKET');
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      authDomain: authDomain.isNotEmpty
          ? authDomain
          : '$projectId.firebaseapp.com',
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      iosBundleId: platformName == 'ios' ? 'com.pifit.app' : null,
    );
  }

  Future<void> initialize() async {
    if (configured) return;
    try {
      final options = resolveOptions();
      if (options == null) {
        _configurationIssue =
            'Contul Firebase este disponibil pe Android, iOS și Web. '
            'Pe această platformă poți folosi profilul local.';
        return;
      }
      // Assign only after the timeout-wrapped operation succeeds. A late SDK
      // completion cannot silently enable Auth after the gate chose local mode.
      final app = await _initializer(options).timeout(_initializationTimeout);
      _app = app;
      _configurationIssue = null;
    } on TimeoutException {
      _configurationIssue =
          'Conexiunea Firebase durează prea mult. Configurația este inclusă; '
          'verifică accesul la internet și repornește aplicația. '
          'Profilul și antrenamentele locale rămân disponibile.';
      rethrow;
    } on StateError catch (error) {
      _configurationIssue = error.message.toString();
      rethrow;
    } catch (_) {
      _configurationIssue =
          'Firebase nu a putut porni. Configurația este inclusă; verifică '
          'conexiunea și repornește aplicația. Modul local este disponibil.';
      rethrow;
    }
  }

  Future<String> signIn(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = result.user;
    if (user == null) throw StateError('Autentificarea nu a returnat un cont.');
    return user.uid;
  }

  Future<String> signUp(String email, String password, String name) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = result.user;
    if (user == null) throw StateError('Înregistrarea nu a returnat un cont.');
    final createdUid = user.uid;
    try {
      _requireSameUser(createdUid);
      if (name.trim().isNotEmpty) {
        await user.updateDisplayName(name.trim());
      }
      _requireSameUser(createdUid);
      await user.sendEmailVerification();
    } catch (_) {
      if (currentUser?.uid != createdUid) {
        throw StateError(
          'Contul a fost creat, dar contul activ s-a schimbat înainte să se '
          'încheie configurarea. Conectează-te la contul creat pentru a continua.',
        );
      }
      throw StateError(
        'Contul a fost creat și ești autentificat, dar configurarea profilului '
        'sau trimiterea emailului de verificare nu s-a încheiat. '
        'Poți retrimite verificarea din Cont.',
      );
    }
    return createdUid;
  }

  Future<void> signOut() async {
    if (configured) await _auth.signOut();
  }

  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> resendVerification() async {
    final user = _requireUser();
    await user.reload();
    _requireSameUser(user.uid);
    final refreshed = _requireUser();
    if (refreshed.emailVerified) {
      throw StateError('Adresa de email este deja verificată.');
    }
    await refreshed.sendEmailVerification();
  }

  /// Reauthentication happens before any data is removed. A Firestore failure
  /// leaves the account intact, so cleanup can be retried while still signed in.
  Future<void> deleteAccount(String currentPassword) async {
    final user = _requireUser();
    final email = user.email;
    if (email == null || currentPassword.isEmpty) {
      throw ArgumentError('Introdu parola curentă pentru a șterge contul.');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: currentPassword),
    );
    _requireSameUser(user.uid);
    final batch = _database.batch();
    batch.delete(_database.doc('users/${user.uid}/backups/current'));
    batch.delete(_database.doc('users/${user.uid}'));
    await batch.commit();
    if (currentUser?.uid != user.uid) {
      throw StateError(
        'Backupul contului inițial a fost șters, dar contul activ s-a schimbat. '
        'Conectează-te din nou la contul inițial pentru a încheia ștergerea.',
      );
    }
    try {
      await user.delete();
    } catch (_) {
      throw StateError(
        'Backupul cloud și profilul cloud au fost șterse, dar contul este încă '
        'activ. Reîncearcă ștergerea pentru a elimina și contul. '
        'Datele locale sunt păstrate.',
      );
    }
  }

  Future<void> saveBackup(Map<String, dynamic> data) async {
    final user = _requireUser();
    await _database.doc('users/${user.uid}/backups/current').set({
      'schemaVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
      'data': data,
    });
  }

  Future<Map<String, dynamic>?> loadBackup() async {
    final user = _requireUser();
    // A restore must get the server version, never claim a stale cache is cloud.
    final snapshot = await _database
        .doc('users/${user.uid}/backups/current')
        .get(const GetOptions(source: Source.server));
    final payload = snapshot.data()?['data'];
    return payload is Map ? Map<String, dynamic>.from(payload) : null;
  }

  FirebaseApp _requireApp() {
    if (_app == null) {
      throw StateError(
        _configurationIssue ??
            'Firebase nu este configurat. Datele rămân pe acest dispozitiv.',
      );
    }
    return _app!;
  }

  User _requireUser() {
    _requireApp();
    final user = currentUser;
    if (user == null) {
      throw StateError('Autentifică-te pentru sincronizarea în cloud.');
    }
    return user;
  }

  void _requireSameUser(String uid) {
    if (currentUser?.uid != uid) {
      throw StateError(
        'Contul activ s-a schimbat. Reia acțiunea în contul dorit.',
      );
    }
  }
}
