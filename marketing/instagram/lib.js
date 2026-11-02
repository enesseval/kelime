// Small helpers for the Instagram scenes. A static asset builds its DOM once; a video asset's
// build() returns update(t) and render.mjs calls it for every frame (t in seconds).

const SHOTS = "shots/";

function h(tag, cls, html, style) {
  const el = document.createElement(tag);
  if (cls) el.className = cls;
  if (html != null) el.innerHTML = html;
  if (style) Object.assign(el.style, style);
  return el;
}
function add(parent, ...children) { children.forEach(c => parent.appendChild(c)); return children[0]; }

const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const seg = (t, a, b) => clamp((t - a) / (b - a));
const easeOut = p => 1 - Math.pow(1 - p, 3);
const easeIn = p => p * p * p;
const easeInOut = p => (p < .5 ? 4 * p * p * p : 1 - Math.pow(-2 * p + 2, 3) / 2);
const lerp = (a, b, p) => a + (b - a) * p;

/** Shows the element only while a <= t < b, with fades of `f` seconds at both ends. */
function window_(el, t, a, b, f = .25) {
  const o = Math.min(seg(t, a, a + f), 1 - seg(t, b - f, b));
  el.style.opacity = (t < a || t >= b) ? 0 : o;
  return o;
}

/** Types `text` up to progress p. HTML-free text only. */
function typeText(el, text, p) {
  const n = Math.round(text.length * clamp(p));
  el.textContent = text.slice(0, n);
}

/** Rises in from below and fades in over [a, a+d]. */
function rise(el, t, a, d = .5, dist = 40) {
  const p = easeOut(seg(t, a, a + d));
  el.style.opacity = p;
  el.style.transform = `translateY(${(1 - p) * dist}px)`;
  return p;
}

function img(src, cls, style) {
  const i = h("img", cls, null, style);
  i.src = src.startsWith("http") || src.startsWith("/") ? src : SHOTS + src;
  return i;
}

function phone(src, x, y, w, extra) {
  const ph = h("div", "phone", null, { left: x + "px", top: y + "px", width: w + "px", height: (w * 2622 / 1206) + "px", ...extra });
  ph.appendChild(img(src));
  return ph;
}

function brand(bottom = 70, dark = false) {
  const b = h("div", "brand", null, { bottom: bottom + "px" });
  add(b, img("icon.png"), h("span", null, "Kilit Kelime"));
  if (dark) b.style.color = "#F4F1EB";
  return b;
}

/** The same last 1.5 s on every Reels: cream, icon, name, line, "Profildeki linkten". */
function closing(root) {
  const c = add(root, h("div", "fill cream center", null, { opacity: 0, color: "var(--ink)" }));
  const icon = add(c, img("icon.png", null, { width: "260px", height: "260px", borderRadius: "58px", boxShadow: "0 30px 70px rgba(0,0,0,.15)" }));
  const name = add(c, h("div", "title", "Kilit Kelime", { fontSize: "92px", marginTop: "56px" }));
  const line = add(c, h("div", "body", "Kilit ekranında İngilizce", { fontSize: "46px", marginTop: "18px", color: "var(--ink2)" }));
  const cta = add(c, h("div", "pill", "Profildeki linkten · App Store", { background: "var(--blue)", color: "#fff", marginTop: "70px", fontSize: "38px", padding: "22px 44px" }));
  return (t) => {
    c.style.opacity = easeOut(seg(t, 0, .35));
    const p = easeOut(seg(t, .05, .6));
    icon.style.transform = `scale(${lerp(.8, 1, p)})`;
    rise(name, t, .15); rise(line, t, .3); rise(cta, t, .45);
  };
}

/** A word card in the app's look (kelime, tür · anlam, optional example). */
function wordCard(w, opts = {}) {
  const c = h("div", "card", null, { padding: opts.pad || "64px 64px", width: opts.width || "880px", textAlign: "left" });
  add(c, h("div", "en", w.word, { fontSize: (opts.size || 150) + "px", lineHeight: "1", letterSpacing: "-.01em" }));
  const m = add(c, h("div", null, null, { marginTop: "30px", fontSize: "50px", display: "flex", gap: "22px", alignItems: "baseline" }));
  add(m, h("span", "en it muted", w.pos), h("span", "body", w.tr));
  if (w.ex && opts.example !== false) {
    add(c, h("div", null, null, { height: "2px", background: "var(--line)", margin: "40px 0 34px" }));
    add(c, h("div", "en it", w.ex, { fontSize: "50px", lineHeight: "1.25" }));
    add(c, h("div", "body muted", w.exTr, { fontSize: "38px", marginTop: "12px" }));
  }
  return c;
}

/** Slide-in transition helper: x offset for a panel that enters at a and leaves at b. */
function slideX(t, a, b, d = .35, w = 1080) {
  if (t < a) return w;
  if (t < a + d) return w * (1 - easeOut(seg(t, a, a + d)));
  if (t < b - d) return 0;
  return -w * easeIn(seg(t, b - d, b));
}
