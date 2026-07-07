class RatingModel {
  final String id;
  final String requestId;
  final String raterId;
  final String ratedId;
  final int score;
  final String? comment;
  final DateTime createdAt;

  RatingModel({
    required this.id,
    required this.requestId,
    required this.raterId,
    required this.ratedId,
    required this.score,
    this.comment,
    required this.createdAt,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      raterId: json['rater_id'] as String,
      ratedId: json['rated_id'] as String,
      score: (json['score'] as num).toInt(),
      comment: json['comment'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'rater_id': raterId,
      'rated_id': ratedId,
      'score': score,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
