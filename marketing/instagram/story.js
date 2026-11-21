// Kilitli Kapı: 2D "code animation" over AI stills. story.mjs injects window.STORY = {imgs:{R1,R3,R4 data URIs}, env:[rms per 10 ms], total}.
// window.draw(t) paints one frame on #c. No video AI: camera moves, a jaw/lip warp driven by the voice envelope,
// eyelids and eye pops drawn from the stills, grain, vignette, subtitles and word cards.
const W = 1080, H = 1920, S0 = 1080 / 768;
const cv = document.getElementById("c"), ctx = cv.getContext("2d");
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const seg = (t, a, b) => clamp((t - a) / (b - a));
const lerp = (a, b, p) => a + (b - a) * p;
const easeIO = p => (p < .5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2);
const easeOut = p => 1 - Math.pow(1 - p, 3);
const rnd = n => { const x = Math.sin(n * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); };

// ---- timeline (seconds, from the voice's silence gaps) ----
let KNOCKS = [0.12, 0.57, 1.52, 10.55, 12.58];
let BLINKS = [2.45, 5.35, 9.0, 13.3];
let LINES = [ // [start, end, text, who]  P = Pirinç, E = Elif (same voice file)
  [0.03, 1.71, "Bu kapı üç gündür kilitli", "P"], [2.00, 3.41, "ve içeriden biri sesleniyor.", "P"],
  [3.86, 4.53, "Sen kimsin?", "P"], [4.83, 6.16, "Bu koridora kimse inmez.", "P"], [6.64, 7.38, "Sesi duydum.", "E"],
  [7.65, 8.02, "Dinle.", "P"], [8.46, 9.31, "Üç kere vurur,", "P"], [9.62, 10.33, "sonra susar.", "P"],
  [10.70, 11.66, "Anahtarı nerede?", "E"], [11.98, 12.41, "Bulalım!", "E"], [12.74, 13.16, "Hmm.", "P"], [13.55, 14.29, "Bulamazsın.", "P"],
  [14.79, 15.49, "Anahtar...", "P"], [15.99, 16.97, "kilidin içinde.", "P"]];
let CARDS = [[0.55, 3.45, "door", "kapı"], [4.9, 7.45, "listen", "dinlemek"], [8.5, 10.45, "lock", "kilit"], [10.75, 11.95, "key", "anahtar"], [12.0, 14.4, "find", "bulmak"]];
let SHOTS = [ // img, start, end, zoom a->b, focus a->b (image px), lipsync on Pirinç lines
  { img: "R1", a: 0.0, b: 3.7, z: [1.12, 1.34], f: [[392, 780], [390, 764]], geo: "R1" },
  { img: "R3", a: 3.7, b: 7.5, z: [1.04, 1.30], f: [[384, 690], [452, 650]], geo: "R3" },
  { img: "R1", a: 7.5, b: 10.55, z: [1.55, 1.78], f: [[386, 806], [388, 796]], geo: "R1" },
  { img: "R3", a: 10.55, b: 14.55, z: [1.45, 1.85], f: [[500, 700], [520, 676]], geo: "R3" },
  { img: "R4", a: 14.55, b: 99, z: [1.22, 1.62], f: [[392, 520], [392, 640]], geo: "R4" }];
let DIPS = [3.7, 7.5, 14.55];
// Episode config (story_eps/epN.json) replaces the ep1 timeline above.
const CFG = window.STORY.cfg || null;
let JOLTS = [], HOOK = { text: "3 GÜNDÜR KİLİTLİ", end: 3.75, prev: null }, END_AT = 16.75, MOUTH_REF = 0.2;
if (CFG) {
  KNOCKS = CFG.knocks.map(k => k[0]); BLINKS = CFG.blinks || []; CARDS = CFG.cards; SHOTS = CFG.shots; DIPS = CFG.dips;
  LINES = CFG.voice.flatMap(v => v.chunks.map(c => [v.at + c[0], v.at + c[1], c[2], v.who]));
  JOLTS = CFG.jolts || []; HOOK = CFG.hook; END_AT = CFG.endAt; MOUTH_REF = CFG.mouthRef || 0.28;
}
// Kling stretches (muted, from kling_frames/): [out start, out end, Kling source start] in seconds. Final cut only.
window.KLING = (window.STORY.kling || []);
window.kimg = null; // 0.2 s dip to black centred on the cut

