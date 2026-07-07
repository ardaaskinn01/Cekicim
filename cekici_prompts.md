# 🚛 Çekici Uygulaması — 11 Prompt Planı

Aşağıdaki 11 prompt'u **sırayla** gir. Her prompt bir öncekinin üzerine inşa eder.

---

## PROMPT 1 — Proje Mimarisi & Klasör Yapısı + pubspec.yaml

```
Flutter çekici hizmet uygulaması için proje mimarisini kur. Uygulama adı "Çekici" olacak.

Şu klasör yapısını lib/ altında oluştur:

lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart         (yeşil renk paleti + dark theme)
│   │   ├── app_strings.dart        (Türkçe sabit metinler)
│   │   └── app_constants.dart      (fiyatlandırma sabitleri: MIN_PRICE=2500, PER_KM=200)
│   ├── theme/
│   │   └── app_theme.dart          (MaterialTheme, Google Fonts: Inter)
│   ├── utils/
│   │   ├── price_calculator.dart   (km bazlı fiyat hesaplama)
│   │   └── location_utils.dart     (iki nokta arası mesafe Haversine formülü)
│   └── enums/
│       ├── user_role.dart          (customer, driver, admin)
│       └── request_status.dart     (pending, accepted, in_progress, completed, cancelled)
├── data/
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── driver_model.dart
│   │   ├── service_request_model.dart
│   │   └── rating_model.dart
│   ├── repositories/
│   │   ├── auth_repository.dart
│   │   ├── request_repository.dart
│   │   └── rating_repository.dart
│   └── services/
│       ├── supabase_service.dart
│       └── location_service.dart
41: ├── presentation/
42: │   ├── auth/
43: │   │   ├── login_screen.dart
44: │   │   ├── register_screen.dart
45: │   │   ├── role_selection_screen.dart
46: │   │   ├── forgot_password_screen.dart
47: │   │   ├── verify_otp_screen.dart
48: │   │   └── reset_password_screen.dart
49: │   ├── customer/
50: │   │   ├── customer_home_screen.dart
51: │   │   ├── request_service_screen.dart
52: │   │   └── tracking_screen.dart
53: │   ├── driver/
54: │   │   ├── driver_home_screen.dart
55: │   │   ├── offer_detail_screen.dart
56: │   │   └── navigation_screen.dart
57: │   ├── admin/
58: │   │   └── admin_dashboard_screen.dart
59: │   ├── shared/
60: │   │   ├── widgets/
61: │   │   │   ├── green_button.dart
62: │   │   │   ├── app_text_field.dart
63: │   │   │   ├── rating_widget.dart
64: │   │   │   └── loading_overlay.dart
65: │   │   └── map_widget.dart
66: │   └── splash_screen.dart
67: ├── providers/
68: │   ├── auth_provider.dart
69: │   ├── location_provider.dart
70: │   ├── request_provider.dart
71: │   └── driver_provider.dart
72: └── main.dart
73: 
74: pubspec.yaml dependencies'e şunları ekle:
75: - supabase_flutter: ^2.5.0
76: - flutter_riverpod: ^2.5.1
77: - google_maps_flutter: ^2.9.0
78: - geolocator: ^13.0.1
79: - flutter_polyline_points: ^2.1.0
80: - google_fonts: ^6.2.1
81: - go_router: ^14.2.7
82: - url_launcher: ^6.3.0
83: - flutter_dotenv: ^5.1.0
84: - cached_network_image: ^3.3.1
85: - lottie: ^3.1.0
86: - shimmer: ^3.0.0
87: 
88: Her dart dosyasını oluştur (içerikleri sonraki promptlarda dolduracağız ama şimdi stub olarak bırak, sadece import ve class tanımı olsun). main.dart'ı da güncelle: ProviderScope ve GoRouter bağlantısı olsun, splash_screen.dart'a yönlendirsin.
89: 
90: Ayrıca .env dosyasını proje kök dizinine oluştur:
91: SUPABASE_URL=https://lytisoqffembcrtplfpo.supabase.co
92: SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx5dGlzb3FmZmVtYmNydHBsZnBvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI2Njk1NTcsImV4cCI6MjA5ODI0NTU1N30.6qULuPDqA9iH_p8u2h1LDFDsyPV-TzKPzqX5N78RtA8
93: 
94: assets/env klasörü oluştur, pubspec.yaml'a .env asset ekle.
95: ```
96: 
97: ---
98: 
99: ## PROMPT 2 — Renk Paleti, Tema & Sabitler
100: 
101: ```
102: Çekici uygulaması için aşağıdaki dosyaları tam olarak doldur:
103: 
104: 1. lib/core/constants/app_colors.dart:
105:    Ana renk: Koyu zeytin-yeşil (#1B5E20 primary, #2E7D32 secondary, #43A047 accent)
106:    Arka plan: #0A0F0A (çok koyu yeşil-siyah)
107:    Kart arka planı: #111811
108:    Surface: #1A231A
109:    Text primary: #E8F5E9
110:    Text secondary: #81C784
111:    Hata: #EF5350
112:    Başarı: #66BB6A
113:    Uyarı: #FFA726
114: 
115: 2. lib/core/theme/app_theme.dart:
116:    Dark theme, Google Fonts Inter kullan, Material3 etkin
117:    Card, Button, Input, AppBar, BottomNav tema ayarları
118:    Smooth elevation shadows with green tint
119: 
120: 3. lib/core/constants/app_constants.dart:
121:    - MIN_PRICE = 2500.0 (TL, ilk 1 km)
122:    - PRICE_PER_KM = 200.0 (TL/km, 1 km üzeri için)
123:    - BASE_KM = 1.0
124:    - MATCHING_RADIUS_KM = 15.0 (çekicileri bu yarıçapta ara)
125:    - OFFER_TIMEOUT_SECONDS = 120 (sürücülerin teklif süresi)
126:    - SUPPORT_PHONE = "08501234567"
127: 
128: 4. lib/core/constants/app_strings.dart:
129:    Tüm Türkçe UI metinleri (login, register, hizmet talebi, sürücü ekranları, admin vb.)
130: 
131: 5. lib/core/utils/price_calculator.dart:
132:    calculatePrice(double distanceKm) fonksiyonu:
133:    - 0–1 km arası: 2500 TL
134:    - 1 km üzeri: 2500 + (distanceKm - 1) * 200
135:    formatPrice(double price) -> "₺2.500" formatında string döner
136: 
137: 6. lib/core/utils/location_utils.dart:
138:    - distanceBetween(lat1, lon1, lat2, lon2) -> Haversine formülü, km cinsinden
139:    - formatDistance(double km) -> "1.2 km" formatında
140: 
141: 7. lib/core/enums/user_role.dart ve request_status.dart enumlarını doldur.
142: ```
143: 
144: ---
145: 
146: ## PROMPT 3 — Supabase Servisi & Auth Entegrasyonu
147: 
148: ```
149: Çekici uygulaması Supabase entegrasyonunu kur:
150: 
151: 1. lib/data/services/supabase_service.dart:
152:    - Singleton SupabaseService sınıfı
153:    - initialize() metodu: flutter_dotenv ile .env'den SUPABASE_URL ve SUPABASE_ANON_KEY oku
154:    - Oturumun cihazda sonsuz (kalıcı) kalması için Supabase otomatik token yenileme (autoRefreshToken: true) ve kalıcı oturum saklama modunu aktif et. Kullanıcı çıkış yapmadığı sürece oturum açık kalsın.
155:    - client getter: Supabase.instance.client
156:    - currentUser getter
157:    - currentUserId getter
158: 
159: 2. lib/data/models/ altındaki tüm modelleri doldur:
160: 
161:    user_model.dart (UserModel):
162:    - id, email, fullName, phone, role (UserRole), createdAt, avatarUrl
163:    - fromJson/toJson, copyWith
164: 
165:    driver_model.dart (DriverModel extends UserModel):
166:    - vehiclePlate, vehicleType, isAvailable, latitude, longitude
167:    - rating (double), totalRatings (int)
168:    - fromJson/toJson, copyWith
169: 
170:    service_request_model.dart (ServiceRequestModel):
171:    - id, customerId, driverId (nullable), 
172:    - customerLat, customerLng, customerAddress
173:    - destinationLat, destinationLng, destinationAddress
174:    - status (RequestStatus), price (double), distanceKm (double)
175:    - createdAt, acceptedAt, completedAt
176:    - customerPhone (850 numarası)
177:    - fromJson/toJson, copyWith
178: 
179:    rating_model.dart (RatingModel):
180:    - id, requestId, raterId, ratedId, score (1-5), comment, createdAt
181:    - fromJson/toJson
182: 
183: 3. main.dart'ı güncelle:
184:    - void main() async { await dotenv.load(); await SupabaseService.initialize(); runApp(ProviderScope(child: CekiciApp())); }
185: 
186: 4. lib/data/repositories/auth_repository.dart:
187:    - signInWithEmail(email, password) -> UserModel
188:    - signUpWithEmail(email, password, fullName, phone, role) -> UserModel
189:    - sendPasswordResetOTP(email) -> Supabase resetPasswordForEmail (6 haneli e-posta doğrulama kodu gönder)
190:    - verifyOTP(email, token) -> Supabase verifyOTP(type: OtpType.recovery)
191:    - updatePassword(newPassword) -> Supabase updateUser(UserAttributes(password: newPassword))
192:    - signOut()
193:    - getCurrentUser() -> UserModel?
194:    - updateUserProfile(UserModel) -> UserModel
195:    Supabase auth + profiles tablosunu kullan
196: 
197: 5. lib/providers/auth_provider.dart:
198:    Riverpod AsyncNotifier, authStateChanges stream'i dinle
199:    authStateProvider, currentUserProvider
200: ```
201: 
202: ---
203: 
204: ## PROMPT 4 — GoRouter & Auth Flow Ekranları
205: 
206: ```
207: Çekici uygulaması routing ve auth ekranlarını oluştur:
208: 
209: 1. GoRouter kurulumu (main.dart veya ayrı router.dart dosyası):
210:    Routes:
211:    - /splash -> SplashScreen
212:    - /login -> LoginScreen
213:    - /register -> RegisterScreen
214:    - /forgot-password -> ForgotPasswordScreen
215:    - /verify-otp -> VerifyOtpScreen
216:    - /reset-password -> ResetPasswordScreen
217:    - /customer -> CustomerHomeScreen (redirect if not customer)
218:    - /customer/request -> RequestServiceScreen
219:    - /customer/tracking/:requestId -> TrackingScreen
220:    - /driver -> DriverHomeScreen (redirect if not driver)
221:    - /driver/offer/:requestId -> OfferDetailScreen
222:    - /driver/navigate/:requestId -> NavigationScreen
223:    - /admin -> AdminDashboardScreen (redirect if not admin)
224:    Auth guard: Giriş yapılmamışsa /login'e yönlendir
225: 
226: 2. lib/presentation/splash_screen.dart:
227:    - Uygulama logosu (TIR simgesi + "Çekici" yazısı, koyu yeşil arka plan)
228:    - 2 sn sonra mevcut aktif oturuma göre otomatik olarak ilgili ana ekrana yönlendir (Müşteri/Sürücü/Admin)
229:    - Lottie loading animasyonu
230: 
231: 3. lib/presentation/auth/role_selection_screen.dart:
232:    - Kayıt sırasında rol seçimi ekranı
233:    - İki büyük kart: "Müşteri" ve "Çekici Sürücüsü"
234:    - Her kart için ikon + açıklama
235:    - Premium dark green tasarım
236: 
237: 4. lib/presentation/auth/register_screen.dart:
238:    - Ad Soyad, E-posta, Şifre, Telefon (850 ön ekli), Rol seçimi
239:    - Form validasyonu
240:    - AuthRepository.signUpWithEmail kullan (Doğrulama e-postası beklemeden doğrudan giriş yaptır)
241:    - Güzel animasyonlu form
242: 
243: 5. lib/presentation/auth/login_screen.dart:
244:    - E-posta + Şifre
245:    - "Giriş Yap" butonu -> role göre yönlendir
246:    - "Şifremi Unuttum?" bağlantısı -> /forgot-password ekranına yönlendir
247:    - Alt kısımda kayıt ol linki
248:    - Uygulama logosu + "Çekici" başlığı
249:    - Koyu yeşil gradient arka plan
250: 
251: 6. Uygulama İçi 6 Haneli OTP Şifre Sıfırlama Ekranları:
252:    - lib/presentation/auth/forgot_password_screen.dart: Kullanıcıdan e-posta al, "Kod Gönder" butonuna basınca Supabase üzerinden e-postaya 6 haneli OTP kodu gönder (sendPasswordResetOTP) ve /verify-otp ekranına geç.
253:    - lib/presentation/auth/verify_otp_screen.dart: E-postaya gelen 6 haneli doğrulama kodunu girmek için 6 kutucuklu OTP tasarımı. Kodu doğrula (verifyOTP), başarılıysa /reset-password ekranına geç.
254:    - lib/presentation/auth/reset_password_screen.dart: Yeni şifre ve şifre tekrarı al, updatePassword ile şifreyi güncelle ve başarı mesajıyla /login ekranına yönlendir.

Tüm auth ekranlarında:
- GreenButton widget kullan (lib/presentation/shared/widgets/green_button.dart'ı doldur)
- AppTextField widget kullan
- LoadingOverlay widget kullan
```

