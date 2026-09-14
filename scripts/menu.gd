extends Node2D
## Başlangıç ekranı.
##
## İlk izlenim oyunun kimliğini taşımalı: karanlık dökümhane, tek sıcak şey
## oyuncu. Menü de aynı karanlık shader'ını ve aynı temayı kullanıyor —
## menüden oyuna geçerken görsel dil hiç değişmiyor.
##
## Arka planda gerçek oyun sahnesi yok; ucuz bir sahne kurulumu var:
## birkaç mangal ışığı, yanıp sönen korlar, ve ısısı kendiliğinden inip
## çıkan bir "nefes" — mekaniği anlatmadan gösteriyor.

const Tema := preload("res://scripts/tema.gd")
const OYUN := "res://scenes/level.tscn"

## Firin kademeleri. Her biri isi ekonomisine dokunuyor; hicbiri oyuncuya
## kalici GUC vermiyor -- sadece daha zor bir firin ve daha cok curuf.
const KADEMELER := [
    "kapalı",
    "körük — ısı %25 hızlı birikir",
    "sıkışan valf — kilit 3 saniye",
    "dökümhane uyanık — düşmanlar %15 güçlü",
]

var _isik: Array[Vector3] = []
var _mat: ShaderMaterial
var _nefes := 0.0
var _oyuncu: AnimatedSprite2D
var _kademe_yazi: Label

func _ready() -> void:
    _zemin_kur()
    _karanlik_kur()
    _oyuncu_kur()
    _arayuz_kur()
    SesYonetici.yukle_klasorden()
    SesYonetici.muzik_cal("res://assets/ses/muzik_dokumhane.ogg", -18.0)

func _zemin_kur() -> void:
    var karolar := TileMapLayer.new()
    karolar.tile_set = load("res://assets/karolar.tres")
    karolar.modulate = Color(0.50, 0.50, 0.58)
    karolar.z_index = -5
    add_child(karolar)
    for y in 22:
        for x in 40:
            var kenar := x == 0 or y == 0 or x == 39 or y == 21
            var atlas := Vector2i(4 + randi() % 3, 0) if kenar else (
                Vector2i(0, 0) if randf() < 0.8 else Vector2i(1 + randi() % 3, 0))
            karolar.set_cell(Vector2i(x, y), 0, atlas)

    # Mangal ışıkları: sahneyi kuran şey bunlar
    for p in [Vector2(120, 250), Vector2(520, 230), Vector2(300, 300), Vector2(430, 90)]:
        var m := Sprite2D.new()
        m.texture = Hiss.parlama_dokusu(Color(1.0, 0.55, 0.18, 0.32),
            Color(0.9, 0.25, 0.05, 0.0), 96)
        m.material = Hiss.ekleme_materyali()
        m.position = p
        m.z_index = -1
        add_child(m)
        _isik.append(Vector3(p.x, p.y, 62.0))

func _karanlik_kur() -> void:
    var k := CanvasLayer.new()
    k.layer = 1
    add_child(k)
    var e := ColorRect.new()
    e.set_anchors_preset(Control.PRESET_FULL_RECT)
    e.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _mat = ShaderMaterial.new()
    _mat.shader = load("res://assets/karanlik.gdshader")
    _mat.set_shader_parameter("ekran_boyu", get_viewport().get_visible_rect().size)
    e.material = _mat
    k.add_child(e)

func _oyuncu_kur() -> void:
    var hale := Sprite2D.new()
    hale.texture = Hiss.parlama_dokusu(Color(1.0, 0.72, 0.30, 0.85),
        Color(1.0, 0.35, 0.05, 0.0), 64)
    hale.material = Hiss.ekleme_materyali()
    hale.position = Vector2(320, 232)
    hale.z_index = -1
    add_child(hale)
    hale.set_meta("hale", true)

    _oyuncu = AnimatedSprite2D.new()
    var Yonlu := load("res://scripts/yonlu.gd")
    var sf = Yonlu.kur("res://assets/sprites/oyuncu", {"dur": 5.0})
    if sf != null:
        _oyuncu.sprite_frames = sf
        _oyuncu.animation = "dur_south"
        _oyuncu.play()
    _oyuncu.position = Vector2(320, 232)
    add_child(_oyuncu)

