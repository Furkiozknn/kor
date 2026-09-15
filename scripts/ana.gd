extends Node2D
## Kor -- koşu döngüsü: arena, dalga doğurma, XP, seviye kartları, HUD, ölüm.

const DusmanSahne := preload("res://scenes/dusman.tscn")
const KupSahne := preload("res://scenes/kup.tscn")
const YapiSahne := preload("res://scenes/yapi.tscn")
const Silahlar := preload("res://scripts/silahlar.gd")
const Gorevler := preload("res://scripts/gorevler.gd")
const PatronSahne := preload("res://scenes/patron.tscn")
const Dalgalar := preload("res://scripts/dalgalar.gd")
const YAZI_TIPI := preload("res://assets/fonts/PublicPixel.ttf")
const Tema := preload("res://scripts/tema.gd")
const KaranlikSahne := preload("res://scripts/karanlik.gd")
const GelistiriciSahne := preload("res://scripts/gelistirici.gd")

const SUTUN := 40
const SATIR := 22
const KARO := 16
# Arenanin ic siniri (duvarlar haric)
const ALAN := Rect2(40, 40, 560, 256)

const ZEMIN_SADE := Vector2i(0, 0)
## Dalga tasarimi. Olculdu: eski egri (1.30 - gecen*0.012, taban 0.16) 95.
## saniyede saniyede 6,25 dusmana cikiyordu; bot saniyede ~1,5 olduruyor,
## yani olum matematiksel olarak kacinilmazdi. Cozum tur standardi: spawn
## hizini sinirsiz artirmak yerine CANLI DUSMAN TAVANI koy, zorlugu
## bilesim ve guc ile buyut.
## Patron dogum anlari. Her patron sonrasi dalgalar sertlesir.


## Arena bilesimi SABIT, rastgele degil. Onceden her yapi 6 turden rastgele
## seciliyordu; sansa gore bir kosuda hic mangal olmayabiliyordu -- yani
## arena cografyasi, yani isi ekonomisinin yari yarisi, yazi-tura idi.
## Torba karistiriliyor: yerlesim rastgele, BILESIM garanti.
const YAPI_BILESIMI := [
    "mangal", "mangal", "mangal", "mangal", "mangal",
    "orsa", "orsa",
    "fici", "fici", "fici", "sandik", "sandik", "fici_yigin", "fici_yigin",
]

@onready var oyuncu: CharacterBody2D = $Oyuncu
@onready var _karolar: TileMapLayer = $TileMapLayer

var gecen := 0.0
var seviye := 1
var xp := 0
var xp_hedef := 5
var oldurulen := 0
var bitti := false
var kazandi := false
var firin_kademesi := 0
## GUNUN DOKUMU. Menu, Engine meta alani ile isaretliyor: sahne degisiminde
## parametre gecirmenin en temiz yolu bu (change_scene_to_file argüman almaz),
## ve KAYDA yazmadigi icin yarim kalan bir bayrak sonraki kosuyu kirletmiyor.
var gunun_dokumu := false
var gun_sonuc := {}

## PAYLASIM METNI icin isi izi. 12 ornek, kosunun sekli icin yeterli:
## Wordle'in izgarasi gibi sonucu vermeden hikayeyi anlatiyor.
var _isi_izi: Array[float] = []
var _izi_sonraki := 0.0
var kilit_sayisi := 0
var _kilit_onceki := false

var kazanilan_curuf := 0
var evre_adi := ""

## Denge taramasi bunu disaridan degistiriyor (1.0 = normal tempo)
var spawn_carpani := 1.0
var guc_carpani := 1.0
var tavan_artis := 1.0
var patron_sayisi := 0
## GOREVLER: icerik PARAYLA degil USTALIKLA acilir. Hicbiri guc vermiyor,
## hepsi SECENEK aciyor -- baslangic silahi, ek yakma hakki, dokum onyukleme.
var gorevler := Gorevler.new()
var acilan_gorevler: Array = []
var _son_darbe := false
## Nefes evresinde suruyu inceltme sayaci.
const GERI_CEKILME_ARALIK := 0.25
var _geri_cekilme := 0.0
var yakilan_mangal := 0
var toplam_mangal := 0
var _patron: Node2D = null
var _patron_cubuk: ColorRect
var _patron_kok: Control

var _spawn_sayaci := 0.0
var _hud: CanvasLayer
var _lbl_ust: Label
var _isi_cubuk: ColorRect
var _isi_yazi: Label
var _lbl_silah: Label
var _lbl_sayac: Label
var _dokum_cubuk: ColorRect
var _dokum_yazi: Label
var karanlik: CanvasLayer
var _kart_katman: CanvasLayer
var _bekleyen_kart := 0
## Alinan kartlar: ad -> {"sayi": int, "ikon": String, "aciklama": String}
var alinan_kartlar := {}
## FIRINA AT: begenmedigin karti kosu boyunca havuzdan cikarir.
## Rakip arastirmasindaki en yaygin sikayet "yapmak istedigim seyi hic
## goremedim" -- VS'in Banish'i bunu yariım cozuyor (10 kullanim, ve
## secenegi sadece o turda siliyor). Bizde kalici: yaktigin kart bir daha
## gelmez, yani havuzu kendine gore daraltiyorsun.
var yakilan_kartlar := {}
var yakma_hakki := 3
var _build_kutu: HBoxContainer
var _can_kutu: HBoxContainer
var _xp_cubuk: ColorRect
var _ipucu: Label
var _duraklat_katman: CanvasLayer

## Bkz. menu.gd _dil(): komut satiri --en ile zorlanabiliyor.
static func _dil() -> String:
    if "--en" in OS.get_cmdline_user_args():
        return "en"
    var k := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Kayit")
    return str(k.ayar("dil", "tr")) if k != null else "tr"

func _ready() -> void:
    TranslationServer.set_locale(_dil())
    # GUNUN DOKUMU: tohum arena kurulmadan ONCE sabitlenmeli, yoksa
    # yerlesim/dalga/kart sirasi gune degil rastgeleye baglanir.
    gunun_dokumu = bool(Engine.get_meta("kor_gunun_dokumu", false))
    Engine.set_meta("kor_gunun_dokumu", false)
    if gunun_dokumu:
        seed(Kayit.gun_tohumu())
    gorevler.kosu_basla()
    SesYonetici.yukle_klasorden()
    SesYonetici.muzik_katmanli_cal()
    _arena_kur()
    _lekeler()
    _yapilari_dog()
    _karanlik_kur()
    # DIKKAT: karanlik dugumu KURULDUKTAN sonra. Kademe 3'un gorus
    # degistiricisi karanlik'a yaziyor; once cagrilirsa sessizce yok olur
    # (olcumde kademe 2 ve 3 birebir ayni cikinca yakalandi).
    _firin_kademesi_uygula()
    _hud_kur()
    if OS.is_debug_build():
        var g := GelistiriciSahne.new()
        g.ana = self
        add_child(g)
    oyuncu.otomatik_ates = bool(Kayit.ayar("otomatik_ates", false))
    _acilan_secenekleri_uygula()
    oyuncu.oldu.connect(_oyun_bitti)
    oyuncu.can_degisti.connect(_can_tazele)
    oyuncu.can_degisti.emit(oyuncu.can, oyuncu.maks_can)
    oyuncu.silah_degisti.connect(func(ad, _i):
        var ek := "   [Q]" if oyuncu.acik_silahlar.size() > 1 else ""
        # Damgalar silahin YANINDA duruyor: hangi silaha yatirim yaptigin
        # her an gorunur olmali, cunku silah degistirmek onlari geride birakir.
        var dmg: Array = oyuncu.silah_damgalari()
        var dmg_ek := ""
        if dmg.size() > 0:
            var adlar: Array = []
            for a in dmg:
                adlar.append(tr(str(Silahlar.damga(str(a)).get("ad", a))))
            dmg_ek = "  ·  " + " · ".join(adlar)
        _lbl_silah.text = "◤ " + tr(str(ad)) + ek + dmg_ek)
    oyuncu.dokum_degisti.connect(_dokum_tazele)
    oyuncu.dokum_degisti.emit(0.0, false)
    oyuncu.silah_degisti.emit(oyuncu.silah(), oyuncu.silah_indeksi)

## Tarayici sekmesi degisince ya da pencere arkaya gecince oyun devam
## ediyordu -- oyuncu geri geldiginde olmus oluyor. Sadece DURAKLAT;
## geri gelince kendi kendine devam ETMIYOR, cunku oyuncu hazir olmayabilir.
func _notification(ne: int) -> void:
    if ne != NOTIFICATION_APPLICATION_FOCUS_OUT and ne != NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        return
    if bitti or get_tree().paused:
        return
    if _kart_katman != null and is_instance_valid(_kart_katman):
        return
    _duraklat_degis()

