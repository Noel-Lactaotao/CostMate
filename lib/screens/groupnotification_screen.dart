import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:costmate/providers/notification_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class GroupNotificationScreen extends ConsumerStatefulWidget {
  const GroupNotificationScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupNotificationScreen> createState() =>
      _GroupNotificationScreenState();
}

class _GroupNotificationScreenState
    extends ConsumerState<GroupNotificationScreen> {
  Set<String> selectedIds = {};
  List<Map<String, dynamic>> notifications = [];
  List<Map<String, dynamic>> _notificationsToMarkSeen = [];
  bool hasMarkedSeen = false;
  String? userRole;

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      getUserRole(widget.groupId, userId).then((role) {
        setState(() {
          userRole = role;
        });
      });
    }
  }

  @override
  void dispose() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null && _notificationsToMarkSeen.isNotEmpty) {
      _markNotificationsAsSeen(_notificationsToMarkSeen, userId);
    }
    super.dispose();
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

  Future<void> _markNotificationsAsSeen(
    List<Map<String, dynamic>> notifications,
    String userId,
  ) async {
    final batch = FirebaseFirestore.instance.batch();

    for (final note in notifications) {
      final docId = note['id'];
      final seenBy = List<String>.from(note['seenBy'] ?? []);

      if (!seenBy.contains(userId)) {
        final docRef = FirebaseFirestore.instance
            .collection('groupnotifications')
            .doc(docId);
        batch.update(docRef, {
          'seenBy': FieldValue.arrayUnion([userId]),
        });
      }
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(body: Center(child: Text('User not logged in.')));
    }

    final notificationsAsync = ref.watch(
      groupNotificationProvider(widget.groupId),
    );

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

        if (!hasMarkedSeen) {
          _notificationsToMarkSeen = notifications;
          hasMarkedSeen = true;
        }

        if (notifications.isEmpty) {
          return Scaffold(
            appBar: _buildAppBar(),
            body: const Center(
              child: Text("You don't have any notifications."),
            ),
          );
        }

        final allSelected = selectedIds.length == notifications.length;

        return Scaffold(
          appBar: _buildAppBar(
            showDelete: selectedIds.isNotEmpty,
            onDelete: () => _deleteSelected(notifications),
          ),
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
                        label: Text(
                          allSelected ? 'Unselect All' : 'Select All',
                        ),
                        onPressed: () {
                          setState(() {
                            if (allSelected) {
                              selectedIds.clear();
                            } else {
                              selectedIds = {
                                for (var note in notifications)
                                  note['id'] as String? ?? '',
                              }..removeWhere((id) => id.isEmpty);
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  const Divider(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final note = notifications[index];
                        final noteId = note['id'] ?? '';
                        final action = note['action'] ?? 'Unknown action';
                        final name = note['name'] ?? 'Unknown user';
                        final timestamp = note['createdAt'];
                        final seenBy = List<String>.from(note['seenBy'] ?? []);
                        final isSeen = seenBy.contains(userId);

                        DateTime createdAt;
                        if (timestamp is Timestamp) {
                          createdAt = timestamp.toDate();
                        } else if (timestamp is DateTime) {
                          createdAt = timestamp;
                        } else {
                          createdAt = DateTime.now();
                        }

                        final formattedDate = DateFormat.yMMMEd()
                            .add_jm()
                            .format(createdAt);
                        final isSelected = selectedIds.contains(noteId);

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Stack(
                            children: [
                              Card(
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
                                      });
                                    },
                                  ),
                                  title: Text(
                                    '$name - "$action"',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    formattedDate,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ),
                              if (!isSeen)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
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
          ),
        );
      },
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  AppBar _buildAppBar({bool showDelete = false, VoidCallback? onDelete}) {
    final canDelete =
        (userRole == 'admin' || userRole == 'co-admin') && showDelete;

    return AppBar(
      title: const Text(
        "Group Notification",
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.green,
      centerTitle: true,
      actions: [
        if (canDelete)
          IconButton(icon: const Icon(Icons.delete), onPressed: onDelete),
      ],
    );
  }

  Future<void> _deleteSelected(List<Map<String, dynamic>> notifications) async {
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
            .collection('groupnotifications')
            .doc(id)
            .delete();
      }
      setState(() {
        selectedIds.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notifications deleted')));
    }
  }
}
