import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_ui/widgets/green_button.dart';
import 'package:shared_ui/widgets/loading_overlay.dart';
import 'package:shared_models/driver_model.dart';
import 'package:shared_services/iban_input_formatter.dart';
import 'package:shared_services/app_error_handler.dart';
import 'package:shared_ui/widgets/legal_documents_dialog.dart';
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

  // Step 4: IBAN & Vehicle Info
  final _ibanController = TextEditingController();
  final _ibanOwnerController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleBrandController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _step4FormKey = GlobalKey<FormState>();
  bool _isDataPrefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDataPrefilled) {
      final user = ref.read(currentUserProvider).value;
      if (user is DriverModel) {
        _isDataPrefilled = true;
        if (user.vehiclePlate.isNotEmpty) {
          _vehiclePlateController.text = user.vehiclePlate;
        } else {
          final metadataPlate = Supabase.instance.client.auth.currentUser?.userMetadata?['vehicle_plate'] as String?;
          if (metadataPlate != null && metadataPlate.isNotEmpty) {
            _vehiclePlateController.text = metadataPlate;
          }
        }
        if (user.vehicleBrand != null && user.vehicleBrand!.isNotEmpty) {
          _vehicleBrandController.text = user.vehicleBrand!;
        }
        if (user.vehicleModel != null && user.vehicleModel!.isNotEmpty) {
          _vehicleModelController.text = user.vehicleModel!;
        }
        if (user.vehicleColor != null && user.vehicleColor!.isNotEmpty) {
          _vehicleColorController.text = user.vehicleColor!;
        }
        if (user.vehicleYear != null) {
          _vehicleYearController.text = user.vehicleYear.toString();
        }
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
    _vehiclePlateController.dispose();
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    _vehicleColorController.dispose();
    _vehicleYearController.dispose();
    super.dispose();
  }

  final ImagePicker _picker = ImagePicker();

  void _setDocumentFile(String docType, XFile file) {
    setState(() {
      switch (docType) {
        case 'license':
          _driverLicense = file;
          break;
        case 'registration':
          _vehicleRegistration = file;
          break;
        case 'tax_plate':
          _taxPlate = file;
          break;
        case 'criminal':
          _criminalRecord = file;
          break;
        case 'photo_front':
          _photoFront = file;
          break;
        case 'photo_back':
          _photoBack = file;
          break;
        case 'photo_left':
          _photoLeft = file;
          break;
        case 'photo_right':
          _photoRight = file;
          break;
      }
    });
  }

  Future<void> _pickImage(String docType, {ImageSource source = ImageSource.camera}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (image == null) return;
      _setDocumentFile(docType, image);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Görsel seçilirken hata oluştu: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _pickDocumentFile(String docType) async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.path == null) return;

      _setDocumentFile(docType, XFile(file.path!, name: file.name));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya seçilirken hata oluştu: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showDocumentSourceSheet(String docType, String docTitle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  docTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Belgeyi nasıl yüklemek istersiniz?',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary),
                  ),
                  title: const Text('Dosya / PDF Seç', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Cihazınızdaki PDF veya belge dosyası (Örn: E-Devlet)', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickDocumentFile(docType);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                  ),
                  title: const Text('Galeriden Seç', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Daha önce çektiğiniz bir fotoğrafı yükleyin', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(docType, source: ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                  ),
                  title: const Text('Kamerayla Çek', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Şimdi yeni bir fotoğraf çekin', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(docType, source: ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPhotoSourceSheet(String docType, String docTitle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  docTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                  title: const Text('Kamerayla Çek', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(docType, source: ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                  title: const Text('Galeriden Seç', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(docType, source: ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocTile(String title, XFile? file, String docType, {bool isRequired = true}) {
    final hasFile = file != null;
    final isPdf = hasFile && file.name.toLowerCase().endsWith('.pdf');
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
            if (hasFile) ...[
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isPdf ? Colors.red.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPdf ? Icons.picture_as_pdf : Icons.image,
                  color: isPdf ? Colors.redAccent : AppColors.primary,
                  size: 22,
                ),
              ),
            ],
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
                    hasFile ? file.name : 'Seçilmedi (PDF veya Fotoğraf)',
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
              ElevatedButton.icon(
                onPressed: () => _showDocumentSourceSheet(docType, title),
                icon: const Icon(Icons.file_upload_outlined, size: 16),
                label: const Text('Yükle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(88, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoBox(String label, XFile? file, String key) {
    return GestureDetector(
      onTap: () => _showPhotoSourceSheet(key, label),
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
    // Production Mode: Strict validations for all documents, photos and vehicle info
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
      // Auto refresh Supabase session if expired to prevent 401 Unauthorized errors during upload
      try {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null || session.isExpired) {
          await Supabase.instance.client.auth.refreshSession();
        }
      } catch (e) {
        debugPrint('Session auto-refresh attempt before onboarding submit: $e');
      }

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

      // Helper to determine filename with proper extension (.pdf, .png, .jpg, etc.)
      String getDocFileName(String base, XFile file) {
        final name = file.name.toLowerCase();
        final ext = name.contains('.') ? name.split('.').last : 'jpg';
        return '$base.$ext';
      }

      // Require mandatory documents (must have selected file or existing valid URL)
      String licenseUrl = (driver.driverLicenseUrl != null && driver.driverLicenseUrl!.isNotEmpty && !driver.driverLicenseUrl!.contains('picsum'))
          ? driver.driverLicenseUrl!
          : '';
      if (_driverLicense != null) {
        _uploadStatus = 'Sürücü belgesi yükleniyor...';
        setState(() {});
        licenseUrl = await repo.uploadDriverDocument(
          driverId: driver.id,
          documentType: 'license',
          fileName: getDocFileName('license', _driverLicense!),
          fileBytes: await _driverLicense!.readAsBytes(),
        );
      }
      if (licenseUrl.isEmpty) throw Exception('Sürücü belgesi yüklenemedi. Lütfen tekrar deneyin.');

      String registrationUrl = (driver.vehicleRegistrationUrl != null && driver.vehicleRegistrationUrl!.isNotEmpty && !driver.vehicleRegistrationUrl!.contains('picsum'))
          ? driver.vehicleRegistrationUrl!
          : '';
      if (_vehicleRegistration != null) {
        _uploadStatus = 'Araç ruhsatı yükleniyor...';
        setState(() {});
        registrationUrl = await repo.uploadDriverDocument(
          driverId: driver.id,
          documentType: 'registration',
          fileName: getDocFileName('registration', _vehicleRegistration!),
          fileBytes: await _vehicleRegistration!.readAsBytes(),
        );
      }
      if (registrationUrl.isEmpty) throw Exception('Araç ruhsatı yüklenemedi. Lütfen tekrar deneyin.');

      String criminalUrl = (driver.criminalRecordUrl != null && driver.criminalRecordUrl!.isNotEmpty && !driver.criminalRecordUrl!.contains('picsum'))
          ? driver.criminalRecordUrl!
          : '';
      if (_criminalRecord != null) {
        _uploadStatus = 'Adli sicil kaydı yükleniyor...';
        setState(() {});
        criminalUrl = await repo.uploadDriverDocument(
          driverId: driver.id,
          documentType: 'criminal',
          fileName: getDocFileName('criminal', _criminalRecord!),
          fileBytes: await _criminalRecord!.readAsBytes(),
        );
      }
      if (criminalUrl.isEmpty) throw Exception('Adli sicil kaydı yüklenemedi. Lütfen tekrar deneyin.');

      String? taxUrl = (driver.taxPlateUrl != null && driver.taxPlateUrl!.isNotEmpty && !driver.taxPlateUrl!.contains('picsum'))
          ? driver.taxPlateUrl!
          : null;
      if (_taxPlate != null) {
        _uploadStatus = 'Vergi levhası yükleniyor...';
        setState(() {});
        taxUrl = await repo.uploadDriverDocument(
          driverId: driver.id,
          documentType: 'tax_plate',
          fileName: getDocFileName('tax_plate', _taxPlate!),
          fileBytes: await _taxPlate!.readAsBytes(),
        );
      }

      // 4 Angle Vehicle Photos upload (No picsum fallback)
      List<String> vehiclePhotos = driver.vehiclePhotos.where((p) => !p.contains('picsum')).toList();
      while (vehiclePhotos.length < 4) {
        vehiclePhotos.add('');
      }

      if (_photoFront != null) {
        _uploadStatus = 'Ön araç fotoğrafı yükleniyor...';
        setState(() {});
        vehiclePhotos[0] = await repo.uploadDriverDocument(
          driverId: driver.id,
          documentType: 'vehicle_photos',
          fileName: 'front.jpg',
          fileBytes: await _photoFront!.readAsBytes(),
        );
      }
      if (_photoBack != null) {
        _uploadStatus = 'Arka araç fotoğrafı yükleniyor...';
        setState(() {});
        vehiclePhotos[1] = await repo.uploadDriverDocument(
          driverId: driver.id,
          documentType: 'vehicle_photos',
          fileName: 'back.jpg',
          fileBytes: await _photoBack!.readAsBytes(),
        );
      }
      if (_photoLeft != null) {
        _uploadStatus = 'Sol araç fotoğrafı yükleniyor...';
        setState(() {});
        vehiclePhotos[2] = await repo.uploadDriverDocument(
          driverId: driver.id,
          documentType: 'vehicle_photos',
          fileName: 'left.jpg',
          fileBytes: await _photoLeft!.readAsBytes(),
        );
      }
      if (_photoRight != null) {
        _uploadStatus = 'Sağ araç fotoğrafı yükleniyor...';
        setState(() {});
        vehiclePhotos[3] = await repo.uploadDriverDocument(
          driverId: driver.id,
          documentType: 'vehicle_photos',
          fileName: 'right.jpg',
          fileBytes: await _photoRight!.readAsBytes(),
        );
      }

      if (vehiclePhotos.any((p) => p.isEmpty)) {
        throw Exception('Lütfen aracınızın tüm 4 açıdan fotoğraflarını eksiksiz yükleyiniz.');
      }

      final selectedEquipments = _equipments.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      final updatedDriver = driver.copyWith(
        vehiclePlate: _vehiclePlateController.text.trim().toUpperCase(),
        vehicleBrand: _vehicleBrandController.text.trim(),
        vehicleModel: _vehicleModelController.text.trim(),
        vehicleColor: _vehicleColorController.text.trim(),
        vehicleYear: int.tryParse(_vehicleYearController.text.trim()),
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
          SnackBar(content: Text(AppErrorHandler.parse(e)), backgroundColor: AppColors.error),
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
                        final driver = ref.read(currentUserProvider).value as DriverModel?;
                        if (_currentStep == 0) {
                          final hasLicense = _driverLicense != null || (driver?.driverLicenseUrl?.isNotEmpty ?? false);
                          final hasRegistration = _vehicleRegistration != null || (driver?.vehicleRegistrationUrl?.isNotEmpty ?? false);
                          final hasCriminal = _criminalRecord != null || (driver?.criminalRecordUrl?.isNotEmpty ?? false);

                          if (!hasLicense || !hasRegistration || !hasCriminal) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Lütfen tüm zorunlu evrakları yükleyiniz (Ehliyet, Ruhsat, Adli Sicil).'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }
                          setState(() => _currentStep++);
                        } else if (_currentStep == 1) {
                          final existingPhotosCount = driver?.vehiclePhotos.where((p) => !p.contains('picsum')).length ?? 0;
                          final hasFront = _photoFront != null || existingPhotosCount > 0;
                          final hasBack = _photoBack != null || existingPhotosCount > 1;
                          final hasLeft = _photoLeft != null || existingPhotosCount > 2;
                          final hasRight = _photoRight != null || existingPhotosCount > 3;

                          if (!hasFront || !hasBack || !hasLeft || !hasRight) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Lütfen çekici aracınızın 4 farklı açıdan fotoğrafını yükleyiniz.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }
                          setState(() => _currentStep++);
                        } else if (_currentStep == 2) {
                          final hasVehicleType = _supportedVehicleTypes.values.any((v) => v);
                          if (!hasVehicleType) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Lütfen en az bir adet taşıyabildiğiniz araç türü seçin.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }
                          setState(() => _currentStep++);
                        } else {
                          if (_step4FormKey.currentState?.validate() ?? false) {
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
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => LegalDocumentsDialog.show(context, LegalDocumentType.consent),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                    children: [
                      TextSpan(text: 'Yüklediğiniz belgeler üzerindeki kimlik ve doğrulama verileri hizmetin ifası kapsamında işlenmektedir. Belge görsellerinde yer alabilecek özel nitelikli kişisel veriler için '),
                      TextSpan(
                        text: 'Açık Rıza Metni',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                      ),
                      TextSpan(text: '\'ni inceleyebilirsiniz.'),
                    ],
                  ),
                ),
              ),
            ),
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
                  side: const BorderSide(color: AppColors.textSecondary, width: 2),
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
                  side: const BorderSide(color: AppColors.textSecondary, width: 2),
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
              key: _step4FormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Araç Plakası *',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _vehiclePlateController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Örn: 35 BFG 051',
                      hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      prefixIcon: const Icon(Icons.directions_car_outlined, color: AppColors.accent),
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
                      if (v == null || v.trim().isEmpty) return 'Araç plakası zorunludur.';
                      if (v.trim().length < 5) return 'Lütfen geçerli bir plaka girin.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Araç Markası *',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _vehicleBrandController,
                              textCapitalization: TextCapitalization.words,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Örn: Ford',
                                hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                                filled: true,
                                fillColor: AppColors.cardBackground,
                                prefixIcon: const Icon(Icons.minor_crash_outlined, color: AppColors.accent),
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
                                if (v == null || v.trim().isEmpty) return 'Marka zorunludur.';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Araç Modeli *',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _vehicleModelController,
                              textCapitalization: TextCapitalization.words,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Örn: Cargo',
                                hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                                filled: true,
                                fillColor: AppColors.cardBackground,
                                prefixIcon: const Icon(Icons.directions_bus_outlined, color: AppColors.accent),
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
                                if (v == null || v.trim().isEmpty) return 'Model zorunludur.';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Araç Rengi *',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _vehicleColorController,
                              textCapitalization: TextCapitalization.words,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Örn: Beyaz',
                                hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                                filled: true,
                                fillColor: AppColors.cardBackground,
                                prefixIcon: const Icon(Icons.palette_outlined, color: AppColors.accent),
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
                                if (v == null || v.trim().isEmpty) return 'Renk zorunludur.';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Model Yılı (Opsiyonel)',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _vehicleYearController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Örn: 2020',
                                hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                                filled: true,
                                fillColor: AppColors.cardBackground,
                                prefixIcon: const Icon(Icons.calendar_today_outlined, color: AppColors.accent),
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
                                if (v != null && v.trim().isNotEmpty) {
                                  final yr = int.tryParse(v.trim());
                                  if (yr == null || yr < 1970 || yr > DateTime.now().year + 1) {
                                    return 'Geçersiz yıl';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
