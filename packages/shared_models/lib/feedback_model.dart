class FeedbackModel {
  final String id;
  final String userId;
  final String userRole;
  final String category;
  final String title;
  final String message;
  final String? attachmentUrl;
  final String status;
  final String? adminNotes;
  final DateTime createdAt;
  final String? userName;
  final String? userEmail;

  FeedbackModel({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.category,
    required this.title,
    required this.message,
    this.attachmentUrl,
    required this.status,
    this.adminNotes,
    required this.createdAt,
    this.userName,
    this.userEmail,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return FeedbackModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userRole: json['user_role'] as String? ?? 'customer',
      category: json['category'] as String? ?? 'general',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      attachmentUrl: json['attachment_url'] as String?,
      status: json['status'] as String? ?? 'pending',
      adminNotes: json['admin_notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      userName: profile?['full_name'] as String?,
      userEmail: profile?['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_role': userRole,
      'category': category,
      'title': title,
      'message': message,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      'status': status,
      if (adminNotes != null) 'admin_notes': adminNotes,
    };
  }

  String get categoryLabel {
    switch (category) {
      case 'bug':
        return 'Hata Bildirimi';
      case 'suggestion':
        return 'Öneri / Fikir';
      case 'complaint':
        return 'Şikayet';
      case 'satisfaction':
        return 'Memnuniyet';
      default:
        return 'Genel Görüş';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'resolved':
        return 'Çözüldü';
      case 'reviewed':
        return 'İncelendi';
      default:
        return 'Beklemede';
    }
  }
}

