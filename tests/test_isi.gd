extends SceneTree
## godot --headless --script res://tests/test_isi.gd

const Isi := preload("res://scripts/isi.gd")

func _initialize() -> void:
    var i := Isi.new()

    # Tavana varana kadar ates -> kilit
    for n in 12:
        i.ates_et()
    assert(i.kilitli, "tavan asilinca kilitlenmeli")
    assert(is_equal_approx(i.deger, i.tavan), "kilitte isi tavanda baslar")

    # Kilitliyken dalis kurtarmaz
    assert(i.bosalt() == false, "kilitliyken dalis isiyi bosaltamaz")
    assert(i.kilitli, "dalis kilidi kirmamali")

    # Kilit sureyle cozulur ve isi sifirlanir
    i.guncelle(i.kilit_suresi + 0.01)
    assert(not i.kilitli, "kilit suresi dolunca cozulmeli")
    assert(is_equal_approx(i.deger, 0.0), "kilit cozulunce isi sifir")

    # Normalde dalis bosaltir
    i.ates_et()
    i.ates_et()
    assert(i.deger > 0.0)
    assert(i.bosalt(), "kilitsizken dalis bosaltmali")
    assert(is_equal_approx(i.deger, 0.0))

    # Ates ettikten hemen sonra sogumaz (gecikme), gecikme bitince soguma baslar
    i.ates_et()
    var d := i.deger
    i.guncelle(0.1)
    assert(is_equal_approx(i.deger, d), "gecikme icinde sogumamali")
    i.guncelle(i.soguma_gecikmesi)
    i.guncelle(0.5)
    assert(i.deger < d, "gecikme bitince sogumali")

    print("test_isi: TAMAM")
    quit(0)
