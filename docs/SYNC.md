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

### 2026-11-14 · 1.2 §5 Sınav geri sayımı · iOS [x] Android [x]
Kurallar `docs/V1_2_PLAN.md` §5. iOS Live Activity, Android kalıcı bildirim. Testler: plan "Test".
Metin kuralı (iOS aynısını yazsın; `ExamCountdownLine`): "YDS'ye 23 gün · bugün 12 kelime" (YDS -ye, YÖKDİL ve IELTS -e); 12 = günlük hedef. Bugünkü hedef tamamsa "bugünkü hedef tamam", listedeki her kelime öğrenildiyse "hepsini öğrendin", sınav günü "YDS bugün · …". Pro (deneme dahil) ve sınav tarihi şart; tarih yoksa öneri çıkmaz; sınav günü geçince kendiliğinden kapanır; Pro biterse kapanır.
Android: Profil › Seviye ve sınav altında "Kilit ekranında geri sayım" anahtarı (tarih varken görünür, Pro değilse paywall `examPlan`), Bugün'deki sınav planı kartında "Kilit ekranında geri sayım göster" önerisi (Pro, kapalıyken). Varsayılan kapalı. Bildirim sessiz, kalıcı, "Kapat" düğmesi ya da kaydırma anahtarı kapatır. Android 13+ bildirim izni ister. Testler: `ExamCountdownLineTest`.
iOS (metin ve kurallar aynı, fark yok): `KelimeCore/Models/ExamCountdownLine.swift` (`ExamCountdownLine.text/available/shouldRun/current(db:clock:now:)`, `ExamCountdownState`, `ExamCountdownLifetime`); ayar anahtarı `exam_countdown_on` (varsayılan kapalı). Pro denetimi `ProEntitlement.isPro(db:now:)` (deneme dahil, deneme bitince kapanır). Live Activity: `Widget/ExamCountdownActivity.swift` (kilit ekranı + Dynamic Island), yönetim `App/ExamLiveActivity.swift`; `WidgetRefresher.refresh` her değişiklikte ve uygulama öne gelince eşitler, "bugün N kelime" çalışınca güncellenir. Live Activity ömrü 8-12 saat: 7 saati dolan kapatılıp yeniden başlatılır. Kullanıcı kaydırıp kapatırsa anahtar kapanır (7 saatten önce kaybolduysa). Profil › Seviye ve sınav: "Kilit ekranında geri sayım" anahtarı (Pro değilse paywall `examPlan`), Bugün sınav planı kartında "Kilit ekranında geri sayım göster" önerisi (Pro, kapalıyken). Testler: `ExamCountdownLineTests`.

