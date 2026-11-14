# iOS ↔ Android eşitliği: arşiv

İki platformda da `[x]` olan, yani kapanmış maddeler. En yeni en üstte. `docs/SYNC.md` yalnızca
açık maddeleri tutar; bir kuralın ayrıntısı (sayılar, metinler, taşınan testler) gerektiğinde burada
tarihle ya da başlıkla ara. Kod yorumlarındaki `docs/SYNC.md <tarih>` atıfları buradaki maddelerdir.

### 2026-11-14 · 1.2 cihaz testi: deneme özeti, Cümle Kur düzeni, Boşluğu Doldur animasyonu · iOS [x] Android [x]

Kullanıcının TestFlight 1.2.0 (34) testinden üç düzeltme. Üçü de görsel; kurallar, sinyaller ve
cevap kayıtları değişmez.

**A. Deneme bitti özeti daha zengin.** Şu an tek satır ("2 kendi listen") ve boş bir sayfa.
- Üstte uygulamanın vurgu renginde büyük bir simge (mühür/yıldız), "DENEME BİTTİ" etiketi ve
  "3 günde şunları denedin" başlığı kalır.
- Altında 2 sütunlu sayı kutuları (her kutu: büyük sayı + kısa etiket, kart zemini, yuvarlak köşe).
  Sırasıyla, değeri 0 olan kutu gösterilmez:
  "Çalışılan kelime", "Gün seri", "Arşivden bulmaca", "Sana Özel Bulmaca", "Kendi listen",
  "Sınav planı %N". En az ilk iki kutu her zaman var (0 olsa da), sayfa hiç boş kalmaz.
- Ardından iki küçük bölüm, her satır onay ya da kilit simgeli:
  - "Ücretsiz devam eden": "Kilit ekranı widget'ı", "Günün Bulmacası", "Sınırsız oyunlar",
    "Arşivden haftada 2 bulmaca", "İlk listen".
  - "Pro ile açılan": "Bulmaca arşivi sınırsız", "Sana Özel Bulmaca", "Sınav planı ve geri sayım",
    "Sınırsız liste".
- En altta "Verilerin yerinde, hiçbir şey silinmedi." notu küçük ve soluk.
- İçerik kaydırılabilir; "Pro'ya geç" ve "Ücretsiz devam et" altta sabit kalır.
- Açılışta kutular kısa bir gecikmeyle sırayla belirir (0,05 sn arayla, sistemde hareketi azalt
  açıksa animasyonsuz).

**B. Cümle Kur düzeni.**
- Hata: alttaki kartlar ikinci satıra taşınca "Kontrol et" düğmesi kartların üstüne biniyor.
  Düğme ekranın altına sabitlenir (güvenli alanın üstünde), kartlar hiçbir zaman altında kalmaz.
- Alttaki havuzda bir kart yukarı gidince yerindeki boşluk kalır: aynı boyutta, kesikli çizgili
  (1 pt, soluk) boş bir yer tutucu. Diğer kartlar kaymaz. Kart geri dönünce kendi yerine oturur.
- Üstteki cevap satırı eskisi gibi soldan dolar (orada kayma doğal).

**C. Boşluğu Doldur animasyonu.**
- Seçenek seçilince kelime boşluğa harf harf yazılır (daktilo, toplam en fazla 0,4 sn, harf başı
  eşit süre), sonra renk geri bildirimi (doğru yeşil / yanlış amber, doğrusu yeşil) gelir ve 1 sn
  sonra sıradaki soru. Yanlışta boşlukta seçilen kelime amber kalır, doğru seçenek yeşil yanar.
- Yazılırken seçenekler kilitli (çift dokunma yok). 60 sn sayaç yazılma sırasında da işler.
- Hareketi azalt açıksa kelime tek seferde, solarak gelir.

Testler: mevcut testler geçer; Boşluğu Doldur'da cevap kaydı yazılma bitmeden alınır, oyundan
çıkılırsa cevap kaybolmaz.

iOS: sayılar `TrialSummary.tiles` (KelimeCore, test `summaryTilesHideZerosExceptFirstTwo`); "Çalışılan kelime" = `review_log`
içinde farklı kart sayısı, "Gün seri" = güncel seri. Dosyalar: `App/Store/TrialSummaryView.swift`, `App/Games/SentenceGameViews.swift`,
`App/AppModel.swift`. Boşluğu Doldur'da doğru cevap sonrası sıradaki soru 350 ms, yanlışta 1 sn (eskisi gibi).


### 2026-11-14 · 1.2 §4 inceleme düzeltmeleri · iOS [x] Android [x]
iOS'un §4 kod incelemesinden; Android'de de kontrol edildi, hepsi test edildi (`SentenceGamesTest`, `FreeTrialTest`):
- Tur ortasında kapatma: Android'de kapatınca kayıt zaten yoktu (kayıt yalnız turun gerçek bitişinde). Eklenen kural: hiç cevap yoksa (süre dolsa bile) çalışma, oyun sonucu, seri günü ve sinyal kaydedilmez (Eşleştir, Boşluğu Doldur, Cümle Kur). Süre sayacı yalnız 60 sn gerçekten dolunca bitirir.
- Cümle Kur ilk kelime: yalnızca kelimenin geri kalanında büyük harf yoksa ilk harf küçülür (`TV`, `DNA`, `McDonald's` olduğu gibi kalır; `I`, `I'm` zaten kalıyordu).
- Aynı örnek cümleyi paylaşan iki kart aynı Cümle Kur turuna girmez (küçük harfe çevrilmiş cümleye göre).
- "Yeni rekor!" yalnızca skor > en iyi (eşitlikte yok; Eşleştir dahil, Android'de `>=` idi, düzeltildi).
- Göç: 1.1'den gelen kullanıcıda `PURCHASED` yoksa eski Pro önbelleğinden dolar; ağ gerekmez (Android'de zaten öyleydi, çıkarılıp test edildi).
- Deneme bitince kilit ekranı kuyruğu: Android'de kurulmuyordu (yalnız tercihler okunuyordu); düzeltildi: deneme bitiş slotunda Pro önbelleği temizlenir, gelecek kuyruk silinip yeniden kurulur, uygulama bayrakları (`trial.ended`, özet) arkadan yetişir.

