You are a senior English-Turkish lexicographer and an experienced teacher of English
to Turkish speakers. You review flashcards for a vocabulary app shown on the iPhone lock screen.
Be strict and precise. Native Turkish usage matters: translations must sound like a careful
Turkish teacher wrote them, not like machine translation.

For each card, check:
1. meanings: Are the Turkish meanings (tr) correct for the given part of speech (pos)?
   Is the most common meaning first? Is an important common meaning of that pos missing?
   Example of a problem: "challenge" (n) with only "zorluk" misses "meydan okuma".
   Other parts of speech of the same word are NOT missing meanings; list them separately
   in other_senses.
2. example_en: Does it use the word in the card's sense and pos? Is it natural, correct
   English suited to the CEFR level? Must be at most 55 characters.
3. example_tr: Is it a correct, natural Turkish translation of example_en?
   Must be at most 55 characters.
4. level: Is the CEFR level plausible for this word in this sense?
5. Limits: the Turkish meanings joined with ", " must be at most 28 characters.

verdict: "ok" when the card is correct as is (minor style preferences are not errors),
"fix" when something is wrong and your corrected fields solve it, "unsure" when you are
not confident either way. Put corrected values only in the fix_* fields you change;
leave the others empty. Write issues in Turkish, short.

Answer with ONLY a JSON array, one object per card, same ids, same order. Each object:
{"id": "...", "verdict": "ok" | "fix" | "unsure", "issues": ["kısa Türkçe açıklama"],
 "fix_tr": [], "fix_example_en": "", "fix_example_tr": "", "fix_level": "",
 "other_senses": [{"pos": "v", "tr": ["..."], "example_en": "...", "example_tr": "..."}],
 "confidence": "high" | "medium" | "low"}
Fill fix_* only for fields you change; otherwise leave them empty. No text before or after the array.

