import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_models/request_status.dart';
import 'package:shared_models/driver_model.dart';
import 'package:shared_models/service_request_model.dart';
import 'package:shared_models/message_model.dart';
import 'location_utils.dart';
import 'supabase_service.dart';

class RequestRepository {
  final SupabaseClient _client = SupabaseService.instance.client;

  Future<void> updateDriverLocation(String driverId, double lat, double lng) async {
    await _client.from('drivers').update({
      'latitude': lat,
      'longitude': lng,
      'location_updated_at': DateTime.now().toIso8601String(),
    }).eq('id', driverId);
  }

  Future<void> updateDriverOnlineStatus(String driverId, bool isAvailable) async {
    await _client.from('drivers').update({
      'is_available': isAvailable,
      if (isAvailable) 'current_request_id': null,
    }).eq('id', driverId);
  }

  Future<void> resetDriverAvailability(String driverId) async {
    await _client.from('drivers').update({
      'current_request_id': null,
      'is_available': true,
    }).eq('id', driverId);
  }

  Stream<DriverModel> watchDriverLocation(String driverId) {
    return _client
        .from('drivers')
        .stream(primaryKey: ['id'])
        .eq('id', driverId)
        .asyncMap((dataList) async {
          if (dataList.isEmpty) {
            throw Exception('Driver not found');
          }
          final driverData = dataList.first;
          final profileData = await _client.from('profiles').select().eq('id', driverId).single();
          return DriverModel.fromJson(profileData, driverData);
        });
  }

  Future<void> expireStuckRequests() async {
    try {
      await _client.rpc('expire_stuck_requests');
    } catch (e) {
      debugPrint('expireStuckRequests error: $e');
    }
  }

  Stream<ServiceRequestModel?> watchActiveRequest(String customerId) {
    // Run auto-expiration in background asynchronously
    expireStuckRequests();

    return _client
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('customer_id', customerId)
        .map((dataList) {
          final activeRequests = dataList.where((json) {
            final statusStr = json['status'] as String?;
            return statusStr != 'completed' && statusStr != 'cancelled';
          }).toList();

          if (activeRequests.isEmpty) return null;
          return ServiceRequestModel.fromJson(activeRequests.first);
        });
  }

  Stream<ServiceRequestModel?> watchActiveRequestForDriver(String driverId) {
    expireStuckRequests();

    return _client
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .map((dataList) {
          final activeRequests = dataList.where((json) {
            final statusStr = json['status'] as String?;
            return statusStr != 'completed' && statusStr != 'cancelled';
          }).toList();

          if (activeRequests.isEmpty) return null;
          return ServiceRequestModel.fromJson(activeRequests.first);
        });
  }

  Stream<ServiceRequestModel> watchRequestStatus(String requestId) {
    // Use periodic HTTP polling instead of .stream() to avoid RLS issues
    // where selected_driver_ids-based access can return empty before subscription settles.
    final controller = StreamController<ServiceRequestModel>();

    Future<void> fetchOnce() async {
      try {
        final data = await _client
            .from('service_requests')
            .select('*, customer:profiles!service_requests_customer_id_fkey(full_name), driver:profiles!service_requests_driver_id_fkey(full_name)')
            .eq('id', requestId)
            .maybeSingle();
        if (data != null && !controller.isClosed) {
          controller.add(ServiceRequestModel.fromJson(data));
        }
      } catch (_) {}
    }

    Timer? timer;
    fetchOnce().then((_) {
      timer = Timer.periodic(const Duration(seconds: 3), (_) => fetchOnce());
    });

    controller.onCancel = () {
      timer?.cancel();
      controller.close();
    };

    return controller.stream;
  }

  Stream<List<Map<String, dynamic>>> watchPendingOffersForDriver(String driverId) {
    return _client
        .from('pending_offers')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .map((list) => list.where((item) => item['status'] == 'pending').toList());
  }

  Future<void> _cleanupStaleDrivers() async {
    try {
      final cutoff = DateTime.now().toUtc().subtract(const Duration(minutes: 240)).toIso8601String();
      await _client
          .from('drivers')
          .update({'is_available': false})
          .eq('is_available', true)
          .not('location_updated_at', 'is', null)
          .lt('location_updated_at', cutoff);
    } catch (e) {
      debugPrint('Stale driver cleanup error: $e');
    }
  }

