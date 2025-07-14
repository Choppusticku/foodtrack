import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:foodtrack/screens/calendar/calendar_screen.dart';
import 'package:foodtrack/screens/group/group_screen.dart';
import 'package:foodtrack/screens/inventory/inventory_screen.dart';
import 'package:foodtrack/screens/inventory/add_item_screen.dart';
import 'package:foodtrack/screens/profile/profile_screen.dart';
import 'package:foodtrack/screens/recipe/recipe_generator_screen.dart';
import 'package:foodtrack/screens/analytics/analytics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 2;
  String? avatarFile;
  int _unreadCount = 0;

  final List<Widget> _pages = [
    const CalendarScreen(),
    const GroupScreen(),
    const AddItemScreen(),
    const InventoryScreen(),
    const RecipeGeneratorScreen(),
  ];

  final List<String> _titles = [
    "Calendar",
    "Group",
    "Add Item",
    "Inventory",
    "Recipes",
  ];

  @override
  void initState() {
    super.initState();
    _loadUserAvatar();
    _listenToUnreadNotifications();
  }

  Future<void> _loadUserAvatar() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() {
      avatarFile = doc.data()?['avatar'];
    });
  }

  void _listenToUnreadNotifications() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _unreadCount = snapshot.docs.length;
      });
    });
  }

  Future<String> getGroupName(String groupId, Map<String, String> cache) async {
    if (cache.containsKey(groupId)) return cache[groupId]!;
    final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(groupId).get();
    final name = groupDoc.data()?['name'] ?? 'Unknown Group';
    cache[groupId] = name;
    return name;
  }

  void _showNotificationDialog(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final Map<String, String> groupNameCache = {};

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            height: 400,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Recent Notifications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () async {
                        final snapshot = await FirebaseFirestore.instance
                            .collection('notifications')
                            .doc(uid)
                            .collection('items')
                            .where('isRead', isEqualTo: false)
                            .get();

                        for (var doc in snapshot.docs) {
                          await doc.reference.update({'isRead': true});
                        }

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("All marked as read")),
                        );
                      },
                      child: const Text("Mark all as read"),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(uid)
                        .collection('items')
                        .orderBy('timestamp', descending: true)
                        .limit(10)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) return const Center(child: Text("No notifications."));

                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final groupId = data['groupId'];
                          final message = data['message'] ?? 'No message';
                          final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                          final isRead = data['isRead'] ?? false;
                          final timeLabel = timestamp != null
                              ? DateFormat('dd MMM, hh:mm a').format(timestamp)
                              : 'Unknown time';

                          return FutureBuilder<String>(
                            future: groupId != null
                                ? getGroupName(groupId, groupNameCache)
                                : Future.value('Unknown Group'),
                            builder: (context, groupSnap) {
                              final groupName = groupSnap.connectionState == ConnectionState.done
                                  ? groupSnap.data ?? 'Unknown Group'
                                  : 'Loading group...';

                              return ListTile(
                                leading: Icon(Icons.notifications,
                                    color: isRead ? Colors.grey : Colors.orange),
                                title: Text(message),
                                subtitle: Text("Group: $groupName\n$timeLabel"),
                                isThreeLine: true,
                                tileColor: isRead ? Colors.grey[100] : null,
                                onTap: () => docs[index].reference.update({'isRead': true}),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openProfilePanel(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, _, __) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, _, __) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.7,
              child: const Material(
                elevation: 12,
                child: ProfileScreen(),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _loadUserAvatar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () => _showNotificationDialog(context),
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
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
          GestureDetector(
            onTap: () => _openProfilePanel(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: (avatarFile != null && avatarFile!.isNotEmpty)
                    ? AssetImage('assets/avatars/$avatarFile') as ImageProvider
                    : null,
                child: (avatarFile == null || avatarFile!.isEmpty)
                    ? const Icon(Icons.person, size: 16)
                    : null,
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.green),
              child: Text("ShelfSync Menu", style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.analytics), // ✅ New Analytics Option
              title: const Text("Analytics"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text("Notifications"),
              onTap: () {
                Navigator.pop(context);
                _showNotificationDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Profile"),
              onTap: () {
                Navigator.pop(context);
                _openProfilePanel(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
            ),
          ],
        ),
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Calendar"),
          const BottomNavigationBarItem(icon: Icon(Icons.groups), label: "Group"),
          BottomNavigationBarItem(
            icon: Container(
              margin: const EdgeInsets.only(top: 2),
              child: Icon(Icons.add_circle, size: 50, color: Colors.green.shade700),
            ),
            label: "",
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: "Inventory"),
          const BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: "Recipes"),
        ],
      ),
    );
  }
}
