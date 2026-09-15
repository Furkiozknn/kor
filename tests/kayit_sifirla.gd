extends SceneTree
## Bot calistirmalarindan kirlenen kaydi sifirlar.
func _process(_d: float) -> bool:
    var k := root.get_node_or_null("Kayit")
    if k == null:
        print("HATA: Kayit yok"); quit(1); return true
    print("once: curuf=%d en_iyi_sure=%.0f en_iyi_oldurme=%d kademe=%d" % [
        k.curuf(), float(k._veri.get("en_iyi_sure", 0.0)),
        int(k._veri.get("en_iyi_oldurme", 0)), k.kademe()])
    k._veri["curuf"] = 0
    k._veri["en_iyi_sure"] = 0.0
    k._veri["en_iyi_oldurme"] = 0
    k.kademe_yaz(0)
    k.kaydet()
    print("TAMAM kayit sifirlandi")
    quit(0)
    return true