// ---- geometry (image px). R1 is measured; R3 is the same face mapped by an affine (lips centre + scale) ----
const R1 = { seam: [[316, 780], [346, 777], [376, 774], [400, 776], [420, 779], [440, 783], [456, 787]],
  bottom: [[309, 790], [336, 803], [376, 808], [416, 806], [452, 798], [464, 789]], maxD: 13,
  eyes: [{ c: [300, 678], r: 54, face: [390, 700] }, { c: [481, 682], r: 56, face: [390, 700] }] };
const mapGeo = (g, o, k, d) => { const m = p => [o[0] + k * (p[0] - 386), o[1] + k * (p[1] - 781)];
  return { seam: g.seam.map(m), bottom: g.bottom.map(m), maxD: g.maxD * k, eyes: g.eyes.map(e => ({ c: m(e.c), r: e.r * k, face: m(e.face) })) }; };
const GEO = { R1, R3: mapGeo(R1, [527, 682], 0.43), R4: null,
  // R2: sad face, lips droop at the corners
  R2: { seam: [[312, 791], [340, 787], [370, 785], [390, 784], [410, 785], [440, 787], [463, 791]],
    bottom: [[315, 797], [345, 809], [385, 815], [425, 812], [455, 802], [463, 795]], maxD: 13,
    eyes: [{ c: [300, 690], r: 58, face: [390, 640] }, { c: [480, 690], r: 58, face: [390, 640] }] } };
// R4 macro: lips run off both edges, seam is a shallow smile, the lower lip is deep
GEO.R4 = { seam: [[0, 244], [90, 226], [200, 208], [300, 199], [400, 197], [500, 201], [600, 211], [700, 227], [768, 243]],
  bottom: [[0, 300], [100, 318], [250, 331], [400, 334], [550, 329], [700, 313], [768, 299]], maxD: 28, eyes: [] };
if (CFG && CFG.geo) Object.assign(GEO, CFG.geo); // per-episode faces: { R13: { seam, bottom, maxD, eyes } }

const IMG = {};
const loads = Object.entries(STORY.imgs).map(([k, src]) => new Promise(r => { const i = new Image(); i.onload = () => { IMG[k] = i; r(); }; i.src = src; }));
const lerpPts = (pts, x) => { if (x <= pts[0][0]) return pts[0][1]; for (let i = 1; i < pts.length; i++) if (x <= pts[i][0]) { const p = (x - pts[i - 1][0]) / (pts[i][0] - pts[i - 1][0]); return lerp(pts[i - 1][1], pts[i][1], p); } return pts[pts.length - 1][1]; };

// ---- voice -> mouth openness ----
const env = STORY.env;
const rmsAt = t => { const i = clamp(Math.round(t * 100), 0, env.length - 1); return env[i]; };
function mouthOpen(t, whisper, talk) { // smoothed (attack fast, release slower) average around t; only lines of the shot's speaker (default Pirinç)
  const L = LINES.find(l => t >= l[0] - .03 && t <= l[1] + .08);
  if (!L || L[3] !== (talk || "P")) return 0;
  let s = 0, ws = 0;
  for (let k = -6; k <= 2; k++) { const w = k < 0 ? Math.exp(k * .25) : 1.2; s += rmsAt(t + k * .01) * w; ws += w; }
  const ref = whisper ? 0.045 : MOUTH_REF;
  return clamp(Math.pow(clamp(s / ws / ref), .8), 0, 1) * (whisper ? .8 : 1);
}

