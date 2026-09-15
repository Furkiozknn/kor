extends RefCounted
## Silah tablosu. Hepsi AYNI ısı sistemini kullanır -- fark, ısıyı ne hızda
## biriktirdikleri. Silah seçmek "ne kadar sürede kilitlenmeyi göze
## alıyorum" sorusunun cevabı.
##
## saniyedeki_isi = isi / aralik  ->  tavan 100 iken kaç saniyede kilit:
##   tabanca 4.7 / 0.14 = 33.6/sn -> ~3.0 sn
##   sacma  13.5 / 0.50 = 27.0/sn -> ~3.7 sn  (ama tek basisi cok vurur)
##   isin    2.2 / 0.05 = 44.0/sn -> ~2.3 sn  (en tehlikeli, en yuksek DPS)
##   cekic  17.6 / 0.85 = 20.7/sn -> ~4.8 sn  (en sabirli)
##
## DEGERLER YARIYA INDIRILDI (onceden 1,2-2,5 sn). Gerekce: kilide varmak
## 1,6 saniye surdugunde "isiyi tut mu harca mi" bir KARAR degil, bir
## refleks oluyordu; oyuncunun dusunecek zamani yoktu ve tavan surekli
## kazayla vuruluyordu. Sogumayi da orantili yavaslattik (isi.gd), yani
## denge noktasi ayni kaldi -- sadece her sey nefes alacak hiza indi.

const LISTE := [
    {
        "ad": "KOR TABANCASI", "ikon": "tetik",
        "aralik": 0.14, "isi": 4.7, "hasar": 1.0, "adet": 1,
        "yayilma": 0.05, "hiz": 265.0, "omur": 1.1, "boy": 1.0,
        "delici": false, "geri_tepme": 26.0, "sarsinti": 0.7,
        "not": "Dengeli. Her şeyi yapar, hiçbirini en iyi yapmaz.",
    },
    {
        "ad": "SAÇMA", "ikon": "catal",
        "aralik": 0.50, "isi": 13.5, "hasar": 0.85, "adet": 6,
        "yayilma": 0.40, "hiz": 225.0, "omur": 0.42, "boy": 0.85,
        "delici": false, "geri_tepme": 95.0, "sarsinti": 2.6,
        "not": "Kısa menzil, yıkıcı. Sürünün içine girmeni ister.",
    },
    {
        "ad": "IŞIN", "ikon": "celik",
        "aralik": 0.05, "isi": 2.2, "hasar": 0.45, "adet": 1,
        "yayilma": 0.015, "hiz": 430.0, "omur": 1.0, "boy": 0.7,
        "delici": false, "geri_tepme": 8.0, "sarsinti": 0.35,
        "not": "En yüksek hasar, en hızlı kilit. Parmağını kaldırmayı öğren.",
    },
    {
        "ad": "ÇEKİÇ", "ikon": "ors",
        "aralik": 0.85, "isi": 17.6, "hasar": 5.0, "adet": 1,
        "yayilma": 0.0, "hiz": 195.0, "omur": 1.5, "boy": 2.1,
        "delici": true, "geri_tepme": 120.0, "sarsinti": 3.4,
        "not": "Delip geçer. Sabır isteyen, sırayı süpüren silah.",
    },
]

## Silahin isi profili, KART UZERINDE gosterilmek uzere.
##
## Turun tekrar eden elestirisi "bilincli karar verecek kadar bilgi yok".
## Kor'da silah secmek dogrudan "kac saniyede kilitlenmeyi goze aliyorum"
## sorusu -- bu sayiyi gizlemek oyuncuyu korlemek demek.
static func isi_profili(i: int, tavan: float = 100.0) -> String:
    var s := al(i)
    var sn_isi: float = float(s["isi"]) / float(s["aralik"])
    return "%.0f ısı/sn · ~%.1f sn'de kilit" % [sn_isi, tavan / sn_isi]

static func al(i: int) -> Dictionary:
    return LISTE[clampi(i, 0, LISTE.size() - 1)]


## --- DAMGA: silaha KALICI yapisan ozellikler ---------------------------
##
## Turde alisilmis kalip "gecici guclendirme" -- 20 saniye surer, biter,
## unutulur. Kor'da tersi: bir damga vurdugun silahta KOSU BOYUNCA kalir.
##
## Bunun tasarim sonucu su: damgalar SILAHA baglandigi icin silah degistirmek
## bedava olmaktan cikiyor. Cekicine uc damga vurduysan Q'ya basmak artik
## "baska bir namlu" degil, "biriktirdigin her seyi geride birakmak" demek.
## Boylece oyuncu kosu ortasinda bir KIMLIK seciyor.
##
## Silah basina en fazla UC damga. Sinir olmasa her silah her seyi alir ve
## secim diye bir sey kalmaz.
const DAMGA_TAVANI := 3

const DAMGALAR := {
    "delici": {
        "ad": "DELİCİ", "ikon": "celik",
        "not": "Mermiler düşmanı delip geçer",
    },
    "catal": {
        "ad": "ÇATAL", "ikon": "catal",
        "not": "+1 mermi, yayılma biraz artar",
    },
    "soguk_namlu": {
        "ad": "SOĞUK NAMLU", "ikon": "soguk",
        "not": "Bu silahın ısısı -%35",
    },
    "agir_dokum": {
        "ad": "AĞIR DÖKÜM", "ikon": "agir",
        "not": "Hasar +%40, mermi hızı -%20",
    },
    "uzun_namlu": {
        "ad": "UZUN NAMLU", "ikon": "tetik",
        "not": "Menzil +%55, yayılma -%40",
    },
    "kor_izi": {
        "ad": "KOR İZİ", "ikon": "kor",
        "not": "Vuruş küçük bir kor patlaması bırakır",
    },
}

static func damga(anahtar: String) -> Dictionary:
    return DAMGALAR.get(anahtar, {})

## Silahin temel degerlerine damgalari uygular. Cagiran tarafta dallanma
## olmasin diye tek yerde toplandi; yeni damga eklemek bir satir.
static func damgali(i: int, anahtarlar: Array) -> Dictionary:
    var s := al(i).duplicate()
    for a in anahtarlar:
        match str(a):
            "delici":
                s["delici"] = true
            "catal":
                s["adet"] = int(s["adet"]) + 1
                s["yayilma"] = float(s["yayilma"]) + 0.10
            "soguk_namlu":
                s["isi"] = float(s["isi"]) * 0.65
            "agir_dokum":
                s["hasar"] = float(s["hasar"]) * 1.40
                s["hiz"] = float(s["hiz"]) * 0.80
            "uzun_namlu":
                s["omur"] = float(s["omur"]) * 1.55
                s["yayilma"] = float(s["yayilma"]) * 0.60
    return s
