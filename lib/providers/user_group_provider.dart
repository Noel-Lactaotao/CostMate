import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userGroupsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return [];

  final List<Map<String, dynamic>> groups = [];
  final firestore = FirebaseFirestore.instance;

  // Groups created by user
  final created =
      await firestore
          .collection('groups')
          .where('createdBy', isEqualTo: user.uid)
          .get();

  for (var doc in created.docs) {
    final data = doc.data();

    final memberCountSnap =
        await firestore
            .collection('groupmembers')
            .where('groupId', isEqualTo: doc.id)
            .get();

    groups.add({
      'groupId': doc.id,
      'groupName': data['groupName'] ?? 'Unnamed',
      'isAdmin': true,
      'adminName': 'You',
      'memberCount': memberCountSnap.size,
      'role': 'Admin',
    });
  }

  // Groups joined by user
  final memberGroupsSnap =
      await firestore
          .collection('groupmembers')
          .where('userId', isEqualTo: user.uid)
          .get();

  for (var memberDoc in memberGroupsSnap.docs) {
    final groupId = memberDoc['groupId'];

    if (groups.any((g) => g['groupId'] == groupId)) continue;

    final groupDoc = await firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) continue;

    final groupData = groupDoc.data()!;
    final memberCountSnap =
        await firestore
            .collection('groupmembers')
            .where('groupId', isEqualTo: groupId)
            .get();

    groups.add({
      'groupId': groupId,
      'groupName': groupData['groupName'] ?? 'Unnamed',
      'isAdmin': false,
      'adminName': groupData['createdByName'] ?? 'Unknown',
      'memberCount': memberCountSnap.size,
      'role': memberDoc['role'] ?? 'Member',
    });
  }

  return groups;
});
