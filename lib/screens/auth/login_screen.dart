import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'register_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, vm, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Login')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
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

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => vm.resetPassword(context),
                    child: const Text("Forgot Password?"),
                  ),
                ),

                if (vm.error != null)
                  Text(vm.error!, style: const TextStyle(color: Colors.red)),

                const SizedBox(height: 8),
                vm.isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: () => vm.login(context),
                  child: const Text('Login'),
                ),

                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: const Text('No account? Register here'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
