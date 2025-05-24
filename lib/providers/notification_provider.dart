import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

final userNotificationProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
      final firestore = FirebaseFirestore.instance;

      final notificationSnapshots =
          firestore
              .collection('usernotifications')
              .where('userId', isEqualTo: userId)
              .snapshots();

      return notificationSnapshots.switchMap((snapshot) {
        final docs = snapshot.docs;

        if (docs.isEmpty) return Stream.value([]);

        final List<Stream<Map<String, dynamic>?>> enrichedStreams =
            docs.map((doc) {
              final data = doc.data();
              final docId = doc.id;
              final userId = data['userId'];
              final groupId = data['groupId'];
              final action = data['action'];
              final createdAt = data['createdAt'];
              final isSeen = data['isSeen'] ?? false;

              final userStream =
                  firestore.collection('users').doc(userId).snapshots();
              final groupStream =
                  firestore.collection('groups').doc(groupId).snapshots();

              return Rx.combineLatest2<
                DocumentSnapshot<Map<String, dynamic>>,
                DocumentSnapshot<Map<String, dynamic>>,
                Map<String, dynamic>
              >(userStream, groupStream, (userDoc, groupDoc) {
                final userData = userDoc.data();
                final groupData = groupDoc.data();

                return {
                  'id': docId,
                  'userId': userId,
                  'name': userData?['name'] ?? 'Unknown',
                  'email': userData?['email'] ?? 'Unknown',
                  'groupId': groupId,
                  'groupName': groupData?['groupName'] ?? 'Unknown Group',
                  'action': action ?? 'No action',
                  'createdAt': createdAt,
                  'isSeen': isSeen,
                };
              });
            }).toList();

        return Rx.combineLatestList(enrichedStreams).map(
          (notifications) =>
              notifications.whereType<Map<String, dynamic>>().toList(),
        );
      });
    });

final groupNotificationProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) {
      final firestore = FirebaseFirestore.instance;

      final notificationSnapshots =
          firestore
              .collection('groupnotifications')
              .where('groupId', isEqualTo: groupId)
              .snapshots();

      return notificationSnapshots.switchMap((snapshot) {
        final docs = snapshot.docs;

        if (docs.isEmpty) return Stream.value([]);

        final List<Stream<Map<String, dynamic>?>> enrichedStreams =
            docs.map((doc) {
              final data = doc.data();
              final docId = doc.id;
              final userId = data['userId'];
              final groupId = data['groupId'];
              final action = data['action'];
              final createdAt = data['createdAt'];
              final seenBy = data['seenBy']; // ✅ Add this line

              final userStream =
                  firestore.collection('users').doc(userId).snapshots();
              final groupStream =
                  firestore.collection('groups').doc(groupId).snapshots();

              return Rx.combineLatest2<
                DocumentSnapshot<Map<String, dynamic>>,
                DocumentSnapshot<Map<String, dynamic>>,
                Map<String, dynamic>
              >(userStream, groupStream, (userDoc, groupDoc) {
                final userData = userDoc.data();
                final groupData = groupDoc.data();

                return {
                  'id': docId,
                  'userId': userId,
                  'name': userData?['name'] ?? 'Unknown',
                  'email': userData?['email'] ?? 'Unknown',
                  'groupId': groupId,
                  'groupName': groupData?['groupName'] ?? 'Unknown Group',
                  'action': action ?? 'No action',
                  'createdAt': createdAt,
                  'seenBy': seenBy ?? [], // ✅ Add this too
                };
              });
            }).toList();

        return Rx.combineLatestList(enrichedStreams).map(
          (notifications) =>
              notifications.whereType<Map<String, dynamic>>().toList(),
        );
      });
    });