func _arayuz_kur() -> void:
    var k := CanvasLayer.new()
    k.layer = 3
    add_child(k)

    var kutu := VBoxContainer.new()
    kutu.theme = Tema.tema()
    kutu.position = Vector2(48, 54)
    kutu.add_theme_constant_override("separation", Tema.BOSLUK_S)
    k.add_child(kutu)

    var ad := Tema._yazi("KOR", 48, Tema.KOR)
    kutu.add_child(ad)
    kutu.add_child(Tema.sonuk("karanlıkta ne kadar görürsen o kadar yakınsın"))

    var bosluk := Control.new()
    bosluk.custom_minimum_size = Vector2(0, Tema.BOSLUK_L)
    kutu.add_child(bosluk)

    for satir in [
        "Ateş etmek ısıtır. Isındıkça daha çok görürsün.",
        "Tavana varırsan silah kilitlenir — ve dalış o kilidi kırmaz.",
        "Dalış ısıyı boşaltır: güvenliği görüşle ödersin.",
    ]:
        kutu.add_child(Tema.govde(satir))

    var bosluk2 := Control.new()
    bosluk2.custom_minimum_size = Vector2(0, Tema.BOSLUK_M)
    kutu.add_child(bosluk2)

    # Kalici durum: curuf ve rekor
    var rekor: float = float(Kayit._veri.get("en_iyi_sure", 0.0))
    var durum := "CÜRÜF %d" % Kayit.curuf()
    if rekor > 0.0:
        durum += "     en iyi %02d:%02d" % [int(rekor) / 60, int(rekor) % 60]
    kutu.add_child(Tema.vurgu(durum))

    # FIRIN KADEMESI -- gonullu zorluk, Kor'un kendi diliyle. Her kademe
    # isi ekonomisine dokunuyor ve curuf kazancini carpiyor.
    var kad := HBoxContainer.new()
    kad.add_theme_constant_override("separation", Tema.BOSLUK_S)
    kad.add_child(Tema.sonuk("FIRIN"))
    for n in KADEMELER.size():
        var d := Button.new()
        d.text = str(n)
        d.custom_minimum_size = Vector2(26, 22)
        d.pressed.connect(_kademe_sec.bind(n))
        kad.add_child(d)
    _kademe_yazi = Tema.sonuk("")
    kad.add_child(_kademe_yazi)
    kutu.add_child(kad)

    var bosluk3 := Control.new()
    bosluk3.custom_minimum_size = Vector2(0, Tema.BOSLUK_M)
    kutu.add_child(bosluk3)

    var basla := Button.new()
    basla.text = "  BAŞLA      [Enter]"
    basla.custom_minimum_size = Vector2(196, 30)
    basla.pressed.connect(_basla)
    kutu.add_child(basla)
    basla.grab_focus()
    _kademe_tazele()

    var alt := Tema.sonuk("WASD hareket · SOL TIK ateş · SAĞ TIK kor atışı · BOŞLUK dalış · Q silah")
    alt.position = Vector2(48, 322)
    alt.modulate = Color(1, 1, 1, 0.55)
    k.add_child(alt)

func _kademe_sec(k: int) -> void:
    Kayit.kademe_yaz(k)
    SesYonetici.cal("kart_sec")
    _kademe_tazele()

func _kademe_tazele() -> void:
    if _kademe_yazi == null:
        return
    var k: int = clampi(Kayit.kademe(), 0, KADEMELER.size() - 1)
    _kademe_yazi.text = "  %s   (cüruf x%.2f)" % [KADEMELER[k], Kayit.kademe_carpani()]

func _process(delta: float) -> void:
    # Nefes: ısının inip çıkışını menüde de görüyorsun. Mekaniği anlatmadan
    # gösteren en ucuz yol.
    _nefes += delta * 0.55
    var oran := 0.5 + 0.5 * sin(_nefes)
    var yaricap := lerpf(46.0, 210.0, oran)

    var liste: Array[Vector3] = [Vector3(320, 232, yaricap)]
    liste.append_array(_isik)
    _mat.set_shader_parameter("isik_sayisi", liste.size())
    _mat.set_shader_parameter("isiklar", liste)

    for c in get_children():
        if c is Sprite2D and c.has_meta("hale"):
            c.scale = Vector2.ONE * (0.5 + 0.55 * oran)
            c.modulate = Color(1.0, 0.45, 0.12).lerp(Color(1.0, 0.95, 0.72), oran)

func _unhandled_key_input(olay: InputEvent) -> void:
    if not olay.is_pressed() or olay.is_echo():
        return
    var k := (olay as InputEventKey).keycode
    if k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
        _basla()
    elif k == KEY_ESCAPE:
        get_tree().quit()

func _basla() -> void:
    SesYonetici.cal("kart_sec")
    get_tree().change_scene_to_file(OYUN)
