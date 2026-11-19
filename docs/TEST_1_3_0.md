# 1.3.0 test listesi

| Platform | Build | Durum |
|---|---|---|
| iOS (iPhone + iPad) | 1.3.0 (40) | Transporter'da, TestFlight'tan kurulur |
| Android | 1.3.0 (versionCode 5) | AAB hazır, Play kapalı teste yüklenecek |

Not: Keşfet'teki "aşağı çekince internet yok" düzeltmesi (19.11) bu build'lerde **yok**. Testten
sonra iOS 41 ve Android versionCode 6 ile girer. Bu testte o hatayı görürsen not etmen yeterli.

İşaretleme: `[x]` geçti, `[!]` sorun var (yanına kısa not).

---

## Ortak testler (iPhone ve Android'de ayrı ayrı)

### A · Hızlı Tekrar: şıklarda noktalama ipucu yok
- [ ] Hızlı Tekrar'ı aç, 10 soruyu çöz.
- [ ] Türkçe soru "?" ile bitiyorsa, dört İngilizce şıkkın hiçbiri tek başına "?" ile öne çıkmıyor.
      Şıkların ya hepsi aynı noktalamayla bitiyor ya da hiçbiri noktalama taşımıyor.
- [ ] Şıklarda büyük/küçük harf farkı cevabı ele vermiyor (biri büyük harfle başlayıp diğerleri
      küçük değil).
- [ ] Cümle/kalıp kartlarında (ör. "How are you?") doğru şık seçilince doğru sayılıyor.

### B · Hızlı Tekrar: her tur farklı kelimeler, farklı sıra
- [ ] Bir tur çöz, bilerek 2-3 tanesini yanlış yap. Soruları bir yere not et.
- [ ] Hemen yeni tur başlat:
  - [ ] İlk 4 soru bir önceki turdan **değil**.
  - [ ] Önceki turdan en fazla 3 kelime geliyor ve bunlar yanlış yaptıkların.
  - [ ] Doğru bildiğin kelimeler bu turda hiç çıkmıyor.
- [ ] 3-4 tur üst üste çöz: sıra her seferinde farklı, aynı kelimeler aynı sırayla dönmüyor.
- [ ] Uygulamayı tamamen kapatıp aç, yeni tur başlat: kural yine geçerli (son tur hafızası kalıyor).
- [ ] Sınav planından (geri sayım) tekrar başlat: aynı kurallar.
- [ ] Az kelimeli tek bir liste seçiliyken tur yine dolu geliyor, boş/çökme yok.

### C · Uygulamayı değerlendir / Arkadaşına öner
- [ ] Profil › Uygulama bölümünde, "Öneri gönder"in üstünde iki yeni satır: "Uygulamayı
      değerlendir" (yıldız) ve "Arkadaşına öner" (paylaş).
- [ ] "Uygulamayı değerlendir":
  - iOS: App Store'da yorum yazma sayfası açılıyor.
  - Android: Play değerlendirme penceresi açılıyor. Açılmazsa sorun değil: Play kotası pencereyi
    bazen sessizce göstermez.
- [ ] "Arkadaşına öner": paylaşım sayfası açılıyor. Metin: "Kilit ekranında her gün İngilizce
      kelime öğreniyorum: Kilit Kelime. Ücretsiz indir: <link>". Link kendi mağazasına gidiyor.
- [ ] Otomatik puanlama penceresi: 3. çalışma gününden önce, paywall görülen oturumda ya da
      %80'in altındaki bir turda **çıkmamalı**. Yeni kurulumda ilk 2 gün çıkmaması normal.
      Apple/Google pencereyi kendi takdirine göre hiç göstermeyebilir; çıkmaması hata değil.

### D · Genel duman testi (eski özellikler bozulmamış mı)
- [ ] Güncelleme üstüne kur: seri, öğrenilen kelimeler, listeler, deneme/Pro durumu yerinde.
- [ ] Kilit ekranı widget'ı yeni kelime gösteriyor, dokununca kelime detayı açılıyor.
- [ ] Günün Bulmacası açılıyor ve bitiyor.
- [ ] Dört oyun (Kelime Avı, Eşleştir, Cümle Kur, Boşluğu Doldur) birer tur bitiyor.
- [ ] Kelimelerim › Listeler: liste oluştur, kelime ekle, sil.
- [ ] Keşfet açılıyor, örnek listeler görünüyor, bir liste "Listelerime ekle" ile ekleniyor.
- [ ] Bildirim/hatırlatıcı ayarı çalışıyor.
- [ ] Profil'de "Geliştirici" bölümü **yok** (App Store build'i).
- [ ] Koyu/açık mod geçişinde bozuk ekran yok.

---

## Yalnız iPhone (iOS 40)
- [ ] Dikey kullanımda ekranlar 1.2.0 ile aynı görünüyor (iPad değişikliği iPhone'u bozmamış).
- [ ] Sekme çubuğu altta, eskisi gibi.
- [ ] Widget galerisinde tüm kilit ekranı widget'ları duruyor.

## Yalnız Android (1.3.0 (5))
- [ ] Release build açılışta çökmüyor (In-App Review için R8 kuralı eklendi).
- [ ] "Uygulamayı değerlendir"e art arda basınca çökme yok.
- [ ] Hızlı Ayarlar kutucuğu ve kilit ekranı/duvar kâğıdı eskisi gibi.

---

## iPad (iOS 40)
- [ ] Uygulama iPad'de tam ekran açılıyor (iPhone penceresi gibi küçük ve ortada değil).
- [ ] Dört yönde de dönüyor: dikey, ters dikey, iki yatay.
- [ ] Yatayda sekmeler kenar çubuğu olarak açılabiliyor; dikeyde üstte sekme çubuğu.
- [ ] Metinler ekran boyu uzamıyor: içerik ortada, okunur genişlikte (~700 pt) duruyor.
- [ ] Bugün, Kelime detayı, Hızlı Tekrar, Bulmaca, dört oyun, Profil, Paywall: yatay ve dikeyde
      taşma, üst üste binme ya da kesilen buton yok.
- [ ] Klavye açılan ekranlar (yazma sorusu, liste arama): klavye butonları kapatmıyor.
- [ ] Split View / Slide Over: yan yana açınca dar pencerede de düzgün.
- [ ] Kilit ekranı widget'ı iPad'de ekleniyor ve kelime gösteriyor.
- [ ] Satın alma/geri yükleme ekranı iPad'de açılıyor (Apple incelemesi iPad'de de bakar).

### iPad ekran görüntüleri (mağaza için, 13" iPad, 2064×2752 ya da 2752×2064)
`marketing/instagram/shots/ipad/` altına bu isimlerle:
1. `kilit-widget.png`: kilit ekranında widget
2. `bugun-yatay.png`: Bugün ekranı, yatay
3. `bulmaca.png`: Günün Bulmacası
4. `hizli-tekrar.png`: Hızlı Tekrar sorusu
5. `oyna-yatay.png`: Oyna ekranı, yatay
6. `kelime-detay.png`: Kelime detayı

---

## Testten sonra
- Hepsi geçti → "gönder" de. iOS'u App Store Connect'ten incelemeye ben gönderiyorum (yenilik
  notları tr/en-US/en-AU, iPad görselleri, build 40 ya da Keşfet düzeltmesiyle 41).
- Android AAB'sini Play kapalı teste sen yüklüyorsun.
