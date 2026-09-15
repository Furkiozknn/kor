extends Node2D
## Başlangıç ekranı.
##
## İlk izlenim oyunun kimliğini taşımalı: karanlık dökümhane, tek sıcak şey
## oyuncu. Menü de aynı karanlık shader'ını ve aynı temayı kullanıyor —
## menüden oyuna geçerken görsel dil hiç değişmiyor.
##
## Arka planda gerçek oyun sahnesi yok; ucuz bir sahne kurulumu var:
## birkaç mangal ışığı, yanıp sönen korlar, ve ısısı kendiliğinden inip
## çıkan bir "nefes" — mekaniği anlatmadan gösteriyor.

const Tema := preload("res://scripts/tema.gd")
const OYUN := "res://scenes/level.tscn"

## Firin kademeleri. Her biri isi ekonomisine dokunuyor; hicbiri oyuncuya
## kalici GUC vermiyor -- sadece daha zor bir firin ve daha cok curuf.
## Her kademe isinin bir ODULUNU kapatiyor, birikim hizina dokunmuyor.
const KADEMELER := [
    "kapalı",
    "kuru mıknatıs — çekim ısıyla büyümez",
    "çatlak pota — döküm kilidi kırmaz",
    "soğuk demir + dar göz — hasar bonusu yok, görüş %20 dar",
]

var _isik: Array[Vector3] = []
var _mat: ShaderMaterial
var _nefes := 0.0
var _oyuncu: AnimatedSprite2D
var _kademe_yazi: Label
var _ses_yazi: Label
var _kunye: CanvasLayer
var _gorev_katman: CanvasLayer
const Gorevler := preload("res://scripts/gorevler.gd")
var _sarsinti_dugme: Button
var _donma_dugme: Button
var _oto_dugme: Button
var _dil_dugme: Button

## Dil: kayitli ayar, ama komut satiri --en ile zorlanabiliyor.
## Gerekce: tr() ile bicimlenen dizeler SET ANINDA pisiyor ve sonradan
## locale degisince guncellenmiyor (oyunda sorun degil, cunku dil degisimi
## sahneyi yeniden yukluyor). Ekran goruntusu aracinin dogru dili
## gorebilmesi icin locale sahne KURULMADAN once belli olmali.
static func _dil() -> String:
    if "--en" in OS.get_cmdline_user_args():
        return "en"
    var k := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Kayit")
    return str(k.ayar("dil", "tr")) if k != null else "tr"

func _ready() -> void:
    TranslationServer.set_locale(_dil())
    _zemin_kur()
    _karanlik_kur()
    _oyuncu_kur()
    _arayuz_kur()
    SesYonetici.yukle_klasorden()
    SesYonetici.ayarlari_uygula()
    SesYonetici.muzik_cal()
    if bool(Kayit.ayar("tam_ekran", false)):
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _zemin_kur() -> void:
    var karolar := TileMapLayer.new()
    karolar.tile_set = load("res://assets/karolar.tres")
    karolar.modulate = Color(0.50, 0.50, 0.58)
    karolar.z_index = -5
    add_child(karolar)
    for y in 22:
        for x in 40:
            var kenar := x == 0 or y == 0 or x == 39 or y == 21
            var atlas := Vector2i(4 + randi() % 3, 0) if kenar else (
                Vector2i(0, 0) if randf() < 0.8 else Vector2i(1 + randi() % 3, 0))
            karolar.set_cell(Vector2i(x, y), 0, atlas)

    # Mangal ışıkları: sahneyi kuran şey bunlar
    for p in [Vector2(120, 250), Vector2(520, 230), Vector2(300, 300), Vector2(430, 90)]:
        var m := Sprite2D.new()
        m.texture = Hiss.parlama_dokusu(Color(1.0, 0.55, 0.18, 0.32),
            Color(0.9, 0.25, 0.05, 0.0), 96)
        m.material = Hiss.ekleme_materyali()
        m.position = p
        m.z_index = -1
        add_child(m)
        _isik.append(Vector3(p.x, p.y, 62.0))

func _karanlik_kur() -> void:
    var k := CanvasLayer.new()
    k.layer = 1
    add_child(k)
    var e := ColorRect.new()
    e.set_anchors_preset(Control.PRESET_FULL_RECT)
    e.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _mat = ShaderMaterial.new()
    _mat.shader = load("res://assets/karanlik.gdshader")
    _mat.set_shader_parameter("ekran_boyu", get_viewport().get_visible_rect().size)
    e.material = _mat
    k.add_child(e)

