extends CharacterBody2D
## Sürüyü oluşturan düşman. Tek sahne, beş tür:
## 0 kül, 1 imp (hızlı), 2 cüruf (iri), 3 iskelet (sert), 4 hayalet (duvar
## tanımaz), 5 cadı (mesafesini korur, ateş eder).

signal olduruldu(pozisyon: Vector2, xp: int)

const DOKULAR := {
    0: preload("res://assets/sprites/dusman_kul.png"),
    1: preload("res://assets/sprites/dusman_imp.png"),
    2: preload("res://assets/sprites/dusman_curuf.png"),
    3: preload("res://assets/sprites/dusman_iskelet.png"),
    4: preload("res://assets/sprites/dusman_hayalet.png"),
    5: preload("res://assets/sprites/dusman_cadi.png"),
}

const MermiSahne := preload("res://scenes/dusman_mermisi.tscn")

var hiz := 42.0
var can := 3.0
var temas_hasari := 1
var temas_mesafe := 11.0
var xp_degeri := 1

var _tur := 0
var _yaricap := 7.0
var _hedef: Node2D
var _temas_bekleme := 0.0
var _atis_bekleme := 0.0
var menzil := 0.0          # 0 = temas dusmani, >0 = bu mesafeyi korur ve ates eder
var _parlama := 0.0

@onready var _gorsel: Sprite2D = $Gorsel
@onready var _carpisma: CollisionShape2D = $Carpisma

## Dogmadan once cagrilir: tur ve zorluk carpani.
func kur(tur: int, guc: float) -> void:
    _tur = tur
    match tur:
        1:  # imp: hizli, zayif
            hiz = 80.0
            can = 2.0 * guc
            _yaricap = 5.0
            temas_mesafe = 9.0
        2:  # curuf: iri, yavas, sert
            hiz = 26.0
            can = 11.0 * guc
            temas_hasari = 2
            xp_degeri = 3
            _yaricap = 11.0
            temas_mesafe = 16.0
        3:  # iskelet: dengeli ama sert
            hiz = 52.0
            can = 6.0 * guc
            xp_degeri = 2
            _yaricap = 6.0
            temas_mesafe = 11.0
        4:  # hayalet: duvar ve siper tanimaz, zayif
            hiz = 62.0
            can = 3.0 * guc
            _yaricap = 5.0
            temas_mesafe = 10.0
            xp_degeri = 2
        5:  # cadi: mesafesini korur, mermi atar
            hiz = 46.0
            can = 4.0 * guc
            xp_degeri = 3
            _yaricap = 6.0
            temas_mesafe = 10.0
            menzil = 112.0
        _:  # kul: standart
            hiz = 44.0
            can = 3.0 * guc
            _yaricap = 7.0
            temas_mesafe = 12.0

func _ready() -> void:
    add_to_group("dusman")
    _gorsel.texture = DOKULAR[_tur]
    var s := CircleShape2D.new()   # her ornek kendi seklini tasisin
    s.radius = _yaricap
    _carpisma.shape = s
    if _tur == 4:
        collision_mask = 0            # duvardan ve siperden gecer
        _gorsel.modulate = Color(1, 1, 1, 0.65)

func _physics_process(delta: float) -> void:
    _temas_bekleme = maxf(_temas_bekleme - delta, 0.0)
    if _parlama > 0.0:
        _parlama -= delta
        if _parlama <= 0.0:
            _gorsel.modulate = Color(1, 1, 1, 0.65) if _tur == 4 else Color(1, 1, 1)

    if not is_instance_valid(_hedef):
        _hedef = get_tree().get_first_node_in_group("oyuncu")
        if not is_instance_valid(_hedef):
            velocity = Vector2.ZERO
            move_and_slide()
            return

    # ponytail: yol bulma yok, duz hedefe yurur -- siperin arkasinda takilir.
    # Sure gectikce siperler kirildigi icin simdilik yeterli; tikanma his olarak
    # rahatsiz edince NavigationAgent2D'ye gec.
    var fark := _hedef.global_position - global_position
    var yon := fark.normalized()
    if menzil > 0.0:
        # Cadi: cok yaklasirsa geri ceker, menzildeyse durup ates eder
        var uzak := fark.length()
        var git := yon
        if uzak < menzil * 0.75:
            git = -yon
        elif uzak < menzil:
            git = Vector2.ZERO
        velocity = velocity.move_toward(git * hiz, 600.0 * delta)
        _atis_bekleme -= delta
        if uzak < menzil * 1.35 and _atis_bekleme <= 0.0:
            _atis_bekleme = 1.6
            _ates_et(yon)
    else:
        velocity = velocity.move_toward(yon * hiz, 600.0 * delta)
    move_and_slide()
    _gorsel.flip_h = yon.x < 0.0

    if _temas_bekleme <= 0.0 and global_position.distance_to(_hedef.global_position) < temas_mesafe:
        _temas_bekleme = 0.5
        _hedef.hasar_al(temas_hasari)

func _ates_et(yon: Vector2) -> void:
    var m := MermiSahne.instantiate()
    m.global_position = global_position + yon * 10.0
    m.yon = yon
    m.hasar = 1.0
    m.hiz = 115.0
    get_parent().add_child(m)

func hasar_al(miktar: float) -> void:
    can -= miktar
    _parlama = 0.09
    _gorsel.modulate = Color(3, 3, 3)
    if can <= 0.0:
        olduruldu.emit(global_position, xp_degeri)
        queue_free()
