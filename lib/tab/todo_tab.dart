import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:costmate/providers/expenses_todos_members_providers.dart';
import 'package:costmate/screens/todo_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;

class TodoTab extends ConsumerStatefulWidget {
  final String groupId;
  const TodoTab({super.key, required this.groupId});

  @override
  ConsumerState<TodoTab> createState() => _TodoTabState();
}

class _TodoTabState extends ConsumerState<TodoTab> {
  final Map<String, String> _userIdToName = {};
  // final Map<String, bool> _groupIdToIsAdmin = {};
  late List<Map<String, dynamic>> _filteredTodo = [];
  String _sortOption = 'Newest';
  String _statusFilter = 'Pending';
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool isLoading = true;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadSavedFilters(ref);
  }

  void _loadSavedFilters(WidgetRef ref) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _sortOption = prefs.getString('todoSortOption') ?? 'Newest';
      _statusFilter = prefs.getString('todoStatusFilter') ?? 'Pending';
    });
    _applyFilters(ref, widget.groupId); // ✅ pass ref here
  }

  String _formatDueDate(DateTime date) {
    return '${_monthName(date.month)} ${date.day}, ${date.year}';
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  void _onMenuSelected(
    String choice,
    Map<String, dynamic> todoData,
    String todoId,
  ) async {
    switch (choice) {
      case 'Edit TODO':
        _showEditTODODialog(
          todoId: todoId,
          groupId: todoData['groupId'],
          currentTitle: todoData['todoTitle'],
          currentDueDate: todoData['dueDate'], // Firestore Timestamp
          currentDescription: todoData['description'] ?? '',
        );
        break;
      case 'Delete TODO':
        _showDeleteTODODialog(
          todoId: todoId,
          title: todoData['todoTitle'] ?? 'Untitled',
        );
        break;
    }
  }

  Future<void> _showEditTODODialog({
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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Edit TODO"),
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
                  onPressed: () async {
                    final title = todoTitleController.text.trim();
                    final description = todoDescriptionController.text.trim();

                    await updateTODO(
                      todoId: todoId,
                      title: title,
                      dueDate: selectedDueDate, // Pass DateTime
                      description: description,
                    );

                    Navigator.pop(context);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
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

  Future<void> _showDeleteTODODialog({
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

  void _applyFilters(WidgetRef ref, String groupId) {
    final todosAsync = ref.read(todoProvider(groupId));

    todosAsync.whenData((todosList) {
      // Convert to list for sorting
      List<Map<String, dynamic>> filtered =
          todosList.where((todo) {
            final createdAt = (todo['createdAt'] as Timestamp?)?.toDate();
            final status = todo['status'] ?? 'Pending';

            if (createdAt == null) return false;
            if (status != _statusFilter) return false;

            return true;
          }).toList();

      // Sort the filtered list
      if (_sortOption == 'Newest') {
        filtered.sort((a, b) {
          final aDate = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          final bDate = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          return bDate.compareTo(aDate);
        });
      } else if (_sortOption == 'Oldest') {
        filtered.sort((a, b) {
          final aDate = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          final bDate = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          return aDate.compareTo(bDate);
        });
      } else if (_sortOption == 'Closest Due Date') {
        final now = DateTime.now();
        filtered.sort((a, b) {
          final aDue = (a['dueDate'] as Timestamp?)?.toDate() ?? DateTime(2100);
          final bDue = (b['dueDate'] as Timestamp?)?.toDate() ?? DateTime(2100);
          return aDue
              .difference(now)
              .abs()
              .compareTo(bDue.difference(now).abs());
        });
      }

      setState(() {
        _filteredTodo = filtered;
      });
    });
  }

  void _showFilterDialog() {
    String tempSort = _sortOption;
    String tempApproval = _statusFilter;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter TODOs'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: tempApproval,
                decoration: const InputDecoration(labelText: 'Status'),
                items:
                    ['Pending', 'Done']
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                onChanged: (value) {
                  if (value != null) tempApproval = value;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: tempSort,
                decoration: const InputDecoration(labelText: 'Sort By'),
                items:
                    ['Newest', 'Oldest', 'Closest Due Date']
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                onChanged: (value) {
                  if (value != null) tempSort = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setString('todoSortOption', tempSort);
                await prefs.setString('todoStatusFilter', tempApproval);

                setState(() {
                  _sortOption = tempSort;
                  _statusFilter = tempApproval;
                  _applyFilters(ref, widget.groupId);
                });

                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    final todoAsyncValue = ref.watch(todoProvider(widget.groupId));

    return todoAsyncValue.when(
      data: (todosList) {
        // Update loading state & filtered list
        isLoading = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _applyFilters(ref, widget.groupId);
        });

        // Optionally, update caches if needed:
        for (var todo in todosList) {
          final createdById = todo['createdBy'] as String?;
          final createdByName = todo['createdByName'] as String? ?? 'Unknown';
          if (createdById != null) {
            _userIdToName[createdById] = createdByName;
          }

          // Cache user role to bool for example
          // final role = todo['currentUserRole'] as String? ?? 'Member';
          // _groupIdToIsAdmin[widget.groupId] =
          //     (role == 'Admin' || role == 'Owner');
        }

        return Center(
          child: Container(
            width: isWide ? 600 : double.infinity,
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _showFilterDialog,
                    icon: const Icon(Icons.filter_list),
                    label: const Text('Filter'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 10),
                Expanded(
                  child:
                      _filteredTodo.isEmpty
                          ? const Center(child: Text('No TODO found.'))
                          : ListView.builder(
                            itemCount: _filteredTodo.length,
                            itemBuilder: (context, index) {
                              final todo = _filteredTodo[index];
                              final String? createdById = todo['createdBy'];
                              final createdByName =
                                  _userIdToName[createdById] ?? 'Loading...';

                              final dueDate =
                                  (todo['dueDate'] as Timestamp?)?.toDate();
                              final status = todo['status'] ?? 'Pending';
                              final createdAt =
                                  (todo['createdAt'] as Timestamp?)?.toDate();
                              final currentUserRole =
                                  todo['currentUserRole'] ?? 'member';
                              final timeAgo =
                                  createdAt != null
                                      ? timeago.format(createdAt)
                                      : 'Unknown';

                              final bool isAdmin =
                                  currentUserRole == 'admin' ||
                                  currentUserRole == 'co-admin';
                              final bool isOwner = createdById == currentUserId;

                              final showPopup =
                                  (status == 'Done' && isAdmin) ||
                                  (status == 'Pending' && (isAdmin || isOwner));

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: ListTile(
                                        title: Text(
                                          todo['todoTitle'] ?? 'Untitled',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Added by: $createdByName',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            Text(
                                              dueDate != null
                                                  ? 'Due: ${_formatDueDate(dueDate)}'
                                                  : 'Due: No due date',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
                                              ),
                                            ),
                                            Text(
                                              'Added: $timeAgo',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      TodoScreen(todo: todo),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    if (showPopup)
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: PopupMenuButton<String>(
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
                                                  value: 'Edit TODO',
                                                  child: Text('Edit'),
                                                ),
                                                PopupMenuItem<String>(
                                                  value: 'Delete TODO',
                                                  child: Text('Delete'),
                                                ),
                                              ],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}
