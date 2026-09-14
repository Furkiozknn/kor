extends Area2D
## Oyuncu mermisi. Duvara carpinca yok olur, dusmana hasar verir.

const OMUR := 1.1
const HIZ := 260.0

var yon := Vector2.RIGHT
var hasar := 1.0
var hiz := HIZ
var delici := false      # kor atisi dusmani delip gecer, duvarda durur
var _kalan := OMUR

func _ready() -> void:
    body_entered.connect(_carpti)

func _physics_process(delta: float) -> void:
    position += yon * hiz * delta
    _kalan -= delta
    if _kalan <= 0.0:
        queue_free()

func _carpti(govde: Node2D) -> void:
    if govde.has_method("hasar_al"):
        govde.hasar_al(hasar)
        if delici and govde.is_in_group("dusman"):
            return
    queue_free()
