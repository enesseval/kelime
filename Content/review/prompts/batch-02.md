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
{"id":"b1-offer","word":"offer","pos":"v","level":"B1","tr":["teklif etmek","sunmak"],"example_en":"They offer free coffee.","example_tr":"Ücretsiz kahve sunuyorlar."},
{"id":"b1-protect","word":"protect","pos":"v","level":"B1","tr":["korumak"],"example_en":"Sunscreen can protect your skin.","example_tr":"Güneş kremi cildini koruyabilir."},
{"id":"b1-realize","word":"realize","pos":"v","level":"B1","tr":["fark etmek","anlamak"],"example_en":"I didn't realize it was late.","example_tr":"Geç olduğunu fark etmedim."},
{"id":"b1-reduce","word":"reduce","pos":"v","level":"B1","tr":["azaltmak"],"example_en":"We must reduce waste.","example_tr":"Atığı azaltmalıyız."},
{"id":"b1-refuse","word":"refuse","pos":"v","level":"B1","tr":["reddetmek"],"example_en":"He may refuse the offer.","example_tr":"Teklifi reddedebilir."},
{"id":"b1-replace","word":"replace","pos":"v","level":"B1","tr":["değiştirmek","yerine koymak"],"example_en":"We need to replace the battery.","example_tr":"Pili değiştirmemiz gerek."},
{"id":"b1-succeed","word":"succeed","pos":"v","level":"B1","tr":["başarılı olmak"],"example_en":"I hope you succeed.","example_tr":"Umarım başarılı olursun."},
{"id":"b1-suggest","word":"suggest","pos":"v","level":"B1","tr":["önermek"],"example_en":"I suggest a short break.","example_tr":"Kısa bir mola öneririm."},
{"id":"b1-support","word":"support","pos":"v","level":"B1","tr":["desteklemek"],"example_en":"Friends support each other.","example_tr":"Arkadaşlar birbirini destekler."},
{"id":"b1-apologize","word":"apologize","pos":"v","level":"B1","tr":["özür dilemek"],"example_en":"You should apologize to her.","example_tr":"Ondan özür dilemelisin."},
{"id":"b1-afford","word":"afford","pos":"v","level":"B1","tr":["gücü yetmek"],"example_en":"I can't afford a new car.","example_tr":"Yeni bir arabaya gücüm yetmez."},
{"id":"b1-argue","word":"argue","pos":"v","level":"B1","tr":["tartışmak"],"example_en":"They argue about money.","example_tr":"Para yüzünden tartışırlar."},
{"id":"b1-accurate","word":"accurate","pos":"adj","level":"B1","tr":["doğru","kesin"],"example_en":"The map is accurate.","example_tr":"Harita doğru."},
{"id":"b1-available","word":"available","pos":"adj","level":"B1","tr":["mevcut","müsait"],"example_en":"Is this seat available?","example_tr":"Bu koltuk boş mu?"},
{"id":"b1-aware","word":"aware","pos":"adj","level":"B1","tr":["farkında"],"example_en":"Are you aware of the risk?","example_tr":"Riskin farkında mısın?"},
{"id":"b1-confident","word":"confident","pos":"adj","level":"B1","tr":["kendinden emin"],"example_en":"She looks confident.","example_tr":"Kendinden emin görünüyor."},
{"id":"b1-curious","word":"curious","pos":"adj","level":"B1","tr":["meraklı"],"example_en":"Children are curious.","example_tr":"Çocuklar meraklıdır."},
{"id":"b1-efficient","word":"efficient","pos":"adj","level":"B1","tr":["verimli"],"example_en":"This engine is efficient.","example_tr":"Bu motor verimli."},
{"id":"b1-familiar","word":"familiar","pos":"adj","level":"B1","tr":["tanıdık"],"example_en":"Your face looks familiar.","example_tr":"Yüzün tanıdık geliyor."},
{"id":"b1-honest","word":"honest","pos":"adj","level":"B1","tr":["dürüst"],"example_en":"Please be honest with me.","example_tr":"Lütfen bana karşı dürüst ol."},
{"id":"b1-necessary","word":"necessary","pos":"adj","level":"B1","tr":["gerekli"],"example_en":"Is it necessary to wait?","example_tr":"Beklemek gerekli mi?"},
{"id":"b1-patient","word":"patient","pos":"adj","level":"B1","tr":["sabırlı"],"example_en":"Be patient with children.","example_tr":"Çocuklara karşı sabırlı ol."},
{"id":"b1-polite","word":"polite","pos":"adj","level":"B1","tr":["kibar"],"example_en":"He is always polite.","example_tr":"O her zaman kibar."},
{"id":"b1-proud","word":"proud","pos":"adj","level":"B1","tr":["gururlu"],"example_en":"I am proud of you.","example_tr":"Seninle gurur duyuyorum."},
{"id":"b1-similar","word":"similar","pos":"adj","level":"B1","tr":["benzer"],"example_en":"Our ideas are similar.","example_tr":"Fikirlerimiz benzer."},
{"id":"b1-suitable","word":"suitable","pos":"adj","level":"B1","tr":["uygun"],"example_en":"This film is suitable for kids.","example_tr":"Bu film çocuklar için uygun."},
{"id":"b1-various","word":"various","pos":"adj","level":"B1","tr":["çeşitli"],"example_en":"We sell various books.","example_tr":"Çeşitli kitaplar satıyoruz."},
{"id":"b1-opportunity","word":"opportunity","pos":"n","level":"B1","tr":["fırsat"],"example_en":"This is a great opportunity.","example_tr":"Bu harika bir fırsat."},
{"id":"b1-advantage","word":"advantage","pos":"n","level":"B1","tr":["avantaj"],"example_en":"Speed is our advantage.","example_tr":"Hız bizim avantajımız."},
{"id":"b1-attitude","word":"attitude","pos":"n","level":"B1","tr":["tutum","tavır"],"example_en":"She has a positive attitude.","example_tr":"Olumlu bir tavrı var."},
{"id":"b1-challenge","word":"challenge","pos":"n","level":"B1","tr":["zorluk"],"example_en":"Learning is a challenge.","example_tr":"Öğrenmek zorlu bir iştir."},
{"id":"b1-decision","word":"decision","pos":"n","level":"B1","tr":["karar"],"example_en":"It was a hard decision.","example_tr":"Zor bir karardı."},
{"id":"b1-environment","word":"environment","pos":"n","level":"B1","tr":["çevre"],"example_en":"We must protect the environment.","example_tr":"Çevreyi korumalıyız."},
{"id":"b1-experience","word":"experience","pos":"n","level":"B1","tr":["deneyim"],"example_en":"She has a lot of experience.","example_tr":"Çok deneyimi var."},
{"id":"b1-knowledge","word":"knowledge","pos":"n","level":"B1","tr":["bilgi"],"example_en":"Knowledge is power.","example_tr":"Bilgi güçtür."},
{"id":"b1-purpose","word":"purpose","pos":"n","level":"B1","tr":["amaç"],"example_en":"What is the purpose of this?","example_tr":"Bunun amacı ne?"},
{"id":"b1-skill","word":"skill","pos":"n","level":"B1","tr":["beceri"],"example_en":"Writing is a useful skill.","example_tr":"Yazmak faydalı bir beceri."},
{"id":"b1-solution","word":"solution","pos":"n","level":"B1","tr":["çözüm"],"example_en":"We found a solution.","example_tr":"Bir çözüm bulduk."},
{"id":"b1-success","word":"success","pos":"n","level":"B1","tr":["başarı"],"example_en":"Hard work brings success.","example_tr":"Sıkı çalışma başarı getirir."},
{"id":"b1-argument","word":"argument","pos":"n","level":"B1","tr":["tartışma"],"example_en":"They had an argument.","example_tr":"Bir tartışma yaşadılar."},
{"id":"b1-community","word":"community","pos":"n","level":"B1","tr":["topluluk"],"example_en":"Our community is small.","example_tr":"Topluluğumuz küçük."},
{"id":"b1-recently","word":"recently","pos":"adv","level":"B1","tr":["son zamanlarda"],"example_en":"I recently moved here.","example_tr":"Son zamanlarda buraya taşındım."},
{"id":"b1-probably","word":"probably","pos":"adv","level":"B1","tr":["muhtemelen"],"example_en":"It will probably rain.","example_tr":"Muhtemelen yağmur yağacak."},
{"id":"b2-reluctant","word":"reluctant","pos":"adj","level":"B2","tr":["isteksiz","gönülsüz"],"example_en":"She was reluctant to leave.","example_tr":"Ayrılmaya gönülsüzdü."},
{"id":"b2-hesitate","word":"hesitate","pos":"v","level":"B2","tr":["tereddüt etmek"],"example_en":"Don't hesitate to ask.","example_tr":"Sormaktan çekinme."},
{"id":"b2-significant","word":"significant","pos":"adj","level":"B2","tr":["önemli","kayda değer"],"example_en":"There was a significant increase in prices.","example_tr":"Fiyatlarda kayda değer bir artış oldu."},
{"id":"b2-consequence","word":"consequence","pos":"n","level":"B2","tr":["sonuç"],"example_en":"Every choice has a consequence.","example_tr":"Her seçimin bir sonucu vardır."},
{"id":"b2-abandon","word":"abandon","pos":"v","level":"B2","tr":["terk etmek"],"example_en":"They had to abandon the ship.","example_tr":"Gemiyi terk etmek zorunda kaldılar."},
{"id":"b2-acquire","word":"acquire","pos":"v","level":"B2","tr":["edinmek","elde etmek"],"example_en":"Children acquire language fast.","example_tr":"Çocuklar dili hızla edinir."},
{"id":"b2-adapt","word":"adapt","pos":"v","level":"B2","tr":["uyum sağlamak"],"example_en":"Animals adapt to the cold.","example_tr":"Hayvanlar soğuğa uyum sağlar."},
{"id":"b2-anticipate","word":"anticipate","pos":"v","level":"B2","tr":["öngörmek","beklemek"],"example_en":"We anticipate some delays.","example_tr":"Bazı gecikmeler öngörüyoruz."},
{"id":"b2-assume","word":"assume","pos":"v","level":"B2","tr":["varsaymak"],"example_en":"I assume you are tired.","example_tr":"Yorgun olduğunu varsayıyorum."},
{"id":"b2-attempt","word":"attempt","pos":"v","level":"B2","tr":["denemek","girişmek"],"example_en":"He will attempt the climb.","example_tr":"Tırmanışı deneyecek."},
{"id":"b2-claim","word":"claim","pos":"v","level":"B2","tr":["iddia etmek"],"example_en":"They claim it is safe.","example_tr":"Güvenli olduğunu iddia ediyorlar."},
{"id":"b2-concern","word":"concern","pos":"n","level":"B2","tr":["endişe"],"example_en":"Safety is our main concern.","example_tr":"Güvenlik ana endişemiz."},
{"id":"b2-consist","word":"consist","pos":"v","level":"B2","tr":["oluşmak"],"example_en":"The team will consist of five people.","example_tr":"Ekip beş kişiden oluşacak."},
{"id":"b2-convince","word":"convince","pos":"v","level":"B2","tr":["ikna etmek"],"example_en":"Try to convince your boss.","example_tr":"Patronunu ikna etmeye çalış."},
{"id":"b2-decline","word":"decline","pos":"v","level":"B2","tr":["azalmak","reddetmek"],"example_en":"Sales began to decline.","example_tr":"Satışlar azalmaya başladı."},
{"id":"b2-demonstrate","word":"demonstrate","pos":"v","level":"B2","tr":["göstermek","kanıtlamak"],"example_en":"The test will demonstrate it.","example_tr":"Test bunu gösterecek."},
{"id":"b2-emphasize","word":"emphasize","pos":"v","level":"B2","tr":["vurgulamak"],"example_en":"I want to emphasize this point.","example_tr":"Bu noktayı vurgulamak istiyorum."},
{"id":"b2-enhance","word":"enhance","pos":"v","level":"B2","tr":["artırmak","geliştirmek"],"example_en":"Music can enhance your mood.","example_tr":"Müzik ruh halini iyileştirebilir."},
{"id":"b2-establish","word":"establish","pos":"v","level":"B2","tr":["kurmak"],"example_en":"They want to establish a company.","example_tr":"Bir şirket kurmak istiyorlar."},
{"id":"b2-evaluate","word":"evaluate","pos":"v","level":"B2","tr":["değerlendirmek"],"example_en":"We evaluate every idea.","example_tr":"Her fikri değerlendiririz."},
{"id":"b2-ignore","word":"ignore","pos":"v","level":"B2","tr":["görmezden gelmek"],"example_en":"Don't ignore the warning.","example_tr":"Uyarıyı görmezden gelme."},
{"id":"b2-indicate","word":"indicate","pos":"v","level":"B2","tr":["göstermek","işaret etmek"],"example_en":"The signs indicate a storm.","example_tr":"İşaretler bir fırtınayı gösteriyor."},
{"id":"b2-maintain","word":"maintain","pos":"v","level":"B2","tr":["sürdürmek","korumak"],"example_en":"It is hard to maintain focus.","example_tr":"Odağı korumak zor."},
{"id":"b2-obtain","word":"obtain","pos":"v","level":"B2","tr":["elde etmek"],"example_en":"You must obtain a visa.","example_tr":"Vize almalısın."},
{"id":"b2-persuade","word":"persuade","pos":"v","level":"B2","tr":["ikna etmek"],"example_en":"She tried to persuade me.","example_tr":"Beni ikna etmeye çalıştı."}
]