## Gamepad START'i da yakalasin diye eylem bazli (InputEventJoypadButton
## _unhandled_key_input'a dusmez).
func _unhandled_input(olay: InputEvent) -> void:
    if olay.is_echo() or bitti:
        return
    if olay.is_action_pressed("duraklat"):
        _duraklat_degis()
        get_viewport().set_input_as_handled()

## ESC duraklatma. Kart ekrani aciksa karismiyor -- o zaten duraklatmis
## durumda ve kendi kararini bekliyor.
func _duraklat_degis() -> void:
    if _kart_katman != null and is_instance_valid(_kart_katman):
        return
    if _duraklat_katman != null and is_instance_valid(_duraklat_katman):
        _duraklat_katman.queue_free()
        _duraklat_katman = null
        get_tree().paused = false
        return
    _duraklat_katman = _panel_kur("DURAKLATILDI", _ozet_satirlari(false),
        "ESC devam   ·   R yeniden basla")
    get_tree().paused = true

## Duraklatma ve olum ekrani ayni govdeyi kullaniyor.
## PAYLASIM METNI. Tarayici oyununun tek dagitim kanali oyuncunun
## kendisi; Wordle'in kanitladigi kalip kopyalanabilir, spoiler'siz
## ve KUCUK bir metin. Isi izi satiri kosunun SEKLINI anlatiyor --
## sonucu vermeden hikayeyi veriyor.
func _paylasim_metni() -> String:
    # UC SEVIYE, sekiz degil. Iki sebep:
    #   1. PublicPixel'de sekiz blok karakterinden yalnizca uctanesi var
    #      (▁ ▄ █); kalan besi eksik glif olarak "_" dusuyor. Fontu
    #      denetledim, tahmin degil.
    #   2. Uc seviye oyunun KENDI bantlarina denk geliyor: soguk (<%25),
    #      orta, kizgin (>%70). Yani cubuk rastgele bir gorsel degil,
    #      kosunun hangi bantta gectigini okutuyor.
    var cubuk := ""
    for o in _isi_izi:
        cubuk += "█" if o > oyuncu.KIZGIN_ESIK else ("▁" if o < 0.25 else "▄")
    var basli := tr("KOR · günün dökümü %s") % Kayit.gun_kodu_bugun() if gunun_dokumu else tr("KOR · serbest koşu")
    var satir: Array = [basli]
    satir.append(tr("%02d:%02d · sv%d · %d döküm%s") % [
        int(gecen) / 60, int(gecen) % 60, seviye, kazanilan_curuf,
        tr("   (fırın %d)") % firin_kademesi if firin_kademesi > 0 else ""])
    if cubuk != "":
        satir.append(tr("ısı %s · %d kilit") % [cubuk, kilit_sayisi])
    if patron_sayisi > 0:
        satir.append(tr("%s: %s") % [_patron_adi(),
            tr("düştü") if _patron == null else tr("ayakta")])
    return nl_birlestir(satir)

## Godot'ta Array.join yok gibi davranmayalim; ama satir sonu platformdan
## bagimsiz olsun diye tek yerde topluyoruz.
func nl_birlestir(satir: Array) -> String:
    return "
".join(PackedStringArray(satir))


func _panel_kur(baslik: String, satirlar: Array, alt: String) -> CanvasLayer:
    var k := CanvasLayer.new()
    k.layer = 5
    k.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(k)
    var fon := ColorRect.new()
    fon.color = Color(0.01, 0.01, 0.03, 0.84)
    fon.set_anchors_preset(Control.PRESET_FULL_RECT)
    k.add_child(fon)

    var sarmal := PanelContainer.new()
    sarmal.theme = Tema.tema()
    sarmal.position = Vector2(56, 52)
    sarmal.custom_minimum_size = Vector2(528, 0)
    sarmal.add_theme_stylebox_override("panel",
        Tema.kutu(Tema.GOVDE, Tema.KENAR_KOR, 1, Tema.BOSLUK_L))
    k.add_child(sarmal)

    var kutu := VBoxContainer.new()
    kutu.add_theme_constant_override("separation", Tema.BOSLUK_S)
    sarmal.add_child(kutu)
    kutu.add_child(Tema.baslik(baslik))
    var ayrac := ColorRect.new()
    ayrac.color = Tema.KENAR
    ayrac.custom_minimum_size = Vector2(0, 1)
    kutu.add_child(ayrac)
    for satir in satirlar:
        var m := str(satir)
        if m == "":
            var b := Control.new()
            b.custom_minimum_size = Vector2(0, Tema.BOSLUK_S)
            kutu.add_child(b)
        elif m == m.to_upper() and m.length() < 20:
            kutu.add_child(_panel_satiri(Tema.vurgu(m)))
        else:
            kutu.add_child(_panel_satiri(Tema.govde(m)))
    var b2 := Control.new()
    b2.custom_minimum_size = Vector2(0, Tema.BOSLUK_M)
    kutu.add_child(b2)
    # PAYLASIM KUTUSU. Panoya yazma web'de kirilgan (Chrome izin sorunu,
    # godot#81252), o yuzden ONCE secilebilir kutu: her zaman calisir.
    # Kopyalama dugmesi onun USTUNE geliyor; basarisiz olursa metin
    # zaten orada duruyor ve elle secilebiliyor.
    if bitti:
        var b3 := Control.new()
        b3.custom_minimum_size = Vector2(0, Tema.BOSLUK_M)
        kutu.add_child(b3)
        var metin := _paylasim_metni()
        var kutucuk := RichTextLabel.new()
        kutucuk.bbcode_enabled = false
        kutucuk.selection_enabled = true
        kutucuk.fit_content = true
        kutucuk.scroll_active = false
        kutucuk.text = metin
        kutucuk.add_theme_color_override("default_color", Tema.YAZI_SONUK)
        kutu.add_child(kutucuk)
        var kopyala := Button.new()
        kopyala.text = tr("koşuyu kopyala")
        kopyala.pressed.connect(func():
            DisplayServer.clipboard_set(metin)
            kopyala.text = tr("kopyalandı"))
        kutu.add_child(kopyala)
    kutu.add_child(Tema.vurgu(alt))
    return k

## Panel satiri: uzun kart aciklamalari paneli tasmasin diye sarilir.
func _panel_satiri(l: Label) -> Label:
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.custom_minimum_size = Vector2(504, 0)
    return l

func _panel_yazi(metin: String, boy: int, renk: Color) -> Label:
    var l := Label.new()
    l.add_theme_font_override("font", YAZI_TIPI)
    l.add_theme_font_size_override("font_size", boy)
    l.modulate = renk
    l.text = metin
    return l

## Kosu ozeti. Olumde ve duraklatmada ayni bilgi -- oyuncu neyi nasil
## yaptigini gorsun.
func _ozet_satirlari(olum: bool) -> Array:
    var s: Array = []
    s.append(tr("sure %02d:%02d    seviye %d    oldurme %d") % [
        int(gecen) / 60, int(gecen) % 60, seviye, oldurulen])
    for g in acilan_gorevler:
        s.append(tr("✓ GÖREV TAMAM: %s — %s") % [g["ad"], g["odul"]])
    s.append(tr("dokumhane %d/%d mangal yandi%s") % [yakilan_mangal, toplam_mangal,
        tr("    — HEPSI") if yakilan_mangal >= toplam_mangal and toplam_mangal > 0 else ""])
    s.append(tr("silah %s    acik %d/4") % [tr(oyuncu.silah()), oyuncu.acik_silahlar.size()])
    s.append("")
    if alinan_kartlar.is_empty():
        s.append("kart alinmadi")
    else:
        s.append("BUILD")
        for ad in alinan_kartlar:
            var b: Dictionary = alinan_kartlar[ad]
            var sayi: int = int(b["sayi"])
            s.append("  %s%s   %s" % [ad, (" x%d" % sayi) if sayi > 1 else "", b["aciklama"]])
    s.append("")
    s.append(tr("DÖKÜM  %d   (en iyi %d)%s") % [kazanilan_curuf, Kayit.en_iyi_curuf(),
        "   ·   fırın kademesi %d" % firin_kademesi if firin_kademesi > 0 else ""])
    if gunun_dokumu:
        # Gunluk kosuda kiyas zemini BUGUNKU SEN. Deneme sayisini gizlemek
        # yerine gosteriyoruz: kazanma orani ~%8 oldugu icin tek denemeli
        # bir gunluk oyuncularin cogunu her gun kaybettirirdi.
        var _r := tr("   ✓ GÜNÜN REKORU") if bool(gun_sonuc.get("rekor", false)) else ""
        s.append(tr("GÜNÜN DÖKÜMÜ %s   ·   bugünkü en iyin %d   ·   bugün %d. koşun%s") % [
            Kayit.gun_kodu_bugun(), int(gun_sonuc.get("en_iyi", Kayit.gun_en_iyi())),
            int(gun_sonuc.get("deneme", Kayit.gun_deneme())), _r])
    if olum:
        s.append("")
        s.append(tr("dakikada %.1f oldurme    seviye basina %.0f sn") % [
            oldurulen / maxf(gecen / 60.0, 0.01), gecen / maxf(float(seviye), 1.0)])
    return s

