import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class TodoScreen extends StatefulWidget {
  final Map<String, dynamic> todo;

  const TodoScreen({super.key, required this.todo});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  late Map<String, dynamic> todo;

  @override
  void initState() {
    super.initState();
    todo = widget.todo;
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
    BuildContext context,
    String choice,
    Map<String, dynamic> expenseData,
    String expenseId,
  ) {
    switch (choice) {
      case 'Edit Todo':
        _showEditTodoDialog();
        break;

      case 'Delete Todo':
        _showDeleteTodoDialog();
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

  Future<void> updateTodo(
    String id,
    String title,
    String desc,
    DateTime dueDate,
    String assignedTo,
  ) async {
    await FirebaseFirestore.instance.collection('todos').doc(id).update({
      'title': title,
      'description': desc,
      'dueDate': Timestamp.fromDate(dueDate),
      'assignedTo': assignedTo,
    });

    setState(() {
      todo['title'] = title;
      todo['description'] = desc;
      todo['dueDate'] = dueDate;
      todo['assignedTo'] = assignedTo;
    });
  }

  Future<void> markTodoCompleted(String id) async {
    await FirebaseFirestore.instance.collection('todos').doc(id).update({
      'status': 'Completed',
    });

    setState(() {
      todo['status'] = 'Completed';
    });
  }

  Future<void> deleteTodo(String id) async {
    await FirebaseFirestore.instance.collection('todos').doc(id).delete();
    Navigator.pop(context);
  }

  void _showEditTodoDialog() async {
    final titleController = TextEditingController(text: todo['title']);
    final descController = TextEditingController(text: todo['description']);
    DateTime selectedDate = (todo['dueDate'] as Timestamp).toDate();
    String assignedTo = todo['assignedTo'] ?? '';

    List<String> members = [];

    // Fetch group members
    final snapshot =
        await FirebaseFirestore.instance
            .collection('groupmembers')
            .where('groupId', isEqualTo: todo['groupId'])
            .get();

    for (var doc in snapshot.docs) {
      final userId = doc['userId'];
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
      if (userDoc.exists) {
        members.add(userDoc['email']);
      }
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
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(labelText: 'Title'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: descController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 10),
                        ListTile(
                          title: Text(
                            'Due: ${selectedDate.toLocal().toString().split(' ')[0]}',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialogState(() => selectedDate = picked);
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: assignedTo,
                          decoration: const InputDecoration(
                            labelText: 'Assign to',
                          ),
                          items:
                              members
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setDialogState(() => assignedTo = value ?? '');
                          },
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
                      onPressed: () {
                        updateTodo(
                          todo['id'],
                          titleController.text.trim(),
                          descController.text.trim(),
                          selectedDate,
                          assignedTo,
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

  void _showDeleteTodoDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete TODO'),
            content: Text(
              'Are you sure you want to delete "${todo['title']}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => deleteTodo(todo['id']),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
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

    final String title = todo['todoTitle'];
    final String groupId = todo['groupId'] ?? '';
    final String description = todo['description'] ?? 'No description';
    final String createdByUid = todo['createdBy'] ?? '';
    final String status = todo['status'] ?? 'Not specified';
    final dueDate = (todo['dueDate'] as Timestamp?)?.toDate();
    final formattedDate =
        dueDate != null
            ? DateFormat('MMMM d, y').format(dueDate)
            : 'No due date';
    ;

    final date = (todo['createdAt'] as Timestamp?)?.toDate();
    final relativeTime = date != null ? timeago.format(date) : 'Unknown time';

    return FutureBuilder<String>(
      future: getUserRole(groupId, userId),
      builder: (context, snapshot) {
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
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.green,
                centerTitle: true,
                actions: [
                  // Keep the same popup menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected:
                        (choice) =>
                            _onMenuSelected(context, choice, todo, todo['id']),
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
                          width:
                              double
                                  .infinity, // makes the card fill max width inside the Column
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
                    
                        FutureBuilder<String>(
                          future: getUserEmail(createdByUid),
                          builder: (context, snapshot) {
                            final String createdByEmail =
                                snapshot.connectionState ==
                                        ConnectionState.waiting
                                    ? 'Loading...'
                                    : (snapshot.data ?? 'Unknown user');
                            return buildDetailItem(
                              const Icon(Icons.account_circle),
                              'Created by',
                              createdByEmail,
                            );
                          },
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
