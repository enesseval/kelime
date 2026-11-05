# Kilit Kelime · Google Play

Play Console'a kopyala-yapıştır metinler, ekran görüntüsü planı, içerik derecelendirmesi ve Veri
güvenliği cevapları, derleme adımları ve cihaz test listesi. iOS metinleri `docs/APP_STORE.md`'den
uyarlandı; Android'de olmayan şeyler (Apple ile giriş, kilit ekranı widget'ı, Apple Watch) çıkarıldı.

> Mağaza girişi oluşturmak, fiyat girmek ve yayınlamak sende. Bu dosya yalnızca hazırlık.

## 1. Derleme (AAB)

1. Android Studio'da `android/` klasörünü aç. JDK 17+, Android SDK 36.
2. `android/local.properties` (git'e girmez):
   ```
   sdk.dir=/Users/<sen>/Library/Android/sdk
   revenuecat.androidKey=goog_...
   google.webClientId=....apps.googleusercontent.com
   kelime.keystore=/Users/<sen>/keys/kilitkelime.jks
   kelime.keystorePassword=...
   kelime.keyAlias=kilitkelime
   kelime.keyPassword=...
   ```
3. Keystore'u oluştur (bir kez, güvenli yerde sakla):
   ```bash
   keytool -genkeypair -v -keystore ~/keys/kilitkelime.jks -alias kilitkelime -keyalg RSA -keysize 4096 -validity 10000
   ```
4. Testler ve paket:
   ```bash
   cd android && ./gradlew :core:test :app:bundleRelease
   ```
   AAB: `android/app/build/outputs/bundle/release/app-release.aab`.
5. Play App Signing açık kalsın. Play Console › Kurulum › Uygulama imzalama'daki **uygulama imzalama
   anahtarı SHA-256**'yı `android/assetlinks.template.json`'a yaz ve
   `https://enesseval.github.io/.well-known/assetlinks.json` olarak yayınla (liste linkleri uygulamada açılsın).

`app/build.gradle.kts` içinde `versionCode` her yüklemede artmalı. `versionName` iOS ile birlikte
değişir (ilk Android sürümü 1.1.0; bkz. `docs/SYNC.md`).

## 2. Mağaza girişi (Türkçe)

### Uygulama adı (30)
Kilit Kelime: İngilizce

### Kısa açıklama (80)
Kilit ekranında İngilizce kelime: A1–C2 kurs, YDS·YÖKDİL·IELTS, günlük bulmaca.

### Tam açıklama (4000)
Telefonuna günde onlarca kez bakıyorsun. Kilit Kelime bu bakışları İngilizce kelime öğrenmeye çeviriyor: kilit ekranında gün boyu yeni kelimeler, anlamıyla ve örnek cümlesiyle.

KİLİT EKRANINDA ÖĞREN
• Kilit ekranı duvar kâğıdına kelime: seçtiğin arka plana ya da kendi fotoğrafına yazılır, gün içinde kendiliğinden değişir; ana ekran duvar kâğıdın aynı kalır
• Kart, sözlük, örnek cümle ya da "kendini sına" görünümü; kelimenin yerini saatine göre ayarlarsın
• Ana ekran widget'ları: Kart, "Hangisi?" mini sorusu ve bulmacalı Büyük widget
• İstersen kilit ekranında sessiz bir bildirim; Hızlı Ayarlar'dan tek dokunuşla Hızlı Tekrar
• Zorlandığın kelimeler daha sık, öğrendiklerin aralıklarla geri gelir; böylece unutmazsın

A1'DEN C2'YE KURS
• 6 seviye, bölüm bölüm ilerleyen kurs; her bölümde kelimeler, kalıplar ve kısa hikâyeler
• Seviyeni bilmiyorsan 2 dakikalık testle bulursun
• Bütün kartlar Türkçe anlamı, örnek cümlesi ve telaffuzuyla

SINAVA HAZIRLAN
• YDS, YÖKDİL ve IELTS kelime listeleri, kursla birlikte kilit ekranında
• Sınav tarihini gir, Bugün ekranında geri sayımı gör

OYNAYARAK PEKİŞTİR
• Hızlı Tekrar: 2 dakikalık turlar, sınırsız
• Günün Bulmacası: bulunduğun bölümün kelimeleriyle Türkçe ipuçlu bulmaca
• Kelime Avı: Türkçesinden yola çıkıp harflerin arasında İngilizcesini bul
• Eşleştir: 60 saniyede kelimeleri anlamlarıyla eşle
• Seri ve haftalık özet; haftada bir kaçırdığın günü seri koruyucu kurtarır
• Sonuçlarını ve haftalık özetini şık kartlarla paylaş

KENDİ LİSTEN VE KEŞFET
• Kendi kelime listeni oluştur; uygulamadaki kelimelerden seç ya da kendin yaz
• Listen kilit ekranında kursla birlikte ya da tek başına döner
• Keşfet'te diğer öğrencilerin hazırladığı listelere göz at

KİLİT KELİME PRO
• Sınırsız kendi listesi; listeni linkle ya da Keşfet'te paylaşma
• Keşfet'ten hazır listeleri ekleme
• Sınav planı: sınav gününe kadar her gün kaç kelime çalışacağını gösterir
• Kilit ekranında daha sık yeni kelime
• Sana özel bulmaca ve bulmaca arşivi
• Haftada 2 seri koruyucu
Pro aylık ya da yıllık abonelikle (yıllıkta 7 gün ücretsiz deneme) veya ömür boyu tek seferlik ödemeyle alınır. Abonelikler iptal edilene kadar otomatik yenilenir; Google Play › Ödemeler ve abonelikler › Abonelikler'den istediğin zaman iptal edebilirsin.

Reklam yok. İnternetsiz çalışır. Hesap isteğe bağlı: Google ile giriş yaparsan listelerin yedeklenir, cihazların arasında (iPhone dahil) eşitlenir ve Keşfet'te paylaşabilirsin. Pro'n da hesabına bağlanır.

Koşullar: https://enesseval.github.io/kelime/kosullar.html
Gizlilik: https://enesseval.github.io/kelime/gizlilik.html

### İngilizce (en-US) giriş
- Ad: `Kilit Kelime: Vocabulary`
- Kısa açıklama: `English words on your lock screen: A1–C2 course, exam lists, daily crossword.`
- Tam açıklama: yukarıdakinin İngilizcesi.

### Kategori ve etiketler
Kategori: Eğitim. Etiketler: Dil öğrenme, Kelime, Sınav hazırlığı.

### Neler yeni (1.1.0, ilk Android sürümü)
İlk Android sürümü. Kilit ekranında İngilizce kelime öğrenmeye hoş geldin.

## 3. Grafikler

- Uygulama simgesi 512×512: `android/app/src/main/res/drawable/ic_launcher_foreground.xml`'i krem
  zeminle 512 px'e çıkar (Android Studio › Image Asset ya da `App/Assets.xcassets/AppIcon.appiconset/AppIcon.png`'yi küçült; aynı tasarım).