func _process(delta: float) -> void:
    if bitti:
        if Input.is_key_pressed(KEY_R):
            get_tree().reload_current_scene()
        elif Input.is_key_pressed(KEY_ESCAPE):
            get_tree().change_scene_to_file("res://scenes/menu.tscn")
        return

    gecen += delta
    if gecen >= Dalgalar.KOSU_SURESI and not kazandi:
        # SON DARBE: sure dolunca patron hala hayattaysa kosu BITMIYOR.
        # Onceden t=720'de patronun durumuna bakilmadan kazaniliyordu ve
        # _kosu_kazanildi() "dusman" grubunu supurdugu icin patron sessizce
        # siliniyordu -- doruk nokta bir sayacti. Artik oyunu patronu
        # oldurerek bitiriyorsun.
        if is_instance_valid(_patron):
            if not _son_darbe:
                _son_darbe = true
                _duyuru("SON DARBE")
                Hiss.sars(6.0)
                SesYonetici.cal("patron_uyandi")
            # Sayac 12:00'de duruyor: uzatma "ek sure" degil, DORUK NOKTA.
            gecen = Dalgalar.KOSU_SURESI
        else:
            _kosu_kazanildi()
            return
    var yeni_evre: String = str(Dalgalar.evre(gecen)["ad"])
    if yeni_evre != evre_adi:
        evre_adi = yeni_evre
        if evre_adi == evre_adi.to_upper():
            _duyuru(evre_adi)
    gorevler.guncelle(delta, oyuncu.isi.kilitli)
    if oyuncu.isi.kilitli and not _kilit_onceki:
        kilit_sayisi += 1
    _kilit_onceki = oyuncu.isi.kilitli
    if gecen >= _izi_sonraki and _isi_izi.size() < 12:
        _izi_sonraki += Dalgalar.KOSU_SURESI / 12.0
        _isi_izi.append(oyuncu.isi.oran())
    _dalis_ogret()
    # ZAFER TURU: son 90 saniyede tavana varmak silahi susturmuyor.
    if oyuncu.isi.kilit_acik and not Dalgalar.kilit_var_mi(gecen):
        oyuncu.isi.kilit_acik = false
        oyuncu.isi.kilitli = false
        _duyuru("DÖKÜMHANE UYANDI")
        Hiss.sars(5.0)
        SesYonetici.cal("patron_uyandi")
    if patron_sayisi < Dalgalar.PATRON_ZAMANLARI.size() and gecen >= float(Dalgalar.PATRON_ZAMANLARI[patron_sayisi]):
        _patron_dog()
    _patron_cubuk_tazele()
    # SESSIZ ACILIS. Olculdu: hic girdi vermeyen oyuncu 12,7 saniyede
    # oluyordu. Ama acilis bir KESIF ani olarak tasarlandi -- karanlikta
    # baslarsin, ates edersin, dunya acilir, bir mangal bulursun. Oyuncu
    # kesfederken yeniyorsa o tasarim calismiyor.
    #
    # Cozum sure vermek degil, sureyi OYUNCUNUN EYLEMINE baglamak: ilk
    # atisini yapana kadar (en fazla 12 sn) surü dogmuyor. Tematik olarak
    # da yerinde -- kul soguk bir koru fark etmez; isindigin an seziyor
    # (dusman.gd _koku zaten bunun uzerine kurulu).
    #
    # Deneyimli oyuncu hemen ates ettigi icin hicbir sey kaybetmiyor.
    if not oyuncu.hic_ates and gecen < ACILIS_SESSIZLIGI:
        _spawn_sayaci = maxf(_spawn_sayaci, 0.35)
    # NEFES: tavan yalnizca YENI DOGUMU kapatiyordu, var olan suruyu
    # azaltmiyordu -- oyuncu 7. evreden cikip nefese girdiginde ekranda
    # hala ~90 dusman olabiliyordu. Olculdu: nefes evresine girenlerin
    # %55,6'si ORADA oluyordu; adi nefes olan evre kosunun en olumcul
    # yeriydi.
    #
    # Cozum karanligi kullaniyor: yalnizca GORUS DISINDAKI dusmanlar
    # geri cekiliyor. Oyuncu bir seyin kayboldugunu gormuyor, cunku
    # zaten gormuyordu -- sadece sonraki saniyelerde uzerine gelen
    # sayi azaliyor. XP dusmuyor: bu bir odul degil, bir nefes.
    if not _son_darbe and Dalgalar.nefes_mi(gecen):
        _geri_cekilme += delta
        if _geri_cekilme >= GERI_CEKILME_ARALIK and _canli_dusman() > canli_tavan():
            _geri_cekilme = 0.0
            _karanliga_cekil()
    if _son_darbe:
        _spawn_sayaci = 1.0        # uzatmada yeni dusman yok
    _spawn_sayaci -= delta
    if not _son_darbe and _spawn_sayaci <= 0.0:
        _spawn_sayaci = Dalgalar.spawn_araligi(gecen) * spawn_carpani
        if _canli_dusman() < canli_tavan():
            _dusman_dog()

    var i = oyuncu.isi
    _isi_cubuk.size.x = 120.0 * i.oran()
    if i.kilitli:
        _isi_cubuk.color = Color(1.0, 0.75, 0.2)
    elif i.oran() > 0.85:
        # Kilit oncesi uyari -- oyuncu tavana yaklastigini hissetmeli
        _isi_cubuk.color = Color(1, 1, 1) if int(Time.get_ticks_msec() / 70) % 2 == 0 else Color(1.0, 0.25, 0.05)
    else:
        _isi_cubuk.color = Color(0.35, 0.7, 1.0).lerp(Color(1.0, 0.3, 0.1), i.oran())
    if i.kilitli:
        _isi_yazi.text = "KİLİTLİ"
    elif oyuncu.kor_atabilir():
        _isi_yazi.text = "KOR HAZIR"
    else:
        _isi_yazi.text = ""
    # MANGAL sayaci sadece SONUK mangal kaldiysa gorunuyor: bu bir hedef
    # gostergesi, bir istatistik degil. Hepsi yaninca kendini siliyor --
    # HUD'da isi bitmis bir eleman durmasin.
    _lbl_ust.text = tr("%02d:%02d") % [int(gecen) / 60, int(gecen) % 60]
    var alt: Array = ["sv%d" % seviye, "×%d" % oldurulen]
    if oldurulen > 0:
        alt.append("+%d" % Kayit.kosu_curufu(oldurulen))
    if toplam_mangal > 0 and yakilan_mangal < toplam_mangal:
        alt.append("▲%d/%d" % [yakilan_mangal, toplam_mangal])
    _lbl_sayac.text = "   ".join(alt)
    _xp_cubuk.size.x = 640.0 * clampf(float(xp) / maxf(float(xp_hedef), 1.0), 0.0, 1.0)
    if _dokum_yazi != null and oyuncu.dokum_hazir():
        _dokum_yazi.scale = Vector2.ONE * (1.0 + 0.06 * sin(gecen * 7.0))
    elif _dokum_yazi != null:
        _dokum_yazi.scale = Vector2.ONE
    _ipucu_tazele()

