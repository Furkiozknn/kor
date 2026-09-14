extends RefCounted
## Kor'un cekirdek mekanigi: ates isi biriktirir, dalis bosaltir,
## tavana varirsan silah kilitlenir ve dalis seni kurtarmaz.

var tavan: float = 100.0
var atis_basina: float = 9.0
var soguma_hizi: float = 30.0
var soguma_gecikmesi: float = 0.45
var kilit_suresi: float = 2.0

var deger: float = 0.0
var kilitli: bool = false
var _kilit_kalan: float = 0.0
var _gecikme_kalan: float = 0.0

func ates_edebilir() -> bool:
    return not kilitli

## miktar > 0 verilirse o kadar isinir (silaha gore), yoksa atis_basina.
func ates_et(miktar: float = 0.0) -> void:
    if kilitli:
        return
    deger += miktar if miktar > 0.0 else atis_basina
    _gecikme_kalan = soguma_gecikmesi
    if deger >= tavan:
        deger = tavan
        kilitli = true
        _kilit_kalan = kilit_suresi

## Dalis isiyi bosaltir -- ama kilitliyken islemez. Gerilim burada:
## "bir mermi daha mi, yoksa simdi mi dalayim".
func bosalt() -> bool:
    if kilitli:
        return false
    deger = 0.0
    _gecikme_kalan = 0.0
    return true

## Isiyi hasara cevirmek icin harca. Donen deger: harcanan oran (0..1).
## Kilitliyken calismaz -- asiri isinma her seyi kapatir.
func harca(pay: float) -> float:
    if kilitli or deger <= 0.0:
        return 0.0
    var oncesi := oran()
    deger -= deger * clampf(pay, 0.0, 1.0)
    _gecikme_kalan = soguma_gecikmesi
    return oncesi - oran()

func guncelle(delta: float) -> void:
    if kilitli:
        _kilit_kalan -= delta
        deger = tavan * maxf(_kilit_kalan, 0.0) / kilit_suresi
        if _kilit_kalan <= 0.0:
            kilitli = false
            deger = 0.0
        return
    if _gecikme_kalan > 0.0:
        _gecikme_kalan -= delta
        return
    deger = maxf(deger - soguma_hizi * delta, 0.0)

func oran() -> float:
    return clampf(deger / tavan, 0.0, 1.0)
