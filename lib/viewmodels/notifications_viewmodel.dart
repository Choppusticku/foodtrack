import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
  import '../models/notification_model.dart';

class NotificationsViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<NotificationModel>> get notificationStream {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      return NotificationModel.fromMap(doc.id, data);
    }).toList());
  }

  Future<void> markAsRead(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .doc(id)
        .update({'isRead': true});
  }

  Future<void> deleteNotification(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .doc(id)
        .delete();
  }
}
