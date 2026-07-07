import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_ui/widgets/green_button.dart';
import 'package:shared_ui/widgets/loading_overlay.dart';
import 'package:shared_models/driver_model.dart';
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
  XFile? _srcCertificate;
  XFile? _psychotechnic;
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
    'Ahtapot Vinç': false,
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
                    final img = await _picker.pickImage(source: ImageSource.gallery);
                    if (context.mounted) Navigator.pop(context, img);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                  title: const Text('Kamerayla Çek', style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () async {
                    final img = await _picker.pickImage(source: ImageSource.camera);
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
          case 'src':
            _srcCertificate = image;
            break;
          case 'psychotechnic':
            _psychotechnic = image;
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          title + (isRequired ? ' *' : ''),
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        subtitle: Text(
          hasFile ? file.name : 'Seçilmedi',
          style: TextStyle(color: hasFile ? AppColors.primary : AppColors.textSecondary, fontSize: 13),
        ),
        trailing: hasFile
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: AppColors.primary),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.error),
                    onPressed: () {
                      setState(() {
                        switch (docType) {
                          case 'license': _driverLicense = null; break;
                          case 'src': _srcCertificate = null; break;
                          case 'psychotechnic': _psychotechnic = null; break;
                          case 'registration': _vehicleRegistration = null; break;
                          case 'tax_plate': _taxPlate = null; break;
                          case 'criminal': _criminalRecord = null; break;
                        }
                      });
                    },
                  )
                ],
              )
            : ElevatedButton(
                onPressed: () => _pickImage(docType),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Yükle'),
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
    // Validations
    if (_driverLicense == null || _vehicleRegistration == null || _criminalRecord == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen zorunlu belgeleri (Ehliyet, Ruhsat, Adli Sicil) yükleyin.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_photoFront == null || _photoBack == null || _photoLeft == null || _photoRight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen çekicinin 4 açıdan fotoğraflarını eksiksiz yükleyin.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

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
      _uploadStatus = 'Dosyalar hazırlanıyor...';
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final driver = ref.read(currentUserProvider).value as DriverModel;

      // Upload files
      setState(() => _uploadStatus = 'Ehliyet yükleniyor...');
      final licenseUrl = await repo.uploadDriverDocument(
        driverId: driver.id,
        documentType: 'license',
        fileName: 'license.jpg',
        fileBytes: await _driverLicense!.readAsBytes(),
      );

      setState(() => _uploadStatus = 'Ruhsat yükleniyor...');
      final registrationUrl = await repo.uploadDriverDocument(
        driverId: driver.id,
        documentType: 'registration',
        fileName: 'registration.jpg',
        fileBytes: await _vehicleRegistration!.readAsBytes(),
      );

      setState(() => _uploadStatus = 'Adli Sicil Kaydı yükleniyor...');
      final criminalUrl = await repo.uploadDriverDocument(
        driverId: driver.id,
        documentType: 'criminal',
        fileName: 'criminal.jpg',
        fileBytes: await _criminalRecord!.readAsBytes(),
      );

      String? srcUrl;
      if (_srcCertificate != null) {
        setState(() => _uploadStatus = 'SRC Belgesi yükleniyor...');
        srcUrl = await repo.uploadDriverDocument(
          driverId: driver.id,
          documentType: 'src',
          fileName: 'src.jpg',
          fileBytes: await _srcCertificate!.readAsBytes(),
        );
      }

      String? psychoUrl;
      if (_psychotechnic != null) {
        setState(() => _uploadStatus = 'Psikoteknik yükleniyor...');
        psychoUrl = await repo.uploadDriverDocument(
          driverId: driver.id,
          documentType: 'psychotechnic',
          fileName: 'psychotechnic.jpg',
          fileBytes: await _psychotechnic!.readAsBytes(),
        );
      }

      String? taxUrl;
      if (_taxPlate != null) {
        setState(() => _uploadStatus = 'Vergi Levhası yükleniyor...');
        taxUrl = await repo.uploadDriverDocument(
          driverId: driver.id,
          documentType: 'tax_plate',
          fileName: 'tax_plate.jpg',
          fileBytes: await _taxPlate!.readAsBytes(),
        );
      }

      // Upload vehicle photos
      setState(() => _uploadStatus = 'Araç fotoğrafları yükleniyor (1/4)...');
      final frontUrl = await repo.uploadDriverDocument(
        driverId: driver.id,
        documentType: 'vehicle_photos',
        fileName: 'front.jpg',
        fileBytes: await _photoFront!.readAsBytes(),
      );

      setState(() => _uploadStatus = 'Araç fotoğrafları yükleniyor (2/4)...');
      final backUrl = await repo.uploadDriverDocument(
        driverId: driver.id,
        documentType: 'vehicle_photos',
        fileName: 'back.jpg',
        fileBytes: await _photoBack!.readAsBytes(),
      );

      setState(() => _uploadStatus = 'Araç fotoğrafları yükleniyor (3/4)...');
      final leftUrl = await repo.uploadDriverDocument(
        driverId: driver.id,
        documentType: 'vehicle_photos',
        fileName: 'left.jpg',
        fileBytes: await _photoLeft!.readAsBytes(),
      );

      setState(() => _uploadStatus = 'Araç fotoğrafları yükleniyor (4/4)...');
      final rightUrl = await repo.uploadDriverDocument(
        driverId: driver.id,
        documentType: 'vehicle_photos',
        fileName: 'right.jpg',
        fileBytes: await _photoRight!.readAsBytes(),
      );

      setState(() => _uploadStatus = 'Bilgiler güncelleniyor...');

      final selectedEquipments = _equipments.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      final updatedDriver = driver.copyWith(
        driverLicenseUrl: licenseUrl,
        vehicleRegistrationUrl: registrationUrl,
        criminalRecordUrl: criminalUrl,
        srcCertificateUrl: srcUrl,
        psychotechnicUrl: psychoUrl,
        taxPlateUrl: taxUrl,
        vehiclePhotos: [frontUrl, backUrl, leftUrl, rightUrl],
        equipments: selectedEquipments,
        supportedVehicleTypes: selectedVehicleTypes,
        isOnboardingCompleted: true,
        isVerified: false, // verification is pending admin review
      );

      await repo.updateUserProfile(updatedDriver);

      // Refresh auth notifier state
      await ref.read(authNotifierProvider.notifier).loadCurrentUser();

      if (mounted) {
        context.go('/driver');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dosya yükleme hatası: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _currentStep,
                children: [
                  // Step 1: Documents
                  ListView(
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
                      _buildDocTile('SRC Belgesi', _srcCertificate, 'src', isRequired: false),
                      _buildDocTile('Psikoteknik Belgesi', _psychotechnic, 'psychotechnic', isRequired: false),
                      _buildDocTile('Vergi Levhası / Oda Kaydı', _taxPlate, 'tax_plate', isRequired: false),
                    ],
                  ),

                  // Step 2: Vehicle Photos
                  Padding(
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
                  ),

                  // Step 3: Equipment and Vehicle Types list
                  ListView(
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
                  ),
                ],
              ),
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
                      text: _currentStep == 2 ? 'Başvuruyu Tamamla' : 'Devam Et',
                      onPressed: () {
                        if (_currentStep < 2) {
                          setState(() => _currentStep++);
                        } else {
                          _handleSubmit();
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