### 2026-11-14 · 1.2 §5 Sınav geri sayımı · iOS [x] Android [x]
Kurallar `docs/V1_2_PLAN.md` §5. iOS Live Activity, Android kalıcı bildirim. Testler: plan "Test".
Metin kuralı (iOS aynısını yazsın; `ExamCountdownLine`): "YDS'ye 23 gün · bugün 12 kelime" (YDS -ye, YÖKDİL ve IELTS -e); 12 = günlük hedef. Bugünkü hedef tamamsa "bugünkü hedef tamam", listedeki her kelime öğrenildiyse "hepsini öğrendin", sınav günü "YDS bugün · …". Pro (deneme dahil) ve sınav tarihi şart; tarih yoksa öneri çıkmaz; sınav günü geçince kendiliğinden kapanır; Pro biterse kapanır.
Android: Profil › Seviye ve sınav altında "Kilit ekranında geri sayım" anahtarı (tarih varken görünür, Pro değilse paywall `examPlan`), Bugün'deki sınav planı kartında "Kilit ekranında geri sayım göster" önerisi (Pro, kapalıyken). Varsayılan kapalı. Bildirim sessiz, kalıcı, "Kapat" düğmesi ya da kaydırma anahtarı kapatır. Android 13+ bildirim izni ister. Testler: `ExamCountdownLineTest`.
iOS (metin ve kurallar aynı, fark yok): `KelimeCore/Models/ExamCountdownLine.swift` (`ExamCountdownLine.text/available/shouldRun/current(db:clock:now:)`, `ExamCountdownState`, `ExamCountdownLifetime`); ayar anahtarı `exam_countdown_on` (varsayılan kapalı). Pro denetimi `ProEntitlement.isPro(db:now:)` (deneme dahil, deneme bitince kapanır). Live Activity: `Widget/ExamCountdownActivity.swift` (kilit ekranı + Dynamic Island), yönetim `App/ExamLiveActivity.swift`; `WidgetRefresher.refresh` her değişiklikte ve uygulama öne gelince eşitler, "bugün N kelime" çalışınca güncellenir. Live Activity ömrü 8-12 saat: 7 saati dolan kapatılıp yeniden başlatılır. Kullanıcı kaydırıp kapatırsa anahtar kapanır (7 saatten önce kaybolduysa). Profil › Seviye ve sınav: "Kilit ekranında geri sayım" anahtarı (Pro değilse paywall `examPlan`), Bugün sınav planı kartında "Kilit ekranında geri sayım göster" önerisi (Pro, kapalıyken). Testler: `ExamCountdownLineTests`.

### 2026-11-14 · 1.2 §4 düzeltme: Cümle Kur büyük harf · iOS [x] Android [x]
Kartlarda her kelime cümledeki yazımıyla gösterilir (I, I'm, I'll, özel isimler, ikinci cümlenin
başı büyük kalır). Yalnızca cümlenin ilk kelimesi küçük harfe çevrilir, çünkü büyük ilk harf
cevabı ele verir; ilk kelime "I" ya da "I'" ile başlayan bir kısaltmaysa o da olduğu gibi
kalır. Neden: `cards.json`'da 228 cümlede ilk kelimeden sonra büyük harf var, 287 cümle "I"
ile başlıyor; hepsini küçültmek "can i ask you" gibi yanlış yazım gösteriyordu.
Test: "Can I ask you something?" → kartlar "can", "I", "ask", "you", "something?";
"I think this is a good idea." → "I" büyük kalır; "Try this cake. It's very good." → "It's"
büyük kalır.
Android: kural zaten böyleydi (yalnız ilk kelime küçülür), üç örnek test olarak eklendi (`SentenceGamesTest`).
Android'de ilgili üç kontrol (iOS incelemesinden):
- Salt okunur liste açığı: seçilen yol "dosya olarak gönder" kapalı. Ücretsizde dışa aktarma zaten Pro; `UserLists.canExport` salt okunur listeyi Pro olmadan vermez, menü `share` paywall'ını açar. Kalan boşluk: deneme sırasında dışa aktarılan liste, deneme bitince içe aktarılırsa `imported` olarak düzenlenebilir gelir (içe aktarılan listeler tasarım gereği sınır dışı); bunu kapatmak için dosyanın kaynağını tanımak gerekir, yapılmadı.
- Deneme bitince uygulama hiç açılmazsa: Android'de de kalıyordu. Düzeltildi: `Preferences.load` önbellekteki Pro'yu deneme bitişine göre kendisi süzer (`FreeTrial.lapsed`, saat geri alınmasına karşı son görülen zamanı da kullanır), böylece widget ve kilit ekranı Pro hızı/temasını bırakır; bitiş anı ayrı bir slot olarak zamanlanır. Sınav bildirimi de aynı süzgeci okur.
- Satın alan, çevrimdışı, RevenueCat okunamıyor, deneme bitmiş: Android'de Pro kaybolmuyor. `PURCHASED` kaydı veritabanında kalır, RevenueCat hata verirse hiçbir şey değişmez; özet satın alana gösterilmez. Test eklendi.
Testler: `FreeTrialTest` (lapsed, offline satın alma, dışa aktarma).

