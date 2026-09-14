extends RefCounted
## 8 yönlü sprite yardımcısı.
##
## PixelLab yön adlarını (south, south-west, ...) kullanıyor; dosya adları da
## öyle: `<kok>/<durum>_<yon>_<n>.png`. Burada iki iş var: bir vektörü en yakın
## yöne yuvarlamak, ve klasördeki kareleri tek bir SpriteFrames'e çevirmek.
## `.tres` elle yazılmıyor, kaynak kodda kuruluyor -- böylece BOM'lu dosya
## yazıp Godot ayrıştırıcısını çökertme sınıfı hata tamamen ortadan kalkıyor.
##
## Üretilen animasyon adları: "<durum>_<yon>"  (örn. "yuru_south-west")

const YONLER := ["east", "south-east", "south", "south-west",
                 "west", "north-west", "north", "north-east"]

## Vektörü 8 yönden birine yuvarlar. (0,0) -> "south".
static func yon_adi(v: Vector2) -> String:
    if v.length_squared() < 0.0001:
        return "south"
    # atan2 -PI..PI -> dilim; YONLER dogu'dan baslayip saat yonunde ilerler
    var dilim := int(round(v.angle() / (TAU / 8.0)))
    return YONLER[wrapi(dilim, 0, 8)]

## Birden çok durumu (duruş, yürüyüş, ...) tek SpriteFrames'te toplar.
## durumlar: { "yuru": 12.0, "dur": 6.0 }  (ad -> fps)
## Hiç kare bulunamazsa null döner; çağıran yedek görsele düşebilir.
static func kur(kok: String, durumlar: Dictionary) -> SpriteFrames:
    var sf := SpriteFrames.new()
    sf.remove_animation("default")
    var toplam := 0
    for durum in durumlar:
        var fps: float = durumlar[durum]
        var yedek := ""
        for y in YONLER:
            var ad := "%s_%s" % [durum, y]
            sf.add_animation(ad)
            sf.set_animation_speed(ad, fps)
            sf.set_animation_loop(ad, true)
            var i := 0
            while true:
                var yol := "%s/%s_%s_%d.png" % [kok, durum, y, i]
                if not ResourceLoader.exists(yol):
                    break
                sf.add_frame(ad, load(yol))
                if yedek == "":
                    yedek = yol
                i += 1
                toplam += 1
        # Eksik yon kalmasin: bulunan ilk kareyle doldur
        if yedek != "":
            for y in YONLER:
                var ad := "%s_%s" % [durum, y]
                if sf.get_frame_count(ad) == 0:
                    sf.add_frame(ad, load(yedek))
    return sf if toplam > 0 else null

## Bir durumun gerçekten karesi var mı (yedekle doldurulmuş değil)?
static func durum_var(kok: String, durum: String) -> bool:
    return ResourceLoader.exists("%s/%s_south_0.png" % [kok, durum])
