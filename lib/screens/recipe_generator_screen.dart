import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/openrouter_service.dart';

class RecipeGeneratorScreen extends StatefulWidget {
  const RecipeGeneratorScreen({super.key});

  @override
  State<RecipeGeneratorScreen> createState() => _RecipeGeneratorScreenState();
}

class _RecipeGeneratorScreenState extends State<RecipeGeneratorScreen> {
  List<String> allItems = [];
  List<String> selectedItems = [];
  bool loading = false;
  String? result;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final currentGroupId = userDoc.data()?['currentGroupId'];
      if (currentGroupId == null) return;

      final query = await FirebaseFirestore.instance
          .collection('items')
          .where('groupId', isEqualTo: currentGroupId)
          .get();

      final itemsWithActiveBatches = <String>{};

      for (var doc in query.docs) {
        final data = doc.data();
        final batches = (data['batches'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .where((b) => (b['status'] ?? 'active') == 'active')
            .toList();

        if (batches != null && batches.isNotEmpty) {
          itemsWithActiveBatches.add(data['name']);
        }
      }

      setState(() {
        allItems = itemsWithActiveBatches.toList();
        selectedItems = List.from(allItems);
      });
    } catch (e) {
      debugPrint("Inventory fetch error: $e");
    }
  }

  Future<void> _generateRecipe() async {
    if (selectedItems.isEmpty) return;

    setState(() {
      loading = true;
      result = null;
    });

    try {
      final service = OpenRouterService(dotenv.env['OPENROUTER_API_KEY']!);
      final recipe = await service.generateRecipe(selectedItems);
      setState(() => result = recipe);
    } catch (e) {
      setState(() => result = "Error: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (allItems.isNotEmpty)
              CheckboxListTile(
                title: const Text("Select All"),
                value: selectedItems.length == allItems.length,
                onChanged: (val) {
                  setState(() {
                    selectedItems = val! ? List.from(allItems) : [];
                  });
                },
              ),
            if (allItems.isEmpty)
              const Center(child: CircularProgressIndicator()),

            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: allItems.map((item) {
                final isSelected = selectedItems.contains(item);
                return FilterChip(
                  label: Text(item),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedItems.add(item);
                      } else {
                        selectedItems.remove(item);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text("Generate Recipe"),
              onPressed: loading ? null : _generateRecipe,
            ),
            const SizedBox(height: 20),
            if (loading) const CircularProgressIndicator(),
            if (result != null)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(result!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