---

## PROMPT 5 — Konum Servisi & Harita Widget'ı

```
Çekici uygulaması için konum ve harita altyapısını kur:

1. lib/data/services/location_service.dart:
   - getCurrentLocation() -> Position
   - watchPosition() -> Stream<Position> (her 5 saniyede güncelle)
   - requestPermission() -> bool
   - getAddressFromCoordinates(lat, lng) -> String (geocoding)
   geolocator paketi kullan

2. lib/providers/location_provider.dart (Riverpod):
   - locationProvider: StateNotifier<AsyncValue<Position?>>
   - selectedLocationProvider: StateProvider<LatLng?>
   - Konum iznini başlangıçta iste
   - Arkaplan konum güncellemesi

3. lib/presentation/shared/map_widget.dart (MapWidget):
   Props: 
   - initialPosition, markers, polylines
   - onTap (konum seçimi için)
   - showMyLocation: bool
   Özellikler:
   - Google Maps dark/green temalı harita stili (JSON style ile)
   - Özel marker oluşturma: müşteri marker (kırmızı), sürücü marker (yeşil TIR ikonu), hedef marker (mavi)
   - Polyline çizimi (rota gösterimi)
   - Haritayı kamera ile otomatik konuma odakla

4. Supabase Realtime konum güncellemesi:
   lib/data/repositories/request_repository.dart içine:
   - updateDriverLocation(driverId, lat, lng) -> drivers tablosunu güncelle
   - watchDriverLocation(driverId) -> Stream<DriverModel> (Realtime subscription)
   - watchRequestStatus(requestId) -> Stream<RequestStatusModel> (Realtime)

5. Android için gerekli izinler:
   android/app/src/main/AndroidManifest.xml'e ekle:
   ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, ACCESS_BACKGROUND_LOCATION
   Google Maps API key placeholder ekle (meta-data tag)

6. lib/presentation/shared/widgets/ içindeki tüm widget'ları doldur:
   - green_button.dart: Gradient yeşil buton, splash efekti, loading state
   - app_text_field.dart: Dark themed, yeşil focus border, prefix icon destekli
   - rating_widget.dart: 1-5 yıldız, interaktif ve readonly mod
   - loading_overlay.dart: Blur + yeşil spinner
```

