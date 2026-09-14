extends RefCounted
## Kor'un görsel dili — tek yerden.
##
## Sorun: kart ekranı Godot'nun varsayılan gri düğmelerini, duraklatma paneli
## düz etiketleri, HUD çıplak dikdörtgenleri kullanıyordu. Üç ayrı ürün gibi
## görünüyorlardı ve "varsayılan Godot arayüzü" her oyunda aynı görünen şey.
##
## Kural: arayüz de oyunun kimliğini taşır. Soğuk kül gövde, sıcak kor kenar.
## Köşeler keskin (pixel art), kenarlıklar 1 piksel, boşluklar 4'ün katı.

const YAZI_TIPI := preload("res://assets/fonts/PublicPixel.ttf")

# --- Palet. Oyunun sprite paletinden türetildi. --------------------------
const GOVDE      := Color(0.055, 0.055, 0.085, 0.94)   # panel zemini
const GOVDE_AC    := Color(0.10, 0.10, 0.145, 0.96)    # düğme zemini
const KENAR      := Color(0.38, 0.42, 0.52, 0.85)      # sakin kenar (kül)
const KENAR_KOR   := Color(1.0, 0.55, 0.18, 0.95)      # vurgulu kenar (kor)
const YAZI       := Color(0.88, 0.90, 0.95)
const YAZI_SONUK  := Color(0.62, 0.66, 0.74)
const KOR        := Color(1.0, 0.66, 0.26)
const SOGUK      := Color(0.55, 0.78, 0.95)
const TEHLIKE    := Color(1.0, 0.36, 0.22)

# --- Boşluk ölçeği. Hepsi 4'ün katı; pixel ızgarası bozulmasın. ----------
const BOSLUK_S := 4
const BOSLUK_M := 8
const BOSLUK_L := 12

static func kutu(dolgu: Color, kenar: Color, kalinlik: int = 1,
        ic_bosluk: int = BOSLUK_M) -> StyleBoxFlat:
    var st := StyleBoxFlat.new()
    st.bg_color = dolgu
    st.border_color = kenar
    st.set_border_width_all(kalinlik)
    st.set_corner_radius_all(0)          # keskin köşe: pixel art dili
    st.set_content_margin_all(ic_bosluk)
    return st

## Bütün arayüzün paylaştığı tema. Bir kez kurulup Control ağacının köküne
## verilince alt düğümlerin hepsi otomatik uyuyor.
static func tema() -> Theme:
    var t := Theme.new()
    t.default_font = YAZI_TIPI
    t.default_font_size = 8

    t.set_stylebox("panel", "PanelContainer", kutu(GOVDE, KENAR))

    var d := kutu(GOVDE_AC, KENAR, 1, BOSLUK_M)
    var d_uzer := kutu(Color(0.16, 0.13, 0.12, 0.98), KENAR_KOR, 1, BOSLUK_M)
    var d_bas := kutu(Color(0.24, 0.16, 0.10, 1.0), KENAR_KOR, 1, BOSLUK_M)
    t.set_stylebox("normal", "Button", d)
    t.set_stylebox("hover", "Button", d_uzer)
    t.set_stylebox("pressed", "Button", d_bas)
    t.set_stylebox("focus", "Button", d_uzer)
    t.set_color("font_color", "Button", YAZI)
    t.set_color("font_hover_color", "Button", Color(1, 1, 1))
    t.set_color("font_pressed_color", "Button", KOR)
    t.set_font("font", "Button", YAZI_TIPI)
    t.set_font_size("font_size", "Button", 8)
    t.set_constant("h_separation", "Button", BOSLUK_M)

    t.set_color("font_color", "Label", YAZI)
    t.set_font("font", "Label", YAZI_TIPI)
    t.set_font_size("font_size", "Label", 8)
    return t

## Başlık/gövde/sönük — üç yazı seviyesi. Başka boyut kullanma.
static func baslik(metin: String) -> Label:
    return _yazi(metin, 16, YAZI)

static func govde(metin: String) -> Label:
    return _yazi(metin, 8, YAZI)

static func sonuk(metin: String) -> Label:
    return _yazi(metin, 8, YAZI_SONUK)

static func vurgu(metin: String) -> Label:
    return _yazi(metin, 8, KOR)

static func _yazi(metin: String, boy: int, renk: Color) -> Label:
    var l := Label.new()
    l.add_theme_font_override("font", YAZI_TIPI)
    l.add_theme_font_size_override("font_size", boy)
    l.add_theme_color_override("font_color", renk)
    l.text = metin
    return l

## Çerçeveli ölçüm çubuğu (ısı göstergesi). Dolgu rengini çağıran veriyor.
## Döndürdüğü sözlük: {"kok": Control, "dolgu": ColorRect, "isaret": ColorRect}
static func cubuk(genislik: int, yukseklik: int, esik_orani: float) -> Dictionary:
    var kok := Control.new()
    kok.custom_minimum_size = Vector2(genislik, yukseklik)

    var cerceve := ColorRect.new()
    cerceve.color = KENAR
    cerceve.size = Vector2(genislik + 2, yukseklik + 2)
    cerceve.position = Vector2(-1, -1)
    kok.add_child(cerceve)

    var arka := ColorRect.new()
    arka.color = Color(0.04, 0.04, 0.06)
    arka.size = Vector2(genislik, yukseklik)
    kok.add_child(arka)

    var dolgu := ColorRect.new()
    dolgu.size = Vector2(0, yukseklik)
    kok.add_child(dolgu)

    # Kor atışı eşiği: çubuğun üstünde küçük bir çentik
    var isaret := ColorRect.new()
    isaret.color = KOR
    isaret.size = Vector2(1, yukseklik + 4)
    isaret.position = Vector2(genislik * esik_orani, -2)
    kok.add_child(isaret)

    return {"kok": kok, "dolgu": dolgu, "isaret": isaret}
