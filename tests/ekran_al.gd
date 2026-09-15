extends SceneTree
## Gerçek bir render alıp PNG'ye yazar -- görsel doğrulama için.
## godot --script res://tests/ekran_al.gd   (headless DEĞİL)

var CIKTI := _cikti("kor-ekran.png")
var CIKTI_KART := _cikti("kor-kart.png")

## `godot --script res://tests/ekran_al.gd -- --kart` ile kart ekranini cek
var _kart_modu := "--kart" in OS.get_cmdline_user_args()
## Isi = gorus kanitI: ayni sahne soguk ve sicak halde
var _gorus_modu := "--gorus" in OS.get_cmdline_user_args()
## Olum/duraklatma ozet panelini cek
var _ozet_modu := "--ozet" in OS.get_cmdline_user_args()
var _menu_modu := "--menu" in OS.get_cmdline_user_args()
var _patron_modu := "--patron" in OS.get_cmdline_user_args()
## Performans olcumu: gercek pencerede, karanlik shader'i + kalabalik sürü
## + parcaciklar birlikte. Headless bunu olcemez cunku cizim atlanir.
var _perf_modu := "--perf" in OS.get_cmdline_user_args()
var _zafer_modu := "--zafer" in OS.get_cmdline_user_args()
## ACILIS: kosunun ilk anlari. Oyuncunun oyun hakkindaki karari burada
## veriliyor, o yuzden ayri ayri incelenebilmeli. Uc kare yazar:
##   1-sonuk   hic ates edilmemis, dokumhane karanlik
##   2-gorus   ates edildi, isi yukseldi, dunya acildi
##   3-yanik   sicakken mangala gidildi ve yakildi
var _acilis_modu := "--acilis" in OS.get_cmdline_user_args()
## Ingilizce cekim: ceviri gercekten yerine oturuyor mu, tasma var mi.
var _ingilizce := "--en" in OS.get_cmdline_user_args()
var _perf_ornek: Array = []
var _son_usec: int = 0

var _ana: Node2D
var _kare := 0

func _initialize() -> void:
    var yol := "res://scenes/menu.tscn" if _menu_modu else "res://scenes/level.tscn"
    _ana = load(yol).instantiate()
    root.add_child(_ana)


