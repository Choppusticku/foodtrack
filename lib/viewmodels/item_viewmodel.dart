import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/item_service.dart';
import '../services/barcode_service.dart';
import '../services/notification_service.dart';
import '../screens/inventory/barcode_scan_screen.dart';

class ItemViewModel extends ChangeNotifier {
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');

  DateTime? expiryDate;
  String? groupId;
  bool isLoading = false;
  String? error;

  final List<String> categories = [
    'Dairy',
    'Produce',
    'Grains',
    'Snacks',
    'Meat',
    'Frozen',
    'Beverages',
    'Others'
  ];
  String selectedCategory = 'Others';

  ItemViewModel() {
    _loadGroupId();
  }

  Future<void> _loadGroupId() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists || doc['currentGroupId'] == null) {
      groupId = null;
    } else {
      groupId = doc['currentGroupId'];
    }
    notifyListeners();
  }

  void setCategory(String cat) {
    selectedCategory = cat;
    notifyListeners();
  }

  void setExpiryDate(DateTime date) {
    expiryDate = date;
    notifyListeners();
  }

  void incrementQty() {
    final current = int.tryParse(qtyCtrl.text) ?? 1;
    qtyCtrl.text = (current + 1).toString();
  }

  void decrementQty() {
    final current = int.tryParse(qtyCtrl.text) ?? 1;
    if (current > 1) qtyCtrl.text = (current - 1).toString();
  }

  String _generateBatchCode(String itemName, DateTime expiry) {
    final short = itemName.toUpperCase().substring(0, 3);
    final date = DateFormat('ddMMyy').format(expiry);
    final random = Random().nextInt(90) + 10;
    return "$short-$date-$random";
  }

  Future<void> addItem(BuildContext context) async {
    if (nameCtrl.text.isEmpty || qtyCtrl.text.isEmpty || expiryDate == null) {
      error = "Please fill all fields";
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final name = nameCtrl.text.trim();
      final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
      final batchCode = _generateBatchCode(name, expiryDate!);

      await ItemService.addItemToFirestore(
        name: name,
        groupId: groupId!,
        category: selectedCategory,
        description: descCtrl.text.trim(),
        qty: qty,
        expiryDate: expiryDate!,
        batchCode: batchCode,
      );

      final currentUser = FirebaseAuth.instance.currentUser!;
      await NotificationService.sendNotification(
        uid: currentUser.uid,
        groupId: groupId!,
        message: "New item '$name' added to your pantry",
        type: 'info',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added')),
        );
      }

      resetForm();
    } catch (e) {
      error = "Error: $e";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void resetForm() {
    nameCtrl.clear();
    qtyCtrl.text = '1';
    descCtrl.clear();
    expiryDate = null;
    selectedCategory = 'Others';
    notifyListeners();
  }

  Future<void> scanBarcode(BuildContext context) async {
    try {
      final scanned = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
      );

      if (!context.mounted || scanned == null || scanned is! String || scanned.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Scan cancelled or failed.")),
        );
        return;
      }

      final name = await BarcodeService.fetchItemNameFromBarcode(scanned);
      if (name != null && name.trim().isNotEmpty) {
        nameCtrl.text = name;
        notifyListeners();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No item found. Please enter manually.")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Scan failed: $e")),
        );
      }
    }
  }
}
