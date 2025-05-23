import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

// Expenses provider for a given groupId
// Expenses with creator name/email
final expensesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) {
      final firestore = FirebaseFirestore.instance;

      final expenseSnapshots =
          firestore
              .collection('expenses')
              .where('groupId', isEqualTo: groupId)
              .snapshots();

      return expenseSnapshots.switchMap((snapshot) {
        final docs = snapshot.docs;
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        if (docs.isEmpty || currentUserId == null) return Stream.value([]);

        // Current user's role in this group
        final currentUserRoleStream = firestore
            .collection('groupmembers')
            .where('groupId', isEqualTo: groupId)
            .where('userId', isEqualTo: currentUserId)
            .limit(1)
            .snapshots()
            .map((snap) {
              final role =
                  snap.docs.isNotEmpty
                      ? snap.docs.first.data()['role'] as String?
                      : null;
              return role ?? 'Member';
            });

        // To avoid duplicate lookups for same user
        final Map<String, Stream<Map<String, dynamic>>> userCache = {};

        List<Stream<Map<String, dynamic>>> enrichedStreams =
            docs.map((doc) {
              final data = doc.data();
              final docId = doc.id;
              final createdBy = data['createdBy'];

              if (createdBy == null) {
                return Stream.value({...data, 'id': docId});
              }

              userCache.putIfAbsent(createdBy, () {
                return firestore
                    .collection('users')
                    .doc(createdBy)
                    .snapshots()
                    .map((userDoc) {
                      final userData = userDoc.data();
                      return {
                        'name': userData?['name'] ?? 'Unknown',
                        'email': userData?['email'] ?? 'Unknown',
                      };
                    });
              });

              return userCache[createdBy]!.map((userInfo) {
                return {
                  ...data,
                  'id': docId,
                  'createdByName': userInfo['name'],
                  'createdByEmail': userInfo['email'],
                };
              });
            }).toList();

        return Rx.combineLatest2<
          List<Map<String, dynamic>>,
          String,
          List<Map<String, dynamic>>
        >(Rx.combineLatestList(enrichedStreams), currentUserRoleStream, (
          expenses,
          currentUserRole,
        ) {
          return expenses
              .map(
                (expense) => {...expense, 'currentUserRole': currentUserRole},
              )
              .toList();
        });
      });
    });

// TODOs with creator name/email
final todoProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((
  ref,
  groupId,
) {
  final firestore = FirebaseFirestore.instance;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // Stream of TODO documents filtered by groupId
  final todoSnapshots =
      firestore
          .collection('TODO')
          .where('groupId', isEqualTo: groupId)
          .snapshots();

  return todoSnapshots.switchMap((snapshot) {
    final docs = snapshot.docs;

    // If no todos or no logged-in user, emit empty list
    if (docs.isEmpty || currentUserId == null) return Stream.value([]);

    // Stream to get current user's role in this group
    final currentUserRoleStream = firestore
        .collection('groupmembers')
        .where('groupId', isEqualTo: groupId)
        .where('userId', isEqualTo: currentUserId)
        .limit(1)
        .snapshots()
        .map<String>((snap) {
          if (snap.docs.isNotEmpty) {
            final role = snap.docs.first.data()['role'];
            return role ?? 'Member';
          } else {
            return 'Member';
          }
        });

    // For each TODO doc, create a stream that enriches it with the creator's user info
    final List<Stream<Map<String, dynamic>?>> enrichedStreams =
        docs.map((doc) {
          final data = doc.data();
          final docId = doc.id;
          final createdBy = data['createdBy'] as String?;

          if (createdBy == null) {
            // If no creator, just return the data with id
            return Stream.value({...data, 'id': docId});
          }

          // Stream the user document of the creator
          return firestore.collection('users').doc(createdBy).snapshots().map((
            userDoc,
          ) {
            final userData = userDoc.data();
            return {
              ...data,
              'id': docId,
              'createdByName': userData?['name'] ?? 'Unknown',
              'createdByEmail': userData?['email'] ?? 'Unknown',
            };
          });
        }).toList();

    // Combine all enriched TODO streams into one stream of list + currentUserRoleStream
    return Rx.combineLatest2<
      List<Map<String, dynamic>?>,
      String,
      List<Map<String, dynamic>>
    >(Rx.combineLatestList(enrichedStreams), currentUserRoleStream, (
      todos,
      currentUserRole,
    ) {
      return todos
          .whereType<Map<String, dynamic>>()
          .map((todo) => {...todo, 'currentUserRole': currentUserRole})
          .toList();
    });
  });
});

// Members provider for a given groupId
final membersProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) {
      final firestore = FirebaseFirestore.instance;

      // Stream for all members of the group
      final groupMembersStream =
          firestore
              .collection('groupmembers')
              .where('groupId', isEqualTo: groupId)
              .snapshots();

      // For each member, fetch user info as stream and combine roles
      return groupMembersStream.switchMap((groupMembersSnapshot) {
        final userIds =
            groupMembersSnapshot.docs
                .map((doc) => doc['userId'] as String)
                .toList();
        final rolesByUserId = {
          for (var doc in groupMembersSnapshot.docs)
            doc['userId'] as String: doc.data()['role'] as String?,
        };

        if (userIds.isEmpty) {
          return Stream.value([]);
        }

        // For each userId, listen to their user doc stream
        final userStreams = userIds.map((userId) {
          return firestore.collection('users').doc(userId).snapshots().map((
            userDoc,
          ) {
            if (!userDoc.exists) return null;
            final userData = userDoc.data()!;
            userData['uid'] = userId;
            userData['role'] = rolesByUserId[userId] ?? 'Member';
            return userData;
          });
        });

        // Combine all user streams into one stream of list
        return Rx.combineLatestList(userStreams).map(
          (userList) => userList.whereType<Map<String, dynamic>>().toList(),
        );
      });
    });

final singleExpenseProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, expenseId) {
      final firestore = FirebaseFirestore.instance;

      return firestore
          .collection('expenses')
          .doc(expenseId)
          .snapshots()
          .asyncMap((doc) async {
            final data = doc.data();
            if (data == null) return null;

            final userDoc =
                await firestore
                    .collection('users')
                    .doc(data['createdBy'])
                    .get();
            final userData = userDoc.data();

            return {
              ...data,
              'id': doc.id,
              'createdByName': userData?['name'] ?? 'Unknown',
              'createdByEmail': userData?['email'] ?? 'Unknown',
            };
          });
    });

final singleTodoProvider = StreamProvider.family<Map<String, dynamic>?, String>(
  (ref, todoId) {
    final firestore = FirebaseFirestore.instance;

    return firestore.collection('TODO').doc(todoId).snapshots().asyncMap((
      doc,
    ) async {
      final data = doc.data();
      if (data == null) return null;

      final userDoc =
          await firestore.collection('users').doc(data['createdBy']).get();
      final userData = userDoc.data();

      return {
        ...data,
        'id': doc.id,
        'createdByName': userData?['name'] ?? 'Unknown',
        'createdByEmail': userData?['email'] ?? 'Unknown',
      };
    });
  },
);
