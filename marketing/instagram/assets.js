// Every Instagram asset of week 1 (docs/INSTAGRAM_HAFTA1.md). `needs` lists screenshots in shots/
// that must exist; render.mjs skips the asset and says so when one is missing.

const ASSETS = [];
const S = { w: 1080, h: 1920 }, C = { w: 1080, h: 1350 };
function still(id, file, size, build, needs) { ASSETS.push({ id, file, ...size, build, needs }); }
function video(id, file, dur, build, needs) { ASSETS.push({ id, file, ...S, dur, build, needs }); }

function theme(root, cls) { root.className = cls; return root; }
function text(parent, cls, html, style) { return add(parent, h("div", cls, html, style)); }
const px = n => n + "px";

// ---------- shared pieces ----------

/** Big headline block for stories and slides. */
function headline(root, { kicker, title, body, cite, top = 300, size = 92, left = 90, width = 900, align = "left" }) {
  const box = add(root, h("div", "abs", null, { left: px(left), top: px(top), width: px(width), textAlign: align }));
  if (kicker) text(box, "kicker", kicker, { marginBottom: "34px" });
  if (title) text(box, "title", title, { fontSize: px(size) });
  if (body) text(box, "body", body, { fontSize: px(Math.round(size * .5)), marginTop: "40px", opacity: .85 });
  if (cite) text(box, "cite", cite, { marginTop: "34px" });
  return box;
}

/** The "Kendini sına" style hint the app uses: meaning, first letter, blanks. */
function blanks(word) { return word[0] + " " + "_ ".repeat(word.length - 1).trim(); }

/** A tidy notebook page: the word list everyone reads over and over. */
function notebook(parent, x, y, w, words, rot = -3) {
  const nb = add(parent, h("div", "abs", null, { left: px(x), top: px(y), width: px(w), padding: "70px 70px 70px 120px",
    background: "#FFFDF6", borderRadius: "18px", boxShadow: "0 30px 80px rgba(0,0,0,.25)", transform: `rotate(${rot}deg)`,
    backgroundImage: "repeating-linear-gradient(#FFFDF6 0 78px, #D9E4F2 78px 80px)", backgroundPositionY: "52px" }));
  add(nb, h("div", "abs", null, { left: "92px", top: 0, bottom: 0, width: "3px", background: "#E8A0A0" }));
  const rows = words.map(([en, tr]) => {
    const r = add(nb, h("div", null, null, { height: "80px", display: "flex", alignItems: "center", justifyContent: "space-between", fontSize: "46px" }));
    add(r, h("span", "en it", en, { color: "#24345E" }), h("span", "en it", tr, { color: "#5A6378" }));
    return r;
  });
  return { nb, rows };
}

/** The spaced-review calendar: 3 → 7 → 21 → 60 days. */
function intervals(parent, x, y, w, dark) {
  const box = add(parent, h("div", "abs", null, { left: px(x), top: px(y), width: px(w), height: "300px" }));
  const line = add(box, h("div", "abs", null, { left: "40px", right: "40px", top: "88px", height: "6px", borderRadius: "3px", background: dark ? "rgba(255,255,255,.18)" : "var(--line)" }));
  const fillLine = add(box, h("div", "abs", null, { left: "40px", top: "88px", height: "6px", borderRadius: "3px", background: "var(--green)", width: 0 }));
  const days = [3, 7, 21, 60];
  const dots = days.map((d, i) => {
    const cx = 40 + (w - 80) * (i / (days.length - 1));
    const dot = add(box, h("div", "abs center", "", { left: px(cx - 40), top: "51px", width: "80px", height: "80px", borderRadius: "40px",
      background: dark ? "#2A2723" : "#fff", border: `6px solid ${dark ? "rgba(255,255,255,.25)" : "var(--line)"}` }));
    const lab = add(box, h("div", "abs title", `${d} gün`, { left: px(cx - 100), width: "200px", textAlign: "center", top: "160px", fontSize: "44px" }));
    return { dot, lab };
  });
  return {
    box,
    set(p) { // p in 0..1 lights the dots in order
      fillLine.style.width = px((w - 80) * clamp(p));
      dots.forEach((d, i) => {
        const on = p >= i / (days.length - 1) - .001;
        d.dot.style.background = on ? "var(--green)" : (dark ? "#2A2723" : "#fff");
        d.dot.style.borderColor = on ? "var(--green)" : (dark ? "rgba(255,255,255,.25)" : "var(--line)");
        d.lab.style.opacity = on ? 1 : .35;
      });
    },
  };
}

/** A generic Android phone (no brand) with the word drawn on the lock-screen wallpaper. */
function androidMock(parent, x, y, w, { blur = 0, word = W.resilient } = {}) {
  const hgt = w * 2.1;
  const ph = add(parent, h("div", "abs", null, { left: px(x), top: px(y), width: px(w), height: px(hgt), borderRadius: px(w * .1),
    overflow: "hidden", boxShadow: "0 0 0 12px #111, 0 40px 90px rgba(0,0,0,.35)",
    background: "radial-gradient(120% 80% at 20% 10%, #F2B680 0%, #C9668B 38%, #3B2D73 75%, #171433 100%)" }));
  const inner = add(ph, h("div", "fill", null, { filter: blur ? `blur(${blur}px)` : "none" }));
  add(inner, h("div", "abs", null, { left: "50%", top: px(w * .045), width: px(w * .05), height: px(w * .05), marginLeft: px(-w * .025), borderRadius: "50%", background: "#0A0A0A" }));
  text(inner, "abs", "22:08", { left: 0, right: 0, top: px(w * .22), textAlign: "center", color: "#fff", fontWeight: 300, fontSize: px(w * .26), letterSpacing: "-.03em" });
  text(inner, "abs", "Pazartesi, 2 Kasım", { left: 0, right: 0, top: px(w * .19), textAlign: "center", color: "rgba(255,255,255,.85)", fontWeight: 600, fontSize: px(w * .045) });
  const card = add(inner, h("div", "abs", null, { left: px(w * .08), right: px(w * .08), top: px(hgt * .66), padding: px(w * .06),
    borderRadius: px(w * .06), background: "rgba(255,255,255,.16)", backdropFilter: "blur(20px)", border: "1px solid rgba(255,255,255,.25)", color: "#fff" }));
  text(card, "en", word.word, { fontSize: px(w * .13), lineHeight: 1 });
  text(card, null, `<span class="en it" style="opacity:.75">${word.pos}</span>&nbsp;&nbsp;${word.tr1}`, { fontSize: px(w * .055), marginTop: px(w * .025), fontWeight: 500 });
  return ph;
}

