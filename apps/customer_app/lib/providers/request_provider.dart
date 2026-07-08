import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/request_status.dart';
import 'package:shared_models/driver_model.dart';
import 'package:shared_models/service_request_model.dart';
import 'package:shared_models/message_model.dart';
import 'package:shared_services/request_repository.dart';
import 'auth_provider.dart';

final requestRepositoryProvider = Provider<RequestRepository>((ref) {
  return RequestRepository();
});

final activeRequestProvider = StreamProvider<ServiceRequestModel?>((ref) {
  final currentUserAsync = ref.watch(currentUserProvider);
  final user = currentUserAsync.value;
  if (user == null) return Stream.value(null);

  final repo = ref.watch(requestRepositoryProvider);
  return repo.watchActiveRequest(user.id);
});

class RequestNotifier extends StateNotifier<AsyncValue<String?>> {
  final RequestRepository _repository;

  RequestNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<String> createRequest(ServiceRequestModel request) async {
    state = const AsyncValue.loading();
    try {
      final id = await _repository.createRequest(request);
      state = AsyncValue.data(id);
      return id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> cancelRequest(String requestId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.cancelRequestByCustomer(requestId, 'Müşteri tarafından iptal edildi');
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
  Future<void> updateRequestStatus(String requestId, RequestStatus status) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateRequestStatus(requestId, status);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final requestNotifierProvider = StateNotifierProvider<RequestNotifier, AsyncValue<String?>>((ref) {
  final repo = ref.watch(requestRepositoryProvider);
  return RequestNotifier(repo);
});

final requestStatusProvider = StreamProvider.family<ServiceRequestModel, String>((ref, requestId) {
  final repo = ref.watch(requestRepositoryProvider);
  return repo.watchRequestStatus(requestId);
});

final driverLocationProvider = StreamProvider.family<DriverModel, String>((ref, driverId) {
  final repo = ref.watch(requestRepositoryProvider);
  return repo.watchDriverLocation(driverId);
});

final messagesStreamProvider = StreamProvider.family<List<MessageModel>, String>((ref, requestId) {
  final repo = ref.watch(requestRepositoryProvider);
  return repo.watchMessages(requestId);
});

