extends RefCounted
## Silah tablosu. Hepsi AYNI ısı sistemini kullanır -- fark, ısıyı ne hızda
## biriktirdikleri. Silah seçmek "ne kadar sürede kilitlenmeyi göze
## alıyorum" sorusunun cevabı.
##
## saniyedeki_isi = isi / aralik  ->  tavan 100 iken kaç saniyede kilit:
##   tabanca 2.5 / 0.14 = 17.9/sn -> ~5.6 sn
##   sacma   7.2 / 0.50 = 14.4/sn -> ~6.9 sn  (ama tek basisi cok vurur)
##   isin    1.2 / 0.05 = 24.0/sn -> ~4.2 sn  (en tehlikeli, en yuksek DPS)
##   cekic   9.4 / 0.85 = 11.1/sn -> ~9.0 sn  (en sabirli)
##
## DEGERLER IKI KEZ INDIRILDI. Ilk tur 1,6 -> 3,0 saniyeydi.
##
## Ikinci tur GERCEK OYUNCU VERISIYLE geldi ve olcum aracinin goremedigi
## seydi: bot dakikada 0,0-0,1 kilit yapiyor, INSAN 50 saniyede 6-9 kilit
## yapti (~7,7-9,8 kilit/dk). Sebep basit -- insan sol tusu BASILI TUTUYOR,
## bot ise hedef varken kisa kisa atiyor. 3 saniyede kilitlenen bir
## sistemde oyuncu zamanin %25-30unu kilitte geciriyordu.
##
## Artik ~5,6 sn (tabanca). Kilit hala var ve hala cezali, ama "her birkac
## saniyede bir" degil "dikkatsiz oynarsan" oluyor.

