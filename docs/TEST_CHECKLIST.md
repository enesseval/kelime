# Kilit Kelime · Yayın öncesi test listesi

Build 26 ve sonrası için. Her maddeyi denedikçe işaretle; sorun çıkarsa maddenin altına not düş.
Aksi yazmıyorsa iPhone'da, TestFlight sürümüyle.

## 0. Hazırlık
- [ ] Uygulamayı sil, TestFlight'tan yeniden kur (temiz kurulum testleri için)
- [ ] Ayrıca bir cihazda eski build'in üstüne güncelle (güncelleme testleri için, bölüm 12)
- [ ] Bildirimler, Hareketi Azalt ve Yazı Boyutu ayarlarının yerini bil (bölüm 11)
- [ ] Sandbox hesabı hazır (Ayarlar › App Store › Sandbox hesabı); mümkünse ikinci bir iPhone ya da ikinci Apple kimliği (senkron ve Keşfet için, bölüm 15–16)
- [ ] Profil › Geliştirici › "Pro'yu aç" KAPALI (satın alma testleri gerçek sandbox ile yapılsın)

## 1. Tanıtım filmi (temiz kurulum)
- [ ] Film kendiliğinden başlıyor: şafakta telefon yanıyor, "serendipity" harf harf yazılıyor, "mutlu tesadüf" çıkıyor
- [ ] Telefon yanarken hafif titreşim var
- [ ] 2. sahne: saat 09:00 → 13:00 → 18:20 → 22:30 akıyor, gökyüzü sabah, öğle, gün batımı, gece oluyor, güneş yayını çiziyor
- [ ] Her kelime değişiminde hafif titreşim var
- [ ] Altta "Günde 4'e kadar yeni kelime, hiç uğraşmadan." yazıyor
- [ ] Sahne geçişlerinde iki altyazı üst üste binmiyor
- [ ] 3. sahne: yıldızlı gece, kelime çipleri düşüyor ve ortalı duruyor, çoğu yeşile dönüyor, başarı titreşimi, "Kilit Kelime" ve "Başla" çıkıyor
- [ ] Ekrana dokununca sonraki sahneye geçiyor
- [ ] "Atla" son sahneye götürüyor
- [ ] Hareketi Azalt açıkken film sade geçişlerle oynuyor (bölüm 11'de tekrar)

## 2. Tanıtım adımları
- [ ] Seviye: kartlar sırayla kayarak geliyor, her kartta örnek kelimeler var, seçilen kart vurgulanıyor
- [ ] Geri okuyla filme dönülebiliyor
- [ ] Widget adımı: hiçbir içerik butonların altında kalmıyor, kaydırma gerekmiyor
- [ ] Telefon animasyonu döngüde: basılı tut → Özelleştir → Widget ekle penceresi → widget beliriyor
- [ ] Alttaki adım metni animasyonla eşleşiyor; eski ve yeni metin üst üste görünmüyor
- [ ] "Ana ekrana eklemek için" küçük pencerede 4 adımı açıyor
- [ ] "Sonra" ve "Ekledim" yan yana ve ikisi de ilerletiyor
- [ ] Hatırlatma adımı: telefonda örnek bildirim düşüyor
- [ ] "Saat" satırından saat değişince telefondaki saat ve gökyüzü değişiyor (08:00 sabah, 22:00 gece), bildirim yeniden düşüyor
- [ ] "İzin ver": sistem izni soruluyor; izin verince tanıtım bitiyor
- [ ] "Gerek yok": izin sorulmadan bitiyor
- [ ] Küçük ekranlı bir iPhone'da (SE, mini) da adımlar sığıyor

## 3. Widget (kilit ekranı)
- [ ] Kilit ekranına Kilit Kelime widget'ı eklenebiliyor
- [ ] Tanıtımda seçilen seviyenin kelimesi hemen görünüyor (eski seviyenin kelimesi kalmıyor)
- [ ] Gün içinde kelime değişiyor (birkaç saat sonra kontrol et)
- [ ] Widget'a dokununca uygulama o kelimenin detayında açılıyor
- [ ] Ayarlar › Kilit ekranı görünümü'ndeki her mod (Kart, Sözlük, Kelime ve cümle, Örnek cümle, Kendini sına) widget'ta doğru görünüyor
- [ ] "Kendini sına": önce anlam ve ilk harf, sonra cevap görünüyor
- [ ] "Hangisi?" widget'ında seçeneklere dokunmak çalışıyor, doğru veya yanlış kaydediliyor
- [ ] Ana ekran widget'ları (küçük, orta, büyük; "Bugünkü tekrar" dahil) doğru veriyi gösteriyor
- [ ] Büyük widget'ta günün bulmacası durumu görünüyor
- [ ] Tema tek, varsayılan Kâğıt teması; tema seçeneği hiçbir yerde yok
- [ ] Apple Watch: saat uygulaması kurulmuyor, saat için bir şey görünmüyor

## 4. Bugün
- [ ] Üstteki kart, widget'taki kelimeyi gösteriyor; dokununca detay açılıyor
- [ ] Altında "Widget'ında: A1 kursu" (sınav listesi açıksa "A1 kursu · YDS") yazıyor
- [ ] "Değiştir" Kelimelerim › Listeler'i açıyor
- [ ] Şu anki bölüm kartı: ilerleme çubuğu doğru, hikâye butonu hikâyeyi açıyor
- [ ] Hızlı Tekrar kartı: zorlanılan sayısı doğru, "Başla" turu açıyor
- [ ] Günün Bulmacası kartı ve haftalık istatistikler görünüyor
- [ ] 2 gün üst üste tekrar yapınca "n gün üst üste" yazıyor; bir gün kaçınca olumsuz bir şey görünmüyor
- [ ] Sınav geri sayımı açıkken sağ üstte "YDS'ye 42 gün" ("YÖKDİL'e", "IELTS'e") görünüyor; kapalıyken görünmüyor
- [ ] Widget eklenmemişse "widget ekle" bandı çıkıyor; kapatılabiliyor

## 5. Hızlı Tekrar
- [ ] 10 soruluk tur açılıyor, sorular ve şıklar doğru
- [ ] Doğru ve yanlış cevaplar işaretleniyor, ilerleme çubuğu ilerliyor
- [ ] Tur sonu özeti: skor, öğrenilen ve zorlanılan kelimeler
- [ ] "Bir tur daha" sınırsız; günde birden fazla tur açılabiliyor
- [ ] Hatırlatma bildirimine dokununca Hızlı Tekrar açılıyor

## 6. Oyna
- [ ] Hızlı Tekrar ve Günün Bulmacası ücretsiz; Arşiv ve Sana Özel Bulmaca Pro
- [ ] Bulmaca şu anki bölümün kelimelerinden oluşuyor, zorlanılan kelimeler içinde
- [ ] Gün içinde hep aynı bulmaca açılıyor; yarım bırakınca ilerleme korunuyor
- [ ] İpucu, harf girişi, silme ve yön değiştirme çalışıyor
- [ ] Bir kelimeyi doğru bitirince imleç numara sırasıyla sonraki çözülmemiş kelimeye geçiyor (1 → 2 → 3, yatay/dikey fark etmeksizin)
- [ ] Çözülmüş bir kelimeyle kesişen kareye dokununca çözülmemiş kelime seçiliyor ve imleç onun ilk boş karesine gidiyor
- [ ] Alttaki ipucu çubuğunda anlam büyük yazıyor; üstünde küçük "1 YATAY · 6 HARF"
- [ ] ‹ ve › okları numara sırasıyla çözülmemiş kelimeler arasında geziyor
- [ ] Bitirince tamamlama ekranı çıkıyor, "Tamamlandı · yarın yenisi" yazıyor
- [ ] Ertesi gün yeni bulmaca geliyor

## 7. Kelimelerim
- [ ] İlk açılışta kaydırma ipucu kutusu çıkıyor; bir satır kaydırınca ya da kapatınca bir daha çıkmıyor
- [ ] Sola kaydırma: "Biliyorum" ve "Zorlanıyorum" çalışıyor, satır doğru sekmeye geçiyor
- [ ] Zorlanılan, Öğrenildi, Favoriler ve Tümü sekmeleri doğru kelimeleri gösteriyor
- [ ] Boş sekmede kart yok; metin ve buton ortalı, düz arka planda
- [ ] Sıralama menüsü: A–Z, Z–A, Seviye, Son çalışılan, En çok yanlış; dört sekmede çalışıyor
- [ ] Seçilen sıralama uygulama kapatıp açınca korunuyor
- [ ] Tümü yalnızca başlanan bölümlerin ve ilerleme olan kelimelerin kelimelerini gösteriyor (başlanmamış bölüm ve sınav kelimesi yok)
- [ ] Yeni bir bölüme başlayınca kelimeleri Tümü'ye geliyor
- [ ] Filtre (yalnızca Tümü'de): seviye, durum ve tür seçilebiliyor, "Temizle" çalışıyor
- [ ] Açık filtreler listenin üstünde etiket olarak görünüyor; etikete dokununca kalkıyor
- [ ] Filtreler uygulama yeniden açılınca sıfırlanıyor
- [ ] Uzun A–Z listede sağda harf şeridi çıkıyor; sürükleyince ilgili harfe atlıyor, titreşim veriyor
- [ ] Arama: İngilizce kelime ve Türkçe anlam; "isik" yazınca "ışık" bulunuyor
- [ ] Kelime detayı: telaffuz, favori yıldızı, örnek cümle ve paylaşım görseli çalışıyor

## 8. Listeler (Kelimelerim › Listeler)
- [ ] En üstte KENDİ LİSTELERİM, sonra KURS (kart + bölümler), sonra SINAV LİSTELERİ
- [ ] KURS kartının "Widget'ta" anahtarı tüm seviyeleri birlikte kapatıyor; altındaki not duruma göre değişiyor
- [ ] Kurs kapalıyken widget ve Hızlı Tekrar'a A1–B1 kelimesi gelmiyor; sadece açık sınav listeleri, kendi listelerin ve Keşfet'ten eklediklerin
- [ ] Kurs kapalıyken bir bölüm bitip yenisi başlasa da kurs kapalı kalıyor
- [ ] Kursu tekrar açınca şu anki ve önceki seviyelerin kelimeleri geri geliyor
- [ ] Bölüme dokununca detay açılıyor; "Bu bölüme geç" çalışıyor
- [ ] SINAV LİSTELERİ: YDS 355, YÖKDİL 309, IELTS 270 kelime civarı; kurs kartıyla aynı düzende
- [ ] Bir sınav listesini açınca Bugün'deki "Widget'ında" satırı güncelleniyor, widget'a sınav kelimeleri karışıyor
- [ ] Açık olan son kaynak kapatılamıyor (anahtar pasif)
- [ ] Kendi listesi sola kaydırınca çöp kutusu çıkıyor; onay soruyor; silinince listeden kalkıyor
- [ ] Widget'ta açık tek kaynak olan listeyi silince kurs yeniden açılıyor (widget boş kalmıyor)
- [ ] "Kelimeler" düğmesiyle kelime listesine dönülüyor

## 9. Profil (eski Ayarlar)
- [ ] Sekmenin adı "Profil"; en üstte HESAP bölümü, altında eski ayarlar
- [ ] Tema satırı yok
- [ ] Seviye değiştirince Bugün, widget, Hızlı Tekrar ve bulmaca yeni seviyeye geçiyor
- [ ] Sınav geri sayımı: aç → sınav (YDS, YÖKDİL, IELTS) ve tarih seç; geçmiş tarih seçilemiyor; kapatınca Bugün'den kalkıyor
- [ ] Kilit ekranı görünümü modu değişince widget güncelleniyor
- [ ] "Widget nasıl eklenir?" rehberi açılıyor; yalnızca kilit ekranı ve ana ekran sekmeleri var, Apple Watch yok
- [ ] Günlük hatırlatma: aç, kapat, saat değiştir; bildirim o saatte geliyor
- [ ] Ses ve hız: 0.8×, 0.9× ve 1.0× örnek okuyor
- [ ] İlerlemeyi sıfırla: onay soruyor; sıfırlayınca tanıtım baştan açılıyor; metinde Pro geçmiyor
- [ ] "Öneri gönder", "Gizlilik" ve "Koşullar" bağlantıları açılıyor; sayfalarda satın alma geçmiyor
- [ ] En altta sürüm numarası doğru

## 10. İçerik ve çevrimdışı
- [ ] Uçak modunda uygulama, widget ve bulmaca çalışıyor
- [ ] İnternet gelince içerik güncellemesi sorunsuz (en fazla 6 saatte bir kontrol ediliyor)
- [ ] C1 ve C2 seviyesinde birkaç bölüm ve hikâye açılıp okunuyor; çeviriler yerinde

## 11. Erişilebilirlik ve görünüm
- [ ] Açık ve koyu modda tüm ekranlar okunaklı
- [ ] Büyük yazı boyutunda (Erişilebilirlik › Daha Büyük Yazı) metinler taşmıyor
- [ ] Hareketi Azalt açıkken tanıtım ve animasyonlar sade
- [ ] VoiceOver: sekmeler, butonlar ve kelime satırları okunuyor

## 9b. Pro ve yeni özellikler
- [ ] Profil'de PRO bölümü var; Geliştirici › "Pro'yu aç" ile Pro açılıp kapanıyor
- [ ] Ödeme ekranı (widget önizlemeli): kaydırmadan tek ekrana sığıyor; küçük ekranlı iPhone'da da (sığmazsa kayıyor)
- [ ] Önizlemede kelimeler 1,5 sn'de bir değişiyor; Normal / Çok sık kutuları var
- [ ] Açılış sebebi başlığı değiştiriyor ve o özellik ilk kutucukta vurgulu (ör. Değişim sıklığı → "Daha sık yeni kelime")
- [ ] 6 kutucuk: Sınırsız kendi listen, Listeni paylaş, Keşfet'ten hazır listeler, Sınav planı, Daha sık yeni kelime, Sana özel bulmaca
- [ ] Sırayla Aylık, Yıllık (seçili, "%… tasarruf"), Ömür boyu; fiyatlar yükleniyor
- [ ] Buton metni: Yıllık + deneme hakkı → "7 gün ücretsiz dene"; Aylık → "Abone ol · fiyat/ay"; Ömür boyu → "Satın al · fiyat"
- [ ] Butonun altındaki not her planda iki satır; plan değişince buton yerinden oynamıyor; yıllık denemede "7 gün ücretsiz, sonra yılda …" yazıyor
- [ ] Satın alma (sandbox) tamamlanınca ekran kapanıyor ve Pro hemen açılıyor; Geri yükle çalışıyor; Koşullar ve Gizlilik açılıyor
- [ ] Geliştirici › "RevenueCat durumu": satın almadan sonra "Yetki: pro · Ürünler: pro.…" görünüyor
- [ ] Değişim sıklığı: Normal ücretsiz; Sık ve Çok sık Pro değilken ödeme ekranını açıyor, Pro'da seçiliyor (satın aldıktan hemen sonra, uygulamayı kapatmadan)
- [ ] Kendi listelerim: ilk liste ücretsiz oluşuyor; ikinci liste Pro değilken ödeme ekranı açıyor
- [ ] Listeye uygulamadan kelime ekleme (arama, ✓ işareti, aynı kelime ikinci kez eklenmiyor)
- [ ] Kendi kelimeni yazma: kelime ve anlam zorunlu, tür seçimi, örnek isteğe bağlı; örneksiz kelime detayda ÖRNEK göstermiyor
- [ ] Listeden kelime çıkarma (sola kaydır → çöp kutusu), adını değiştirme, silme
- [ ] Liste "Widget'ta" açıkken widget ve Hızlı Tekrar'a listenin kelimeleri karışıyor; Bugün'deki satırda listenin adı görünüyor
- [ ] Kursu kapatıp yalnızca listeyi açınca widget sadece liste kelimelerini gösteriyor
- [ ] Liste menüsü › "Dosya olarak gönder": Pro değilken ödeme ekranı; Pro'da paylaşma penceresi .kelimelist dosyasıyla açılıyor
- [ ] Başka bir cihazda (ya da Dosyalar'dan) .kelimelist açınca liste ekleniyor, mesaj çıkıyor, Listeler açılıyor
- [ ] Sınav planı: sınav geri sayımı açıkken Bugün'de kart; Pro değilken Pro rozeti ve ödeme ekranı; Pro'da günlük hedef, ilerleme ve "Sınav tekrarı" yalnızca o sınav listesinden soruyor
- [ ] Oyna: Arşiv ve Sana Özel Bulmaca Pro değilken ödeme ekranı, Pro'da açılıyor
- [ ] Seviye testi: tanıtımda "Seviyemi bilmiyorum", sorular, Bilmiyorum, sonuç ve "… ile başla" seviyeyi seçiyor
- [ ] Öğrenilen bir kelimenin detayında "Sonraki tekrar" tarihi; zamanı gelince widget'ta ve Hızlı Tekrar'da çıkıyor
- [ ] Kelime detayında "Bu kartta hata mı var? Bildir" formu kelimeyle dolu açılıyor
- [ ] Geliştirici › Kullanım sayaçları yeni olayları sayıyor
- [ ] TestFlight build'inde birkaç işlem yap; TelemetryDeck panelinde (Test Mode açık) "Usage." sinyalleri görünüyor

## 14. Hesap (Profil › HESAP)
- [ ] Giriş yapmamışken "Hesabını bağla" kartı ve "Apple ile devam et" butonu var (açık temada siyah, koyu temada beyaz)
- [ ] Apple ile giriş: ilk girişte adın görünüyor; "Kullanıcı adı seç" mavi yazıyor
- [ ] Vazgeçince hata mesajı çıkmıyor; internet yokken anlaşılır bir hata çıkıyor
- [ ] Düzenle: 15 avatar + baş harf seçilebiliyor; ad ve kullanıcı adı kaydediliyor
- [ ] Kullanıcı adı kuralları: 3–20 karakter, harf/rakam/_; başkasının adı "Bu kullanıcı adı alınmış" diyor
- [ ] Profil sekmesinin alttaki ikonu seçilen avatarın simgesine dönüyor; baş harf seçiliyse harfli daire; çıkış yapınca kişi simgesi
- [ ] "Listelerim · Eşitlendi …" satırına dokununca yeniden eşitliyor
- [ ] Giriş yapınca Pro hesaba bağlanıyor: aynı Apple kimliğiyle başka cihazda Geri yükle Pro'yu açıyor
- [ ] Çıkış yap: onay soruyor; listeler cihazda kalıyor, paylaşımları "Sadece ben"e dönüyor
- [ ] Hesabı sil: onay metni net; silince çıkış yapılıyor, cihazdaki listeler ve ilerleme duruyor; tekrar girince eski listeler sunucudan gelmiyor
- [ ] Uygulama kapatıp açınca oturum korunuyor

## 15. Liste senkronu ve paylaşım
- [ ] Geliştirici › "Örnek listeler oluştur" 3 liste ekliyor (Seyahat'te kendi yazılmış "boarding pass" var)
- [ ] Giriş yapınca cihazdaki kendi listelerin hesaba yükleniyor (Supabase panelinde lists tablosunda görünür)
- [ ] İkinci cihazda aynı hesapla girince listeler kelimeleriyle geliyor; kendi yazdığın kelimeler de
- [ ] Bir cihazda yeniden adlandır / kelime ekle / sil → diğerinde uygulamayı öne getirince güncelleniyor
- [ ] Bir cihazda liste silinince diğerinden de kalkıyor
- [ ] İnternetsiz yapılan değişiklik internet gelince gönderiliyor
- [ ] Keşfet'ten ya da dosyadan eklenen listeler hesaba yüklenmiyor (sadece o cihazda)
- [ ] Liste menüsü › Paylaşım: giriş yoksa "Paylaşmak için Profil'den Apple ile giriş yap" mesajı
- [ ] Paylaşım ekranı: Sadece ben / Linke sahip olanlar / Herkese açık; Pro değilken son ikisi Pro rozetli ve ödeme ekranını açıyor
- [ ] Link ya da herkese açıkken "Linki paylaş" çıkıyor; gönderilen link Safari'de sayfayı açıp uygulamaya geçiriyor ve listeyi gösteriyor
- [ ] Sadece ben'e çekilen listenin linki açılınca "Bu liste paylaşılmıyor" diyor

## 16. Keşfet
- [ ] Hesapsız da açılıyor; "Örnek listeler" hesabının 4 herkese açık listesi görünüyor (Seyahat, İş toplantısı, Mutfak ve yemek, Duygular)
- [ ] "Film izlerken" (sadece linkle) Keşfet'te görünmüyor; linki: https://enesseval.github.io/kelime/liste.html?id=a1b2c3d4-0000-4000-8000-000000000005
- [ ] Arama başlığa göre süzüyor; Popüler / Yeni sıralaması değişiyor; aşağı çekince yenileniyor
- [ ] İnternet yokken "Keşfet'e ulaşılamadı" ve "Tekrar dene"
- [ ] Liste detayında sahibin avatarı, adı, kelime sayısı ve kelimeler var
- [ ] Pro değilken "Listelerime ekle" Pro rozetli, ödeme ekranını "Keşfet'ten hazır listeler" başlığıyla açıyor
- [ ] Pro'da ekleyince "Listelerinde · aç" oluyor; Kelimelerim › Listeler'de görünüyor, widget'ta açık; kayıt sayısı artıyor
- [ ] Bildiğin kelimeler ilerlemesini koruyor; "whisk" (Mutfak) kendi kelimesi olarak geliyor
- [ ] Kendi herkese açık listen Keşfet'te "Bu senin listen" diye açılıyor
- [ ] ⋯ › Şikayet et ve Kullanıcıyı engelle: giriş yoksa uyarı; girişliyken şikayet gidiyor, engellenen kişinin listeleri Keşfet'ten kalkıyor

## 12. Eski sürümden güncelleme
- [ ] Sandbox ile Pro alınmış test hesabı Pro olarak kalıyor
- [ ] İlerleme, favoriler ve seçili seviye korunuyor
- [ ] Önceden girilmiş YDS tarihi sınav geri sayımı olarak duruyor
- [ ] Eskiden seçilen değişim sıklığı Pro değilse Normal'e düşüyor
- [ ] Eski saat uygulaması güncellenmiyor (elle silinebilir)

## 13. App Store'a göndermeden önce (App Store Connect)
- [ ] Sürüm 1.0 için doğru build seçildi
- [ ] Üç ürün (pro.monthly, pro.yearly, pro.lifetime) bu sürüme eklendi ve "Gönderime hazır"; RevenueCat'te üçü de `pro` yetkisine bağlı
- [ ] App Privacy docs/ASC_GUIDE.md bölüm 4'teki gibi (Ürün Etkileşimi, Satın Alma Geçmişi, Kullanıcı Kimliği, Ad, Diğer Kullanıcı İçeriği)
- [ ] Review notu: hesap isteğe bağlı, hesap silme yeri, şikayet/engelleme (docs/ASC_GUIDE.md 4b)
- [ ] Ekran görüntüleri yeni sekmelerle (Keşfet, Profil) ve yeni ödeme ekranıyla güncel
- [ ] Açıklama docs/APP_STORE.md ile aynı; "hesap yok" gibi artık doğru olmayan ifade yok; Apple Watch ve belirli yenileme aralığı vaadi yok
- [ ] gizlilik.html canlıda hesap bölümüyle görünüyor
- [ ] Destek ve gizlilik URL'leri: enesseval.github.io/kelime/
- [ ] Yaş derecelendirmesi ve kategori (Eğitim) dolduruldu
- [ ] Review notu docs/APP_STORE.md'deki metin
