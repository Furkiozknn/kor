// Oyundaki KULLANICIYA GORUNEN Turkce dizeleri cikarir ve ceviri
// tablosuyla karsilastirir.
//
// Neden arac: ceviri tek seferlik bir is degil. Her yeni ozellik yeni
// dize getiriyor ve elle takip edilemez -- arastirma tarafinin hazirladigi
// 84 satirlik tablo, uzerine bir tur gelistirme yapildigi anda eskidi.
//
//   node araclar/dil/dizeleri-cikar.mjs              rapor
//   node araclar/dil/dizeleri-cikar.mjs --csv        eksikleri CSV olarak bas

import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join } from "node:path";

const KOK = join(import.meta.dirname, "..", "..");
const KLASORLER = ["scripts"];
const CSV = join(KOK, "assets", "dil", "kor.en.csv");

// Turkce'ye ozgu harf iceren ya da bosluklu cok kelimeli dizeler
// kullaniciya gorunen metin sayiliyor. Tek kelimelik ASCII dizeler
// (ses adlari, grup adlari, sozluk anahtarlari) eleniyor.
const TR = /[çğıöşüÇĞİÖŞÜ]/;
// DIKKAT: burada eskiden "saf ASCII ise ele" kurali vardi ve SES, FIRIN,
// HAREKET, efekt gibi GERCEK arayuz kelimelerini sessizce atiyordu --
// ekran goruntusunde yakalandi. Artik sadece kod-benzeri dizeler eleniyor.
const ELE = [
  /^res:\/\//, /^user:\/\//,
  /^[a-z][a-z0-9_]*$/,          // snake_case anahtar (ses adi, grup adi)
  /^[%.\d+\-ds fx]*$/,          // sadece bicimlendirme ("%d", "%.1f", "x%d")
];

function gorunurMu(m) {
  if (m.length < 2) return false;
  // Harf icermeyen dizeler ayraç/bicimlendirme parcasi ("  ·  ", ", ")
  if (!/[A-Za-zçğıöşüÇĞİÖŞÜ]/.test(m)) return false;
  // Ic ice tirnak yuzunden yarim yakalanan kod parcalari
  if (m.includes('["') || m.includes('%s"')) return false;
  if (ELE.some((r) => r.test(m))) return false;
  return TR.test(m) || /\s/.test(m);
}

const dizeler = new Map();   // metin -> [dosya:satir]
for (const kl of KLASORLER) {
  for (const dosya of readdirSync(join(KOK, kl))) {
    if (!dosya.endsWith(".gd")) continue;
    // Gelistirici katmani (F3) sadece hata ayiklama; oyuncu gormuyor.
    if (dosya === "gelistirici.gd") continue;
    const yol = join(KOK, kl, dosya);
    readFileSync(yol, "utf8").split("\n").forEach((satir, i) => {
      const kod = satir.trimStart();
      if (kod.startsWith("#")) return;            // yorum satiri
      // Gelistirici uyarilari oyuncuya gosterilmiyor (konsola gidiyor).
      if (/push_(warning|error)\s*\(/.test(satir)) return;
      // Dil dugmesinin kendi etiketi cevrilmez: dilin ADI o dilde yazilir.
      if (/_dil_dugme\.text/.test(satir)) return;
      // Cok satirli bicim ifadesinin DEVAM satiri: bastaki tirnak bir
      // onceki satirda acilmis, burada yakalanan sey kod parcasi.
      if (kod.startsWith("%")) return;
      for (const m of satir.matchAll(/"([^"\n]*)"/g)) {
        const metin = m[1];
        if (!gorunurMu(metin)) continue;
        if (!dizeler.has(metin)) dizeler.set(metin, []);
        dizeler.get(metin).push(`${kl}/${dosya}:${i + 1}`);
      }
    });
  }
}

// Mevcut ceviri tablosu
const cevrili = new Set();
if (existsSync(CSV)) {
  for (const satir of readFileSync(CSV, "utf8").split("\n").slice(1)) {
    const m = satir.match(/^"((?:[^"]|"")*)"/);
    if (m) cevrili.add(m[1].replace(/""/g, '"'));
  }
}

const hepsi = [...dizeler.keys()].sort();
const eksik = hepsi.filter((d) => !cevrili.has(d));
const olu = [...cevrili].filter((d) => !dizeler.has(d));

if (process.argv.includes("--csv")) {
  console.log("keys,en");
  for (const d of eksik) console.log(`"${d.replace(/"/g, '""')}",""`);
} else {
  console.log(`oyundaki gorunur dize : ${hepsi.length}`);
  console.log(`ceviri tablosunda     : ${cevrili.size}`);
  console.log(`EKSIK (cevrilmemis)   : ${eksik.length}`);
  console.log(`OLU (artik kodda yok) : ${olu.length}`);
  console.log("\n--- EKSIK ---");
  for (const d of eksik) console.log(`  ${JSON.stringify(d)}   ${dizeler.get(d)[0]}`);
  console.log("\n--- OLU (tablodan cikarilmali) ---");
  for (const d of olu) console.log(`  ${JSON.stringify(d)}`);
}

// --kontrol: dogrulama zinciri icin. Eksik varsa sifir disi cikis kodu.
if (process.argv.includes("--kontrol")) {
  if (eksik.length > 0) {
    console.error(`HATA: ${eksik.length} dize cevrilmemis`);
    for (const d of eksik) console.error(`  ${JSON.stringify(d)}  ${dizeler.get(d)[0]}`);
    process.exit(1);
  }
  console.log(`TAMAM dil: ${hepsi.length} dize, hepsi cevrili (olu kayit ${olu.length})`);
}
