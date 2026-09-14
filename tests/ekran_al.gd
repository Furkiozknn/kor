extends SceneTree
## Gerçek bir render alıp PNG'ye yazar -- görsel doğrulama için.
## godot --script res://tests/ekran_al.gd   (headless DEĞİL)

const CIKTI := "D:/Claude Projeleri/gecici/kor-ekran.png"
const CIKTI_KART := "D:/Claude Projeleri/gecici/kor-kart.png"

## `godot --script res://tests/ekran_al.gd -- --kart` ile kart ekranini cek
var _kart_modu := "--kart" in OS.get_cmdline_user_args()
## Isi = gorus kanitI: ayni sahne soguk ve sicak halde
var _gorus_modu := "--gorus" in OS.get_cmdline_user_args()
## Olum/duraklatma ozet panelini cek
var _ozet_modu := "--ozet" in OS.get_cmdline_user_args()
var _menu_modu := "--menu" in OS.get_cmdline_user_args()

var _ana: Node2D
var _kare := 0

func _initialize() -> void:
    var yol := "res://scenes/menu.tscn" if _menu_modu else "res://scenes/level.tscn"
    _ana = load(yol).instantiate()
    root.add_child(_ana)

func _process(_delta: float) -> bool:
    if _menu_modu:
        _kare += 1
        if _kare < 120:
            return false
        RenderingServer.force_draw()
        root.get_texture().get_image().save_png("D:/Claude Projeleri/gecici/kor-menu.png")
        print("menu: kor-menu.png")
        return true

    _kare += 1
    # Isi çubuğu ve mermiler görünsün diye ateş ettir
    if _kare == 80 and not _gorus_modu:
        _ana.oyuncu.silah_ver(1)          # SACMA -- cok mermi gorunsun
    if not _gorus_modu and _kare > 90 and _kare < 200 and _kare % 9 == 0:
        _ana.oyuncu._ates_et(Vector2.RIGHT.rotated(randf() * TAU))
    if _kare == 180:
        # Gercek girdi taklidi: yuruyus animasyonu calissin
        Input.action_press("move_right")
        Input.action_press("move_down")
    if _kare == 210:
        # Kor atisi gorunsun: isiyi esigin ustune getir, sonra at
        var o = _ana.oyuncu
        # Demo icin kilidi elle sifirla -- oyunda dalis bunu YAPAMAZ,
        # kilit sadece suresi dolunca cozulur.
        o.isi.kilitli = false
        o.isi.deger = 0.0
        o._kor_bekleme = 0.0
        while o.isi.oran() < 0.75 and not o.isi.kilitli:
            o.isi.ates_et()
    if _kare == 248:
        # Bir dusmani oldur -- olum patlamasi ve kul zerreleri gorunsun
        var liste := get_nodes_in_group("dusman")
        if liste.size() > 0:
            liste[0].hasar_al(9999.0, Vector2.RIGHT * 90.0)
    if _kare == 252:
        _ana.oyuncu._kor_at(Vector2.RIGHT)
    if _kare == 256:
        _ana.oyuncu._ates_et(Vector2.RIGHT.rotated(-0.5))
    if _kare == 235:
        # Bes turu de yan yana koy ki hepsi tek karede gorunsun
        for t in 6:
            var d = _ana.DusmanSahne.instantiate()
            d.kur(t, 1.0)
            d.global_position = _ana.oyuncu.global_position + Vector2(-85 + t * 34, -54)
            _ana.add_child(d)
    if _ozet_modu:
        if _kare == 100:
            for n in 4:
                _ana._xp_topla(_ana.xp_hedef)
                var kk = _ana.get("_kart_katman")
                if kk != null and is_instance_valid(kk):
                    for kat in kk.get_children():
                        for c in kat.get_children():
                            if c is Button:
                                c.pressed.emit()
                                break
        if _kare == 130:
            _ana.oyuncu.hasar_al(99.0)
        if _kare == 160:
            RenderingServer.force_draw()
            root.get_texture().get_image().save_png("D:/Claude Projeleri/gecici/kor-ozet.png")
            print("ozet paneli: kor-ozet.png")
            return true
        return false
    if _gorus_modu:
        var o = _ana.oyuncu
        if _kare == 150:
            o.isi.kilitli = false
            o.isi.deger = 0.0
        if _kare == 170:
            RenderingServer.force_draw()
            root.get_texture().get_image().save_png("D:/Claude Projeleri/gecici/kor-soguk.png")
        if _kare == 172:
            o.isi.deger = o.isi.tavan * 0.95
        if _kare == 210:
            RenderingServer.force_draw()
            root.get_texture().get_image().save_png("D:/Claude Projeleri/gecici/kor-sicak.png")
            o.isi.kilitle()
        if _kare == 240:
            RenderingServer.force_draw()
            root.get_texture().get_image().save_png("D:/Claude Projeleri/gecici/kor-kilit.png")
            print("gorus: soguk + sicak + kilit")
            return true
        return false
    if _kart_modu and _kare == 120:
        _ana._xp_topla(_ana.xp_hedef)      # seviye kartlarini ac
    if _kart_modu and _kare == 150:
        RenderingServer.force_draw()
        root.get_texture().get_image().save_png(CIKTI_KART)
        print("kart ekrani: %s" % CIKTI_KART)
        return true
    if _kare < 260:
        return false
    RenderingServer.force_draw()
    var img := root.get_texture().get_image()
    img.save_png(CIKTI)
    print("ekran: %s  (%dx%d, dusman=%d, isi=%.0f)" % [
        CIKTI, img.get_width(), img.get_height(),
        get_nodes_in_group("dusman").size(), _ana.oyuncu.isi.deger])
    return true
