extends SceneTree
## godot --headless --script res://tests/test_denge_kurallari.gd
##
## Telemetry-free balance rules. No bot, no recorded play, no network: every
## number here is computed from the game's own tables and heat rules, so the
## test is deterministic and runs in well under a second.
##
## Why it exists: the bot (tests/denge.gd) is a weak proxy (TESLIM.md, open
## issue 1) and cannot see the heat economy. These checks pin the design
## claims the README and the cards make, so a tuning change that breaks one is
## caught here instead of by a player:
##   - weapon lock times (card text, README table) come from the real rules,
##   - the vision curve gives most of the sight in the first half of heat,
##   - the furnace ladder only ever pays more,
##   - the run's shape (phases, breathers, bosses, victory lap) holds together.

const Isi := preload("res://scripts/isi.gd")
const Silahlar := preload("res://scripts/silahlar.gd")
const Dalgalar := preload("res://scripts/dalgalar.gd")
const KaranlikSahne := preload("res://scripts/karanlik.gd")
const KayitBetik := preload("res://scripts/kayit.gd")

const TABANCA := 0
const SACMA := 1
const ISIN := 2
const CEKIC := 3

var _hata := 0
var _sayac := 0

func dogru(kosul: bool, ad: String) -> void:
    _sayac += 1
    if not kosul:
        _hata += 1
        printerr("  [HATA] ", ad)

func _initialize() -> void:
    TranslationServer.set_locale("tr")
    _silah_kurallari()
    _readme_tablosu()
    _gorus_egrisi()
    _firin_merdiveni()
    _kosu_sekli()
    if _hata > 0:
        printerr("test_denge_kurallari: %d/%d kural BOZUK" % [_hata, _sayac])
        quit(1)
        return
    print("test_denge_kurallari: TAMAM (%d kural)" % _sayac)
    quit(0)

## --- weapons -------------------------------------------------------------

func _silah_kurallari() -> void:
    var adim := Silahlar.FIZIK_ADIMI
    for i in Silahlar.LISTE.size():
        var nominal := float(Silahlar.LISTE[i]["aralik"])
        var etkin := Silahlar.etkin_aralik(nominal)
        dogru(etkin >= nominal - 0.0001 and etkin < nominal + adim + 0.0001,
            "%s: real shot interval %.4f is the nominal %.2f rounded up to a physics tick"
            % [Silahlar.LISTE[i]["ad"], etkin, nominal])

    var t := []
    for i in Silahlar.LISTE.size():
        t.append(Silahlar.kilit_suresi(i))
    # Design target in silahlar.gd: the pistol locks after ~5.6 s of holding
    # fire, "if you play carelessly", not every few seconds.
    dogru(t[TABANCA] >= 4.5 and t[TABANCA] <= 7.5,
        "pistol locks in the 4.5-7.5 s design band when held (%.2f s)" % t[TABANCA])
    dogru(t[ISIN] > 0.0 and t[ISIN] <= t[TABANCA],
        "the beam locks first: 'highest damage, fastest lock' (%.2f <= %.2f s)" % [t[ISIN], t[TABANCA]])
    dogru(t[SACMA] < 0.0 or t[SACMA] > t[TABANCA],
        "the shotgun is slower to lock than the pistol (%.2f s)" % t[SACMA])
    dogru(t[CEKIC] < 0.0 or t[CEKIC] > t[SACMA],
        "the hammer is the most patient weapon (%.2f s)" % t[CEKIC])

    # Heat per second in real ticks keeps the documented order.
    var sn := []
    for i in Silahlar.LISTE.size():
        var s: Dictionary = Silahlar.LISTE[i]
        sn.append(float(s["isi"]) / Silahlar.etkin_aralik(float(s["aralik"])))
    dogru(sn[ISIN] > sn[TABANCA] and sn[TABANCA] > sn[SACMA] and sn[SACMA] > sn[CEKIC],
        "heat per second: beam > pistol > shotgun > hammer (%s)" % str(sn))

    for i in Silahlar.LISTE.size():
        var soguk := Silahlar.kilit_suresi(i, ["soguk_namlu"])
        dogru(soguk < 0.0 or (t[i] >= 0.0 and soguk > t[i]),
            "%s: SOĞUK NAMLU (-35%% heat) never makes the lock come sooner (%.2f -> %.2f s)"
            % [Silahlar.LISTE[i]["ad"], t[i], soguk])
        var tepe := Silahlar.basili_tepe(i)
        dogru((t[i] < 0.0) == (tepe < 1.0),
            "%s: a weapon that never locks settles below the ceiling, one that locks reaches it (peak %.0f%%)"
            % [Silahlar.LISTE[i]["ad"], tepe * 100.0])

    # The card shows the simulated number, not tavan / (heat per second).
    for i in Silahlar.LISTE.size():
        var kart := Silahlar.isi_profili(i)
        if t[i] < 0.0:
            dogru(kart.contains("kilitlenmez"), "%s card says holding fire never locks (%s)" % [Silahlar.LISTE[i]["ad"], kart])
        else:
            dogru(kart.contains("~%.1f sn" % t[i]), "%s card shows the simulated lock time (%s)" % [Silahlar.LISTE[i]["ad"], kart])

    # Cards that change heat rules move the card number the right way.
    var genis := Silahlar.kilit_suresi(TABANCA, [], 125.0, 19.0 * 0.85)
    dogru(genis > t[TABANCA], "GENİŞ KAZAN (+25 ceiling, -15%% cooling) delays the pistol lock (%.2f s)" % genis)
    var tetik := Silahlar.kilit_suresi(TABANCA, [], 100.0, 19.0, 1.12, 1.2)
    dogru(tetik > 0.0 and tetik < t[TABANCA], "HIZLI TETİK (+20%% rate, +12%% heat) brings the pistol lock sooner (%.2f s)" % tetik)

