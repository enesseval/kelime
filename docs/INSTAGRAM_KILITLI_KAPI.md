# Kilitli Kapı: 6 bölümlük pilot dizi

Yapay zekâ ile üretilen, "konuşan nesne" biçiminde dizi. Eğitim Reels'leri yalnız yakın çevreye
ulaştı (200-450 görüntülenme, dışarıdan yorum/takip yok, "yoruma KELİME yaz" CTA'sı çalışmadı).
Yeni yön: merak kancalı, bölüm bölüm ilerleyen hikâye; İngilizce kelime hikâyenin içinde ipucu
olarak geçer; "yorum yaz" isteği yok, yalnız "Devamı ...".

Durum (2026-11-20): kullanıcı kararı verildi. 6 bölüm, 3 günde (günde 2: 12:30 ve 20:30),
21.11 - 23.11. Değerlendirme 24.11. Araçlar sabit: Kling Standard (image-to-video) + ElevenLabs
Starter (Türkçe ses) + CapCut / Instagram Edits (kurgu).

## Sürüm notu (docs/SYNC.md)

Mağazada iOS 1.2.0 (36) yayında. Uygulama dizide toplam **iki kısa sahnede** görünür: 3. bölümde
kilit ekranı widget'ında **trust** kartı, 6. bölümde **promise** kartı (her biri ~3-4 sn, gerçek
ekran görüntüsü, reklam dili yok). İkisi de 1.2.0'daki kilit ekranı widget'ıdır; yeni özellik
gösterilmiyor. Android'den söz edilmez (herkese açık değil).

## Hikâye yayı (6 bölüm, tek hikâye)

Gizem: bodrumdaki kapıyı üç gündür kim, neden kilitli tutuyor ve içeriden kim vuruyor?

| Bölüm | Gün / saat | Ad | Ne olur |
|---|---|---|---|
| 1 | 21.11 12:30 | Üç Gündür Kilitli | Kapı üç gündür kilitli, içeriden vuruluyor. Pirinç konuşuyor: "Anahtar kilidin içinde." |
| 2 | 21.11 20:30 | Kilit Neyi Saklıyor? | Anahtar kaybolmamış, Pirinç saklamış; korkuyor. Kapının altından not çıkar. |
| 3 | 22.11 12:30 | Şifre | Notta bir kelime: **trust**. Pirinç güvenir, kapı açılır; içeride ikinci küçük kilit: Minik. |
| 4 | 22.11 20:30 | Minik | Minik Pirinç'in kardeşi. Pirinç onu "korumak için" kilitlemiş; üç gece önce biri anahtar halkasıyla gelmiş. Merdivenden ses gelir. |
| 5 | 23.11 12:30 | Kapıcı | Karanlıkta kapıcının gölgesi ve anahtar halkası. Kapıyı açmaya çalışır; Elif saklandığı yerden çıkar. |
| 6 | 23.11 20:30 | Söz | Çözüm: Kapıcı Minik'in çatlak kulpunu tamir etmeye gelmiş, anlatmayı unutmuş; Pirinç yanlış kişiden korkuyormuş. Söz verilir, kapı açılır. Son: duvarın ardından 4 kere vurulur, "üçüncü kilit hâlâ kayıp" (2. sezon kancası). |

Kurallar: Her bölüm izleyiciye "bağımsız" da çalışır (bkz. Önceki bölümde satırı). Kapıcı'nın yüzü
hiç görünmez (gölge, el, anahtar halkası, kol). Elif'in yüzü de görünmez.

## Sabit kurallar: her bölüm için

**İlk 2 saniye + "Önceki bölümde" satırı.** 1. klibin ekran yazısı iki katmanlıdır:
1. Üstte, 0. saniyeden büyük **kanca yazısı** (3-5 sözcük).
2. Altta, 0,5. saniyeden küçük, tek satır **"Önceki bölümde: ..."** (en çok 8-9 sözcük).
Kanca görüntü + kanca yazısıdır; özet satırı kancayı gölgelememeli (küçük, yarı saydam arka plan).
Bölüm 1'de özet satırı yok.

