extends SceneTree
## Denge ölçüm takımı.
##
## Kor'un dengesi tahminle ayarlanmayacak. Bu araç betikli bir oyuncu
## politikasıyla N koşu oynatıp ölçüm çıkarıyor: hayatta kalma süresi,
## kilit sıklığı, ortalama ısı, seviye eğrisi, ekrandaki düşman sayısının
## zaman serisi.
##
## Bot **gerçek oyunu** oynuyor: aynı `_ates_et`, aynı `_kor_at`, aynı ısı
## kuralları. Paralel bir simülasyon değil — yoksa ölçtüğümüz şey oyun
## olmazdı.
##
## Çalıştırma (hızlı ileri sarma için --fixed-fps şart):
##   godot --headless --fixed-fps 60 --script res://tests/denge.gd
##   godot --headless --fixed-fps 60 --script res://tests/denge.gd -- --kosu 20 --sure 300
##
## `--fixed-fps` motoru gerçek zamandan koparır: her kare tam 1/60 sn
## ilerler ama CPU izin verdiği kadar hızlı döner. 10 koşu x 180 sn oyun
## süresi birkaç dakikada biter.

const RAPOR := "D:/Claude Projeleri/raporlar/kor-denge-olcum.md"

var kosu_sayisi := 10
var kosu_suresi := 180.0
var tohum := 20260914
# Tarama parametreleri (-1 = dokunma)
var ayar_soguma := -1.0
var ayar_spawn := -1.0
var ayar_gorus := -1.0
var ayar_guc := -1.0
var ayar_tavan := -1.0
var ayar_hasar := -1.0
var ayar_yayilim := -1.0
var ayar_can := -1
var etiket := ""

var _ana: Node2D
var _oyuncu: CharacterBody2D
var _kosu := 0
var _sonuclar: Array[Dictionary] = []

# Tek koşunun biriktirdikleri
var _isi_toplam := 0.0
var _isi_ornek := 0
var _kilit_sayisi := 0
var _kilit_sure := 0.0
var _onceki_kilit := false
var _seri: Array = []          # [saniye, dusman, seviye, isi_orani]
var _sonraki_ornek := 0.0
var _secilen_kartlar: Array = []
var _kare := 0
var _karanlik: Node = null
var _son_gorulen := Vector2.ZERO
var _gorunen_toplam := 0.0
var _son_gorunen_sayi := 0
# Olum tanilama: darbeyi ne vuruyor, ne zaman, kac dusman dibimizdeydi
var _darbe := 0
var _darbe_zamanlari: Array = []
var _dip_toplam := 0.0
var _ayar_can := -1
var _son_can := 99

func _initialize() -> void:
    var a := OS.get_cmdline_user_args()
    for i in a.size():
        if a[i] == "--kosu" and i + 1 < a.size():
            kosu_sayisi = int(a[i + 1])
        elif a[i] == "--sure" and i + 1 < a.size():
            kosu_suresi = float(a[i + 1])
        elif a[i] == "--tohum" and i + 1 < a.size():
            tohum = int(a[i + 1])
        elif a[i] == "--soguma" and i + 1 < a.size():
            ayar_soguma = float(a[i + 1])
        elif a[i] == "--spawn" and i + 1 < a.size():
            ayar_spawn = float(a[i + 1])
        elif a[i] == "--gorus" and i + 1 < a.size():
            ayar_gorus = float(a[i + 1])
        elif a[i] == "--guc" and i + 1 < a.size():
            ayar_guc = float(a[i + 1])
        elif a[i] == "--tavan" and i + 1 < a.size():
            ayar_tavan = float(a[i + 1])
        elif a[i] == "--hasar" and i + 1 < a.size():
            ayar_hasar = float(a[i + 1])
        elif a[i] == "--yayilim" and i + 1 < a.size():
            ayar_yayilim = float(a[i + 1])
        elif a[i] == "--can" and i + 1 < a.size():
            ayar_can = int(a[i + 1])
        elif a[i] == "--etiket" and i + 1 < a.size():
            etiket = a[i + 1]
    print("denge: %d kosu x %.0f sn, tohum %d" % [kosu_sayisi, kosu_suresi, tohum])
    _kosu_basla()

func _kosu_basla() -> void:
    seed(tohum + _kosu * 7919)
    _ana = load("res://scenes/level.tscn").instantiate()
    root.add_child(_ana)
    # NOT: @onready degiskenler bu anda henuz cozulmemis oluyor
    # (dugum _initialize icinde ekleniyor), oyuncu ilk _process'te aliniyor.
    _oyuncu = null
    _isi_toplam = 0.0
    _isi_ornek = 0
    _kilit_sayisi = 0
    _kilit_sure = 0.0
    _onceki_kilit = false
    _seri = []
    _sonraki_ornek = 0.0
    _secilen_kartlar = []
    _darbe = 0
    _darbe_zamanlari = []
    _dip_toplam = 0.0
    _son_can = 99
    _gorunen_toplam = 0.0
    _son_gorunen_sayi = 0
    _kare = 0

