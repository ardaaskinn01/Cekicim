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

  // For dropoff (Step 1)
  final _dropoffSearchController = TextEditingController();
  List<Map<String, dynamic>> _dropoffSearchResults = [];
  bool _isSearchingDropoff = false;
  LatLng? _destinationLatLng;
  String? _destinationAddress;
  
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

  @override
  void dispose() {
    _plateController.dispose();
    _pickupSearchController.dispose();
    _dropoffSearchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _searchAddress(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final client = HttpClient();
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1&countrycodes=tr'
      );
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'CekiciApp/1.0');
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final List<dynamic> data = json.decode(responseBody);
        return data.map((item) {
          return {
            'display_name': item['display_name'] as String,
            'lat': double.parse(item['lat'] as String),
            'lon': double.parse(item['lon'] as String),
          };
        }).toList();
      }
    } catch (e) {
      debugPrint('Address search error: $e');
    }
    return [];
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1'
      );
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'CekiciApp/1.0');
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data = json.decode(responseBody);
        return data['display_name'] as String?;
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() => _vehiclePhoto = pickedFile);
    }
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

      // Calculate price dynamically:
      // - First 1 km: 2000 TL (Base fee)
      // - Between 1 km and 15 km: +200 TL/km
      // - Beyond 15 km: +150 TL/km
      double price = 2000.0;
      if (distance > 1.0) {
        if (distance <= 15.0) {
          price += (distance - 1.0) * 200.0;
        } else {
          price += (14.0 * 200.0) + (distance - 15.0) * 150.0;
        }
      }

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
        vehiclePhotoUrl: 'https://placeholder.com/image.jpg',
        selectedDriverIds: _selectedDriverIds,
        distanceKm: distance,
        price: price,
        status: RequestStatus.awaitingAcceptance,
        createdAt: DateTime.now(),
        customerPhone: user.phone ?? '08501234567',
        completionCode: random,
      );

      final requestId = await repo.createRequest(tempRequest);

      String photoUrl = 'https://placeholder.com/image.jpg';
      if (_vehiclePhoto != null) {
        try {
          final bytes = await _vehiclePhoto!.readAsBytes();
          photoUrl = await repo.uploadRequestPhoto(
            requestId: requestId,
            fileName: _vehiclePhoto!.name,
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
                  onPressed: () async {
                    setState(() => _isSearchingPickup = true);
                    final results = await _searchAddress(_pickupSearchController.text);
                    setState(() {
                      _pickupSearchResults = results;
                      _isSearchingPickup = false;
                    });
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
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MapWidget(
                  initialPosition: _selectedLatLng,
                  markers: {
                    Marker(
                      markerId: const MarkerId('pickup_pos'),
                      position: _selectedLatLng,
                      infoWindow: InfoWindow(title: 'Alınacak Konum', snippet: _pickupAddress ?? 'Haritadan Seçilen Konum'),
                    ),
                  },
                  onTap: (latLng) async {
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
            InkWell(
              onTap: _pickImage,
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: _vehiclePhoto != null
                    ? Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(File(_vehiclePhoto!.path), fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: InkWell(
                              onTap: () => setState(() => _vehiclePhoto = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_outlined, size: 32, color: AppColors.primary),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Aracın Fotoğrafını Çekmek İçin Dokunun', 
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Çekici sürücüsünün aracınızı tanımasını kolaylaştırır.', 
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
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
                  onPressed: () async {
                    setState(() => _isSearchingDropoff = true);
                    final results = await _searchAddress(_dropoffSearchController.text);
                    setState(() {
                      _dropoffSearchResults = results;
                      _isSearchingDropoff = false;
                    });
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
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MapWidget(
                  initialPosition: _destinationLatLng ?? _selectedLatLng,
                  showMyLocation: true,
                  markers: {
                    Marker(
                      markerId: const MarkerId('pickup_pos'),
                      position: _selectedLatLng,
                      infoWindow: InfoWindow(title: 'Alınacak Konum', snippet: _pickupAddress),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                    ),
                    if (_destinationLatLng != null)
                      Marker(
                        markerId: const MarkerId('destination_pos'),
                        position: _destinationLatLng!,
                        infoWindow: InfoWindow(title: 'Gidilecek Yer', snippet: _destinationAddress),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                      ),
                  },
                  onTap: (latLng) async {
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
        double price = 2000.0;
        if (dist > 1.0) {
          if (dist <= 15.0) {
            price += (dist - 1.0) * 200.0;
          } else {
            price += (14.0 * 200.0) + (dist - 15.0) * 150.0;
          }
        }

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
                        const Text('Yakındaki Çekiciler (30 km):', style: TextStyle(color: AppColors.textSecondary)),
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
                        'Şu anda yakınınızda (30 km) aktif çekici bulunamadı. Talep oluşturulduğunda ilk aktif olan çekiciye bildirim gönderilecektir.',
                        style: TextStyle(color: Colors.orange, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Onayladığınızda 30 km yarıçapındaki müsait çekicilere alarm gönderilecektir. İlk kabul eden çekici size yönlendirilecektir.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        );
    }
  }
}