/** Phone screenshot with an optional highlight ring (fractions of the screen). */
function shot(parent, src, x, y, w) { return add(parent, phone(src, x, y, w)); }

// ---------- Day 1 ----------

video("g1-reels", "gun1-pazartesi/reels.mp4", 18, root => {
  theme(root, "dark");
  const lock = n => img(n, "fill", { width: "100%", height: "100%", objectFit: "cover" });
  const empty = add(root, lock("kilit-bos.png"));
  const shade = add(root, h("div", "fill", null, { background: "rgba(0,0,0,.38)" }));
  const flash = add(root, h("div", "fill", null, { background: "#fff", opacity: 0 }));
  const words = ["kilit-kart.png", "kilit-2.png", "kilit-3.png", "kilit-cumle.png"].map(n => add(root, lock(n)));
  words.forEach(i => { i.style.transformOrigin = "22% 80%"; i.style.opacity = 0; });
  const t1 = text(root, "abs title", "", { left: "90px", right: "90px", top: "300px", fontSize: "84px", color: "#fff", textShadow: "0 4px 30px rgba(0,0,0,.5)" });
  const count = text(root, "abs title", "", { right: "90px", top: "520px", fontSize: "150px", color: "#fff", textShadow: "0 4px 30px rgba(0,0,0,.5)" });
  const black = add(root, h("div", "fill dark center", null, { opacity: 0 }));
  const nothing = text(black, "title", "…hiçbir şey<br>öğrenmiyorsun.", { fontSize: "110px" });
  const scrim = add(root, h("div", "abs", null, { left: 0, right: 0, top: 0, height: "760px", background: "linear-gradient(rgba(0,0,0,.55), transparent)", opacity: 0 }));
  const t4 = text(root, "abs title", "Ya her bakışta bir<br>kelime görseydin?", { left: "90px", right: "90px", top: "300px", fontSize: "84px", color: "#fff", textShadow: "0 4px 30px rgba(0,0,0,.55)", opacity: 0 });

  const sci = add(root, h("div", "fill cream", null, { opacity: 0 }));
  const sTitle = text(sci, "abs title", "Bir kez görmek<br>yetmiyor.", { left: "90px", top: "300px", fontSize: "96px" });
  const card = add(sci, wordCard(W.hypothesis, { example: false, size: 140 }));
  Object.assign(card.style, { position: "absolute", left: "100px", top: "640px" });
  const reps = text(sci, "abs title", "", { left: "100px", top: "1060px", fontSize: "200px", color: "var(--green)" });
  const sBody = text(sci, "abs body", "Bir kelimeyi ne kadar çok görürsen<br>o kadar kalıcı öğreniyorsun.", { left: "100px", top: "1310px", fontSize: "50px", width: "880px" });
  const sCite = text(sci, "abs cite", "Tekrar ve kelime öğrenimi üzerine meta-analiz:<br>Uchihara, Webb & Yanagisawa, 2019", { left: "100px", top: "1460px", width: "880px" });

  const cal = add(root, h("div", "fill blue center", null, { opacity: 0 }));
  const page = add(cal, h("div", "card center", null, { width: "420px", height: "460px", color: "var(--ink)" }));
  const month = text(page, "kicker", "KASIM", { color: "var(--blue)", opacity: 1 });
  const dayN = text(page, "title", "1", { fontSize: "230px", marginTop: "10px" });
  const calT = text(cal, "title", "Kilit ekranında bu her gün,<br>kendiliğinden olur.", { fontSize: "70px", marginTop: "90px", color: "#fff" });

  const close = closing(root);
  return t => {
    // 0–4: the empty lock screen, four times
    empty.style.opacity = t < 4 ? 1 : 0;
    shade.style.opacity = t < 4 ? 1 : 0;
    typeText(t1, t < 2 ? "Telefonuna günde 50'den fazla bakıyorsun." : "Ve her seferinde…", t < 2 ? seg(t, .1, 1.4) : seg(t, 2.05, 2.6));
    t1.style.opacity = t < 4 ? 1 : 0;
    const cut = t >= 2 && t < 4 ? Math.floor((t - 2) / .5) : -1;
    count.textContent = cut >= 0 ? `${cut + 1}×` : "";
    empty.style.transform = `scale(${cut >= 0 ? (cut % 2 ? 1.06 : 1.0) : lerp(1, 1.04, seg(t, 0, 2))})`;
    const sinceCut = t >= 2 && t < 4 ? (t - 2) % .5 : 1;
    flash.style.opacity = t >= 2 && t < 4 ? .55 * (1 - seg(sinceCut, 0, .12)) : 0;
    // 4–6: black
    window_(black, t, 4, 6, .15);
    nothing.style.transform = `scale(${lerp(.86, 1, easeOut(seg(t, 4, 4.6)))})`;
    // 6–11: four lock screens with a word, zooming into the widget
    words.forEach((im, i) => {
      const a = 6 + i * 1.25, b = a + 1.25;
      im.style.opacity = t >= a && t < b ? 1 : 0;
      im.style.transform = `scale(${lerp(1, 1.55, easeInOut(seg(t, a + .2, b)))})`;
    });
    t4.style.opacity = t >= 6 && t < 11 ? rise(t4, t, 6.1, .4) : 0;
    scrim.style.opacity = t >= 6 && t < 11 ? 1 : 0;
    // 11–15: science
    window_(sci, t, 11, 15, .2);
    rise(sTitle, t, 11.1); rise(card, t, 11.4, .6, 60);
    reps.textContent = t < 11.9 ? "" : `${Math.max(1, Math.round(lerp(1, 20, easeOut(seg(t, 11.9, 13.4)))))}×`;
    rise(sBody, t, 13.2); rise(sCite, t, 13.6);
    // 15–16.5: days go by
    window_(cal, t, 15, 16.5, .15);
    dayN.textContent = String(Math.min(30, 1 + Math.floor(seg(t, 15.05, 16.2) * 29)));
    page.style.transform = `rotate(${Math.sin(t * 40) * 1.2}deg)`;
    rise(calT, t, 15.1, .4);
    // 16.5–18: closing
    if (t >= 16.5) close(t - 16.5);
  };
}, ["kilit-bos.png", "kilit-kart.png", "kilit-2.png", "kilit-3.png", "kilit-cumle.png"]);