---

## PROMPT 6 — Müşteri Ana Ekranı & Hizmet Talebi

```
Çekici uygulaması müşteri tarafını geliştir:

1. lib/presentation/customer/customer_home_screen.dart:
   - Üst kısım: Kullanıcı selamlaması + profil avatar
   - Orta: Büyük harita (MapWidget) - mevcut konum gösterilsin
   - Alt: Bottom sheet ile "Çekici Çağır" CTA butonu
   - Aktif talep varsa: Durum kartı göster (sürücü bilgisi, tahmini süre)
   - Sağ üst: Geçmiş siparişler ikonu
   - BottomNavigationBar: Ana Sayfa, Geçmiş, Profil

2. lib/presentation/customer/request_service_screen.dart:
   - Step 1: Mevcut konum haritada seçilsin (sürüklenebilir pin)
   - Step 2: Araç bilgisi gir (marka, model, renk, plaka)
   - Step 3: Sorun tipi seç (arıza, kaza, yakıtsızlık vb. - chip selection)
   - Step 4: Fiyat tahmini göster (price_calculator kullan, km hesapla)
   - "Çekici Çağır" -> RequestRepository.createRequest()
   - Supabase'e kayıt et, status: 'pending'
   - Başarılı olursa tracking ekranına yönlendir

3. lib/providers/request_provider.dart:
   - requestNotifierProvider: AsyncNotifier
   - createRequest(ServiceRequestModel) -> String (requestId)
   - cancelRequest(requestId)
   - activeRequestProvider: stream ile aktif talebi izle

4. Eşleştirme algoritması (client-side + Supabase function):
   lib/data/repositories/request_repository.dart içine:
   - findNearbyDrivers(lat, lng, radiusKm) -> List<DriverModel>
   - Supabase'den müsait (isAvailable=true) sürücüleri çek
   - distanceBetween ile sırala (en yakın önce)
   - İlk 5 sürücüye bildirim/istek gönder (pending_offers tablosuna kayıt)
   - createRequest() sonrası otomatik çalışsın

5. Hizmet talebi durumları UI'ı:
   - pending: "Çekici aranıyor..." + animasyonlu radar efekti
   - accepted: Sürücü bilgi kartı (isim, araç, telefon, puan) + harita
   - in_progress: Canlı takip modu
   - completed: "Hizmet tamamlandı" -> Rating ekranı
   - cancelled: "İptal edildi" mesajı

Tasarım: Tüm ekranlar koyu yeşil tema, glassmorphism kartlar, smooth animasyonlar.
```

