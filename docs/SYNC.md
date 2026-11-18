# iOS ↔ Android eşitliği

İki uygulama aynı sürüm numarasıyla, aynı davranışla ilerler. iOS ve Android ayrı Claude
oturumlarında geliştirilir (Mac'te lead ve iOS, Windows'ta Android); bu dosya ikisinin ortak
defteridir. Kök dizindeki `CLAUDE.md` her oturumu buraya yönlendirir. Kapanan maddeler
`docs/SYNC_ARCHIVE.md` dosyasındadır; bu dosya kısa kalsın diye yalnızca açık maddeler burada durur.

## Her oturumun başında

1. `git fetch origin` ve çalışılan dalı güncelle: `git pull --rebase origin v1.1.1`.
2. Aşağıdaki **Sürümler** tablosunu kendi platformunla karşılaştır. Fark varsa önce onu düzelt.
3. **Değişiklik günlüğü**nde kendi platformunda `[ ]` olan maddeleri sırayla uygula; bitince
   `[x]` yap ve gerekirse "Not" ekle.
4. Kullanıcıya oturum başında tek satırla durumu söyle: "Bekleyen eşitleme: N madde" ya da
   "Eşit".

## Her değişiklikte

- Kullanıcıya görünen davranış, kural, metin, sinyal ya da veri değişiyorsa: aynı commit'te
  günlüğe yeni madde ekle (en yeni en üstte). Kendi platformunu `[x]`, diğerini `[ ]` yap.
- Madde şunları yazar: ne değişti ve neden, kurallar (sayılar, süreler, metinler aynen), taşınacak
  testler, ilgili dosyalar (iki tarafta biliniyorsa ikisi).
- Ortak plan `docs/V1_1_PLAN.md` ile çelişen bir değişiklikte planı da güncelle.
- Platforma özgü iş (Kontrol Merkezi, StandBy, duvar kâğıdı, Hızlı Ayarlar…) günlüğe yalnızca
  ortak bir şeyi etkiliyorsa girer; o zaman diğer platform `—` olur.
- Sürüm numarası (`MARKETING_VERSION` / `versionName`) yalnızca iki tarafta birlikte değişir; build
  numaraları (`CURRENT_PROJECT_VERSION` / `versionCode`) bağımsızdır.
- Bir madde iki tarafta da `[x]` olunca (ya da biri `[x]`, diğeri `—`), son kutuyu işaretleyen
  oturum maddeyi olduğu gibi `docs/SYNC_ARCHIVE.md` dosyasının başına taşır.
- Oturum sonunda `git pull --rebase` ve ardından push. iOS kodu `App/`, `Widget/`, `Packages/`;
  Android kodu `android/`; ortak dosyalar `docs/`, `Content/`, `Fonts/`.

## Sürümler

| | iOS | Android |
|---|---|---|
| Sürüm | 1.3.0 | 1.3.0 |
| Build | 39 (1.3.0, iPad desteği; 36 = 1.2.0 yayında, 37 en yüksek yüklenen, 38 yüklenmedi) | versionCode 5 (1.3.0; Play'e yüklenmedi; 4 = ilk 1.3.0 AAB'si, 3 = 1.2.0 AAB) |
| Dal | `v1.1.1` | `v1.1.1` |
| Mağazada | 1.2.0 (36) yayında (16 Kasım; 1.0.0 `main` 10 Kasım) | kapalı test (Play) |

**Android üretim erişimi:** Play kapalı testinde 12 test kullanıcısı 13 Kasım 2026 itibarıyla 1
gündür kayıtlı. 12 kişi kayıtlı kalırsa 14 gün koşulu en erken **26 Kasım 2026**'da doluyor;
o gün Kontrol paneli › "Üretime başvur". Testers Community kendi panosunda 16 gün sayıyor (~28 Kasım).

`main` App Store'daki 1.0'dır; reddedilirse düzeltme orada build 30+ ile yapılır. İş `v1.1.1`
dalında sürer (14 Kasım 2026'da `v1.1`'den ayrıldı). `v1.1` ve `main`'e yalnızca kullanıcı isterse
dokunulur.

