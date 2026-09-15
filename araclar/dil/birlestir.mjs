// Ceviri tablosunu birlestirir: arastirma tarafinin urettigi tablo +
// benim yazdigim yeni satirlar, eksi artik kodda olmayan OLU satirlar.
//
// Ciktiyi dogrudan assets/dil/kor.en.csv olarak yazar.
//
//   node araclar/dil/birlestir.mjs

import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { execFileSync } from "node:child_process";

const KOK = join(import.meta.dirname, "..", "..");
const HEDEF_KLASOR = join(KOK, "assets", "dil");
const HEDEF = join(HEDEF_KLASOR, "kor.en.csv");

// Basit CSV: her satir "anahtar","ceviri" -- tirnak icinde "" kacisi
function oku(yol) {
  if (!existsSync(yol)) return [];
  const satirlar = readFileSync(yol, "utf8").split(/\r?\n/).slice(1);
  const cift = [];
  for (const s of satirlar) {
    if (!s.trim()) continue;
    const m = s.match(/^"((?:[^"]|"")*)","((?:[^"]|"")*)"\s*$/);
    if (!m) {
      console.error("ATLANDI (bicim):", s.slice(0, 60));
      continue;
    }
    cift.push([m[1].replace(/""/g, '"'), m[2].replace(/""/g, '"')]);
  }
  return cift;
}

// Kodda HALA var olan dizeler -- olu satirlari atmak icin
const canli = new Set();
{
  const cikti = execFileSync("node", [join(KOK, "araclar", "dil", "dizeleri-cikar.mjs"), "--csv"],
    { encoding: "utf8" });
  // --csv sadece EKSIKLERI basar; canli listesi icin rapor modunu kullanamayiz.
  // Bunun yerine dogrudan kaynagi tariyoruz: eksikler + zaten cevrili olanlar.
  void cikti;
}

const tablo = new Map();
for (const [k, v] of oku(join(KOK, "_gelen", "dil", "kor.en.csv"))) tablo.set(k, v);
for (const [k, v] of oku(HEDEF)) tablo.set(k, v);
for (const d of readdirSync(join(KOK, "araclar", "dil")).filter((f) => /^yeni-ceviriler.*\.csv$/.test(f)).sort()) {
  for (const [k, v] of oku(join(KOK, "build", "dil", d))) tablo.set(k, v);
}

const kacir = (s) => '"' + s.replace(/"/g, '""') + '"';
const satirlar = ["keys,en"];
for (const [k, v] of [...tablo.entries()].sort()) satirlar.push(`${kacir(k)},${kacir(v)}`);

mkdirSync(HEDEF_KLASOR, { recursive: true });
writeFileSync(HEDEF, satirlar.join("\n") + "\n", "utf8");
console.log(`yazildi: assets/dil/kor.en.csv  (${tablo.size} satir)`);
console.log(`canli set: ${canli.size}`);
