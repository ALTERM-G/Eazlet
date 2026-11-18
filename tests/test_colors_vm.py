import pytest

from eazlet.backend.viewmodels import colors_vm
from eazlet.backend.viewmodels.colors_vm import ColorsVM


@pytest.fixture
def vm():
    return ColorsVM()


def test_screen_pick_updates_color_and_clears_flag(vm, monkeypatch, qtbot):
    monkeypatch.setattr(colors_vm, "pick_screen_color", lambda: "#123456")

    vm.pickScreenColor()
    assert vm.picking is True

    qtbot.waitUntil(lambda: vm.hex == "#123456", timeout=3000)
    assert vm.picking is False
    assert vm.inputError == ""


def test_screen_pick_failure_is_reported(vm, monkeypatch, qtbot):
    monkeypatch.setattr(colors_vm, "pick_screen_color", lambda: None)

    vm.pickScreenColor()
    qtbot.waitUntil(lambda: vm.picking is False, timeout=3000)

    assert "cancelled or unavailable" in vm.inputError


def test_initial_color(vm):
    assert vm.hex == "#4A90E2"
    assert (vm.red, vm.green, vm.blue) == (74, 144, 226)
    assert vm.rgbText == "rgb(74, 144, 226)"
    assert vm.hslText.startswith("hsl(")
    assert vm.hsvText.startswith("hsv(")
    assert vm.cmykText.startswith("cmyk(")


@pytest.mark.parametrize(
    "text,expected",
    [
        ("#FF0000", "#FF0000"),
        ("ff0000", "#FF0000"),
        ("#f00", "#FF0000"),
        ("0x00FF00", "#00FF00"),
        ("rgb(0, 0, 255)", "#0000FF"),
        ("rgba(0, 128, 255, 0.5)", "#0080FF"),
        ("hsl(120, 100%, 50%)", "#00FF00"),
        ("hsv(240, 100%, 100%)", "#0000FF"),
        ("cmyk(0%, 100%, 100%, 0%)", "#FF0000"),
    ],
)
def test_set_color_parses_supported_formats(vm, text, expected):
    assert vm.setColor(text) is True
    assert vm.hex == expected
    assert vm.inputError == ""


def test_invalid_color_reports_error_then_clears(vm):
    assert vm.setColor("not a color") is False
    assert vm.inputError != ""

    assert vm.setColor("#123456") is True
    assert vm.inputError == ""


def test_rgb_setters_clamp_and_round(vm):
    vm.setRgb(300, -20, 127.6)

    assert (vm.red, vm.green, vm.blue) == (255, 0, 128)


def test_hsv_setters_keep_hue_at_zero_value(vm):
    vm.setHsv(200.0, 80.0, 0.0)

    assert vm.red == vm.green == vm.blue == 0
    assert vm.hue == pytest.approx(200.0)
    assert vm.saturation == pytest.approx(80.0)
    assert vm.value == pytest.approx(0.0)


def test_hsv_setter_wraps_hue(vm):
    vm.setHsv(400.0, 100.0, 100.0)

    assert vm.hue == pytest.approx(40.0)


def test_individual_channel_setters(vm):
    vm.red = 10
    vm.green = 20
    vm.blue = 30

    assert vm.hex == "#0A141E"


def test_conversions_lists_every_format(vm):
    labels = [entry["label"] for entry in vm.conversions]
    values = {entry["label"]: entry["value"] for entry in vm.conversions}

    assert labels == ["HEX", "RGB", "HSL", "HSV", "CMYK"]
    assert values["HEX"] == vm.hex
    assert values["RGB"] == vm.rgbText


def test_color_name_and_lightness(vm):
    vm.setColor("#FF0000")
    assert vm.colorName == "Red"
    assert vm.isLight is False

    vm.setColor("#FFFFFF")
    assert vm.colorName == "White"
    assert vm.isLight is True


def test_harmony_types_are_stable(vm):
    assert vm.harmonyTypes[0] == "Complementary"
    assert "Monochromatic" in vm.harmonyTypes

    vm.harmonyType = "Not a harmony"
    assert vm.harmonyType == "Complementary"


def test_harmony_count_defaults_to_five_and_clamps(vm):
    assert vm.maxHarmonyCount == 5
    assert vm.harmonyCount == 5
    assert len(vm.harmony) == 5

    vm.harmonyCount = 1
    assert vm.harmonyCount == 2
    assert len(vm.harmony) == 2

    vm.harmonyCount = 99
    assert vm.harmonyCount == 5


def test_complementary_harmony(vm):
    vm.setColor("#FF0000")
    vm.harmonyCount = 2

    harmony = vm.harmony
    assert len(harmony) == 2
    assert harmony[0]["hex"] == "#FF0000"
    assert harmony[1]["hex"] == "#00FFFF"


def test_short_harmony_patterns_are_filled_with_tones(vm):
    vm.setColor("#FF0000")
    vm.harmonyCount = 5

    harmony = vm.harmony
    assert len(harmony) == 5
    assert [entry["label"] for entry in harmony] == [
        "Base",
        "Complement",
        "Base tint",
        "Complement tint",
        "Base shade",
    ]
    assert harmony[0]["hex"] == "#FF0000"
    assert harmony[1]["hex"] == "#00FFFF"
    assert harmony[0]["hex"] != harmony[2]["hex"]


def test_triadic_and_square_harmonies(vm):
    vm.setColor("#FF0000")

    vm.harmonyType = "Triadic"
    vm.harmonyCount = 3
    assert [entry["hex"] for entry in vm.harmony] == [
        "#FF0000",
        "#00FF00",
        "#0000FF",
    ]

    vm.harmonyType = "Square"
    vm.harmonyCount = 4
    assert len(vm.harmony) == 4
    assert vm.harmony[0]["hex"] == "#FF0000"

    vm.harmonyCount = 5
    assert len(vm.harmony) == 5
    assert vm.harmony[-1]["label"] == "Base tint"


def test_harmony_count_can_trim_patterns(vm):
    vm.setColor("#FF0000")
    vm.harmonyType = "Triadic"
    vm.harmonyCount = 2

    assert [entry["label"] for entry in vm.harmony] == ["Base", "+240°"]


def test_monochromatic_harmony_steps_lightness(vm):
    vm.setColor("#FF0000")
    vm.harmonyType = "Monochromatic"

    harmony = vm.harmony
    assert [entry["label"] for entry in harmony] == [
        "Dark",
        "Shade",
        "Base",
        "Tint",
        "Light",
    ]
    assert harmony[2]["hex"] == "#FF0000"
    assert harmony[0]["hex"] != harmony[4]["hex"]


def test_random_color_stays_in_range(vm):
    for _ in range(20):
        vm.randomColor()
        assert 0 <= vm.red <= 255
        assert 0 <= vm.green <= 255
        assert 0 <= vm.blue <= 255
        assert len(vm.hex) == 7
        assert vm.hex.startswith("#")
