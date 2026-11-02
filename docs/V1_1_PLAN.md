# Kilit Kelime 1.1.0: ortak özellik planı (iOS ve Android)

iOS 1.1.0 ve Android 1.0 (ilk sürüm) aynı özellik setiyle çıkar. Bu belge ikisinin de kaynağıdır;
davranış farkı olan yerler platform başlıklarında yazılıdır.

## 1. Seri (streak) ve haftalık özet

**Seri günü:** Yerel takvimde bir günde şu üçünden en az biri olursa o gün "çalışılmış" sayılır:
- Hızlı Tekrar turu bitirmek (10 soru, doğru sayısı fark etmez)
- Günün Bulmacası'nda en az 1 kelime çözmek
- Yeni oyunlardan (Kelime Avı, Eşleştir) birini bitirmek

Widget'a bakmak ya da widget'tan Biliyorum/Zorlanıyorum demek seriyi **saymaz**. Seri, uygulamayı
açıp bir şey yapmayı ödüllendirir; widget zaten pasif öğrenmeyi verir.

**Kurallar**
- Seri = bugün dahil arka arkaya çalışılmış gün sayısı. Bugün henüz çalışılmadıysa dünkü seri
  "risk altında" gösterilir, sıfırlanmaz; gece yarısı geçince ve dün de boşsa sıfırlanır.
