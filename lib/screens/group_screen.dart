import 'package:another_flushbar/flushbar.dart';
import 'package:costmate/providers/user_and_group_providers.dart';
import 'package:costmate/screens/groupnotification_screen.dart';
import 'package:costmate/screens/invite_screen.dart';
import 'package:costmate/screens/main_screen.dart';
import 'package:costmate/tab/expense_tab.dart';
import 'package:costmate/tab/member_tab.dart';
import 'package:costmate/tab/todo_tab.dart';
import 'package:costmate/validation/validation_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupScreen extends ConsumerStatefulWidget {
  final Function(AppBar) onUpdateAppBar;
  final String? groupId;
  final String? groupName;
  final bool? isAdmin;

  const GroupScreen({
    super.key,
    required this.onUpdateAppBar,
    this.groupId,
    this.groupName,
    this.isAdmin,
  });

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  int _selectedIndex = 0;
  late String groupId = widget.groupId!;
  late String groupName = widget.groupName!;
  late bool isAdmin = widget.isAdmin!;
  final expenseTitleController = TextEditingController();
  final expenseDescriptionController = TextEditingController();
  final expenseAmountController = TextEditingController();
  final todoTitleController = TextEditingController();
  final todoDescriptionController = TextEditingController();
  DateTime? selectedDueDate;

  String? selectedPaidBy;
  File? selectedProofImage;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final user = FirebaseAuth.instance.currentUser;
  late String currentRole = 'member';
  bool isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    groupId = widget.groupId ?? '';
    getUserRole(groupId);
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

  Future<void> getUserRole(String groupId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final query =
          await FirebaseFirestore.instance
              .collection('groupmembers')
              .where('groupId', isEqualTo: groupId)
              .where('userId', isEqualTo: userId)
              .limit(1)
              .get();

      if (query.docs.isNotEmpty) {
        setState(() {
          currentRole =
              (query.docs.first.data()['role'] as String?)?.toLowerCase() ??
              'member';
          isLoadingRole = false;
        });
      } else {
        setState(() {
          currentRole = 'member';
          isLoadingRole = false;
        });
      }
      updateAppBar(); // ← Now update after the role is set
    } catch (e) {
      if (!mounted) return; // widget is no longer in the widget tree
      showErrorDialog(context, "Something went wrong. Please try again later.");
    }
  }

  void updateAppBar() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    widget.onUpdateAppBar(
      AppBar(
        title: Text(
          groupName,
          style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        centerTitle: true,
        actions: [
          // ✅ StreamBuilder for notifications
          StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('groupnotifications')
                    .where('groupId', isEqualTo: groupId)
                    .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final unseenCount =
                  docs.where((doc) {
                    final seenBy = List<String>.from(doc['seenBy'] ?? []);
                    return !seenBy.contains(userId);
                  }).length;

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  GroupNotificationScreen(groupId: groupId),
                        ),
                      );
                    },
                  ),
                  if (unseenCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unseenCount > 99 ? '99+' : '$unseenCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          // ⚙️ PopupMenuButton
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (choice) => _onMenuSelected(choice, groupId),
            itemBuilder: (context) {
              return [
                const PopupMenuItem(
                  value: 'Add Expense',
                  child: Text('Add Expense'),
                ),
                const PopupMenuItem(value: 'Add TODO', child: Text('Add TODO')),
                if (currentRole != 'admin')
                  const PopupMenuItem(
                    value: 'Leave Group',
                    child: Text('Leave Group'),
                  ),
                if (currentRole == 'admin')
                  const PopupMenuItem(
                    value: 'Edit Group',
                    child: Text('Edit Group'),
                  ),
                if (currentRole == 'admin')
                  const PopupMenuItem(
                    value: 'Delete Group',
                    child: Text('Delete Group'),
                  ),
                if (currentRole == 'admin' || currentRole == 'co-admin') ...[
                  const PopupMenuItem(
                    value: 'View Group Code',
                    child: Text('View Group Code'),
                  ),
                  const PopupMenuItem(
                    value: 'Invite Member',
                    child: Text('Invite Member'),
                  ),
                ],
              ];
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    expenseTitleController.dispose();
    expenseDescriptionController.dispose();
    expenseAmountController.dispose();
    todoTitleController.dispose();
    todoDescriptionController.dispose();
    super.dispose();
  }

  void _onMenuSelected(String choice, String groupId) async {
    final firestore = FirebaseFirestore.instance;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final String userId = currentUser.uid;
    final timestamp = Timestamp.now();

    switch (choice) {
      case 'Add Expense':
        _showAddExpense(groupId);

        await firestore.collection('groupnotifications').add({
          'userId': userId,
          'groupId': groupId,
          'type': 'message',
          'action': 'added an expense to the group',
          'seenBy': [],
          'createdAt': timestamp,
        });
        break;

      case 'Add TODO':
        _showAddTODOList();

        await firestore.collection('groupnotifications').add({
          'userId': userId,
          'groupId': groupId,
          'type': 'message',
          'action': 'added a TODO item to the group',
          'seenBy': [],
          'createdAt': timestamp,
        });
        break;

      case 'Leave Group':
        _showLeaveGroupDialog();

        await firestore.collection('groupnotifications').add({
          'userId': userId,
          'groupId': groupId,
          'type': 'message',
          'action': 'left the group',
          'seenBy': [],
          'createdAt': timestamp,
        });
        break;

      case 'Edit Group':
        _showEditGroupDialog();

        await FirebaseFirestore.instance.collection('groupnotifications').add({
          'userId': user?.uid,
          'groupId': groupId,
          'type': 'message',
          'action': 'edited the group name',
          'seenBy': [],
          'createdAt': Timestamp.now(),
        });
        break;

      case 'Delete Group':
        _showDeleteGroupDialog();

        final memberSnapshot =
            await firestore
                .collection('groupmembers')
                .where('groupId', isEqualTo: groupId)
                .get();

        for (final doc in memberSnapshot.docs) {
          final memberId = doc['userId'];

          await firestore.collection('usernotifications').add({
            'userId': memberId,
            'groupId': groupId,
            'type': 'message',
            'action': 'The group "$groupName" has been deleted',
            'isSeen': false,
            'createdAt': timestamp,
          });
        }

        break;

      case 'Invite Member':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InviteScreen(groupId: this.groupId),
          ),
        );
        break;

      case 'View Group Code':
        _showViewGroupCodeDialog();
        break;
    }
  }

  Future<void> _showAddExpense(String groupId) async {
    List<String> memberList = [];
    String? currentUserEmail = user?.email;

    try {
      // Query top-level 'groupmembers' collection where groupId == current groupId
      final groupMembersSnapshot =
          await FirebaseFirestore.instance
              .collection('groupmembers')
              .where('groupId', isEqualTo: groupId)
              .get();

      for (var doc in groupMembersSnapshot.docs) {
        final userId = doc['userId'] as String;
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          if (userData != null && userData.containsKey('email')) {
            memberList.add(userData['email']);
          }
        }
      }
    } catch (e) {
      if (!mounted) return; // widget is no longer in the widget tree
      showErrorDialog(context, "Something went wrong. Please try again later.");
    }

    if (currentUserEmail != null) {
      memberList.remove(currentUserEmail);
      memberList.insert(0, currentUserEmail);
    }

    String? selectedPaidBy = currentUserEmail;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Add Expense"),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 10),
                        TextFormField(
                          controller: expenseTitleController,
                          decoration: InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: expenseAmountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: selectedPaidBy,
                          items:
                              memberList
                                  .map(
                                    (email) => DropdownMenuItem(
                                      value: email,
                                      child: Text(
                                        email,
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedPaidBy = value;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Paid By',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: expenseDescriptionController,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          decoration: const InputDecoration(
                            labelText: 'Description (optional)',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    expenseTitleController.clear();
                    expenseDescriptionController.clear();
                    expenseAmountController.clear();
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    final title = expenseTitleController.text.trim();
                    final amountText = expenseAmountController.text.trim();
                    final description =
                        expenseDescriptionController.text.trim();
                    // Pass values explicitly to addExpense
                    addExpense(
                      groupId: groupId,
                      title: title,
                      amountText: amountText,
                      description: description,
                      paidByUser: selectedPaidBy,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddTODOList() async {
    final todoTitleController = TextEditingController();
    final todoDescriptionController = TextEditingController();
    DateTime? selectedDueDate;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Add TODO"),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: todoTitleController,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                selectedDueDate = pickedDate;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedDueDate != null
                                      ? 'Due: ${selectedDueDate!.toLocal().toString().split(' ')[0]}'
                                      : 'Select Due Date',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const Icon(Icons.calendar_today, size: 16),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: todoDescriptionController,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          decoration: const InputDecoration(
                            labelText: 'Description (optional)',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    todoTitleController.clear();
                    todoDescriptionController.clear();
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    final title = todoTitleController.text.trim();
                    final description = todoDescriptionController.text.trim();

                    // Pass selectedDueDate directly (it's already DateTime?)
                    addTODOList(
                      title: title,
                      description: description,
                      dueDate: selectedDueDate,
                    );

                    Navigator.pop(context);
                  },
                  child: const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
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

  void _leaveGroup() async {
    try {
      final groupId = this.groupId;

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

        if (!mounted) return;
        showSuccessFlushbar(context, "You Left the Group");

        // Navigate to MainScreen after leaving
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else {
        if (!mounted) return;
        showSuccessFlushbar(context, "You are not a member of the Group");
      }
    } catch (e) {
      if (!mounted) return; // widget is no longer in the widget tree
      showErrorDialog(context, "Something went wrong. Please try again later.");
    }
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
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteGroup() async {
    try {
      // final groupId = _selectedGroup?['groupId'];
      final groupId = this.groupId;

      await ValidationService().deleteGroupWithSubcollections(groupId);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final _ = ref.refresh(userInfoProvider);
        final _ = ref.refresh(userGroupsProvider);
      }

      if (!mounted) return;
      showSuccessFlushbar(context, "Group deleted successfully.");

      // Navigate to MainScreen after deleting
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } catch (e) {
      if (!mounted) return; // widget is no longer in the widget tree
      showErrorDialog(context, "Something went wrong. Please try again later.");
    }
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
                    await _editGroup(newGroupName); // Update group name
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
      final groupId = this.groupId;

      await getUserRole(groupId);

      final groupRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId);
      await groupRef.update({'groupName': newName});

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final _ = ref.refresh(userInfoProvider);
        final _ = ref.refresh(userGroupsProvider);
      }

      widget.onUpdateAppBar(
        AppBar(
          title: Text(
            newName,
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.notifications),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => GroupNotificationScreen(
                          groupId: groupId, // <-- pass actual group ID here
                        ),
                  ),
                );
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (choice) => _onMenuSelected(choice, groupId),
              itemBuilder: (context) {
                return [
                  const PopupMenuItem(
                    value: 'Add Expense',
                    child: Text('Add Expense'),
                  ),
                  const PopupMenuItem(
                    value: 'Add TODO',
                    child: Text('Add TODO'),
                  ),
                  if (currentRole != 'admin')
                    const PopupMenuItem(
                      value: 'Leave Group',
                      child: Text('Leave Group'),
                    ),
                  if (currentRole == 'admin')
                    const PopupMenuItem(
                      value: 'Edit Group',
                      child: Text('Edit Group'),
                    ),
                  if (currentRole == 'admin')
                    const PopupMenuItem(
                      value: 'Delete Group',
                      child: Text('Delete Group'),
                    ),
                  if (currentRole == 'admin' || currentRole == 'co-admin') ...[
                    const PopupMenuItem(
                      value: 'View Group Code',
                      child: Text('View Group Code'),
                    ),
                    const PopupMenuItem(
                      value: 'Invite Member',
                      child: Text('Invite Member'),
                    ),
                  ],
                ];
              },
            ),
          ],
        ),
      );
      if (!mounted) return;
      showSuccessFlushbar(context, "Group name Updated successfully.");
    } catch (e) {
      if (!mounted) return; // widget is no longer in the widget tree
      showErrorDialog(context, "Something went wrong. Please try again later.");
    }
  }

  void _showViewGroupCodeDialog() async {
    final groupId = widget.groupId;

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

  void addExpense({
    required String groupId,
    required String title,
    required String amountText,
    required String description,
    String? paidByUser,
  }) async {
    if (title.isEmpty || amountText.isEmpty || paidByUser == null) {
      showSuccessFlushbar(context, "Please fill in all requied fields.");
      return;
    }

    double? amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      showSuccessFlushbar(context, "Please enter a valid amount.");
      return;
    }

    try {
      final expenseId = await ValidationService().addExpense(
        title: title,
        groupId: groupId,
        amount: amount.toString(),
        paidBy: paidByUser,
        description: description,
      );

      if (expenseId != null) {
        if (!mounted) return;
        showSuccessFlushbar(context, "Expense added successfully.");

        // Clear input fields after success
        expenseTitleController.clear();
        expenseDescriptionController.clear();
        expenseAmountController.clear();

        // No need to call _fetchExpenses(); Riverpod stream will auto-update
      } else {
        if (!mounted) return; // widget is no longer in the widget tree
        showErrorDialog(
          context,
          "Something went wrong. Please try again later.",
        );
      }
    } catch (e) {
      if (!mounted) return; // widget is no longer in the widget tree
      showErrorDialog(context, "Something went wrong. Please try again later.");
    }
  }

  Future<void> addTODOList({
    required String title,
    required String description,
    required DateTime? dueDate,
  }) async {
    final groupId = this.groupId;
    final createdBy = user?.uid;

    if (title.isEmpty || createdBy == null) {
      showSuccessFlushbar(context, "Please fill in the title.");
      return;
    }

    try {
      final todoId = await ValidationService().addTODOList(
        title: title,
        groupId: groupId,
        dueDate: dueDate,
        description: description,
        createdBy: createdBy,
      );

      if (todoId != null) {
        if (!mounted) return;
        showSuccessFlushbar(context, "TODO added successfully.");
      } else {
        if (!mounted) return; // widget is no longer in the widget tree
        showErrorDialog(
          context,
          "Something went wrong. Please try again later.",
        );
      }
    } catch (e) {
      if (!mounted) return; // widget is no longer in the widget tree
      showErrorDialog(context, "Something went wrong. Please try again later.");
    }
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    switch (_selectedIndex) {
      case 0:
        body = ExpensesTab(groupId: groupId);
        break;
      case 1:
        body = TodoTab(groupId: groupId);
        break;
      case 2:
        body = MemberTab(groupId: groupId); // ✅ pass members here
        break;
      default:
        body = Center(child: Text('Invalid Tab'));
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTapped,
        selectedItemColor: Colors.blue, // Color of the selected item
        unselectedItemColor: Colors.grey, // Color of the unselected items
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'TODO'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Members'),
        ],
      ),
    );
  }
}
