// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MemberTab extends StatefulWidget {
  final String groupId;
  const MemberTab({super.key, required this.groupId});

  @override
  State<MemberTab> createState() => _MemberTabState();
}

class _MemberTabState extends State<MemberTab> {
  String? currentUserRole;

  @override
  void initState() {
    super.initState();
    // _fetchCurrentUserRole();
  }
  
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }

  // Future<void> _fetchCurrentUserRole() async {
  //   final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  //   if (currentUserId != null) {
  //     for (var member in widget.members) {
  //       if (member['uid'] == currentUserId) {
  //         setState(() {
  //           currentUserRole = member['role'];
  //         });
  //         break;
  //       }
  //     }
  //   }
  // }

  // void _onMemberMenuSelected(String choice) {
  //   switch (choice) {
  //     case 'Add Expense':
  //       break;
  //     case 'Add TODO List':
  //       break;
  //   }
  // }

  // @override
  // Widget build(BuildContext context) {
  //   final isWide = MediaQuery.of(context).size.width > 600;

  //   if (widget.members.isEmpty) {
  //     return const Center(child: Text('No members found.'));
  //   }

  //   final admins = widget.members.where((m) => m['role'] == 'admin').toList();
  //   final coAdmins =
  //       widget.members.where((m) => m['role'] == 'co-admin').toList();
  //   final normalMembers =
  //       widget.members
  //           .where((m) => m['role'] != 'admin' && m['role'] != 'co-admin')
  //           .toList();

  //   final List<Widget> listItems = [];

  //   if (admins.isNotEmpty) {
  //     listItems.add(_buildSectionHeader('Admin'));
  //     listItems.addAll(admins.map((m) => _buildMemberTile(m, isWide)));
  //   }

  //   if (coAdmins.isNotEmpty) {
  //     listItems.add(_buildSectionHeader('Co-Admin'));
  //     listItems.addAll(coAdmins.map((m) => _buildMemberTile(m, isWide)));
  //   }

  //   if (normalMembers.isNotEmpty) {
  //     listItems.add(_buildSectionHeader('Members'));
  //     listItems.addAll(normalMembers.map((m) => _buildMemberTile(m, isWide)));
  //   }

  //   return ListView(
  //     padding: const EdgeInsets.symmetric(vertical: 8),
  //     children: listItems,
  //   );
  // }

  // Widget _buildSectionHeader(String title) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //     child: Row(
  //       children: [
  //         const Expanded(
  //           child: Divider(thickness: 1, color: Colors.grey, endIndent: 8),
  //         ),
  //         Text(
  //           title,
  //           style: const TextStyle(
  //             fontSize: 14,
  //             fontWeight: FontWeight.bold,
  //             color: Colors.grey,
  //           ),
  //         ),
  //         const Expanded(
  //           child: Divider(thickness: 1, color: Colors.grey, indent: 8),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildMemberTile(Map<String, dynamic> member, bool isWide) {
  //   final name = member['name'] ?? 'Unnamed';
  //   final email = member['email'] ?? '';
  //   final role = member['role'] ?? 'Member';

  //   return Center(
  //     child: Container(
  //       width: isWide ? 600 : double.infinity,
  //       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  //       child: Card(
  //         margin: const EdgeInsets.symmetric(vertical: 6),
  //         child: Stack(
  //           children: [
  //             Padding(
  //               padding: const EdgeInsets.all(8.0),
  //               child: ListTile(
  //                 leading: const Icon(Icons.person),
  //                 title: Text(
  //                   name,
  //                   style: const TextStyle(
  //                     fontSize: 16,
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                 ),
  //                 subtitle: Text(email, style: const TextStyle(fontSize: 13)),
  //               ),
  //             ),
  //             if ((currentUserRole == 'admin' ||
  //                     currentUserRole == 'co-admin') &&
  //                 role != 'admin')
  //               Positioned(
  //                 top: 0,
  //                 right: 0,
  //                 child: PopupMenuButton<String>(
  //                   icon: const Icon(Icons.more_vert),
  //                   onSelected: (choice) => _onMemberMenuSelected(choice),
  //                   itemBuilder:
  //                       (context) => const [
  //                         PopupMenuItem<String>(
  //                           value: 'Edit',
  //                           child: Text('Edit'),
  //                         ),
  //                         PopupMenuItem<String>(
  //                           value: 'Remove',
  //                           child: Text('Remove'),
  //                         ),
  //                       ],
  //                 ),
  //               ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }
}
