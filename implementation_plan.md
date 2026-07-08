# Implementation Plan — Talep Oluşturma, Eşleşme Motoru & Tamamlama Sistemi

Bu plan, müşterinin çekici talebini oluşturduğu andan hizmetin güvenli şekilde tamamlanmasına kadar olan tam akışı kapsamaktadır.

---

## Mevcut Durumdan Farklılıklar

> [!IMPORTANT]
> Mevcut `RequestServiceScreen` müşterinin talebi doğrudan oluşturup "çekici aranıyor" ekranına geçmesini sağlıyor. Yeni sistemde müşteri talep oluştururken önce en yakın 5 çekiciyi görecek, dilediği çekicileri seçip onlara alarm gönderecek. İlk kabul eden eşleşecek. Bu, mevcut `ServiceRequestModel`, `PriceCalculator` ve `RequestRepository` katmanlarında köklü değişiklik gerektiriyor.

> [!WARNING]
> Sürücü onboardingindeki **Ahtapot Vinç** ekipman seçeneği kaldırılacak. Bu UI-only bir değişiklik, veritabanı şemasını etkilemiyor.

---

## Open Questions

1.  **Sanayi Siteleri (Hedef Nokta):** Müşteri talep açarken "Nereye götüreceğiz?" seçimi için Ankara'daki sanayi sitelerinin listesini siz mi vereceksiniz, yoksa ben başlangıç için standart Ankara sanayi siteleri (OSTİM, İvedik, Siteler, Dışkapı vb.) listesini elle tanımlayayım mı?
2.  **Araç Görseli (Fotoğraf):** Müşteri fotoğraf yükleyecek demiştiniz. Bu fotoğraf Supabase Storage'a yüklensin mi? (Evet ise mevcut `driver-documents` bucket'ına mı, yoksa ayrı bir `request-photos` bucket'ına mı?)
3.  **Araç Türü Seçimi (Müşteri):** Müşteri yalnızca kendi aracının türünü mü seçecek (Sedan, SUV, Minibüs vb.), yoksa hasar/durum soruları da sorulacak mı? (Talepteki notlarınıza göre hasar sorularını sormayacağız, sadece araç türü + fotoğraf yeterli.)
4.  **Alarm (Push Notification) Altyapısı:** Seçilen çekicilere alarm gönderebilmek için Firebase Cloud Messaging (FCM) token'larının sürücü profillerinde saklanması gerekiyor. Projede mevcut bir FCM entegrasyonu var mı?

---

## Proposed Changes

### 1. Sabitler & Fiyat Hesaplayıcı (shared_ui)

#### [MODIFY] [app_constants.dart](file:///c:/Users/ardaa/StudioProjects/cekici/packages/shared_ui/lib/app_constants.dart)
- `minPrice`: `2000.0` (0-1 km arası başlangıç fiyatı)
- `pricePerKmUpTo15`: `200.0` (1-15 km arası km başı artış)
- `pricePerKmAfter15`: `150.0` (15 km sonrası km başı artış)
- `matchingRadiusKm`: `30.0` (Maksimum eşleşme yarıçapı)
- `maxDriversToShow`: `5` (Müşteriye gösterilen maksimum çekici sayısı)

#### [MODIFY] [price_calculator.dart](file:///c:/Users/ardaa/StudioProjects/cekici/packages/shared_ui/lib/price_calculator.dart)
Yeni formüle göre güncelleme:
```
0 - 1 km  → ₺2.000 (sabit)
1 - 15 km → ₺2.000 + (mesafe - 1) × ₺200
15+ km    → 15 km fiyatı + (mesafe - 15) × ₺150
```

---

### 2. Veri Modeli (shared_models)

