import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  String? groupId;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final group = doc['currentGroupId'];
    setState(() => groupId = group);

    final snapshot = await FirebaseFirestore.instance
        .collection('items')
        .where('groupId', isEqualTo: group)
        .get();

    final items = snapshot.docs;

    final events = <DateTime, List<Map<String, dynamic>>>{};
    for (var item in items) {
      final data = item.data();
      final name = data['name'] ?? 'Unnamed';
      final batches = List<Map<String, dynamic>>.from(data['batches'] ?? []);
      for (var batch in batches) {
        final expiry = (batch['expiryDate'] as Timestamp).toDate();
        final day = DateTime(expiry.year, expiry.month, expiry.day);
        events.putIfAbsent(day, () => []).add({'name': name, 'qty': batch['quantity']});
      }
    }

    setState(() => _events = events);
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Calendar View")),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            eventLoader: _getEventsForDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: _getEventsForDay(_selectedDay ?? _focusedDay).map((e) {
                return ListTile(
                  title: Text("${e['name']}"),
                  subtitle: Text("Qty: ${e['qty']}"),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