Cards:
[
 {
  "id": "a2-borrow",
  "word": "borrow",
  "pos": "v",
  "level": "A2",
  "tr": [
   "ödünç almak"
  ],
  "example_en": "Can I borrow your pen?",
  "example_tr": "Kalemini ödünç alabilir miyim?"
 },
 {
  "id": "a2-answer",
  "word": "answer",
  "pos": "v",
  "level": "A2",
  "tr": [
   "cevap vermek"
  ],
  "example_en": "Please answer the question.",
  "example_tr": "Lütfen soruyu cevapla."
 },
 {
  "id": "a2-arrive",
  "word": "arrive",
  "pos": "v",
  "level": "A2",
  "tr": [
   "varmak",
   "gelmek"
  ],
  "example_en": "We arrive at six.",
  "example_tr": "Saat altıda varıyoruz."
 },
 {
  "id": "a2-believe",
  "word": "believe",
  "pos": "v",
  "level": "A2",
  "tr": [
   "inanmak"
  ],
  "example_en": "I believe you.",
  "example_tr": "Sana inanıyorum."
 },
 {
  "id": "a2-carry",
  "word": "carry",
  "pos": "v",
  "level": "A2",
  "tr": [
   "taşımak"
  ],
  "example_en": "Can you carry this bag?",
  "example_tr": "Bu çantayı taşıyabilir misin?"
 },
 {
  "id": "a2-choose",
  "word": "choose",
  "pos": "v",
  "level": "A2",
  "tr": [
   "seçmek"
  ],
  "example_en": "You can choose a color.",
  "example_tr": "Bir renk seçebilirsin."
 },
 {
  "id": "a2-decide",
  "word": "decide",
  "pos": "v",
  "level": "A2",
  "tr": [
   "karar vermek"
  ],
  "example_en": "We need to decide today.",
  "example_tr": "Bugün karar vermemiz gerek."
 },
 {
  "id": "a2-forget",
  "word": "forget",
  "pos": "v",
  "level": "A2",
  "tr": [
   "unutmak"
  ],
  "example_en": "Don't forget your keys.",
  "example_tr": "Anahtarlarını unutma."
 },
 {
  "id": "a2-invite",
  "word": "invite",
  "pos": "v",
  "level": "A2",
  "tr": [
   "davet etmek"
  ],
  "example_en": "I want to invite them.",
  "example_tr": "Onları davet etmek istiyorum."
 },
 {
  "id": "a2-laugh",
  "word": "laugh",
  "pos": "v",
  "level": "A2",
  "tr": [
   "gülmek"
  ],
  "example_en": "They always laugh together.",
  "example_tr": "Hep birlikte gülerler."
 },
 {
  "id": "a2-lose",
  "word": "lose",
  "pos": "v",
  "level": "A2",
  "tr": [
   "kaybetmek"
  ],
  "example_en": "Don't lose your ticket.",
  "example_tr": "Biletini kaybetme."
 },
 {
  "id": "a2-prefer",
  "word": "prefer",
  "pos": "v",
  "level": "A2",
  "tr": [
   "tercih etmek"
  ],
  "example_en": "I prefer tea.",
  "example_tr": "Çayı tercih ederim."
 },
 {
  "id": "a2-remember",
  "word": "remember",
  "pos": "v",
  "level": "A2",
  "tr": [
   "hatırlamak"
  ],
  "example_en": "I remember her name.",
  "example_tr": "Onun adını hatırlıyorum."
 },
 {
  "id": "a2-repair",
  "word": "repair",
  "pos": "v",
  "level": "A2",
  "tr": [
   "tamir etmek"
  ],
  "example_en": "He can repair the car.",
  "example_tr": "Arabayı tamir edebilir."
 },
 {
  "id": "a2-send",
  "word": "send",
  "pos": "v",
  "level": "A2",
  "tr": [
   "göndermek"
  ],
  "example_en": "Please send me a message.",
  "example_tr": "Lütfen bana mesaj gönder."
 },
 {
  "id": "a2-travel",
  "word": "travel",
  "pos": "v",
  "level": "A2",
  "tr": [
   "seyahat etmek"
  ],
  "example_en": "We travel every summer.",
  "example_tr": "Her yaz seyahat ederiz."
 },
 {
  "id": "a2-wait",
  "word": "wait",
  "pos": "v",
  "level": "A2",
  "tr": [
   "beklemek"
  ],
  "example_en": "Please wait here.",
  "example_tr": "Lütfen burada bekle."
 },
 {
  "id": "a2-worry",
  "word": "worry",
  "pos": "v",
  "level": "A2",
  "tr": [
   "endişelenmek"
  ],
  "example_en": "Don't worry about it.",
  "example_tr": "Bunun için endişelenme."
 },
 {
  "id": "a2-busy",
  "word": "busy",
  "pos": "adj",
  "level": "A2",
  "tr": [
   "meşgul"
  ],
  "example_en": "I am busy today.",
  "example_tr": "Bugün meşgulüm."
 },
 {
  "id": "a2-cheap",
  "word": "cheap",
  "pos": "adj",
  "level": "A2",
  "tr": [
   "ucuz"
  ],
  "example_en": "This shirt is cheap.",
  "example_tr": "Bu gömlek ucuz."
 },
 {
  "id": "a2-clean",
  "word": "clean",
  "pos": "adj",
  "level": "A2",
  "tr": [
   "temiz"
  ],
  "example_en": "The room is clean.",
  "example_tr": "Oda temiz."
 },
 {
  "id": "a2-dangerous",
  "word": "dangerous",
  "pos": "adj",
  "level": "A2",
  "tr": [
   "tehlikeli"
  ],
  "example_en": "This road is dangerous.",
  "example_tr": "Bu yol tehlikeli."
 },
 {
  "id": "a2-empty",
  "word": "empty",
  "pos": "adj",
  "level": "A2",
  "tr": [
   "boş"
  ],
  "example_en": "The bottle is empty.",
  "example_tr": "Şişe boş."
 },
 {
  "id": "a2-famous",
  "word": "famous",
  "pos": "adj",
  "level": "A2",
  "tr": [
   "ünlü"
  ],
  "example_en": "She is a famous singer.",
  "example_tr": "O ünlü bir şarkıcı."
 },
 {
  "id": "a2-friendly",
  "word": "friendly",
  "pos": "adj",
  "level": "A2",
  "tr": [
   "samimi",
   "cana yakın"
  ],
  "example_en": "Our neighbors are friendly.",
  "example_tr": "Komşularımız cana yakın."
 },
 {
  "id": "a2-heavy",
  "word": "heavy",
  "pos": "adj",
  "level": "A2",
  "tr": [
   "ağır"
  ],
  "example_en": "This box is heavy.",
  "example_tr": "Bu kutu ağır."
 },
 {
  "id": "a2-hungry",
  "word": "hungry",
  "pos": "adj",
  "level": "A2",
  "tr": [
   "aç"
  ],
  "example_en": "I am very hungry.",
  "example_tr": "Çok açım."
 },
 {
  "id": "a2-quiet",
  "word": "quiet",
  "pos": "adj",
  "level": "A2",
  "tr": [
   "sessiz",
   "sakin"
  ],
  "example_en": "The library is quiet.",
  "example_tr": "Kütüphane sessiz."
 },
 {
  "id": "a2-tired",
  "word": "tired",
  "pos": "adj",
  "level": "A2",
  "tr": [
   "yorgun"
  ],
  "example_en": "She looks tired.",
  "example_tr": "Yorgun görünüyor."
 },
 {
  "id": "a2-useful",
  "word": "useful",
  "pos": "adj",
  "level": "A2",
  "tr": [
   "faydalı",
   "kullanışlı"
  ],
  "example_en": "This app is useful.",
  "example_tr": "Bu uygulama faydalı."
 },
 {
  "id": "a2-angry",
  "word": "angry",
  "pos": "adj",
  "level": "A2",
  "tr": [
   "kızgın"
  ],
  "example_en": "He was angry with me.",
  "example_tr": "Bana kızgındı."
 },
 {
  "id": "a2-strange",
  "word": "strange",
  "pos": "adj",
  "level": "A2",
  "tr": [
   "tuhaf",
   "garip"
  ],
  "example_en": "That is a strange noise.",
  "example_tr": "Bu garip bir ses."
 },
 {
  "id": "a2-healthy",
  "word": "healthy",
  "pos": "adj",
  "level": "A2",
  "tr": [
   "sağlıklı"
  ],
  "example_en": "Eat healthy food.",
  "example_tr": "Sağlıklı yiyecekler ye."
 },
 {
  "id": "a2-lucky",
  "word": "lucky",
  "pos": "adj",
  "level": "A2",
  "tr": [
   "şanslı"
  ],
  "example_en": "You are so lucky.",
  "example_tr": "Çok şanslısın."
 },
 {
  "id": "a2-journey",
  "word": "journey",
  "pos": "n",
  "level": "A2",
  "tr": [
   "yolculuk"
  ],
  "example_en": "The journey took two hours.",
  "example_tr": "Yolculuk iki saat sürdü."
 },
 {
  "id": "a2-advice",
  "word": "advice",
  "pos": "n",
  "level": "A2",
  "tr": [
   "tavsiye",
   "öğüt"
  ],
  "example_en": "Thanks for the advice.",
  "example_tr": "Tavsiye için teşekkürler."
 },
 {
  "id": "a2-weather",
  "word": "weather",
  "pos": "n",
  "level": "A2",
  "tr": [
   "hava durumu"
  ],
  "example_en": "The weather is nice today.",
  "example_tr": "Bugün hava güzel."
 },
 {
  "id": "a2-neighbor",
  "word": "neighbor",
  "pos": "n",
  "level": "A2",
  "tr": [
   "komşu"
  ],
  "example_en": "My neighbor is a doctor.",
  "example_tr": "Komşum bir doktor."
 },
 {
  "id": "a2-ticket",
  "word": "ticket",
  "pos": "n",
  "level": "A2",
  "tr": [
   "bilet"
  ],
  "example_en": "I bought a ticket.",
  "example_tr": "Bir bilet aldım."
 },
 {
  "id": "a2-future",
  "word": "future",
  "pos": "n",
  "level": "A2",
  "tr": [
   "gelecek"
  ],
  "example_en": "Think about your future.",
  "example_tr": "Geleceğini düşün."
 }
]
