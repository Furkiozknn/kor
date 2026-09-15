extends SceneTree
## Koşu döngüsü dumanı: düşman doğuyor mu, temas hasar veriyor mu,
## XP dolunca kartlar açılıp uygulanıyor mu?
## godot --headless --script res://tests/test_dongu.gd

const SURE := 8.0
const KARE_TAVANI := 20000   # assert patlarsa sonsuz donguye girmeyelim

const Silahlar := preload("res://scripts/silahlar.gd")

var _ana: Node2D
var _kare := 0
var _hasar_sayaci := 0
var _can_koru := true
var _asama := 0
var _xp_once := 0
var _kup_karesi := 0

func _initialize() -> void:
    seed(20260914)
    _ana = load("res://scenes/level.tscn").instantiate()
    root.add_child(_ana)

func _process(_delta: float) -> bool:
    _kare += 1
    # SESSIZ ACILIS: ilk atisa kadar suru dogmuyor (ana.gd ACILIS_SESSIZLIGI).
    # Bu test OYNAYAN bir oyuncuyu temsil etmeli; yoksa dusman dogmuyor,
    # kup dusmuyor ve miknatis kontrolu bos yere patliyor.
    if _kare == 2 and is_instance_valid(_ana) and _ana.oyuncu != null:
        _ana.oyuncu._ates_et(Vector2.RIGHT)
    if _kare == 2:
        # Temas hasarini zamana birakma: dusmanlar artik oyuncu SOGUKSA
        # %38 yavas geliyor (isi takasi) ve 8 saniyede yetisemiyorlar.
        # Bir dusmani dibe koyup olayi deterministik hale getiriyoruz.
        var yakin = _ana.DusmanSahne.instantiate()
        yakin.kur(0, 1.0)
        _ana.add_child(yakin)
        yakin.global_position = _ana.oyuncu.global_position + Vector2(8, 0)
    if _kare == 1:
        # Sabit duran oyuncu er ya da geç ölür; bu test hayatta kalmayı değil
        # döngünün döndüğünü ölçüyor -- canı dolu tutup hasarı sayıyoruz.
        _ana.oyuncu.can_degisti.connect(func(c, m):
            if c < m:
                _hasar_sayaci += 1
                if _can_koru:              # olcum sirasinda kapatiliyor
                    _ana.oyuncu.can = m)
    if _kare > KARE_TAVANI:
        push_error("test_dongu: kare tavanı aşıldı")
        return true
    if _asama == 1:
        return _kup_asamasi()
    if _ana.gecen < SURE:
        return false

    var dusmanlar := get_nodes_in_group("dusman").size()
    var oyuncu = _ana.oyuncu
    assert(not _ana.bitti, "oyuncu canı dolu tutulurken ölmemeli")
    assert(dusmanlar > 0, "dalga spawn'i calismiyor: hic dusman yok")
    assert(_hasar_sayaci > 0, "temas hasari islemiyor")

    # Ses. NOT: autoload adi bu dosya derlenirken henuz tanimli degil
    # (--script ile giren betik projeden once derleniyor), o yuzden
    # tanimlayici yerine dugum uzerinden aliniyor.
    var ses = root.get_node_or_null("SesYonetici")
    assert(ses != null, "SesYonetici autoload'u yuklenmemis")
    var ses_sayisi: int = ses.yukle_klasorden()
    assert(ses_sayisi >= 12, "ses dosyalari eksik: %d" % ses_sayisi)
    for ad in ses.AYAR.keys():
        assert(ses._sesler.has(ad), "AYAR'da olup dosyasi olmayan ses: " + str(ad))
    ses._son_calma.clear()   # oyun da vurus caliyor; bekleme suresi sifirlansin
    assert(ses.cal("vurus"), "cal() ses calamadi")
    # Bekleme suresi: ayni sesi arka arkaya isteyince ikincisi dusmeli
    var dusen_once: int = ses.dusen_sayisi()
    for n in 20:
        ses.cal("vurus")
    assert(ses.dusen_sayisi() > dusen_once, "bekleme suresi calismiyor")

    # ISI = GORUS: oyunun ayrisma noktasi. Soguk dar, sicak genis, kilit kor.
    var kar := get_nodes_in_group("karanlik")
    assert(kar.size() == 1, "karanlik katmani yok")
    var kl: Node = kar[0]
    # Onceki bolum oyuncuyu yanan mangalin yaninda birakmis olabilir ve
    # mangal isiyi tavana itip kilitlemis olabilir. Kilitliyken bosalt()
    # bilerek calismiyor, o yuzden durum ACIKCA sifirlaniyor.
    oyuncu.isi.kilitli = false
    oyuncu.isi.bosalt()
    var dar: float = kl._oyuncu_yaricapi()
    while oyuncu.isi.oran() < 0.9 and not oyuncu.isi.kilitli:
        oyuncu.isi.ates_et()
    var genis: float = kl._oyuncu_yaricapi()
    assert(genis > dar * 1.8, "isindikca gorus acilmali: %.0f -> %.0f" % [dar, genis])

    # KILIT: gorus DARALMAZ, en genis halinde kalir. Ceza silahin susmasi,
    # kirilganlik ve dusmanlarin isiyi sezmesi -- kor olmak degil. Gorus
    # daralsaydi oyunun kendi kurali ("isi = gorus") tersine donerdi.
    oyuncu.isi.kilitle()
    assert(kl._oyuncu_yaricapi() >= genis, "kilitliyken gorus daralmamali")
    assert(not oyuncu.isi.ates_edebilir(), "kilitliyken ates edilememeli")
    assert(not oyuncu.isi.bosalt(), "dalis kilidi kirmamali")

    # TAVLAMA: kilitte hasarsiz dayanirsan 1 can. Kart acmadan calismamali.
    # DIKKAT: harness can_degisti'de cani dolduruyor -- olcum icin kapali.
    _can_koru = false
    oyuncu.isi.kilitli = false
    oyuncu.isi.bosalt()
    oyuncu.maks_can = 6
    oyuncu.can = 3
    oyuncu.tavlanma = false
    oyuncu._tavlama_izle(true)          # kilitten cikis taklidi
    assert(oyuncu.can == 3, "kart alinmadan tavlama olmamali")
    oyuncu.tavlanma = true
    oyuncu.isi.kilitle()
    oyuncu._tavlama_izle(false)         # kilide GIRIS
    oyuncu.isi.kilitli = false
    oyuncu._tavlama_izle(true)          # kilitten CIKIS, hasarsiz
    assert(oyuncu.can == 4, "temiz kilit 1 can vermeli: %d" % oyuncu.can)
    oyuncu.isi.kilitle()
    oyuncu._tavlama_izle(false)
    oyuncu._tavlanma_temiz = false      # kilitte darbe yendi
    oyuncu.isi.kilitli = false
    oyuncu._tavlama_izle(true)
    assert(oyuncu.can == 4, "kilitte hasar alinca tavlama olmamali: %d" % oyuncu.can)
    oyuncu.tavlanma = false
    oyuncu.can = oyuncu.maks_can
    _can_koru = true
    oyuncu.isi.kilitli = false
    oyuncu.isi.deger = 0.0

    # KOR YAYILIMI: sicakken cevre yanmali, soguksan yanmamali
    var hedef = _ana.DusmanSahne.instantiate()
    hedef.kur(0, 1.0)
    _ana.add_child(hedef)
    hedef.global_position = oyuncu.global_position + Vector2(20, 0)
    hedef.can = 999.0
    oyuncu.isi.deger = 0.0
    oyuncu._yayilim_sayaci = 0.0
    oyuncu._kor_yayilimi(1.0)
    assert(is_equal_approx(hedef.can, 999.0), "soguksan yayilim olmamali")
    oyuncu.isi.deger = oyuncu.isi.tavan * 0.9
    oyuncu._yayilim_sayaci = 0.0
    oyuncu._kor_yayilimi(1.0)
    assert(hedef.can < 999.0, "sicakken yayilim hasar vermeli")
    hedef.queue_free()
    oyuncu.isi.deger = 0.0

    # ARENA TERMODINAMIGI: mangal isitir, ors sogutur
    var mangal: Node2D = null
    var ors: Node2D = null
    for y in get_nodes_in_group("yapi"):
        if y.turu() == "mangal" and mangal == null:
            mangal = y
        elif y.turu() == "orsa" and ors == null:
            ors = y
    if mangal != null:
        var eski_yer: Vector2 = oyuncu.global_position
        oyuncu.global_position = mangal.global_position + Vector2(10, 0)

        # SONUK MANGAL: ne isitir ne aydinlatir. Fener disindaki mangallar
        # boyle basliyor -- oyuncu onlari kendi isisiyla yakacak.
        mangal.yanik = false
        mangal.remove_from_group("isik_kaynagi")
        oyuncu.isi.deger = 0.0
        oyuncu._arena_isisi(0.5)
        assert(is_zero_approx(oyuncu.isi.deger), "sonuk mangal isitmamali")

        # SOGUKKEN yakilamaz -- yakmak risk olmali, kaza olmamali
        oyuncu.isi.deger = oyuncu.isi.tavan * (oyuncu.YAKMA_ESIK - 0.15)
        oyuncu._arena_isisi(0.1)
        assert(not mangal.yanik, "esik altinda mangal yanmamali")

        # SICAKKEN yaklasinca yanar ve kalici isik kaynagi olur
        oyuncu.isi.deger = oyuncu.isi.tavan * 0.9
        oyuncu._arena_isisi(0.1)
        assert(mangal.yanik, "sicakken yaklasinca mangal yanmali")
        assert(mangal.is_in_group("isik_kaynagi"), "yanan mangal isik vermeli")

        # Yanik mangal artik isitiyor
        oyuncu.isi.deger = 20.0
        oyuncu._arena_isisi(0.5)
        assert(oyuncu.isi.deger > 20.0, "yanik mangalin yaninda isi artmali")
        oyuncu.global_position = eski_yer
    if ors != null:
        var eski_yer2: Vector2 = oyuncu.global_position
        oyuncu.global_position = ors.global_position + Vector2(8, 0)
        oyuncu.isi.deger = 50.0
        oyuncu._arena_isisi(0.5)
        assert(oyuncu.isi.deger < 50.0, "orsun yaninda isi dusmeli")
        oyuncu.global_position = eski_yer2
    oyuncu.isi.deger = 0.0

    # GERCEK MERMI YOLU. Onceden test dusmanlari elle hasar_al ile
    # olduruyordu; mermi.body_entered zinciri (fizik akisi icinde XP kupu
    # dogurma) hic calismiyordu ve orada gercek bir hata vardi. Artik
    # gercek carpisma geri cagirmasi tetikleniyor.
    var kurban = _ana.DusmanSahne.instantiate()
    kurban.kur(0, 1.0)
    _ana.add_child(kurban)
    kurban.global_position = oyuncu.global_position + Vector2(50, 0)
    var mermi = load("res://scenes/mermi.tscn").instantiate()
    mermi.hasar = 9999.0
    mermi.yon = Vector2.RIGHT
    _ana.add_child(mermi)
    var xp_once2: int = _ana.xp
    mermi._carpti(kurban)            # body_entered'in cagirdigi yol
    assert(kurban.is_queued_for_deletion(), "mermi dusmani olduremedi")

    # ISI TAKASI. Yapisal bosluk: isinin dort faydasi ve tek bedeli vardi,
    # yani soguk olmak bir secim degil ceza suresiydi. Iki karsi bedel
    # eklendi ve ikisi de burada korunuyor.
    var iz = _ana.DusmanSahne.instantiate()
    iz.kur(0, 1.0)
    _ana.add_child(iz)
    iz._hedef = oyuncu
    oyuncu.isi.deger = 0.0
    var koku_soguk: float = iz._koku()
    oyuncu.isi.deger = oyuncu.isi.tavan
    var koku_sicak: float = iz._koku()
    assert(koku_sicak > koku_soguk * 1.5,
        "dusmanlar isiyi sezmeli: soguk %.2f, sicak %.2f" % [koku_soguk, koku_sicak])
    assert(koku_soguk < 0.8, "soguksan izini kaybetmeliler")
    iz.queue_free()

    # Sicakken kirilgansin: ayni hasar daha cok can goturmeli
    _can_koru = false          # can-doldurma kancasi olcumu bozmasin
    oyuncu.maks_can = 40
    oyuncu.isi.deger = 0.0
    oyuncu._dokunulmaz = 0.0
    oyuncu.can = 40
    oyuncu.hasar_al(4.0)
    var soguk_kayip: int = 40 - oyuncu.can
    oyuncu.isi.deger = oyuncu.isi.tavan
    oyuncu._dokunulmaz = 0.0
    oyuncu.can = 40
    oyuncu.hasar_al(4.0)
    var sicak_kayip: int = 40 - oyuncu.can
    assert(sicak_kayip > soguk_kayip,
        "sicakken daha cok hasar almali: %d vs %d" % [sicak_kayip, soguk_kayip])
    oyuncu.isi.deger = 0.0
    oyuncu.maks_can = 6
    oyuncu.can = 6
    _can_koru = true

    # KALICI KAYIT + FIRIN KADEMESI
    var kyt = root.get_node_or_null("Kayit")
    assert(kyt != null, "Kayit autoload'u yok")
    # ONEMLI: kayit KALICI. Onceki calistirmadan kalan kademe testi
    # yanilttigi icin olcumden once acikca sifirlaniyor.
    kyt.kademe_yaz(0)
    var curuf_once: int = kyt.curuf()
    var kazanc: int = kyt.kosu_bitti(120.0, 50)
    assert(kazanc > 0, "kosu sonu curuf vermedi")
    assert(kyt.curuf() == curuf_once + kazanc, "curuf eklenmedi")
    # Kademe carpani kazanci buyutmeli
    kyt.kademe_yaz(2)
    var k2: int = kyt.kosu_bitti(120.0, 50)
    assert(k2 > kazanc, "firin kademesi curuf kazancini buyutmeli")
    assert(kyt.kademe_carpani() > 1.0, "kademe carpani 1'den buyuk olmali")
    kyt.kademe_yaz(0)
    # Kalici gelisim GUC vermemeli: kademe sadece zorlugu artirir
    assert(not kyt.acik("kalici_hasar"), "kalici guc yukseltmesi olmamali")

    # KIZGIN BOLGE: hasar carpani KADEMELI DEGIL ESIKLI olmali.
    # Onceden `ceil(miktar * (1 + 0.6 * oran))` yaziyordu; ceil() yuzunden
    # isi %1'de bile hasar 1'den 2'ye ciktigi icin mekanik gizlice ikiliydi
    # ve efektif can 6 yerine 3'tu. Bu test o sinifi kapatiyor: esigin
    # ALTINDA hasar ham degerinde, USTUNDE tam iki katI.
    _can_koru = false
    oyuncu._dokunulmaz = 0.0
    for olcum in [
        {"oran": 0.00, "bekle": 1}, {"oran": 0.05, "bekle": 1},
        {"oran": 0.50, "bekle": 1}, {"oran": 0.69, "bekle": 1},
        {"oran": 0.85, "bekle": 2}, {"oran": 1.00, "bekle": 2},
    ]:
        oyuncu.isi.kilitli = false
        oyuncu.isi.deger = oyuncu.isi.tavan * float(olcum["oran"])
        oyuncu.maks_can = 20
        oyuncu.can = 20
        oyuncu._dokunulmaz = 0.0
        oyuncu.hasar_al(1.0)
        var yenen: int = 20 - oyuncu.can
        assert(yenen == int(olcum["bekle"]),
            "isi %%%.0f'de hasar %d olmali, %d oldu" % [float(olcum["oran"]) * 100.0, int(olcum["bekle"]), yenen])
    oyuncu.isi.kilitli = false
    oyuncu.isi.deger = 0.0
    oyuncu.maks_can = 6
    oyuncu.can = 6
    oyuncu._dokunulmaz = 0.0
    _can_koru = true

    # FIRIN KADEMELERI GERCEKTEN ISIRIYOR MU.
    # Her kademe isinin bir ODULUNU kapatmali. Kademe 3'un gorus
    # degistiricisi bir sure boyunca sessizce yok oluyordu (karanlik
    # dugumu henuz kurulmadan cagriliyordu) ve kimse fark etmedi --
    # olcumde kademe 2 ile 3 birebir ayni sonucu verdigi icin cikti.
    for kademe in [1, 2, 3]:
        oyuncu.miknatis_isiya_bagli = true
        oyuncu.dokum_kilit_kirar = true
        oyuncu.sicak_hasar_bonusu = true
        var gorus_once: float = kl.gorus_carpani
        kl.gorus_carpani = 1.0
        kyt.kademe_yaz(kademe)
        _ana._firin_kademesi_uygula()
        assert(not oyuncu.miknatis_isiya_bagli, "kademe %d: miknatis odulu kapanmali" % kademe)
        if kademe >= 2:
            assert(not oyuncu.dokum_kilit_kirar, "kademe %d: dokum kilit kirmamali" % kademe)
        if kademe >= 3:
            assert(not oyuncu.sicak_hasar_bonusu, "kademe 3: sicak hasar bonusu kapanmali")
            assert(kl.gorus_carpani < 1.0, "kademe 3: gorus daralmali (%.2f)" % kl.gorus_carpani)
        kl.gorus_carpani = gorus_once
    kyt.kademe_yaz(0)
    oyuncu.miknatis_isiya_bagli = true
    oyuncu.dokum_kilit_kirar = true
    oyuncu.sicak_hasar_bonusu = true

    # GOREVLER: sayaclar dogru isliyor mu, odul SECENEK mi GUC mu
    var gv = _ana.gorevler
    gv.kosu_basla()
    gv.guncelle(5.0, false)
    gv.guncelle(3.0, true)          # kilit sayaci SIFIRLAMALI
    assert(is_zero_approx(gv._sayac["kilitsiz_sure"]), "kilit sayaci sifirlamali")
    gv.guncelle(4.0, false)
    assert(is_equal_approx(gv._sayac["kilitsiz_sure"], 4.0), "kilitsiz sure birikmeli")
    gv.oldurme(0.9)
    gv.oldurme(0.1)
    gv.oldurme(0.5)                 # ara bant hicbirine sayilmamali
    assert(is_equal_approx(gv._sayac["sicak_oldurme"], 1.0), "sicak oldurme sayilmali")
    assert(is_equal_approx(gv._sayac["soguk_oldurme"], 1.0), "soguk oldurme sayilmali")
    # Her gorevin odulu GERCEK bir secenege baglanmis olmali
    for g in _ana.Gorevler.LISTE:
        assert(g.has("verir") and str(g["verir"]) != "", "gorev odulu baglanmamis: " + str(g["ad"]))
    gv.kosu_basla()

    # DAMGA: silaha KALICI yapisir, tavani var, silah degisince TASINMAZ
    oyuncu.damgalar.clear()
    oyuncu.silah_indeksi = 0
    assert(oyuncu.silah_damgalari().size() == 0, "damga bos baslamali")
    assert(oyuncu.damga_tak("delici"), "damga takilmali")
    assert(not oyuncu.damga_tak("delici"), "ayni damga iki kez takilmamali")
    assert(oyuncu.damga_tak("catal") and oyuncu.damga_tak("soguk_namlu"),
        "tavana kadar damga takilabilmeli")
    assert(not oyuncu.damga_takilabilir(), "tavan dolunca takilamamali")
    assert(not oyuncu.damga_tak("agir_dokum"), "tavan dolunca damga eklenmemeli")

    # Damga SILAHA bagli: baska silaha gecince gelmiyor.
    # NOT: silah_ver() kalici olarak silah acar ve sonraki kontrolleri
    # bozar -- burada sadece indeks degistiriliyor, envanter degil.
    var silah_yedek: int = oyuncu.silah_indeksi
    oyuncu.silah_indeksi = 1
    assert(oyuncu.silah_damgalari().size() == 0, "damga silaha ozel olmali")
    oyuncu.silah_indeksi = silah_yedek
    assert(oyuncu.silah_damgalari().size() == 3, "eski silahin damgalari durmali")

    # Damgalar silahin degerlerini GERCEKTEN degistiriyor mu
    var ham: Dictionary = _ana.Silahlar.al(0)
    var dmg: Dictionary = _ana.Silahlar.damgali(0, ["delici", "catal", "soguk_namlu"])
    assert(dmg["delici"] and not ham["delici"], "delici damgasi islemedi")
    assert(int(dmg["adet"]) == int(ham["adet"]) + 1, "catal damgasi islemedi")
    assert(float(dmg["isi"]) < float(ham["isi"]), "soguk namlu damgasi islemedi")
    var agir: Dictionary = _ana.Silahlar.damgali(0, ["agir_dokum"])
    assert(float(agir["hasar"]) > float(ham["hasar"]) and float(agir["hiz"]) < float(ham["hiz"]),
        "agir dokum damgasi islemedi")
    oyuncu.damgalar.clear()

    # DOKUM: sarj dolunca TEK kullanim, gucu ISIYA bagli, kilidi kirar
    _can_koru = false
    oyuncu.dokum_sarj = 0.0
    assert(not oyuncu.dokum_hazir(), "dokum bos baslamali")
    assert(not oyuncu.dokum_yap(), "dolmadan dokum yapilamamali")
    oyuncu._dokum_guncelle(oyuncu.DOKUM_SURE)
    assert(oyuncu.dokum_hazir(), "sure dolunca dokum hazir olmali")

    # Kilitliyken bile calismali -- kilidi kiran TEK sey
    oyuncu.isi.kilitle()
    assert(not oyuncu.isi.bosalt(), "dalis kilidi kirmamali (on kosul)")
    assert(oyuncu.dokum_yap(), "dokum kilitliyken de yapilabilmeli")
    assert(not oyuncu.isi.kilitli, "dokum kilidi kirmali")
    assert(is_zero_approx(oyuncu.isi.deger), "dokum isiyi sifirlamali")
    assert(not oyuncu.dokum_hazir(), "dokum TEK kullanimlik olmali")
    assert(not oyuncu.dokum_yap(), "bosalmis dokum tekrar calismamali")
    _can_koru = true

    # FIRINA AT: yakilan kart kosu boyunca bir daha gelmemeli
    var havuz_once: int = _ana._kart_havuzu().size()
    var kurban_kart: Dictionary = _ana._kart_havuzu()[0]
    var hak_once: int = _ana.yakma_hakki
    _ana._kart_yak(kurban_kart)
    assert(_ana.yakma_hakki == hak_once - 1, "yakma hakki dusmedi")
    var havuz_sonra: int = _ana._kart_havuzu().size()
    assert(havuz_sonra == havuz_once - 1, "yakilan kart havuzdan cikmadi")
    for k in _ana._kart_havuzu():
        assert(str(k["ad"]) != str(kurban_kart["ad"]), "yakilan kart hala havuzda")
    # Hak bitince yakma calismamali
    _ana.yakma_hakki = 0
    var havuz_h: int = _ana._kart_havuzu().size()
    _ana._kart_yak(_ana._kart_havuzu()[0])
    assert(_ana._kart_havuzu().size() == havuz_h, "hak bitince yakma olmamali")
    _ana.yakma_hakki = 3

    # GORUS KAYNAK: kartlar gorusu takas edebilmeli
    var g_once: float = kl._oyuncu_yaricapi()
    _ana._gorus_degistir(1.25, 0.0)
    assert(kl._oyuncu_yaricapi() > g_once, "gorus karti menzili buyutmeli")
    _ana._gorus_degistir(0.8, 0.0)

    # PATRON: can torbasi degil, mekanigin sinavi olmali.
    # Sicakken savunmasiz, soguksa neredeyse dokunulmaz ve kendini onarir.
    var pt = _ana.PatronSahne.instantiate()
    pt.kur(1.0)
    _ana.add_child(pt)
    pt.global_position = oyuncu.global_position + Vector2(60, 0)
    pt._dogus = 0.0
    pt._hedef = oyuncu
    oyuncu.isi.deger = 0.0
    var c0: float = pt.can
    pt.hasar_al(100.0)
    var soguk_hasar: float = c0 - pt.can
    pt.can = c0
    oyuncu.isi.deger = oyuncu.isi.tavan * 0.9
    pt.hasar_al(100.0)
    var sicak_hasar: float = c0 - pt.can
    assert(sicak_hasar > soguk_hasar * 3.0,
        "patron sicakken cok daha savunmasiz olmali: %.0f vs %.0f" % [sicak_hasar, soguk_hasar])
    # Soguksa onarilmali
    oyuncu.isi.deger = 0.0
    pt.can = 100.0
    pt._physics_process(1.0)
    assert(pt.can > 100.0, "oyuncu soguksa patron onarilmali")
    # Soguk dalga isiyi sifirlamali
    oyuncu.isi.deger = oyuncu.isi.tavan * 0.8
    pt._soguk_dalga()
    assert(is_equal_approx(oyuncu.isi.deger, 0.0), "soguk dalga isiyi sondurmeli")
    pt.queue_free()
    oyuncu.isi.deger = 0.0

    # Arena: her hucre doldu mu
    var hucre: int = _ana._karolar.get_used_cells().size()
    assert(hucre == _ana.SUTUN * _ana.SATIR, "arena karolari eksik: %d" % hucre)

    # Siperler: dogdular mi, kirilabilir olan kiriliyor mu, kalici olan durmali mi
    var yapilar: Array = get_nodes_in_group("yapi")
    assert(yapilar.size() > 0, "arena siperleri dogmadi")
    var kirilir: Array = yapilar.filter(func(y): return y.can > 0.0)
    var kalici: Array = yapilar.filter(func(y): return y.can <= 0.0)
    assert(kirilir.size() > 0, "hic kirilabilir siper yok")
    var k: Node = kirilir[0]
    k.hasar_al(9999.0)
    assert(k.is_queued_for_deletion(), "kirilabilir siper hasarla yok olmali")
    if kalici.size() > 0:
        var m: Node = kalici[0]
        m.hasar_al(9999.0)
        assert(not m.is_queued_for_deletion(), "orsa/mangal kirilmamali")

    # Yedi dusman turu de kurulabiliyor mu (0..6); ozel davranislari dogru mu
    for t in 7:
        var yeni = _ana.DusmanSahne.instantiate()
        yeni.kur(t, 1.0)
        _ana.add_child(yeni)
        var gs: AnimatedSprite2D = yeni.get_node("Gorsel")
        assert(gs.sprite_frames != null, "tur %d karesiz" % t)
        assert(gs.sprite_frames.get_frame_count("yuru") > 0, "tur %d bos animasyon" % t)
        assert(yeni.can > 0.0, "tur %d cansiz" % t)
        if t == 4:
            assert(yeni.collision_mask == 0, "hayalet duvardan gecmeli")
        if t == 5:
            assert(yeni.menzil > 0.0, "cadi menzilli olmali")
        if t == 6:
            assert(yeni.kosucu, "kosucu telegrafli hucum yapmali")
        yeni.queue_free()

    # Cadinin mermisi oyuncuya hasar vermeli (ayri carpisma katmani)
    var cadi = _ana.DusmanSahne.instantiate()
    cadi.kur(5, 1.0)
    cadi.global_position = oyuncu.global_position + Vector2(90, 0)
    _ana.add_child(cadi)
    cadi._ates_et(Vector2.LEFT)
    var mermiler := _ana.get_children().filter(func(c): return c.name.begins_with("DusmanMermisi"))
    assert(mermiler.size() > 0, "cadi mermi uretmedi")
    var cm: Node = mermiler[0]
    assert(cm.collision_mask & 2 != 0, "cadi mermisi oyuncu katmanini gormeli")
    assert(cm.collision_mask & 4 == 0, "cadi mermisi dusmanlari vurmamali")
    # NOT: testin can-doldurma kancasi hasari aninda geri aliyor,
    # o yuzden cani degil hasar sayacini olcuyoruz.
    var vurus_once: int = _hasar_sayaci
    oyuncu._dokunulmaz = 0.0
    cm._carpti(oyuncu)
    assert(_hasar_sayaci > vurus_once, "cadi mermisi oyuncuya hasar vermeli")
    cadi.queue_free()

    # Kor atisi: esik altinda calismamali
    oyuncu.isi.bosalt()
    oyuncu._kor_bekleme = 0.0
    assert(not oyuncu.kor_atabilir(), "esik altinda kor atisi olmamali")
    # Esigin ustune isit, sonra at
    while oyuncu.isi.oran() < 0.6 and not oyuncu.isi.kilitli:
        oyuncu.isi.ates_et()
    assert(oyuncu.kor_atabilir(), "esik ustunde kor atisi hazir olmali")
    var isi_once: float = oyuncu.isi.deger
    var m: Node = oyuncu._kor_at(Vector2.RIGHT)
    assert(m != null, "kor atisi mermi uretmedi")
    assert(m.delici, "kor atisi delici olmali")
    assert(m.hasar > oyuncu.mermi_hasari, "kor atisi normal mermiden guclu olmali")
    assert(oyuncu.isi.deger < isi_once, "kor atisi isiyi harcamali")
    assert(not oyuncu.kor_atabilir(), "kor atisindan hemen sonra tekrar atilamaz")

    # Silahlar: kart acinca gecis calismali.
    # ON KOSULU KENDI KURUYOR: onceden bir onceki bolumun hangi karti
    # sectigine bagliydi ve havuza kart eklenince cekilis degisip test
    # kiriliyordu. Test bolumleri birbirinin durumuna guvenmemeli.
    oyuncu.acik_silahlar = [0]
    oyuncu.silah_indeksi = 0
    assert(oyuncu.acik_silahlar.size() == 1, "on kosul: tek silah")
    var ilk_silah: int = oyuncu.silah_indeksi
    oyuncu.silah_gec(true)
    assert(oyuncu.silah_indeksi == ilk_silah, "tek silahla gecis olmamali")
    oyuncu.silah_ver(3)
    assert(oyuncu.acik_silahlar.size() == 2, "silah acilmadi")
    assert(oyuncu.silah_indeksi == 3, "yeni silah eline gecmeli")
    oyuncu.silah_gec(true)
    assert(oyuncu.silah_indeksi != 3, "iki silah varken gecis calismali")
    # Her silahin isi profili farkli olmali -- yoksa secim anlamsiz
    var profiller := {}
    for sl in Silahlar.LISTE:
        var oran: float = float(sl["isi"]) / float(sl["aralik"])   # saniyedeki isi
        profiller[round(oran)] = true
        assert(sl["hasar"] > 0.0 and sl["aralik"] > 0.0, "silah tablosu bozuk: " + str(sl["ad"]))
    assert(profiller.size() == Silahlar.LISTE.size(), "iki silah ayni isi profilinde")

    # Seviye kartlari: XP dolunca açılmalı, seçince oyun devam etmeli
    _ana._xp_topla(_ana.xp_hedef)
    assert(_ana.seviye == 2, "XP dolunca seviye atlamali")
    assert(_ana._kart_katman != null, "seviye kartlari acilmadi")
    assert(paused, "kart ekrani oyunu duraklatmali")
    var dugmeler := _dugmeleri_bul(_ana._kart_katman)
    assert(dugmeler.size() == 3, "3 kart secenegi olmali, %d bulundu" % dugmeler.size())
    var once := _oyuncu_ozeti(oyuncu)
    (dugmeler[0] as Button).pressed.emit()
    assert(not paused, "kart secilince duraklatma kalkmali")
    assert(_oyuncu_ozeti(oyuncu) != once, "secilen kart oyuncuya uygulanmadi")

    # Aşama 2: oyuncunun yanındaki düşmanı öldür -> XP küpü düşsün,
    # mıknatısla toplansın, XP artsın. (uçtan uca: hasar -> küp -> XP)
    var d: Node2D = get_nodes_in_group("dusman")[0]
    d.global_position = oyuncu.global_position + Vector2(24, 0)
    _xp_once = _ana.xp
    _kup_karesi = _kare
    d.hasar_al(9999.0)
    _asama = 1
    return false

