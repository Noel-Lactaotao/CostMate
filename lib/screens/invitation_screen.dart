import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

class InvitationScreen extends ConsumerStatefulWidget {
  const InvitationScreen({
    super.key,
    required this.onUpdateAppBar,
    required this.onGroupTap,
  });

  final Function(AppBar) onUpdateAppBar;
  final void Function(Map<String, dynamic> group) onGroupTap;

  @override
  ConsumerState<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends ConsumerState<InvitationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateAppBar(); // 📌 Initial app bar setup
    });
  }

  void updateAppBar() {
    widget.onUpdateAppBar(
      AppBar(
        title: const Text(
          " User Invitation",
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _getInvitations(String userId) {
    return FirebaseFirestore.instance
        .collection('groupInvitations')
        .where('invitedUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
          final results = <Map<String, dynamic>>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final groupId = data['groupId'];
            final inviterUserId = data['inviterUserId'];

            final groupDoc =
                await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(groupId)
                    .get();

            final inviterDoc =
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(inviterUserId)
                    .get();

            results.add({
              'inviteId': doc.id,
              'groupId': groupId,
              'groupName': groupDoc.data()?['groupName'] ?? 'Unknown Group',
              'inviterUserId': inviterUserId,
              'inviterName': inviterDoc.data()?['name'] ?? 'Someone',
              'timestamp': data['timestamp'],
            });
          }

          return results;
        });
  }

  Future<void> _handleAccept(Map<String, dynamic> invite) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final inviteId = invite['inviteId'];
    final groupId = invite['groupId'];

    try {
      // Add user to groupMembers collection
      await FirebaseFirestore.instance.collection('groupmembers').add({
        'groupId': groupId,
        'userId': userId,
        'role': 'member',
        'createdAt':
            FieldValue.serverTimestamp(), // ✅ adds the current server time
      });

      // Delete the invitation
      await FirebaseFirestore.instance
          .collection('groupInvitations')
          .doc(inviteId)
          .delete();

      await FirebaseFirestore.instance.collection('groupnotifications').add({
          'userId': userId,
          'groupId': groupId,
          'type': 'message',
          'action': 'joined the group',
          'createdAt': Timestamp.now(),
        });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have joined the group.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to accept invite: $e')));
    }
  }

  Future<void> _handleDeny(String inviteId) async {
    try {
      await FirebaseFirestore.instance
          .collection('groupInvitations')
          .doc(inviteId)
          .delete();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitation declined.')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to decline invite: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('You must be logged in to view invitations.')),
      );
    }

    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getInvitations(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final invitations = snapshot.data ?? [];

          if (invitations.isEmpty) {
            return const Center(child: Text('No invitations at the moment.'));
          }

          return ListView.builder(
            itemCount: invitations.length,
            itemBuilder: (context, index) {
              final invite = invitations[index];
              final sentTime = invite['timestamp']?.toDate();
              final timeAgo =
                  sentTime != null ? timeago.format(sentTime) : 'some time ago';

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500, minWidth: 0),
                    width: MediaQuery.of(context).size.width * 1,
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${invite['inviterName']} invites you to join ${invite['groupName']}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Sent $timeAgo',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _handleDeny(invite['inviteId']),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Deny'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _handleAccept(invite),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Accept'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
