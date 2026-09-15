extends SceneTree
## itch GIF'i: karanliktan sicaga acilan gorus. Isi 0'dan tavana ramp
## edilirken her kare PNG olarak yazilir; sonra ffmpeg birlestirir.
##
##   godot --script res://tests/gif_cek.gd        (headless DEGIL)

const KLASOR := "KARE_KLASORU_BURAYA"
const ISINMA := 110       # sahne otursun, dusmanlar dogsun
const KARE := 90          # ~4.5 sn @ 20fps (60 fizik karesinden ornekle)
const ORNEK := 3          # her 3 karede bir yaz -> 20 fps

var _ana: Node2D
var _k := 0
var _yazilan := 0

func _initialize() -> void:
    DisplayServer.window_set_size(Vector2i(640, 360))
    _ana = load("res://scenes/level.tscn").instantiate()
    root.add_child(_ana)
    DirAccess.make_dir_recursive_absolute(KLASOR)
    print("gif cekimi basliyor -> ", KLASOR)

func _process(_d: float) -> bool:
    _k += 1
    var o = _ana.get("oyuncu")
    if o == null:
        return false
    o.can = 99
    if _k < ISINMA:
        o.isi.deger = 0.0                       # isinmada soguk tut
        return false
    var t := float(_k - ISINMA) / float(KARE * ORNEK)
    if t > 1.0:
        print("bitti: %d kare" % _yazilan)
        quit()
        return true
    # Isi 0 -> tavan: gorus acilir. Son ceyrekte tavanda tut.
    o.isi.deger = o.isi.tavan * clampf(t * 1.35, 0.0, 0.99)
    o.isi.kilitli = false
    if (_k - ISINMA) % ORNEK == 0:
        var img := root.get_texture().get_image()
        img.resize(640, 360, Image.INTERPOLATE_NEAREST)
        img.save_png("%s/k%03d.png" % [KLASOR, _yazilan])
        _yazilan += 1
    return false
