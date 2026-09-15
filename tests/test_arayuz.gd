extends SceneTree
## ARAYUZ TASMA TESTI.
##
## Neden var: ayni hatayi uc kez elle duzelttim -- menudeki ipucu satiri,
## kart ekranindaki "bir kart sec", duyuru etiketi. Hepsinin koku ayni:
## SABIT KONUM + icerige gore buyuyen genislik. 640x360'lik bir ekranda
## Turkce metin (uzun kelimeler) kolayca tasiyor ve kimse fark etmiyor
## cunku ekran goruntusu alinmadikca gorunmuyor.
##
## Tek tek duzeltmek yerine SINIFI kapatiyoruz: her ekrani kur, Control
## agacini gez, ekran disina tasan gorunur elemani bildir.
##
##   godot --script res://tests/test_arayuz.gd        (headless DEGIL: yerlesim gerekiyor)

const EKRAN := Vector2(640.0, 360.0)
const TOLERANS := 0.5      # yuvarlama payi

var _ana: Node
var _kare := 0
var _asama := 0
var _hata := 0
var _rapor: Array[String] = []

func _initialize() -> void:
    _ana = load("res://scenes/menu.tscn").instantiate()
    root.add_child(_ana)

func _process(_delta: float) -> bool:
    _kare += 1
    # Yerlesimin oturmasi icin birkac kare bekle: Container'lar ilk karede
    # henuz boyut vermemis oluyor, olcum sifir cikar.
    if _kare < 22:
        return false
    _kare = 0
    match _asama:
        0:
            _tara("MENU", _ana)
            _ana._gorev_degis()
        1:
            _tara("GÖREV EKRANI", _ana)
            _ana._gorev_degis()
            _gec("res://scenes/level.tscn")
        2:
            _tara("OYUN HUD", _ana)
            _ana._xp_topla(_ana.xp_hedef)      # kart ekrani acilsin
        3:
            _tara("KART EKRANI", _ana)
            for d in _dugme_ara(_ana):         # karti sec, ekran kapansin
                d.pressed.emit()
                break
            _ana._duraklat_degis()
        4:
            _tara("DURAKLATMA", _ana)
            _ana._duraklat_degis()
            _ana._oyun_bitti()
        5:
            _tara("OLUM EKRANI", _ana)
            return _bitir()
    _asama += 1
    return false

## Kart secim dugmesini agacta derinlemesine ara (yakma dugmesi degil).
func _dugme_ara(n: Node) -> Array[Button]:
    var liste: Array[Button] = []
    if n is Button and n.has_meta("kart_secim"):
        liste.append(n)
    for c in n.get_children():
        liste.append_array(_dugme_ara(c))
    return liste

func _gec(yol: String) -> void:
    _ana.queue_free()
    _ana = load(yol).instantiate()
    root.add_child(_ana)

func _bitir() -> bool:
    for satir in _rapor:
        print(satir)
    if _hata == 0:
        print("TAMAM arayuz: alti ekranda tasan eleman yok")
    quit(_hata)
    return true

## Gorunur her Control'un dikdortgenini ekranla karsilastir.
func _tara(ad: String, kok: Node) -> void:
    var bulunan := 0
    for c in _controller_topla(kok):
        if not c.is_visible_in_tree():
            continue
        var r := c.get_global_rect()
        if r.size.x <= 0.0 or r.size.y <= 0.0:
            continue
        var tasma := ""
        if r.position.x < -TOLERANS: tasma += " sol=%.0f" % r.position.x
        if r.position.y < -TOLERANS: tasma += " ust=%.0f" % r.position.y
        if r.end.x > EKRAN.x + TOLERANS: tasma += " sag=%.0f" % (r.end.x - EKRAN.x)
        if r.end.y > EKRAN.y + TOLERANS: tasma += " alt=%.0f" % (r.end.y - EKRAN.y)
        if tasma == "":
            continue
        # Sadece YAZI ve DUGME onemli: okunamayan metin hatadir. Zemin
        # ColorRect'leri bilerek ekrani asabiliyor (vinyet, karartma).
        if not (c is Label or c is Button):
            continue
        var metin: String = c.text if "text" in c else "<?>"
        _rapor.append("  TASMA [%s] %s  %s  ->%s" % [ad, c.get_class(), metin.substr(0, 38), tasma])
        bulunan += 1
    if bulunan > 0:
        _hata = 1
    else:
        _rapor.append("  [ok] %s" % ad)

func _controller_topla(n: Node) -> Array[Control]:
    var liste: Array[Control] = []
    if n is Control:
        liste.append(n)
    for c in n.get_children():
        liste.append_array(_controller_topla(c))
    return liste