---

## PROMPT 7 — Çekici Sürücü Ekranı & Teklif Sistemi

```
Çekici uygulaması sürücü (driver) tarafını geliştir:

1. lib/presentation/driver/driver_home_screen.dart:
   - Üst: Çevrimiçi/Çevrimdışı toggle (büyük, belirgin switch)
   - Online olduğunda: Yeşil "Çevrimiçi" badge + konum paylaşımı başlar
   - Harita: Çevresindeki talepleri göster (pending request pinleri)
   - Alt: Günlük kazanç özeti kartı
   - Gelen teklif varsa: Tam ekran teklif bildirimi (120 sn countdown)
   
2. lib/presentation/driver/offer_detail_screen.dart:
   Gelen hizmet talebi detayları:
   - Müşteri konumu haritada
   - Müşteriye mesafe: "3.2 km"  
   - Tahmini kazanç: "₺2.840"
   - Araç bilgisi: Marka, model, renk, plaka
   - Sorun tipi
   - Müşteri telefon numarası (850'li, tıklanabilir -> url_launcher)
   - 120 saniyelik geri sayım progress bar
   - "Kabul Et" (yeşil) / "Reddet" (kırmızı) butonları
   - Kabul: status güncelle, navigation ekranına geç
   - Ret: pending_offers'dan sil, sıradaki sürücüye geç

3. lib/providers/driver_provider.dart:
   - driverStatusProvider: online/offline state
   - toggleOnlineStatus() -> Supabase drivers tablosunu güncelle (isAvailable)
   - pendingOffersProvider: Supabase Realtime ile gelen teklifleri dinle
   - Stream<List<ServiceRequestModel>> nearbyRequestsProvider

4. Çekici sürücüsü konum güncellemesi:
   - Online olduğunda her 5 saniyede Supabase'e konum gönder
   - location_service.dart watchPosition() kullan
   - Timer ile periyodik güncelleme

5. lib/data/repositories/request_repository.dart tamamla:
   - acceptOffer(requestId, driverId) -> Supabase transaction
     * requests tablosunda status='accepted', driver_id set et
     * drivers tablosunda current_request_id set et
     * pending_offers'daki diğer sürücüleri temizle
   - rejectOffer(requestId, driverId) 
   - completeService(requestId) -> status='completed'
   - getDriverHistory(driverId) -> List<ServiceRequestModel>

6. Sürücü kazanç istatistikleri:
   - Bugün: X hizmet, ₺Y kazanç
   - Bu hafta özeti
   - Ortalama puan gösterimi
```