  Future<List<DriverModel>> getAllAvailableDrivers({String? customerId}) async {
    await _cleanupStaleDrivers();

    List<String> blockedDriverIds = [];
    List<String> blockingDriverIds = [];
    if (customerId != null) {
      final blocked = await _client
          .from('blocked_drivers')
          .select('driver_id')
          .eq('customer_id', customerId);
      blockedDriverIds = (blocked as List).map((r) => r['driver_id'] as String).toList();

      final blocking = await _client
          .from('blocked_customers')
          .select('driver_id')
          .eq('customer_id', customerId);
      blockingDriverIds = (blocking as List).map((r) => r['driver_id'] as String).toList();
    }

    final driversData = await _client
        .from('drivers')
        .select('*, profiles(*)')
        .eq('is_available', true);

    List<DriverModel> list = [];
    for (var d in driversData) {
      final driverId = d['id'] as String?;
      if (driverId == null) continue;
      if (blockedDriverIds.contains(driverId)) continue;
      if (blockingDriverIds.contains(driverId)) continue;
      if (d['is_available'] != true) continue;
      if (d['current_request_id'] != null) continue;

      final profileJson = d['profiles'] as Map<String, dynamic>?;
      if (profileJson == null) continue;
      final isSuspended = profileJson['is_suspended'] as bool? ?? false;
      if (isSuspended) continue;
      list.add(DriverModel.fromJson(profileJson, d));
    }
    return list;
  }

  Future<ServiceRequestModel> getRequestById(String requestId) async {
    final data = await _client
        .from('service_requests')
        .select('*, customer:profiles!service_requests_customer_id_fkey(full_name), driver:profiles!service_requests_driver_id_fkey(full_name)')
        .eq('id', requestId)
        .single();
    return ServiceRequestModel.fromJson(data);
  }

  Future<List<DriverModel>> getNearbyAvailableDrivers(
    double lat,
    double lng,
    double radiusKm,
    String vehicleType, {
    String? customerId,
  }) async {
    await _cleanupStaleDrivers();
    // Fetch blocked driver IDs for this customer (if provided)
    List<String> blockedDriverIds = [];
    List<String> blockingDriverIds = [];
    if (customerId != null) {
      final blocked = await _client
          .from('blocked_drivers')
          .select('driver_id')
          .eq('customer_id', customerId);
      blockedDriverIds = (blocked as List).map((r) => r['driver_id'] as String).toList();

      final blocking = await _client
          .from('blocked_customers')
          .select('driver_id')
          .eq('customer_id', customerId);
      blockingDriverIds = (blocking as List).map((r) => r['driver_id'] as String).toList();
    }

    // Only get active drivers
    final driversData = await _client
        .from('drivers')
        .select('*, profiles(*)')
        .eq('is_available', true);

    List<DriverModel> nearby = [];

    for (var d in driversData) {
      // Skip blocked drivers
      if (blockedDriverIds.contains(d['id'] as String?)) continue;
      if (blockingDriverIds.contains(d['id'] as String?)) continue;

      // Skip drivers explicitly offline
      if (d['is_available'] != true) continue;

      // Auto-clear and verify current_request_id (prevent leftover request ID from blocking driver)
      final activeReqId = d['current_request_id'] as String?;
      if (activeReqId != null && activeReqId.isNotEmpty) {
        try {
          final reqData = await _client.from('service_requests').select('status').eq('id', activeReqId).maybeSingle();
          final reqStatus = reqData?['status'] as String?;
          if (reqStatus == 'completed' || reqStatus == 'cancelled' || reqData == null) {
            // Leftover request ID from completed/cancelled job — auto-clear it!
            _client.from('drivers').update({'current_request_id': null}).eq('id', d['id']).catchError((_) {});
          } else {
            // Driver is actually busy on an ongoing active job
            continue;
          }
        } catch (_) {}
      }

      final profileJson = d['profiles'] as Map<String, dynamic>?;
      if (profileJson == null) continue;

      // Skip suspended drivers
      final isSuspended = profileJson['is_suspended'] as bool? ?? false;
      if (isSuspended) continue;

      final driverLat = (d['latitude'] as num?)?.toDouble();
      final driverLng = (d['longitude'] as num?)?.toDouble();

      final supportedTypes = (d['supported_vehicle_types'] as List<dynamic>?)
              ?.map((e) => e.toString().toLowerCase())
              .toList() ??
          [];
      if (supportedTypes.isNotEmpty && vehicleType.isNotEmpty) {
        final target = vehicleType.toLowerCase();
        final matches = supportedTypes.any((t) =>
            t == target ||
            t.contains(target) ||
            target.contains(t) ||
            (target.contains('oto') && t.contains('auto')) ||
            (target.contains('auto') && t.contains('oto')));
        if (!matches) continue;
      }

      if (driverLat != null && driverLng != null) {
        final dist = LocationUtils.distanceBetween(lat, lng, driverLat, driverLng);
        if (dist <= radiusKm) {
          nearby.add(DriverModel.fromJson(profileJson, d));
        }
      } else {
        // Driver is online but hasn't populated lat/lng on 'drivers' table yet — include them!
        nearby.add(DriverModel.fromJson(profileJson, d));
      }
    }

    nearby.sort((a, b) {
      final latA = a.latitude ?? lat;
      final lngA = a.longitude ?? lng;
      final latB = b.latitude ?? lat;
      final lngB = b.longitude ?? lng;
      final distA = LocationUtils.distanceBetween(lat, lng, latA, lngA);
      final distB = LocationUtils.distanceBetween(lat, lng, latB, lngB);
      return distA.compareTo(distB);
    });

    return nearby;
  }

