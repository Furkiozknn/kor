extends CharacterBody2D
## Kor oyuncusu: 8 yönlü hareket, fareye nişan alan ateş, ısı + dalış,
## dört silah ve biriken ısıyı hasara çeviren kor atışı.

const Isi := preload("res://scripts/isi.gd")
const Silahlar := preload("res://scripts/silahlar.gd")
const MermiSahne := preload("res://scenes/mermi.tscn")
const Yonlu := preload("res://scripts/yonlu.gd")
const TEK_DOKU := preload("res://assets/sprites/oyuncu.png")

signal can_degisti(can: int, maks: int)
signal silah_degisti(ad: String, indeks: int)
signal oldu

const DALIS_SURE := 0.22
const DALIS_HIZ := 430.0
const DALIS_BEKLEME := 0.65
const VURULMA_DOKUNULMAZLIK := 0.6
const KOR_ESIK := 0.35       # bu isinin altinda kor atisi yapilamaz
const MANGAL_MENZIL := 74.0  # bu mesafede mangal isitir
const MANGAL_ISI := 11.0     # saniyede
## Sonuk mangali yakmak icin gereken isi orani ve mesafe. Esik KOR_ESIK'ten
## (0,35) YUKSEK bilerek: yakmak gercek bir risk olsun, kazara olmasin.
const YAKMA_ESIK := 0.52
const YAKMA_MENZIL := 30.0

## TAVLAMA -- "TAVLANMIŞ ZIRH" karti acar.
##
## Tavlama gercek bir metal islemi: metali kizdirip KONTROLLU sogutursun,
## boylece sertlesir. Kartin eski hali "maks can +1 VE aninda tam iyiles"ti
## -- bedava, yigilabilir, ve gordugun her seferde almak optimaldi. Havuz
## tek stratejiye cokuyordu.
##
## Yeni hali isi ekonomisinin bir degiskeni: kilide GIRMEYI ve orada
## hasar almadan dayanmayi odullendiriyor. Boylece tavan sadece ceza
## olmaktan cikip bir KARAR oluyor -- "simdi bilerek asiri isinayim mi?"
var tavlanma := false
var _tavlanma_izleme := false
var _tavlanma_temiz := false
const ORS_MENZIL := 40.0     # bu mesafede ors sogutmayi hizlandirir
const ORS_CARPAN := 2.6
# Kor yayilimi: sicakken cevreni yakarsin. Menzil gorus yaricapina bagli,
# yani "gordugunu yakiyorsun". Tekil hasarin surune yetismemesi sorununun
# kimlige uygun cozumu bu -- ve uc sistemi tek dugume bagliyor:
# isi = gorus = alan hasari.
const YAYILIM_TICK := 0.22
const KOR_BEKLEME := 0.5
## KIZGIN BOLGE. Isi bu esigin ustundeyken hem daha cok vuruyorsun
## (asiri_isi_carpani, satir ~348) hem daha cok yiyorsun. Tek esik, iki
## yone de calisiyor: "%70 ustunde her sey iki katI" akilda kalan bir kural.
##
## ONCEDEN: `ceil(miktar * (1 + 0.6 * isi.oran()))` yaziyordu. ceil()
## yuzunden mekanik KADEMELI DEGIL IKILIYDI -- isi %1'de temas hasari
## 1'den 2'ye cikiyor ve %100'e kadar hic degismiyordu. Oyuncu neredeyse
## her zaman %0'in ustunde oldugu icin efektif can 6 degil 3'tu, ve bu
## "sicak oynamak olduruyor" seklinde yanlis olculuyordu.
const KIZGIN_ESIK := 0.70
const KIZGIN_HASAR := 2.0  # kizgin bolgede alinan hasar carpani

@export var hiz := 115.0
@export var ivme := 1200.0
@export var surtunme := 1500.0

var isi := Isi.new()
var maks_can := 6
var can := 6

# Silahlar -- baslangicta sadece ilki acik, kartlar digerlerini aciyor
var silah_indeksi := 0
var acik_silahlar := [0]

