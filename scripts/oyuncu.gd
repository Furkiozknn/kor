extends CharacterBody2D
## Kor oyuncusu: 8 yönlü hareket, fareye nişan alan ateş, ısı + dalış,
## dört silah ve biriken ısıyı hasara çeviren kor atışı.

const Isi := preload("res://scripts/isi.gd")
const Silahlar := preload("res://scripts/silahlar.gd")
const MermiSahne := preload("res://scenes/mermi.tscn")

signal can_degisti(can: int, maks: int)
signal silah_degisti(ad: String, indeks: int)
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

# Silahlar -- baslangicta sadece ilki acik, kartlar digerlerini aciyor
var silah_indeksi := 0
var acik_silahlar := [0]

# Kartlarla buyuyen degerler (silahin ustune carpan olarak biner)
var atis_hizi_carpani := 1.0
var isi_carpani := 1.0         # kart: atis basina isi
var mermi_hasari := 1.0
var ek_mermi := 0
var ek_yayilma := 0.0
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
var _namlu_parlama := 0.0
var _hayalet_sayaci := 0.0
var _adim := 0.0
var _kor_zerre := 0.0
var _silah_gecis := 0.0

@onready var _gorsel: Sprite2D = $Gorsel
@onready var _parlama: Sprite2D = $Parlama
@onready var _namlu: Sprite2D = $Namlu
@onready var _kamera: Camera2D = $Kamera

func _ready() -> void:
    add_to_group("oyuncu")
    Hiss.kamera = _kamera
    _parlama.texture = Hiss.parlama_dokusu(
        Color(1.0, 0.72, 0.30, 0.85), Color(1.0, 0.35, 0.05, 0.0), 64)
    _parlama.material = Hiss.ekleme_materyali()
    _namlu.texture = Hiss.parlama_dokusu(
        Color(1.0, 0.96, 0.80, 1.0), Color(1.0, 0.55, 0.15, 0.0), 32)
    _namlu.material = Hiss.ekleme_materyali()
    _namlu.scale = Vector2.ZERO
    can_degisti.emit(can, maks_can)
    silah_degisti.emit(silah(), silah_indeksi)

func silah() -> String:
    return Silahlar.al(silah_indeksi)["ad"]

func silah_ver(i: int) -> void:
    if i in acik_silahlar:
        return
    acik_silahlar.append(i)
    acik_silahlar.sort()
    silah_indeksi = i
    _silah_gecis = 0.25
    silah_degisti.emit(silah(), silah_indeksi)

func silah_gec(ileri: bool = true) -> void:
    if acik_silahlar.size() < 2:
        return
    var k: int = acik_silahlar.find(silah_indeksi)
    k = wrapi(k + (1 if ileri else -1), 0, acik_silahlar.size())
    silah_indeksi = acik_silahlar[k]
    _silah_gecis = 0.25
    _atis_sayaci = maxf(_atis_sayaci, 0.12)
    silah_degisti.emit(silah(), silah_indeksi)
    Hiss.sars(0.6)

func dalisityor() -> bool:
    return _dalis_kalan > 0.0

func _unhandled_key_input(olay: InputEvent) -> void:
    if not olay.is_pressed() or olay.is_echo():
        return
    if olay.keycode == KEY_Q or olay.keycode == KEY_TAB:
        silah_gec(true)
    elif olay.keycode >= KEY_1 and olay.keycode <= KEY_4:
        var i: int = olay.keycode - KEY_1
        if i in acik_silahlar and i != silah_indeksi:
            silah_indeksi = i
            _silah_gecis = 0.25
            silah_degisti.emit(silah(), silah_indeksi)

func _physics_process(delta: float) -> void:
    isi.guncelle(delta)
    _dokunulmaz = maxf(_dokunulmaz - delta, 0.0)
    _dalis_bekleme = maxf(_dalis_bekleme - delta, 0.0)
    _atis_sayaci = maxf(_atis_sayaci - delta, 0.0)
    _kor_bekleme = maxf(_kor_bekleme - delta, 0.0)
    _namlu_parlama = maxf(_namlu_parlama - delta * 7.0, 0.0)
    _silah_gecis = maxf(_silah_gecis - delta, 0.0)

    var nisan := (get_global_mouse_position() - global_position).normalized()
    if nisan == Vector2.ZERO:
        nisan = Vector2.RIGHT

    if _dalis_kalan > 0.0:
        _dalis_kalan -= delta
        _hayalet_sayaci -= delta
        if _hayalet_sayaci <= 0.0:
            _hayalet_sayaci = 0.045
            Hiss.hayalet(_gorsel)
        if _dalis_kalan <= 0.0:
            _dalis_bitti()
        move_and_slide()
        _gorunum_guncelle(delta, nisan)
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
    _gorunum_guncelle(delta, nisan)

func _dalis_basla(nisan: Vector2) -> void:
    var yon := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if yon == Vector2.ZERO:
        yon = nisan
    isi.bosalt()   # kilitliyken calismaz -- asiri isinma cezasi budur
    _dalis_kalan = DALIS_SURE
    _dalis_bekleme = DALIS_BEKLEME
    _hayalet_sayaci = 0.0
    velocity = yon.normalized() * DALIS_HIZ
    Hiss.sars(1.2)

