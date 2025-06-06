import 'package:costmate/auth/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

/// User info state model
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

/// Provider that listens for user info and group memberships
final userInfoProvider = StreamProvider<UserInfoState>((ref) {
  final user = ref.watch(authStateProvider).value;
  final firestore = FirebaseFirestore.instance;

  if (user == null) {
    return Stream.value(UserInfoState.initial());
  }

  final userDocStream = firestore.collection("users").doc(user.uid).snapshots();
  final createdGroupsStream =
      firestore
          .collection('groups')
          .where('createdBy', isEqualTo: user.uid)
          .snapshots();
  final groupMembersStream =
      firestore
          .collection('groupmembers')
          .where('userId', isEqualTo: user.uid)
          .snapshots();

  return Rx.combineLatest3(
    userDocStream,
    createdGroupsStream,
    groupMembersStream,
    (
      DocumentSnapshot userDoc,
      QuerySnapshot createdGroupsSnap,
      QuerySnapshot joinedGroupsSnap,
    ) async {
      final data = userDoc.data() as Map<String, dynamic>? ?? {};
      final name = data['name'] ?? user.displayName ?? 'No Name';
      final email = data['email'] ?? user.email ?? 'No Email';
      final photoURL = data['photoURL'] ?? user.photoURL ?? '';

      final createdGroups = await Future.wait(
        createdGroupsSnap.docs.map((doc) async {
          return {
            'groupId': doc.id,
            'groupName': doc['groupName'] ?? 'Unnamed',
            'isAdmin': true,
          };
        }),
      );

      final createdGroupIds =
          createdGroupsSnap.docs.map((doc) => doc.id).toSet();

      final joinedGroups = await Future.wait(
        joinedGroupsSnap.docs.map((memberDoc) async {
          final groupId = memberDoc['groupId'];
          if (createdGroupIds.contains(groupId)) return null;

          final groupDoc =
              await firestore.collection('groups').doc(groupId).get();
          if (!groupDoc.exists) return null;

          return {
            'groupId': groupId,
            'groupName': groupDoc['groupName'] ?? 'Unnamed',
            'isAdmin': false,
          };
        }),
      );

      return UserInfoState(
        name: name,
        email: email,
        photoURL: photoURL,
        createdGroups: createdGroups,
        joinedGroups: joinedGroups.whereType<Map<String, dynamic>>().toList(),
      );
    },
  ).asyncMap((futureState) => futureState);
});

/// Provider that returns detailed group info (admin name, member count, etc.)
final userGroupsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final firestore = FirebaseFirestore.instance;

  if (user == null) {
    return Stream.value([]);
  }

  final createdGroupsStream =
      firestore
          .collection('groups')
          .where('createdBy', isEqualTo: user.uid)
          .snapshots();

  final joinedGroupsStream =
      firestore
          .collection('groupmembers')
          .where('userId', isEqualTo: user.uid)
          .snapshots();

  return Rx.combineLatest2(
    createdGroupsStream,
    joinedGroupsStream,
    (QuerySnapshot createdSnapshot, QuerySnapshot joinedSnapshot) => [
      createdSnapshot,
      joinedSnapshot,
    ],
  ).switchMap((snapshots) {
    final createdSnapshot = snapshots[0];
    final joinedSnapshot = snapshots[1];

    final createdGroupIds = createdSnapshot.docs.map((doc) => doc.id).toSet();
    final joinedGroupIds =
        joinedSnapshot.docs
            .map((doc) => doc['groupId'] as String)
            .where((id) => !createdGroupIds.contains(id))
            .toSet();

    final allGroupIds = {...createdGroupIds, ...joinedGroupIds};

    if (allGroupIds.isEmpty) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    final groupStreams = allGroupIds.map((groupId) {
      final groupDocStream =
          firestore.collection('groups').doc(groupId).snapshots();
      final memberCountStream = firestore
          .collection('groupmembers')
          .where('groupId', isEqualTo: groupId)
          .snapshots()
          .map((snap) => snap.size);

      return Rx.combineLatest2<
        DocumentSnapshot<Map<String, dynamic>>,
        int,
        Map<String, dynamic>?
      >(groupDocStream, memberCountStream, (groupDoc, memberCount) {
        if (!groupDoc.exists) return null;
        final data = groupDoc.data()!;
        final isAdmin = data['createdBy'] == user.uid;
        final matchingDocs = joinedSnapshot.docs.where(
          (d) => d['groupId'] == groupId,
        );

        final role =
            isAdmin
                ? 'Admin'
                : (matchingDocs.isNotEmpty
                    ? matchingDocs.first['role'] ?? 'Member'
                    : 'Member');

        return {
          'groupId': groupId,
          'groupName': data['groupName'] ?? 'Unnamed',
          'isAdmin': isAdmin,
          'adminName': isAdmin ? 'You' : data['createdByName'] ?? 'Unknown',
          'memberCount': memberCount,
          'role': role,
        };
      });
    });

    return Rx.combineLatestList(groupStreams).map((groupList) {
      return groupList.whereType<Map<String, dynamic>>().toList();
    });
  });
});