---

## PROMPT 8 — Gerçek Zamanlı Takip & Navigasyon

```
Çekici uygulaması gerçek zamanlı takip ve navigasyon özelliklerini ekle:

1. lib/presentation/customer/tracking_screen.dart:
   - Tam ekran harita
   - Sürücü konumu: Gerçek zamanlı güncellenen TIR marker
   - Müşteri konumu: Sabit marker
   - İkisi arasında polyline (rota çizgisi, yeşil renk)
   - Alt bilgi paneli (bottom sheet):
     * Sürücü adı + avatar + yıldız puanı
     * "Tahmini varış: X dakika"
     * Araç: Plaka + marka model
     * Telefon butonu (850 numarası) -> url_launcher tel: scheme
     * "Talebi İptal Et" (sadece in_progress öncesi)
   - Supabase Realtime: drivers tablosunu dinle, marker güncelle
   - Sürücü geldiğinde: "Çekiciniz geldi!" banner animasyonu

2. lib/presentation/driver/navigation_screen.dart:
   - Müşteri konumuna navigasyon başlat
   - "Navigasyonu Başlat" -> Google Maps/Yandex Maps deep link aç
     url_launcher ile: 
     google.navigation:q=LAT,LNG veya yandexnavi://build_route_on_map?lat_to=LAT&lon_to=LNG
   - Haritada müşteri pin + sürücünün canlı konumu
   - Üst panel: Müşteri bilgisi + telefon
   - Alt panel:
     * "Müşteriye Ulaştım" butonu -> status='in_progress' yap
     * "Hizmeti Tamamla" butonu -> status='completed' yap (disabled until in_progress)
   - Konum sürekli Supabase'e gönderiliyor

3. Realtime subscription yönetimi:
   lib/data/repositories/request_repository.dart:
   - subscribeToRequest(requestId) -> RealtimeChannel
   - subscribeToDriverLocation(driverId) -> RealtimeChannel
   - unsubscribe() metodları
   
   lib/providers/request_provider.dart:
   - Ekran dispose edildiğinde subscription'ları kapat

4. Rota çizimi:
   - flutter_polyline_points ile Google Directions API (veya basit düz çizgi)
   - Eğer API key yoksa: İki nokta arası düz PointLatLng çizgisi kullan
   - Yeşil renk, 4px kalınlık

5. Durum geçiş animasyonları:
   - pending -> accepted: Konfeti animasyonu (lottie)
   - in_progress: Nabız atan konum noktası (animated widget)
   - completed: Başarı animasyonu (lottie checkmark)
```

