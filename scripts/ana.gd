extends Node2D
## Kor -- koşu döngüsü: arena, dalga doğurma, XP, seviye kartları, HUD, ölüm.

const DusmanSahne := preload("res://scenes/dusman.tscn")
const KupSahne := preload("res://scenes/kup.tscn")
const YapiSahne := preload("res://scenes/yapi.tscn")
const Silahlar := preload("res://scripts/silahlar.gd")
const YAZI_TIPI := preload("res://assets/fonts/PublicPixel.ttf")
const KaranlikSahne := preload("res://scripts/karanlik.gd")
const GelistiriciSahne := preload("res://scripts/gelistirici.gd")

const SUTUN := 40
const SATIR := 22
const KARO := 16
# Arenanin ic siniri (duvarlar haric)
const ALAN := Rect2(40, 40, 560, 256)

const ZEMIN_SADE := Vector2i(0, 0)
## Dalga tasarimi. Olculdu: eski egri (1.30 - gecen*0.012, taban 0.16) 95.
## saniyede saniyede 6,25 dusmana cikiyordu; bot saniyede ~1,5 olduruyor,
## yani olum matematiksel olarak kacinilmazdi. Cozum tur standardi: spawn
## hizini sinirsiz artirmak yerine CANLI DUSMAN TAVANI koy, zorlugu
## bilesim ve guc ile buyut.
const SPAWN_BAS := 1.45        # sn
const SPAWN_AZALMA := 0.0055   # sn / oyun saniyesi
const SPAWN_TABAN := 0.34      # sn -- saniyede ~3 dusman tavani
const CANLI_TAVAN_BAS := 45
const CANLI_TAVAN_ARTIS := 0.28   # saniyede, tavan buyur
const GUC_BOLEN := 90.0           # dusman gucu: 1 + gecen/GUC_BOLEN
const CANLI_TAVAN_UST := 170

const YAPI_TURLERI := ["fici", "sandik", "fici_yigin", "orsa", "mangal", "mangal"]

@onready var oyuncu: CharacterBody2D = $Oyuncu
@onready var _karolar: TileMapLayer = $TileMapLayer

var gecen := 0.0
var seviye := 1
var xp := 0
var xp_hedef := 5
var oldurulen := 0
var bitti := false

## Denge taramasi bunu disaridan degistiriyor (1.0 = normal tempo)
var spawn_carpani := 1.0
var guc_bolen := GUC_BOLEN
var tavan_artis := CANLI_TAVAN_ARTIS

var _spawn_sayaci := 0.0
var _hud: CanvasLayer
var _lbl_ust: Label
var _lbl_can: Label
var _isi_cubuk: ColorRect
var _isi_yazi: Label
var _lbl_silah: Label
var karanlik: CanvasLayer
var _kart_katman: CanvasLayer
var _bekleyen_kart := 0
## Alinan kartlar: ad -> {"sayi": int, "ikon": String, "aciklama": String}
var alinan_kartlar := {}
var _build_kutu: HBoxContainer
var _duraklat_katman: CanvasLayer

func _ready() -> void:
    SesYonetici.yukle_klasorden()
    SesYonetici.muzik_cal()
    _arena_kur()
    _lekeler()
    _yapilari_dog()
    _karanlik_kur()
    _hud_kur()
    if OS.is_debug_build():
        var g := GelistiriciSahne.new()
        g.ana = self
        add_child(g)
    oyuncu.oldu.connect(_oyun_bitti)
    oyuncu.can_degisti.connect(func(c, m): _lbl_can.text = "CAN  " + "*".repeat(max(c, 0)) + "-".repeat(max(m - c, 0)))
    oyuncu.can_degisti.emit(oyuncu.can, oyuncu.maks_can)
    oyuncu.silah_degisti.connect(func(ad, _i):
        var ek := "   [Q]" if oyuncu.acik_silahlar.size() > 1 else ""
        _lbl_silah.text = "◤ " + str(ad) + ek)
    oyuncu.silah_degisti.emit(oyuncu.silah(), oyuncu.silah_indeksi)

func _unhandled_key_input(olay: InputEvent) -> void:
    if not olay.is_pressed() or olay.is_echo():
        return
    if (olay as InputEventKey).keycode == KEY_ESCAPE and not bitti:
        _duraklat_degis()

