import 'package:cloud_firestore/cloud_firestore.dart';

class ItemService {
  static Future<void> addItemToFirestore({
    required String name,
    required String groupId,
    required String category,
    required String description,
    required int qty,
    required DateTime expiryDate,
    required String batchCode,
  }) async {
    final existing = await FirebaseFirestore.instance
        .collection('items')
        .where('name', isEqualTo: name)
        .where('groupId', isEqualTo: groupId)
        .limit(1)
        .get();

    final batch = {
      'batchId': DateTime.now().millisecondsSinceEpoch.toString(),
      'expiryDate': expiryDate,
      'quantity': qty,
      'addedOn': Timestamp.now(),
      'batchCode': batchCode,
      'status': 'active',
    };

    if (existing.docs.isNotEmpty) {
      final itemDoc = existing.docs.first;
      final batches = List<Map<String, dynamic>>.from(itemDoc['batches'] ?? []);
      batches.add(batch);
      await itemDoc.reference.update({
        'batches': batches,
        'category': category,
        'description': description,
      });
    } else {
      await FirebaseFirestore.instance.collection('items').add({
        'name': name,
        'groupId': groupId,
        'category': category,
        'description': description,
        'batches': [batch],
      });
    }
  }
}
