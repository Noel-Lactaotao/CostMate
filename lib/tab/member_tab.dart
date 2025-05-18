import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:costmate/providers/expenses_todos_members_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MemberTab extends ConsumerStatefulWidget {
  final String groupId;

  const MemberTab({super.key, required this.groupId});

  @override
  ConsumerState<MemberTab> createState() => _MemberTabState();
}

class _MemberTabState extends ConsumerState<MemberTab> {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;

  void _onMemberMenuSelected(
    String choice,
    String selectedUserId,
    String groupId,
  ) async {
    final memberRef = FirebaseFirestore.instance
        .collection('groupmembers')
        .where('userId', isEqualTo: selectedUserId)
        .where('groupId', isEqualTo: groupId);

    try {
      final querySnapshot = await memberRef.get();

      if (querySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Member not found.')));
        return;
      }

      final docId = querySnapshot.docs.first.id;
      final docRef = FirebaseFirestore.instance
          .collection('groupmembers')
          .doc(docId);

      switch (choice) {
        case 'Promote':
          await docRef.update({'role': 'co-admin'});
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('User promoted to co-admin.')));
          break;

        case 'Demote':
          await docRef.update({'role': 'member'});
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('User demoted to member.')));
          break;

        case 'Remove':
          await docRef.delete();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('User removed from group.')));
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    final membersAsyncValue = ref.watch(membersProvider(widget.groupId));

    return membersAsyncValue.when(
      data: (membersList) {
        // Get current user's role
        final currentUserData = membersList.firstWhere(
          (m) => m['uid'] == currentUserId,
          orElse:
              () =>
                  <String, dynamic>{}, // ✅ Return an empty map instead of null
        );

        final currentUserRole = currentUserData['role'] ?? 'member';

        final admins = membersList.where((m) => m['role'] == 'admin').toList();
        final coAdmins =
            membersList.where((m) => m['role'] == 'co-admin').toList();
        final normalMembers =
            membersList
                .where((m) => m['role'] != 'admin' && m['role'] != 'co-admin')
                .toList();

        final List<Widget> listItems = [];

        if (admins.isNotEmpty) {
          listItems.add(_buildSectionHeader('Admin'));
          listItems.addAll(
            admins.map((m) => _buildMemberTile(m, isWide, currentUserRole)),
          );
        }

        if (coAdmins.isNotEmpty) {
          listItems.add(_buildSectionHeader('Co-Admin'));
          listItems.addAll(
            coAdmins.map((m) => _buildMemberTile(m, isWide, currentUserRole)),
          );
        }

        if (normalMembers.isNotEmpty) {
          listItems.add(_buildSectionHeader('Members'));
          listItems.addAll(
            normalMembers.map(
              (m) => _buildMemberTile(m, isWide, currentUserRole),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: listItems,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Expanded(
            child: Divider(thickness: 1, color: Colors.grey, endIndent: 8),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const Expanded(
            child: Divider(thickness: 1, color: Colors.grey, indent: 8),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(
    Map<String, dynamic> member,
    bool isWide,
    String currentUserRole,
  ) {
    final name = member['name'] ?? 'Unnamed';
    final email = member['email'] ?? '';
    final role = member['role'] ?? 'member';
    final memberId = member['uid'];

    final canEdit =
        (currentUserRole == 'admin' || currentUserRole == 'co-admin') &&
        role != 'admin' &&
        currentUserId != memberId;

    return Center(
      child: Container(
        width: isWide ? 600 : double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(email, style: const TextStyle(fontSize: 13)),
                ),
              ),
              if (canEdit)
                Positioned(
                  top: 0,
                  right: 0,
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected:
                        (choice) => _onMemberMenuSelected(
                          choice,
                          memberId,
                          widget.groupId,
                        ),
                    itemBuilder: (context) {
                      List<PopupMenuEntry<String>> items = [];

                      if (role == 'member') {
                        items.add(
                          const PopupMenuItem<String>(
                            value: 'Promote',
                            child: Text('Promote to Co-Admin'),
                          ),
                        );
                      }

                      if (role == 'co-admin') {
                        items.add(
                          const PopupMenuItem<String>(
                            value: 'Demote',
                            child: Text('Demote to Member'),
                          ),
                        );
                      }

                      if (role == 'member' || role == 'co-admin') {
                        items.add(
                          const PopupMenuItem<String>(
                            value: 'Remove',
                            child: Text('Remove from Group'),
                          ),
                        );
                      }

                      return items;
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
