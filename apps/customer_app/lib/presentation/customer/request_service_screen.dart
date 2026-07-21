import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_services/location_utils.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_models/driver_model.dart';
import 'package:shared_models/service_request_model.dart';
import 'package:shared_models/request_status.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/request_provider.dart';
import 'package:shared_ui/widgets/map_widget.dart';
import 'package:shared_ui/widgets/app_text_field.dart';
import 'package:shared_ui/widgets/green_button.dart';
import 'package:shared_ui/widgets/loading_overlay.dart';

class RequestServiceScreen extends ConsumerStatefulWidget {
  const RequestServiceScreen({super.key});

  @override
  ConsumerState<RequestServiceScreen> createState() => _RequestServiceScreenState();
}

class _RequestServiceScreenState extends ConsumerState<RequestServiceScreen> {
  int _currentStep = 0;
  LatLng _selectedLatLng = const LatLng(39.9208, 32.8541); // Default Ankara
  
  String? _selectedVehicleType;
  final _plateController = TextEditingController();
  XFile? _vehiclePhoto;
  
  // For pickup (Step 0)
  final _pickupSearchController = TextEditingController();
  List<Map<String, dynamic>> _pickupSearchResults = [];
  bool _isSearchingPickup = false;
  String? _pickupAddress;
  bool _isPickupSelected = false;
  String? _pickupSearchError;

  // For dropoff (Step 1)
  final _dropoffSearchController = TextEditingController();
  List<Map<String, dynamic>> _dropoffSearchResults = [];
  bool _isSearchingDropoff = false;
  LatLng? _destinationLatLng;
  String? _destinationAddress;
  String? _dropoffSearchError;
  
  List<DriverModel> _nearbyDrivers = [];
  List<String> _selectedDriverIds = [];
  
  bool _isLoading = false;

  final List<String> _vehicleTypes = [
    'Sedan / Hatchback',
    'SUV / Pick-up',
    'Minibüs / Hafif Ticari',
    'Motosiklet',
    'Ağır Vasıta (Otobüs / Kamyon)',
  ];

