extends Node
## kayit.gd dogrulama testi.
##
## DIKKAT: bu test `extends Node`, yani --script ILE CALISMAZ. Oyle
## cagrildiginda sessizce hicbir sey yapmaz ve CIKTI DA VERMEZ -- yani
## kirik oldugu halde gecmis gibi gorunur. Bir kez tam boyle oldu.
## O yuzden yaninda bir sahne duruyor:
##
##   godot --headless --path . --quit-after 300 tests/test_kayit.tscn
##
## Diger bes test SceneTree oldugu icin --script ile calisiyor; yalnizca
## bu farkli.

const KayitSinif := preload("res://scripts/kayit.gd")

var _k: Node

func _kur() -> Node:
	if _k != null:
		_k.queue_free()
		await get_tree().process_frame
	_k = KayitSinif.new()
	add_child(_k)
	await get_tree().process_frame
	return _k

func _ready() -> void:
	# Temiz baslangic
	if FileAccess.file_exists("user://kor.save"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://kor.save"))

	var k := await _kur()

	# 1) Varsayilanlar
	assert(k.curuf() == 0, "yeni kayit curuf 0 olmali")
	assert(k.kademe() == 0, "kademe 0 olmali")
	assert(not k.acik("silah_kazan"), "hicbir sey acik olmamali")
	assert(k.ayar("ses_muzik", 999.0) == -14.0, "varsayilan ayar gelmedi")
	print("1) varsayilanlar OK")

	# 2) Curuf ekleme/harcama
	k.curuf_ekle(100)
	assert(k.curuf() == 100)
	assert(k.curuf_harca(30) == true and k.curuf() == 70)
	assert(k.curuf_harca(999) == false and k.curuf() == 70, "yetersiz curuf harcanmamali")
	print("2) curuf ekonomisi OK")

	# 3) Kademe carpani — gonullu zorluk odule baglaniyor
	assert(is_equal_approx(k.kademe_carpani(), 1.0))
	k.kademe_yaz(2)
	# kademe_carpani() = pow(1.55, kademe) -> kademe 2 icin 2,4025
	assert(is_equal_approx(k.kademe_carpani(), pow(1.55, 2)), "kademe 2 -> 2,4025 olmali")
	var kazanc: int = k.kosu_bitti(95.0, 40)
	var bek := int(round(40.0 * pow(1.55, 2)))
	assert(kazanc == bek, "40 oldurme x %.4f = %d bekleniyordu, gelen: %d" % [pow(1.55, 2), bek, kazanc])
	print("3) kademe carpani OK (kazanc %d)" % kazanc)

	# 4) Disk turu: yeniden yukleyince ayni mi
	k.ayar_yaz("ses_muzik", -20.0)
	k.ac("silah_kazan")
	assert(k.kaydet(), "kaydetme basarisiz")
	var curuf_once: int = k.curuf()
	k = await _kur()
	assert(k.curuf() == curuf_once, "curuf disk turundan sagi cikmadi")
	assert(k.acik("silah_kazan"), "acilan silah kayboldu")
	assert(k.ayar("ses_muzik") == -20.0, "ayar kayboldu")
	assert(k.kademe() == 2, "kademe kayboldu")
	print("4) disk turu OK")

	# 5) Bozuk dosya varsayilana dusmeli, cokmemeli
	var f := FileAccess.open("user://kor.save", FileAccess.WRITE)
	f.store_string("{bu gecerli json degil")
	f.close()
	k = await _kur()
	assert(k.curuf() == 0, "bozuk kayit varsayilana dusmeliydi")
	print("5) bozuk dosya dayanikliligi OK")

	# 6) Eski kayitta olmayan alan varsayilandan gelmeli
	f = FileAccess.open("user://kor.save", FileAccess.WRITE)
	f.store_string('{"curuf": 555}')
	f.close()
	k = await _kur()
	assert(k.curuf() == 555, "eski alan korunmali")
	assert(k.ayar("ses_muzik") == -14.0, "eksik alan varsayilandan gelmeli")
	assert(k.kademe() == 0, "eksik alan varsayilandan gelmeli")
	print("6) surum gecisi OK")

	print("KAYIT TESTI GECTI")
	get_tree().quit()
