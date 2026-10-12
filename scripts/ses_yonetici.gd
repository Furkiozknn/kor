extends Node
## Surunun sesi. VS-benzeri oyunda tek karede 50 vurus olabilir; hepsini
## calarsan ses camura doner ve kirpilir. Uc sey yapiyor:
##   1. Sabit oynatici havuzu — dugum yaratip yok etmiyoruz
##   2. Ses basina bekleme suresi — ayni efekt su kadar ms'de bir calabilir
##   3. Hafif perde/ses sapmasi — ust uste binince faz bulanikligi olmasin
##
## Kullanim (Autoload olarak ekle, adi SesYonetici):
##   SesYonetici.cal("vurus")
##   SesYonetici.cal("asiri_isinma")

const KLASOR := "res://assets/ses/"
const HAVUZ := 16          # ayni anda en fazla bu kadar ses
const VARSAYILAN_BEKLEME := 0.045   # saniye
const EFEKT_BUS := "Efekt"

## ad -> {bekleme: saniye, perde: sapma orani, ses: dB}
const AYAR := {
    "ates":          {"bekleme": 0.05,  "perde": 0.10, "ses": -6.0},
    "isi_uyari":     {"bekleme": 0.25,  "perde": 0.03, "ses": -9.0},
    "asiri_isinma":  {"bekleme": 0.60,  "perde": 0.02, "ses": -2.0},
    "dalis":         {"bekleme": 0.20,  "perde": 0.05, "ses": -4.0},
    "vurus":         {"bekleme": 0.04,  "perde": 0.14, "ses": -8.0},
    "dusman_olum":   {"bekleme": 0.06,  "perde": 0.12, "ses": -5.0},
    "kup":           {"bekleme": 0.03,  "perde": 0.16, "ses": -12.0},
    "seviye":        {"bekleme": 0.50,  "perde": 0.00, "ses": -2.0},
    "kart_sec":      {"bekleme": 0.08,  "perde": 0.04, "ses": -6.0},
    # 6. tur sonrasi: kor atisi ve menzilli dusman
    "kor_atisi":     {"bekleme": 0.30,  "perde": 0.04, "ses": -1.0},
    "cadi_atisi":    {"bekleme": 0.06,  "perde": 0.12, "ses": -10.0},
    # Duygusal anlar: perde sapmasi yok -- bunlar her calisinda AYNI olmali,
    # taninabilir olsunlar diye. Bekleme uzun: ust uste binmesinler.
    "oyuncu_hasar":  {"bekleme": 0.22,  "perde": 0.04, "ses": -3.0},
    "oyun_bitti":    {"bekleme": 1.00,  "perde": 0.00, "ses": -2.0},
    "patron_uyandi": {"bekleme": 1.00,  "perde": 0.00, "ses": 0.0},
    "soguk_dalga":   {"bekleme": 0.50,  "perde": 0.02, "ses": -1.0},
    "kosu_bitti":    {"bekleme": 1.00,  "perde": 0.00, "ses": -2.0},
}

var _sesler := {}
var _oynaticilar: Array[AudioStreamPlayer] = []
var _sonraki := 0
var _son_calma := {}
var _dusen := 0
## Kalici ayarlardan gelen ses seviyeleri (dB offset)
var efekt_db := 0.0
var muzik_db := -14.0          # bekleme yuzunden calinmayan ses sayisi (ayar icin)

## Efekt bus'ini bulur, yoksa kurar. Kodda kurulmasinin sebebi: bus duzeni
## .tscn disinda bir kaynak dosyasinda tutuluyor ve elle yazilan kaynak
## dosyalari bu projede BOM riski yuzunden yasak.
func _efekt_bus() -> int:
    var i := AudioServer.get_bus_index(EFEKT_BUS)
    if i >= 0:
        return i
    i = AudioServer.bus_count
    AudioServer.add_bus(i)
    AudioServer.set_bus_name(i, EFEKT_BUS)
    AudioServer.set_bus_send(i, "Master")
    return i

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    # DIKKAT: havuz SADECE burada kurulur. Onceden ayarlari_uygula() icindeydi;
    # ayar menusu her kaydedisinde 16 oynatici daha ekliyordu (sizinti), ve
    # Kayit yoksa erken return yuzunden hic oynatici olusmuyordu (sessiz oyun).
    var bus := AudioServer.get_bus_name(_efekt_bus())
    for i in HAVUZ:
        var p := AudioStreamPlayer.new()
        p.bus = bus
        add_child(p)
        _oynaticilar.append(p)
    ayarlari_uygula()