func _process(_delta: float) -> bool:
    # DIKKAT: sahnenin _ready()'si kayitli dili uyguluyor ve _initialize'dan
    # SONRAKI karede calisiyor -- yani orada set etmek is gormuyor, eziliyor.
    # Her karede yeniden uygulaniyor; kullanicinin kayitli ayarina dokunmadan.
    if _ingilizce and TranslationServer.get_locale() != "en":
        TranslationServer.set_locale("en")
    if _acilis_modu:
        return _acilis()
    if _zafer_modu:
        _kare += 1
        if _kare == 60:
            for n in 5:
                _ana._xp_topla(_ana.xp_hedef)
                var kk = _ana.get("_kart_katman")
                if kk != null and is_instance_valid(kk):
                    for d in _dugme_ara(kk):
                        d.pressed.emit()
                        break
            _ana.oldurulen = 742
            _ana.gecen = 721.0
        if _kare < 130:
            return false
        RenderingServer.force_draw()
        root.get_texture().get_image().save_png(_cikti("kor-zafer.png"))
        print("zafer: kor-zafer.png  (kazandi=%s)" % str(_ana.kazandi))
        return true

    if _perf_modu:
        _kare += 1
        if _kare == 5:
            # Vsync kare suresini 16.7 ms'ye sabitliyor; gercek yuku gormek
            # icin kapat. Yoksa olculen sey basarim degil, senkron tavani.
            DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
            Engine.max_fps = 0
        if _kare == 40:
            _ana.gecen = 300.0
            for n in 140:
                _ana._dusman_dog()
            _ana._patron_dog()
            _ana.oyuncu.silah_ver(1)
            _ana.oyuncu.silah_ver(2)
            _ana.oyuncu.silah_ver(3)
        if _kare > 90:      # ilk kareler dogus maliyeti, kararli duruma bak
            _ana.oyuncu.isi.deger = _ana.oyuncu.isi.tavan * 0.85
            if _kare % 3 == 0:
                _ana.oyuncu._ates_et(Vector2.RIGHT.rotated(randf() * TAU))
            # Duvar saati: motor sayaclari vsync'e takilip yaniltiyor.
            var simdi := Time.get_ticks_usec()
            if _son_usec > 0:
                _perf_ornek.append(float(simdi - _son_usec) / 1000.0)
            _son_usec = simdi
        if _kare < 340:
            return false
        _perf_ornek.sort()
        var n2 := _perf_ornek.size()
        var toplam := 0.0
        for v in _perf_ornek:
            toplam += v
        var asan := 0
        for v in _perf_ornek:
            if v > 16.67:
                asan += 1
        print("PERF dusman=%d ornek=%d | betik+fizik ortanca %.2f ms | %%95 %.2f ms | en kotu %.2f ms | butce asan %%%.0f | FPS %.0f (vsync kapali)" % [
            get_nodes_in_group("dusman").size(), n2,
            _perf_ornek[n2 / 2], _perf_ornek[int(n2 * 0.95)], _perf_ornek[n2 - 1],
            100.0 * asan / n2, Engine.get_frames_per_second()])
        RenderingServer.force_draw()
        root.get_texture().get_image().save_png(_cikti("kor-perf.png"))
        return true

    if _patron_modu:
        _kare += 1
        if _kare == 60:
            _ana.gecen = 149.0
            _ana.oyuncu.isi.deger = _ana.oyuncu.isi.tavan * 0.75
        if _kare > 60 and _kare < 200 and _kare % 8 == 0:
            _ana.oyuncu.isi.deger = _ana.oyuncu.isi.tavan * 0.75
            _ana.oyuncu._ates_et(Vector2.RIGHT.rotated(randf() * 0.6))
        if _kare < 210:
            return false
        RenderingServer.force_draw()
        root.get_texture().get_image().save_png(_cikti("kor-patron.png"))
        print("patron: kor-patron.png")
        return true

    if _menu_modu:
        _kare += 1
        if _kare < 120:
            return false
        RenderingServer.force_draw()
        root.get_texture().get_image().save_png(_cikti("kor-menu.png"))
        print("menu: kor-menu.png  locale=%s  ingilizce=%s" % [TranslationServer.get_locale(), _ingilizce])
        return true

    _kare += 1
    # Isi çubuğu ve mermiler görünsün diye ateş ettir
    if _kare == 80 and not _gorus_modu:
        _ana.oyuncu.silah_ver(1)          # SACMA -- cok mermi gorunsun
    if not _gorus_modu and _kare > 90 and _kare < 200 and _kare % 9 == 0:
        _ana.oyuncu._ates_et(Vector2.RIGHT.rotated(randf() * TAU))
    if _kare == 180:
        # Gercek girdi taklidi: yuruyus animasyonu calissin
        Input.action_press("move_right")
        Input.action_press("move_down")
    if _kare == 210:
        # Kor atisi gorunsun: isiyi esigin ustune getir, sonra at
        var o = _ana.oyuncu
        # Demo icin kilidi elle sifirla -- oyunda dalis bunu YAPAMAZ,
        # kilit sadece suresi dolunca cozulur.
        o.isi.kilitli = false
        o.isi.deger = 0.0
        o._kor_bekleme = 0.0
        while o.isi.oran() < 0.75 and not o.isi.kilitli:
            o.isi.ates_et()
    if _kare == 248:
        # Bir dusmani oldur -- olum patlamasi ve kul zerreleri gorunsun
        var liste := get_nodes_in_group("dusman")
        if liste.size() > 0:
            liste[0].hasar_al(9999.0, Vector2.RIGHT * 90.0)
    if _kare == 252:
        _ana.oyuncu._kor_at(Vector2.RIGHT)
    if _kare == 256:
        _ana.oyuncu._ates_et(Vector2.RIGHT.rotated(-0.5))
    if _kare == 100 and not _gorus_modu:
        var o2 = _ana.oyuncu
        o2.dokum_sarj = 1.0
        o2.dokum_degisti.emit(1.0, true)
        o2.damga_tak("delici")
        o2.damga_tak("kor_izi")
    if _kare == 235:
        # Bes turu de yan yana koy ki hepsi tek karede gorunsun
        for t in 6:
            var d = _ana.DusmanSahne.instantiate()
            d.kur(t, 1.0)
            d.global_position = _ana.oyuncu.global_position + Vector2(-85 + t * 34, -54)
            _ana.add_child(d)
    if _ozet_modu:
        if _kare == 100:
            for n in 4:
                _ana._xp_topla(_ana.xp_hedef)
                var kk = _ana.get("_kart_katman")
                if kk != null and is_instance_valid(kk):
                    for kat in kk.get_children():
                        for c in kat.get_children():
                            if c is Button:
                                c.pressed.emit()
                                break
        if _kare == 130:
            _ana.oyuncu.hasar_al(99.0)
        if _kare == 160:
            RenderingServer.force_draw()
            root.get_texture().get_image().save_png(_cikti("kor-ozet.png"))
            print("ozet paneli: kor-ozet.png")
            return true
        return false
    if _gorus_modu:
        var o = _ana.oyuncu
        if _kare == 150:
            o.isi.kilitli = false
            o.isi.deger = 0.0
        if _kare == 170:
            RenderingServer.force_draw()
            root.get_texture().get_image().save_png(_cikti("kor-soguk.png"))
        if _kare == 172:
            o.isi.deger = o.isi.tavan * 0.95
        if _kare == 210:
            RenderingServer.force_draw()
            root.get_texture().get_image().save_png(_cikti("kor-sicak.png"))
            o.isi.kilitle()
        if _kare == 240:
            RenderingServer.force_draw()
            root.get_texture().get_image().save_png(_cikti("kor-kilit.png"))
            print("gorus: soguk + sicak + kilit")
            return true
        return false
    if _kart_modu and _kare == 120:
        _ana._xp_topla(_ana.xp_hedef)      # seviye kartlarini ac
    if _kart_modu and _kare == 150:
        RenderingServer.force_draw()
        root.get_texture().get_image().save_png(CIKTI_KART)
        print("kart ekrani: %s" % CIKTI_KART)
        return true
    if _kare < 260:
        return false
    RenderingServer.force_draw()
    var img := root.get_texture().get_image()
    img.save_png(CIKTI)
    print("ekran: %s  (%dx%d, dusman=%d, isi=%.0f)" % [
        CIKTI, img.get_width(), img.get_height(),
        get_nodes_in_group("dusman").size(), _ana.oyuncu.isi.deger])
    return true

