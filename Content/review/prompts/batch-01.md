You are a senior English-Turkish lexicographer and an experienced teacher of English
to Turkish speakers. You review flashcards for a vocabulary app shown on the iPhone lock screen.
Be strict about real errors and relaxed about taste. Native Turkish usage matters: translations
must sound like a careful Turkish teacher wrote them, not like machine translation.

For each card, check:
1. meanings: Are the Turkish meanings (tr) correct for the given part of speech (pos)?
   Is the most common meaning first? Is a common meaning of that pos missing, one a learner
   at this level will meet often? Example of a real problem: "challenge" (n) with only
   "zorluk" misses "meydan okuma". A synonym of a meaning already listed is NOT missing
   ("cevap vermek" already covers "cevaplamak"). Keep at most 3 meanings.
   Other parts of speech of the same word are not missing meanings; list them in
   other_senses, only if they are common at this level or below.
2. example_en: Does it use the word in the card's sense and pos? Is it natural, correct
   English suited to the CEFR level? At most 55 characters.
3. example_tr: Is it a correct translation of example_en that a Turkish speaker would
   actually say? Judge idiomatic equivalence, not word-for-word match: "Don't worry about
   it." is "Merak etme." or "Dert etme.", not "Bunun için endişelenme.". It must not add or
   drop meaning: do not add words like "çok" that are not in the English. At most
   55 characters.
4. level: Is the CEFR level plausible for this word in this sense?
5. Limits: the Turkish meanings joined with ", " must be at most 28 characters.

verdict:
- "ok": correct as is. Possible improvements that are a matter of taste are not errors;
  put them in issues starting with "Öneri:" and keep the verdict "ok".
- "fix": something is wrong or misleading (a wrong or missing common meaning, the wrong
  meaning first, an unnatural or inaccurate translation, a wrong level, a length limit
  broken), and your corrected fields solve it.
- "unsure": you are not confident; say why.
confidence: "high" only when Turkish teachers would agree; "medium" when they could
differ; "low" when you are guessing.
Put corrected values only in the fix_* fields you change; leave the others empty. If you
change tr or example_en, check that example_tr still matches. Write issues in Turkish, short.

Answer with ONLY a JSON array, one object per card, same ids, same order. Each object:
{"id": "...", "verdict": "ok" | "fix" | "unsure", "issues": ["kısa Türkçe açıklama"],
 "fix_tr": [], "fix_example_en": "", "fix_example_tr": "", "fix_level": "",
 "other_senses": [{"pos": "v", "tr": ["..."], "example_en": "...", "example_tr": "..."}],
 "confidence": "high" | "medium" | "low"}
Fill fix_* only for fields you change; otherwise leave them empty. No text before or after the array.