still("g1-h1", "gun1-pazartesi/hikaye-1-1230.png", S, root => {
  theme(root, "cream");
  headline(root, { kicker: "Bugün yayında", title: "Kilit ekranında<br>İngilizce 🎉", top: 240, size: 100 });
  const p = shot(root, "bugun-10.png", 230, 640, 620);
  p.style.transform = "rotate(-3deg)";
  add(root, h("div", "abs", null, { left: 0, right: 0, bottom: 0, height: "520px", background: "linear-gradient(transparent, var(--cream) 45%)" }));
  text(root, "abs body muted", "Link aşağıda 👇", { left: 0, right: 0, bottom: "420px", textAlign: "center", fontSize: "44px" });
  add(root, brand(170));
});

still("g1-h2", "gun1-pazartesi/hikaye-2-1800.png", S, root => {
  theme(root, "blue");
  headline(root, { kicker: "Dürüst ol", title: "Günde kaç kez<br>telefonuna<br>bakıyorsun?", top: 330, size: 116 });
  text(root, "abs body", "👇", { left: "90px", top: "1000px", fontSize: "80px" });
  add(root, brand(170, true));
});

still("g1-h3", "gun1-pazartesi/hikaye-3-2130.png", S, root => {
  theme(root, "dark");
  headline(root, { kicker: "Gerçek sayın", title: "Ortalama bir telefon<br>günde 50'den fazla<br>kez açılıyor.", top: 300, size: 92,
    cite: "Cihazla ölçülen kullanım verisi, RescueTime, 2019" });
  const box = add(root, h("div", "abs card", null, { left: "90px", right: "90px", top: "930px", padding: "56px" }));
  text(box, "body", "Seninkini gör:", { fontSize: "40px", opacity: .7 });
  text(box, "title", "Ayarlar › Ekran Süresi", { fontSize: "58px", marginTop: "16px" });
  text(box, "body", "Telefonu kaç kez eline aldığın orada yazıyor.", { fontSize: "40px", marginTop: "20px", opacity: .8 });
  text(root, "abs title", "Bu sayı kadar kelime<br>görebilirdin. 🔒", { left: "90px", top: "1340px", fontSize: "72px", color: "var(--orange)" });
  add(root, brand(170, true));
});

still("g1-h4", "gun1-pazartesi/hikaye-4-2145-android.png", S, root => {
  theme(root, "dark");
  headline(root, { kicker: "Android yolda #1", title: "Android<br>kullanıyorum,<br>bana yok mu? 🤖", top: 300, size: 110 });
  text(root, "abs body", "Android sürümü yolda.<br>Haber almak için bu hikâyeye ❤️ bırak.", { left: "90px", top: "1000px", fontSize: "54px", width: "900px" });
  add(root, brand(170, true));
});

// ---------- Day 2: carousel ----------

