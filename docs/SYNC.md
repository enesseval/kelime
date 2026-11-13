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
| Build | 33 (App Store'a gönderilecek) | versionCode 2 (Play'e yüklenecek) |
| Dal | `v1.1` | `v1.1` |
| Mağazada | 1.0.0 (28) yayında (10 Kasım), `main` | kapalı test (Play) |

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
- Android'de Profil › Geliştirici bölümü yok (kullanıcı kaldırttı, 2026-11-05); iOS'ta Debug ve
  TestFlight'ta duruyor.

## Değişiklik günlüğü

### 2026-11-13 · 1.1.0 yayın öncesi plan kontrolü · iOS [ ] Android [x]
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
