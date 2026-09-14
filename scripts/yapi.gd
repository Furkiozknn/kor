extends StaticBody2D
## Arena siperi. Fıçı/sandık kırılır (ateş hattını açarsın), örs/mangal kalıcıdır.

signal kirildi(pozisyon: Vector2)

const TURLER := {
    "fici":       {"doku": preload("res://assets/sprites/yapi_fici.png"),       "can": 6.0,  "yaricap": 6.0},
    "sandik":     {"doku": preload("res://assets/sprites/yapi_sandik.png"),     "can": 9.0,  "yaricap": 7.0},
    "fici_yigin": {"doku": preload("res://assets/sprites/yapi_fici_yigin.png"), "can": 14.0, "yaricap": 7.5},
    "orsa":       {"doku": preload("res://assets/sprites/yapi_orsa.png"),       "can": 0.0,  "yaricap": 7.0},
    "mangal":     {"doku": preload("res://assets/sprites/yapi_mangal.png"),     "can": 0.0,  "yaricap": 6.5},
}

var can := 0.0
var _tur := "fici"
var _parlama := 0.0

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

func _process(delta: float) -> void:
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
    _gorsel.modulate = Color(3, 3, 3)
    if can <= 0.0:
        kirildi.emit(global_position)
        queue_free()