### 2026-11-14 · 1.2 inceleme düzeltmeleri (§1–§3) · iOS [x] Android [x]
Android kendi düzeltmelerini e910748'de yaptı; iOS karşılığı:
- Deneme bitişi önbelleğe yazılır (`trial_end`), `is_pro` yalnızca satın alma/geliştirici anahtarıdır; widget, tercihler, seri hakları ve liste kuralları `ProEntitlement.isPro(db:now:)` ile "satın alma || şimdi < deneme bitişi" hesaplar. Uygulama hiç açılmasa da 72. saatte Pro biter. `Preferences.save` denemeyi kalıcı Pro'ya çevirmez.
- Son bilinen satın alma saklanır (`is_purchased`); çevrimdışı açılışta ya da RevenueCat okunamazsa alıcı Pro'sunu ve özetsizliğini korur.
- Satın alma `kind`: yetki yoksa abonelik `periodType`'ına, sonra ücretsiz deneme tanıtım teklifine bakılır.
- Deneme Keychain'e her `refresh`te yazılmaz: bellekte tutulur, bayrak değişince ya da `lastSeen` 1 saatten fazla ilerleyince yazılır.
- "Dosya olarak gönder": `UserLists.canExport` (Pro ve salt okunur değil); içe aktarılan liste salt okunur yapılmadı (Android ile aynı; deneme sırasında dışa aktarma boşluğu ikisinde de açık).
- "Devam et" yarım saniye sonra sayfa (deneme özeti) açıksa oyunu açmaz, öneriyi bırakır. Deneme özeti `await`ten sonra yeniden denetlenir, ancak gerçekten sunulurken işaretlenir.
Testler: `ReviewFixTests`. Dosyalar: `Models/ProEntitlement.swift`, `ReverseTrial.swift`, `Preferences.swift`, `UserLists.swift`, `App/Store/PurchaseManager.swift`, `App/AppModel.swift`, `App/Puzzle/CrosswordView.swift`.

### 2026-11-14 · 1.2 §4 Cümle Kur ve Boşluğu Doldur · iOS [x] Android [x]
Kurallar `docs/V1_2_PLAN.md` §4. Sinyaller `game.sentence.finished`, `game.gapfill.finished`.
Testler: plan "Test" (uygunluk taraması dahil).
Android'de plana eklenen ayrıntılar (iOS aynısını yapsın):
- Adlar: `streak.day` kaynağı `sentence` / `gapFill`; öğrenme kaydı (`review_log.source`) `sentence` / `gapFill`; oyun kaydı `game_result.game` `sentence` / `gapFill`. Sinyallerin parametreleri `score` ve `seconds` (Boşluğu Doldur'da `seconds` 60'a kadar geçen süre).
- Cümle Kur kelimeleri: İngilizce cümle boşlukla bölünür (4–10 kelime, Türkçe çevirisi var, en az iki farklı kelime). Noktalama bulunduğu kelimede kalır; yalnızca ilk kelimenin baş harfi küçültülür (`I`, `I'm`, kısaltmalar kalır), satırda 1. yerdeki kart büyük harfle gösterilir. Karıştırma doğru sırayı vermez (metne göre karşılaştırılır; aynı kelimeden ikisi varsa yer değiştirmeleri hata sayılmaz). Doğruluk metne göre: aynı iki kelime birbirinin yerine geçebilir.
- Yanlış kontrolde yanlış yerdeki kartlar sallanır ve yerinde kalır, ikinci yanlışta doğru cümle "Doğrusu" olarak gösterilir. İkinci denemede doğru yapmak da `answered(correct: false)` sayılır (ilk denemede doğru değil). Kayıt tur sonunda.
- Boşluğu Doldur: kelime cümlede aynen (büyük/küçük harf fark etmez, harfle komşu olmadan, kesme işaretinden önce/sonra değil: `can't` içinde `can` sayılmaz) geçmeli; her geçtiği yer boşaltılır. Çeldirici: aynı `pos` ve seviyeden, kullanıcı kartı olmayan, cümlede görünmeyen, hepsi farklı üç kelime; üçü bulunamazsa kart girmez. Doğru: 0,35 sn yeşil, yanlış: seçilen amber + doğrusu yeşil, 1 sn sonra sıradaki (kırmızı yerine amber: uygulamada "asla kırmızı" kuralı, Eşleştir ile aynı). Cevaplanmayan sorular kaydedilmez.
- Oyna sekmesi: iki yeni kart (altı oyun kartı), ikisinde de "Sınırsız" etiketi. Bulmaca sonu önerisi sırası: Kelime Avı, Eşleştir, Cümle Kur, Boşluğu Doldur.
- Testler: `SentenceGamesTest` (uygunluk taraması tüm `cards.json` kartlarında: Cümle Kur ≥ 2100, Boşluğu Doldur ≥ 1700 kart kalmalı).
iOS (yukarıdakilerin aynısı, fark yok): kurallar KelimeCore'da `Games/SentenceGames.swift` (`SentenceTokens`, `SentenceGame`, `GapFill`, `GapFillGame`); kaynak adları `StreakSource` / `ReviewSource` `.sentence` / `.gapFill`; `game_result.game` aynı adlar; `FreeGame` sırası wordSearch, match, sentence, gapFill; `GamePool.cards(where:)` uygunluk süzgeci, `GamePool.best` oyun en iyisi (Boşluğu Doldur). iOS'ta Cümle Kur'da `shown(_:position:)` satırda 1. yerdeki kartı büyük harfle gösterir. Görünüm: `App/Games/SentenceGameViews.swift` (`SentenceView`, `GapFillView`), sonuç ekranı `GameResultView` (Cümle Kur'da cümle listesi). Testler: `SentenceGamesTests` (taramada Cümle Kur ≥ 2100, Boşluğu Doldur ≥ 1700), `FreeGameOrderTests`.

