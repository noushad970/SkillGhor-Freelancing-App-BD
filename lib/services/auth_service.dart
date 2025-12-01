// services/auth_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthState {
  final bool signedIn;
  final String? role; // 'freelancer' or 'client'
  final bool hasRole;
  final bool onboarded;
  final AppUser? user;

  AuthState({
    required this.signedIn,
    this.role,
    required this.hasRole,
    required this.onboarded,
    this.user,
  });

  // Helper for easy debugging
  @override
  String toString() {
    return 'AuthState(signedIn: $signedIn, role: $role, hasRole: $hasRole, onboarded: $onboarded)';
  }
}

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Public reactive stream
  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();
  Stream<AuthState> get authState$ => _authStateController.stream;

  StreamSubscription<User?>? _firebaseUserSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  AuthService() {
    _firebaseUserSub = _auth.authStateChanges().listen(_onFirebaseUserChanged);
  }

  Future<void> _onFirebaseUserChanged(User? firebaseUser) async {
    await _userDocSub?.cancel();

    if (firebaseUser == null) {
      _emit(AuthState(signedIn: false, hasRole: false, onboarded: false));
      return;
    }

    final docRef = _db.collection('users').doc(firebaseUser.uid);

    _userDocSub = docRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists) {
        // First time user → create minimal profile
        final basicUser = {
          'uid': firebaseUser.uid,
          'name': firebaseUser.displayName ?? 'User',
          'email': firebaseUser.email ?? '',
          'photoUrl': firebaseUser.photoURL,
          'role': null,
          'onboarded': false,
          'createdAt': FieldValue.serverTimestamp(),
        };

        await docRef.set(basicUser);
        _emit(AuthState(signedIn: true, hasRole: false, onboarded: false));
        return;
      }

      final data = snapshot.data()!;
      final appUser = AppUser.fromMap(data);

      _emit(
        AuthState(
          signedIn: true,
          role: appUser.role,
          hasRole: appUser.role != null,
          onboarded: appUser.onboarded ?? false,
          user: appUser,
        ),
      );
    });
  }

  void _emit(AuthState state) {
    if (!_authStateController.isClosed) {
      _authStateController.add(state);
    }
  }

  // GOOGLE SIGN IN (Only method)
  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        await _auth.signInWithPopup(provider);
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn
            .authenticate();
        if (googleUser == null) return; // User canceled

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.idToken,
          idToken: googleAuth.idToken,
        );

        await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint('Google Sign-In Failed: $e');
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Set Role (Freelancer or Client) + Onboarding
  Future<void> setRole({
    required String role, // 'freelancer' or 'client'
    Map<String, dynamic> extraFields = const {},
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final payload = {'role': role, 'onboarded': true, ...extraFields};

    await _db
        .collection('users')
        .doc(uid)
        .set(payload, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _firebaseUserSub?.cancel();
    _userDocSub?.cancel();
    _authStateController.close();
    super.dispose();
  }
}