// ---- drawing the stills ----
let oc = document.createElement("canvas"); oc.width = oc.height = 256; const octx = oc.getContext("2d");
function drawBase(img, shear) { // optional shear: lock "swing" around the hasp (strip warp)
  if (!shear || !shear.a) { ctx.drawImage(img, 0, 0); return; }
  const y0 = shear.y0, y1 = shear.y1, st = 6;
  ctx.drawImage(img, 0, 0);
  for (let y = y0 + st; y < img.height; y += st) {
    const p = easeIO(seg(y, y0, y1)) * (1 - easeIO(seg(y, y1, y1 + 220)));
    ctx.drawImage(img, 0, y, img.width, st + 1, shear.a * p, y, img.width, st + 1);
  }
}
function mouth(img, g, o) {
  if (o < .02) return;
  const d = o * g.maxD, xl = g.seam[0][0], xr = g.seam[g.seam.length - 1][0];
  const sy = x => lerpPts(g.seam, x), by = x => lerpPts(g.bottom, x);
  const wgt = x => Math.pow(Math.sin(Math.PI * clamp((x - xl) / (xr - xl))), .7);
  // dark mouth interior between the seam and the lowered lip
  ctx.save();
  ctx.beginPath();
  for (let x = xl; x <= xr; x += 2) ctx.lineTo(x, sy(x) - .6);
  for (let x = xr; x >= xl; x -= 2) ctx.lineTo(x, sy(x) + d * wgt(x) + 1.5);
  ctx.closePath();
  const gr = ctx.createLinearGradient(0, sy((xl + xr) / 2), 0, sy((xl + xr) / 2) + d + 1);
  gr.addColorStop(0, "#040201"); gr.addColorStop(.6, "#0a0503"); gr.addColorStop(1, "#150b05");
  ctx.fillStyle = gr; ctx.fill(); ctx.restore();
  // lower lip: 1 px strips lowered by d * lens weight
  const step = Math.max(.7, (xr - xl) / 200);
  for (let x = xl; x < xr; x += step) {
    const y0 = sy(x) - .5, y1 = by(x) + 3;
    ctx.drawImage(img, x, y0, step + .6, y1 - y0, x, y0 + d * wgt(x), step + .6, y1 - y0);
  }
}
function patch(img, cx, cy, R, scale, bright) { // feathered zoomed patch (eye "snap")
  octx.clearRect(0, 0, 256, 256);
  const q = 256 / (2 * R);
  octx.globalCompositeOperation = "source-over";
  octx.drawImage(img, cx - R, cy - R, 2 * R, 2 * R, 0, 0, 256, 256);
  octx.globalCompositeOperation = "destination-in";
  const g = octx.createRadialGradient(128, 128, 60, 128, 128, 128);
  g.addColorStop(0, "#fff"); g.addColorStop(1, "rgba(255,255,255,0)"); octx.fillStyle = g; octx.fillRect(0, 0, 256, 256);
  octx.globalCompositeOperation = "source-over";
  ctx.drawImage(oc, 0, 0, 256, 256, cx - R * scale, cy - R * scale, 2 * R * scale, 2 * R * scale);
  if (bright > 0) { ctx.save(); ctx.globalCompositeOperation = "lighter"; ctx.globalAlpha = bright; ctx.drawImage(oc, 0, 0, 256, 256, cx - R * scale, cy - R * scale, 2 * R * scale, 2 * R * scale); ctx.restore(); }
}
const px1 = document.createElement("canvas"); px1.width = px1.height = 1; const p1 = px1.getContext("2d", { willReadFrequently: true });
function avgColor(img, x, y, w, h, m = 1) { p1.clearRect(0, 0, 1, 1); p1.drawImage(img, x, y, w, h, 0, 0, 1, 1); const d = p1.getImageData(0, 0, 1, 1).data; return `rgb(${d[0] * m | 0},${d[1] * m | 0},${d[2] * m | 0})`; }
function eyelid(img, e, cov) { // the still's own brass upper lid slid down over the eye; brass colour averaged from the lid
  if (cov < .02) return;
  const [cx, cy] = e.c, r = e.r;
  const shift = (cy + r * 1.0 - (cy - r * .40)) * cov;
  ctx.save();
  ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.clip();
  const lg = ctx.createLinearGradient(0, cy - r, 0, cy - r * .65 + shift + r * .1);
  const fw = Math.max(2, r * .3); lg.addColorStop(0, avgColor(img, e.face[0] - fw, e.face[1] - fw, 2 * fw, 2 * fw, .78)); lg.addColorStop(1, avgColor(img, e.face[0] - fw, e.face[1] - fw, 2 * fw, 2 * fw, .98));
  ctx.fillStyle = lg; ctx.fillRect(cx - r - 1, cy - r - 1, 2 * r + 2, r * .35 + shift + r * .12 + 1);
  ctx.drawImage(img, cx - r, cy - r * .65, 2 * r, r * .25, cx - r, cy - r * .65 + shift, 2 * r, r * .25);
  ctx.restore();
}
let hcCanvas = document.createElement("canvas"), hc = hcCanvas.getContext("2d", { willReadFrequently: true });
let hcFor = null;