Cards:
[
{"id":"a2-borrow","word":"borrow","pos":"v","level":"A2","tr":["ödünç almak"],"example_en":"Can I borrow your pen?","example_tr":"Kalemini ödünç alabilir miyim?"},
{"id":"a2-answer","word":"answer","pos":"v","level":"A2","tr":["cevap vermek"],"example_en":"Please answer the question.","example_tr":"Lütfen soruyu cevapla."},
{"id":"a2-arrive","word":"arrive","pos":"v","level":"A2","tr":["varmak","gelmek"],"example_en":"We arrive at six.","example_tr":"Saat altıda varıyoruz."},
{"id":"a2-believe","word":"believe","pos":"v","level":"A2","tr":["inanmak"],"example_en":"I believe you.","example_tr":"Sana inanıyorum."},
{"id":"a2-carry","word":"carry","pos":"v","level":"A2","tr":["taşımak"],"example_en":"Can you carry this bag?","example_tr":"Bu çantayı taşıyabilir misin?"},
{"id":"a2-choose","word":"choose","pos":"v","level":"A2","tr":["seçmek"],"example_en":"You can choose a color.","example_tr":"Bir renk seçebilirsin."},
{"id":"a2-decide","word":"decide","pos":"v","level":"A2","tr":["karar vermek"],"example_en":"We need to decide today.","example_tr":"Bugün karar vermemiz gerek."},
{"id":"a2-forget","word":"forget","pos":"v","level":"A2","tr":["unutmak"],"example_en":"Don't forget your keys.","example_tr":"Anahtarlarını unutma."},
{"id":"a2-invite","word":"invite","pos":"v","level":"A2","tr":["davet etmek"],"example_en":"I want to invite them.","example_tr":"Onları davet etmek istiyorum."},
{"id":"a2-laugh","word":"laugh","pos":"v","level":"A2","tr":["gülmek"],"example_en":"They always laugh together.","example_tr":"Hep birlikte gülerler."},
{"id":"a2-lose","word":"lose","pos":"v","level":"A2","tr":["kaybetmek"],"example_en":"Don't lose your ticket.","example_tr":"Biletini kaybetme."},
{"id":"a2-prefer","word":"prefer","pos":"v","level":"A2","tr":["tercih etmek"],"example_en":"I prefer tea.","example_tr":"Çayı tercih ederim."},
{"id":"a2-remember","word":"remember","pos":"v","level":"A2","tr":["hatırlamak"],"example_en":"I remember her name.","example_tr":"Onun adını hatırlıyorum."},
{"id":"a2-repair","word":"repair","pos":"v","level":"A2","tr":["tamir etmek"],"example_en":"He can repair the car.","example_tr":"Arabayı tamir edebilir."},
{"id":"a2-send","word":"send","pos":"v","level":"A2","tr":["göndermek"],"example_en":"Please send me a message.","example_tr":"Lütfen bana mesaj gönder."},
{"id":"a2-travel","word":"travel","pos":"v","level":"A2","tr":["seyahat etmek"],"example_en":"We travel every summer.","example_tr":"Her yaz seyahat ederiz."},
{"id":"a2-wait","word":"wait","pos":"v","level":"A2","tr":["beklemek"],"example_en":"Please wait here.","example_tr":"Lütfen burada bekle."},
{"id":"a2-worry","word":"worry","pos":"v","level":"A2","tr":["endişelenmek"],"example_en":"Don't worry about it.","example_tr":"Bunun için endişelenme."},
{"id":"a2-busy","word":"busy","pos":"adj","level":"A2","tr":["meşgul"],"example_en":"I am busy today.","example_tr":"Bugün meşgulüm."},
{"id":"a2-cheap","word":"cheap","pos":"adj","level":"A2","tr":["ucuz"],"example_en":"This shirt is cheap.","example_tr":"Bu gömlek ucuz."},
{"id":"a2-clean","word":"clean","pos":"adj","level":"A2","tr":["temiz"],"example_en":"The room is clean.","example_tr":"Oda temiz."},
{"id":"a2-dangerous","word":"dangerous","pos":"adj","level":"A2","tr":["tehlikeli"],"example_en":"This road is dangerous.","example_tr":"Bu yol tehlikeli."},
{"id":"a2-empty","word":"empty","pos":"adj","level":"A2","tr":["boş"],"example_en":"The bottle is empty.","example_tr":"Şişe boş."},
{"id":"a2-famous","word":"famous","pos":"adj","level":"A2","tr":["ünlü"],"example_en":"She is a famous singer.","example_tr":"O ünlü bir şarkıcı."},
{"id":"a2-friendly","word":"friendly","pos":"adj","level":"A2","tr":["samimi","cana yakın"],"example_en":"Our neighbors are friendly.","example_tr":"Komşularımız cana yakın."},
{"id":"a2-heavy","word":"heavy","pos":"adj","level":"A2","tr":["ağır"],"example_en":"This box is heavy.","example_tr":"Bu kutu ağır."},
{"id":"a2-hungry","word":"hungry","pos":"adj","level":"A2","tr":["aç"],"example_en":"I am very hungry.","example_tr":"Çok açım."},
{"id":"a2-quiet","word":"quiet","pos":"adj","level":"A2","tr":["sessiz","sakin"],"example_en":"The library is quiet.","example_tr":"Kütüphane sessiz."},
{"id":"a2-tired","word":"tired","pos":"adj","level":"A2","tr":["yorgun"],"example_en":"She looks tired.","example_tr":"Yorgun görünüyor."},
{"id":"a2-useful","word":"useful","pos":"adj","level":"A2","tr":["faydalı","kullanışlı"],"example_en":"This app is useful.","example_tr":"Bu uygulama faydalı."},
{"id":"a2-angry","word":"angry","pos":"adj","level":"A2","tr":["kızgın"],"example_en":"He was angry with me.","example_tr":"Bana kızgındı."},
{"id":"a2-strange","word":"strange","pos":"adj","level":"A2","tr":["tuhaf","garip"],"example_en":"That is a strange noise.","example_tr":"Bu garip bir ses."},
{"id":"a2-healthy","word":"healthy","pos":"adj","level":"A2","tr":["sağlıklı"],"example_en":"Eat healthy food.","example_tr":"Sağlıklı yiyecekler ye."},
{"id":"a2-lucky","word":"lucky","pos":"adj","level":"A2","tr":["şanslı"],"example_en":"You are so lucky.","example_tr":"Çok şanslısın."},
{"id":"a2-journey","word":"journey","pos":"n","level":"A2","tr":["yolculuk"],"example_en":"The journey took two hours.","example_tr":"Yolculuk iki saat sürdü."},
{"id":"a2-advice","word":"advice","pos":"n","level":"A2","tr":["tavsiye","öğüt"],"example_en":"Thanks for the advice.","example_tr":"Tavsiye için teşekkürler."},
{"id":"a2-weather","word":"weather","pos":"n","level":"A2","tr":["hava durumu"],"example_en":"The weather is nice today.","example_tr":"Bugün hava güzel."},
{"id":"a2-neighbor","word":"neighbor","pos":"n","level":"A2","tr":["komşu"],"example_en":"My neighbor is a doctor.","example_tr":"Komşum bir doktor."},
{"id":"a2-ticket","word":"ticket","pos":"n","level":"A2","tr":["bilet"],"example_en":"I bought a ticket.","example_tr":"Bir bilet aldım."},
{"id":"a2-future","word":"future","pos":"n","level":"A2","tr":["gelecek"],"example_en":"Think about your future.","example_tr":"Geleceğini düşün."},
{"id":"a2-money","word":"money","pos":"n","level":"A2","tr":["para"],"example_en":"I need some money.","example_tr":"Biraz paraya ihtiyacım var."},
{"id":"a2-gift","word":"gift","pos":"n","level":"A2","tr":["hediye"],"example_en":"This gift is for you.","example_tr":"Bu hediye senin için."},
{"id":"a2-mistake","word":"mistake","pos":"n","level":"A2","tr":["hata"],"example_en":"Everyone makes a mistake.","example_tr":"Herkes hata yapar."},
{"id":"a2-habit","word":"habit","pos":"n","level":"A2","tr":["alışkanlık"],"example_en":"Reading is a good habit.","example_tr":"Okumak iyi bir alışkanlık."},
{"id":"a2-price","word":"price","pos":"n","level":"A2","tr":["fiyat"],"example_en":"The price is too high.","example_tr":"Fiyat çok yüksek."},
{"id":"a2-reason","word":"reason","pos":"n","level":"A2","tr":["sebep","neden"],"example_en":"Tell me the reason.","example_tr":"Bana sebebini söyle."},
{"id":"a2-village","word":"village","pos":"n","level":"A2","tr":["köy"],"example_en":"They live in a village.","example_tr":"Bir köyde yaşıyorlar."},
{"id":"a2-often","word":"often","pos":"adv","level":"A2","tr":["sık sık"],"example_en":"I often walk to work.","example_tr":"Sık sık işe yürürüm."},
{"id":"a2-already","word":"already","pos":"adv","level":"A2","tr":["zaten","çoktan"],"example_en":"I have already eaten.","example_tr":"Çoktan yemek yedim."},
{"id":"a2-almost","word":"almost","pos":"adv","level":"A2","tr":["neredeyse"],"example_en":"It is almost ready.","example_tr":"Neredeyse hazır."},
{"id":"a2-together","word":"together","pos":"adv","level":"A2","tr":["birlikte"],"example_en":"Let's go together.","example_tr":"Hadi birlikte gidelim."},
{"id":"b1-reliable","word":"reliable","pos":"adj","level":"B1","tr":["güvenilir"],"example_en":"He is a reliable friend.","example_tr":"O, güvenilir bir arkadaş."},
{"id":"b1-obvious","word":"obvious","pos":"adj","level":"B1","tr":["açık","belli"],"example_en":"The answer was obvious.","example_tr":"Cevap belliydi."},
{"id":"b1-achieve","word":"achieve","pos":"v","level":"B1","tr":["başarmak"],"example_en":"You can achieve your goals.","example_tr":"Hedeflerine ulaşabilirsin."},
{"id":"b1-ancient","word":"ancient","pos":"adj","level":"B1","tr":["antik","çok eski"],"example_en":"We visited an ancient city.","example_tr":"Antik bir şehri ziyaret ettik."},
{"id":"b1-avoid","word":"avoid","pos":"v","level":"B1","tr":["kaçınmak"],"example_en":"Try to avoid sugar.","example_tr":"Şekerden kaçınmaya çalış."},
{"id":"b1-compare","word":"compare","pos":"v","level":"B1","tr":["karşılaştırmak"],"example_en":"Compare the two prices.","example_tr":"İki fiyatı karşılaştır."},
{"id":"b1-complain","word":"complain","pos":"v","level":"B1","tr":["şikâyet etmek"],"example_en":"They always complain.","example_tr":"Hep şikâyet ederler."},
{"id":"b1-develop","word":"develop","pos":"v","level":"B1","tr":["geliştirmek"],"example_en":"We develop new apps.","example_tr":"Yeni uygulamalar geliştiriyoruz."},
{"id":"b1-discover","word":"discover","pos":"v","level":"B1","tr":["keşfetmek"],"example_en":"I want to discover new places.","example_tr":"Yeni yerler keşfetmek istiyorum."},
{"id":"b1-encourage","word":"encourage","pos":"v","level":"B1","tr":["cesaretlendirmek"],"example_en":"Teachers encourage students.","example_tr":"Öğretmenler öğrencileri cesaretlendirir."},
{"id":"b1-explain","word":"explain","pos":"v","level":"B1","tr":["açıklamak"],"example_en":"Can you explain this word?","example_tr":"Bu kelimeyi açıklayabilir misin?"},
{"id":"b1-improve","word":"improve","pos":"v","level":"B1","tr":["geliştirmek","iyileştirmek"],"example_en":"I want to improve my English.","example_tr":"İngilizcemi geliştirmek istiyorum."},
{"id":"b1-include","word":"include","pos":"v","level":"B1","tr":["içermek","dahil etmek"],"example_en":"The price will include breakfast.","example_tr":"Fiyata kahvaltı dahil olacak."},
{"id":"b1-increase","word":"increase","pos":"v","level":"B1","tr":["artırmak","artmak"],"example_en":"Prices increase every year.","example_tr":"Fiyatlar her yıl artıyor."},
{"id":"b1-manage","word":"manage","pos":"v","level":"B1","tr":["yönetmek","başarmak"],"example_en":"She can manage the team.","example_tr":"Ekibi yönetebilir."},
{"id":"b1-mention","word":"mention","pos":"v","level":"B1","tr":["bahsetmek"],"example_en":"Did he mention the meeting?","example_tr":"Toplantıdan bahsetti mi?"},
{"id":"b1-notice","word":"notice","pos":"v","level":"B1","tr":["fark etmek"],"example_en":"Did you notice the change?","example_tr":"Değişikliği fark ettin mi?"}
]
