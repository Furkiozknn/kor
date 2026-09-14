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

    # harca(): isiyi hasara cevirme -- kilitliyken calismamali
    var j = Isi.new()
    for n in 5:
        j.ates_et()
    var once: float = j.deger
    var pay: float = j.harca(1.0)
    assert(pay > 0.0, "harca bir sey dondurmeli")
    assert(j.deger < once, "harca isiyi dusurmeli")
    assert(is_equal_approx(j.deger, 0.0), "tam maliyet isiyi sifirlar")
    for n in 5:
        j.ates_et()
    var yari_once: float = j.deger
    j.harca(0.5)
    assert(is_equal_approx(j.deger, yari_once * 0.5), "yarim maliyet yariyi birakir")
    for n in 12:
        j.ates_et()
    assert(j.kilitli)
    assert(is_equal_approx(j.harca(1.0), 0.0), "kilitliyken harcanamaz")

    # kilitle(): mangal tavana ittiginde ates etmekle ayni ceza
    var m = Isi.new()
    m.kilitle()
    assert(m.kilitli, "kilitle() kilitlemeli")
    assert(is_equal_approx(m.deger, m.tavan), "kilitle() isiyi tavana koymali")
    assert(m.harca(1.0) == 0.0, "kilitliyken harcanamaz")

    # hizli_sogu(): ors etkisi. Gecikmeyi atlar, normalden hizli soğutur.
    var o = Isi.new()
    var n = Isi.new()
    for x in 5:
        o.ates_et()
        n.ates_et()
    o.hizli_sogu(0.1, 2.6)
    n.guncelle(0.1)                      # gecikme icinde, sogumamali
    assert(o.deger < n.deger, "ors sogutmasi normalden hizli olmali")
    # kilitliyken ors de kurtarmaz
    for x in 12:
        o.ates_et()
    assert(o.kilitli)
    var kilit_degeri: float = o.deger
    o.hizli_sogu(0.5, 2.6)
    assert(is_equal_approx(o.deger, kilit_degeri), "kilitliyken ors islememeli")

    print("test_isi: TAMAM")
    quit(0)