// ---- camera ----
function camera(sh, t) {
  const p = easeIO(seg(t, sh.a, Math.min(sh.b, sh.a + 4.2)));
  const z0 = lerp(sh.z[0], sh.z[1], p);
  let fx = lerp(sh.f[0][0], sh.f[1][0], p), fy = lerp(sh.f[0][1], sh.f[1][1], p);
  // handheld drift
  fx += 2.2 * Math.sin(t * .9 + sh.a) + 1.1 * Math.sin(t * 2.3); fy += 2.0 * Math.sin(t * .7 + 2) + 1.0 * Math.sin(t * 1.9);
  let rot = .0022 * Math.sin(t * .6 + sh.a);
  let z = z0, sx = 0, sy = 0, shear = 0;
  for (const k of [...KNOCKS, ...JOLTS]) { const q = t - k; if (q >= 0 && q < 1) {
    const a = Math.exp(-q * 11); const ph = Math.sin(q * 52);
    sx += 16 * a * ph * (rnd(k * 9) > .5 ? 1 : -1); sy += 20 * a * Math.cos(q * 44); z += .035 * Math.exp(-q * 13); rot += .006 * a * ph; shear += 9 * Math.exp(-q * 8) * Math.sin(q * 38); } }
  return { z, fx, fy, rot, sx, sy, shear };
}

function glint(t) { // growing glint on the brass key tip inside the R4 keyhole
  let g = easeOut(seg(t, 14.9, 17.2)), hit = Math.exp(-Math.max(0, t - 15.97) * 4) * (t >= 15.97 ? 1 : 0);
  if (CFG) { g = .85 * (1 - easeIO(seg(t, 0.6, 3.6))); hit = 0; }
  const fl = 1 + .12 * Math.sin(t * 17) + .08 * Math.sin(t * 29);
  const R = (22 + 120 * g + 150 * hit) * fl;
  const x = 392, y = 672;
  ctx.save(); ctx.globalCompositeOperation = "lighter";
  let gr = ctx.createRadialGradient(x, y, 0, x, y, R);
  gr.addColorStop(0, `rgba(255,235,170,${.55 * (.3 + g) + .35 * hit})`); gr.addColorStop(.25, `rgba(255,190,90,${.28 * (.3 + g)})`); gr.addColorStop(1, "rgba(255,160,60,0)");
  ctx.fillStyle = gr; ctx.fillRect(x - R, y - R, 2 * R, 2 * R);
  const L = (20 + 70 * g + 110 * hit) * fl;
  for (const [dx, dy] of [[1, 0]]) { const lg = ctx.createLinearGradient(x - dx * L, y - dy * L * 1.4, x + dx * L, y + dy * L * 1.4);
    const al = .1 + .5 * g; lg.addColorStop(0, "rgba(255,230,170,0)"); lg.addColorStop(.5, `rgba(255,240,200,${al})`); lg.addColorStop(1, "rgba(255,230,170,0)");
    ctx.fillStyle = lg; ctx.fillRect(x - dx * L - (dy ? 2 : 0), y - dy * L * 1.4 - (dx ? 2 : 0), dx ? 2 * L : 4, dy ? 2.8 * L : 4); }
  ctx.restore();
}

// ---- grain & vignette ----
const grainTiles = [0, 1, 2, 3].map(n => { const c = document.createElement("canvas"); c.width = c.height = 360; const x = c.getContext("2d");
  const id = x.createImageData(360, 360); for (let i = 0; i < id.data.length; i += 4) { const v = (rnd(i * .37 + n * 1000) * 255) | 0; id.data[i] = id.data[i + 1] = id.data[i + 2] = v; id.data[i + 3] = 255; }
  x.putImageData(id, 0, 0); return c; });
