import pytest

from eazlet.backend.controller import DEFAULT_THEME, Controller
from eazlet.backend.viewmodels.ascii_art_vm import AsciiArtVM


@pytest.fixture
def isolated_controller(tmp_path):
    controller = Controller()
    controller._settings_path = tmp_path / "Settings.json"
    controller._theme_path = tmp_path / "CurrentTheme.json"
    controller._theme_last_modified = 0
    controller._theme_cache = DEFAULT_THEME
    return controller


def test_all_figlet_fonts_are_available():
    vm = AsciiArtVM()
    assert len(vm.fonts) >= 500
    assert vm.fonts == sorted(vm.fonts)
    assert "standard" in vm.fonts
    assert vm.font in vm.fonts


def test_preview_is_rendered_and_cached():
    vm = AsciiArtVM()
    rendered = vm.preview("standard", "Hi")
    assert rendered
    assert len(vm._preview_cache) == 1

    assert vm.preview("standard", "Hi") == rendered
    assert len(vm._preview_cache) == 1


def test_preview_uses_font_name_for_empty_text_and_rejects_unknown_fonts():
    vm = AsciiArtVM()
    assert vm.preview("standard", "") != ""
    assert vm.preview("standard", "   \n  ") != ""
    assert vm.preview("__not_a_font__", "Hello") == ""


def test_preview_collapses_and_truncates_sample_text():
    vm = AsciiArtVM()
    vm.preview("standard", "one    two\nthree " * 20)
    assert len(vm._preview_cache) == 1
    key = next(iter(vm._preview_cache))
    assert key[1].startswith("one two three")
    assert len(key[1]) <= vm.PREVIEW_TEXT_LENGTH


def test_preview_cache_is_bounded():
    vm = AsciiArtVM()
    for index in range(vm.MAX_PREVIEWS + 5):
        vm.preview("standard", f"sample {index}")
    assert len(vm._preview_cache) == vm.MAX_PREVIEWS


def test_favorites_toggle_and_persist(isolated_controller):
    vm = AsciiArtVM(isolated_controller)
    vm.toggleFavorite("banner")
    vm.toggleFavorite("big")
    assert vm.favorites == ["big", "banner"]
    assert isolated_controller.get_ascii_favorites() == ["big", "banner"]

    vm.toggleFavorite("banner")
    assert vm.favorites == ["big"]
    assert isolated_controller.get_ascii_favorites() == ["big"]

    vm.toggleFavorite("__not_a_font__")
    assert vm.favorites == ["big"]

    reloaded = AsciiArtVM(isolated_controller)
    assert reloaded.favorites == ["big"]
    assert reloaded.isFavorite("big") is True
    assert reloaded.isFavorite("banner") is False


def test_recents_are_unique_and_persist(isolated_controller):
    vm = AsciiArtVM(isolated_controller)
    vm.setFont("banner")
    vm.setFont("standard")
    vm.setFont("banner")
    assert vm.recents == ["banner", "standard"]
    assert isolated_controller.get_ascii_recents() == ["banner", "standard"]

    reloaded = AsciiArtVM(isolated_controller)
    assert reloaded.recents == ["banner", "standard"]


def test_recents_are_bounded(isolated_controller):
    vm = AsciiArtVM(isolated_controller)
    for font in vm.fonts[: vm.MAX_RECENTS + 8]:
        vm.setFont(font)
    assert len(vm.recents) == vm.MAX_RECENTS
    assert vm.recents[0] == vm.fonts[vm.MAX_RECENTS + 7]
    assert isolated_controller.get_ascii_recents() == vm.recents


def test_preview_does_not_change_current_font_or_output(isolated_controller):
    vm = AsciiArtVM(isolated_controller)
    vm.setInput("Hi")
    vm.process()
    font_before = vm.font
    output_before = vm.output

    vm.preview("banner", "Preview")

    assert vm.font == font_before
    assert vm.output == output_before
    assert vm.recents == []


def test_applying_font_updates_output(isolated_controller):
    vm = AsciiArtVM(isolated_controller)
    vm.setInput("Hi")
    vm.setFont("banner")
    assert vm.output
    assert vm.font == "banner"
    assert vm.recents[0] == "banner"
