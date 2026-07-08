class MessageModel {
  final String id;
  final String requestId;
  final String senderId;
  final String content;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.requestId,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'sender_id': senderId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
