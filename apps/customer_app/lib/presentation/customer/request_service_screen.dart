import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_ui/price_calculator.dart';
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
  LatLng _selectedLatLng = const LatLng(41.0082, 28.9784); // Default Istanbul

  final _brandController = TextEditingController(text: 'Renault');
  final _modelController = TextEditingController(text: 'Clio');
  final _colorController = TextEditingController(text: 'Beyaz');
  final _plateController = TextEditingController(text: '34 ABC 123');
  final _descriptionController = TextEditingController();

  String _selectedProblem = 'breakdown';
  bool _isLoading = false;

  final List<Map<String, String>> _problemTypes = [
    {'id': 'breakdown', 'label': 'Motor / Arıza', 'icon': '🛠️'},
    {'id': 'accident', 'label': 'Kaza / Darbe', 'icon': '💥'},
    {'id': 'fuel_empty', 'label': 'Yakıt Bitti', 'icon': '⛽'},
    {'id': 'flat_tire', 'label': 'Lastik Patladı', 'icon': '🛞'},
    {'id': 'battery_dead', 'label': 'Akü Bitti', 'icon': '🔋'},
    {'id': 'other', 'label': 'Diğer Sorunlar', 'icon': '⚠️'},
  ];

  @override
  void initState() {
    super.initState();
    final pos = ref.read(locationProvider).value;
    if (pos != null) {
      _selectedLatLng = LatLng(pos.latitude, pos.longitude);
    }
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('Kullanıcı oturumu bulunamadı');

      const distanceKm = 3.5; // Calculated distance or estimate
      final price = PriceCalculator.calculatePrice(distanceKm);

      final request = ServiceRequestModel(
        id: '',
        customerId: user.id,
        customerLat: _selectedLatLng.latitude,
        customerLng: _selectedLatLng.longitude,
        customerAddress: 'Mevcut Seçili Konum',
        carBrand: _brandController.text.trim(),
        carModel: _modelController.text.trim(),
        carColor: _colorController.text.trim(),
        carPlate: _plateController.text.trim(),
        problemType: _selectedProblem,
        problemDescription: _descriptionController.text.trim(),
        distanceKm: distanceKm,
        price: price,
        status: RequestStatus.pending,
        createdAt: DateTime.now(),
        customerPhone: user.phone ?? '08501234567',
      );

      final requestId = await ref.read(requestNotifierProvider.notifier).createRequest(request);

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

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'En yakın çekiciler aranıyor...',
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
                        text: _currentStep == 3 ? 'Çekiciyi Çağır' : 'Devam Et',
                        onPressed: () {
                          if (_currentStep < 3) {
                            setState(() => _currentStep++);
                          } else {
                            _submitRequest();
                          }
                        },
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
            const Text('1. Konumunuzu Doğrulayın', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Çekicinin aracınıza ulaşacağı konumu haritadan seçin.', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
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
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('2. Araç Bilgileri', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            AppTextField(controller: _brandController, label: 'Marka', prefixIcon: Icons.directions_car),
            const SizedBox(height: 12),
            AppTextField(controller: _modelController, label: 'Model', prefixIcon: Icons.car_repair),
            const SizedBox(height: 12),
            AppTextField(controller: _colorController, label: 'Renk', prefixIcon: Icons.palette),
            const SizedBox(height: 12),
            AppTextField(controller: _plateController, label: 'Plaka', prefixIcon: Icons.numbers),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('3. Arıza / Sorun Tipi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _problemTypes.map((item) {
                final isSelected = _selectedProblem == item['id'];
                return ChoiceChip(
                  label: Text('${item['icon']}  ${item['label']}'),
                  selected: isSelected,
                  selectedColor: AppColors.secondary,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(color: isSelected ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: FontWeight.bold),
                  onSelected: (val) {
                    if (val) setState(() => _selectedProblem = item['id']!);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: _descriptionController,
              label: 'Sorun Açıklaması (İsteğe Bağlı)',
              hint: 'Örn: Sağ ön tekerlek kilitlendi...',
            ),
          ],
        );
      case 3:
      default:
        const distanceKm = 3.5;
        final price = PriceCalculator.calculatePrice(distanceKm);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('4. Özet ve Fiyat Tahmini', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tahmini Mesafe', style: TextStyle(color: AppColors.textSecondary)),
                        Text('$distanceKm km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const Divider(height: 24, color: AppColors.divider),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Hizmet Ücreti', style: TextStyle(color: AppColors.textSecondary)),
                        Text(PriceCalculator.formatPrice(price), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppColors.accent)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }
}
