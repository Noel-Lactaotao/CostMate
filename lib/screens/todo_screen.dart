import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:costmate/providers/expenses_todos_members_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

  @override
  void initState() {
    super.initState();
  }

  Future<String> getUserRole(String groupId, String userId) async {
    final doc =
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .get();
    final data = doc.data();
    if (data == null) return 'none';
    if (data['adminId'] == userId) return 'admin';
    if ((data['coAdmins'] ?? []).contains(userId)) return 'co-admin';
    return 'member';
  }

  void _onMenuSelected(
    String choice,
    Map<String, dynamic> todoData,
    String todoId,
  ) {
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
        _showDeleteTodoDialog(
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

      if (kDebugMode) {
        print('TODO updated successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating TODO: $e');
      }
    }
  }

  Future<void> markTodoCompleted(String id) async {
    await FirebaseFirestore.instance.collection('TODO').doc(id).update({
      'status': 'Completed',
    });
  }

  Future<void> deleteTodo(String id) async {
    await FirebaseFirestore.instance.collection('TODO').doc(id).delete();
    Navigator.pop(context);
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
                        Navigator.pop(context);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showDeleteTodoDialog({
    required String todoId,
    required String title,
  }) async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete "$title"?'),
            content: const Text('Are you sure you want to delete this TODO?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('TODO')
                      .doc(todoId)
                      .delete();
                  Navigator.pop(context);
                },
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
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

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

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

        return FutureBuilder<String>(
          future: getUserRole(groupId, userId),
          builder: (context, roleSnapshot) {
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
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected:
                            (choice) => _onMenuSelected(
                              choice,
                              todo,
                              todo['id'],
                            ),
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
