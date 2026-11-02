// Renders the Instagram assets: node render.mjs [id-prefix ...]
// Stills go to out/<file>.png; videos are drawn frame by frame and encoded by encode.swift.
import puppeteer from "puppeteer-core";
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const FPS = 30;
const list = JSON.parse(execFileSync("node", ["-e", `
  global.window = {}; global.document = { createElement(){return {}} };
  ${fs.readFileSync(path.join(here, "assets.js"), "utf8")}
  console.log(JSON.stringify(ASSETS.map(a => ({ id: a.id, file: a.file, w: a.w, h: a.h, dur: a.dur || 0, needs: a.needs || [] }))));
`]).toString());
const only = process.argv.slice(2);
const todo = list.filter(a => !only.length || only.some(p => a.id.startsWith(p)));

const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  args: ["--allow-file-access-from-files", "--font-render-hinting=none"] });
const page = await browser.newPage();
const skipped = [];
for (const a of todo) {
  const missing = a.needs.filter(f => !fs.existsSync(path.join(here, "shots", f)));
  if (missing.length) { skipped.push(`${a.file}: ${missing.join(", ")}`); continue; }
  await page.setViewport({ width: a.w, height: a.h, deviceScaleFactor: 1 });
  await page.goto("file://" + path.join(here, "stage.html") + "?id=" + encodeURIComponent(a.id));
  await page.evaluate(() => window.assetReady);
  const out = path.join(here, "out", a.file);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  if (!a.dur) {
    await page.screenshot({ path: out, clip: { x: 0, y: 0, width: a.w, height: a.h } });
    console.log("✓", a.file);
    continue;
  }
  const dir = path.join(here, "frames", a.id);
  fs.rmSync(dir, { recursive: true, force: true }); fs.mkdirSync(dir, { recursive: true });
  const n = Math.round(a.dur * FPS);
  for (let i = 0; i < n; i++) {
    await page.evaluate(t => window.update(t), i / FPS);
    await page.screenshot({ path: path.join(dir, String(i).padStart(5, "0") + ".jpg"), type: "jpeg", quality: 92,
      clip: { x: 0, y: 0, width: a.w, height: a.h } });
  }
  execFileSync("swift", [path.join(here, "encode.swift"), dir, out, String(FPS)], { stdio: "inherit" });
  fs.rmSync(dir, { recursive: true, force: true });
  console.log("✓", a.file, `(${a.dur} sn)`);
}
await browser.close();
if (skipped.length) console.log("\nEksik ekran görüntüsü yüzünden atlananlar:\n  " + skipped.join("\n  "));