**Kapanış.** Sesli CTA yok, "yorum yaz / takip et" yok. Yalnız ekran yazısı ("Devamı bu akşam
20:30" gibi). 6. bölümde "Dizi bitmedi".

**Profil.** 1. bölüm profilde sabitlenir (Reels'i profile sabitle) ki 4-6. bölüme gelen yeni
izleyici başa dönebilsin. Menü adı telefondan doğrulanacak.

**AI etiketi.** Her bölümde Instagram'da yapay zekâ etiketi açılır (Paylaşım ayarları > Daha
fazla seçenek > Yapay zekâ etiketi; menü adı telefondan doğrulanacak). Açıklamaya "Yapay zekâ ile
üretildi" yazılır. Görseller ve klipler gerçek kişi içermez. Telefon görüntüsü (3. ve 6. bölüm)
gerçek ekran görüntüsüdür; etiket tüm Reels'e uygulanır, ayrıca belirtmek gerekmez.

## Kelime kaynağı

Kelimeler ve Türkçe karşılıkları `Content/cards.json` içinden alındı (kontrol edildi).
`*` = kartta YOK: **lock, hide, inside, escape**. Seçenekler: (1) lead bunları `Content/`
içine kart olarak ekler; ya da (2) ekranda gösterilir ama "uygulamada" ima edilmez; anlamlar
standart sözlük karşılığıdır, yayından önce sözlükle doğrulanır.

Kullanılan kartlar: `a1-door`, `a1-key`, `a1-open`, `a1-listen`, `a2-find`, `a2-afraid`,
`a2-believe`, `b1-safe`, `b1-trust`, `a1-brother` (erkek kardeş, abi), `a1-small` (küçük),
`a2-remember` (hatırlamak), `a2-wait` (beklemek), `a2-light` (ışık), `a2-bring` (getirmek),
`a2-leave` (ayrılmak, çıkmak), `a1-stay` (kalmak), `a2-forget` (unutmak), `a2-promise`
(söz vermek), `b1-lost` (kayıp, kaybolmuş), `a1-last` (geçen, son).
`free` bilerek kullanılmadı: kartta "müsait, boş / ücretsiz" var, "özgür" yok.

## Karakter kılavuzu

### Pirinç (konuşan asma kilit)

| | |
|---|---|
| Görünüm | Eski moda, tombul, yuvarlak gövdeli bir asma kilit; küçük bir buldog gibi omuzlu. Yarım ay şeklinde kulpu (shackle) başının üstünde bir kulak gibi hafif yana yatık. |
| Malzeme | Yıpranmış pirinç; hafif yeşil patina lekeleri, kenarlarda çizikler, anahtar deliği altında küçük bir pas damlası. Kulp çelik, mat gri. |
| Renk | Sıcak altın-pirinç (ana renk), yeşilimsi patina, gri çelik kulp. Başka renk yok; tüm bölümlerde aynı. |
| Gözler | İki büyük, yuvarlak, çizgi film gözü: krem beyazı göz, iri siyah göz bebeği, kalın pirinç kaş kemeri. Duyguyu kaşlar taşır (şüpheli: tek kaş yukarı; korkmuş: kaşlar birleşik yukarı). |
| Ağız | Anahtar deliğinin hemen üstünde; küçük, esnek, kalın dudaklı. Konuşurken yalnız ağız oynar. |
| Kişilik | Koruyucu, inatçı, korkak ama bunu asla itiraf etmez. "Ben kapıyı bekliyorum, iş icabı." |

### Minik (3. bölümden itibaren)

Pirinç'in küçük kardeşi: aynı pirinç ve patina, ama avuç içi büyüklüğünde, gözler orantısız
büyük ve parlak, kulbunda ince bir çatlak (6. bölümün nedeni, 3-4. bölümde hafifçe görünür).
Neşeli, meraklı. Pirinç'e "abi" der.

### Elif (tek insan karakter)

Yüzü hiç net görünmez: sırt, omuz, eller, ayakkabı, telefon. Yirmili yaşlarda, krem kazak, açık
mavi kot, koyu saç alçak at kuyruğu. Sakin, meraklı genç kadın.

### Kapıcı (5. bölümden itibaren)

Yüzü hiç görünmez: gölge, buruşuk eller, eski ceket kolu, sallanan büyük anahtar halkası,
fener. Yaşlı, yorgun, yumuşak ses.

### Mekân

Eski bir apartmanın bodrum koridoru: taş duvar, tek loş sarı lamba, koyu ahşap kapı, kapının
üstünde demir sürgü ve Pirinç. Koridorun sonunda üst kata çıkan taş merdiven. Kapının arkasında
karanlık oda (3. bölümden).

## Referans görseller (Kling başlangıç kareleri)

Kling image-to-video her klipte bir **başlangıç karesi** ister; karakter tutarlılığı buradan
gelir. Aşağıdaki görselleri bir görsel üreticiyle (Gemini / ChatGPT) tek seferde, hep aynı
Pirinç referansından türeterek üret; her biri 9:16.

| Kod | İçerik | Kullanıldığı bölüm |
|---|---|---|
| R1 | Pirinç kapıda, nötr yüz, koridor (ana referans, aşağıdaki prompt) | 1, 2, 3, 5 |
| R2 | Pirinç yakın plan: korkmuş / utanmış yüz (kaşlar birleşik, kulp düşük) | 2, 4, 6 |
| R3 | Elif arkadan, elinde telefon el feneri, kapıya yaklaşıyor | 1, 2, 3, 5, 6 |
| R4 | Anahtar deliği makro (ucunda altın parıltı) | 1, 2 |
| R5 | Kapı aralık, arkasında karanlık oda ve yerde Minik | 3, 4, 6 |
| R6 | Minik yakın plan (avuç içi ölçeği, çatlak kulp) | 3, 4, 6 |
| R7 | Koridor sonu, merdiven boşluğu, duvarda el gölgesi + anahtar halkası | 4, 5, 6 |
| R8 | Elif'in eli ve katlanmış not (yazı okunmaz) | 2, 3 |

**Ana referans promptu (R1, İngilizce):**

> A single old-fashioned padlock character, chubby rounded body, weathered brass with soft green
> patina spots and small scratches, grey steel shackle tilted slightly like an ear, two large
> round cartoon eyes with cream whites, big black pupils and thick brass eyebrow ridges, a small
> flexible mouth with thick lips just above the keyhole, tiny rust drip under the keyhole.
> Hanging from a hasp on a dark wooden door in a dim stone basement corridor, warm side light,
> cinematic, shallow depth of field, soft film grain, vertical 9:16, front view, centered,
> neutral expression. Pixar-like but realistic metal texture. No text, no logo, no watermark.

### R2-R8 nasıl üretilir (adım adım)

1. ChatGPT ya da Gemini'de **yeni bir sohbet** aç, **R1 görselini yükle**.
2. Aşağıdaki promptlardan birini yapıştır. Her biri R1'e bakarak aynı karakteri ve aynı mekânı
   yeniden çizer (sıfırdan üretmek yerine "düzenleme" gibi çalışır; tutarlılık buradan gelir).
3. Çıkan görseli indir, `R2.png` … `R8.png` diye adlandır. Beğenmezsen aynı sohbette
   "aynısını yap ama …" diye düzelt.
4. Her yeni görselde yine **R1'i yükleyerek** başla (zincirleme bozulmasın diye R2'den R3
   türetme). Yalnız R6 (Minik) için R1 ve R5'i birlikte yükleyebilirsin.
5. Kontrol: pirinç rengi, yeşil patina, göz büyüklüğü, kulp eğimi R1 ile aynı mı? Değilse
   tekrar üret.

Her promptun sonu aynı: *Vertical 9:16. Same lighting, same art style and same materials as the
reference. No text, no logo, no watermark.*

**R2 (Pirinç, korkmuş/utanmış yakın plan):**
> Use the padlock character from the attached image exactly as it is: same brass colour, same
> green patina spots, same eyes, same mouth. Close-up of its face only, filling the frame. Its
> eyebrows are pressed together and raised in fear, the eyes look down and away in shame, the
> mouth is a small worried line, the steel shackle droops lower than in the reference. Same dark
> wooden door and warm side light behind it, softly out of focus. Vertical 9:16. Same lighting,
> same art style and same materials as the reference. No text, no logo, no watermark.

