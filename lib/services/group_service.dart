import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupService {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final usersRef = FirebaseFirestore.instance.collection('users');
  final groupsRef = FirebaseFirestore.instance.collection('groups');

  // ✅ Create new group and update user's group list
  Future<void> createGroup(String groupName, {String? description}) async {
    final newGroup = await groupsRef.add({
      'name': groupName,
      'description': description ?? '',
      'createdAt': Timestamp.now(),
      'ownerId': uid,
    });

    final groupData = {
      'id': newGroup.id,
      'name': groupName,
      'isOwner': true,
    };

    final userDoc = await usersRef.doc(uid).get();
    final List<dynamic> existingGroups = userDoc.data()?['groups'] ?? [];

    await usersRef.doc(uid).set({
      'groups': [...existingGroups, groupData],
      'currentGroupId': newGroup.id,
      'role': 'Owner',
    }, SetOptions(merge: true));
  }

  // ✅ Send join request to group
  Future<void> joinGroup(String groupCode) async {
    final groupDoc = await groupsRef.doc(groupCode).get();
    if (!groupDoc.exists) throw Exception("Group not found");

    final ownerId = groupDoc['ownerId'];
    final currentUser = FirebaseAuth.instance.currentUser;

    await groupsRef.doc(groupCode).collection('joinRequests').doc(uid).set({
      'requestedAt': Timestamp.now(),
      'uid': uid,
    });

    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(ownerId)
        .collection('items')
        .add({
      'type': 'join_request',
      'message':
      "${currentUser?.email ?? 'A user'} wants to join '${groupDoc['name']}'",
      'groupId': groupCode,
      'timestamp': Timestamp.now(),
      'seen': false,
    });
  }

  // ✅ Get groups properly for both owners and members
  Future<List<Map<String, dynamic>>> getUserGroups() async {
    final userDoc = await usersRef.doc(uid).get();
    final userData = userDoc.data();
    if (userData == null) return [];

    final role = userData['role'] ?? 'Member';

    if (role == 'Owner') {
      final ownerGroups =
      await groupsRef.where('ownerId', isEqualTo: uid).get();

      return ownerGroups.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed Group',
          'isOwner': true,
        };
      }).toList();
    } else {
      final List<dynamic> groupList = userData['groups'] ?? [];
      return groupList.map<Map<String, dynamic>>((g) => {
        'id': g['id'],
        'name': g['name'] ?? 'Unnamed',
        'isOwner': g['isOwner'] ?? false,
      }).toList();
    }
  }

  // ✅ Get current selected group
  Future<String?> getCurrentGroupId() async {
    final doc = await usersRef.doc(uid).get();
    return doc.data()?['currentGroupId'];
  }

  // ✅ Switch active group
  Future<void> switchGroup(String groupId) async {
    await usersRef.doc(uid).update({'currentGroupId': groupId});
  }

  // ✅ Get pending join requests
  Future<List<Map<String, dynamic>>> getJoinRequests(String groupId) async {
    final query =
    await groupsRef.doc(groupId).collection('joinRequests').get();
    return query.docs
        .map((doc) => doc.data())
        .cast<Map<String, dynamic>>()
        .toList();
  }

  // ✅ Approve a pending request and update user's group list
  Future<void> approveJoinRequest(String groupId, String targetUid) async {
    final userDoc = await usersRef.doc(targetUid).get();
    final userGroups = List.from(userDoc.data()?['groups'] ?? []);

    final groupDoc = await groupsRef.doc(groupId).get();
    final groupName = groupDoc.data()?['name'];

    userGroups.add({
      'id': groupId,
      'name': groupName,
      'isOwner': false,
    });

    final userData = userDoc.data();
    final currentGroupId = userData?['currentGroupId'];

    await usersRef.doc(targetUid).update({
      'groups': userGroups,
      if (currentGroupId == null) 'currentGroupId': groupId,
    });

    await groupsRef
        .doc(groupId)
        .collection('joinRequests')
        .doc(targetUid)
        .delete();
  }

  // ✅ Delete group and clean up references
  Future<void> deleteGroup(String groupId) async {
    await groupsRef.doc(groupId).delete();

    final usersSnapshot = await usersRef.get();
    for (final userDoc in usersSnapshot.docs) {
      final userData = userDoc.data();
      final List groups = userData['groups'] ?? [];

      final updatedGroups = List<Map<String, dynamic>>.from(groups)
        ..removeWhere((g) => g['id'] == groupId);

      await usersRef.doc(userDoc.id).update({
        'groups': updatedGroups,
        if ((userData['currentGroupId'] ?? '') == groupId)
          'currentGroupId': updatedGroups.isNotEmpty ? updatedGroups[0]['id'] : null,
      });
    }

    final joinReqs =
    await groupsRef.doc(groupId).collection('joinRequests').get();
    for (final req in joinReqs.docs) {
      await req.reference.delete();
    }
  }

  // ✅ Leave group (members only)
  Future<void> leaveGroup(String groupId) async {
    final userDoc = await usersRef.doc(uid).get();
    final userData = userDoc.data();
    if (userData == null) return;

    final List<dynamic> groupList = List.from(userData['groups'] ?? []);
    groupList.removeWhere((g) => g['id'] == groupId);

    final currentGroupId = userData['currentGroupId'];

    await usersRef.doc(uid).update({
      'groups': groupList,
      if (currentGroupId == groupId)
        'currentGroupId': groupList.isNotEmpty ? groupList[0]['id'] : null,
    });
  }
}
