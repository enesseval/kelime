# App Store Connect: yayına adım adım

Uygulama: Kelime Widget · Bundle ID `com.enesseval.kelime` · Takım `82S9ART43D`
Metinlerin hepsi docs/APP_STORE.md'de; buradaki adımlar nereye ne yazılacağını anlatır.
Adres: appstoreconnect.apple.com

## 0. Önce bir kez (satın alma için şart)
1. **İşletme › Anlaşmalar (Business › Agreements):** "Paid Apps" (Ücretli Uygulamalar) anlaşmasını kabul et.
   Bu olmadan uygulama içi satın almalar çalışmaz ve incelemeye gönderilemez.
2. Aynı sayfada **banka hesabı** ve **vergi formlarını** doldur (W-8BEN: ABD dışı kişi; Türkiye vergi kimlik numaran).
   Durumun "Active" olmasını bekle; bir iki gün sürebilir.
3. **Kullanıcılar ve Erişim › Sandbox › Test hesapları:** Satın almayı denemek için bir sandbox hesabı aç (gerçek olmayan bir e-posta olabilir).
   iPhone'da Ayarlar › App Store › Sandbox Hesabı ile giriş yapılır.

## 1. Uygulama kaydı (TestFlight için açtıysan var; kontrol et)
**Uygulamalarım › Kelime Widget**. Yoksa: **+ › Yeni Uygulama**:
- Platform: iOS
- Ad: `Kelime Widget: İngilizce`
- Birincil dil: Türkçe
- Paket kimliği: `com.enesseval.kelime`
- SKU: herhangi bir iç kod (ör. `kelime-widget-1`)
- Erişim: Tam erişim

## 2. Uygulama Bilgileri (App Information)
- **Alt başlık:** `Kilit ekranında kelime öğren`
- **Kategori:** Birincil Eğitim; ikincil isteğe bağlı (Başvuru Kaynakları)
- **İçerik hakları:** "Üçüncü taraf içeriği içermiyor ya da haklarına sahibim". Kelime listesi CC BY-SA'dır, kaynağı uygulamada belirtildi.
- **Yaş derecelendirmesi › Düzenle:** Tüm sorulara "Hayır / Yok" → 4+.
  "Kullanıcı tarafından oluşturulan içerik" sorusu varsa: liste paylaşımı yalnızca dosyayla ve kişiden kişiye olduğu için "Hayır".
- **Gizlilik Politikası URL'si:** `https://enesseval.github.io/kelime/gizlilik.html`

## 3. Fiyatlandırma ve Erişilebilirlik
- Fiyat: **Ücretsiz** (Pro uygulama içi satın almayla gelir)
- Ülkeler: Tümü ya da yalnızca Türkiye. İçerik Türkçe konuşanlar için; tümü sorun değil.

## 4. Uygulama Gizliliği (App Privacy)
Uygulama TelemetryDeck ile kimliksiz kullanım sayıları gönderiyor, bu yüzden "Veri toplamıyoruz" seçilmez:
- **Başlayın › Evet, veri topluyoruz**
- **Kullanım Verileri › Ürün Etkileşimi** (TelemetryDeck): amaç **Analiz**, kimliğe bağlı **Hayır**, izleme **Hayır**
- **Satın Almalar › Satın Alma Geçmişi** (RevenueCat): amaç **Uygulama İşlevi**, kimliğe bağlı **Hayır**, izleme **Hayır**
- Kaydet → **Yayınla**
- Gizlilik politikası URL'si yukarıdakiyle aynı.

## 5. Uygulama içi satın almalar (Pro) ve RevenueCat
Kimlikler koddaki ve RevenueCat'tekiyle **birebir aynı** olmalı: `pro.monthly`, `pro.yearly`, `pro.lifetime`.