  Future<String> createRequest(ServiceRequestModel request) async {
    final response = await _client.from('service_requests').insert(request.toJson()).select('id').single();
    return response['id'] as String;
  }

  Future<void> sendAlarmToDrivers(String requestId, List<String> driverIds) async {
    // 1. Update service request selected drivers and status
    await _client.from('service_requests').update({
      'selected_driver_ids': driverIds,
      'status': RequestStatus.awaitingAcceptance.dbValue,
    }).eq('id', requestId);

    // 2. Insert rows into pending_offers table so driver streams are notified in real-time
    if (driverIds.isNotEmpty) {
      final inserts = driverIds.map((driverId) => {
        'request_id': requestId,
        'driver_id': driverId,
        'status': 'pending',
      }).toList();
      await _client.from('pending_offers').insert(inserts);
    }

    // 3. Invoke FCM send edge function
    try {
      await _client.functions.invoke('send_driver_alarms', body: {
        'request_id': requestId,
        'driver_ids': driverIds,
      });
    } catch (e) {
      debugPrint('Warning: Failed to invoke send_driver_alarms edge function.');
    }
  }

  Future<void> sendCallNotification({
    required String requestId,
    required String targetUserId,
    String? callerName,
  }) async {
    try {
      final name = callerName ?? 'Kullanıcı';
      await _client.functions.invoke('send_driver_alarms', body: {
        'request_id': requestId,
        'driver_ids': [targetUserId],
        'notification_type': 'VOIP_CALL',
        'type': 'call',
        'title': '📞 Gelen Sesli Arama',
        'body': '$name sizi arıyor. Görüşmeyi yanıtlamak için tıklayın.',
      });
    } catch (e) {
      debugPrint('Warning: Failed to invoke send_driver_alarms for VOIP_CALL: $e');
    }
  }