const LISTE := [
    {
        "ad": "KOR TABANCASI", "ikon": "tetik",
        "aralik": 0.14, "isi": 2.5, "hasar": 1.0, "adet": 1,
        "yayilma": 0.05, "hiz": 265.0, "omur": 1.1, "boy": 1.0,
        "delici": false, "geri_tepme": 26.0, "sarsinti": 0.7,
        "not": "Dengeli. Her şeyi yapar, hiçbirini en iyi yapmaz.",
    },
    {
        "ad": "SAÇMA", "ikon": "catal",
        "aralik": 0.50, "isi": 7.2, "hasar": 0.85, "adet": 6,
        "yayilma": 0.40, "hiz": 225.0, "omur": 0.42, "boy": 0.85,
        "delici": false, "geri_tepme": 95.0, "sarsinti": 2.6,
        "not": "Kısa menzil, yıkıcı. Sürünün içine girmeni ister.",
    },
    {
        "ad": "IŞIN", "ikon": "celik",
        "aralik": 0.05, "isi": 1.2, "hasar": 0.45, "adet": 1,
        "yayilma": 0.015, "hiz": 430.0, "omur": 1.0, "boy": 0.7,
        "delici": false, "geri_tepme": 8.0, "sarsinti": 0.35,
        "not": "En yüksek hasar, en hızlı kilit. Parmağını kaldırmayı öğren.",
    },
    {
        "ad": "ÇEKİÇ", "ikon": "ors",
        "aralik": 0.85, "isi": 9.4, "hasar": 5.0, "adet": 1,
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
##
## The lock time used to be tavan / (heat per second), which ignores cooling
## between shots. That is close for fast weapons (the cooling delay never runs
## out between shots) but wrong for slow ones: with the base cooling the
## hammer cools more between swings than a swing heats, so holding fire never
## locks it, while the card promised "~9 s". The number now comes from
## kilit_suresi(), the same heat rules the game runs, with the player's
## current ceiling, cooling and fire-rate modifiers.
static func isi_profili(i: int, tavan: float = 100.0, soguma: float = 19.0,
        isi_carpani: float = 1.0, atis_hizi: float = 1.0) -> String:
    var s := al(i)
    var sn_isi: float = float(s["isi"]) * isi_carpani / etkin_aralik(float(s["aralik"]) / atis_hizi)
    var t := kilit_suresi(i, [], tavan, soguma, isi_carpani, atis_hizi)
    # tr() ORNEK metodu, bu fonksiyon static -- TranslationServer static-guvenli.
    # (tr() denendi: "Cannot call non-static function" ile derlenmedi.)
    if t < 0.0:
        return TranslationServer.translate("%.0f ısı/sn · basılı tutunca kilitlenmez") % sn_isi
    return TranslationServer.translate("%.0f ısı/sn · ~%.1f sn'de kilit") % [sn_isi, t]

const Isi := preload("res://scripts/isi.gd")
const FIZIK_ADIMI := 1.0 / 60.0
const KILIT_YOK := -1.0

## The real time between shots. The shot timer is counted down once per
## physics tick, so an interval is rounded UP to whole ticks: the beam's 0.05 s
## is 4 ticks (0.067 s) once float rounding leaves a sliver above zero, so it
## heats 18/s, not the nominal 24/s.
static func etkin_aralik(aralik: float) -> float:
    var sayac := aralik
    var n := 0
    while true:
        sayac = maxf(sayac - FIZIK_ADIMI, 0.0)
        n += 1
        if sayac <= 0.0:
            break
    return n * FIZIK_ADIMI

## Seconds of HOLDING fire from cold until weapon `i` locks, simulated with the
## real heat rules (Isi: cooling delay, cooling between shots) at the physics
## tick, in the order oyuncu._physics_process uses: cool, count down the shot
## timer, fire. KILIT_YOK if it does not lock within `ust_sinir` seconds, i.e.
## the cooling between shots keeps up with the heat per shot.
##
## No telemetry, no bot: a deterministic number the card, the README table and
## tests/test_denge_kurallari.gd all read from the same place.
static func kilit_suresi(i: int, damgalar: Array = [], tavan: float = 100.0,
        soguma: float = 19.0, isi_carpani: float = 1.0, atis_hizi: float = 1.0,
        ust_sinir: float = 30.0) -> float:
    var s := damgali(i, damgalar)
    var isi = Isi.new()
    isi.tavan = tavan
    isi.soguma_hizi = soguma
    var aralik: float = float(s["aralik"]) / atis_hizi
    var miktar: float = float(s["isi"]) * isi_carpani
    var sayac := 0.0
    var t := 0.0
    while t < ust_sinir:
        isi.guncelle(FIZIK_ADIMI)
        sayac = maxf(sayac - FIZIK_ADIMI, 0.0)
        if sayac <= 0.0 and isi.ates_edebilir():
            isi.ates_et(miktar)
            sayac = aralik
            if isi.kilitli:
                return t
        t += FIZIK_ADIMI
    return KILIT_YOK

## Highest heat ratio (0..1) reached while holding fire for `sure` seconds.
## For a weapon that never locks this is where it settles: how close to the
## ceiling holding the trigger brings you.
static func basili_tepe(i: int, damgalar: Array = [], tavan: float = 100.0,
        soguma: float = 19.0, sure: float = 30.0) -> float:
    var s := damgali(i, damgalar)
    var isi = Isi.new()
    isi.tavan = tavan
    isi.soguma_hizi = soguma
    var sayac := 0.0
    var t := 0.0
    var tepe := 0.0
    while t < sure:
        isi.guncelle(FIZIK_ADIMI)
        sayac = maxf(sayac - FIZIK_ADIMI, 0.0)
        if sayac <= 0.0 and isi.ates_edebilir():
            isi.ates_et(float(s["isi"]))
            sayac = float(s["aralik"])
        tepe = maxf(tepe, isi.oran())
        t += FIZIK_ADIMI
    return tepe

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
## Damgalarin CARPMA cinsinden olanlari. Toplamalardan SONRA uygulanmali:
## "catal" yayilmaya +0,10 ekliyor, "uzun_namlu" ×0,60 carpiyor -- alinma
## sirasina birakilirsa ayni iki damga 0,090 ya da 0,130 yayilma uretiyor,
## yani %44 fark, ve oyuncu bunu goremiyor.
const CARPAN_DAMGALAR := ["soguk_namlu", "agir_dokum", "uzun_namlu"]

static func damgali(i: int, anahtarlar: Array) -> Dictionary:
    var s := al(i).duplicate()
    var sirali: Array = []
    for a in anahtarlar:
        if not str(a) in CARPAN_DAMGALAR:
            sirali.append(a)
    for a in anahtarlar:
        if str(a) in CARPAN_DAMGALAR:
            sirali.append(a)
    for a in sirali:
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
