import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_models/feedback_model.dart';
import 'supabase_service.dart';

class FeedbackRepository {
  final SupabaseClient _client = SupabaseService.instance.client;

  Future<void> submitFeedback({
    required String title,
    required String message,
    required String category,
    required String userRole,
    String? attachmentUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Giriş yapmış kullanıcı bulunamadı.');

    await _client.from('feedbacks').insert({
      'user_id': user.id,
      'user_role': userRole,
      'category': category,
      'title': title,
      'message': message,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      'status': 'pending',
    });
  }

  Future<List<FeedbackModel>> getAllFeedbacks() async {
    try {
      final data = await _client
          .from('feedbacks')
          .select('*, profiles:user_id(full_name, email)')
          .order('created_at', ascending: false);

      return (data as List).map((json) => FeedbackModel.fromJson(Map<String, dynamic>.from(json))).toList();
    } catch (e) {
      debugPrint('[FeedbackRepository] getAllFeedbacks error: $e');
      // Fallback simple query
      final data = await _client
          .from('feedbacks')
          .select('*')
          .order('created_at', ascending: false);
      return (data as List).map((json) => FeedbackModel.fromJson(Map<String, dynamic>.from(json))).toList();
    }
  }

  Future<void> updateFeedbackStatus(String id, String status, {String? adminNotes}) async {
    await _client.from('feedbacks').update({
      'status': status,
      if (adminNotes != null) 'admin_notes': adminNotes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}

