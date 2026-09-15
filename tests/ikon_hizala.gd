extends SceneTree
## Kart ikonlarini ortak tuvale hizalar.
##
## Sorun: 11 ikon, 7 farkli boyut (8x16'dan 14x16'ya). Kart ekraninda sabit
## genislikli bir sutunda duruyorlar, bu yuzden her biri farkli yukseklikte
## goruniyor -- sutun tarandiginda goz takiliyor.
##
## OLCEKLEME YOK: piksel verisi birebir kopyalanir, etrafina seffaf dolgu
## eklenir. Olceklemek pixel art'i bulanıklastirir.
##
## Dikeyde ALTA hizalanir: ikonlar nesne (cizme, ors, kazan); ortak bir
## zemine oturmalilar, ortalaninca havada duruyor gibi gorunuyorlar.
##
##   godot --headless --script res://tests/ikon_hizala.gd
##   godot --headless --script res://tests/ikon_hizala.gd -- --dene   (yazmaz)

const TUVAL := Vector2i(16, 16)
const KLASOR := "res://assets/sprites/"

func _init() -> void:
    var dene := "--dene" in OS.get_cmdline_user_args()
    var d := DirAccess.open(KLASOR)
    if d == null:
        print("HATA: klasor acilamadi")
        quit(1); return

    var degisen := 0
    for dosya in d.get_files():
        if not dosya.begins_with("ikon_") or not dosya.ends_with(".png"):
            continue
        var g := Image.load_from_file(KLASOR + dosya)
        if g == null:
            print("HATA: okunamadi ", dosya)
            continue
        var boy := g.get_size()
        if boy == TUVAL:
            continue
        if boy.x > TUVAL.x or boy.y > TUVAL.y:
            print("ATLANDI (tuvalden buyuk): %s %dx%d" % [dosya, boy.x, boy.y])
            continue

        g.convert(Image.FORMAT_RGBA8)
        var yeni := Image.create_empty(TUVAL.x, TUVAL.y, false, Image.FORMAT_RGBA8)
        yeni.fill(Color(0, 0, 0, 0))
        var hedef := Vector2i((TUVAL.x - boy.x) / 2, TUVAL.y - boy.y)   # yatay orta, dikey alt
        yeni.blit_rect(g, Rect2i(Vector2i.ZERO, boy), hedef)
        print("%-22s %2dx%-2d -> 16x16  (+%d,+%d)" % [dosya, boy.x, boy.y, hedef.x, hedef.y])
        if not dene:
            yeni.save_png(ProjectSettings.globalize_path(KLASOR + dosya))
        degisen += 1

    print("TAMAM ikon_hizala: %d dosya%s" % [degisen, "  (DENEME -- yazilmadi)" if dene else ""])
    quit(0)
