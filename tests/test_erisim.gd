extends SceneTree
## godot --headless --script res://tests/test_erisim.gd
##
## Accessibility options for light-based information (scripts/erisim.gd):
## the cold-sight floor and calm (non-blinking) warnings. Pure rules first,
## then the settings row in the real menu scene.

const Erisim := preload("res://scripts/erisim.gd")
const Isi := preload("res://scripts/isi.gd")
const KaranlikSahne := preload("res://scripts/karanlik.gd")
const KayitBetik := preload("res://scripts/kayit.gd")

var _hata := 0
var _sayac := 0
var _menu: Node
var _kare := 0
var _eski_taban: Variant
var _eski_sakin: Variant

func dogru(kosul: bool, ad: String) -> void:
    _sayac += 1
    if not kosul:
        _hata += 1
        printerr("  [HATA] ", ad)

func _initialize() -> void:
    _varsayilanlar()
    _gorus_tabani()
    _sakin_isik()
    _menu = load("res://scenes/menu.tscn").instantiate()
    root.add_child(_menu)

func _process(_delta: float) -> bool:
    _kare += 1
    if _kare == 2:
        # The Kayit autoload loads the save in its _ready, after _initialize.
        var kayit := root.get_node_or_null("Kayit")
        dogru(kayit != null, "Kayit autoload is available")
        _eski_taban = kayit.ayar("gorus_tabani", 0)
        _eski_sakin = kayit.ayar("sakin_isik", false)
        kayit.ayar_yaz("gorus_tabani", 0)
        kayit.ayar_yaz("sakin_isik", false)
    if _kare == 5:
        _menu._ayar_degis()
    if _kare < 12:
        return false
    _menu_satiri()
    var kayit := root.get_node("Kayit")
    kayit.ayar_yaz("gorus_tabani", _eski_taban)
    kayit.ayar_yaz("sakin_isik", _eski_sakin)
    kayit.kaydet()
    if _hata > 0:
        printerr("test_erisim: %d/%d BOZUK" % [_hata, _sayac])
        quit(1)
    else:
        print("test_erisim: TAMAM (%d kural)" % _sayac)
        quit(0)
    return true

func _varsayilanlar() -> void:
    var a: Dictionary = KayitBetik.VARSAYILAN["ayarlar"]
    dogru(int(a.get("gorus_tabani", -1)) == 0 and a.get("sakin_isik", true) == false,
        "both options are off by default: the core rule is unchanged unless the player asks")

func _yaricap(o: Node2D, k, oran: float) -> float:
    o.isi.deger = o.isi.tavan * oran
    return k._oyuncu_yaricapi()

func _gorus_tabani() -> void:
    dogru(Erisim.gorus_tabani_ek(0) == 0.0 and Erisim.gorus_tabani_ek(1) == 32.0 and Erisim.gorus_tabani_ek(2) == 64.0,
        "floor steps: +0, +32, +64 px")
    dogru(Erisim.gorus_tabani_ek(-3) == 0.0 and Erisim.gorus_tabani_ek(9) == 64.0, "a broken setting clamps instead of crashing")
    dogru(Erisim.gorus_tabani_sonraki(0) == 1 and Erisim.gorus_tabani_sonraki(2) == 0, "the button cycles back to normal")

    var tutucu := GDScript.new()
    tutucu.source_code = "extends Node2D\nvar isi\n"
    tutucu.reload()
    var o: Node2D = tutucu.new()
    o.isi = Isi.new()
    var k = KaranlikSahne.new()
    k.oyuncu = o
    var normal_soguk := _yaricap(o, k, 0.0)
    var normal_sicak := _yaricap(o, k, 1.0)
    k.taban_yaricap += Erisim.gorus_tabani_ek(2)
    var genis_soguk := _yaricap(o, k, 0.0)
    var genis_sicak := _yaricap(o, k, 1.0)
    dogru(is_equal_approx(genis_soguk, normal_soguk + 64.0), "floor +64: cold sight 40 -> 104 px (%.0f)" % genis_soguk)
    dogru(is_equal_approx(genis_sicak, normal_sicak), "the hot end is unchanged: heat still opens the arena to the same 300 px")
    var monoton := true
    var onceki := 0.0
    for n in 21:
        var r := _yaricap(o, k, float(n) / 20.0)
        if r < onceki:
            monoton = false
        onceki = r
    dogru(monoton, "with the floor, sight still only grows with heat")
    dogru(_yaricap(o, k, 0.5) - genis_soguk > 0.0 and genis_sicak - genis_soguk >= 150.0,
        "heat still buys real sight with the widest floor (%.0f px of range)" % (genis_sicak - genis_soguk))
    k.gorus_carpani = 0.80   # furnace step 3, DAR GÖZ
    dogru(is_equal_approx(_yaricap(o, k, 0.0), 104.0 * 0.80), "furnace 3's narrow eye still applies on top of the floor")
    k.free()
    o.free()

