extends StaticBody2D
## Arena siperi. Fıçı/sandık kırılır (ateş hattını açarsın), örs/mangal kalıcıdır.

signal kirildi(pozisyon: Vector2)
signal yakildi(pozisyon: Vector2)

const TURLER := {
    "fici":       {"doku": preload("res://assets/sprites/yapi_fici.png"),       "can": 6.0,  "yaricap": 6.0},
    "sandik":     {"doku": preload("res://assets/sprites/yapi_sandik.png"),     "can": 9.0,  "yaricap": 7.0},
    "fici_yigin": {"doku": preload("res://assets/sprites/yapi_fici_yigin.png"), "can": 14.0, "yaricap": 7.5},
    "orsa":       {"doku": preload("res://assets/sprites/yapi_orsa.png"),       "can": 0.0,  "yaricap": 7.0},
    "mangal":     {"doku": preload("res://assets/sprites/yapi_mangal.png"),     "can": 0.0,  "yaricap": 6.5},
}

## SONUK DOKUMHANE. Mangallar sonuk baslar; oyuncu KENDI ISISIYLA yakar.
##
## Neden: Kor'un turdeki tek ozgun mekanigi "isi = gorus". Ama arena
## mangallarla zaten aydinlik basliyordu, yani oyuncu bu mekanigi ilk
## dakikada HIC kesfetmiyordu -- ve oyunu birakip birakmayacagina o dakikada
## karar veriyor. Baslangic ekranindaki uc satir metin bunu ogretmez;
## metin okunmaz, oynanir.
##
## Cozum ayri bir ogretim sistemi degil, sahnenin BASLANGIC DURUMU:
## karanlikta baslarsin, ates edersin, isinirsin, gorursun, bir mangal
## bulursun, sicakken yaklasirsin ve yakarsin. Kimse soylemeden ogrendin.
##
## Tasarim kazanci: yakmak icin SICAK olman gerekiyor -- yani riske girmen.
## Boylece isi ekonomisine paralel bir sistem eklemiyoruz, onu derinlestiriyoruz.
var yanik := true
var can := 0.0
var _tur := "fici"
var _parlama := 0.0
var _hale: Sprite2D
var _zerre := 0.0

@onready var _gorsel: Sprite2D = $Gorsel
@onready var _carpisma: CollisionShape2D = $Carpisma

func kur(tur: String) -> void:
    _tur = tur
    can = TURLER[tur]["can"]

func _ready() -> void:
    add_to_group("yapi")
    var t: Dictionary = TURLER[_tur]
    _gorsel.texture = t["doku"]
    var s := CircleShape2D.new()
    s.radius = t["yaricap"]
    _carpisma.shape = s
    if _tur == "mangal":
        # Hale her zaman kuruluyor ama sonukken gizli -- yakma aninda
        # yeniden dugum yaratmak icin kare beklemeyelim.
        _hale = Sprite2D.new()
        _hale.texture = Hiss.parlama_dokusu(
            Color(1.0, 0.55, 0.18, 0.32), Color(0.9, 0.25, 0.05, 0.0), 96)
        _hale.material = Hiss.ekleme_materyali()
        _hale.z_index = -1
        _hale.scale = Vector2.ONE * 1.1
        add_child(_hale)
        if yanik:
            add_to_group("isik_kaynagi")
        else:
            _sonuk_gorunum()

## Sonuk mangal: kul rengi, halesiz. Silueti duruyor ki oyuncu YAKILACAK
## BIR SEY oldugunu gorsun -- gorus alanina girdiginde hedef olsun.
func _sonuk_gorunum() -> void:
    _hale.visible = false
    _gorsel.modulate = Color(0.42, 0.45, 0.52)

## Oyuncu sicakken yaklasinca cagriliyor. Geri donusu yok: yanan yanik kalir.
func yak() -> void:
    if yanik or _tur != "mangal":
        return
    yanik = true
    add_to_group("isik_kaynagi")
    _hale.visible = true
    _gorsel.modulate = Color(1, 1, 1)
    _parlama = 0.25
    _gorsel.modulate = Color(3.0, 2.2, 1.4)
    yakildi.emit(global_position)

func turu() -> String:
    return _tur

## Karanlik shader'i her karede bunu soruyor. Mangal nefes alsin diye
## yaricap hafifce salinir.
func isik_yaricapi() -> float:
    return 62.0 + sin(Time.get_ticks_msec() / 240.0 + position.x) * 6.0

func _process(delta: float) -> void:
    if _hale != null and yanik:
        var n := 1.05 + sin(Time.get_ticks_msec() / 220.0 + position.x) * 0.10
        _hale.scale = Vector2(n, n)
        _hale.modulate.a = 0.85 + sin(Time.get_ticks_msec() / 130.0 + position.y) * 0.15
        _zerre -= delta
        if _zerre <= 0.0:
            _zerre = randf_range(0.25, 0.6)
            Hiss.patlama(get_parent(), global_position + Vector2(randf_range(-4, 4), -2),
                Color(1.0, 0.6, 0.2), 1, 22.0, 1.0, 0.9)
    if _parlama > 0.0:
        _parlama -= delta
        if _parlama <= 0.0:
            _gorsel.modulate = Color(1, 1, 1)

## can == 0 -> kirilmaz siper. Mermi yine de durur.
func hasar_al(miktar: float) -> void:
    if can <= 0.0:
        return
    can -= miktar
    _parlama = 0.09
    Hiss.patlama(get_parent(), global_position, Color(0.9, 0.7, 0.4), 3, 60.0, 1.2, 0.2)
    _gorsel.modulate = Color(3, 3, 3)
    if can <= 0.0:
        kirildi.emit(global_position)
        Hiss.patlama(get_parent(), global_position, Color(0.85, 0.62, 0.35),
            20, 140.0, 2.2, 0.55)
        Hiss.sars(1.6)
        queue_free()
