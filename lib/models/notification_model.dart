import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String message;
  final String type;
  final String groupId;
  final DateTime timestamp;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.message,
    required this.type,
    required this.groupId,
    required this.timestamp,
    required this.isRead,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> data) {
    return NotificationModel(
      id: id,
      message: data['message'] ?? '',
      type: data['type'] ?? 'info',
      groupId: data['groupId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
    );
  }
}