function finish(t, fi, flick) {
  ctx.save(); ctx.globalCompositeOperation = "overlay"; ctx.globalAlpha = .17;
  const g = grainTiles[fi % 4], ox = (rnd(fi) * 360) | 0, oy = (rnd(fi + 99) * 360) | 0;
  for (let y = -360 + oy; y < H; y += 360) for (let x = -360 + ox; x < W; x += 360) ctx.drawImage(g, x, y, 360, 360);
  ctx.restore();
  const v = ctx.createRadialGradient(W / 2, H * .47, H * .28, W / 2, H * .5, H * .72);
  v.addColorStop(0, "rgba(0,0,0,0)"); v.addColorStop(1, "rgba(0,0,0,.62)"); ctx.fillStyle = v; ctx.fillRect(0, 0, W, H);
  if (flick) { ctx.fillStyle = `rgba(0,0,0,${flick})`; ctx.fillRect(0, 0, W, H); }
}

// ---- text ----
function shadowText(txt, x, y, font, fill, o = {}) {
  ctx.save(); ctx.font = font; ctx.textAlign = "center"; ctx.textBaseline = "middle"; ctx.fillStyle = fill;
  if (o.spacing) { ctx.letterSpacing = o.spacing; x += parseFloat(o.spacing) / 2; } // canvas adds spacing after the last letter too
  ctx.shadowColor = "rgba(0,0,0,.85)"; ctx.shadowBlur = o.blur ?? 14; ctx.shadowOffsetY = 3;
  ctx.fillText(txt, x, y); ctx.restore();
}
const CX = 540; // true centre; 800 px max line width keeps text clear of the Reels buttons
function hook(t) {
  const a = 1 - seg(t, HOOK.end - .3, HOOK.end);
  if (a <= 0) return;
  ctx.save(); ctx.globalAlpha = a;
  const y = 225;
  ctx.font = "800 84px Hanken"; ctx.letterSpacing = "3px";
  const w = ctx.measureText(HOOK.text).width;
  shadowText(HOOK.text, 540, y, "800 84px Hanken", "#F6EFE0", { spacing: "3px", blur: 22 });
  ctx.fillStyle = "#E49839"; ctx.fillRect(540 - w * .5, y + 58, w, 7);
  if (HOOK.prev) { ctx.globalAlpha = a * seg(t, .4, .8); shadowText(HOOK.prev, 540, y + 120, "600 38px Hanken", "rgba(244,241,235,.85)", { blur: 12 }); }
  ctx.restore();
}
function wordCard(t) {
  for (const [a, b, en, tr] of CARDS) {
    if (t < a || t > b) continue;
    const p = easeOut(seg(t, a, a + .3)), o = Math.min(p, 1 - seg(t, b - .22, b));
    ctx.save(); ctx.globalAlpha = o; ctx.translate(0, (1 - p) * 26);
    ctx.font = "italic 600 76px News"; const w1 = ctx.measureText(en).width;
    ctx.font = "700 64px Hanken"; const w2 = ctx.measureText(tr).width;
    const pad = 44, gap = 70, tw = w1 + gap + w2, bw = tw + pad * 2, bh = 118, bx = CX - bw / 2, by = 1392;
    ctx.fillStyle = "rgba(244,241,235,.95)"; ctx.shadowColor = "rgba(0,0,0,.45)"; ctx.shadowBlur = 30; ctx.shadowOffsetY = 8;
    ctx.beginPath(); ctx.roundRect(bx, by, bw, bh, 36); ctx.fill(); ctx.shadowColor = "transparent";
    ctx.textBaseline = "middle"; ctx.textAlign = "left";
    ctx.fillStyle = "#1B1916"; ctx.font = "italic 600 76px News"; ctx.fillText(en, bx + pad, by + bh / 2 + 3);
    ctx.fillStyle = "#B5651D"; ctx.font = "800 54px Hanken"; ctx.fillText("=", bx + pad + w1 + gap * .5 - 17, by + bh / 2 + 2);
    ctx.fillStyle = "#335AA6"; ctx.font = "700 64px Hanken"; ctx.fillText(tr, bx + pad + w1 + gap, by + bh / 2 + 2);
    ctx.restore();
  }
}
function subtitle(t) {
  const i = LINES.findIndex(l => t >= l[0] - .06 && t < l[1] + .28);
  if (i < 0) return;
  const [a, b, txt, who] = LINES[i];
  const words = txt.split(" "), tot = txt.replace(/ /g, "").length; let acc = 0;
  const o = Math.min(seg(t, a - .06, a + .04), 1 - seg(t, b + .12, b + .28));
  const E = who === "E", M = who === "M", K = who === "K"; // Elif italic blue, Minik green, Kapıcı lantern orange
  const col = E ? [207, 224, 255] : M ? [214, 245, 196] : K ? [255, 214, 170] : [255, 244, 214];
  ctx.save(); ctx.globalAlpha = o; ctx.textBaseline = "middle";
  const font = (E ? "italic 600 " : "800 ") + "62px " + (E ? "News" : "Hanken");
  ctx.font = font;
  const sp = ctx.measureText(" ").width;
  const lines = [], widths = []; let cur = []; // wrap at 800 px
  words.forEach(w => { const test = [...cur, w].join(" "); if (cur.length && ctx.measureText(test).width > 800) { lines.push(cur); cur = [w]; } else cur.push(w); });
  lines.push(cur);
  const lh = 78, y0 = (window.subLow ? 1700 : 1262) - (lines.length - 1) * lh / 2; // below the widget on phone shots let idx = 0;
  lines.forEach((ln, li) => {
    const lw = ctx.measureText(ln.join(" ")).width; let x = CX - lw / 2;
    ln.forEach(w => {
      const wlen = w.replace(/[^\p{L}]/gu, "").length; const startP = (acc / tot); acc += wlen;
      const spoken = t >= lerp(a, b, startP) - .02;
      ctx.save(); ctx.textAlign = "left"; ctx.shadowColor = "rgba(0,0,0,.9)"; ctx.shadowBlur = 16; ctx.shadowOffsetY = 3;
      ctx.lineWidth = 9; ctx.strokeStyle = "rgba(10,6,3,.55)"; ctx.lineJoin = "round"; ctx.font = font; ctx.strokeText(w, x, y0 + li * lh);
      ctx.fillStyle = `rgba(${col[0]},${col[1]},${col[2]},${spoken ? 1 : .45})`;
      ctx.fillText(w, x, y0 + li * lh); ctx.restore();
      x += ctx.measureText(w).width + sp;
    });
  });
  ctx.restore();
}
function endCard(t) {
  const a = easeOut(seg(t, END_AT, END_AT + .6)); if (a <= 0) return;
  ctx.fillStyle = `rgba(6,4,2,${.5 * a})`; ctx.fillRect(0, 0, W, H);
  ctx.save(); ctx.globalAlpha = a; ctx.translate(0, (1 - a) * 24);
  shadowText("KİLİTLİ KAPI", CX, 1330, "700 36px Hanken", "rgba(244,241,235,.75)", { spacing: "6px" });
  shadowText(STORY.endText || "Devamı bu akşam 20:30", CX, 1408, "800 74px Hanken", "#F6EFE0", { blur: 20 });
  ctx.restore();
}

