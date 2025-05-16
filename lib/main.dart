import 'package:costmate/auth/auth_gate.dart';
import 'package:costmate/auth/signin_screen.dart';
import 'package:costmate/auth/signup_screen.dart';
import 'package:costmate/screens/group_screen.dart';
import 'package:costmate/screens/main_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Web needs manual Firebase options
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAMg_8Znrfblm9aJ2DW3ZatdDp1xNC6g5Q",
        authDomain: "costmate-58c96.firebaseapp.com",
        projectId: "costmate-58c96",
        storageBucket: "costmate-58c96.firebasestorage.app",
        messagingSenderId: "419867456944",
        appId: "1:419867456944:web:43b65c7c4d5e6753871275",
        measurementId: "G-L3D5XH7Y4Z",
      ),
    );
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(ProviderScope(child: const MainApp(),));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black12),
      ),
      title: "CostMate",
      debugShowCheckedModeBanner: false,
      home: const AuthGate(), // Use AuthGate to determine which screen to show
      routes: {
        '/signin': (context) => const SignInScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const MainScreen(), // Main screen route
        '/group':
            (context) =>
                GroupScreen(onUpdateAppBar: (appBar) {}), // Group screen
      },
    );
  }
}
