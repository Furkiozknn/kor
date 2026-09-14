extends SceneTree
## Koşu döngüsü dumanı: düşman doğuyor mu, temas hasar veriyor mu,
## XP dolunca kartlar açılıp uygulanıyor mu?
## godot --headless --script res://tests/test_dongu.gd

const SURE := 8.0
const KARE_TAVANI := 20000   # assert patlarsa sonsuz donguye girmeyelim

var _ana: Node2D
var _kare := 0
var _hasar_sayaci := 0
var _asama := 0
var _xp_once := 0
var _kup_karesi := 0

func _initialize() -> void:
    seed(20260914)
    _ana = load("res://scenes/level.tscn").instantiate()
    root.add_child(_ana)

func _process(_delta: float) -> bool:
    _kare += 1
    if _kare == 1:
        # Sabit duran oyuncu er ya da geç ölür; bu test hayatta kalmayı değil
        # döngünün döndüğünü ölçüyor -- canı dolu tutup hasarı sayıyoruz.
        _ana.oyuncu.can_degisti.connect(func(c, m):
            if c < m:
                _hasar_sayaci += 1
                _ana.oyuncu.can = m)
    if _kare > KARE_TAVANI:
        push_error("test_dongu: kare tavanı aşıldı")
        return true
    if _asama == 1:
        return _kup_asamasi()
    if _ana.gecen < SURE:
        return false

    var dusmanlar := get_nodes_in_group("dusman").size()
    var oyuncu = _ana.oyuncu
    assert(not _ana.bitti, "oyuncu canı dolu tutulurken ölmemeli")
    assert(dusmanlar > 0, "dalga spawn'i calismiyor: hic dusman yok")
    assert(_hasar_sayaci > 0, "temas hasari islemiyor")

    # Seviye kartlari: XP dolunca açılmalı, seçince oyun devam etmeli
    _ana._xp_topla(_ana.xp_hedef)
    assert(_ana.seviye == 2, "XP dolunca seviye atlamali")
    assert(_ana._kart_katman != null, "seviye kartlari acilmadi")
    assert(paused, "kart ekrani oyunu duraklatmali")
    var kutu: Node = _ana._kart_katman.get_child(1)
    assert(kutu.get_child_count() == 4, "1 baslik + 3 kart olmali")
    var once := _oyuncu_ozeti(oyuncu)
    kutu.get_child(1).pressed.emit()
    assert(not paused, "kart secilince duraklatma kalkmali")
    assert(_oyuncu_ozeti(oyuncu) != once, "secilen kart oyuncuya uygulanmadi")

    # Aşama 2: oyuncunun yanındaki düşmanı öldür -> XP küpü düşsün,
    # mıknatısla toplansın, XP artsın. (uçtan uca: hasar -> küp -> XP)
    var d: Node2D = get_nodes_in_group("dusman")[0]
    d.global_position = oyuncu.global_position + Vector2(24, 0)
    _xp_once = _ana.xp
    _kup_karesi = _kare
    d.hasar_al(9999.0)
    _asama = 1
    return false

func _kup_asamasi() -> bool:
    if _ana.xp > _xp_once or _ana.seviye > 2:
        print("test_dongu: TAMAM  (dusman=%d, temas=%d, sure=%.1fs, kup toplandi)" % [
            get_nodes_in_group("dusman").size(), _hasar_sayaci, _ana.gecen])
        return true
    assert(_kare - _kup_karesi < 240, "XP kupu miknatisla toplanmadi")
    return _kare - _kup_karesi >= 240

func _oyuncu_ozeti(o) -> Array:
    return [o.isi.tavan, o.isi.soguma_hizi, o.isi.atis_basina, o.hiz, o.atis_araligi,
        o.mermi_hasari, o.mermi_sayisi, o.maks_can, o.asiri_isi_carpani, o.dalis_patlamasi, o.miknatis]
