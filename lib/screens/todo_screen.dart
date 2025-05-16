import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

class TodoScreen extends StatelessWidget {
  final Map<String, dynamic> todo;

  const TodoScreen({Key? key, required this.todo}) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    final date = (todo['createdAt'] as Timestamp?)?.toDate();
    final relativeTime = date != null ? timeago.format(date) : 'Unknown time';

    final String title = todo['expenseTitle'] ?? 'Untitled';
    final String groupId = todo['groupId'] ?? '';
    final String paidBy = todo['expensePaidBy'] ?? 'Unknown';
    final String description =
        todo['expenseDescription'] ?? 'No description';
    final String createdByUid = todo['createdBy'] ?? '';
    final String status = todo['status'] ?? 'Not specified';
    final double amount = (todo['expenseAmount'] ?? 0.0) * 1.0;
    final String? imageUrl =
        todo['expenseImageUrl']; // Assuming this field stores the image URL

    return FutureBuilder<String>(
      // To fetch group name
      future: getGroupName(groupId),
      builder: (context, snapshot) {
        final String groupName =
            snapshot.connectionState == ConnectionState.waiting
                ? 'Loading...'
                : (snapshot.data ?? 'Unknown group');

        return Scaffold(
          appBar: AppBar(title: Text('$groupName > $title')),
          body: SingleChildScrollView(
            child: Align(
              alignment:
                  Alignment.topCenter, // Center horizontally, top vertically
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                      const SizedBox(height: 24),

                      // Display the image if the URL is available
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Image.network(
                            imageUrl,
                            height: 200, // Adjust the height as needed
                            width: double.infinity,
                            fit:
                                BoxFit
                                    .cover, // Ensure the image fits the container
                          ),
                        ),

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
                        // To fetch user email
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
                        'Created at',
                        relativeTime,
                      ),

                      const SizedBox(height: 20),

                      // Approve button
                      if (status.toLowerCase() == 'pending')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await approveExpense(todo['id']);
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildDetailItem(Icon icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