- **Seri koruyucu (dondurma):** Haftada 1 adet, otomatik. Kaçırılan tek bir gün varsa ve o hafta
  koruyucu kullanılmadıysa seri bozulmaz. Pro kullanıcılara haftada 2. (Ücretsizden bir şey
  kısmıyoruz, Pro'ya ek veriyoruz.)
- En uzun seri ayrıca saklanır.
- Veri: `review_log` ve bulmaca/oyun kayıtlarından türetilir; ayrıca `streak_day(day TEXT PK,
  source TEXT)` tablosu tutulur ki hesaplama ucuz olsun.

**Gösterim**
- Bugün ekranının üstünde küçük seri rozeti: alev değil, kilit motifi ya da "🔒 12 gün".
  Tıklanınca seri sayfası: son 5 haftanın takvimi (çalışılan günler dolu daire, koruyucu ile
  kurtarılan gün kesik çizgili daire).
- Hatırlatma bildirimi zaten var; seri risk altındaysa metni değişir: "12 günlük serin bu akşam
  bitiyor. 2 dakikalık bir tur yeter."

**Haftalık özet**
- Her pazartesi ilk açılışta (ya da Bugün'deki karttan) bir özet ekranı:
  - Bu hafta öğrenilen kelime sayısı, zorlanılan sayısı
  - Widget'ın gösterdiği kelime sayısı (gösterim kayıtlarından)
  - Hızlı Tekrar doğruluk oranı
  - Seri
  - "Haftanın kelimesi": en çok zorlanıp sonunda öğrenilen kelime
- Altında **Paylaş** düğmesi: 9:16 özet kartı (bkz. madde 5).

## 2. İki yeni oyun (Oyna sekmesi)

İkisi de **kullanıcının kendi kaynaklarından** kelime alır: widget'ın da kullandığı kaynak
(kurs + açık listeler), öncelik zorlanılan kelimeler, sonra widget'ta gösterilmiş yeni
kelimeler, sonra öğrenilenlerden tekrar zamanı gelenler. Ücretsiz, günde sınırsız.

### 2a. Kelime Avı
- 8×8 (küçük ekranlarda 7×7) harf ızgarası, 6 kelime saklı: yatay, dikey ve çapraz. Ters yazım
  yok (öğrenme amaçlı).
- Liste olarak İngilizce kelimeler değil, **Türkçe anlamları** gösterilir; kullanıcı İngilizcesini
  bulur. Bulunan kelimenin anlamının yanına İngilizcesi yazılır.
- Parmakla sürükleyerek seçim. Doğru seçim yeşile döner, kısa titreşim.
- İpucu: "İlk harfi göster" (ızgarada ilk harf parlar). İpucu kullanılan kelime
  `hintUsed` sayılır → zorlanılan olur (bulmacadaki kuralla aynı).
- Bitince sonuç ekranı: süre, ipucu sayısı, kelimeler. Doğru (ipucusuz) bulunan her kelime
  `answered(correct: true)`.
- Tek harf seti: A–Z ASCII. Kalıplar ve boşluk/tire içeren kelimeler dahil edilmez; 3–8 harf.
- Üretim deterministik bir tohumla yapılır ki test edilebilsin.

### 2b. Eşleştir
- 60 saniyelik tur. Ekranda solda 5 İngilizce, sağda 5 Türkçe kart; hiçbir kelimenin iki yarısı
  aynı satırda başlamaz. Doğru çift yavaşça kaybolur, yeri boş kalır. Her tarafta 3 yer
  boşalınca sıradaki 3 kelime boş yerlere rastgele dağıtılır (yine aynı satırda eş yok).
  Yanlış eşleşmede iki kart kısa sallanır. Ayrıntı: docs/android/CHANGES.md.
- Puan: doğru eşleşme sayısı; en iyi skor saklanır.
- Yanlış eşleştirilen kelime `answered(correct: false)` → zorlanılan; doğru ilk denemede
  eşleşen `answered(correct: true)`.
- Kalıplar da girebilir (kart metni iki satıra kadar).
- Bitince sonuç ekranı ve paylaşım kartı.

## 3. Hızlı erişim (platforma göre)

### iOS
- **Kontrol Merkezi düğmesi** (iOS 18+, `ControlWidget`): "Hızlı Tekrar" düğmesi uygulamayı
  doğrudan Hızlı Tekrar'da açar. İkinci kontrol: "Bugünün kelimesi" (dokununca kelime detayı).
- **StandBy:** Mevcut small/medium widget'lar StandBy'da görünür; StandBy için büyük, okunaklı
  bir görünüm: kelime çok büyük, altında anlam. `widgetRenderingMode` / `showsWidgetContainerBackground`
  ile ayırt edilir. Kırmızı gece modunda okunur kalmalı.
- **Kilit ekranı:** zaten var.

### Android
- **Kilit ekranı duvar kâğıdı (asıl özellik):** Kullanıcı açarsa uygulama kilit ekranı duvar
  kâğıdını rotasyon diliminde değiştirir (`WallpaperManager.setBitmap(..., FLAG_LOCK)`).
  Kullanıcı kendi fotoğrafını seçer ya da hazır zeminlerden birini; kelime alt üçte birde
  şık bir kartla basılır (saatle ve bildirimlerle çakışmayacak konum, cihaz başına ayar).
- **Hızlı Ayarlar kutucuğu** (`TileService`): "Hızlı Tekrar".
- **Ana ekran widget'ları** (Glance): Kart, Hangisi? (quiz), Büyük.
- **Android 16 kilit ekranı widget'ı:** destekleyen cihazlarda aynı Glance widget'ı kilit
  ekranında da çalışır (`widgetCategory="home_screen|keyguard"`).

## 4. Paylaşılabilir sonuç kartları

Tüm paylaşım kartları 1080×1920 (9:16), uygulamanın 3 stili (Açık, Koyu, Mavi):
- **Bulmaca sonucu:** çözüm göstermeyen ızgara (yeşil = yardımsız, amber = ipucuyla), süre,
  "Günün Bulmacası · 1 Kasım".
- **Kelime Avı / Eşleştir sonucu:** skor, süre, bulunan kelime sayısı.
- **Haftalık özet:** öğrenilen sayı, seri, haftanın kelimesi.
- **Seri kilometre taşı:** 7, 30, 100 gün.
- Her kartın altında küçük logo ve "Kilit Kelime" yazısı; App Store / Play linki **yok**
  (görsel paylaşımda tıklanmaz), onun yerine "Kilit ekranında İngilizce" satırı.

## 5. Ölçüm (TelemetryDeck sinyalleri)

`streak.day`, `streak.freezeUsed`, `weekly.opened`, `weekly.shared`, `game.wordsearch.finished`,
`game.match.finished`, `share.card` (tür parametresiyle), `control.quickReview` (iOS),
`tile.quickReview` / `wallpaper.enabled` (Android).

## Kapsam dışı (1.2'ye)
Live Activity sınav geri sayımı, Cümle Kur oyunu, Apple Watch, iPad düzeni.
