extends Node
## Oyun hissi: kamera sarsıntısı, vuruş donması, parçacık patlamaları,
## dalış hayaletleri. Autoload -- her yerden `Hiss.sars(3.0)` diye çağrılır.
##
## Hepsi kodla üretiliyor, tek bir varlık dosyası gerektirmiyor.

var kamera: Camera2D

var _sarsinti := 0.0
var _donma := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

## Kamerayı sars. guc: piksel cinsinden tepe genlik (1 hafif, 6 sert).
func sars(guc: float) -> void:
    _sarsinti = maxf(_sarsinti, guc)

## Vuruş donması -- darbenin ağırlığını hissettiren birkaç kare.
func dondur(sure: float = 0.05) -> void:
    if _donma > 0.0:
        return
    _donma = sure
    Engine.time_scale = 0.05

func _process(delta: float) -> void:
    if _donma > 0.0:
        # Engine.time_scale'den bagimsiz gercek sure
        _donma -= delta / maxf(Engine.time_scale, 0.001)
        if _donma <= 0.0:
            Engine.time_scale = 1.0

    if not is_instance_valid(kamera):
        return
    if _sarsinti > 0.05:
        _sarsinti = maxf(_sarsinti - delta * 26.0, 0.0)
        kamera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _sarsinti
    elif kamera.offset != Vector2.ZERO:
        kamera.offset = kamera.offset.lerp(Vector2.ZERO, 0.35)

## Tek atımlık parçacık patlaması. Kendini temizler.
func patlama(ebeveyn: Node, poz: Vector2, renk: Color, adet: int, hiz: float,
        boy: float = 2.0, omur: float = 0.45) -> void:
    if not is_instance_valid(ebeveyn):
        return
    var p := CPUParticles2D.new()
    p.global_position = poz
    p.emitting = true
    p.one_shot = true
    p.explosiveness = 1.0
    p.amount = adet
    p.lifetime = omur
    p.direction = Vector2.ZERO
    p.spread = 180.0
    p.initial_velocity_min = hiz * 0.4
    p.initial_velocity_max = hiz
    p.damping_min = hiz * 0.7
    p.damping_max = hiz * 1.4
    p.scale_amount_min = boy * 0.6
    p.scale_amount_max = boy
    p.color = renk
    var g := Gradient.new()
    g.set_color(0, Color(renk.r, renk.g, renk.b, 1.0))
    g.set_color(1, Color(renk.r, renk.g, renk.b, 0.0))
    p.color_ramp = g
    ebeveyn.add_child(p)
    p.finished.connect(p.queue_free)

## Dalış izi: sprite'ın solup kaybolan kopyası.
## Hem Sprite2D hem AnimatedSprite2D kabul eder.
func hayalet(kaynak: Node2D, renk: Color = Color(1, 0.6, 0.25, 0.55)) -> void:
    if not is_instance_valid(kaynak):
        return
    var doku: Texture2D = null
    if kaynak is Sprite2D:
        doku = kaynak.texture
    elif kaynak is AnimatedSprite2D and kaynak.sprite_frames != null:
        var a: String = kaynak.animation
        if kaynak.sprite_frames.has_animation(a) and kaynak.sprite_frames.get_frame_count(a) > 0:
            doku = kaynak.sprite_frames.get_frame_texture(a, kaynak.frame)
    if doku == null:
        return
    var ebeveyn := kaynak.get_parent().get_parent()
    if not is_instance_valid(ebeveyn):
        return
    var s := Sprite2D.new()
    s.texture = doku
    s.global_position = kaynak.global_position
    s.flip_h = kaynak.flip_h
    s.modulate = renk
    s.z_index = -1
    ebeveyn.add_child(s)
    var t := s.create_tween()
    t.tween_property(s, "modulate:a", 0.0, 0.28)
    t.parallel().tween_property(s, "scale", Vector2(0.7, 0.7), 0.28)
    t.tween_callback(s.queue_free)

## Kor parlaması için yarıçapsal gradyan dokusu (kodla üretilir).
static func parlama_dokusu(ic: Color, dis: Color, boy: int = 64) -> GradientTexture2D:
    var g := Gradient.new()
    g.set_color(0, ic)
    g.set_color(1, dis)
    var t := GradientTexture2D.new()
    t.gradient = g
    t.fill = GradientTexture2D.FILL_RADIAL
    t.fill_from = Vector2(0.5, 0.5)
    t.fill_to = Vector2(1.0, 0.5)
    t.width = boy
    t.height = boy
    return t

## Toplama (additive) karışım -- ışık gibi davranan sprite'lar için.
static func ekleme_materyali() -> CanvasItemMaterial:
    var m := CanvasItemMaterial.new()
    m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    return m
