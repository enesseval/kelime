# Kelime Widget · Yayın öncesi test listesi

Build 21 ve sonrası için. Her maddeyi denedikçe işaretle; sorun çıkarsa maddenin altına not düş.
Aksi yazmıyorsa iPhone'da, TestFlight sürümüyle.

## 0. Hazırlık
- [ ] Uygulamayı sil, TestFlight'tan yeniden kur (temiz kurulum testleri için)
- [ ] Ayrıca bir cihazda eski build'in üstüne güncelle (güncelleme testleri için, bölüm 12)
- [ ] Bildirimler, Hareketi Azalt ve Yazı Boyutu ayarlarının yerini bil (bölüm 11)

## 1. Tanıtım filmi (temiz kurulum)
- [ ] Film kendiliğinden başlıyor: şafakta telefon yanıyor, "serendipity" harf harf yazılıyor, "mutlu tesadüf" çıkıyor
- [ ] Telefon yanarken hafif titreşim var
- [ ] 2. sahne: saat 09:00 → 13:00 → 18:20 → 22:30 akıyor, gökyüzü sabah, öğle, gün batımı, gece oluyor, güneş yayını çiziyor
- [ ] Her kelime değişiminde hafif titreşim var
- [ ] Altta "Günde 4'e kadar yeni kelime, hiç uğraşmadan." yazıyor
- [ ] Sahne geçişlerinde iki altyazı üst üste binmiyor
- [ ] 3. sahne: yıldızlı gece, kelime çipleri düşüyor ve ortalı duruyor, çoğu yeşile dönüyor, başarı titreşimi, "Kelime Widget" ve "Başla" çıkıyor
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
- [ ] Kilit ekranına Kelime widget'ı eklenebiliyor
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
- [ ] Üstte KURS: "A1 kursu" kartı (ilerleme ve "Widget'ta" anahtarı), altında bölümler
- [ ] Bölüme dokununca detay açılıyor; "Bu bölüme geç" çalışıyor
- [ ] SINAV LİSTELERİ: YDS 355, YÖKDİL 309, IELTS 270 kelime civarı; kurs kartıyla aynı düzende
- [ ] Bir sınav listesini açınca Bugün'deki "Widget'ında" satırı güncelleniyor, widget'a sınav kelimeleri karışıyor
- [ ] Açık olan son liste kapatılamıyor (anahtar pasif)
- [ ] "Kelimeler" düğmesiyle kelime listesine dönülüyor

## 9. Ayarlar
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
- [ ] Ayarlar'da PRO bölümü ve "Satın alımları geri yükle" var; Geliştirici › "Pro'yu aç" ile Pro açılıp kapanıyor
- [ ] Ödeme ekranı: yeni Pro maddeleri, fiyatlar yükleniyor, satın alma (sandbox) ve geri yükleme çalışıyor
- [ ] Değişim sıklığı: Normal ücretsiz; Sık ve Çok sık Pro değilken ödeme ekranını açıyor, Pro'da seçiliyor
- [ ] Kendi listelerim: ilk liste ücretsiz oluşuyor; ikinci liste Pro değilken ödeme ekranı açıyor
- [ ] Listeye uygulamadan kelime ekleme (arama, ✓ işareti, aynı kelime ikinci kez eklenmiyor)
- [ ] Kendi kelimeni yazma: kelime ve anlam zorunlu, tür seçimi, örnek isteğe bağlı; örneksiz kelime detayda ÖRNEK göstermiyor
- [ ] Listeden kelime çıkarma (basılı tut), adını değiştirme, silme
- [ ] Liste "Widget'ta" açıkken widget ve Hızlı Tekrar'a listenin kelimeleri karışıyor; Bugün'deki satırda listenin adı görünüyor
- [ ] Kursu kapatıp yalnızca listeyi açınca widget sadece liste kelimelerini gösteriyor
- [ ] Paylaş: Pro değilken ödeme ekranı; Pro'da paylaşma penceresi .kelimelist dosyasıyla açılıyor
- [ ] Başka bir cihazda (ya da Dosyalar'dan) .kelimelist açınca liste ekleniyor, mesaj çıkıyor, Listeler açılıyor
- [ ] Sınav planı: sınav geri sayımı açıkken Bugün'de kart; Pro değilken Pro rozeti ve ödeme ekranı; Pro'da günlük hedef, ilerleme ve "Sınav tekrarı" yalnızca o sınav listesinden soruyor
- [ ] Oyna: Arşiv ve Sana Özel Bulmaca Pro değilken ödeme ekranı, Pro'da açılıyor
- [ ] Seviye testi: tanıtımda "Seviyemi bilmiyorum", sorular, Bilmiyorum, sonuç ve "… ile başla" seviyeyi seçiyor
- [ ] Öğrenilen bir kelimenin detayında "Sonraki tekrar" tarihi; zamanı gelince widget'ta ve Hızlı Tekrar'da çıkıyor
- [ ] Kelime detayında "Bu kartta hata mı var? Bildir" formu kelimeyle dolu açılıyor
- [ ] Geliştirici › Kullanım sayaçları yeni olayları sayıyor
- [ ] TestFlight build'inde birkaç işlem yap; TelemetryDeck panelinde (Test Mode açık) "Usage." sinyalleri görünüyor

## 12. Eski sürümden güncelleme
- [ ] Sandbox ile Pro alınmış test hesabı Pro olarak kalıyor
- [ ] İlerleme, favoriler ve seçili seviye korunuyor
- [ ] Önceden girilmiş YDS tarihi sınav geri sayımı olarak duruyor
- [ ] Eskiden seçilen değişim sıklığı Pro değilse Normal'e düşüyor
- [ ] Eski saat uygulaması güncellenmiyor (elle silinebilir)

## 13. App Store'a göndermeden önce (App Store Connect)
- [ ] Sürüm 1.0 için doğru build seçildi
- [ ] Uygulama içi satın alma ürünleri (ömür boyu, yıllık) bu sürüme eklendi; açıklamaları docs/APP_STORE.md
- [ ] App Privacy: Kullanım Verileri › Ürün Etkileşimi, analiz, kimliğe bağlı değil, izleme yok
- [ ] Açıklama ve ekran görüntüleri docs/APP_STORE.md ile aynı; Apple Watch ve belirli yenileme aralığı vaadi yok
- [ ] Destek ve gizlilik URL'leri: enesseval.github.io/kelime/
- [ ] Yaş derecelendirmesi ve kategori (Eğitim) dolduruldu
- [ ] Review notu docs/APP_STORE.md'deki metin
