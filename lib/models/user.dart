class UserModel {
  final String id;
  final String email;
  final String name;
  final String role;
  final String photoUrl;
  final List<String> clubIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String status; // Add status field

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.photoUrl,
    required this.clubIds,
    this.createdAt,
    this.updatedAt,
    this.status = 'approved', // Default status
  });

  factory UserModel.fromFirestore(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'user',
      photoUrl: json['photoUrl'] ?? '',
      clubIds: List<String>.from(json['clubIds'] ?? []),
      createdAt: json['createdAt']?.toDate(),
      updatedAt: json['updatedAt']?.toDate(),
      status: json['status'] ?? 'approved', // Add status
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'photoUrl': photoUrl,
      'clubIds': clubIds,
      'status': status, // Add status
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Add status-related helper methods
  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get canCreateEvents => (isClub || isAdmin) && isApproved;
  
  // Update other helper methods to consider status
  bool get isParticipant => role == 'participant' && isApproved;
  bool get isClub => role == 'club';
  bool get isAdmin => role == 'admin';

  // In copyWith method, add status
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    String? photoUrl,
    List<String>? clubIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status, // Add status
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      clubIds: clubIds ?? this.clubIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status, // Add status
    );
  }
}