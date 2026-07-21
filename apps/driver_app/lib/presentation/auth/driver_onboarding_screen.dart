import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_ui/widgets/green_button.dart';
import 'package:shared_ui/widgets/loading_overlay.dart';
import 'package:shared_models/driver_model.dart';
import 'package:shared_services/iban_input_formatter.dart';
import '../../providers/auth_provider.dart';

class DriverOnboardingScreen extends ConsumerStatefulWidget {
  const DriverOnboardingScreen({super.key});

  @override
  ConsumerState<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends ConsumerState<DriverOnboardingScreen> {
  int _currentStep = 0;
  bool _isUploading = false;
  String _uploadStatus = '';

  // Step 1 Files
  XFile? _driverLicense;
  XFile? _vehicleRegistration;
  XFile? _taxPlate;
  XFile? _criminalRecord;

  // Step 2 Files (Vehicle Photos: Front, Back, Left, Right)
  XFile? _photoFront;
  XFile? _photoBack;
  XFile? _photoLeft;
  XFile? _photoRight;

  // Step 3 Equipment Selection
  final Map<String, bool> _equipments = {
    'Kayar Kasa': false,
    'Tekerlek Kilidi': false,
    'Takviye Kablosu': false,
    'Aparatlar': false,
  };

  // Step 3 Vehicle Types Selection
  final Map<String, bool> _supportedVehicleTypes = {
    'Sedan / Hatchback': false,
    'SUV / Pick-up': false,
    'Minibüs / Hafif Ticari': false,
    'Motosiklet': false,
    'Ağır Vasıta (Otobüs / Kamyon)': false,
  };

  // Step 4: IBAN
  final _ibanController = TextEditingController();
  final _ibanOwnerController = TextEditingController();
  final _ibanFormKey = GlobalKey<FormState>();
  bool _isDataPrefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDataPrefilled) {
      final user = ref.read(currentUserProvider).value;
      if (user is DriverModel) {
        _isDataPrefilled = true;
        if (user.iban != null && user.iban!.isNotEmpty) {
          _ibanController.text = user.iban!;
        }
        if (user.ibanOwnerName != null && user.ibanOwnerName!.isNotEmpty) {
          _ibanOwnerController.text = user.ibanOwnerName!;
        } else if (user.fullName.isNotEmpty) {
          _ibanOwnerController.text = user.fullName;
        }
        if (user.equipments.isNotEmpty) {
          for (var eq in user.equipments) {
            if (_equipments.containsKey(eq)) {
              _equipments[eq] = true;
            }
          }
        }
        if (user.supportedVehicleTypes.isNotEmpty) {
          for (var vt in user.supportedVehicleTypes) {
            if (_supportedVehicleTypes.containsKey(vt)) {
              _supportedVehicleTypes[vt] = true;
            }
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _ibanController.dispose();
    _ibanOwnerController.dispose();
    super.dispose();
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(String docType) async {
    try {
      final XFile? image = await showModalBottomSheet<XFile?>(
        context: context,
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library, color: AppColors.primary),
                  title: const Text('Galeriden Seç', style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () async {
                    final img = await _picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 80,
                      maxWidth: 1080,
                      maxHeight: 1920,
                    );
                    if (context.mounted) Navigator.pop(context, img);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                  title: const Text('Kamerayla Çek', style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () async {
                    final img = await _picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 80,
                      maxWidth: 1080,
                      maxHeight: 1920,
                    );
                    if (context.mounted) Navigator.pop(context, img);
                  },
                ),
              ],
            ),
          );
        },
      );

      if (image == null) return;

      setState(() {
        switch (docType) {
          case 'license':
            _driverLicense = image;
            break;

          case 'registration':
            _vehicleRegistration = image;
            break;
          case 'tax_plate':
            _taxPlate = image;
            break;
          case 'criminal':
            _criminalRecord = image;
            break;
          case 'photo_front':
            _photoFront = image;
            break;
          case 'photo_back':
            _photoBack = image;
            break;
          case 'photo_left':
            _photoLeft = image;
            break;
          case 'photo_right':
            _photoRight = image;
            break;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Widget _buildDocTile(String title, XFile? file, String docType, {bool isRequired = true}) {
    final hasFile = file != null;
    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title + (isRequired ? ' *' : ''),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasFile ? file.name : 'Seçilmedi',
                    style: TextStyle(
                      color: hasFile ? AppColors.primary : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (hasFile)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.error, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        switch (docType) {
                          case 'license': _driverLicense = null; break;

                          case 'registration': _vehicleRegistration = null; break;
                          case 'tax_plate': _taxPlate = null; break;
                          case 'criminal': _criminalRecord = null; break;
                        }
                      });
                    },
                  )
                ],
              )
            else
              ElevatedButton(
                onPressed: () => _pickImage(docType),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: const Size(80, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Yükle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoBox(String label, XFile? file, String key) {
    return GestureDetector(
      onTap: () => _pickImage(key),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null ? AppColors.primary : AppColors.cardBackground,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: file != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(file.path), fit: BoxFit.cover),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (key == 'photo_front') _photoFront = null;
                            if (key == 'photo_back') _photoBack = null;
                            if (key == 'photo_left') _photoLeft = null;
                            if (key == 'photo_right') _photoRight = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt_outlined, size: 36, color: AppColors.textSecondary),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    // [TEST MODE] Document and Photo validations are bypassed. 
    // We only require at least one vehicle type for basic request routing.
    final selectedVehicleTypes = _supportedVehicleTypes.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (selectedVehicleTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen en az bir adet taşıyabildiğiniz araç türü seçin.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatus = 'Bilgiler kaydediliyor...';
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('Kullanıcı oturumu bulunamadı.');

      // Safely cast UserModel to DriverModel if not already casted by repository
      final DriverModel driver = user is DriverModel
          ? user
          : DriverModel(
              id: user.id,
              email: user.email,
              fullName: user.fullName,
              phone: user.phone,
              role: user.role,
              createdAt: user.createdAt,
              isVerified: user.isVerified,
              vehiclePlate: Supabase.instance.client.auth.currentUser?.userMetadata?['vehicle_plate'] as String? ?? '06ANK06',
            );

      // Assign existing document URLs if available, fallback to mockUrl if completely missing
      final mockUrl = 'https://picsum.photos/800/600';
      
      String licenseUrl = (driver.driverLicenseUrl != null && driver.driverLicenseUrl!.isNotEmpty)
          ? driver.driverLicenseUrl!
          : mockUrl;
      if (_driverLicense != null) {
        licenseUrl = await repo.uploadDriverDocument(
          driverId: driver.id,
          documentType: 'license',
          fileName: 'license.jpg',
          fileBytes: await _driverLicense!.readAsBytes(),
        );
      }

      String registrationUrl = (driver.vehicleRegistrationUrl != null && driver.vehicleRegistrationUrl!.isNotEmpty)
          ? driver.vehicleRegistrationUrl!
          : mockUrl;
      if (_vehicleRegistration != null) {
        registrationUrl = await repo.uploadDriverDocument(
          driverId: driver.id,
          documentType: 'registration',
          fileName: 'registration.jpg',
          fileBytes: await _vehicleRegistration!.readAsBytes(),
        );
      }

      String criminalUrl = (driver.criminalRecordUrl != null && driver.criminalRecordUrl!.isNotEmpty)
          ? driver.criminalRecordUrl!
          : mockUrl;
      if (_criminalRecord != null) {
        criminalUrl = await repo.uploadDriverDocument(
          driverId: driver.id,
          documentType: 'criminal',
          fileName: 'criminal.jpg',
          fileBytes: await _criminalRecord!.readAsBytes(),
        );
      }

      String? taxUrl = (driver.taxPlateUrl != null && driver.taxPlateUrl!.isNotEmpty)
          ? driver.taxPlateUrl!
          : mockUrl;
      if (_taxPlate != null) {
        taxUrl = await repo.uploadDriverDocument(
          driverId: driver.id,
          documentType: 'tax_plate',
          fileName: 'tax_plate.jpg',
          fileBytes: await _taxPlate!.readAsBytes(),
        );
      }

      List<String> vehiclePhotos = List.from(driver.vehiclePhotos);
      while (vehiclePhotos.length < 4) {
        vehiclePhotos.add(mockUrl);
      }
      if (_photoFront != null) {
        vehiclePhotos[0] = await repo.uploadDriverDocument(
          driverId: driver.id,
          documentType: 'vehicle_photos',
          fileName: 'front.jpg',
          fileBytes: await _photoFront!.readAsBytes(),
        );
      }
      if (_photoBack != null) {
        vehiclePhotos[1] = await repo.uploadDriverDocument(
          driverId: driver.id,
          documentType: 'vehicle_photos',
          fileName: 'back.jpg',
          fileBytes: await _photoBack!.readAsBytes(),
        );
      }
      if (_photoLeft != null) {
        vehiclePhotos[2] = await repo.uploadDriverDocument(
          driverId: driver.id,
          documentType: 'vehicle_photos',
          fileName: 'left.jpg',
          fileBytes: await _photoLeft!.readAsBytes(),
        );
      }
      if (_photoRight != null) {
        vehiclePhotos[3] = await repo.uploadDriverDocument(
          driverId: driver.id,
          documentType: 'vehicle_photos',
          fileName: 'right.jpg',
          fileBytes: await _photoRight!.readAsBytes(),
        );
      }

      final selectedEquipments = _equipments.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      final updatedDriver = driver.copyWith(
        driverLicenseUrl: licenseUrl,
        vehicleRegistrationUrl: registrationUrl,
        criminalRecordUrl: criminalUrl,

        taxPlateUrl: taxUrl,
        vehiclePhotos: vehiclePhotos,
        equipments: selectedEquipments,
        supportedVehicleTypes: selectedVehicleTypes,
        isOnboardingCompleted: true,
        isVerified: false, // verification is pending admin review
        rejectionReason: '', // Clear rejection reason since they resubmitted!
        iban: _ibanController.text.replaceAll(' ', '').toUpperCase(),
        ibanOwnerName: _ibanOwnerController.text.trim(),
      );

      await repo.updateUserProfile(updatedDriver);

      if (!mounted) return;

      // Invalidate the future provider so that GoRouter gets the updated user model
      ref.invalidate(currentUserProvider);
      
      // Refresh auth notifier state
      ref.read(authNotifierProvider.notifier).loadCurrentUser();
    } catch (e, stack) {
      debugPrint('Onboarding submit error: $e');
      debugPrint('Onboarding submit stack: $stack');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıt güncellenirken hata oluştu: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for current user changes and navigate to /driver as soon as onboarding is completed successfully
    ref.listen<AsyncValue<dynamic>>(currentUserProvider, (previous, next) {
      final user = next.value;
      if (user is DriverModel && user.isOnboardingCompleted) {
        if (mounted) {
          context.go('/driver');
        }
      }
    });

    final driver = ref.watch(currentUserProvider).value;
    if (driver == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return LoadingOverlay(
      isLoading: _isUploading,
      message: _uploadStatus,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sürücü Başvurusu'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            if (driver is DriverModel && driver.rejectionReason != null && driver.rejectionReason!.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Önceki Başvurunuz Reddedildi',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Gerekçe: ${driver.rejectionReason}',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // Custom Step Indicator
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: AppColors.cardBackground,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStepIndicator(0, 'Belgeler'),
                  _buildStepIndicator(1, 'Araç Resimleri'),
                  _buildStepIndicator(2, 'Ekipmanlar'),
                  _buildStepIndicator(3, 'Ödeme'),
                ],
              ),
            ),
            Expanded(
              child: _buildActiveStepContent(),
            ),
            // Bottom Buttons
            Container(
              padding: const EdgeInsets.all(24),
              color: AppColors.background,
              child: Row(
                children: [
                  if (_currentStep > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _currentStep--);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Geri'),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: GreenButton(
                      text: _currentStep == 3 ? 'Tamamla' : 'Devam Et',
                      onPressed: () {
                        if (_currentStep < 3) {
                          setState(() => _currentStep++);
                        } else {
                          if (_ibanFormKey.currentState?.validate() ?? false) {
                            _handleSubmit();
                          }
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
    );
  }

  Widget _buildActiveStepContent() {
    switch (_currentStep) {
      case 0:
        return ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            const Text(
              'Resmi Belgeleri Yükleyin',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Başvurunuzun onaylanması için gerekli evrakların net fotoğraflarını çekin veya seçin.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            _buildDocTile('Sürücü Belgesi (Ehliyet)', _driverLicense, 'license'),
            _buildDocTile('Araç Ruhsatı', _vehicleRegistration, 'registration'),
            _buildDocTile('Adli Sicil Kaydı (E-Devlet)', _criminalRecord, 'criminal'),

            _buildDocTile('Vergi Levhası / Oda Kaydı', _taxPlate, 'tax_plate', isRequired: false),
          ],
        );
      case 1:
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Çekici Fotoğrafları',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Platforma kayıtlı aracınızın 4 farklı açıdan net çekilmiş fotoğrafını yükleyin.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _buildPhotoBox('Ön Görünüm *', _photoFront, 'photo_front'),
                    _buildPhotoBox('Arka Görünüm *', _photoBack, 'photo_back'),
                    _buildPhotoBox('Sol Yan Görünüm *', _photoLeft, 'photo_left'),
                    _buildPhotoBox('Sağ Yan Görünüm *', _photoRight, 'photo_right'),
                  ],
                ),
              ),
            ],
          ),
        );
      case 2:
        return ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            const Text(
              'Ekipman Tanımlama',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Çekici aracınızda hazır bulundurduğunuz donanımları seçin. Doğru eşleşme için önemlidir.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ..._equipments.keys.map((String key) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CheckboxListTile(
                  title: Text(key, style: const TextStyle(color: AppColors.textPrimary)),
                  activeColor: AppColors.primary,
                  checkColor: Colors.white,
                  value: _equipments[key],
                  onChanged: (bool? value) {
                    setState(() {
                      _equipments[key] = value ?? false;
                    });
                  },
                ),
              );
            }),
            const SizedBox(height: 24),
            const Divider(color: AppColors.border),
            const SizedBox(height: 16),
            const Text(
              'Taşıyabildiğiniz Araç Türleri *',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Çekebileceğiniz araç modellerini seçin. Müşteriler araç tipine göre filtreleme yapacaktır.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ..._supportedVehicleTypes.keys.map((String key) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CheckboxListTile(
                  title: Text(key, style: const TextStyle(color: AppColors.textPrimary)),
                  activeColor: AppColors.primary,
                  checkColor: Colors.white,
                  value: _supportedVehicleTypes[key],
                  onChanged: (bool? value) {
                    setState(() {
                      _supportedVehicleTypes[key] = value ?? false;
                    });
                  },
                ),
              );
            }),
          ],
        );
      case 3:
        return ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ödeme bilgileriniz yalnızca eşleşme gerçekleştikten sonra müşteriye gösterilecektir. Platform ücret veya komisyon almamaktadır.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Banka Hesap Bilgileri',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hizmet bedelini almak için IBAN bilgilerinizi girin. Müşteriler ödemeyi doğrudan banka transferiyle yapacaktır.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            Form(
              key: _ibanFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'IBAN Numarası *',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _ibanController,
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [IbanInputFormatter()],
                    style: const TextStyle(color: AppColors.textPrimary, letterSpacing: 1.5, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'TR00 0000 0000 0000 0000 0000 00',
                      hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), letterSpacing: 1.0),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      prefixIcon: const Icon(Icons.account_balance, color: AppColors.accent),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'IBAN zorunludur.';
                      final clean = v.replaceAll(' ', '').toUpperCase();
                      if (!clean.startsWith('TR')) return "Türkiye IBAN'ı TR ile başlamalıdır.";
                      if (clean.length != 26) return 'IBAN tam 26 karakter olmalıdır (TR + 24 rakam).';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Hesap Sahibi Adı Soyadı *',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _ibanOwnerController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Örn: Ahmet Yılmaz',
                      hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      prefixIcon: const Icon(Icons.person_outline, color: AppColors.accent),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Hesap sahibi adı zorunludur.';
                      if (v.trim().split(' ').length < 2) return 'Lütfen ad ve soyadınızı girin.';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepIndicator(int index, String label) {
    final isActive = _currentStep == index;
    final isDone = _currentStep > index;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? AppColors.primary
                : isActive
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.background,
            border: Border.all(
              color: isDone || isActive ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isActive ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