#### [MODIFY] [service_request_model.dart](file:///c:/Users/ardaa/StudioProjects/cekici/packages/shared_models/lib/service_request_model.dart)
Aşağıdaki yeni alanlar eklenecek:
- `vehicleType` (String) — Müşterinin araç türü (sedan, suv, minibus vb.)
- `vehiclePhotoUrl` (String?) — Yüklenen araç görsel URL'i
- `selectedDriverIds` (List<String>) — Müşterinin seçtiği (alarm gönderilen) sürücü ID listesi
- `destinationIndustryZone` (String?) — Seçilen sanayi sitesi adı
- `completionCode` (String?) — Hizmet tamamlama kodu (4 haneli, DB tarafından oluşturulacak)
- `cancellationReason` (String?) — İptal nedeni

#### [MODIFY] [request_status.dart](file:///c:/Users/ardaa/StudioProjects/cekici/packages/shared_models/lib/request_status.dart)
Yeni durum ekleniyor:
- `awaitingAcceptance` — Seçilen çekiciler beklenirken (alarm gönderildi, henüz kabul yok)

---

### 3. Servis Katmanı (shared_services)

#### [MODIFY] [request_repository.dart](file:///c:/Users/ardaa/StudioProjects/cekici/packages/shared_services/lib/request_repository.dart)
Yeni metodlar:
- `getNearbyAvailableDrivers(lat, lng, radiusKm, vehicleType)` → Yarıçap içindeki, `is_available = true`, çevrimiçi ve araç türü uyumlu sürücüleri sıralar.
- `sendAlarmToDrivers(requestId, driverIds)` → Seçilen sürücü ID'lerine FCM push notification + DB kaydı atar.
- `acceptRequest(requestId, driverId)` → İlk kabul eden sürücüyü kilit mekanizmasıyla (DB transaction) atar, diğerlerine "iptal" bildirimi gönderir.
- `completeRequest(requestId, code)` → Müşteriden alınan 4 haneli kodu doğrulayıp hizmeti kapatır.
- `cancelRequestByCustomer(requestId, reason)` → Müşteri iptali.
- `cancelRequestByDriver(requestId, driverId)` → Sürücü iptali + iptal oranı güncelleme.

#### [NEW] [ankara_industry_zones.dart](file:///c:/Users/ardaa/StudioProjects/cekici/packages/shared_services/lib/ankara_industry_zones.dart)
Ankara'daki sanayi siteleri ve koordinatları statik listesi:
- OSTİM, İvedik OSB, Siteler, Dışkapı, Kazan OSB, Sincan OSB, Pursaklar, Ergazi Sanayi vb.

---

### 4. Müşteri Uygulaması (customer_app)

#### [MODIFY] [request_service_screen.dart](file:///c:/Users/ardaa/StudioProjects/cekici/apps/customer_app/lib/presentation/customer/request_service_screen.dart)
Mevcut 4 adımlı akış tamamen yeniden tasarlanıyor:

**Adım 1 — Konum & Araç Bilgisi:**
- Mevcut harita bileşeni korunuyor.
- Araç Türü seçimi (Sedan, SUV/Pick-up, Minibüs/Hafif Ticari, Motosiklet, Kamyon) ekleniyor.
- Araç plakası girişi.
- En az 1 araç görseli yükleme (image_picker, zorunlu).

**Adım 2 — Nereye Götüreceğiz? (Sanayi Seçimi):**
- En yakın sanayi sitesi öneri olarak üstte çıkacak.
- Tüm sanayi listesi kaydırılabilir şekilde harita üzerinde gösterilecek.
- Seçilen sanayiye göre mesafe hesaplanacak ve fiyat önizlemesi gösterilecek.

**Adım 3 — Yakın Çekiciler & Seçim:**
- 30 km içinde, uygun araç türüne sahip, hizmete hazır en fazla 5 çekici listelenecek.
- Her sürücü kartında:
  - İsim, Puan (⭐), Başarılı Çekme Sayısı
  - Konuma olan mesafesi / tahmini varış süresi
  - **Araç tipine ve mesafeye göre hesaplanan bireysel fiyat**
- Checkbox ile 1-5 arası seçim yapılabiliyor.
- "Seçilenleri Çağır" butonu ile devam.

