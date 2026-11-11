import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:shared_models/service_request_model.dart';
import 'package:shared_models/user_model.dart';
import 'file_downloader.dart';

class ExportService {
  static String _escapeCsv(dynamic value) {
    if (value == null) return '""';
    final str = value.toString().replaceAll('"', '""');
    return '"$str"';
  }

  static String _dateStamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  static void exportRequestsToCsv(List<ServiceRequestModel> requests) {
    final buffer = StringBuffer();
    // UTF-8 BOM for Excel Turkish character compatibility
    buffer.write('\uFEFF');

    // Headers
    buffer.writeln([
      'Talep ID',
      'Müşteri Adı',
      'Sürücü Adı',
      'Araç Marka Model',
      'Plaka',
      'Arıza Tipi',
      'Alınış Adresi',
      'Varış Adresi / Sanayi',
      'Mesafe (KM)',
      'Tutar (TL)',
      'Durum',
      'Oluşturulma Tarihi',
      'Tamamlanma Tarihi',
    ].map(_escapeCsv).join(';'));

    // Rows
    for (var r in requests) {
      final createdStr = '${r.createdAt.day.toString().padLeft(2, '0')}.${r.createdAt.month.toString().padLeft(2, '0')}.${r.createdAt.year} ${r.createdAt.hour.toString().padLeft(2, '0')}:${r.createdAt.minute.toString().padLeft(2, '0')}';
      final completedStr = r.completedAt != null
          ? '${r.completedAt!.day.toString().padLeft(2, '0')}.${r.completedAt!.month.toString().padLeft(2, '0')}.${r.completedAt!.year} ${r.completedAt!.hour.toString().padLeft(2, '0')}:${r.completedAt!.minute.toString().padLeft(2, '0')}'
          : '-';

      buffer.writeln([
        r.id,
        r.customerName ?? 'Bilinmiyor',
        r.driverName ?? (r.driverId != null ? 'Sürücü Atandı' : 'Bekliyor'),
        '${r.carBrand} ${r.carModel} (${r.carColor})',
        r.carPlate,
        r.problemType,
        r.customerAddress ?? '-',
        r.destinationAddress ?? r.destinationIndustryZone ?? '-',
        r.distanceKm.toStringAsFixed(1),
        r.price.toStringAsFixed(2),
        r.status.label,
        createdStr,
        completedStr,
      ].map(_escapeCsv).join(';'));
    }

    final filename = 'cekicim_talepler_${_dateStamp()}.csv';
    downloadFileFromString(buffer.toString(), filename, 'text/csv;charset=utf-8');
  }

  static void exportDriversToCsv(List<Map<String, dynamic>> drivers) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');

    buffer.writeln([
      'Sürücü ID',
      'Ad Soyad',
      'Telefon',
      'E-posta',
      'Araç Plakası',
      'Araç Tipi',
      'Puan',
      'Toplam Sefer',
      'IBAN Sahibi',
      'IBAN',
      'Evrak Onay Durumu',
      'Hesap Durumu',
    ].map(_escapeCsv).join(';'));

    for (var d in drivers) {
      final prof = d['profiles'] as Map<String, dynamic>? ?? {};
      final isVerified = d['is_verified'] as bool? ?? false;
      final isSuspended = prof['is_suspended'] as bool? ?? false;

      buffer.writeln([
        d['id'],
        prof['full_name'] ?? 'Bilinmiyor',
        prof['phone'] ?? '-',
        prof['email'] ?? '-',
        d['vehicle_plate'] ?? '-',
        d['vehicle_type'] ?? '-',
        (d['rating'] as num?)?.toStringAsFixed(1) ?? '5.0',
        d['total_services'] ?? 0,
        d['iban_owner_name'] ?? '-',
        d['iban'] ?? '-',
        isVerified ? 'Onaylandı' : 'Beklemede',
        isSuspended ? 'Engellenmiş / Askıda' : 'Aktif',
      ].map(_escapeCsv).join(';'));
    }

