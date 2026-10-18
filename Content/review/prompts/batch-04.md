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
  "id": "b2-attempt",
  "word": "attempt",
  "pos": "v",
  "level": "B2",
  "tr": [
   "denemek",
   "girişmek"
  ],
  "example_en": "He will attempt the climb.",
  "example_tr": "Tırmanışı deneyecek."
 },
 {
  "id": "b2-claim",
  "word": "claim",
  "pos": "v",
  "level": "B2",
  "tr": [
   "iddia etmek"
  ],
  "example_en": "They claim it is safe.",
  "example_tr": "Güvenli olduğunu iddia ediyorlar."
 },
 {
  "id": "b2-concern",
  "word": "concern",
  "pos": "n",
  "level": "B2",
  "tr": [
   "endişe"
  ],
  "example_en": "Safety is our main concern.",
  "example_tr": "Güvenlik ana endişemiz."
 },
 {
  "id": "b2-consist",
  "word": "consist",
  "pos": "v",
  "level": "B2",
  "tr": [
   "oluşmak"
  ],
  "example_en": "The team will consist of five people.",
  "example_tr": "Ekip beş kişiden oluşacak."
 },
 {
  "id": "b2-convince",
  "word": "convince",
  "pos": "v",
  "level": "B2",
  "tr": [
   "ikna etmek"
  ],
  "example_en": "Try to convince your boss.",
  "example_tr": "Patronunu ikna etmeye çalış."
 },
 {
  "id": "b2-decline",
  "word": "decline",
  "pos": "v",
  "level": "B2",
  "tr": [
   "azalmak",
   "reddetmek"
  ],
  "example_en": "Sales began to decline.",
  "example_tr": "Satışlar azalmaya başladı."
 },
 {
  "id": "b2-demonstrate",
  "word": "demonstrate",
  "pos": "v",
  "level": "B2",
  "tr": [
   "göstermek",
   "kanıtlamak"
  ],
  "example_en": "The test will demonstrate it.",
  "example_tr": "Test bunu gösterecek."
 },
 {
  "id": "b2-emphasize",
  "word": "emphasize",
  "pos": "v",
  "level": "B2",
  "tr": [
   "vurgulamak"
  ],
  "example_en": "I want to emphasize this point.",
  "example_tr": "Bu noktayı vurgulamak istiyorum."
 },
 {
  "id": "b2-enhance",
  "word": "enhance",
  "pos": "v",
  "level": "B2",
  "tr": [
   "artırmak",
   "geliştirmek"
  ],
  "example_en": "Music can enhance your mood.",
  "example_tr": "Müzik ruh halini iyileştirebilir."
 },
 {
  "id": "b2-establish",
  "word": "establish",
  "pos": "v",
  "level": "B2",
  "tr": [
   "kurmak"
  ],
  "example_en": "They want to establish a company.",
  "example_tr": "Bir şirket kurmak istiyorlar."
 },
 {
  "id": "b2-evaluate",
  "word": "evaluate",
  "pos": "v",
  "level": "B2",
  "tr": [
   "değerlendirmek"
  ],
  "example_en": "We evaluate every idea.",
  "example_tr": "Her fikri değerlendiririz."
 },
 {
  "id": "b2-ignore",
  "word": "ignore",
  "pos": "v",
  "level": "B2",
  "tr": [
   "görmezden gelmek"
  ],
  "example_en": "Don't ignore the warning.",
  "example_tr": "Uyarıyı görmezden gelme."
 },
 {
  "id": "b2-indicate",
  "word": "indicate",
  "pos": "v",
  "level": "B2",
  "tr": [
   "göstermek",
   "işaret etmek"
  ],
  "example_en": "The signs indicate a storm.",
  "example_tr": "İşaretler bir fırtınayı gösteriyor."
 },
 {
  "id": "b2-maintain",
  "word": "maintain",
  "pos": "v",
  "level": "B2",
  "tr": [
   "sürdürmek",
   "korumak"
  ],
  "example_en": "It is hard to maintain focus.",
  "example_tr": "Odağı korumak zor."
 },
 {
  "id": "b2-obtain",
  "word": "obtain",
  "pos": "v",
  "level": "B2",
  "tr": [
   "elde etmek"
  ],
  "example_en": "You must obtain a visa.",
  "example_tr": "Vize almalısın."
 },
 {
  "id": "b2-persuade",
  "word": "persuade",
  "pos": "v",
  "level": "B2",
  "tr": [
   "ikna etmek"
  ],
  "example_en": "She tried to persuade me.",
  "example_tr": "Beni ikna etmeye çalıştı."
 },
 {
  "id": "b2-pursue",
  "word": "pursue",
  "pos": "v",
  "level": "B2",
  "tr": [
   "peşinden gitmek"
  ],
  "example_en": "You should pursue your dreams.",
  "example_tr": "Hayallerinin peşinden gitmelisin."
 },
 {
  "id": "b2-require",
  "word": "require",
  "pos": "v",
  "level": "B2",
  "tr": [
   "gerektirmek"
  ],
  "example_en": "This job will require patience.",
  "example_tr": "Bu iş sabır gerektirecek."
 },
 {
  "id": "b2-reveal",
  "word": "reveal",
  "pos": "v",
  "level": "B2",
  "tr": [
   "ortaya çıkarmak"
  ],
  "example_en": "The study will reveal the truth.",
  "example_tr": "Çalışma gerçeği ortaya çıkaracak."
 },
 {
  "id": "b2-tend",
  "word": "tend",
  "pos": "v",
  "level": "B2",
  "tr": [
   "eğiliminde olmak"
  ],
  "example_en": "People tend to forget names.",
  "example_tr": "İnsanlar isimleri unutmaya meyillidir."
 },
 {
  "id": "b2-undergo",
  "word": "undergo",
  "pos": "v",
  "level": "B2",
  "tr": [
   "geçirmek",
   "maruz kalmak"
  ],
  "example_en": "He will undergo surgery.",
  "example_tr": "Ameliyat olacak."
 },
 {
  "id": "b2-adequate",
  "word": "adequate",
  "pos": "adj",
  "level": "B2",
  "tr": [
   "yeterli"
  ],
  "example_en": "The room has adequate light.",
  "example_tr": "Odada yeterli ışık var."
 },
 {
  "id": "b2-apparent",
  "word": "apparent",
  "pos": "adj",
  "level": "B2",
  "tr": [
   "belli",
   "görünürdeki"
  ],
  "example_en": "The problem became apparent.",
  "example_tr": "Sorun belli oldu."
 },
 {
  "id": "b2-considerable",
  "word": "considerable",
  "pos": "adj",
  "level": "B2",
  "tr": [
   "epey",
   "önemli ölçüde"
  ],
  "example_en": "It costs a considerable amount.",
  "example_tr": "Epey bir paraya mal oluyor."
 },
 {
  "id": "b2-crucial",
  "word": "crucial",
  "pos": "adj",
  "level": "B2",
  "tr": [
   "çok önemli",
   "kritik"
  ],
  "example_en": "Sleep is crucial for health.",
  "example_tr": "Uyku sağlık için çok önemli."
 },
 {
  "id": "b2-essential",
  "word": "essential",
  "pos": "adj",
  "level": "B2",
  "tr": [
   "temel",
   "gerekli"
  ],
  "example_en": "Water is essential for life.",
  "example_tr": "Su yaşam için gereklidir."
 },
 {
  "id": "b2-evident",
  "word": "evident",
  "pos": "adj",
  "level": "B2",
  "tr": [
   "açık",
   "belli"
  ],
  "example_en": "Her talent was evident.",
  "example_tr": "Yeteneği belliydi."
 },
 {
  "id": "b2-inevitable",
  "word": "inevitable",
  "pos": "adj",
  "level": "B2",
  "tr": [
   "kaçınılmaz"
  ],
  "example_en": "Change is inevitable.",
  "example_tr": "Değişim kaçınılmazdır."
 },
 {
  "id": "b2-reasonable",
  "word": "reasonable",
  "pos": "adj",
  "level": "B2",
  "tr": [
   "makul"
  ],
  "example_en": "The price is reasonable.",
  "example_tr": "Fiyat makul."
 },
 {
  "id": "b2-sufficient",
  "word": "sufficient",
  "pos": "adj",
  "level": "B2",
  "tr": [
   "yeterli"
  ],
  "example_en": "We have sufficient time.",
  "example_tr": "Yeterli zamanımız var."
 },
 {
  "id": "b2-vast",
  "word": "vast",
  "pos": "adj",
  "level": "B2",
  "tr": [
   "çok geniş",
   "engin"
  ],
  "example_en": "The desert is vast.",
  "example_tr": "Çöl uçsuz bucaksız."
 },
 {
  "id": "b2-vulnerable",
  "word": "vulnerable",
  "pos": "adj",
  "level": "B2",
  "tr": [
   "savunmasız"
  ],
  "example_en": "Babies are vulnerable.",
  "example_tr": "Bebekler savunmasızdır."
 },
 {
  "id": "b2-anxious",
  "word": "anxious",
  "pos": "adj",
  "level": "B2",
  "tr": [
   "kaygılı",
   "endişeli"
  ],
  "example_en": "I feel anxious before exams.",
  "example_tr": "Sınavlardan önce kaygılanırım."
 },
 {
  "id": "b2-genuine",
  "word": "genuine",
  "pos": "adj",
  "level": "B2",
  "tr": [
   "gerçek",
   "samimi"
  ],
  "example_en": "She showed genuine interest.",
  "example_tr": "Samimi bir ilgi gösterdi."
 },
 {
  "id": "b2-rapid",
  "word": "rapid",
  "pos": "adj",
  "level": "B2",
  "tr": [
   "hızlı"
  ],
  "example_en": "The city saw rapid growth.",
  "example_tr": "Şehir hızlı bir büyüme yaşadı."
 },
 {
  "id": "b2-approach",
  "word": "approach",
  "pos": "n",
  "level": "B2",
  "tr": [
   "yaklaşım"
  ],
  "example_en": "We need a new approach.",
  "example_tr": "Yeni bir yaklaşıma ihtiyacımız var."
 },
 {
  "id": "b2-assessment",
  "word": "assessment",
  "pos": "n",
  "level": "B2",
  "tr": [
   "değerlendirme"
  ],
  "example_en": "The assessment took an hour.",
  "example_tr": "Değerlendirme bir saat sürdü."
 },
 {
  "id": "b2-evidence",
  "word": "evidence",
  "pos": "n",
  "level": "B2",
  "tr": [
   "kanıt"
  ],
  "example_en": "There is no evidence.",
  "example_tr": "Hiç kanıt yok."
 },
 {
  "id": "b2-feature",
  "word": "feature",
  "pos": "n",
  "level": "B2",
  "tr": [
   "özellik"
  ],
  "example_en": "This phone has a new feature.",
  "example_tr": "Bu telefonun yeni bir özelliği var."
 },
 {
  "id": "b2-impact",
  "word": "impact",
  "pos": "n",
  "level": "B2",
  "tr": [
   "etki"
  ],
  "example_en": "Social media has a big impact.",
  "example_tr": "Sosyal medyanın büyük bir etkisi var."
 }
]
