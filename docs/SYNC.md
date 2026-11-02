# iOS ↔ Android eşitliği

İki uygulama aynı sürüm numarasıyla, aynı davranışla ilerler. iOS ve Android ayrı Claude
oturumlarında geliştirilir; bu dosya ikisinin ortak defteridir. Kök dizindeki `CLAUDE.md` her
oturumu buraya yönlendirir.

## Her oturumun başında

1. `git fetch origin` ve çalışılan dalı güncelle: `git pull --rebase origin v1.1`.
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
- Oturum sonunda `git pull --rebase` ve ardından push. iOS kodu `App/`, `Widget/`, `Packages/`;
  Android kodu `android/`; ortak dosyalar `docs/`, `Content/`, `Fonts/`.

## Sürümler

| | iOS | Android |
|---|---|---|
| Sürüm | 1.1.0 | 1.1.0 |
| Build | 31 (TestFlight) | versionCode 1 |
| Dal | `v1.1` | `v1.1` |
| Mağazada | 1.0.0 (28) incelemede, `main` | henüz yok |

`main` App Store'daki 1.0'dır; reddedilirse düzeltme orada build 30+ ile yapılır. 1.1 işi `v1.1`
dalında sürer.

## Bilinçli farklar

- Kelime Avı küçük ızgara eşiği: iOS 380 pt altı, Android 360 dp altı 9×9 (iki platformun
  yaygın dar ekranlarına göre).
- Gösterim kaydı tablosu: iOS `shown_log`, Android `widget_shown`. Veri cihazda kalır, ad farkı
  sorun değil.
- Paywall'da "Pro ile haftada 2 seri koruyucu" iki tarafta da yazmıyor; seri sayfasında yazıyor.
- Hızlı erişim platforma göre: iOS Kontrol Merkezi + StandBy, Android Hızlı Ayarlar kutucuğu +
  kilit ekranı duvar kâğıdı.

## Değişiklik günlüğü

### 2026-11-02 · Bildirim izni ilk iyi andan sonra soruluyor · iOS [x] Android [ ]
- **Onboarding üç adım** oldu: karşılama, seviye, widget. Hatırlatma adımı kaldırıldı. Widget
  adımındaki "Sonra" ve "Ekledim" onboarding'i bitirir.
- **İyi an:** bir Hızlı Tekrar turunu bitirmek, bulmacada bir kelime çözmek ya da bir oyunu
  bitirmek. Yani seri gününün sayıldığı her yer (`recordStudy`).
- **Soru şu şartlarda sorulur:**
  - Sistem izni hiç sorulmamış (iOS `notDetermined`; Android 13+ `POST_NOTIFICATIONS`
    verilmemiş ve kalıcı reddedilmemiş).
  - Kartımız en çok 2 kez gösterilmiş ve son gösterimin üstünden en az 3 gün geçmiş.
  - Bu durumda "sorulacak" diye işaretlenir.
- **Soru tam ekran tur kapanınca gelir.** Tur ekranı (tekrar, bulmaca, oyun) kapandıktan
  0,6 sn sonra alttan bir kart açılır:
  - Zil simgesi.
  - Başlık "Güzel bir tur oldu".
  - Metin "Yarın da aynı saatte 2 dakikalık bir tur hatırlatalım mı? Günde bir bildirim,
    başka bir şey yok."
  - Saat seçici (varsayılan 20:30).
  - **Hatırlat** düğmesi: sistem izni ancak bu düğmeyle istenir. İzin gelirse hatırlatma o
    saate kurulur ve ayar kaydedilir.
  - **Şimdi değil** düğmesi.
- **Sinyal:** `reminder.ask` ile `result` = `granted` / `denied` / `later`.
- **Oyunların bitişi de iyi an sayılıyor.** Kelime Avı ve Eşleştir bitince de `recordStudy`
  çağrılıyor. Önceden çağrılmıyordu, bu yüzden oyunlar `streak.day` göndermiyordu.
- iOS dosyaları: `App/Notifications/ReminderAsk.swift`, `App/Onboarding/OnboardingView.swift`,
  `App/MainTabView.swift`, `App/AppModel.swift`.