- Öne çıkan grafik 1024×500: krem zemin, "Telefonuna her baktığında bir kelime" (Newsreader) ve
  sağda kilit ekranı duvar kâğıdı örneği.
- Telefon ekran görüntüleri (en az 4, 1080×2400 önerilir), sırayla:
  1. Kilit ekranı duvar kâğıdı kelimesi (Kart stili) · "Telefonuna her baktığında bir kelime"
  2. Kilit ekranı kurulumu (önizleme, arka plan, konum) · "Kendi fotoğrafın, senin düzenin"
  3. Bugün · "A1'den C2'ye kurs, bölüm bölüm"
  4. Kelimelerim › Listeler · "YDS · YÖKDİL · IELTS listeleri"
  5. Oyna (Hızlı Tekrar, bulmaca, Kelime Avı, Eşleştir) · "Oynayarak pekiştir"
  5b. Seri sayfası ya da haftalık özet · "Serini koru, haftanı gör"
  6. Ana ekran widget'ları · "Ana ekranda da: Kart, Hangisi?, Büyük"
  7. Keşfet · "Hazır listeleri tek dokunuşla ekle"
- Belirli bir yenileme aralığı vaat etme ("tam 3 saatte bir" gibi); "günde 4'e kadar" de.

## 4. İçerik derecelendirmesi (IARC anketi)

| Soru | Cevap |
|---|---|
| Kategori | Referans, Haberler veya Eğitim |
| Şiddet, korku, cinsellik, küfür, uyuşturucu, kumar | Hayır |
| Kullanıcılar birbiriyle etkileşebilir mi / içerik paylaşabilir mi? | **Evet**: kullanıcılar kelime listelerini herkese açık paylaşabilir (Keşfet). Sohbet, mesaj yok. |
| Kullanıcı konumu paylaşılıyor mu? | Hayır |
| Dijital ürün satın alımı | Evet (Pro) |
| Reklam | Hayır |

