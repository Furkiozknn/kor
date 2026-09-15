extends SceneTree
## Girdi haritasini KODDAN kurar ve project.godot'a yazar.
##
## Neden elle yazmiyoruz: project.godot'taki girdi girdileri
## `Object(InputEventKey,"resource_local_to_scene":false,...)` seklinde
## serilestirilmis uzun satirlar. Elle yazmak kacis/BOM tuzaklarina acik.
## Bu betik InputMap uzerinden kurup ProjectSettings.save() ile yazdiriyor.
##
##   godot --headless --script res://tests/girdi_haritasi_kur.gd

func _tus(kod: Key) -> InputEventKey:
    var e := InputEventKey.new()
    e.physical_keycode = kod
    return e

func _fare(dugme: MouseButton) -> InputEventMouseButton:
    var e := InputEventMouseButton.new()
    e.button_index = dugme
    return e

func _pad(dugme: JoyButton) -> InputEventJoypadButton:
    var e := InputEventJoypadButton.new()
    e.button_index = dugme
    return e

func _eksen(eksen: JoyAxis, yon: float) -> InputEventJoypadMotion:
    var e := InputEventJoypadMotion.new()
    e.axis = eksen
    e.axis_value = yon
    return e

func _init() -> void:
    # eylem -> olaylar. Klavye/fare KORUNUYOR, gamepad EKLENIYOR.
    var harita := {
        "ates":      [_fare(MOUSE_BUTTON_LEFT),  _pad(JOY_BUTTON_RIGHT_SHOULDER), _eksen(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
        "kor":       [_fare(MOUSE_BUTTON_RIGHT), _pad(JOY_BUTTON_LEFT_SHOULDER),  _eksen(JOY_AXIS_TRIGGER_LEFT, 1.0)],
        "dalis":     [_tus(KEY_SPACE),           _pad(JOY_BUTTON_A)],
        "dokum":     [_tus(KEY_E), _tus(KEY_R),  _pad(JOY_BUTTON_Y)],
        "silah_gec": [_tus(KEY_Q), _tus(KEY_TAB),_pad(JOY_BUTTON_X)],
        "duraklat":  [_tus(KEY_ESCAPE),          _pad(JOY_BUTTON_START)],
        # Gamepad nisani: sag cubuk. Fare nisani kodda korunuyor;
        # sag cubuk hareket ederse o kazaniyor.
        "nisan_sol":    [_eksen(JOY_AXIS_RIGHT_X, -1.0)],
        "nisan_sag":    [_eksen(JOY_AXIS_RIGHT_X,  1.0)],
        "nisan_yukari": [_eksen(JOY_AXIS_RIGHT_Y, -1.0)],
        "nisan_asagi":  [_eksen(JOY_AXIS_RIGHT_Y,  1.0)],
    }
    # Mevcut hareket eylemlerine de gamepad sol cubugu ekle
    var hareket := {
        "move_left":  _eksen(JOY_AXIS_LEFT_X, -1.0),
        "move_right": _eksen(JOY_AXIS_LEFT_X,  1.0),
        "move_up":    _eksen(JOY_AXIS_LEFT_Y, -1.0),
        "move_down":  _eksen(JOY_AXIS_LEFT_Y,  1.0),
    }

    var eklenen := 0
    for ad in harita.keys():
        var yol := "input/" + str(ad)
        var olaylar: Array = harita[ad]
        ProjectSettings.set_setting(yol, {"deadzone": 0.25, "events": olaylar})
        eklenen += 1
    for ad in hareket.keys():
        var yol := "input/" + str(ad)
        var mevcut = ProjectSettings.get_setting(yol)
        if mevcut == null:
            print("ATLANDI (eylem yok): ", ad)
            continue
        var olaylar: Array = mevcut["events"]
        var var_mi := false
        for o in olaylar:
            if o is InputEventJoypadMotion:
                var_mi = true
        if not var_mi:
            olaylar.append(hareket[ad])
            ProjectSettings.set_setting(yol, {"deadzone": 0.25, "events": olaylar})
            eklenen += 1

    var kod := ProjectSettings.save()
    print("TAMAM girdi haritasi: %d eylem yazildi, save=%d" % [eklenen, kod])
    quit(0 if kod == OK else 1)
