// node android_story.mjs  ->  out/android_yayinda_story.png (1080x1920; link sticker area left empty at y~1500-1750)
import puppeteer from "puppeteer-core";
import path from "node:path";
import { fileURLToPath } from "node:url";
const here = path.dirname(fileURLToPath(import.meta.url));
const b = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", args: ["--allow-file-access-from-files"] });
const p = await b.newPage(); await p.setViewport({ width: 1080, height: 1920 });
await p.goto("file://" + path.join(here, "android_story.html")); await p.evaluate(() => document.fonts.ready);
await new Promise(r => setTimeout(r, 500));
await p.screenshot({ path: path.join(here, "out", "android_yayinda_story.png") }); await b.close();