### 5a. Abonelik grubu "Pro" (aylık ve yıllık aynı grupta)
**Gelir Elde Etme › Abonelikler › Abonelik grubu oluştur**: ad `Pro`, Türkçe görünen ad `Kelime Widget Pro`.
- **Aylık:** referans `Pro Monthly`, kimlik `pro.monthly`, süre 1 ay, fiyat (ör. 49,99 ₺), Türkçe ad `Kelime Widget Pro, aylık`
- **Yıllık:** referans `Pro Yearly`, kimlik `pro.yearly`, süre 1 yıl, fiyat (ör. 249,99 ₺), **tanıtım teklifi: 1 hafta ücretsiz deneme**, Türkçe ad `Kelime Widget Pro, yıllık`
- Açıklama (ikisi): `Sınırsız liste, paylaşma, sınav planı ve daha fazlası`
- Grup sıralaması: yıllık üstte.

### 5b. Ömür boyu
**Uygulama İçi Satın Almalar › + › Tüketilemeyen**: referans `Pro Lifetime`, kimlik `pro.lifetime`, fiyat (ör. 599,99 ₺), Türkçe ad `Kelime Widget Pro, ömür boyu`.

### 5c. İnceleme bilgisi (üç ürün)
Ödeme ekranının ekran görüntüsü ve not: "Pro özelliklerini açar."

### 5d. RevenueCat (uygulama `appl_` public key ile bağlı)
- Uygulama: bundle `com.enesseval.kelime`; App-Specific Shared Secret ve In-App Purchase Key (.p8) girili
- Products: üç ürün · Entitlement: `pro` (üçü bağlı) · Offering: `default` (Current) → Monthly, Annual, Lifetime paketleri
- Satın alımlar ilk sürümde **uygulama sürümüyle birlikte** incelemeye gider (6. adım).

## 6. Sürüm 1.0 sayfası
**Uygulamalarım › Kelime Widget › iOS Uygulaması › 1.0 Hazırlanıyor**
1. **Ekran görüntüleri:** iPhone **6,9 inç** (1320 × 2868 dikey) zorunlu; 6,5 inç isteğe bağlı.
   Sırası ve yazıları docs/APP_STORE.md'de. Simülatörde iPhone 17 Pro Max ile `Cmd+S` alınabilir.
2. **Tanıtım metni, açıklama, anahtar kelimeler:** docs/APP_STORE.md
3. **Destek URL'si:** `https://enesseval.github.io/kelime/` · Pazarlama URL'si: aynı ya da boş
4. **Telif hakkı:** `2026 Enes Seval`
5. **Derleme (Build):** **+** ile TestFlight'ta test ettiğin build'i seç (ör. 22).
   Şifreleme sorusu çıkmaz (Info.plist'te `ITSAppUsesNonExemptEncryption = NO`).
6. **Uygulama İçi Satın Almalar ve Abonelikler** bölümü: **+** ile `pro.monthly`, `pro.yearly` ve `pro.lifetime`'ı bu sürüme ekle. Bu adım atlanırsa ürünler incelemeye gitmez.
7. **App Review bilgileri:**
   - Oturum açma gerekli mi: **Hayır**
   - İletişim: adın, telefon, `enesseval@outlook.com`
   - Not: docs/APP_STORE.md'deki "App Review notu"
8. **Sürüm yayını:** "Bu sürümü manuel olarak yayınla". Onaylanınca ne zaman çıkacağına sen karar verirsin.
9. Sağ üstte **İncelemeye Gönder**.

## 7. İnceleme sonrası
- Genelde 24–48 saat sürer. Red gelirse mesajı bana ilet, birlikte düzeltelim.
- Onaylanınca **Bu sürümü yayınla**. Mağazada görünmesi birkaç saat sürebilir.
- Yayından sonra **Analitik** ve **Satışlar** sekmeleri indirme, elde tutma ve satışları gösterir.

## Sık hatalar
- Ürün kimliği kodla aynı değil → ödeme ekranında fiyat görünmez ("Fiyatlar yüklenemedi")
- Paid Apps anlaşması aktif değil → satın almalar sandbox'ta bile çalışmaz
- Satın almalar 6. adımda sürüme eklenmemiş → inceleme "IAP bulunamadı" diye döner
- Ekran görüntüsünde Apple Watch ya da gerçekte olmayan bir özellik görünüyor → ret sebebi (Guideline 2.3)
