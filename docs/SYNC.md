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
| Build | 36 yayında (1.2.0; 37 yalnızca TestFlight, Geliştirici açık; 38 aynı kod, yüklenmedi) | versionCode 3 (1.2.0; AAB hazır, Play'e henüz yüklenmedi) |
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

### 2026-11-17 · Hızlı Tekrar: noktalama cevabı ele vermesin (1.3.0)
iOS [ ] Android [ ]

Kullanıcı bildirdi: Hızlı Tekrar'da üstte soru işaretiyle biten Türkçe cümle çıktı; 4 seçenekten
yalnız birinin sonunda "?" vardı, diğer üçünde başka noktalama. Cevap noktalamadan bilinebiliyor.
Aynı açık ifade/kalıp/cümle seçenekli her oyunda olabilir (Hızlı Tekrar, Eşleştir, Kelime Avı ipucu
değil; Boşluğu Doldur tek kelime olduğu için etkilenmez).

Kural:
- Seçenekler aynı "cümle türünden" seçilir: doğru cevabın son karakteri `?` ise çeldiriciler de
  `?` ile biten adaylardan; `!` ise `!`; `.` ya da noktalamasız ise onlardan. Tür = son anlamlı
  karakter (sondaki boşluk, tırnak, parantez atlanır).
- Aynı türden yeterli aday yoksa (3'ten az): dört seçeneğin hepsinin **sonundaki** noktalama
  (`. , ! ? ; : …` ve tekrarları) kaldırılır ve hepsi öyle gösterilir. Ortadaki noktalama kalır.
- Büyük harf de ipucu olmasın: seçenekler cümle ise hepsi aynı kuralla (ilk harf büyük) ya da
  kelime/kalıp ise hepsi küçük gösterilir. ("I" ve özel isimler korunur, Cümle Kur kuralı gibi.)
- Tek kelime seçeneklerde değişiklik yok.
- Kural tüm seçenekli üreticilere uygulanır; hangileri olduğunu iki taraf kendi kodunda tarar ve
  "Not"a yazar.

Testler: `cards.json` üzerinden her seçenekli soru üretilir; hiçbir soruda doğru cevap sondaki
noktalama ya da büyük harfle diğer üç seçenekten ayrılamaz (dört seçeneğin "son karakter türü" ve
"ilk harf büyük mü" değerleri aynı).

