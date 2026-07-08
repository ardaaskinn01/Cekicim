import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_models/rating_model.dart';
import 'supabase_service.dart';

class RatingRepository {
  final SupabaseClient _client = SupabaseService.instance.client;

  Future<void> submitRating(RatingModel rating) async {
    try {
      await _client.from('ratings').insert(rating.toJson());
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception('Bu talep için zaten değerlendirme yaptınız.');
      }
      throw Exception('Değerlendirme kaydedilemedi: ${e.message}');
    } catch (e) {
      throw Exception('Bir hata oluştu: $e');
    }
  }

  Future<void> blockDriver(String customerId, String driverId) async {
    await _client.from('blocked_drivers').upsert({
      'customer_id': customerId,
      'driver_id': driverId,
    });
  }

  Future<void> blockCustomer(String driverId, String customerId) async {
    await _client.from('blocked_customers').upsert({
      'driver_id': driverId,
      'customer_id': customerId,
    });
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
