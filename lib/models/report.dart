import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String eventId;
  final String eventName;
  final String userId;
  final String reason;
  final String? details;
  final String? imageUrl;
  final String status; // 'pending', 'reviewing', 'resolved', 'dismissed'
  final String type; // 'event' or 'review'
  final String? targetId; // ID of the review or event
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewerNotes;

  ReportModel({
    required this.id,
    required this.eventId,
    required this.eventName,
    required this.userId,
    required this.reason,
    this.details,
    this.imageUrl,
    this.status = 'pending',
    this.type = 'event',
    this.targetId,
    required this.createdAt,
    this.reviewedAt,
    this.reviewerNotes,
  });

  factory ReportModel.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime created;
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is int) {
      created = DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int);
    } else if (data['timestamp'] is Timestamp) {
      created = (data['timestamp'] as Timestamp).toDate();
    } else if (data['timestamp'] is int) {
      created = DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int);
    } else {
      created = DateTime.now();
    }

    DateTime? reviewed;
    if (data['reviewedAt'] != null) {
      if (data['reviewedAt'] is Timestamp) {
        reviewed = (data['reviewedAt'] as Timestamp).toDate();
      } else if (data['reviewedAt'] is int) {
        reviewed = DateTime.fromMillisecondsSinceEpoch(data['reviewedAt'] as int);
      }
    }

    return ReportModel(
      id: id,
      eventId: data['eventId'] ?? '',
      eventName: data['eventName'] ?? '',
      userId: data['userId'] ?? data['reporterId'] ?? '',
      reason: data['reason'] ?? '',
      details: data['details'],
      imageUrl: data['imageUrl'],
      status: data['status'] ?? 'pending',
      type: data['type'] ?? data['targetType'] ?? 'event',
      targetId: data['targetId'],
      createdAt: created,
      reviewedAt: reviewed,
      reviewerNotes: data['reviewerNotes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'eventName': eventName,
      'userId': userId,
      'reason': reason,
      'details': details,
      'imageUrl': imageUrl,
      'status': status,
      'type': type,
      'targetId': targetId,
      'createdAt': Timestamp.fromDate(createdAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewerNotes': reviewerNotes,
    };
  }

  ReportModel copyWith({
    String? id,
    String? eventId,
    String? eventName,
    String? userId,
    String? reason,
    String? details,
    String? status,
    String? type,
    String? targetId,
    DateTime? createdAt,
    DateTime? reviewedAt,
    String? reviewerNotes,
  }) {
    return ReportModel(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      userId: userId ?? this.userId,
      reason: reason ?? this.reason,
      details: details ?? this.details,
      status: status ?? this.status,
      type: type ?? this.type,
      targetId: targetId ?? this.targetId,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewerNotes: reviewerNotes ?? this.reviewerNotes,
    );
  }
}