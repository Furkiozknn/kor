extends Area2D
## Düşman ölünce düşen XP küpü. Mıknatıs menziline girince oyuncuya akar.

signal toplandi(xp: int)

const MAKS_HIZ := 320.0
const IVME := 900.0

var xp := 1
var _hedef: Node2D
var _hiz := 0.0
var _alindi := false

@onready var _gorsel: Polygon2D = $Gorsel

func _ready() -> void:
    var hale := Sprite2D.new()
    hale.texture = Hiss.parlama_dokusu(Color(0.45, 1.0, 0.6, 0.55), Color(0.2, 0.8, 0.4, 0.0), 32)
    hale.material = Hiss.ekleme_materyali()
    hale.scale = Vector2.ONE * 0.5
    hale.z_index = -1
    add_child(hale)
    body_entered.connect(func(g: Node2D) -> void:
        if g.is_in_group("oyuncu"):
            _al())
    _hedef = get_tree().get_first_node_in_group("oyuncu")

func _physics_process(delta: float) -> void:
    if _alindi or not is_instance_valid(_hedef):
        return
    # Nabiz: goz kosede yakalasin
    var n := 1.0 + sin(Time.get_ticks_msec() / 140.0) * 0.18
    _gorsel.scale = Vector2(n, n)
    _gorsel.rotation += delta * 1.6
    var uzak := global_position.distance_to(_hedef.global_position)
    if uzak > _hedef.miknatis:
        _hiz = 0.0
        return
    _hiz = minf(_hiz + IVME * delta, MAKS_HIZ)
    global_position = global_position.move_toward(_hedef.global_position, _hiz * delta)
    if uzak < 6.0:
        _al()

func _al() -> void:
    if _alindi:
        return
    _alindi = true
    SesYonetici.cal("kup")
    Hiss.patlama(get_parent(), global_position, Color(0.5, 1.0, 0.65), 6, 80.0, 1.3, 0.25)
    toplandi.emit(xp)
    queue_free()
