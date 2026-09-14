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

const TUR_ADI := {0: "kul", 1: "imp", 2: "curuf", 3: "iskelet", 4: "hayalet", 5: "cadi"}
const ANIM_KOK := "res://assets/sprites/anim"

## Tur basina SpriteFrames -- 60 dusman ayni anda dogarken her biri yeniden
## kurmasin diye onbellekte tutuluyor.
static var _kare_onbellegi := {}

static func _kareler(tur: int, dokular: Dictionary) -> SpriteFrames:
    if _kare_onbellegi.has(tur):
        return _kare_onbellegi[tur]
    var sf := SpriteFrames.new()
    sf.remove_animation("default")
    sf.add_animation("yuru")
    sf.set_animation_speed("yuru", 10.0)
    sf.set_animation_loop("yuru", true)
    var i := 0
    while true:
        var yol := "%s/%s_%d.png" % [ANIM_KOK, TUR_ADI[tur], i]
        if not ResourceLoader.exists(yol):
            break
        sf.add_frame("yuru", load(yol))
        i += 1
    if i == 0:
        sf.add_frame("yuru", dokular[tur])   # animasyon yoksa tek kare
    _kare_onbellegi[tur] = sf
    return sf

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
var _itme := Vector2.ZERO
var _dogus := 0.0
var _adim := 0.0

var _cekirdek: Sprite2D

@onready var _gorsel: AnimatedSprite2D = $Gorsel
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
    _dogus = 1.0
    _gorsel.sprite_frames = _kareler(_tur, DOKULAR)
    _gorsel.animation = "yuru"
    _gorsel.frame = randi() % maxi(_gorsel.sprite_frames.get_frame_count("yuru"), 1)
    _gorsel.play()
    # Soguk cekirdek. Karanlikta detayi gormezsin ama SURUYU sezersin --
    # turun "yuzlerce dusman" fantezisi karanlikta bogulmasin diye.
    # Isiktan degil kendinden geliyor: kul faksiyonunun camgobegi cekirdegi.
    _cekirdek = Sprite2D.new()
    _cekirdek.texture = Hiss.parlama_dokusu(
        Color(0.42, 0.86, 1.0, 0.34), Color(0.1, 0.4, 0.6, 0.0), 32)
    _cekirdek.material = Hiss.ekleme_materyali()
    _cekirdek.z_index = -1
    _cekirdek.scale = Vector2.ONE * (_yaricap / 16.0)
    add_child(_cekirdek)
    var s := CircleShape2D.new()   # her ornek kendi seklini tasisin
    s.radius = _yaricap
    _carpisma.shape = s
    if _tur == 4:
        collision_mask = 0            # duvardan ve siperden gecer
        _gorsel.modulate = Color(1, 1, 1, 0.65)

func _physics_process(delta: float) -> void:
    _temas_bekleme = maxf(_temas_bekleme - delta, 0.0)

    # Dogus: yoktan bitmesin, buyuyerek gelsin
    if _cekirdek != null:
        _cekirdek.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 320.0 + position.x)
    if _dogus > 0.0:
        _dogus = maxf(_dogus - delta * 4.5, 0.0)
        var b := 1.0 - _dogus
        _gorsel.scale = Vector2(b * (1.0 + _dogus * 0.4), b)
        _gorsel.modulate.a = (0.65 if _tur == 4 else 1.0) * b

    # Vurus itmesi
    if _itme.length_squared() > 1.0:
        _itme = _itme.move_toward(Vector2.ZERO, 900.0 * delta)
    if _parlama > 0.0:
        _parlama -= delta
        if _parlama <= 0.0:
            _gorsel.modulate = Color(1, 1, 1, 0.65) if _tur == 4 else Color(1, 1, 1)
    if _dogus <= 0.0:
        # Yurume salinimi: hizlandikca daha cok sekiyor
        var h := velocity.length() / maxf(hiz, 1.0)
        _adim += delta * (5.0 + h * 5.0)
        var e := 1.0 + sin(_adim) * minf(h, 1.0) * 0.035
        _gorsel.scale = _gorsel.scale.lerp(Vector2(2.0 - e, e), 12.0 * delta)
        _gorsel.position.y = -abs(sin(_adim)) * minf(h, 1.0) * 0.7
        _gorsel.rotation = sin(_adim * 0.5) * minf(h, 1.0) * 0.04

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
        velocity = velocity.move_toward(git * hiz + _itme, 600.0 * delta)
        _atis_bekleme -= delta
        if uzak < menzil * 1.35 and _atis_bekleme <= 0.0:
            _atis_bekleme = 1.6
            _ates_et(yon)
    else:
        velocity = velocity.move_toward(yon * hiz + _itme, 600.0 * delta)
    move_and_slide()
    _gorsel.flip_h = yon.x < 0.0
    _gorsel.speed_scale = clampf(0.5 + velocity.length() / maxf(hiz, 1.0), 0.4, 1.8)

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
    SesYonetici.cal("cadi_atisi")

func hasar_al(miktar: float, itme: Vector2 = Vector2.ZERO) -> void:
    can -= miktar
    _parlama = 0.09
    _gorsel.modulate = Color(3, 3, 3)
    _gorsel.scale = Vector2(1.35, 0.72)          # vurus ezilmesi
    _itme += itme
    SesYonetici.cal("vurus")
    Hiss.patlama(get_parent(), global_position, Color(0.75, 0.95, 1.0),
        4, 70.0, 1.3, 0.2)
    if can <= 0.0:
        olduruldu.emit(global_position, xp_degeri)
        SesYonetici.cal("dusman_olum")
        # Kul patlamasi -- olum gorulsun
        Hiss.patlama(get_parent(), global_position, Color(0.72, 0.86, 0.95),
            14 + int(xp_degeri) * 6, 130.0, 2.0, 0.5)
        Hiss.sars(0.8 + float(xp_degeri) * 0.3)
        queue_free()