const D2 = [
  root => { theme(root, "dark");
    headline(root, { title: "Kelime ezberlerken yaptığın en büyük hata", top: 330, size: 112 });
    text(root, "abs body", "Hayır, az çalışmak değil.", { left: "90px", top: "860px", fontSize: "52px", color: "var(--orange)" });
    text(root, "swipe", "Kaydır →"); },
  root => { theme(root, "cream");
    notebook(root, 120, 120, 840, [["reluctant", "isteksiz"], ["resilient", "dirençli"], ["entail", "gerektirmek"], ["hypothesis", "hipotez"], ["significant", "önemli"]], -2);
    headline(root, { title: "Listeyi tekrar tekrar okumak.", body: "Tanıdık geliyor diye bildiğini sanıyorsun.", top: 860, size: 76 });
    text(root, "counter", "2/7"); },
  root => { theme(root, "cream");
    headline(root, { title: "Okumak ≠ hatırlamak", top: 150, size: 100 });
    const row = (y, label, quote, emoji, bg) => {
      const b = add(root, h("div", "abs card", null, { left: "90px", right: "90px", top: px(y), padding: "50px 56px", background: bg }));
      text(b, "kicker", label, { fontSize: "28px" });
      text(b, "title", `${quote} <span style="font-size:70px">${emoji}</span>`, { fontSize: "62px", marginTop: "18px" });
    };
    row(430, "Okurken", "“Evet, bunu biliyorum.”", "😌", "#fff");
    row(790, "Sınavda", "“…neydi bu?”", "😶", "var(--amberBg)");
    text(root, "counter", "3/7"); },
  root => { theme(root, "blue");
    headline(root, { kicker: "Bilim ne diyor?", title: "61 çalışmayı inceleyen bir meta-analiz:", top: 200, size: 72 });
    text(root, "abs title", "Kendini sınamak, tekrar okumaktan daha kalıcı öğrenme sağlıyor.", { left: "90px", width: "900px", top: "560px", fontSize: "88px", color: "#fff" });
    text(root, "abs cite", "Rowland, 2014 · Psychological Bulletin", { left: "90px", top: "1080px", color: "#fff" });
    text(root, "counter", "4/7"); },
  root => { theme(root, "cream");
    headline(root, { kicker: "Daha da iyisi", title: "Cevabı hemen kontrol et, bir gün sonra yine sına.", body: "Geri bildirim ve araya zaman koymak etkiyi büyütüyor.", cite: "Aynı meta-analiz", top: 260, size: 84 });
    text(root, "counter", "5/7"); },
  root => { theme(root, "cream");
    headline(root, { title: "Nasıl uygularsın?", top: 170, size: 96 });
    [["1", "Anlamı gör, kelimeyi kendin hatırlamaya çalış."], ["2", "Sonra kontrol et."], ["3", "Bilemediğini yarın tekrar sor."]].forEach(([n, s], i) => {
      const r = add(root, h("div", "abs", null, { left: "90px", right: "90px", top: px(420 + i * 250), display: "flex", gap: "40px", alignItems: "center" }));
      add(r, h("div", "center title", n, { flex: "0 0 120px", height: "120px", borderRadius: "60px", background: "var(--blue)", color: "#fff", fontSize: "64px" }));
      add(r, h("div", "body", s, { fontSize: "54px", fontWeight: 600 }));
    });
    text(root, "counter", "6/7"); },
  root => { theme(root, "dark");
    const p = shot(root, "kilit-sina.png", 90, 140, 420);
    p.style.height = px(420 * 1792 / 828);
    headline(root, { title: "Kilit ekranında kendini sına.", body: "Önce anlam ve ilk harf, cevap biraz sonra.", left: 580, width: 420, top: 300, size: 74 });
    text(root, "abs body", "Kaydet, yarın tekrar bak 🔖", { left: "580px", width: "420px", top: "960px", fontSize: "42px", color: "var(--orange)" });
    text(root, "counter", "7/7"); },
];
D2.forEach((b, i) => still(`g2-c${i + 1}`, `gun2-sali/carousel-${i + 1}.png`, C, b, i === 6 ? ["kilit-sina.png"] : undefined));

still("g2-h1", "gun2-sali/hikaye-1-1230-test.png", S, root => {
  theme(root, "cream");
  headline(root, { kicker: "Hızlı test", title: "", top: 300 });
  text(root, "abs en", "reluctant", { left: "90px", top: "380px", fontSize: "170px", lineHeight: 1 });
  text(root, "abs title", "ne demek?", { left: "90px", top: "590px", fontSize: "90px" });
  add(root, brand(170));
});

still("g2-h2", "gun2-sali/hikaye-2-1800.png", S, root => {
  theme(root, "dark");
  const frame = add(root, h("div", "abs", null, { left: "90px", top: "330px", width: "1080px", height: "1350px", transform: "scale(.833)", transformOrigin: "0 0", borderRadius: "40px", overflow: "hidden", boxShadow: "0 30px 80px rgba(0,0,0,.4)" }));
  D2[3](frame);
  text(root, "abs title", "Yeni gönderi 👆", { left: 0, right: 0, top: "1520px", textAlign: "center", fontSize: "64px" });
});

still("g2-h3", "gun2-sali/hikaye-3-2130-cevap.png", S, root => {
  theme(root, "cream");
  headline(root, { kicker: "Cevap", title: "B) isteksiz ✓", top: 300, size: 100 });
  const c = add(root, wordCard(W.reluctant, { size: 130 }));
  Object.assign(c.style, { position: "absolute", left: "100px", top: "620px" });
  text(root, "abs body muted", "Bilemediysen kilit ekranına koy,<br>her gün görürsün.", { left: "100px", top: "1330px", fontSize: "46px" });
  add(root, brand(170));
});

// ---------- Day 3 ----------

