import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:foodtrack/utils/utils.dart';

import 'barcode_scan_screen.dart'; // Scanner

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadGroupId();
  }

  Future<void> _loadGroupId() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists || doc['currentGroupId'] == null) {
      setState(() => groupId = null);
    } else {
      setState(() => groupId = doc['currentGroupId']);
    }
  }

  String _generateBatchCode(String itemName, DateTime expiry) {
    final short = itemName.toUpperCase().substring(0, 3);
    final date = DateFormat('ddMMyy').format(expiry);
    final random = Random().nextInt(90) + 10;
    return "$short-$date-$random";
  }

  Future<void> _addItem() async {
    if (nameCtrl.text.isEmpty || qtyCtrl.text.isEmpty || expiryDate == null) {
      setState(() => error = "Please fill all fields");
      return;
    }

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final name = nameCtrl.text.trim();
      final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
      final batchCode = _generateBatchCode(name, expiryDate!);

      final existing = await FirebaseFirestore.instance
          .collection('items')
          .where('name', isEqualTo: name)
          .where('groupId', isEqualTo: groupId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        final itemDoc = existing.docs.first;
        final batches = List<Map<String, dynamic>>.from(itemDoc['batches'] ?? []);
        batches.add({
          'batchId': DateTime.now().millisecondsSinceEpoch.toString(),
          'expiryDate': expiryDate,
          'quantity': qty,
          'addedOn': Timestamp.now(),
          'batchCode': batchCode,
          'status': 'active',
        });
        await itemDoc.reference.update({
          'batches': batches,
          'category': selectedCategory,
          'description': descCtrl.text.trim(),
        });
      } else {
        await FirebaseFirestore.instance.collection('items').add({
          'name': name,
          'groupId': groupId,
          'category': selectedCategory,
          'description': descCtrl.text.trim(),
          'batches': [
            {
              'batchId': DateTime.now().millisecondsSinceEpoch.toString(),
              'expiryDate': expiryDate,
              'quantity': qty,
              'addedOn': Timestamp.now(),
              'batchCode': batchCode,
              'status': 'active',
            }
          ],
        });
      }

      final currentUser = FirebaseAuth.instance.currentUser!;
      await sendNotification(
        uid: currentUser.uid,
        groupId: groupId!,
        message: "New item '$name' added to your pantry",
        type: 'info',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added')),
        );
        nameCtrl.clear();
        qtyCtrl.text = '1';
        descCtrl.clear();
        setState(() => expiryDate = null);
      }
    } catch (e) {
      setState(() => error = "Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _scanBarcode() async {
    try {
      final scanned = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
      );

      if (!mounted || scanned == null || scanned is! String || scanned.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Scan cancelled or failed.")),
        );
        return;
      }

      final response = await http.get(Uri.parse(
          "https://world.openfoodfacts.org/api/v0/product/$scanned.json"));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final product = data['product'];
        final name = product?['product_name'];

        if (name != null && name.toString().trim().isNotEmpty) {
          setState(() {
            nameCtrl.text = name;
          });
        } else {
          _showManualEntryPrompt();
        }
      } else {
        _showManualEntryPrompt();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Scan failed: $e")),
        );
      }
    }
  }

  void _showManualEntryPrompt() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No item found. Please enter manually.")),
    );
  }

  void _incrementQty() {
    final current = int.tryParse(qtyCtrl.text) ?? 1;
    qtyCtrl.text = (current + 1).toString();
  }

  void _decrementQty() {
    final current = int.tryParse(qtyCtrl.text) ?? 1;
    if (current > 1) qtyCtrl.text = (current - 1).toString();
  }

  @override
  Widget build(BuildContext context) {
    if (groupId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("You haven't joined a group yet."),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/group_screen.dart');
                },
                child: const Text("Go to Group"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Add Item")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text("Scan"),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: "Item Name"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: "Category"),
                items: categories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (val) => setState(() => selectedCategory = val ?? 'Others'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: "Description (optional)"),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text("Quantity:"),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _decrementQty,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: qtyCtrl,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  IconButton(
                    onPressed: _incrementQty,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(expiryDate == null
                      ? "Pick expiry date"
                      : "Expiry: ${DateFormat('dd MMM yyyy').format(expiryDate!)}"),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => expiryDate = picked);
                      }
                    },
                    child: const Text("Select Date"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
              if (isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text("Add Item"),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
