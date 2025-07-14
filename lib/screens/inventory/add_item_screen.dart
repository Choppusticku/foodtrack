import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/item_viewmodel.dart';
import '../../screens/inventory/add_item_screen.dart';

class AddItemScreen extends StatelessWidget {
  const AddItemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<ItemViewModel>(context);

    if (vm.groupId == null) {
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
                    onPressed: () => vm.scanBarcode(context),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text("Scan"),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: vm.nameCtrl,
                      decoration: const InputDecoration(labelText: "Item Name"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: vm.selectedCategory,
                decoration: const InputDecoration(labelText: "Category"),
                items: vm.categories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (val) => vm.setCategory(val ?? 'Others'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: vm.descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: "Description (optional)"),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text("Quantity:"),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: vm.decrementQty,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: vm.qtyCtrl,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  IconButton(
                    onPressed: vm.incrementQty,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(vm.expiryDate == null
                      ? "Pick expiry date"
                      : "Expiry: ${DateFormat('dd MMM yyyy').format(vm.expiryDate!)}"),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: DateTime.now(),
                      );
                      if (picked != null) vm.setExpiryDate(picked);
                    },
                    child: const Text("Select Date"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (vm.error != null)
                Text(vm.error!, style: const TextStyle(color: Colors.red)),
              if (vm.isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: () => vm.addItem(context),
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
