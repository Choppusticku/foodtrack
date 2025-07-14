import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/inventory_viewmodel.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late InventoryViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = context.read<InventoryViewModel>();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => vm.updateTabIndex(_tabController.index));
    WidgetsBinding.instance.addPostFrameCallback((_) => vm.init());
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
    return Consumer<InventoryViewModel>(
      builder: (context, vm, _) {
        if (vm.groupId == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(vm.groupName),
            bottom: TabBar(
              controller: _tabController,
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
                  onChanged: vm.setSearchQuery,
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
                        value: vm.selectedCategory,
                        isExpanded: true,
                        onChanged: (val) => vm.setCategory(val ?? 'All'),
                        items: vm.categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButton<String>(
                        value: vm.sortOption,
                        isExpanded: true,
                        onChanged: (val) => vm.setSort(val ?? 'Expiry ASC'),
                        items: vm.sortOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('items')
                        .where('groupId', isEqualTo: vm.groupId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                      final filteredDocs = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['name'] ?? '').toString().toLowerCase();
                        final category = (data['category'] ?? 'Others').toString();
                        return name.contains(vm.searchQuery) &&
                            (vm.selectedCategory == 'All' || category == vm.selectedCategory);
                      }).toList();

                      if (filteredDocs.isEmpty) return const Center(child: Text("No items found."));

                      return ListView(
                        children: filteredDocs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final name = data['name'] ?? 'Unnamed';
                          final category = data['category'] ?? 'Others';
                          final description = data['description'] ?? '-';
                          final allBatches = (data['batches'] as List?)?.whereType<Map<String, dynamic>>() ?? [];
                          final batches = allBatches
                              .where((b) => (b['status'] ?? 'active') == vm.batchFilterStatus)
                              .toList();

                          if (batches.isEmpty) return const SizedBox.shrink();

                          if (vm.batchFilterStatus == 'active') {
                            batches.sort((a, b) {
                              final aExpiry = (a['expiryDate'] as Timestamp).toDate();
                              final bExpiry = (b['expiryDate'] as Timestamp).toDate();
                              return vm.sortOption == 'Expiry DESC'
                                  ? bExpiry.compareTo(aExpiry)
                                  : aExpiry.compareTo(bExpiry);
                            });

                            final soonestExpiry = (batches.first['expiryDate'] as Timestamp).toDate();
                            final expiryLabel = vm.getExpiryWarning(soonestExpiry);

                            final Map<String, List<Map<String, dynamic>>> bucketed = {};
                            for (var batch in batches) {
                              final expiry = (batch['expiryDate'] as Timestamp).toDate();
                              final bucket = vm.getExpiryBucket(expiry);
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
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold, color: Colors.green)),
                                        ),
                                        ...entry.value.map((batch) {
                                          final expiry = (batch['expiryDate'] as Timestamp).toDate();
                                          final qty = batch['quantity'];
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

                          // Consumed or Thrown
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              children: batches.map((batch) {
                                final expiry = (batch['expiryDate'] as Timestamp).toDate();
                                final qty = batch['quantity'];
                                final code = batch['batchCode'];
                                final movedDate = DateTime.fromMillisecondsSinceEpoch(
                                    int.tryParse(code.split("_").last) ??
                                        DateTime.now().millisecondsSinceEpoch);

                                return ListTile(
                                  title: Text("$name  (${qty}x)",
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Expired on: ${DateFormat('dd MMM yyyy').format(expiry)}"),
                                      Text(
                                          "${vm.batchFilterStatus == 'consumed' ? 'Consumed' : 'Deleted'} on: ${DateFormat('dd MMM yyyy').format(movedDate)}"),
                                    ],
                                  ),
                                  trailing: Icon(
                                    vm.batchFilterStatus == 'consumed'
                                        ? Icons.check_circle
                                        : Icons.delete,
                                    color: vm.batchFilterStatus == 'consumed'
                                        ? Colors.green
                                        : Colors.red,
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
      },
    );
  }
}
