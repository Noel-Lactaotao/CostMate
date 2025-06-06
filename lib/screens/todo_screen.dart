import 'package:another_flushbar/flushbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:costmate/providers/expenses_todos_members_providers.dart';
import 'package:costmate/validation/validation_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class TodoScreen extends ConsumerStatefulWidget {
  final String todoId;

  const TodoScreen({super.key, required this.todoId});

  @override
  ConsumerState<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends ConsumerState<TodoScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final expenseTitleController = TextEditingController();
  final expenseDescriptionController = TextEditingController();
  final expenseAmountController = TextEditingController();

  String? selectedPaidBy;

  @override
  void initState() {
    super.initState();
  }

  void showSuccessFlushbar(BuildContext context, String message) {
    Flushbar(
      message: message,
      // icon: const Icon(Icons.check_circle, size: 28.0, color: Colors.green),
      duration: const Duration(seconds: 2),
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

  Future<String> getUserRole(String groupId, String userId) async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('groupmembers')
              .where('groupId', isEqualTo: groupId)
              .where('userId', isEqualTo: userId)
              .limit(1)
              .get();

      if (querySnapshot.docs.isEmpty) return 'none';

      final data = querySnapshot.docs.first.data();
      return data['role'] ?? 'none';
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return 'none';
    }
  }

  void _onMenuSelected(
    String choice,
    Map<String, dynamic> todoData,
    String todoId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    final groupId = todoData['groupId'];

    if (user == null || groupId == null) return;

    switch (choice) {
      case 'Edit Todo':
        _showEditTodoDialog(
          todoId: todoId,
          groupId: todoData['groupId'],
          currentTitle: todoData['todoTitle'],
          currentDueDate: todoData['dueDate'], // Firestore Timestamp
          currentDescription: todoData['description'] ?? '',
        );
        break;

      case 'Delete Todo':
        _showDeleteTODODialog(
          todoId: todoId,
          title: todoData['todoTitle'] ?? 'Untitled',
        );
        break;
    }
  }

  Future<String> getUserEmail(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return doc.data()?['email'] ?? 'Unknown email';
    } catch (e) {
      return 'Error fetching email';
    }
  }

  Future<void> updateTODO({
    required String todoId,
    required String title,
    required DateTime? dueDate, // Nullable
    required String description,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    final todoSnapshot =
        await FirebaseFirestore.instance
            .collection('TODO')
            .where('todoId', isEqualTo: todoId)
            .get();

    String todoTitle = 'None';
    String groupId = 'None';
    if (todoSnapshot.docs.isNotEmpty) {
      todoTitle = todoSnapshot.docs.first['todoTitle'] ?? 'None';
      groupId = todoSnapshot.docs.first['groupId'] ?? 'None';
    }
    try {
      final docRef = FirebaseFirestore.instance.collection('TODO').doc(todoId);

      final data = {
        'todoTitle': title,
        'description': description,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (dueDate != null) {
        data['dueDate'] = Timestamp.fromDate(dueDate);
      } else {
        data['dueDate'] = FieldValue.delete(); // Remove from Firestore
      }

      await docRef.update(data);

      if (!mounted) return;
      Navigator.pop(context);

      // Send edit notification
      await FirebaseFirestore.instance.collection('groupnotifications').add({
        'action': 'edited a TODO: $todoTitle',
        'userId': user?.uid,
        'type': 'message',
        'seenBy': [],
        'groupId': groupId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      showSuccessFlushbar(context, "TODO updated successfully.");
    } catch (e) {
      if (!mounted) return; // widget is no longer in the widget tree
      showErrorDialog(context, "Something went wrong. Please try again later.");
    }
  }

  Future<void> markTodoCompleted(String id) async {
    await FirebaseFirestore.instance.collection('TODO').doc(id).update({
      'status': 'Completed',
    });
  }

  void _showEditTodoDialog({
    required String todoId,
    required String groupId,
    required String currentTitle,
    required Timestamp? currentDueDate, // ⬅️ Firestore Timestamp
    required String currentDescription,
  }) async {
    List<String> memberList = [];
    String? currentUserEmail = user?.email;

    final TextEditingController todoTitleController = TextEditingController(
      text: currentTitle,
    );
    final TextEditingController todoDescriptionController =
        TextEditingController(text: currentDescription);

    // Convert Firestore Timestamp to DateTime
    DateTime? selectedDueDate = currentDueDate?.toDate();

    if (currentUserEmail != null) {
      memberList.remove(currentUserEmail);
      memberList.insert(0, currentUserEmail);
    }

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Edit TODO'),
                  content: SingleChildScrollView(
                    child: Column(
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
                              initialDate: selectedDueDate ?? DateTime.now(),
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
                                      ? 'Due: ${selectedDueDate?.toLocal().toString().split(' ')[0]}'
                                      : 'No Due Date',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16),
                                    if (selectedDueDate != null)
                                      IconButton(
                                        icon: Icon(Icons.clear),
                                        onPressed: () {
                                          setState(() {
                                            selectedDueDate = null;
                                          });
                                        },
                                      ),
                                  ],
                                ),
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
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final title = todoTitleController.text.trim();
                        final description =
                            todoDescriptionController.text.trim();

                        await updateTODO(
                          todoId: todoId,
                          title: title,
                          dueDate: selectedDueDate, // Pass DateTime
                          description: description,
                        );
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _showDeleteTODODialog({
    required String todoId,
    required String title,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false, // prevent accidental dismiss
      builder:
          (dialogContext) => AlertDialog(
            title: Text('Delete "$title"?'),
            content: const Text('Are you sure you want to delete this TODO?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  final userId = user?.uid;

                  final todoSnapshot =
                      await FirebaseFirestore.instance
                          .collection('TODO')
                          .where('todoId', isEqualTo: todoId)
                          .get();

                  String todoTitle = 'None';
                  String groupId = 'None';

                  if (todoSnapshot.docs.isNotEmpty) {
                    final doc = todoSnapshot.docs.first;
                    todoTitle = doc['todoTitle'] ?? 'None';
                    groupId = doc['groupId'] ?? 'None';
                  }

                  await FirebaseFirestore.instance
                      .collection('TODO')
                      .doc(todoId)
                      .delete();

                  // First pop the dialog
                  Navigator.pop(context);

                  await FirebaseFirestore.instance
                      .collection('groupnotifications')
                      .add({
                        'action': 'deleted a TODO: $todoTitle',
                        'userId': userId,
                        'type': 'message',
                        'seenBy': [],
                        'groupId': groupId,
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                  Navigator.pop(context, 'deleted');

                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void showDoneDialog({
    required BuildContext context,
    required Future<void> Function() onMarkTodoDone,
    required Future<void> Function() onAddExpense,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Is it an Expense?'),
            content: const Text('Would you like to add this as an expense?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false), // No
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true), // Yes
                child: const Text('Yes'),
              ),
            ],
          ),
    );

    if (result == null) return;

    if (result == false) {
      await onMarkTodoDone();
      Navigator.pop(context); // close screen if needed
    } else {
      await onAddExpense();
    }
  }

  Future<String> getGroupName(String groupId) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(groupId)
              .get();
      return doc.data()?['groupName'] ?? 'Unknown group';
    } catch (e) {
      return 'Error fetching Group Name';
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
                    // markTodoAsDone(todoId);
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

  void addExpense({
    required String groupId,
    required String title,
    required String amountText,
    required String description,
    String? paidByUser,
  }) async {
    if (title.isEmpty || amountText.isEmpty || paidByUser == null) {
      if (!mounted) return;
      showSuccessFlushbar(context, "Please fill in all required fields.");
      return;
    }

    double? amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      if (!mounted) return;
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

  Future<void> markTodoAsDone(String todoId) async {
    final todoRef = FirebaseFirestore.instance.collection('TODO').doc(todoId);

    try {
      await todoRef.update({
        'status': 'Done',
        'updatedAt': FieldValue.serverTimestamp(), // optional: update timestamp
      });
      if (!mounted) return;
      showSuccessFlushbar(context, "TODO Marked as Done.");
    } catch (e) {
      if (!mounted) return; // widget is no longer in the widget tree
      showErrorDialog(context, "Something went wrong. Please try again later.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    final todoAsync = ref.watch(singleTodoProvider(widget.todoId));

    return todoAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (todo) {
        if (todo == null) {
          return const Scaffold(body: Center(child: Text('Todo not found')));
        }

        final todoId = todo['todoId'];
        final String title = todo['todoTitle'] ?? 'No title';
        final String groupId = todo['groupId'] ?? '';
        final String description = todo['description'] ?? 'No description';
        final String status = todo['status'] ?? 'Not specified';
        final dueDate = (todo['dueDate'] as Timestamp?)?.toDate();
        final formattedDate =
            dueDate != null
                ? DateFormat('MMMM d, y').format(dueDate)
                : 'No due date';
        final date = (todo['createdAt'] as Timestamp?)?.toDate();
        final relativeTime =
            date != null ? timeago.format(date) : 'Unknown time';
        final String createdByUid = todo['createdBy'] ?? '';

        final currentUser = FirebaseAuth.instance.currentUser;
        final String userId = currentUser?.uid ?? '';
        final bool isOwner = userId == createdByUid;

        return FutureBuilder<String>(
          future: getUserRole(groupId, userId),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (roleSnapshot.hasError) {
              return const Center(child: Text('Error loading role'));
            }

            final role = roleSnapshot.data ?? 'none';
            final isAdminOrCoAdmin = (role == 'admin' || role == 'co-admin');
            return FutureBuilder<String>(
              future: getGroupName(groupId),
              builder: (context, groupSnapshot) {
                final String groupName =
                    groupSnapshot.connectionState == ConnectionState.waiting
                        ? 'Loading...'
                        : (groupSnapshot.data ?? 'Unknown group');

                return Scaffold(
                  appBar: AppBar(
                    title: Text(
                      groupName,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: Colors.green,
                    centerTitle: true,
                    actions: [
                      if (isAdminOrCoAdmin || isOwner)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected:
                              (choice) =>
                                  _onMenuSelected(choice, todo, todo['id']),
                          itemBuilder:
                              (context) => const [
                                PopupMenuItem<String>(
                                  value: 'Edit Todo',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'Delete Todo',
                                  child: Text('Delete'),
                                ),
                              ],
                        ),
                    ],
                  ),
                  body: SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: isWide ? 600 : double.infinity,
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: Card(
                                color: Colors.blue.shade50,
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                    horizontal: 35,
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        title,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            buildDetailItem(
                              const Icon(Icons.description),
                              'Description',
                              description,
                            ),
                            buildDetailItem(
                              const Icon(Icons.account_circle),
                              'Created by',
                              todo['createdByEmail'] ?? 'Unknown user',
                            ),
                            buildDetailItem(
                              const Icon(Icons.verified),
                              'Status',
                              status,
                            ),
                            buildDetailItem(
                              const Icon(Icons.access_time),
                              'Due Date',
                              formattedDate,
                            ),
                            buildDetailItem(
                              const Icon(Icons.access_time),
                              'Created At',
                              relativeTime,
                            ),
                            if (status == 'Pending')
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    showDoneDialog(
                                      context: context,
                                      onMarkTodoDone:
                                          () => markTodoAsDone(
                                            todoId,
                                          ), // Pass the function reference, no parentheses
                                      onAddExpense: () async {
                                        await _showAddExpense(
                                          groupId,
                                        ); // wait for the dialog to finish
                                        await markTodoAsDone(todoId);
                                      }, // Pass the function reference
                                    );
                                  },
                                  icon: const Icon(Icons.check),
                                  label: const Text('Done'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    textStyle: const TextStyle(fontSize: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget buildDetailItem(Icon icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
