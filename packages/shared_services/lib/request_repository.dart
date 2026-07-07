import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_models/request_status.dart';
import 'package:shared_models/driver_model.dart';
import 'package:shared_models/service_request_model.dart';
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

  Stream<ServiceRequestModel?> watchActiveRequest(String customerId) {
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

  Stream<ServiceRequestModel> watchRequestStatus(String requestId) {
    return _client
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('id', requestId)
        .map((dataList) {
          if (dataList.isEmpty) {
            throw Exception('Request not found');
          }
          return ServiceRequestModel.fromJson(dataList.first);
        });
  }

  Stream<List<Map<String, dynamic>>> watchPendingOffersForDriver(String driverId) {
    return _client
        .from('pending_offers')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .map((list) => list.where((item) => item['status'] == 'pending').toList());
  }

  Future<ServiceRequestModel> getRequestById(String requestId) async {
    final data = await _client.from('service_requests').select().eq('id', requestId).single();
    return ServiceRequestModel.fromJson(data);
  }

  Future<List<DriverModel>> findNearbyDrivers(double lat, double lng, double radiusKm) async {
    final driversData = await _client.from('drivers').select('*, profiles(*)').eq('is_available', true);

    List<DriverModel> nearby = [];
    for (var d in driversData) {
      final driverLat = (d['latitude'] as num?)?.toDouble();
      final driverLng = (d['longitude'] as num?)?.toDouble();
      if (driverLat != null && driverLng != null) {
        final dist = LocationUtils.distanceBetween(lat, lng, driverLat, driverLng);
        if (dist <= radiusKm) {
          final profileJson = d['profiles'] as Map<String, dynamic>;
          nearby.add(DriverModel.fromJson(profileJson, d));
        }
      }
    }

    nearby.sort((a, b) {
      final distA = LocationUtils.distanceBetween(lat, lng, a.latitude!, a.longitude!);
      final distB = LocationUtils.distanceBetween(lat, lng, b.latitude!, b.longitude!);
      return distA.compareTo(distB);
    });

    return nearby;
  }

  Future<String> createRequestAndMatch(ServiceRequestModel request) async {
    final response = await _client.from('service_requests').insert(request.toJson()).select('id').single();
    final requestId = response['id'] as String;

    final nearbyDrivers = await findNearbyDrivers(request.customerLat, request.customerLng, 15.0);
    final topDrivers = nearbyDrivers.take(5).toList();

    for (var driver in topDrivers) {
      await _client.from('pending_offers').insert({
        'request_id': requestId,
        'driver_id': driver.id,
        'status': 'pending',
      });
    }

    return requestId;
  }

  Future<void> acceptOffer(String requestId, String driverId) async {
    await _client.from('service_requests').update({
      'status': 'accepted',
      'driver_id': driverId,
      'accepted_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);

    await _client.from('drivers').update({
      'current_request_id': requestId,
    }).eq('id', driverId);

    await _client.from('pending_offers').update({'status': 'expired'}).eq('request_id', requestId);
    await _client.from('pending_offers').update({'status': 'accepted'}).eq('request_id', requestId).eq('driver_id', driverId);
  }

  Future<void> rejectOffer(String requestId, String driverId) async {
    await _client.from('pending_offers').update({
      'status': 'rejected',
    }).eq('request_id', requestId).eq('driver_id', driverId);
  }

  Future<void> completeService(String requestId, String driverId) async {
    await _client.from('service_requests').update({
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);

    await _client.from('drivers').update({
      'current_request_id': null,
    }).eq('id', driverId);
  }

  Future<void> cancelRequest(String requestId) async {
    await _client.from('service_requests').update({
      'status': 'cancelled',
      'cancelled_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  Future<void> updateRequestStatus(String requestId, RequestStatus status) async {
    await _client.from('service_requests').update({
      'status': status.dbValue,
      if (status == RequestStatus.accepted) 'accepted_at': DateTime.now().toIso8601String(),
      if (status == RequestStatus.completed) 'completed_at': DateTime.now().toIso8601String(),
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
}
