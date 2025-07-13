import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:foodtrack/services/group_service.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final GroupService groupService = GroupService();

  String? currentGroupId;
  List<Map<String, dynamic>> userGroups = [];
  String role = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final groups = await groupService.getUserGroups();
    final groupId = await groupService.getCurrentGroupId();

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get();

    final userData = userDoc.data();
    final List<Map<String, dynamic>> userGroupList =
    List<Map<String, dynamic>>.from(userData?['groups'] ?? []);

    final selectedGroupId =
        groupId ?? (userGroupList.isNotEmpty ? userGroupList[0]['id'] : null);

    String roleFromUserDoc = userData?['role'] ?? 'Member';
    String detectedRole = roleFromUserDoc;

    if (userGroupList.isNotEmpty && selectedGroupId != null) {
      final currentGroup = userGroupList.firstWhere(
            (g) => g['id'] == selectedGroupId,
        orElse: () => {},
      );
      if (currentGroup.isNotEmpty && currentGroup['isOwner'] == true) {
        detectedRole = 'Owner';
      } else {
        detectedRole = 'Member';
      }
    }

    setState(() {
      userGroups = groups;
      currentGroupId = selectedGroupId;
      role = detectedRole;
      loading = false;
    });
  }
  //test
  Future<void> _switchGroup(String newId) async {
    await groupService.switchGroup(newId);
    await _initData();
  }

  Future<void> _approveRequest(String uid) async {
    if (currentGroupId == null) return;
    await groupService.approveJoinRequest(currentGroupId!, uid);
    await _initData();
  }

  Future<void> _changeRole(String uid, String newRole) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'role': newRole});
    await _initData();
  }

  Future<void> _removeUser(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
    await _initData();
  }

  Future<void> _deleteGroup() async {
    if (currentGroupId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Group"),
        content: const Text(
            "Are you sure you want to delete this group? This action cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await groupService.deleteGroup(currentGroupId!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Group deleted successfully")),
      );
      await _initData();
    }
  }

  Future<void> _showCreateGroupDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding:
        MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Create New Group",
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Group Name")),
            TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: "Description")),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await groupService.createGroup(
                  nameCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                );
                Navigator.pop(context);
                await _initData();
              },
              child: const Text("Create"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showJoinGroupDialog() async {
    final codeCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding:
        MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Join Group",
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: codeCtrl,
              decoration:
              const InputDecoration(labelText: "Enter Group Code"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                if (codeCtrl.text.trim().isEmpty) return;
                try {
                  await groupService.joinGroup(codeCtrl.text.trim());
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Join request sent")));
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              },
              child: const Text("Send Request"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: currentGroupId == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(role == 'Owner'
                ? "You haven’t created a group yet."
                : "You're not in any group."),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: role == 'Owner'
                  ? _showCreateGroupDialog
                  : _showJoinGroupDialog,
              child: Text(role == 'Owner'
                  ? "Create Group"
                  : "Request to Join"),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: currentGroupId,
              decoration:
              const InputDecoration(labelText: "Switch Group"),
              items:
              userGroups.map<DropdownMenuItem<String>>((group) {
                return DropdownMenuItem<String>(
                  value: group['id'] as String,
                  child: Text(group['name'] +
                      (group['isOwner'] ? " (Owner)" : "")),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) _switchGroup(value);
              },
            ),
            const SizedBox(height: 16),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('groups')
                  .doc(currentGroupId)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                if (!snapshot.data!.exists) {
                  return const Text("No group data available.");
                }

                final data = snapshot.data!.data()
                as Map<String, dynamic>? ?? {};
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    title: Text(data['name'] ?? 'Unnamed Group'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['description'] ?? 'No description'),
                        Row(
                          children: [
                            Text("ID: $currentGroupId", style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16),
                              tooltip: "Copy Group ID",
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: currentGroupId ?? ""));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Group ID copied to clipboard")),
                                );
                              },
                            ),
                          ],
                        ),

                      ],
                    ),
                  ),
                );
              },
            ),

            if (role == 'Owner') ...[
              ElevatedButton.icon(
                onPressed: _deleteGroup,
                icon: const Icon(Icons.delete),
                label: const Text("Delete This Group"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (role == 'Owner') ...[
              const Text("Pending Join Requests",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              FutureBuilder<List<Map<String, dynamic>>>(
                future:
                groupService.getJoinRequests(currentGroupId!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Text("Loading requests...");
                  }
                  final requests = snapshot.data!;
                  if (requests.isEmpty) {
                    return const Text("No pending requests.");
                  }
                  return Column(
                    children: requests.map((req) {
                      final requesterUid = req['uid'];

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(requesterUid).get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox.shrink(); // Skip if not loaded
                          }

                          final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                          final displayName = userData['displayName'] ?? userData['email'] ?? requesterUid;
                          final avatar = userData['avatar'] ?? '';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: avatar.isNotEmpty
                                  ? AssetImage('assets/avatars/$avatar') as ImageProvider
                                  : const AssetImage('assets/avatars/blank.jpg'),
                              radius: 20,
                            ),
                            title: Text(displayName),
                            trailing: ElevatedButton(
                              onPressed: () => _approveRequest(requesterUid),
                              child: const Text("Approve"),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  );

                },
              ),
              const SizedBox(height: 20),
            ],

            const Text("Group Members",
                style: TextStyle(fontWeight: FontWeight.bold)),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final userData =
                  doc.data() as Map<String, dynamic>;
                  final groups = List<Map<String, dynamic>>.from(
                      userData['groups'] ?? []);
                  return groups.any(
                          (g) => g['id'] == currentGroupId);
                }).toList();

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final uid = data['uid'];
                    final name = data['displayName'] ?? data['email'];
                    final userRole = data['role'] ?? 'Member';

                    return ListTile(
                      title: Text(name),
                      subtitle: Text("UID: $uid • Role: $userRole"),
                      trailing: role == 'Owner' &&
                          uid != FirebaseAuth
                              .instance.currentUser!.uid
                          ? PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'Promote') {
                            _changeRole(uid, 'Owner');
                          } else if (action == 'Demote') {
                            _changeRole(uid, 'Member');
                          } else if (action == 'Remove') {
                            _removeUser(uid);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 'Promote',
                              child: Text("Make Owner")),
                          const PopupMenuItem(
                              value: 'Demote',
                              child: Text("Make Member")),
                          const PopupMenuItem(
                              value: 'Remove',
                              child: Text("Remove")),
                        ],
                      )
                          : null,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:
        role == 'Owner' ? _showCreateGroupDialog : _showJoinGroupDialog,
        child: const Icon(Icons.add),
        tooltip: role == 'Owner' ? "Create Group" : "Join Group",
      ),
    );
  }
}
