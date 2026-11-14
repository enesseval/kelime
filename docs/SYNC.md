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

### 2026-11-14 · 1.2 §5 Sınav geri sayımı · iOS [ ] Android [x]
Kurallar `docs/V1_2_PLAN.md` §5. iOS Live Activity, Android kalıcı bildirim. Testler: plan "Test".
Metin kuralı (iOS aynısını yazsın; `ExamCountdownLine`): "YDS'ye 23 gün · bugün 12 kelime" (YDS -ye, YÖKDİL ve IELTS -e); 12 = günlük hedef. Bugünkü hedef tamamsa "bugünkü hedef tamam", listedeki her kelime öğrenildiyse "hepsini öğrendin", sınav günü "YDS bugün · …". Pro (deneme dahil) ve sınav tarihi şart; tarih yoksa öneri çıkmaz; sınav günü geçince kendiliğinden kapanır; Pro biterse kapanır.
Android: Profil › Seviye ve sınav altında "Kilit ekranında geri sayım" anahtarı (tarih varken görünür, Pro değilse paywall `examPlan`), Bugün'deki sınav planı kartında "Kilit ekranında geri sayım göster" önerisi (Pro, kapalıyken). Varsayılan kapalı. Bildirim sessiz, kalıcı, "Kapat" düğmesi ya da kaydırma anahtarı kapatır. Android 13+ bildirim izni ister. Testler: `ExamCountdownLineTest`.

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