---

## PROMPT 9 — Puanlama Sistemi & Geçmiş

```
Çekici uygulaması puanlama ve geçmiş özelliklerini ekle:

1. Hizmet tamamlanınca otomatik puan verme ekranı:
   lib/presentation/customer/rating_screen.dart:
   - "Hizmetiniz tamamlandı!" başlığı
   - Sürücü adı + avatar + araç
   - 1-5 yıldız seçimi (büyük, animasyonlu yıldızlar)
   - Yorum text alanı (isteğe bağlı)
   - "Puanla" butonu -> RatingRepository.submitRating()
   - "Şimdi Değil" seçeneği
   
   Sürücü için de benzer ekran: Müşteriyi puanla
   lib/presentation/driver/rate_customer_screen.dart

2. lib/data/repositories/rating_repository.dart:
   - submitRating(RatingModel) -> Supabase ratings tablosuna kayıt
   - getRatingsForUser(userId) -> List<RatingModel>
   - getAverageRating(userId) -> double
   - Puan gönderince drivers tablosunda rating ve total_ratings güncelle
     (Supabase trigger veya client-side hesaplama)

3. Geçmiş ekranı (müşteri):
   lib/presentation/customer/history_screen.dart:
   - Tamamlanan talepler listesi
   - Her kart: tarih, sürücü adı, fiyat, verilen puan
   - Shimmer loading efekti
   - RequestRepository.getCustomerHistory(customerId)

4. Geçmiş ekranı (sürücü):
   lib/presentation/driver/driver_history_screen.dart:
   - Tamamlanan hizmetler + kazanılan ücretler
   - Toplam kazanç özeti
   - Ortalama puan

5. Profil ekranları:
   lib/presentation/customer/customer_profile_screen.dart:
   - Ad soyad, e-posta, telefon düzenleme
   - Toplam hizmet sayısı istatistiği
   - Çıkış yap butonu

   lib/presentation/driver/driver_profile_screen.dart:
   - Kişisel bilgiler + araç bilgileri
   - Ortalama puan + toplam değerlendirme sayısı
   - Çalışma istatistikleri (bu ay, toplam)
   - Çıkış yap

6. RatingWidget (lib/presentation/shared/widgets/rating_widget.dart) güncelle:
   - readonly mod: Yıldızları göster ama tıklanamasın
   - interactive mod: Seçilebilir yıldızlar, animasyonlu renk değişimi
   - Yarım yıldız desteği (readonly için)
```

