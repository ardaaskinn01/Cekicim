import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_services/location_utils.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_models/driver_model.dart';
import 'package:shared_models/service_request_model.dart';
import 'package:shared_models/request_status.dart';
import 'package:shared_services/ankara_industry_zones.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/request_provider.dart';
import '../widgets/driver_selection_card.dart';
import 'package:shared_ui/widgets/map_widget.dart';
import 'package:shared_ui/widgets/app_text_field.dart';
import 'package:shared_ui/widgets/green_button.dart';
import 'package:shared_ui/widgets/loading_overlay.dart';
import 'package:shared_ui/price_calculator.dart';

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
  
  IndustryZone? _selectedZone;
  
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
        final zoneName = queryParams['zone'];

        if (plate != null) {
          _plateController.text = plate;
        }
        if (vehicleType != null && _vehicleTypes.contains(vehicleType)) {
          setState(() => _selectedVehicleType = vehicleType);
        }
        if (zoneName != null) {
          try {
            final matchedZone = AnkaraIndustryZones.zones.firstWhere(
              (z) => z.name.toLowerCase() == zoneName.toLowerCase(),
              orElse: () => AnkaraIndustryZones.zones.first,
            );
            setState(() => _selectedZone = matchedZone);
          } catch (_) {}
        }
      }
    });
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
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
        _nearbyDrivers = drivers.take(5).toList();
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
    if (_selectedDriverIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen en az bir çekici seçin.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('Kullanıcı oturumu bulunamadı');

      final repo = ref.read(requestRepositoryProvider);

      double distance = 10.0;
      if (_selectedZone != null) {
        distance = LocationUtils.distanceBetween(
          _selectedLatLng.latitude,
          _selectedLatLng.longitude,
          _selectedZone!.latitude,
          _selectedZone!.longitude,
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
        customerAddress: 'Ankara',
        destinationLat: _selectedZone?.latitude,
        destinationLng: _selectedZone?.longitude,
        destinationAddress: _selectedZone?.name,
        destinationIndustryZone: _selectedZone?.name,
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
      setState(() => _currentStep++);
    } else if (_currentStep == 1) {
      if (_selectedZone == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen sanayi sitesi seçin.')));
        return;
      }
      _fetchDrivers();
      setState(() => _currentStep++);
    } else if (_currentStep == 2) {
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
        children: List.generate(4, (index) {
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
                if (index < 3)
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
                        text: _currentStep == 3 ? 'Alarmları Gönder' : 'Devam Et',
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
            const Text('Konumunuz', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MapWidget(
                  initialPosition: _selectedLatLng,
                  markers: {
                    Marker(
                      markerId: const MarkerId('my_current_position'),
                      position: _selectedLatLng,
                      infoWindow: const InfoWindow(title: 'Benim Konumum'),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                    ),
                  },
                  onTap: null,
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
                
                // Assign specific icons to each vehicle type
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
            const Text('Nereye Götürülecek?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            // Industry Zones Map Selection
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MapWidget(
                  initialPosition: _selectedLatLng,
                  showMyLocation: true,
                  fitMarkers: true, // Automatically center and fit both user & target sanayi site
                  markers: {
                    // User's own position
                    Marker(
                      markerId: const MarkerId('my_current_position'),
                      position: _selectedLatLng,
                      infoWindow: const InfoWindow(title: 'Benim Konumum'),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                    ),
                    // If a zone is selected, show only that zone to focus on the route direction
                    if (_selectedZone != null)
                      Marker(
                        markerId: MarkerId('zone_${_selectedZone!.id}'),
                        position: LatLng(_selectedZone!.latitude, _selectedZone!.longitude),
                        infoWindow: InfoWindow(title: _selectedZone!.name),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                      )
                    else
                      // If no zone selected, show all zones as red dots to select from
                      ...AnkaraIndustryZones.zones.map((zone) {
                        return Marker(
                          markerId: MarkerId('zone_${zone.id}'),
                          position: LatLng(zone.latitude, zone.longitude),
                          infoWindow: InfoWindow(
                            title: zone.name,
                            snippet: 'Seçmek için dokunun',
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                          onTap: () {
                            setState(() => _selectedZone = zone);
                          },
                        );
                      }),
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Sanayi Siteleri Listesi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            ...() {
              // Get sorted zones based on user current position
              final sortedZones = AnkaraIndustryZones.getSortedZones(_selectedLatLng.latitude, _selectedLatLng.longitude);
              
              return sortedZones.asMap().entries.map((entry) {
                final index = entry.key;
                final zone = entry.value;
                final isNearest = index == 0; // The first item is the closest one
                final isSelected = _selectedZone?.id == zone.id;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: isSelected 
                          ? AppColors.primary 
                          : (isNearest ? AppColors.primary.withValues(alpha: 0.4) : Colors.transparent), 
                      width: 2
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(zone.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        if (isNearest)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary, width: 1),
                            ),
                            child: const Text(
                              'Önerilen (En Yakın)',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(zone.description),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                    onTap: () => setState(() => _selectedZone = zone),
                  ),
                );
              });
            }(),
          ],
        );
      case 2:
        if (_nearbyDrivers.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'Yakınınızda uygun araç tipinde boşta çekici bulunamadı.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Yakındaki Çekiciler', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Alarm göndermek istediğiniz çekicileri seçin.', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ..._nearbyDrivers.map((driver) {
              final isSelected = _selectedDriverIds.contains(driver.id);
              final dist = LocationUtils.distanceBetween(
                _selectedLatLng.latitude,
                _selectedLatLng.longitude,
                driver.latitude ?? 0.0,
                driver.longitude ?? 0.0,
              );
              // Calculate pricing distance (customer to target zone)
              final targetDist = _selectedZone != null ? LocationUtils.distanceBetween(
                _selectedLatLng.latitude,
                _selectedLatLng.longitude,
                _selectedZone!.latitude,
                _selectedZone!.longitude,
              ) : 1.0;
              final targetPrice = PriceCalculator.calculatePrice(targetDist);

              return DriverSelectionCard(
                driver: driver,
                distanceKm: dist,
                targetPrice: targetPrice,
                isSelected: isSelected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedDriverIds.add(driver.id);
                    } else {
                      _selectedDriverIds.remove(driver.id);
                    }
                  });
                },
              );
            }).toList(),
          ],
        );
      case 3:
      default:
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
                        const Text('Hedef:', style: TextStyle(color: AppColors.textSecondary)),
                        Text('${_selectedZone?.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Seçilen Çekici Sayısı:', style: TextStyle(color: AppColors.textSecondary)),
                        Text('${_selectedDriverIds.length} Çekici', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Onayladığınızda seçtiğiniz çekicilere alarm gönderilecektir. İlk kabul eden çekici size yönlendirilecektir.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        );
    }
  }
}