## FIRIN KADEMESI -- gonullu zorluk. Hades'in Pact'i gibi ama Kor'un kendi
## diliyle: zorlugu artirmanin yolu firini daha cok yakmak. Her degistirici
## ISI EKONOMISINE dokunuyor, baska sisteme degil. Kalici gelisim GUC degil
## SECENEK veriyor; isi baskisini azaltan hicbir sey kalici degil.
func _firin_kademesi_uygula() -> void:
    var k: int = Kayit.kademe()
    firin_kademesi = k
    # OLCULDU: eski uc degistirici de isinin BIRIKIM HIZINA dokunuyordu ve
    # merdiven TERS calisiyordu -- kademe 1 hicbir sey yapmiyor (t=-0,33),
    # kademe 2 oyunu KOLAYLASTIRIYOR (+60,2 sn, t=+2,21) ve en cok oduyordu.
    # Yani baskin strateji her zaman kademe 2 idi, kademe 3'u oynamak icin
    # kimsenin sebebi yoktu.
    #
    # Sebep: Kor'da isi CEZA DEGIL ODUL (gorus + hasar + yayilim + dokum +
    # miknatis) ve tek bedeli olan kilidi dokum kiriyor. Isirmasi icin
    # degistiricilerin ODUL tarafina dokunmasi gerekiyor.
    # DIKKAT: kademe 1 once "sicak hasar bonusu yok" idi, ama
    # asiri_isi_carpani VARSAYILAN 1,0 -- yani KIZGIN CELIK karti
    # alinmadiysa bonusu kapatmak HICBIR SEY YAPMIYORDU. Olcumde de
    # oyle cikti (605 sn, kademe 0'in 590'indan farksiz). Kademe
    # degistiricisi KOSULSUZ isirmali.
    # Her kademe ayrica dusman gucunu artiriyor. Gerekce: isi ekonomisine
    # dokunan degistiriciler INSAN oyuncu icin isiriyor ama botun politikasi
    # onlari kullanmadigi icin olcumde gorunmuyorlar (bot neredeyse hic
    # kilitlenmiyor, kupleri pasif topluyor). Olcumde k0/k1/k2 sirasi iki
    # kez TERS cikti ve bu bir tuning sorunu degil, botun goremedigi bir
    # eksen. Guc carpani POLITIKADAN BAGIMSIZ isiriyor, yani merdiven
    # yapisi geregi monoton oluyor; isi degistiricileri de kimligi tasiyor.
    guc_carpani *= pow(1.14, k)
    if k >= 1:
        oyuncu.miknatis_isiya_bagli = false  # KURU MIKNATIS: cekim isiyla buyumez
    if k >= 2:
        oyuncu.dokum_kilit_kirar = false    # CATLAK POTA: dokum artik kilidi kirmiyor
    if k >= 3:
        oyuncu.sicak_hasar_bonusu = false   # SOGUK DEMIR: %70 ustu hasar bonusu yok
        _gorus_degistir(0.80, 0.0)          # DAR GOZ: gorus %20 daraliyor

## Isi = gorus. Oyunun ayrisma noktasi; ayrinti karanlik.gd icinde.
func _karanlik_kur() -> void:
    karanlik = KaranlikSahne.new()
    karanlik.oyuncu = oyuncu
    add_child(karanlik)

# --- Arena ------------------------------------------------------------------

func _arena_kur() -> void:
    for y in SATIR:
        for x in SUTUN:
            var kenar := x == 0 or y == 0 or x == SUTUN - 1 or y == SATIR - 1
            var atlas: Vector2i
            # ZEMIN BILESIMI. Onceden hucrelerin %80'i TEK bir neredeyse
            # bos karoydu ve isi %75'te oyun alaninin %58'i aydinlik --
            # yani kosunun cogunda ekranin yarisi bos kahverengi duzlem.
            # Alti dokumhane karosu (oluk, izgara, dikis, tahliye, is
            # halkasi, catlak+kor) %14 oraninda serpiliyor. Yogunluk
            # gozle denendi: %14 kullanilmis endustriyel zemin, %40 duvar
            # kagidi oluyor ve dusman aramak zorlasiyor.
            if kenar:
                atlas = Vector2i(4 + randi() % 3, 0)          # duvar (carpismali)
            elif randf() < 0.14:
                atlas = Vector2i(7 + randi() % 6, 0)          # dokumhane karolari
            elif randf() < 0.24:
                atlas = Vector2i(1 + randi() % 3, 0)          # catlakli zemin
            else:
                atlas = ZEMIN_SADE
            _karolar.set_cell(Vector2i(x, y), 0, atlas)

## Zemine is/kurum lekeleri serp -- duz kahverengi bir deniz kalmasin.
func _lekeler() -> void:
    var katman := Node2D.new()
    katman.z_index = -4
    add_child(katman)
    for n in 46:
        var leke := Polygon2D.new()
        var r := randf_range(5.0, 17.0)
        var noktalar := PackedVector2Array()
        for a in 8:
            var ac := TAU * a / 8.0
            var yc := r * randf_range(0.55, 1.0)
            noktalar.append(Vector2(cos(ac) * yc, sin(ac) * yc * 0.55))
        leke.polygon = noktalar
        leke.color = Color(0.05, 0.03, 0.02, randf_range(0.10, 0.26))
        leke.position = Vector2(randf_range(24, 616), randf_range(24, 330))
        katman.add_child(leke)

## Siperler: ates hattini keser, suruyu yonlendirir. Fici/sandik kirilabilir.
func _yapilari_dog() -> void:
    var basla := oyuncu.position
    var torba := YAPI_BILESIMI.duplicate()
    torba.shuffle()

    # 1. GECIS -- yerlesim. Dugum yaratmadan once konumlar belli olmali:
    # fener secimi _ready()'den ONCE bilinmek zorunda, cunku `yanik`
    # bayragini _ready() okuyor (add_child sonrasi degistirmek is gormez).
    var yerler: Array = []
    var dolu := {}
    for tur in torba:
        for deneme in 12:
            var h := Vector2i(randi_range(2, SUTUN - 3), randi_range(2, SATIR - 3))
            if dolu.has(h):
                continue
            var p := Vector2(h.x * KARO + KARO / 2.0, h.y * KARO + KARO / 2.0)
            if p.distance_to(basla) < 56.0:   # oyuncunun dogdugu yeri tikama
                continue
            dolu[h] = true
            yerler.append({"tur": str(tur), "poz": p})
            break

    # FENER: oyuncuya en yakin mangal YANIK baslar. Tamamen karanlik bir
    # ekranda gidilecek bir yer olmali -- yoksa kesif degil, kaybolus olur.
    var fener := -1
    for n in yerler.size():
        if yerler[n]["tur"] != "mangal":
            continue
        if fener < 0 or yerler[n]["poz"].distance_to(basla) < yerler[fener]["poz"].distance_to(basla):
            fener = n

    # 2. GECIS -- dugumleri kur.
    toplam_mangal = 0
    yakilan_mangal = 0
    for n in yerler.size():
        var bilgi: Dictionary = yerler[n]
        var y := YapiSahne.instantiate()
        y.kur(str(bilgi["tur"]))
        if bilgi["tur"] == "mangal":
            toplam_mangal += 1
            y.yanik = (n == fener)
            if n == fener:
                yakilan_mangal = 1
            else:
                y.yakildi.connect(_mangal_yakildi)
        y.position = bilgi["poz"]
        # Varil 1 XP dusuruyordu -- sv10'da bir seviyenin 1/165'i, yani
        # gorunmez. Artik kirmak ISI veriyor: karanlikta bir varil kirmak
        # "biraz gorus satin almak" oluyor ve siperi kirmanin bedeli
        # (acik kalmak) karsiligini buluyor.
        y.kirildi.connect(_yapi_kirildi)
        add_child(y)

# --- Dalgalar ---------------------------------------------------------------

## Ayni anda yasayabilecek dusman sayisi. Zorluk buradan degil, dusmanin
## gucunden ve turunden geliyor.
func canli_tavan() -> int:
    return int(Dalgalar.canli_tavan(gecen) * tavan_artis)

func _canli_dusman() -> int:
    return get_tree().get_nodes_in_group("dusman").size()

## Patron. Can torbasi degil, cekirdek mekanigin sinavi -- ayrinti
## patron.gd icinde.
## Uc patron da ayni sahne ve ayni dovus; ama ekranda ayni ISIM olunca
## 150. saniyedeki ilk karsilasma ile 690. saniyedeki doruk birbirinden
## ayirt edilemiyordu. Isimler ayrilinca KUL ANASI adi yalnizca finale ait
## oluyor ve oyuncu onu ilk kez 690'da duyuyor.
const PATRON_ADLARI := ["OCAK BEKÇİSİ", "CÜRUF ANASI", "KÜL ANASI"]

func _patron_adi() -> String:
    return str(PATRON_ADLARI[clampi(patron_sayisi - 1, 0, PATRON_ADLARI.size() - 1)])

