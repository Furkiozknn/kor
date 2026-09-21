# Tanıtım varlıkları — itch sayfası için

**21 Eylül 07:1x'te, `343bd49` derlemesinden yeniden üretildi.** Öncekiler
15 Eylül 12:40'ta alınmıştı; sonrasında tema, menü ve dil dosyaları
değişti (`58aef31`, `f227c41`, `343bd49` — "ısı yavaşlatıldı, ana ekran
sadeleştirildi"), yani eski varlıklar **yayındaki oyunu göstermiyordu**.

| dosya | ne |
|---|---|
| `kapak-315x250.png` | itch kapak görseli |
| `kor-640.gif` · `kor-480.gif` | 12 fps, 90 kare, **kusursuz döngü** |
| `ilk-kare.png` | GIF'in ilk karesi (durağan önizleme) |
| `gif_cek.gd` | üretici betik |

## Kapak ölçüldü — rakip bandında

`_gelen/arac/kapsul-testi.mjs` ile, rakiplerle **aynı araçla**:

| | parlaklık | kontrast | odak |
|---|---|---|---|
| **Kor (bu kapak)** | **66** | **104** | **%43** |
| Hades | 62 | 157 | %25 |
| Brotato | 57 | 148 | %19 |
| Vampire Survivors | 52 | 141 | %20 |
| Halls of Torment | 48 | 98 | %41 |

Parlaklık Hades'in hemen üstünde, kontrast **rakip eşiğinin (98) üstünde**
— önceki kapak 96 ile eşiğin altında kalıyordu. Odak HoT'unkine yakın.
Odağın yüksek olması Kor için doğru: görsel birkaç sıcak havuza bakıyor,
kenarları karanlık yiyor — oyunun tezi bu.

### Kırpma nasıl seçildi

**Aynı tuzağa iki kez düşüldü.** 15 Eylül'de "ışık havuzunun ortası"
denemesi 89/37 ile elenmişti; 21 Eylül'deki ilk yeniden çekimde ortadan
kırpılan kare yine **85/66** verdi — parlaklık bandın üstünde, kontrast
eşiğin altında. Ders: ışık havuzunu ortalama, **karanlığı kadraja al**.

Bu sefer tahmin edilmedi. Dört kare × üç pencere aynı araçla ölçüldü:

| aday | parlaklık | kontrast | odak |
|---|---|---|---|
| k010 sol | 24 | 95 | %94 |
| k030 orta | 47 | 102 | %27 |
| **k030 sol** | **66** | **104** | **%43** |
| k050 orta | 75 | 104 | %33 |
| k075 orta (ilk deneme) | 85 | 66 | %38 |
| k075 sol | 50 | 98 | %66 |

Seçilen **k030 sol** (`crop=315x250+162+70`): parlaklığı 48–74 bandında
kalan **ve kontrastı en yüksek** tek aday. Ölçeklenmiyor — 315x250 birebir
kırpım, piksel sanatı yeniden örneklenmiyor. Arayüz bandı (üst 118 px,
alt 30 px) kırpma dışında.

## GIF döngüsü

Döngü **en parlak kareden** başlıyor (ısı rampasının tepesi, k090) ve
palindrom: `k090 → k000 → k088`, iki karede bir örneklenerek 90 kare.
İki iş birden:

1. Durağan önizleme **aydınlık** kare oluyor — karanlıkla başlasa çoğu
   yerde siyah dikdörtgen görünürdü.
2. Isı düşünce karanlık kapanıyor, yükselince açılıyor — **mekaniği tek
   harekette, metinsiz** anlatıyor.

`ffmpeg` `palettegen`/`paletteuse` ile `dither=none`, `flags=neighbor` ve
`max_colors=64`: piksel sanatı bulanmıyor, renk bandı oluşmuyor, 640'lık
dosya 3 MB sınırının altında kalıyor (2,95 MB).

## Yakalama betiği neden değişti

Eski `gif_cek.gd` oyuncuya **hiç girdi vermiyordu** — sadece ısıyı ramp
edip kare yazıyordu. 15 Eylül'de bu yeterliydi; `8ea08c5` (zorluk eğrisi)
ve `343bd49` (ısı yavaşlatıldı) sonrasında ilk saniyeler boşaldı ve
yeniden çekim **hareketsiz, öğretici yazısı ekranda duran** bir kare
dizisi üretti (00:06, düşman yok).

Betik artık `tests/denge.gd`'yi genişletiyor: orada zaten **gerçek oyunu
oynayan** bot politikası var (`bot_aktif`, `_politika()`, kart seçimi).
Bot 120 oyun saniyesi normal oynuyor — arena doluyor, seviye atlanıyor,
öğretici yazısı gidiyor — sonra ısı rampası uygulanıyor. Sonuç: 02:05,
sv7, 176 öldürme, ekranda dört düşman, oyuncu ateş ediyor.

Politika kopyalanmadı, miras alındı: denge ayarı değişince tanıtım
çekimi de kendiliğinden güncel kalıyor.

## Not

`tanitim/` dışa aktarım filtresinde — bu dosyalar **oyunun paketine
girmiyor**, yalnızca depoda duruyor.
