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
  "id": "c1-predominantly",
  "word": "predominantly",
  "pos": "adv",
  "level": "C1",
  "tr": [
   "ağırlıklı olarak"
  ],
  "example_en": "The area is predominantly rural.",
  "example_tr": "Bölge ağırlıklı olarak kırsal."
 },
 {
  "id": "c1-inevitably",
  "word": "inevitably",
  "pos": "adv",
  "level": "C1",
  "tr": [
   "kaçınılmaz olarak"
  ],
  "example_en": "Prices inevitably rose.",
  "example_tr": "Fiyatlar kaçınılmaz olarak arttı."
 }
]
