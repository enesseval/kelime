// Kilitli Kapı episode renderer: node story.mjs <ep-dir> <out.mp4> [t ...]   (extra t values = stills to check instead of video)
// Needs <ep-dir>/R1.jpg R3.jpg R4.jpg env.json mix.wav (python3 story_audio.py <ep-dir> <total>).
import puppeteer from "puppeteer-core";
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
const here = path.dirname(fileURLToPath(import.meta.url));
const ep = path.resolve(process.argv[2]), outFile = path.resolve(process.argv[3]);
const stills = process.argv.slice(4).map(Number);
const cfgFile = path.join(here, "story_eps", path.basename(ep) + ".json");
const cfg = fs.existsSync(cfgFile) ? JSON.parse(fs.readFileSync(cfgFile)) : null;
const FPS = 30, TOTAL = cfg ? cfg.total : 18.74;
const uri = f => `data:image/${f.endsWith(".png") ? "png" : "jpeg"};base64,` + fs.readFileSync(path.join(ep, f)).toString("base64");
const imgs = Object.fromEntries(fs.readdirSync(ep).filter(f => /^(R\d+\.jpg|[a-z]+\.png)$/.test(f)).map(f => [f.replace(/\.(jpg|png)$/, ""), uri(f)]));
const story = { imgs, cfg, endText: (cfg && cfg.endText) || process.env.END_TEXT || null, env: JSON.parse(fs.readFileSync(path.join(ep, "env.json"))), total: TOTAL, kling: JSON.parse(process.env.KLING || "[]") };
const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", args: ["--allow-file-access-from-files", "--font-render-hinting=none"] });
const page = await browser.newPage();
await page.setViewport({ width: 1080, height: 1920, deviceScaleFactor: 1 });
await page.evaluateOnNewDocument(s => { window.STORY = s; }, story);
page.on("pageerror", e => console.log("PAGE ERROR", e.message));
if (process.env.DEBUG_GEO) await page.evaluateOnNewDocument(() => { window.DEBUG_GEO = true; });
await page.goto("file://" + path.join(here, "story.html"));
await page.evaluate(() => window.storyReady);
const kdir = path.join(ep, "kling_frames");
async function setKling(t) {
  const seg = story.kling.find(k => t >= k[0] && t < k[1]);
  if (!seg) { await page.evaluate(() => { window.kimg = null; }); return; }
  const idx = Math.min(755, Math.round((seg[2] + (t - seg[0])) * FPS));
  const d = "data:image/jpeg;base64," + fs.readFileSync(path.join(kdir, String(idx).padStart(5, "0") + ".jpg")).toString("base64");
  await page.evaluate(src => new Promise(r => { const im = new Image(); im.onload = () => { window.kimg = im; r(); }; im.src = src; }), d);
}
if (stills.length) {
  fs.mkdirSync(outFile, { recursive: true });
  for (const t of stills) { await setKling(t); await page.evaluate(t => window.draw(t), t); await page.screenshot({ path: path.join(outFile, `t${t.toFixed(2)}.png`), clip: { x: 0, y: 0, width: 1080, height: 1920 } }); }
  await browser.close(); process.exit(0);
}
const dir = path.join(here, "frames", "story"); fs.rmSync(dir, { recursive: true, force: true }); fs.mkdirSync(dir, { recursive: true });
const n = Math.round(TOTAL * FPS);
for (let i = 0; i < n; i++) {
  const t = i / FPS; await setKling(t);
  await page.evaluate(t => window.draw(t), t);
  await page.screenshot({ path: path.join(dir, String(i).padStart(5, "0") + ".jpg"), type: "jpeg", quality: 93, clip: { x: 0, y: 0, width: 1080, height: 1920 } });
}
await browser.close();
fs.mkdirSync(path.dirname(outFile), { recursive: true });
execFileSync("swift", [path.join(here, "encode.swift"), dir, outFile, String(FPS), path.join(ep, "mix.wav")], { stdio: "inherit" });
fs.rmSync(dir, { recursive: true, force: true });
console.log("✓", outFile, `(${TOTAL} sn)`);
