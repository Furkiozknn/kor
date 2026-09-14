extends Area2D
## Mermi. Duvara/sipere çarpınca söner, düşmana hasar verir ve iter.
## Delici mermiler düşmanı geçer, duvarda durur.

var yon := Vector2.RIGHT
var hasar := 1.0
var hiz := 265.0
var omur := 1.1
var delici := false      # kor atisi ve cekic dusmani delip gecer

var _kalan := 0.0

@onready var _gorsel: Polygon2D = $Gorsel
@onready var _hale: Sprite2D = $Parlama

func _ready() -> void:
    _kalan = omur
    body_entered.connect(_carpti)
    rotation = yon.angle()
    # Mermi kendi isigini tasisin -- karanlik arenada duz dikdortgen kalmasin
    var c := _gorsel.color
    _hale.texture = Hiss.parlama_dokusu(Color(c.r, c.g, c.b, 0.75),
        Color(c.r, c.g, c.b, 0.0), 32)
    _hale.material = Hiss.ekleme_materyali()
    _hale.scale = Vector2.ONE * 0.55

    # Iz. ONEMLI: onceden her 35 ms'de bir YENI parcacik dugumu yaratiliyordu;
    # 20 mermi = saniyede ~570 dugum ayirma. Olculdu: kare suresi p95 72 ms'ye
    # firliyordu. Artik mermi basina TEK kalici yayici var, mermiyle olur.
    if hiz > 150.0:
        var iz := CPUParticles2D.new()
        iz.amount = 10
        iz.lifetime = 0.22
        iz.local_coords = false          # mermi gidince iz yerinde kalir
        iz.direction = Vector2.ZERO
        iz.spread = 180.0
        iz.initial_velocity_min = 2.0
        iz.initial_velocity_max = 10.0
        iz.scale_amount_min = scale.x * 0.5
        iz.scale_amount_max = scale.x * 0.9
        var g := Gradient.new()
        g.set_color(0, Color(c.r, c.g, c.b, 0.8))
        g.set_color(1, Color(c.r, c.g, c.b, 0.0))
        iz.color_ramp = g
        iz.z_index = -2
        add_child(iz)

func _physics_process(delta: float) -> void:
    position += yon * hiz * delta
    _kalan -= delta

    if _kalan <= 0.0:
        _son(false)

func _carpti(govde: Node2D) -> void:
    if govde.is_in_group("dusman"):
        govde.hasar_al(hasar, yon * (26.0 + hasar * 7.0))
        if delici:
            return
        _son(true)
        return
    if govde.has_method("hasar_al"):
        govde.hasar_al(hasar)
    _son(true)

func _son(carpma: bool) -> void:
    if carpma:
        Hiss.patlama(get_parent(), global_position, Color(1.0, 0.8, 0.45),
            5, 90.0, scale.x * 1.6, 0.22)
    queue_free()
