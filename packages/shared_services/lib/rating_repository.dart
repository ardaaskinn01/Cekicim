import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_models/rating_model.dart';
import 'supabase_service.dart';

class RatingRepository {
  final SupabaseClient _client = SupabaseService.instance.client;

  Future<void> submitRating(RatingModel rating) async {
    await _client.from('ratings').insert(rating.toJson());

    // Update rated user statistics if they are a driver
    final driverCheck = await _client.from('drivers').select('id, rating, total_ratings').eq('id', rating.ratedId).maybeSingle();
    if (driverCheck != null) {
      final currentRating = (driverCheck['rating'] as num?)?.toDouble() ?? 0.0;
      final totalRatings = (driverCheck['total_ratings'] as int?) ?? 0;

      final newTotal = totalRatings + 1;
      final newRating = ((currentRating * totalRatings) + rating.score) / newTotal;

      await _client.from('drivers').update({
        'rating': newRating,
        'total_ratings': newTotal,
      }).eq('id', rating.ratedId);
    }
  }

  Future<List<RatingModel>> getRatingsForUser(String userId) async {
    final data = await _client.from('ratings').select().eq('rated_id', userId).order('created_at', ascending: false);
    return (data as List).map((json) => RatingModel.fromJson(json)).toList();
  }

  Future<double> getAverageRating(String userId) async {
    final ratings = await getRatingsForUser(userId);
    if (ratings.isEmpty) return 0.0;
    final total = ratings.fold<double>(0.0, (sum, item) => sum + item.score);
    return total / ratings.length;
  }
}