func _oyuncu_kur() -> void:
    var hale := Sprite2D.new()
    hale.texture = Hiss.parlama_dokusu(Color(1.0, 0.72, 0.30, 0.85),
        Color(1.0, 0.35, 0.05, 0.0), 64)
    hale.material = Hiss.ekleme_materyali()
    hale.position = Vector2(320, 232)
    hale.z_index = -1
    add_child(hale)
    hale.set_meta("hale", true)

    _oyuncu = AnimatedSprite2D.new()
    var Yonlu := load("res://scripts/yonlu.gd")
    var sf = Yonlu.kur("res://assets/sprites/oyuncu", {"dur": 5.0})
    if sf != null:
        _oyuncu.sprite_frames = sf
        _oyuncu.animation = "dur_south"
        _oyuncu.play()
    _oyuncu.position = Vector2(320, 232)
    add_child(_oyuncu)

func _arayuz_kur() -> void:
    var k := CanvasLayer.new()
    k.layer = 3
    add_child(k)

    var kutu := VBoxContainer.new()
    kutu.theme = Tema.tema()
    kutu.position = Vector2(48, 54)
    kutu.add_theme_constant_override("separation", Tema.BOSLUK_S)
    k.add_child(kutu)

    var ad := Tema._yazi("KOR", 48, Tema.KOR)
    kutu.add_child(ad)
    kutu.add_child(Tema.sonuk("karanlıkta ne kadar görürsen o kadar yakınsın"))

    var bosluk := Control.new()
    bosluk.custom_minimum_size = Vector2(0, Tema.BOSLUK_L)
    kutu.add_child(bosluk)

    kutu.add_child(Tema.govde("Dökümhane söndü. Elinde kalan tek ateş sensin."))

    var bosluk2 := Control.new()
    bosluk2.custom_minimum_size = Vector2(0, Tema.BOSLUK_M)
    kutu.add_child(bosluk2)

    # Kalici durum: curuf ve rekor
    var rekor: float = float(Kayit._veri.get("en_iyi_sure", 0.0))
    # Biriken toplam yerine EN IYI KOSU gosteriliyor: curuf harcanmiyor,
    # yani biriken bir sayi olarak gostermek olmayan bir dukkan sozu veriyor.
    var durum := tr("EN İYİ DÖKÜM %d") % Kayit.en_iyi_curuf()
    if rekor > 0.0:
        durum += tr("     en iyi %02d:%02d") % [int(rekor) / 60, int(rekor) % 60]
    kutu.add_child(Tema.vurgu(durum))

    # FIRIN KADEMESI -- gonullu zorluk, Kor'un kendi diliyle. Her kademe
    # isi ekonomisine dokunuyor ve curuf kazancini carpiyor.
    var kad := HBoxContainer.new()
    kad.add_theme_constant_override("separation", Tema.BOSLUK_S)
    kad.add_child(Tema.sonuk("FIRIN"))
    for n in KADEMELER.size():
        var d := Button.new()
        d.text = str(n)
        d.custom_minimum_size = Vector2(26, 22)
        d.pressed.connect(_kademe_sec.bind(n))
        kad.add_child(d)
    _kademe_yazi = Tema.sonuk("")
    kad.add_child(_kademe_yazi)
    kutu.add_child(kad)

    # Ses ayarlari -- kalici. Ayri bir ayarlar ekrani acmak yerine menude,
    # cunku tek ihtiyac bu ve fazladan adim UX borcudur.
    var ses := HBoxContainer.new()
    ses.add_theme_constant_override("separation", Tema.BOSLUK_S)
    ses.add_child(Tema.sonuk("SES"))
    for bilgi in [["müzik", "ses_muzik", -14.0], ["efekt", "ses_efekt", -6.0]]:
        ses.add_child(Tema.sonuk(str(bilgi[0])))
        var eksi := Button.new()
        eksi.text = "-"
        eksi.custom_minimum_size = Vector2(20, 20)
        eksi.pressed.connect(_ses_degis.bind(str(bilgi[1]), -4.0, float(bilgi[2])))
        ses.add_child(eksi)
        var arti := Button.new()
        arti.text = "+"
        arti.custom_minimum_size = Vector2(20, 20)
        arti.pressed.connect(_ses_degis.bind(str(bilgi[1]), 4.0, float(bilgi[2])))
        ses.add_child(arti)
    _ses_yazi = Tema.sonuk("")
    ses.add_child(_ses_yazi)
    kutu.add_child(ses)

    # ERISILEBILIRLIK. Kor'da sarsinti ve vurus donmasi surekli; hareket
    # duyarliligi olan oyuncu icin bu bir bariyer. Ayri bir "erisilebilirlik"
    # ekrani acmiyoruz -- iki dugme, ses satirinin hemen altinda.
    var hrk := HBoxContainer.new()
    hrk.add_theme_constant_override("separation", Tema.BOSLUK_S)
    hrk.add_child(Tema.sonuk("HAREKET"))
    _sarsinti_dugme = Button.new()
    _sarsinti_dugme.custom_minimum_size = Vector2(104, 20)
    _sarsinti_dugme.pressed.connect(_sarsinti_degis)
    hrk.add_child(_sarsinti_dugme)
    _donma_dugme = Button.new()
    _donma_dugme.custom_minimum_size = Vector2(104, 20)
    _donma_dugme.pressed.connect(_donma_degis)
    hrk.add_child(_donma_dugme)
    _oto_dugme = Button.new()
    _oto_dugme.custom_minimum_size = Vector2(112, 20)
    _oto_dugme.pressed.connect(_oto_degis)
    hrk.add_child(_oto_dugme)
    # DIL. Anahtarlar Turkce metinlerin kendisi oldugu icin "tr" secildiginde
    # ceviri tablosu devreden cikiyor ve oyun kaynaktaki metinleri gosteriyor.
    _dil_dugme = Button.new()
    _dil_dugme.custom_minimum_size = Vector2(72, 20)
    _dil_dugme.pressed.connect(_dil_degis)
    hrk.add_child(_dil_dugme)
    kutu.add_child(hrk)

    var bosluk3 := Control.new()
    bosluk3.custom_minimum_size = Vector2(0, Tema.BOSLUK_M)
    kutu.add_child(bosluk3)

    var basla := Button.new()
    basla.text = "  BAŞLA      [Enter]"
    basla.custom_minimum_size = Vector2(196, 30)
    basla.pressed.connect(_basla)
    kutu.add_child(basla)
    basla.grab_focus()
    _kademe_tazele()
    _ses_tazele()
    _hareket_tazele()

    # Tek satira sigmiyordu (93 karakter, 640 piksel) -- son iki ipucu
    # ekran disinda kaliyordu. Iki satir + tam genislikte ortalama: sabit
    # koordinat yok, yazi tipi degisse de kesilmez.
    var alt := Tema.sonuk("WASD hareket · SOL TIK ateş · SAĞ TIK kor · BOŞLUK dalış")
    var alt2 := Tema.sonuk("E döküm · Q silah · G görevler · F11 tam ekran · C künye")
    alt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    alt.offset_left = Tema.BOSLUK_M
    alt.offset_right = -Tema.BOSLUK_M
    alt.offset_top = -58
    alt.offset_bottom = -34
    alt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    alt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    alt.modulate = Color(1, 1, 1, 0.55)
    k.add_child(alt)
    alt2.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    alt2.offset_left = Tema.BOSLUK_M
    alt2.offset_right = -Tema.BOSLUK_M
    alt2.offset_top = -34
    alt2.offset_bottom = -10
    alt2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    alt2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    alt2.modulate = Color(1, 1, 1, 0.55)
    k.add_child(alt2)

