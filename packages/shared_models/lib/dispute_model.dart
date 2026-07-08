enum DisputeStatus {
  pending,
  investigating,
  resolved,
  dismissed;

  String get label {
    switch (this) {
      case DisputeStatus.pending:
        return 'Beklemede';
      case DisputeStatus.investigating:
        return 'İnceleniyor';
      case DisputeStatus.resolved:
        return 'Çözüldü';
      case DisputeStatus.dismissed:
        return 'Reddedildi';
    }
  }

  String get dbValue {
    switch (this) {
      case DisputeStatus.pending:
        return 'pending';
      case DisputeStatus.investigating:
        return 'investigating';
      case DisputeStatus.resolved:
        return 'resolved';
      case DisputeStatus.dismissed:
        return 'dismissed';
    }
  }

  static DisputeStatus fromString(String? value) {
    switch (value) {
      case 'investigating':
        return DisputeStatus.investigating;
      case 'resolved':
        return DisputeStatus.resolved;
      case 'dismissed':
        return DisputeStatus.dismissed;
      case 'pending':
      default:
        return DisputeStatus.pending;
    }
  }
}

class DisputeModel {
  final String id;
  final String requestId;
  final String reporterId;
  final String reportedId;
  final String title;
  final String description;
  final DisputeStatus status;
  final String? adminNotes;
  final DateTime createdAt;

  DisputeModel({
    required this.id,
    required this.requestId,
    required this.reporterId,
    required this.reportedId,
    required this.title,
    required this.description,
    this.status = DisputeStatus.pending,
    this.adminNotes,
    required this.createdAt,
  });

  factory DisputeModel.fromJson(Map<String, dynamic> json) {
    return DisputeModel(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      reporterId: json['reporter_id'] as String,
      reportedId: json['reported_id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: DisputeStatus.fromString(json['status'] as String?),
      adminNotes: json['admin_notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'request_id': requestId,
      'reporter_id': reporterId,
      'reported_id': reportedId,
      'title': title,
      'description': description,
      'status': status.dbValue,
      'admin_notes': adminNotes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  DisputeModel copyWith({
    String? id,
    String? requestId,
    String? reporterId,
    String? reportedId,
    String? title,
    String? description,
    DisputeStatus? status,
    String? adminNotes,
    DateTime? createdAt,
  }) {
    return DisputeModel(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      reporterId: reporterId ?? this.reporterId,
      reportedId: reportedId ?? this.reportedId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
