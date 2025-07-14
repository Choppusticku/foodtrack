import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalendarViewModel extends ChangeNotifier {
  String? groupId;
  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;
  final Map<DateTime, List<Map<String, dynamic>>> _events = {};

  Map<DateTime, List<Map<String, dynamic>>> get events => _events;

  Future<void> loadEvents() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    groupId = doc['currentGroupId'];

    final snapshot = await FirebaseFirestore.instance
        .collection('items')
        .where('groupId', isEqualTo: groupId)
        .get();

    final items = snapshot.docs;

    _events.clear();
    for (var item in items) {
      final data = item.data();
      final name = data['name'] ?? 'Unnamed';
      final batches = List<Map<String, dynamic>>.from(data['batches'] ?? []);
      for (var batch in batches) {
        final expiry = (batch['expiryDate'] as Timestamp).toDate();
        final day = DateTime(expiry.year, expiry.month, expiry.day);
        _events.putIfAbsent(day, () => []).add({'name': name, 'qty': batch['quantity']});
      }
    }

    notifyListeners();
  }

  List<Map<String, dynamic>> getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  void selectDay(DateTime selected, DateTime focused) {
    selectedDay = selected;
    focusedDay = focused;
    notifyListeners();
  }
}
