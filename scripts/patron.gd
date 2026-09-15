extends CharacterBody2D
## KÜL ANASI — patron.
##
## Tasarım kuralı: patron can torbası olmayacak, **çekirdek mekaniği
## sınayacak.** Kor'un çekirdeği "ısıyı tut mu, harca mı" ve "görmek için
## ısın, yaşamak için soğu". Kül Anası bu iki ikilemi de doğrudan zorluyor:
##
##   IŞIK İÇER   — oyuncu soğukken patron kendini onarır ve neredeyse
##                 görünmezdir. Onu öldürmek için SICAK kalmak zorundasın,
##                 yani kilide yaklaşmak zorundasın.
##   SOĞUK DALGA — belirli aralıklarla ısını bir anda sıfırlar. Kör kalırsın
##                 ve o karanlıkta üstüne gelir. Mangal/örs coğrafyası
##                 burada hayat kurtarır: mangal seni tekrar ısıtır.
##
## Yani patron "daha çok vur"u değil, "ısı ekonomisini yönet"i ödüllendiriyor.

signal olduruldu(pozisyon: Vector2, xp: int)
signal patron_oldu

const DOKU := preload("res://assets/sprites/patron.png")

const SOGUK_DALGA_ARALIK := 13.0
const SOGUK_DALGA_MENZIL := 260.0
const ONARIM_HIZI := 5.0          # saniyede, oyuncu soğukken
const SICAK_ESIK := 0.55          # bu ısının üstünde patron savunmasız
const SOGUK_ESIK := 0.25          # bu ısının altında onarılır

var maks_can := 260.0
var can := 260.0
var hiz := 34.0
var temas_hasari := 2
var xp_degeri := 40

var _hedef: Node2D
var _temas_bekleme := 0.0
var _dalga_sayaci := 6.0
## TELEGRAF. Soguk dalga telegrafsizdi: oyuncu isisini bir anda kaybediyor
## ve neden oldugunu anlamiyordu. Turun en sik elestirisi tam bu --
## "kacinilamayan vurus". 0,9 saniyelik hazirlik: patron kasiliyor,
## cekirdegi buyuyup mavilesiyor. Dalga ayni sertlikte kaliyor ama artik
## OKUNABILIR -- kacmak ya da mangala kosmak icin zaman var.
const TELEGRAF := 0.9
var _telegraf_kalan := 0.0
var _parlama := 0.0
var _dogus := 1.0
var _adim := 0.0

@onready var _gorsel: Sprite2D = $Gorsel
@onready var _carpisma: CollisionShape2D = $Carpisma
@onready var _cekirdek: Sprite2D = $Cekirdek

func kur(guc: float) -> void:
    maks_can = 260.0 * guc
    can = maks_can

func _ready() -> void:
    add_to_group("dusman")
    add_to_group("patron")
    _gorsel.texture = DOKU
    var s := CircleShape2D.new()
    s.radius = 15.0
    _carpisma.shape = s
    # Çekirdek: patronun tek sıcak olmayan ışığı. Savunmasızken parlar.
    _cekirdek.texture = Hiss.parlama_dokusu(
        Color(0.35, 0.95, 1.0, 0.75), Color(0.1, 0.5, 0.7, 0.0), 48)
    _cekirdek.material = Hiss.ekleme_materyali()
    _cekirdek.z_index = -1

