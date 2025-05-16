import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:costmate/auth/auth_service.dart';
import 'package:costmate/auth/signin_screen.dart';
import 'package:costmate/screens/group_screen.dart';
import 'package:costmate/screens/myhome_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  AppBar _currentAppBar = AppBar(title: Text('Home')); // Default AppBar
  String name = '';
  String email = '';
  String? photoURL;
  String _selectedDrawerItem = 'Home';
  String? _selectedDrawerGroupId;
  int _selectedIndex = 0;
  String? selectedGroupId;
  String? selectedGroupName;
  bool? isSelectedAdmin;

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

    _screens = [
      MyHomeScreen(onUpdateAppBar: _updateAppBar, onGroupTap: _onGroupTap),
      GroupScreen(onUpdateAppBar: _updateAppBar),
    ];

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _getUserInfo(user);
        _loadCreatedAndJoinedGroups(user.uid);
      }
    });
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

  Future<void> _getUserInfo(User user) async {
    try {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance
              .collection("users")
              .doc(user.uid)
              .get();

      if (userDoc.exists && userDoc.data() != null) {
        setState(() {
          name = userDoc["name"] ?? user.displayName ?? "No Name";
          email = userDoc["email"] ?? user.email ?? "No Email";
          photoURL = userDoc["photoURL"] ?? user.photoURL ?? "";
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching user info: $e");
      }
    }
  }

  Future<void> _loadCreatedAndJoinedGroups(String userId) async {
    try {
      final createdSnapshot =
          await FirebaseFirestore.instance
              .collection('groups')
              .where('createdBy', isEqualTo: userId)
              .get();

      List<Map<String, dynamic>> created =
          createdSnapshot.docs.map((doc) {
            return {
              'groupId': doc.id,
              'groupName': doc['groupName'],
              'isAdmin': true,
            };
          }).toList();

      List<String> createdIds =
          created.map((g) => g['groupId'] as String).toList();

      // Groups where the user is a member (search in top-level groupmembers collection)
      final joinedSnapshot =
          await FirebaseFirestore.instance
              .collection('groupmembers')
              .where('userId', isEqualTo: userId)
              .get();

      List<Map<String, dynamic>> joined = [];

      for (var doc in joinedSnapshot.docs) {
        final groupId = doc['groupId'] as String;

        if (createdIds.contains(groupId)) continue;

        final groupDoc =
            await FirebaseFirestore.instance
                .collection('groups')
                .doc(groupId)
                .get();

        if (!groupDoc.exists) continue;

        joined.add({
          'groupId': groupId,
          'groupName': groupDoc['groupName'],
          'isAdmin': false,
        });
      }

      setState(() {
        createdGroups = created;
        joinedGroups = joined;
        _isCreatedExpanded = true; // Automatically expand to see groups
        _isJoinedExpanded = true;
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error loading groups: $e");
      }
    }
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

  @override
  Widget build(BuildContext context) {
    bool hasCreatedGroups = createdGroups.isNotEmpty;
    bool hasJoinedGroups = joinedGroups.isNotEmpty;

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
                              (photoURL != null && photoURL!.isNotEmpty)
                                  ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: photoURL!,
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
                        _selectedDrawerGroupId = null; // ✅ Deselect group
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
                                  group['groupId']; // ✅ FIXED

                              return ListTile(
                                title: Text(group['groupName']),
                                selected: isSelected,
                                selectedTileColor: Colors.green.shade100,
                                onTap: () {
                                  setState(() {
                                    _selectedIndex = 1;
                                    _selectedDrawerGroupId = group['groupId'];
                                    _selectedDrawerItem = '';
                                    selectedGroupId = group['groupId'];
                                    selectedGroupName = group['groupName'];
                                    isSelectedAdmin = group['isAdmin'];

                                    // Update the _screens[1] with new GroupScreen
                                    _screens[1] = GroupScreen(
                                      key: ValueKey(selectedGroupId),
                                      onUpdateAppBar: _updateAppBar,
                                      groupId: selectedGroupId,
                                      groupName: selectedGroupName,
                                      isAdmin: isSelectedAdmin,
                                    );
                                  });
                                  Navigator.pop(context); // Close drawer
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
                                  group['groupId']; // ✅ FIXED

                              return ListTile(
                                title: Text(group['groupName']),
                                selected: isSelected,
                                selectedTileColor: Colors.green.shade100,
                                onTap: () {
                                  setState(() {
                                    _selectedIndex = 1;
                                    _selectedDrawerGroupId = group['groupId'];
                                    _selectedDrawerItem = '';
                                    selectedGroupId = group['groupId'];
                                    selectedGroupName = group['groupName'];
                                    isSelectedAdmin = group['isAdmin'];

                                    // Update the _screens[1] with new GroupScreen
                                    _screens[1] = GroupScreen(
                                      key: ValueKey(selectedGroupId),
                                      onUpdateAppBar: _updateAppBar,
                                      groupId: selectedGroupId,
                                      groupName: selectedGroupName,
                                      isAdmin: isSelectedAdmin,
                                    );
                                  });
                                  Navigator.pop(context); // Close drawer
                                },
                              );
                            }).toList(),
                      ),
                    ),
                  if (hasJoinedGroups && _isJoinedExpanded)
                    const Divider(height: 5),

                  const ListTile(
                    leading: Icon(Icons.feedback),
                    title: Text('Feedback'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.notifications),
                    title: Text('Notification'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.settings),
                    title: Text('Settings'),
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
  }
}