func _process(delta: float) -> bool:
    if _ana == null:
        return true
    if _oyuncu == null:
        _oyuncu = _ana.oyuncu
        if _oyuncu == null:
            return false
        _oyuncu.bot_aktif = true
        _oyuncu.can_degisti.connect(func(c, m):
            if c < _son_can:
                _darbe += 1
                _darbe_zamanlari.append(snappedf(_ana.gecen, 0.1))
            _son_can = c)
        var kl := get_nodes_in_group("karanlik")
        _karanlik = kl[0] if not kl.is_empty() else null
        if ayar_soguma > 0.0:
            _oyuncu.isi.soguma_hizi = ayar_soguma
        if ayar_spawn > 0.0:
            _ana.spawn_carpani = ayar_spawn
        if ayar_gorus > 0.0 and _karanlik != null:
            _karanlik.taban_yaricap = ayar_gorus
        if ayar_guc > 0.0:
            _ana.guc_carpani = ayar_guc
        if ayar_tavan > 0.0:
            _ana.tavan_artis = ayar_tavan
        if ayar_hasar > 0.0:
            _oyuncu.mermi_hasari = ayar_hasar
        if ayar_yayilim >= 0.0:
            _oyuncu.yayilim_dps = ayar_yayilim
        if ayar_can > 0:
            _oyuncu.maks_can = ayar_can
            _oyuncu.can = ayar_can
            _son_can = ayar_can
    if not is_instance_valid(_oyuncu):
        return true

    # Seviye karti aciksa oyun DURAKLI: bot secmezse kosu sonsuza donar.
    # (Bu takim tam da bunu yakalamak icin var.)
    if _kart_sec():
        return false

    _politika()

    # Ölçüm
    var i = _oyuncu.isi
    _isi_toplam += i.oran()
    _gorunen_toplam += float(_son_gorunen_sayi)
    _dip_toplam += float(_dipteki_dusman())
    _isi_ornek += 1
    if i.kilitli:
        _kilit_sure += delta
        if not _onceki_kilit:
            _kilit_sayisi += 1
    _onceki_kilit = i.kilitli

    if _ana.gecen >= _sonraki_ornek:
        _sonraki_ornek += 10.0
        _seri.append([int(_ana.gecen), get_nodes_in_group("dusman").size(),
            _ana.seviye, snappedf(i.oran(), 0.01)])

    # Guvenlik agi: bir kosu asla sonsuza donmesin
    _kare += 1
    if _kare > int(kosu_suresi * 90.0) + 3000:
        push_error("kosu %d takildi (kare tavani)" % (_kosu + 1))
        _kosu_bitir()
        _rapor_yaz()
        return true

    if _ana.bitti or _ana.gecen >= kosu_suresi:
        _kosu_bitir()
        if _kosu >= kosu_sayisi:
            _rapor_yaz()
            return true
        _kosu_basla()
    return false

