// Yayin oncesi TARAYICI kapisi: web yapisi gercekten aciliyor ve oynaniyor mu?
//
//   node tests/web-dogrula.mjs build/web            # export klasoru
//   node tests/web-dogrula.mjs build/web ciktilar   # ekran goruntusu de yaz
//
// Gereken: npm i --no-save playwright  (ya da kurulu bir playwright)
//
// NEDEN VAR. tests/dogrula.sh saf mantigi ve Godot calisma zamanini sinar;
// hicbiri TARAYICIDA acildigini sinamaz. Bu projede masaustunde gorunmeyen
// web hatalari kayitli: ses pitch/volume/dongu tarayicida sessizce bozulur,
// ve SharedArrayBuffer basligi eksikse oyun HIC acilmaz -- oyuncunun gordugu
// tek sey siyah ekran olur. itch.io'da bu kutu isaretlenmezse tam olarak bu
// yasanir, o yuzden kapi burada.
//
// Uc sey olculuyor:
//   1. SharedArrayBuffer var mi (COOP/COEP dogru mu)
//   2. Tuval boyaniyor mu, sayfa/konsol hatasi var mi
//   3. Enter'a basinca menuden kosuya GERCEKTEN geciliyor mu (piksel farki)

import { chromium } from "playwright";
import http from "node:http";
import fs from "node:fs";
import path from "node:path";

const kok = process.argv[2] || "build/web";
const ciktiDir = process.argv[3] || null;
const PORT = 8901;

if (!fs.existsSync(path.join(kok, "index.html"))) {
  console.error(`index.html yok: ${kok}`);
  console.error("Once web export al:  godot --headless --path . --export-release \"Web (HTML5)\" build/web/index.html");
  process.exit(2);
}

const TIP = {
  ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm",
  ".pck": "application/octet-stream", ".png": "image/png", ".json": "application/json",
};

// COOP/COEP olmadan SharedArrayBuffer kapali olur ve motor baslamaz.
// itch.io'daki "SharedArrayBuffer support" kutusu tam olarak bunu aciyor,
// yani bu sunucu itch ortamini taklit ediyor.
const sunucu = http.createServer((q, c) => {
  const url = decodeURIComponent(q.url.split("?")[0]);
  const p = path.join(kok, url === "/" ? "index.html" : url);
  fs.readFile(p, (e, d) => {
    if (e) { c.writeHead(404); return c.end("yok"); }
    c.writeHead(200, {
      "Content-Type": TIP[path.extname(p)] || "application/octet-stream",
      "Cross-Origin-Opener-Policy": "same-origin",
      "Cross-Origin-Embedder-Policy": "require-corp",
    });
    c.end(d);
  });
});

const farkOrani = (a, b) => {
  let n = 0, k = 0;
  const u = Math.min(a.length, b.length);
  for (let i = 0; i < u; i += 997) { k++; if (a[i] !== b[i]) n++; }
  return k ? n / k : 0;
};

let cikis = 0;
const sorun = (m) => { console.log(`  [HATA] ${m}`); cikis = 1; };
const iyi = (m) => console.log(`  [ok]   ${m}`);

await new Promise((r) => sunucu.listen(PORT, "127.0.0.1", r));
const tarayici = await chromium.launch();
try {
  const sayfa = await (await tarayici.newContext({
    viewport: { width: 1280, height: 720 },
  })).newPage();

  const sayfaHatalari = [], konsolHatalari = [];
  sayfa.on("pageerror", (e) => sayfaHatalari.push(String(e).slice(0, 300)));
  sayfa.on("console", (m) => {
    if (/error|exception|failed/i.test(m.text())) konsolHatalari.push(m.text().slice(0, 200));
  });

  console.log("Kor web dogrulama");
  await sayfa.goto(`http://127.0.0.1:${PORT}/index.html`, { waitUntil: "load", timeout: 60000 });

  if (await sayfa.evaluate(() => typeof SharedArrayBuffer !== "undefined")) {
    iyi("SharedArrayBuffer acik");
  } else {
    sorun("SharedArrayBuffer YOK - itch'te 'SharedArrayBuffer support' isaretlenmezse oyun hic acilmaz");
  }

  // Motor acilisi + ilk kare. Dusuk uclu makinede uzun surebiliyor.
  await sayfa.waitForTimeout(32000);

  const tuval = await sayfa.evaluate(() => {
    const c = document.querySelector("canvas");
    return c ? { var: true, en: c.width, boy: c.height } : { var: false };
  });
  if (tuval.var && tuval.en > 0) iyi(`tuval ${tuval.en}x${tuval.boy}`);
  else sorun("tuval yok veya bos");

  const menuKare = await sayfa.screenshot();

  // Menuden kosuya gec. Once tuvale odaklan, yoksa klavye sayfaya gider.
  await sayfa.locator("canvas").click({ position: { x: 640, y: 400 } });
  await sayfa.keyboard.press("Enter");
  await sayfa.waitForTimeout(6000);
  const kosuKare = await sayfa.screenshot();

  const gecis = farkOrani(menuKare, kosuKare);
  if (gecis > 0.1) iyi(`menu -> kosu gecisi (ekran %${Math.round(gecis * 100)} degisti)`);
  else sorun(`menu -> kosu gecisi YOK (ekran yalnizca %${Math.round(gecis * 100)} degisti)`);

  // Girdiye cevap veriyor mu: hareket + ates.
  for (const t of ["KeyW", "KeyD", "KeyS", "KeyA"]) {
    await sayfa.keyboard.down(t); await sayfa.waitForTimeout(400); await sayfa.keyboard.up(t);
  }
  await sayfa.locator("canvas").click({ position: { x: 800, y: 300 } });
  await sayfa.waitForTimeout(3000);
  const sonKare = await sayfa.screenshot();
  if (farkOrani(kosuKare, sonKare) > 0.05) iyi("oyun girdiye cevap veriyor");
  else sorun("girdiden sonra ekran degismedi - oyun donmus olabilir");

  if (sayfaHatalari.length === 0) iyi("sayfa hatasi yok");
  else { sorun(`${sayfaHatalari.length} sayfa hatasi`); sayfaHatalari.slice(0, 5).forEach((h) => console.log("         " + h)); }

  if (konsolHatalari.length === 0) iyi("konsol hatasi yok");
  else { sorun(`${konsolHatalari.length} konsol hatasi`); konsolHatalari.slice(0, 5).forEach((h) => console.log("         " + h)); }

  if (ciktiDir) {
    fs.mkdirSync(ciktiDir, { recursive: true });
    fs.writeFileSync(path.join(ciktiDir, "web-menu.png"), menuKare);
    fs.writeFileSync(path.join(ciktiDir, "web-kosu.png"), kosuKare);
    console.log(`  ekran goruntuleri: ${ciktiDir}`);
  }
} finally {
  await tarayici.close();
  sunucu.close();
}

console.log(cikis === 0 ? "SONUC: TEMIZ" : "SONUC: SORUNLU");
process.exit(cikis);
