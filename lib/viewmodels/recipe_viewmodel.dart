import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../services/openrouter_service.dart';

class RecipeViewModel extends ChangeNotifier {
  List<String> allItems = [];
  List<String> selectedItems = [];
  bool loading = false;
  String? result;

  Future<void> fetchInventory() async {
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

      allItems = itemsWithActiveBatches.toList();
      selectedItems = List.from(allItems);
      notifyListeners();
    } catch (e) {
      debugPrint("Inventory fetch error: $e");
    }
  }

  Future<void> generateRecipe() async {
    if (selectedItems.isEmpty) return;

    loading = true;
    result = null;
    notifyListeners();

    try {
      final service = OpenRouterService(dotenv.env['OPENROUTER_API_KEY']!);
      result = await service.generateRecipe(selectedItems);
    } catch (e) {
      result = "Error: $e";
    }

    loading = false;
    notifyListeners();
  }

  void toggleSelectAll(bool selectAll) {
    selectedItems = selectAll ? List.from(allItems) : [];
    notifyListeners();
  }

  void toggleItem(String item) {
    if (selectedItems.contains(item)) {
      selectedItems.remove(item);
    } else {
      selectedItems.add(item);
    }
    notifyListeners();
  }

  bool isItemSelected(String item) => selectedItems.contains(item);
  bool isAllSelected() => selectedItems.length == allItems.length;
}
