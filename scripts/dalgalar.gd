extends RefCounted
## Dalga yönetmeni — koşunun şekli.
##
## Önceden tek formül vardı: `spawn = max(2.30 - t*0.0035, 0.55)`. Düz bir
## rampa. Araştırmanın en net bulgusu buydu: **türün en çok eleştirilen yanı
## sürekli aynı basınç.** VS'in kendi geliştirme notunda bile 4. dakikadaki
## sıçramayı yumuşatmak zorunda kaldıkları yazıyor.
##
## Bu yüzden koşu artık bir eğri değil, **bir şekil**: ısınma → basınç →
## **nefes** → daha sert basınç → final. Nefes anları iki iş yapıyor:
## zirveleri hissettiriyor, ve oyuncuya kart okuyacak/ısı toplayacak alan
## açıyor.
##
## Koşu 12 dakika. Gerekçe: Kor'da her saniye bir ısı kararı var, 30 dakika
## yorar; ayrıca tarayıcıda tek oturumda bitmesi gerekiyor.

const KOSU_SURESI := 720.0     # 12:00 -- kazanma anı

## Her evre: başlangıç saniyesi, spawn aralığı, canlı düşman tavanı,
## o evrede doğabilecek türler, ve ekranda gösterilecek ad.
##
## `turler` bir AĞIRLIK listesidir: tekrar eden girdi daha sık çıkar.
## Tehlikeli türler (koşucu, cüruf, cadı) listede bir kez, doldurucu türler
## (kül, imp) birkaç kez geçer. Ölçüldü: eşit ağırlıkta koşucu koymak
## hayatta kalmayı 540 -> 276 sn'ye düşürüyordu.
const EVRELER := [
    {"sn":   0.0, "spawn": 2.20, "tavan":  30, "turler": [0],
        "ad": "kül"},
    {"sn": 100.0, "spawn": 1.45, "tavan":  55, "turler": [0, 1],
        "ad": "sürü kalabalıklaşıyor"},
    {"sn": 190.0, "spawn": 1.15, "tavan":  75, "turler": [0, 0, 0, 1, 1, 3, 6],
        "ad": "koşucular"},
    {"sn": 285.0, "spawn": 0.62, "tavan": 115, "turler": [0, 0, 0, 1, 1, 3, 3, 2, 6],
        "ad": "İLK BASKI", "baski": true},
    {"sn": 345.0, "spawn": 2.60, "tavan":  38, "turler": [0, 1],
        "ad": "nefes", "nefes": true},
    {"sn": 368.0, "spawn": 1.00, "tavan":  92, "turler": [0, 0, 0, 1, 1, 3, 3, 2, 4, 6],
        "ad": "hayaletler"},
    {"sn": 470.0, "spawn": 0.86, "tavan": 110, "turler": [0, 0, 0, 1, 1, 1, 3, 3, 2, 4, 5, 6],
        "ad": "cadılar"},
    {"sn": 560.0, "spawn": 2.40, "tavan":  45, "turler": [0, 1, 5],
        "ad": "nefes", "nefes": true},
    {"sn": 584.0, "spawn": 0.70, "tavan": 140, "turler": [0, 0, 0, 1, 1, 1, 3, 3, 2, 4, 5, 6],
        "ad": "dökümhane uyanıyor"},
    {"sn": 660.0, "spawn": 0.50, "tavan": 175, "turler": [0, 0, 0, 1, 1, 1, 3, 3, 2, 4, 5, 6],
        "ad": "FİNAL", "baski": true},
]

## Patronlar. Nefes anlarına denk getirilmiyor -- nefes gerçekten nefes olsun.
const PATRON_ZAMANLARI := [150.0, 400.0, 690.0]

static func evre_indeksi(gecen: float) -> int:
    var i := 0
    for n in EVRELER.size():
        if gecen >= float(EVRELER[n]["sn"]):
            i = n
    return i

static func evre(gecen: float) -> Dictionary:
    return EVRELER[evre_indeksi(gecen)]

## Evre içinde yumuşak geçiş: eşikte ani sıçrama olmasın diye spawn aralığı
## ve tavan bir sonraki evreye doğru enterpole ediliyor. (Araştırma:
## "eğri düz olmalı, uçurum olmamalı.")
static func spawn_araligi(gecen: float) -> float:
    var i := evre_indeksi(gecen)
    var su: Dictionary = EVRELER[i]
    if i + 1 >= EVRELER.size():
        return float(su["spawn"])
    var sonraki: Dictionary = EVRELER[i + 1]
    var t := inverse_lerp(float(su["sn"]), float(sonraki["sn"]), gecen)
    # Nefes ve baskı evrelerinde geçiş keskin olsun: his net olmalı
    if su.get("nefes", false) or su.get("baski", false):
        t = smoothstep(0.55, 1.0, t)
    return lerpf(float(su["spawn"]), float(sonraki["spawn"]), clampf(t, 0.0, 1.0))

static func canli_tavan(gecen: float) -> int:
    var i := evre_indeksi(gecen)
    var su: Dictionary = EVRELER[i]
    if i + 1 >= EVRELER.size():
        return int(su["tavan"])
    var sonraki: Dictionary = EVRELER[i + 1]
    var t := inverse_lerp(float(su["sn"]), float(sonraki["sn"]), gecen)
    return int(lerpf(float(su["tavan"]), float(sonraki["tavan"]), clampf(t, 0.0, 1.0)))

## O anda doğabilecek türlerden biri.
static func tur_sec(gecen: float) -> int:
    var turler: Array = evre(gecen)["turler"]
    return int(turler[randi() % turler.size()])

## Düşman gücü. Süreye göre doğrusal; 12 dakikada ~2,4 kat.
static func guc(gecen: float) -> float:
    return 1.0 + gecen / 510.0
