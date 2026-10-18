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
  "id": "a2-money",
  "word": "money",
  "pos": "n",
  "level": "A2",
  "tr": [
   "para"
  ],
  "example_en": "I need some money.",
  "example_tr": "Biraz paraya ihtiyacım var."
 },
 {
  "id": "a2-gift",
  "word": "gift",
  "pos": "n",
  "level": "A2",
  "tr": [
   "hediye"
  ],
  "example_en": "This gift is for you.",
  "example_tr": "Bu hediye senin için."
 },
 {
  "id": "a2-mistake",
  "word": "mistake",
  "pos": "n",
  "level": "A2",
  "tr": [
   "hata"
  ],
  "example_en": "Everyone makes a mistake.",
  "example_tr": "Herkes hata yapar."
 },
 {
  "id": "a2-habit",
  "word": "habit",
  "pos": "n",
  "level": "A2",
  "tr": [
   "alışkanlık"
  ],
  "example_en": "Reading is a good habit.",
  "example_tr": "Okumak iyi bir alışkanlık."
 },
 {
  "id": "a2-price",
  "word": "price",
  "pos": "n",
  "level": "A2",
  "tr": [
   "fiyat"
  ],
  "example_en": "The price is too high.",
  "example_tr": "Fiyat çok yüksek."
 },
 {
  "id": "a2-reason",
  "word": "reason",
  "pos": "n",
  "level": "A2",
  "tr": [
   "sebep",
   "neden"
  ],
  "example_en": "Tell me the reason.",
  "example_tr": "Bana sebebini söyle."
 },
 {
  "id": "a2-village",
  "word": "village",
  "pos": "n",
  "level": "A2",
  "tr": [
   "köy"
  ],
  "example_en": "They live in a village.",
  "example_tr": "Bir köyde yaşıyorlar."
 },
 {
  "id": "a2-often",
  "word": "often",
  "pos": "adv",
  "level": "A2",
  "tr": [
   "sık sık"
  ],
  "example_en": "I often walk to work.",
  "example_tr": "Sık sık işe yürürüm."
 },
 {
  "id": "a2-already",
  "word": "already",
  "pos": "adv",
  "level": "A2",
  "tr": [
   "zaten",
   "çoktan"
  ],
  "example_en": "I have already eaten.",
  "example_tr": "Çoktan yemek yedim."
 },
 {
  "id": "a2-almost",
  "word": "almost",
  "pos": "adv",
  "level": "A2",
  "tr": [
   "neredeyse"
  ],
  "example_en": "It is almost ready.",
  "example_tr": "Neredeyse hazır."
 },
 {
  "id": "a2-together",
  "word": "together",
  "pos": "adv",
  "level": "A2",
  "tr": [
   "birlikte"
  ],
  "example_en": "Let's go together.",
  "example_tr": "Hadi birlikte gidelim."
 },
 {
  "id": "b1-reliable",
  "word": "reliable",
  "pos": "adj",
  "level": "B1",
  "tr": [
   "güvenilir"
  ],
  "example_en": "He is a reliable friend.",
  "example_tr": "O, güvenilir bir arkadaş."
 },
 {
  "id": "b1-obvious",
  "word": "obvious",
  "pos": "adj",
  "level": "B1",
  "tr": [
   "açık",
   "belli"
  ],
  "example_en": "The answer was obvious.",
  "example_tr": "Cevap belliydi."
 },
 {
  "id": "b1-achieve",
  "word": "achieve",
  "pos": "v",
  "level": "B1",
  "tr": [
   "başarmak"
  ],
  "example_en": "You can achieve your goals.",
  "example_tr": "Hedeflerine ulaşabilirsin."
 },
 {
  "id": "b1-ancient",
  "word": "ancient",
  "pos": "adj",
  "level": "B1",
  "tr": [
   "antik",
   "çok eski"
  ],
  "example_en": "We visited an ancient city.",
  "example_tr": "Antik bir şehri ziyaret ettik."
 },
 {
  "id": "b1-avoid",
  "word": "avoid",
  "pos": "v",
  "level": "B1",
  "tr": [
   "kaçınmak"
  ],
  "example_en": "Try to avoid sugar.",
  "example_tr": "Şekerden kaçınmaya çalış."
 },
 {
  "id": "b1-compare",
  "word": "compare",
  "pos": "v",
  "level": "B1",
  "tr": [
   "karşılaştırmak"
  ],
  "example_en": "Compare the two prices.",
  "example_tr": "İki fiyatı karşılaştır."
 },
 {
  "id": "b1-complain",
  "word": "complain",
  "pos": "v",
  "level": "B1",
  "tr": [
   "şikâyet etmek"
  ],
  "example_en": "They always complain.",
  "example_tr": "Hep şikâyet ederler."
 },
 {
  "id": "b1-develop",
  "word": "develop",
  "pos": "v",
  "level": "B1",
  "tr": [
   "geliştirmek"
  ],
  "example_en": "We develop new apps.",
  "example_tr": "Yeni uygulamalar geliştiriyoruz."
 },
 {
  "id": "b1-discover",
  "word": "discover",
  "pos": "v",
  "level": "B1",
  "tr": [
   "keşfetmek"
  ],
  "example_en": "I want to discover new places.",
  "example_tr": "Yeni yerler keşfetmek istiyorum."
 },
 {
  "id": "b1-encourage",
  "word": "encourage",
  "pos": "v",
  "level": "B1",
  "tr": [
   "cesaretlendirmek"
  ],
  "example_en": "Teachers encourage students.",
  "example_tr": "Öğretmenler öğrencileri cesaretlendirir."
 },
 {
  "id": "b1-explain",
  "word": "explain",
  "pos": "v",
  "level": "B1",
  "tr": [
   "açıklamak"
  ],
  "example_en": "Can you explain this word?",
  "example_tr": "Bu kelimeyi açıklayabilir misin?"
 },
 {
  "id": "b1-improve",
  "word": "improve",
  "pos": "v",
  "level": "B1",
  "tr": [
   "geliştirmek",
   "iyileştirmek"
  ],
  "example_en": "I want to improve my English.",
  "example_tr": "İngilizcemi geliştirmek istiyorum."
 },
 {
  "id": "b1-include",
  "word": "include",
  "pos": "v",
  "level": "B1",
  "tr": [
   "içermek",
   "dahil etmek"
  ],
  "example_en": "The price will include breakfast.",
  "example_tr": "Fiyata kahvaltı dahil olacak."
 },
 {
  "id": "b1-increase",
  "word": "increase",
  "pos": "v",
  "level": "B1",
  "tr": [
   "artırmak",
   "artmak"
  ],
  "example_en": "Prices increase every year.",
  "example_tr": "Fiyatlar her yıl artıyor."
 },
 {
  "id": "b1-manage",
  "word": "manage",
  "pos": "v",
  "level": "B1",
  "tr": [
   "yönetmek",
   "başarmak"
  ],
  "example_en": "She can manage the team.",
  "example_tr": "Ekibi yönetebilir."
 },
 {
  "id": "b1-mention",
  "word": "mention",
  "pos": "v",
  "level": "B1",
  "tr": [
   "bahsetmek"
  ],
  "example_en": "Did he mention the meeting?",
  "example_tr": "Toplantıdan bahsetti mi?"
 },
 {
  "id": "b1-notice",
  "word": "notice",
  "pos": "v",
  "level": "B1",
  "tr": [
   "fark etmek"
  ],
  "example_en": "Did you notice the change?",
  "example_tr": "Değişikliği fark ettin mi?"
 },
 {
  "id": "b1-offer",
  "word": "offer",
  "pos": "v",
  "level": "B1",
  "tr": [
   "teklif etmek",
   "sunmak"
  ],
  "example_en": "They offer free coffee.",
  "example_tr": "Ücretsiz kahve sunuyorlar."
 },
 {
  "id": "b1-protect",
  "word": "protect",
  "pos": "v",
  "level": "B1",
  "tr": [
   "korumak"
  ],
  "example_en": "Sunscreen can protect your skin.",
  "example_tr": "Güneş kremi cildini koruyabilir."
 },
 {
  "id": "b1-realize",
  "word": "realize",
  "pos": "v",
  "level": "B1",
  "tr": [
   "fark etmek",
   "anlamak"
  ],
  "example_en": "I didn't realize it was late.",
  "example_tr": "Geç olduğunu fark etmedim."
 },
 {
  "id": "b1-reduce",
  "word": "reduce",
  "pos": "v",
  "level": "B1",
  "tr": [
   "azaltmak"
  ],
  "example_en": "We must reduce waste.",
  "example_tr": "Atığı azaltmalıyız."
 },
 {
  "id": "b1-refuse",
  "word": "refuse",
  "pos": "v",
  "level": "B1",
  "tr": [
   "reddetmek"
  ],
  "example_en": "He may refuse the offer.",
  "example_tr": "Teklifi reddedebilir."
 },
 {
  "id": "b1-replace",
  "word": "replace",
  "pos": "v",
  "level": "B1",
  "tr": [
   "değiştirmek",
   "yerine koymak"
  ],
  "example_en": "We need to replace the battery.",
  "example_tr": "Pili değiştirmemiz gerek."
 },
 {
  "id": "b1-succeed",
  "word": "succeed",
  "pos": "v",
  "level": "B1",
  "tr": [
   "başarılı olmak"
  ],
  "example_en": "I hope you succeed.",
  "example_tr": "Umarım başarılı olursun."
 },
 {
  "id": "b1-suggest",
  "word": "suggest",
  "pos": "v",
  "level": "B1",
  "tr": [
   "önermek"
  ],
  "example_en": "I suggest a short break.",
  "example_tr": "Kısa bir mola öneririm."
 },
 {
  "id": "b1-support",
  "word": "support",
  "pos": "v",
  "level": "B1",
  "tr": [
   "desteklemek"
  ],
  "example_en": "Friends support each other.",
  "example_tr": "Arkadaşlar birbirini destekler."
 },
 {
  "id": "b1-apologize",
  "word": "apologize",
  "pos": "v",
  "level": "B1",
  "tr": [
   "özür dilemek"
  ],
  "example_en": "You should apologize to her.",
  "example_tr": "Ondan özür dilemelisin."
 },
 {
  "id": "b1-afford",
  "word": "afford",
  "pos": "v",
  "level": "B1",
  "tr": [
   "gücü yetmek"
  ],
  "example_en": "I can't afford a new car.",
  "example_tr": "Yeni bir arabaya gücüm yetmez."
 },
 {
  "id": "b1-argue",
  "word": "argue",
  "pos": "v",
  "level": "B1",
  "tr": [
   "tartışmak"
  ],
  "example_en": "They argue about money.",
  "example_tr": "Para yüzünden tartışırlar."
 }
]
