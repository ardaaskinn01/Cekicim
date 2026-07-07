import 'dart:convert';
import 'dart:io';

class NviService {
  static const String _nviUrl = 'https://tckimlik.nvi.gov.tr/Service/KPSPublic.asmx';

  static String toTurkishUpperCase(String input) {
    return input
        .replaceAll('ı', 'I')
        .replaceAll('i', 'İ')
        .replaceAll('ğ', 'Ğ')
        .replaceAll('ü', 'Ü')
        .replaceAll('ş', 'Ş')
        .replaceAll('ö', 'Ö')
        .replaceAll('ç', 'Ç')
        .toUpperCase();
  }

  Future<bool> validateTCKimlikNo({
    required String tcNo,
    required String firstName,
    required String lastName,
    required int birthYear,
  }) async {
    final cleanFirstName = toTurkishUpperCase(firstName.trim());
    final cleanLastName = toTurkishUpperCase(lastName.trim());

    final soapEnvelope = '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <TCKimlikNoDogrula xmlns="http://tckimlik.nvi.gov.tr/WS">
      <TCKimlikNo>$tcNo</TCKimlikNo>
      <Ad>$cleanFirstName</Ad>
      <Soyad>$cleanLastName</Soyad>
      <DogumYili>$birthYear</DogumYili>
    </TCKimlikNoDogrula>
  </soap:Body>
</soap:Envelope>''';

    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(_nviUrl));
      request.headers.set('Content-Type', 'text/xml; charset=utf-8');
      request.headers.set('SOAPAction', 'http://tckimlik.nvi.gov.tr/WS/TCKimlikNoDogrula');
      
      request.write(soapEnvelope);
      final response = await request.close();
      
      if (response.statusCode != 200) {
        throw Exception('NVİ servisine bağlanılamadı. Durum kodu: ${response.statusCode}');
      }
      
      final responseBody = await response.transform(utf8.decoder).join();
      
      final match = RegExp(r'<TCKimlikNoDogrulaResult>(true|false)</TCKimlikNoDogrulaResult>').firstMatch(responseBody);
      if (match != null) {
        return match.group(1) == 'true';
      }
      return false;
    } catch (e) {
      throw Exception('Kimlik doğrulaması sırasında hata oluştu: $e');
    } finally {
      client.close();
    }
  }
}
