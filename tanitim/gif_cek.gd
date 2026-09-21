extends "res://tests/denge.gd"
## GEÇİCİ tanıtım yakalama betiği (oturum sonunda silinir).
##
## Neden denge.gd'yi genişletiyor: tanitim/gif_cek.gd oyuncuya hiç girdi
## vermiyordu, bu yüzden yeniden çekimde ekran boş ve hareketsiz çıktı
## (00:06'da öğretici yazısı hâlâ ekranda). denge.gd'de zaten **gerçek
## oyunu oynayan** betikli bot politikası var; onu miras alıp üstüne
## kare yazmak, politikayı kopyalamaktan kısa.
##
## Akış: bot ISINMA_SN saniye normal oynar (arena dolar, seviye atlanır,
## öğretici yazısı gider) -> sonra orijinal GIF'in fikri uygulanır:
## ısı 0'dan tavana ramp edilirken görüş karanlıktan açılır, bot bu
## sırada oynamaya devam eder.
##
##   godot --script res://tanitim/_gif_cek_gecici.gd     (headless DEGIL)

const KLASOR := "KARE_KLASORU_BURAYA"
const ISINMA_SN := 120.0   # bot bu kadar oyun saniyesi normal oynasin
const KARE := 91           # ~4.5 sn @ 20fps
const ORNEK := 3           # her 3 fizik karesinde bir yaz -> 20 fps

var _yazilan := 0
var _ramp := 0

func _initialize() -> void:
	# Tek kosu, uzun sure: rapor yazma asamasina hic varmayacagiz.
	kosu_sayisi = 1
	kosu_suresi = 9999.0
	ayar_kademe = 0
	DisplayServer.window_set_size(Vector2i(640, 360))
	DirAccess.make_dir_recursive_absolute(KLASOR)
	print("tanitim cekimi: %.0f sn isinma, sonra %d kare -> %s" % [ISINMA_SN, KARE, KLASOR])
	_kosu_basla()

func _process(delta: float) -> bool:
	# Botu ve olcumu oldugu gibi calistir.
	if super._process(delta):
		push_error("kosu isinma bitmeden sona erdi (bot oldu mu?)")
		quit(1)
		return true
	if _ana == null or _oyuncu == null or not is_instance_valid(_oyuncu):
		return false
	if _ana.gecen < ISINMA_SN:
		return false

	# Isinma bitti: olmesin diye canini tut, gorusu karanliktan aca aca ac.
	_oyuncu.can = _oyuncu.maks_can
	var t := float(_ramp) / float(KARE * ORNEK)
	_ramp += 1
	_oyuncu.isi.kilitli = false
	_oyuncu.isi.deger = _oyuncu.isi.tavan * clampf(t * 1.35, 0.0, 0.99)

	if (_ramp - 1) % ORNEK == 0:
		var img := root.get_texture().get_image()
		img.resize(640, 360, Image.INTERPOLATE_NEAREST)
		img.save_png("%s/k%03d.png" % [KLASOR, _yazilan])
		_yazilan += 1
		if _yazilan >= KARE:
			print("bitti: %d kare" % _yazilan)
			quit()
			return true
	return false
