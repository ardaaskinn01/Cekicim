import 'user_role.dart';

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final UserRole role;
  final DateTime createdAt;
  final String? avatarUrl;
  final bool isVerified;
  final double rating;
  final int totalRatings;

  final bool isSuspended;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
    required this.createdAt,
    this.avatarUrl,
    this.isVerified = false,
    this.rating = 5.0,
    this.totalRatings = 0,
    this.isSuspended = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String?,
      role: UserRole.fromString(json['role'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      avatarUrl: json['avatar_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      totalRatings: json['total_ratings'] as int? ?? 0,
      isSuspended: json['is_suspended'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'role': role.dbValue,
      'created_at': createdAt.toIso8601String(),
      'avatar_url': avatarUrl,
      'is_verified': isVerified,
      'rating': rating,
      'total_ratings': totalRatings,
      'is_suspended': isSuspended,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    UserRole? role,
    DateTime? createdAt,
    String? avatarUrl,
    bool? isVerified,
    double? rating,
    int? totalRatings,
    bool? isSuspended,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      isSuspended: isSuspended ?? this.isSuspended,
    );
  }
}
