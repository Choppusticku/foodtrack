import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../viewmodels/group_viewmodel.dart';

class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<GroupViewModel>(context);

    if (vm.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: vm.currentGroupId == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(vm.role == 'Owner'
                ? "You haven’t created a group yet."
                : "You're not in any group."),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                if (vm.role == 'Owner') {
                  _showCreateGroupDialog(context);
                } else {
                  _showJoinGroupDialog(context);
                }
              },
              child: Text(vm.role == 'Owner'
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
              value: vm.currentGroupId,
              decoration: const InputDecoration(labelText: "Switch Group"),
              items: vm.userGroups.map<DropdownMenuItem<String>>((group) {
                return DropdownMenuItem<String>(
                  value: group['id'] as String,
                  child: Text(group['name'] +
                      (group['isOwner'] ? " (Owner)" : "")),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) vm.switchGroup(value);
              },
            ),
            const SizedBox(height: 16),

            // Group Info
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('groups')
                  .doc(vm.currentGroupId)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                if (!snapshot.data!.exists) {
                  return const Text("No group data available.");
                }

                final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
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
                            Text("ID: ${vm.currentGroupId}",
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16),
                              tooltip: "Copy Group ID",
                              onPressed: () {
                                Clipboard.setData(ClipboardData(
                                    text: vm.currentGroupId ?? ""));
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(
                                    content: Text(
                                        "Group ID copied to clipboard")));
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

            if (vm.role == 'Owner') ...[
              ElevatedButton.icon(
                onPressed: () => vm.deleteCurrentGroup(context),
                icon: const Icon(Icons.delete),
                label: const Text("Delete This Group"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text("Pending Join Requests",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('join_requests')
                    .doc(vm.currentGroupId)
                    .get()
                    .then((doc) =>
                List<Map<String, dynamic>>.from(doc['requests'] ?? [])),
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
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(requesterUid)
                            .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox.shrink();
                          }
                          final userData =
                              snapshot.data!.data() as Map<String, dynamic>? ??
                                  {};
                          final displayName = userData['displayName'] ??
                              userData['email'] ??
                              requesterUid;
                          final avatar = userData['avatar'] ?? '';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: avatar.isNotEmpty
                                  ? AssetImage('assets/avatars/$avatar')
                              as ImageProvider
                                  : const AssetImage(
                                  'assets/avatars/blank.jpg'),
                              radius: 20,
                            ),
                            title: Text(displayName),
                            trailing: ElevatedButton(
                              onPressed: () =>
                                  vm.approveRequest(requesterUid),
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
                  return groups
                      .any((g) => g['id'] == vm.currentGroupId);
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
                      trailing: vm.role == 'Owner' &&
                          uid != FirebaseAuth
                              .instance.currentUser!.uid
                          ? PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'Promote') {
                            vm.updateUserRole(uid, 'Owner');
                          } else if (action == 'Demote') {
                            vm.updateUserRole(uid, 'Member');
                          } else if (action == 'Remove') {
                            vm.removeUser(uid);
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
        onPressed: () {
          if (vm.role == 'Owner') {
            _showCreateGroupDialog(context);
          } else {
            _showJoinGroupDialog(context);
          }
        },
        child: const Icon(Icons.add),
        tooltip: vm.role == 'Owner' ? "Create Group" : "Join Group",
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final vm = Provider.of<GroupViewModel>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
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
              onPressed: () {
                vm.createGroup(nameCtrl.text, descCtrl.text);
                Navigator.pop(context);
              },
              child: const Text("Create"),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinGroupDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    final vm = Provider.of<GroupViewModel>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
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
              onPressed: () {
                vm.joinGroup(codeCtrl.text, context);
              },
              child: const Text("Send Request"),
            ),
          ],
        ),
      ),
    );
  }
}