function finishAll(t, fi, sh) {
  // torch / lamp flicker + dips to black
  const flick = (sh.img === "R3" || sh.img === "R8" || (CFG && (CFG.flicker || []).includes(sh.img))) ? .06 * (.5 + .5 * Math.sin(t * 23) * Math.sin(t * 7.3)) : .02 * (.5 + .5 * Math.sin(t * 11));
  let dip = 0; for (const d of DIPS) dip = Math.max(dip, 1 - seg(Math.abs(t - d), 0, .1));
  finish(t, fi, flick + dip * .98);
  endCard(t); hook(t); wordCard(t); subtitle(t);
}

function drawPhone(t, sh) { // lock-screen screenshot over a blurred, darkened still
  const bg = IMG[sh.img], ph = IMG[sh.phone];
  ctx.filter = "blur(22px) brightness(.4)"; ctx.drawImage(bg, -60, -60, W + 120, H + 120); ctx.filter = "none";
  const p = easeOut(seg(t, sh.a, sh.a + .55)), h = 1560 * (1 + .05 * seg(t, sh.a, sh.b)), w = ph.width * h / ph.height;
  const x = (W - w) / 2, y = (H - h) / 2 - 30 + (1 - p) * 70;
  ctx.save(); ctx.globalAlpha = p;
  if (sh.pz) { // push in on the widget: point (fraction of the screenshot) drifts toward the frame centre
    const q = easeIO(seg(t, sh.a + .7, sh.b - .2)), z = 1 + (sh.pz[2] - 1) * q;
    const px = x + sh.pz[0] * w, py = y + sh.pz[1] * h;
    ctx.translate(lerp(px, W / 2, q), lerp(py, 880, q)); ctx.scale(z, z); ctx.translate(-px, -py);
  } ctx.shadowColor = "rgba(0,0,0,.7)"; ctx.shadowBlur = 50;
  ctx.beginPath(); ctx.roundRect(x, y, w, h, 56); ctx.fillStyle = "#000"; ctx.fill(); ctx.shadowBlur = 0; ctx.clip();
  ctx.drawImage(ph, x, y, w, h); ctx.restore();
}

