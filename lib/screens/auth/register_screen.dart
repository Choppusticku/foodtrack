import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, vm, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Register')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: vm.nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: vm.emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: vm.passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    const Text("Register as: "),
                    DropdownButton<String>(
                      value: vm.role,
                      items: const [
                        DropdownMenuItem(value: 'Owner', child: Text('Owner')),
                        DropdownMenuItem(value: 'Member', child: Text('Member')),
                      ],
                      onChanged: (val) => vm.setRole(val!),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                if (vm.error != null)
                  Text(vm.error!, style: const TextStyle(color: Colors.red)),

                vm.isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: () => vm.register(context),
                  child: const Text('Register'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
