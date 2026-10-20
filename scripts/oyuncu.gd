extends CharacterBody2D
## Kor oyuncusu: 8 yönlü hareket, fareye nişan alan ateş, ısı + dalış,
## dört silah ve biriken ısıyı hasara çeviren kor atışı.

const Isi := preload("res://scripts/isi.gd")
const Silahlar := preload("res://scripts/silahlar.gd")
const Erisim := preload("res://scripts/erisim.gd")
const MermiSahne := preload("res://scenes/mermi.tscn")
const Yonlu := preload("res://scripts/yonlu.gd")
const TEK_DOKU := preload("res://assets/sprites/oyuncu.png")

signal can_degisti(can: int, maks: int)
signal silah_degisti(ad: String, indeks: int)
signal oldu
signal dokum_degisti(oran: float, hazir: bool)

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
## KIZGIN CELIK kartinin esigi AYRI: kirilganlik esigi %70'te kaliyor
## (hasar almak orada iki katina cikmali) ama kartin odulu %50'ye indi --
## olculdu, %70'te kart cogu zaman hicbir sey yapmiyordu (-50,3 sn).
const KIZGIN_ESIK_KART := 0.50
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
## Silah indeksi -> damga anahtarlari. KOSU BOYUNCA kalici.
var damgalar := {}

func silah_damgalari(i: int = -1) -> Array:
    return damgalar.get(i if i >= 0 else silah_indeksi, [])

func damga_takilabilir(i: int = -1) -> bool:
    return silah_damgalari(i).size() < Silahlar.DAMGA_TAVANI

## Damgayi ELDEKI silaha vurur. Ayni damga iki kez takilmaz.
func damga_tak(anahtar: String) -> bool:
    var i := silah_indeksi
    var liste: Array = damgalar.get(i, [])
    if liste.size() >= Silahlar.DAMGA_TAVANI or anahtar in liste:
        return false
    liste.append(anahtar)
    damgalar[i] = liste
    silah_degisti.emit(silah(), silah_indeksi)
    return true

# Kartlarla buyuyen degerler (silahin ustune carpan olarak biner)
var atis_hizi_carpani := 1.0
var isi_carpani := 1.0         # kart: atis basina isi
var mermi_hasari := 1.0
var ek_mermi := 0
var ek_yayilma := 0.0
var asiri_isi_carpani := 1.0   # isi > %70 iken gecerli
## Firin kademesi 1: sicak bolgenin HASAR odulu kapaniyor (kirilganlik kaliyor).
var sicak_hasar_bonusu := true
## KARANLIK GOZU karti: soguk bandda (isi < %30) hasar carpani.
## Olculdu: isinin UCLARINDA tanimli kartlar kaybediyordu cunku oyuncu
## orta bandda yasiyor; soguk tarafa gercek bir odul gerekiyordu.
var soguk_hasar_bonusu := 1.0
## Firin kademesi 2: dokum artik kilidi kirmiyor -- guvenlik valfi yok.
var dokum_kilit_kirar := true
## Firin kademesi 1: miknatis artik isiyla buyumuyor -- kupleri elle topla.
var miknatis_isiya_bagli := true
var dalis_patlamasi := 0.0     # dalis bitince cevreye hasar
## XP kupu cekim menzili. SABIT DEGIL -- isiyla buyuyor.
##
## Turun imza dopamin ani "kupler ekran disindan sana akiyor". Kor'da bu
## HIC yoktu: menzil 38 piksel sabitti, kupler yerinde duruyordu ve
## oyuncu her birini tek tek toplamak zorundaydi.
##
## Ama bunu VS'ten kopyalamiyoruz: Kor'da akis ISININ odulu. Sicaksan
## dokumhane senin etrafinda toplaniyor. Boylece tek satirda hem turun
## imza ani geliyor hem de isi ekonomisinin bir degiskeni daha aciliyor.
var miknatis := 38.0
var miknatis_carpani := 1.0    # kart: taban menzili buyutur
const MIKNATIS_ISI_KAZANC := 3.4   # tavanda menzil bu kat buyur

func miknatis_menzili() -> float:
    var isi_kazanci := lerpf(1.0, MIKNATIS_ISI_KAZANC, isi.oran()) if miknatis_isiya_bagli else 1.0
    return miknatis * miknatis_carpani * isi_kazanci