func _dugme_ara(kok: Node) -> Array:
    var b: Array = []
    for c in kok.get_children():
        if c is Button and c.has_meta("kart_secim"):
            b.append(c)
        b.append_array(_dugme_ara(c))
    return b


## Acilis dizisi. Elle oynayarak bakmak yerine tek komutla uc ani da cek:
##   godot --script res://tests/ekran_al.gd -- --acilis
func _acilis() -> bool:
    _kare += 1
    var o = _ana.oyuncu

    # 1. SONUK -- oyuncu daha hicbir sey yapmadi
    if _kare == 40:
        RenderingServer.force_draw()
        root.get_texture().get_image().save_png(_cikti("kor-acilis-1-sonuk.png"))
        print("acilis 1/3 sonuk  (yakilan=%d/%d, gorus=%.0fpx)" % [
            _ana.yakilan_mangal, _ana.toplam_mangal, _karanlik_yaricap()])

    # 2. GORUS -- ates et, isin, dunya acilsin
    if _kare > 45 and _kare < 110 and _kare % 4 == 0:
        o._ates_et(Vector2.RIGHT.rotated(randf() * TAU))
    if _kare == 115:
        RenderingServer.force_draw()
        root.get_texture().get_image().save_png(_cikti("kor-acilis-2-gorus.png"))
        print("acilis 2/3 gorus  (isi=%.0f%%, gorus=%.0fpx)" % [
            o.isi.oran() * 100.0, _karanlik_yaricap()])

    # 3. YANIK -- sicakken sonuk bir mangala git
    if _kare == 120:
        var hedef: Node2D = null
        for y in get_nodes_in_group("yapi"):
            if y.turu() == "mangal" and not y.yanik:
                hedef = y
                break
        if hedef != null:
            o.global_position = hedef.global_position + Vector2(12, 0)
            o.isi.kilitli = false
            o.isi.deger = o.isi.tavan * 0.75
    if _kare == 150:
        RenderingServer.force_draw()
        root.get_texture().get_image().save_png(_cikti("kor-acilis-3-yanik.png"))
        print("acilis 3/3 yanik  (yakilan=%d/%d)" % [_ana.yakilan_mangal, _ana.toplam_mangal])
        return true
    return false

func _karanlik_yaricap() -> float:
    var kl := get_nodes_in_group("karanlik")
    return kl[0]._oyuncu_yaricapi() if kl.size() > 0 else -1.0

## Cikti klasoru. Onceden mutlak yol sabitlenmisti ("D:/..."): hem makine
## duzenini sizdiriyordu (depo public olacak) hem de klonlayan kimsede
## calismiyordu. Varsayilan proje icindeki ciktilar/, KOR_CIKTI ortam
## degiskeniyle degistirilebilir.
static func _cikti(ad: String) -> String:
    var kok := OS.get_environment("KOR_CIKTI")
    if kok.is_empty():
        kok = ProjectSettings.globalize_path("res://ciktilar")
    DirAccess.make_dir_recursive_absolute(kok)
    return kok.rstrip("/\\") + "/" + ad
