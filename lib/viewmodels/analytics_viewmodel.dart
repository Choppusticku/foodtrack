import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AnalyticsViewModel extends ChangeNotifier {
  Map<String, int> categoryCounts = {};
  List<Map<String, dynamic>> expiryTrend = [];
  bool loading = true;

  Future<void> loadAnalytics() async {
    loading = true;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final groupId = userDoc.data()?['currentGroupId'];

    if (groupId == null) {
      loading = false;
      notifyListeners();
      return;
    }

    final query = await FirebaseFirestore.instance
        .collection('items')
        .where('groupId', isEqualTo: groupId)
        .get();

    final categoryMap = <String, int>{};
    final dateMap = <String, int>{};

    for (var doc in query.docs) {
      final data = doc.data();
      final category = data['category'] ?? 'Others';
      categoryMap[category] = (categoryMap[category] ?? 0) + 1;

      final batches = List<Map<String, dynamic>>.from(data['batches'] ?? []);
      for (var batch in batches) {
        final expiry = (batch['expiryDate'] as Timestamp?)?.toDate();
        if (expiry != null) {
          final formatted = DateFormat('yyyy-MM-dd').format(expiry);
          dateMap[formatted] = (dateMap[formatted] ?? 0) + 1;
        }
      }
    }

    expiryTrend = dateMap.entries
        .map((e) => {'date': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    categoryCounts = categoryMap;
    loading = false;
    notifyListeners();
  }
}
