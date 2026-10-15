extends RefCounted
## Accessibility rules for the two things Kor shows through light: how far you
## see, and the warnings that flash. Pure functions, so tests/test_erisim.gd can
## check them without a scene.
##
## SIGHT FLOOR. Cold sight is 40 px on a 640x360 screen: the core rule, and the
## hardest thing in the game for a player with low vision. The floor option
## widens only the COLD end (40 -> 72 -> 104 px). Heat still opens the arena
## up to the same 300 px ceiling, diving still darkens the screen, and the
## locked state is still the widest. The trade between heat and sight stays;
## it starts from a radius the player can actually read. Off by default.
##
## CALM LIGHTS. Two warnings blink:
##   - invulnerability after a hit: 85 ms half period = 5.9 Hz,
##   - the heat bar above 85%: 70 ms half period = 7.1 Hz.
## Both are above the 3 flashes per second that WCAG 2.3.1 uses as the
## general flash threshold (the areas are small, so they likely pass the area
## exemption, but players with photosensitivity cannot know that). Calm mode
## replaces each blink with a steady colour of the same meaning. No
## information is lost: the heat bar keeps its fill and threshold line, and
## the player sprite keeps its distinct invulnerability tint.

const GORUS_TABANI_EK := [0.0, 32.0, 64.0]
const GORUS_TABANI_AD := ["görüş tabanı normal", "görüş tabanı +32", "görüş tabanı +64"]

const DOKUNULMAZ_YARI_MS := 85
const ISI_UYARI_YARI_MS := 70
const WCAG_FLAS_SINIRI_HZ := 3.0

const DOKUNULMAZ_RENK := Color(2.4, 1.2, 1.2)
const DOKUNULMAZ_SAKIN := Color(1.9, 1.15, 1.15)
const ISI_UYARI_A := Color(1, 1, 1)
const ISI_UYARI_B := Color(1.0, 0.25, 0.05)
const ISI_UYARI_SAKIN := Color(1.0, 0.45, 0.2)

## Extra cold-sight radius (px) for setting step `kademe`; out-of-range steps clamp.
static func gorus_tabani_ek(kademe: int) -> float:
    return float(GORUS_TABANI_EK[clampi(kademe, 0, GORUS_TABANI_EK.size() - 1)])

static func gorus_tabani_ad(kademe: int) -> String:
    return str(GORUS_TABANI_AD[clampi(kademe, 0, GORUS_TABANI_AD.size() - 1)])

## Next step of the floor setting (wraps around).
static func gorus_tabani_sonraki(kademe: int) -> int:
    return (clampi(kademe, 0, GORUS_TABANI_EK.size() - 1) + 1) % GORUS_TABANI_EK.size()

## Full cycles per second of a blink with half period `yari_ms`.
static func flas_hz(yari_ms: int) -> float:
    return 1000.0 / (2.0 * float(yari_ms))

## Player tint while invulnerable at time `ms`. Calm: steady.
static func dokunulmaz_rengi(ms: int, sakin: bool) -> Color:
    if sakin:
        return DOKUNULMAZ_SAKIN
    return DOKUNULMAZ_RENK if int(ms / DOKUNULMAZ_YARI_MS) % 2 == 0 else Color(1, 1, 1)

## Heat bar colour above the warning threshold at time `ms`. Calm: steady.
static func isi_uyari_rengi(ms: int, sakin: bool) -> Color:
    if sakin:
        return ISI_UYARI_SAKIN
    return ISI_UYARI_A if int(ms / ISI_UYARI_YARI_MS) % 2 == 0 else ISI_UYARI_B