## Sarsinti uc kademe: tam / yari / kapali. Yari kademe onemli -- cogu
## oyuncu sarsintiyi sevmiyor ama tamamen kapatinca vurus hissi kayboluyor.
const SARSINTI_KADEME := [1.0, 0.5, 0.0]
const SARSINTI_AD := ["sarsıntı tam", "sarsıntı yarı", "sarsıntı yok"]

func _sarsinti_degis() -> void:
    var su := float(Kayit.ayar("sarsinti", 1.0))
    var i := 0
    for n in SARSINTI_KADEME.size():
        if is_equal_approx(SARSINTI_KADEME[n], su):
            i = n
    Kayit.ayar_yaz("sarsinti", SARSINTI_KADEME[(i + 1) % SARSINTI_KADEME.size()])
    Hiss.ayarlari_uygula()
    SesYonetici.cal("kart_sec")
    _hareket_tazele()

func _donma_degis() -> void:
    Kayit.ayar_yaz("donma", not bool(Kayit.ayar("donma", true)))
    Hiss.ayarlari_uygula()
    SesYonetici.cal("kart_sec")
    _hareket_tazele()

## Dil degisimi sahneyi yeniden kuruyor: kurulmus Label'larin metni
## otomatik guncellenmiyor (bircogu tr() ile bir kez bicimlenmis).
func _dil_degis() -> void:
    var yeni := "en" if str(Kayit.ayar("dil", "tr")) == "tr" else "tr"
    Kayit.ayar_yaz("dil", yeni)
    Kayit.kaydet()
    TranslationServer.set_locale(yeni)
    get_tree().reload_current_scene()

