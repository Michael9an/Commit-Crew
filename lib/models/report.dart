class ReportModel {
  final String id;
  final String eventId;
  final String eventName;
  final String userId;
  final String reason;
  final String? details;
  final String status; // 'pending', 'reviewed', 'resolved'
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
    this.status = 'pending',
    required this.createdAt,
    this.reviewedAt,
    this.reviewerNotes,
  });

  factory ReportModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ReportModel(
      id: id,
      eventId: data['eventId'] ?? '',
      eventName: data['eventName'] ?? '',
      userId: data['userId'] ?? '',
      reason: data['reason'] ?? '',
      details: data['details'],
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int)
          : DateTime.now(),
      reviewedAt: data['reviewedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['reviewedAt'] as int)
          : null,
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
      'status': status,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'reviewedAt': reviewedAt?.millisecondsSinceEpoch,
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
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewerNotes: reviewerNotes ?? this.reviewerNotes,
    );
  }
}