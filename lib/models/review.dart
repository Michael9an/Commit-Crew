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
  
  // NEW FEATURES
  final bool isEdited; 
  final List<String> likedBy; // List of user IDs who liked this review

  ReviewModel({
    this.id,
    required this.eventId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    this.photoUrls = const [],
    this.createdAt,
    this.isEdited = false,
    this.likedBy = const [],
  });

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'photoUrls': photoUrls,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'isEdited': isEdited,
      'likedBy': likedBy,
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
      isEdited: data['isEdited'] ?? false,
      likedBy: List<String>.from(data['likedBy'] ?? []),
    );
  }
}

// NEW: Reply Model
class ReplyModel {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final DateTime? createdAt;

  ReplyModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory ReplyModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ReplyModel(
      id: id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}