---

## PROMPT 10 — Admin Paneli & Bildirimler

```
Çekici uygulaması admin paneli ve bildirim sistemini ekle:

1. lib/presentation/admin/admin_dashboard_screen.dart:
   - Özet kartlar: Bugün toplam talep, aktif hizmetler, kayıtlı sürücüler, müşteriler
   - Tüm aktif hizmetlerin haritada gösterimi
   - Tab bar: Talepler | Sürücüler | Müşteriler | İstatistikler

2. Admin alt ekranlar:
   lib/presentation/admin/requests_management_screen.dart:
   - Tüm talepler listesi (filtrelenebilir: status'a göre)
   - Her talep: ID, müşteri, sürücü, fiyat, durum, tarih
   - Detay görüntüleme + manuel durum değiştirme
   - İptal edilen taleplerin nedeni

   lib/presentation/admin/drivers_management_screen.dart:
   - Kayıtlı sürücüler listesi
   - Online/offline durumu (yeşil/gri indicator)
   - Sürücü onaylama/askıya alma (is_verified alanı)
   - Detay: Puan ortalaması, toplam hizmet, araç bilgisi

   lib/presentation/admin/statistics_screen.dart:
   - Günlük/haftalık/aylık hizmet grafiği (basit bar chart - CustomPaint ile)
   - Toplam gelir (platform komisyonu hesabı %10)
   - En çok kullanılan bölgeler
   - Puan ortalamaları

3. Bildirim sistemi (in-app):
   lib/data/services/notification_service.dart:
   - showLocalNotification(title, body) - flutter_local_notifications paketi ekle pubspec'e
   - Sürücüye yeni teklif geldiğinde bildirim
   - Müşteriye kabul/red bildiriminde bildirim
   Supabase Realtime üzerinden tetikle

4. lib/presentation/admin/admin_home_screen.dart:
   - Drawer navigation ile admin modülleri
   - Koyu yeşil admin teması, daha sert ve profesyonel
   - "Sistem Durumu" widget: Supabase bağlantısı OK/hata

5. Admin auth guard:
   - GoRouter redirect: user.role != UserRole.admin ise /login'e gönder
   - Admin kaydı sadece mevcut admin invite ile (email whitelist kontrolü)

6. pubspec.yaml'a ekle:
   flutter_local_notifications: ^17.2.2
   fl_chart: ^0.69.0 (grafik için)
   
   Bu paketleri de ekle ve gerekli platform konfigürasyonlarını yap (Android notification channel).
```

