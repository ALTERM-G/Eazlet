from collections import OrderedDict

try:
    import pyfiglet
except Exception:
    pyfiglet = None

from PySide6.QtCore import Property, Signal, Slot
from PySide6.QtGui import QGuiApplication

from .base_vm import BaseVM


class AsciiArtVM(BaseVM):
    inputChanged = Signal()
    outputChanged = Signal()
    fontChanged = Signal()
    fontsChanged = Signal()
    statusChanged = Signal()
    errorChanged = Signal()
    favoritesChanged = Signal()
    recentsChanged = Signal()

    MAX_RECENTS = 24
    MAX_PREVIEWS = 256
    PREVIEW_TEXT_LENGTH = 32

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self._controller = parent
        self._input = ""
        self._output = ""
        self._status = "Idle"
        self._error = ""
        self._figures: dict[str, object] = {}
        self._preview_cache: OrderedDict[tuple[str, str], str] = OrderedDict()
        self._favorites: list[str] = []
        self._recents: list[str] = []
        if pyfiglet is None:
            self._fonts = ["standard"]
            self._font = "standard"
            self._error = "pyfiglet is not installed (add it to project dependencies)."
            self._status = "Unavailable"
        else:
            try:
                fonts = pyfiglet.FigletFont.getFonts()
                self._fonts = sorted(fonts) if fonts else ["standard"]
            except Exception:
                self._fonts = ["standard"]
            self._font = "standard" if "standard" in self._fonts else self._fonts[0]
        self._load_persisted_lists()

    def _load_persisted_lists(self) -> None:
        controller = self._controller
        if controller is None or not hasattr(controller, "get_ascii_favorites"):
            return
        valid = set(self._fonts)
        self._favorites = self._unique_valid(
            controller.get_ascii_favorites(), valid
        )
        self._recents = self._unique_valid(controller.get_ascii_recents(), valid)

    @staticmethod
    def _unique_valid(fonts: list, valid: set[str]) -> list[str]:
        seen: set[str] = set()
        result: list[str] = []
        for font in fonts:
            if isinstance(font, str) and font in valid and font not in seen:
                seen.add(font)
                result.append(font)
        return result

    @Property(str, notify=inputChanged)
    def input(self) -> str:
        return self._input

    @input.setter
    def input(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._input:
            self._input = value
            self.inputChanged.emit()

    @Property(str, notify=outputChanged)
    def output(self) -> str:
        return self._output

    @Property(str, notify=fontChanged)
    def font(self) -> str:
        return self._font

    @font.setter
    def font(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._font:
            self._font = value
            self.fontChanged.emit()

    @Property(list, notify=fontsChanged)
    def fonts(self) -> list:
        return self._fonts

    @Property(list, notify=favoritesChanged)
    def favorites(self) -> list:
        return self._favorites

    @Property(list, notify=recentsChanged)
    def recents(self) -> list:
        return self._recents

    @Property(str, notify=statusChanged)
    def status(self) -> str:
        return self._status

    @Property(str, notify=errorChanged)
    def error(self) -> str:
        return self._error

    def _set_status(self, value: str) -> None:
        if value != self._status:
            self._status = value
            self.statusChanged.emit()

    def _set_error(self, value: str) -> None:
        value = value or ""
        if value != self._error:
            self._error = value
            self.errorChanged.emit()

    def _figure(self, font: str):
        figure = self._figures.get(font)
        if figure is None:
            figure = pyfiglet.Figlet(font=font)
            self._figures[font] = figure
        return figure

    def _persist_favorites(self) -> None:
        controller = self._controller
        if controller is not None and hasattr(controller, "save_ascii_favorites"):
            controller.save_ascii_favorites(list(self._favorites))

    def _persist_recents(self) -> None:
        controller = self._controller
        if controller is not None and hasattr(controller, "save_ascii_recents"):
            controller.save_ascii_recents(list(self._recents))

    def _remember_recent(self, font: str) -> None:
        if font not in self._fonts:
            return
        recents = [font] + [item for item in self._recents if item != font]
        recents = recents[: self.MAX_RECENTS]
        if recents != self._recents:
            self._recents = recents
            self.recentsChanged.emit()
            self._persist_recents()

    @Slot(str)
    def setInput(self, value: str) -> None:
        self.input = value

    @Slot(str)
    def setFont(self, value: str) -> None:
        if value not in self._fonts:
            return
        old = self._font
        self.font = value
        self._remember_recent(value)
        if value != old and self._input.strip():
            self.process()

    @Slot(str)
    def toggleFavorite(self, font: str) -> None:
        if font not in self._fonts:
            return
        if font in self._favorites:
            self._favorites = [item for item in self._favorites if item != font]
        else:
            self._favorites = [font] + self._favorites
        self.favoritesChanged.emit()
        self._persist_favorites()

    @Slot(str, result=bool)
    def isFavorite(self, font: str) -> bool:
        return font in self._favorites

    @Slot(str, str, result=str)
    def preview(self, font: str, text: str) -> str:
        if pyfiglet is None or font not in self._fonts:
            return ""
        sample = " ".join((text or "").split())[: self.PREVIEW_TEXT_LENGTH]
        if not sample:
            sample = font.replace("_", " ")
        key = (font, sample)
        cached = self._preview_cache.get(key)
        if cached is not None:
            self._preview_cache.move_to_end(key)
            return cached
        try:
            rendered = self._figure(font).renderText(sample).rstrip("\n")
        except Exception:
            return ""
        self._preview_cache[key] = rendered
        if len(self._preview_cache) > self.MAX_PREVIEWS:
            self._preview_cache.popitem(last=False)
        return rendered

    @Slot()
    def process(self) -> None:
        self._set_error("")
        if pyfiglet is None:
            self._set_error("pyfiglet is not installed (add it to project dependencies).")
            self._set_status("Unavailable")
            return
        text = self._input
        if not text:
            self._set_status("Enter text to convert")
            self._output = ""
            self.outputChanged.emit()
            return
        try:
            rendered = self._figure(self._font).renderText(text)
        except Exception as e:
            self._set_error(str(e))
            self._set_status("Error")
            self._output = ""
            self.outputChanged.emit()
            return
        self._output = rendered.rstrip("\n")
        self.outputChanged.emit()
        self._set_status("Done")

    @Slot()
    def processAction(self) -> None:
        self.process()

    @Slot()
    def clear(self) -> None:
        self.input = ""
        self._output = ""
        self.outputChanged.emit()
        self._set_error("")
        self._set_status("Idle")

    @Slot()
    def copyOutput(self) -> None:
        if not self._output:
            return
        try:
            QGuiApplication.clipboard().setText(self._output)
            self._set_status("Copied")
        except Exception as e:
            self._set_error(str(e))
