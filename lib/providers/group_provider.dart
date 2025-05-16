import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final groupListProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        // Return an empty stream if user is not logged in
        return const Stream.empty();
      }

      return FirebaseFirestore.instance
          .collection('groups')
          .where(
            'members',
            arrayContains: user.uid,
          ) // assumes each group has a members list
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map((doc) => doc.data() as Map<String, dynamic>)
                    .toList(),
          );
    });
