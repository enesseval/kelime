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
  "id": "b1-accurate",
  "word": "accurate",
  "pos": "adj",
  "level": "B1",
  "tr": [
   "doğru",
   "kesin"
  ],
  "example_en": "The map is accurate.",
  "example_tr": "Harita doğru."
 },
 {
  "id": "b1-available",
  "word": "available",
  "pos": "adj",
  "level": "B1",
  "tr": [
   "mevcut",
   "müsait"
  ],
  "example_en": "Is this seat available?",
  "example_tr": "Bu koltuk boş mu?"
 },
 {
  "id": "b1-aware",
  "word": "aware",
  "pos": "adj",
  "level": "B1",
  "tr": [
   "farkında"
  ],
  "example_en": "Are you aware of the risk?",
  "example_tr": "Riskin farkında mısın?"
 },
 {
  "id": "b1-confident",
  "word": "confident",
  "pos": "adj",
  "level": "B1",
  "tr": [
   "kendinden emin"
  ],
  "example_en": "She looks confident.",
  "example_tr": "Kendinden emin görünüyor."
 },
 {
  "id": "b1-curious",
  "word": "curious",
  "pos": "adj",
  "level": "B1",
  "tr": [
   "meraklı"
  ],
  "example_en": "Children are curious.",
  "example_tr": "Çocuklar meraklıdır."
 },
 {
  "id": "b1-efficient",
  "word": "efficient",
  "pos": "adj",
  "level": "B1",
  "tr": [
   "verimli"
  ],
  "example_en": "This engine is efficient.",
  "example_tr": "Bu motor verimli."
 },
 {
  "id": "b1-familiar",
  "word": "familiar",
  "pos": "adj",
  "level": "B1",
  "tr": [
   "tanıdık"
  ],
  "example_en": "Your face looks familiar.",
  "example_tr": "Yüzün tanıdık geliyor."
 },
 {
  "id": "b1-honest",
  "word": "honest",
  "pos": "adj",
  "level": "B1",
  "tr": [
   "dürüst"
  ],
  "example_en": "Please be honest with me.",
  "example_tr": "Lütfen bana karşı dürüst ol."
 },
 {
  "id": "b1-necessary",
  "word": "necessary",
  "pos": "adj",
  "level": "B1",
  "tr": [
   "gerekli"
  ],
  "example_en": "Is it necessary to wait?",
  "example_tr": "Beklemek gerekli mi?"
 },
 {
  "id": "b1-patient",
  "word": "patient",
  "pos": "adj",
  "level": "B1",
  "tr": [
   "sabırlı"
  ],
  "example_en": "Be patient with children.",
  "example_tr": "Çocuklara karşı sabırlı ol."
 },
 {
  "id": "b1-polite",
  "word": "polite",
  "pos": "adj",
  "level": "B1",
  "tr": [
   "kibar"
  ],
  "example_en": "He is always polite.",
  "example_tr": "O her zaman kibar."
 },
 {
  "id": "b1-proud",
  "word": "proud",
  "pos": "adj",
  "level": "B1",
  "tr": [
   "gururlu"
  ],
  "example_en": "I am proud of you.",
  "example_tr": "Seninle gurur duyuyorum."
 },
 {
  "id": "b1-similar",
  "word": "similar",
  "pos": "adj",
  "level": "B1",
  "tr": [
   "benzer"
  ],
  "example_en": "Our ideas are similar.",
  "example_tr": "Fikirlerimiz benzer."
 },
 {
  "id": "b1-suitable",
  "word": "suitable",
  "pos": "adj",
  "level": "B1",
  "tr": [
   "uygun"
  ],
  "example_en": "This film is suitable for kids.",
  "example_tr": "Bu film çocuklar için uygun."
 },
 {
  "id": "b1-various",
  "word": "various",
  "pos": "adj",
  "level": "B1",
  "tr": [
   "çeşitli"
  ],
  "example_en": "We sell various books.",
  "example_tr": "Çeşitli kitaplar satıyoruz."
 },
 {
  "id": "b1-opportunity",
  "word": "opportunity",
  "pos": "n",
  "level": "B1",
  "tr": [
   "fırsat"
  ],
  "example_en": "This is a great opportunity.",
  "example_tr": "Bu harika bir fırsat."
 },
 {
  "id": "b1-advantage",
  "word": "advantage",
  "pos": "n",
  "level": "B1",
  "tr": [
   "avantaj"
  ],
  "example_en": "Speed is our advantage.",
  "example_tr": "Hız bizim avantajımız."
 },
 {
  "id": "b1-attitude",
  "word": "attitude",
  "pos": "n",
  "level": "B1",
  "tr": [
   "tutum",
   "tavır"
  ],
  "example_en": "She has a positive attitude.",
  "example_tr": "Olumlu bir tavrı var."
 },
 {
  "id": "b1-challenge",
  "word": "challenge",
  "pos": "n",
  "level": "B1",
  "tr": [
   "zorluk"
  ],
  "example_en": "Learning is a challenge.",
  "example_tr": "Öğrenmek zorlu bir iştir."
 },
 {
  "id": "b1-decision",
  "word": "decision",
  "pos": "n",
  "level": "B1",
  "tr": [
   "karar"
  ],
  "example_en": "It was a hard decision.",
  "example_tr": "Zor bir karardı."
 },
 {
  "id": "b1-environment",
  "word": "environment",
  "pos": "n",
  "level": "B1",
  "tr": [
   "çevre"
  ],
  "example_en": "We must protect the environment.",
  "example_tr": "Çevreyi korumalıyız."
 },
 {
  "id": "b1-experience",
  "word": "experience",
  "pos": "n",
  "level": "B1",
  "tr": [
   "deneyim"
  ],
  "example_en": "She has a lot of experience.",
  "example_tr": "Çok deneyimi var."
 },
 {
  "id": "b1-knowledge",
  "word": "knowledge",
  "pos": "n",
  "level": "B1",
  "tr": [
   "bilgi"
  ],
  "example_en": "Knowledge is power.",
  "example_tr": "Bilgi güçtür."
 },
 {
  "id": "b1-purpose",
  "word": "purpose",
  "pos": "n",
  "level": "B1",
  "tr": [
   "amaç"
  ],
  "example_en": "What is the purpose of this?",
  "example_tr": "Bunun amacı ne?"
 },
 {
  "id": "b1-skill",
  "word": "skill",
  "pos": "n",
  "level": "B1",
  "tr": [
   "beceri"
  ],
  "example_en": "Writing is a useful skill.",
  "example_tr": "Yazmak faydalı bir beceri."
 },
 {
  "id": "b1-solution",
  "word": "solution",
  "pos": "n",
  "level": "B1",
  "tr": [
   "çözüm"
  ],
  "example_en": "We found a solution.",
  "example_tr": "Bir çözüm bulduk."
 },
 {
  "id": "b1-success",
  "word": "success",
  "pos": "n",
  "level": "B1",
  "tr": [
   "başarı"
  ],
  "example_en": "Hard work brings success.",
  "example_tr": "Sıkı çalışma başarı getirir."
 },
 {
  "id": "b1-argument",
  "word": "argument",
  "pos": "n",
  "level": "B1",
  "tr": [
   "tartışma"
  ],
  "example_en": "They had an argument.",
  "example_tr": "Bir tartışma yaşadılar."
 },
 {
  "id": "b1-community",
  "word": "community",
  "pos": "n",
  "level": "B1",
  "tr": [
   "topluluk"
  ],
  "example_en": "Our community is small.",
  "example_tr": "Topluluğumuz küçük."
 },
 {
  "id": "b1-recently",
  "word": "recently",
  "pos": "adv",
  "level": "B1",
  "tr": [
   "son zamanlarda"
  ],
  "example_en": "I recently moved here.",
  "example_tr": "Son zamanlarda buraya taşındım."
 },
 {
  "id": "b1-probably",
  "word": "probably",
  "pos": "adv",
  "level": "B1",
  "tr": [
   "muhtemelen"
  ],
  "example_en": "It will probably rain.",
  "example_tr": "Muhtemelen yağmur yağacak."
 },
 {
  "id": "b2-reluctant",
  "word": "reluctant",
  "pos": "adj",
  "level": "B2",
  "tr": [
   "isteksiz",
   "gönülsüz"
  ],
  "example_en": "She was reluctant to leave.",
  "example_tr": "Ayrılmaya gönülsüzdü."
 },
 {
  "id": "b2-hesitate",
  "word": "hesitate",
  "pos": "v",
  "level": "B2",
  "tr": [
   "tereddüt etmek"
  ],
  "example_en": "Don't hesitate to ask.",
  "example_tr": "Sormaktan çekinme."
 },
 {
  "id": "b2-significant",
  "word": "significant",
  "pos": "adj",
  "level": "B2",
  "tr": [
   "önemli",
   "kayda değer"
  ],
  "example_en": "There was a significant increase in prices.",
  "example_tr": "Fiyatlarda kayda değer bir artış oldu."
 },
 {
  "id": "b2-consequence",
  "word": "consequence",
  "pos": "n",
  "level": "B2",
  "tr": [
   "sonuç"
  ],
  "example_en": "Every choice has a consequence.",
  "example_tr": "Her seçimin bir sonucu vardır."
 },
 {
  "id": "b2-abandon",
  "word": "abandon",
  "pos": "v",
  "level": "B2",
  "tr": [
   "terk etmek"
  ],
  "example_en": "They had to abandon the ship.",
  "example_tr": "Gemiyi terk etmek zorunda kaldılar."
 },
 {
  "id": "b2-acquire",
  "word": "acquire",
  "pos": "v",
  "level": "B2",
  "tr": [
   "edinmek",
   "elde etmek"
  ],
  "example_en": "Children acquire language fast.",
  "example_tr": "Çocuklar dili hızla edinir."
 },
 {
  "id": "b2-adapt",
  "word": "adapt",
  "pos": "v",
  "level": "B2",
  "tr": [
   "uyum sağlamak"
  ],
  "example_en": "Animals adapt to the cold.",
  "example_tr": "Hayvanlar soğuğa uyum sağlar."
 },
 {
  "id": "b2-anticipate",
  "word": "anticipate",
  "pos": "v",
  "level": "B2",
  "tr": [
   "öngörmek",
   "beklemek"
  ],
  "example_en": "We anticipate some delays.",
  "example_tr": "Bazı gecikmeler öngörüyoruz."
 },
 {
  "id": "b2-assume",
  "word": "assume",
  "pos": "v",
  "level": "B2",
  "tr": [
   "varsaymak"
  ],
  "example_en": "I assume you are tired.",
  "example_tr": "Yorgun olduğunu varsayıyorum."
 }
]