### 2026-11-14 · 1.2 §2–§3 Ters deneme (3 gün), arşivde haftada 2, ücretsiz oyunlar görünür · iOS [x] Android [x]
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
iOS (yukarıdakilerin aynısı): deneme durumu Keychain'de (`ReverseTrial`, `KeychainTrialStore`; yeniden yüklemede ve ilerleme sıfırlamasında silinmez, okunamazsa yeni deneme başlatmaz); `PurchaseManager.isPro = satın alma || deneme`; kota `settings` tablosunda (`ArchiveQuota`, `archive_week`/`archive_opened`, ilerleme sıfırlaması dokunmaz); salt okunur liste `UserLists.isReadOnly` (ilk kendi listesi açık, `.readOnly` hatası); özet `TrialSummary.lines`; sıradaki oyun `FreeGame.next`; `moment` kuralı `PaywallMomentRule`. Testler: `ReverseTrialTests`, `ArchiveQuotaTests` (kota, salt okunur liste, oyun sırası), `UsageSignalTests`. Dosyalar: `Models/ReverseTrial.swift`, `ArchiveQuota.swift`, `TrialSummary.swift`, `PaywallMomentRule.swift`, `App/Store/TrialSummaryView.swift`, `PurchaseManager.swift`, `MainTabView.swift`, `PuzzleArchiveView.swift`, `PuzzleCompletionView.swift`.

### 2026-11-14 · 1.2 §1 Ölçüm: paywall `source`, satın alma `kind` / `product` · iOS [x] Android [x]
Kurallar `docs/V1_2_PLAN.md` §1. Değerler iki platformda aynı yazılır.
Android: `PaywallSignals` (core), `trialEnded` tetikleyicisi enum'da hazır; `kind` RevenueCat `periodType == TRIAL`'dan, `product` Play taban plan ekisiz (`pro.yearly`). Test: `PaywallSignalsTest`.
iOS: `UsageSignal` (KelimeCore) kurar; `Usage.paywallShown` → `source`, `Usage.purchase` → `kind` (RevenueCat `periodType == .trial`) + `product` (store ürün kimliği); `trialEnded` tetikleyicisi hazır. Test: `UsageSignalTests`. Dosyalar: `Models/UsageSignal.swift`, `PaywallTrigger.swift`, `App/Settings/Analytics.swift`, `AppRouter.swift`, `PurchaseManager.swift`.

<!-- Yeni maddeler buraya, en yeni en üstte. Kapananlar docs/SYNC_ARCHIVE.md dosyasının başına taşınır. -->

### 2026-11-13 · RevenueCat yetki kimliği `kelime_widget_pro` · iOS [x] Android [x]
**Sorun:** iki uygulama da RevenueCat'te `pro` adlı yetkiyi arıyor; projedeki tek yetkinin kimliği
`kelime_widget_pro` ("Kelime Widget Pro"). Aynı platformdaki satın alma ürün kimliğinden yine
tanınıyordu, ama hesapla giriş yapınca diğer platformda alınan Pro yetkiden gelmiyordu.
- Android: `ProEntitlement.ENTITLEMENT = "kelime_widget_pro"` (`core/model/Pro.kt`).
- iOS: `App/Store/PurchaseManager.swift` `entitlement = "kelime_widget_pro"`.
- RevenueCat'te Play ürünleri (`pro.monthly:monthly`, `pro.yearly:yearly`, `pro.lifetime`) bu
  yetkiye ve `default` teklifinin `$rc_monthly` / `$rc_annual` / `$rc_lifetime` paketlerine bağlı.

### 2026-11-13 · Paywall: "ücretsiz" yerine "deneme" · iOS [x] Android [x]
Yıllık plandaki deneme metinlerinde "ücretsiz" kelimesi kalktı, yerine "deneme" geldi.
Metinler aynen:
- Plan notu: "7 gün deneme, sonra yıllık · ayda …" (eski: "7 gün ücretsiz, sonra yıllık")
- Buton: "7 gün denemeyi başlat" (eski: "7 gün ücretsiz dene")
- Yasal not: "7 gün deneme, sonra yılda …. Deneme bitmeden …" (eski: "7 gün ücretsiz, sonra …")

Dosyalar: iOS `App/Store/PaywallView.swift`, `App/Store/PaywallDesigns.swift`; Android
`ui/paywall/PaywallScreen.kt` (199, 201, 208. satırlar).
### 2026-11-13 · 1.1.0 yayın öncesi plan kontrolü · iOS [x] Android [x]
`docs/V1_1_PLAN.md` Android'de madde madde kontrol edildi. İki fark çıktı:
- **`share.card` parametresi:** iOS `kind` = paylaşım sayfasının başlığı ("Kartı paylaş",
  "Bulmaca sonucu", "Sonuç", "Haftalık özet", "Seri") gönderiyor; Android `type` = word/puzzle/…
  gönderiyordu. Android iOS'a uyduruldu (`kind`, aynı başlıklar). iOS'ta iş yok.
