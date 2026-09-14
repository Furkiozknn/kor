extends CharacterBody2D
## Kor oyuncusu: 8 yonlu hareket, fareye nisan alan otomatik ates, isi + dalis.

const Isi := preload("res://scripts/isi.gd")
const MermiSahne := preload("res://scenes/mermi.tscn")

signal can_degisti(can: int, maks: int)
signal oldu

const DALIS_SURE := 0.22
const DALIS_HIZ := 430.0
const DALIS_BEKLEME := 0.65
const VURULMA_DOKUNULMAZLIK := 0.6
const KOR_ESIK := 0.35       # bu isinin altinda kor atisi yapilamaz
const KOR_BEKLEME := 0.5

@export var hiz := 115.0
@export var ivme := 1200.0
@export var surtunme := 1500.0

var isi := Isi.new()
var maks_can := 4
var can := 4

# Kartlarla buyuyen degerler
var atis_araligi := 0.14
var mermi_hasari := 1.0
var mermi_sayisi := 1
var yayilma := 0.10
var asiri_isi_carpani := 1.0   # isi > %70 iken gecerli
var dalis_patlamasi := 0.0     # dalis bitince cevreye hasar
var miknatis := 38.0           # XP kupu cekim menzili
var kor_carpani := 1.0         # kart: kor atisi hasari
var kor_maliyet := 1.0         # kart: 1.0 = biriken isinin tamamini harcar

var _atis_sayaci := 0.0
var _dalis_kalan := 0.0
var _dalis_bekleme := 0.0
var _dokunulmaz := 0.0
var _kor_bekleme := 0.0

@onready var _gorsel: Sprite2D = $Gorsel
@onready var _halka: Polygon2D = $Halka
@onready var _namlu: Polygon2D = $Namlu

func _ready() -> void:
    add_to_group("oyuncu")
    can_degisti.emit(can, maks_can)

func dalisityor() -> bool:
    return _dalis_kalan > 0.0

func _physics_process(delta: float) -> void:
    isi.guncelle(delta)
    _dokunulmaz = maxf(_dokunulmaz - delta, 0.0)
    _dalis_bekleme = maxf(_dalis_bekleme - delta, 0.0)
    _atis_sayaci = maxf(_atis_sayaci - delta, 0.0)
    _kor_bekleme = maxf(_kor_bekleme - delta, 0.0)

    var nisan := (get_global_mouse_position() - global_position).normalized()
    if nisan == Vector2.ZERO:
        nisan = Vector2.RIGHT
    _namlu.position = nisan * 12.0

    if _dalis_kalan > 0.0:
        _dalis_kalan -= delta
        if _dalis_kalan <= 0.0:
            _dalis_bitti()
        move_and_slide()
        _renk_guncelle()
        return

    if Input.is_key_pressed(KEY_SPACE) and _dalis_bekleme <= 0.0:
        _dalis_basla(nisan)
        return

    var yon := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if yon != Vector2.ZERO:
        velocity = velocity.move_toward(yon * hiz, ivme * delta)
    else:
        velocity = velocity.move_toward(Vector2.ZERO, surtunme * delta)
    move_and_slide()

    if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and kor_atabilir():
        _kor_at(nisan)
    elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and isi.ates_edebilir() and _atis_sayaci <= 0.0:
        _ates_et(nisan)
    _renk_guncelle()

func _dalis_basla(nisan: Vector2) -> void:
    var yon := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if yon == Vector2.ZERO:
        yon = nisan
    isi.bosalt()   # kilitliyken calismaz -- asiri isinma cezasi budur
    _dalis_kalan = DALIS_SURE
    _dalis_bekleme = DALIS_BEKLEME
    velocity = yon.normalized() * DALIS_HIZ

func _dalis_bitti() -> void:
    velocity *= 0.25
    if dalis_patlamasi <= 0.0:
        return
    for d in get_tree().get_nodes_in_group("dusman"):
        if global_position.distance_to(d.global_position) < 48.0:
            d.hasar_al(dalis_patlamasi)

func _ates_et(nisan: Vector2) -> void:
    _atis_sayaci = atis_araligi
    isi.ates_et()
    var hasar := mermi_hasari
    if isi.oran() > 0.7:
        hasar *= asiri_isi_carpani
    for n in mermi_sayisi:
        var sapma := 0.0
        if mermi_sayisi > 1:
            sapma = lerpf(-yayilma, yayilma, float(n) / float(mermi_sayisi - 1))
        var m := MermiSahne.instantiate()
        m.global_position = global_position + nisan * 10.0
        m.yon = nisan.rotated(sapma)
        m.hasar = hasar
        get_parent().add_child(m)

## Isi karakterin altindaki kor halkasinda okunur: sonuk -> beyaz sicak.
func kor_atabilir() -> bool:
    return _kor_bekleme <= 0.0 and not isi.kilitli and isi.oran() >= KOR_ESIK

## Kor atisi: biriken isiyi tek delici mermiye cevirir ve isiyi harcar.
## Dalis isiyi bosa harcar, bu onu hasara cevirir -- ayni kaynagin iki cikisi.
func _kor_at(nisan: Vector2) -> Area2D:
    var harcanan := isi.harca(kor_maliyet)
    if harcanan <= 0.0:
        return null
    _kor_bekleme = KOR_BEKLEME
    _atis_sayaci = maxf(_atis_sayaci, 0.18)
    var m := MermiSahne.instantiate()
    m.global_position = global_position + nisan * 12.0
    m.yon = nisan
    m.hasar = mermi_hasari * (2.0 + 7.0 * harcanan) * kor_carpani
    m.delici = true
    m.hiz = 200.0
    m.scale = Vector2.ONE * (1.5 + 2.2 * harcanan)
    m.modulate = Color(1.7, 1.25, 0.6)   # normal mermiden daha akkor
    get_parent().add_child(m)
    return m

func _renk_guncelle() -> void:
    var t := isi.oran()
    var c := Color(0.45, 0.18, 0.05).lerp(Color(1.0, 0.95, 0.55), t)
    c.a = 0.35 + 0.65 * t
    _halka.scale = Vector2.ONE * (0.75 + 0.35 * t)
    if isi.kilitli:
        c = Color(1.0, 0.9, 0.4, 0.95) if int(Time.get_ticks_msec() / 90) % 2 == 0 else Color(0.8, 0.2, 0.05, 0.6)
    _halka.color = c
    _gorsel.modulate = Color(2, 2, 2) if _dokunulmaz > 0.0 and int(Time.get_ticks_msec() / 60) % 2 == 0 else Color(1, 1, 1)
    _gorsel.flip_h = _namlu.position.x < 0.0

func hasar_al(miktar: float) -> void:
    if _dokunulmaz > 0.0 or dalisityor() or can <= 0:
        return
    can -= int(ceilf(miktar))
    _dokunulmaz = VURULMA_DOKUNULMAZLIK
    can_degisti.emit(can, maks_can)
    if can <= 0:
        oldu.emit()