## Kayit'tan ses seviyelerini oku ve uygula. Menuden degisince tekrar cagrilir.
func ayarlari_uygula() -> void:
    var k := get_node_or_null("/root/Kayit")
    if k == null:
        return
    efekt_db = float(k.ayar("ses_efekt", -6.0)) + 6.0   # -6 varsayilan = 0 offset
    muzik_db = float(k.ayar("ses_muzik", -14.0))
    # Seviye BUS uzerinden uygulanir, oynatici uzerinden degil: web'in Sample
    # yolunda volume_db yok sayiliyor ve kaydiraci olu dugmeye cevirir.
    # Efektlerin AYRI bus'i var; yoksa efekt kaydiraci muzigi de kisardi.
    AudioServer.set_bus_volume_db(_efekt_bus(), efekt_db)
    if _muzik != null:
        _muzik.volume_db = muzik_db
    if _muzik_ocak != null:
        _muzik_ocak.volume_db = muzik_db

func yukle(ad: String, akis: AudioStream) -> void:
    _sesler[ad] = akis

func yukle_klasorden() -> int:
    var d := DirAccess.open(KLASOR)
    if d == null:
        push_warning("ses klasoru yok: " + KLASOR)
        return 0
    var sayi := 0
    for dosya in d.get_files():
        if dosya.ends_with(".wav") or dosya.ends_with(".ogg"):
            var ad := dosya.get_basename()
            var akis: AudioStream = load(KLASOR + dosya)
            if akis != null:
                _sesler[ad] = akis
                sayi += 1
    return sayi

## Sesi calar. Bekleme suresi dolmadiysa sessizce atlar — cagiran taraf
## kosul yazmak zorunda kalmasin diye bool dondurur ama kullanmak sart degil.
## Ses KENDI rastgele akisini kullanir: bekleme kontrolu duvar saatine bagli
## oldugu icin global akistan cekilirse cekilis SAYISI makine hizina gore
## degisiyor ve butun oyun deterministligini kaybediyor (olculdu).
var _rng := RandomNumberGenerator.new()

func cal(ad: String) -> bool:
    var akis: AudioStream = _sesler.get(ad)
    if akis == null:
        return false

    var ayar: Dictionary = AYAR.get(ad, {})
    var bekleme: float = ayar.get("bekleme", VARSAYILAN_BEKLEME)
    var simdi := Time.get_ticks_msec() / 1000.0
    if simdi - float(_son_calma.get(ad, -999.0)) < bekleme:
        _dusen += 1
        return false
    _son_calma[ad] = simdi

    var p := _oynaticilar[_sonraki]
    _sonraki = (_sonraki + 1) % HAVUZ
    p.stream = akis
    p.volume_db = float(ayar.get("ses", -6.0))   # efekt_db Master bus'ta
    var sapma: float = ayar.get("perde", 0.08)
    p.pitch_scale = 1.0 + _rng.randf_range(-sapma, sapma)
    p.play()
    return true

func dusen_sayisi() -> int:
    return _dusen

## --- Muzik: efektlerden ayri tek oynatici, dongulu ---

var _muzik: AudioStreamPlayer = null

