import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InviteScreen extends StatefulWidget {
  final String groupId;
  final String currentUserId;

  const InviteScreen({
    super.key,
    required this.groupId,
    required this.currentUserId,
  });

  @override
  _InviteScreenState createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, bool> invitedUserMap = {}; // invitedUserId -> true if pending

  @override
  void initState() {
    super.initState();
    fetchPendingInvites();
  }

  Future<void> fetchPendingInvites() async {
    final pending =
        await FirebaseFirestore.instance
            .collection('groupInvitations')
            .where('groupId', isEqualTo: widget.groupId)
            .where('status', isEqualTo: 'pending')
            .get();

    setState(() {
      invitedUserMap = {
        for (var doc in pending.docs) doc['invitedUserId']: true,
      };
    });
  }

  Future<void> sendInvite(String userId) async {
    await FirebaseFirestore.instance.collection('groupInvitations').add({
      'groupId': widget.groupId,
      'invitedUserId': userId,
      'invitedBy': widget.currentUserId,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await fetchPendingInvites();
  }

  Future<void> cancelInvite(String userId) async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('groupInvitations')
            .where('groupId', isEqualTo: widget.groupId)
            .where('invitedUserId', isEqualTo: userId)
            .where('status', isEqualTo: 'pending')
            .get();

    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }

    await fetchPendingInvites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Invite to Group")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by email',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Expanded(child: _buildUserList()),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final users =
            snapshot.data!.docs
                .where((doc) => doc.id != widget.currentUserId)
                .toList();

        // Sort: invited users first
        users.sort((a, b) {
          final aInvited = invitedUserMap[a.id] ?? false;
          final bInvited = invitedUserMap[b.id] ?? false;
          if (aInvited && !bInvited) return -1;
          if (!aInvited && bInvited) return 1;
          return 0;
        });

        // Filter by search
        final filteredUsers =
            users.where((doc) {
              final email = doc['email'] ?? '';
              return email.toLowerCase().contains(
                _searchController.text.toLowerCase(),
              );
            }).toList();

        if (filteredUsers.isEmpty) return const Text('No users found.');

        return ListView.builder(
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final user = filteredUsers[index];
            final userId = user.id;
            final email = user['email'] ?? '';
            final name = user['name'] ?? 'No Name';
            final isInvited = invitedUserMap[userId] ?? false;

            return ListTile(
              title: Text(name),
              subtitle: Text(email),
              trailing: ElevatedButton(
                onPressed: () {
                  isInvited ? cancelInvite(userId) : sendInvite(userId);
                },
                child: Text(isInvited ? "Cancel" : "Invite"),
              ),
            );
          },
        );
      },
    );
  }
}