var kor_carpani := 1.0         # kart: kor atisi hasari
## ISI BIR KAYNAK, SIFIRLANAN BIR SAYAC DEGIL.
##
## Onceden 1,0'di: kor atisi biriken isinin TAMAMINI siliyordu. Isinin uc
## gideri var ve ikisi tamamini yok ediyordu -- dalis (bosalt) ve kor
## atisi. Kor atisi oyuncunun ana alan hasari, yani HER GUCLU SALDIRIDA
## isi sifirlaniyordu. Isi biriktirilemiyordu, cunku onu harcamanin tek
## yolu onu yok etmekti.
##
## Olculdu (8'er kosuluk uc kol, tek parti, politika degisikligi yok):
##   1,0 -> sicak bandda %8,6 / soguk bandda %46,9
##   0,6 -> %13,0 / %23,1
##   0,3 -> %30,6 / %12,1   (t=5,24)
## Ve BEDAVA GUC DEGIL: hayatta kalma degismiyor (t=1,03), cunku oldurme
## dusuyor (924 -> 875 -> 792). Denge notr; degisen sey oyuncunun
## isi bandinda NEREDE YASADIGI.
##
## Bu tek sabit KIZGIN CELIK, GENIS KAZAN, tavlama ve firin kademelerini
## kendiliginden anlamli yapiyor -- hepsi isinin ustte kalabilmesine bagli.
var kor_maliyet := 0.4
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
    hic_silah_degisti = true
    var k: int = acik_silahlar.find(silah_indeksi)
    k = wrapi(k + (1 if ileri else -1), 0, acik_silahlar.size())
    silah_indeksi = acik_silahlar[k]
    _silah_gecis = 0.25
    _atis_sayaci = maxf(_atis_sayaci, 0.12)
    silah_degisti.emit(silah(), silah_indeksi)
    Hiss.sars(0.6)

func dalisityor() -> bool:
    return _dalis_kalan > 0.0

## --- DOKUM: sarjli, tek kullanimlik ozel silah -----------------------
##
## Tur kalibi: "dolunca bas". Kor'da bundan iki yerde ayriliyoruz.
##
## 1. GUCU SARJA DEGIL ISINA BAGLI. Dolmus dokumu bosken atarsan zayif,
##    tavana yakinken atarsan yikici. Yani "ne zaman basayim" sorusu
##    "ne kadar riske girdim" sorusuyla ayni soru oluyor -- bekleme
##    suresini saymak degil, isini yonetmek.
## 2. KILIDI KIRAN TEK SEY. Dalis bile kirmiyor (isi.bosalt kilitliyken
##    calismiyor). Asiri isindiysan dokum can simidin -- ama onu o an
##    harcamis oluyorsun.
##
## Doldugunda ISI SIFIRLANIR: dokum ayni zamanda en buyuk dalis.
const DOKUM_SURE := 42.0        # saniye, tam dolum
const DOKUM_MENZIL := 58.0      # taban; isiyla buyur
const DOKUM_MENZIL_ISI := 104.0 # tavanda eklenen menzil
const DOKUM_HASAR := 7.0        # taban; isiyla 2,6 kata cikar

var dokum_sarj := 0.0           # 0..1
var dokum_kullanim := 0         # kac kez dokum yapildi (ozet icin)

func dokum_hazir() -> bool:
    return dokum_sarj >= 1.0

func _dokum_guncelle(delta: float) -> void:
    if dokum_sarj >= 1.0:
        return
    var onceki := dokum_sarj
    dokum_sarj = minf(dokum_sarj + delta / DOKUM_SURE, 1.0)
    if onceki < 1.0 and dokum_sarj >= 1.0:
        SesYonetici.cal("seviye")
        Hiss.sars(2.0)
    dokum_degisti.emit(dokum_sarj, dokum_hazir())