Moderasyon: listeler ⋯ menüsünden şikayet edilir ve sahibi engellenebilir; 3 şikayet alan liste
otomatik gizlenir (`supabase/migrations`).

## 5. Hedef kitle ve içerik

- Hedef yaş: 13+ (çocuklara yönelik değil; "Aileler için tasarlandı" programına girme).
- Reklam içeriyor mu: Hayır.
- Uygulama erişimi: Bütün özellikler hesapsız açık. İnceleme için: Pro satın alma her zaman
  Profil › "Kilit Kelime Pro" kartından açılır ve test kartıyla denenebilir; Pro iken aynı yerde
  "ÜYELİK" › "Aboneliği yönet" Play abonelik sayfasını açar. Hesap: Profil › Google ile giriş yap.
- Hesap silme: uygulamada Profil › Hesabı sil. Web'den silme bağlantısı istenirse
  `https://enesseval.github.io/kelime/gizlilik.html#hesap-silme` (gizlilik sayfasında anlatılıyor).

### İzin beyanları
- `SET_WALLPAPER`: yalnızca kullanıcı "Kelimeyi duvar kâğıdına yaz"ı açınca, yalnızca kilit ekranı.
- `SCHEDULE_EXACT_ALARM`: kelime değişim anı için, isteğe bağlı; Play'in "alarm/saat" beyanı gerekirse:
  "Kullanıcının seçtiği kelime değişim saatlerinde kilit ekranını güncellemek."
- `POST_NOTIFICATIONS`: günlük hatırlatma ve isteğe bağlı kilit ekranı bildirimi.
- `RECEIVE_BOOT_COMPLETED`: yeniden başlatmadan sonra kelime döngüsünü kurmak.
- Fotoğraf: sistem fotoğraf seçici (izin istemez); fotoğraf cihazdan çıkmaz.

## 6. Veri güvenliği formu

Genel: Veriler aktarım sırasında şifrelenir (HTTPS). Kullanıcı hesabını ve verilerini silmeyi
isteyebilir (uygulama içinde). Uygulama çocuk politikasına tabi değil.

