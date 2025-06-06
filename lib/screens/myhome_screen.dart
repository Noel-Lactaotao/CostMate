import 'package:another_flushbar/flushbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:costmate/providers/user_and_group_providers.dart';
import 'package:costmate/screens/invite_screen.dart';
import 'package:costmate/validation/validation_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyHomeScreen extends ConsumerStatefulWidget {
  const MyHomeScreen({
    super.key,
    required this.onUpdateAppBar,
    required this.onGroupTap,
  });

  final Function(AppBar) onUpdateAppBar;
  final void Function(Map<String, dynamic> group) onGroupTap;

  @override
  ConsumerState<MyHomeScreen> createState() => _MyHomeScreenState();
}

class _MyHomeScreenState extends ConsumerState<MyHomeScreen> {
  final TextEditingController groupCodeController = TextEditingController();
  final TextEditingController groupNameController = TextEditingController();
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final userId = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? _selectedGroup;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onUpdateAppBar(
        AppBar(
          title: const Text(
            "CostMate",
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
          centerTitle: true,
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.add),
              onSelected: _onMenuSelected,
              itemBuilder: (BuildContext context) {
                return ['Create Group', 'Join Group'].map((String choice) {
                  return PopupMenuItem<String>(
                    value: choice,
                    child: Text(choice),
                  );
                }).toList();
              },
            ),
          ],
        ),
      );
    });
  }

  void showSuccessFlushbar(BuildContext context, String message) {
    Flushbar(
      message: message,
      // icon: const Icon(Icons.check_circle, size: 28.0, color: Colors.green),
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      flushbarPosition: FlushbarPosition.TOP,
      backgroundColor: Colors.black87,
      animationDuration: const Duration(milliseconds: 500),
    ).show(context);
  }

  void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              'Error',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
    );
  }

  void _onMenuSelected(String choice) async {
    if (choice == 'Create Group') {
      _showCreateGroupDialog();
    } else if (choice == 'Join Group') {
      _showJoinGroupDialog();
    }
  }

  void _showCreateGroupDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Create Group"),
          content: TextField(
            controller: groupNameController,
            decoration: const InputDecoration(labelText: 'Group Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close the dialog first
                final groupId = await ValidationService().createGroup(
                  groupName: groupNameController.text.trim(),
                );
                if (groupId != null) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final _ = ref.refresh(userInfoProvider);
                    final _ = ref.refresh(userGroupsProvider);
                  }

                  if (!mounted) return;
                  showSuccessFlushbar(context, "Group created successfully.");
                }

                groupNameController.clear();
              },
              child: const Text("Create"),
            ),
          ],
        );
      },
    );
  }

  void _showJoinGroupDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Join Group"),
          content: TextField(
            controller: groupCodeController,
            maxLength: 6,
            inputFormatters: [LengthLimitingTextInputFormatter(6)],
            decoration: const InputDecoration(labelText: 'Group Code'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog first
                final groupId = await ValidationService().joinGroup(
                  groupCode: groupCodeController.text.trim(),
                );
                if (groupId != null) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final _ = ref.refresh(userInfoProvider);
                    final _ = ref.refresh(userGroupsProvider);
                  }

                  final firestore = FirebaseFirestore.instance;
                  final currentUser = FirebaseAuth.instance.currentUser;
                  final String userId = currentUser!.uid;
                  final timestamp = Timestamp.now();

                  final notificationGroupData = {
                    'userId': userId,
                    'groupId': groupId,
                    'type': 'message',
                    'action': 'joined the group',
                    'seenBy': [],
                    'createdAt': timestamp,
                  };

                  await firestore
                      .collection('groupnotifications')
                      .add(notificationGroupData);

                  if (!mounted) return;
                  showSuccessFlushbar(
                    context,
                    "You successfully joined the group.",
                  );
                }

                groupCodeController.clear();
              },
              child: const Text("Join"),
            ),
          ],
        );
      },
    );
  }

  void _onGroupMenuSelected(String choice, Map<String, dynamic> group) async {
    setState(() {
      _selectedGroup = group;
    });
    final groupId = group['groupId'];

    // Leave Group
    if (choice == 'Leave Group') {
      await _showLeaveGroupDialog();
    }
    // Edit Group
    else if (choice == 'Edit Group') {
      await _showEditGroupDialog();
    }
    // Delete Group
    else if (choice == 'Delete Group') {
      await _showDeleteGroupDialog();
    }
    // View Group Code (no notification needed)
    else if (choice == 'View Group Code') {
      await _showViewGroupCodeDialog();
    } else if (choice == 'Invite Member') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => InviteScreen(groupId: groupId)),
      );
    }
  }

  Future<void> _showViewGroupCodeDialog() async {
    final groupId = _selectedGroup?['groupId'];
    if (groupId == null) return;

    try {
      final groupDoc =
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(groupId)
              .get();

      if (groupDoc.exists) {
        final groupCode = groupDoc.data()?['groupCode'] ?? 'Unavailable';

        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Group Code'),
                content: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Code: $groupCode',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: groupCode));
                        if (!mounted) return;
                        showSuccessFlushbar(
                          context,
                          "Group code copied to Clipboard.",
                        );
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      } else {
        if (!mounted) return;
        showSuccessFlushbar(context, "Group not found.");
      }
    } catch (e) {
      if (!mounted) return; // widget is no longer in the widget tree
      showErrorDialog(context, "Something went wrong. Please try again later.");
    }
  }

  Future<void> _showLeaveGroupDialog() async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Leave Group'),
            content: const Text('Are you sure you want to leave this group?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), // Cancel
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _leaveGroup();
                },
                child: const Text('Leave'),
              ),
            ],
          ),
    );
  }

  Future<void> _leaveGroup() async {
    try {
      final groupId = _selectedGroup?['groupId'];
      if (groupId == null) return;

      final groupMembersRef = FirebaseFirestore.instance
          .collection('groupmembers')
          .where('groupId', isEqualTo: groupId)
          .where('userId', isEqualTo: currentUserId);

      final snapshot = await groupMembersRef.get();

      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final _ = ref.refresh(userInfoProvider);
          final _ = ref.refresh(userGroupsProvider);
        }

        if (!context.mounted) return;

        if (!mounted) return;
        showSuccessFlushbar(context, "You left the group.");

        await FirebaseFirestore.instance.collection('groupnotifications').add({
          'userId': userId,
          'groupId': groupId,
          'type': 'message',
          'action': 'left the group',
          'seenBy': [],
          'createdAt': Timestamp.now(),
        });
      } else {
        if (!mounted) return;
        showSuccessFlushbar(context, "You are not a member of the Group.");
      }
    } catch (e) {
      if (!mounted) return; // widget is no longer in the widget tree
      showErrorDialog(context, "Something went wrong. Please try again later.");
    }
  }

  Future<void> _showDeleteGroupDialog() async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Group'),
            content: const Text(
              'This action is irreversible. Delete this group?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(context);
                  await _deleteGroup();
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteGroup() async {
    try {
      final groupId = _selectedGroup?['groupId'];
      if (groupId == null) return;

      final memberSnapshot =
          await FirebaseFirestore.instance
              .collection('groupmembers')
              .where('groupId', isEqualTo: groupId)
              .get();

      final groupSnapshot =
          await FirebaseFirestore.instance
              .collection('groups')
              .where('groupId', isEqualTo: groupId)
              .get();

      String groupName = 'Unnamed Group';
      if (groupSnapshot.docs.isNotEmpty) {
        groupName = groupSnapshot.docs.first['groupName'] ?? 'Unnamed Group';
      }

      await ValidationService().deleteGroupWithSubcollections(groupId);

      for (final doc in memberSnapshot.docs) {
        final memberId = doc['userId'];

        await FirebaseFirestore.instance.collection('usernotifications').add({
          'userId': memberId,
          'groupId': groupId,
          'type': 'message',
          'action': 'The group "$groupName" has been deleted',
          'isSeen': false,
          'createdAt': Timestamp.now(),
        });
      }

      // Refresh userInfoProvider
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final _ = ref.refresh(userInfoProvider);
        final _ = ref.refresh(userGroupsProvider);
      }

      if (!mounted) return;
      showSuccessFlushbar(context, "Group deleted successfully.");

      // NO navigation here anymore
    } catch (e) {
      if (!mounted) return; // widget is no longer in the widget tree
      showErrorDialog(context, "Something went wrong. Please try again later.");
    }
  }

  Future<void> _showEditGroupDialog() async {
    final TextEditingController groupNameController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Group Name'),
            content: TextField(
              controller: groupNameController,
              decoration: const InputDecoration(
                labelText: 'Enter New Group Name',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newGroupName = groupNameController.text.trim();
                  if (newGroupName.isNotEmpty) {
                    Navigator.pop(context); // Close the dialog
                    await _editGroup(newGroupName); // Update group name
                    // NO navigation here anymore
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _editGroup(String newName) async {
    try {
      final groupId = _selectedGroup?['groupId'];
      if (groupId == null) return;

      final groupRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId);
      await groupRef.update({'groupName': newName});

      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid;
      
      if (user != null) {
        final _ = ref.refresh(userInfoProvider);
        final _ = ref.refresh(userGroupsProvider);
      }

      await FirebaseFirestore.instance.collection('groupnotifications').add({
        'userId': userId,
        'groupId': groupId,
        'type': 'message',
        'action': 'edited the group',
        'seenBy': [],
        'createdAt': Timestamp.now(),
      });

      if (!mounted) return;
      showSuccessFlushbar(context, "Group name Updated successfully.");
    } catch (e) {
      if (!mounted) return; // widget is no longer in the widget tree
      showErrorDialog(context, "Something went wrong. Please try again later.");
    }
  }

  String formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'co-admin':
        return 'Co-Admin';
      case 'member':
        return 'Member';
      default:
        return role[0].toUpperCase() + role.substring(1).toLowerCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(userGroupsProvider);

    return Padding(
      padding: const EdgeInsets.all(15),
      child: groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return const Center(child: Text("You're not in any group."));
          }

          return SingleChildScrollView(
            child: Center(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children:
                    groups.map((group) {
                      final String role =
                          (group['role'] as String).toLowerCase();
                      return GestureDetector(
                        onTap: () {
                          widget.onGroupTap({
                            'groupId': group['groupId'],
                            'groupName': group['groupName'],
                            'isAdmin': group['isAdmin'],
                          });
                        },
                        child: Stack(
                          children: [
                            Container(
                              constraints: const BoxConstraints(
                                maxWidth: 450,
                                minWidth: 0,
                              ),
                              width: MediaQuery.of(context).size.width * 0.9,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group['groupName'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Role: ${formatRole(group['role'])}",
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    "Members: ${group['memberCount']}",
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: PopupMenuButton<String>(
                                onSelected:
                                    (choice) =>
                                        _onGroupMenuSelected(choice, group),
                                itemBuilder: (BuildContext context) {
                                  return <PopupMenuEntry<String>>[
                                    if (role != 'admin')
                                      const PopupMenuItem<String>(
                                        value: 'Leave Group',
                                        child: Text('Leave Group'),
                                      ),
                                    if (role == 'admin') ...[
                                      const PopupMenuItem<String>(
                                        value: 'Edit Group',
                                        child: Text('Edit Group'),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: 'Delete Group',
                                        child: Text('Delete Group'),
                                      ),
                                    ],
                                    if (role == 'admin' ||
                                        role == 'co-admin') ...[
                                      const PopupMenuItem<String>(
                                        value: 'View Group Code',
                                        child: Text('View Group Code'),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: 'Invite Member',
                                        child: Text('Invite Member'),
                                      ),
                                    ],
                                  ];
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }
}
