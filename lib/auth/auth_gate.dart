import 'package:costmate/screens/main_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:costmate/auth/signin_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show a loading spinner while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If user is signed in, go to HomeScreen
        if (snapshot.hasData) {
          return const MainScreen();
        }

        // If not signed in, go to SignInScreen (or GetStarted)
        return const SignInScreen(); // or const GetstartedScreen()
      },
    );
  }
}
