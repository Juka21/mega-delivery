import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../config/app_config.dart';

class AppUser {
  final String uid;
  final String email;
  final String nome;
  final String role;
  final String telefone;
  final String photoURL;

  AppUser({
    required this.uid,
    required this.email,
    required this.nome,
    required this.role,
    this.telefone = '',
    this.photoURL = '',
  });

  factory AppUser.fromFirebase(User user, Map<String, dynamic>? data) {
    final email = data?['email']?.toString() ?? user.email ?? '';
    return AppUser(
      uid: user.uid,
      email: email,
      nome: data?['nome']?.toString() ?? user.displayName ?? 'Cliente',
      role: data?['role']?.toString() ??
          (AppConfig.isAdminEmail(email) ? 'admin' : 'cliente'),
      telefone: data?['telefone']?.toString() ?? user.phoneNumber ?? '',
      photoURL: data?['photoURL']?.toString() ?? user.photoURL ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'nome': nome,
      'role': role,
      'telefone': telefone,
      'photoURL': photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final StreamController<AppUser?> _authStateController =
      StreamController<AppUser?>.broadcast();

  Stream<AppUser?> get userChanges => _authStateController.stream;
  AppUser? currentUser;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;

  Future<void> inicializar() async {
    await _syncCurrentUser(_auth.currentUser);
    _authSubscription ??= _auth.authStateChanges().listen(_syncCurrentUser);
    _tokenSubscription ??=
        FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      _db.collection('users').doc(uid).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<String> getAuthToken() async {
    return await _auth.currentUser?.getIdToken() ?? '';
  }

  Future<void> _syncCurrentUser(User? user) async {
    if (user == null) {
      currentUser = null;
      _authStateController.add(null);
      return;
    }

    var doc = await _db.collection('users').doc(user.uid).get();
    if (AppConfig.isAdminEmail(user.email) && doc.data()?['role'] != 'admin') {
      await _saveUserProfile(user);
      doc = await _db.collection('users').doc(user.uid).get();
    }

    currentUser = AppUser.fromFirebase(user, doc.data());
    _authStateController.add(currentUser);

    await _saveFcmToken(user.uid);
  }

  Future<void> _saveUserProfile(User user,
      {String nome = 'Cliente',
      String telefone = '',
      String role = 'cliente'}) async {
    final ref = _db.collection('users').doc(user.uid);
    final existing = await ref.get();
    final existingData = existing.data();
    final email = (user.email ?? '').trim();
    final resolvedRole = AppConfig.isAdminEmail(email)
        ? 'admin'
        : existingData?['role']?.toString() ?? role;

    final data = {
      'uid': user.uid,
      'email': email,
      'nome': existingData?['nome'] ?? user.displayName ?? nome,
      'role': resolvedRole,
      'telefone': existingData?['telefone'] ?? telefone,
      'photoURL': existingData?['photoURL'] ?? user.photoURL ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(data, SetOptions(merge: true));
    await _saveFcmToken(user.uid);
  }

  Future<void> _saveFcmToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _db.collection('users').doc(uid).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Notifications are optional; auth should not fail because FCM is unavailable.
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    final user = credential.user;
    if (user == null) throw Exception('Erro ao fazer login.');
    await _saveUserProfile(user);
    await _syncCurrentUser(user);
  }

  Future<void> signUp(
      {required String email,
      required String password,
      String nome = 'Cliente',
      String telefone = ''}) async {
    final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    final user = credential.user;
    if (user == null) throw Exception('Erro ao registar conta.');

    await user.updateDisplayName(nome);
    await _saveUserProfile(user, nome: nome, telefone: telefone);
    await _syncCurrentUser(user);
  }

  Future<void> refreshUser() async {
    await _syncCurrentUser(_auth.currentUser);
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Google Sign-In may not be initialized if the user signed in with email.
    }
    await _auth.signOut();
    currentUser = null;
    _authStateController.add(null);
  }

  Future<void> forgotPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(
      serverClientId: AppConfig.googleSignInServerClientId,
    );

    final googleUser = await googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    final credential =
        GoogleAuthProvider.credential(idToken: googleAuth.idToken);
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) throw Exception('Erro no login com Google.');

    await _saveUserProfile(user);
    await _syncCurrentUser(user);
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final identityToken = appleCredential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw Exception('Erro no login com Apple.');
    }

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: identityToken,
      rawNonce: rawNonce,
    );

    final userCredential = await _auth.signInWithCredential(oauthCredential);
    final user = userCredential.user;
    if (user == null) throw Exception('Erro no login com Apple.');

    final appleName = [
      appleCredential.givenName,
      appleCredential.familyName,
    ]
        .where((part) => part != null && part.trim().isNotEmpty)
        .map((part) => part!.trim())
        .join(' ');

    if (appleName.isNotEmpty && (user.displayName ?? '').isEmpty) {
      await user.updateDisplayName(appleName);
    }

    await _saveUserProfile(
      user,
      nome: appleName.isNotEmpty ? appleName : 'Cliente',
    );
    await _syncCurrentUser(user);
  }
}
