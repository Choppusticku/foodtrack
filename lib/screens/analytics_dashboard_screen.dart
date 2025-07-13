import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, int> _categoryCounts = {};
  List<Map<String, dynamic>> _expiryTrend = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final groupId = userDoc.data()?['currentGroupId'];

    if (groupId == null) {
      setState(() => _loading = false);
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

    final expiryList = dateMap.entries
        .map((e) => {'date': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    setState(() {
      _categoryCounts = categoryMap;
      _expiryTrend = expiryList;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Analytics")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Items per Category", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 180, child: _PieChartWidget()),
            const SizedBox(height: 20),
            const Text("Expiring Items Over Time", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index < 0 || index >= _expiryTrend.length) return const SizedBox();
                          return Text(_expiryTrend[index]['date'].substring(5)); // MM-DD
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _expiryTrend.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), (e.value['count'] as int).toDouble());
                      }).toList(),
                      isCurved: true,
                      color: Colors.green,
                      dotData: FlDotData(show: false),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PieChartWidget extends StatelessWidget {
  const _PieChartWidget();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_AnalyticsScreenState>();
    if (state == null || state._categoryCounts.isEmpty) return const SizedBox();

    final total = state._categoryCounts.values.reduce((a, b) => a + b);
    final sections = state._categoryCounts.entries.map((e) {
      final percentage = (e.value / total) * 100;
      return PieChartSectionData(
        title: "${e.key} (${percentage.toStringAsFixed(0)}%)",
        value: e.value.toDouble(),
        color: Colors.primaries[state._categoryCounts.keys.toList().indexOf(e.key) % Colors.primaries.length],
        radius: 60,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return PieChart(PieChartData(sections: sections));
  }
}
