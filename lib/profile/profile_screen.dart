import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/profile_viewmodel.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late ProfileViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = context.read<ProfileViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) => vm.init());
  }

  @override
  void dispose() {
    vm.disposeControllers();
    super.dispose();
  }

  void _changePasswordDialog() {
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Password"),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: "New Password"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final newPassword = passCtrl.text.trim();
              if (newPassword.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Password must be at least 6 characters.")),
                );
                return;
              }
              vm.updatePassword(context, newPassword);
              Navigator.pop(context);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
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
              vm.updateAvatar(file);
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
    return Consumer<ProfileViewModel>(
      builder: (context, vm, _) {
        if (vm.loading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          appBar: AppBar(title: const Text("Profile"), automaticallyImplyLeading: false),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _showAvatarSelector,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: vm.avatarPath != null ? AssetImage(vm.avatarPath!) : null,
                    child: vm.avatarPath == null ? const Icon(Icons.person, size: 50) : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: vm.nameCtrl,
                  decoration: const InputDecoration(labelText: "Name"),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: vm.email,
                  enabled: false,
                  decoration: const InputDecoration(labelText: "Email"),
                ),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: () => vm.updateName(context), child: const Text("Save Name")),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _changePasswordDialog,
                  icon: const Icon(Icons.lock),
                  label: const Text("Change Password"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