func _kup_asamasi() -> bool:
    if _ana.xp > _xp_once or _ana.seviye > 2:
        print("test_dongu: TAMAM  (dusman=%d, temas=%d, sure=%.1fs, kup toplandi)" % [
            get_nodes_in_group("dusman").size(), _hasar_sayaci, _ana.gecen])
        return true
    assert(_kare - _kup_karesi < 240, "XP kupu miknatisla toplanmadi")
    return _kare - _kup_karesi >= 240

## Arayuz agaci degisince test kirilmasin: dugmeleri derinlemesine ara.
func _dugmeleri_bul(kok: Node) -> Array:
    var b: Array = []
    for c in kok.get_children():
        if c is Button and c.has_meta("kart_secim"):
            b.append(c)
        b.append_array(_dugmeleri_bul(c))
    return b

## Kart etkisi ozeti. Gorus kartlari OYUNCUYU degil karanlik dugumunu
## degistirdigi icin onun degerleri de burada -- test bu eksikligi yakaladi.
func _oyuncu_ozeti(o) -> Array:
    var kl := get_nodes_in_group("karanlik")
    var g := [0.0, 0.0]
    if not kl.is_empty():
        g = [kl[0].gorus_carpani, kl[0].taban_yaricap]
    return [g[0], g[1],
        o.isi.tavan, o.isi.soguma_hizi, o.isi_carpani, o.hiz, o.atis_hizi_carpani,
        o.mermi_hasari, o.ek_mermi, o.ek_yayilma, o.maks_can, o.asiri_isi_carpani,
        o.dalis_patlamasi, o.miknatis_menzili(), o.kor_carpani, o.kor_maliyet, o.yayilim_dps, o.yayilim_menzil,
        o.acik_silahlar.size(), o.silah_indeksi, _damga_imzasi(o)]

## Butun silahlarin damgalari tek bir metne: ozet bunu gorunce damga
## kartlari da "degisiklik yapti" sayiliyor.
func _damga_imzasi(o) -> String:
    var parcalar: Array = []
    for i in o.damgalar.keys():
        parcalar.append("%d:%s" % [i, ",".join(o.damgalar[i])])
    parcalar.sort()
    return "|".join(parcalar)
