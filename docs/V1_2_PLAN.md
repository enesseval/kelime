# Kilit Kelime 1.2.0: ortak plan (iOS ve Android)

Durum: kullanıcıyla kararlaştırıldı (2026-11-14). Kurallardaki sayılar ve metinler aynen uygulanır.
Dal: `v1.1.1` (sürüm adı 1.2.0). Build 33 sonrası düzeltmeler (seriye göre hatırlatma, "deneme"
metni, `kelime_widget_pro` yetkisi) bu sürümle mağazaya çıkar.

## Neden

- Geri bildirim (Android kullanıcısı, 2026-11-14): tasarım sade ve güzel, ama "1-2 test çözdüm,
  sonrası ücretli". Daha uzun bir deneme istiyor.
- TelemetryDeck, son 30 gün (2026-11-14):
  - iOS App Store 1.0.0: 29 yükleme, 27 onboarding, 12 widget, 11 oyun, 4 paywall gören, kişi başı
    1,9 oturum. Kayıp paywall'da değil, geri dönüşte.
  - Android 1.1.0 kapalı test: 38 yüklemenin 12'si paywall'ı 27 kez gördü (kişi başı 2,25).
    Geri bildirimle örtüşüyor.
  - Kelime Avı ve Eşleştir'i 1-2 kişi oynadı. Sınırsız ücretsiz oyunlar fark edilmiyor.
  - `paywallShown` kaynağını göndermiyor, hangi ekranın paywall açtığı bilinmiyor.
- RevenueCat: 1 aktif abonelik, 28 günde 1 dolar, aktif deneme 0.

## 1. Ölçüm (önce bu)

- `Usage.paywallShown` sinyaline `source` parametresi: tetikleyicinin adı aynen
  (`moment`, `archive`, `personalPuzzle`, `examPlan`, `lists`, `share`, `discover`, `rotation`,
  `base`, `trialEnded`). İki platform aynı değerleri gönderir.
- `Usage.purchase` sinyaline `kind`: `trial` (deneme başladı) ya da `paid`, ve `product`
  (ürün kimliği).
- Yeni sinyal `trial.started`, `trial.ended` (bölüm 2).
- Bu iş tek başına önce çıkabilecek kadar küçük. İki tarafa ilk verilecek iş bu.

## 2. Ücretsiz deneme (ters deneme)

- İlk açılıştan itibaren **3 gün** (72 saat) her şey açık; kart ya da mağaza denemesi gerekmez.
  Pro kontrolü: `isPro = satın alma || denemeSürüyor`.
- Deneme başlangıcı cihazda saklanır (iOS: Keychain, yeniden yüklemede sıfırlanmaz;
  Android: uygulama verisi). Mağazadaki "7 gün deneme" (kartlı) aynen kalır, ters deneme
  bittikten sonra alınabilir.
- Deneme sürerken paywall kendiliğinden açılmaz (`moment` yok). Profil'deki Pro satırı
  "Deneme: N gün kaldı" der.
- Deneme bitince bir kez, uygulama açılışında özet sayfası (`source: trialEnded`): bu hafta
  3 günde kullandığı Pro özellikleri, sayılarla ("Arşivden 4 bulmaca", "Sınav planın %20"), altında
  Pro'ya geç ve "Ücretsiz devam et". Kullanıcının verisi (listeler, ilerleme) silinmez;
  ikinci ve sonraki kendi listeleri salt okunur kalır.
- Deneme sonrası ücretsiz kullanıcıya: bulmaca arşivinden **haftada 2** bulmaca
  (pazartesi yenilenir).
- Mevcut ücretsiz özelliklerin hiçbiri kapanmaz.

## 3. Ücretsiz olanı görünür yapmak

- Oyna sekmesinde ücretsiz oyun kartlarında küçük "Sınırsız" etiketi.
- Günün Bulmacası bitince sonuç ekranında "Devam et" önerisi: bir sonraki ücretsiz oyun
  (sırayla Kelime Avı, Eşleştir, yeni oyunlar). Pro satırı burada öne çıkmaz.
- Android'de paywall sıklığı incelenir: iOS ile aynı kuralı mı uyguluyor (üç çalışma günü,
  iyi bir turun sonunda, onboarding'den sonra asla)? Fark varsa iOS kuralına uyulur.

## 4. İki yeni oyun (Oyna sekmesi)

