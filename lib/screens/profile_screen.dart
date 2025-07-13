import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  Map<String, dynamic>? userData;
  bool loading = true;
  final nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    setState(() {
      userData = data;
      nameCtrl.text = data?['displayName'] ?? '';
      loading = false;
    });
  }

  Future<void> _updateName() async {
    final newName = nameCtrl.text.trim();
    if (newName.isEmpty) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({'displayName': newName});
    await FirebaseAuth.instance.currentUser!.updateDisplayName(newName);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Name updated")),
    );
  }

  Future<void> _updatePassword() async {
    final passCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Password"),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: "New Password"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPassword = passCtrl.text.trim();
              if (newPassword.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Password must be at least 6 characters.")),
                );
                return;
              }

              try {
                await FirebaseAuth.instance.currentUser!.updatePassword(newPassword);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Password updated successfully")),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAvatar(String fileName) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'avatar': fileName});
    _loadProfile();
  }

  void _showAvatarSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => GridView.builder(
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
        ),
        itemBuilder: (context, index) {
          final file = "${index + 1}.jpg";
          return GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _updateAvatar(file);
            },
            child: CircleAvatar(
              radius: 40,
              backgroundImage: AssetImage("assets/avatars/$file"),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading || userData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final email = userData!['email'] ?? '';
    final avatarFile = userData!['avatar'] ?? '';
    final avatarPath = avatarFile.isNotEmpty ? 'assets/avatars/$avatarFile' : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
          automaticallyImplyLeading: false
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _showAvatarSelector,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: avatarPath != null ? AssetImage(avatarPath) : null,
                child: avatarPath == null
                    ? const Icon(Icons.person, size: 50)
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            // Name field
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            const SizedBox(height: 12),

            // Email (readonly)
            TextFormField(
              initialValue: email,
              enabled: false,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _updateName,
              child: const Text("Save Name"),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _updatePassword,
              icon: const Icon(Icons.lock),
              label: const Text("Change Password"),
            ),
          ],
        ),
      ),
    );
  }
}