## Bilinçli farklar

- Kelime Avı küçük ızgara eşiği: iOS 380 pt altı, Android 360 dp altı 9×9 (iki platformun
  yaygın dar ekranlarına göre).
- Gösterim kaydı tablosu: iOS `shown_log`, Android `widget_shown`. Veri cihazda kalır, ad farkı
  sorun değil.
- Paywall'da "Pro ile haftada 2 seri koruyucu" iki tarafta da yazmıyor; seri sayfasında yazıyor.
- Hızlı erişim platforma göre: iOS Kontrol Merkezi + StandBy, Android Hızlı Ayarlar kutucuğu +
  kilit ekranı duvar kâğıdı.
- Android'de Profil › Geliştirici bölümü yok (kullanıcı kaldırttı, 2026-11-05); iOS'ta Debug ve
  TestFlight'ta duruyor.

## Değişiklik günlüğü

### 2026-11-18 · Uygulamayı değerlendir ve Arkadaşına öner (1.3.0)
iOS [ ] Android [ ]

Testers Community raporu ve büyüme için. Puan/yorum sayısı mağaza sıralamasını etkiler; şu an
neredeyse yok.

**Profil › Uygulama bölümü** ("Öneri gönder"in hemen üstüne iki satır):
- "Uygulamayı değerlendir" (yıldız simgesi): iOS'ta
  `https://apps.apple.com/app/id6823302964?action=write-review` açılır; Android'de Play In-App
  Review akışı, olmazsa Play mağaza sayfası.
- "Arkadaşına öner" (paylaş simgesi): sistem paylaşım sayfası, metin aynen:
  "Kilit ekranında her gün İngilizce kelime öğreniyorum: Kilit Kelime. Ücretsiz indir: <link>"
  Link: iOS `https://apps.apple.com/tr/app/id6823302964`, Android
  `https://play.google.com/store/apps/details?id=com.enesseval.kilitkelime`.

**Otomatik puanlama isteği** (iOS `requestReview`, Android In-App Review API; metin yok, sistem
penceresi):
- Yalnız iyi bir anın sonunda: Hızlı Tekrar ya da bir oyun turu biter ve doğru oranı en az %80'dir
  (Günün Bulmacası tamamlanınca da sayılır).
- En erken farklı **3. çalışma gününde** (seri günü sayısı değil, çalışılan gün sayısı).
- Aynı oturumda paywall ya da deneme özeti açıldıysa gösterilmez; onboarding'de asla.
- Kendi sınırımız: iki istek arası en az **120 gün**, toplamda en fazla 3 (Apple da yılda 3 ile
  sınırlar). Kullanıcı "Uygulamayı değerlendir" satırına dokunduysa otomatik istek bir daha sorulmaz.
- Sonuç ekranı açıldıktan ~1 sn sonra, kullanıcı bir şeye dokunmadan önce.

Sinyaller: `review.prompted` (otomatik istek gösterildi), `review.opened` (satır), `share.app`.

Testler: kural fonksiyonu için birim testleri: 2. gün hayır, 3. gün ve %80 evet, %79 hayır,
paywall aynı oturumda hayır, 119. gün hayır, 120. gün evet, 3 istekten sonra hayır, satıra
dokunduktan sonra hayır.

### 2026-11-18 · Hızlı Tekrar: her tur aynı kelimeler, aynı sırayla (1.3.0)
iOS [ ] Android [x]

Kullanıcı geri bildirimi: Hızlı Tekrar'da sürekli aynı kelimeler çıkıyor ve sıraları değişmiyor;
yeni turun ilk 3-4 sorusu bir önceki turun kelimeleri.

