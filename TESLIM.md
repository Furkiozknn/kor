# Kor — teslim durumu

Son güncelleme: 15 Eylül 2026. Bu dosya **projenin nerede olduğunu** ve
**yayına ne kaldığını** tek yerde tutar.

---

## Ne durumda

| alan | durum |
|---|---|
| Çekirdek oynanış | tamam — ısı = görüş, dalış, kor atışı, döküm, damga |
| Koşu yapısı | 12 dakika, şekilli evreler, üç patron, SON DARBE uzatması |
| Meta | görevler (5), fırın kademesi (0-3), günün dökümü, en iyi döküm |
| İçerik | 4 silah + 6 damga, 7 düşman türü, 20+ kart, 3 patron |
| Görsel | sönük dökümhane, sıcak ışık, çekirdek imzaları, 13 zemin karosu |
| Ses | 16 olay + ısıyla yükselen iki katmanlı müzik |
| Dil | Türkçe + İngilizce, kapsam **test ediliyor** |
| Erişilebilirlik | sarsıntı 3 kademe, vuruş donması, oto ateş, 5,9 Hz yanıp sönme |
| Test | `dogrula.sh` 10 adım, hepsi geçiyor |
| Derleme | Windows + Web, ikisi de güncel |

## Ölçülen sayılar

```
hayatta kalma (ortanca, 10 koşu)   608,1 / 720 sn
ortalama ısı                        %57
öldürme (ortanca)                   ~800
kare bütçesi aşımı                  %0
tarayıcı indirmesi (gzip)           ~11,4 MB  (wasm 9,9 + pck 1,4)
```

Ölçüm zinciri (aynı tohum, kademe sabit): 528,7 → 572,6 → 603,7 → 660,3 → 608,1

## Bilinen açık konular

1. **Bot 10/10 ölüyor.** Bir kez kazanmıştı (720/720) ama o ölçüm
   `kor_maliyet` 0,4 ve zorluk merdiveni değişmeden önceydi. Bot zayıf bir
   vekil: `kilit/dk 0,0` ile oynuyor, dökümü panikte basıyor, küpleri pasif
   topluyor. **Bunu körlemesine ayarlamıyoruz** — araştırma tarafından
   insan politikasını temsil eden bir bot ölçümü istendi (`_gelen/ISTEK.md`).
2. **Zorluk merdiveni yapısal olarak monoton**, ama bu bir yama: her kademe
   `guc_carpani *= 1,14^k` alıyor çünkü ısı ekonomisine dokunan
   değiştiriciler mevcut botla ölçülemiyor.
3. `.wasm` 38,8 MB (gzip 9,9). Godot'nun tarayıcı tabanı; küçültmek özel
   şablon derlemesi gerektirir.
4. Işık duvarlardan geçiyor (`karanlik.gdshader` saf radyal). Şu an fark
   edilmiyor çünkü yapılar 16 px; koridorlu arena yapılırsa sorun olur.

## Yayın için gereken — ONAY BEKLİYOR

Aşağıdakiler **dışarı açılan işlemler**, izin olmadan yapılmadı:

- [ ] itch.io sayfası oluşturma ve derlemeyi yükleme
- [ ] Sayfa metni (Türkçe/İngilizce hangisi önce?)
- [ ] Kapak görseli seçimi (`_gelen/tanitim/` altında aday var, ama oyun
      o zamandan beri görsel olarak değişti)
- [ ] Tanıtım GIF/videosu
- [ ] Depoyu public yapma

**Kritik hatırlatma:** itch.io'da **SharedArrayBuffer kutusu işaretli
olmalı.** `export_presets.cfg` içinde `thread_support=true` açık; kutu
işaretlenmezse oyun tarayıcıda **hiç açılmaz.**

Gömme boyutu **1280×720** (tam 2×; `scale_mode="integer"` ile bantsız).

## Nasıl doğrulanır

```bash
bash tests/dogrula.sh        # 10 adım, herhangi bir ERROR satırı = başarısız
```

Derleme:

```bash
godot --headless --export-release "Windows Masaustu" build/windows/Kor.exe
godot --headless --export-release "Web (HTML5)"      build/web/index.html
node _gelen/arac/web-sunucu.mjs build/web 8123   # COOP+COEP başlıklarıyla sun
```

## Geliştirici araçları

```bash
godot --headless --fixed-fps 60 --script res://tests/denge.gd -- --kosu 10 --sure 720 --kademe 0
godot --script res://tests/ekran_al.gd -- --acilis     # ilk 20 saniyenin üç anı
godot --script res://tests/ekran_al.gd -- --menu --en  # herhangi bir ekran İngilizce
node build/dil/dizeleri-cikar.mjs                      # çevrilmemiş dize raporu
godot --headless --script res://tests/kayit_sifirla.gd # bot kirliliğini temizle
```
