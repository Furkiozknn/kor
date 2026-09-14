# Kor

Top-down roguelite. *Vampire Survivors*'ın sürüsü ile *Enter the Gungeon*'ın
el becerisini tek bir düğmede birleştiriyor: **ateş etmek ısı biriktirir.**

## Çekirdek mekanik: ısı ve dalış

```
  ateş et  →  ısı ↑ ↑ ↑  →  KİLİT (2 sn savunmasız)
                 ↓
              DALIŞ  →  ısı = 0, dokunulmazlık
```

Silahın ısınır. Tavana varırsan iki saniye boyunca ateş edemezsin — ve
**dalış seni o kilitten kurtarmaz.** Yani dalış hem kaçınma hem yeniden
yükleme: sürünün içine zamanında dalarsan ısın sıfırlanır, geç kalırsan
sürünün ortasında kilitli kalırsın. Oyunun bütün gerilimi şu tek soruda:
*bir mermi daha mı, yoksa şimdi mi dalayım?*

Kartlar bu ikilemi büker — ısı tavanını büyütmek, soğumayı hızlandırmak,
ya da tam tersi: ısı yüksekken hasar veren "kızgın çelik" ile kilidin
kenarında oynamayı ödüllendirmek.

## Kontroller

| Tuş | İş |
|---|---|
| `WASD` / yön tuşları | hareket |
| Sol tık (basılı) | ateş — fareye nişan alır |
| `Boşluk` | dalış (ısıyı boşaltır, dokunulmazlık verir) |
| `R` | öldükten sonra yeniden başla |

## Koşu döngüsü

Düşman öl → XP küpü düşer → mıknatıs menzilinde sana akar → seviye →
3 karttan biri. Süre geçtikçe dalgalar sıklaşır, düşmanlar sertleşir ve
yeni türler devreye girer.

### Düşmanlar

| Tür | Ne yapar | Ne zaman |
|---|---|---|
| **kül** | standart takip | baştan |
| **imp** | hızlı, zayıf | 15. saniye |
| **iskelet** | dengeli ama sert, 2 XP | 30. saniye |
| **cüruf** | iri, yavaş, 2 hasar, 3 XP | 45. saniye |
| **hayalet** | **duvar ve siper tanımaz**, hızlı, 2 XP | 60. saniye |

Hayalet oyunun siper mantığını bozmak için var: bir köşeye yerleşip
sürüyü fıçıların arkasında tutmak 60. saniyeden sonra işe yaramaz.

### Arena ve siperler

Arena her koşuda yeniden kuruluyor: 40×22 karo zemin, çevresi çarpışmalı
duvar, içine 14 siper serpiliyor. **Fıçı, sandık ve fıçı yığını kırılabilir**
— ateş hattını sen açarsın, kırınca XP düşer. **Örs ve mangal kalıcı**:
mermiyi de sürüyü de durdurur, ama kırılmaz.

## Çalıştırma

```
godot --path .                      # editörde aç
build/windows/kor.exe               # derlenmiş sürüm
```

Testler (ikisi de headless, saniyeler sürer):

```
godot --headless --script res://tests/test_isi.gd     # ısı/kilit/dalış kuralları
godot --headless --script res://tests/test_dongu.gd   # arena, siper, 5 tür,
                                                      # spawn -> hasar -> küp -> XP -> kart
godot --script res://tests/ekran_al.gd                # gerçek render'ı PNG'ye yazar
```

## Dosya haritası

| Dosya | İşi |
|---|---|
| `scripts/isi.gd` | çekirdek mekanik, saf mantık — oyundan bağımsız test edilir |
| `scripts/oyuncu.gd` | hareket, nişan, ateş, dalış, hasar |
| `scripts/dusman.gd` | takip + temas hasarı, beş tür tek sahnede |
| `scripts/yapi.gd` | arena siperleri, kırılabilir ve kalıcı |
| `scripts/mermi.gd` | mermi uçuşu ve çarpışma |
| `scripts/kup.gd` | XP küpü + mıknatıs |
| `scripts/ana.gd` | arena kurulumu, dalga doğurma, XP/seviye, kart ekranı, HUD |

## Görsel kimlik

Sıcak ve soğuk. Oyuncu tek sıcak şey: karanlık dökümhanede ateş eden,
altında kor halkası taşıyan bir figür. Bütün düşmanlar tek "kül fraksiyonu"
paletinde — gri-camgöbeği, soğuk. Isın yükseldikçe halkan büyür ve
beyazlaşır; ısı göstergesine bakmadan da nerede olduğunu görürsün.

## Varlıklar

- **Oyuncu ve üç düşman** — PixelLab ile üretildi (`create_image_pixen`),
  sonra tek palete çekildi. Ham hâlleri `assets/sprites/_ham/` altında.
- **Zemin, duvar, siperler, kart ikonları, iskelet ve hayalet** —
  [Kenney](https://kenney.nl) *Tiny Dungeon* (CC0), paleti oyunun
  fraksiyonuna uyacak şekilde değiştirildi.

## Durum

Oynanabilir dikey dilim. Tek arena, tek silah, on kart, beş düşman türü.

Sırada: yürüme animasyonu ve 8 yönlü sprite, ikinci silah, ses.
