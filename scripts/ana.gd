extends Node2D
## Kor -- koşu döngüsü: dalga spawn'ı, XP, seviye kartları, HUD, ölüm.

const DusmanSahne := preload("res://scenes/dusman.tscn")
const KupSahne := preload("res://scenes/kup.tscn")

# Arenanin ic siniri (duvarlar haric), 16px karolar
const ALAN := Rect2(40, 40, 560, 272)

@onready var oyuncu: CharacterBody2D = $Oyuncu

var gecen := 0.0
var seviye := 1
var xp := 0
var xp_hedef := 5
var oldurulen := 0
var bitti := false

var _spawn_sayaci := 0.0
var _hud: CanvasLayer
var _lbl_ust: Label
var _lbl_can: Label
var _isi_cubuk: ColorRect
var _isi_yazi: Label
var _kart_katman: CanvasLayer
var _bekleyen_kart := 0

func _ready() -> void:
    _hud_kur()
    oyuncu.oldu.connect(_oyun_bitti)
    oyuncu.can_degisti.connect(func(c, m): _lbl_can.text = "CAN  " + "*".repeat(max(c, 0)) + "-".repeat(max(m - c, 0)))
    oyuncu.can_degisti.emit(oyuncu.can, oyuncu.maks_can)

func _process(delta: float) -> void:
    if bitti:
        if Input.is_key_pressed(KEY_R):
            get_tree().reload_current_scene()
        return

    gecen += delta
    _spawn_sayaci -= delta
    if _spawn_sayaci <= 0.0:
        _spawn_sayaci = maxf(1.30 - gecen * 0.012, 0.16)
        _dusman_dog()

    var i = oyuncu.isi
    _isi_cubuk.size.x = 120.0 * i.oran()
    _isi_cubuk.color = Color(1.0, 0.75, 0.2) if i.kilitli else Color(0.35, 0.7, 1.0).lerp(Color(1.0, 0.3, 0.1), i.oran())
    _isi_yazi.text = "KİLİTLİ" if i.kilitli else "ISI"
    _lbl_ust.text = "%02d:%02d   SEVİYE %d   XP %d/%d   ÖLDÜRME %d" % [
        int(gecen) / 60, int(gecen) % 60, seviye, xp, xp_hedef, oldurulen]

func _dusman_dog() -> void:
    var d := DusmanSahne.instantiate()
    var tur := 0
    var r := randf()
    if gecen > 45.0 and r < 0.18:
        tur = 2
    elif gecen > 15.0 and r < 0.45:
        tur = 1
    d.kur(tur, 1.0 + gecen / 90.0)
    d.global_position = _kenar_noktasi()
    d.olduruldu.connect(_dusman_oldu)
    add_child(d)

func _kenar_noktasi() -> Vector2:
    # Oyuncudan uzak bir kenar sec, tepesine dogmasin
    for n in 8:
        var p: Vector2
        match randi() % 4:
            0: p = Vector2(randf_range(ALAN.position.x, ALAN.end.x), ALAN.position.y)
            1: p = Vector2(randf_range(ALAN.position.x, ALAN.end.x), ALAN.end.y)
            2: p = Vector2(ALAN.position.x, randf_range(ALAN.position.y, ALAN.end.y))
            _: p = Vector2(ALAN.end.x, randf_range(ALAN.position.y, ALAN.end.y))
        if p.distance_to(oyuncu.global_position) > 90.0:
            return p
    return ALAN.position

func _dusman_oldu(poz: Vector2, kazanc: int) -> void:
    oldurulen += 1
    var k := KupSahne.instantiate()
    k.global_position = poz
    k.xp = kazanc
    k.toplandi.connect(_xp_topla)
    add_child(k)

func _xp_topla(kazanc: int) -> void:
    xp += kazanc
    while xp >= xp_hedef:
        xp -= xp_hedef
        seviye += 1
        xp_hedef = int(xp_hedef * 1.45) + 2
        _bekleyen_kart += 1
    # Ayni karede iki seviye gelirse kart kaybolmasin: sirayla acilirlar
    if _bekleyen_kart > 0 and _kart_katman == null:
        _kartlari_ac()

# --- Kartlar ---------------------------------------------------------------

