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
3 karttan biri. Süre geçtikçe dalgalar sıklaşır ve düşmanlar sertleşir.
Üç düşman türü: **kül** (standart), **imp** (hızlı, zayıf),
**cüruf** (iri, yavaş, sert — 3 XP).

## Çalıştırma

```
godot --path .                      # editörde aç
build/windows/kor.exe               # derlenmiş sürüm
```

Testler (ikisi de headless, saniyeler sürer):

```
godot --headless --script res://tests/test_isi.gd     # ısı/kilit/dalış kuralları
godot --headless --script res://tests/test_dongu.gd   # spawn -> hasar -> küp -> XP -> kart
godot --script res://tests/ekran_al.gd                # gerçek render'ı PNG'ye yazar
```

## Dosya haritası

| Dosya | İşi |
|---|---|
| `scripts/isi.gd` | çekirdek mekanik, saf mantık — oyundan bağımsız test edilir |
| `scripts/oyuncu.gd` | hareket, nişan, ateş, dalış, hasar |
| `scripts/dusman.gd` | takip + temas hasarı, üç tür tek sahnede |
| `scripts/mermi.gd` | mermi uçuşu ve çarpışma |
| `scripts/kup.gd` | XP küpü + mıknatıs |
| `scripts/ana.gd` | dalga spawn'ı, XP/seviye, kart ekranı, HUD, ölüm |
| `assets/sprites/` | PixelLab ile üretilen pixel art |

## Durum

Oynanabilir dikey dilim. Tek arena, tek silah, dokuz kart.

Sırada: yürüme animasyonu ve 8 yönlü sprite, zemin karolarının dökümhane
kimliğine çekilmesi, ikinci silah, ses.

## Görsel kimlik

Sıcak ve soğuk. Oyuncu tek sıcak şey: karanlık dökümhanede ateş eden,
altında kor halkası taşıyan bir figür. Düşmanlar kül grisi, çekirdekleri
soğuk camgöbeği. Isın yükseldikçe halkan büyür ve beyazlaşır — ısı
göstergesine bakmadan da nerede olduğunu görürsün.