## Kart ekrani aciksa rastgele bir kart sec. "Ortalama oyuncu" modeli:
## en iyi karti degil, gelenlerden birini aliyor.
func _kart_sec() -> bool:
    var kk = _ana.get("_kart_katman")
    if kk == null or not is_instance_valid(kk):
        return false
    # Arayuz agaci degisince kirilmasin diye derinlemesine ara.
    var dugmeler: Array = _dugme_ara(kk)
    if dugmeler.is_empty():
        return false
    var d: Button = dugmeler[randi() % dugmeler.size()]
    _secilen_kartlar.append(d.text.strip_edges().split("
")[0].strip_edges())
    d.pressed.emit()
    return true

func _dugme_ara(kok: Node) -> Array:
    var b: Array = []
    for c in kok.get_children():
        if c is Button:
            b.append(c)
        b.append_array(_dugme_ara(c))
    return b

## --- Bot politikasi ---------------------------------------------------------
##
## Makul bir oyuncuyu taklit ediyor, mükemmel oyuncuyu değil. Amaç "en iyi
## oynanışta ne oluyor" değil, "ortalama oyuncuda ne oluyor" ölçmek.
func _politika() -> void:
    var o := _oyuncu
    var p := o.global_position

    # ONEMLI: bot SADECE gordugunu bilir. Isi = gorus mekanigini bot da
    # odemezse olculen sey oyun olmaz, iyimser bir hayal olur. Gorus
    # yaricapinin biraz disini de "siluet/ses" payi olarak sayiyoruz.
    var gorus := 90.0
    if _karanlik != null:
        gorus = _karanlik._oyuncu_yaricapi() + 24.0

    var en_yakin: Node2D = null
    var en_yakin_d := 1e9
    var yakin_sayi := 0
    var gorunen := 0
    for d in get_nodes_in_group("dusman"):
        var uz: float = p.distance_to(d.global_position)
        if uz > gorus:
            continue                      # karanlikta, bot bunu bilmiyor
        gorunen += 1
        if uz < 120.0:
            yakin_sayi += 1
        if uz < en_yakin_d:
            en_yakin_d = uz
            en_yakin = d

    # Nişan: en yakın düşman
    if en_yakin != null:
        o.bot_nisan = (en_yakin.global_position - p).normalized()
        _son_gorulen = en_yakin.global_position

    # Hareket: tehditten uzaklaş, arenanın ortasına doğru yanaş (köşeye sıkışma)
    var kac := Vector2.ZERO
    if en_yakin != null and en_yakin_d < 90.0:
        kac = (p - en_yakin.global_position).normalized()
    var merkez := (Vector2(320, 176) - p)
    if merkez.length() > 150.0:
        kac += merkez.normalized() * 0.8
    # XP küpü yakınsa topla
    var kup = _en_yakin_kup(p)
    if kup != null and en_yakin_d > 70.0:
        kac += (kup - p).normalized() * 0.6
    o.bot_hareket = kac.normalized()
    _son_gorunen_sayi = gorunen

    # Ateş. Iki sebep: hedef var, VEYA korum ve gormek icin isinmam lazim.
    # Ikincisi oyunun cekirdegi: gorus satin almak icin kilide yaklasiyorsun.
    var gormek_icin: bool = gorunen == 0 and o.isi.oran() < 0.55
    o.bot_ates = (en_yakin != null and en_yakin_d < 260.0) or gormek_icin

    # Kor atışı: kalabalık varsa ya da ısı tavana yaklaştıysa boşa harcama
    o.bot_kor = o.kor_atabilir() and (yakin_sayi >= 3 or o.isi.oran() > 0.80)

    # Dalış. Isi sadece tehdit degil gorus de oldugu icin bot artik kor
    # kalmayi goze alarak bosaltiyor -- yani gercek bir bedel oduyor.
    # Tehlike yokken bosaltmiyor; ancak dibimizde biri varsa ya da tavan
    # cok yakinsa daliyor.
    var tehlike: bool = en_yakin != null and en_yakin_d < 30.0
    o.bot_dalis = tehlike or (not o.isi.kilitli and o.isi.oran() > 0.93 and yakin_sayi > 0)

## Temas menzilindeki dusman sayisi -- olumun asil sebebi bu.
func _dipteki_dusman() -> int:
    if not is_instance_valid(_oyuncu):
        return 0
    var p := _oyuncu.global_position
    var n := 0
    for d in get_nodes_in_group("dusman"):
        if p.distance_squared_to(d.global_position) < 40.0 * 40.0:
            n += 1
    return n

func _en_yakin_kup(p: Vector2) -> Variant:
    var en: Variant = null
    var d := 1e9
    for c in _ana.get_children():
        if c is Area2D and c.has_method("_al") and is_instance_valid(c):
            var u: float = p.distance_to(c.global_position)
            if u < d and u < 130.0:
                d = u
                en = c.global_position
    return en

## --- Raporlama --------------------------------------------------------------

func _kosu_bitir() -> void:
    _kosu += 1
    var sure: float = _ana.gecen
    _sonuclar.append({
        "sure": sure,
        "olduMu": _ana.bitti,
        "seviye": _ana.seviye,
        "oldurulen": _ana.oldurulen,
        "kilit_sayisi": _kilit_sayisi,
        "kilit_orani": (_kilit_sure / maxf(sure, 0.001)),
        "kilit_dk": _kilit_sayisi / maxf(sure / 60.0, 0.001),
        "ort_isi": _isi_toplam / maxf(float(_isi_ornek), 1.0),
        "seri": _seri.duplicate(),
        "silahlar": _oyuncu.acik_silahlar.size(),
        "kartlar": _secilen_kartlar.duplicate(),
        "gorunen": _gorunen_toplam / maxf(float(_isi_ornek), 1.0),
        "darbe": _darbe,
        "darbe_dk": _darbe / maxf(_ana.gecen / 60.0, 0.001),
        "dip": _dip_toplam / maxf(float(_isi_ornek), 1.0),
        "olum_dusman": get_nodes_in_group("dusman").size(),
    })
    var son: Dictionary = _sonuclar[-1]
    print("  kosu %2d: %5.1f sn  sv%-2d  %3d oldurme  kilit %d  isi %%%.0f  darbe %d (dk %.1f)  dipte %.1f  gorunen %.1f  %s" % [
        _kosu, sure, _ana.seviye, _ana.oldurulen, _kilit_sayisi,
        son["ort_isi"] * 100.0, son["darbe"], son["darbe_dk"], son["dip"],
        son["gorunen"], "OLDU" if _ana.bitti else "sagkaldi"])
    _ana.queue_free()
    _ana = null

func _ortanca(d: Array) -> float:
    if d.is_empty():
        return 0.0
    var k: Array = d.duplicate()
    k.sort()
    return float(k[k.size() / 2])

func _rapor_yaz() -> void:
    var sureler: Array = []
    var seviyeler: Array = []
    var kilit_dk: Array = []
    var isilar: Array = []
    var olum := 0
    for s in _sonuclar:
        sureler.append(s["sure"])
        seviyeler.append(float(s["seviye"]))
        kilit_dk.append(s["kilit_dk"])
        isilar.append(s["ort_isi"])
        if s["olduMu"]:
            olum += 1

    var satir: Array[String] = []
    satir.append("# Kor denge ölçümü")
    satir.append("")
    satir.append("Otomatik üretildi: `tests/denge.gd`. Bot gerçek oyunu oynuyor")
    satir.append("(aynı ateş/ısı/dalış yolları), paralel simülasyon değil.")
    satir.append("")
    satir.append("- Koşu: **%d**, tavan süre **%.0f sn**, tohum `%d`" % [kosu_sayisi, kosu_suresi, tohum])
    satir.append("- Ölen koşu: **%d / %d**" % [olum, _sonuclar.size()])
    satir.append("- Hayatta kalma ortancası: **%.1f sn**  (en kısa %.1f, en uzun %.1f)" % [
        _ortanca(sureler), sureler.min(), sureler.max()])
    satir.append("- Seviye ortancası: **%.0f**" % _ortanca(seviyeler))
    satir.append("- Kilit / dakika ortancası: **%.1f**" % _ortanca(kilit_dk))
    satir.append("- Ortalama ısı ortancası: **%%%.0f**" % (_ortanca(isilar) * 100.0))
    satir.append("")
    satir.append("## Koşular")
    satir.append("")
    satir.append("| # | süre | seviye | öldürme | kilit | kilit/dk | ort. ısı | sonuç |")
    satir.append("|---|---|---|---|---|---|---|---|")
    for n in _sonuclar.size():
        var s: Dictionary = _sonuclar[n]
        satir.append("| %d | %.1f sn | %d | %d | %d | %.1f | %%%.0f | %s |" % [
            n + 1, s["sure"], s["seviye"], s["oldurulen"], s["kilit_sayisi"],
            s["kilit_dk"], s["ort_isi"] * 100.0, "öldü" if s["olduMu"] else "sağ kaldı"])
    satir.append("")
    satir.append("## Dalga eğrisi (ilk koşunun zaman serisi)")
    satir.append("")
    satir.append("| sn | ekrandaki düşman | seviye | ısı |")
    satir.append("|---|---|---|---|")
    if not _sonuclar.is_empty():
        for e in _sonuclar[0]["seri"]:
            satir.append("| %d | %d | %d | %%%.0f | " % [e[0], e[1], e[2], float(e[3]) * 100.0])

    var f := FileAccess.open(RAPOR, FileAccess.WRITE)
    if f != null:
        f.store_string("\n".join(satir) + "\n")
        f.close()
    print("")
    var darbeler: Array = []
    var dipler: Array = []
    for s2 in _sonuclar:
        darbeler.append(s2["darbe_dk"])
        dipler.append(s2["dip"])
    print("SONUC %s | sure %.1f | seviye %.0f | kilit/dk %.1f | isi %%%.0f | darbe/dk %.1f | dipte %.1f | olum %d/%d" % [
        etiket if etiket != "" else "varsayilan", _ortanca(sureler), _ortanca(seviyeler),
        _ortanca(kilit_dk), _ortanca(isilar) * 100.0, _ortanca(darbeler),
        _ortanca(dipler), olum, _sonuclar.size()])
    print("ORTANCA: %.1f sn hayatta, seviye %.0f, kilit/dk %.1f, ort isi %%%.0f  (%d/%d oldu)" % [
        _ortanca(sureler), _ortanca(seviyeler), _ortanca(kilit_dk),
        _ortanca(isilar) * 100.0, olum, _sonuclar.size()])
    print("rapor: %s" % RAPOR)