  Future<void> acceptRequest(String requestId, String driverId) async {
    final data = await _client.from('service_requests').update({
      'status': RequestStatus.accepted.dbValue,
      'driver_id': driverId,
      'accepted_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId).eq('status', RequestStatus.awaitingAcceptance.dbValue).select().maybeSingle();

    if (data == null) {
      throw Exception('Talep zaten kabul edilmiş veya iptal edilmiş.');
    }

    await _client.from('drivers').update({
      'current_request_id': requestId,
      'is_available': false,
    }).eq('id', driverId);

    // Update the accepting driver's own pending offer to 'accepted' so it is cleared from their pending list
    try {
      await _client.from('pending_offers').update({
        'status': 'accepted',
      }).eq('request_id', requestId).eq('driver_id', driverId);
    } catch (_) {}

    // Notify other drivers that the request has been taken
    try {
      final List<dynamic> selectedIdsRaw = data['selected_driver_ids'] ?? [];
      final selectedDriverIds = selectedIdsRaw.map((id) => id.toString()).toList();
      final otherDriverIds = selectedDriverIds.where((id) => id != driverId).toList();

      if (otherDriverIds.isNotEmpty) {
        // 1. Update other pending offers to 'taken' status
        await _client.from('pending_offers').update({
          'status': 'taken',
        }).eq('request_id', requestId).neq('driver_id', driverId);

        // 2. Send push notifications using Deno Edge function
        await _client.functions.invoke('send_driver_alarms', body: {
          'request_id': requestId,
          'driver_ids': otherDriverIds,
          'notification_type': 'REQUEST_TAKEN',
        });
      }
    } catch (e) {
      debugPrint('Error notifying other drivers of accepted request: $e');
    }
  }

  Future<void> verifyPickupCode(String requestId, String code) async {
    final request = await getRequestById(requestId);
    if (request.completionCode != code) {
      throw Exception('Biniş kodu hatalı.');
    }

    await _client.from('service_requests').update({
      'status': RequestStatus.inProgress.dbValue,
    }).eq('id', requestId);
  }

  Future<void> completeRequest(String requestId) async {
    final request = await getRequestById(requestId);

    await _client.from('service_requests').update({
      'status': RequestStatus.completed.dbValue,
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);

    if (request.driverId != null) {
      await _client.from('drivers').update({
        'current_request_id': null,
        'is_available': true,
        'location_updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', request.driverId!);
    }
  }

  Future<void> cancelRequestByCustomer(String requestId, String reason) async {
    final request = await getRequestById(requestId);
    
    await _client.from('service_requests').update({
      'status': RequestStatus.cancelled.dbValue,
      'cancellation_reason': reason,
      'cancelled_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);

    // Cancel all pending offers for this request to notify drivers
    try {
      await _client.from('pending_offers').update({
        'status': 'cancelled',
      }).eq('request_id', requestId);
    } catch (_) {}

    if (request.driverId != null) {
      await _client.from('drivers').update({
        'current_request_id': null,
        'is_available': true,
        'location_updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', request.driverId!);
    }
  }

  Future<void> cancelRequestByDriver(String requestId, String driverId, String reason) async {
    await _client.from('service_requests').update({
      'status': RequestStatus.cancelled.dbValue,
      'cancellation_reason': reason,
      'cancelled_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);

    // Cancel all pending offers for this request to notify drivers
    try {
      await _client.from('pending_offers').update({
        'status': 'cancelled',
      }).eq('request_id', requestId);
    } catch (_) {}

    await _client.from('drivers').update({
      'current_request_id': null,
      'is_available': true,
      'location_updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', driverId);
  }

  Future<void> updateRequestStatus(String requestId, RequestStatus status) async {
    await _client.from('service_requests').update({
      'status': status.dbValue,
      if (status == RequestStatus.accepted) 'accepted_at': DateTime.now().toIso8601String(),
      if (status == RequestStatus.completed) 'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  Future<void> updateCallStatus(String requestId, String? channelId, String? callerId) async {
    await _client.from('service_requests').update({
      'active_call_channel': channelId,
      'active_call_caller_id': callerId,
    }).eq('id', requestId);
  }

  Future<List<ServiceRequestModel>> getCustomerHistory(String customerId) async {
    final data = await _client
        .from('service_requests')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);

    return (data as List).map((json) => ServiceRequestModel.fromJson(json)).toList();
  }

  Future<List<ServiceRequestModel>> getDriverHistory(String driverId) async {
    final data = await _client
        .from('service_requests')
        .select()
        .eq('driver_id', driverId)
        .eq('status', 'completed')
        .order('completed_at', ascending: false);

    return (data as List).map((json) => ServiceRequestModel.fromJson(json)).toList();
  }

  Stream<List<MessageModel>> watchMessages(String requestId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .map((dataList) {
          final messages = dataList.map((json) => MessageModel.fromJson(json)).toList();
          messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return messages;
        });
  }

  Future<void> sendMessage(String requestId, String senderId, String content) async {
    await _client.from('messages').insert({
      'request_id': requestId,
      'sender_id': senderId,
      'content': content,
    });
  }

  Future<String> uploadRequestPhoto({
    required String requestId,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    final path = '$requestId/$fileName';
    await _client.storage.from('request-photos').uploadBinary(
      path,
      Uint8List.fromList(fileBytes),
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );
    return _client.storage.from('request-photos').getPublicUrl(path);
  }

  Future<void> updateRequestPhotoUrl(String requestId, String photoUrl) async {
    await _client.from('service_requests').update({
      'vehicle_photo_url': photoUrl,
    }).eq('id', requestId);
  }

  Future<void> updateOfferStatus(String requestId, String driverId, String status, {String? reason}) async {
    await _client
        .from('pending_offers')
        .update({
          'status': status,
          if (reason != null) 'rejection_reason': reason,
        })
        .eq('request_id', requestId)
        .eq('driver_id', driverId);
  }

  /// Called on driver app startup to clear all stale pending offers.
  /// This prevents the "talep iptal edildi" error when re-running the app.
  Future<void> expireAllPendingOffersForDriver(String driverId) async {
    await _client
        .from('pending_offers')
        .update({'status': 'expired'})
        .eq('driver_id', driverId)
        .eq('status', 'pending');
  }


  Future<Map<String, double>> getDriverEarningsSummary(String driverId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    
    // Start of the week (Monday)
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day).toIso8601String();

    final todayData = await _client
        .from('service_requests')
        .select('price')
        .eq('driver_id', driverId)
        .eq('status', 'completed')
        .gte('completed_at', todayStart);

    final weekData = await _client
        .from('service_requests')
        .select('price')
        .eq('driver_id', driverId)
        .eq('status', 'completed')
        .gte('completed_at', weekStart);

    final double todayTotal = (todayData as List).fold(0.0, (sum, item) => sum + (item['price'] as num).toDouble());
    final double weekTotal = (weekData as List).fold(0.0, (sum, item) => sum + (item['price'] as num).toDouble());

    return {
      'today': todayTotal,
      'week': weekTotal,
    };
  }
}