## ESC duraklatma. Kart ekrani aciksa karismiyor -- o zaten duraklatmis
## durumda ve kendi kararini bekliyor.
func _duraklat_degis() -> void:
    if _kart_katman != null and is_instance_valid(_kart_katman):
        return
    if _duraklat_katman != null and is_instance_valid(_duraklat_katman):
        _duraklat_katman.queue_free()
        _duraklat_katman = null
        get_tree().paused = false
        return
    _duraklat_katman = _panel_kur("DURAKLATILDI", _ozet_satirlari(false),
        "ESC devam   ·   R yeniden basla")
    get_tree().paused = true

## Duraklatma ve olum ekrani ayni govdeyi kullaniyor.
func _panel_kur(baslik: String, satirlar: Array, alt: String) -> CanvasLayer:
    var k := CanvasLayer.new()
    k.layer = 4
    k.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(k)
    var fon := ColorRect.new()
    fon.color = Color(0.01, 0.01, 0.03, 0.82)
    fon.set_anchors_preset(Control.PRESET_FULL_RECT)
    k.add_child(fon)
    var kutu := VBoxContainer.new()
    kutu.position = Vector2(56, 52)
    kutu.add_theme_constant_override("separation", 5)
    k.add_child(kutu)
    kutu.add_child(_panel_yazi(baslik, 16, Color(1, 1, 1)))
    for satir in satirlar:
        kutu.add_child(_panel_yazi(str(satir), 8, Color(1, 1, 1)))
    kutu.add_child(_panel_yazi("", 8, Color(1, 1, 1)))
    kutu.add_child(_panel_yazi(alt, 8, Color(1.0, 0.82, 0.45)))
    return k

func _panel_yazi(metin: String, boy: int, renk: Color) -> Label:
    var l := Label.new()
    l.add_theme_font_override("font", YAZI_TIPI)
    l.add_theme_font_size_override("font_size", boy)
    l.modulate = renk
    l.text = metin
    return l

## Kosu ozeti. Olumde ve duraklatmada ayni bilgi -- oyuncu neyi nasil
## yaptigini gorsun.
func _ozet_satirlari(olum: bool) -> Array:
    var s: Array = []
    s.append("sure %02d:%02d    seviye %d    oldurme %d" % [
        int(gecen) / 60, int(gecen) % 60, seviye, oldurulen])
    s.append("silah %s    acik %d/4" % [oyuncu.silah(), oyuncu.acik_silahlar.size()])
    s.append("")
    if alinan_kartlar.is_empty():
        s.append("kart alinmadi")
    else:
        s.append("BUILD")
        for ad in alinan_kartlar:
            var b: Dictionary = alinan_kartlar[ad]
            var sayi: int = int(b["sayi"])
            s.append("  %s%s   %s" % [ad, (" x%d" % sayi) if sayi > 1 else "", b["aciklama"]])
    if olum:
        s.append("")
        s.append("dakikada %.1f oldurme    seviye basina %.0f sn" % [
            oldurulen / maxf(gecen / 60.0, 0.01), gecen / maxf(float(seviye), 1.0)])
    return s

func _process(delta: float) -> void:
    if bitti:
        if Input.is_key_pressed(KEY_R):
            get_tree().reload_current_scene()
        return

    gecen += delta
    _spawn_sayaci -= delta
    if _spawn_sayaci <= 0.0:
        _spawn_sayaci = maxf(SPAWN_BAS - gecen * SPAWN_AZALMA, SPAWN_TABAN) * spawn_carpani
        if _canli_dusman() < canli_tavan():
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

## Isi = gorus. Oyunun ayrisma noktasi; ayrinti karanlik.gd icinde.
func _karanlik_kur() -> void:
    karanlik = KaranlikSahne.new()
    karanlik.oyuncu = oyuncu
    add_child(karanlik)

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

## Zemine is/kurum lekeleri serp -- duz kahverengi bir deniz kalmasin.
func _lekeler() -> void:
    var katman := Node2D.new()
    katman.z_index = -4
    add_child(katman)
    for n in 46:
        var leke := Polygon2D.new()
        var r := randf_range(5.0, 17.0)
        var noktalar := PackedVector2Array()
        for a in 8:
            var ac := TAU * a / 8.0
            var yc := r * randf_range(0.55, 1.0)
            noktalar.append(Vector2(cos(ac) * yc, sin(ac) * yc * 0.55))
        leke.polygon = noktalar
        leke.color = Color(0.05, 0.03, 0.02, randf_range(0.10, 0.26))
        leke.position = Vector2(randf_range(24, 616), randf_range(24, 330))
        katman.add_child(leke)

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

