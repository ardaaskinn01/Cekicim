import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
        distanceKm: 10.0,
        price: 3000.0,
        status: RequestStatus.awaitingAcceptance,
        createdAt: DateTime.now(),
        customerPhone: user.phone ?? '08501234567',
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

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'İşlem yapılıyor...',
      child: Scaffold(
        appBar: AppBar(
          title: Text('Çekici Çağır (Adım ${_currentStep + 1}/4)'),
        ),
        body: SafeArea(
          child: Column(
            children: [
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
                      markerId: const MarkerId('pickup'),
                      position: _selectedLatLng,
                      draggable: true,
                      onDragEnd: (newPos) => setState(() => _selectedLatLng = newPos),
                    ),
                  },
                  onTap: (pos) => setState(() => _selectedLatLng = pos),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Araç Türü *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _vehicleTypes.map((type) {
                final isSelected = _selectedVehicleType == type;
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  selectedColor: AppColors.secondary,
                  onSelected: (val) {
                    if (val) setState(() => _selectedVehicleType = type);
                  },
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
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: _vehiclePhoto != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(_vehiclePhoto!.path), fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 40, color: AppColors.textSecondary),
                          SizedBox(height: 8),
                          Text('Fotoğraf Çekmek İçin Dokunun', style: TextStyle(color: AppColors.textSecondary)),
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
            const Text('Nereye Götürülecek?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...AnkaraIndustryZones.zones.map((zone) {
              final isSelected = _selectedZone?.id == zone.id;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: isSelected ? AppColors.primary : Colors.transparent, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(zone.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(zone.description),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                  onTap: () => setState(() => _selectedZone = zone),
                ),
              );
            }).toList(),
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
              return DriverSelectionCard(
                driver: driver,
                distanceKm: 10.0, // Placeholder
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
