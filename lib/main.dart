import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'screens/sign_in_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/freelancer_profile_screen.dart';
import 'screens/client_profile_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: 'Freelance App',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const EntryPoint(),
      ),
    );
  }
}

class EntryPoint extends StatelessWidget {
  const EntryPoint({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    return StreamBuilder<AuthState>(
      stream: auth.authState$, // custom stream from AuthService
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(body: Center(child: Text('Auth stream error')));
        }
        final state = snapshot.data;
        if (state == null) {
          // waiting for init
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!state.signedIn) {
          return const SignInScreen();
        }

        // signed in but role not set -> show role selection
        if (!state.hasRole) {
          return const RoleSelectionScreen();
        }

        // signed in and has role and onboarding finished -> go to home
        if (state.role == 'freelancer' && !state.onboarded) {
          return FreelancerProfileScreen(uid: state.user!.uid);
        }
        if (state.role == 'client' && !state.onboarded) {
          return ClientProfileScreen(uid: state.user!.uid);
        }

        return const HomeScreen();
      },
    );
  }
}