    final filename = 'cekicim_suruculer_${_dateStamp()}.csv';
    downloadFileFromString(buffer.toString(), filename, 'text/csv;charset=utf-8');
  }

  static void exportCustomersToCsv(List<UserModel> customers) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');

    buffer.writeln([
      'Müşteri ID',
      'Ad Soyad',
      'Telefon',
      'E-posta',
      'Puan',
      'Hesap Durumu',
      'Kayıt Tarihi',
    ].map(_escapeCsv).join(';'));

    for (var c in customers) {
      buffer.writeln([
        c.id,
        c.fullName,
        c.phone ?? '-',
        c.email,
        c.rating.toStringAsFixed(1),
        c.isSuspended ? 'Engellenmiş' : 'Aktif',
        '${c.createdAt.day.toString().padLeft(2, '0')}.${c.createdAt.month.toString().padLeft(2, '0')}.${c.createdAt.year}',
      ].map(_escapeCsv).join(';'));
    }

    final filename = 'cekicim_musteriler_${_dateStamp()}.csv';
    downloadFileFromString(buffer.toString(), filename, 'text/csv;charset=utf-8');
  }

  static void exportFinancialReportToCsv(List<ServiceRequestModel> requests) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');

    double totalGmv = 0.0;
    double totalDriverPayout = 0.0;
    double totalPlatformFee = 0.0;

    for (var r in requests) {
      if (r.status.dbValue == 'completed') {
        totalGmv += r.price;
        // Platform komisyon oranı: %15, Sürücü hakedişi: %85
        totalDriverPayout += (r.price * 0.85);
        totalPlatformFee += (r.price * 0.15);
      }
    }

    // Finansal Özet Başlığı
    buffer.writeln('"ÇEKİCİM MALİ VE HAKEDİŞ DENETİM RAPORU"');
    buffer.writeln('"Rapor Tarihi";${_escapeCsv(_dateStamp())}');
    buffer.writeln('"Toplam Brüt Tahsilat (GMV)";"${totalGmv.toStringAsFixed(2)} TL"');
    buffer.writeln('"Toplam Sürücü Hakediş Havuzu (%85)";"${totalDriverPayout.toStringAsFixed(2)} TL"');
    buffer.writeln('"Net Platform Komisyon Geliri (%15)";"${totalPlatformFee.toStringAsFixed(2)} TL"');
    buffer.writeln('');

    // Tablo Başlıkları
    buffer.writeln([
      'Talep ID',
      'Tarih',
      'Müşteri Adı',
      'Sürücü Adı',
      'Plaka',
      'Hizmet Bedeli (TL)',
      'Sürücü Hakedişi (%85) (TL)',
      'Platform Komisyonu (%15) (TL)',
      'Durum',
    ].map(_escapeCsv).join(';'));

    for (var r in requests) {
      final isCompleted = r.status.dbValue == 'completed';
      final driverShare = isCompleted ? (r.price * 0.85) : 0.0;
      final platformShare = isCompleted ? (r.price * 0.15) : 0.0;
      final dateStr = '${r.createdAt.day.toString().padLeft(2, '0')}.${r.createdAt.month.toString().padLeft(2, '0')}.${r.createdAt.year}';

      buffer.writeln([
        r.id,
        dateStr,
        r.customerName ?? 'Bilinmiyor',
        r.driverName ?? (r.driverId != null ? 'Sürücü Atandı' : 'Bekliyor'),
        r.carPlate,
        r.price.toStringAsFixed(2),
        driverShare.toStringAsFixed(2),
        platformShare.toStringAsFixed(2),
        r.status.label,
      ].map(_escapeCsv).join(';'));
    }

    final filename = 'cekicim_mali_hakedis_raporu_${_dateStamp()}.csv';
    downloadFileFromString(buffer.toString(), filename, 'text/csv;charset=utf-8');
  }

  static String _sanitizeFilename(String text) {
    return text
        .replaceAll(RegExp(r'[^\w\s\.-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
  }

  /// Tek bir sürücünün tüm evrak ve araç fotoğraflarını ZIP olarak paketleyip indirir
  static Future<void> downloadSingleDriverArchiveZip(Map<String, dynamic> driver) async {
    final prof = driver['profiles'] as Map<String, dynamic>? ?? {};
    final driverName = _sanitizeFilename(prof['full_name'] as String? ?? 'surucu');
    final plate = _sanitizeFilename(driver['vehicle_plate'] as String? ?? 'plakasiz');

    final archive = Archive();

    final docs = <String, String?>{
      'ehliyet': driver['driver_license_url'] as String?,
      'ruhsat': driver['vehicle_registration_url'] as String?,
      'vergi_levhasi': driver['tax_plate_url'] as String?,
      'adli_sicil_kaydi': driver['criminal_record_url'] as String?,
      'src_belgesi': driver['src_certificate_url'] as String?,
      'psikoteknik_belgesi': driver['psychotechnic_url'] as String?,
      'profil_fotografi': prof['avatar_url'] as String?,
    };

    final client = http.Client();
    try {
      for (var entry in docs.entries) {
        final url = entry.value;
        if (url != null && url.isNotEmpty && !url.contains('picsum')) {
          try {
            final res = await client.get(Uri.parse(url));
            if (res.statusCode == 200) {
              final ext = url.split('?').first.split('.').last.toLowerCase();
              final validExt = ['jpg', 'jpeg', 'png', 'pdf', 'webp'].contains(ext) ? ext : 'jpg';
              final filename = '${entry.key}.$validExt';
              archive.addFile(ArchiveFile(filename, res.bodyBytes.length, res.bodyBytes));
            }
          } catch (_) {}
        }
      }

      // Araç fotoğrafları (4 açı)
      final rawPhotos = driver['vehicle_photos'];
      if (rawPhotos is List) {
        final photoNames = ['arac_on', 'arac_arka', 'arac_sol', 'arac_sag'];
        int photoIndex = 0;
        for (var p in rawPhotos) {
          if (p is String && p.isNotEmpty && !p.contains('picsum')) {
            try {
              final res = await client.get(Uri.parse(p));
              if (res.statusCode == 200) {
                final ext = p.split('?').first.split('.').last.toLowerCase();
                final validExt = ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
                final label = photoIndex < photoNames.length ? photoNames[photoIndex] : 'arac_ek_$photoIndex';
                archive.addFile(ArchiveFile('$label.$validExt', res.bodyBytes.length, res.bodyBytes));
                photoIndex++;
              }
            } catch (_) {}
          }
        }
      }

      // Sürücü özet bilgi metin dosyası
      final summary = '''
ÇEKİCİM SÜRÜCÜ ARŞİV BİLGİ KARTI
================================
Ad Soyad: ${prof['full_name'] ?? '-'}
Telefon: ${prof['phone'] ?? '-'}
E-posta: ${prof['email'] ?? '-'}
Sürücü ID: ${driver['id']}
Araç Plakası: ${driver['vehicle_plate'] ?? '-'}
Araç Tipi: ${driver['vehicle_type'] ?? '-'}
Puan: ${(driver['rating'] as num?)?.toStringAsFixed(1) ?? '5.0'}
Toplam Sefer: ${driver['total_services'] ?? 0}
IBAN Sahibi: ${driver['iban_owner_name'] ?? '-'}
IBAN: ${driver['iban'] ?? '-'}
Arşiv İndirme Tarihi: ${DateTime.now()}
''';
      final summaryBytes = utf8.encode(summary);
      archive.addFile(ArchiveFile('surucu_bilgi_kartı.txt', summaryBytes.length, summaryBytes));

      final zipData = ZipEncoder().encode(archive);
      downloadFileFromBytes(Uint8List.fromList(zipData), '${driverName}_${plate}_arsiv.zip', 'application/zip');
    } finally {
      client.close();
    }
  }

  /// Tüm kabul edilen sürücülerin arşivini klasörler halinde toplu ZIP olarak paketleyip indirir
  static Future<void> downloadAllDriversArchiveZip(
    List<Map<String, dynamic>> drivers, {
    void Function(int current, int total, String driverName)? onProgress,
  }) async {
    final archive = Archive();
    final client = http.Client();

    try {
      int count = 0;
      for (var driver in drivers) {
        count++;
        final prof = driver['profiles'] as Map<String, dynamic>? ?? {};
        final rawName = prof['full_name'] as String? ?? 'surucu_$count';
        final driverFolder = '${_sanitizeFilename(rawName)}_${_sanitizeFilename(driver['vehicle_plate'] as String? ?? 'plakasiz')}';

        onProgress?.call(count, drivers.length, rawName);

        final docs = <String, String?>{
          'ehliyet': driver['driver_license_url'] as String?,
          'ruhsat': driver['vehicle_registration_url'] as String?,
          'vergi_levhasi': driver['tax_plate_url'] as String?,
          'adli_sicil_kaydi': driver['criminal_record_url'] as String?,
          'src_belgesi': driver['src_certificate_url'] as String?,
          'psikoteknik_belgesi': driver['psychotechnic_url'] as String?,
        };

        for (var entry in docs.entries) {
          final url = entry.value;
          if (url != null && url.isNotEmpty && !url.contains('picsum')) {
            try {
              final res = await client.get(Uri.parse(url));
              if (res.statusCode == 200) {
                final ext = url.split('?').first.split('.').last.toLowerCase();
                final validExt = ['jpg', 'jpeg', 'png', 'pdf', 'webp'].contains(ext) ? ext : 'jpg';
                final path = '$driverFolder/${entry.key}.$validExt';
                archive.addFile(ArchiveFile(path, res.bodyBytes.length, res.bodyBytes));
              }
            } catch (_) {}
          }
        }

        // Araç fotoğrafları
        final rawPhotos = driver['vehicle_photos'];
        if (rawPhotos is List) {
          final photoNames = ['arac_on', 'arac_arka', 'arac_sol', 'arac_sag'];
          int photoIndex = 0;
          for (var p in rawPhotos) {
            if (p is String && p.isNotEmpty && !p.contains('picsum')) {
              try {
                final res = await client.get(Uri.parse(p));
                if (res.statusCode == 200) {
                  final ext = p.split('?').first.split('.').last.toLowerCase();
                  final validExt = ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
                  final label = photoIndex < photoNames.length ? photoNames[photoIndex] : 'arac_ek_$photoIndex';
                  final path = '$driverFolder/$label.$validExt';
                  archive.addFile(ArchiveFile(path, res.bodyBytes.length, res.bodyBytes));
                  photoIndex++;
                }
              } catch (_) {}
            }
          }
        }

        // Sürücü metin özeti
        final summary = '''Sürücü: ${prof['full_name']} | Plaka: ${driver['vehicle_plate']} | Tel: ${prof['phone']} | IBAN: ${driver['iban']}''';
        final summaryBytes = utf8.encode(summary);
        archive.addFile(ArchiveFile('$driverFolder/ozet.txt', summaryBytes.length, summaryBytes));
      }

      final zipData = ZipEncoder().encode(archive);
      final filename = 'cekicim_surucu_arsivi_toplu_${_dateStamp()}.zip';
      downloadFileFromBytes(Uint8List.fromList(zipData), filename, 'application/zip');
    } finally {
      client.close();
    }
  }
}