# Kartlarla buyuyen degerler (silahin ustune carpan olarak biner)
var atis_hizi_carpani := 1.0
var isi_carpani := 1.0         # kart: atis basina isi
var mermi_hasari := 1.0
var ek_mermi := 0
var ek_yayilma := 0.0
var asiri_isi_carpani := 1.0   # isi > %70 iken gecerli
var dalis_patlamasi := 0.0     # dalis bitince cevreye hasar
var miknatis := 38.0           # XP kupu cekim menzili
var kor_carpani := 1.0         # kart: kor atisi hasari
var kor_maliyet := 1.0         # kart: 1.0 = biriken isinin tamamini harcar
var yayilim_dps := 2.4         # kart: kor yayilimi saniyelik hasari
var yayilim_menzil := 0.62     # gorus yaricapinin bu orani

var _atis_sayaci := 0.0
var _dalis_kalan := 0.0
var _dalis_bekleme := 0.0
var _dokunulmaz := 0.0
var _kor_bekleme := 0.0
var _namlu_parlama := 0.0
var _hayalet_sayaci := 0.0
var _adim := 0.0
var _kor_zerre := 0.0
var _yayilim_sayaci := 0.0
var _silah_gecis := 0.0
# --- Bot kancasi -------------------------------------------------------
# Denge olcum takimi oyuncuyu buradan suruyor. Insan girdisiyle ayni yollari
# kullaniyor (ayni _ates_et, ayni _kor_at, ayni isi kurallari) ki olculen sey
# gercek oyun olsun, paralel bir simulasyon olmasin.
var bot_aktif := false
var bot_hareket := Vector2.ZERO
var bot_nisan := Vector2.RIGHT
var bot_ates := false
var bot_dalis := false
var bot_kor := false

var _yonlu_mu := false
var _yuruyus_var := false
var _onceki_kilit := false
var _onceki_uyari := false

@onready var _gorsel: AnimatedSprite2D = $Gorsel
var _cekirdek: Sprite2D

@onready var _parlama: Sprite2D = $Parlama
@onready var _namlu: Sprite2D = $Namlu
@onready var _kamera: Camera2D = $Kamera

func _ready() -> void:
    add_to_group("oyuncu")
    Hiss.kamera = _kamera
    _parlama.texture = Hiss.parlama_dokusu(
        Color(1.0, 0.72, 0.30, 0.85), Color(1.0, 0.35, 0.05, 0.0), 64)
    _parlama.material = Hiss.ekleme_materyali()
    _namlu.texture = Hiss.parlama_dokusu(
        Color(1.0, 0.96, 0.80, 1.0), Color(1.0, 0.55, 0.15, 0.0), 32)
    _namlu.material = Hiss.ekleme_materyali()
    _namlu.scale = Vector2.ZERO
    # Gorsel denetim bulgusu: gri testinde oyuncu ekranin EN KARANLIK
    # nesnesiydi. "Tek sicak sey sensin" yalnizca renk kanalinda kuruluydu;
    # renk kanali kirilgan (kucuk ekran, GIF, renk korlugu). Bu cekirdek
    # hiyerarsiyi PARLAKLIK kanalina tasiyor: sicak rampanin ust ucu.
    _cekirdek = Sprite2D.new()
    _cekirdek.texture = Hiss.parlama_dokusu(
        Color(1.0, 0.98, 0.92, 1.0), Color(1.0, 0.70, 0.28, 0.0), 32)
    _cekirdek.material = Hiss.ekleme_materyali()
    _cekirdek.z_index = 1
    add_child(_cekirdek)
    _sprite_kur()
    can_degisti.emit(can, maks_can)
    silah_degisti.emit(silah(), silah_indeksi)

## 8 yonlu kareler varsa onu kullan; yoksa tek karelik yedege dus.
## Boylece varlik dosyalari gelmeden de oyun calisir.
const SPRITE_KOK := "res://assets/sprites/oyuncu"

func _sprite_kur() -> void:
    var sf := Yonlu.kur(SPRITE_KOK, {"dur": 6.0, "yuru": 12.0})
    if sf != null:
        _yonlu_mu = true
        _yuruyus_var = Yonlu.durum_var(SPRITE_KOK, "yuru")
        _gorsel.sprite_frames = sf
        _gorsel.animation = "dur_south"
    else:
        sf = SpriteFrames.new()
        sf.remove_animation("default")
        sf.add_animation("dur_south")
        sf.add_frame("dur_south", TEK_DOKU)
        _gorsel.sprite_frames = sf
        _gorsel.animation = "dur_south"
    _gorsel.play()

