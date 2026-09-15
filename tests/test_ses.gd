extends SceneTree
## Ses varlik dogrulamasi.
##
## Neden ayri bir test: ses hatasi SESSIZ bir hatadir. AYAR sozlugune yeni
## bir olay yazip dosyayi koymayi unutursan `cal()` sadece false doner --
## ne cokme olur, ne uyari. Oyun eksik sesle yayinlanir ve kimse fark etmez.
## Bu test o sinifi kapatiyor: AYAR'daki HER ad icin dosya var mi?

## NOT: autoload'lar _init sirasinda henuz agaca eklenmemis oluyor --
## kontrol ilk _process karesinde yapiliyor.
func _process(_delta: float) -> bool:
    var hata := 0
    var yon := root.get_node_or_null("SesYonetici")
    if yon == null:
        print("HATA: SesYonetici autoload yok")
        quit(1)
        return true

    var yuklenen: int = yon.yukle_klasorden()
    print("yuklenen ses: ", yuklenen)

    # 1) AYAR'da adi gecen her olayin dosyasi olmali
    for ad in yon.AYAR.keys():
        if not yon.cal(ad):
            print("HATA: ses dosyasi yok veya calmadi -> ", ad)
            hata = 1

    # 2) Katmanli muzik: iki dosya ve AYNI uzunluk (senkron sarti)
    var yollar := ["res://assets/ses/muzik_ocak.ogg", "res://assets/ses/muzik_kor.ogg"]
    var sureler: Array[float] = []
    for y in yollar:
        var a: AudioStream = load(y)
        if a == null:
            print("HATA: katmanli muzik yok -> ", y)
            hata = 1
        else:
            sureler.append(a.get_length())
    if sureler.size() == 2 and absf(sureler[0] - sureler[1]) > 0.01:
        print("HATA: katmanlar esit uzunlukta degil -> ", sureler)
        hata = 1

    # 3) Havuz sizintisi: ayarlari_uygula() tekrar cagrilinca oynatici artmamali
    var once: int = yon._oynaticilar.size()
    yon.ayarlari_uygula()
    yon.ayarlari_uygula()
    if yon._oynaticilar.size() != once:
        print("HATA: oynatici havuzu buyudu ", once, " -> ", yon._oynaticilar.size())
        hata = 1

    # 4) Efekt kaydiraci muzigi kismamali: ayri bus sart
    var efekt_bus: int = AudioServer.get_bus_index("Efekt")
    if efekt_bus < 0:
        print("HATA: Efekt bus'i kurulmamis -- efekt kaydiraci muzigi de kisar")
        hata = 1
    elif yon._oynaticilar[0].bus != "Efekt":
        print("HATA: efekt oynaticilari Efekt bus'inda degil -> ", yon._oynaticilar[0].bus)
        hata = 1

    if hata == 0:
        print("TAMAM ses (", yon.AYAR.size(), " olay, katman ", sureler, ", havuz ", once, ")")
    quit(hata)
    return true
