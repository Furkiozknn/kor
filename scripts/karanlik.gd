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

@export var taban_yaricap := 34.0     # ısı sıfırken görüş
@export var tavan_yaricap := 215.0    # ısı tavandayken görüş
@export var kilit_yaricap := 26.0     # silah kilitliyken -- kör noktası

var oyuncu: Node2D
var gorus_carpani := 1.0              # kart: görüş menzili

var _ekran: ColorRect
var _mat: ShaderMaterial
var _yumusak_yaricap := 0.0

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

## Işık listesi her karede yeniden kuruluyor: oyuncu + mangallar + geçici
## parlamalar (namlu alevi, kor atışı). Sabit maliyet, tek geçiş.
func _process(delta: float) -> void:
    if not is_instance_valid(oyuncu):
        return
    var kt := get_viewport().get_canvas_transform()

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

func _oyuncu_yaricapi() -> float:
    var i = oyuncu.isi
    if i.kilitli:
        # Kilitliyken görüş de çöküyor: ceza iki katmanlı
        return kilit_yaricap * gorus_carpani
    return lerpf(taban_yaricap, tavan_yaricap, i.oran()) * gorus_carpani

## Kısa süreli parlama (kor atışı gibi) -- görüşü bir anlığına açar.
func cakma(sure: float = 0.25, yaricap: float = 240.0) -> void:
    var t := create_tween()
    var eski := _yumusak_yaricap
    _yumusak_yaricap = maxf(_yumusak_yaricap, yaricap)
    t.tween_interval(sure)
    t.tween_callback(func(): _yumusak_yaricap = minf(_yumusak_yaricap, maxf(eski, _oyuncu_yaricapi())))
