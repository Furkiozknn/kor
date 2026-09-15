extends RefCounted
## Görev sistemi — içerik PARAYLA değil USTALIKLA açılır.
##
## Neden böyle: türün en nefret edilen kalıbı "yeterince yükseltme açana
## kadar 10-15 koşu boyunca güçsüz hissetmek". Para biriktirmek o kalıbı
## doğuruyor; görev doğurmuyor, çünkü görevi oynayarak geçiyorsun.
## Halls of Torment'in 6 hall'u da parayla değil görevle açılıyor.
##
## Ayrıca tekrar eden bir istek karşılanıyor: "neredeyse 400 survivors-like
## var ve iyi satanların çoğunda başarım var." itch'te Steam başarımı yok,
## bu liste onun yerini tutuyor.
##
## GitHub'da bakımlı bir Godot 4 görev eklentisi YOK (arandı: en büyüğü
## 21 yıldız ve Godot 3). Bu dosya o yüzden var — 60 satır, bağımlılık sıfır.
##
## Kullanım:
##   var g := Gorevler.new()
##   g.kosu_basla()
##   # koşu sırasında: g.olay("oldurme", {"isi": 0.82})
##   # koşu sonunda:   var acilanlar := g.kosu_bitti(sure, oldurulen, kazandi)

const LISTE := [
    {
        "kod": "arena_curuf", "ad": "SOĞUK DEMİR",
        "aciklama": "Hiç kilitlenmeden 300 saniye hayatta kal",
        "odul": "ÇEKİÇ ile başlama",
        "verir": "baslangic_cekic",
        "ilerleme": "kilitsiz_sure", "hedef": 300.0,
    },
    {
        "kod": "arena_koruk", "ad": "KÖRÜK",
        "aciklama": "Isı %80 üstündeyken 100 düşman öldür",
        "odul": "IŞIN ile başlama",
        "verir": "baslangic_isin",
        "ilerleme": "sicak_oldurme", "hedef": 100.0,
    },
    {
        "kod": "arena_sonmus", "ad": "KARANLIĞA ALIŞ",
        "aciklama": "Isı %25 altındayken 150 düşman öldür",
        "odul": "SAÇMA ile başlama",
        "verir": "baslangic_sacma",
        "ilerleme": "soguk_oldurme", "hedef": 150.0,
    },
    {
        "kod": "kademe_1", "ad": "PATRON AVCISI",
        "aciklama": "Bir patronu yen",
        "odul": "+1 kart fırına atma hakkı",
        "verir": "ek_yakma",
        "ilerleme": "patron", "hedef": 1.0,
    },
    {
        "kod": "kademe_2", "ad": "DÖKÜMHANE SÖNDÜ",
        "aciklama": "Bir koşuyu kazan",
        "odul": "DÖKÜM yarı dolu başlar",
        "verir": "dokum_onyukleme",
        "ilerleme": "zafer", "hedef": 1.0,
    },
]

## Koşu içi sayaçlar. Hepsi basit toplam — durum makinesi yok.
var _sayac := {}

func kosu_basla() -> void:
    _sayac = {"kilitsiz_sure": 0.0, "sicak_oldurme": 0.0, "soguk_oldurme": 0.0,
              "patron": 0.0, "zafer": 0.0}

## Her karede çağrılır: kilitsiz geçen süreyi biriktirir.
func guncelle(delta: float, kilitli: bool) -> void:
    if kilitli:
        _sayac["kilitsiz_sure"] = 0.0      # kilit sayacı sıfırlar — "hiç kilitlenmeden"
    else:
        _sayac["kilitsiz_sure"] += delta

## Öldürme anında çağrılır.
func oldurme(isi_orani: float) -> void:
    if isi_orani > 0.80:
        _sayac["sicak_oldurme"] += 1.0
    elif isi_orani < 0.25:
        _sayac["soguk_oldurme"] += 1.0

func patron_dustu() -> void:
    _sayac["patron"] = 1.0

func kazandi() -> void:
    _sayac["zafer"] = 1.0

## Koşu bitince çağrılır. Yeni açılanların listesini döner (duyuru için).
func kosu_bitti() -> Array:
    var yeni: Array = []
    for g in LISTE:
        if _kayit().acik(g["kod"]):
            continue
        if float(_sayac.get(g["ilerleme"], 0.0)) >= float(g["hedef"]):
            _kayit().ac(g["kod"])
            yeni.append(g)
    return yeni

## Ölüm/zafer ekranında gösterilecek ilerleme satırları.
func ozet() -> Array:
    var satirlar: Array = []
    for g in LISTE:
        var acik: bool = _kayit().acik(g["kod"])
        var su: float = float(_sayac.get(g["ilerleme"], 0.0))
        var hedef: float = float(g["hedef"])
        if acik:
            satirlar.append("✓  %s — %s" % [g["ad"], g["odul"]])
        else:
            satirlar.append("   %s — %s  (%d/%d)" % [
                g["ad"], g["aciklama"], int(min(su, hedef)), int(hedef)])
    return satirlar


## Autoload adi bu dosya --script testlerinde derlenirken tanimli
## olmayabiliyor; her zaman dugum uzerinden aliniyor.
static func _kayit() -> Node:
    return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Kayit")

## Bir kosuya baslarken gecerli olan acilmis seceneklerin listesi.
static func acik_secenekler() -> Array:
    var k := _kayit()
    var liste: Array = []
    if k == null:
        return liste
    for g in LISTE:
        if k.acik(str(g["kod"])):
            liste.append(str(g["verir"]))
    return liste
