import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:costmate/providers/expenses_todos_members_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class ExpenseScreen extends ConsumerStatefulWidget {
  final String expenseId;

  const ExpenseScreen({super.key, required this.expenseId});

  @override
  ConsumerState<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends ConsumerState<ExpenseScreen> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
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

  Future<String> getUserRole(String groupId, String userId) async {
    try {
      final groupDoc =
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(groupId)
              .get();

      final groupData = groupDoc.data();
      if (groupData == null) return 'none';

      if (groupData['adminId'] == userId) return 'admin';

      final coAdmins = List<String>.from(groupData['coAdmins'] ?? []);
      if (coAdmins.contains(userId)) return 'co-admin';

      return 'member';
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return 'none';
    }
  }

  Future<void> approveExpense(String expenseId) async {
    try {
      await FirebaseFirestore.instance
          .collection('expenses')
          .doc(expenseId)
          .update({'status': 'Approved'});
    } catch (e) {
      debugPrint('Error approving expense: $e');
    }
  }

  void _onMenuSelected(
    String choice,
    Map<String, dynamic> expenseData,
    String expenseId,
  ) {
    switch (choice) {
      case 'Edit Expense':
        _showEditExpenseDialog(
          expenseId: expenseId,
          groupId: expenseData['groupId'],
          currentTitle: expenseData['expenseTitle'] ?? '',
          currentAmount: expenseData['expenseAmount']?.toString() ?? '0.0',
          currentDescription: expenseData['expenseDescription'] ?? '',
          currentPaidBy: expenseData['paidBy'],
        );
        break;

      case 'Delete Expense':
        _showDeleteExpenseDialog(
          expenseId: expenseId,
          title: expenseData['expenseTitle'] ?? 'Untitled',
        );
        break;
    }
  }

  Future<void> updateExpense({
    required String expenseId,
    required String title,
    required String amountText,
    required String description,
    required String? paidByUser,
  }) async {
    double? amount = double.tryParse(amountText);
    if (amount == null) {
      if (kDebugMode) {
        print('Invalid amount format');
      }
      return;
    }

    try {
      final expenseDocRef = FirebaseFirestore.instance
          .collection('expenses')
          .doc(expenseId);

      await expenseDocRef.update({
        'expenseTitle': title,
        'expenseAmount': amount,
        'expenseDescription': description,
        'expensePaidBy': paidByUser,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('Expense updated successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating expense: $e');
      }
    }
  }

  void _showEditExpenseDialog({
    required String expenseId,
    required String groupId,
    required String currentTitle,
    required String currentAmount,
    required String currentDescription,
    required String? currentPaidBy,
  }) async {
    List<String> memberList = [];
    String? currentUserEmail = user?.email;

    // Initialize controllers with current expense values
    final TextEditingController expenseTitleController = TextEditingController(
      text: currentTitle,
    );
    final TextEditingController expenseAmountController = TextEditingController(
      text: currentAmount,
    );
    final TextEditingController expenseDescriptionController =
        TextEditingController(text: currentDescription);

    try {
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
      if (kDebugMode) {
        print('Error fetching group members: $e');
      }
    }

    if (currentUserEmail != null) {
      memberList.remove(currentUserEmail);
      memberList.insert(0, currentUserEmail);
    }

    String? selectedPaidBy = currentPaidBy ?? currentUserEmail;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Edit Expense"),
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
                          controller: expenseTitleController,
                          decoration: const InputDecoration(
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
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedPaidBy = value;
                            });
                          },
                          decoration: const InputDecoration(
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
                  onPressed: () async {
                    final title = expenseTitleController.text.trim();
                    final amountText = expenseAmountController.text.trim();
                    final description =
                        expenseDescriptionController.text.trim();

                    await updateExpense(
                      expenseId: expenseId,
                      title: title,
                      amountText: amountText,
                      description: description,
                      paidByUser: selectedPaidBy,
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

  void _showDeleteExpenseDialog({
    required String expenseId,
    required String title,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Expense'),
            content: Text('Are you sure you want to delete "$title"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('expenses')
                      .doc(expenseId)
                      .delete();

                  Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    final expenseAsync = ref.watch(singleExpenseProvider(widget.expenseId));

    return expenseAsync.when(
      data: (expense) {
        if (expense == null)
          return const Center(child: Text('Expense not found'));

        final date = (expense['createdAt'] as Timestamp?)?.toDate();
        final relativeTime =
            date != null ? timeago.format(date) : 'Unknown time';
        final formattedDate =
            date != null
                ? DateFormat('MMMM d, y').format(date)
                : 'Unknown date';

        final expenseId = expense['expenseId'];
        final String title = expense['expenseTitle'] ?? 'Untitled';
        final String groupId = expense['groupId'] ?? '';
        final String paidBy = expense['expensePaidBy'] ?? 'Unknown';
        final String description =
            expense['expenseDescription'] ?? 'No description';
        final String createdByUid = expense['createdBy'] ?? '';
        final String status = expense['status'] ?? 'Not specified';
        final double amount = (expense['expenseAmount'] ?? 0.0) * 1.0;

        final currentUser = FirebaseAuth.instance.currentUser;
        final String userId = currentUser?.uid ?? '';

        return FutureBuilder<String>(
          future: getUserRole(groupId, userId),
          builder: (context, roleSnapshot) {
            final isAdminOrCoAdmin =
                (roleSnapshot.data == 'admin' ||
                    roleSnapshot.data == 'co-admin');

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
                            (choice) =>
                                _onMenuSelected(choice, expense, expense['id']),
                        itemBuilder:
                            (context) => const [
                              PopupMenuItem<String>(
                                value: 'Edit Expense',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem<String>(
                                value: 'Delete Expense',
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
                                      const SizedBox(height: 12),
                                      Text(
                                        '₱${amount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            buildDetailItem(
                              const Icon(Icons.person),
                              'Paid by',
                              paidBy,
                            ),
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
                              const Icon(Icons.calendar_today),
                              'Created on',
                              formattedDate,
                            ),
                            buildDetailItem(
                              const Icon(Icons.access_time),
                              'Created',
                              relativeTime,
                            ),
                            const SizedBox(height: 20),

                            if (status.toLowerCase() == 'pending' &&
                                isAdminOrCoAdmin)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    await approveExpense(expenseId);
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.check),
                                  label: const Text('Approve'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    textStyle: const TextStyle(fontSize: 16),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
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