## README "Silahlar" table: the "Kilide kalan" column must match the rules.
func _readme_tablosu() -> void:
    var adlar := {"Kor Tabancası": TABANCA, "Saçma": SACMA, "Işın": ISIN, "Çekiç": CEKIC}
    var bulunan := 0
    for satir in FileAccess.get_file_as_string("res://README.md").split("\n"):
        for ad in adlar:
            if not satir.begins_with("| **%s** |" % ad):
                continue
            bulunan += 1
            var hucre := satir.split("|")[3].strip_edges()
            var t := Silahlar.kilit_suresi(int(adlar[ad]))
            if t < 0.0:
                dogru(hucre.contains("kilitlenmez"), "README: %s never locks when held (table says '%s')" % [ad, hucre])
            else:
                var r := RegEx.new()
                r.compile("~?([0-9]+[.,][0-9]+) sn")
                var m := r.search(hucre)
                var yazan := float(m.get_string(1).replace(",", ".")) if m != null else -99.0
                dogru(absf(yazan - t) <= 0.15, "README: %s locks in %.1f s (table says '%s')" % [ad, t, hucre])
    dogru(bulunan == adlar.size(), "README weapon table has all %d weapons (%d found)" % [adlar.size(), bulunan])

## --- vision --------------------------------------------------------------

