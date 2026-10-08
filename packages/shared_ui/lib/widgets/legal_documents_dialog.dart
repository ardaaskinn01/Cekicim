import 'package:flutter/material.dart';

class LegalDocumentType {
  static const String kvkk = 'kvkk';
  static const String terms = 'terms';
  static const String consent = 'consent';
  static const String privacy = 'privacy';
}

class LegalDocumentsDialog extends StatelessWidget {
  final String title;
  final String content;

  const LegalDocumentsDialog({
    super.key,
    required this.title,
    required this.content,
  });

  static void show(BuildContext context, String type) {
    String title = '';
    String content = '';

    switch (type) {
      case LegalDocumentType.kvkk:
        title = 'ÇEKİCİM KİŞİSEL VERİLERİN KORUNMASI VE İŞLENMESİ AYDINLATMA METNİ';
        content = _kvkkText;
        break;
      case LegalDocumentType.terms:
        title = 'ÇEKİCİM SORUMLULUK REDDİ BEYANI VE PLATFORM KULLANIM KOŞULLARI';
        content = _termsText;
        break;
      case LegalDocumentType.consent:
        title = 'ÇEKİCİM AÇIK RIZA METNİ';
        content = _consentText;
        break;
      case LegalDocumentType.privacy:
        title = 'ÇEKİCİM GİZLİLİK POLİTİKASI';
        content = _privacyText;
        break;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LegalDocumentsDialog(title: title, content: content),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: SelectableText(
                content,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const String _kvkkText = '''
ÇEKİCİM MOBİL UYGULAMASI KİŞİSEL VERİLERİN KORUNMASI VE İŞLENMESİ AYDINLATMA METNİ

1. Veri Sorumlusunun Kimliği
6698 sayılı Kişisel Verilerin Korunması Kanunu (“KVKK”) uyarınca kişisel verileriniz; veri sorumlusu sıfatıyla Arda Çağan MANTAŞ (Adres: Kavaklıdere Mah. Paris Cad. No: 11/16 Çankaya / Ankara, E-posta: cekicimapp@gmail.com / ardamantas94@gmail.com) tarafından, ÇEKİCİM mobil uygulaması (“Uygulama”) kapsamında aşağıda açıklanan amaçlar ve hukuki sebepler doğrultusunda işlenmektedir.

2. İşlenen Kişisel Veriler, İşleme Amaçları ve Hukuki Sebepleri
Uygulamamız, araç sahipleri/kullanıcılar (“Kullanıcı”) ile çekici/yol yardım hizmeti sunan bağımsız sürücüleri (“Çekici / Hizmet Veren”) bir araya getiren bir teknoloji platformudur. Sıfatınıza göre işlenen kişisel verileriniz şunlardır:

A. Tüm Üyeler (Kullanıcılar ve Çekiciler) İçin Ortak Veriler:
• Kimlik ve İletişim Bilgileri (Ad, soyad, T.C. kimlik numarası, telefon numarası, e-posta adresi): Üyelik kaydının oluşturulması, kimlik doğrulama (SMS OTP) ve taraflar arası iletişimin sağlanması amacıyla KVKK m. 5/2-c (Sözleşmenin kurulması veya ifası) hukuki sebebine dayanarak.
• Konum Bilgileri (Anlık GPS konumu, arıza/teslimat adres bilgileri): Kullanıcıya en yakın çekicinin tespit edilmesi, öngörülebilir rota/fiyat hesaplamasının yapılması ve çekici hizmetinin canlı takip edilebilmesi amacıyla KVKK m. 5/2-c (Sözleşmenin kurulması veya ifası) hukuki sebebine dayanarak.
• İşlem Güvenliği Bilgileri (IP adresi, cihaz ID, log kayıtları, giriş-çıkış saatleri): Bilgi güvenliği süreçlerinin yürütülmesi ve 5651 sayılı Kanun başta olmak üzere mevzuattan kaynaklanan yükümlülüklerin yerine getirilmesi amacıyla KVKK m. 5/2-ç (Hukuki yükümlülüğün yerine getirilmesi) ve m. 5/2-f (Meşru menfaat) hukuki sebeplerine dayanarak.
• Müşteri İşlem ve Finans Bilgileri (Talep geçmişi, hizmet bedeli, fatura/ödeme bilgileri): Hizmet süreçlerinin yürütülmesi ve finans/muhasebe işlerinin takibi amacıyla KVKK m. 5/2-c ve m. 5/2-ç hukuki sebeplerine dayanarak.

B. Yalnızca Kullanıcılar (Hizmet Alan Araç Sahipleri) İçin:
• Araç ve Görsel Bilgileri (Araç plakası, marka, model, araç ruhsat bilgisi, aracın bulunduğu konum/hasar/arıza fotoğrafları): Çekilecek aracın niteliğine uygun çekici tipinin belirlenmesi, hizmet maliyetinin öngörülmesi, aracın zilyetlik/mülkiyet teyidinin yapılması ve olası hasar uyuşmazlıklarında delil teşkil etmesi amacıyla KVKK m. 5/2-c ve m. 5/2-e hukuki sebeplerine dayanarak.

C. Yalnızca Çekiciler (Hizmet Veren Sürücüler) İçin:
• Sürücü, Araç ve Mesleki Yeterlilik Belgeleri (Ehliyet, kimlik belgesi, çekici araç ruhsatı, profil fotoğrafı, çekici araç fotoğrafları, varsa SRC/Yetki Belgesi/Vergi Levhası bilgileri): Hizmet verenlerin kimlik ve mesleki yeterliliklerinin doğrulanması, platform güvenliğinin sağlanması ve kullanıcılara güvenli hizmet sunulması amacıyla KVKK m. 5/2-c ve m. 5/2-f hukuki sebebine dayanarak. (Belge görselleri üzerinde yer alabilecek kan grubu vb. özel nitelikli kişisel veriler ise yalnızca KVKK m. 6/2 kapsamında açık rızanızın bulunması halinde işlenmektedir.)

3. Kişisel Verilerin Aktarılması
Kişisel verileriniz;
• Eşleşmenin ve çekici hizmetinin gerçekleşebilmesi için KVKK m. 8/2-a kapsamında; talep oluşturulduğunda Kullanıcının ad-soyad, iletişim, konum, araç ve arıza/fotoğraf bilgileri ilgili Çekici ile; Çekicinin ad-soyad, fotoğraf, iletişim, plaka/araç ve canlı konum bilgileri ise ilgili Kullanıcı ile paylaşılır.
• Hukuki uyuşmazlıklarda veya yasal taleplerde yetkili kamu kurum ve kuruluşları ile KVKK m. 8/2-a kapsamında paylaşılır.
• Uygulamanın teknik altyapısının sağlanması amacıyla hizmet alınan tedarikçilerle KVKK m. 8 ve m. 9 hükümlerine uygun olarak paylaşılır.

4. Kişisel Verilerin Toplanma Yöntemi
Kişisel verileriniz; Uygulama içindeki kayıt formları, belge/fotoğraf yükleme ekranları, cihazınızın GPS/konum servisleri ve çağrı/destek kanalları aracılığıyla tamamen veya kısmen otomatik yöntemlerle elektronik ortamda toplanmaktadır.

5. İlgili Kişinin Hakları (KVKK m. 11)
KVKK’nın 11. maddesi uyarınca haklarınızı kullanmak için taleplerinizi cekicimapp@gmail.com veya ardamantas94@gmail.com adresine iletebilirsiniz.
''';

  static const String _termsText = '''
ÇEKİCİM SORUMLULUK REDDİ BEYANI VE PLATFORM KULLANIM KOŞULLARI

1. Platformun Hukuki Niteliği ve Aracı Statüsü
1.1. ÇEKİCİM mobil uygulaması (“Platform”), araç sahipleri veya zilyetleri (“Kullanıcı”) ile bağımsız olarak çekici, kurtarıcı ve yol yardım hizmeti sunan gerçek veya tüzel kişileri (“Çekici / Hizmet Veren”) çevrimiçi ortamda bir araya getiren bir teknoloji ve eşleştirme platformudur.
1.2. Platform işleticisi Arda Çağan MANTAŞ, 6102 sayılı Türk Ticaret Kanunu anlamında “Taşıyıcı”, “Nakliyeci” veya “Taşıma İşleri Komisyoncusu” değildir. Platformun bünyesinde kendine ait çekici aracı veya bordrolu sürücü bulunmamaktadır.
1.3. Çekici ve yol yardım hizmetine ilişkin taşıma sözleşmesi, yalnızca ve doğrudan Kullanıcı ile Çekici arasında kurulur. Platform, bu sözleşmenin tarafı, kefili veya garantörü değildir.

2. Taşıma Süreci, Araç Hasarları ve Maddi/Bedeni Zararlar
2.1. Aracın bulunduğu yerden alınması, çekiciye yüklenmesi, sabitlenmesi, taşınması ve varış noktasında indirilmesi süreçlerinin tamamı bağımsız Hizmet Veren’in (Çekici’nin) mesleki uzmanlığı, kontrolü ve sorumluluğu altındadır.
2.2. Yükleme, taşıma veya indirme esnasında taşınan araçta, üçüncü kişilerin malvarlığında veya şahıslarda meydana gelebilecek her türlü çizik, göçük, mekanik arıza, kaza, devrilme, yangın, ziya, hasar veya bedeni zararlardan Platform hiçbir şekilde sorumlu tutulamaz.
2.3. Çekilecek araç içerisinde bırakılan nakit para, kıymetli evrak, elektronik cihaz veya sair özel eşyaların güvenliği tamamen Kullanıcı’nın sorumluluğundadır.

3. Tahmini Ücret, Mesafe ve Varış Süresi (Öngörülebilirlik Sınırları)
3.1. Platform üzerinden sunulan ücret hesaplamaları, rota çizimleri ve tahmini varış süreleri; GPS verileri, harita servisleri ve Kullanıcı’nın beyan ettiği standart veriler üzerinden algoritma tarafından üretilen ön bilgilendirme ve tahmin niteliğindedir.
3.2. Trafik yoğunluğu, hava ve yol koşulları, GPS sapmaları veya Kullanıcı tarafından eksik/hatalı bildirilen durumlar nedeniyle oluşabilecek süre uzamalarından ve fiyat farklarından Platform sorumlu değildir.

4. Çekici (Hizmet Veren) Beyan ve Yükümlülükleri
4.1. Platformda hizmet sunan her bir Çekici; Karayolları Trafik Kanunu ve ilgili mevzuat uyarınca sahip olması gereken geçerli sürücü belgesi, mesleki yeterlilik belgesi (SRC), psikoteknik değerlendirme belgesi, yetki belgesi, taşıyıcı sorumluluk sigortalarına sahip olduğunu kabul ve taahhüt eder.

5. Kullanıcı Beyan ve Yükümlülükleri
5.1. Kullanıcı, çekilmesini talep ettiği aracın maliki, yasal zilyedi veya yetkilendirilmiş kişi olduğunu kabul eder.

6. Hizmet Kesintileri ve Teknik Sınırlar
6.1. Platform “olduğu gibi” (as is) sunulmaktadır. İnternet kesintileri, harita/konum servis sağlayıcılarındaki hatalar nedeniyle eşleşmenin gerçekleşmemesinden Platform sorumlu tutulamaz.

7. Kabul ve Yürürlük
Platforma üye olan, çekici talebi oluşturan veya çağrı kabul eden tüm Kullanıcılar ve Çekiciler, işbu Sorumluluk Reddi Beyanı’nı okuduklarını ve şartları kayıtsız şartsız kabul ettiklerini beyan ederler.
''';

  static const String _consentText = '''
ÇEKİCİM AÇIK RIZA METNİ

ÇEKİCİM Aydınlatma Metni’ni okudum ve inceledim. Bu kapsamda;

1. Belge Görsellerindeki Özel Nitelikli Veriler (Belge Yükleyen Üyeler İçin):
Kimlik, ehliyet ve yetki doğrulaması amacıyla Uygulamaya kendi irademle yüklediğim kimlik belgesi ve sürücü belgesi görselleri üzerinde yer alan kan grubu (ve eski tip kimliklerde yer alabilecek din bilgisi) gibi özel nitelikli kişisel verilerimin, doğrulama süreçlerinin yürütülmesi ve güvenliğin sağlanması amacıyla kaydedilmesine ve saklanmasına,

2. Konum Bazlı İyileştirme ve Analiz:
Uygulamayı aktif olarak kullanmadığım zamanlarda dahi bana daha özel çekici/yol yardım tekliflerinin sunulabilmesi ve bölgesel yoğunluk analizlerinin yapılabilmesi amacıyla konum verilerimin işlenmesine,

3. Pazarlama ve Kampanya Süreçleri:
Kullanım alışkanlıklarımın analiz edilerek bana özel indirim, kampanya ve fırsatların oluşturulması amacıyla iletişim verilerimin işlenmesine,

her zaman geri alma hakkım saklı kalmak kaydıyla, özgür irademle açık rıza veriyorum.
''';

  static const String _privacyText = '''
ÇEKİCİM GİZLİLİK POLİTİKASI (PRIVACY POLICY)
Son Güncelleme Tarihi: 06.10.2026

1. Giriş ve Kapsam
İşbu Gizlilik Politikası, Arda Çağan MANTAŞ (“Platform”, “Biz”) tarafından işletilen ÇEKİCİM mobil uygulamasını (“Uygulama”) kullanan araç sahipleri/hizmet alanlar (“Kullanıcı”) ile bağımsız çekici ve yol yardım sürücülerinin (“Çekici / Hizmet Veren”) hangi verilerinin toplandığını, cihaz izinlerinin nasıl kullanıldığını ve veri silme süreçlerini açıklamak amacıyla hazırlanmıştır.

2. Toplanan Veriler ve Cihaz İzinleri (App Permissions)
• Konum Verileri (Ön Plan ve Arka Plan Konum İzni)
• Kamera ve Fotoğraf Galerisi İzni
• Kimlik, İletişim ve Araç Bilgileri
• Anlık Bildirimler (Push Notifications)

3. Hesap Silme ve Verilerin İmhası (Account & Data Deletion)
Kullanıcılar ve Çekiciler, diledikleri zaman hesaplarını ve kişisel verilerini silme hakkına sahiptir:
1. Uygulama İçinden Silme: Profil / Ayarlar -> Hesabımı Sil adımlarını takip ederek hesabınızı anında ve kalıcı olarak silebilirsiniz.
2. Web / E-posta Üzerinden Silme: cekicimapp@gmail.com veya ardamantas94@gmail.com adresine talep gönderebilirsiniz.
''';
}
