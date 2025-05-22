import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InviteScreen extends StatefulWidget {
  final String groupId;
  final String currentUserId;

  const InviteScreen({
    Key? key,
    required this.groupId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _InviteScreenState createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final TextEditingController _emailController = TextEditingController();
  String _statusMessage = '';

  Future<void> inviteUserByEmail(String email) async {
    try {
      // Find user by email
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userSnapshot.docs.isEmpty) {
        setState(() {
          _statusMessage = 'User not found.';
        });
        return;
      }

      final invitedUserId = userSnapshot.docs.first.id;

      // Check if already invited
      final existing = await FirebaseFirestore.instance
          .collection('groupInvitations')
          .where('groupId', isEqualTo: widget.groupId)
          .where('invitedUserId', isEqualTo: invitedUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existing.docs.isNotEmpty) {
        setState(() {
          _statusMessage = 'User already invited.';
        });
        return;
      }

      // Create invitation
      await FirebaseFirestore.instance.collection('groupInvitations').add({
        'groupId': widget.groupId,
        'invitedUserId': invitedUserId,
        'invitedBy': widget.currentUserId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _statusMessage = 'Invitation sent!';
        _emailController.clear();
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Invite to Group")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'User Email',
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => inviteUserByEmail(_emailController.text.trim()),
              child: const Text("Send Invitation"),
            ),
            const SizedBox(height: 12),
            Text(_statusMessage),
            const Divider(height: 40),
            const Text("Pending Invitations", style: TextStyle(fontSize: 18)),
            Expanded(child: _buildPendingInvitesList())
          ],
        ),
      ),
    );
  }

  Widget _buildPendingInvitesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groupInvitations')
          .where('groupId', isEqualTo: widget.groupId)
          .where('invitedBy', isEqualTo: widget.currentUserId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Text('No pending invitations.');
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final invitedUserId = doc['invitedUserId'];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(invitedUserId).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) return const ListTile(title: Text("Loading..."));
                final userEmail = userSnap.data!['email'] ?? 'Unknown';

                return ListTile(
                  title: Text(userEmail),
                  subtitle: Text("Invitation Pending"),
                );
              },
            );
          },
        );
      },
    );
  }
}
