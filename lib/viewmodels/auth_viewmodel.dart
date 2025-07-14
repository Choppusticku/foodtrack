import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthViewModel extends ChangeNotifier {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final nameCtrl = TextEditingController();

  String role = 'Member';
  bool isLoading = false;
  String? error;

  Future<void> login(BuildContext context) async {
    _startLoading();
    try {
      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text,
      );
      final user = userCred.user!;

      if (!user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        error = "Please verify your email before logging in.";
      } else {
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } on FirebaseAuthException catch (e) {
      error = e.message;
    } finally {
      _stopLoading();
    }
  }

  Future<void> register(BuildContext context) async {
    _startLoading();
    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      final userCred = await auth.createUserWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text,
      );
      final user = userCred.user!;
      final uid = user.uid;

      await user.sendEmailVerification();

      await firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': emailCtrl.text.trim(),
        'displayName': nameCtrl.text.trim(),
        'role': role,
        'groupId': null,
        'currentGroupId': null,
        'groups': [],
        'createdAt': Timestamp.now(),
        'avatar': '',
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verification email sent. Please verify before logging in.")),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      error = e.message;
    } finally {
      _stopLoading();
    }
  }

  Future<void> resetPassword(BuildContext context) async {
    final email = emailCtrl.text.trim();
    if (email.isEmpty) {
      error = "Enter your email first.";
      notifyListeners();
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password reset email sent")),
        );
      }
    } on FirebaseAuthException catch (e) {
      error = e.message;
    }
    notifyListeners();
  }

  void setRole(String value) {
    role = value;
    notifyListeners();
  }

  void _startLoading() {
    error = null;
    isLoading = true;
    notifyListeners();
  }

  void _stopLoading() {
    isLoading = false;
    notifyListeners();
  }
}
