extends CanvasLayer
## Geliştirici katmanı. Sadece hata ayıklama derlemesinde çalışır; dışa
## aktarılan sürümde `_ready` erken dönüyor, hiçbir maliyeti yok.
##
## Amaç: elle test ederken "şu duruma nasıl gelirim" sorusunu ortadan
## kaldırmak. Dakika 5'teki dalgayı görmek için 5 dakika oynamak zorunda
## kalmak, geliştirmenin en yavaş yanı.
##
##   F1  katmanı aç/kapat        F6  ısıyı tavana çıkar
##   F2  karanlığı aç/kapat      F7  seviye atlat (kart ekranı)
##   F3  ölümsüzlük              F8  bütün silahları aç
##   F4  30 saniye ileri sar     F9  ekrandaki düşmanları temizle
##   F5  dalga doğur (x10)       +/- zamanı hızlandır/yavaşlat

const TUS_YARDIM := "F1 panel  F2 karanlik  F3 olumsuz  F4 +30sn  F5 dalga  F6 isi  F7 seviye  F8 silah  F9 temizle  +/- hiz"

var ana: Node2D

var _panel: PanelContainer
var _yazi: Label
var _acik := false
var _olumsuz := false
var _karanlik_kapali := false
var _fps_biriken := 0.0
var _fps_sayac := 0
var _fps := 0.0

func _ready() -> void:
    if not OS.is_debug_build():
        queue_free()
        return
    layer = 90
    process_mode = Node.PROCESS_MODE_ALWAYS
    _kur()

func _kur() -> void:
    _panel = PanelContainer.new()
    _panel.position = Vector2(8, 60)
    _panel.modulate = Color(1, 1, 1, 0.92)
    _panel.visible = false
    var st := StyleBoxFlat.new()
    st.bg_color = Color(0.02, 0.02, 0.05, 0.88)
    st.border_color = Color(1.0, 0.6, 0.2, 0.7)
    st.set_border_width_all(1)
    st.set_content_margin_all(6)
    _panel.add_theme_stylebox_override("panel", st)
    _yazi = Label.new()
    _yazi.add_theme_font_override("font", load("res://assets/fonts/PublicPixel.ttf"))
    _yazi.add_theme_font_size_override("font_size", 8)
    _panel.add_child(_yazi)
    add_child(_panel)

func _process(delta: float) -> void:
    _fps_biriken += delta
    _fps_sayac += 1
    if _fps_biriken >= 0.25:
        _fps = _fps_sayac / _fps_biriken
        _fps_biriken = 0.0
        _fps_sayac = 0
    if _acik:
        _tazele()

func _tazele() -> void:
    if not is_instance_valid(ana):
        _yazi.text = "sahne yok"
        return
    var o = ana.oyuncu
    var i = o.isi
    var kl := get_tree().get_first_node_in_group("karanlik")
    var gorus := 0.0
    if kl != null:
        gorus = kl._oyuncu_yaricapi()
    var s: Array[String] = []
    s.append("%.0f FPS   x%.2f hiz%s" % [_fps, Engine.time_scale,
        "   [OLUMSUZ]" if _olumsuz else ""])
    s.append("sure %.1f   seviye %d   xp %d/%d   oldurme %d" % [
        ana.gecen, ana.seviye, ana.xp, ana.xp_hedef, ana.oldurulen])
    s.append("isi %.0f/%.0f  %s  gorus %.0f px" % [
        i.deger, i.tavan, "KILITLI" if i.kilitli else "-", gorus])
    s.append("can %d/%d   silah %s (%d acik)" % [
        o.can, o.maks_can, o.silah(), o.acik_silahlar.size()])
    s.append("dusman %d   yapi %d   mermi %d" % [
        get_tree().get_nodes_in_group("dusman").size(),
        get_tree().get_nodes_in_group("yapi").size(),
        _mermi_sayisi()])
    s.append("evre '%s'   spawn %.2f sn   canli %d / tavan %d" % [
        ana.evre_adi, ana.Dalgalar.spawn_araligi(ana.gecen) * ana.spawn_carpani,
        get_tree().get_nodes_in_group("dusman").size(), ana.canli_tavan()])
    s.append("kart: " + (", ".join(PackedStringArray(ana.alinan_kartlar.keys())) if not ana.alinan_kartlar.is_empty() else "-"))
    s.append("")
    s.append(TUS_YARDIM)
    _yazi.text = "\n".join(s)

func _mermi_sayisi() -> int:
    if not is_instance_valid(ana):
        return 0
    var n := 0
    for c in ana.get_children():
        if c is Area2D:
            n += 1
    return n

func _unhandled_key_input(olay: InputEvent) -> void:
    if not olay.is_pressed() or olay.is_echo():
        return
    var k := (olay as InputEventKey).keycode
    match k:
        KEY_F1:
            _acik = not _acik
            _panel.visible = _acik
        KEY_F2:
            _karanlik_kapali = not _karanlik_kapali
            var kl := get_tree().get_first_node_in_group("karanlik")
            if kl != null:
                kl.visible = not _karanlik_kapali
        KEY_F3:
            _olumsuz = not _olumsuz
            if is_instance_valid(ana):
                ana.oyuncu.set_meta("olumsuz", _olumsuz)
        KEY_F4:
            if is_instance_valid(ana):
                ana.gecen += 30.0
        KEY_F5:
            if is_instance_valid(ana):
                for n in 10:
                    ana._dusman_dog()
        KEY_F6:
            if is_instance_valid(ana):
                ana.oyuncu.isi.deger = ana.oyuncu.isi.tavan * 0.99
        KEY_F7:
            if is_instance_valid(ana):
                ana._xp_topla(ana.xp_hedef)
        KEY_F8:
            if is_instance_valid(ana):
                for n in range(1, 4):
                    ana.oyuncu.silah_ver(n)
        KEY_F9:
            for d in get_tree().get_nodes_in_group("dusman"):
                d.queue_free()
        KEY_EQUAL, KEY_KP_ADD:
            Engine.time_scale = minf(Engine.time_scale * 1.5, 8.0)
        KEY_MINUS, KEY_KP_SUBTRACT:
            Engine.time_scale = maxf(Engine.time_scale / 1.5, 0.1)
        KEY_0, KEY_KP_0:
            Engine.time_scale = 1.0