video("g3-reels", "gun3-carsamba/reels.mp4", 22, root => {
  theme(root, "dark");
  const night = add(root, h("div", "fill", null, { background: "radial-gradient(70% 45% at 70% 30%, #5B4A2E 0%, #2A2219 45%, #12100D 100%)" }));
  const list = [["significant", "önemli"], ["consequence", "sonuç"], ["inevitable", "kaçınılmaz"], ["entail", "gerektirmek"], ["resilient", "dirençli"], ["plausible", "akla yatkın"], ["hypothesis", "hipotez"]];
  const { nb, rows } = notebook(root, 110, 760, 860, list, -3);
  const q = text(root, "abs title", "", { left: "90px", right: "90px", top: "280px", fontSize: "84px", color: "#fff" });

  const chart = add(root, h("div", "fill cream", null, { opacity: 0 }));
  text(chart, "abs title", "Bir hafta sonra", { left: "90px", top: "280px", fontSize: "84px" });
  const W_ = 900, H_ = 700, ox = 90, oy = 560;
  const svg = add(chart, h("div", "abs", `<svg width="${W_}" height="${H_ + 120}" viewBox="0 0 ${W_} ${H_ + 120}">
    <line x1="0" y1="${H_}" x2="${W_}" y2="${H_}" stroke="#CFC8BA" stroke-width="4"/>
    <line x1="0" y1="0" x2="0" y2="${H_}" stroke="#CFC8BA" stroke-width="4"/>
    <path id="cram" d="" fill="none" stroke="#B5651D" stroke-width="12" stroke-linecap="round"/>
    <path id="spaced" d="" fill="none" stroke="#2F7A4F" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/>
    <text x="${W_}" y="${H_ + 70}" text-anchor="end" font-family="Hanken" font-size="40" fill="#6B655C">zaman →</text>
    <text x="20" y="40" font-family="Hanken" font-size="40" fill="#6B655C">hatırlanan</text>
  </svg>`, { left: px(ox), top: px(oy) }));
  // Forgetting curves: cramming decays once; spaced review climbs back at each review.
  const cramPts = [], spacedPts = [];
  const reviews = [0, .18, .42, .72];
  for (let i = 0; i <= 100; i++) {
    const x = i / 100;
    cramPts.push([x * W_, H_ - H_ * (.08 + .82 * Math.exp(-x * 5))]);
    const k = reviews.filter(r => r <= x).length - 1;
    spacedPts.push([x * W_, H_ - H_ * (.08 + .82 * Math.exp(-(x - reviews[k]) * 5 / (1 + k * 1.6)))]);
  }
  const d = pts => "M" + pts.map(p => p.map(v => v.toFixed(1)).join(",")).join(" L");
  const cram = svg.querySelector("#cram"), spaced = svg.querySelector("#spaced");
  cram.setAttribute("d", d(cramPts)); spaced.setAttribute("d", d(spacedPts));
  const cramLen = cram.getTotalLength ? cram.getTotalLength() : 3000, spacedLen = spaced.getTotalLength ? spaced.getTotalLength() : 4000;
  [[cram, cramLen], [spaced, spacedLen]].forEach(([p, l]) => { p.style.strokeDasharray = l; p.style.strokeDashoffset = l; });
  const legC = text(chart, "abs title", "● Bir gecede", { left: "90px", top: "1400px", fontSize: "52px", color: "var(--amber)", opacity: 0 });
  const legS = text(chart, "abs title", "● Aralıklı tekrar", { left: "90px", top: "1480px", fontSize: "52px", color: "var(--green)", opacity: 0 });

  const sci = add(root, h("div", "fill blue", null, { opacity: 0 }));
  const l1 = text(sci, "abs title", "300'den fazla deneyi inceleyen bir çalışma:", { left: "90px", width: "900px", top: "420px", fontSize: "64px" });
  const l2 = text(sci, "abs title", "Aynı sürede, araya zaman koyarak çalışmak neredeyse her zaman kazanıyor.", { left: "90px", width: "900px", top: "720px", fontSize: "88px" });
  const l3 = text(sci, "abs cite", "Cepeda ve ark., 2006 · Psychological Bulletin", { left: "90px", top: "1320px", color: "#fff" });

  const app = add(root, h("div", "fill cream", null, { opacity: 0 }));
  const appT = text(app, "abs title", "Zorlandığın kelime daha sık,<br>öğrendiğin aralıklarla gelir.", { left: "90px", right: "90px", top: "240px", fontSize: "66px" });
  const pw = 600, px0 = 240, py0 = 520;
  const p1 = shot(app, "tekrar-soru.png", px0, py0, pw), p2 = shot(app, "tekrar-yanlis.png", px0, py0, pw), p3 = shot(app, "kilit-kart.png", px0, py0, pw);
  p3.style.height = px(pw * 1792 / 828);
  const ring = add(app, h("div", "abs", null, { left: px(px0 + 10), top: px(py0 + pw * 2622 / 1206 * .823), width: px(pw - 20), height: "70px", borderRadius: "35px", border: "8px solid var(--orange)", opacity: 0 }));

  const tl = add(root, h("div", "fill dark", null, { opacity: 0 }));
  text(tl, "abs title", "Öğrendiğin kelime<br>yeniden gelir:", { left: "90px", top: "420px", fontSize: "84px" });
  const iv = intervals(tl, 90, 820, 900, true);

  const close = closing(root);
  return t => {
    // 0–4.5: the night before
    night.style.opacity = nb.style.opacity = t < 4.5 ? 1 : 0;
    typeText(q, t < 2.5 ? "Sınavdan önceki gece 50 kelime ezberledin." : "Bir hafta sonra kaçını hatırlıyorsun?", t < 2.5 ? seg(t, .1, 1.6) : seg(t, 2.6, 3.4));
    q.style.opacity = t < 4.5 ? 1 : 0;
    rows.forEach((r, i) => { r.style.opacity = 1 - seg(t, 3.2 + i * .14, 3.5 + i * .14) * (i === 2 ? 0 : 1); });
    nb.style.transform = `rotate(-3deg) scale(${lerp(1, 1.04, seg(t, 0, 4.5))})`;
    // 4.5–10: two curves
    window_(chart, t, 4.5, 10, .2);
    cram.style.strokeDashoffset = cramLen * (1 - easeInOut(seg(t, 5, 7.3)));
    spaced.style.strokeDashoffset = spacedLen * (1 - easeInOut(seg(t, 7.3, 9.6)));
    legC.style.opacity = seg(t, 5.2, 5.6); legS.style.opacity = seg(t, 7.5, 7.9);
    // 10–14: the evidence
    window_(sci, t, 10, 14, .2);
    rise(l1, t, 10.1); rise(l2, t, 10.9); rise(l3, t, 12.2);
    // 14–19: the app
    window_(app, t, 14, 19, .2);
    rise(appT, t, 14.1);
    p1.style.opacity = t < 15.5 ? 1 : 0;
    p2.style.opacity = t >= 15.5 && t < 17.4 ? 1 : 0;
    p3.style.opacity = t >= 17.4 ? 1 : 0;
    ring.style.opacity = t >= 15.9 && t < 17.4 ? .5 + .5 * Math.sin((t - 15.9) * 9) : 0;
    // 19–20.5: intervals
    window_(tl, t, 19, 20.5, .15);
    iv.set(seg(t, 19.2, 20.2));
    if (t >= 20.5) close(t - 20.5);
  };
}, ["tekrar-soru.png", "tekrar-yanlis.png", "kilit-kart.png"]);