Neden (iOS'ta bulundu, `QuickReview.orderedCardIDs`): "zorlanılan" ve "tekrarı gelen" kelimeler
`last_answered_on` (yalnız GÜN) ile sıralanıyor. Aynı gün cevaplananların hepsi eşit, sıra her
seferinde veritabanı sırası. Turda yanlış yapılan kelime zorlanılan kalıp bir sonraki turun başına
dönüyor. Android'de aynı mantık varsa aynı hata vardır; kontrol et.

Kural (iki platform aynı):
1. Seçim önceliği aynı kalır (zorlanılan → tekrarı gelen → widget'ın gösterdiği yeni → diğer yeni →
   öğrenilmiş). Her grubun içinde eşitler (aynı gün) **karıştırılır**, sonra gün sırasına konur.
2. Son tur hafızası: biten turun 10 kart kimliği saklanır (ayarlarda, uygulama kapanınca da kalır).
   Bir sonraki turda bu kartlar **en fazla 3** tane olabilir ve **ilk 4 soruda yer almaz**. Boşalan
   yerler önceliğe göre sonraki kartlarla dolar. Önceki turdan gelecek 3 kart, o turda yanlış
   cevaplananlardan seçilir (doğru cevaplananlar bir sonraki turda hiç çıkmaz).
3. Tur seçildikten sonra 10 sorunun **sırası karıştırılır** (yukarıdaki "ilk 4'te değil" kuralı
   korunarak).
4. Havuz 10'dan küçükse (ör. tek liste, az kelime) kurallar uygulanabildiği kadar uygulanır; tur boş
   ya da 10'dan kısa kalmaz, gerekirse önceki turun kartları da girer.
5. Sınav planı turu (`deck` ile) da aynı kurallar.
6. Oyunlar (`GamePool`) bu sıralamayı kullanıyorsa 1. kural onlara da yansır; 2-3 yalnız Hızlı Tekrar.

Testler: aynı veritabanıyla art arda 5 tur: (a) hiçbir turun ilk 4 sorusu önceki turdan değil,
(b) önceki turdan en fazla 3 kart, ve bunlar önceki turda yanlış cevaplananlar, (c) aynı gün
cevaplanmış 20 zorlanılan kelimeyle iki tur aynı sırayı vermez (sabit tohumlu rng ile), (d) 6
kelimelik havuzda tur yine 6 soru üretir.

Not (Android): Kök neden aynıydı (`QuickReview.makeQuestions`: zorlanılan/tekrarı gelen/öğrenilmiş
grupları `sortedBy { gün }`, eşitler veritabanı sırasında; tur sonunda karıştırma yok). Düzeltme
`QuickReview.orderedIds` (eşitler karıştırılıp sonra gün sırası) + `pickRound` (son turdan en fazla 3
yanlış cevaplı kart, ilk 4'te yok, sonra sıra karıştırılır, küçük havuzda önceki turun kartları
doldurur). Son tur ayarlarda: `review_last_round`, `review_last_wrong`; ekran turu
`QuickReview.start` ile açar, her cevapta `noteAnswer` çağırır. Oyunlar (`GameWords.pick`) bu
sıralamayı kullanmıyor, değişmedi. Testler: `QuickReviewRotationTest` (a, b, c, d + hafıza).

### 2026-11-17 · iPad desteği (1.3.0, yalnız iOS)
iOS [x] Android —

iOS uygulaması ve widget uzantısı evrensel oldu (`TARGETED_DEVICE_FAMILY = 1,2`; Watch aynı).
Dört iPad yönü ve Split View / Slide Over açık (`UIRequiresFullScreen` yok). Sekme çubuğu
iPadOS 18'de kenar çubuğuna açılabilir (`.sidebarAdaptable`), iOS 17'de düz sekmeler. İçerik
sütunları 700 pt (onboarding 600, oyunlar 640-700) ile ortalanır (`readableWidth`,
`ReadableScrollView`); bulmaca hücreleri geniş ekranda 40 yerine 62 pt. Davranış, kural ve metin
değişmedi; iPhone aynı. Android tablet düzeni ayrı bir iş, bu madde onu gerektirmez.
Dosyalar: `Config/Shared.xcconfig`, `Config/App-Info.plist`, `App/Components/Components.swift`,
`App/MainTabView.swift` ve ekran dosyaları.
