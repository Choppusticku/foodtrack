import 'package:cloud_firestore/cloud_firestore.dart';

class ItemModel {
  final String id;
  final String name;
  final String category;
  final String description;
  final String groupId;
  final List<BatchModel> batches;

  ItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.groupId,
    required this.batches,
  });

  factory ItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ItemModel(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? 'Others',
      description: data['description'] ?? '',
      groupId: data['groupId'] ?? '',
      batches: (data['batches'] as List<dynamic>?)
          ?.map((b) => BatchModel.fromMap(b))
          .toList() ??
          [],
    );
  }
}

class BatchModel {
  final String batchCode;
  final DateTime expiryDate;
  final int quantity;
  final String status;

  BatchModel({
    required this.batchCode,
    required this.expiryDate,
    required this.quantity,
    required this.status,
  });

  factory BatchModel.fromMap(Map<String, dynamic> data) {
    return BatchModel(
      batchCode: data['batchCode'] ?? '',
      expiryDate: (data['expiryDate'] as Timestamp).toDate(),
      quantity: data['quantity'] ?? 0,
      status: data['status'] ?? 'active',
    );
  }
}
