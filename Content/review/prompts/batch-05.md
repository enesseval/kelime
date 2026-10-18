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
  "id": "b2-outcome",
  "word": "outcome",
  "pos": "n",
  "level": "B2",
  "tr": [
   "sonuç"
  ],
  "example_en": "The outcome was positive.",
  "example_tr": "Sonuç olumluydu."
 },
 {
  "id": "b2-priority",
  "word": "priority",
  "pos": "n",
  "level": "B2",
  "tr": [
   "öncelik"
  ],
  "example_en": "Health is my priority.",
  "example_tr": "Sağlık benim önceliğim."
 },
 {
  "id": "b2-resource",
  "word": "resource",
  "pos": "n",
  "level": "B2",
  "tr": [
   "kaynak"
  ],
  "example_en": "Water is a precious resource.",
  "example_tr": "Su değerli bir kaynaktır."
 },
 {
  "id": "b2-strategy",
  "word": "strategy",
  "pos": "n",
  "level": "B2",
  "tr": [
   "strateji"
  ],
  "example_en": "We need a clear strategy.",
  "example_tr": "Net bir stratejiye ihtiyacımız var."
 },
 {
  "id": "b2-tendency",
  "word": "tendency",
  "pos": "n",
  "level": "B2",
  "tr": [
   "eğilim"
  ],
  "example_en": "He has a tendency to worry.",
  "example_tr": "Endişelenme eğilimi var."
 },
 {
  "id": "b2-threat",
  "word": "threat",
  "pos": "n",
  "level": "B2",
  "tr": [
   "tehdit"
  ],
  "example_en": "Pollution is a serious threat.",
  "example_tr": "Kirlilik ciddi bir tehdit."
 },
 {
  "id": "b2-burden",
  "word": "burden",
  "pos": "n",
  "level": "B2",
  "tr": [
   "yük"
  ],
  "example_en": "Debt is a heavy burden.",
  "example_tr": "Borç ağır bir yüktür."
 },
 {
  "id": "b2-shortage",
  "word": "shortage",
  "pos": "n",
  "level": "B2",
  "tr": [
   "kıtlık",
   "eksiklik"
  ],
  "example_en": "There is a water shortage.",
  "example_tr": "Su kıtlığı var."
 },
 {
  "id": "b2-eventually",
  "word": "eventually",
  "pos": "adv",
  "level": "B2",
  "tr": [
   "sonunda"
  ],
  "example_en": "He eventually agreed.",
  "example_tr": "Sonunda kabul etti."
 },
 {
  "id": "b2-merely",
  "word": "merely",
  "pos": "adv",
  "level": "B2",
  "tr": [
   "sadece",
   "yalnızca"
  ],
  "example_en": "It was merely a joke.",
  "example_tr": "Sadece bir şakaydı."
 },
 {
  "id": "b2-nevertheless",
  "word": "nevertheless",
  "pos": "adv",
  "level": "B2",
  "tr": [
   "yine de"
  ],
  "example_en": "It was hard; nevertheless, we won.",
  "example_tr": "Zordu; yine de kazandık."
 },
 {
  "id": "c1-ambiguous",
  "word": "ambiguous",
  "pos": "adj",
  "level": "C1",
  "tr": [
   "belirsiz",
   "muğlak"
  ],
  "example_en": "The message was ambiguous.",
  "example_tr": "Mesaj muğlaktı."
 },
 {
  "id": "c1-arbitrary",
  "word": "arbitrary",
  "pos": "adj",
  "level": "C1",
  "tr": [
   "keyfi"
  ],
  "example_en": "The rule seems arbitrary.",
  "example_tr": "Kural keyfi görünüyor."
 },
 {
  "id": "c1-coherent",
  "word": "coherent",
  "pos": "adj",
  "level": "C1",
  "tr": [
   "tutarlı"
  ],
  "example_en": "Give a coherent answer.",
  "example_tr": "Tutarlı bir cevap ver."
 },
 {
  "id": "c1-comprehensive",
  "word": "comprehensive",
  "pos": "adj",
  "level": "C1",
  "tr": [
   "kapsamlı"
  ],
  "example_en": "We need a comprehensive plan.",
  "example_tr": "Kapsamlı bir plana ihtiyacımız var."
 },
 {
  "id": "c1-explicit",
  "word": "explicit",
  "pos": "adj",
  "level": "C1",
  "tr": [
   "açık",
   "net"
  ],
  "example_en": "The rules are explicit.",
  "example_tr": "Kurallar açık."
 },
 {
  "id": "c1-feasible",
  "word": "feasible",
  "pos": "adj",
  "level": "C1",
  "tr": [
   "uygulanabilir"
  ],
  "example_en": "Is the plan feasible?",
  "example_tr": "Plan uygulanabilir mi?"
 },
 {
  "id": "c1-inherent",
  "word": "inherent",
  "pos": "adj",
  "level": "C1",
  "tr": [
   "doğasında olan"
  ],
  "example_en": "Risk is inherent in business.",
  "example_tr": "Risk işin doğasında vardır."
 },
 {
  "id": "c1-meticulous",
  "word": "meticulous",
  "pos": "adj",
  "level": "C1",
  "tr": [
   "titiz",
   "özenli"
  ],
  "example_en": "She is a meticulous editor.",
  "example_tr": "O titiz bir editör."
 },
 {
  "id": "c1-plausible",
  "word": "plausible",
  "pos": "adj",
  "level": "C1",
  "tr": [
   "akla yatkın"
  ],
  "example_en": "His story sounds plausible.",
  "example_tr": "Hikâyesi akla yatkın geliyor."
 },
 {
  "id": "c1-profound",
  "word": "profound",
  "pos": "adj",
  "level": "C1",
  "tr": [
   "derin"
  ],
  "example_en": "The book had a profound effect.",
  "example_tr": "Kitabın derin bir etkisi oldu."
 },
 {
  "id": "c1-redundant",
  "word": "redundant",
  "pos": "adj",
  "level": "C1",
  "tr": [
   "gereksiz",
   "fazla"
  ],
  "example_en": "This step is redundant.",
  "example_tr": "Bu adım gereksiz."
 },
 {
  "id": "c1-subtle",
  "word": "subtle",
  "pos": "adj",
  "level": "C1",
  "tr": [
   "ince",
   "belli belirsiz"
  ],
  "example_en": "There is a subtle difference.",
  "example_tr": "İnce bir fark var."
 },
 {
  "id": "c1-tedious",
  "word": "tedious",
  "pos": "adj",
  "level": "C1",
  "tr": [
   "sıkıcı",
   "usandırıcı"
  ],
  "example_en": "The work was tedious.",
  "example_tr": "İş sıkıcıydı."
 },
 {
  "id": "c1-undermine",
  "word": "undermine",
  "pos": "v",
  "level": "C1",
  "tr": [
   "baltalamak"
  ],
  "example_en": "Lies undermine trust.",
  "example_tr": "Yalanlar güveni baltalar."
 },
 {
  "id": "c1-alleviate",
  "word": "alleviate",
  "pos": "v",
  "level": "C1",
  "tr": [
   "hafifletmek"
  ],
  "example_en": "This will alleviate the pain.",
  "example_tr": "Bu acıyı hafifletecek."
 },
 {
  "id": "c1-compensate",
  "word": "compensate",
  "pos": "v",
  "level": "C1",
  "tr": [
   "telafi etmek"
  ],
  "example_en": "Nothing can compensate for it.",
  "example_tr": "Hiçbir şey bunu telafi edemez."
 },
 {
  "id": "c1-deteriorate",
  "word": "deteriorate",
  "pos": "v",
  "level": "C1",
  "tr": [
   "kötüleşmek"
  ],
  "example_en": "His health began to deteriorate.",
  "example_tr": "Sağlığı kötüleşmeye başladı."
 },
 {
  "id": "c1-exacerbate",
  "word": "exacerbate",
  "pos": "v",
  "level": "C1",
  "tr": [
   "şiddetlendirmek"
  ],
  "example_en": "Stress can exacerbate pain.",
  "example_tr": "Stres ağrıyı şiddetlendirebilir."
 },
 {
  "id": "c1-facilitate",
  "word": "facilitate",
  "pos": "v",
  "level": "C1",
  "tr": [
   "kolaylaştırmak"
  ],
  "example_en": "Maps facilitate travel.",
  "example_tr": "Haritalar seyahati kolaylaştırır."
 },
 {
  "id": "c1-hinder",
  "word": "hinder",
  "pos": "v",
  "level": "C1",
  "tr": [
   "engellemek"
  ],
  "example_en": "Noise can hinder sleep.",
  "example_tr": "Gürültü uykuyu engelleyebilir."
 },
 {
  "id": "c1-mitigate",
  "word": "mitigate",
  "pos": "v",
  "level": "C1",
  "tr": [
   "azaltmak",
   "hafifletmek"
  ],
  "example_en": "Trees mitigate the heat.",
  "example_tr": "Ağaçlar sıcağı azaltır."
 },
 {
  "id": "c1-scrutinize",
  "word": "scrutinize",
  "pos": "v",
  "level": "C1",
  "tr": [
   "incelemek"
  ],
  "example_en": "They scrutinize every detail.",
  "example_tr": "Her ayrıntıyı incelerler."
 },
 {
  "id": "c1-advocate",
  "word": "advocate",
  "pos": "v",
  "level": "C1",
  "tr": [
   "savunmak"
  ],
  "example_en": "They advocate free education.",
  "example_tr": "Ücretsiz eğitimi savunuyorlar."
 },
 {
  "id": "c1-discrepancy",
  "word": "discrepancy",
  "pos": "n",
  "level": "C1",
  "tr": [
   "tutarsızlık"
  ],
  "example_en": "There is a discrepancy here.",
  "example_tr": "Burada bir tutarsızlık var."
 },
 {
  "id": "c1-dilemma",
  "word": "dilemma",
  "pos": "n",
  "level": "C1",
  "tr": [
   "ikilem"
  ],
  "example_en": "She faced a moral dilemma.",
  "example_tr": "Ahlaki bir ikilemle karşılaştı."
 },
 {
  "id": "c1-hypothesis",
  "word": "hypothesis",
  "pos": "n",
  "level": "C1",
  "tr": [
   "hipotez"
  ],
  "example_en": "Test your hypothesis.",
  "example_tr": "Hipotezini test et."
 },
 {
  "id": "c1-paradigm",
  "word": "paradigm",
  "pos": "n",
  "level": "C1",
  "tr": [
   "paradigma"
  ],
  "example_en": "This is a new paradigm.",
  "example_tr": "Bu yeni bir paradigma."
 },
 {
  "id": "c1-scarcity",
  "word": "scarcity",
  "pos": "n",
  "level": "C1",
  "tr": [
   "kıtlık"
  ],
  "example_en": "Scarcity raises prices.",
  "example_tr": "Kıtlık fiyatları artırır."
 },
 {
  "id": "c1-consensus",
  "word": "consensus",
  "pos": "n",
  "level": "C1",
  "tr": [
   "fikir birliği",
   "uzlaşma"
  ],
  "example_en": "They reached a consensus.",
  "example_tr": "Fikir birliğine vardılar."
 }
]
