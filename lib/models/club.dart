import 'user.dart';

class Club {
  final String id;
  final String name;
  final String description;
  final String createdBy; // Store user ID instead of full UserModel
  final String imageUrl;
  final List<String> memberIds; // Store member IDs instead of full UserModels
  final List<String> adminIds; // Club admins who can manage the club
  final List<String> eventIds; // Store event IDs created by this club
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final String status; // 'pending', 'approved', 'rejected'
  final String? contactEmail;
  final String? contactPhone;
  final String? website;
  final String? location;
  final List<String> categories; // Club categories/tags
  final String? approvalLetterUrl; // URL to uploaded approval letter

  Club({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.imageUrl,
    required this.memberIds,
    required this.adminIds,
    required this.eventIds,
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.status = 'pending', // Default to pending for new clubs
    this.contactEmail,
    this.contactPhone,
    this.website,
    this.location,
    this.categories = const [],
    this.approvalLetterUrl,
  });

  factory Club.fromFirestore(Map<String, dynamic> json) {
    return Club(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      createdBy: json['createdBy'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      memberIds: List<String>.from(json['memberIds'] ?? []),
      adminIds: List<String>.from(json['adminIds'] ?? []),
      eventIds: List<String>.from(json['eventIds'] ?? []),
      createdAt: json['createdAt']?.toDate(),
      updatedAt: json['updatedAt']?.toDate(),
      isActive: json['isActive'] ?? true,
      status: json['status'] ?? 'pending',
      contactEmail: json['contactEmail'],
      contactPhone: json['contactPhone'],
      website: json['website'],
      location: json['location'],
      categories: List<String>.from(json['categories'] ?? []),
      approvalLetterUrl: json['approvalLetterUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'imageUrl': imageUrl,
      'memberIds': memberIds,
      'adminIds': adminIds,
      'eventIds': eventIds,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isActive': isActive,
      'status': status,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'website': website,
      'location': location,
      'categories': categories,
      'approvalLetterUrl': approvalLetterUrl,
    };
  }

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      createdBy: json['createdBy'],
      imageUrl: json['imageUrl'] ?? '',
      memberIds: List<String>.from(json['memberIds'] ?? []),
      adminIds: List<String>.from(json['adminIds'] ?? []),
      eventIds: List<String>.from(json['eventIds'] ?? []),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      isActive: json['isActive'] ?? true,
      status: json['status'] ?? 'pending',
      contactEmail: json['contactEmail'],
      contactPhone: json['contactPhone'],
      website: json['website'],
      location: json['location'],
      categories: List<String>.from(json['categories'] ?? []),
      approvalLetterUrl: json['approvalLetterUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'imageUrl': imageUrl,
      'memberIds': memberIds,
      'adminIds': adminIds,
      'eventIds': eventIds,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isActive': isActive,
      'status': status,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'website': website,
      'location': location,
      'categories': categories,
      'approvalLetterUrl': approvalLetterUrl,
    };
  }

  Club copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    String? imageUrl,
    List<String>? memberIds,
    List<String>? adminIds,
    List<String>? eventIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? status,
    String? contactEmail,
    String? contactPhone,
    String? website,
    String? location,
    List<String>? categories,
    String? approvalLetterUrl,
  }) {
    return Club(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      imageUrl: imageUrl ?? this.imageUrl,
      memberIds: memberIds ?? this.memberIds,
      adminIds: adminIds ?? this.adminIds,
      eventIds: eventIds ?? this.eventIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      website: website ?? this.website,
      location: location ?? this.location,
      categories: categories ?? this.categories,
      approvalLetterUrl: approvalLetterUrl ?? this.approvalLetterUrl,
    );
  }

  // Helper methods
  bool get isPublic => true; // You can add visibility settings later
  int get memberCount => memberIds.length;
  int get eventCount => eventIds.length;
  
  // Status checkers
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  
  // Check if club can create events
  bool get canCreateEvents => isApproved && isActive;
  
  // Check if user is a member
  bool isMember(String userId) => memberIds.contains(userId);
  
  // Check if user is an admin
  bool isAdmin(String userId) => adminIds.contains(userId);
  
  // Check if user is the creator
  bool isCreator(String userId) => createdBy == userId;
  
  // Check if user can manage the club (creator or admin)
  bool canManage(String userId) => isCreator(userId) || isAdmin(userId);

  // Check if user can create events for this club
  bool canUserCreateEvents(String userId) => canManage(userId) && canCreateEvents;

  // Add member to club
  Club addMember(String userId) {
    return copyWith(
      memberIds: [...memberIds, userId],
      updatedAt: DateTime.now(),
    );
  }

  // Remove member from club
  Club removeMember(String userId) {
    return copyWith(
      memberIds: memberIds.where((id) => id != userId).toList(),
      adminIds: adminIds.where((id) => id != userId).toList(), // Also remove from admins
      updatedAt: DateTime.now(),
    );
  }

  // Add admin to club
  Club addAdmin(String userId) {
    // Ensure user is a member first
    final newMemberIds = memberIds.contains(userId) ? memberIds : [...memberIds, userId];
    final newAdminIds = [...adminIds, userId];
    
    return copyWith(
      memberIds: newMemberIds,
      adminIds: newAdminIds,
      updatedAt: DateTime.now(),
    );
  }

  // Remove admin from club (but keep as member)
  Club removeAdmin(String userId) {
    return copyWith(
      adminIds: adminIds.where((id) => id != userId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  // Add event to club
  Club addEvent(String eventId) {
    return copyWith(
      eventIds: [...eventIds, eventId],
      updatedAt: DateTime.now(),
    );
  }

  // Remove event from club
  Club removeEvent(String eventId) {
    return copyWith(
      eventIds: eventIds.where((id) => id != eventId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  // Update club status
  Club updateStatus(String newStatus) {
    return copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );
  }

  // Set approval letter URL
  Club setApprovalLetter(String url) {
    return copyWith(
      approvalLetterUrl: url,
      updatedAt: DateTime.now(),
    );
  }

  // Check if club has approval letter
  bool get hasApprovalLetter => approvalLetterUrl != null && approvalLetterUrl!.isNotEmpty;

  // Get display status with color
  Map<String, dynamic> get statusInfo {
    switch (status) {
      case 'approved':
        return {'text': 'Approved', 'color': 'green'};
      case 'pending':
        return {'text': 'Pending Approval', 'color': 'orange'};
      case 'rejected':
        return {'text': 'Rejected', 'color': 'red'};
      default:
        return {'text': 'Unknown', 'color': 'gray'};
    }
  }

  // Validate club data for creation
  bool get isValidForCreation {
    return name.isNotEmpty && 
           description.isNotEmpty && 
           createdBy.isNotEmpty;
  }

  // Get contact information summary
  String get contactSummary {
    final contacts = <String>[];
    if (contactEmail != null && contactEmail!.isNotEmpty) {
      contacts.add(contactEmail!);
    }
    if (contactPhone != null && contactPhone!.isNotEmpty) {
      contacts.add(contactPhone!);
    }
    return contacts.join(' • ');
  }

  // Check if club needs approval (for new clubs)
  bool get needsApproval => isPending && hasApprovalLetter;
}