## Doner: dokum yapildi mi. Bot ve testler de bunu cagiriyor.
func dokum_yap() -> bool:
    if not dokum_hazir() or can <= 0:
        return false
    var oran := isi.oran()
    var menzil := DOKUM_MENZIL + DOKUM_MENZIL_ISI * oran
    var hasar := DOKUM_HASAR * (0.55 + 2.05 * oran)

    for dus in get_tree().get_nodes_in_group("dusman"):
        if not is_instance_valid(dus):
            continue
        var fark: Vector2 = dus.global_position - global_position
        if fark.length() <= menzil:
            dus.hasar_al(hasar, fark.normalized() * (150.0 + 90.0 * oran))

    # Sonuk mangallari da yakar: dokum dokumhaneyi besler.
    for y in get_tree().get_nodes_in_group("yapi"):
        if y.turu() == "mangal" and not y.yanik                 and y.global_position.distance_to(global_position) <= menzil:
            y.yak()

    if dokum_kilit_kirar:
        isi.kilitli = false      # KILIDI KIRAN TEK SEY (firin 2'de kapali)
    isi.deger = 0.0
    dokum_sarj = 0.0
    dokum_kullanim += 1
    _dokunulmaz = maxf(_dokunulmaz, 0.45)   # dokum aninda kisa bagisiklik
    Hiss.sars(9.0)
    Hiss.dondur(0.14)
    Hiss.patlama(get_parent(), global_position, Color(1.0, 0.72, 0.28),
        70, menzil * 3.4, 3.0, 0.9)
    SesYonetici.cal("kor_atisi")
    var kl := get_tree().get_first_node_in_group("karanlik")
    if kl != null:
        kl.cakma(0.45, menzil * 2.6)
    dokum_degisti.emit(dokum_sarj, false)
    return true

## Gamepad dugmeleri _unhandled_key_input'a DUSMEZ (InputEventJoypadButton).
## Eylem bazli kanca hem klavyeyi hem pad'i yakaliyor.
func _unhandled_input(olay: InputEvent) -> void:
    if olay.is_echo():
        return
    if olay.is_action_pressed("dokum"):
        dokum_yap()
        get_viewport().set_input_as_handled()
    elif olay.is_action_pressed("silah_gec"):
        silah_gec(true)
        get_viewport().set_input_as_handled()

func _unhandled_key_input(olay: InputEvent) -> void:
    if not olay.is_pressed() or olay.is_echo():
        return
    if olay.keycode >= KEY_1 and olay.keycode <= KEY_4:
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
        _tavlama_tavanda(delta)
    # Muzigin kor katmani isiyla acilir -- durum sesle de anlatilsin.
    SesYonetici.muzik_isi(isi.oran())
    _arena_isisi(delta)
    _kor_yayilimi(delta)
    _isi_sesleri()
    _dokunulmaz = maxf(_dokunulmaz - delta, 0.0)
    _dalis_bekleme = maxf(_dalis_bekleme - delta, 0.0)
    _dokum_guncelle(delta)
    _atis_sayaci = maxf(_atis_sayaci - delta, 0.0)
    _kor_bekleme = maxf(_kor_bekleme - delta, 0.0)
    _namlu_parlama = maxf(_namlu_parlama - delta * 7.0, 0.0)
    _silah_gecis = maxf(_silah_gecis - delta, 0.0)

    var nisan: Vector2
    if bot_aktif:
        nisan = bot_nisan.normalized()
    else:
        # GAMEPAD NISANI: sag cubuk hareket ederse fareyi eziyor, ama fare
        # de her an calismaya devam ediyor -- oyuncu ikisi arasinda gecis
        # yapabiliyor ve bir "girdi modu" secmek zorunda kalmiyor.
        var cubuk := Input.get_vector("nisan_sol", "nisan_sag", "nisan_yukari", "nisan_asagi")
        if cubuk.length() > 0.25:
            nisan = cubuk.normalized()
            _son_nisan = nisan
        else:
            nisan = (get_global_mouse_position() - global_position).normalized()
            if nisan != Vector2.ZERO:
                _son_nisan = nisan
    if nisan == Vector2.ZERO:
        nisan = _son_nisan

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
        hic_hareket = true
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
    if bot_aktif:
        return bot_ates
    if otomatik_ates:
        return true
    return Input.is_action_pressed("ates")

func _kor_istegi() -> bool:
    return bot_kor if bot_aktif else Input.is_action_pressed("kor")

