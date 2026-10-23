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
- **Ölçüm (TelemetryDeck) eklenmediyse:** "Veri toplamıyoruz" (Data Not Collected) → Yayınla.
- **TelemetryDeck eklenirse:** Kullanım Verileri › Ürün Etkileşimi → Analiz amaçlı → **Kimliğe bağlı değil** → **İzleme için kullanılmıyor**.
- Gizlilik politikası URL'si yukarıdakiyle aynı.

## 5. Uygulama içi satın almalar (Pro)
Kimlikler koddakiyle **birebir aynı** olmalı: `pro.lifetime` ve `pro.yearly`.

### 5a. Ömür boyu (tek seferlik)
**Gelir Elde Etme › Uygulama İçi Satın Almalar › +**
- Tür: **Tüketilemeyen (Non-Consumable)**
- Referans adı: `Pro Lifetime` (yalnız sen görürsün)
- Ürün kimliği: `pro.lifetime`
- **Fiyat:** Fiyat planı ekle; Türkiye fiyatını seç (test ayarlarında 249,99 ₺; istediğin fiyatı seç). Diğer ülkeler otomatik hesaplanır.
- **Yerelleştirme (Türkçe):** Görünen ad `Kelime Widget Pro, ömür boyu`; açıklama (55 karakter sınırı): `Sınırsız liste, paylaşma, sınav planı ve daha fazlası`
- **İnceleme bilgisi:** Ödeme ekranının ekran görüntüsü (uygulamada Ayarlar › Pro › Mevcut plan). Not: "Pro özellikleri açar; tek seferlik."
- Durum "Gönderilmeye hazır" olmalı.

### 5b. Yıllık abonelik
**Gelir Elde Etme › Abonelikler › Abonelik grubu oluştur**
- Grup adı: `Pro`; grup yerelleştirmesi (Türkçe): görünen ad `Kelime Widget Pro`
- Gruba **+ abonelik**:
  - Referans adı: `Pro Yearly` · Ürün kimliği: `pro.yearly`
  - Süre: **1 yıl**
  - **Fiyat:** Türkiye fiyatı (test ayarlarında 149,99 ₺)
  - **Tanıtım teklifi › Ücretsiz deneme › 1 hafta**, yeni aboneler için, tüm ülkeler
  - Yerelleştirme (Türkçe): `Kelime Widget Pro, yıllık`; açıklama: `Sınırsız liste, paylaşma, sınav planı ve daha fazlası`
  - İnceleme ekran görüntüsü ve notu (5a gibi)
- İlk sürümde abonelikler **uygulama sürümüyle birlikte** incelemeye gider (6. adım).

## 6. Sürüm 1.0 sayfası
**Uygulamalarım › Kelime Widget › iOS Uygulaması › 1.0 Hazırlanıyor**
1. **Ekran görüntüleri:** iPhone **6,9 inç** (1320 × 2868 dikey) zorunlu; 6,5 inç isteğe bağlı.
   Sırası ve yazıları docs/APP_STORE.md'de. Simülatörde iPhone 17 Pro Max ile `Cmd+S` alınabilir.
2. **Tanıtım metni, açıklama, anahtar kelimeler:** docs/APP_STORE.md
3. **Destek URL'si:** `https://enesseval.github.io/kelime/` · Pazarlama URL'si: aynı ya da boş
4. **Telif hakkı:** `2026 Enes Seval`
5. **Derleme (Build):** **+** ile TestFlight'ta test ettiğin build'i seç (ör. 22).
   Şifreleme sorusu çıkmaz (Info.plist'te `ITSAppUsesNonExemptEncryption = NO`).
6. **Uygulama İçi Satın Almalar ve Abonelikler** bölümü: **+** ile `pro.lifetime` ve `pro.yearly`'yi bu sürüme ekle. Bu adım atlanırsa ürünler incelemeye gitmez.
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
