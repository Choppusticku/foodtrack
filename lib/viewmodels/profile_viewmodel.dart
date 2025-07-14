import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileViewModel extends ChangeNotifier {
  final nameCtrl = TextEditingController();
  String email = '';
  String avatarFile = '';
  bool loading = true;

  final uid = FirebaseAuth.instance.currentUser!.uid;

  Future<void> init() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();

    if (data != null) {
      nameCtrl.text = data['displayName'] ?? '';
      email = data['email'] ?? '';
      avatarFile = data['avatar'] ?? '';
    }

    loading = false;
    notifyListeners();
  }

  String? get avatarPath => avatarFile.isNotEmpty ? 'assets/avatars/$avatarFile' : null;

  Future<void> updateName(BuildContext context) async {
    final newName = nameCtrl.text.trim();
    if (newName.isEmpty) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({'displayName': newName});
    await FirebaseAuth.instance.currentUser!.updateDisplayName(newName);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name updated")));
  }

  Future<void> updatePassword(BuildContext context, String newPassword) async {
    try {
      await FirebaseAuth.instance.currentUser!.updatePassword(newPassword);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated successfully")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> updateAvatar(String fileName) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'avatar': fileName});
    avatarFile = fileName;
    notifyListeners();
  }

  void disposeControllers() {
    nameCtrl.dispose();
  }
}
