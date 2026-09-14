extends Node2D
## Kor -- koşu döngüsü: arena, dalga doğurma, XP, seviye kartları, HUD, ölüm.

const DusmanSahne := preload("res://scenes/dusman.tscn")
const KupSahne := preload("res://scenes/kup.tscn")
const YapiSahne := preload("res://scenes/yapi.tscn")

const SUTUN := 40
const SATIR := 22
const KARO := 16
# Arenanin ic siniri (duvarlar haric)
const ALAN := Rect2(40, 40, 560, 256)

const ZEMIN_SADE := Vector2i(0, 0)
const YAPI_TURLERI := ["fici", "sandik", "fici_yigin", "orsa", "mangal"]

@onready var oyuncu: CharacterBody2D = $Oyuncu
@onready var _karolar: TileMapLayer = $TileMapLayer

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
    _arena_kur()
    _yapilari_dog()
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
    if i.kilitli:
        _isi_cubuk.color = Color(1.0, 0.75, 0.2)
    elif i.oran() > 0.85:
        # Kilit oncesi uyari -- oyuncu tavana yaklastigini hissetmeli
        _isi_cubuk.color = Color(1, 1, 1) if int(Time.get_ticks_msec() / 70) % 2 == 0 else Color(1.0, 0.25, 0.05)
    else:
        _isi_cubuk.color = Color(0.35, 0.7, 1.0).lerp(Color(1.0, 0.3, 0.1), i.oran())
    if i.kilitli:
        _isi_yazi.text = "KİLİTLİ"
    elif oyuncu.kor_atabilir():
        _isi_yazi.text = "KOR HAZIR"
    else:
        _isi_yazi.text = "ISI"
    _lbl_ust.text = "%02d:%02d   SEVİYE %d   XP %d/%d   ÖLDÜRME %d" % [
        int(gecen) / 60, int(gecen) % 60, seviye, xp, xp_hedef, oldurulen]

# --- Arena ------------------------------------------------------------------

func _arena_kur() -> void:
    for y in SATIR:
        for x in SUTUN:
            var kenar := x == 0 or y == 0 or x == SUTUN - 1 or y == SATIR - 1
            var atlas: Vector2i
            if kenar:
                atlas = Vector2i(4 + randi() % 3, 0)          # duvar (carpismali)
            elif randf() < 0.80:
                atlas = ZEMIN_SADE
            else:
                atlas = Vector2i(1 + randi() % 3, 0)          # catlakli zemin
            _karolar.set_cell(Vector2i(x, y), 0, atlas)

## Siperler: ates hattini keser, suruyu yonlendirir. Fici/sandik kirilabilir.
func _yapilari_dog() -> void:
    var dolu := {}
    var basla := oyuncu.position
    for n in 14:
        for deneme in 12:
            var h := Vector2i(randi_range(2, SUTUN - 3), randi_range(2, SATIR - 3))
            if dolu.has(h):
                continue
            var p := Vector2(h.x * KARO + KARO / 2.0, h.y * KARO + KARO / 2.0)
            if p.distance_to(basla) < 56.0:   # oyuncunun dogdugu yeri tikama
                continue
            dolu[h] = true
            var y := YapiSahne.instantiate()
            y.kur(YAPI_TURLERI[randi() % YAPI_TURLERI.size()])
            y.position = p
            y.kirildi.connect(func(poz: Vector2) -> void: _kup_dus(poz, 1))
            add_child(y)
            break

# --- Dalgalar ---------------------------------------------------------------

func _dusman_dog() -> void:
    var d := DusmanSahne.instantiate()
    d.kur(_tur_sec(), 1.0 + gecen / 90.0)
    d.global_position = _kenar_noktasi()
    d.olduruldu.connect(_dusman_oldu)
    add_child(d)

## Sure gectikce yeni turler devreye girer.
func _tur_sec() -> int:
    var r := randf()
    if gecen > 75.0 and r < 0.10:
        return 5    # cadi -- menzilli
    if gecen > 60.0 and r < 0.12:
        return 4    # hayalet -- duvar tanimaz
    if gecen > 45.0 and r < 0.22:
        return 2    # curuf -- iri
    if gecen > 30.0 and r < 0.42:
        return 3    # iskelet -- sert
    if gecen > 15.0 and r < 0.62:
        return 1    # imp -- hizli
    return 0        # kul

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
    _kup_dus(poz, kazanc)