still("g3-h1", "gun3-carsamba/hikaye-1-1230-kaydirici.png", S, root => {
  theme(root, "orange");
  headline(root, { kicker: "Dürüst ol", title: "Bir hafta önce ezberlediğin kelimelerin ne kadarını hatırlıyorsun?", top: 300, size: 92 });
  add(root, brand(170));
});

still("g3-h2", "gun3-carsamba/hikaye-2-1800-takvim.png", S, root => {
  theme(root, "cream");
  headline(root, { kicker: "Aralıklı tekrar", title: "Öğrendiğin kelime unutmadan önce geri gelir.", top: 300, size: 90 });
  intervals(root, 90, 820, 900, false).set(1);
  text(root, "abs body muted", "Zorlandığın kelime ise widget'ında daha sık görünür.", { left: "90px", width: "900px", top: "1180px", fontSize: "46px" });
  add(root, brand(170));
});

still("g3-h3", "gun3-carsamba/hikaye-3-2130-soru.png", S, root => {
  theme(root, "blue");
  headline(root, { kicker: "Sana göre içerik", title: "Hangi sınava hazırlanıyorsun?", body: "YDS, YÖKDİL, IELTS, TOEFL… ya da hiçbiri?", top: 330, size: 104 });
  add(root, brand(170, true));
});

still("g3-h4", "gun3-carsamba/hikaye-4-2145-android.png", S, root => {
  theme(root, "dark");
  headline(root, { kicker: "Android yolda #2", title: "Android'de kilit ekranı nasıl olacak?", top: 260, size: 92 });
  androidMock(root, 300, 640, 480, { blur: 18 });
  text(root, "abs title center", "?", { left: "300px", top: "940px", width: "480px", fontSize: "300px", color: "#fff", textShadow: "0 10px 40px rgba(0,0,0,.4)" });
  text(root, "abs body", "Yakında gösteriyoruz 🤖", { left: 0, right: 0, textAlign: "center", top: "1700px", fontSize: "50px" });
});

// ---------- Day 4 ----------

const STEPS = [
  { src: "adim-1.png", n: "1", t: "Kilit ekranına basılı tut,<br>Özelleştir'e dokun" },
  { src: "adim-3.png", n: "2", t: "Widget alanına dokun,<br>listeden Kilit Kelime'yi seç" },
  { src: "kilit-3.png", n: "3", t: "Bitti'ye dokun.<br>Kelimen kilit ekranında" },
];
function widgetSteps(root) {
  theme(root, "cream");
  const before = add(root, h("div", "fill", null));
  const bL = add(before, img("kilit-bos.png", "abs", { left: 0, top: 0, width: "1080px", height: "1920px", objectFit: "cover" }));
  const bR = add(before, h("div", "abs", null, { left: 0, top: 0, width: "1080px", height: "1920px", overflow: "hidden" }));
  add(bR, img("kilit-kart.png", "abs", { left: 0, top: 0, width: "1080px", height: "1920px", objectFit: "cover" }));
  const bar = add(before, h("div", "abs", null, { top: 0, bottom: 0, width: "8px", background: "#fff" }));
  const bT = text(before, "abs title", "Kilit ekranına İngilizce koymak 15 saniye sürüyor.", { left: "90px", right: "90px", top: "260px", fontSize: "78px", color: "#fff", textShadow: "0 4px 30px rgba(0,0,0,.55)" });

  const steps = STEPS.map(s => {
    const g = add(root, h("div", "fill cream", null, { opacity: 0 }));
    text(g, "abs title", s.n, { left: "70px", top: "200px", fontSize: "220px", color: "var(--blue)", lineHeight: 1 });
    text(g, "abs title", s.t, { left: "250px", right: "70px", top: "230px", fontSize: "62px" });
    const p = add(g, phone(s.src, 250, 560, 580));
    return { g, p };
  });
  const after = add(root, h("div", "fill", null, { opacity: 0 }));
  add(after, img("kilit-kart.png", "abs", { left: 0, top: 0, width: "1080px", height: "1920px", objectFit: "cover", transformOrigin: "22% 80%" }));
  const aT = text(after, "abs title", "Her bakışta bir kelime. 🔒", { left: "90px", right: "90px", top: "260px", fontSize: "80px", color: "#fff", textShadow: "0 4px 30px rgba(0,0,0,.55)" });
  return t => {
    // 0–2: before / after split
    before.style.opacity = t < 2 ? 1 : 0;
    const split = 1080 * (1 - easeInOut(seg(t, .5, 1.8)));
    bR.style.clipPath = `inset(0 0 0 ${split}px)`;
    bar.style.left = px(split - 4);
    rise(bT, t, .05, .4);
    // 2–11: three steps, 3 s each
    steps.forEach((s, i) => {
      const a = 2 + i * 3;
      window_(s.g, t, a, a + 3, .2);
      s.p.style.transform = `scale(${lerp(.96, 1, easeOut(seg(t, a, a + .5)))})`;
    });
    // 11–13: result
    window_(after, t, 11, 13.5, .2);
    after.firstChild.style.transform = `scale(${lerp(1, 1.35, easeInOut(seg(t, 11.3, 13.3)))})`;
    rise(aT, t, 11.2);
  };
}
const W_NEEDS = ["kilit-bos.png", "kilit-kart.png", ...STEPS.map(s => s.src)];
video("g4-reels", "gun4-persembe/reels.mp4", 15, root => {
  const steps = widgetSteps(root), close = closing(root);
  return t => { steps(t); if (t >= 13.5) close(t - 13.5); };
}, W_NEEDS);
video("g4-h1", "gun4-persembe/hikaye-1-1230-ilk5sn.mp4", 5, root => {
  const steps = widgetSteps(root);
  const tag = text(root, "abs pill", "Tam hali profilde 👆", { left: "50%", transform: "translateX(-50%)", bottom: "300px", background: "var(--dark)", color: "#fff", fontSize: "40px", padding: "22px 44px" });
  return t => { steps(t); tag.style.opacity = seg(t, 3.5, 3.9); };
}, W_NEEDS);