func silah() -> String:
    return Silahlar.al(silah_indeksi)["ad"]

func silah_ver(i: int) -> void:
    if i in acik_silahlar:
        return
    acik_silahlar.append(i)
    acik_silahlar.sort()
    silah_indeksi = i
    _silah_gecis = 0.25
    silah_degisti.emit(silah(), silah_indeksi)

func silah_gec(ileri: bool = true) -> void:
    if acik_silahlar.size() < 2:
        return
    var k: int = acik_silahlar.find(silah_indeksi)
    k = wrapi(k + (1 if ileri else -1), 0, acik_silahlar.size())
    silah_indeksi = acik_silahlar[k]
    _silah_gecis = 0.25
    _atis_sayaci = maxf(_atis_sayaci, 0.12)
    silah_degisti.emit(silah(), silah_indeksi)
    Hiss.sars(0.6)

func dalisityor() -> bool:
    return _dalis_kalan > 0.0

func _unhandled_key_input(olay: InputEvent) -> void:
    if not olay.is_pressed() or olay.is_echo():
        return
    if olay.keycode == KEY_Q or olay.keycode == KEY_TAB:
        silah_gec(true)
    elif olay.keycode >= KEY_1 and olay.keycode <= KEY_4:
        var i: int = olay.keycode - KEY_1
        if i in acik_silahlar and i != silah_indeksi:
            silah_indeksi = i
            _silah_gecis = 0.25
            silah_degisti.emit(silah(), silah_indeksi)

func _physics_process(delta: float) -> void:
    var kilit_onceki := isi.kilitli
    isi.guncelle(delta)
    if tavlanma:
        _tavlama_izle(kilit_onceki)
    # Muzigin kor katmani isiyla acilir -- durum sesle de anlatilsin.
    SesYonetici.muzik_isi(isi.oran())
    _arena_isisi(delta)
    _kor_yayilimi(delta)
    _isi_sesleri()
    _dokunulmaz = maxf(_dokunulmaz - delta, 0.0)
    _dalis_bekleme = maxf(_dalis_bekleme - delta, 0.0)
    _atis_sayaci = maxf(_atis_sayaci - delta, 0.0)
    _kor_bekleme = maxf(_kor_bekleme - delta, 0.0)
    _namlu_parlama = maxf(_namlu_parlama - delta * 7.0, 0.0)
    _silah_gecis = maxf(_silah_gecis - delta, 0.0)

    var nisan: Vector2
    if bot_aktif:
        nisan = bot_nisan.normalized()
    else:
        nisan = (get_global_mouse_position() - global_position).normalized()
    if nisan == Vector2.ZERO:
        nisan = Vector2.RIGHT

    if _dalis_kalan > 0.0:
        _dalis_kalan -= delta
        _hayalet_sayaci -= delta
        if _hayalet_sayaci <= 0.0:
            _hayalet_sayaci = 0.045
            Hiss.hayalet(_gorsel)
        if _dalis_kalan <= 0.0:
            _dalis_bitti()
        move_and_slide()
        _gorunum_guncelle(delta, nisan)
        return

    if _dalis_istegi() and _dalis_bekleme <= 0.0:
        _dalis_basla(nisan)
        return

    var yon := _hareket_istegi()
    if yon != Vector2.ZERO:
        velocity = velocity.move_toward(yon * hiz, ivme * delta)
    else:
        velocity = velocity.move_toward(Vector2.ZERO, surtunme * delta)
    move_and_slide()

    if _kor_istegi() and kor_atabilir():
        _kor_at(nisan)
    elif _ates_istegi() and isi.ates_edebilir() and _atis_sayaci <= 0.0:
        _ates_et(nisan)
    _gorunum_guncelle(delta, nisan)