func muzik_cal(yol := "res://assets/ses/muzik_dokumhane.ogg", ses_db := 999.0) -> bool:
    muzik_katmanli_dur()
    var akis: AudioStream = load(yol)
    if akis == null:
        push_warning("muzik bulunamadi: " + yol)
        return false
    # Ogg/Wav dongusu: kaynak dosyada dongu bayragini acmak yeterli,
    # oynaticiyi her bitiste yeniden baslatmaya gerek yok.
    if akis is AudioStreamOggVorbis:
        akis.loop = true
    elif akis is AudioStreamWAV:
        akis.loop_mode = AudioStreamWAV.LOOP_FORWARD
        # data.size() bayt sayar, ornek degil; ice aktarma QOA sikistirirsa
        # (compress/mode=2) dongu parcanin bir kismina duser. Ornek sayisi:
        akis.loop_end = int(round(akis.get_length() * akis.mix_rate))
    if _muzik == null:
        _muzik = AudioStreamPlayer.new()
        add_child(_muzik)
    _muzik.stream = akis
    _muzik.volume_db = muzik_db if ses_db > 900.0 else ses_db
    _muzik.play()
    return true

func muzik_ses(db: float) -> void:
    if _muzik != null:
        _muzik.volume_db = db

func muzik_dur() -> void:
    if _muzik != null:
        _muzik.stop()
    muzik_katmanli_dur()

## --- Katmanli muzik: isiyla yukselen ikinci kat -------------------------
##
## Tek 10 saniyelik dongu 720 saniyelik kosuda 72 kez tekrar ediyordu. Iki
## sorunu birden cozuyor: dongu 40 saniye, VE muzik oyunun durumunu anlatiyor.
##
##   muzik_ocak.ogg  her zaman calar       (drone + cekic + uzak metal)
##   muzik_kor.ogg   isiyla acilir, ustune (bas nabiz + hizli perkusyon)
##
## Ikisi ayni uzunlukta (40,000 sn) ve AYNI KAREDE baslatiliyor -- yoksa
## senkron kayar ve iki ayri parca gibi duyulur.

var _muzik_ocak: AudioStreamPlayer = null
var _muzik_kor: AudioStreamPlayer = null
var _kor_hedef_db := SESSIZ_DB

const SESSIZ_DB := -60.0

func _process(delta: float) -> void:
    if _muzik_kor == null:
        return
    # Kare hizindan bagimsiz yumusatma; yoksa her atista ses sicriyor.
    var k := 1.0 - pow(0.02, delta)
    _muzik_kor.volume_db = lerpf(_muzik_kor.volume_db, _kor_hedef_db, k)

func _oynatici(yol: String, db: float) -> AudioStreamPlayer:
    var akis: AudioStream = load(yol)
    if akis == null:
        push_warning("muzik bulunamadi: " + yol)
        return null
    if akis is AudioStreamOggVorbis:
        akis.loop = true
    var p := AudioStreamPlayer.new()
    p.stream = akis
    p.volume_db = db
    add_child(p)
    return p

## Katmanli muzigi baslatir. Dosyalar yoksa tek katmanli eskiye duser.
func muzik_katmanli_cal() -> bool:
    if _muzik_ocak != null and _muzik_ocak.playing:
        return true
    if _muzik != null:
        _muzik.stop()
    _muzik_ocak = _oynatici("res://assets/ses/muzik_ocak.ogg", muzik_db)
    _muzik_kor = _oynatici("res://assets/ses/muzik_kor.ogg", SESSIZ_DB)
    if _muzik_ocak == null or _muzik_kor == null:
        return muzik_cal()
    _kor_hedef_db = SESSIZ_DB
    _muzik_ocak.play()
    _muzik_kor.play()
    return true

## Her karede oyuncunun isi oranini ver (0..1). Ustel egri onemli: dogrusal
## olursa dusuk isida bile kor katmani duyuluyor ve etki kayboluyor.
func muzik_isi(oran: float) -> void:
    _kor_hedef_db = lerpf(SESSIZ_DB, muzik_db, pow(clampf(oran, 0.0, 1.0), 1.6))

func muzik_katmanli_dur() -> void:
    _kor_hedef_db = SESSIZ_DB
    for p in [_muzik_ocak, _muzik_kor]:
        if p != null:
            p.stop()
