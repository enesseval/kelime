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
| Sürüm | 1.2.0 | 1.2.0 |
| Build | 34 (TestFlight, 1.2.0; 1.1.0 (33) incelemeye girmeden 1.2 ile değiştirilecek) | versionCode 3 (1.2.0; Play'de son yüklenen 2 idi, henüz yüklenmedi) |
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

### 2026-11-14 · 1.2 cihaz testi: deneme özeti, Cümle Kur düzeni, Boşluğu Doldur animasyonu
iOS [ ] Android [ ]

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