### 2026-11-02 · Kelime Avı: 10×10 tabla, kelimeler şeritle işaretlenir · iOS [x] Android [x]
- Izgara **10×10**; dar ekranda (iOS 380 pt, Android 360 dp altı) **9×9**. Kelime uzunluğu
  3 ile (boyut − 1) harf arası, yani 9 ya da 8 harfe kadar. Kelime sayısı 6.
- Görünüm sadeleşti:
  - Harfler artık tek tek kutularda değil, tek beyaz kart üzerinde duruyor (köşe 20, ince
    çerçeve, 8'lik iç boşluk).
  - Bulunan kelime harflerin altında yuvarlak uçlu bir şeritle gösteriliyor: yeşil, %32
    opaklık, kalınlık hücrenin %80'i. Harfleri koyu yeşil ve kalın.
  - Sürüklerken seçim aynı şekilde mavi şerit (%35); yanlışta kısa süre amber.
  - İpucu, ilk harfin altında amber bir daire.
  - Şeritler 0,25 sn'de belirir.
- Android'de Canvas'ta `drawLine(cap = StrokeCap.Round)` ile aynısı yapılır.
- Android: `WordHunt.SIZE = 10`, `SMALL_SIZE = 9`, `maxLength(size) = size − 1`; sürüklenen çizgi
  iOS'taki gibi kelimeyi her iki yönde de heceliyorsa sayılır (`WordHunt.spelled`). Görünüm
  `GameScreens.kt` › `Board` (Canvas `drawLine`, `StrokeCap.Round`). Test: `GamesTest`.

### 2026-11-02 · Eşleştir: doğru ve yanlış belirgin · iOS [x] Android [x]
- **Doğru çift:**
  - İki kart da yeşil olur (zemin yeşil, 2'lik yeşil çerçeve, yazı koyu yeşil).
  - Yazının önüne ✓ gelir ve kart %5 büyür (yaylanarak).
  - **0,42 sn** öyle kalır, sonra kaybolur ve tahta güncellenir.
  - Bu sırada başka bir karta dokunulursa beklemeden güncellenir. Yeşil kartlara dokunmak hiçbir
    şey yapmaz.
- **Yanlış çift:**
  - İki kart da amber olur (zemin amber, 2'lik amber çerçeve, yazı koyu amber) ve önüne ✕
    gelir.
  - İkisi birlikte iki kez sağa sola sallanır: 7 pt, 0,4 sn.
  - 0,65 sn sonra normale döner. Hata titreşimi verilir.
- Süre dolarken bekleyen eşleşme varsa önce o sayılır.
- Android: `MatchGame.isMatch` doğru çifti oynamadan sınar; ekran 0,42 sn sonra (ya da sonraki
  dokunuşta, ya da süre bitince) `pair` ile işler. Titreşim: doğruda `Confirm`, yanlışta `Reject`.

### 2026-11-02 · Oyunlar Bugün'den çıktı, Oyna'da 4 eşit kart · iOS [x] Android [x]
- **Bugün:** Hızlı Tekrar ve Günün Bulmacası kartları kaldırıldı; Bugün'de hiçbir oyun yok.
  Kalanlar: seri rozeti, haftalık özet kartı, widget'taki kelime, kaynak satırı, bölüm kartı,
  sınav planı, hafta istatistikleri.
- **Oyna:** üstte 2×2 ızgarada dört oyun aynı boyda kart olarak durur. Her kartta 44'lük mavi
  kutuda simge, başlık (serif, 23) ve en çok iki satır alt yazı var; kartın en az yüksekliği 150.
  - Hızlı Tekrar (şimşek): zorlanılan kelime varsa "N zorlandığın kelime seni bekliyor" (amber,
    kalın), yoksa "10 kelime · 2 dakika".
  - Günün Bulmacası (küçük bulmaca ızgarası, çözülmemiş hücreler mavi): "x/y kelime çözüldü" ya
    da "Tamamlandı · yarın yenisi".
  - Kelime Avı: "Anlamından bul".
  - Eşleştir: "60 saniye", en iyi skor varsa "60 saniye · en iyi N".
- Altında tek kartta iki satır (Pro): "Bulmaca arşivi · Geçmiş günlerin bulmacaları" ve "Sana Özel
  Bulmaca · Zorlandığın ve öğrendiğin kelimelerden". Pro değilse sağda PRO rozeti, değilse ok.
- iOS: `App/MainTabView.swift` (PlayView, PlayData), `App/Today/TodayView.swift`.
- Android: `ui/play/PlayScreen.kt` (`PlayData`, `GameCard`), `ui/today/TodayScreen.kt`.

### 2026-11-02 · Profil sekmesi simgesi açılışta değişmiyor · iOS [x] Android [x]
Profil sunucudan gelene kadar sekmede düz kişi simgesi görünüp sonra avatara dönüyordu. Profil
artık cihazda da saklanıyor ve açılışta hemen o gösteriliyor. Çevrimdışıyken ya da oturum
yenilenirken saklanan profil silinmiyor; yalnızca çıkış yapınca siliniyor. Android'de sekme ya
da üst çubukta avatar varsa aynısı (DataStore'da profil).
Android: `AccountManager` profili DataStore'da (`account` / `profile`) saklar; açılışta onu
gösterir; çevrimdışı ve oturum yenilemede tutar, yalnızca çıkışta (`isSignOut`) siler.

### 2026-11-02 · Haftalık özet kutuları eşit boyda · iOS [x] Android [x]
Özetteki 2×2 istatistik kutuları aynı satırda aynı yükseklikte; uzun etiket ("kelime kilit
ekranında göründü") komşusunu kısa bırakmıyor.
Android: `WeeklyScreen` satırları `IntrinsicSize.Min`, kutular `fillMaxHeight`; etiket iOS ile
aynı: "kelime kilit ekranında göründü".

### 2026-11-02 · Sürüm numaraları eşit · iOS [x] Android [x]
Android ilk sürümü 1.0 değil **1.1.0** olarak çıkar: `versionName = "1.1.0"`, `versionCode = 1`
kalır. `docs/ANDROID_NOTES.md`, `docs/ANDROID_PLAY.md` ve planda "Android 1.0" geçen yerler
1.1.0 olur.

### 2026-11-02 · Bugün'deki hafta noktaları seri günlerini gösterir · iOS [x] Android [x]
Bugün ekranındaki 7 noktalı hafta satırı "o gün herhangi bir cevap verildi mi"yi değil, seri
gününü (`streak_day`) gösterir; seri rozetiyle çelişmesin. Koruyucuyla kurtarılan gün boş
görünür (kesik çizgi yalnızca seri sayfasında). iOS: `StatsQueries` hafta noktaları
`streak_day`'den okur. Android: `StatsQueries.week` noktaları `Streak.studiedDays`'ten okur
(`QueriesTest.weekStatsCountThisWeekOnly`).

### 2026-11-02 · Ölçüm sinyalleri iki tarafta aynı · iOS [x] Android [x]
- `streak.day` günde **bir kez**, o gün ilk sayıldığında gider; parametre `source` = `quickReview`,
  `puzzle`, `wordSearch`, `match`. Android `streak_day.source` değerinde `wordHunt` yerine
  `wordSearch` kullanır (yayımlanmadığı için veri taşıması gerekmez).
- `streak.freezeUsed`: kayıttan sonra koruyucuyla kurtarılan gün sayısı arttıysa.
- `weekly.shared`: haftalık özetteki Paylaş düğmesine basılınca.
- iOS'a eklenenler: `streak.freezeUsed`, `weekly.shared`, `control.quickReview` (Kontrol Merkezi
  düğmesi `kelime://review?from=control` açar). Android'deki `tile.quickReview` ve
  `wallpaper.enabled` bunların karşılığı.
- Not (Android): `AppModel.studied(reason, source)` `streak.day`'i `source` ile gönderir;
  `weekly.shared` haftalık özetteki Paylaş'a basılınca gider; `share.card` (`type`) paylaşım
  yapılınca. `GamesTest` `streak_day.source = 'wordSearch'` kontrol eder.

### 2026-11-02 · Seri: koruyucu takvim sırasıyla harcanır · iOS [x] Android [x]
Android'in kuralı esas alındı (Streak.kt / StreakTest). Not: iOS'ta iki fark vardı, düzeltildi.
- Günler eskiden yeniye yürünür; bir haftanın koruyucusu o haftanın **ilk** boşluğuna gider.
  Pzt çalışıldı, Salı boş, Çrş çalışıldı, Prş boş, Cuma çalışıldı → ücretsizde seri 1 (Perşembe
  bozar), Pro'da 3.
- Dün boş ve bugün henüz çalışılmadıysa dün koruyucuyla kurtarılır: seri sıfır değil, risk
  altında görünür.
- Tek boş gün kurtarılabilir; arka arkaya iki boş gün seriyi bitirir. Koruyucu her pazartesi
  yenilenir (haftada 1, Pro'da 2).
- Testler: `yesterdayMissedIsFrozenWhileTodayIsOpen`, `freezesRenewEveryMonday`,
  `oneMissedDayIsFrozenOncePerWeek` (iOS `V11Tests`), Android `StreakTest`.

### 2026-11-02 · Eşleştir: boşalan yerler üçer üçer dolar · iOS [x] Android [x]
**Hata (iOS build 29):** Eşleşen çiftin yerine hemen yeni kart geliyordu ve iki yeni kart çoğu
zaman birbirinin eşiydi. Aynı iki satıra (ör. Türkçe 2, İngilizce 4) basarak sürekli doğru
yapılabiliyordu. Android'deki "doğru çift kaybolur, yerine yenisi gelir" davranışı da bu yüzden
değişir.

**Yeni davranış:**
1. Solda 5 İngilizce, sağda 5 Türkçe yer. Başta iki sütun ayrı karıştırılır ve **hiçbir kelimenin
   iki yarısı aynı satırda olmaz**.
2. Doğru çift yavaşça kaybolur ve yerleri **boş kalır**.
3. Her tarafta **3 yer** boşalınca (`refillAt = 3`) sıradaki 3 kelime aynı anda gelir:
   İngilizceleri soldaki boş yerlere, Türkçeleri sağdaki boş yerlere rastgele. Yine hiçbir yeni
   kelimenin iki yarısı aynı satıra düşmez (en çok 20 kez yeniden karıştır).
4. Tahta tamamen boşalırsa da doldurulur. Kuyrukta boş yerden az kart varsa kalan kadar gelir.
   Kuyruk bitince doldurma olmaz; tur, tahta boşalınca ya da süre dolunca biter.
5. Eş anlamlı eşleşme (iki farklı kart, aynı Türkçe anlam): eşleşen İngilizce ve Türkçe kart
   gider. İki kartın kalan yarıları da aynı anlamı taşıdığı için birbiriyle eşleşir; ek kayıt
   gerekmez.
6. Rastgelelik tohumlu üreteçten gelir; testler deterministik olur.
7. Başlangıç ekranı metni: "İngilizce kelimeyi Türkçe anlamıyla eşleştir. Doğru çift gider; üç
   çift gidince yenileri gelir."

**Animasyon:** Eşleşen kart 0,3 sn'de kaybolur (ease-out). Yeni kart 0,25 sn bekleyip 0,45 sn'de
belirir (ease-in). Yerlerin yüksekliği sabittir (68), boş yer boş görünür. Compose:
`AnimatedVisibility`/`AnimatedContent`, anahtar karo kimliği (`cardId + "-en"` / `"-tr"`),
`fadeOut(tween(300))`, `fadeIn(tween(450, delayMillis = 250))`.

**Değişmeyen:** 60 sn tur, puan = eşleşme sayısı, yanlış çift iki kartı sallar ve İngilizce
kelimeyi bir kez zorlanılana yazar, ilk denemede eşleşen doğru sayılır, en iyi skor saklanır.

**Testler:**
- `noPairStartsOnTheSameRow`: 200 tohum, 10 kart; hiçbir satırda bir kartın iki yarısı yok.
- `matchedSlotsRefillInBatches`: 50 tohum, 30 kart, hep görünen bir çifti eşleştir. Her
  eşleşmeden sonra (son tur hariç) her tarafta 3'ten az boş yer var; yeni gelen hiçbir kart iki
  yarısıyla aynı satırda değil; tur 30 puan ve boş tahtayla biter.
- `matchGameScoresAndMisses`: önce yanlış sonra doğru; firstTry ve missed listeleri.

**iOS dosyaları:** `Packages/KelimeCore/Sources/KelimeCore/Games/MatchGame.swift`,
`App/Games/GameViews.swift` (MatchView).

**Android dosyaları:** `android/core/.../games/Games.kt` (`MatchGame`, `REFILL_AT = 3`),
`android/app/.../ui/games/GameScreens.kt` (`MatchSlot`). Testler `GamesTest`: üçü de taşındı.