func _oto_degis() -> void:
    Kayit.ayar_yaz("otomatik_ates", not bool(Kayit.ayar("otomatik_ates", false)))
    SesYonetici.cal("kart_sec")
    _hareket_tazele()

func _hareket_tazele() -> void:
    if _sarsinti_dugme == null:
        return
    if _oto_dugme != null:
        _oto_dugme.text = "oto ateş açık" if bool(Kayit.ayar("otomatik_ates", false)) else "oto ateş kapalı"
    if _dil_dugme != null:
        _dil_dugme.text = "TÜRKÇE" if str(Kayit.ayar("dil", "tr")) == "tr" else "ENGLISH"
    var su := float(Kayit.ayar("sarsinti", 1.0))
    var i := 0
    for n in SARSINTI_KADEME.size():
        if is_equal_approx(SARSINTI_KADEME[n], su):
            i = n
    _sarsinti_dugme.text = SARSINTI_AD[i]
    _donma_dugme.text = "donma açık" if bool(Kayit.ayar("donma", true)) else "donma kapalı"

func _kademe_sec(k: int) -> void:
    Kayit.kademe_yaz(k)
    SesYonetici.cal("kart_sec")
    _kademe_tazele()

func _kademe_tazele() -> void:
    if _kademe_yazi == null:
        return
    var k: int = clampi(Kayit.kademe(), 0, KADEMELER.size() - 1)
    _kademe_yazi.text = tr("  %s   (cüruf x%.2f)") % [tr(str(KADEMELER[k])), Kayit.kademe_carpani()]

func _ses_degis(anahtar: String, delta_db: float, varsayilan: float) -> void:
    var d: float = clampf(float(Kayit.ayar(anahtar, varsayilan)) + delta_db, -40.0, 6.0)
    Kayit.ayar_yaz(anahtar, d)
    SesYonetici.ayarlari_uygula()
    SesYonetici.cal("kup")
    _ses_tazele()

func _ses_tazele() -> void:
    if _ses_yazi == null:
        return
    _ses_yazi.text = "   %+.0f / %+.0f dB" % [
        float(Kayit.ayar("ses_muzik", -14.0)), float(Kayit.ayar("ses_efekt", -6.0))]

func _process(delta: float) -> void:
    # Nefes: ısının inip çıkışını menüde de görüyorsun. Mekaniği anlatmadan
    # gösteren en ucuz yol.
    _nefes += delta * 0.55
    var oran := 0.5 + 0.5 * sin(_nefes)
    var yaricap := lerpf(46.0, 210.0, oran)

    var liste: Array[Vector3] = [Vector3(320, 232, yaricap)]
    liste.append_array(_isik)
    _mat.set_shader_parameter("isik_sayisi", liste.size())
    _mat.set_shader_parameter("isiklar", liste)

    for c in get_children():
        if c is Sprite2D and c.has_meta("hale"):
            c.scale = Vector2.ONE * (0.5 + 0.55 * oran)
            c.modulate = Color(1.0, 0.45, 0.12).lerp(Color(1.0, 0.95, 0.72), oran)

func _unhandled_key_input(olay: InputEvent) -> void:
    if not olay.is_pressed() or olay.is_echo():
        return
    var k := (olay as InputEventKey).keycode
    if k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
        _basla()
    elif k == KEY_C:
        _kunye_degis()
    elif k == KEY_G:
        _gorev_degis()
    elif k == KEY_F11:
        _tam_ekran_degis()
    elif k == KEY_ESCAPE:
        get_tree().quit()

