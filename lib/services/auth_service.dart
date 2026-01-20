// services/auth_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthState {
  final bool signedIn;
  final String? role;
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
}

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Public getter for current user
  User? get currentUser => _auth.currentUser;

  final StreamController<AuthState> _stateController =
      StreamController<AuthState>.broadcast();
  Stream<AuthState> get authState$ => _stateController.stream;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  AuthService() {
    _authSubscription = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    await _userDocSubscription?.cancel();

    if (firebaseUser == null) {
      _emit(AuthState(signedIn: false, hasRole: false, onboarded: false));
      return;
    }

    final docRef = _db.collection('users').doc(firebaseUser.uid);

    _userDocSubscription = docRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists) {
        final initialData = {
          'uid': firebaseUser.uid,
          'email': firebaseUser.email,
          'name': firebaseUser.displayName ?? '',
          'photoUrl': firebaseUser.photoURL,
          'role': null,
          'onboarded': false,
          'createdAt': FieldValue.serverTimestamp(),
          'isVerified': false,
          'totalConnects': 20,
          'totalEarnings': 0,
          'totalProposals': 0,
        };
        await docRef.set(initialData);
      }

      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final appUser = AppUser.fromMap({
        ...data,
        'uid': firebaseUser.uid,
        'email': firebaseUser.email ?? '',
        'name': data['name'] ?? firebaseUser.displayName ?? 'User',
        'photoUrl': data['photoUrl'] ?? firebaseUser.photoURL,
      });

      _emit(
        AuthState(
          signedIn: true,
          role: appUser.role,
          hasRole: appUser.role != null,
          onboarded: appUser.onboarded,
          user: appUser,
        ),
      );
    });
  }

  void _emit(AuthState state) {
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        await _auth.signInWithPopup(provider);
      } else {
        final googleUser = await _googleSignIn.authenticate();
        if (googleUser == null) return;

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.idToken,
          idToken: googleAuth.idToken,
        );
        await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  Future<void> setRole({
    required String role,
    Map<String, dynamic> extraFields = const {},
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    final payload = {
      'role': role,
      'onboarded': extraFields['onboarded'] ?? false,
      ...extraFields,
    };

    await _db
        .collection('users')
        .doc(uid)
        .set(payload, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userDocSubscription?.cancel();
    _stateController.close();
    super.dispose();
  }
}
