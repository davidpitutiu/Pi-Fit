import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase is optional for local workouts. An absent configuration never
/// creates a pretend user or marks local data as synchronized.
class FirebaseGateway {
  FirebaseGateway._();

  static final FirebaseGateway instance = FirebaseGateway._();
  FirebaseApp? _app;

  bool get configured => _app != null;
  FirebaseAuth get _auth => FirebaseAuth.instanceFor(app: _requireApp());
  FirebaseFirestore get _database =>
      FirebaseFirestore.instanceFor(app: _requireApp());
  User? get currentUser => configured ? _auth.currentUser : null;
  Stream<User?> get authStateChanges =>
      configured ? _auth.authStateChanges() : Stream<User?>.value(null);

  Future<void> initialize() async {
    if (configured) return;
    const commonApiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const androidApiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
    const iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
    const webApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
    final platformApiKey = kIsWeb
        ? webApiKey
        : defaultTargetPlatform == TargetPlatform.iOS
        ? iosApiKey
        : androidApiKey;
    final apiKey = platformApiKey.isNotEmpty ? platformApiKey : commonApiKey;
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const commonAppId = String.fromEnvironment('FIREBASE_APP_ID');
    const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
    const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
    const webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
    final platformAppId = kIsWeb
        ? webAppId
        : defaultTargetPlatform == TargetPlatform.iOS
        ? iosAppId
        : androidAppId;
    final appId = platformAppId.isNotEmpty ? platformAppId : commonAppId;
    final values = [apiKey, projectId, senderId, appId];
    if (values.every((value) => value.isEmpty)) return;
    if (values.any((value) => value.isEmpty || value.startsWith('replace-with'))) {
      throw StateError(
        'Configurarea Firebase este incompletă. Verifică FIREBASE_API_KEY, '
        'FIREBASE_PROJECT_ID, FIREBASE_MESSAGING_SENDER_ID și FIREBASE_APP_ID.',
      );
    }
    const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
    const bundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
    const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
    _app = await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
        authDomain: authDomain.isNotEmpty
            ? authDomain
            : '$projectId.firebaseapp.com',
        storageBucket: storageBucket.isEmpty ? null : storageBucket,
        iosBundleId: bundleId.isEmpty ? null : bundleId,
      ),
    );
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signUp(String email, String password, String name) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (name.trim().isNotEmpty) {
      await result.user?.updateDisplayName(name.trim());
    }
    await result.user?.sendEmailVerification();
  }

  Future<void> signOut() async {
    if (configured) await _auth.signOut();
  }

  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

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
}