func _patron_dog() -> void:
    patron_sayisi += 1
    var p := PatronSahne.instantiate()
    p.kur(1.0 + float(patron_sayisi - 1) * 0.85)
    p.global_position = _kenar_noktasi()
    p.olduruldu.connect(_dusman_oldu)
    p.patron_oldu.connect(_patron_yenildi)
    add_child(p)
    _patron = p
    Hiss.sars(5.0)
    SesYonetici.cal("patron_uyandi")
    _duyuru("%s UYANDI" % _patron_adi())

## Mangal yakmak kalici bir kazanim: arena aydinlanir, yeni bir isi kaynagi
## acilir. Odulu XP degil -- odul haritanin kendisi. Ustune kucuk bir XP
## veriliyor ki ilk yakmada seviye atlama hissi gelsin.
func _mangal_yakildi(poz: Vector2) -> void:
    yakilan_mangal += 1
    Hiss.sars(3.2)
    Hiss.patlama(self, poz, Color(1.0, 0.62, 0.22), 34, 170.0, 2.6, 0.9)
    SesYonetici.cal("seviye")
    _kup_dus(poz, 3)
    if yakilan_mangal == 2:
        # Ilk yakma FENER'di (bedava); bu oyuncunun KENDI yaktigi ilk mangal.
        _duyuru("DÖKÜMHANE UYANIYOR")
    elif yakilan_mangal == toplam_mangal:
        _duyuru("DÖKÜMHANE TAM YANDI")

## Patron olunce oyuncu odullendirilir ve dalgalar sertlesir.
func _patron_yenildi() -> void:
    _patron = null
    gorevler.patron_dustu()
    tavan_artis *= 1.08
    guc_carpani *= 1.10
    _duyuru("%s DÜŞTÜ" % _patron_adi())
    for n in 6:
        _kup_dus(oyuncu.global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40)), 5)

## DURUMA BAGLI OGRETIM -- bir kereye mahsus.
##
## Dalis oyunun imza fiili ama sadece 25. saniyede solan ipucu satiriyla
## anlatiliyordu. Sabit bir ogretici yerine: oyuncu GERCEKTEN sikisinca
## (isi %80 ustu) ve dalmayi hic denememisse, tam yaninda tek satir.
## Kendi kesfettiyse hic gorunmuyor -- ogretici gurultusu yok.
var _dalis_ogretildi := false

func _dalis_ogret() -> void:
    if _dalis_ogretildi or oyuncu.hic_daldi or bitti:
        return
    if oyuncu.isi.oran() < 0.80 or oyuncu.isi.kilitli:
        return
    _dalis_ogretildi = true
    var l := Tema.vurgu("BOŞLUK — ısını boşalt")
    l.set_anchors_preset(Control.PRESET_TOP_WIDE)
    l.offset_top = 152
    l.offset_bottom = 168
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _hud.add_child(l)
    var t := create_tween()
    t.tween_interval(3.2)
    t.tween_property(l, "modulate:a", 0.0, 0.8)
    t.tween_callback(l.queue_free)

## DOKUM cubugu. Dolunca renk degisip nabiz atiyor -- "hazir" bilgisi
## yaziya degil HAREKETE bagli, her gorme tipinde okunur.
func _dokum_tazele(oran: float, hazir: bool) -> void:
    if _dokum_cubuk == null:
        return
    _dokum_cubuk.size.x = 120.0 * clampf(oran, 0.0, 1.0)
    _dokum_cubuk.color = Tema.KOR if hazir else Color(0.55, 0.42, 0.30)
    _dokum_yazi.text = tr("DÖKÜM [E]") if hazir else tr("DÖKÜM")
    _dokum_yazi.add_theme_color_override("font_color",
        Tema.KOR if hazir else Tema.YAZI_SONUK)

## Sirayla ogretim: her an TEK satir, ve sadece oyuncunun henuz yapmadigi
## sey. Hepsini yaptiysa satir kendini siliyor.
func _ipucu_tazele() -> void:
    if _ipucu == null:
        return
    var metin := ""
    if not oyuncu.hic_hareket:
        metin = "WASD  hareket et"
    elif not oyuncu.hic_ates:
        metin = "SOL TIK  ateş et — ateş ısıtır, ısı görüş demek"
    elif oyuncu.isi.oran() > 0.40 and not oyuncu.hic_daldi:
        metin = "BOŞLUK  dalış — ısını boşaltır"
    elif oyuncu.dokum_hazir() and oyuncu.dokum_kullanim == 0:
        metin = "E  döküm hazır — ne kadar sıcaksan o kadar yıkıcı"
    elif oyuncu.acik_silahlar.size() > 1 and not oyuncu.hic_silah_degisti:
        metin = "Q  silah değiştir"
    if metin == "":
        _ipucu.queue_free()
        _ipucu = null
        return
    _ipucu.text = metin

## Ekranin ortasinda kisa duyuru.
func _duyuru(metin: String) -> void:
    var l := Tema.baslik(metin)
    # Konum ELLE hesaplanmiyordu-> "320 - uzunluk * 8" yazi tipinin karakter
    # genisligini varsayiyordu ve uzun duyurular ekran disina tasiyordu.
    # Anchor + ortalama: metin ne olursa olsun ortalanir.
    l.set_anchors_preset(Control.PRESET_TOP_WIDE)
    l.offset_top = 112
    l.offset_bottom = 136
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _hud.add_child(l)
    var t := l.create_tween()
    t.tween_interval(1.6)
    t.tween_property(l, "modulate:a", 0.0, 0.8)
    t.tween_callback(l.queue_free)

## Nefes evresinde GORUS DISINDAKI bir dusmani karanliga geri ceker.
## Gorunur olani asla silmiyoruz -- oyuncunun gozunun onunde dusman
## yok olmasi hile gibi okunur.
func _karanliga_cekil() -> void:
    var uzak: Node2D = null
    var en_uzak := -1.0
    for d in get_tree().get_nodes_in_group("dusman"):
        if not is_instance_valid(d) or d.is_in_group("patron"):
            continue
        if karanlik != null and karanlik.has_method("aydinlik"):
            if karanlik.aydinlik(d.global_position) > 0.03:
                continue        # gorus icinde: dokunma
        var u: float = d.global_position.distance_squared_to(oyuncu.global_position)
        if u > en_uzak:
            en_uzak = u
            uzak = d
    if uzak != null:
        uzak.queue_free()


func _dusman_dog() -> void:
    var d := DusmanSahne.instantiate()
    d.kur(Dalgalar.tur_sec(gecen), Dalgalar.guc(gecen) * guc_carpani)
    d.global_position = _kenar_noktasi()
    d.olduruldu.connect(_dusman_oldu)
    add_child(d)

func _kenar_noktasi() -> Vector2:
    # Oyuncudan uzak bir kenar sec, tepesine dogmasin
    for n in 8:
        var p: Vector2
        match randi() % 4:
            0: p = Vector2(randf_range(ALAN.position.x, ALAN.end.x), ALAN.position.y)
            1: p = Vector2(randf_range(ALAN.position.x, ALAN.end.x), ALAN.end.y)
            2: p = Vector2(ALAN.position.x, randf_range(ALAN.position.y, ALAN.end.y))
            _: p = Vector2(ALAN.end.x, randf_range(ALAN.position.y, ALAN.end.y))
        if p.distance_to(oyuncu.global_position) > 90.0:
            return p
    return ALAN.position

## Ilk atisa kadar (en fazla bu kadar saniye) suru dogmuyor.
const ACILIS_SESSIZLIGI := 12.0

const KILOMETRE_TASLARI := [100, 250, 500, 750, 1000]

func _dusman_oldu(poz: Vector2, kazanc: int) -> void:
    oldurulen += 1
    gorevler.oldurme(oyuncu.isi.oran())
    # Seviye araligi sv12'de 243 saniyeye ciktigi icin kosunun ikinci
    # yarisi sessizlesiyor. Bunlar o sessizligi dolduran ucuz ritim.
    if oldurulen in KILOMETRE_TASLARI:
        _duyuru(tr("%d KÜL") % oldurulen)
        Hiss.sars(2.4)
        SesYonetici.cal("seviye")
    _kup_dus(poz, kazanc)

## XP kupu. DIKKAT: bu fonksiyon fizik sorgusu akarken cagrilabiliyor
## (mermi.body_entered -> dusman.hasar_al -> olduruldu -> burasi). Kupun
## Area2D'si o sirada agaca girerse Godot izleme durumunu reddediyor:
## "Can't change this state while flushing queries". Kup yine gorunuyor ama
## alani ilk karelerde izlemiyor -- kalabalikta "ustunden gectim almadi"
## seklinde ortaya cikar. Bu yuzden agaca ekleme ERTELENIYOR; konum, xp ve
## sinyal baglantisi eklemeden ONCE ayarlandigi icin bir sey kaybolmuyor.
func _kup_dus(poz: Vector2, kazanc: int) -> void:
    var k := KupSahne.instantiate()
    k.global_position = poz
    k.xp = kazanc
    k.toplandi.connect(_xp_topla)
    add_child.call_deferred(k)

