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

  // stream controller to push AuthState updates
  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();
  Stream<AuthState> get authState$ => _controller.stream;

  StreamSubscription<User?>? _firebaseUserSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  AuthService() {
    _firebaseUserSub = _auth.authStateChanges().listen(_onFirebaseUserChanged);
  }

  Future<void> _onFirebaseUserChanged(User? fUser) async {
    // cancel old doc sub
    await _userDocSub?.cancel();

    if (fUser == null) {
      _controller.add(
        AuthState(signedIn: false, hasRole: false, onboarded: false),
      );
      return;
    }

    // listen to user document
    final docRef = _db.collection('users').doc(fUser.uid);
    _userDocSub = docRef.snapshots().listen((snapshot) {
      if (!snapshot.exists) {
        // create minimal user doc
        final basic = {
          'name': fUser.displayName,
          'email': fUser.email,
          'photoUrl': fUser.photoURL,
          'role': null,
          'verified': false,
          'onboarded': false,
        };
        docRef.set(basic, SetOptions(merge: true));
        _controller.add(
          AuthState(signedIn: true, hasRole: false, onboarded: false),
        );
        return;
      }

      final data = snapshot.data()!;
      final appUser = AppUser.fromMap(snapshot.id, data);
      final hasRole = (appUser.role != null);
      _controller.add(
        AuthState(
          signedIn: true,
          role: appUser.role,
          hasRole: hasRole,
          onboarded: appUser.onboarded,
          user: appUser,
        ),
      );
    });
  }

  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        await _auth.signInWithPopup(provider);
      } else {
        final g = GoogleSignIn.instance;
        // initialize lightweight (optional)
        await g.initialize();
        // try lightweight auth first
        await g.attemptLightweightAuthentication();
        GoogleSignInAccount? account;
        if (g.supportsAuthenticate()) {
          account = await g.authenticate();
        } else {
          // fallback (older platforms) – you could provide alternative UI
          account = await g.authenticate();
        }
        if (account == null) return; // user cancelled
        final auth = await account.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: auth.idToken,
          idToken: auth.idToken,
        );
        await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
    _controller.add(
      AuthState(signedIn: false, hasRole: false, onboarded: false),
    );
  }

  Future<void> setRoleAndOnboard({
    required String uid,
    required String role,
    required Map<String, dynamic> extraFields,
  }) async {
    final docRef = _db.collection('users').doc(uid);
    final payload = <String, dynamic>{'role': role, 'onboarded': true};
    payload.addAll(extraFields);
    // Keep verified false until you decide to verify KYC
    await docRef.set(payload, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _firebaseUserSub?.cancel();
    _userDocSub?.cancel();
    _controller.close();
    super.dispose();
  }
}