## Kunye. Kullanilan CC0 varliklarin hakki teslim ediliyor -- CC0 atif
## zorunlu kilmiyor ama Kenney'in kendi lisans dosyasi "destek olmak
## istersen kredi ver" diyor, ve tamamlanmis bir urunde bu ekran olur.
func _kunye_degis() -> void:
    if _kunye != null and is_instance_valid(_kunye):
        _kunye.queue_free()
        _kunye = null
        return
    _kunye = CanvasLayer.new()
    _kunye.layer = 5
    add_child(_kunye)
    var fon := ColorRect.new()
    fon.color = Color(0.01, 0.01, 0.03, 0.9)
    fon.set_anchors_preset(Control.PRESET_FULL_RECT)
    _kunye.add_child(fon)
    var sarmal := PanelContainer.new()
    sarmal.theme = Tema.tema()
    sarmal.position = Vector2(64, 54)
    sarmal.custom_minimum_size = Vector2(512, 0)
    sarmal.add_theme_stylebox_override("panel",
        Tema.kutu(Tema.GOVDE, Tema.KENAR_KOR, 1, Tema.BOSLUK_L))
    _kunye.add_child(sarmal)
    var kutu := VBoxContainer.new()
    kutu.add_theme_constant_override("separation", Tema.BOSLUK_S)
    sarmal.add_child(kutu)
    kutu.add_child(Tema.baslik("KÜNYE"))
    for satir in [
        ["Motor", "Godot Engine 4.7 — MIT"],
        ["Yazı tipi", "PublicPixel — CC0"],
        ["Zemin, siper, ikon, iki düşman", "Kenney Tiny Dungeon — CC0"],
        ["Oyuncu, patron, düşman sprite'ları", "PixelLab ile üretildi"],
        ["Ses ve müzik", "sfxr algoritmasıyla kodda üretildi"],
        ["Kod, tasarım, denge", "Claude — Furkiozknn için"],
    ]:
        var r := HBoxContainer.new()
        r.add_theme_constant_override("separation", Tema.BOSLUK_M)
        var sol := Tema.sonuk(str(satir[0]))
        sol.custom_minimum_size = Vector2(230, 0)
        r.add_child(sol)
        r.add_child(Tema.govde(str(satir[1])))
        kutu.add_child(r)
    var b := Control.new()
    b.custom_minimum_size = Vector2(0, Tema.BOSLUK_M)
    kutu.add_child(b)
    kutu.add_child(Tema.vurgu("C ile kapat"))

func _tam_ekran_degis() -> void:
    var tam: bool = not bool(Kayit.ayar("tam_ekran", false))
    Kayit.ayar_yaz("tam_ekran", tam)
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if tam
        else DisplayServer.WINDOW_MODE_WINDOWED)

func _basla() -> void:
    SesYonetici.cal("kart_sec")
    get_tree().change_scene_to_file(OYUN)


## GOREV LISTESI. Oyuncu neyin pesinde oldugunu bilmeli -- yoksa gorev
## sistemi "kosu bitince surpriz cikan sey"e donusur ve hedef olmaz.
## itch'te Steam basarimi yok; bu liste onun yerini tutuyor.
func _gorev_degis() -> void:
    if _gorev_katman != null and is_instance_valid(_gorev_katman):
        _gorev_katman.queue_free()
        _gorev_katman = null
        return
    _gorev_katman = CanvasLayer.new()
    _gorev_katman.layer = 5
    add_child(_gorev_katman)
    var fon := ColorRect.new()
    fon.color = Color(0.01, 0.01, 0.03, 0.9)
    fon.set_anchors_preset(Control.PRESET_FULL_RECT)
    _gorev_katman.add_child(fon)

    var sarmal := PanelContainer.new()
    sarmal.theme = Tema.tema()
    sarmal.set_anchors_preset(Control.PRESET_FULL_RECT)
    sarmal.offset_left = 48
    sarmal.offset_right = -48
    sarmal.offset_top = 40
    sarmal.offset_bottom = -34
    sarmal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    sarmal.add_theme_stylebox_override("panel",
        Tema.kutu(Tema.GOVDE, Tema.KENAR_KOR, 1, Tema.BOSLUK_L))
    _gorev_katman.add_child(sarmal)

    var kutu := VBoxContainer.new()
    kutu.add_theme_constant_override("separation", Tema.BOSLUK_S)
    sarmal.add_child(kutu)
    kutu.add_child(Tema.baslik("GÖREVLER"))
    kutu.add_child(Tema.sonuk("içerik parayla değil ustalıkla açılır"))
    var bosluk := Control.new()
    bosluk.custom_minimum_size = Vector2(0, Tema.BOSLUK_M)
    kutu.add_child(bosluk)

    var acik_sayi := 0
    for g in Gorevler.LISTE:
        var acik: bool = Kayit.acik(str(g["kod"]))
        if acik:
            acik_sayi += 1
        var l := Tema.vurgu(tr("✓  %s") % tr(str(g["ad"]))) if acik else Tema.govde(tr("·  %s") % tr(str(g["ad"])))
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        kutu.add_child(l)
        var alt := Tema.sonuk(tr("     %s  →  %s") % [
            tr("AÇILDI") if acik else tr(str(g["aciklama"])), tr(str(g["odul"]))])
        alt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        kutu.add_child(alt)

    var bosluk2 := Control.new()
    bosluk2.custom_minimum_size = Vector2(0, Tema.BOSLUK_M)
    kutu.add_child(bosluk2)
    kutu.add_child(Tema.sonuk(tr("%d/%d açıldı   ·   G kapat") % [acik_sayi, Gorevler.LISTE.size()]))
