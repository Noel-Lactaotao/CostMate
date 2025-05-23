import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InviteScreen extends StatefulWidget {
  final String groupId;

  const InviteScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  final TextEditingController _searchController = TextEditingController();

  // Stream for pending invited user IDs
  Stream<List<String>> _pendingInvitedUserIdsStream() {
    return FirebaseFirestore.instance
        .collection('groupInvitations')
        .where('groupId', isEqualTo: widget.groupId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => doc['invitedUserId'] as String)
                  .toList(),
        );
  }

  // Stream for current group members
  Stream<Set<String>> _groupMemberIdsStream() {
    return FirebaseFirestore.instance
        .collection('groupmembers')
        .where('groupId', isEqualTo: widget.groupId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => doc['userId'] as String).toSet(),
        );
  }

  void _sendInvite(String invitedUserId) async {
    await FirebaseFirestore.instance.collection('groupInvitations').add({
      'groupId': widget.groupId,
      'invitedUserId': invitedUserId,
      'inviterUserId': userId,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _cancelInvite(String invitedUserId) async {
    final invites =
        await FirebaseFirestore.instance
            .collection('groupInvitations')
            .where('groupId', isEqualTo: widget.groupId)
            .where('invitedUserId', isEqualTo: invitedUserId)
            .where('status', isEqualTo: 'pending')
            .get();

    for (var doc in invites.docs) {
      await doc.reference.delete();
    }
  }

  Widget _buildUserTile(DocumentSnapshot userDoc, bool isInvited) {
    final email = userDoc['email'] ?? 'No email';
    final userId = userDoc.id;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListTile(
          title: Text(
            email,
            style: const TextStyle(fontSize: 13, color: Colors.black),
          ),
          trailing:
              isInvited
                  ? ElevatedButton(
                    onPressed: () => _cancelInvite(userId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                  : ElevatedButton(
                    onPressed: () => _sendInvite(userId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Invite',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<List<String>>(
      stream: _pendingInvitedUserIdsStream(),
      builder: (context, invitedSnapshot) {
        if (!invitedSnapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final invitedUserIds = invitedSnapshot.data!;

        return StreamBuilder<Set<String>>(
          stream: _groupMemberIdsStream(),
          builder: (context, membersSnapshot) {
            if (!membersSnapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final groupMemberIds = membersSnapshot.data!;

            return StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, usersSnapshot) {
                if (!usersSnapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final allUsers =
                    usersSnapshot.data!.docs
                        .where(
                          (doc) =>
                              doc.id != userId &&
                              !groupMemberIds.contains(doc.id),
                        )
                        .toList();

                final invitedUsers =
                    allUsers
                        .where((doc) => invitedUserIds.contains(doc.id))
                        .toList();
                final notInvitedUsers =
                    allUsers
                        .where((doc) => !invitedUserIds.contains(doc.id))
                        .toList();

                // Filter not-invited users by search query
                final searchQuery = _searchController.text.toLowerCase();
                final filteredNotInvited =
                    notInvitedUsers.where((doc) {
                      final email = (doc['email'] ?? '').toLowerCase();
                      return email.contains(searchQuery);
                    }).toList();

                final totalItems =
                    invitedUsers.length +
                    (filteredNotInvited.isNotEmpty
                        ? filteredNotInvited.length + 1
                        : 0);

                if (invitedUsers.isEmpty && filteredNotInvited.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('No users found.')),
                  );
                }

                return ListView.builder(
                  itemCount: totalItems,
                  itemBuilder: (context, index) {
                    if (index < invitedUsers.length) {
                      return _buildUserTile(invitedUsers[index], true);
                    } else if (index == invitedUsers.length) {
                      return const Divider(
                        thickness: 1.5,
                        height: 32,
                        color: Colors.grey,
                      );
                    } else {
                      return _buildUserTile(
                        filteredNotInvited[index - invitedUsers.length - 1],
                        false,
                      );
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Invite Members",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, minWidth: 0),
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _searchController,
                  onChanged:
                      (_) => setState(() {}), // Trigger rebuild on search input
                  decoration: InputDecoration(
                    hintText: 'Search by email...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              Expanded(child: _buildUserList()),
            ],
          ),
        ),
      ),
    );
  }
}
