import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/analytics_viewmodel.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalyticsViewModel>().loadAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalyticsViewModel>(
      builder: (context, vm, _) {
        if (vm.loading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                              final vm = context.read<AnalyticsViewModel>();
                              if (index < 0 || index >= vm.expiryTrend.length) return const SizedBox();
                              return Text(vm.expiryTrend[index]['date'].substring(5)); // MM-DD
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: vm.expiryTrend.asMap().entries.map((e) {
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
      },
    );
  }
}

class _PieChartWidget extends StatelessWidget {
  const _PieChartWidget();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AnalyticsViewModel>();
    if (vm.categoryCounts.isEmpty) return const SizedBox();

    final total = vm.categoryCounts.values.reduce((a, b) => a + b);
    final sections = vm.categoryCounts.entries.map((e) {
      final percentage = (e.value / total) * 100;
      return PieChartSectionData(
        title: "${e.key} (${percentage.toStringAsFixed(0)}%)",
        value: e.value.toDouble(),
        color: Colors.primaries[vm.categoryCounts.keys.toList().indexOf(e.key) % Colors.primaries.length],
        radius: 60,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return PieChart(PieChartData(sections: sections));
  }
}
