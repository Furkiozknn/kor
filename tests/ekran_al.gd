extends SceneTree
## Gerçek bir render alıp PNG'ye yazar -- görsel doğrulama için.
## godot --script res://tests/ekran_al.gd   (headless DEĞİL)

const CIKTI := "D:/Claude Projeleri/gecici/kor-ekran.png"

var _ana: Node2D
var _kare := 0

func _initialize() -> void:
    _ana = load("res://scenes/level.tscn").instantiate()
    root.add_child(_ana)

func _process(_delta: float) -> bool:
    _kare += 1
    # Isi çubuğu ve mermiler görünsün diye ateş ettir
    if _kare > 90 and _kare % 7 == 0:
        _ana.oyuncu._ates_et(Vector2.RIGHT.rotated(randf() * TAU))
    if _kare == 235:
        # Bes turu de yan yana koy ki hepsi tek karede gorunsun
        for t in 5:
            var d = _ana.DusmanSahne.instantiate()
            d.kur(t, 1.0)
            d.global_position = _ana.oyuncu.global_position + Vector2(-68 + t * 34, -54)
            _ana.add_child(d)
    if _kare < 260:
        return false
    RenderingServer.force_draw()
    var img := root.get_texture().get_image()
    img.save_png(CIKTI)
    print("ekran: %s  (%dx%d, dusman=%d, isi=%.0f)" % [
        CIKTI, img.get_width(), img.get_height(),
        get_nodes_in_group("dusman").size(), _ana.oyuncu.isi.deger])
    return true