## Oyuncu bir kez bile daldiysa ogretmeye gerek yok.
var hic_daldi := false
var hic_hareket := false
var hic_ates := false
var hic_silah_degisti := false
## Ayar: sol tusu basili tutmadan surekli ates. Nisan yine oyuncuda.
var otomatik_ates := false
## Accessibility: steady invulnerability tint instead of the 5.9 Hz blink (scripts/erisim.gd).
var sakin_isik := false
## Son gecerli nisan yonu. Gamepad'de cubuk birakilinca sifira dusuyor;
## oyuncunun namlusu o anda saga zıplamasin diye son yon korunuyor.
var _son_nisan := Vector2.RIGHT

func _dalis_basla(nisan: Vector2) -> void:
    hic_daldi = true
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
    hic_ates = true
    var s := Silahlar.damgali(silah_indeksi, silah_damgalari())
    _atis_sayaci = s["aralik"] / atis_hizi_carpani
    isi.ates_et(float(s["isi"]) * isi_carpani, Silahlar.isi_gecikmesi(s))
    var hasar: float = s["hasar"] * mermi_hasari
    if sicak_hasar_bonusu and isi.oran() > KIZGIN_ESIK_KART:
        hasar *= asiri_isi_carpani
    elif isi.oran() < 0.30:
        hasar *= soguk_hasar_bonusu

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
        if "kor_izi" in silah_damgalari():
            m.kor_izi = true
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
    # 60 ms = 8,3 Hz -- fotosensitif nobet esiginin (3-60 Hz) tam icinde
    # ve gozu yoruyor. 85 ms = 5,9 Hz: hala net okunuyor, cok daha sakin.
    # Calm lights (accessibility): a steady tint instead of the blink.
    elif _dokunulmaz > 0.0:
        _gorsel.modulate = Erisim.dokunulmaz_rengi(Time.get_ticks_msec(), sakin_isik)
    else:
        _gorsel.modulate = Color(1, 1, 1)

## Kilide girdigin andan cozuldugu ana kadar hasar almadiysan 1 can.
## ZAFER TURUNDA TAVLAMA. Kilit kapaninca (isi.kilit_acik = false)
## tavlama iyilesmesi de kapaniyordu -- cunku kilide GIRMEYE bagliydi.
## Yani oyuncu, yipranmanin en yuksek oldugu son ucte birde iyilesemez
## hale geliyordu. Olculdu: oyuncu finale 1 CANLA variyor.
##
## Kilit yokken tavlama TAVANDA DURMAYA baglaniyor: isi %95 ustunde,
## hasar almadan TAVLAMA_SURESI kadar dayanirsan 1 can. Tasarim ayni
## kaliyor -- odul hala "tavana cik ve orada dayan" -- sadece kilit
## olmadigi durumda da olculebiliyor.
const TAVLAMA_TAVAN_ESIK := 0.95
const TAVLAMA_SURESI := 2.0
var _tavlama_tavan_sayac := 0.0

func _tavlama_tavanda(delta: float) -> void:
    if isi.kilit_acik or can <= 0:
        _tavlama_tavan_sayac = 0.0
        return
    if isi.oran() < TAVLAMA_TAVAN_ESIK:
        _tavlama_tavan_sayac = 0.0
        return
    _tavlama_tavan_sayac += delta
    if _tavlama_tavan_sayac < TAVLAMA_SURESI:
        return
    _tavlama_tavan_sayac = 0.0
    if can >= maks_can:
        return
    can += 1
    can_degisti.emit(can, maks_can)
    SesYonetici.cal("seviye")
    Hiss.patlama(get_parent(), global_position,
        Color(0.6, 0.85, 1.0), 16, 90.0, 1.6, 0.6)

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
    _tavlama_tavan_sayac = 0.0   # tavanda dayanma sayaci da sifirlanir
    can -= int(ceilf(miktar * (KIZGIN_HASAR if isi.oran() > KIZGIN_ESIK else 1.0)))
    _dokunulmaz = VURULMA_DOKUNULMAZLIK
    can_degisti.emit(can, maks_can)
    SesYonetici.cal("oyuncu_hasar")
    Hiss.sars(4.5)
    Hiss.dondur(0.06)
    Hiss.patlama(get_parent(), global_position, Color(1.0, 0.35, 0.25), 14, 130.0, 2.0)
    if can <= 0:
        oldu.emit()