still("g4-h2", "gun4-persembe/hikaye-2-1800-anket.png", S, root => {
  theme(root, "cream");
  headline(root, { kicker: "Senin kilit ekranın", title: "Hangi görünüm?", top: 300, size: 110 });
  const opts = [["Kart", "hypothesis", "isim · hipotez"], ["Sözlük", "HYPOTHESIS (isim)", "hipotez"], ["Örnek cümle", "The experiment supports the hypothesis.", "Deney hipotezi destekliyor."], ["Kendini sına", "hipotez", "h _ _ _ _ _ _ _ _ _"]];
  opts.forEach(([n, a, b], i) => {
    const c = add(root, h("div", "abs card", null, { left: px(90 + (i % 2) * 460), top: px(620 + Math.floor(i / 2) * 330), width: "440px", height: "300px", padding: "36px" }));
    text(c, "kicker", n, { fontSize: "24px" });
    text(c, "en", a, { fontSize: a.length > 20 ? "34px" : "48px", marginTop: "20px", lineHeight: 1.15 });
    text(c, "body muted", b, { fontSize: "30px", marginTop: "12px" });
  });
  add(root, brand(170));
});

still("g4-h3", "gun4-persembe/hikaye-3-2130-siradasen.png", S, root => {
  theme(root, "blue");
  headline(root, { kicker: "Sıra sende", title: "Kilit ekranındaki kelimeyi paylaş", body: "Hikâyemizde paylaşalım. 🔒", top: 300, size: 100 });
  add(root, brand(170, true));
});

// ---------- Day 5: carousel ----------

const YDS = ["significant", "consequence", "inevitable", "comprehensive", "substantial", "plausible"];
const D5 = [
  root => { theme(root, "blue");
    headline(root, { kicker: "YDS · YÖKDİL", title: "YDS listemizden 6 kelime", body: "Kaçını biliyorsun?<br>Saymaya&nbsp;başla&nbsp;→", top: 330, size: 120 });
    add(root, brand(56, true)); },
  ...YDS.map((w, i) => root => { theme(root, "cream");
    text(root, "abs pill", "YDS", { left: "90px", top: "110px", background: "var(--amberBg)", color: "var(--amber)" });
    const wrap = add(root, h("div", "fill center", null, { padding: "0 90px" }));
    const c = add(wrap, wordCard(W[w], { size: W[w].word.length > 11 ? 120 : 150, width: "900px", pad: "80px 72px" }));
    c.style.transform = "translateY(20px)";
    text(root, "counter", `${i + 1}/6`); }),
  root => { theme(root, "dark");
    headline(root, { title: "6'da kaç?", body: "Bilmediklerini kilit ekranına koy:<br>Kilit Kelime › Listeler › YDS", top: 300, size: 140 });
    text(root, "abs body", "Kaydet, sınava kadar bak 🔖", { left: "90px", top: "980px", fontSize: "48px", color: "var(--orange)" });
    add(root, brand(56, true)); },
];
D5.forEach((b, i) => still(`g5-c${i + 1}`, `gun5-cuma/carousel-${i + 1}.png`, C, b));

still("g5-h1", "gun5-cuma/hikaye-1-1230.png", S, root => {
  theme(root, "blue");
  headline(root, { kicker: "Cevaplarınız", title: "Hangi sınav dediniz?", body: "Gelen cevaplardan birkaçı 👇 Bugün YDS kelimeleri geliyor.", top: 260, size: 96 });
  add(root, brand(170, true));
});
still("g5-h2", "gun5-cuma/hikaye-2-1800.png", S, root => {
  theme(root, "dark");
  const frame = add(root, h("div", "abs", null, { left: "90px", top: "330px", width: "1080px", height: "1350px", transform: "scale(.833)", transformOrigin: "0 0", borderRadius: "40px", overflow: "hidden", boxShadow: "0 30px 80px rgba(0,0,0,.4)" }));
  D5[0](frame);
  text(root, "abs title", "Yeni gönderi 👆", { left: 0, right: 0, top: "1520px", textAlign: "center", fontSize: "64px" });
});
still("g5-h3", "gun5-cuma/hikaye-3-2130-test.png", S, root => {
  theme(root, "cream");
  headline(root, { kicker: "Hızlı test", title: "", top: 300 });
  text(root, "abs en", "inevitable", { left: "90px", top: "380px", fontSize: "160px", lineHeight: 1 });
  text(root, "abs title", "ne demek?", { left: "90px", top: "590px", fontSize: "90px" });
  add(root, brand(170));
});

// ---------- Day 6 ----------

