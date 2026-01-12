import 'package:cloud_firestore/cloud_firestore.dart';

class Register {
  final String id;
  final String eventId;
  final String clubId;
  final String fullName;
  final String email;
  final String phoneNumber;
  final DateTime registrationDate;
  final String? userId;
  final String status; // 'registered', 'attended', 'cancelled', 'no_show'
  final String? paymentStatus; // 'pending', 'paid', 'refunded'
  final String? paymentId;
  final DateTime? attendedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? notes;
  final int ticketQuantity;
  final double amountPaid;

  Register({
    required this.id,
    required this.eventId,
    required this.clubId,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.registrationDate,
    this.userId,
    this.status = 'registered',
    this.paymentStatus,
    this.paymentId,
    this.attendedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.notes,
    this.ticketQuantity = 1,
    this.amountPaid = 0.0,
  });

  factory Register.fromFirestore(Map<String, dynamic> data, {String? documentId}) {
    return Register(
      id: documentId ?? data['id'] ?? '',
      eventId: data['eventId'] ?? '',
      clubId: data['clubId'] ?? '',
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      registrationDate: data['registrationDate'] != null
          ? (data['registrationDate'] as Timestamp).toDate()
          : DateTime.now(),
      userId: data['userId'],
      status: data['status'] ?? 'registered',
      paymentStatus: data['paymentStatus'],
      paymentId: data['paymentId'],
      attendedAt: data['attendedAt'] != null
          ? (data['attendedAt'] as Timestamp).toDate()
          : null,
      cancelledAt: data['cancelledAt'] != null
          ? (data['cancelledAt'] as Timestamp).toDate()
          : null,
      cancellationReason: data['cancellationReason'],
      notes: data['notes'],
      ticketQuantity: data['ticketQuantity'] ?? 1,
      amountPaid: (data['amountPaid'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'eventId': eventId,
      'clubId': clubId,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'registrationDate': Timestamp.fromDate(registrationDate),
      'userId': userId,
      'status': status,
      'paymentStatus': paymentStatus,
      'paymentId': paymentId,
      'attendedAt': attendedAt != null ? Timestamp.fromDate(attendedAt!) : null,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'cancellationReason': cancellationReason,
      'notes': notes,
      'ticketQuantity': ticketQuantity,
      'amountPaid': amountPaid,
    };
  }

  Register copyWith({
    String? id,
    String? eventId,
    String? clubId,
    String? fullName,
    String? email,
    String? phoneNumber,
    DateTime? registrationDate,
    String? userId,
    String? status,
    String? paymentStatus,
    String? paymentId,
    DateTime? attendedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    String? notes,
    int? ticketQuantity,
    double? amountPaid,
  }) {
    return Register(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      clubId: clubId ?? this.clubId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      registrationDate: registrationDate ?? this.registrationDate,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentId: paymentId ?? this.paymentId,
      attendedAt: attendedAt ?? this.attendedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      notes: notes ?? this.notes,
      ticketQuantity: ticketQuantity ?? this.ticketQuantity,
      amountPaid: amountPaid ?? this.amountPaid,
    );
  }

  // Helper methods
  bool get hasAttended => status == 'attended';
  bool get isCancelled => status == 'cancelled';
  bool get isActive => status == 'registered';
  bool get isNoShow => status == 'no_show';
  
  bool get isPaid => paymentStatus == 'paid';
  bool get isPaymentPending => paymentStatus == 'pending';
  bool get isRefunded => paymentStatus == 'refunded';

  String get displayStatus {
    switch (status) {
      case 'registered':
        return 'Registered';
      case 'attended':
        return 'Attended';
      case 'cancelled':
        return 'Cancelled';
      case 'no_show':
        return 'No Show';
      default:
        return 'Unknown';
    }
  }

  String get displayPaymentStatus {
    if (paymentStatus == null) return 'Free';
    switch (paymentStatus) {
      case 'paid':
        return 'Paid';
      case 'pending':
        return 'Payment Pending';
      case 'refunded':
        return 'Refunded';
      default:
        return 'Unknown';
    }
  }

  // Mark as attended
  Register markAsAttended() {
    return copyWith(
      status: 'attended',
      attendedAt: DateTime.now(),
    );
  }

  // Mark as cancelled
  Register markAsCancelled({String? reason}) {
    return copyWith(
      status: 'cancelled',
      cancelledAt: DateTime.now(),
      cancellationReason: reason,
    );
  }

  // Update payment status
  Register updatePaymentStatus(String newStatus, {String? paymentId}) {
    return copyWith(
      paymentStatus: newStatus,
      paymentId: paymentId ?? this.paymentId,
    );
  }

  // Check if registration is valid for the event
  bool get isValid => fullName.isNotEmpty && email.isNotEmpty && phoneNumber.isNotEmpty;
}