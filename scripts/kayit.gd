extends Node
## Kor'un kalici hafizasi — hem meta ilerleme hem ayarlar, tek dosyada.
##
## Neden tek dosya: iki ayri kayit dosyasi iki ayri bozulma yolu demek.
## user://kor.save JSON; okunabilir, elle duzeltilebilir, surum alani var.
##
## Kullanim (Autoload, ad: Kayit):
##   Kayit.curuf_ekle(120)
##   if Kayit.acik("silah_kazan"): ...
##   Kayit.ac("silah_kazan")
##   Kayit.ayar_yaz("ses_muzik", -18.0)
##   var d := Kayit.ayar("ses_muzik", -14.0)
##
## Tasarim notu: kalici gelisim GUC degil SECENEK vermeli. Buraya kalici
## +hasar / +isi kapasitesi gibi alanlar EKLEME — isi baskisini azaltan her
## kalici yukseltme oyunun cekirdegini sondurur. Ayrinti:
## raporlar/2026-09-14-kor-meta-ilerleme.md

const YOL := "user://kor.save"
const SURUM := 1

## Varsayilanlar. Yeni alan eklerken buraya ekle — eski kayitlar da alir.
const VARSAYILAN := {
	"surum": SURUM,
	"curuf": 0,
	"acilanlar": [],        # "silah_kazan", "kart_ailesi_ocak" gibi anahtarlar
	"firin_kademesi": 0,    # gonullu zorluk; 0 = kapali
	"en_iyi_sure": 0.0,
	"en_iyi_oldurme": 0,
	"ayarlar": {
		"ses_ana": 0.0,
		"ses_efekt": -6.0,
		"ses_muzik": -14.0,
		"tam_ekran": false,
	},
}

var _veri := {}
var _kirli := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	yukle()

func _notification(ne: int) -> void:
	# Oyun kapanirken bekleyen yazma varsa kaydet.
	if ne == NOTIFICATION_WM_CLOSE_REQUEST or ne == NOTIFICATION_PREDELETE:
		if _kirli:
			kaydet()

## --- Dosya ---

func yukle() -> void:
	_veri = VARSAYILAN.duplicate(true)
	if not FileAccess.file_exists(YOL):
		return
	var f := FileAccess.open(YOL, FileAccess.READ)
	if f == null:
		push_warning("kayit okunamadi: " + str(FileAccess.get_open_error()))
		return
	var ham := f.get_as_text()
	f.close()
	var cozulen: Variant = JSON.parse_string(ham)
	if typeof(cozulen) != TYPE_DICTIONARY:
		push_warning("kayit bozuk, varsayilanla devam ediliyor")
		return
	# Eksik alanlari varsayilandan tamamla — eski kayit yeni surumu kirmasin.
	_birlestir(_veri, cozulen)
	_veri["surum"] = SURUM

func _birlestir(hedef: Dictionary, kaynak: Dictionary) -> void:
	for anahtar in kaynak:
		if hedef.has(anahtar) and typeof(hedef[anahtar]) == TYPE_DICTIONARY \
				and typeof(kaynak[anahtar]) == TYPE_DICTIONARY:
			_birlestir(hedef[anahtar], kaynak[anahtar])
		else:
			hedef[anahtar] = kaynak[anahtar]

func kaydet() -> bool:
	var f := FileAccess.open(YOL, FileAccess.WRITE)
	if f == null:
		push_warning("kayit yazilamadi: " + str(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(_veri, "\t"))
	f.close()
	_kirli = false
	return true

func sifirla() -> void:
	_veri = VARSAYILAN.duplicate(true)
	kaydet()

## --- Meta ilerleme ---

func curuf() -> int:
	return int(_veri.get("curuf", 0))

func curuf_ekle(miktar: int) -> int:
	_veri["curuf"] = curuf() + miktar
	_kirli = true
	return curuf()

## Yeterli curuf varsa harcar ve true doner; yoksa dokunmaz.
func curuf_harca(miktar: int) -> bool:
	if curuf() < miktar:
		return false
	_veri["curuf"] = curuf() - miktar
	_kirli = true
	return true

func acik(anahtar: String) -> bool:
	return anahtar in _veri.get("acilanlar", [])

func ac(anahtar: String) -> void:
	if not acik(anahtar):
		_veri["acilanlar"].append(anahtar)
		_kirli = true

func kademe() -> int:
	return int(_veri.get("firin_kademesi", 0))

func kademe_yaz(k: int) -> void:
	_veri["firin_kademesi"] = maxi(0, k)
	_kirli = true

## Firin kademesi curuf kazancini carpar: 0 -> 1.0, her kademe +%35.
func kademe_carpani() -> float:
	return 1.0 + 0.35 * kademe()

## Kosu bitince tek cagri: rekorlari gunceller, curufu kademeye gore ekler.
func kosu_bitti(sure: float, oldurme: int) -> int:
	var kazanc := int(round(oldurme * kademe_carpani()))
	curuf_ekle(kazanc)
	if sure > float(_veri.get("en_iyi_sure", 0.0)):
		_veri["en_iyi_sure"] = sure
	if oldurme > int(_veri.get("en_iyi_oldurme", 0)):
		_veri["en_iyi_oldurme"] = oldurme
	kaydet()
	return kazanc

## --- Ayarlar ---

func ayar(anahtar: String, varsayilan: Variant = null) -> Variant:
	return _veri.get("ayarlar", {}).get(anahtar, varsayilan)

func ayar_yaz(anahtar: String, deger: Variant) -> void:
	_veri["ayarlar"][anahtar] = deger
	_kirli = true
