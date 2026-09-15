extends SceneTree
## KOSU YASAM DONGUSU. Tek tek sistemler test ediliyordu ama oyuncunun
## gercekte izledigi YOL hic test edilmemisti:
##   menu -> kosu -> olum -> ozet -> yeniden basla -> menu
## ve gorev odulunun SONRAKI kosuda gercekten gelip gelmedigi.
##
## Bu sinifta bir hata sessiz olur: her parca kendi basina calisir, zincir
## kopuk olur. Ornegin gorev acilir ama odul uygulanmazsa hicbir test patlamaz.
##
##   godot --headless --script res://tests/test_akis.gd

var _asama := 0
var _kare := 0
var _hata := 0
var _ana: Node
var _kayit: Node

func _yaz(ok: bool, mesaj: String) -> void:
    if not ok:
        print("HATA: ", mesaj)
        _hata = 1

func _process(_delta: float) -> bool:
    _kare += 1
    if _kare < 40:      # 0,66 sn -- spawn sayacinin donmesine yetiyor
        return false
    _kare = 0
    match _asama:
        0:
            _kayit = root.get_node_or_null("Kayit")
            if _kayit == null:
                print("HATA: Kayit autoload yok"); quit(1); return true
            # Temiz baslangic: acilan gorev yok
            _kayit._veri["acilanlar"] = []
            _kayit._veri["en_iyi_curuf"] = 0
            _kayit.kademe_yaz(0)
            _kayit.kaydet()
            _ana = load("res://scenes/menu.tscn").instantiate()
            root.add_child(_ana)
        1:
            _yaz(_ana.has_method("_basla"), "menude baslatma yok")
            _yaz(_ana.has_method("_gunluk_basla"), "menude gunun dokumu yok")
            _ana.queue_free()
            _ana = load("res://scenes/level.tscn").instantiate()
            root.add_child(_ana)
        2:
            # SESSIZ ACILIS: ilk atisa kadar suru dogmamali.
            # Olculdu: bu olmadan hic girdi vermeyen oyuncu 12,7 sn
            # yasiyordu; acilis bir KESIF ani olarak tasarlandigi halde
            # oyuncu kesfederken yeniyordu. 22,8 sn'ye cikti.
            _yaz(not _ana.oyuncu.hic_ates, "on kosul: henuz ates edilmemis olmali")
            _yaz(_ana.gecen < _ana.ACILIS_SESSIZLIGI, "on kosul: hala acilis penceresinde")
            _yaz(get_nodes_in_group("dusman").size() == 0,
                "ilk atistan once dusman dogmamali: %d" % get_nodes_in_group("dusman").size())
            # Ates edince suru uyanmali
            _ana.oyuncu._ates_et(Vector2.RIGHT)
            _yaz(_ana.oyuncu.hic_ates, "ates bayragi kalkmadi")
        3:
            if get_nodes_in_group("dusman").size() == 0 and _ana.gecen < 4.0:
                return false      # oyun zamani bekle, kare degil
            _yaz(get_nodes_in_group("dusman").size() > 0,
                "atistan sonra suru uyanmali (gecen %.2f sn)" % _ana.gecen)
            # Gorevi ELDE tamamla: patron dustu + kosu bitti
            _ana.gorevler.patron_dustu()
            _ana.oyuncu.can = 1
            _ana.oyuncu.hasar_al(99.0)
        4:
            _yaz(_ana.bitti, "olum tetiklenmedi")
            _yaz(_ana.acilan_gorevler.size() > 0, "gorev acilmadi (patron dustu)")
            _yaz(_kayit.acik("kademe_1"), "acilan gorev KAYDA yazilmadi")
            _yaz(_kayit.en_iyi_curuf() >= 0, "en iyi dokum kaydedilmedi")
            # Ozet paneli gercekten kuruldu mu
            var panel := false
            for c in _ana.get_children():
                if c is CanvasLayer and c.layer == 5:
                    panel = true
            _yaz(panel, "olum ozet paneli kurulmadi")
            _ana.queue_free()
            _ana = load("res://scenes/level.tscn").instantiate()
            root.add_child(_ana)
        5:
            # ODUL ZINCIRI: acilan gorev SONRAKI kosuda uygulanmali
            _yaz(_ana.yakma_hakki >= 4,
                "gorev odulu (+1 yakma hakki) sonraki kosuda gelmedi: %d" % _ana.yakma_hakki)
            _ana.queue_free()
            _ana = load("res://scenes/menu.tscn").instantiate()
            root.add_child(_ana)
        6:
            # Menu acilan gorevi gosteriyor mu
            _ana._gorev_degis()
        7:
            var bulundu := false
            for c in _ana.get_children():
                if c is CanvasLayer and c.layer == 5:
                    bulundu = true
            _yaz(bulundu, "gorev ekrani acilmadi")
            _kayit._veri["acilanlar"] = []
            _kayit.kaydet()
            if _hata == 0:
                print("TAMAM akis: menu -> kosu -> olum -> odul -> sonraki kosu -> menu")
            quit(_hata)
            return true
    _asama += 1
    return false