**Adım 4 — Onay & Alarm:**
- Seçilen çekicilerin isimlerini gösteren özet ekran.
- Onaylandığında seçilen çekicilere push alarm gönderilir.
- Ekran otomatik olarak `tracking_screen`'e geçer (ilk kabul edenin bilgileri anlık yüklenecek).

#### [NEW] [driver_selection_card.dart](file:///c:/Users/ardaa/StudioProjects/cekici/apps/customer_app/lib/presentation/widgets/driver_selection_card.dart)
Her çekicinin puan, mesafe ve fiyatını gösteren seçilebilir kart bileşeni.

#### [MODIFY] [tracking_screen.dart](file:///c:/Users/ardaa/StudioProjects/cekici/apps/customer_app/lib/presentation/customer/tracking_screen.dart)
Hizmet tamamlama kodu ekranı:
- Hizmet `in_progress` durumuna geçtiğinde müşteriye **4 haneli tamamlama kodu** gösterilir (büyük, belirgin şekilde).
- Müşteri bu kodu sürücüye söyler.
- Sürücü bu kodu kendi ekranında girdiğinde hizmet kapanır.

---

### 5. Sürücü Uygulaması (driver_app)

#### [MODIFY] [driver_onboarding_screen.dart](file:///c:/Users/ardaa/StudioProjects/cekici/apps/driver_app/lib/presentation/auth/driver_onboarding_screen.dart)
- Ekipman listesinden **"Ahtapot Vinç"** seçeneği kaldırılıyor.

#### [NEW] [incoming_request_screen.dart](file:///c:/Users/ardaa/StudioProjects/cekici/apps/driver_app/lib/presentation/driver/incoming_request_screen.dart)
- Push notification alındığında (alarm) ön plana çıkan, tam ekran uyarı ekranı.
- Müşterinin konumu, araç tipi, mesafe, fiyat bilgileri gösterilir.
- **"Kabul Et"** veya **"Reddet"** butonları.
- Kabul edilirse: Diğer sürücülerin alarmı susturulur (DB transaction), sürücü yönlendirme ekranına geçer.

#### [NEW] [complete_request_screen.dart](file:///c:/Users/ardaa/StudioProjects/cekici/apps/driver_app/lib/presentation/driver/complete_request_screen.dart)
- Sürücü müşteriden aldığı 4 haneli kodu gireceği ekran.
- Kod doğrulanırsa hizmet "completed" durumuna güncellenir.

---

### 6. İptal Sistemi Tasarımı

**Müşteri İptali:**
- Sürücü henüz yoldayken (accepted durumunda): Ücretsiz iptal, sürücüye bildirim gönderilir.
- Sürücü belirlenen varış noktasına 1 km içindeyken: Uyarı mesajı ("Sürücü neredeyse geldi, iptal etmek istiyor musunuz?").
- Kabul edilen taleplerde belirli süreden sonra iptal seçeneği gizlenebilir (tartışmaya açık).

**Sürücü İptali (Kabul Sonrası):**
- İptal oranı `drivers` tablosunda `cancellation_count` ve `total_accepted_count` alanları üzerinden takip edilir.
- 5 iptalden sonra sistemden geçici uzaklaştırma uyarısı gösterilir.

---

## Verification Plan

### Automated Tests
```bash
flutter analyze   # packages/shared_services içinde
flutter analyze   # apps/customer_app içinde
flutter analyze   # apps/driver_app içinde
```

### Manuel Test Senaryoları
1. Müşteri talep açar → Araç türü seçer → Fotoğraf yükler → Sanayi seçer → Fiyat görür.
2. Müşteri 2-3 çekici seçer → Alarm gönderilir.
3. Sürücü 1 kabul eder → Sürücü 2'nin alarmı otomatik susarken sürücü 1 eşleşme ekranına geçer.
4. Sürücü varış noktasına ulaşır, hizmet verir → Tamamlama kodunu girer → Müşterinin kodu ile doğrulama yapılır.
5. Müşteri veya sürücü iptal eder → İptal oranı güncellenir.