| Veri türü | Toplanıyor | Paylaşılıyor | Amaç | Zorunlu mu | Not |
|---|---|---|---|---|---|
| Ad (görünen ad) | Evet, hesap açılırsa | Hayır* | Hesap yönetimi, uygulama işlevi | İsteğe bağlı | Herkese açık listelerin yanında görünür |
| E-posta | Evet, hesap açılırsa | Hayır | Hesap yönetimi | İsteğe bağlı | Google girişinden; Supabase Auth'ta saklanır |
| Kullanıcı kimlikleri | Evet, hesap açılırsa | Hayır | Hesap yönetimi, uygulama işlevi | İsteğe bağlı | Supabase kullanıcı kimliği; RevenueCat kullanıcı kimliği olarak da kullanılır |
| Diğer kullanıcı içeriği | Evet, hesap açılırsa | Hayır* | Uygulama işlevi | İsteğe bağlı | Kendi kelime listeleri, şikayet ve geri bildirim metinleri |
| Satın alma geçmişi | Evet | Hayır | Uygulama işlevi | Satın alanlar için | Google Play / RevenueCat (Pro'yu açmak için) |
| Uygulama etkileşimleri | Evet | Hayır | Analiz | Hayır, anonim | TelemetryDeck: hangi özellik kullanılıyor; kimliğe bağlı değil, reklam kimliği yok |
| Fotoğraflar | **Hayır** | Hayır | — | — | Duvar kâğıdı fotoğrafı yalnızca cihazda işlenir |
| Konum, kişiler, mesajlar, sağlık, finans | Hayır | — | — | — | |

\* Kullanıcı bir listeyi "herkese açık" ya da "linke sahip olanlar" yaparsa liste ve görünen adı
diğer kullanıcılara gösterilir. Bu, kullanıcının başlattığı bir paylaşım; Play'in tanımında
"üçüncü tarafla paylaşım" sayılmaz.

Hizmet sağlayıcılar (veri işleyen): Supabase (hesap, listeler, geri bildirim), RevenueCat (satın
alma durumu), TelemetryDeck (anonim analiz), GitHub Pages (içerik güncellemesi: yalnızca dosya
indirilir, hiçbir şey gönderilmez).

Uygulamanın yaptığı ağ çağrıları yalnızca bunlar: `elqtyiuvalanlsxuawar.supabase.co`, RevenueCat,
TelemetryDeck, `enesseval.github.io/kelime/content/`.

## 7. Uygulama içi ürünler (Play Console › Para kazanma) — sen oluşturursun

- Abonelik `pro.monthly`: temel plan `monthly` (1 ay, otomatik yenilenen). Ad: "Kilit Kelime Pro, aylık"
- Abonelik `pro.yearly`: temel plan `yearly` (1 yıl), teklif `trial-7d` (7 gün ücretsiz deneme, yeni
  aboneler). Ad: "Kilit Kelime Pro, yıllık"
- Tek seferlik ürün `pro.lifetime`. Ad: "Kilit Kelime Pro, ömür boyu"
- Açıklama: "Sınırsız kendi listesi, liste paylaşma, sınav planı, daha sık yeni kelime, sana özel bulmaca ve arşiv."
- RevenueCat: Android uygulamasını ekle, Play servis hesabı anahtarını bağla, üç ürünü `pro`
  yetkisine ve `default` teklifine (monthly / annual / lifetime paketleri) ekle. iOS ile aynı yetki:
  hesapla giriş yapan kullanıcıda bir platformdaki satın alma diğerinde de açılır.

## 8. Cihaz test listesi

Her maddeyi denedikçe işaretle; sorun çıkarsa altına not düş. En az bir **Pixel** ve bir **Samsung**.
Hangi cihaz, Android sürümü, tarih: ____________________

### 0. Hazırlık
- [ ] Temiz kurulum (uygulamayı sil, dahili test kanalından kur)
- [ ] Lisans test hesabı Play Console'da ekli (satın alma testleri)
- [ ] Profil › Geliştirici › "Pro'yu aç" KAPALI (yalnızca debug derlemesinde görünür)

### 1. Tanıtım
- [ ] Giriş animasyonu: kelimeler harf harf yazılıyor, "Başla" çalışıyor
- [ ] Seviye seçimi; "Seviyemi bilmiyorum · 2 dk test" testi bitiriyor ve seviye öneriyor
- [ ] Kilit ekranı adımı: önizleme seçtiğin arka planla ve konumla değişiyor
- [ ] Onboarding üç adım; kilit ekranı adımındaki "Başla" bitiriyor, bildirim izni sorulmuyor
- [ ] İlk iyi andan sonra (Hızlı Tekrar bitişi, bulmacada bir kelime, oyun bitişi) tur ekranı kapanınca
  0,6 sn sonra "Güzel bir tur oldu" kartı açılıyor; saat 20:30; sistem izni yalnızca "Hatırlat" ile
  soruluyor; izin verilince hatırlatma o saate kuruluyor ve Profil'de görünüyor
- [ ] Kart en çok 2 kez, aralarında en az 3 gün; izin verildiyse ya da kalıcı reddedildiyse bir daha çıkmıyor

### 2. Kilit ekranı duvar kâğıdı (asıl özellik)
- [ ] "Kelimeyi duvar kâğıdına yaz" açınca kilit ekranında kelime görünüyor
- [ ] **Ana ekran duvar kâğıdı değişmiyor**
- [ ] 6 hazır arka planın her biri; metin rengi açık/koyu zeminde okunuyor
- [ ] Kendi fotoğrafın: seçici açılıyor, fotoğraf ekranı dolduruyor (kırpılıyor), metinde yumuşak gölge var
- [ ] Dikey çekilmiş bir fotoğraf ters/yan dönmüyor (EXIF; sorun varsa not et)
- [ ] Konum kaydırıcısı: üst / orta / alt; saat ve bildirimlerle çakışmıyor
- [ ] Stiller: Kart, Sözlük, Örnek cümle, Kendini sına (önceki kelimenin cevabı altta)
- [ ] Değişim zamanı ölçümü (aşağıdaki tabloya yaz): Normal (3 saat) ile en az bir gün
- [ ] "Tam zamanında değiştir" izni verilince değişim saat başına yakın oluyor
- [ ] Telefonu yeniden başlat: döngü kendiliğinden devam ediyor
- [ ] Saat dilimini değiştir: kelime yeni yerel saate göre değişiyor
- [ ] Pil tasarrufu modunda gecikme ne kadar? (not et)

| Cihaz | Slot | Beklenen | Değişti | Gecikme | Tam alarm izni |
|---|---|---|---|---|---|
| | | | | | |

Profil › Geliştirici › Widget günlüğü her duvar kâğıdı değişimini, beklenen kelimeyi ve gecikmeyi
gösterir.

### 3. Widget'lar
- [ ] Kart (küçük ve orta): kelime ve anlam; orta boyda Biliyorum/Zorlanıyorum çalışıyor
- [ ] Hangisi?: seçeneğe dokununca sonuç 1 dakika kalıyor, sonra sonraki soru geliyor
- [ ] Büyük: kelime, bugün zorlandıkların, bulmaca küçük resmi; dokununca doğru yere gidiyor
- [ ] Widget'lar duvar kâğıdıyla aynı kelimeyi gösteriyor
- [ ] Android 16 cihazda kilit ekranı/şarj hub'ına eklenebiliyor (varsa)

### 4. Bildirim ve kutucuk
- [ ] "Kilit ekranında bildirim olarak göster": sessiz, kalıcı, kelime değişince güncelleniyor
- [ ] Bildirimdeki Biliyorum/Zorlanıyorum çalışıyor
- [ ] Hızlı Ayarlar kutucuğu "Hızlı Tekrar" eklenebiliyor, altında o anki kelime; dokununca Hızlı Tekrar açılıyor
- [ ] Günlük hatırlatma seçilen saatte geliyor; o gün seri günü sayıldıysa gelmiyor
- [ ] Seri risk altındayken hatırlatma "N günlük serin bu akşam bitiyor…" diyor

### 5. Bugün, kelime, Kelimelerim
- [ ] Bugün: seri rozeti, şu anki kelime, kaynak satırı, bölüm kartı, sınav planı, hafta istatistikleri; oyun kartı yok
- [ ] Oyna: 2×2 eşit kart (Hızlı Tekrar, Günün Bulmacası, Kelime Avı, Eşleştir), altında Bulmaca arşivi ve Sana Özel Bulmaca (Pro)
- [ ] Girişliyken uygulamayı kapatıp aç: Profil sekmesinde avatar hemen görünüyor (düz kişi simgesi yanıp sönmüyor)
- [ ] Pazartesi ilk açılışta haftalık özet açılıyor (bir kez); Bugün'deki karttan yeniden açılıyor
- [ ] Özette: öğrenilen, zorlanılan, kilit ekranında gösterilen, Hızlı Tekrar doğruluğu, seri, haftanın kelimesi; Paylaş 9:16 kart veriyor
- [ ] Kelime detayı: "Dinle" İngilizce telaffuz ediyor; Paylaş üç görünümle (Açık/Koyu/Mavi) 9:16 resim paylaşıyor
- [ ] Biliyorum / Zorlanıyorum, favori, "Bu kartta hata mı var? Bildir" gönderiyor
- [ ] Kelimelerim › Kelimeler: segmentler, arama (Türkçe "ı/İ" ile), filtre, sıralama, A–Z şeridi, kaydırma
- [ ] Listeler: kurs, sınav listeleri ve kendi listeler aç/kapat; son açık kaynak kapatılamıyor
- [ ] Kendi liste: oluştur (ücretsizde 1), kelime ekle/çıkar, kendi kelimeni yaz, adını değiştir, sil

### 6. Oyunlar
- [ ] Hızlı Tekrar: seçmeli ve yazmalı sorular; klavye özel A–Z (Türkçe "İ" yok), yakın cevap ipucu
- [ ] Günün Bulmacası: yazma, silme, kesişimde yön değişimi, Harf aç / Kontrol et / Göster, süre, bitiş ekranı
- [ ] Kelime Avı: 10×10 (360 dp altı telefonda 9×9), harfler tek kartta; sürüklerken mavi şerit, bulunan kelime yeşil şerit (0,25 sn'de beliriyor), yanlışta kısa amber; doğru seçimde titreşim
- [ ] "İlk harfi göster" ilk harfin altına amber daire koyuyor; o kelime zorlanılana geçiyor; sonuç ekranında süre ve ipucu sayısı
- [ ] Eşleştir: doğru çift 0,42 sn yeşil ✓ ve biraz büyük, sonra kayboluyor; yanlış çift amber ✕, iki kez sallanıyor ve 0,65 sn sonra normale dönüyor
- [ ] Eşleştir: başlangıç metni görünüyor; 60 sn, 5 + 5 kart, hiçbir kelimenin iki yarısı aynı satırda değil; doğru çift yavaşça kayboluyor ve yeri boş kalıyor; 3 çift gidince 3 yeni kelime rastgele yerlere geliyor; yanlışta kartlar sallanıyor (amber, asla kırmızı); en iyi skor
- [ ] Sonuç kartları (bulmaca ızgarası yeşil/amber, oyun skorları, seri 7/30/100) paylaşılıyor; kartta mağaza linki yok
- [ ] Seri: Hızlı Tekrar bitince, bulmacada 1 kelime çözünce ya da oyun bitince bugün sayılıyor; widget'tan Biliyorum demek saymıyor
- [ ] Bugün'de "🔒 N gün" rozeti; bugün çalışılmadıysa amber; dokununca seri sayfası (5 hafta, koruyucu günü kesik çizgili)
- [ ] Tek gün atlayınca seri bozulmuyor (koruyucu); aynı hafta ikinci atlamada bozuluyor (Pro'da ikinci de kurtarılıyor)

### 7. Hesap, Keşfet, Pro
- [ ] Google ile giriş; profil adı ve avatar
- [ ] Liste eşitleme: iki cihazda aynı hesap, değişiklik diğerine geliyor; silme de
- [ ] iPhone'daki listeler Android'e geliyor (aynı hesap)
- [ ] Keşfet: popüler/yeni, arama, sayfalama; liste aç; Pro değilken "Listelerime ekle" paywall açıyor
- [ ] Şikayet et, kullanıcıyı engelle
- [ ] `https://enesseval.github.io/kelime/liste.html?id=…` linki uygulamada açılıyor (assetlinks yayınlandıktan sonra)
- [ ] Paywall: üç plan fiyatlarla, yasal not, Geri yükle, Koşullar, Gizlilik
- [ ] Profil: Pro değilken hesap kartının altında "Kilit Kelime Pro" kartı paywall'u açıyor; Pro iken "ÜYELİK" bölümü ve "Aboneliği yönet" Play abonelik sayfasını açıyor
- [ ] Temiz kurulum ve ilk günler: hiçbir yerde kendiliğinden paywall çıkmıyor
- [ ] 3 farklı gün çalıştıktan sonra bir tur bitip kapanınca 0,6 sn sonra "Güzel gidiyorsun" Pro ekranı
- [ ] Aynı turda bildirim kartı bekliyorsa önce o çıkıyor, Pro bir sonraki tura kalıyor
- [ ] Kapatınca 14 gün yeniden çıkmıyor; en çok 2 kez
- [ ] Kilitli özelliğe dokunup paywall gördükten sonraki 48 saat içinde teklif çıkmıyor
- [ ] Yıllık deneme ile satın al → Pro açılıyor, sıklık seçenekleri açılıyor
- [ ] iOS'ta Pro olan hesapla girince Android'de Pro açılıyor
- [ ] Hesabı sil: hesap gidiyor, listeler cihazda kalıyor
- [ ] Ücretsizde açık olanlar kilitli değil: kurs, sınav listeleri, Hızlı Tekrar, günlük bulmaca, widget'lar, duvar kâğıdı, oyunlar

### 8. Erişilebilirlik ve görünüm
- [ ] Koyu tema
- [ ] Yazı boyutu %200: ekranlar okunuyor, butonlar taşmıyor
- [ ] TalkBack: sekmeler, kelime durumu (Yeni/Zorlanılan/Öğrenildi), bulmaca hücreleri okunuyor
- [ ] 360 dp genişlikte küçük bir telefonda yatay kaydırma yok
- [ ] Soğuk açılış 1,5 sn altında (orta seviye telefon; ilk kurulumda içerik yüklemesi hariç)

### 9. İnternetsiz ve güncelleme
- [ ] Uçak modunda her şey çalışıyor (Keşfet ve giriş hariç)
- [ ] İçerik güncellemesi: yeni `contentVersion` yayınlanınca 6 saat içinde geliyor, ilerleme kayboluyor mu? (kaybolmamalı)