func _gorus_egrisi() -> void:
    var tutucu := GDScript.new()
    tutucu.source_code = "extends Node2D\nvar isi\n"
    tutucu.reload()
    var o: Node2D = tutucu.new()
    o.isi = Isi.new()
    var k = KaranlikSahne.new()
    k.oyuncu = o
    var onceki := -1.0
    var monoton := true
    for n in 21:
        o.isi.deger = o.isi.tavan * float(n) / 20.0
        var r: float = k._oyuncu_yaricapi()
        if r < onceki:
            monoton = false
        onceki = r
    dogru(monoton, "sight never shrinks as heat rises")
    o.isi.deger = 0.0
    var soguk: float = k._oyuncu_yaricapi()
    o.isi.deger = o.isi.tavan
    var sicak: float = k._oyuncu_yaricapi()
    o.isi.deger = o.isi.tavan * 0.5
    var yari: float = k._oyuncu_yaricapi()
    dogru(is_equal_approx(soguk, k.taban_yaricap) and is_equal_approx(sicak, k.tavan_yaricap),
        "cold sight is the floor (%.0f px), full heat the ceiling (%.0f px)" % [soguk, sicak])
    dogru((yari - soguk) / (sicak - soguk) >= 0.6,
        "the first half of heat gives most of the sight (%.0f%%)" % (100.0 * (yari - soguk) / (sicak - soguk)))
    o.isi.kilitle()
    dogru(k._oyuncu_yaricapi() > sicak, "locked is the widest sight, never a collapse (%.0f px)" % k._oyuncu_yaricapi())
    k.free()
    o.free()

## --- furnace ladder ------------------------------------------------------

func _firin_merdiveni() -> void:
    var kayit = KayitBetik.new()
    var onceki := 0.0
    var artan := true
    for kd in 4:
        kayit.kademe_yaz(kd)
        var c: float = kayit.kademe_carpani()
        if c <= onceki:
            artan = false
        onceki = c
    dogru(artan, "every furnace step pays strictly more slag than the one below")
    kayit.kademe_yaz(0)
    dogru(is_equal_approx(kayit.kademe_carpani(), 1.0), "furnace 0 pays exactly the kill count")
    kayit.free()

## --- run shape -----------------------------------------------------------

func _kosu_sekli() -> void:
    var e: Array = Dalgalar.EVRELER
    dogru(is_equal_approx(float(e[0]["sn"]), 0.0), "the run starts in phase 0")
    var sirali := true
    for n in range(1, e.size()):
        if float(e[n]["sn"]) <= float(e[n - 1]["sn"]):
            sirali = false
    dogru(sirali and float(e[e.size() - 1]["sn"]) < Dalgalar.KOSU_SURESI, "phases are in time order and inside the run")
    var nefes := 0
    for n in range(1, e.size()):
        if not e[n].get("nefes", false):
            continue
        nefes += 1
        dogru(float(e[n]["spawn"]) > float(e[n - 1]["spawn"]) and int(e[n]["tavan"]) < int(e[n - 1]["tavan"]),
            "breather at %.0f s spawns slower and caps lower than the phase before" % float(e[n]["sn"]))
    dogru(nefes >= 2, "the run has at least two breathers (%d)" % nefes)
    for p in Dalgalar.PATRON_ZAMANLARI:
        dogru(not Dalgalar.nefes_mi(float(p)), "the boss at %.0f s does not wake inside a breather" % float(p))
    dogru(is_equal_approx(Dalgalar.ZAFER_TURU, Dalgalar.KOSU_SURESI - 180.0)
        and Dalgalar.kilit_var_mi(Dalgalar.ZAFER_TURU - 1.0) and not Dalgalar.kilit_var_mi(Dalgalar.ZAFER_TURU),
        "the victory lap (no lock) is the last three minutes")
    var guc_artan := true
    var g0 := Dalgalar.guc(0.0)
    for s in range(30, int(Dalgalar.KOSU_SURESI) + 1, 30):
        var g := Dalgalar.guc(float(s))
        if g <= g0:
            guc_artan = false
        g0 = g
    dogru(guc_artan, "enemy power only rises over the run")
    for n in e.size():
        var turler: Array = e[n]["turler"]
        var dolgu := 0
        for tur in turler:
            if int(tur) <= 1:
                dolgu += 1
        dogru(float(dolgu) / float(turler.size()) >= 0.5,
            "phase '%s': fillers (ash, imp) are at least half of the spawn weights (%d/%d)"
            % [e[n]["ad"], dolgu, turler.size()])
