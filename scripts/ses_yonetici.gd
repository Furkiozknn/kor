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
}

var _sesler := {}
var _oynaticilar: Array[AudioStreamPlayer] = []
var _sonraki := 0
var _son_calma := {}
var _dusen := 0          # bekleme yuzunden calinmayan ses sayisi (ayar icin)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in HAVUZ:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_oynaticilar.append(p)

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
	p.volume_db = ayar.get("ses", -6.0)
	var sapma: float = ayar.get("perde", 0.08)
	p.pitch_scale = 1.0 + randf_range(-sapma, sapma)
	p.play()
	return true

func dusen_sayisi() -> int:
	return _dusen

## --- Muzik: efektlerden ayri tek oynatici, dongulu ---

var _muzik: AudioStreamPlayer = null

func muzik_cal(yol := "res://assets/ses/muzik_dokumhane.ogg", ses_db := -14.0) -> bool:
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
		akis.loop_end = akis.data.size() / 4
	if _muzik == null:
		_muzik = AudioStreamPlayer.new()
		add_child(_muzik)
	_muzik.stream = akis
	_muzik.volume_db = ses_db
	_muzik.play()
	return true

func muzik_ses(db: float) -> void:
	if _muzik != null:
		_muzik.volume_db = db

func muzik_dur() -> void:
	if _muzik != null:
		_muzik.stop()
