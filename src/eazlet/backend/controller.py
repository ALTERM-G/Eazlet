import json
import logging
from datetime import datetime, timezone
from pathlib import Path

from PySide6.QtCore import Property, QIODevice, QObject, QSaveFile, QUrl, Signal, Slot

from .viewmodels import (
    ArchiveVM,
    AsciiArtVM,
    CipherVM,
    ColorsVM,
    ConverterVM,
    DictionaryVM,
    GeneratorsVM,
    MainVM,
    MathVM,
    NumberToolsVM,
    OrganizerVM,
    ReplVM,
    SettingsVM,
    TextAnalysisVM,
    TextToolsVM,
    TierListVM,
    UnifiedDownloadVM,
)

logger = logging.getLogger(__name__)

DEFAULT_THEME = "Alterm"


class Controller(QObject):
    languageChanged = Signal()
    storageError = Signal(str)
    historyChanged = Signal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._theme_path = (
            Path(__file__).parent.parent / "resources" / "runtime" / "CurrentTheme.json"
        )
        self._settings_path = (
            Path(__file__).parent.parent / "resources" / "runtime" / "Settings.json"
        )
        self._themes_path = (
            Path(__file__).parent.parent / "resources" / "style" / "themes"
        )
        self._theme_last_modified = 0
        self._theme_cache = DEFAULT_THEME

        self._main_vm = MainVM(self)
        self._settings_vm = SettingsVM(self)
        self._unified_download_vm = UnifiedDownloadVM(self)
        self._converter_vm = ConverterVM(self)
        self._archive_vm = ArchiveVM(self)
        self._organizer_vm = OrganizerVM(self)
        self._cipher_vm = CipherVM(self)
        self._colors_vm = ColorsVM(self)
        self._tier_list_vm = TierListVM(self)
        self._text_analysis_vm = TextAnalysisVM(self)
        self._text_tools_vm = TextToolsVM(self)
        self._ascii_art_vm = AsciiArtVM(self)
        self._number_tools_vm = NumberToolsVM(self)
        self._math_vm = MathVM(self)
        self._generators_vm = GeneratorsVM(self)
        self._dictionary_vm = DictionaryVM(self)
        self._repl_vm = ReplVM(self)

        self._language_files = ["en.json", "fr.json", "de.json", "es.json", "it.json"]
        self._languages_path = (
            Path(__file__).parent.parent / "resources" / "assets" / "languages"
        )
        self._english_language_data: dict | None = None
        self._language_data_cache: dict = {}

        self._load_all_themes()
        self._current_language = self.get_language()
        self._refresh_language_data()

    def _read_json(self, path: Path, context: str) -> dict | None:
        if not path.exists():
            return None
        try:
            with open(path) as f:
                data = json.load(f)
        except (OSError, ValueError) as e:
            logger.warning("Could not read %s at %s: %s", context, path, e)
            return None
        if not isinstance(data, dict):
            logger.warning("Ignoring %s at %s: expected a JSON object", context, path)
            return None
        return data

    def _write_json(self, path: Path, data: dict, context: str) -> bool:
        try:
            payload = json.dumps(data, indent=2).encode("utf-8")
        except (TypeError, ValueError) as e:
            logger.error("Could not serialise %s: %s", context, e)
            self.storageError.emit(f"Could not save {context}: {e}")
            return False
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            out = QSaveFile(str(path))
            if not out.open(QIODevice.WriteOnly):
                raise OSError(out.errorString())
            if out.write(payload) == -1:
                raise OSError(out.errorString())
            if not out.commit():
                raise OSError(out.errorString())
        except OSError as e:
            logger.error("Could not write %s at %s: %s", context, path, e)
            self.storageError.emit(f"Could not save {context}: {e}")
            return False
        return True

    def _load_all_themes(self) -> None:
        self._base_config: dict = {}
        self._theme_colors: dict = {}

        base = self._read_json(self._themes_path / "base.json", "theme base")
        if base is not None:
            self._base_config = base

        for theme_path in sorted(self._themes_path.glob("*.json")):
            if theme_path.stem == "base":
                continue
            data = self._read_json(theme_path, f"theme '{theme_path.stem}'")
            if data is not None and "colors" in data:
                self._theme_colors[theme_path.stem] = data["colors"]

    def _load_theme(self) -> str:
        try:
            if self._theme_path.exists():
                current_mtime = self._theme_path.stat().st_mtime
                if current_mtime > self._theme_last_modified:
                    data = self._read_json(self._theme_path, "current theme")
                    if data is not None:
                        self._theme_cache = data.get("currentTheme", DEFAULT_THEME)
                    self._theme_last_modified = current_mtime
        except OSError as e:
            logger.warning("Could not stat current theme at %s: %s", self._theme_path, e)
        return self._theme_cache

    @Slot(str)
    def save_theme(self, theme_name: str) -> None:
        self._theme_cache = theme_name
        if self._write_json(
            self._theme_path, {"currentTheme": theme_name}, "current theme"
        ):
            try:
                self._theme_last_modified = self._theme_path.stat().st_mtime
            except OSError as e:
                logger.warning(
                    "Could not stat current theme at %s: %s", self._theme_path, e
                )

    @Slot(result=str)
    def get_current_theme(self) -> str:
        return self._load_theme()

    @Slot(result=dict)
    def get_base_config(self) -> dict:
        return self._base_config

    @Slot(result=dict)
    def get_theme_colors(self) -> dict:
        return self._theme_colors

    def _load_settings(self) -> dict:
        data = self._read_json(self._settings_path, "settings")
        return data if data is not None else {}

    def _save_settings(self, settings: dict) -> None:
        self._write_json(self._settings_path, settings, "settings")

    def _update_settings(self, **updates: object) -> dict:
        settings = self._load_settings()
        settings.update(updates)
        self._save_settings(settings)
        return settings

    @Slot(float)
    def save_scale_factor(self, factor: float) -> None:
        self._update_settings(scaleFactor=factor)

    @Slot(result=float)
    def get_scale_factor(self) -> float:
        return self._load_settings().get("scaleFactor", 1.0)

    @Slot(float)
    def save_corner_radius(self, factor: float) -> None:
        self._update_settings(cornerRadius=factor)

    @Slot(result=float)
    def get_corner_radius(self) -> float:
        return self._load_settings().get("cornerRadius", 1.0)

    @Slot(bool)
    def save_animations_enabled(self, value: bool) -> None:
        self._update_settings(animationsEnabled=bool(value))

    @Slot(result=bool)
    def get_animations_enabled(self) -> bool:
        return self._load_settings().get("animationsEnabled", True)

    @Slot(bool)
    def save_is_continuous(self, value: bool) -> None:
        self._update_settings(isContinuous=value)

    @Slot(result=bool)
    def get_is_continuous(self) -> bool:
        return self._load_settings().get("isContinuous", True)

    @Slot(str)
    def save_font_family(self, family: str) -> None:
        self._update_settings(fontFamily=family)

    @Slot(result=str)
    def get_font_family(self) -> str:
        return self._load_settings().get("fontFamily", "JetBrains Mono")

    @Slot(int)
    def save_language(self, index: int) -> None:
        self._update_settings(language=index)
        self._current_language = index
        self._refresh_language_data()
        self.languageChanged.emit()

    @Slot(result=int)
    def get_language(self) -> int:
        idx = self._load_settings().get("language", 0)
        if 0 <= idx < len(self._language_files):
            return idx
        return 0

    @Slot(result=list)
    def get_languages(self) -> list[str]:
        names: list[str] = []
        for filename in self._language_files:
            data = self._read_json(
                self._languages_path / filename, f"language '{filename}'"
            )
            names.append(data.get("language", filename) if data else filename)
        return names

    def _refresh_language_data(self) -> None:
        idx = self.get_language()
        data = None
        if 0 <= idx < len(self._language_files):
            data = self._read_json(
                self._languages_path / self._language_files[idx], "language data"
            )
        self._language_data_cache = data if data is not None else {}

    @Slot(result=dict)
    def get_language_data(self) -> dict:
        if not self._language_data_cache:
            self._refresh_language_data()
        return self._language_data_cache

    def _english_data(self) -> dict:
        if self._english_language_data is None:
            data = self._read_json(self._languages_path / "en.json", "english language")
            self._english_language_data = data if data is not None else {}
        return self._english_language_data

    @staticmethod
    def _lookup_language_value(data: dict, key: str):
        cur = data
        for part in key.split("."):
            if isinstance(cur, dict) and part in cur:
                cur = cur[part]
            else:
                return None
        return cur

    @Slot(str, result=str)
    def translate(self, key: str, default: str = "") -> str:
        value = self._lookup_language_value(self.get_language_data(), key)
        if not isinstance(value, str):
            value = self._lookup_language_value(self._english_data(), key)
        if not isinstance(value, str):
            return default if default else key
        return value

    @Slot(result=dict)
    def get_shortcuts(self) -> dict:
        data = self._load_settings().get("shortcuts", {})
        return data if isinstance(data, dict) else {}

    @Slot(dict)
    def save_shortcuts(self, shortcuts: dict) -> None:
        self._update_settings(shortcuts=dict(shortcuts))

    def _load_string_list(self, key: str) -> list[str]:
        data = self._load_settings().get(key, [])
        if not isinstance(data, list):
            return []
        return [item for item in data if isinstance(item, str)]

    @Slot(result=list)
    def get_ascii_favorites(self) -> list[str]:
        return self._load_string_list("asciiArtFavorites")

    @Slot(list)
    def save_ascii_favorites(self, fonts: list[str]) -> None:
        self._update_settings(
            asciiArtFavorites=[font for font in fonts if isinstance(font, str)]
        )

    @Slot(result=list)
    def get_ascii_recents(self) -> list[str]:
        return self._load_string_list("asciiArtRecents")

    @Slot(list)
    def save_ascii_recents(self, fonts: list[str]) -> None:
        self._update_settings(
            asciiArtRecents=[font for font in fonts if isinstance(font, str)]
        )

    def _default_downloads_dir(self) -> str:
        return str(Path.home() / "Downloads")

    def _default_documents_dir(self) -> str:
        return str(Path.home() / "Documents")

    def _normalise_dir(self, value: object, default: str) -> str:
        path = str(value or "").strip()
        if path.startswith("file://"):
            path = path[len("file://") :]
        if not path:
            return default
        return str(Path(path).expanduser())

    def _workspace_dir(
        self, key: str, default: str, legacy_key: str | None = None
    ) -> str:
        settings = self._load_settings()
        value = settings.get(key)
        if value is None and legacy_key is not None:
            value = settings.get(legacy_key)
        return self._normalise_dir(value, default)

    @Slot()
    def apply_saved_settings(self) -> None:
        self._unified_download_vm.destination = self.get_downloader_dir()
        self._converter_vm.outputDir = self.get_converter_dir()
        self._archive_vm.outputDir = self.get_archive_dir()

    @Slot(result=str)
    def get_downloader_default_dir(self) -> str:
        return self._default_downloads_dir()

    @Slot(result=str)
    def get_downloader_dir(self) -> str:
        return self._workspace_dir(
            "downloaderDir", self._default_downloads_dir(), legacy_key="downloadDir"
        )

    @Slot(str)
    def save_downloader_dir(self, path: str) -> None:
        directory = self._normalise_dir(path, self._default_downloads_dir())
        self._update_settings(downloaderDir=directory)
        self._unified_download_vm.destination = directory

    @Slot(result=str)
    def get_converter_default_dir(self) -> str:
        return self._default_documents_dir()

    @Slot(result=str)
    def get_converter_dir(self) -> str:
        return self._workspace_dir(
            "converterOutputDir", self._default_documents_dir()
        )

    @Slot(str)
    def save_converter_dir(self, path: str) -> None:
        directory = self._normalise_dir(path, self._default_documents_dir())
        self._update_settings(converterOutputDir=directory)
        self._converter_vm.outputDir = directory

    @Slot(result=str)
    def get_archive_default_dir(self) -> str:
        return self._default_documents_dir()

    @Slot(result=str)
    def get_archive_dir(self) -> str:
        return self._workspace_dir("archiveOutputDir", self._default_documents_dir())

    @Slot(str)
    def save_archive_dir(self, path: str) -> None:
        directory = self._normalise_dir(path, self._default_documents_dir())
        self._update_settings(archiveOutputDir=directory)
        self._archive_vm.outputDir = directory

    @Slot(result=str)
    def get_app_version(self) -> str:
        try:
            from importlib.metadata import PackageNotFoundError, version

            return version("eazlet")
        except Exception:
            return "0.1.0"

    @Slot(result=int)
    def get_startup_page(self) -> int:
        try:
            idx = int(self._load_settings().get("startupPage", 0))
        except (TypeError, ValueError):
            idx = 0
        return idx if 0 <= idx <= 14 else 0

    @Slot(int)
    def save_startup_page(self, index: int) -> None:
        try:
            idx = int(index)
        except (TypeError, ValueError):
            idx = 0
        if idx < 0 or idx > 14:
            idx = 0
        self._update_settings(startupPage=idx)

    @Slot(result=list)
    def get_history(self) -> list:
        data = self._load_settings().get("ioHistory", [])
        return data if isinstance(data, list) else []

    @Slot()
    def clear_history(self) -> None:
        self._update_settings(ioHistory=[])
        self.historyChanged.emit()

    @Slot(str, str, str, str)
    def record_history(
        self, tool: str, action: str, input_text: str = "", output_text: str = ""
    ) -> None:
        try:
            tool = str(tool or "")
            action = str(action or "")
            input_text = "" if input_text is None else str(input_text)
            output_text = "" if output_text is None else str(output_text)
            if len(input_text) > 4000:
                input_text = input_text[:4000] + "…"
            if len(output_text) > 4000:
                output_text = output_text[:4000] + "…"
            entry = {
                "time": datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds"),
                "tool": tool,
                "action": action,
                "input": input_text,
                "output": output_text,
            }
            history = self.get_history()
            history.insert(0, entry)
            if len(history) > 200:
                history = history[:200]
            self._update_settings(ioHistory=history)
            self.historyChanged.emit()
        except Exception as e:
            logger.warning("Could not record history: %s", e)

    @Slot(str, str, result=str)
    def save_text_file(self, path: str, content: str) -> str:
        try:
            if not path:
                return ""
            local = path
            if local.startswith("file://"):
                local = QUrl(local).toLocalFile() or local
            if local.startswith("file:"):
                local = QUrl(local).toLocalFile() or local[len("file:"):]
            file_path = Path(local).expanduser()
            file_path.parent.mkdir(parents=True, exist_ok=True)
            file_path.write_text(content or "", encoding="utf-8")
            return str(file_path)
        except Exception as e:
            logger.warning("Could not save text file: %s", e)
            self.storageError.emit(f"Could not save file: {e}")
            return ""

    @Slot(str)
    def apply_app_icon(self, theme_name: str) -> None:
        try:
            from PySide6.QtGui import QGuiApplication, QIcon

            app = QGuiApplication.instance()
            if app is None:
                return
            safe_name = str(theme_name or DEFAULT_THEME).replace(" ", "-")
            base = Path(__file__).parent.parent / "resources" / "assets" / "icons"
            icon_path = base / "app_icons" / f"Eazlet_icon_{safe_name}.svg"
            if not icon_path.exists():
                icon_path = base / "icon.svg"
            if icon_path.exists():
                app.setWindowIcon(QIcon(str(icon_path)))
        except Exception as e:
            logger.warning("Could not set app icon: %s", e)

    @Slot()
    def reset_settings(self) -> None:
        settings = self._load_settings()
        for key in (
            "scaleFactor",
            "cornerRadius",
            "animationsEnabled",
            "isContinuous",
            "fontFamily",
            "language",
            "shortcuts",
            "startupPage",
            "downloaderDir",
            "downloadDir",
            "converterOutputDir",
            "archiveOutputDir",
        ):
            settings.pop(key, None)
        self._save_settings(settings)
        self.save_theme(DEFAULT_THEME)
        self._current_language = 0
        self._refresh_language_data()
        self.apply_saved_settings()
        self.languageChanged.emit()

    @Property(QObject, constant=True)
    def mainVM(self) -> MainVM:
        return self._main_vm

    @Property(QObject, constant=True)
    def settingsVM(self) -> SettingsVM:
        return self._settings_vm

    @Property(QObject, constant=True)
    def unifiedDownloadVM(self) -> UnifiedDownloadVM:
        return self._unified_download_vm

    @Property(QObject, constant=True)
    def converterVM(self) -> ConverterVM:
        return self._converter_vm

    @Property(QObject, constant=True)
    def archiveVM(self) -> ArchiveVM:
        return self._archive_vm

    @Property(QObject, constant=True)
    def organizerVM(self) -> OrganizerVM:
        return self._organizer_vm

    @Property(QObject, constant=True)
    def cipherVM(self) -> CipherVM:
        return self._cipher_vm

    @Property(QObject, constant=True)
    def colorsVM(self) -> ColorsVM:
        return self._colors_vm

    @Property(QObject, constant=True)
    def tierListVM(self) -> TierListVM:
        return self._tier_list_vm

    @Property(QObject, constant=True)
    def textAnalysisVM(self) -> TextAnalysisVM:
        return self._text_analysis_vm

    @Property(QObject, constant=True)
    def textToolsVM(self) -> TextToolsVM:
        return self._text_tools_vm

    @Property(QObject, constant=True)
    def asciiArtVM(self) -> AsciiArtVM:
        return self._ascii_art_vm

    @Property(QObject, constant=True)
    def numberToolsVM(self) -> NumberToolsVM:
        return self._number_tools_vm

    @Property(QObject, constant=True)
    def mathVM(self) -> MathVM:
        return self._math_vm

    @Property(QObject, constant=True)
    def generatorsVM(self) -> GeneratorsVM:
        return self._generators_vm

    @Property(QObject, constant=True)
    def dictionaryVM(self) -> DictionaryVM:
        return self._dictionary_vm

    @Property(QObject, constant=True)
    def replVM(self) -> ReplVM:
        return self._repl_vm
