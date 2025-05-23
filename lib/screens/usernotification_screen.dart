import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:costmate/providers/notification_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class UserNotificationScreen extends ConsumerStatefulWidget {
  const UserNotificationScreen({
    super.key,
    required this.onUpdateAppBar,
    required this.onGroupTap,
  });

  final Function(AppBar) onUpdateAppBar;
  final void Function(Map<String, dynamic> group) onGroupTap;

  @override
  ConsumerState<UserNotificationScreen> createState() =>
      _UserNotificationScreenState();
}

class _UserNotificationScreenState
    extends ConsumerState<UserNotificationScreen> {
  Set<String> selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateAppBar(); // 📌 Initial app bar setup
    });
  }

  void updateAppBar() {
    widget.onUpdateAppBar(
      AppBar(
        title: const Text(
          " User Notification",
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        centerTitle: true,
        actions: [
          if (selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        title: const Text('Delete Notifications'),
                        content: Text(
                          'Are you sure you want to delete ${selectedIds.length} notification(s)?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                );

                if (confirm == true) {
                  for (final id in selectedIds) {
                    await FirebaseFirestore.instance
                        .collection('usernotifications')
                        .doc(id)
                        .delete();
                  }
                  setState(() {
                    selectedIds.clear();
                    updateAppBar(); // 🔁 Refresh app bar
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifications deleted')),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) return const Center(child: Text('User not logged in.'));

    final notificationsAsync = ref.watch(userNotificationProvider(userId));

    return notificationsAsync.when(
      data: (notificationsRaw) {
        final notifications = List<Map<String, dynamic>>.from(notificationsRaw)
          ..sort((a, b) {
            final aTime =
                (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final bTime =
                (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            return bTime.compareTo(aTime); // Newest first
          });

        if (notifications.isEmpty) {
          return const Center(child: Text("You don't have any notification."));
        }

        final allSelected = selectedIds.length == notifications.length;

        return Scaffold(
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500, minWidth: 0),
                width: MediaQuery.of(context).size.width * 1,
                // padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(
                          allSelected ? Icons.remove_done : Icons.done_all,
                        ),
                        label: Text(allSelected ? 'Unselect All' : 'Select All'),
                        onPressed: () {
                          setState(() {
                            if (allSelected) {
                              selectedIds.clear();
                            } else {
                              selectedIds = {
                                for (var note in notifications)
                                  note['id'] as String,
                              };
                            }
                            updateAppBar();
                          });
                        },
                      ),
                    ),
                  ),
                  Divider(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final note = notifications[index];
                        final noteId = note['id'];
                        final action = note['action'] ?? 'Unknown action';
                        // final groupName = note['groupName'] ?? 'Unknown group';
                        final timestamp = note['createdAt'];
              
                        DateTime createdAt;
                        if (timestamp is Timestamp) {
                          createdAt = timestamp.toDate();
                        } else if (timestamp is DateTime) {
                          createdAt = timestamp;
                        } else {
                          createdAt = DateTime.now();
                        }
              
                        final formattedDate = DateFormat.yMMMEd().add_jm().format(
                          createdAt,
                        );
              
                        final isSelected = selectedIds.contains(noteId);
              
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Checkbox(
                                value: isSelected,
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      selectedIds.add(noteId);
                                    } else {
                                      selectedIds.remove(noteId);
                                    }
                                    updateAppBar();
                                  });
                                },
                              ),
                              title: Text(
                                action,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