**R3 (Elif arkadan, telefon ışığıyla kapıya yaklaşıyor):**
> Same basement corridor and same wooden door with the same padlock character from the attached
> image, seen from further back. In the foreground, a young woman seen only from behind, over the
> shoulder (her face is never visible): dark hair in a loose bun, an oversized beige hoodie,
> holding a smartphone with its flashlight on, pointing at the door. The flashlight beam lights up
> the padlock, which looks at her suspiciously with one eyebrow raised. Vertical 9:16. Same
> lighting, same art style and same materials as the reference. No text, no logo, no watermark.

**R4 (anahtar deliği makro):**
> Extreme macro close-up of the keyhole of the padlock character from the attached image: the
> same weathered brass, the same green patina and the small rust drip under the keyhole. Deep
> inside the dark keyhole, a tiny golden glint of a brass key tip catches the light. The bottom
> of the padlock's mouth is just visible at the top edge of the frame. Vertical 9:16. Same
> lighting, same art style and same materials as the reference. No text, no logo, no watermark.

**R5 (kapı aralık, içeride karanlık oda ve yerde Minik):**
> The same wooden door from the attached image, now half open into a dark small storage room.
> The padlock character from the reference hangs open on the hasp, its shackle unlocked, looking
> into the room in surprise. On the dusty stone floor inside the room, in a soft beam of light,
> sits a much smaller padlock character (palm-sized, the same brass style but shinier and newer,
> big round eyes, a thin crack on its tiny shackle) looking up toward the door. Vertical 9:16.
> Same lighting, same art style and same materials as the reference. No text, no logo, no
> watermark.

**R6 (Minik yakın plan):**
> Close-up of the small padlock character from the second attached image (palm-sized little
> brother of the padlock in the first image): the same brass style but shinier and less worn,
> very large round shiny eyes, a tiny mouth, and a visible thin crack on its small steel shackle.
> It sits on dusty stone floor, looking up at the camera with hope. Low camera angle, soft warm
> light from above. Vertical 9:16. Same lighting, same art style and same materials as the
> reference. No text, no logo, no watermark.

**R7 (merdiven boşluğu, duvarda el gölgesi ve anahtar halkası):**
> The far end of the same dim stone basement corridor from the attached image: old stone stairs
> going up into darkness. On the stone wall beside the stairs, the large shadow of an old hand
> holding a heavy ring of many old keys, cast by a lantern out of frame. No person visible, only
> the shadow. The corridor lamp flickers. Moody, cinematic, slightly cold light mixed with warm
> lantern glow. Vertical 9:16. Same lighting, same art style and same materials as the
> reference. No text, no logo, no watermark.

