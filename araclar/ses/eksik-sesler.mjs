// Kor'un sessiz kalan bes olayi. Deterministik: ayni tohum -> ayni dosya.
//   node araclar/ses/eksik-sesler.mjs
//
// Neden elde uretiliyor: bu bes olay oyunun en duygusal anlari (hasar almak,
// olmek, patron uyanmak). Hazir kutuphane sesi kimligi bozardi; hepsi ayni
// palete -- kor/kul/metal -- oturmali.

import { writeFileSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const CIKTI = join(dirname(fileURLToPath(import.meta.url)), "cikti");
const SR = 44100;

function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// 16 bit mono PCM -- mevcut seslerle ayni bicim.
function yaz(ad, ornekler) {
  const n = ornekler.length;
  const b = Buffer.alloc(44 + n * 2);
  b.write("RIFF", 0); b.writeUInt32LE(36 + n * 2, 4); b.write("WAVE", 8);
  b.write("fmt ", 12); b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20);
  b.writeUInt16LE(1, 22); b.writeUInt32LE(SR, 24); b.writeUInt32LE(SR * 2, 28);
  b.writeUInt16LE(2, 32); b.writeUInt16LE(16, 34);
  b.write("data", 36); b.writeUInt32LE(n * 2, 40);
  let tepe = 0;
  for (const v of ornekler) tepe = Math.max(tepe, Math.abs(v));
  // Normalize: -1 dB tavan. Kirpma olmasin ama ses de cilizsa kalmasin.
  const k = tepe > 0 ? 0.89 / tepe : 0;
  for (let i = 0; i < n; i++) {
    b.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(ornekler[i] * k * 32767))), 44 + i * 2);
  }
  writeFileSync(join(CIKTI, ad), b);
  return { ad, sn: (n / SR).toFixed(3), tepe: tepe.toFixed(3) };
}

// sure saniye, uret(t, p) -> -1..1   (t = saniye, p = 0..1 ilerleme)
const kur = (sure, uret) => {
  const n = Math.floor(SR * sure), o = new Float64Array(n);
  for (let i = 0; i < n; i++) o[i] = uret(i / SR, i / n);
  return o;
};

const rapor = [];
mkdirSync(CIKTI, { recursive: true });

// --- 1. oyuncu_hasar: eti degil, SOGUYAN METALI duy ----------------------
// Kor'da hasar "canin gitmesi" degil, korun sonmesi. Bu yuzden dusen bir
// perde + kisa buhar tislamasi. Kisa (0,22 sn) cunku sik calacak.
{
  const r = mulberry32(7301);
  rapor.push(yaz("oyuncu_hasar.wav", kur(0.22, (t, p) => {
    const dusen = Math.sin(2 * Math.PI * (420 - 300 * p) * t) * Math.exp(-p * 9);
    const carpma = Math.sin(2 * Math.PI * (150 - 90 * p) * t) * Math.exp(-p * 16) * 0.8;
    const buhar = (r() * 2 - 1) * Math.exp(-p * 5) * (p > 0.25 ? 0.22 : 0.05);
    return dusen * 0.5 + carpma + buhar;
  })));
}

// --- 2. oyun_bitti: son kor sonuyor -------------------------------------
// Uzun (2,6 sn) ve inen. Hicbir sey "kaybettin" demiyor; ocak soguyor.
{
  const r = mulberry32(1918);
  rapor.push(yaz("oyun_bitti.wav", kur(2.6, (t, p) => {
    const kok = 98 * Math.pow(2, -1.6 * p);           // bir buçuk oktav duser
    const gov = (Math.sin(2 * Math.PI * kok * t) + Math.sin(2 * Math.PI * kok * 1.5 * t) * 0.4);
    const kul = (r() * 2 - 1) * Math.exp(-Math.pow(p - 0.08, 2) * 90) * 0.30;
    const zil = Math.sin(2 * Math.PI * 1760 * t) * Math.exp(-p * 6) * 0.10;
    const sonus = Math.exp(-p * 2.1);
    return (gov * 0.34 + kul + zil) * sonus;
  })));
}

// --- 3. patron_uyandi: KUL ANASI ----------------------------------------
// Alcak bir nefes + yukselen ugultu. Oyuncu bunu duyunca ekrani aramali.
{
  const r = mulberry32(4404);
  rapor.push(yaz("patron_uyandi.wav", kur(2.2, (t, p) => {
    const nefes = (r() * 2 - 1) * Math.exp(-Math.pow(p - 0.12, 2) * 45) * 0.45;
    const yukselen = Math.sin(2 * Math.PI * (36 + 54 * p * p) * t) * Math.min(1, p * 4) * 0.9;
    const cinlama = Math.sin(2 * Math.PI * (880 + 420 * p) * t) * Math.exp(-Math.pow(p - 0.72, 2) * 140) * 0.20;
    const kapanis = 1 - Math.pow(Math.max(0, p - 0.82) / 0.18, 2);
    return (nefes + yukselen * 0.55 + cinlama) * Math.max(0, kapanis);
  })));
}

// --- 4. soguk_dalga: isi bir anda sifirlaniyor ---------------------------
// Ters tarafta: yukselen degil, ICE CEKEN bir ses. Emme + cam kirilmasi.
{
  const r = mulberry32(6120);
  rapor.push(yaz("soguk_dalga.wav", kur(1.4, (t, p) => {
    const emme = Math.sin(2 * Math.PI * (60 + 500 * Math.pow(1 - p, 3)) * t) * Math.exp(-p * 2.4) * 0.55;
    const cam = (r() * 2 - 1) * Math.exp(-Math.pow(p - 0.30, 2) * 400) * 0.60;
    const kristal = (Math.sin(2 * Math.PI * 2640 * t) + Math.sin(2 * Math.PI * 3520 * t) * 0.6)
      * Math.exp(-Math.max(0, p - 0.28) * 9) * (p > 0.28 ? 0.22 : 0);
    return emme + cam + kristal;
  })));
}

// --- 5. kosu_bitti: 12 dakika bitti, kazandin ---------------------------
// Tek net akor. Zafer marsi degil -- Kor'un dili sakin. Ucuncu ve besinci.
{
  rapor.push(yaz("kosu_bitti.wav", kur(3.0, (t, p) => {
    const ses = (f, gec, kaz) => (t < gec ? 0
      : Math.sin(2 * Math.PI * f * (t - gec)) * Math.exp(-(t - gec) * 1.15) * kaz);
    const akor = ses(220, 0.00, 1.0) + ses(277.2, 0.10, 0.75)
      + ses(329.6, 0.20, 0.62) + ses(440, 0.30, 0.45) + ses(659.3, 0.45, 0.22);
    const parlak = Math.sin(2 * Math.PI * 1318.5 * t) * Math.exp(-p * 7) * 0.08;
    return akor * 0.36 + parlak;
  })));
}

console.table(rapor);