## Isi esiklerini GECERKEN ses cal -- her karede degil, sadece gecis aninda.
## Arena termodinamigi. Mangal gorus verir ama isitir; ors korduur ama
## sogutur. Harita boylece isi ekonomisinin parcasi oluyor -- "nerede
## duruyorum" sorusu "ne kadar goruyorum" ve "ne kadar sicagim" ile ayni soru.
func _arena_isisi(delta: float) -> void:
    if isi.kilitli:
        return
    var yakin_mangal := false
    var yakin_ors := false
    var oran := isi.oran()
    for y in get_tree().get_nodes_in_group("yapi"):
        var d := global_position.distance_to(y.global_position)
        if y.turu() == "mangal":
            # Sonuk mangal ne isitir ne aydinlatir -- ama SICAKKEN uzerine
            # gidersen korunu ona birakirsin ve kalici olarak yanar.
            if not y.yanik:
                if d < YAKMA_MENZIL and oran >= YAKMA_ESIK:
                    y.yak()
            elif d < MANGAL_MENZIL:
                yakin_mangal = true
        elif y.turu() == "orsa" and d < ORS_MENZIL:
            yakin_ors = true
    if yakin_mangal:
        isi.deger = minf(isi.deger + MANGAL_ISI * delta, isi.tavan)
        if isi.deger >= isi.tavan:
            isi.kilitle()
    if yakin_ors:
        isi.hizli_sogu(delta, ORS_CARPAN)

## Kor yayilimi. Isi oraniyla olcekleniyor: soguksan hic yakmiyorsun,
## tavana yakinsan cevren erimiye basliyor. Kilitliyken de calisiyor --
## kilit "silahin sustu" demek, "kor sondu" demek degil.
func _kor_yayilimi(delta: float) -> void:
    if yayilim_dps <= 0.0:
        return
    var oran := isi.oran()
    if oran < 0.12:
        return
    _yayilim_sayaci -= delta
    if _yayilim_sayaci > 0.0:
        return
    _yayilim_sayaci = YAYILIM_TICK

    var menzil := 70.0
    var kl := get_tree().get_first_node_in_group("karanlik")
    if kl != null:
        menzil = kl._oyuncu_yaricapi() * yayilim_menzil
    var hasar := yayilim_dps * oran * YAYILIM_TICK
    var menzil_kare := menzil * menzil
    for d in get_tree().get_nodes_in_group("dusman"):
        if global_position.distance_squared_to(d.global_position) <= menzil_kare:
            d.hasar_al(hasar)

func _isi_sesleri() -> void:
    if isi.kilitli and not _onceki_kilit:
        SesYonetici.cal("asiri_isinma")
    _onceki_kilit = isi.kilitli
    var uyari := not isi.kilitli and isi.oran() > 0.85
    if uyari and not _onceki_uyari:
        SesYonetici.cal("isi_uyari")
    _onceki_uyari = uyari

func _hareket_istegi() -> Vector2:
    return bot_hareket if bot_aktif else Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _dalis_istegi() -> bool:
    return bot_dalis if bot_aktif else Input.is_key_pressed(KEY_SPACE)

func _ates_istegi() -> bool:
    return bot_ates if bot_aktif else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _kor_istegi() -> bool:
    return bot_kor if bot_aktif else Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

func _dalis_basla(nisan: Vector2) -> void:
    var yon := _hareket_istegi()
    if yon == Vector2.ZERO:
        yon = nisan
    isi.bosalt()   # kilitliyken calismaz -- asiri isinma cezasi budur
    _dalis_kalan = DALIS_SURE
    _dalis_bekleme = DALIS_BEKLEME
    _hayalet_sayaci = 0.0
    velocity = yon.normalized() * DALIS_HIZ
    Hiss.sars(1.2)
    SesYonetici.cal("dalis")

func _dalis_bitti() -> void:
    velocity *= 0.25
    if dalis_patlamasi <= 0.0:
        return
    Hiss.sars(3.0)
    Hiss.patlama(get_parent(), global_position, Color(1.0, 0.6, 0.2), 22, 150.0, 2.4)
    for d in get_tree().get_nodes_in_group("dusman"):
        var fark: Vector2 = d.global_position - global_position
        if fark.length() < 48.0:
            d.hasar_al(dalis_patlamasi, fark.normalized() * 120.0)

