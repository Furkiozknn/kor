extends Area2D
## Düşman ölünce düşen XP küpü. Mıknatıs menziline girince oyuncuya akar.

signal toplandi(xp: int)

const MAKS_HIZ := 320.0
const IVME := 900.0

var xp := 1
var _hedef: Node2D
var _hiz := 0.0
var _alindi := false

func _ready() -> void:
    body_entered.connect(func(g: Node2D) -> void:
        if g.is_in_group("oyuncu"):
            _al())
    _hedef = get_tree().get_first_node_in_group("oyuncu")

func _physics_process(delta: float) -> void:
    if _alindi or not is_instance_valid(_hedef):
        return
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
    toplandi.emit(xp)
    queue_free()