func _sakin_isik() -> void:
    dogru(Erisim.flas_hz(Erisim.DOKUNULMAZ_YARI_MS) > Erisim.WCAG_FLAS_SINIRI_HZ
        and Erisim.flas_hz(Erisim.ISI_UYARI_YARI_MS) > Erisim.WCAG_FLAS_SINIRI_HZ,
        "documented: both default blinks are above 3 flashes/s (%.1f Hz, %.1f Hz), hence the option"
        % [Erisim.flas_hz(Erisim.DOKUNULMAZ_YARI_MS), Erisim.flas_hz(Erisim.ISI_UYARI_YARI_MS)])
    var dk := {}
    var iu := {}
    var dk_normal := {}
    for ms in range(0, 2000, 5):
        dk[Erisim.dokunulmaz_rengi(ms, true)] = true
        iu[Erisim.isi_uyari_rengi(ms, true)] = true
        dk_normal[Erisim.dokunulmaz_rengi(ms, false)] = true
    dogru(dk.size() == 1 and iu.size() == 1, "calm mode: no colour change over two seconds (no flashing at all)")
    dogru(dk_normal.size() == 2, "default mode still blinks between two colours")
    dogru(Erisim.DOKUNULMAZ_SAKIN != Color(1, 1, 1) and Erisim.DOKUNULMAZ_SAKIN.r > 1.5,
        "calm invulnerability keeps a distinct bright tint (meaning kept, blink removed)")
    dogru(Erisim.ISI_UYARI_SAKIN != Color(0.35, 0.7, 1.0).lerp(Color(1.0, 0.3, 0.1), 0.85),
        "calm heat warning is still its own colour, not the normal gradient")
    for f in ["res://scripts/oyuncu.gd", "res://scripts/ana.gd"]:
        var kaynak := FileAccess.get_file_as_string(f)
        dogru(not kaynak.contains("get_ticks_msec() / 85") and not kaynak.contains("get_ticks_msec() / 70"),
            "%s: no blink timer left outside scripts/erisim.gd" % f.get_file())

func _menu_satiri() -> void:
    var kayit := root.get_node("Kayit")
    var taban: Button = _menu._taban_dugme
    var sakin: Button = _menu._sakin_dugme
    dogru(taban != null and sakin != null and taban.is_visible_in_tree() and sakin.is_visible_in_tree(),
        "settings screen shows the ERİŞİM row")
    if taban == null or sakin == null:
        return
    dogru(taban.text == "görüş tabanı normal" and sakin.text == "sakin ışık kapalı", "row starts at the defaults")
    taban.pressed.emit()
    dogru(int(kayit.ayar("gorus_tabani", 0)) == 1 and taban.text == "görüş tabanı +32", "floor button steps to +32")
    taban.pressed.emit()
    taban.pressed.emit()
    dogru(int(kayit.ayar("gorus_tabani", 0)) == 0, "floor button wraps back to normal")
    sakin.pressed.emit()
    dogru(bool(kayit.ayar("sakin_isik", false)) and sakin.text == "sakin ışık açık", "calm-lights button turns on")