func _physics_process(delta: float) -> void:
    _temas_bekleme = maxf(_temas_bekleme - delta, 0.0)
    if _dogus > 0.0:
        _dogus = maxf(_dogus - delta * 1.2, 0.0)
        _gorsel.scale = Vector2.ONE * (1.0 - _dogus) * 1.6
        _gorsel.modulate.a = 1.0 - _dogus
        return
    if _parlama > 0.0:
        _parlama -= delta
        if _parlama <= 0.0:
            _gorsel.modulate = Color(1, 1, 1)

    if not is_instance_valid(_hedef):
        _hedef = get_tree().get_first_node_in_group("oyuncu")
        if not is_instance_valid(_hedef):
            return

    var oran: float = _hedef.isi.oran()

    # Işık içer: oyuncu soğukken onarılır ve silikleşir
    if oran < SOGUK_ESIK:
        can = minf(can + ONARIM_HIZI * delta, maks_can)
        _gorsel.modulate.a = 0.35
    else:
        _gorsel.modulate.a = lerpf(0.35, 1.0, clampf((oran - SOGUK_ESIK) / 0.35, 0.0, 1.0))
    _cekirdek.scale = Vector2.ONE * (0.6 + 0.5 * oran)
    _cekirdek.modulate.a = clampf(oran * 1.4, 0.15, 1.0)

    # Soğuk dalga
    _dalga_sayaci -= delta
    if _telegraf_kalan > 0.0:
        _telegraf_kalan -= delta
        # Kasilma: cekirdek buyuyor, govde maviye caliyor
        var t := 1.0 - _telegraf_kalan / TELEGRAF
        _cekirdek.scale = Vector2.ONE * (0.6 + 2.4 * t)
        _cekirdek.modulate = Color(0.5, 0.9, 1.0, 0.35 + 0.65 * t)
        _gorsel.modulate = Color(1, 1, 1).lerp(Color(0.55, 0.85, 1.25), t)
        if _telegraf_kalan <= 0.0:
            _gorsel.modulate = Color(1, 1, 1)
            _soguk_dalga()
    elif _dalga_sayaci <= 0.0:
        _dalga_sayaci = SOGUK_DALGA_ARALIK
        _telegraf_kalan = TELEGRAF
        SesYonetici.cal("isi_uyari")
        Hiss.sars(1.6)

    var yon := (_hedef.global_position - global_position).normalized()
    velocity = velocity.move_toward(yon * hiz, 320.0 * delta)
    move_and_slide()
    _gorsel.flip_h = yon.x < 0.0
    _adim += delta * 3.0
    _gorsel.scale = Vector2(1.6 + sin(_adim) * 0.05, 1.6 - sin(_adim) * 0.05)

    if _temas_bekleme <= 0.0 and global_position.distance_to(_hedef.global_position) < 24.0:
        _temas_bekleme = 0.7
        _hedef.hasar_al(temas_hasari)

## Isıyı bir anda söndürür: kör kalırsın ve patron karanlıkta üstüne gelir.
func _soguk_dalga() -> void:
    Hiss.sars(6.0)
    Hiss.patlama(get_parent(), global_position, Color(0.5, 0.9, 1.0), 40, 220.0, 3.0, 0.7)
    SesYonetici.cal("soguk_dalga")
    if is_instance_valid(_hedef):
        if global_position.distance_to(_hedef.global_position) < SOGUK_DALGA_MENZIL:
            _hedef.isi.deger = 0.0
            _hedef.isi.kilitli = false

func hasar_al(miktar: float, itme: Vector2 = Vector2.ZERO) -> void:
    if _dogus > 0.0:
        return
    var carpan := 1.0
    if is_instance_valid(_hedef):
        var oran: float = _hedef.isi.oran()
        if oran < SOGUK_ESIK:
            carpan = 0.15          # soğukken neredeyse dokunamıyorsun
        elif oran > SICAK_ESIK:
            carpan = 1.6           # sıcakken savunmasız
    can -= miktar * carpan
    _parlama = 0.08
    _gorsel.modulate = Color(2.4, 2.4, 2.4)
    Hiss.patlama(get_parent(), global_position, Color(0.75, 0.95, 1.0), 3, 60.0, 1.4, 0.2)
    if can <= 0.0:
        olduruldu.emit(global_position, xp_degeri)
        patron_oldu.emit()
        SesYonetici.cal("dusman_olum")
        Hiss.sars(8.0)
        Hiss.dondur(0.12)
        Hiss.patlama(get_parent(), global_position, Color(0.7, 0.9, 1.0), 70, 230.0, 3.4, 1.0)
        queue_free()

func can_orani() -> float:
    return clampf(can / maxf(maks_can, 1.0), 0.0, 1.0)
