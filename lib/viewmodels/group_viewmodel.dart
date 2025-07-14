import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/group_service.dart';

class GroupViewModel extends ChangeNotifier {
  final GroupService _groupService = GroupService();

  String? currentGroupId;
  List<Map<String, dynamic>> userGroups = [];
  String role = '';
  bool loading = true;

  GroupViewModel() {
    loadUserGroups();
  }

  Future<void> loadUserGroups() async {
    loading = true;
    notifyListeners();

    final groups = await _groupService.getUserGroups();
    final groupId = await _groupService.getCurrentGroupId();

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

    userGroups = groups;
    currentGroupId = selectedGroupId;
    role = detectedRole;
    loading = false;
    notifyListeners();
  }

  Future<void> switchGroup(String newId) async {
    await _groupService.switchGroup(newId);
    await loadUserGroups();
  }

  Future<void> approveRequest(String uid) async {
    if (currentGroupId == null) return;
    await _groupService.approveJoinRequest(currentGroupId!, uid);
    await loadUserGroups();
  }

  Future<void> updateUserRole(String uid, String newRole) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'role': newRole});
    await loadUserGroups();
  }

  Future<void> removeUser(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
    await loadUserGroups();
  }

  Future<void> deleteCurrentGroup(BuildContext context) async {
    if (currentGroupId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Group"),
        content: const Text("Are you sure you want to delete this group?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _groupService.deleteGroup(currentGroupId!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Group deleted successfully")),
      );
      await loadUserGroups();
    }
  }

  Future<void> createGroup(String name, String desc) async {
    if (name.trim().isEmpty) return;
    await _groupService.createGroup(name.trim(), description: desc.trim());
    await loadUserGroups();
  }

  Future<void> joinGroup(String code, BuildContext context) async {
    if (code.trim().isEmpty) return;
    try {
      await _groupService.joinGroup(code.trim());
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Join request sent")));
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // ✅ Leave current group (for members only)
  Future<void> leaveCurrentGroup(BuildContext context) async {
    if (currentGroupId == null || role == 'Owner') return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Leave Group"),
        content: const Text("Are you sure you want to leave this group?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Leave")),
        ],
      ),
    );

    if (confirm == true) {
      await _groupService.leaveGroup(currentGroupId!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You have left the group")),
      );
      await loadUserGroups();
    }
  }
}
