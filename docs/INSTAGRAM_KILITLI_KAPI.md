# Kilitli Kapı: 3 bölümlük pilot dizi

Yapay zekâ ile üretilen, "konuşan nesne" biçiminde dizi. Eğitim Reels'leri yalnız yakın çevreye
ulaştı (200-450 görüntülenme, dışarıdan yorum/takip yok, "yoruma KELİME yaz" CTA'sı çalışmadı).
Yeni yön: merak kancalı, bölüm bölüm ilerleyen hikâye; İngilizce kelime hikâyenin içinde ipucu
olarak geçer; "yorum yaz" isteği yok, yalnız "Devamı yarın".

Durum (2026-11-20): taslak. Üretim aracı seçilmedi; tüm promptlar araçtan bağımsız İngilizce.

## Sürüm notu (docs/SYNC.md)

Mağazada iOS 1.2.0 (36) yayında. 3. bölümde gösterilen kilit ekranı widget'ı ve kelime kartı
1.2.0'da var; yeni bir özellik gösterilmiyor. Android'den söz edilmez (herkese açık değil).

## Kelime kaynağı: önemli uyarı

Kelimeler ve Türkçe karşılıkları `Content/cards.json` içinden alındı. Brief'teki dayanak
kelimelerden **lock, hide, escape** ile eklediğim **inside** `cards.json` içinde YOK (kontrol edildi:
tek tek kelime kartı olarak yok). Bunlar aşağıda `*` ile işaretli. Seçenekler:
1. Lead bu dört kelimeyi `Content/` içine kart olarak ekler (örnek cümle + anlam), ya da
2. `*` kelimeler ekranda gösterilir ama "uygulamada" ima edilmez; anlamları standart sözlük
   karşılığıdır, yayından önce bir sözlükle doğrulanmalı.
Widget sahnesindeki kelime (**trust**) gerçek bir karttır (`b1-trust`, "güvenmek",
"I don't trust him." / "Ona güvenmiyorum.").

## Karakter kılavuzu

### Pirinç (konuşan asma kilit)

| | |
|---|---|
| Görünüm | Eski moda, tombul, yuvarlak gövdeli bir asma kilit; küçük bir buldog gibi omuzlu. Yarım ay şeklinde kulpu (shackle) başının üstünde bir kulak gibi hafif yana yatık. |
| Malzeme | Yıpranmış pirinç; yüzeyde hafif yeşil patina lekeleri, kenarlarda çizikler, anahtar deliği altında küçük bir pas damlası. Kulp çelik, mat gri. |
| Renk | Sıcak altın-pirinç (ana renk), yeşilimsi patina (yan lekeler), gri çelik kulp. Başka renk yok; tüm bölümlerde aynı. |
| Gözler | İki büyük, yuvarlak, çizgi film gözü: krem beyazı göz, iri siyah göz bebeği, kalın pirinç kaş kemeri. Duyguyu kaşlar taşır (şüpheli: tek kaş yukarı; korkmuş: kaşlar birleşik yukarı). |
| Ağız | Anahtar deliğinin hemen üstünde, gövdenin ortasında; küçük, esnek, kalın dudaklı bir ağız. Konuşurken yalnız ağız oynar, anahtar deliği sabit kalır. |
| Ses tonu | Hırıltılı, yaşlı ve huysuz bir amca sesi; sert konuşur ama içi yumuşak. Kısa cümleler, "Hmm." diye başlayan düşünme payı. Fısıldadığı yerlerde alçalır. Aynı ses profili 3 bölümde de kullanılır. |
| Kişilik | Koruyucu, inatçı, korkak ama bunu asla itiraf etmez. "Ben kapıyı bekliyorum, iş icabı." |

**Referans görsel promptu (İngilizce, araçtan bağımsız):**

> A single old-fashioned padlock character, chubby rounded body, weathered brass with soft green
> patina spots and small scratches, grey steel shackle tilted slightly like an ear, two large
> round cartoon eyes with cream whites, big black pupils and thick brass eyebrow ridges, a small
> flexible mouth with thick lips just above the keyhole, tiny rust drip under the keyhole.
> Hanging from a hasp on a dark wooden door in a dim stone basement corridor, warm side light,
> cinematic, shallow depth of field, soft film grain, vertical 9:16, front view, centered,
> neutral expression. Pixar-like but realistic metal texture. No text, no logo, no watermark.

Her klip için bu görseli **image-to-video başlangıç karesi** olarak kullan (tutarlılık için en
önemli adım). Araç görsel yüklemeyi desteklemiyorsa, her promptun başına karakter cümlesini
(aşağıdaki "SABİT BLOK") aynen yapıştır.

**SABİT BLOK (her prompta eklenir):**
`Pirinç: old chubby brass padlock with green patina, grey steel shackle tilted like an ear,
two large round cartoon eyes, small flexible mouth above the keyhole.`

### Elif (tek insan karakter)

Ekranda hiçbir zaman yüzü net görünmez: sırt, omuz, eller, ayakkabı, telefon. Böylece
tutarlılık sorunu çıkmaz. Yirmili yaşlarda, krem kazak, açık mavi kot, elinde telefon. Sesi:
sakin, meraklı bir genç kadın; Pirinç'ten daha yumuşak. Sabit blok:
`Elif (seen only from behind or hands): cream knit sweater, light blue jeans, dark hair in a low ponytail.`

### Mekân

Eski bir apartmanın bodrum koridoru: taş duvar, tek loş sarı lamba, koyu ahşap kapı, kapının
üstünde demir sürgü ve Pirinç. Üç bölümde aynı.

### Üretim kuralları (tüm klipler)

- Dikey 9:16, 5-8 sn, **tek eylem, tek kamera hareketi**. Videonun içinde yazı yok.
- Altyazı, İngilizce kelime kartı, Türkçe anlam ve kapak montajda eklenir.
- Ses: Türkçe seslendirme montajda (TTS ya da kayıt) eklenir; araçların kendi sesi/dudak
  eşlemesine güvenilmez. Ağız hareketi yalnız "konuşuyor" izlenimi verir.
- İlk 2 sn: logo yok, tanıtım yok; doğrudan garip görüntü + kanca cümlesi.
- Her klip, başarısız olursa, aynı promptla 2-3 kez üretilip en iyisi seçilir.

---

## Bölüm 1: "Üç Gündür Kilitli"

**Süre:** ~38 sn, 5 klip. **Kanca:** "Bu kapı üç gündür kilitli ve içeriden biri sesleniyor."

| # | Süre | Görsel prompt (EN) | Kamera | Türkçe seslendirme | Ekran yazısı |
|---|---|---|---|---|---|
| 1 | 7 sn | Dim stone basement corridor, a dark wooden door shut with a brass padlock. From behind the door, three soft knocks make the padlock shake. The padlock's eyes snap open and stare at the camera. [SABİT BLOK] | Yavaş itme (slow push-in) kapıya | Pirinç: "Bu kapı üç gündür kilitli ve içeriden biri sesleniyor." | "3 gündür kilitli" (üstte, 1. saniyeden); altta "door = kapı" |
| 2 | 8 sn | Over-the-shoulder shot of Elif, seen from behind, holding a phone flashlight in the dim corridor, approaching the door with the padlock. The padlock's eyebrows raise suspiciously. [SABİT BLOK] | Omuz üstü, hafif sallantılı elde çekim | Pirinç: "Sen kimsin? Bu koridora kimse inmez." Elif: "Sesi duydum. Birisi orada." | "listen = dinlemek" (Elif "dinle" derken) |
| 3 | 7 sn | Close-up of the padlock turning its eyes toward the dark gap under the door, where a faint warm light flickers. The padlock's mouth tightens. [SABİT BLOK] | Sabit, yakın plan; ışık titrer | Pirinç: "Dinle. Üç kere vurur, sonra susar. Hep aynı." | "lock = kilit *" |
| 4 | 8 sn | Elif's hands knock on the wooden door twice; from the other side, two knocks answer. The padlock shakes and its eyes widen. [SABİT BLOK] | Eller ve kilit aynı kadrajda, hafif yaklaşma | Elif: "Anahtarı nerede? Bulalım!" Pirinç: "Hmm. Bulamazsın." | "key = anahtar", "find = bulmak" |
| 5 | 8 sn | Extreme close-up of the padlock keyhole as the padlock whispers; inside the dark keyhole a tiny glint of a brass key tip is visible. [SABİT BLOK] | Çok yavaş yakınlaşma (macro push-in) anahtar deliğine | Pirinç (fısıltı): "Anahtar... kilidin içinde." | "Devamı yarın" (son 2 sn, sade) |

**İngilizce kelimeler (Türkçe):**
- door = kapı (kart `a1-door`; "Please close the door." / "Lütfen kapıyı kapat.")
- listen = dinlemek (kart `a1-listen`)
- key = anahtar (kart `a1-key`; "Do you have the key?" / "Anahtar sende mi?")
- find = bulmak (kart `a2-find`; "I can't find my keys." / "Anahtarlarımı bulamıyorum.")
- lock = kilit; kilitlemek *(kartta yok, bkz. uyarı)*

Kelimelerin hikâyedeki rolü: **key** ve **lock** ipucudur (anahtar kilidin içinde); **listen**
Elif'in ilk yaptığı iştir (sesi duymak). Ekran kartı o kelime söylendiği anda belirir, 1,5 sn
kalır; kart: büyük İngilizce kelime + altında Türkçe anlam.

**Cliffhanger:** "Anahtar kilidin içinde." Anahtar deliğinde pirinç bir anahtar ucu parlar;
anahtar kilidin dışında değil, içinde.

**Kapanış (CTA):** ekranda "Devamı yarın". Sesli CTA yok, "yorum yaz / takip et" yok.

**Açıklama (caption):**
> Bu kapı üç gündür kilitli ve içeriden biri sesleniyor.
>
> Kilit konuşuyor ama anahtarın nerede olduğunu söylemiyor. Yapay zekâ ile üretilen
> mini dizi, 1/3. Devamı yarın.
>
> #kilitlikapı #yapayzeka #ingilizcekelime #minidizi

**Kapak karesi:** Pirinç'in gözleri açık, kapı aralığından sarı ışık sızıyor; üstte büyük
"3 GÜNDÜR KİLİTLİ" yazısı; altta küçük "1/3".

**Yapay zekâ etiketi:** Instagram'da "AI info" / yapay zekâ ile üretildi etiketini aç
(Paylaşım ayarları > Daha fazla seçenek > Yapay zekâ etiketi). Açıklamaya "Yapay zekâ ile
üretildi" yazılır (yukarıda geçiyor). Görseller ve klipler gerçek kişi içermiyor.

---

## Bölüm 2: "Kilit Neyi Saklıyor?"

**Süre:** ~40 sn, 5 klip. **Kanca:** "Kilit bana yalan söyledi. Anahtar hiç kaybolmamıştı."
(Bölüm 1'den takip eden izleyici için; yeni izleyici bu cümleyle de ilk 2 saniyede hikâyeye girer.)

| # | Süre | Görsel prompt (EN) | Kamera | Türkçe seslendirme | Ekran yazısı |
|---|---|---|---|---|---|
| 1 | 6 sn | Close-up of the padlock keyhole, a small glowing key tip shining from inside, then the padlock's big eyes look away guiltily. [SABİT BLOK] | Sabit, yakın plan | Elif: "Anahtar hiç kaybolmamış. Sen onu yutmuşsun." | "Anahtar kaybolmadı" (1. saniye); "key = anahtar" |
| 2 | 8 sn | Padlock looking down in shame, the shackle drooping, Elif's hand resting gently near it in the dim corridor. [SABİT BLOK] | Hafif aşağıdan yukarı (tilt up) kilitten Elif'in eline | Pirinç: "Onu sakladım. Üç gün önce içeriden biri bana geldi." | "hide = saklamak *" |
| 3 | 8 sn | Padlock whispering toward the camera, behind it the wooden door seems to breathe, a thin crack of warm light along its edge. [SABİT BLOK] | Yavaş yana kayma (slow dolly right) | Pirinç: "İçeride biri var. Dışarı çıkmak istiyor ama dışarısı güvenli değil." | "safe = güvenli"; "inside = içinde *" |
| 4 | 8 sn | Padlock's eyes wet and shaking, a small tear of oil rolling down the brass; behind it a shadow moves under the door. [SABİT BLOK] | Sabit, çok yakın | Pirinç: "Korkuyorum. Açarsam... bir daha kapatamam." | "afraid = korkmuş" |
| 5 | 8 sn | A folded paper note slides slowly out from under the door onto the stone floor, Elif's shoes step back in the frame. | Zemin seviyesinde sabit kamera | Elif (kısık): "Bir not." Pirinç: "Okuma!" | "Devamı yarın" |

**İngilizce kelimeler (Türkçe):**
- key = anahtar (tekrar; kart `a1-key`)
- hide = saklamak *(kartta yok)*
- safe = güvenli (kart `b1-safe`; "It is safe to walk at night." / "Gece yürümek güvenli.")
- afraid = korkmuş, korkan (kart `a2-afraid`; "Are you afraid of the storm?" / "Fırtınadan korkuyor musun?")
- inside = içinde *(kartta yok)*

Hikâyedeki rolü: **hide** sır; **safe** Pirinç'in saklama nedeni; **afraid** onun asıl duygusu.
Bu bölümde Elif kelimeyi bilmiyor gibi oynar: "Saklamak İngilizce'de neydi?" diye sorma sahnesi
istenirse klip 2'de Pirinç "hide" der, kart gelir.

**Cliffhanger:** Kapının altından bir not çıkıyor; ne yazdığı gösterilmez.

**Açıklama:**
> Kilit bana yalan söyledi: anahtar hiç kaybolmamıştı.
>
> Pirinç korkuyor ve içerideki biri not gönderdi. Yapay zekâ ile üretilen mini dizi, 2/3.
> Devamı yarın.
>
> #kilitlikapı #yapayzeka #ingilizcekelime #minidizi

**Kapak karesi:** Pirinç'in gözleri yaşlı, altında yerdeki katlanmış not; üstte "YALAN SÖYLEDİ"; altta "2/3".

**Yapay zekâ etiketi:** Bölüm 1 ile aynı; AI etiketi açık, açıklamada "Yapay zekâ ile üretildi".

---

## Bölüm 3: "Şifre"

**Süre:** ~42 sn, 6 klip. **Kanca:** "Notta tek bir kelime yazıyordu ve ben o kelimeyi bilmiyordum."

| # | Süre | Görsel prompt (EN) | Kamera | Türkçe seslendirme | Ekran yazısı |
|---|---|---|---|---|---|
| 1 | 6 sn | Close-up of a folded paper note being opened by hands in dim light; a single handwritten word is on it but the paper is tilted so the word is not readable. | Omuz üstü, yavaş yaklaşma | Elif: "Notta tek kelime var. Bilmiyorum bile." | Üstte "Tek kelime. Bilmiyorum." (1. sn) |
| 2 | 7 sn | Padlock with arms-crossed expression (eyebrows low), stubborn, shackle straight, looking at the note. [SABİT BLOK] | Sabit orta plan | Pirinç: "Ben yalnız bir kelimeyle açılırım. İngilizce. Ona gerçekten inanan biri söylemeli." | "believe = inanmak" |
| 3 | 7 sn | Elif's hand pulls out a phone; the dark screen lights up in the corridor, glow on the padlock's surprised face. [SABİT BLOK] | Omuz üstü, telefon ekranına yaklaşma | Elif: "Telefonumun kilit ekranında bir kelime var. Sabah beri duruyor." | (kısa) telefon görüntüsü montajda eklenir, bkz. aşağıdaki not |
| 4 | 8 sn | Phone (real screen capture is composited in the edit, the generated clip shows the phone from behind with its glow) held toward the padlock; padlock reads, eyes slowly widening. [SABİT BLOK] | Kilidin gözünden telefona (point-of-view) | Pirinç (yavaş): "Trust. Güvenmek..." | **Kart:** "trust = güvenmek" |
| 5 | 8 sn | Padlock closes its eyes, takes a breath, the shackle springs open with a small spark; the brass key slides out of the keyhole and falls into Elif's palm. [SABİT BLOK] | Kilit sabit; yavaş yakınlaşma | Pirinç: "Sana güveniyorum. Aç." | "open = açmak"; "trust" kartı küçük köşede |
| 6 | 7 sn | The wooden door swings slowly open into a dark room; inside, on the floor, a second tiny padlock with bright eyes looks up at the camera, shackle wiggling. The same warm light as before. | Kapı açılırken yavaş itme (push-in) | Küçük ses: "Üç gündür seni bekliyordum, abi." Pirinç: "...Minik?" | "Devamı yarın" |

**Not: telefon sahnesi.** Klip 3-4'te telefonun ekranı yapay zekâ ile çizilmez. Gerçek bir
uygulama ekran görüntüsü / ekran kaydı (kilit ekranı widget'ında **trust** kartı) montajda
klibin üstüne yerleştirilir. `marketing/instagram/shots/` içinde şu an kilit ekranı görüntüleri
var (`kilit-2.png`, `kilit-3.png`, `kilit-kart.png` vb.) ama bunların hangisinde "trust"
gösterildiğini doğrulamadım. **Kullanıcının getireceği:** kilit ekranında *trust / güvenmek*
kartını gösteren bir ekran görüntüsü. Yoksa elle çizilmez; bu sahne bekler.

**İngilizce kelimeler (Türkçe):**
- believe = inanmak (kart `a2-believe`; "I don't believe this story." / "Bu hikâyeye inanmıyorum.")
- trust = güvenmek (kart `b1-trust`; "I don't trust him." / "Ona güvenmiyorum.") **ana ipucu**
- open = açmak (kart `a1-open`; "Open the door, please." / "Kapıyı aç lütfen.")
- escape = kaçmak *(kartta yok; klip 6'da Minik: "Ben kaçmak istemedim, sadece dışarı çıkmak istedim." diye
  kullanılabilir, istenirse çıkarılır)*

Hikâyedeki rolü: **trust** bulmacanın çözümü; kelimeyi Elif bilmez ama widget'taki kart ona
öğretir; uygulama yalnızca bu bir sahnede (klip 3-4, toplam ~8 sn), reklam dili yok, uygulama
adı seslendirilmez. Ekranda uygulamanın adı için küçük bir alt köşe etiketi yeterli
("Kilit Kelime" yazısı kartın üzerinde zaten görünüyorsa ayrıca eklenmez).

**Cliffhanger / dizi sonu:** Kapı açılır, içeride Minik: ikinci küçük bir kilit. Pirinç saklıyordu
çünkü Minik'in dışarıdaki dünyaya karışmasından korkuyordu. Pilot burada biter ve yeni sezon
için kapı açık bırakılır. Bölüm 3'ün CTA'sı: "Devamı yarın" yerine, pilot sonucuna göre,
"Yeni bölümler gelecek" de olabilir (bkz. ölçüm planı).

**Açıklama:**
> Notta tek bir kelime vardı ve ben o kelimeyi bilmiyordum.
>
> Kilitli kapının sırrı: Pirinç ve Minik. Yapay zekâ ile üretilen mini dizi, 3/3.
> Devamı yarın.
>
> #kilitlikapı #yapayzeka #ingilizcekelime #minidizi

**Kapak karesi:** Telefonun parlak ekranı Pirinç'in şaşkın yüzünde yansıyor; üstte büyük
"TRUST?" ve altında küçük "3/3".

**Yapay zekâ etiketi:** AI etiketi açık, açıklamada "Yapay zekâ ile üretildi". Telefon
görüntüsü gerçek ekran görüntüsüdür; AI ile üretilmemiş kısmı doğru ayırt etmek için
açıklamada ayrıca belirtmek gerekmez, etiket tüm Reels'e uygulanır.

---

## Doğrulanacak kaynaklar

- Kelime kartlarındaki anlamlar ve örnek cümleler: `Content/cards.json` (`a1-door`, `a1-key`,
  `a1-open`, `a1-listen`, `a2-find`, `a2-afraid`, `a2-believe`, `b1-safe`, `b1-trust`); kontrol edildi.
- `lock`, `hide`, `escape`, `inside` kartlarda yok; Türkçe anlamları sözlükle doğrulanacak ya da
  kart olarak eklenecek (lead).
- Instagram yapay zekâ etiketi menüsünün adı ve yeri: telefondan doğrulanacak (arayüz değişebilir).
- Dizi biçiminin ("konuşan nesne") trend olduğu bilgisi araştırmadan (researcher) geldi; ben
  doğrulamadım, bir sayı ya da iddia olarak yayında kullanılmıyor.
- Hiçbir üretim aracının ücretsiz kotası/süre sınırı doğrulanmadı; araç seçilince kontrol edilir.

## Ölçüm planı

**Başarı (3. bölüm sonrası):** her bölümde **1.000+ görüntülenme** ve takipçi olmayanlardan
**yorum ya da takip**. Geçmiş en iyi Reels: 454 görüntülenme; bu yüzden 1.000 hedefi gerçek bir
sıçrama demek.

**Zamanlama (mevcut yuvalar 12:30 ve 20:30):**
- 3 bölüm 3 ardışık günde paylaşılır; her gün **20:30** (akşam izleme, "yarın" cliffhanger'ı
  doğal oturur). Alternatif test: bölüm 1 20:30, bölüm 2 12:30, bölüm 3 20:30; böylece iki
  yuva tek seferde karşılaştırılır. Tek değişken olsun diye önce yalnız 20:30, sonra yalnız 12:30
  seçmek daha temiz, ama pilotta 3 gün yetmeyebilir; Insights'a göre karar ver.
- Bölüm 2 ve 3'ün bir önceki bölümü izleyenlere nasıl ulaştığı (profilden mi, öneriden mi)
  Insights'ta "Takipçi olmayanlar" yüzdesinden okunur.

**Insights'tan okunacaklar (her bölüm, 24 sa ve 72 sa):**
1. Görüntülenme ve erişim; takipçi olmayan yüzdesi.
2. Ortalama izlenme süresi ve ilk 3 sn atlama oranı (kanca testi).
3. Paylaşım (send) ve kaydetme sayıları; bunlar beğeniden daha önemli.
4. "Bu Reels'ten gelen takipçi" ve profil ziyareti.
5. Bölüm 1 -> 2 -> 3 arasında izleme düşüşü (dizi devam ettiriyor mu?).

**Karar:**
- Bölümlerin çoğu 1.000+ ve dışarıdan yorum/takip geliyorsa: dizi sürer, 2. sezon (Minik ile).
- 1. bölüm yüksek, 2-3 düşükse: bölüm kancaları zayıf; bölüm başlarına bağımsız kanca ekle.
- 1. bölümün ilk 3 sn atlama oranı yüksekse: kanca görseli değişir (Pirinç'in gözleri
  daha erken açılsın, ışık daha güçlü olsun).
- Hepsi 500 altındaysa: biçim çalışmıyor; eğitim Reels'lerine dön, gerçek kullanıcı verisini
  bekle.

**Yorum davranışı:** "yoruma yaz" isteği yok. Yorumlara bir cevap verilecekse: tahmin soruları
(örn. "kapının arkasında kim var?") izleyicinin kendiliğinden yazdığı yorumlar olursa yanıtla,
kendin sorma.

## Üretim yolu (araştırma, 2026-11-20; ücretsiz kotaların çoğu doğrulanmadı)

1. **Referans görsel:** Gemini ya da ChatGPT ücretsiz, yukarıdaki referans promptuyla tek görsel.
   Her klipte bu görsel image-to-video başlangıç karesi olur (karakter tutarlılığı).
2. **Klipler:** Dreamina (CapCut) Seedance image-to-video, ücretsiz günlük kredi (ABD'de 120/gün;
   Türkiye doğrulanmadı), filigranlı. Yetmezse Kling Standard (~10 $/ay, filigransız, ticari).
   15-18 klip ücretsiz krediyle ~2-3 gün.
3. **Ses:** Azure Speech ücretsiz katman (ayda 0,5M karakter), Türkçe nöral ses (AhmetNeural).
   ElevenLabs ücretsiz katman ticari kullanıma kapalı; kaliteli ses istenirse Starter 6 $/ay.
4. **Ağız:** AI lip-sync yerine CapCut'ta 2-3 karelik ağız katmanı.
5. **Kurgu ve altyazı:** Instagram Edits ya da CapCut, ücretsiz.

Toplam: 0 $ (ücretsiz kotalar yeterse), en fazla ~16-25 $.
