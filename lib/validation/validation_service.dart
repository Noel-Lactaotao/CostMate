import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ValidationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new group
  Future<String?> createGroup({required String groupName}) async {
    try {
      User? user = _auth.currentUser;

      if (user != null) {
        DocumentReference groupRef = _firestore.collection('groups').doc();

        String groupCode = _generateGroupCode();

        await groupRef.set({
          'groupId': groupRef.id,
          'groupName': groupName,
          'createdBy': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'groupCode': groupCode,
        });

        // Add creator as a member in top-level collection 'groupmembers'
        await _firestore.collection('groupmembers').add({
          'groupId': groupRef.id, // associate with group
          'userId': user.uid,
          'role': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
        });

        return groupRef.id;
      }
    } catch (e) {
      print('Error creating group: $e');
    }
    return null;
  }

  // Join an existing group using its group code
  Future<String?> joinGroup({required String groupCode}) async {
    try {
      User? user = _auth.currentUser;

      if (user != null) {
        QuerySnapshot groupSnapshot =
            await _firestore
                .collection('groups')
                .where('groupCode', isEqualTo: groupCode)
                .limit(1)
                .get();

        if (groupSnapshot.docs.isNotEmpty) {
          DocumentSnapshot groupDoc = groupSnapshot.docs.first;
          String groupId = groupDoc.id;

          // Check if user is already a member in top-level collection 'groupmembers'
          QuerySnapshot existingMemberSnapshot =
              await _firestore
                  .collection('groupmembers')
                  .where('groupId', isEqualTo: groupId)
                  .where('userId', isEqualTo: user.uid)
                  .get();

          if (existingMemberSnapshot.docs.isEmpty) {
            // Add member to 'groupmembers' top-level collection
            await _firestore.collection('groupmembers').add({
              'groupId': groupId,
              'userId': user.uid,
              'role': 'member',
              'createdAt': FieldValue.serverTimestamp(),
            });

            return groupId;
          } else {
            print('User is already a member of this group.');
            return null;
          }
        } else {
          print('No group found with that code.');
        }
      }
    } catch (e) {
      print('Error joining group: $e');
    }
    return null;
  }

  // Add expense to top-level 'expenses' collection
  Future<String?> addExpense({
    required String title,
    required String groupId,
    required String amount,
    required String paidBy,
    String? description,
  }) async {
    try {
      User? user = _auth.currentUser;

      if (user != null) {
        DocumentReference expenseRef = _firestore.collection('expenses').doc();

        await expenseRef.set({
          'expenseId': expenseRef.id,
          'groupId': groupId, // associate with group
          'expenseTitle': title,
          'expenseAmount': double.tryParse(amount) ?? 0.0,
          'expensePaidBy': paidBy,
          'expenseDescription': description ?? '',
          'createdBy': user.uid,
          'status': 'Pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        return expenseRef.id;
      }
    } catch (e) {
      print('Error creating expense: $e');
    }
    return null;
  }

  // Add TODO list to top-level 'TODO' collection
  Future<String?> addTODOList({
    required String title,
    required String groupId,
    required DateTime? dueDate, // Make this nullable DateTime
    required String description,
    required String createdBy,
  }) async {
    try {
      DocumentReference todoRef = _firestore.collection('TODO').doc();

      Map<String, dynamic> todoData = {
        'todoId': todoRef.id,
        'groupId': groupId, // associate with group
        'todoTitle': title,
        'status': 'Pending',
        'description': description,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (dueDate != null) {
        todoData['dueDate'] = Timestamp.fromDate(dueDate);
      }

      await todoRef.set(todoData);

      return todoRef.id;
    } catch (e) {
      print('Error creating TODO list: $e');
      return null;
    }
  }

  // Delete group and all related documents in top-level collections
  Future<void> deleteGroupWithSubcollections(String groupId) async {
    try {
      final groupRef = _firestore.collection('groups').doc(groupId);

      // Delete groupmembers where groupId == groupId
      final membersSnapshot =
          await _firestore
              .collection('groupmembers')
              .where('groupId', isEqualTo: groupId)
              .get();
      for (final doc in membersSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete expenses where groupId == groupId
      final expensesSnapshot =
          await _firestore
              .collection('expenses')
              .where('groupId', isEqualTo: groupId)
              .get();
      for (final doc in expensesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete TODOs where groupId == groupId
      final todoSnapshot =
          await _firestore
              .collection('TODO')
              .where('groupId', isEqualTo: groupId)
              .get();
      for (final doc in todoSnapshot.docs) {
        await doc.reference.delete();
      }

      final groupNotificationSnapshot =
          await _firestore
              .collection('groupnotifications')
              .where('groupId', isEqualTo: groupId)
              .get();
      for (final doc in groupNotificationSnapshot.docs) {
        await doc.reference.delete();
      }

      await groupRef.delete();
      print("Group and all its related documents deleted.");
    } catch (e) {
      print("Error deleting group: $e");
    }
  }

  String _generateGroupCode({int length = 6}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(
      length,
      (index) => chars[rand.nextInt(chars.length)],
    ).join();
  }
}
