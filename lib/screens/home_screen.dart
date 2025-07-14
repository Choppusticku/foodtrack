import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:foodtrack/theme/app_theme.dart';
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
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            height: 500,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Notifications",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                          SnackBar(
                            content: const Text("All marked as read"),
                            backgroundColor: AppTheme.successColor,
                          ),
                        );
                      },
                      child: Text(
                        "Mark all read",
                        style: TextStyle(color: AppTheme.primaryColor),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
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
                      if (!snapshot.hasData) {
                        return Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_none,
                                size: 48,
                                color: AppTheme.textHint,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No notifications yet",
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: AppTheme.dividerColor,
                        ),
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

                              return Container(
                                color: isRead ? null : AppTheme.primaryColor.withOpacity(0.05),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isRead 
                                          ? AppTheme.textHint.withOpacity(0.1)
                                          : AppTheme.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Icon(
                                      Icons.notifications,
                                      color: isRead ? AppTheme.textHint : AppTheme.primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    message,
                                    style: TextStyle(
                                      fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        "Group: $groupName",
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        timeLabel,
                                        style: TextStyle(
                                          color: AppTheme.textHint,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () => docs[index].reference.update({'isRead': true}),
                                ),
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
                color: AppTheme.surfaceColor,
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => _showNotificationDialog(context),
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.errorColor,
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
              padding: const EdgeInsets.only(right: 16, left: 8),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.2),
                backgroundImage: (avatarFile != null && avatarFile!.isNotEmpty)
                    ? AssetImage('assets/avatars/$avatarFile') as ImageProvider
                    : null,
                child: (avatarFile == null || avatarFile!.isEmpty)
                    ? const Icon(Icons.person, size: 20, color: Colors.white)
                    : null,
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppTheme.surfaceColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.restaurant,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "ShelfSync",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    "Smart Food Tracking",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.analytics_outlined, color: AppTheme.primaryColor),
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
              leading: Icon(Icons.notifications_outlined, color: AppTheme.primaryColor),
              title: const Text("Notifications"),
              onTap: () {
                Navigator.pop(context);
                _showNotificationDialog(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.person_outline, color: AppTheme.primaryColor),
              title: const Text("Profile"),
              onTap: () {
                Navigator.pop(context);
                _openProfilePanel(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: AppTheme.errorColor),
              title: const Text("Logout"),
              textColor: AppTheme.errorColor,
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
        backgroundColor: AppTheme.surfaceColor,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textSecondary,
        elevation: 8,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: "Calendar",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: "Group",
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add, size: 28, color: Colors.white),
            ),
            label: "",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: "Inventory",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: "Recipes",
          ),
        ],
      ),
    );
  }
}
