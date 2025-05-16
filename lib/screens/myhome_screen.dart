import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:costmate/screens/main_screen.dart';
import 'package:costmate/validation/validation_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MyHomeScreen extends StatefulWidget {
  const MyHomeScreen({
    super.key,
    required this.onUpdateAppBar,
    required this.onGroupTap,
  });

  final Function(AppBar) onUpdateAppBar;
  final void Function(Map<String, dynamic> group) onGroupTap;

  @override
  State<MyHomeScreen> createState() => _MyHomeScreenState();
}

class _MyHomeScreenState extends State<MyHomeScreen> {
  final TextEditingController groupCodeController = TextEditingController();
  final TextEditingController groupNameController = TextEditingController();
  late Future<List<Map<String, dynamic>>> userGroupsFuture;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
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

    userGroupsFuture = _fetchUserGroups();
  }

  Future<List<Map<String, dynamic>>> _fetchUserGroups() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final List<Map<String, dynamic>> groups = [];
    final firestore = FirebaseFirestore.instance;

    // Fetch groups created by the user
    final created =
        await firestore
            .collection('groups')
            .where('createdBy', isEqualTo: user.uid)
            .get();

    for (var doc in created.docs) {
      final data = doc.data();

      // Count members in groupmembers collection where groupId == doc.id
      final memberCountSnap =
          await firestore
              .collection('groupmembers')
              .where('groupId', isEqualTo: doc.id)
              .get();

      groups.add({
        'groupId': doc.id,
        'groupName': data['groupName'] ?? 'Unnamed',
        'isAdmin': true,
        'adminName': 'You',
        'memberCount': memberCountSnap.size,
        'role': 'Admin',
      });
    }

    // Find groups where the user is a member (search in top-level groupmembers)
    final memberGroupsSnap =
        await firestore
            .collection('groupmembers')
            .where('userId', isEqualTo: user.uid)
            .get();

    for (var memberDoc in memberGroupsSnap.docs) {
      final groupId = memberDoc['groupId'];

      // Skip groups already added (created by user)
      if (groups.any((g) => g['groupId'] == groupId)) continue;

      final groupDoc = await firestore.collection('groups').doc(groupId).get();

      if (!groupDoc.exists) continue; // Safety check

      final groupData = groupDoc.data()!;

      // Count members in this group
      final memberCountSnap =
          await firestore
              .collection('groupmembers')
              .where('groupId', isEqualTo: groupId)
              .get();

      groups.add({
        'groupId': groupId,
        'groupName': groupData['groupName'] ?? 'Unnamed',
        'isAdmin': false,
        'adminName': groupData['createdByName'] ?? 'Unknown',
        'memberCount': memberCountSnap.size,
        'role': memberDoc['role'] ?? 'Member',
      });
    }

    return groups;
  }

  void _onMenuSelected(String choice) {
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Group Created")),
                  );
                  // Navigate to MyHomeScreen and replace current screen:
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => MainScreen()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Error creating group")),
                  );
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
                Navigator.pop(context);
                final groupId = await ValidationService().joinGroup(
                  groupCode: groupCodeController.text.trim(),
                );
                if (groupId != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("Joined Group")));

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => MainScreen()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Error joining group")),
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

  void _onGroupMenuSelected(String choice, Map<String, dynamic> group) {
    setState(() {
      _selectedGroup = group;
    });

    if (choice == 'Leave Group') {
      _showLeaveGroupDialog();
    } else if (choice == 'Delete Group') {
      _showDeleteGroupDialog();
    } else if (choice == 'Edit Group') {
      _showEditGroupDialog();
    } else if (choice == 'View Group Code') {
      _showViewGroupCodeDialog();
    }
  }

  void _showLeaveGroupDialog() {
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

  void _showDeleteGroupDialog() {
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

                  setState(() {
                    userGroupsFuture =
                        _fetchUserGroups(); // refresh after deletion
                  });

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => MainScreen()),
                  );
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _showEditGroupDialog() {
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
                    _editGroup(newGroupName); // Update group name
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => MainScreen()),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _showViewGroupCodeDialog() async {
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Group code copied to clipboard'),
                          ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Group not found.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching group code: $e')));
    }
  }

  void _leaveGroup() async {
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

        if (!context.mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('You left the group.')));

        // ✅ Navigate to MainScreen after successful removal
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are not a member of this group.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error leaving group: $e')));
    }
  }

  Future<void> _deleteGroup() async {
    try {
      final groupId = _selectedGroup?['groupId'];
      if (groupId == null) return;

      await ValidationService().deleteGroupWithSubcollections(groupId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group deleted successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting group: $e')));
    }
  }

  void _editGroup(String newName) async {
    try {
      final groupId = _selectedGroup?['groupId'];
      if (groupId == null) return;

      final groupRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId);

      await groupRef.update({'groupName': newName});

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Group name updated.')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating name: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: userGroupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("You're not in any group."));
          }

          final groups = snapshot.data!;

          return SingleChildScrollView(
            child: Center(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children:
                    groups.map((group) {
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
                                    "Role: ${group['role']}",
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
                                    if (!group['isAdmin'])
                                      const PopupMenuItem<String>(
                                        value: 'Leave Group',
                                        child: Text('Leave Group'),
                                      ),
                                    if (group['isAdmin'])
                                      const PopupMenuItem<String>(
                                        value: 'Edit Group',
                                        child: Text('Edit Group'),
                                      ),
                                    if (group['isAdmin'])
                                      const PopupMenuItem<String>(
                                        value: 'Delete Group',
                                        child: Text('Delete Group'),
                                      ),
                                    if (group['isAdmin'])
                                      const PopupMenuItem<String>(
                                        value: 'View Group Code',
                                        child: Text('View Group Code'),
                                      ),
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
      ),
    );
  }
}
