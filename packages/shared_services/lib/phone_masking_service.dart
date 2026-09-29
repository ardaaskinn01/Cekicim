import 'supabase_service.dart';

class PhoneMaskingService {
  final _client = SupabaseService.instance.client;

  /// Supabase Edge Function'ı tetikleyerek sürücü ile müşteri arasında 0850 araması başlatır.
  Future<void> initiateMaskedCall(String requestId) async {
    try {
      final response = await _client.functions.invoke(
        'mask-call',
        body: {'request_id': requestId},
      );
      
      if (response.status != 200) {
        throw Exception(response.data['error'] ?? 'Arama başlatılamadı.');
      }
    } catch (e) {
      throw Exception('Arama Hatası: $e');
    }
  }
}