Kelime kaynağı ve öncelik Kelime Avı ile aynı (V1_1_PLAN §2). Ücretsiz, sınırsız. İkisi de
`cards.json` içindeki `example_en` / `example_tr` cümlelerini kullanır; cümlesi olmayan kart
girmez.
İçerik yeterli (2026-11-14): 2271 kartın 2224'ü Cümle Kur'a (4–10 kelime), 1831'i Boşluğu
Doldur'a (kelime cümlede aynen geçiyor) uygun.

### 4a. Cümle Kur
- Üstte Türkçe cümle (`example_tr`). Altta İngilizce cümlenin kelimeleri karışık kartlar.
  Kullanıcı kartlara dokunarak sırayı kurar; dokunulan kart üstteki satıra geçer, satırdaki
  karta dokununca geri döner.
- Noktalama son kelimeye yapışık kalır; büyük harf yalnızca ilk kelimede. 4–10 kelimelik
  cümleler.
- "Kontrol et": doğruysa yeşil, sıradaki cümle. Yanlışsa yanlış yerdeki kartlar kısa sallanır,
  bir hak daha. İkinci yanlışta doğru cümle gösterilir.
- Tur 5 cümle. İlk denemede doğru → hedef kelime `answered(correct: true)`; yanlış ya da
  gösterilen → `answered(correct: false)`.
- Sonuç ekranı: doğru sayısı, süre, cümleler; paylaşım kartı.

### 4b. Boşluğu Doldur
- İngilizce cümle (`example_en`), hedef kelimenin yeri boş ("I ____ this is a good idea.").
  Altında Türkçe çevirisi küçük ve soluk. Dört seçenek: doğru kelime ve aynı tür (`pos`) ve
  seviyeden üç çeldirici.
- Cümledeki çekimli biçim kartın kelimesiyle aynı değilse (thought / think) kart bu oyuna
  girmez.
- 60 saniyelik tur, Eşleştir gibi. Doğru: yeşil, sıradaki. Yanlış: kırmızı, doğrusu yeşil
  gösterilir, 1 saniye sonra sıradaki.
- Puan: doğru sayısı, en iyi skor saklanır. Sinyal, cevap kuralları ve sonuç ekranı Eşleştir ile
  aynı.

Sinyaller: `game.sentence.finished`, `game.gapfill.finished` (`score`, `seconds`).

## 5. Sınav geri sayımı

- iOS: Live Activity, kilit ekranında ve Dynamic Island'da "YDS'ye 23 gün · bugün 12 kelime".
- Android: kalıcı bildirim (kapatılabilir), aynı metin.
- Sınav planı Pro olduğu için deneme süresince ve Pro'da çalışır.
- Sınav tarihi sınav planından gelir; tarih yoksa geri sayım önerilmez. Sınav günü geçince
  kendiliğinden kapanır.

## Kapsam dışı

- iPad düzeni: ertelendi.
- Apple Watch: askıda, kod kalır.

## Test (hata kabul edilmez)

Her bölüm şu testlerle biter; testi olmayan bölüm bitmiş sayılmaz.
- Kural testleri (KelimeCore / Android birim testleri):
  - Deneme: başlangıç, 72. saatin hemen öncesi ve sonrası, saat geri alınması, yeniden
    açılış; deneme sürerken `moment` yok; özet yalnızca bir kez.
  - Arşiv kotası: haftada 2, pazartesi yenilenir, Pro'da sınırsız.
  - Cümle Kur: karıştırılan sıra hiçbir zaman doğru sıra olmaz; noktalama ve büyük harf kuralı;
    iki hak; cevap kayıtları.
  - Boşluğu Doldur: çeldiriciler aynı `pos` ve seviyeden, hepsi farklı, doğru cevaptan farklı;
    cümlede aynen geçmeyen kart girmez; 60 saniye.
  - Uygunluk taraması: `cards.json` içindeki her kart için iki oyunun üreticisi çalıştırılır,
    hiçbiri çökmez ve boş tur üretmez.
  - Sinyaller: her paywall tetikleyicisi doğru `source` ile gider.
- Mevcut testlerin hepsi geçer; iOS'ta Debug derlemesi, Android'de `testDebugUnitTest` ve
  `lintRelease` temiz.
- Bölüm bitince kod, yazan dışında bir gözle hata için gözden geçirilir (iOS: lead
  `/code-review`; Android: kendi oturumunda inceleme) ve bulunanlar düzeltilir.
- Cihaz testi kullanıcıda: her bölümün sonunda lead kısa bir test listesi verir.

## Sıra

1. Ölçüm (§1).
2. Ters deneme ve görünürlük (§2, §3).
3. Cümle Kur, sonra Boşluğu Doldur (§4).
4. Sınav geri sayımı (§5).
