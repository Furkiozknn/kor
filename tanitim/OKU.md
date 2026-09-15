# Tanıtım varlıkları — itch sayfası için

**15 Eylül 12:40'ta, `d454f92` derlemesinden yeniden üretildi.** Öncekiler
sabah 00:43'te alınmıştı, yani parıltı katmanı, yeni zemin karoları,
çekirdek imzaları, yeni HUD ve günlük koşu düğmesi **hiçbiri yoktu**.

| dosya | ne |
|---|---|
| `kapak-315x250.png` | itch kapak görseli |
| `kor-640.gif` · `kor-480.gif` | 12 fps, 100 kare, **kusursuz döngü** |
| `ilk-kare.png` | GIF'in ilk karesi (durağan önizleme) |
| `gif_cek.gd` | üretici betik |

## Kapak ölçüldü — rakip bandında

`_gelen/arac/kapsul-testi.mjs` ile, rakiplerle **aynı araçla**:

| | parlaklık | kontrast | odak |
|---|---|---|---|
| **Kor (bu kapak)** | **56** | **96** | **%48** |
| Hades | 62 | 157 | %25 |
| Brotato | 57 | 148 | %19 |
| Vampire Survivors | 52 | 141 | %20 |
| Halls of Torment | 48 | 98 | %41 |

Parlaklık VS ile Brotato arasında, kontrast HoT'un hemen altında, **odak
hepsinden yüksek**. Odağın yüksek olması Kor için doğru: görsel tek bir
sıcak havuza bakıyor, kenarları karanlık yiyor — oyunun tezi bu.

### Kırpma nasıl seçildi

Üç deneme yapıldı, ilk ikisi elendi:

1. **En parlak kare, tam kare** → 20/46/%16. Arayüz çerçevesi içeride ve
   küçük resimde gri lekeye dönüyordu.
2. **Işık havuzunun ortası** → 89/37/%33. Çok parlak, **kontrast çöktü** —
   karanlık kalmayınca Kor'a benzemiyor.
3. **Seçilen:** parlaklığı rakip bandına (56–74) sabitleyip **kontrastı
   maksimize eden** pencere. Yani kare hem ışık havuzunu hem karanlığı
   içeriyor. Arayüz bandı (üst 118 px, alt 30 px) kırpma dışında.

## GIF döngüsü

Döngü **en parlak kareden** başlıyor (k050 ölçüldü) ve palindrom:
`k050 → k000 → k049`. İki iş birden:

1. Durağan önizleme **aydınlık** kare oluyor — karanlıkla başlasa çoğu
   yerde siyah dikdörtgen görünürdü.
2. Isı düşünce karanlık kapanıyor, yükselince açılıyor — **mekaniği tek
   harekette, metinsiz** anlatıyor.

`ffmpeg` `palettegen`/`paletteuse` ile `dither=none` ve `flags=neighbor`:
piksel sanatı bulanmıyor, renk bandı oluşmuyor.

## Not

`tanitim/` dışa aktarım filtresinde — bu dosyalar **oyunun paketine
girmiyor**, yalnızca depoda duruyor.