  @override
  void initState() {
    super.initState();
    final pos = ref.read(locationProvider).value;
    if (pos != null) {
      _selectedLatLng = LatLng(pos.latitude, pos.longitude);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = GoRouterState.of(context);
      final queryParams = state.uri.queryParameters;
      if (queryParams.isNotEmpty) {
        final plate = queryParams['plate'];
        final vehicleType = queryParams['vehicleType'];

        if (plate != null) {
          _plateController.text = plate;
        }
        if (vehicleType != null && _vehicleTypes.contains(vehicleType)) {
          setState(() => _selectedVehicleType = vehicleType);
        }
      }
    });
  }

  double _calculatePrice(double dist) {
    double price = 2000.0;
    if (dist > 1.0) {
      if (dist <= 15.0) {
        price += (dist - 1.0) * 200.0;
      } else {
        price += (14.0 * 200.0) + (dist - 15.0) * 150.0;
      }
    }
    // Round to nearest 100 TL step (e.g., 2140 -> 2100 TL)
    return (price / 100).round() * 100.0;
  }

  @override
  void dispose() {
    _plateController.dispose();
    _pickupSearchController.dispose();
    _dropoffSearchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _searchAddress(String query) async {
    if (query.trim().isEmpty) return [];

    const googleApiKey = 'AIzaSyAgKEFl5fFWgP4Oncf9ee6yNyceR49t4NI';
    const timeout = Duration(seconds: 8);

    // 1. Try Google Geocoding API with 8-second timeout
    try {
      final client = HttpClient();
      client.connectionTimeout = timeout;
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=$googleApiKey&components=country:tr',
      );
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join().timeout(timeout);
        final Map<String, dynamic> data = json.decode(responseBody);
        if (data['status'] == 'OK' && data['results'] != null) {
          final List<dynamic> results = data['results'];
          return results.map((item) {
            final geometry = item['geometry']['location'];
            return {
              'display_name': item['formatted_address'] as String,
              'lat': geometry['lat'] as double,
              'lon': geometry['lng'] as double,
            };
          }).toList();
        }
      }
    } on TimeoutException {
      throw Exception('network_timeout');
    } catch (e) {
      if (e.toString().contains('network_timeout')) rethrow;
      debugPrint('Google Geocoding error: $e');
    }

    // 2. Fallback to Nominatim with 8-second timeout
    try {
      final client = HttpClient();
      client.connectionTimeout = timeout;
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1&countrycodes=tr',
      );
      final request = await client.getUrl(uri).timeout(timeout);
      request.headers.set('User-Agent', 'CekicimApp-CustomerPlatform/1.0 (ardaaskinn01@gmail.com)');
      final response = await request.close().timeout(timeout);
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join().timeout(timeout);
        final List<dynamic> data = json.decode(responseBody);
        return data.map((item) {
          return {
            'display_name': item['display_name'] as String,
            'lat': double.parse(item['lat'] as String),
            'lon': double.parse(item['lon'] as String),
          };
        }).toList();
      }
    } on TimeoutException {
      throw Exception('network_timeout');
    } catch (e) {
      if (e.toString().contains('network_timeout')) rethrow;
      debugPrint('Address search fallback error: $e');
    }
    return [];
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    // 1. Try Google Reverse Geocoding API first
    const googleApiKey = 'AIzaSyAgKEFl5fFWgP4Oncf9ee6yNyceR49t4NI';
    try {
      final client = HttpClient();
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lon&key=$googleApiKey'
      );
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data = json.decode(responseBody);
        if (data['status'] == 'OK' && data['results'] != null && (data['results'] as List).isNotEmpty) {
          return data['results'][0]['formatted_address'] as String?;
        }
      }
    } catch (e) {
      debugPrint('Google Reverse Geocoding error: $e');
    }

    // 2. Fallback to Nominatim with a distinct User-Agent to prevent 403 blocks
    try {
      final client = HttpClient();
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1'
      );
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'CekicimApp-CustomerPlatform/1.0 (ardaaskinn01@gmail.com)');
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data = json.decode(responseBody);
        return data['display_name'] as String?;
      }
    } catch (e) {
      debugPrint('Reverse geocoding fallback error: $e');
    }
    return null;
  }

  Future<void> _useCurrentLocationForPickup() async {
    setState(() => _isLoading = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      final address = await _reverseGeocode(latLng.latitude, latLng.longitude);
      
      setState(() {
        _selectedLatLng = latLng;
        _pickupAddress = address ?? 'Konumum (${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)})';
        _isPickupSelected = true;
        _pickupSearchController.text = _pickupAddress!;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Konum bilgisi alınamadı: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _useCurrentLocationForDropoff() async {
    setState(() => _isLoading = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      final address = await _reverseGeocode(latLng.latitude, latLng.longitude);
      
      setState(() {
        _destinationLatLng = latLng;
        _destinationAddress = address ?? 'Konumum (${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)})';
        _dropoffSearchController.text = _destinationAddress!;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Konum bilgisi alınamadı: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickVehiclePhoto() async {
    final picker = ImagePicker();
    final result = await showModalBottomSheet<XFile?>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: AppColors.primary),
            title: const Text('Kamerayı Kullan'),
            onTap: () async {
              final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
              if (ctx.mounted) Navigator.pop(ctx, img);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: AppColors.primary),
            title: const Text('Galeriden Seç'),
            onTap: () async {
              final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
              if (ctx.mounted) Navigator.pop(ctx, img);
            },
          ),
        ]),
      ),
    );
    if (result != null) setState(() => _vehiclePhoto = result);
  }

  Future<void> _fetchDrivers() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(requestRepositoryProvider);
      final currentUser = ref.read(currentUserProvider).value;
      final drivers = await repo.getNearbyAvailableDrivers(
        _selectedLatLng.latitude,
        _selectedLatLng.longitude,
        30.0,
        _selectedVehicleType!,
        customerId: currentUser?.id,
      );
      setState(() {
        _nearbyDrivers = drivers;
        _selectedDriverIds = _nearbyDrivers.map((d) => d.id).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sürücüler alınırken hata oluştu: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitRequest() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('Kullanıcı oturumu bulunamadı');

      final repo = ref.read(requestRepositoryProvider);

      double distance = 10.0;
      if (_destinationLatLng != null) {
        distance = LocationUtils.distanceBetween(
          _selectedLatLng.latitude,
          _selectedLatLng.longitude,
          _destinationLatLng!.latitude,
          _destinationLatLng!.longitude,
        );
      }

      // Calculate price dynamically (rounded to nearest 100 TL)
      final price = _calculatePrice(distance);

      // Generate a random 4-digit completion code
      final random = (1000 + (DateTime.now().microsecondsSinceEpoch % 9000)).toString();

      final tempRequest = ServiceRequestModel(
        id: '',
        customerId: user.id,
        customerLat: _selectedLatLng.latitude,
        customerLng: _selectedLatLng.longitude,
        customerAddress: _pickupAddress ?? 'Seçilen Konum',
        destinationLat: _destinationLatLng?.latitude,
        destinationLng: _destinationLatLng?.longitude,
        destinationAddress: _destinationAddress ?? 'Seçilen Hedef',
        destinationIndustryZone: _destinationAddress ?? 'Seçilen Hedef',
        carBrand: '',
        carModel: '',
        carColor: '',
        carPlate: _plateController.text.trim(),
        problemType: 'Diğer',
        vehicleType: _selectedVehicleType,
        vehiclePhotoUrl: null,
        selectedDriverIds: _selectedDriverIds,
        distanceKm: distance,
        price: price,
        status: RequestStatus.awaitingAcceptance,
        createdAt: DateTime.now(),
        customerPhone: user.phone ?? '08501234567',
        completionCode: random,
      );

      final requestId = await repo.createRequest(tempRequest);

      if (_vehiclePhoto != null) {
        try {
          final bytes = await _vehiclePhoto!.readAsBytes();
          final cleanFileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final photoUrl = await repo.uploadRequestPhoto(
            requestId: requestId,
            fileName: cleanFileName,
            fileBytes: bytes,
          );
          await repo.updateRequestPhotoUrl(requestId, photoUrl);
        } catch (storageError) {
          debugPrint('Storage upload error: $storageError');
        }
      }

      await repo.sendAlarmToDrivers(requestId, _selectedDriverIds);

      if (!mounted) return;
      context.go('/customer/tracking/$requestId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Talep oluşturulamadı: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_selectedVehicleType == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen araç tipini seçin.')));
        return;
      }
      if (_plateController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen plakayı girin.')));
        return;
      }
      if (_vehiclePhoto == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen aracın fotoğrafını çekin.')));
        return;
      }
      if (!_isPickupSelected) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen alınacak konumu aratıp seçin.')));
        return;
      }
      setState(() => _currentStep++);
    } else if (_currentStep == 1) {
      if (_destinationLatLng == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen gidilecek konumu aratıp seçin.')));
        return;
      }
      _fetchDrivers();
      setState(() => _currentStep++);
    } else {
      _submitRequest();
    }
  }

  Widget _buildStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: List.generate(3, (index) {
          final isCompleted = _currentStep > index;
          final isActive = _currentStep == index;
          
          return Expanded(
            child: Row(
              children: [
                // Step Circle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isCompleted 
                        ? AppColors.primary
                        : (isActive ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isCompleted || isActive) ? AppColors.primary : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive ? AppColors.primary : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                // Step Line Connection
                if (index < 2)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 2,
                      color: isCompleted ? AppColors.primary : AppColors.border,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Position?>>(locationProvider, (prev, next) {
      final pos = next.value;
      if (pos != null && _selectedLatLng == const LatLng(39.9208, 32.8541) && !_isPickupSelected) {
        setState(() {
          _selectedLatLng = LatLng(pos.latitude, pos.longitude);
        });
      }
    });

    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'İşlem yapılıyor...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Çekici Çağır'),
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildStepper(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: _buildStepContent(),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.cardBackground,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _currentStep--),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Geri', style: TextStyle(color: AppColors.textPrimary)),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GreenButton(
                        text: _currentStep == 2 ? 'En Yakın Çekiciyi Ara' : 'Devam Et',
                        onPressed: _nextStep,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Alınacak Konum *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _pickupSearchController,
                    label: 'Konum Ara',
                    hint: 'Alınacağınız adresi yazıp aratın',
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSearchingPickup ? null : () async {
                    if (_pickupSearchController.text.trim().isEmpty) return;
                    setState(() {
                      _isSearchingPickup = true;
                      _pickupSearchError = null;
                      _pickupSearchResults = [];
                    });
                    try {
                      final results = await _searchAddress(_pickupSearchController.text);
                      if (mounted) {
                        setState(() {
                          _pickupSearchResults = results;
                          _pickupSearchError = results.isEmpty ? 'empty' : null;
                          _isSearchingPickup = false;
                        });
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() {
                          _pickupSearchError = 'network';
                          _isSearchingPickup = false;
                        });
                      }
                    }
                  },
                  icon: _isSearchingPickup
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                ),
              ],
            ),
            if (_pickupSearchError == 'network')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: const [
                    Icon(Icons.wifi_off, color: AppColors.error, size: 16),
                    SizedBox(width: 6),
                    Text('Ağ bağlantısını kontrol edin', style: TextStyle(color: AppColors.error, fontSize: 13)),
                  ],
                ),
              ),
            if (_pickupSearchError == 'empty')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: const [
                    Icon(Icons.search_off, color: AppColors.textSecondary, size: 16),
                    SizedBox(width: 6),
                    Text('Sonuç bulunamadı', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _useCurrentLocationForPickup,
                  icon: const Icon(Icons.my_location, color: AppColors.primary, size: 18),
                  label: const Text(
                    'Şu Anki Konumumu Kullan',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            if (_pickupSearchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: _pickupSearchResults.map((res) {
                    return ListTile(
                      title: Text(res['display_name'], style: const TextStyle(fontSize: 13)),
                      onTap: () {
                        setState(() {
                          _selectedLatLng = LatLng(res['lat'], res['lon']);
                          _pickupAddress = res['display_name'];
                          _isPickupSelected = true;
                          _pickupSearchResults = [];
                          _pickupSearchError = null;
                          _pickupSearchController.text = res['display_name'];
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 250, // Make it a bit larger for premium feeling
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MapWidget(
                  initialPosition: _selectedLatLng,
                  isSelectorMode: true,
                  fitMarkers: false,
                  showMyLocation: true,
                  onCameraIdleLatLng: (latLng) async {
                    setState(() {
                      _selectedLatLng = latLng;
                      _isPickupSelected = true;
                    });
                    final address = await _reverseGeocode(latLng.latitude, latLng.longitude);
                    if (address != null && mounted) {
                      setState(() {
                        _pickupAddress = address;
                        _pickupSearchController.text = address;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Araç Türü *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _vehicleTypes.map((type) {
                final isSelected = _selectedVehicleType == type;
                
                IconData icon;
                switch (type) {
                  case 'Sedan / Hatchback':
                    icon = Icons.directions_car_filled_outlined;
                    break;
                  case 'SUV / Pick-up':
                    icon = Icons.airport_shuttle_outlined;
                    break;
                  case 'Minibüs / Hafif Ticari':
                    icon = Icons.local_shipping_outlined;
                    break;
                  case 'Motosiklet':
                    icon = Icons.two_wheeler_outlined;
                    break;
                  case 'Ağır Vasıta (Otobüs / Kamyon)':
                    icon = Icons.departure_board_outlined;
                    break;
                  default:
                    icon = Icons.directions_car;
                }

                return InkWell(
                  onTap: () {
                    setState(() => _selectedVehicleType = type);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ] : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon, 
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          type,
                          style: TextStyle(
                            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: _plateController,
              label: 'Plaka *',
              hint: 'Örn: 06 ABC 123',
            ),
            const SizedBox(height: 20),
            const Text('Araç Fotoğrafı *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Fotoğraf seçme kartı — daha belirgin ve önizlemeli
            GestureDetector(
              onTap: _pickVehiclePhoto,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: _vehiclePhoto != null ? 200 : 100,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _vehiclePhoto != null ? AppColors.primary : AppColors.border,
                    width: _vehiclePhoto != null ? 2 : 1,
                  ),
                ),
                child: _vehiclePhoto != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.file(
                              File(_vehiclePhoto!.path),
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() => _vehiclePhoto = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Colors.black54, Colors.transparent],
                                ),
                                borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
                              ),
                              child: const Text(
                                'Fotoğrafı değiştirmek için dokunun',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo_outlined, size: 36, color: AppColors.textSecondary),
                          const SizedBox(height: 8),
                          const Text(
                            'Arıza Fotoğrafı Ekle',
                            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Çekici sürücüsü bu fotoğrafı görecek',
                            style: TextStyle(color: AppColors.textHint, fontSize: 12),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nereye Götürülecek? *', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _dropoffSearchController,
                    label: 'Hedef Ara',
                    hint: 'Gidilecek adresi yazıp aratın',
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSearchingDropoff ? null : () async {
                    if (_dropoffSearchController.text.trim().isEmpty) return;
                    setState(() {
                      _isSearchingDropoff = true;
                      _dropoffSearchError = null;
                      _dropoffSearchResults = [];
                    });
                    try {
                      final results = await _searchAddress(_dropoffSearchController.text);
                      if (mounted) {
                        setState(() {
                          _dropoffSearchResults = results;
                          _dropoffSearchError = results.isEmpty ? 'empty' : null;
                          _isSearchingDropoff = false;
                        });
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() {
                          _dropoffSearchError = 'network';
                          _isSearchingDropoff = false;
                        });
                      }
                    }
                  },
                  icon: _isSearchingDropoff
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                ),
              ],
            ),
            if (_dropoffSearchError == 'network')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: const [
                    Icon(Icons.wifi_off, color: AppColors.error, size: 16),
                    SizedBox(width: 6),
                    Text('Ağ bağlantısını kontrol edin', style: TextStyle(color: AppColors.error, fontSize: 13)),
                  ],
                ),
              ),
            if (_dropoffSearchError == 'empty')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: const [
                    Icon(Icons.search_off, color: AppColors.textSecondary, size: 16),
                    SizedBox(width: 6),
                    Text('Sonuç bulunamadı', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _useCurrentLocationForDropoff,
                  icon: const Icon(Icons.my_location, color: AppColors.primary, size: 18),
                  label: const Text(
                    'Şu Anki Konumumu Kullan',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            if (_dropoffSearchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: _dropoffSearchResults.map((res) {
                    return ListTile(
                      title: Text(res['display_name'], style: const TextStyle(fontSize: 13)),
                      onTap: () {
                        setState(() {
                          _destinationLatLng = LatLng(res['lat'], res['lon']);
                          _destinationAddress = res['display_name'];
                          _dropoffSearchResults = [];
                          _dropoffSearchError = null;
                          _dropoffSearchController.text = res['display_name'];
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 250, // Make it a bit larger for premium feeling
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MapWidget(
                  initialPosition: _destinationLatLng ?? _selectedLatLng,
                  isSelectorMode: true,
                  fitMarkers: false,
                  showMyLocation: true,
                  markers: {
                    Marker(
                      markerId: const MarkerId('pickup_pos'),
                      position: _selectedLatLng,
                      infoWindow: InfoWindow(title: 'Alınacak Konum', snippet: _pickupAddress),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                    ),
                  },
                  onCameraIdleLatLng: (latLng) async {
                    setState(() {
                      _destinationLatLng = latLng;
                    });
                    final address = await _reverseGeocode(latLng.latitude, latLng.longitude);
                    if (address != null && mounted) {
                      setState(() {
                        _destinationAddress = address;
                        _dropoffSearchController.text = address;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        );
      case 2:
      default:
        double dist = 10.0;
        if (_destinationLatLng != null) {
          dist = LocationUtils.distanceBetween(
            _selectedLatLng.latitude,
            _selectedLatLng.longitude,
            _destinationLatLng!.latitude,
            _destinationLatLng!.longitude,
          );
        }
        final price = _calculatePrice(dist);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Özet ve Onay', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Başlangıç Konumu:', style: TextStyle(color: AppColors.textSecondary)),
                        Expanded(
                          child: Text(
                            _pickupAddress ?? 'Seçilen Konum',
                            textAlign: TextAlign.right,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Hedef Konum:', style: TextStyle(color: AppColors.textSecondary)),
                        Expanded(
                          child: Text(
                            _destinationAddress ?? 'Seçilen Hedef',
                            textAlign: TextAlign.right,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Mesafe:', style: TextStyle(color: AppColors.textSecondary)),
                        Text('${dist.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Fiyat:', style: TextStyle(color: AppColors.textSecondary)),
                        Text('₺${price.round()}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Yakındaki Çekiciler:', style: TextStyle(color: AppColors.textSecondary)),
                        Text('${_selectedDriverIds.length} Çekici', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_selectedDriverIds.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Şu anda yakınınızda aktif çekici bulunamadı. Talep oluşturulduğunda ilk aktif olan çekiciye bildirim gönderilecektir.',
                        style: TextStyle(color: Colors.orange, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Onayladığınızda yakındaki müsait çekicilere alarm gönderilecektir. İlk kabul eden çekici size yönlendirilecektir.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        );
    }
  }
}
