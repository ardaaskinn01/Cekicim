import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_models/dispute_model.dart';
import 'package:shared_models/message_model.dart';
import 'supabase_service.dart';

class DisputeRepository {
  final SupabaseClient _client = SupabaseService.instance.client;

  Future<void> createDispute(DisputeModel dispute) async {
    await _client.from('disputes').insert(dispute.toJson());
  }

  Future<List<DisputeModel>> getDisputesForUser(String userId) async {
    final data = await _client
        .from('disputes')
        .select()
        .or('reporter_id.eq.$userId,reported_id.eq.$userId')
        .order('created_at', ascending: false);
    return (data as List).map((json) => DisputeModel.fromJson(json)).toList();
  }

  Future<List<DisputeModel>> getAllDisputes() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) throw Exception('Yetkisiz işlem.');

    final profile = await _client.from('profiles').select('role').eq('id', currentUser.id).single();
    if (profile['role'] != 'admin') {
      throw Exception('Bu işlem için yönetici yetkiniz bulunmamaktadır.');
    }

    final data = await _client
        .from('disputes')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((json) => DisputeModel.fromJson(json)).toList();
  }

  Future<void> updateDisputeStatus(String disputeId, DisputeStatus status, String? adminNotes) async {
    await _client.from('disputes').update({
      'status': status.dbValue,
      'admin_notes': adminNotes,
    }).eq('id', disputeId);
  }

  Future<List<MessageModel>> getRequestChatLogs(String requestId) async {
    final data = await _client
        .from('messages')
        .select()
        .eq('request_id', requestId)
        .order('created_at', ascending: true);
    return (data as List).map((json) => MessageModel.fromJson(json)).toList();
  }
}