func _dalis_bitti() -> void:
    velocity *= 0.25
    if dalis_patlamasi <= 0.0:
        return
    Hiss.sars(3.0)
    Hiss.patlama(get_parent(), global_position, Color(1.0, 0.6, 0.2), 22, 150.0, 2.4)
    for d in get_tree().get_nodes_in_group("dusman"):
        var fark: Vector2 = d.global_position - global_position
        if fark.length() < 48.0:
            d.hasar_al(dalis_patlamasi, fark.normalized() * 120.0)

func _ates_et(nisan: Vector2) -> void:
    var s := Silahlar.al(silah_indeksi)
    _atis_sayaci = s["aralik"] / atis_hizi_carpani
    isi.ates_et(float(s["isi"]) * isi_carpani)
    var hasar: float = s["hasar"] * mermi_hasari
    if isi.oran() > 0.7:
        hasar *= asiri_isi_carpani

    var adet: int = int(s["adet"]) + ek_mermi
    var yay: float = float(s["yayilma"]) + ek_yayilma
    for n in adet:
        var sapma := 0.0
        if adet > 1:
            sapma = lerpf(-yay, yay, float(n) / float(adet - 1)) + randf_range(-0.03, 0.03)
        var m := MermiSahne.instantiate()
        m.global_position = global_position + nisan * 10.0
        m.yon = nisan.rotated(sapma)
        m.hasar = hasar
        m.hiz = s["hiz"]
        m.omur = s["omur"]
        m.delici = s["delici"]
        m.scale = Vector2.ONE * float(s["boy"])
        get_parent().add_child(m)

    velocity -= nisan * float(s["geri_tepme"])          # geri tepme
    _namlu_parlama = 1.0
    Hiss.sars(float(s["sarsinti"]))

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
    m.omur = 1.6
    m.scale = Vector2.ONE * (1.5 + 2.2 * harcanan)
    m.modulate = Color(1.9, 1.35, 0.65)   # normal mermiden daha akkor
    get_parent().add_child(m)

    velocity -= nisan * 150.0 * harcanan
    _namlu_parlama = 1.6
    Hiss.sars(2.0 + 4.0 * harcanan)
    Hiss.dondur(0.045)
    Hiss.patlama(get_parent(), global_position + nisan * 14.0,
        Color(1.0, 0.75, 0.3), 16, 190.0, 2.2, 0.35)
    return m

# --- Gorunum ----------------------------------------------------------------

## Isi karakterin altindaki kor parlamasinda okunur; adim sekmesi ve
## namlu alevi hareketi "canli" gosterir.
func _gorunum_guncelle(delta: float, nisan: Vector2) -> void:
    var t := isi.oran()

    # Kor parlamasi: isindikca buyur, beyazlas
    var renk := Color(1.0, 0.45, 0.12).lerp(Color(1.0, 0.95, 0.72), t)
    renk.a = 0.45 + 0.55 * t
    if isi.kilitli:
        var carp := 1.0 if int(Time.get_ticks_msec() / 80) % 2 == 0 else 0.45
        renk = Color(1.0, 0.85, 0.35, 0.95 * carp)
    _parlama.modulate = renk
    _parlama.scale = Vector2.ONE * (0.52 + 0.40 * t + 0.03 * sin(Time.get_ticks_msec() / 90.0))

    # Isi yuksekken kordan zerre kalkar
    if t > 0.55:
        _kor_zerre -= delta
        if _kor_zerre <= 0.0:
            _kor_zerre = lerpf(0.18, 0.05, t)
            Hiss.patlama(get_parent(), global_position + Vector2(randf_range(-5, 5), 2),
                Color(1.0, 0.6, 0.2), 1, 26.0, 1.1, 0.5)

    # Namlu alevi
    _namlu.position = nisan * 11.0
    _namlu.scale = Vector2.ONE * (0.55 * _namlu_parlama)
    _namlu.visible = _namlu_parlama > 0.02

    # Yurume sekmesi + dalista uzama
    var h := velocity.length()
    if dalisityor():
        _gorsel.scale = Vector2(1.28, 0.78)
    else:
        _adim += delta * (6.0 + h * 0.07)
        var s := 1.0 + sin(_adim) * minf(h / hiz, 1.0) * 0.10
        _gorsel.scale = Vector2(2.0 - s, s)
    _gorsel.position.y = -abs(sin(_adim)) * minf(h / hiz, 1.0) * 1.6

    # Silah degisiminde kisa beyaz parlama
    if _silah_gecis > 0.0:
        _gorsel.modulate = Color(1, 1, 1).lerp(Color(2.2, 2.0, 1.4), _silah_gecis / 0.25)
    elif _dokunulmaz > 0.0 and int(Time.get_ticks_msec() / 60) % 2 == 0:
        _gorsel.modulate = Color(2.4, 1.2, 1.2)
    else:
        _gorsel.modulate = Color(1, 1, 1)
    _gorsel.flip_h = nisan.x < 0.0

func hasar_al(miktar: float) -> void:
    if _dokunulmaz > 0.0 or dalisityor() or can <= 0:
        return
    can -= int(ceilf(miktar))
    _dokunulmaz = VURULMA_DOKUNULMAZLIK
    can_degisti.emit(can, maks_can)
    Hiss.sars(4.5)
    Hiss.dondur(0.06)
    Hiss.patlama(get_parent(), global_position, Color(1.0, 0.35, 0.25), 14, 130.0, 2.0)
    if can <= 0:
        oldu.emit()
