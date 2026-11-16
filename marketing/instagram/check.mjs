// Taşma denetimi: node check.mjs <id-prefix ...>
// Her varlığı örnek karelerde çizer; ekrandan taşan ya da kutusuna sığmayan görünür yazıları ve
// (Reels için) Instagram arayüzünün altında kalan yazıları listeler.
import puppeteer from "puppeteer-core";
import path from "node:path";
import fs from "node:fs";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
const here = path.dirname(fileURLToPath(import.meta.url));
const list = JSON.parse(execFileSync("node", ["-e", `
  global.window = {}; global.document = { createElement(){return {}} };
  ${fs.readFileSync(path.join(here, "assets.js"), "utf8")}
  console.log(JSON.stringify(ASSETS.map(a => ({ id: a.id, file: a.file, w: a.w, h: a.h, dur: a.dur || 0 }))));
`]).toString());
const only = process.argv.slice(2);
const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", args: ["--allow-file-access-from-files"] });
const page = await browser.newPage();
let bad = 0;
for (const a of list.filter(a => only.some(p => a.id.startsWith(p)))) {
  await page.setViewport({ width: a.w, height: a.h });
  await page.goto("file://" + path.join(here, "stage.html") + "?id=" + encodeURIComponent(a.id));
  await page.evaluate(() => window.assetReady);
  const times = a.dur ? Array.from({ length: Math.floor(a.dur / .25) }, (_, i) => i * .25) : [0];
  const found = new Map();
  for (const t of times) {
    if (a.dur) await page.evaluate(t => window.update(t), t);
    const res = await page.evaluate((W, H, isVideo) => {
      const out = [];
      const vis = el => { for (let e = el; e && e.id !== "root"; e = e.parentElement) if (parseFloat(getComputedStyle(e).opacity) < .5) return false; return true; };
      document.querySelectorAll("#root *").forEach(el => {
        const own = [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim());
        if (!own || !vis(el)) return;
        const r = el.getBoundingClientRect(), txt = el.textContent.trim().slice(0, 40);
        const range = document.createRange(); range.selectNodeContents(el);
        const tr = range.getBoundingClientRect();
        if (tr.left < 40 || tr.right > W - 40 || tr.top < 0 || tr.bottom > H) out.push(`dışarı taşıyor: "${txt}" (${Math.round(tr.left)}–${Math.round(tr.right)}, ${Math.round(tr.top)}–${Math.round(tr.bottom)})`);
        else if (el.scrollWidth > el.clientWidth + 2 && getComputedStyle(el).display !== "inline") out.push(`kutudan taşıyor: "${txt}"`);
        else if (isVideo && tr.bottom > 1560 && !el.closest(".brand")) out.push(`arayüz alanında (y>1560): "${txt}" (${Math.round(tr.bottom)})`);
      });
      return out;
    }, a.w, a.h, !!a.dur);
    res.forEach(m => { if (!found.has(m)) found.set(m, t); });
  }
  console.log(found.size ? `✗ ${a.file}` : `✓ ${a.file}`);
  found.forEach((t, m) => { console.log(`    t=${t}s ${m}`); bad++; });
}
await browser.close();
process.exit(bad ? 1 : 0);