// ---- frame ----
window.draw = (t) => {
  const fi = Math.round(t * 30);
  const sh = SHOTS.find(s => t >= s.a && t < s.b) || SHOTS[SHOTS.length - 1];
  const img = IMG[sh.img], g = GEO[sh.geo];
  if (hcFor !== sh.img) { hcCanvas.width = img.width; hcCanvas.height = img.height; hc.drawImage(img, 0, 0); hcFor = sh.img; }
  const cam = camera(sh, t - 0); if (window.DEBUG_GEO) { cam.z = sh.img === "R4" ? 1.2 : 2.2; cam.fx = cam.fy = 0; cam.sx = cam.sy = cam.rot = 0; cam.fx = sh.img === "R4" ? 384 : 386; cam.fy = sh.img === "R4" ? 330 : 780; }
  ctx.save(); ctx.fillStyle = "#000"; ctx.fillRect(0, 0, W, H);
  window.subLow = !!sh.phone;
  if (sh.phone) { drawPhone(t, sh); ctx.restore(); finishAll(t, fi, sh); return; }
  if (window.kimg) { ctx.drawImage(window.kimg, 0, 0, W, H); ctx.restore(); finishAll(t, fi, sh); return; }
  const k = S0 * cam.z;
  ctx.translate(W / 2 + cam.sx, H / 2 + cam.sy); ctx.rotate(cam.rot); ctx.scale(k, k);
  const hx = 384 / cam.z, hy = 960 / (S0 * cam.z);
  const fx = clamp(cam.fx, hx, 768 - hx), fy = clamp(cam.fy, hy, 1376 - hy);
  ctx.translate(-fx, -fy);
  ctx.imageSmoothingQuality = "high";
  const swing = (sh.img === "R4" || !g) ? null : { a: cam.shear, y0: sh.img === "R1" ? 420 : 470, y1: sh.img === "R1" ? 760 : 700 };
  drawBase(img, swing);
  // eyes: snap on knocks / line starts, occasional blink
  if (g && g.eyes && g.eyes.length) {
    let pop = 0;
    for (const kn of KNOCKS) { const q = t - kn; if (q >= 0 && q < .5) pop = Math.max(pop, q < .06 ? q / .06 : Math.exp(-(q - .06) * 7)); }
    for (const e of g.eyes) if (pop > .02) patch(img, e.c[0], e.c[1], e.r * 1.55, 1 + .13 * pop, .16 * pop);
    let bl = 0; for (const b of BLINKS) { const q = t - b; if (q >= 0 && q < .2) bl = Math.max(bl, q < .07 ? q / .07 : q < .11 ? 1 : 1 - (q - .11) / .09); }
    if (bl > 0) for (const e of g.eyes) eyelid(img, e, easeIO(bl));
  }
  if (g && g.seam) mouth(img, g, mouthOpen(t, sh.img === "R4", sh.talk));
  if (sh.img === "R4") glint(t);
  if (window.DEBUG_GEO && g) { ctx.lineWidth = 1.5; for (const [pts, c] of [[g.seam, "#f00"], [g.bottom, "#0f0"]]) { ctx.strokeStyle = c; ctx.beginPath(); pts.forEach(p => ctx.lineTo(p[0], p[1])); ctx.stroke(); } }
  ctx.restore();
  finishAll(t, fi, sh);
};
window.storyReady = Promise.all([...loads, document.fonts.load("800 80px Hanken"), document.fonts.load("italic 600 70px News"), document.fonts.load("700 60px Hanken"), document.fonts.ready]);
