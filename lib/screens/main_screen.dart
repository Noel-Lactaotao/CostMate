import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:costmate/auth/auth_service.dart';
import 'package:costmate/auth/signin_screen.dart';
import 'package:costmate/providers/user_and_group_providers.dart';
import 'package:costmate/screens/group_screen.dart';
import 'package:costmate/screens/invitation_screen.dart';
import 'package:costmate/screens/myhome_screen.dart';
import 'package:costmate/screens/usernotification_screen.dart';
import 'package:costmate/screens/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  AppBar _currentAppBar = AppBar(
    title: const Text(
      "CostMate",
      style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
    ),
    backgroundColor: Colors.green,
    centerTitle: true,
    actions: [
      PopupMenuButton<String>(
        icon: const Icon(Icons.add),
        itemBuilder: (BuildContext context) {
          return ['Create Group', 'Join Group'].map((String choice) {
            return PopupMenuItem<String>(value: choice, child: Text(choice));
          }).toList();
        },
      ),
    ],
  ); // Default AppBar
  String name = '';
  String email = '';
  String? photoURL;
  String _selectedDrawerItem = 'Home';
  String? _selectedDrawerGroupId;
  int _selectedIndex = 0;
  String? selectedGroupId;
  String? selectedGroupName;
  bool? isSelectedAdmin;
  int _unseenInvitationCount = 0;
  int _unseenUserNotificationCount = 0;

  List<Map<String, dynamic>> createdGroups =
      []; // Make this dynamic to include isAdmin
  List<Map<String, dynamic>> joinedGroups = [];

  bool _isCreatedExpanded = false;
  bool _isJoinedExpanded = false;

  final AuthService _auth = AuthService();
  List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _listenToInvitationCount();
    _listenToUserNotificationCount();

    _screens = [
      MyHomeScreen(onUpdateAppBar: _updateAppBar, onGroupTap: _onGroupTap),
      GroupScreen(onUpdateAppBar: _updateAppBar),
      InvitationScreen(onUpdateAppBar: _updateAppBar, onGroupTap: _onGroupTap),
      UserNotificationScreen(
        onUpdateAppBar: _updateAppBar,
        onGroupTap: _onGroupTap,
      ),
      SettingsScreen(onUpdateAppBar: _updateAppBar, onGroupTap: _onGroupTap),
    ];
  }

  void _onGroupTap(Map<String, dynamic> group) {
    setState(() {
      _selectedIndex = 1; // Switch to GroupScreen
      _selectedDrawerGroupId = group['groupId'];
      _selectedDrawerItem = '';
      selectedGroupId = group['groupId'];
      selectedGroupName = group['groupName'];
      isSelectedAdmin = group['isAdmin'];

      // Update _screens[1] with the new GroupScreen
      _screens[1] = GroupScreen(
        onUpdateAppBar: _updateAppBar,
        groupId: selectedGroupId,
        groupName: selectedGroupName,
        isAdmin: isSelectedAdmin,
      );
    });
  }

  void _updateAppBar(AppBar appBar) {
    setState(() {
      _currentAppBar = appBar;
    });
  }

  void _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
      );
    }
  }

  Future<void> _showLogoutConfirmation() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Log Out"),
          content: const Text("Are you sure you want to log out?"),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
              child: const Text("Log Out"),
            ),
          ],
        );
      },
    );
  }

  void _listenToInvitationCount() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    FirebaseFirestore.instance
        .collection('groupInvitations')
        .where('invitedUserId', isEqualTo: userId)
        .where('isSeen', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          setState(() {
            _unseenInvitationCount = snapshot.docs.length;
          });
        });
  }

  void _listenToUserNotificationCount() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    FirebaseFirestore.instance
        .collection('usernotifications')
        .where('userId', isEqualTo: userId)
        .where('isSeen', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          setState(() {
            _unseenUserNotificationCount = snapshot.docs.length;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final userInfoAsync = ref.watch(userInfoProvider);

    return userInfoAsync.when(
      data: (userInfo) {
        final name = userInfo.name;
        final email = userInfo.email;
        final photoURL = userInfo.photoURL;
        final createdGroups = userInfo.createdGroups;
        final joinedGroups = userInfo.joinedGroups;

        final bool hasCreatedGroups = createdGroups.isNotEmpty;
        final bool hasJoinedGroups = joinedGroups.isNotEmpty;

        return Scaffold(
          drawer: Drawer(
            child: Column(
              children: [
                // Scrollable content
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      Container(
                        height: 250,
                        color: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.grey[200],
                              child:
                                  (photoURL.isNotEmpty)
                                      ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: photoURL,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          placeholder:
                                              (context, url) =>
                                                  CircularProgressIndicator(),
                                          errorWidget:
                                              (context, url, error) =>
                                                  Icon(Icons.person, size: 40),
                                        ),
                                      )
                                      : Icon(Icons.person, size: 40),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(email, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),

                      ListTile(
                        leading: const Icon(Icons.home),
                        title: const Text('Home'),
                        selected: _selectedDrawerItem == 'Home',
                        selectedTileColor: Colors.green.shade100,
                        onTap: () {
                          setState(() {
                            _selectedIndex = 0;
                            _selectedDrawerItem = 'Home';
                            _selectedDrawerGroupId = null;
                          });
                          Navigator.pop(context);
                        },
                      ),

                      if (hasCreatedGroups)
                        ListTile(
                          leading: const Icon(Icons.group),
                          title: const Text('Created Groups'),
                          trailing: Icon(
                            _isCreatedExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          onTap: () {
                            setState(() {
                              _isCreatedExpanded = !_isCreatedExpanded;
                            });
                          },
                        ),
                      if (_isCreatedExpanded)
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Column(
                            children:
                                createdGroups.map((group) {
                                  final bool isSelected =
                                      _selectedDrawerGroupId ==
                                      group['groupId'];

                                  return ListTile(
                                    title: Text(group['groupName']),
                                    selected: isSelected,
                                    selectedTileColor: Colors.green.shade100,
                                    onTap: () {
                                      setState(() {
                                        _selectedIndex = 1;
                                        _selectedDrawerGroupId =
                                            group['groupId'];
                                        _selectedDrawerItem = '';
                                        selectedGroupId = group['groupId'];
                                        selectedGroupName = group['groupName'];
                                        isSelectedAdmin = group['isAdmin'];

                                        _screens[1] = GroupScreen(
                                          key: ValueKey(selectedGroupId),
                                          onUpdateAppBar: _updateAppBar,
                                          groupId: selectedGroupId,
                                          groupName: selectedGroupName,
                                          isAdmin: isSelectedAdmin,
                                        );
                                      });
                                      Navigator.pop(context);
                                    },
                                  );
                                }).toList(),
                          ),
                        ),
                      if (hasCreatedGroups && _isCreatedExpanded)
                        const Divider(height: 5),

                      if (hasJoinedGroups)
                        ListTile(
                          leading: const Icon(Icons.group),
                          title: const Text('Joined Groups'),
                          trailing: Icon(
                            _isJoinedExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          onTap: () {
                            setState(() {
                              _isJoinedExpanded = !_isJoinedExpanded;
                            });
                          },
                        ),
                      if (_isJoinedExpanded)
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Column(
                            children:
                                joinedGroups.map((group) {
                                  final bool isSelected =
                                      _selectedDrawerGroupId ==
                                      group['groupId'];

                                  return ListTile(
                                    title: Text(group['groupName']),
                                    selected: isSelected,
                                    selectedTileColor: Colors.green.shade100,
                                    onTap: () {
                                      setState(() {
                                        _selectedIndex = 1;
                                        _selectedDrawerGroupId =
                                            group['groupId'];
                                        _selectedDrawerItem = '';
                                        selectedGroupId = group['groupId'];
                                        selectedGroupName = group['groupName'];
                                        isSelectedAdmin = group['isAdmin'];

                                        _screens[1] = GroupScreen(
                                          key: ValueKey(selectedGroupId),
                                          onUpdateAppBar: _updateAppBar,
                                          groupId: selectedGroupId,
                                          groupName: selectedGroupName,
                                          isAdmin: isSelectedAdmin,
                                        );
                                      });
                                      Navigator.pop(context);
                                    },
                                  );
                                }).toList(),
                          ),
                        ),
                      if (hasJoinedGroups && _isJoinedExpanded)
                        const Divider(height: 5),
                      ListTile(
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.email),
                            if (_unseenInvitationCount > 0)
                              Positioned(
                                right: -6,
                                top: -6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                    minHeight: 20,
                                  ),
                                  child: Text(
                                    '$_unseenInvitationCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: const Text('Invitation'),
                        selected: _selectedDrawerItem == 'Invitation',
                        selectedTileColor: Colors.green.shade100,
                        onTap: () {
                          setState(() {
                            _selectedIndex = 2;
                            _selectedDrawerItem = 'Invitation';
                            _selectedDrawerGroupId = null;
                          });
                          Navigator.pop(context);
                        },
                      ),

                      ListTile(
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications),
                            if (_unseenUserNotificationCount > 0)
                              Positioned(
                                right: -6,
                                top: -6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                    minHeight: 20,
                                  ),
                                  child: Text(
                                    '$_unseenUserNotificationCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: const Text('Notification'),
                        selected: _selectedDrawerItem == 'Notification',
                        selectedTileColor: Colors.green.shade100,
                        onTap: () {
                          setState(() {
                            _selectedIndex = 3;
                            _selectedDrawerItem = 'Notification';
                            _selectedDrawerGroupId = null;
                          });
                          Navigator.pop(context);
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.settings),
                        title: const Text('Settings'),
                        selected: _selectedDrawerItem == 'Settings',
                        selectedTileColor: Colors.green.shade100,
                        onTap: () {
                          setState(() {
                            _selectedIndex = 4;
                            _selectedDrawerItem = 'Settings';
                            _selectedDrawerGroupId = null;
                          });
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: _showLogoutConfirmation,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size.fromHeight(45),
                    ),
                  ),
                ),
              ],
            ),
          ),
          appBar: _currentAppBar,
          body: _screens[_selectedIndex],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Error: $error')),
    );
  }
}
