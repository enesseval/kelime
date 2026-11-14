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
| Sürüm | 1.1.0 (sıradaki 1.2.0) | 1.1.0 (sıradaki 1.2.0) |
| Build | 33 (App Store'a gönderilecek) | versionCode 2 (Play dahili testte; kapalı test incelemeye hazır) |
| Dal | `v1.1.1` | `v1.1.1` |
| Mağazada | 1.0.0 (28) yayında (10 Kasım), `main` | kapalı test (Play) |

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

### 2026-11-14 · 1.2 §5 Sınav geri sayımı · iOS [ ] Android [ ]
Kurallar `docs/V1_2_PLAN.md` §5. iOS Live Activity, Android kalıcı bildirim. Testler: plan "Test".

### 2026-11-14 · 1.2 §4 Cümle Kur ve Boşluğu Doldur · iOS [ ] Android [ ]
Kurallar `docs/V1_2_PLAN.md` §4. Sinyaller `game.sentence.finished`, `game.gapfill.finished`.
Testler: plan "Test" (uygunluk taraması dahil).

### 2026-11-14 · 1.2 §2–§3 Ters deneme (3 gün), arşivde haftada 2, ücretsiz oyunlar görünür · iOS [ ] Android [x]
Kurallar `docs/V1_2_PLAN.md` §2 ve §3. Testler: plan "Test".
Android'de uygulanan ayrıntılar (iOS aynısını yapsın):
- Deneme: ilk açılışta başlar (uygulama güncelleyen mevcut kullanıcılar da ilk 1.2 açılışında 3 gün alır), 72 saat. En son görülen zaman saklanır, saat geri alınınca süre uzamaz. `isPro = satın alma || deneme`; ayrı `PURCHASED` kaydı. Paywall yalnızca satın almayla kapanır, deneme sırasında Profil'den açılabilir. İlerleme sıfırlaması denemeyi ve satın almayı silmez.
- `trial.started` ilk açılışta, `trial.ended` bitiş ilk fark edildiğinde (bir kez). Özet sayfası bitişten sonra bir kez, uygulama açıkken başka tam ekran sayfa yokken (`source: trialEnded`); satın alan görmez.
- Özet satırları (sıfırlar yazılmaz): "Arşivden N bulmaca", "Sana özel N bulmaca", "N kendi listen" (1'den çoksa), "Sınav planın %X" (sınav listesinde öğrenilen kelime oranı).
- Arşiv (ücretsiz): haftada 2 hak, pazartesi yenilenir. Bir bulmacayı açmak hakkı harcar; bu hafta açılmış ya da daha önce oynanmış (çözülmüş kelimesi olan) bulmaca hak harcamadan açılır. Hak bitince arşiv satırı `archive` paywall'ı açar. Arşiv satırı herkes için açık, alt yazı "Haftada 2 bulmaca · bu hafta N hakkın var".
- Kendi listeleri: ücretsizde ikinci ve sonraki liste salt okunur (kelime ekle/çıkar, ad değiştirme kapalı; "Pro ile düzenle"); silme açık, hiçbir şey silinmez. İçe aktarılan listeler etkilenmez.
- "Sınırsız" etiketi: Hızlı Tekrar, Kelime Avı, Eşleştir kartlarında; Günün Bulmacası'nda yok (günde bir tane, sınırsız değil).
- Bulmaca sonu: yalnızca Günün Bulmacası'nda "Devam et: <oyun>"; sıra Kelime Avı, Eşleştir, (yeni oyunlar); o gün oynanmamış ilk oyun önerilir, hepsi oynandıysa ilki.
- Paywall sıklığı incelemesi: Android'in `moment` kuralı iOS ile aynı (3 çalışma günü, en çok 2 teklif, 14 gün arayla, herhangi bir paywall'dan sonra 48 saat sessizlik, tur bitince, onboarding'de hiç). Fark yok. 27 gösterim kilitli satırlara dokunuştan geliyor (Oyna'da arşiv ve Sana Özel, Bugün'de sınav planı, Profil kartı, liste/paylaş/döndürme); artık arşivde kilit yok, deneme sırasında hiçbiri açılmaz.
- Testler: `FreeTrialTest` (deneme, saat geri alma, özet bir kez, kota, salt okunur liste, sıradaki oyun).

### 2026-11-14 · 1.2 §1 Ölçüm: paywall `source`, satın alma `kind` / `product` · iOS [ ] Android [x]
Kurallar `docs/V1_2_PLAN.md` §1. Değerler iki platformda aynı yazılır.
Android: `PaywallSignals` (core), `trialEnded` tetikleyicisi enum'da hazır; `kind` RevenueCat `periodType == TRIAL`'dan, `product` Play taban plan ekisiz (`pro.yearly`). Test: `PaywallSignalsTest`.

<!-- Yeni maddeler buraya, en yeni en üstte. Kapananlar docs/SYNC_ARCHIVE.md dosyasının başına taşınır. -->
