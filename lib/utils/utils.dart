import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> sendNotification({
  required String uid,
  required String message,
  required String type,
  required String groupId,
}) async {
  final notificationRef = FirebaseFirestore.instance
      .collection('notifications')
      .doc(uid)
      .collection('items');

  await notificationRef.add({
    'message': message,
    'type': type,
    'isRead': false,
    'groupId': groupId,
    'timestamp': Timestamp.now(),
  });
}
