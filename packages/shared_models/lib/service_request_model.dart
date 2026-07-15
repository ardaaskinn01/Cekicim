import 'request_status.dart';

class ServiceRequestModel {
  final String id;
  final String customerId;
  final String? driverId;
  final double customerLat;
  final double customerLng;
  final String? customerAddress;
  final double? destinationLat;
  final double? destinationLng;
  final String? destinationAddress;
  final String carBrand;
  final String carModel;
  final String carColor;
  final String carPlate;
  final String problemType;
  final String? problemDescription;
  final double distanceKm;
  final double price;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final String? customerPhone;
  final String? vehicleType;
  final String? vehiclePhotoUrl;
  final List<String> selectedDriverIds;
  final String? destinationIndustryZone;
  final String? completionCode;
  final String? cancellationReason;
  final DateTime? cancelledAt;
  final String? activeCallChannel;
  final String? activeCallCallerId;
  final String? customerName;
  final String? driverName;
  final double? customerRatingFromDriver;
  final double? driverRatingFromCustomer;

  ServiceRequestModel({
    required this.id,
    required this.customerId,
    this.driverId,
    required this.customerLat,
    required this.customerLng,
    this.customerAddress,
    this.destinationLat,
    this.destinationLng,
    this.destinationAddress,
    required this.carBrand,
    required this.carModel,
    required this.carColor,
    required this.carPlate,
    required this.problemType,
    this.problemDescription,
    required this.distanceKm,
    required this.price,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.completedAt,
    this.customerPhone,
    this.vehicleType,
    this.vehiclePhotoUrl,
    this.selectedDriverIds = const [],
    this.destinationIndustryZone,
    this.completionCode,
    this.cancellationReason,
    this.cancelledAt,
    this.activeCallChannel,
    this.activeCallCallerId,
    this.customerName,
    this.driverName,
    this.customerRatingFromDriver,
    this.driverRatingFromCustomer,
  });

