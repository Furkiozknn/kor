extends RefCounted
## Silah tablosu. Hepsi AYNI ısı sistemini kullanır -- fark, ısıyı ne hızda
## biriktirdikleri. Silah seçmek "ne kadar sürede kilitlenmeyi göze
## alıyorum" sorusunun cevabı.
##
## saniyedeki_isi = isi / aralik  ->  tavan 100 iken kaç saniyede kilit:
##   tabanca  9 / 0.14 =  64/sn  -> ~1.6 sn
##   sacma   26 / 0.50 =  52/sn  -> ~1.9 sn  (ama tek basisi cok vurur)
##   isin   4.2 / 0.05 =  84/sn  -> ~1.2 sn  (en tehlikeli, en yuksek DPS)
##   cekic   34 / 0.85 =  40/sn  -> ~2.5 sn  (en sabirli)

const LISTE := [
    {
        "ad": "KOR TABANCASI", "ikon": "tetik",
        "aralik": 0.14, "isi": 9.0, "hasar": 1.0, "adet": 1,
        "yayilma": 0.05, "hiz": 265.0, "omur": 1.1, "boy": 1.0,
        "delici": false, "geri_tepme": 26.0, "sarsinti": 0.7,
        "not": "Dengeli. Her şeyi yapar, hiçbirini en iyi yapmaz.",
    },
    {
        "ad": "SAÇMA", "ikon": "catal",
        "aralik": 0.50, "isi": 26.0, "hasar": 0.85, "adet": 6,
        "yayilma": 0.40, "hiz": 225.0, "omur": 0.42, "boy": 0.85,
        "delici": false, "geri_tepme": 95.0, "sarsinti": 2.6,
        "not": "Kısa menzil, yıkıcı. Sürünün içine girmeni ister.",
    },
    {
        "ad": "IŞIN", "ikon": "celik",
        "aralik": 0.05, "isi": 4.2, "hasar": 0.45, "adet": 1,
        "yayilma": 0.015, "hiz": 430.0, "omur": 1.0, "boy": 0.7,
        "delici": false, "geri_tepme": 8.0, "sarsinti": 0.35,
        "not": "En yüksek hasar, en hızlı kilit. Parmağını kaldırmayı öğren.",
    },
    {
        "ad": "ÇEKİÇ", "ikon": "ors",
        "aralik": 0.85, "isi": 34.0, "hasar": 5.0, "adet": 1,
        "yayilma": 0.0, "hiz": 195.0, "omur": 1.5, "boy": 2.1,
        "delici": true, "geri_tepme": 120.0, "sarsinti": 3.4,
        "not": "Delip geçer. Sabır isteyen, sırayı süpüren silah.",
    },
]

static func al(i: int) -> Dictionary:
    return LISTE[clampi(i, 0, LISTE.size() - 1)]
