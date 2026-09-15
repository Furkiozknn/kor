extends Area2D
## Mermi. Duvara/sipere çarpınca söner, düşmana hasar verir ve iter.
## Delici mermiler düşmanı geçer, duvarda durur.

var yon := Vector2.RIGHT
var hasar := 1.0
var hiz := 265.0
var omur := 1.1
var delici := false      # kor atisi ve cekic dusmani delip gecer
## KOR IZI damgasi: vurus noktasinda kucuk bir kor patlamasi birakir.
var kor_izi := false
const KOR_IZI_MENZIL := 24.0
const KOR_IZI_PAY := 0.55      # ana hasarin bu kadari, cevredeki herkese

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
        if kor_izi:
            _kor_izi_patlat(govde)
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


## Vurusun etrafina kucuk bir kor patlamasi. Vurulan dusmana IKINCI kez
## hasar vermiyor -- yoksa damga tek hedefte de hasar carpani olurdu ve
## "cevreye yayilir" vaadini tutmazdi.
func _kor_izi_patlat(vurulan: Node2D) -> void:
    Hiss.patlama(get_parent(), global_position, Color(1.0, 0.55, 0.16), 8, 70.0, 1.5, 0.35)
    for d in get_tree().get_nodes_in_group("dusman"):
        if d == vurulan or not is_instance_valid(d):
            continue
        if d.global_position.distance_to(global_position) <= KOR_IZI_MENZIL:
            d.hasar_al(hasar * KOR_IZI_PAY, (d.global_position - global_position).normalized() * 40.0)
