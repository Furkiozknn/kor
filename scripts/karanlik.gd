extends CanvasLayer
## Isı = görüş.
##
## Oyunun ayrışma noktası burası. Arena karanlık; **oyuncunun ısısı tek
## başına görüş yarıçapını belirliyor.** Soğukken dar bir daire içinde
## kalıyorsun, nereye ateş ettiğini bilmiyorsun. Isındıkça arena açılıyor —
## ama aynı anda kilide yaklaşıyorsun. Dalış ısıyı boşaltır ve ekran kararır:
## güvenliği görüşle ödüyorsun.
##
## Mangallar sabit ışık adaları. Arena düzeni böylece bir karar hâline
## geliyor: sıcak kalıp geniş görmek mi, mangalın yanında soğuk ve güvende
## durmak mı.

const TAVAN := 24                 # shader'daki dizi boyu ile aynı olmalı

@export var taban_yaricap := 40.0     # ısı sıfırken görüş
@export var tavan_yaricap := 300.0    # ısı tavandayken görüş
## Kilitliyken gorus ACIK kalir -- hatta en genis halindedir.
##
## Onceden 26 piksele COKUYORDU ve bu oyunun kendi kuralini tersine
## ceviriyordu: "isi = gorus" diye ogrettigimiz sistemde en yuksek isi
## en dar gorusu veriyordu. Yeni oyuncu karanlikta ates ediyor, iki
## saniyede kilitleniyor ve odul yerine ceza aliyordu -- ogrendigi ders
## "ates etmek kor eder" oluyordu, yani tam tersi.
##
## Ceza kalkmadi, TUTARLI hale geldi: tavandayken her seyi goruyorsun ama
## hicbir sey yapamiyorsun. Ustelik en parlak halindesin, dusmanlar isiyi
## seziyor (dusman.gd _koku) ve %60 daha kirilgansin. Iki saniye boyunca
## ustune gelen suruyu seyrediyorsun. Bu daha iyi bir ceza -- cunku
## anlasiliyor.
@export var kilit_parlama := 1.12    # kilitliyken gorus carpani

var oyuncu: Node2D
var gorus_carpani := 1.0              # kart: görüş menzili

var _ekran: ColorRect
var _mat: ShaderMaterial
var _yumusak_yaricap := 0.0
## Karanligin USTUNDE cizilen katman. Perdeye ragmen gorunur.
## Olculdu: perdenin altinda karanliktaki cekirdek rgb(9,14,21),
## bos zemin rgb(3,3,8) -- yani hic gorunmuyordu.
var parilti: CanvasLayer
## Son karede kurulan isik listesi; aydinlik() bunu okuyor.
var _son_isiklar: Array[Vector3] = []

func _ready() -> void:
    add_to_group("karanlik")
    layer = 1
    _ekran = ColorRect.new()
    _ekran.set_anchors_preset(Control.PRESET_FULL_RECT)
    _ekran.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _mat = ShaderMaterial.new()
    _mat.shader = load("res://assets/karanlik.gdshader")
    var g := get_viewport().get_visible_rect().size
    _mat.set_shader_parameter("ekran_boyu", g)
    _ekran.material = _mat
    add_child(_ekran)
    parilti = CanvasLayer.new()
    parilti.layer = 2                      # karanlik 1, bu 2
    get_parent().add_child.call_deferred(parilti)

## Işık listesi her karede yeniden kuruluyor: oyuncu + mangallar + geçici
## parlamalar (namlu alevi, kor atışı). Sabit maliyet, tek geçiş.
func _process(delta: float) -> void:
    if not is_instance_valid(oyuncu):
        return
    var kt := get_viewport().get_canvas_transform()
    if parilti != null:
        parilti.transform = kt

    var hedef := _oyuncu_yaricapi()
    # Görüş anında zıplamasın; ısı düşünce karanlık üstüne kapanıyormuş gibi
    _yumusak_yaricap = lerpf(_yumusak_yaricap, hedef, 1.0 - pow(0.001, delta))

    var liste: Array[Vector3] = []
    var op: Vector2 = kt * oyuncu.global_position
    liste.append(Vector3(op.x, op.y, _yumusak_yaricap))

    for m in get_tree().get_nodes_in_group("isik_kaynagi"):
        if liste.size() >= TAVAN:
            break
        if not is_instance_valid(m):
            continue
        var sp: Vector2 = kt * m.global_position
        liste.append(Vector3(sp.x, sp.y, m.isik_yaricapi()))

    _mat.set_shader_parameter("isik_sayisi", liste.size())
    _mat.set_shader_parameter("isiklar", liste)
    _son_isiklar = liste

func _oyuncu_yaricapi() -> float:
    var i = oyuncu.isi
    if i.kilitli:
        return tavan_yaricap * kilit_parlama * gorus_carpani
    # EGRI DOGRUSAL DEGIL. Isinin ilk yarisi gorusun cogunu veriyor,
    # son yarisi cok az ekliyor.
    #
    # Neden: isi artik yavas doluyor (kilide varmak ~3 sn, onceden 1,6).
    # Dogrusal egriyle bu "oyuncu kosunun cogunu kor gecirir" demek
    # oluyordu -- olculdu, hayatta kalma 660 -> 572 sn'ye dustu.
    #
    # Ustel egri ikisini birden veriyor: dunya erken aciliyor AMA tavana
    # tirmanmak hala 3 saniye suruyor. Yan fayda tasarima daha da uygun:
    # tavana yakin bolgede gorus neredeyse hic artmadigi icin asiri
    # isinmak artik "daha iyi gormek icin" yapilmiyor -- sadece dokum
    # gucu, tavlama ve kizgin bolge hasari icin yapiliyor. Yani BILINCLI
    # bir karar, farkinda olmadan surüklenilen bir yer degil.
    return lerpf(taban_yaricap, tavan_yaricap, pow(i.oran(), 0.55)) * gorus_carpani

## Kısa süreli parlama (kor atışı gibi) -- görüşü bir anlığına açar.
func cakma(sure: float = 0.25, yaricap: float = 240.0) -> void:
    var t := create_tween()
    var eski := _yumusak_yaricap
    _yumusak_yaricap = maxf(_yumusak_yaricap, yaricap)
    t.tween_interval(sure)
    t.tween_callback(func(): _yumusak_yaricap = minf(_yumusak_yaricap, maxf(eski, _oyuncu_yaricapi())))


## Bu dunya noktasinda aydinlik ne kadar? 0 = zifiri, 1 = tam isik.
func aydinlik(p: Vector2) -> float:
    var sp: Vector2 = get_viewport().get_canvas_transform() * p
    var en := 0.0
    for l in _son_isiklar:
        if l.z <= 0.0:
            continue
        en = maxf(en, 1.0 - smoothstep(l.z * 0.45, l.z, sp.distance_to(Vector2(l.x, l.y))))
    return en