func _kup_dus(poz: Vector2, kazanc: int) -> void:
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

# --- Kartlar ----------------------------------------------------------------

func _kart_havuzu() -> Array:
    return [
        {"ad": "GENİŞ KAZAN", "aciklama": "Isı tavanı +25", "ikon": "kazan",
            "uygula": func(o): o.isi.tavan += 25.0},
        {"ad": "SOĞUK HAT", "aciklama": "Soğuma hızı +%35", "ikon": "soguk",
            "uygula": func(o): o.isi.soguma_hizi *= 1.35},
        {"ad": "HIZLI TETİK", "aciklama": "Atış hızı +%20, ısı +%15", "ikon": "tetik", "uygula": func(o):
            o.atis_araligi *= 0.8
            o.isi.atis_basina *= 1.15},
        {"ad": "AĞIR MERMİ", "aciklama": "Hasar +%40, ısı +%20", "ikon": "agir", "uygula": func(o):
            o.mermi_hasari *= 1.4
            o.isi.atis_basina *= 1.2},
        {"ad": "ÇATAL NAMLU", "aciklama": "+1 mermi, ısı +%30", "ikon": "catal", "uygula": func(o):
            o.mermi_sayisi += 1
            o.yayilma += 0.06
            o.isi.atis_basina *= 1.3},
        {"ad": "KOR PATLAMASI", "aciklama": "Dalış bitince çevreye hasar", "ikon": "kor",
            "uygula": func(o): o.dalis_patlamasi += 3.0},
        {"ad": "KIZGIN ÇELİK", "aciklama": "Isı %70 üstündeyken hasar +%50", "ikon": "celik",
            "uygula": func(o): o.asiri_isi_carpani += 0.5},
        {"ad": "TAVLANMIŞ ZIRH", "aciklama": "Maks can +1, dolu iyileş", "ikon": "zirh", "uygula": func(o):
            o.maks_can += 1
            o.can = o.maks_can
            o.can_degisti.emit(o.can, o.maks_can)},
        {"ad": "MIKNATIS", "aciklama": "XP toplama menzili +%60", "ikon": "miknatis",
            "uygula": func(o): o.miknatis *= 1.6},
        {"ad": "ÖRS DARBESİ", "aciklama": "Kor atışı hasarı +%60", "ikon": "ors",
            "uygula": func(o): o.kor_carpani += 0.6},
        {"ad": "YARIM BOŞALTMA", "aciklama": "Kor atışı ısının yarısını bırakır", "ikon": "soguk",
            "uygula": func(o): o.kor_maliyet = maxf(o.kor_maliyet * 0.5, 0.25)},
        {"ad": "YAĞLI ÇİZME", "aciklama": "Hareket hızı +%12", "ikon": "cizme",
            "uygula": func(o): o.hiz *= 1.12},
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
        b.add_theme_font_size_override("font_size", 10)
        b.custom_minimum_size = Vector2(360, 40)
        b.icon = load("res://assets/sprites/ikon_%s.png" % k["ikon"])
        b.expand_icon = false
        b.text = "  %s\n  %s" % [k["ad"], k["aciklama"]]
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

# --- HUD --------------------------------------------------------------------

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

    # Kor atisi esigi: bu cizgiyi gecince sag tik aktif
    var esik := ColorRect.new()
    esik.position = Vector2(10 + 120.0 * oyuncu.KOR_ESIK, 34)
    esik.size = Vector2(1, 12)
    esik.color = Color(1, 0.85, 0.4, 0.8)
    _hud.add_child(esik)

    _isi_yazi = _yazi(9)
    _isi_yazi.position = Vector2(134, 33)

    var ipucu := _yazi(9)
    ipucu.position = Vector2(10, 330)
    ipucu.modulate = Color(1, 1, 1, 0.55)
    ipucu.text = "WASD   ·   SOL TIK ateş   ·   SAĞ TIK kor atışı (ısıyı hasara çevirir)   ·   BOŞLUK dalış"

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