func _ates_et(nisan: Vector2) -> void:
    var s := Silahlar.al(silah_indeksi)
    _atis_sayaci = s["aralik"] / atis_hizi_carpani
    isi.ates_et(float(s["isi"]) * isi_carpani)
    var hasar: float = s["hasar"] * mermi_hasari
    if isi.oran() > 0.7:
        hasar *= asiri_isi_carpani

    var adet: int = int(s["adet"]) + ek_mermi
    var yay: float = float(s["yayilma"]) + ek_yayilma
    for n in adet:
        var sapma := 0.0
        if adet > 1:
            sapma = lerpf(-yay, yay, float(n) / float(adet - 1)) + randf_range(-0.03, 0.03)
        var m := MermiSahne.instantiate()
        m.global_position = global_position + nisan * 10.0
        m.yon = nisan.rotated(sapma)
        m.hasar = hasar
        m.hiz = s["hiz"]
        m.omur = s["omur"]
        m.delici = s["delici"]
        m.scale = Vector2.ONE * float(s["boy"])
        get_parent().add_child(m)

    velocity -= nisan * float(s["geri_tepme"])          # geri tepme
    _namlu_parlama = 1.0
    Hiss.sars(float(s["sarsinti"]))
    SesYonetici.cal("ates")

func kor_atabilir() -> bool:
    return _kor_bekleme <= 0.0 and not isi.kilitli and isi.oran() >= KOR_ESIK

## Kor atisi: biriken isiyi tek delici mermiye cevirir ve isiyi harcar.
## Dalis isiyi bosa harcar, bu onu hasara cevirir -- ayni kaynagin iki cikisi.
func _kor_at(nisan: Vector2) -> Area2D:
    var harcanan := isi.harca(kor_maliyet)
    if harcanan <= 0.0:
        return null
    _kor_bekleme = KOR_BEKLEME
    _atis_sayaci = maxf(_atis_sayaci, 0.18)
    var m := MermiSahne.instantiate()
    m.global_position = global_position + nisan * 12.0
    m.yon = nisan
    m.hasar = mermi_hasari * (2.0 + 7.0 * harcanan) * kor_carpani
    m.delici = true
    m.hiz = 200.0
    m.omur = 1.6
    m.scale = Vector2.ONE * (1.5 + 2.2 * harcanan)
    m.modulate = Color(1.9, 1.35, 0.65)   # normal mermiden daha akkor
    get_parent().add_child(m)

    velocity -= nisan * 150.0 * harcanan
    _namlu_parlama = 1.6
    SesYonetici.cal("kor_atisi")
    var k := get_tree().get_first_node_in_group("karanlik")
    if k != null:
        k.cakma(0.22, 150.0 + 190.0 * harcanan)   # patlama arenayi aydinlatir
    Hiss.sars(2.0 + 4.0 * harcanan)
    Hiss.dondur(0.045)
    Hiss.patlama(get_parent(), global_position + nisan * 14.0,
        Color(1.0, 0.75, 0.3), 16, 190.0, 2.2, 0.35)
    return m

# --- Gorunum ----------------------------------------------------------------