---

## PROMPT 11 — Test, Hata Yönetimi & Son Dokunuşlar

```
Çekici uygulamasını production-ready hale getir:

1. Global hata yönetimi:
   lib/core/utils/error_handler.dart:
   - AppException sınıfları: NetworkException, AuthException, LocationException, DatabaseException
   - handleError(Object error) -> AppException
   - showErrorSnackbar(BuildContext, AppException) - kırmızı snackbar

2. Loading & empty states:
   Tüm liste ekranlarına ekle:
   - Shimmer loading (shimmer paketi)
   - Empty state widget: Lottie animasyonu + açıklayıcı metin
   - Error state widget: Hata mesajı + "Tekrar Dene" butonu

3. Form validasyonları gözden geçir:
   - Telefon: 10 haneli, 850 ile başlayan kontrolü
   - E-posta format kontrolü
   - Şifre: min 8 karakter, en az 1 rakam
   - Plaka: Türk plaka formatı (XX XX XXX)

4. Offline durumu yönetimi:
   lib/core/utils/connectivity_utils.dart:
   - connectivity_plus paketi ekle
   - İnternet yoksa: "Bağlantı yok" banner
   - Tekrar bağlanınca: subscription'ları yenile

5. Uygulama ikonları ve splash screen:
   - Flutter launcher icons için pubspec.yaml config ekle
   - Yeşil TIR ikonu konsepti (emoji veya SVG)
   - Native splash screen: Koyu yeşil arka plan + logo

6. Performance optimizasyonları:
   - const constructors ekle
   - ListView.builder kullan (tüm listelerde)
   - Image caching (cached_network_image)
   - Supabase subscription cleanup (dispose'da)

7. Basit unit testler:
   test/price_calculator_test.dart:
   - 0.5 km -> 2500 TL
   - 1.0 km -> 2500 TL  
   - 3.0 km -> 2900 TL (2500 + 2*200)
   - 10.0 km -> 4300 TL (2500 + 9*200)

8. README.md güncelle:
   - Proje açıklaması (Türkçe)
   - Kurulum adımları
   - .env konfigürasyonu
   - Supabase kurulumu linki
   - Google Maps API key alma talimatı
   - Rol bazlı özellikler tablosu

9. pubspec.yaml'a son paket eklemeleri:
   connectivity_plus: ^6.0.3
   flutter_launcher_icons: ^0.13.1
   flutter_native_splash: ^2.4.0

10. Genel UX iyileştirmeleri:
    - Tüm butonlara haptic feedback ekle
    - Sayfalara hero animasyonu ekle
    - SnackBar yerine özel Toast widget
    - Pull-to-refresh tüm listelerde
    - Keyboard dismiss on tap outside
```

---

## ⭐ BONUS: Supabase SQL & Auth Kurulumu

Ayrı bir mesaj olarak gönderilecek — aşağıda mevcut.
