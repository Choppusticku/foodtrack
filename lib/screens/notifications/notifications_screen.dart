import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/notifications_viewmodel.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Icon _getIcon(String type) {
    switch (type) {
      case 'expiry':
        return const Icon(Icons.hourglass_bottom, color: Colors.red);
      case 'consumed':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'info':
        return const Icon(Icons.info, color: Colors.blue);
      default:
        return const Icon(Icons.notifications, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationsViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder(
        stream: vm.notificationStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final notifications = snapshot.data!;
          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                "No notifications.",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final formattedTime = DateFormat('dd MMM yyyy, hh:mm a').format(notif.timestamp);
              return Dismissible(
                key: Key(notif.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => vm.deleteNotification(notif.id),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  leading: _getIcon(notif.type),
                  title: Text(
                    notif.message,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Group: ${notif.groupId}"),
                      Text(formattedTime),
                    ],
                  ),
                  tileColor: !notif.isRead ? Colors.orange.shade50 : null,
                  onTap: () => vm.markAsRead(notif.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
