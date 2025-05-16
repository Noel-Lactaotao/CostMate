import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => null;

  Future<User?> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      // Create the user using Firebase Authentication
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      User? user = userCredential.user;
      if (user != null) {
        // Save user data to Firestore with 'verified' field as false initially
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'verified': false, // User is not verified initially
          'createdAt': FieldValue.serverTimestamp(),
        });

        return user; // Return the user object after creation
      }
    } catch (e) {
      print('Error during user creation: $e');
    }
    return null; // Return null if creation fails
  }

  Future<bool> checkEmailVerified() async {
    User? user = _auth.currentUser;

    if (user != null) {
      await user.reload(); // Reload to get the updated status
      return user.emailVerified;
    }
    return false;
  }

  /// 🔹 Send email verification
  Future<void> sendEmailVerification(User user) async {
    try {
      await user.sendEmailVerification();
    } catch (e) {
      print('Error sending verification email: $e');
    }
  }

  // 🔹 Email & Password Sign-Up
  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // First, register the user (this will handle adding data to Firestore)
      User? user = await registerUser(
        name: name,
        email: email,
        password: password,
      );

      if (user != null) {
        // Send email verification after the user is successfully created
        await user.sendEmailVerification();
        return null; // Return null indicating success
      } else {
        return 'User creation failed';
      }
    } catch (e) {
      return e.toString(); // Handle any errors that occur
    }
  }

  // 🔹 Email & Password Sign-In
  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // 🔹 Google Sign-In
  Future<String?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // 🔹 Web sign-in with popup
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // 🔹 Android/iOS
        await GoogleSignIn().signOut(); // Optional: ensures a clean start
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return "Google Sign-In cancelled";

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      // 🔐 User info setup
      User? user = userCredential.user;
      if (user != null) {
        DocumentSnapshot userDoc = await _firestore.collection("users").doc(user.uid).get();

        if (!userDoc.exists) {
          await _firestore.collection("users").doc(user.uid).set({
            "uid": user.uid,
            "email": user.email,
            "name": user.displayName ?? "Unknown User",
            "photoURL": user.photoURL ?? "",
            "createdAt": FieldValue.serverTimestamp(),
          });
        }
        return null; // ✅ Success
      }
    } catch (e) {
      return e.toString(); // ⚠️ Return error message
    }

    return "Google Sign-In failed.";
  }

  // 🔹 Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }

  // 🔹 Get Current User
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
