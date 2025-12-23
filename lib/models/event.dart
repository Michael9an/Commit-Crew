import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String name;
  final String description;
  final String date;
  final String startTime;
  final String endTime;
  final String? bannerUrl;
  final String location;
  final double? latitude;
  final double? longitude;
  final String clubId;
  final String clubName;
  final String? clubImageUrl;
  final int maxAttendees;
  final double price;
  final bool isFree;
  final String? refundPolicy;
  final String? publishTime;
  final DateTime? createdAt;
  final String status;
  final List<String> attendees;
  final List<String> attendeesEmail;
  final List<String> waitlist;
  final int views;
  final int shares;
  final bool isCancelled;
  final DateTime? updatedAt;
  final String category;
  final List<String> tags;
  final String contactEmail;
  final String contactPhone;
  final bool refundEnabled;          
  final int refundDeadlineDays;
  final String refundMethodDetails; 

  EventModel({
    required this.id,
    required this.name,
    required this.description,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.bannerUrl,
    required this.location,
    this.latitude,
    this.longitude,
    required this.clubId,
    required this.clubName,
    this.clubImageUrl,
    this.maxAttendees = 0,
    this.price = 0.0,
    this.isFree = true,
    this.refundPolicy,
    this.publishTime,
    this.createdAt,
    this.status = 'upcoming',
    this.attendees = const [],
    this.attendeesEmail = const [],
    this.waitlist = const [],
    this.views = 0,
    this.shares = 0,
    this.isCancelled = false,
    this.updatedAt,
    this.category = 'General',
    this.tags = const [],
    this.contactEmail = '',
    this.contactPhone = '',
    this.refundEnabled = false,
    this.refundDeadlineDays = 0,
    this.refundMethodDetails = '',
  });

 factory EventModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    
    DateTime? _convertToDateTime(dynamic timestamp) {
      if (timestamp == null) return null;
      if (timestamp is Timestamp) return timestamp.toDate();
      if (timestamp is int) return DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (timestamp is String) return DateTime.tryParse(timestamp);
      return null;
    }

    return EventModel(
      id: documentId,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      date: data['date'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      bannerUrl: data['bannerUrl'],
      location: data['location'] ?? '',
      latitude: data['latitude']?.toDouble(), 
      longitude: data['longitude']?.toDouble(),      
      clubId: data['clubId'] ?? '',
      clubName: data['clubName'] ?? '',
      clubImageUrl: data['clubImageUrl'],
      maxAttendees: data['maxAttendees'] ?? 0,
      price: (data['price'] ?? 0.0).toDouble(),
      isFree: data['isFree'] ?? true,
      refundPolicy: data['refundPolicy'],
      publishTime: data['publishTime'],
      createdAt: _convertToDateTime(data['createdAt']),
      status: data['status'] ?? 'upcoming',
      attendees: List<String>.from(data['attendees'] ?? []),
      attendeesEmail: List<String>.from(data['attendeesEmail'] ?? []),
      waitlist: List<String>.from(data['waitlist'] ?? []),
      views: data['views'] ?? 0,
      shares: data['shares'] ?? 0,
      isCancelled: data['isCancelled'] ?? false,
      updatedAt: _convertToDateTime(data['updatedAt']),
      category: data['category'] ?? 'General',
      tags: List<String>.from(data['tags'] ?? []),
      contactEmail: data['contactEmail'] ?? '',
      contactPhone: data['contactPhone'] ?? '',
      refundEnabled: data['refundEnabled'] ?? false,
      refundDeadlineDays: data['refundDeadlineDays'] ?? 0,
      refundMethodDetails: data['refundMethodDetails'] ?? '',
    );
  }
  Map<String, dynamic> toFirestore() {
    dynamic _convertToTimestamp(DateTime? dateTime) {
      if (dateTime == null) return FieldValue.serverTimestamp();
      return Timestamp.fromDate(dateTime);
    }

    return {
      'id': id,
      'name': name,
      'description': description,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'bannerUrl': bannerUrl,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'clubId': clubId,
      'clubName': clubName,
      'clubImageUrl': clubImageUrl,
      'maxAttendees': maxAttendees,
      'price': price,
      'isFree': isFree,
      'refundPolicy': refundPolicy,
      'publishTime': publishTime,
      'createdAt': _convertToTimestamp(createdAt),
      'status': status,
      'attendees': attendees,
      'attendeesEmail': attendeesEmail,
      'waitlist': waitlist,
      'views': views,
      'shares': shares,
      'isCancelled': isCancelled,
      'updatedAt': _convertToTimestamp(updatedAt),
      'category': category,
      'tags': tags,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'refundEnabled': refundEnabled,
      'refundDeadlineDays': refundDeadlineDays,
      'refundMethodDetails': refundMethodDetails,
    };
  }

  // 3. Corrected fromJson (Added missing lat/lng logic)
  factory EventModel.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDateTime(String? dateString) {
      if (dateString == null) return null;
      return DateTime.tryParse(dateString);
    }

    return EventModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      date: json['date'],
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      bannerUrl: json['bannerUrl'],
      location: json['location'],
      clubId: json['clubId'],
      clubName: json['clubName'],
      clubImageUrl: json['clubImageUrl'],
      maxAttendees: json['maxAttendees'] ?? 0,
      price: (json['price'] ?? 0.0).toDouble(),
      isFree: json['isFree'] ?? true,
      refundPolicy: json['refundPolicy'],
      publishTime: json['publishTime'],
      createdAt: _parseDateTime(json['createdAt']),
      status: json['status'] ?? 'upcoming',
      attendees: List<String>.from(json['attendees'] ?? []),
      attendeesEmail: List<String>.from(json['attendeesEmail'] ?? []), // Added this missing field
      waitlist: List<String>.from(json['waitlist'] ?? []),
      views: json['views'] ?? 0,
      shares: json['shares'] ?? 0,
      isCancelled: json['isCancelled'] ?? false,
      updatedAt: _parseDateTime(json['updatedAt']),
      category: json['category'] ?? 'General',
      tags: List<String>.from(json['tags'] ?? []),
      contactEmail: json['contactEmail'] ?? '',
      contactPhone: json['contactPhone'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      refundEnabled: json['refundEnabled'] ?? false,
      refundDeadlineDays: json['refundDeadlineDays'] ?? 0,
      refundMethodDetails: json['refundMethodDetails'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'bannerUrl': bannerUrl,
      'location': location,
      'clubId': clubId,
      'clubName': clubName,
      'clubImageUrl': clubImageUrl,
      'maxAttendees': maxAttendees,
      'price': price,
      'isFree': isFree,
      'refundPolicy': refundPolicy,
      'publishTime': publishTime,
      'createdAt': createdAt?.toIso8601String(),
      'status': status,
      'attendees': attendees,
      'attendeesEmail': attendeesEmail, // Added this missing field
      'waitlist': waitlist,
      'views': views,
      'shares': shares,
      'isCancelled': isCancelled,
      'updatedAt': updatedAt?.toIso8601String(),
      'category': category,
      'tags': tags,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'latitude': latitude,
      'longitude': longitude,
      'refundEnabled': refundEnabled,
      'refundDeadlineDays': refundDeadlineDays,
      'refundMethodDetails': refundMethodDetails,
    };
  }

  // Enhanced date and time formatting
  String get formattedDate {
    final timestamp = int.tryParse(date);
    if (timestamp == null) return 'Date not set';
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${_getWeekday(dateTime.weekday)}, ${dateTime.day} ${_getMonth(dateTime.month)} ${dateTime.year}';
  }

  String get formattedTime {
    if (startTime.isEmpty || endTime.isEmpty) return 'Time not set';
    return '$startTime - $endTime';
  }

  String get formattedDateTime {
    return '$formattedDate at $formattedTime';
  }

  DateTime get dateTime {
    final timestamp = int.tryParse(date);
    return timestamp != null 
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : DateTime.now();
  }

  // Helper methods for weekday and month names
  String _getWeekday(int weekday) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[weekday - 1];
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  // Helper methods for analytics
  bool get isCompleted => status == 'completed';
  bool get isUpcoming => status == 'upcoming';
  bool get isDraft => status == 'draft';
  bool get isPublished => status == 'published';
  bool get isCancelledStatus => status == 'cancelled' || isCancelled;
  
  int get attendanceCount => attendees.length;
  int get waitlistCount => waitlist.length;
  
  double get capacityUtilization {
    if (maxAttendees <= 0) return 0.0;
    return (attendees.length / maxAttendees) * 100;
  }
  
  double get totalRevenue {
    if (isFree) return 0.0;
    return price * attendees.length;
  }
  
  bool get isFull {
    if (maxAttendees <= 0) return false;
    return attendees.length >= maxAttendees;
  }
  
  bool get hasWaitlist {
    return maxAttendees > 0 && attendees.length >= maxAttendees;
  }

  bool get hasContactInfo {
    return contactEmail.isNotEmpty || contactPhone.isNotEmpty;
  }

  String get priceDisplay {
    if (isFree) return 'FREE';
    return 'RM${price.toStringAsFixed(2)}';
  }

  String get capacityDisplay {
    if (maxAttendees <= 0) return 'Unlimited';
    return '$attendanceCount / $maxAttendees';
  }

  // Check if user is attending
  bool isUserAttending(String userId) {
    return attendees.contains(userId);
  }

  // Check if user is on waitlist
  bool isUserOnWaitlist(String userId) {
    return waitlist.contains(userId);
  }

  /// Returns a new [EventModel] copying current values and replacing
  /// any provided fields. Useful for keeping the model immutable while
  /// updating a single field (for example, assigning an ID before save).
  EventModel copyWith({
    String? id,
    String? name,
    String? description,
    String? date,
    String? startTime,
    String? endTime,
    String? bannerUrl,
    String? location,
    double? latitude, 
    double? longitude, 
    String? clubId,
    String? clubName,
    String? clubImageUrl,
    int? maxAttendees,
    double? price,
    bool? isFree,
    String? refundPolicy,
    String? publishTime,
    DateTime? createdAt,
    String? status,
    List<String>? attendees,
    List<String>? waitlist,
    int? views,
    int? shares,
    bool? isCancelled,
    DateTime? updatedAt,
    String? category,
    List<String>? tags,
    String? contactEmail,
    String? contactPhone,
    bool? refundEnabled,
    int? refundDeadlineDays,
    String? refundMethodDetails,
  }) {
    return EventModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude, 
      longitude: longitude ?? this.longitude, 
      clubId: clubId ?? this.clubId,
      clubName: clubName ?? this.clubName,
      clubImageUrl: clubImageUrl ?? this.clubImageUrl,
      maxAttendees: maxAttendees ?? this.maxAttendees,
      price: price ?? this.price,
      isFree: isFree ?? this.isFree,
      refundPolicy: refundPolicy ?? this.refundPolicy,
      publishTime: publishTime ?? this.publishTime,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      attendees: attendees ?? this.attendees,
      waitlist: waitlist ?? this.waitlist,
      views: views ?? this.views,
      shares: shares ?? this.shares,
      isCancelled: isCancelled ?? this.isCancelled,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      refundEnabled: refundEnabled ?? this.refundEnabled,
      refundDeadlineDays: refundDeadlineDays ?? this.refundDeadlineDays,
      refundMethodDetails: refundMethodDetails ?? this.refundMethodDetails,
    );
  }

  // Add attendee to event
  EventModel addAttendee(String userId) {
    if (attendees.contains(userId)) return this;
    
    return copyWith(
      attendees: [...attendees, userId],
      updatedAt: DateTime.now(),
    );
  }

  // Remove attendee from event
  EventModel removeAttendee(String userId) {
    if (!attendees.contains(userId)) return this;
    
    return copyWith(
      attendees: attendees.where((id) => id != userId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  // Add user to waitlist
  EventModel addToWaitlist(String userId) {
    if (waitlist.contains(userId) || attendees.contains(userId)) return this;
    
    return copyWith(
      waitlist: [...waitlist, userId],
      updatedAt: DateTime.now(),
    );
  }

  // Remove user from waitlist
  EventModel removeFromWaitlist(String userId) {
    if (!waitlist.contains(userId)) return this;
    
    return copyWith(
      waitlist: waitlist.where((id) => id != userId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  // Promote from waitlist to attendee
  EventModel promoteFromWaitlist(String userId) {
    if (!waitlist.contains(userId) || attendees.contains(userId)) return this;
    
    return copyWith(
      waitlist: waitlist.where((id) => id != userId).toList(),
      attendees: [...attendees, userId],
      updatedAt: DateTime.now(),
    );
  }

  // Mark event as completed
  EventModel markAsCompleted() {
    return copyWith(
      status: 'completed',
      updatedAt: DateTime.now(),
    );
  }

  // Mark event as published
  EventModel markAsPublished() {
    return copyWith(
      status: 'published',
      publishTime: DateTime.now().millisecondsSinceEpoch.toString(),
      updatedAt: DateTime.now(),
    );
  }

  // Mark event as draft
  EventModel markAsDraft() {
    return copyWith(
      status: 'draft',
      updatedAt: DateTime.now(),
    );
  }

  // Mark event as cancelled
  EventModel markAsCancelled() {
    return copyWith(
      status: 'cancelled',
      isCancelled: true,
      updatedAt: DateTime.now(),
    );
  }

  // Increment views
  EventModel incrementViews() {
    return copyWith(
      views: views + 1,
      updatedAt: DateTime.now(),
    );
  }

  // Increment shares
  EventModel incrementShares() {
    return copyWith(
      shares: shares + 1,
      updatedAt: DateTime.now(),
    );
  }

  // Update event with new image
  EventModel updateBanner(String newBannerUrl) {
    return copyWith(
      bannerUrl: newBannerUrl,
      updatedAt: DateTime.now(),
    );
  }

  // Add tag to event
  EventModel addTag(String tag) {
    if (tags.contains(tag)) return this;
    
    return copyWith(
      tags: [...tags, tag],
      updatedAt: DateTime.now(),
    );
  }

  // Remove tag from event
  EventModel removeTag(String tag) {
    if (!tags.contains(tag)) return this;
    
    return copyWith(
      tags: tags.where((t) => t != tag).toList(),
      updatedAt: DateTime.now(),
    );
  }

  // Check if event is happening today
  bool get isToday {
    final now = DateTime.now();
    final eventDate = dateTime;
    return now.year == eventDate.year &&
           now.month == eventDate.month &&
           now.day == eventDate.day;
  }

  // Check if event is happening in the future
  bool get isFuture {
    return dateTime.isAfter(DateTime.now());
  }

  // Check if event is happening in the past
  bool get isPast {
    return dateTime.isBefore(DateTime.now());
  }

  // Get days until event
  int get daysUntil {
    final now = DateTime.now();
    final eventDate = dateTime;
    return eventDate.difference(now).inDays;
  }

  @override
  String toString() {
    return 'EventModel(id: $id, name: $name, date: $formattedDate, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // --- HELPER: CHECK IF EDIT IS ALLOWED ---
  // Returns TRUE if we are currently BEFORE the 3-day lockout
  bool get canEdit {
    // If date isn't set, allow edit
    final timestamp = int.tryParse(date);
    if (timestamp == null) return true;
    
    final eventDateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    // Deadline is 3 days before the event
    final deadline = eventDateTime.subtract(const Duration(days: 3));
    
    return DateTime.now().isBefore(deadline);
  }
}