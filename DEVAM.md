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

## 3. Dokunulmayacak karar

**Dalış, aşırı ısınma kilidini kırmaz.** Sadece kilitlenmeden önce ısıyı
boşaltır. Oyunun bütün gerilimi bu kuralda; "dalış her şeyi sıfırlasın"
diye basitleştirmek oyunu düzleştirir. Aynı şekilde kor atışı ısıyı
*harcar* — ısı hem tehdit hem kaynak, ikisi birden.

## 4. Sıradaki iş

- [x] arena, siperler, 5 düşman türü, XP küpü + mıknatıs, ikonlu kartlar
- [x] kor atışı (sağ tık): biriken ısıyı hasara çevirir
- [ ] ses — **başka bir oturumda**, `assets/ses/` + `scripts/ses.gd`
- [ ] yürüme animasyonu / 8 yönlü sprite (PixelLab `create_character`,
      20-40 generation — kotanın çoğunu yer, Furki'nin onayı gerekir)
- [x] menzilli düşman (cadı)

## 5. Kota ve varlık kuralı

- PixelLab: **36/40 generation kaldı.** Üretmeden önce `get_balance`.
  Pahalı olan `create_character` / tileset (20-40). Ucuz olan
  `create_image_pixen` (1 gen/görsel).
- Bedava yol: `D:\Claude Projeleri\araclar\kenney\` (CC0). Zemin, duvar,
  siper, kart ikonu, iskelet ve hayalet oradan geldi.
- Yeni düşman sprite'ı eklersen **kül fraksiyonu paletine** çek
  (gri-camgöbeği). Oyuncu tek sıcak nesne kalmalı. Ham kopyalar
  `assets/sprites/_ham/`.
