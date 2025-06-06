import 'dart:core';

import 'package:another_flushbar/flushbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:costmate/providers/expenses_todos_members_providers.dart';
import 'package:costmate/screens/expense_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;

class ExpensesTab extends ConsumerStatefulWidget {
  final String groupId;

  const ExpensesTab({super.key, required this.groupId});

  @override
  ConsumerState<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<ExpensesTab> {
  final Map<String, String> _userIdToName = {};
  // final Map<String, bool> _groupIdToIsAdmin = {};
  List<Map<String, dynamic>> _filteredExpenses = [];
  String _sortOption = 'Newest';
  String _timeRange = 'All';
  String _approvalFilter = 'Approved';
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool isLoading = true;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadSavedFilters(ref);
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

  Future<void> _loadSavedFilters(WidgetRef ref) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _sortOption = prefs.getString('sortOption') ?? 'Newest';
      _timeRange = prefs.getString('timeRange') ?? 'All';
      _approvalFilter = prefs.getString('approvalFilter') ?? 'Pending';
    });
    _applyFilters(ref, widget.groupId);
  }

  void _applyFilters(WidgetRef ref, String groupId) {
    final expensesAsync = ref.read(expensesProvider(groupId));

    DateTime now = DateTime.now();

    expensesAsync.whenData((expensesList) {
      final filtered =
          expensesList.where((expense) {
            final createdAt = (expense['createdAt'] as Timestamp?)?.toDate();
            final status = expense['status'] ?? 'Pending';

            if (createdAt == null) return false;
            if (status != _approvalFilter) {
              return false;
            }

            switch (_timeRange) {
              case 'Week':
                final startOfWeek = now.subtract(
                  Duration(days: now.weekday - 1),
                );
                return createdAt.isAfter(startOfWeek);
              case 'Month':
                return createdAt.month == now.month &&
                    createdAt.year == now.year;
              case 'Year':
                return createdAt.year == now.year;
              case 'All':
              default:
                return true;
            }
          }).toList();

      filtered.sort((a, b) {
        final aDate = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        final bDate = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);

        switch (_sortOption) {
          case 'Oldest':
            return aDate.compareTo(bDate);
          case 'Highest':
            return (b['expenseAmount'] ?? 0).compareTo(a['expenseAmount'] ?? 0);
          case 'Lowest':
            return (a['expenseAmount'] ?? 0).compareTo(b['expenseAmount'] ?? 0);
          case 'Newest':
          default:
            return bDate.compareTo(aDate);
        }
      });

      setState(() {
        _filteredExpenses = filtered;
      });
    });
  }

  void _showFilterDialog() {
    String tempSort = _sortOption;
    String tempTime = _timeRange;
    String tempApproval = _approvalFilter;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter Expenses'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDropdown('Time Range', tempTime, [
                'All',
                'Week',
                'Month',
                'Year',
              ], (value) => tempTime = value),
              const SizedBox(height: 12),
              _buildDropdown('Approval Status', tempApproval, [
                'Approved',
                'Pending',
              ], (value) => tempApproval = value),
              const SizedBox(height: 12),
              _buildDropdown('Sort By', tempSort, [
                'Newest',
                'Oldest',
                'Highest',
                'Lowest',
              ], (value) => tempSort = value),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setString('sortOption', tempSort);
                await prefs.setString('timeRange', tempTime);
                await prefs.setString('approvalFilter', tempApproval);

                setState(() {
                  _sortOption = tempSort;
                  _timeRange = tempTime;
                  _approvalFilter = tempApproval;
                });

                _applyFilters(ref, widget.groupId);
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items:
          items.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
      onChanged: (val) => val != null ? onChanged(val) : null,
    );
  }

  void _showYearlyRecordsDialog(WidgetRef ref, String groupId) {
    final expensesAsync = ref.read(expensesProvider(groupId));

    expensesAsync.whenData((expensesList) {
      final years =
          expensesList
              .map((e) => (e['createdAt'] as Timestamp?)?.toDate().year)
              .whereType<int>()
              .toSet()
              .toList()
            ..sort((a, b) => b.compareTo(a));

      int selectedYear = years.isNotEmpty ? years.first : DateTime.now().year;

      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              final monthlyTotals = {
                for (int i = 1; i <= 12; i++) _monthName(i): 0.0,
              };

              for (var e in expensesList) {
                final date = (e['createdAt'] as Timestamp?)?.toDate();
                if (date != null &&
                    date.year == selectedYear &&
                    e['status'] == 'Approved') {
                  monthlyTotals[_monthName(date.month)] =
                      (monthlyTotals[_monthName(date.month)] ?? 0.0) +
                      (e['expenseAmount'] ?? 0.0);
                }
              }

              final total = monthlyTotals.values.fold(0.0, (a, b) => a + b);

              return AlertDialog(
                title: const Text(
                  'Monthly Totals by Year',
                  textAlign: TextAlign.center,
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        value: selectedYear,
                        decoration: const InputDecoration(
                          labelText: 'Select Year',
                        ),
                        items:
                            years
                                .map(
                                  (y) => DropdownMenuItem(
                                    value: y,
                                    child: Text('$y'),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) => setState(() => selectedYear = val!),
                      ),
                      const SizedBox(height: 16),
                      ...monthlyTotals.entries.map(
                        (entry) => ListTile(
                          dense: true,
                          title: Text(entry.key),
                          trailing: Text('₱${entry.value.toStringAsFixed(2)}'),
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        dense: true,
                        title: const Text(
                          'Total',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: Text(
                          '₱${total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        },
      );
    });
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

  double _calculateTotal() {
    return _filteredExpenses
        .where((e) => e['status'] == _approvalFilter)
        .fold(0.0, (sum, e) => sum + (e['expenseAmount'] ?? 0.0));
  }

  void _onMenuSelected(
    String choice,
    Map<String, dynamic> expenseData,
    String expenseId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    final groupId = expenseData['groupId'];

    if (user == null || groupId == null) return;

    final expenseTitle = expenseData['expenseTitle'] ?? 'Untitled';

    switch (choice) {
      case 'Edit Expense':
        _showEditExpenseDialog(
          expenseId: expenseId,
          groupId: groupId,
          currentTitle: expenseTitle,
          currentAmount: expenseData['expenseAmount']?.toString() ?? '0.0',
          currentDescription: expenseData['expenseDescription'] ?? '',
          currentPaidBy: expenseData['paidBy'],
        );
        break;

      case 'Delete Expense':
        _showDeleteExpenseDialog(expenseId: expenseId, title: expenseTitle);
        break;
    }
  }

  Future<void> _showEditExpenseDialog({
    required String expenseId,
    required String groupId,
    required String currentTitle,
    required String currentAmount,
    required String currentDescription,
    required String? currentPaidBy,
  }) async {
    List<String> memberList = [];
    String? currentUserEmail = user?.email;

    // Setup controllers with current values
    final TextEditingController expenseTitleController = TextEditingController(
      text: currentTitle,
    );
    final TextEditingController expenseAmountController = TextEditingController(
      text: currentAmount,
    );
    final TextEditingController expenseDescriptionController =
        TextEditingController(text: currentDescription);

    try {
      // Fetch group members (same as your add dialog)
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

                    // Navigator.pop(context);
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

  Future<void> updateExpense({
    required String expenseId,
    required String title,
    required String amountText,
    required String description,
    required String? paidByUser,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    final expenseSnapshot =
        await FirebaseFirestore.instance
            .collection('expenses')
            .where('expenseId', isEqualTo: expenseId)
            .get();

    String expenseTitle = 'None';
    String groupId = 'None';
    if (expenseSnapshot.docs.isNotEmpty) {
      expenseTitle = expenseSnapshot.docs.first['expenseTitle'] ?? 'None';
      groupId = expenseSnapshot.docs.first['groupId'] ?? 'None';
    }

    double? amount = double.tryParse(amountText);
    if (!mounted) return;
    if (amount == null) {
      showSuccessFlushbar(context, "Invalid amount format.");
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

      if (!mounted) return;
      Navigator.pop(context);

      await FirebaseFirestore.instance.collection('groupnotifications').add({
        'action': 'edited the expense: $expenseTitle',
        'userId': user?.uid,
        'type': 'message',
        'seenBy': [],
        'groupId': groupId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      showSuccessFlushbar(context, "Expense updated successfully.");
    } catch (e) {
      if (!mounted) return; // widget is no longer in the widget tree
      showErrorDialog(context, "Something went wrong. Please try again later.");
    }
  }

  void _showDeleteExpenseDialog({
    required String expenseId,
    required String title,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Expense'),
            content: Text('Are you sure you want to delete "$title"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;

                  final expenseSnapshot =
                      await FirebaseFirestore.instance
                          .collection('expenses')
                          .where('expenseId', isEqualTo: expenseId)
                          .get();

                  String expenseTitle = 'None';
                  String groupId = 'None';
                  if (expenseSnapshot.docs.isNotEmpty) {
                    expenseTitle =
                        expenseSnapshot.docs.first['expenseTitle'] ?? 'None';
                    groupId = expenseSnapshot.docs.first['groupId'] ?? 'None';
                  }

                  await FirebaseFirestore.instance
                      .collection('groupnotifications')
                      .add({
                        'action': 'deleted the expense: $expenseTitle',
                        'userId': user?.uid,
                        'type': 'message',
                        'seenBy': [],
                        'groupId': groupId,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                  await FirebaseFirestore.instance
                      .collection('expenses')
                      .doc(expenseId)
                      .delete();
                  Navigator.pop(context);

                  if (!mounted) return;
                  showSuccessFlushbar(context, "Expense successfully deleted.");
                },
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    final total = _calculateTotal();

    final expenseAsyncValue = ref.watch(expensesProvider(widget.groupId));

    return expenseAsyncValue.when(
      data: (expenseList) {
        // Update loading state & filtered list
        isLoading = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _applyFilters(ref, widget.groupId);
        });

        // Optionally, update caches if needed:
        for (var expense in expenseList) {
          final createdById = expense['createdBy'] as String?;
          final createdByName =
              expense['createdByName'] as String? ?? 'Unknown';
          if (createdById != null) {
            _userIdToName[createdById] = createdByName;
          }

          // Cache user role to bool for example
          // final role = expense['currentUserRole'] as String? ?? 'Member';
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showFilterDialog,
                        icon: const Icon(Icons.filter_list),
                        label: const Text('Filter'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed:
                            () => _showYearlyRecordsDialog(ref, widget.groupId),
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Yearly Records'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Card(
                  color: Colors.blue.shade50,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 16,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Total ${_timeRange.toLowerCase()} expenses (${_approvalFilter.toLowerCase()})',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        isLoading
                            ? const Text("")
                            : Text(
                              '₱${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 20),
                Expanded(
                  child:
                      _filteredExpenses.isEmpty
                          ? const Center(child: Text('No expenses found.'))
                          : ListView.builder(
                            itemCount: _filteredExpenses.length,
                            itemBuilder: (context, index) {
                              final expense = _filteredExpenses[index];
                              final expenseId = expense['expenseId'] ?? '';
                              final String? createdById = expense['createdBy'];
                              final createdByName =
                                  _userIdToName[createdById] ?? 'Loading...';
                              final status = expense['status'] ?? 'Pending';
                              final amount = expense['expenseAmount'] ?? 0.0;
                              final createdAt =
                                  (expense['createdAt'] as Timestamp?)
                                      ?.toDate();
                              final currentUserRole =
                                  expense['currentUserRole'] ?? 'member';
                              final timeAgo =
                                  createdAt != null
                                      ? timeago.format(createdAt)
                                      : 'Unknown';

                              final bool isAdmin =
                                  currentUserRole == 'admin' ||
                                  currentUserRole == 'co-admin';
                              final bool isOwner = createdById == currentUserId;

                              final showPopup =
                                  (status == 'Approved' && isAdmin) ||
                                  (status == 'Pending' && (isAdmin || isOwner));

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 8,
                                ),
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: ListTile(
                                        title: Text(
                                          expense['expenseTitle'] ?? 'Untitled',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 5),
                                            Text(
                                              '₱${amount.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green[700],
                                              ),
                                            ),
                                            Text(
                                              'Added by: $createdByName',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Color.fromARGB(
                                                  221,
                                                  0,
                                                  0,
                                                  0,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Added: $timeAgo',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Color.fromARGB(
                                                  221,
                                                  122,
                                                  122,
                                                  122,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        trailing: Text(
                                          status,
                                          style: TextStyle(
                                            color:
                                                (status == 'Approved')
                                                    ? Colors.green
                                                    : Colors.orange,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onTap: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => ExpenseScreen(
                                                    expenseId: expenseId,
                                                  ),
                                            ),
                                          );

                                          if (!mounted) return;

                                          if (result == 'deleted') {
                                            // Show success message
                                            showSuccessFlushbar(
                                              context,
                                              "Expense successfully deleted.",
                                            );

                                            // Optionally refresh your data here
                                            setState(() {
                                              // Trigger a UI update if needed
                                            });
                                          }
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
                                                expense,
                                                expense['id'],
                                              ),
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