## Isi karakterin altindaki kor parlamasinda okunur; adim sekmesi ve
## namlu alevi hareketi "canli" gosterir.
func _gorunum_guncelle(delta: float, nisan: Vector2) -> void:
    var t := isi.oran()

    # Kor parlamasi: isindikca buyur, beyazlas
    var renk := Color(1.0, 0.45, 0.12).lerp(Color(1.0, 0.95, 0.72), t)
    renk.a = 0.45 + 0.55 * t
    if isi.kilitli:
        var carp := 1.0 if int(Time.get_ticks_msec() / 80) % 2 == 0 else 0.45
        renk = Color(1.0, 0.85, 0.35, 0.95 * carp)
    _parlama.modulate = renk
    _parlama.scale = Vector2.ONE * (0.52 + 0.40 * t + 0.03 * sin(Time.get_ticks_msec() / 90.0))

    # Cekirdek: ekrandaki en yuksek parlaklik. Isi arttikca buyuyup beyazlasir.
    var c_renk := Color(1.0, 0.72, 0.30).lerp(Color(1.0, 0.99, 0.94), t)
    c_renk.a = 0.55 + 0.45 * t
    if isi.kilitli:
        c_renk = Color(1.0, 0.95, 0.75, 0.9 if int(Time.get_ticks_msec() / 80) % 2 == 0 else 0.3)
    _cekirdek.modulate = c_renk
    _cekirdek.scale = Vector2.ONE * (0.16 + 0.22 * t)

    # Isi yuksekken kordan zerre kalkar
    if t > 0.55:
        _kor_zerre -= delta
        if _kor_zerre <= 0.0:
            _kor_zerre = lerpf(0.18, 0.05, t)
            Hiss.patlama(get_parent(), global_position + Vector2(randf_range(-5, 5), 2),
                Color(1.0, 0.6, 0.2), 1, 26.0, 1.1, 0.5)

    # Namlu alevi
    _namlu.position = nisan * 11.0
    _namlu.scale = Vector2.ONE * (0.55 * _namlu_parlama)
    _namlu.visible = _namlu_parlama > 0.02

    # Yurume sekmesi + dalista uzama
    var h := velocity.length()
    if dalisityor():
        _gorsel.scale = Vector2(1.28, 0.78)
    else:
        _adim += delta * (6.0 + h * 0.07)
        # Gercek yuruyus kareleri varsa kod salinimi hafifler
        var g := 0.03 if _yonlu_mu else 0.10
        var s := 1.0 + sin(_adim) * minf(h / hiz, 1.0) * g
        _gorsel.scale = Vector2(2.0 - s, s)
    _gorsel.position.y = -abs(sin(_adim)) * minf(h / hiz, 1.0) * (0.5 if _yonlu_mu else 1.6)

    # Yon: 8 yonlu kareler varsa yone gore animasyon, yoksa aynalama
    if _yonlu_mu:
        var hareketli := h > 6.0 or dalisityor()
        var durum := "yuru" if (hareketli and _yuruyus_var) else "dur"
        var ad := "%s_%s" % [durum, Yonlu.yon_adi(nisan)]
        if _gorsel.animation != ad:
            _gorsel.animation = ad
        if durum == "yuru":
            _gorsel.speed_scale = 1.8 if dalisityor() else clampf(0.55 + h / hiz, 0.4, 1.7)
        else:
            _gorsel.speed_scale = 1.0
        if not _gorsel.is_playing():
            _gorsel.play()
    else:
        _gorsel.flip_h = nisan.x < 0.0

    # Silah degisiminde kisa beyaz parlama
    if _silah_gecis > 0.0:
        _gorsel.modulate = Color(1, 1, 1).lerp(Color(2.2, 2.0, 1.4), _silah_gecis / 0.25)
    elif _dokunulmaz > 0.0 and int(Time.get_ticks_msec() / 60) % 2 == 0:
        _gorsel.modulate = Color(2.4, 1.2, 1.2)
    else:
        _gorsel.modulate = Color(1, 1, 1)

## Kilide girdigin andan cozuldugu ana kadar hasar almadiysan 1 can.
func _tavlama_izle(kilit_onceki: bool) -> void:
    if isi.kilitli and not kilit_onceki:
        _tavlanma_izleme = true
        _tavlanma_temiz = true
        return
    if not isi.kilitli and kilit_onceki and _tavlanma_izleme:
        _tavlanma_izleme = false
        if _tavlanma_temiz and can < maks_can:
            can += 1
            can_degisti.emit(can, maks_can)
            SesYonetici.cal("seviye")
            Hiss.patlama(get_parent(), global_position,
                Color(0.6, 0.85, 1.0), 16, 90.0, 1.6, 0.6)

func hasar_al(miktar: float) -> void:
    if _dokunulmaz > 0.0 or dalisityor() or can <= 0:
        return
    if get_meta("olumsuz", false):      # gelistirici katmani, F3
        _dokunulmaz = VURULMA_DOKUNULMAZLIK
        return
    # Kizgin metal yumusaktir. %70 ustundeki hasar bonusu boylece gercek bir
    # KUMAR oluyor: daha cok vuruyorsun ama daha cok yiyorsun. Onceden bedavaydi.
    _tavlanma_temiz = false      # tavlama bozuldu: kilitte darbe yedin
    can -= int(ceilf(miktar * (KIZGIN_HASAR if isi.oran() > KIZGIN_ESIK else 1.0)))
    _dokunulmaz = VURULMA_DOKUNULMAZLIK
    can_degisti.emit(can, maks_can)
    SesYonetici.cal("oyuncu_hasar")
    Hiss.sars(4.5)
    Hiss.dondur(0.06)
    Hiss.patlama(get_parent(), global_position, Color(1.0, 0.35, 0.25), 14, 130.0, 2.0)
    if can <= 0:
        oldu.emit()