func _xp_topla(kazanc: int) -> void:
    xp += kazanc
    while xp >= xp_hedef:
        xp -= xp_hedef
        seviye += 1
        xp_hedef = int(xp_hedef * 1.45) + 2
        _bekleyen_kart += 1
        SesYonetici.cal("seviye")
    # Ayni karede iki seviye gelirse kart kaybolmasin: sirayla acilirlar
    if _bekleyen_kart > 0 and _kart_katman == null:
        _kartlari_ac()

# --- Kartlar ----------------------------------------------------------------

func _kart_havuzu() -> Array:
    var liste := [
        {"ad": "GENİŞ KAZAN", "aile": "sicak", "aciklama": "Isı tavanı +25, soğuma -%15", "ikon": "kazan",
            "uygula": func(o):
                o.isi.tavan += 25.0
                o.isi.soguma_hizi *= 0.85},   # kartin kendisi seni tavana yaklastirsin
        {"ad": "SOĞUK HAT", "aile": "soguk", "aciklama": "Soğuma hızı +%35", "ikon": "soguk",
            "uygula": func(o): o.isi.soguma_hizi *= 1.35},
        {"ad": "HIZLI TETİK", "aciklama": "Atış hızı +%20, ısı +%12", "ikon": "tetik", "uygula": func(o):
            o.atis_hizi_carpani *= 1.2
            o.isi_carpani *= 1.12},
        {"ad": "AĞIR MERMİ", "aciklama": "Hasar +%40, ısı +%18", "ikon": "agir", "uygula": func(o):
            o.mermi_hasari *= 1.4
            o.isi_carpani *= 1.18},
        {"ad": "ÇATAL NAMLU", "aciklama": "+1 mermi, ısı +%25", "ikon": "catal", "uygula": func(o):
            o.ek_mermi += 1
            o.ek_yayilma += 0.06
            o.isi_carpani *= 1.25},
        {"ad": "KOR PATLAMASI", "aile": "sicak", "aciklama": "Dalış bitince çevreye hasar", "ikon": "kor",
            "uygula": func(o): o.dalis_patlamasi += 3.0},
        {"ad": "KIZGIN ÇELİK", "aile": "sicak", "aciklama": "Isı %50 üstündeyken hasar +%50", "ikon": "celik",
            "uygula": func(o): o.asiri_isi_carpani += 0.5},
        {"ad": "TAVLANMIŞ ZIRH", "aile": "sicak", "aciklama": "Maks can +1. Kilitte hasarsız dayanırsan +1 can", "ikon": "zirh", "uygula": func(o):
            o.maks_can += 1
            o.can += 1
            o.tavlanma = true
            o.can_degisti.emit(o.can, o.maks_can)},
        {"ad": "MIKNATIS", "aciklama": "Çekim menzili +%60 (ısıyla ayrıca büyür)", "ikon": "miknatis",
            "uygula": func(o): o.miknatis_carpani *= 1.6},
        {"ad": "ÖRS DARBESİ", "aile": "sicak", "aciklama": "Kor atışı hasarı +%60", "ikon": "ors",
            "uygula": func(o): o.kor_carpani += 0.6},
        {"ad": "YARIM BOŞALTMA", "aile": "soguk", "aciklama": "Kor atışı ısının yarısını bırakır", "ikon": "soguk",
            "uygula": func(o): o.kor_maliyet = maxf(o.kor_maliyet * 0.5, 0.15)},
        {"ad": "KOR YAYILIMI", "aile": "sicak", "aciklama": "Çevreni yakma hasarı +%70", "ikon": "kor",
            "uygula": func(o): o.yayilim_dps *= 1.7},
        {"ad": "GENİŞ HALKA", "aile": "sicak", "aciklama": "Yayılım menzili +%25", "ikon": "kazan",
            "uygula": func(o): o.yayilim_menzil = minf(o.yayilim_menzil * 1.25, 1.0)},
        {"ad": "YAĞLI ÇİZME", "aciklama": "Hareket hızı +%12", "ikon": "cizme",
            "uygula": func(o): o.hiz *= 1.12},
        {"ad": "GENİŞ GÖZ", "aile": "sicak", "aciklama": "Görüş menzili +%25", "ikon": "miknatis",
            "uygula": func(_o): _gorus_degistir(1.25, 0.0)},
        {"ad": "KARANLIK GÖZÜ", "aile": "soguk", "aciklama": "Taban görüş +14 px, soğukken hasar +%25", "ikon": "soguk",
            "uygula": func(o):
                _gorus_degistir(1.0, 14.0)
                o.soguk_hasar_bonusu *= 1.25},   # soguk oynamak strateji olsun
        {"ad": "KÖR ÖFKE", "aile": "sicak", "aciklama": "Görüş -%18 ama hasar +%35", "ikon": "celik", "uygula": func(o):
            _gorus_degistir(0.82, 0.0)
            o.mermi_hasari *= 1.35},
    ]
    # Sahip olunmayan silahlar kart olarak cikar -- alinca Q ile gecilir
    for i in range(1, Silahlar.LISTE.size()):
        if i in oyuncu.acik_silahlar:
            continue
        var sl: Dictionary = Silahlar.LISTE[i]
        liste.append({
            "ad": tr("SİLAH: ") + tr(str(sl["ad"])),
            "aciklama": "%s
%s" % [str(sl["not"]), Silahlar.isi_profili(i, oyuncu.isi.tavan)],
            "ikon": str(sl["ikon"]), "silah": i,
            "uygula": func(o): o.silah_ver(i),
        })
    # DAMGA kartlari: ELDEKI silaha KALICI olarak yapisirlar.
    #
    # Havuza sadece eldeki silaha TAKILABILEN damgalar giriyor -- zaten
    # takiliysa veya silah doluysa kart hic gorunmuyor. Boylece "aldim ama
    # bir ise yaramadi" durumu olusmuyor.
    #
    # Kartin adi silahi da tasiyor ("DAMGA: DELİCİ -> ÇEKİÇ") cunku damga
    # o silaha baglaniyor ve oyuncu neye yatirim yaptigini bilmeli.
    if oyuncu.damga_takilabilir():
        var eldeki: String = oyuncu.silah()
        var takili: Array = oyuncu.silah_damgalari()
        for anahtar in Silahlar.DAMGALAR.keys():
            if anahtar in takili:
                continue
            var dm: Dictionary = Silahlar.DAMGALAR[anahtar]
            liste.append({
                "ad": tr("DAMGA: %s → %s") % [tr(str(dm["ad"])), tr(str(eldeki))],
                "aciklama": tr(str(dm["not"])) + tr("  (kalıcı)"),
                "ikon": str(dm["ikon"]), "damga": anahtar,
                "uygula": func(o): o.damga_tak(str(anahtar)),
            })

    # Firina atilanlar bir daha gelmez
    var kalan: Array = []
    for k in liste:
        if not yakilan_kartlar.has(str(k["ad"])):
            kalan.append(k)
    return kalan

## Gorus artik bir kaynak: kartlar onu takas edebiliyor.
func _gorus_degistir(carpan: float, taban_ek: float) -> void:
    if karanlik == null:
        # Sessizce donmek bir kere cok pahaliya patladi: firin kademesi 3
        # bu yuzden hicbir sey yapmiyordu ve kimse fark etmedi.
        push_error("gorus degistirilemedi: karanlik dugumu henuz yok")
        return
    karanlik.gorus_carpani *= carpan
    karanlik.taban_yaricap += taban_ek