func _kart_havuzu() -> Array:
    return [
        {"ad": "GENİŞ KAZAN", "aciklama": "Isı tavanı +25", "uygula": func(o): o.isi.tavan += 25.0},
        {"ad": "SOĞUK HAT", "aciklama": "Soğuma hızı +%35", "uygula": func(o): o.isi.soguma_hizi *= 1.35},
        {"ad": "HIZLI TETİK", "aciklama": "Atış hızı +%20, ısı +%15", "uygula": func(o):
            o.atis_araligi *= 0.8
            o.isi.atis_basina *= 1.15},
        {"ad": "AĞIR MERMİ", "aciklama": "Hasar +%40, ısı +%20", "uygula": func(o):
            o.mermi_hasari *= 1.4
            o.isi.atis_basina *= 1.2},
        {"ad": "ÇATAL NAMLU", "aciklama": "+1 mermi, ısı +%30", "uygula": func(o):
            o.mermi_sayisi += 1
            o.yayilma += 0.06
            o.isi.atis_basina *= 1.3},
        {"ad": "KOR PATLAMASI", "aciklama": "Dalış bitince çevreye hasar", "uygula": func(o): o.dalis_patlamasi += 3.0},
        {"ad": "KIZGIN ÇELİK", "aciklama": "Isı %70 üstündeyken hasar +%50", "uygula": func(o): o.asiri_isi_carpani += 0.5},
        {"ad": "TAVLANMIŞ ZIRH", "aciklama": "Maks can +1, dolu iyileş", "uygula": func(o):
            o.maks_can += 1
            o.can = o.maks_can
            o.can_degisti.emit(o.can, o.maks_can)},
        {"ad": "MIKNATIS", "aciklama": "XP toplama menzili +%60", "uygula": func(o): o.miknatis *= 1.6},
        {"ad": "YAĞLI ÇİZME", "aciklama": "Hareket hızı +%12", "uygula": func(o): o.hiz *= 1.12},
    ]

func _kartlari_ac() -> void:
    var havuz := _kart_havuzu()
    havuz.shuffle()
    var secilen := havuz.slice(0, 3)

    _kart_katman = CanvasLayer.new()
    _kart_katman.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(_kart_katman)

    var fon := ColorRect.new()
    fon.color = Color(0, 0, 0, 0.72)
    fon.set_anchors_preset(Control.PRESET_FULL_RECT)
    _kart_katman.add_child(fon)

    var kutu := VBoxContainer.new()
    kutu.position = Vector2(140, 90)
    kutu.custom_minimum_size = Vector2(360, 0)
    kutu.add_theme_constant_override("separation", 8)
    _kart_katman.add_child(kutu)

    var baslik := Label.new()
    baslik.add_theme_font_size_override("font_size", 12)
    baslik.text = "SEVİYE %d  —  bir kart seç" % seviye
    kutu.add_child(baslik)

    for k in secilen:
        var b := Button.new()
        b.text = "%s\n   %s" % [k["ad"], k["aciklama"]]
        b.add_theme_font_size_override("font_size", 10)
        b.custom_minimum_size = Vector2(360, 40)
        b.pressed.connect(_kart_secildi.bind(k["uygula"]))
        kutu.add_child(b)

    get_tree().paused = true
    kutu.get_child(1).grab_focus()

func _kart_secildi(uygula: Callable) -> void:
    uygula.call(oyuncu)
    _bekleyen_kart -= 1
    _kart_katman.queue_free()
    _kart_katman = null
    if _bekleyen_kart > 0:
        _kartlari_ac()
    else:
        get_tree().paused = false

# --- HUD -------------------------------------------------------------------

func _hud_kur() -> void:
    _hud = CanvasLayer.new()
    add_child(_hud)

    _lbl_ust = _yazi(10)
    _lbl_ust.position = Vector2(10, 4)

    _lbl_can = _yazi(10)
    _lbl_can.position = Vector2(10, 18)

    var arka := ColorRect.new()
    arka.position = Vector2(10, 36)
    arka.size = Vector2(120, 8)
    arka.color = Color(0.12, 0.12, 0.16)
    _hud.add_child(arka)

    _isi_cubuk = ColorRect.new()
    _isi_cubuk.position = Vector2(10, 36)
    _isi_cubuk.size = Vector2(0, 8)
    _hud.add_child(_isi_cubuk)

    _isi_yazi = _yazi(9)
    _isi_yazi.position = Vector2(134, 33)

    var ipucu := _yazi(9)
    ipucu.position = Vector2(10, 330)
    ipucu.modulate = Color(1, 1, 1, 0.55)
    ipucu.text = "WASD hareket   ·   SOL TIK ateş   ·   BOŞLUK dalış (ısıyı boşaltır)"

## HUD yazilari: 640x360 tabanda okunur boyut
func _yazi(boy: int) -> Label:
    var l := Label.new()
    l.add_theme_font_size_override("font_size", boy)
    _hud.add_child(l)
    return l

func _oyun_bitti() -> void:
    bitti = true
    var l := _yazi(14)
    l.position = Vector2(230, 150)
    l.text = "SÖNDÜN\n%d öldürme · %02d:%02d · seviye %d\nR ile yeniden" % [
        oldurulen, int(gecen) / 60, int(gecen) % 60, seviye]
    for d in get_tree().get_nodes_in_group("dusman"):
        d.queue_free()