video("g6-reels", "gun6-cumartesi/reels.mp4", 12, root => {
  theme(root, "cream");
  const list = ["curious", "resilient", "ineffable"].map(w => W[w]);
  const panels = list.map((w, i) => {
    const p = add(root, h("div", "fill cream", null));
    text(p, "abs kicker", `${["Kolay", "Orta", "Zor"][i]} · ${i + 1}/3`, { left: 0, right: 0, textAlign: "center", top: "800px" });
    text(p, "abs en", w.word, { left: 0, right: 0, textAlign: "center", top: "880px", fontSize: "180px", lineHeight: 1 });
    const track = add(p, h("div", "abs", null, { left: "190px", right: "190px", top: "1160px", height: "16px", borderRadius: "8px", background: "var(--line)" }));
    const bar = add(track, h("div", null, null, { height: "100%", width: 0, borderRadius: "8px", background: "var(--blue)" }));
    const ans = add(p, h("div", "abs center", null, { left: "190px", right: "190px", top: "1240px", padding: "34px", borderRadius: "36px", background: "var(--greenBg)", color: "var(--green)", opacity: 0 }));
    text(ans, "title", w.tr1, { fontSize: "76px" }); text(ans, "en it", w.pos, { fontSize: "40px", marginTop: "6px", opacity: .8 });
    return { p, bar, ans };
  });
  const head = text(root, "abs title", "3 kelime. 3 saniye.<br>Kaçını bildin?", { left: "90px", right: "90px", top: "300px", fontSize: "76px", textAlign: "center" });
  const end = add(root, h("div", "fill dark center", null, { opacity: 0 }));
  text(end, "title", "Kaçını bildin?", { fontSize: "110px" });
  text(end, "body", "Yorumlara yaz: 1/3, 2/3, 3/3 👇", { fontSize: "52px", marginTop: "40px", opacity: .85 });
  const close = closing(root);
  return t => {
    panels.forEach((s, i) => {
      const a = i * 3;
      s.p.style.transform = `translateX(${slideX(t, a, a + 3, .3)}px)`;
      if (i === 0 && t < .3) s.p.style.transform = "none";
      s.bar.style.width = (100 * seg(t, a + .2, a + 2.1)) + "%";
      s.ans.style.opacity = seg(t, a + 2.1, a + 2.3);
      s.ans.style.transform = `scale(${lerp(.9, 1, easeOut(seg(t, a + 2.1, a + 2.4)))})`;
    });
    head.style.opacity = 1 - seg(t, 1.6, 2);
    window_(end, t, 9, 10.5, .2);
    if (t >= 10.5) close(t - 10.5);
  };
});

still("g6-h2", "gun6-cumartesi/hikaye-2-1800-kaydirici.png", S, root => {
  theme(root, "orange");
  headline(root, { kicker: "Hafta sonu", title: "Bu hafta kaç yeni kelime öğrendin?", top: 300, size: 104 });
  add(root, brand(170));
});
still("g6-h3", "gun6-cumartesi/hikaye-3-2130-android.png", S, root => {
  theme(root, "dark");
  headline(root, { kicker: "Android yolda #3", title: "Android'de kelime, kilit ekranı duvar kâğıdına gelecek.", top: 220, size: 76 });
  androidMock(root, 300, 640, 480);
  text(root, "abs body", "Bekleme listesi için DM'den <b>android</b> yaz 🤖", { left: 0, right: 0, textAlign: "center", top: "1700px", fontSize: "46px" });
});

// ---------- Day 7: carousel ----------

const WEEK = ["reluctant", "resilient", "entail", "hypothesis", "significant", "consequence", "inevitable", "comprehensive", "substantial", "curious"];
const groups = [[0, 3], [3, 6], [6, 8], [8, 10]];
const D7 = [
  root => { theme(root, "orange");
    headline(root, { kicker: "Haftalık tekrar", title: "Bu haftanın 10 kelimesi", body: "Kaydırırken anlamını<br>tahmin&nbsp;et&nbsp;→", top: 330, size: 130 });
    add(root, brand(56)); },
  ...groups.map(([a, b], gi) => root => { theme(root, "cream");
    WEEK.slice(a, b).forEach((w, i, arr) => {
      const y = 1350 / 2 - (arr.length * 300) / 2 + i * 300;
      text(root, "abs en", W[w].word, { left: "90px", top: px(y + 40), fontSize: "120px", lineHeight: 1 });
      text(root, "abs body", `${W[w].pos} · ${W[w].tr1}`, { left: "94px", top: px(y + 185), fontSize: "40px", opacity: .28 });
    });
    text(root, "counter", `${gi + 2}/6`); }),
  root => { theme(root, "dark");
    headline(root, { title: "Neden haftalık tekrar?", body: "Araya zaman koyarak yeniden görmek kalıcılığı artırır.", cite: "Cepeda ve ark., 2006", top: 260, size: 100 });
    text(root, "abs title", "Kilit Kelime bunu senin yerine yapar.", { left: "90px", width: "900px", top: "930px", fontSize: "58px", color: "var(--orange)" });
    add(root, brand(56, true)); },
];
D7.forEach((b, i) => still(`g7-c${i + 1}`, `gun7-pazar/carousel-${i + 1}.png`, C, b));

still("g7-h2", "gun7-pazar/hikaye-2-1800-soru.png", S, root => {
  theme(root, "blue");
  headline(root, { kicker: "Sen seç", title: "Gelecek hafta hangi konu?", body: "Seyahat, iş, sınav, günlük konuşma…", top: 330, size: 110 });
  add(root, brand(170, true));
});
still("g7-h3", "gun7-pazar/hikaye-3-2130.png", S, root => {
  theme(root, "cream");
  headline(root, { title: "Pazartesi yeni kelimeler 👋", body: "En çok seçtiğiniz konuyla geliyoruz.", top: 300, size: 110 });
  const p = shot(root, "kilit-kart.png", 290, 820, 500);
  p.style.height = px(500 * 1792 / 828); p.style.transform = "rotate(4deg)";
  add(root, h("div", "abs", null, { left: 0, right: 0, bottom: 0, height: "620px", background: "linear-gradient(transparent, var(--cream) 50%)" }));
  add(root, brand(170));
});