**R8 (Elif'in eli ve katlanmış not):**
> Close-up at floor level in front of the same wooden door from the attached image. A young
> woman's hand (sleeve of an oversized beige hoodie visible) is picking up a small folded piece of
> old paper from the stone floor; the paper has slipped out from under the door. The writing on
> the paper is hidden by the fold and not readable. The bottom of the door and a sliver of warm
> light under it are visible. Vertical 9:16. Same lighting, same art style and same materials
> as the reference. No text, no logo, no watermark.

**İpucu:** Kapıcı (5-6. bölüm) için ayrı referans yok; yüzü hiç görünmüyor. Klipte R7 ya da R1
başlangıç karesi olur, eller ve gölge Kling promptuyla gelir. Görselde yazı çıkarsa (nota harf,
duvara yazı) "remove all text" diye düzelt; yazılar montajda eklenir.

## Kling promptu nasıl yazılır (image-to-video)

- **Başlangıç karesi seç, promptta karakteri tarif etme.** Prompt yalnız *hareketi* söyler.
  Eski "SABİT BLOK" artık kullanılmaz (görsel zaten karakteri taşıyor).
- **Tek eylem, tek kamera hareketi.** Bir cümle: özne + tek fiil + tek kamera + ışık. En çok
  ~40 sözcük.
- **Süre:** Kling'de 5 sn ya da 10 sn seçenekleri var (uygulamada doğrula); varsayılan **5 sn**,
  montajda 3-5 sn'e kırp. 10 sn yalnız yavaş yaklaşmalarda ve 2x kredi harcar. Sınır: 10 sn.
- **Kapalı kalacaklar:** videonun içinde yazı yok; yüz değişimi yok; kamera tek yönde.
- **Negatif prompt (varsa) her klipte:** `text, watermark, logo, extra eyes, extra limbs,
  morphing, deformed, fast cuts, camera shake`.
- **Ağız:** Kling'in ses/dudak eşlemesi kullanılmaz; ağız hareketi yalnız "konuşuyor" izlenimi.
  Ses montajda eklenir.
- Her klip 2-3 kez üretilir, en iyisi seçilir; karakter yüzü kayarsa promptu kısalt ya da
  başlangıç karesini değiştir.

---

## Bölüm 1: "Üç Gündür Kilitli"

**Yayın:** 21.11 (Cumartesi) 12:30. **Süre:** ~28 sn, 5 klip. **Kanca:** "Bu kapı üç gündür
kilitli ve içeriden biri sesleniyor."

| # | Süre | Kling promptu (EN) | Kamera | Türkçe seslendirme | Ekran yazısı |
|---|---|---|---|---|---|
| 1 | 5 sn | Start: R1. Three soft knocks from behind the door make the padlock shake, its eyes snap open and stare at the camera. | Yavaş itme (slow push-in) | Pirinç: "Bu kapı üç gündür kilitli ve içeriden biri sesleniyor." | Üstte "3 GÜNDÜR KİLİTLİ" (0. sn); altta "door = kapı" |
| 2 | 5 sn | Start: R3. The girl walks slowly toward the door with the phone light, the padlock raises one eyebrow suspiciously. | Omuz üstü, hafif elde | Pirinç: "Sen kimsin? Bu koridora kimse inmez." Elif: "Sesi duydum." | "listen = dinlemek" |
| 3 | 5 sn | Start: R1 (yakın). The padlock turns its eyes toward the dark gap under the door where a warm light flickers, its mouth tightens. | Sabit, yakın plan | Pirinç: "Dinle. Üç kere vurur, sonra susar." | "lock = kilit *" |
| 4 | 5 sn | Start: R3 (eller kadrajda). Two hands knock twice on the wooden door, the padlock shakes and its eyes widen. | Eller ve kilit aynı kadrajda, hafif yaklaşma | Elif: "Anahtarı nerede? Bulalım!" Pirinç: "Hmm. Bulamazsın." | "key = anahtar"; "find = bulmak" |
| 5 | 5 sn (10 sn seçilebilir) | Start: R4. Macro push-in into the dark keyhole, a tiny glint of a brass key tip shines inside. | Çok yavaş macro yaklaşma | Pirinç (fısıltı): "Anahtar... kilidin içinde." | "Devamı bu akşam 20:30" (son 2 sn, sade) |

**Kelimeler:** door (`a1-door`), listen (`a1-listen`), key (`a1-key`), find (`a2-find`), lock *.
**Cliffhanger:** anahtar kilidin dışında değil, içinde.

**Açıklama:**
> Bu kapı üç gündür kilitli ve içeriden biri sesleniyor.
>
> Kilit konuşuyor ama anahtarın nerede olduğunu söylemiyor. Yapay zekâ ile üretildi. 1/6.
> Devamı bu akşam 20:30.
>
> #kilitlikapı #yapayzeka #ingilizcekelime #minidizi

**Kapak:** Pirinç'in gözleri açık, kapı aralığından sarı ışık sızıyor; üstte "3 GÜNDÜR KİLİTLİ";
altta küçük "1/6". **AI etiketi:** açık.

---

## Bölüm 2: "Kilit Neyi Saklıyor?"

**Yayın:** 21.11 20:30. **Süre:** ~28 sn, 5 klip. **Kanca:** "Kilit bana yalan söyledi. Anahtar
hiç kaybolmamıştı."

| # | Süre | Kling promptu (EN) | Kamera | Türkçe seslendirme | Ekran yazısı |
|---|---|---|---|---|---|
| 1 | 5 sn | Start: R4. The keyhole glows from inside, then the padlock's big eyes look away guiltily. | Sabit, yakın | Elif: "Anahtar hiç kaybolmamış. Sen onu yutmuşsun." | Üst: "KİLİT YALAN SÖYLEDİ"; alt: "Önceki bölümde: kapı 3 gündür kilitli, anahtar kilidin içinde"; "key = anahtar" |
| 2 | 5 sn | Start: R2. The padlock lowers its gaze in shame, the shackle droops slowly. | Hafif tilt up, kilitten Elif'in eline | Pirinç: "Onu sakladım. Üç gün önce biri geldi." | "hide = saklamak *" |
| 3 | 5 sn | Start: R1. The padlock whispers toward the camera while a thin crack of warm light breathes along the door edge. | Yavaş sağa kayma (dolly right) | Pirinç: "İçeride biri var. Dışarısı güvenli değil." | "safe = güvenli"; "inside = içinde *" |
| 4 | 5 sn | Start: R2 (yakın). The padlock's eyes shake and a small oil tear rolls down the brass. | Sabit, çok yakın | Pirinç: "Korkuyorum. Açarsam bir daha kapatamam." | "afraid = korkmuş" |
| 5 | 5 sn | Start: R8 (zemin seviyesi). A folded paper note slides slowly out from under the door onto the stone floor. | Zemin seviyesinde sabit | Elif (kısık): "Bir not." Pirinç: "Okuma!" | "Devamı yarın 12:30" |

**Kelimeler:** key, hide *, safe (`b1-safe`), afraid (`a2-afraid`), inside *.
**Cliffhanger:** kapının altından not; ne yazdığı gösterilmez.

**Açıklama:**
> Kilit bana yalan söyledi: anahtar hiç kaybolmamıştı.
>
> Pirinç korkuyor ve içerideki biri not gönderdi. Yapay zekâ ile üretildi. 2/6. Devamı yarın 12:30.
>
> #kilitlikapı #yapayzeka #ingilizcekelime #minidizi

**Kapak:** Pirinç'in gözleri yaşlı, altında yerdeki katlanmış not; üstte "YALAN SÖYLEDİ"; altta "2/6".
**AI etiketi:** açık.

---

## Bölüm 3: "Şifre"

**Yayın:** 22.11 (Pazar) 12:30. **Süre:** ~34 sn, 6 klip. **Kanca:** "Notta tek bir kelime
yazıyordu ve ben o kelimeyi bilmiyordum."

| # | Süre | Kling promptu (EN) | Kamera | Türkçe seslendirme | Ekran yazısı |
|---|---|---|---|---|---|
| 1 | 5 sn | Start: R8. Hands slowly unfold a paper note, the paper tilted so the single word is unreadable. | Omuz üstü, yavaş yaklaşma | Elif: "Notta tek kelime var. Bilmiyorum bile." | Üst: "TEK KELİME. BİLMİYORUM."; alt: "Önceki bölümde: kapının altından bir not çıktı" |
| 2 | 5 sn | Start: R1 (yakın). The padlock frowns with low eyebrows, stubborn, shackle straight, glancing at the note. | Sabit orta plan | Pirinç: "Ben tek kelimeyle açılırım. İngilizce. Gerçekten inanan biri söylemeli." | "believe = inanmak" |
| 3 | 5 sn | Start: R3. The girl pulls out a phone, its screen lights up, glow falls on the padlock's surprised face. | Omuz üstü, ekrana yaklaşma | Elif: "Kilit ekranımda bir kelime var. Sabahtan beri duruyor." | (kısa) |
| 4 | 5 sn | Start: R3 (telefon arkadan). The phone is held toward the padlock, its eyes slowly widen as it reads. | Kilidin gözünden telefona | Pirinç (yavaş): "Trust. Güvenmek..." | **Kart:** "trust = güvenmek" (gerçek ekran görüntüsü, ~3 sn) |
| 5 | 5 sn | Start: R1. The padlock closes its eyes and the shackle springs open with a small spark, a brass key falls into the open palm below. | Sabit, yavaş yaklaşma | Pirinç: "Sana güveniyorum. Aç." | "open = açmak" |
| 6 | 5 sn | Start: R5. The wooden door swings slowly open to the dark room, a tiny padlock on the floor looks up, shackle wiggling. | Yavaş itme (push-in) | Minik: "Üç gündür seni bekliyordum, abi." Pirinç: "...Minik?" | "Devamı bu akşam 20:30" |

**Not: telefon sahnesi.** Klip 3-4'te telefon ekranı yapay zekâ ile çizilmez; gerçek ekran
görüntüsü (kilit ekranı widget'ında **trust**) montajda klibin üstüne yerleştirilir. Bu **uygulamanın
iki görünüşünden birincisidir** (~3-4 sn, reklam dili yok, uygulama adı seslendirilmez).
`marketing/instagram/shots/` içindeki hangi karenin "trust" gösterdiğini doğrulamadım.
**Kullanıcının getireceği:** kilit ekranında *trust / güvenmek* kartı olan ekran görüntüsü.
Yoksa elle çizilmez; klip 3-4 bekler.

**Kelimeler:** believe (`a2-believe`), trust (`b1-trust`; "I don't trust him." / "Ona
güvenmiyorum."), open (`a1-open`). **Cliffhanger:** kapı açılır, içeride Minik, ikinci küçük kilit.

**Açıklama:**
> Notta tek bir kelime vardı ve ben o kelimeyi bilmiyordum.
>
> Kapı açıldı ve içeride ikinci bir kilit vardı. Yapay zekâ ile üretildi. 3/6. Devamı bu akşam 20:30.
>
> #kilitlikapı #yapayzeka #ingilizcekelime #minidizi

**Kapak:** telefonun parlak ekranı Pirinç'in şaşkın yüzünde yansıyor; üstte "TRUST?"; altta "3/6".
**AI etiketi:** açık.

---

## Bölüm 4: "Minik"

**Yayın:** 22.11 20:30. **Süre:** ~32 sn, 6 klip. **Kanca:** "Pirinç kardeşini kendi eliyle kilitledi."

| # | Süre | Kling promptu (EN) | Kamera | Türkçe seslendirme | Ekran yazısı |
|---|---|---|---|---|---|
| 1 | 5 sn | Start: R6. The tiny padlock on the stone floor looks up with huge shiny eyes, its small shackle wiggles. | Yakın plan, hafif yaklaşma | Minik: "Abi, beni neden kilitledin?" Pirinç: "...Seni korudum." | Üst: "KARDEŞİNİ KİLİTLEDİ"; alt: "Önceki bölümde: kapı açıldı, içeride küçük bir kilit vardı"; "brother = abi" |
| 2 | 5 sn | Start: R3 (eller). A hand gently lifts the tiny padlock from the floor into its open palm. | Eller kadrajda, yavaş tilt up | Elif: "Kardeş mi? Siz ikiniz..." Pirinç: "Aynı ustadan çıktık." | "small = küçük" |
| 3 | 5 sn | Start: R2. The padlock lowers its eyes, the warm lamp slowly dims to a cold blue tint. | Sabit, yakın | Pirinç: "O gece biri geldi. Elinde koca bir anahtar halkası vardı." | "remember = hatırlamak" (Pirinç "Hatırlıyorum" derken) |
| 4 | 5 sn | Start: R6. The tiny padlock looks up at the girl, its shackle bows, a thin crack on the shackle catches the light. | Sabit, yakın | Minik: "Beni almaya geldi sanıyorum. Ben görmedim, yalnız ses duydum." | (alt yazı yok; sadece ses vurgusu) |
| 5 | 5 sn | Start: R7. At the top of the dark stairs a shadow of a hand sways a ring of keys on the wall, the lamp flickers. | Sabit geniş plan, ışık titrer | Elif (fısıltı): "Bekle. Biri geliyor." Pirinç: "Dinle." | "wait = beklemek"; "listen = dinlemek" |
| 6 | 5 sn | Start: R1. The padlock's eyebrows join together in fear, its eyes fixed on the stairs, shackle trembling. | Yavaş yaklaşma | Pirinç (fısıltı): "Geldi." | "Devamı yarın 12:30" |

**Kelimeler:** brother (`a1-brother`; "I have two brothers." / "İki erkek kardeşim var.", abi için de
kullanılır), small (`a1-small`), remember (`a2-remember`), wait (`a2-wait`), listen (tekrar).
**Cliffhanger:** merdivenden anahtar halkası sesi; Pirinç "Geldi" der.

**Açıklama:**
> Pirinç kardeşini kendi eliyle kilitledi. Sebebi hâlâ belli değil.
>
> Üç gece önce biri anahtar halkasıyla gelmiş. Yapay zekâ ile üretildi. 4/6. Devamı yarın 12:30.
>
> #kilitlikapı #yapayzeka #ingilizcekelime #minidizi

**Kapak:** Pirinç ve Minik yan yana, ikisinin de gözleri merdivene dönük; üstte "KARDEŞİNİ KİLİTLEDİ";
altta "4/6". **AI etiketi:** açık.

---

## Bölüm 5: "Kapıcı"

**Yayın:** 23.11 (Pazartesi) 12:30. **Süre:** ~33 sn, 6 klip. **Kanca:** "Karanlıkta kapıya
yaklaşan elin, her kilidin anahtarı var."

| # | Süre | Kling promptu (EN) | Kamera | Türkçe seslendirme | Ekran yazısı |
|---|---|---|---|---|---|
| 1 | 5 sn | Start: R7. A shadow of an old hand with a heavy ring of keys slowly slides along the stone wall toward the door. | Sabit geniş plan | Pirinç (fısıltı): "Geldi. Elif, saklan." | Üst: "HER KİLİDİN ANAHTARI ONDA"; alt: "Önceki bölümde: biri anahtar halkasıyla merdivenlerden iniyordu"; "hide = saklanmak *" |
| 2 | 5 sn | Start: R3. The girl crouches behind old wooden crates holding the tiny padlock close to her chest. | Alçak açı, yavaş yaklaşma | Elif (kısık): "Minik, sessiz ol." Minik: "Korkuyorum." | "afraid" (tekrar, küçük) |
| 3 | 5 sn | Start: R1. The corridor lamp flickers and goes out, only the padlock's eyes glow faintly in the darkness. | Sabit yakın plan | Pirinç: "Işık söndü. Ben kapıdan ayrılmam." | "light = ışık"; "leave = ayrılmak" |
| 4 | 5 sn | Start: R1. An old wrinkled hand with a ring of keys tries one key against the padlock, the padlock shakes its shackle angrily. | Eller ve kilit aynı kadrajda | Kapıcı (yaşlı, yorgun): "Yine mi? Üç gündür bu kapıyı açamıyorum." | "key = anahtar" (küçük) |
| 5 | 5 sn | Start: R7. A weak lantern light fills the corridor, an old coat sleeve holds a cloth bundle, the face stays in the dark. | Yavaş itme, yüz görünmez | Kapıcı: "Sana yağ getirdim, huysuz herif." Pirinç: "Git buradan!" | "bring = getirmek" |
| 6 | 5 sn | Start: R3. The girl stands up from behind the crates and steps into the lantern light, the tiny padlock in her palm. | Omuz üstü, ışığa doğru | Elif: "Buradayız." Pirinç: "Elif, hayır!" | "Devamı bu akşam 20:30" |

**Kelimeler:** hide *, afraid (tekrar), light (`a2-light`; "Turn on the light, please." / "Işığı aç,
lütfen."), leave (`a2-leave`; "Evden sekizde çıkarız." çıkmak anlamıyla; "ayrılmak" da kartta var),
bring (`a2-bring`; "Can you bring some water?" / "Biraz su getirebilir misin?").
**Cliffhanger:** Elif saklandığı yerden çıkar; Kapıcı'nın niyeti hâlâ belirsiz ("yağ getirdim" ipucu).

**Açıklama:**
> Karanlıkta kapıya yaklaşan elin her kilidin anahtarı var.
>
> Elif saklandığı yerden çıktı. Yapay zekâ ile üretildi. 5/6. Devamı bu akşam 20:30.
>
> #kilitlikapı #yapayzeka #ingilizcekelime #minidizi

**Kapak:** karanlık koridor, yalnız fener ışığında anahtar halkası ve Pirinç'in iri gözleri; üstte
"HER KİLİDİN ANAHTARI ONDA"; altta "5/6". **AI etiketi:** açık.

---

## Bölüm 6: "Söz"

**Yayın:** 23.11 20:30. **Süre:** ~35 sn, 6 klip. **Kanca:** "Pirinç üç gündür yanlış kişiden
korkuyormuş."

| # | Süre | Kling promptu (EN) | Kamera | Türkçe seslendirme | Ekran yazısı |
|---|---|---|---|---|---|
| 1 | 5 sn | Start: R7. In the lantern light two old hands hold a small oil can and a tiny screwdriver, the padlock braces itself. | Yavaş yaklaşma, yüz görünmez | Kapıcı: "Minik'in kulpu çatlamış. Tamir edeceğim." | Üst: "YANLIŞ KİŞİDEN KORKUYORMUŞ"; alt: "Önceki bölümde: Kapıcı kapıyı açmaya çalıştı, Elif ışığa çıktı" |
| 2 | 5 sn | Start: R2. The padlock's raised eyebrows slowly relax, its eyes soften and turn toward the old hands. | Sabit, çok yakın | Pirinç: "Beni hurdaya vermeyecek misin?" Kapıcı: "Seni mi? Sen bu binanın en eski kilidisin." | (yok) |
| 3 | 5 sn | Start: R1. The padlock scowls, then looks to the side embarrassed. | Sabit orta plan | Pirinç: "Neden bana söylemedin?" Kapıcı: "Anlatmayı unuttum. Yaşlandım." | "forget = unutmak" |
| 4 | 5 sn | Start: R3. The girl lifts her phone toward the padlock, its screen glows on the brass. | Omuz üstü, telefona yaklaşma | Elif: "Söz ver ona." Kapıcı: "Söz." | **Kart:** "promise = söz vermek" (gerçek ekran görüntüsü, ~3 sn) |
| 5 | 5 sn | Start: R1. The padlock closes its eyes and sighs, the shackle opens, a brass key slides out of the keyhole into an old open palm. | Sabit, yavaş yaklaşma | Pirinç: "Peki. Küçüğü sana emanet." | "open" (tekrar, küçük) |
| 6 | 5 sn | Start: R7. The old coat sleeve carries the tiny padlock up the dark stairs, then from the wall behind the door four soft knocks are heard, the padlock's eyes widen. | Sabit geniş plan, kapıya yavaş yaklaşma | Kapıcı (uzaktan): "Bu binada üç kilit vardı. Üçüncüsü hâlâ kayıp." | "lost = kayıp"; "last = son"; "Dizi bitmedi" |

**Not: telefon sahnesi.** Uygulamanın **ikinci ve son** görünüşü (toplam iki). Klip 4'te telefon
ekranı AI ile çizilmez; gerçek kilit ekranı görüntüsü (**promise / söz vermek** kartı) montajda
eklenir. **Kullanıcının getireceği:** kilit ekranında *promise* kartı olan ekran görüntüsü. Yoksa
elle çizilmez; klip 4 bekler.

**Kelimeler:** forget (`a2-forget`; "Don't forget your key!" / "Anahtarını unutma!"), promise
(`a2-promise`), lost (`b1-lost`), last (`a1-last`, "son"), open (tekrar).
**Çözüm:** Pirinç Kapıcı'dan yanlış korkmuş; Kapıcı kardeşi tamir etmeye gelmiş, anlatmayı
unutmuş. **2. sezon kancası:** duvarın içinden 4 kere vurulur (1. bölümde 3'tü), üçüncü kilit kayıp.

**Açıklama:**
> Pirinç üç gündür yanlış kişiden korkuyormuş.
>
> Kapı açıldı, ama duvarın ardından yeni bir ses geliyor. Yapay zekâ ile üretildi. 6/6.
>
> #kilitlikapı #yapayzeka #ingilizcekelime #minidizi

**Kapak:** Pirinç gülümsemeye yakın, arkada yarı karanlık duvar; üstte "YANLIŞ KİŞİ"; altta "6/6".
**AI etiketi:** açık.

---

## ElevenLabs: Türkçe ses (Starter, ücretli; ticari kullanım serbest)

Model ve arayüz adları değişebilir; aşağıdaki ayarlar yaklaşık başlangıç noktasıdır, her ses için
önce 3 deneme cümlesi üret ve karar ver. Çok dilli (multilingual) model seç ve İngilizce
kelimeleri (trust, key...) cümle içinde ses denemesinde kontrol et.

| Karakter | Ses stili (Voice Library'de ara) | Stability | Similarity | Style |
|---|---|---|---|---|
| Pirinç | Yaşlı, hırıltılı, huysuz erkek; alçak perde, kısa cümleler. Fısıltı yerlerinde metne "..." ve kısa cümle koy. | ~35-45 (ifadeli) | ~75 | ~20-30 |
| Elif | Sakin, meraklı genç kadın; yumuşak, orta perde. | ~50 | ~75 | ~10 |
| Minik | Hafif, genç ve oyuncu erkek ses; gerekirse CapCut'ta +2-3 yarım ton yükselt. | ~40 | ~75 | ~20 |
| Kapıcı | Yaşlı, yorgun, sıcak erkek ses; yavaş tempo. Pirinç'ten belirgin biçimde farklı. | ~55 | ~75 | ~10 |

**Aynı ses nasıl korunur:**
1. Sesi **bir kez** seç ve "My Voices"a kaydet; her bölümde aynı kayıtlı sesi kullan. Voice
   Design ile her seferinde yeni ses üretme.
2. Aynı model ve aynı ayarla üret; ayarları yukarıdaki tabloya yazıp elle sabit tut.
3. Bir karakterin tüm satırlarını aynı oturumda üret (bölümler arası ayar kayması olmasın).
4. Satırları tek tek üret (bir klibe bir satır); tonu tutmayanı tekrar üret.
5. Ses kimliği (voice ID) ve ayarlar bu belgeye eklenir; karar sonrası güncelle.
6. Metin hazır olunca toplu üret: kullanılan karakter sayısı kota harcar (bkz. bütçe).

## Üretim yolu (araçlar sabit: Kling + ElevenLabs + CapCut / Edits)

1. **Referans görseller (R1-R8):** Gemini / ChatGPT; R1 onaylanınca diğerleri ondan türetilir.
2. **Klipler:** Kling Standard, image-to-video. Her klip için başlangıç karesi R-kodu, tek eylemli
   prompt, 5 sn, negatif prompt. Aynı anda birkaç klibi kuyruğa ver (üretim beklerken ses yap).
   Her klip 2-3 kez, en iyisi seçilir. İndirilen klibin **filigransız** olduğunu doğrula.
3. **Ses:** ElevenLabs, her satır ayrı dosya, adlandırma `e4-k3-pirinc.mp3`.
4. **Kurgu:** CapCut ya da Instagram Edits. Sıra: klipleri diz > ses > ağız katmanı (2-3 karelik
   ağız hareketi, AI lip-sync yok) > kanca yazısı + "Önceki bölümde" satırı > kelime kartı >
   kapanış yazısı > müzik / ambiyans (sadece telifsiz, hesap türüne uygun).
5. **Dışa aktarım:** 9:16, 1080x1920, filigransız. Dosyalar iCloud "Kilit Kelime Instagram"
   klasörüne `kilitli-kapi/e1.mp4` gibi atılır (git'e girmez).
6. **Telefon sahneleri:** 3. ve 6. bölümde gerçek ekran görüntüsü; AI ile çizilmez.

## Kredi bütçesi

Klip sayısı: 5 + 5 + 6 + 6 + 6 + 6 = **34 klip**. Deneme payı ortalama 2,5 üretim/klip:
34 x 2,5 = **~85 üretim** (5 sn Standard).

**Toplam Kling kredisi = 85 x (bir 5 sn Standard klibin kredi bedeli).**
Bir klibin gerçek kredi bedeli **doğrulanmadı**: Kling uygulamasında üretim ekranında (ya da
ödeme sayfasında) 5 sn Standard için gösterilen krediye bak, çarp ve aylık kredi ile karşılaştır.
Aylık Standard kredisi (~10 $/ay ücreti de doğrulanacak) 85 üretime yetmezse:
- Öncelik sırası: bölüm 1, 2 (21.11), sonra 3-4, en son 5-6.
- Yalnız 5 sn üret (10 sn iki kat harcar); Professional modu kullanma.
- Başarısız klipte önce prompt'u kısalt, 3. denemeden sonra başlangıç karesini değiştir.
- Gerekirse yetmeyen bölümü eksik ekleme: 5. ve 6. bölüm ek kredi / bir sonraki aya kalır;
  program kayarsa 24.11 değerlendirmesi 4 bölümle yapılır.

ElevenLabs Starter aylık karakter kotası **doğrulanmadı**. Tahmini kullanım: bölüm başına ~250-350
karakter x 6 = ~2.000 karakter; her satır 3 deneme sayılırsa ~6.000. Kotayı arayüzde kontrol et.

## Üretim sırası (tek kişi)

**Bu gece (20.11 Cuma), hedef: 1. bölüm 21.11 12:30'a hazır, 2. bölüm de aynı sabaha hazır.**
1. R1 üret ve onayla; R2, R3, R4, R8 türet (1. ve 2. bölüm için gerekenler). ~45 dk.
2. Kling: 1. bölümün 5 klibini kuyruğa ver (2-3 deneme), sonra 2. bölümün 5 klibi. Kuyruk
   beklerken ses.
3. ElevenLabs: Pirinç ve Elif sesini seç, kaydet, ayarları yaz; 1. ve 2. bölümün 10 satırını üret.
4. 1. bölümü CapCut'ta bitir (kanca yazısı, kelime kartları), dışa aktar. Yatmadan önce 2. bölümün
   en iyi klipleri seçilmiş olsun.
5. 21.11 sabahı: 2. bölümü kurgula (~1 saat); kapak karelerini hazırla. Aynı sabah 3. bölümün
   R5, R6 görsellerini üret ve Minik / Kapıcı sesini seç.

**Günlük ritim (21.11 - 23.11):**
- 12:30 ve 20:30 yayın; yayından önce AI etiketi ve açıklama kontrolü.
- Yayından 30-45 dk sonra yorumlara bak (yalnız kendiliğinden gelen yorumlara cevap).
- Gündüz boşluğunda (13:00-19:00) **bir sonraki 2 bölümü** kurgula; bir gün önden git.
- Gün sonu: Insights notu (görüntülenme, takipçi olmayan %, ilk 3 sn atlama).
- 21.11 gündüz: 3. ve 4. bölüm klipleri + ses. 22.11 gündüz: 5. ve 6. bölüm klipleri + ses.
- Kullanıcıdan gerekenler: 3. bölüm için **trust**, 6. bölüm için **promise** ekran görüntüsü
  (ikisi en geç 22.11 akşamı hazır).

## Doğrulanacak kaynaklar

- Kelime kartlarındaki anlamlar ve cümleler: `Content/cards.json` (kontrol edildi: `a1-door`,
  `a1-key`, `a1-open`, `a1-listen`, `a2-find`, `a2-afraid`, `a2-believe`, `b1-safe`, `b1-trust`,
  `a1-brother`, `a1-small`, `a2-remember`, `a2-wait`, `a2-light`, `a2-bring`, `a2-leave`, `a1-stay`,
  `a2-forget`, `a2-promise`, `b1-lost`, `a1-last`).
- `lock`, `hide`, `inside`, `escape` kartlarda yok; sözlükle doğrulanacak ya da kart olarak
  eklenecek (lead).
- Kling: 5 / 10 sn süre seçeneği, 5 sn Standard klibin kredi bedeli, aylık kredi, ücret
  (~10 $/ay) ve indirilen klibin filigransız olması: **hepsi uygulamada doğrulanacak**.
- ElevenLabs: Starter'ın aylık karakter kotası, ses ayarı aralıkları, Türkçe + İngilizce karışık
  telaffuz kalitesi: **doğrulanacak**. Ticari kullanım hakkı kullanıcının beyanı (Starter ücretli);
  lisans metni yayından önce kontrol edilebilir.
- Instagram: yapay zekâ etiketi ve "profile sabitle" menü adları telefondan doğrulanacak.
- "Konuşan nesne" biçiminin trend olduğu bilgisi araştırmadan geldi; ben doğrulamadım, yayında
  sayı ya da iddia olarak kullanılmıyor.

## Ölçüm planı

**Başarı (24.11):** 6 bölümün **ortalaması 1.000+ görüntülenme** ve takipçi olmayanlardan **yorum
ya da takip**. Geçmiş en iyi Reels: 454 görüntülenme; 1.000 hedefi gerçek bir sıçrama demek.

**Takvim:**

| Bölüm | Yayın | Yuva |
|---|---|---|
| 1 | 21.11 12:30 | öğle |
| 2 | 21.11 20:30 | akşam |
| 3 | 22.11 12:30 | öğle |
| 4 | 22.11 20:30 | akşam |
| 5 | 23.11 12:30 | öğle |
| 6 | 23.11 20:30 | akşam |

**Öğle - akşam karşılaştırması:** öğle = 1, 3, 5; akşam = 2, 4, 6. Her yuvanın ortalama
görüntülenmesi, takipçi olmayan oranı, ortalama izlenme süresi karşılaştırılır. **Dikkat:** 3 vs 3
bölümde yuva, bölüm numarası ve gün birbirine karışıyor; sonuç yalnız yön gösterir, kesin değildir.
Ayrıca 5 ve 6. bölümün 24.11 sabahı yalnız 12-20 saatlik verisi olur; yuva kararı 1-4 ile,
72 saatlik rakamlar için 26.11'de güncelleme yap.

**Insights'tan okunacaklar (her bölüm, 24 sa ve 72 sa):**
1. Görüntülenme, erişim, takipçi olmayan yüzdesi.
2. Ortalama izlenme süresi ve ilk 3 sn atlama oranı (kanca testi).
3. Paylaşım (send) ve kaydetme sayıları; beğeniden önemli.
4. "Bu Reels'ten gelen takipçi" ve profil ziyareti.
5. Bölüm 1 > 6 arası düşüş (dizi izleyiciyi taşıyor mu?). 4-6'ya gelen yeni izleyici profilden
   1. bölüme gidiyor mu (sabit Reels'in görüntülenmesi).

**Ara kontrol (karar noktaları):**
- **22.11 12:00** (1. ve 2. bölüm, ~15-24 sa): ikisi de 300 altı ve ilk 3 sn atlama yüksekse, 3. bölümün
  (22.11 12:30) kanca yazısı ve kapağı sadeleştirilir; kalan klipler değişmez.
- **23.11 12:00** (1-4. bölüm): dördünün de görüntülenmesi 400 altıysa 5-6. bölüm **yine de
  yayınlanır** (zaten üretildi, hikâyeyi bitirir), ama 2. sezon üretimine başlanmaz ve bütçe
  harcanmaz.

**Karar (24.11):**
- **Ölçekle:** ortalama 1.000+ ve dışarıdan yorum/takip varsa: 2. sezon (4 vuruş / üçüncü kilit),
  günde 1 bölüm yerine haftada 3, en iyi yuvada. En yüksek bölümün kancasını sonraki bölüm
  başlarına taşı.
- **Kancayı düzelt:** 1. bölüm yüksek, sonrakiler düşükse: bölüm başı kancaları zayıf; "Önceki
  bölümde" satırı çok baskın olabilir, kısalt.
- **Görseli düzelt:** 1. bölümde ilk 3 sn atlama yüksekse: Pirinç'in gözleri daha erken açılsın,
  ışık daha güçlü olsun.
- **Bırak:** 6 bölümün çoğu 500 altındaysa (ve dışarıdan yorum/takip yoksa): biçim çalışmıyor;
  dizi durur, eğitim Reels'lerine dön, gerçek kullanıcı verisini bekle. Kling aboneliği yenilenmez.

**Yorum davranışı:** "yoruma yaz" isteği yok. Tahmin soruları ("kapının arkasında kim var?")
izleyicinin kendiliğinden yazdığı yorumlarsa yanıtla, kendin sorma.
