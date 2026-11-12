import json
from pathlib import Path

import pytest

from eazlet.backend.controller import DEFAULT_THEME, Controller


@pytest.fixture
def isolated_controller(tmp_path):
    controller = Controller()
    controller._settings_path = tmp_path / "Settings.json"
    controller._theme_path = tmp_path / "CurrentTheme.json"
    controller._theme_last_modified = 0
    controller._theme_cache = DEFAULT_THEME
    return controller


def test_defaults_without_settings(isolated_controller):
    controller = isolated_controller
    assert controller.get_scale_factor() == 1.0
    assert controller.get_corner_radius() == 1.0
    assert controller.get_animations_enabled() is True
    assert controller.get_is_continuous() is True
    assert controller.get_font_family() == "JetBrains Mono"
    assert controller.get_language() == 0
    assert controller.get_shortcuts() == {}


def test_settings_round_trip(isolated_controller):
    controller = isolated_controller
    controller.save_scale_factor(2.5)
    controller.save_corner_radius(0.75)
    controller.save_animations_enabled(False)
    controller.save_is_continuous(False)
    controller.save_font_family("Fira Code")

    assert controller.get_scale_factor() == 2.5
    assert controller.get_corner_radius() == 0.75
    assert controller.get_animations_enabled() is False
    assert controller.get_is_continuous() is False
    assert controller.get_font_family() == "Fira Code"

    data = json.loads(controller._settings_path.read_text())
    assert data["scaleFactor"] == 2.5
    assert data["cornerRadius"] == 0.75
    assert data["animationsEnabled"] is False
    assert data["isContinuous"] is False
    assert data["fontFamily"] == "Fira Code"


def test_theme_defaults(isolated_controller):
    controller = isolated_controller
    assert DEFAULT_THEME == "Alterm"
    assert controller.get_current_theme() == DEFAULT_THEME

    controller.save_theme("Alterm")
    assert controller.get_current_theme() == "Alterm"
    assert json.loads(controller._theme_path.read_text())["currentTheme"] == "Alterm"


def test_all_known_themes_registered():
    controller = Controller()
    colors = controller.get_theme_colors()
    for theme in ['Alterm', 'Carbon Amber', 'Catppuccin Mocha', 'Dracula', 'Everforest', 'Github Dark', 'Gruvbox', 'Monokai', 'Vanilla Light']:
        assert theme in colors, f"missing theme {theme}"


def test_get_languages_returns_endonyms(isolated_controller):
    controller = isolated_controller
    assert controller.get_languages() == [
        "English",
        "Français",
        "Deutsch",
        "Español",
        "Italiano",
    ]


def test_language_round_trip(isolated_controller):
    controller = isolated_controller
    controller.save_language(3)
    assert controller.get_language() == 3
    assert controller.get_language_data()["language"] == "Español"


def test_out_of_range_language_clamped(isolated_controller):
    controller = isolated_controller
    controller.save_language(99)
    assert controller.get_language() == 0


def test_ascii_font_lists_round_trip(isolated_controller):
    controller = isolated_controller
    assert controller.get_ascii_favorites() == []
    assert controller.get_ascii_recents() == []

    controller.save_ascii_favorites(["banner", "big"])
    controller.save_ascii_recents(["standard", "banner"])
    assert controller.get_ascii_favorites() == ["banner", "big"]
    assert controller.get_ascii_recents() == ["standard", "banner"]

    data = json.loads(controller._settings_path.read_text())
    assert data["asciiArtFavorites"] == ["banner", "big"]
    assert data["asciiArtRecents"] == ["standard", "banner"]


def test_ascii_font_lists_ignore_invalid_values(isolated_controller):
    controller = isolated_controller
    controller._settings_path.write_text(
        json.dumps(
            {
                "asciiArtFavorites": ["banner", 4, None, "big"],
                "asciiArtRecents": "not a list",
            }
        )
    )
    assert controller.get_ascii_favorites() == ["banner", "big"]
    assert controller.get_ascii_recents() == []


def test_workspace_default_dirs(isolated_controller):
    controller = isolated_controller
    assert controller.get_downloader_dir() == str(Path.home() / "Downloads")
    assert controller.get_converter_dir() == str(Path.home() / "Documents")
    assert controller.get_archive_dir() == str(Path.home() / "Documents")


def test_downloader_dir_round_trip_and_propagation(isolated_controller, tmp_path):
    controller = isolated_controller
    target = str(tmp_path / "DownloadsTarget")
    controller.save_downloader_dir(f"file://{target}")

    assert controller.get_downloader_dir() == target
    assert controller.downloadVM.destination == target
    assert controller.unifiedDownloadVM.destination == target
    assert controller.converterVM.outputDir == controller.get_converter_default_dir()
    assert controller.archiveVM.outputDir == controller.get_archive_default_dir()
    assert json.loads(controller._settings_path.read_text())["downloaderDir"] == target


def test_converter_dir_round_trip(isolated_controller, tmp_path):
    controller = isolated_controller
    target = str(tmp_path / "ConverterTarget")
    controller.save_converter_dir(target)

    assert controller.get_converter_dir() == target
    assert controller.converterVM.outputDir == target
    assert controller.unifiedDownloadVM.destination == controller.get_downloader_default_dir()
    assert json.loads(controller._settings_path.read_text())["converterOutputDir"] == target


def test_archive_dir_round_trip(isolated_controller, tmp_path):
    controller = isolated_controller
    target = str(tmp_path / "ArchiveTarget")
    controller.save_archive_dir(target)

    assert controller.get_archive_dir() == target
    assert controller.archiveVM.outputDir == target
    assert controller.converterVM.outputDir == controller.get_converter_default_dir()
    assert json.loads(controller._settings_path.read_text())["archiveOutputDir"] == target


def test_apply_saved_settings_loads_workspace_dirs(isolated_controller, tmp_path):
    controller = isolated_controller
    downloader = str(tmp_path / "SavedDownloads")
    converter = str(tmp_path / "SavedConverter")
    archive = str(tmp_path / "SavedArchive")
    controller._settings_path.write_text(
        json.dumps(
            {
                "downloaderDir": downloader,
                "converterOutputDir": converter,
                "archiveOutputDir": archive,
            }
        )
    )

    controller.apply_saved_settings()

    assert controller.unifiedDownloadVM.destination == downloader
    assert controller.converterVM.outputDir == converter
    assert controller.archiveVM.outputDir == archive


def test_downloader_dir_falls_back_to_legacy_setting(
    isolated_controller, tmp_path
):
    controller = isolated_controller
    legacy = str(tmp_path / "LegacyDownloads")
    controller._settings_path.write_text(json.dumps({"downloadDir": legacy}))

    assert controller.get_downloader_dir() == legacy
    assert controller.get_converter_dir() == controller.get_converter_default_dir()


def test_empty_workspace_dirs_use_defaults(isolated_controller):
    controller = isolated_controller
    controller.save_downloader_dir("")
    controller.save_converter_dir("")
    controller.save_archive_dir("")

    assert controller.get_downloader_dir() == controller.get_downloader_default_dir()
    assert controller.get_converter_dir() == controller.get_converter_default_dir()
    assert controller.get_archive_dir() == controller.get_archive_default_dir()


