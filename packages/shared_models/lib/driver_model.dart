import 'user_role.dart';
import 'user_model.dart';

class DriverModel extends UserModel {
  final String vehiclePlate;
  final String vehicleType;
  final bool isAvailable;
  final bool isVerified;
  final double? latitude;
  final double? longitude;
  final int totalServices;
  
  // Verification documents
  final String? driverLicenseUrl;
  final String? srcCertificateUrl;
  final String? psychotechnicUrl;
  final String? vehicleRegistrationUrl;
  final String? taxPlateUrl;
  final String? criminalRecordUrl;
  
  // Photos, equipment and vehicle types
  final List<String> vehiclePhotos;
  final List<String> equipments;
  final List<String> supportedVehicleTypes;
  final bool isOnboardingCompleted;

  // Payment info
  final String? iban;
  final String? ibanOwnerName;

  // Admin verification info
  final String? rejectionReason;

  DriverModel({
    required super.id,
    required super.email,
    required super.fullName,
    super.phone,
    required super.role,
    required super.createdAt,
    super.avatarUrl,
    super.isSuspended = false,
    required this.vehiclePlate,
    this.vehicleType = 'small',
    this.isAvailable = false,
    this.isVerified = false,
    this.latitude,
    this.longitude,
    super.rating = 0.0,
    super.totalRatings = 0,
    this.totalServices = 0,
    this.driverLicenseUrl,
    this.srcCertificateUrl,
    this.psychotechnicUrl,
    this.vehicleRegistrationUrl,
    this.taxPlateUrl,
    this.criminalRecordUrl,
    this.vehiclePhotos = const [],
    this.equipments = const [],
    this.supportedVehicleTypes = const [],
    this.isOnboardingCompleted = false,
    this.iban,
    this.ibanOwnerName,
    this.rejectionReason,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json, Map<String, dynamic> driverJson) {
    final user = UserModel.fromJson(json);
    return DriverModel(
      id: user.id,
      email: user.email,
      fullName: user.fullName,
      phone: user.phone,
      role: user.role,
      createdAt: user.createdAt,
      avatarUrl: user.avatarUrl,
      isSuspended: user.isSuspended,
      vehiclePlate: driverJson['vehicle_plate'] as String? ?? '',
      vehicleType: driverJson['vehicle_type'] as String? ?? 'small',
      isAvailable: driverJson['is_available'] as bool? ?? false,
      isVerified: driverJson['is_verified'] as bool? ?? false,
      latitude: (driverJson['latitude'] as num?)?.toDouble(),
      longitude: (driverJson['longitude'] as num?)?.toDouble(),
      rating: (driverJson['rating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: driverJson['total_ratings'] as int? ?? 0,
      totalServices: driverJson['total_services'] as int? ?? 0,
      driverLicenseUrl: driverJson['driver_license_url'] as String?,
      srcCertificateUrl: driverJson['src_certificate_url'] as String?,
      psychotechnicUrl: driverJson['psychotechnic_url'] as String?,
      vehicleRegistrationUrl: driverJson['vehicle_registration_url'] as String?,
      taxPlateUrl: driverJson['tax_plate_url'] as String?,
      criminalRecordUrl: driverJson['criminal_record_url'] as String?,
      vehiclePhotos: (driverJson['vehicle_photos'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      equipments: (driverJson['equipments'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      supportedVehicleTypes: (driverJson['supported_vehicle_types'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      isOnboardingCompleted: driverJson['is_onboarding_completed'] as bool? ?? false,
      iban: driverJson['iban'] as String?,
      ibanOwnerName: driverJson['iban_owner_name'] as String?,
      rejectionReason: driverJson['rejection_reason'] as String?,
    );
  }

  Map<String, dynamic> toDriverJson() {
    return {
      'id': id,
      'vehicle_plate': vehiclePlate,
      'vehicle_type': vehicleType,
      'is_available': isAvailable,
      'is_verified': isVerified,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'total_ratings': totalRatings,
      'total_services': totalServices,
      'driver_license_url': driverLicenseUrl,
      'src_certificate_url': srcCertificateUrl,
      'psychotechnic_url': psychotechnicUrl,
      'vehicle_registration_url': vehicleRegistrationUrl,
      'tax_plate_url': taxPlateUrl,
      'criminal_record_url': criminalRecordUrl,
      'vehicle_photos': vehiclePhotos,
      'equipments': equipments,
      'supported_vehicle_types': supportedVehicleTypes,
      'is_onboarding_completed': isOnboardingCompleted,
      'iban': iban,
      'iban_owner_name': ibanOwnerName,
      'rejection_reason': rejectionReason,
    };
  }

  @override
  DriverModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    UserRole? role,
    DateTime? createdAt,
    String? avatarUrl,
    String? vehiclePlate,
    String? vehicleType,
    bool? isAvailable,
    bool? isVerified,
    double? latitude,
    double? longitude,
    double? rating,
    int? totalRatings,
    int? totalServices,
    String? driverLicenseUrl,
    String? srcCertificateUrl,
    String? psychotechnicUrl,
    String? vehicleRegistrationUrl,
    String? taxPlateUrl,
    String? criminalRecordUrl,
    List<String>? vehiclePhotos,
    List<String>? equipments,
    List<String>? supportedVehicleTypes,
    bool? isOnboardingCompleted,
    String? iban,
    String? ibanOwnerName,
    String? rejectionReason,
    bool? isSuspended,
  }) {
    return DriverModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isSuspended: isSuspended ?? this.isSuspended,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleType: vehicleType ?? this.vehicleType,
      isAvailable: isAvailable ?? this.isAvailable,
      isVerified: isVerified ?? this.isVerified,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      totalServices: totalServices ?? this.totalServices,
      driverLicenseUrl: driverLicenseUrl ?? this.driverLicenseUrl,
      srcCertificateUrl: srcCertificateUrl ?? this.srcCertificateUrl,
      psychotechnicUrl: psychotechnicUrl ?? this.psychotechnicUrl,
      vehicleRegistrationUrl: vehicleRegistrationUrl ?? this.vehicleRegistrationUrl,
      taxPlateUrl: taxPlateUrl ?? this.taxPlateUrl,
      criminalRecordUrl: criminalRecordUrl ?? this.criminalRecordUrl,
      vehiclePhotos: vehiclePhotos ?? this.vehiclePhotos,
      equipments: equipments ?? this.equipments,
      supportedVehicleTypes: supportedVehicleTypes ?? this.supportedVehicleTypes,
      isOnboardingCompleted: isOnboardingCompleted ?? this.isOnboardingCompleted,
      iban: iban ?? this.iban,
      ibanOwnerName: ibanOwnerName ?? this.ibanOwnerName,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