## Ayni anda yasayabilecek dusman sayisi. Zorluk buradan degil, dusmanin
## gucunden ve turunden geliyor.
func canli_tavan() -> int:
    return mini(CANLI_TAVAN_BAS + int(gecen * tavan_artis), CANLI_TAVAN_UST)

func _canli_dusman() -> int:
    return get_tree().get_nodes_in_group("dusman").size()

func _dusman_dog() -> void:
    var d := DusmanSahne.instantiate()
    d.kur(_tur_sec(), 1.0 + gecen / guc_bolen)
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
        SesYonetici.cal("seviye")
    # Ayni karede iki seviye gelirse kart kaybolmasin: sirayla acilirlar
    if _bekleyen_kart > 0 and _kart_katman == null:
        _kartlari_ac()

# --- Kartlar ----------------------------------------------------------------

func _kart_havuzu() -> Array:
    var liste := [
        {"ad": "GENİŞ KAZAN", "aciklama": "Isı tavanı +25", "ikon": "kazan",
            "uygula": func(o): o.isi.tavan += 25.0},
        {"ad": "SOĞUK HAT", "aciklama": "Soğuma hızı +%35", "ikon": "soguk",
            "uygula": func(o): o.isi.soguma_hizi *= 1.35},
        {"ad": "HIZLI TETİK", "aciklama": "Atış hızı +%20, ısı +%12", "ikon": "tetik", "uygula": func(o):
            o.atis_hizi_carpani *= 1.2
            o.isi_carpani *= 1.12},
        {"ad": "AĞIR MERMİ", "aciklama": "Hasar +%40, ısı +%18", "ikon": "agir", "uygula": func(o):
            o.mermi_hasari *= 1.4
            o.isi_carpani *= 1.18},
        {"ad": "ÇATAL NAMLU", "aciklama": "+1 mermi, ısı +%25", "ikon": "catal", "uygula": func(o):
            o.ek_mermi += 1
            o.ek_yayilma += 0.06
            o.isi_carpani *= 1.25},
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
    # Sahip olunmayan silahlar kart olarak cikar -- alinca Q ile gecilir
    for i in range(1, Silahlar.LISTE.size()):
        if i in oyuncu.acik_silahlar:
            continue
        var sl: Dictionary = Silahlar.LISTE[i]
        liste.append({
            "ad": "SİLAH: " + str(sl["ad"]), "aciklama": str(sl["not"]),
            "ikon": str(sl["ikon"]), "silah": i,
            "uygula": func(o): o.silah_ver(i),
        })
    return liste

func _kartlari_ac() -> void:
    var havuz := _kart_havuzu()
    havuz.shuffle()
    var secilen := havuz.slice(0, 3)

    _kart_katman = CanvasLayer.new()
    _kart_katman.layer = 3
    _kart_katman.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(_kart_katman)

    var fon := ColorRect.new()
    fon.color = Color(0, 0, 0, 0.72)
    fon.set_anchors_preset(Control.PRESET_FULL_RECT)
    _kart_katman.add_child(fon)

    var kutu := VBoxContainer.new()
    kutu.position = Vector2(60, 84)
    kutu.custom_minimum_size = Vector2(520, 0)
    kutu.add_theme_constant_override("separation", 8)
    _kart_katman.add_child(kutu)

    var baslik := Label.new()
    baslik.add_theme_font_override("font", YAZI_TIPI)
    baslik.add_theme_font_size_override("font_size", 16)
    baslik.text = "SEVİYE %d  —  bir kart seç" % seviye
    kutu.add_child(baslik)

    for k in secilen:
        var b := Button.new()
        b.add_theme_font_override("font", YAZI_TIPI)
        b.add_theme_font_size_override("font_size", 8)
        b.custom_minimum_size = Vector2(520, 44)
        b.icon = load("res://assets/sprites/ikon_%s.png" % k["ikon"])
        b.expand_icon = false
        b.text = "  %s\n  %s" % [k["ad"], k["aciklama"]]
        b.pressed.connect(_kart_secildi.bind(k))
        kutu.add_child(b)

    get_tree().paused = true
    kutu.get_child(1).grab_focus()

func _kart_secildi(kart: Dictionary) -> void:
    SesYonetici.cal("kart_sec")
    var uygula: Callable = kart["uygula"]
    uygula.call(oyuncu)
    var ad: String = str(kart["ad"])
    if alinan_kartlar.has(ad):
        alinan_kartlar[ad]["sayi"] += 1
    else:
        alinan_kartlar[ad] = {"sayi": 1, "ikon": str(kart["ikon"]),
            "aciklama": str(kart["aciklama"])}
    _build_tazele()
    _bekleyen_kart -= 1
    _kart_katman.queue_free()
    _kart_katman = null
    if _bekleyen_kart > 0:
        _kartlari_ac()
    else:
        get_tree().paused = false

# --- HUD --------------------------------------------------------------------

func _hud_kur() -> void:
    _vinyet_kur()
    _hud = CanvasLayer.new()
    _hud.layer = 2          # karanlik 1'de, HUD onun ustunde
    add_child(_hud)

    _lbl_ust = _yazi(8)
    _lbl_ust.position = Vector2(10, 4)

    _lbl_can = _yazi(8)
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

    _isi_yazi = _yazi(8)
    _isi_yazi.position = Vector2(134, 33)

    _lbl_silah = _yazi(8)
    _lbl_silah.position = Vector2(10, 48)
    _lbl_silah.modulate = Color(1.0, 0.82, 0.45)

    # Build seridi -- oyuncu ne aldigini GORSUN. VS'te bile var, bizde yoktu.
    _build_kutu = HBoxContainer.new()
    _build_kutu.position = Vector2(640 - 12, 6)
    _build_kutu.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    _build_kutu.add_theme_constant_override("separation", 3)
    _hud.add_child(_build_kutu)

    var ipucu := _yazi(8)
    ipucu.position = Vector2(10, 330)
    ipucu.modulate = Color(1, 1, 1, 0.55)
    ipucu.text = "WASD  SOL TIK ateş  SAĞ TIK kor  BOŞLUK dalış  Q silah"

## Kenarlari karartan vinyet -- arenayi bir dokumhane cukuru gibi gosterir.
func _vinyet_kur() -> void:
    var k := CanvasLayer.new()
    k.layer = -1
    add_child(k)
    var t := TextureRect.new()
    t.texture = Hiss.parlama_dokusu(Color(0, 0, 0, 0), Color(0.03, 0.01, 0.0, 0.75), 128)
    t.set_anchors_preset(Control.PRESET_FULL_RECT)
    t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    t.stretch_mode = TextureRect.STRETCH_SCALE
    t.mouse_filter = Control.MOUSE_FILTER_IGNORE
    k.add_child(t)

## HUD yazilari. PublicPixel 8x8 bir pixel font: boyut 8'in kati olmali,
## ara degerlerde piksel izgarasi bozulup bulaniyor.
## Alinan kartlari sag ust seride ikon + sayac olarak goster.
func _build_tazele() -> void:
    if _build_kutu == null:
        return
    for c in _build_kutu.get_children():
        c.queue_free()
    for ad in alinan_kartlar:
        var bilgi: Dictionary = alinan_kartlar[ad]
        var kutu := VBoxContainer.new()
        kutu.add_theme_constant_override("separation", 0)
        var res := TextureRect.new()
        res.texture = load("res://assets/sprites/ikon_%s.png" % bilgi["ikon"])
        res.custom_minimum_size = Vector2(14, 14)
        res.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        res.tooltip_text = "%s  %s" % [ad, bilgi["aciklama"]]
        kutu.add_child(res)
        if int(bilgi["sayi"]) > 1:
            var sy := Label.new()
            sy.add_theme_font_override("font", YAZI_TIPI)
            sy.add_theme_font_size_override("font_size", 8)
            sy.text = "x%d" % int(bilgi["sayi"])
            sy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            kutu.add_child(sy)
        _build_kutu.add_child(kutu)

func _yazi(boy: int) -> Label:
    var l := Label.new()
    l.add_theme_font_override("font", YAZI_TIPI)
    l.add_theme_font_size_override("font_size", boy)
    _hud.add_child(l)
    return l

func _oyun_bitti() -> void:
    bitti = true
    SesYonetici.muzik_dur()
    SesYonetici.cal("asiri_isinma")
    _panel_kur("SÖNDÜN", _ozet_satirlari(true), "R ile yeniden başla")
    for d in get_tree().get_nodes_in_group("dusman"):
        d.queue_free()
