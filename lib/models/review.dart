import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String? id; // Document ID
  final String eventId;
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final List<String> photoUrls;
  final DateTime? createdAt;

  ReviewModel({
    this.id,
    required this.eventId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    this.photoUrls = const [],
    this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'photoUrls': photoUrls,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory ReviewModel.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime? parseDateTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      return null;
    }

    return ReviewModel(
      id: id,
      eventId: data['eventId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'] ?? '',
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      createdAt: parseDateTime(data['createdAt']),
    );
  }
}