func _kartlari_ac() -> void:
    var havuz := _kart_havuzu()
    havuz.shuffle()
    var secilen := havuz.slice(0, 3)

    _kart_katman = CanvasLayer.new()
    _kart_katman.layer = 4
    _kart_katman.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(_kart_katman)

    var fon := ColorRect.new()
    fon.color = Color(0.01, 0.01, 0.03, 0.80)
    fon.set_anchors_preset(Control.PRESET_FULL_RECT)
    _kart_katman.add_child(fon)

    var sarmal := PanelContainer.new()
    sarmal.theme = Tema.tema()
    # Sabit konum + icerige gore buyuyen genislik = tasma. Anchor'a bagli
    # panel ekrandan cikamaz, uzun metin tasmak yerine satir atlar.
    sarmal.set_anchors_preset(Control.PRESET_TOP_WIDE)
    sarmal.offset_left = 56
    sarmal.offset_right = -56
    sarmal.offset_top = 74
    sarmal.add_theme_stylebox_override("panel",
        Tema.kutu(Tema.GOVDE, Tema.KENAR_KOR, 1, Tema.BOSLUK_L))
    _kart_katman.add_child(sarmal)

    var kutu := VBoxContainer.new()
    kutu.add_theme_constant_override("separation", Tema.BOSLUK_M)
    sarmal.add_child(kutu)

    var ust := HBoxContainer.new()
    ust.add_theme_constant_override("separation", Tema.BOSLUK_M)
    ust.add_child(Tema.baslik(tr("SEVİYE %d") % seviye))
    var bosluk := Control.new()
    bosluk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ust.add_child(bosluk)
    var alt_bilgi := Tema.sonuk("bir kart seç")
    alt_bilgi.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    ust.add_child(alt_bilgi)
    kutu.add_child(ust)

    for k in secilen:
        kutu.add_child(_kart_satiri(k))
    if yakma_hakki > 0:
        var ipucu := Tema.sonuk(tr("sağdaki ateşe basarak bir kartı fırına atabilirsin — kalan %d") % yakma_hakki)
        ipucu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        kutu.add_child(ipucu)

    get_tree().paused = true
    # Kart satiri artik kapsayici (secim + firina at), dugmeyi derinlemesine bul
    var ilk := _ilk_dugme(kutu)
    if ilk != null:
        ilk.grab_focus()

func _ilk_dugme(kok: Node) -> Button:
    for c in kok.get_children():
        if c is Button:
            return c
        var alt := _ilk_dugme(c)
        if alt != null:
            return alt
    return null

## Kart satiri: secim dugmesi + (hak varsa) firina atma dugmesi.
func _kart_satiri(k: Dictionary) -> Control:
    var satir := HBoxContainer.new()
    satir.add_theme_constant_override("separation", Tema.BOSLUK_S)
    var sec := _kart_dugmesi(k)
    sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    satir.add_child(sec)
    if yakma_hakki > 0:
        var yak := Button.new()
        yak.icon = load("res://assets/sprites/ikon_kor.png")
        yak.expand_icon = false
        yak.tooltip_text = "Bu kartı fırına at: koşu boyunca bir daha gelmez"
        yak.custom_minimum_size = Vector2(34, 40)
        yak.pressed.connect(_kart_yak.bind(k))
        satir.add_child(yak)
    return satir

## Tek kart. Ikon solda sabit sutunda, ad ve aciklama sola hizali --
## uc kart alt alta gelince gozle taranabilir olsun diye.
func _kart_dugmesi(k: Dictionary) -> Button:
    var b := Button.new()
    b.custom_minimum_size = Vector2(0, 40)
    b.focus_mode = Control.FOCUS_ALL
    b.set_meta("kart_secim", true)      # test yakma dugmesiyle karistirmasin
    b.pressed.connect(_kart_secildi.bind(k))

    var satir := HBoxContainer.new()
    satir.add_theme_constant_override("separation", Tema.BOSLUK_M)
    satir.mouse_filter = Control.MOUSE_FILTER_IGNORE
    satir.set_anchors_preset(Control.PRESET_FULL_RECT)
    satir.offset_left = Tema.BOSLUK_M
    satir.offset_right = -Tema.BOSLUK_M

    var ikon := TextureRect.new()
    ikon.texture = load("res://assets/sprites/ikon_%s.png" % k["ikon"])
    ikon.custom_minimum_size = Vector2(20, 20)
    ikon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    ikon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    satir.add_child(ikon)

    var metin := VBoxContainer.new()
    metin.add_theme_constant_override("separation", 2)
    metin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    # Aile rozeti kart adinin ONUNDE: oyuncu bir YOL sectigini gormeli.
    var aile := str(k.get("aile", ""))
    var baslik_satir := HBoxContainer.new()
    baslik_satir.add_theme_constant_override("separation", Tema.BOSLUK_S)
    if aile != "":
        var rozet := Tema._yazi("◆" if aile == "sicak" else "◇", 8,
            Tema.AILE_SICAK if aile == "sicak" else Tema.AILE_SOGUK)
        rozet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        baslik_satir.add_child(rozet)
    baslik_satir.add_child(Tema.vurgu(str(k["ad"])))
    metin.add_child(baslik_satir)
    var ac := Tema.sonuk(str(k["aciklama"]))
    ac.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    ac.custom_minimum_size = Vector2(400, 0)
    metin.add_child(ac)
    satir.add_child(metin)

    b.add_child(satir)
    return b

## Karti kalici olarak havuzdan cikar ve ekrani yeniden dagit.
func _kart_yak(kart: Dictionary) -> void:
    if yakma_hakki <= 0:
        return
    yakma_hakki -= 1
    yakilan_kartlar[str(kart["ad"])] = true
    SesYonetici.cal("asiri_isinma")
    # Ekran acik degilse (test/betik cagrisi) sadece havuzdan cikar
    if _kart_katman == null or not is_instance_valid(_kart_katman):
        return
    _kart_katman.queue_free()
    _kart_katman = null
    _kartlari_ac()

func _kart_secildi(kart: Dictionary) -> void:
    SesYonetici.cal("kart_sec")
    var uygula: Callable = kart["uygula"]
    uygula.call(oyuncu)
    var ad: String = str(kart["ad"])
    if alinan_kartlar.has(ad):
        alinan_kartlar[ad]["sayi"] += 1
    else:
        alinan_kartlar[ad] = {"sayi": 1, "ikon": str(kart["ikon"]),
            "aciklama": str(kart["aciklama"])}
    _build_tazele()
    _bekleyen_kart -= 1
    _kart_katman.queue_free()
    _kart_katman = null
    if _bekleyen_kart > 0:
        _kartlari_ac()
    else:
        get_tree().paused = false

# --- HUD --------------------------------------------------------------------

## HUD. Tek hizalanmis blok: ust satir kosu bilgisi, altinda can pulleri,
## isi cubugu ve silah. Hepsi ayni sol kenardan (10 px) baslar, satir
## araliklari 4'un kati. Onceden her parca kendi yerinde duruyordu.
## Kenarlari karartan vinyet -- arenayi bir dokumhane cukuru gibi gosterir.
## Karanlik shader'inin altinda, zeminin ustunde.
func _vinyet_kur() -> void:
    var k := CanvasLayer.new()
    k.layer = -1
    add_child(k)
    var t := TextureRect.new()
    t.texture = Hiss.parlama_dokusu(Color(0, 0, 0, 0), Color(0.03, 0.01, 0.0, 0.75), 128)
    t.set_anchors_preset(Control.PRESET_FULL_RECT)
    t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    t.stretch_mode = TextureRect.STRETCH_SCALE
    t.mouse_filter = Control.MOUSE_FILTER_IGNORE
    k.add_child(t)

