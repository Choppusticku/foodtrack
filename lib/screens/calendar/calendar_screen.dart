import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../viewmodels/calendar_viewmodel.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CalendarViewModel()..loadEvents(),
      builder: (context, _) {
        final vm = context.watch<CalendarViewModel>();

        return Scaffold(
          appBar: AppBar(title: const Text("Calendar View")),
          body: Column(
            children: [
              TableCalendar(
                focusedDay: vm.focusedDay,
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                selectedDayPredicate: (day) => isSameDay(vm.selectedDay, day),
                eventLoader: vm.getEventsForDay,
                onDaySelected: vm.selectDay,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: vm
                      .getEventsForDay(vm.selectedDay ?? vm.focusedDay)
                      .map((e) => ListTile(
                    title: Text("${e['name']}"),
                    subtitle: Text("Qty: ${e['qty']}"),
                  ))
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