- **Hatırlatma metni (iOS'ta eksik):** plan §1 "seri risk altındaysa metni değişir: '12 günlük
  serin bu akşam bitiyor. 2 dakikalık bir tur yeter.'" diyor. Android böyle yapıyor ve o gün
  seri günü sayıldıysa hatırlatmayı hiç göndermiyor. iOS `Reminder.swift` sabit, her gün tekrar
  eden tek bir bildirim kuruyor ("Tekrar zamanı" / "Günde bir hatırlatma: …"); risk metni ve
  "çalıştıysan gelme" yok. iOS: 1.1.1'de ya da şimdi, planı uygula ya da planı değiştir.
- Android dosyası: `ui/word/ShareCard.kt`.

**Not (iOS):** hatırlatma plana uyduruldu. iOS bildirim anında kod çalıştıramadığı için
`Reminder.swift` artık tekrar eden tek bildirim yerine önümüzdeki 14 günün her biri için ayrı
bildirim kuruyor (`daily-reminder-YYYY-MM-DD`; 1.0'ın `daily-reminder` kaydı da siliniyor) ve
plan uygulama açıldığında, günün ilk çalışmasında, saat değişince yeniden kuruluyor. Kurallar
`KelimeCore/Learning/ReminderPlan.swift`: bugün çalışıldıysa bugün bildirim yok, yarın risk
metni; seri risk altındaysa bugün "Serin bu akşam bitiyor" / "N günlük serin bu akşam bitiyor.
2 dakikalık bir tur yeter."; diğer günler eski metin. Test: `ReminderPlanTests`. Android'de iş yok.

### 2026-11-11 · Kendini sına: soru ve cevap dönüşümlü · iOS [x] Android [x]
**Sorun:** Kendini sına görünümünde soru yalnızca dilimin ilk 30 dakikasında görünüyor, sonra
dilim bitene kadar cevap kalıyordu. 3 saatlik dilimde bu, sürenin 6'da 5'inde cevabın
görünmesi demek; kullanıcı neredeyse hiç soru görmüyordu.

**Yeni kural:** bir dilimin içinde soru ve cevap dönüşümlü gösterilir.
- 30 dakikalık döngü: **20 dakika soru, 10 dakika cevap**, sonra yine soru (aynı kelime).
- Dilim başından dakika olarak: soru 0, cevap 20, soru 30, cevap 50, soru 60… 3 saatlik
  dilimde 6 döngü, 1 saatlikte 2, 30 dakikalıkta 1.
- Zaman çizelgesi çok büyümesin diye yalnızca 24 saat içinde başlayan dilimler döngülü kurulur;
  daha sonraki dilimlerde tek soru (0) ve tek cevap (20) olur.
- Eski sabitler (`maxRevealDelay` 30 dk, dilimin yarısı) kalktı. Yeni sabitler:
  `selfTestQuestion` 20 dk, `selfTestAnswer` 10 dk, `selfTestCycleHorizon` 24 saat.
- Android'de `core/widgets/WidgetTimeline.kt` içindeki `revealDelay` aynı şekilde değişir;
  kilit ekranı duvar kâğıdı da aynı anlarda yenilenmelidir.

**Test:** `selfTestCyclesQuestionAndAnswerInsideASlot`: ilk dilimde 12 kayıt, dakikalar
0, 20, 30, 50, …, 170; dilim başından 95 dakika sonra görünen kayıt soru; bir günden uzak
dilimde yalnızca soru + cevap; 30 dakikalık dilimde soru 0, cevap 20.

**Not (Android):** kilit ekranı duvar kâğıdı artık evreye göre çizilir: soru evresinde anlam +
`k _ _ _` kalıbı + küçük "Önceki: …" satırı, cevap evresinde kalıbın yerinde kelimenin kendisi.
Yenileme zamanı bir sonraki dilim ya da dilim içindeki bir sonraki soru/cevap değişimidir
(`WidgetTimelineBuilder.nextSelfTestChange`).


### 2026-11-05 · Android paywall ve bulmaca sonu iOS ile aynı · iOS [x] Android [x]
iOS'ta zaten böyleydi.
- **Paywall:** gece gökyüzü zemin (yıldızlar, ay), ✦ parıltı, "KİLİT KELİME PRO", başlık ve neden
  metni; altı özellik iki sütun kutucuk (açılma nedeni önde ve mavi); planlar alt alta satır
  (Aylık "Her ay yenilenir, istediğin zaman iptal et", Yıllık "7 gün ücretsiz, sonra yıllık · ayda …"
  ya da "Yıllık yenilenir", rozet "%N tasarruf" / "En avantajlı", Ömür boyu "Tek seferlik ödeme,
  abonelik yok"); "Fiyatlar yüklenemedi · Tekrar dene"; altta düğme, iki satır yasal metin (mağazaya
  göre), Geri yükle · Koşullar · Gizlilik; sağ üstte buzlu ✕. Bekleyen ödeme: "Satın alma onay bekliyor".
- **Bulmaca sonu:** "BULMACA TAMAM", "6 kelime,\n4 dakika." (serif 52), süre / ipucu, "Widget'ına
  eklenen kelimeler" amber baloncuklar, spoilersız ızgara, "Sonucu paylaş", "Yeniden çöz" · "Kapat",
  günlükte "Yarın yeni bulmaca seni bekliyor."
- Android dosyaları: `ui/paywall/PaywallScreen.kt`, `ui/puzzle/CrosswordScreen.kt`.

### 2026-11-05 · Android Kelimelerim satırları, Listeler ve liste sayfası iOS ile aynı · iOS [x] Android [x]
iOS'ta zaten böyleydi.
- **Kelime satırı:** serif 22 kelime, altında anlam; sağda durum ve seviye çipi; 66 pt, 20 pt içeriden
  ince çizgi. Boş liste: küçük halka, ortalı metin, "Hızlı Tekrar" (Favoriler hariç).
- **Listeler:** KENDİ LİSTELERİM (kartlar: serif başlık + ok, "N / M kelime öğrenildi" ya da
  "Henüz kelime yok", ilerleme, "Widget'ta" anahtarı; kesik çizgili "İlk listeni oluştur" / "Yeni
  liste", Pro etiketi), KURS (kurs kartı, not satırı, bölümler listesi; şu anki bölüm mavi
  çerçeveli), SINAV LİSTELERİ iki sütun ("Bu listeyi bitirdin 🎉", "Yakında"). Silme onayı iOS
  metinleriyle; Android'de listeye uzun basınca açılır (iOS'ta sola kaydırma).
- **Liste sayfası:** serif 34 başlık, "N kelime · widget'ta" ya da boş liste metni, "Kelime ekle"
  ana düğmesi, kelime satırları (sola kaydır: "Listeden çıkar"), alt not. Menü sırası: Paylaşım,
  Dosya olarak gönder, Adını değiştir, Listeyi sil.
- Android dosyaları: `ui/words/WordsScreen.kt`, `ui/lists/UserListScreen.kt`, `ui/course/CourseScreens.kt`.

### 2026-11-05 · Android Hızlı Tekrar, Oyna ve Arşiv iOS ile aynı · iOS [x] Android [x]
iOS'ta zaten böyleydi.
- **Hızlı Tekrar:** üst çubuk ✕ · ilerleme · "3/10"; soru: üst yazı + 30 pt anlam (tür yazmaz).
  Seçenekler 60 pt, serif 24, cevaptan sonra doğru yeşil ✓, seçilen yanlış amber, diğerleri
  soluk; altta "Bilmiyorum". Yazma: cümle, harf kutuları (ilk harf verili, imleç kutusu mavi,
  cevaptan sonra yeşil/amber; yanlışta doğru harfler), klavyenin üstünde "Bilmiyorum" (çerçeveli) ve
  "Kontrol et". Cevap paneli alttan: "Doğru" / "Doğru cevap: …", "wom[e]n → woman" gösterimi ya
  da "Seçtiğin: …" (üstü çizili), örnek cümle, "Bu kelimeyi widget'ında daha sık göreceksin",
  koyu "Devam". Özet: "TUR BİTTİ", büyük skor "/ 10", Öğrenildi / Zorlanılan baloncukları,
  "Bitti" ve "Bir tur daha". Soru yoksa ekran kapanır.
- **Oyna:** Günün Bulmacası alt yazısı bulmaca yokken "İpuçları Türkçe"; Pro satırları başlık
  üstte, açıklama altta.
- **Arşiv:** son 30 günün günlük bulmacası: tarih, "B1 · 3/6 kelime", bittiyse ✓.
- Android dosyaları: `ui/review/QuickReviewScreen.kt`, `ui/play/PlayScreen.kt`.

### 2026-11-05 · Android Kelime Avı ve Eşleştir ekranları iOS ile aynı · iOS [x] Android [x]
iOS'ta zaten böyleydi; Android'de çerçeve, ipucu ve sonuç ekranı farklıydı.
- **Çerçeve:** üstte ✕, ortada oyun adı, sağda süre (Kelime Avı "0:42") ya da kalan saniye
  (Eşleştir, son 10'da amber).
- **Kelime Avı:** "N / M kelime", ızgara, iki sütun ipucu (anlam; altında "N harf" ya da
  bulununca kelime yeşil, anlam üstü çizili), altta "İlk harfi göster" (sıradaki bulunmamış
  kelimeye). Üç harften kısa seçim cevap sayılmaz; ipucu dairesi açık amber zemin.
- **Eşleştir:** giriş ekranı "60 saniye", açıklama, "En iyi skorun: N" (yeşil), Başla; oyunda
  "N eşleşme"; iki taraftan da önce dokunulabilir.
- **Sonuç (ortak):** "KELİME AVI TAMAM" / "YENİ REKOR!" / "SÜRE DOLDU", büyük başlık ("6 kelime",
  "12 eşleşme"), iki değer (süre, ipucu / en iyi, zorlandığın), kelime baloncukları ("Bu turun
  kelimeleri" / "Widget'ında daha sık görünecek"), "Sonucu paylaş", "Bir tur daha" · "Kapat".
- Yetersiz kelime: "Yeterli kelime yok" / "Widget'ında açık bir liste ya da kurs olmalı."
- Android dosyası: `ui/games/GameScreens.kt`.

### 2026-11-05 · Android seri sayfası, haftalık özet, Bugün ve paylaşım kartları iOS ile aynı · iOS [x] Android [x]
iOS'ta zaten böyleydi; Android'de metin ve düzen farklıydı.
- **Bugün:** seri rozeti kilit simgesi + "N gün" (amber: bugün açık), seri ya da en uzun seri
  varsa görünür. Pazartesi kartı "Geçen haftan hazır · N kelime öğrendin · N kelime kilit
  ekranında". Şu anki bölüm kartı: başlık yanında ok, hedef 2 satır, "N/N kart öğrenildi";
  yarısı öğrenilince "Hikâye oku: …"; sonraki seviye düğmesi ana düğme. Kahraman kelime tek satır.
- **Seri sayfası:** büyük sayı, "günlük seri" (0 ise "Bugün bir tur yap, serin başlasın."), alt
  satır (risk / en uzun / "Bu senin en uzun serin."), 5 haftalık takvim kartı (30 dp nokta,
  bugün mavi halka, koruyucu kesik çizgi), üç kural satırı, "Serini paylaş".
- **Haftalık özet ("Geçen hafta"):** tarih aralığı, büyük sayı + "kelime öğrendin", 2×2 kutu
  (kilit ekranında göründü, seri, Hızlı Tekrar doğruluğu, kelimede zorlandın), haftanın kelimesi
  ("Önce zorlandın, sonunda öğrendin."), "Haftanı paylaş".
- **Paylaşım kartları:** iOS `ShareFrame` ölçüleri (360×640 pt, 3×; 36 pt kenar), sola yaslı;
  alt satır "Kilit Kelime · Kilit ekranında İngilizce". Seri (takvimli), Geçen haftam, Bulmaca
  (N kelime, süre · ipucu, ızgara: yardımlı kelimeler amber), Oyun (başlık, tarih, sonuç, ilk 6
  kelime), Kelime kartı. Mavi zemin `#21386B`, Koyu `#12110F`, Açık `#FBF9F5`.
- Android dosyaları: `ui/today/TodayScreen.kt`, `ui/today/StreakScreens.kt`, `ui/word/ShareCard.kt`,
  `ui/share/ShareSheet.kt`; `core/games/Games.kt` (`firstTryCards`, `missedCards`).

### 2026-11-05 · Kelimelerim üst kısmı iOS düzeninde · iOS [x] Android [x]
iOS'ta zaten böyleydi; Android'de sıra ve görünüm farklıydı.
- Sıra: "Bu hafta N öğrenildi · şu an N zorlanılan" satırı (yeşil / amber kalın), arama kutusu,
  yanında 44 pt kare Sırala (ve yalnızca Tümü'nde Filtrele, filtre açıkken mavi) düğmesi, altında
  bütün genişliği kaplayan Zorlanılan / Öğrenildi / Favoriler / Tümü seçici.
- Filtreler yalnızca Tümü'nde uygulanır.
- Android dosyası: `ui/words/WordsScreen.kt`.

### 2026-11-05 · Android Profil iOS ile aynı; uygulama ikonu · iOS [x] Android [x]
iOS'ta zaten böyleydi; Android geride kalmıştı. Bundan sonra Profil iki tarafta aynı ilerler.
- **Sıra:** HESAP (profil, Listelerim eşitleme, Çıkış yap, Hesabı sil), Pro kartı / ÜYELİK,
  SEVİYE VE SINAV (Seviye; Sınav geri sayımı anahtarı; açıkken Sınav ve Sınav tarihi), WIDGET
  (Değişim sıklığı, Kilit ekranı görünümü, Gösterilecekler, Widget nasıl eklenir?), HATIRLATMA VE
  TELAFFUZ (Günlük hatırlatma 20:30 varsayılan, Saat, Ses ve hız 0,8/0,9/1,0× ve "reluctant"
  dinletir), BAŞTAN BAŞLA, UYGULAMA (Uygulama ikonu, Öneri gönder, Gizlilik politikası,
  Kullanım koşulları, Satın alımları geri yükle), GELİŞTİRİCİ (yalnızca debug), alt bilgi.
- **Uygulama ikonu:** Krem, Mavi, Turuncu (iOS `AppIcon`, `AppIcon-Blue`, `AppIcon-Orange` ile
  aynı renkler). Android'de üç launcher `activity-alias`'ı; biri açık.
- **Geliştirici:** Android'de kaldırıldı (bkz. Bilinçli farklar).
- Android'e özgü: WIDGET bölümünde "Kilit ekranı kelimesi" (duvar kâğıdı / bildirim) satırı.
- Android dosyaları: `ui/profile/ProfileScreen.kt`, `ui/profile/AppIcon.kt`,
  `AndroidManifest.xml`, `tools/make_android_icon.py`.

### 2026-11-05 · Profil'de sabit Pro girişi · iOS [x] Android [x]
App Review 1.0'ı 2.1(b) ile durdurdu: inceleyen kişi uygulama içi satın almaları bulamadı,
çünkü Pro ekranı yalnızca kilitli bir özelliğe dokununca açılıyordu. Artık her zaman bulunan
bir giriş var. Google Play incelemesi için de aynısı gerekli.
- **Pro değilse:** Profil'de hesap kartının hemen altında açık mavi bir kart.
  - Solda mavi kutuda ✦ simgesi.
  - Başlık: "Kilit Kelime Pro".
  - Alt yazı: "Sınırsız liste, sınav planı, sana özel bulmaca ve daha fazlası".
  - Sağda ok. Dokununca paywall `base` tetikleyicisiyle açılır.
- **Pro ise:** "ÜYELİK" bölümü.
  - "Kilit Kelime Pro" satırı, sağında yeşil onay ve plan adı.
  - "Aboneliği yönet" satırı: iOS'ta `https://apps.apple.com/account/subscriptions`, Android'de
    Play abonelik sayfası (`https://play.google.com/store/account/subscriptions`).
- iOS dosyası: `App/Settings/SettingsView.swift` (`proSection`).
- Android dosyası: `ui/profile/ProfileScreen.kt`. Plan adı iOS'taki gibi "Pro".


### 2026-11-04 · İnceleme düzeltmeleri · iOS [x] Android [x]
Kod incelemesinde bulunan hatalar. Android'de aynı kod yolu varsa aynı düzeltme yapılmalı.
- **Kelime Avı seçimi:** "yanlış" durumu ile hata titreşimi ayrı değişkenlerde tutuluyor.
  - Yanlış seçim 0,35 sn amber kalır, sonra temizlenir. Bu süre içinde yeni bir sürükleme
    başladıysa yalnızca yanlış olan temizlenir.
  - Doğru seçim hemen temizlenir.
  - Önceden tek bir değişken açılıp kapanıyordu. Bu yüzden bir yanlıştan sonra seçim hep amber
    kalıyor ve bulunan kelimenin üstünde seçim izi duruyordu.
- **Kelime Avı dolgu harfleri:** dolgu harfleri A–Z'nin 26 harfinin tamamından seçilir.
  Q, W, X eksikti; bu harfleri içeren kelime tek başına göze batıyordu.
- **En uzun seri:** kullanıcının kendi planıyla hesaplanır (ücretsizde haftada 1 koruyucu).
  Önceden herkes için 2 koruyucuyla hesaplanıyordu. Bir güne ikinci kaynak eklenmesi seriyi
  uzatamaz, o yüzden o durumda en uzun seri yeniden hesaplanmaz.
  - Test: `longestStreakUsesTheFreePlanFreezes` (Pzt, Çrş, Cum çalışıldı → en uzun 2).
- **Eşleştir:** her eşleşmenin 0,42 sn'lik bekleme sayacı yalnızca kendi eşleşmesini uygular.
  Önceden ikinci bir eşleşme hızlı gelince ilkinin sayacı onu erken uyguluyordu.
- **Bildirim kartı ve Pro teklifi:**
  - Yalnızca tur ekranı açıkken "sorulacak" diye işaretlenir. Tur kapandıktan sonra
    işaretlenip alakasız bir sonraki turda çıkmaz.
  - Başka bir sayfa açıksa (haftalık özet, paywall) gösterilmez ve bir sonraki tura kalır.
    Önceden reddediliyor ama gösterilmiş sayılıyordu.
- **`recordStudy`:** seri durumu yalnızca günün ilk çalışmasında yeniden okunur. Bulmacada her
  kelimede gereksiz hesap yapılmıyor.
- **v7 taşıma (iOS'a özel):** bir güne ait bütün kaynaklar `group_concat` ile saklanır.
- Android: dolgu harfleri 26 harf (`core/games/Games.kt`); `longestStreakUsesTheFreePlanFreezes`
  `StreakTest`'e taşındı (Android en uzun seriyi zaten kullanıcının planıyla hesaplıyordu); Eşleştir
  her doğru eşleşmeye bir sayaç numarası verir, 0,42 sn sonra yalnızca kendi numarası hâlâ
  geçerliyse uygular (aynı yerlere gelen yeni bir eşleşmeyi erken uygulamaz); `AppModel.studied`
  yalnızca tur ekranı açıkken (`roundOpen`) işaretler ve günün ilk çalışması değilse seri
  durumunu okumaz; `MainScaffold` 0,6 sn sonra başka bir tam ekran sayfa açıksa göstermez,
  işaret bir sonraki tura kalır. Kelime Avı'nda yanlış seçim zaten ayrı değişkendeydi
  (`miss`, 0,35 sn amber; doğru seçim hemen temizleniyor); değişiklik gerekmedi.

### 2026-11-03 · Pro teklifi uygulama sevildikten sonra · iOS [x] Android [x]
- **Kendiliğinden açılan tek Pro ekranı bu.** Onboarding sonunda paywall yok. Kilitli bir
  özelliğe dokununca açılan paywall'lar aynen kalır.
- **Şartların hepsi gerekir:**
  - Pro değil.
  - `streak_day` tablosunda en az **3 farklı gün** var.
  - Bu teklif en çok **2 kez** gösterilmiş ve son teklifin üstünden **14 gün** geçmiş.
  - Herhangi bir paywall'un açılmasının üstünden **48 saat** geçmiş.
- **Ne zaman açılır:** seri günü sayıldığında (`recordStudy`) şartlar tutuyorsa "teklif
  edilecek" diye işaretlenir. Tam ekran tur kapanınca 0,6 sn sonra paywall açılır.
- **Bildirim kartıyla çakışmaz:** aynı turda bildirim kartı da bekliyorsa önce o gösterilir;
  Pro teklifi bir sonraki iyi ana kalır. Bir turdan sonra en çok bir soru çıkar.
- **Yeni tetikleyici `moment`:**
  - Başlık: "Güzel gidiyorsun".
  - Alt yazı: "Birkaç gündür buradasın. Ücretsiz olan her şey öyle kalır; Pro daha fazlasını
    açar."
  - Öne çıkan özellik yok; liste sırası `base` ile aynı.
- **Sinyal:** `paywall.moment`.
- iOS dosyaları: `App/Store/PaywallMoment.swift`, `App/MainTabView.swift`, `App/AppModel.swift`,
  `App/AppRouter.swift`, `PaywallTrigger.swift` (core).
- Android dosyaları: `core/model/Pro.kt` (`PaywallTrigger.MOMENT`, `PaywallMoment` kuralları,
  `PaywallMomentTest`), `data/PaywallMomentStore.kt` (sayaçlar `LockPrefs`'te), `data/AppModel.kt`
  (`studied`), `ui/Navigation.kt` (tur kapanınca 0,6 sn; her `showPaywall` saati kaydeder),
  `ui/paywall/PaywallScreen.kt`.


### 2026-11-02 · Bildirim izni ilk iyi andan sonra soruluyor · iOS [x] Android [x]
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
- Android dosyaları: `notifications/ReminderAsk.kt` (kural + kart), `ui/onboarding/Onboarding.kt`,
  `ui/Navigation.kt` (tur kapanınca 0,6 sn), `data/AppModel.kt` (`studied`), `data/LockPrefs.kt`.
  Android "hiç sorulmadı" bilgisini vermediği için uygulama izni istediğini kendisi saklar; daha önce
  istenmiş ve gerekçe gösterilmiyorsa kalıcı reddedilmiş sayılır. Android 12 ve altında sistem izni
  yok: hatırlatma kurulmamışsa kart çıkar, Hatırlat doğrudan kurar.

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
