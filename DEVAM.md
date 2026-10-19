# Buradan devam et

Oturum kapanıp açıldığında ilk okunacak dosya. Uzun anlatım README.md'de.

## 1. Oturumu DOĞRU klasörde aç

```
D:\Repolar\kor
```

**Önemli:** `godot-mcp` bu klasörün **proje kapsamına** kayıtlı
(`~/.claude.json` → `projects["D:/Repolar/kor"].mcpServers`). Oturumu
`D:\Claude Projeleri`'nden açarsan godot-mcp araçları görünmez. Kontrol:

```
claude mcp list        # kor klasöründen çalıştır, "godot-mcp ... Connected" görmelisin
```

Editör eklentisi `addons/godot_mcp/` altına kopyalandı ama **etkinleştirilmedi**.
Godot'da: Project → Project Settings → Plugins → godot_mcp → Enable.
Ondan sonra 21 araç açılıyor (oyun saatini dondurup ilerletme, gerçek girdi
enjeksiyonu, canlı durum JSON'u, çalışan oyunda GDScript, profil).

## 2. Durumu 30 saniyede doğrula

```
git log --oneline -3
git status --short                                    # temiz olmalı
godot --headless --script res://tests/test_isi.gd     # test_isi: TAMAM
godot --headless --script res://tests/test_dongu.gd   # test_dongu: TAMAM
```

İkisi de TAMAM diyorsa hiçbir şey bozulmamış. Oynamak için:
`build\windows\kor.exe`

Görsel bir şey değiştirdiysen ekrana **bak**, tahmin etme:

```
godot --script res://tests/ekran_al.gd     # D:\Claude Projeleri\gecici\kor-ekran.png
```

## 3. `_gelen/` kutusu — 3/5 bağlandı

Yan araştırma oturumu hazırladı, ben bağladım. Durum:

- [x] **zemin paleti** — bağlandı, `modulate` 0.50'ye ayarlandı
- [x] **font** — bağlandı, boyutlar 8'in katına çekildi, yerleşim düzeltildi
- [x] **ses** — 12 dosya + `SesYonetici` autoload, bütün olaylar bağlı
- [ ] `arac/palet-uygula.mjs` — dışarıdan gelen görseli palete oturtmak için,
      şimdilik gerek olmadı
- [ ] `addons/godot_mcp` — kopyalandı, **etkinleştirilmedi** (bkz. bölüm 1)

Tam talimat `_gelen/OKU.md`. Eski özet:

1. **Zemin paleti** (tek satır, en yüksek etkili değişiklik). Ölçüm: arenanın
   zemini oyuncunun ısı rampasıyla aynı sıcak renk ailesinden, bu yüzden
   "karanlık dökümhanede tek sıcak şey sensin" kimliği çalışmıyor.
   `cp _gelen/zemin/karolar-kul.png assets/sprites/karolar.png`
   Sonra `ekran_al.gd` ile **bak**. Düşman sprite'larına dokunma, onlar doğru.
2. **Font** — `PublicPixel.ttf` (CC0, 8×8, Türkçe ÇĞİÖŞÜ test edilmiş).
   `assets/fonts/` altına kopyala, Label'lara ver, boyut 8'in katı olsun
   (ara boyutlarda pixel font bulanır). HUD şu an varsayılan fontla çiziliyor.
3. **Ses** — 11 efekt + 10 sn fon müziği + `ses_yonetici.gd` (16 oynatıcılık
   havuz, ses başına bekleme, perde sapması; 50 eşzamanlı istekten 1'i çalıyor).
   `assets/ses/` altına kopyala, `SesYonetici` adıyla autoload yap, sonra
   çağrıları bağla. Olay adları OKU.md'de.

Bittiğinde `_gelen/` klasörünü sil. `.gitignore`'da, commit edilmiyor.

## 4. Dokunulmayacak karar

**Dalış, aşırı ısınma kilidini kırmaz.** Sadece kilitlenmeden önce ısıyı
boşaltır. Oyunun bütün gerilimi bu kuralda; "dalış her şeyi sıfırlasın"
diye basitleştirmek oyunu düzleştirir. Aynı şekilde kor atışı ısıyı
*harcar* — ısı hem tehdit hem kaynak, ikisi birden.

## 5. Ölçülmüş performans sınırları (bu makinede, 60 FPS = 16,67 ms)

Tasarım kararı verirken bunlara bak, tahmin etme:

- 2000 Sprite2D → 2,55 ms. **Çizim darboğaz değil.**
- 2000 Sprite2D + Area2D → 12,49 ms, ve doğrusal değil. **Darboğaz burada.**
- Düşman↔oyuncu teması: `distance_squared_to` Area2D'den **3,75 kat ucuz**.
  (Kod zaten böyle yapıyor, bozma.)
- Mermi↔düşman'da **tersi**: 400×300 için Area2D 1,90 ms, elle GDScript
  4,57 ms. Çoktan-çoğa işi fizik motoruna bırak. (Kod zaten böyle.)
- 4000 GPU parçacığı → 0,42 ms. **Atmosfer bedava**, cömert ol.
- 60 PointLight2D → 1,48 ms, ama `shadow_enabled` açılırsa 18,49 ms.
  **Işık serbest, gölge yasak.**
- GL Compatibility'de 2B glow çalışıyor ama `hdr_2d` kapalı: `modulate` ile
  1.0 üstüne çıkmak bloom vermez, beyaza kırpar.

Ayrıntı: `D:\Claude Projeleri\raporlar\2026-09-14-kor-teknik-bulgular.md`

## 6. Sıradaki iş

- [x] arena, siperler, XP küpü + mıknatıs, ikonlu kartlar
- [x] kor atışı (sağ tık): biriken ısıyı hasara çevirir
- [x] dört silah + Q ile geçiş, silah kartları
- [x] altı düşman türü (menzilli cadı dahil)
- [x] oyun hissi katmanı (`scripts/hiss.gd`): sarsıntı, donma, itme, parçacık
- [x] görsel: vinyet, mangal ışık havuzları, zemin lekeleri, mermi haleleri
- [x] 8 yönlü oyuncu + yürüyüş animasyonu, altı düşmanın yürüyüş döngüsü
- [x] `_gelen/` kutusu: zemin paleti, pixel font, ses
- [x] **eksik sesler** — beşi de üretilip bağlandı (`araclar/ses/eksik-sesler.mjs`):
      oyuncu_hasar, oyun_bitti, patron_uyandi, soguk_dalga, kosu_bitti
- [x] **katmanlı müzik** — `muzik_ocak` her zaman, `muzik_kor` ısıyla açılıyor;
      döngü 10 sn → 40 sn
- [x] **web ses yolu** — `default_playback_type.web=2`; Sample yolunda perde
      sapması, ses kaydıracı ve döngü sessizce bozuluyordu
- [x] **web derlemesi tarayıcıda doğrulandı** — crossOriginIsolated, konsol temiz
- [ ] **web'de tam koşu denenmedi** — sadece menü açılışı görüldü; 12 dakikalık
      koşu tarayıcıda baştan sona oynanmadı
- [ ] font: büyük Türkçe harfler küçük yükseklikte — peer daha iyi bir
      CC0 pixel fontu arıyor, gelirse `_gelen/font2/` altında olacak
- [ ] patron — çekirdek mekaniği sınayan bir tasarım
- [ ] dalga temposu dengesi

## 7. Kota ve varlık kuralı

- PixelLab: **21/40 generation kaldı.** Üretmeden önce `get_balance`.
  Gerçek fiyatlar (eski "20-40" bilgisi YANLIŞ):
  `create_character` mode=v3 + referans görsel = **1 gen** (8 yön),
  `animate_character` mode=template = **yön başına 1 gen**,
  `animate_image` (küçük sprite, 8 kare) = **1 gen**,
  `create_image_pixen` = 1 gen. Pahalı olan sadece mode="pro" (20-40).
  Referans görsel en az 32×32 olmalı — küçükse şeffaf dolguyla tamamla,
  ölçekleyip bulanıklaştırma. Aynı anda en fazla **8 iş** kuyrukta;
  fazlasını `animation_group_id` ile aynı gruba sonradan ekle.
- Bedava yol: `D:\Claude Projeleri\araclar\kenney\` (CC0).
- Yeni düşman sprite'ı eklersen **kül fraksiyonu paletine** çek
  (gri-camgöbeği). Oyuncu tek sıcak nesne kalmalı. Ham kopyalar
  `assets/sprites/_ham/`.
