import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  String? groupId;
  String groupName = "My Pantry";
  String selectedCategory = 'All';
  String searchQuery = '';
  String batchFilterStatus = 'active';
  String sortOption = 'Expiry ASC';

  final List<String> categories = ['All', 'Dairy', 'Produce', 'Grains', 'Snacks', 'Meat', 'Frozen', 'Beverages', 'Others'];
  final List<String> sortOptions = ['Name A-Z', 'Name Z-A', 'Expiry ASC', 'Expiry DESC'];

  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
    tabController.addListener(() {
      setState(() {
        batchFilterStatus = switch (tabController.index) {
          0 => 'active',
          1 => 'consumed',
          _ => 'thrown'
        };
      });
    });
    _loadGroupIdAndName();
  }

  Future<void> _loadGroupIdAndName() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final gid = doc['currentGroupId'];
    final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(gid).get();
    setState(() {
      groupId = gid;
      groupName = groupDoc['name'] ?? 'My Pantry';
    });
  }

  String getExpiryWarning(DateTime expiry) {
    final daysLeft = expiry.difference(DateTime.now()).inDays;
    if (daysLeft <= 3) return '⚠️ Expires in $daysLeft day${daysLeft == 1 ? '' : 's'}';
    return '';
  }

  String getBucket(DateTime expiry) {
    final daysLeft = expiry.difference(DateTime.now()).inDays;
    if (daysLeft <= 3) return 'Expiring in 1–3 days';
    if (daysLeft <= 7) return 'Expiring in 4–7 days';
    return 'Expiring after 7 days';
  }

  Future<void> _handleBatchAction(String itemId, Map<String, dynamic> batch, String action) async {
    final batchCode = batch['batchCode'];
    final currentQty = batch['quantity'];
    int qtyToMove = 1;

    if (currentQty > 1) {
      final controller = TextEditingController();
      final result = await showDialog<int>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('How many to ${action == 'consumed' ? 'consume' : 'delete'}?'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Enter quantity'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final input = int.tryParse(controller.text);
                  if (input != null && input > 0 && input <= currentQty) {
                    Navigator.of(context).pop(input);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Enter a valid quantity")),
                    );
                  }
                },
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );

      if (result == null) return;
      qtyToMove = result;
    }

    final itemRef = FirebaseFirestore.instance.collection('items').doc(itemId);
    final itemSnap = await itemRef.get();
    final itemData = itemSnap.data() as Map<String, dynamic>;
    final List<dynamic> batches = itemData['batches'] ?? [];

    final updatedBatches = batches.where((b) => (b as Map<String, dynamic>)['batchCode'] != batchCode).toList();

    if (qtyToMove < currentQty) {
      final updatedOriginal = Map<String, dynamic>.from(batch);
      updatedOriginal['quantity'] = currentQty - qtyToMove;
      updatedBatches.add(updatedOriginal);
    }

    final newBatch = {
      ...batch,
      'quantity': qtyToMove,
      'status': action,
      'batchCode': '${batchCode}_${action}_${DateTime.now().millisecondsSinceEpoch}'
    };
    updatedBatches.add(newBatch);

    await itemRef.update({'batches': updatedBatches});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Item ${action == 'consumed' ? 'consumed' : 'deleted'} successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (groupId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(groupName),
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(text: "Active"),
            Tab(text: "Consumed"),
            Tab(text: "Thrown"),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: selectedCategory,
                    isExpanded: true,
                    onChanged: (val) => setState(() => selectedCategory = val ?? 'All'),
                    items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String>(
                    value: sortOption,
                    isExpanded: true,
                    onChanged: (val) => setState(() => sortOption = val ?? 'Expiry ASC'),
                    items: sortOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('items')
                    .where('groupId', isEqualTo: groupId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final allItems = snapshot.data!.docs;

                  final filtered = allItems.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final category = (data['category'] ?? 'Others').toString();
                    return name.contains(searchQuery) &&
                        (selectedCategory == 'All' || category == selectedCategory);
                  }).toList();

                  if (filtered.isEmpty) return const Center(child: Text("No items found."));

                  return ListView(
                    children: filtered.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Unnamed';
                      final category = data['category'] ?? 'Others';
                      final description = data['description'] ?? '-';
                      final allBatches = (data['batches'] as List?)?.whereType<Map<String, dynamic>>() ?? [];
                      final batches = allBatches.where((b) => (b['status'] ?? 'active') == batchFilterStatus).toList();

                      if (batches.isEmpty) return const SizedBox.shrink();

                      if (batchFilterStatus == 'active') {
                        batches.sort((a, b) {
                          final aExpiry = (a['expiryDate'] as Timestamp).toDate();
                          final bExpiry = (b['expiryDate'] as Timestamp).toDate();
                          return sortOption == 'Expiry DESC' ? bExpiry.compareTo(aExpiry) : aExpiry.compareTo(bExpiry);
                        });

                        final soonestExpiry = (batches.first['expiryDate'] as Timestamp).toDate();
                        final expiryLabel = getExpiryWarning(soonestExpiry);

                        final Map<String, List<Map<String, dynamic>>> bucketed = {};
                        for (var batch in batches) {
                          final expiry = (batch['expiryDate'] as Timestamp).toDate();
                          final bucket = getBucket(expiry);
                          bucketed.putIfAbsent(bucket, () => []).add(batch);
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ExpansionTile(
                            title: Row(
                              children: [
                                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                if (expiryLabel.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(expiryLabel, style: const TextStyle(fontSize: 12)),
                                  ),
                              ],
                            ),
                            subtitle: Text("Category: $category"),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text("Description: $description"),
                                ),
                              ),
                              ...bucketed.entries.map((entry) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16.0, top: 6),
                                      child: Text(entry.key,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                    ),
                                    ...entry.value.map((batch) {
                                      final expiry = (batch['expiryDate'] as Timestamp).toDate();
                                      final qty = batch['quantity'];
                                      final code = batch['batchCode'];
                                      return ListTile(
                                        title: Text("Qty: $qty"),
                                        subtitle: Text("Expires: ${DateFormat('dd MMM yyyy').format(expiry)}"),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.check_circle, color: Colors.green),
                                              tooltip: 'Consume',
                                              onPressed: () => _handleBatchAction(doc.id, batch, 'consumed'),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              tooltip: 'Delete',
                                              onPressed: () => _handleBatchAction(doc.id, batch, 'thrown'),
                                            ),
                                          ],
                                        ),
                                        dense: true,
                                      );
                                    }).toList(),
                                  ],
                                );
                              }),
                            ],
                          ),
                        );
                      }

                      // Consumed / Thrown display
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: batches.map((batch) {
                            final expiry = (batch['expiryDate'] as Timestamp).toDate();
                            final qty = batch['quantity'];
                            final code = batch['batchCode'];
                            final movedDate = DateTime.fromMillisecondsSinceEpoch(
                                int.tryParse(code.split("_").last) ?? DateTime.now().millisecondsSinceEpoch);

                            return ListTile(
                              title: Text("$name  (${qty}x)", style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Expired on: ${DateFormat('dd MMM yyyy').format(expiry)}"),
                                  Text("${batchFilterStatus == 'consumed' ? 'Consumed' : 'Deleted'} on: ${DateFormat('dd MMM yyyy').format(movedDate)}"),
                                ],
                              ),
                              trailing: Icon(
                                batchFilterStatus == 'consumed' ? Icons.check_circle : Icons.delete,
                                color: batchFilterStatus == 'consumed' ? Colors.green : Colors.red,
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