  factory ServiceRequestModel.fromJson(Map<String, dynamic> json) {
    return ServiceRequestModel(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      driverId: json['driver_id'] as String?,
      customerLat: (json['customer_lat'] as num).toDouble(),
      customerLng: (json['customer_lng'] as num).toDouble(),
      customerAddress: json['customer_address'] as String?,
      destinationLat: (json['destination_lat'] as num?)?.toDouble(),
      destinationLng: (json['destination_lng'] as num?)?.toDouble(),
      destinationAddress: json['destination_address'] as String?,
      carBrand: json['car_brand'] as String? ?? '',
      carModel: json['car_model'] as String? ?? '',
      carColor: json['car_color'] as String? ?? '',
      carPlate: json['car_plate'] as String? ?? '',
      problemType: json['problem_type'] as String? ?? 'breakdown',
      problemDescription: json['problem_description'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      status: RequestStatus.fromString(json['status'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      customerPhone: json['customer_phone'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      vehiclePhotoUrl: json['vehicle_photo_url'] as String?,
      selectedDriverIds: (json['selected_driver_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      destinationIndustryZone: json['destination_industry_zone'] as String?,
      completionCode: json['completion_code'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      activeCallChannel: json['active_call_channel'] as String?,
      activeCallCallerId: json['active_call_caller_id'] as String?,
      customerName: json['customer'] != null ? json['customer']['full_name'] as String? : null,
      driverName: json['driver'] != null ? json['driver']['full_name'] as String? : null,
      customerRatingFromDriver: _parseCustomerRating(json['ratings'], json['customer_id'] as String),
      driverRatingFromCustomer: _parseDriverRating(json['ratings'], json['customer_id'] as String),
    );
  }

  static double? _parseCustomerRating(dynamic ratingsList, String customerId) {
    if (ratingsList == null || ratingsList is! List) return null;
    for (var r in ratingsList) {
      if (r['rated_id'] == customerId) {
        return (r['score'] as num?)?.toDouble();
      }
    }
    return null;
  }

  static double? _parseDriverRating(dynamic ratingsList, String customerId) {
    if (ratingsList == null || ratingsList is! List) return null;
    for (var r in ratingsList) {
      if (r['rater_id'] == customerId) {
        return (r['score'] as num?)?.toDouble();
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    final data = {
      'customer_id': customerId,
      'driver_id': driverId,
      'customer_lat': customerLat,
      'customer_lng': customerLng,
      'customer_address': customerAddress,
      'destination_lat': destinationLat,
      'destination_lng': destinationLng,
      'destination_address': destinationAddress,
      'car_brand': carBrand,
      'car_model': carModel,
      'car_color': carColor,
      'car_plate': carPlate,
      'problem_type': problemType,
      'problem_description': problemDescription,
      'distance_km': distanceKm,
      'price': price,
      'status': status.dbValue,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'customer_phone': customerPhone,
      'vehicle_type': vehicleType,
      'vehicle_photo_url': vehiclePhotoUrl,
      'selected_driver_ids': selectedDriverIds,
      'destination_industry_zone': destinationIndustryZone,
      'completion_code': completionCode,
      'cancellation_reason': cancellationReason,
      'cancelled_at': cancelledAt?.toIso8601String(),
      'active_call_channel': activeCallChannel,
      'active_call_caller_id': activeCallCallerId,
    };
    if (id.isNotEmpty) {
      data['id'] = id;
    }
    return data;
  }

  ServiceRequestModel copyWith({
    String? id,
    String? customerId,
    String? driverId,
    double? customerLat,
    double? customerLng,
    String? customerAddress,
    double? destinationLat,
    double? destinationLng,
    String? destinationAddress,
    String? carBrand,
    String? carModel,
    String? carColor,
    String? carPlate,
    String? problemType,
    String? problemDescription,
    double? distanceKm,
    double? price,
    RequestStatus? status,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
    String? customerPhone,
    String? vehicleType,
    String? vehiclePhotoUrl,
    List<String>? selectedDriverIds,
    String? destinationIndustryZone,
    String? completionCode,
    String? cancellationReason,
    DateTime? cancelledAt,
    String? activeCallChannel,
    String? activeCallCallerId,
    String? customerName,
    String? driverName,
    double? customerRatingFromDriver,
    double? driverRatingFromCustomer,
  }) {
    return ServiceRequestModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      driverId: driverId ?? this.driverId,
      customerLat: customerLat ?? this.customerLat,
      customerLng: customerLng ?? this.customerLng,
      customerAddress: customerAddress ?? this.customerAddress,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      carBrand: carBrand ?? this.carBrand,
      carModel: carModel ?? this.carModel,
      carColor: carColor ?? this.carColor,
      carPlate: carPlate ?? this.carPlate,
      problemType: problemType ?? this.problemType,
      problemDescription: problemDescription ?? this.problemDescription,
      distanceKm: distanceKm ?? this.distanceKm,
      price: price ?? this.price,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      customerPhone: customerPhone ?? this.customerPhone,
      vehicleType: vehicleType ?? this.vehicleType,
      vehiclePhotoUrl: vehiclePhotoUrl ?? this.vehiclePhotoUrl,
      selectedDriverIds: selectedDriverIds ?? this.selectedDriverIds,
      destinationIndustryZone: destinationIndustryZone ?? this.destinationIndustryZone,
      completionCode: completionCode ?? this.completionCode,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      activeCallChannel: activeCallChannel ?? this.activeCallChannel,
      activeCallCallerId: activeCallCallerId ?? this.activeCallCallerId,
      customerName: customerName ?? this.customerName,
      driverName: driverName ?? this.driverName,
      customerRatingFromDriver: customerRatingFromDriver ?? this.customerRatingFromDriver,
      driverRatingFromCustomer: driverRatingFromCustomer ?? this.driverRatingFromCustomer,
    );
  }
}
