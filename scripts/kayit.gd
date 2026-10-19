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
	"en_iyi_curuf": 0,
	# GUNUN DOKUMU: her gun tek tohum. Gun degisince en iyi ve deneme
	# sayaci sifirlanir -- "bugunku sen" ile yarisiyorsun.
	"gun_kodu": "",
	"gun_en_iyi": 0,
	"gun_deneme": 0,
	"ayarlar": {
		"ses_ana": 0.0,
		"ses_efekt": -6.0,
		"ses_muzik": -14.0,
		"tam_ekran": false,
		"sarsinti": 1.0,
		"donma": true,
		"otomatik_ates": false,
		"gorus_tabani": 0,      # accessibility: cold-sight floor step (scripts/erisim.gd)
		"sakin_isik": false,    # accessibility: steady colours instead of blinking warnings
		"dil": "tr",
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

## Tek bir kosuda elde edilen en yuksek dokum -- oyunun skoru.
func en_iyi_curuf() -> int:
	return int(_veri.get("en_iyi_curuf", 0))

## GUNUN DOKUMU. Tohum UTC tarihten uretiliyor: dunyanin her yerinde
## ayni gun ayni dokumhane. Sunucu gerekmiyor -- kiyas zemini TOHUM.
static func gun_kodu_bugun() -> String:
	var g := Time.get_date_dict_from_system(true)
	return "%04d-%02d-%02d" % [g["year"], g["month"], g["day"]]

## Gunun tohumu. seed() bunu aliyor; ayni gun = ayni arena, ayni dalga
## sirasi, ayni kart teklifleri.
static func gun_tohumu() -> int:
	return abs(hash("kor-" + gun_kodu_bugun()))

## Gun degistiyse gunluk sayaclari sifirla. Her okumadan once cagriliyor.
func _gun_tazele() -> void:
	var bugun := gun_kodu_bugun()
	if str(_veri.get("gun_kodu", "")) != bugun:
		_veri["gun_kodu"] = bugun
		_veri["gun_en_iyi"] = 0
		_veri["gun_deneme"] = 0

func gun_en_iyi() -> int:
	_gun_tazele()
	return int(_veri.get("gun_en_iyi", 0))

func gun_deneme() -> int:
	_gun_tazele()
	return int(_veri.get("gun_deneme", 0))

## Gunluk kosu bitti. Doner: {"en_iyi": int, "deneme": int, "rekor": bool}
func gun_bitti(curuf: int) -> Dictionary:
	_gun_tazele()
	_veri["gun_deneme"] = int(_veri.get("gun_deneme", 0)) + 1
	var rekor := curuf > int(_veri.get("gun_en_iyi", 0))
	if rekor:
		_veri["gun_en_iyi"] = curuf
	kaydet()
	return {"en_iyi": int(_veri["gun_en_iyi"]), "deneme": int(_veri["gun_deneme"]), "rekor": rekor}

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
## Kademe carpani USTEL: onceden dogrusaldi (1 + 0,35k) ve olcumde
## kademe 2 hem kolay hem en cok oduyen secenekti -- baskin strateji.
## Ustel egri, degistiriciler artik gercekten isirdigi icin, ust
## kademeleri gercek bir tercih haline getiriyor.
func kademe_carpani() -> float:
	return pow(1.55, kademe())

## Kosu bitince tek cagri: rekorlari gunceller, curufu kademeye gore ekler.
## Kosu sirasinda BIRIKEN curuf. Onceden butun kazanc kosu SONUNDA tek
## seferde hesaplaniyordu; yani kosunun ikinci yarisinda oyuncunun aldigi
## tek geri bildirim "olmedim" oluyordu. Artik her oldurme gorunur ve
## KALICI bir odul -- olsen bile kazandigin curuf duruyor.
func kosu_curufu(oldurme: int) -> int:
	return int(round(oldurme * kademe_carpani()))

## CURUF BIR PARA BIRIMI DEGIL, BIR SKOR.
##
## curuf_harca() hicbir yerden cagrilmiyordu -- dukkan yok, sink yok. Ama
## curuf iki ekranda birden BIRIKEN BIR TOPLAM olarak gosteriliyordu ve
## biriken para gostergesi "bir yerde dukkan var" sozu verir. Yoktu.
##
## Dukkan eklemek de yanlis olurdu: kendi ilkemiz "icerik parayla degil
## ustalikla acilir" ve gorev sistemi zaten secenek veriyor.
##
## kosu_curufu = oldurme x kademe_carpani ZATEN bir arcade skor formulu.
## Yanlis olan sunumuydu. Artik EN IYI DOKUM olarak gosteriliyor, yani
## firin kademesi de anlam kazaniyor: yuksek kademe = yuksek tavan.
func kosu_bitti(sure: float, oldurme: int) -> int:
	var kazanc := kosu_curufu(oldurme)
	curuf_ekle(kazanc)
	if kazanc > int(_veri.get("en_iyi_curuf", 0)):
		_veri["en_iyi_curuf"] = kazanc
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