func _hud_kur() -> void:
    _vinyet_kur()
    _hud = CanvasLayer.new()
    # KATMAN SIRASI (tek yerde belgeli, cakisma olmasin):
    #   -1 vinyet · 1 karanlik · 2 parilti (dusman cekirdekleri) ·
    #    3 HUD · 4 kart ekrani · 5 duraklatma/olum paneli · 90 gelistirici
    _hud.layer = 3
    add_child(_hud)

    # XP seridi: ekranin en ust kenarinda 2 px. Surekli bakilacak bir sey
    # degil, goz ucuyla gorulecek bir sey -- o yuzden kenarda ve ince.
    var xp_arka := ColorRect.new()
    xp_arka.color = Color(0.06, 0.06, 0.09)
    xp_arka.size = Vector2(640, 2)
    _hud.add_child(xp_arka)
    _xp_cubuk = ColorRect.new()
    _xp_cubuk.color = Tema.SOGUK
    _xp_cubuk.size = Vector2(0, 2)
    _hud.add_child(_xp_cubuk)

    var kok := VBoxContainer.new()
    kok.position = Vector2(10, 7)
    kok.add_theme_constant_override("separation", Tema.BOSLUK_S)
    _hud.add_child(kok)

    # HIYERARSI: sure parlak, sayaclar sonuk. Onceden alti veri de ayni
    # boyut ve ayni renkteydi; oyuncu bir bakista neyin onemli oldugunu
    # ayirt edemiyordu.
    var ust_satir := HBoxContainer.new()
    ust_satir.add_theme_constant_override("separation", Tema.BOSLUK_L)
    kok.add_child(ust_satir)
    _lbl_ust = Tema.vurgu("")
    ust_satir.add_child(_lbl_ust)
    _lbl_sayac = Tema.sonuk("")
    _lbl_sayac.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    ust_satir.add_child(_lbl_sayac)

    # Can pulleri: yildiz yerine kor kareleri
    _can_kutu = HBoxContainer.new()
    _can_kutu.add_theme_constant_override("separation", 3)
    kok.add_child(_can_kutu)

    # Isi cubugu + durum yazisi
    var isi_satir := HBoxContainer.new()
    isi_satir.add_theme_constant_override("separation", Tema.BOSLUK_M)
    kok.add_child(isi_satir)
    var c := Tema.cubuk(120, 8, oyuncu.KOR_ESIK)
    var cubuk_kok: Control = c["kok"]
    cubuk_kok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    isi_satir.add_child(cubuk_kok)
    _isi_cubuk = c["dolgu"]
    _isi_yazi = Tema.sonuk("ISI")
    isi_satir.add_child(_isi_yazi)

    # DOKUM sarji. Isi cubugunun altinda ve AYNI genislikte: ikisi de
    # "birikiyor" diyor, biri tehlike biri firsat.
    var dokum_satir := HBoxContainer.new()
    dokum_satir.add_theme_constant_override("separation", Tema.BOSLUK_M)
    kok.add_child(dokum_satir)
    var dc := Tema.cubuk(120, 5, -1.0)
    var dc_kok: Control = dc["kok"]
    dc_kok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    dokum_satir.add_child(dc_kok)
    _dokum_cubuk = dc["dolgu"]
    _dokum_yazi = Tema.sonuk("DÖKÜM")
    dokum_satir.add_child(_dokum_yazi)

    _lbl_silah = Tema.vurgu("")
    kok.add_child(_lbl_silah)

    # Patron can cubugu: sadece patron sahnedeyken gorunur
    var pc := Tema.cubuk(420, 6, -1.0)
    _patron_kok = pc["kok"]
    _patron_kok.position = Vector2(110, 318)
    _patron_kok.visible = false
    _hud.add_child(_patron_kok)
    _patron_cubuk = pc["dolgu"]
    _patron_cubuk.color = Color(0.55, 0.85, 1.0)

    # Build seridi -- oyuncu ne aldigini GORSUN. VS'te bile var, bizde yoktu.
    _build_kutu = HBoxContainer.new()
    _build_kutu.position = Vector2(640 - 12, 6)
    _build_kutu.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    _build_kutu.add_theme_constant_override("separation", 3)
    _hud.add_child(_build_kutu)

    # Ipucu satiri ogretici gurultusu: ilk 25 saniyeden sonra soner.
    # SIRAYLA OGRETIM. Tek satirda hepsini yazmak 77 karakter = 616 px,
    # yani ekranin %96'si -- ve oyun alaninin alt seridinde, tam oyuncunun
    # hareket etmeyi ogrendigi yerde. Ustelik bes bilgiyi ayni anda
    # okumuyor, sadece biri lazim.
    #
    # Ayni kalibi dalis ogretiminde zaten kurmustuk: "gerektiginde, bir
    # kez, kendisi kesfettiyse hic". Alt satir bunu kullanmayan son yerdi.
    _ipucu = Tema.sonuk("")
    _ipucu.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    _ipucu.offset_left = Tema.BOSLUK_M
    _ipucu.offset_right = -Tema.BOSLUK_M
    _ipucu.offset_top = -22
    _ipucu.offset_bottom = -Tema.BOSLUK_M
    _ipucu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _ipucu.modulate = Color(1, 1, 1, 0.5)
    _hud.add_child(_ipucu)

func _patron_cubuk_tazele() -> void:
    if _patron_kok == null:
        return
    var var_mi := _patron != null and is_instance_valid(_patron)
    _patron_kok.visible = var_mi
    if var_mi:
        _patron_cubuk.size.x = 420.0 * _patron.can_orani()

## Can pulleri. Dolu = kor, bos = sonuk cerceve.
func _can_tazele(mevcut: int, maks: int) -> void:
    if _can_kutu == null:
        return
    for c in _can_kutu.get_children():
        c.queue_free()
    for n in maks:
        var pul := ColorRect.new()
        pul.custom_minimum_size = Vector2(7, 7)
        pul.color = Tema.KOR if n < mevcut else Color(0.16, 0.16, 0.20)
        _can_kutu.add_child(pul)

## Alinan kartlari sag ust seride ikon + sayac olarak goster.
func _build_tazele() -> void:
    if _build_kutu == null:
        return
    for c in _build_kutu.get_children():
        c.queue_free()
    for ad in alinan_kartlar:
        var bilgi: Dictionary = alinan_kartlar[ad]
        var kutu := VBoxContainer.new()
        kutu.add_theme_constant_override("separation", 0)
        var res := TextureRect.new()
        res.texture = load("res://assets/sprites/ikon_%s.png" % bilgi["ikon"])
        res.custom_minimum_size = Vector2(14, 14)
        res.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        res.tooltip_text = "%s  %s" % [ad, bilgi["aciklama"]]
        kutu.add_child(res)
        if int(bilgi["sayi"]) > 1:
            var sy := Label.new()
            sy.add_theme_font_override("font", YAZI_TIPI)
            sy.add_theme_font_size_override("font_size", 8)
            sy.text = "x%d" % int(bilgi["sayi"])
            sy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            kutu.add_child(sy)
        _build_kutu.add_child(kutu)

## Koşu tamamlandı. Turde kazanma kosulu yoktu -- eklendi.
func _kosu_kazanildi() -> void:
    kazandi = true
    gorevler.kazandi()
    bitti = true
    kazanilan_curuf = Kayit.kosu_bitti(gecen, oldurulen)
    if gunun_dokumu:
        gun_sonuc = Kayit.gun_bitti(kazanilan_curuf)
    acilan_gorevler = gorevler.kosu_bitti()
    SesYonetici.muzik_dur()
    SesYonetici.cal("kosu_bitti")
    for d in get_tree().get_nodes_in_group("dusman"):
        d.queue_free()
    Hiss.sars(4.0)
    _panel_kur("DÖKÜMHANE SÖNDÜ", _ozet_satirlari(true), "R yeniden başla   ·   ESC menü")

func _oyun_bitti() -> void:
    bitti = true
    kazanilan_curuf = Kayit.kosu_bitti(gecen, oldurulen)
    if gunun_dokumu:
        gun_sonuc = Kayit.gun_bitti(kazanilan_curuf)
    acilan_gorevler = gorevler.kosu_bitti()
    # Acik modal kalmasin: olum her seyin ustunde
    for katman in [_kart_katman, _duraklat_katman]:
        if katman != null and is_instance_valid(katman):
            katman.queue_free()
    _kart_katman = null
    _duraklat_katman = null
    _bekleyen_kart = 0
    get_tree().paused = false
    SesYonetici.muzik_dur()
    SesYonetici.cal("oyun_bitti")
    _panel_kur("SÖNDÜN", _ozet_satirlari(true), "R yeniden başla   ·   ESC menü")
    for d in get_tree().get_nodes_in_group("dusman"):
        d.queue_free()


## Gorevlerle acilan secenekleri kosu basinda uygular. Hicbiri GUC degil:
## farkli baslangic silahi farkli bir oynayis, daha guclu bir oynayis degil.
func _acilan_secenekleri_uygula() -> void:
    var acik: Array = Gorevler.acik_secenekler()
    var silahlar := {"baslangic_sacma": 1, "baslangic_isin": 2, "baslangic_cekic": 3}
    for anahtar in acik:
        if silahlar.has(anahtar):
            oyuncu.silah_ver(int(silahlar[anahtar]))
        elif anahtar == "ek_yakma":
            yakma_hakki += 1
        elif anahtar == "dokum_onyukleme":
            oyuncu.dokum_sarj = 0.5
            oyuncu.dokum_degisti.emit(0.5, false)


## Kirilan siperin odulu: XP degil ISI. Karanlikta bir varil kirmak
## "biraz gorus satin almak" demek -- ve siperi kaybetmenin bedeli
## (artik arkasina saklanamiyorsun) boylece bir karsilik buluyor.
func _yapi_kirildi(poz: Vector2) -> void:
    _kup_dus(poz, 2)
    if not oyuncu.isi.kilitli:
        oyuncu.isi.ates_et(9.0)
    Hiss.patlama(self, poz, Color(1.0, 0.62, 0.22), 10, 90.0, 1.6, 0.5)
