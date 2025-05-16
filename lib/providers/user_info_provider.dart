import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserInfoState {
  final String name;
  final String email;
  final String photoURL;
  final List<Map<String, dynamic>> createdGroups;
  final List<Map<String, dynamic>> joinedGroups;

  UserInfoState({
    required this.name,
    required this.email,
    required this.photoURL,
    required this.createdGroups,
    required this.joinedGroups,
  });

  UserInfoState.initial()
    : name = '',
      email = '',
      photoURL = '',
      createdGroups = [],
      joinedGroups = [];
}

class UserInfoNotifier extends StateNotifier<UserInfoState> {
  UserInfoNotifier() : super(UserInfoState.initial());

  Future<void> loadUserData(User user) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection("users")
              .doc(user.uid)
              .get();

      String name = userDoc["name"] ?? user.displayName ?? "No Name";
      String email = userDoc["email"] ?? user.email ?? "No Email";
      String photoURL = userDoc["photoURL"] ?? user.photoURL ?? "";

      final createdSnapshot =
          await FirebaseFirestore.instance
              .collection('groups')
              .where('createdBy', isEqualTo: user.uid)
              .get();

      List<Map<String, dynamic>> createdGroups =
          createdSnapshot.docs.map((doc) {
            return {
              'groupId': doc.id,
              'groupName': doc['groupName'],
              'isAdmin': true,
            };
          }).toList();

      List<String> createdIds =
          createdGroups.map((g) => g['groupId'] as String).toList();

      final joinedSnapshot =
          await FirebaseFirestore.instance
              .collection('groupmembers')
              .where('userId', isEqualTo: user.uid)
              .get();

      List<Map<String, dynamic>> joinedGroups = [];

      for (var doc in joinedSnapshot.docs) {
        final groupId = doc['groupId'] as String;

        if (createdIds.contains(groupId)) continue;

        final groupDoc =
            await FirebaseFirestore.instance
                .collection('groups')
                .doc(groupId)
                .get();

        if (!groupDoc.exists) continue;

        joinedGroups.add({
          'groupId': groupId,
          'groupName': groupDoc['groupName'],
          'isAdmin': false,
        });
      }

      state = UserInfoState(
        name: name,
        email: email,
        photoURL: photoURL,
        createdGroups: createdGroups,
        joinedGroups: joinedGroups,
      );
    } catch (e) {
      print("Error loading user data: $e");
    }
  }
}

final userInfoProvider = StateNotifierProvider<UserInfoNotifier, UserInfoState>(
  (ref) {
    return UserInfoNotifier();
  },
);
