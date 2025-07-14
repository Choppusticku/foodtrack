import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InventoryViewModel extends ChangeNotifier {
  String? groupId;
  String groupName = "My Pantry";

  String selectedCategory = 'All';
  String searchQuery = '';
  String batchFilterStatus = 'active';
  String sortOption = 'Expiry ASC';

  final List<String> categories = ['All', 'Dairy', 'Test' , 'Produce', 'Grains', 'Snacks', 'Meat', 'Frozen', 'Beverages', 'Others'];
  final List<String> sortOptions = ['Name A-Z', 'Name Z-A', 'Expiry ASC', 'Expiry DESC'];

  Future<void> init() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    groupId = doc['currentGroupId'];
    final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(groupId).get();
    groupName = groupDoc['name'] ?? 'My Pantry';
    notifyListeners();
  }

  void updateTabIndex(int index) {
    batchFilterStatus = switch (index) {
      0 => 'active',
      1 => 'consumed',
      _ => 'thrown'
    };
    notifyListeners();
  }

  void setSearchQuery(String query) {
    searchQuery = query.toLowerCase();
    notifyListeners();
  }

  void setCategory(String category) {
    selectedCategory = category;
    notifyListeners();
  }

  void setSort(String sort) {
    sortOption = sort;
    notifyListeners();
  }

  String getExpiryWarning(DateTime expiry) {
    final daysLeft = expiry.difference(DateTime.now()).inDays;
    if (daysLeft <= 3) return '⚠️ Expires in $daysLeft day${daysLeft == 1 ? '' : 's'}';
    return '';
  }

  String getExpiryBucket(DateTime expiry) {
    final daysLeft = expiry.difference(DateTime.now()).inDays;
    if (daysLeft <= 3) return 'Expiring in 1–3 days';
    if (daysLeft <= 7) return 'Expiring in 4–7 days';
    return 'Expiring after 7 days';
  }
}
