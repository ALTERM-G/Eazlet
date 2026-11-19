from collections import OrderedDict
from pathlib import Path

try:
    import pyfiglet
except Exception:
    pyfiglet = None

from PySide6.QtCore import Property, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication

from ..ascii_svg import render_ascii_svg
from .base_vm import BaseVM


def _normalize_preview(rendered: str) -> str:
    """Trim the empty border FIGlet fonts add around their glyphs."""
    lines = rendered.splitlines()
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    lines = [line.rstrip() for line in lines]

    # Right-to-left fonts and FIGlet justification pad the art with a large
    # left margin. Dedent it so the preview stays centred and scalable.
    indents = [len(line) - len(line.lstrip()) for line in lines if line]
    if indents:
        common = min(indents)
        if common:
            lines = [line[common:] if line else line for line in lines]
    return "\n".join(lines)


BORDER_STYLES = {
    "none": None,
    "single": {"tl": "┌", "tr": "┐", "bl": "└", "br": "┘", "h": "─", "v": "│"},
    "double": {"tl": "╔", "tr": "╗", "bl": "╚", "br": "╝", "h": "═", "v": "║"},
    "rounded": {"tl": "╭", "tr": "╮", "bl": "╰", "br": "╯", "h": "─", "v": "│"},
    "ascii": {"tl": "+", "tr": "+", "bl": "+", "br": "+", "h": "-", "v": "|"},
    "bold": {"tl": "┏", "tr": "┓", "bl": "┗", "br": "┛", "h": "━", "v": "┃"},
    "stars": {"tl": "*", "tr": "*", "bl": "*", "br": "*", "h": "*", "v": "*"},
    "dots": {"tl": "·", "tr": "·", "bl": "·", "br": "·", "h": "·", "v": "·"},
    "hash": {"tl": "#", "tr": "#", "bl": "#", "br": "#", "h": "#", "v": "#"},
    "block": {"tl": "█", "tr": "█", "bl": "█", "br": "█", "h": "█", "v": "█"},
}

COOL_FONTS = [
    "standard", "big", "slant", "banner3-D", "doom", "graffiti", "ghost",
    "starwars", "isometric1", "epic", "cyberlarge", "larry3d", "speed",
    "poison", "roman", "3-d", "block", "bubble", "digital", "ivrit", "mini",
    "script", "shadow", "small", "smslant", "stop",
]


def _apply_border(text: str, style_id: str, h_pad: int, v_pad: int) -> str:
    style = BORDER_STYLES.get(style_id)
    if not style or not text:
        return text
    h_pad = max(0, int(h_pad))
    v_pad = max(0, int(v_pad))
    raw_lines = text.splitlines() or [""]
    width = max((len(line) for line in raw_lines), default=0)
    inner = width + h_pad * 2

    top = style["tl"] + style["h"] * inner + style["tr"]
    bottom = style["bl"] + style["h"] * inner + style["br"]
    empty = style["v"] + " " * inner + style["v"]
    pad_left = " " * h_pad
    pad_right = " " * h_pad

    body = []
    for _ in range(v_pad):
        body.append(empty)
    for line in raw_lines:
        body.append(style["v"] + pad_left + line.ljust(width) + pad_right + style["v"])
    for _ in range(v_pad):
        body.append(empty)
    return "\n".join([top, *body, bottom])


class AsciiArtVM(BaseVM):
    inputChanged = Signal()
    outputChanged = Signal()
    fontChanged = Signal()
    fontsChanged = Signal()
    statusChanged = Signal()
    errorChanged = Signal()
    favoritesChanged = Signal()
    recentsChanged = Signal()
    widthChanged = Signal()
    justifyChanged = Signal()
    directionChanged = Signal()
    borderStyleChanged = Signal()
    borderHPaddingChanged = Signal()
    borderVPaddingChanged = Signal()
    coolFontsChanged = Signal()

    MAX_RECENTS = 24
    MAX_PREVIEWS = 256
    PREVIEW_TEXT_LENGTH = 32
    # FIGlet's default width is 80 columns, which wraps output into stacked
    # blocks long before the wide result box is full. A generous width lets
    # art flow across the box so the horizontal scroll bar is actually useful.
    FIGLET_WIDTH = 1000

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self._controller = parent
        self._input = ""
        self._raw_output = ""
        self._output = ""
        self._status = ""
        self._error = ""
        self._width = self.FIGLET_WIDTH
        self._justify = "auto"
        self._direction = "auto"
        self._border_style = "none"
        self._border_h_padding = 1
        self._border_v_padding = 0
        self._figures: dict[tuple[str, int, str, str], object] = {}
        self._preview_figures: dict[str, object] = {}
        self._preview_cache: OrderedDict[tuple[str, str], str] = OrderedDict()
        self._favorites: list[str] = []
        self._recents: list[str] = []
        if pyfiglet is None:
            self._fonts = ["standard"]
            self._font = "standard"
            self._error = self.tr(
                "pages.asciiArt.msgPyfigletMissing",
                "pyfiglet is not installed (add it to project dependencies).",
            )
            self._status = self.tr("pages.asciiArt.msgUnavailable", "Unavailable")
        else:
            try:
                fonts = pyfiglet.FigletFont.getFonts()
                self._fonts = sorted(fonts) if fonts else ["standard"]
            except Exception:
                self._fonts = ["standard"]
            self._font = "standard" if "standard" in self._fonts else self._fonts[0]
        self._cool_fonts = [f for f in COOL_FONTS if f in self._fonts]
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

    @Property(list, notify=coolFontsChanged)
    def coolFonts(self) -> list:
        return self._cool_fonts

    @Property(int, notify=widthChanged)
    def width(self) -> int:
        return self._width

    @width.setter
    def width(self, value: int) -> None:
        try:
            value = int(value)
        except Exception:
            value = self.FIGLET_WIDTH
        value = max(20, min(4000, value))
        if value != self._width:
            self._width = value
            self.widthChanged.emit()

    @Property(str, notify=justifyChanged)
    def justify(self) -> str:
        return self._justify

    @justify.setter
    def justify(self, value: str) -> None:
        value = value if value in ("auto", "left", "center", "right") else "auto"
        if value != self._justify:
            self._justify = value
            self.justifyChanged.emit()

    @Property(str, notify=directionChanged)
    def direction(self) -> str:
        return self._direction

    @direction.setter
    def direction(self, value: str) -> None:
        value = value if value in ("auto", "left-to-right", "right-to-left") else "auto"
        if value != self._direction:
            self._direction = value
            self.directionChanged.emit()

    @Property(str, notify=borderStyleChanged)
    def borderStyle(self) -> str:
        return self._border_style

    @borderStyle.setter
    def borderStyle(self, value: str) -> None:
        value = value if value in BORDER_STYLES else "none"
        if value != self._border_style:
            self._border_style = value
            self.borderStyleChanged.emit()

    @Property(int, notify=borderHPaddingChanged)
    def borderHPadding(self) -> int:
        return self._border_h_padding

    @borderHPadding.setter
    def borderHPadding(self, value: int) -> None:
        try:
            value = int(value)
        except Exception:
            value = 1
        value = max(0, min(20, value))
        if value != self._border_h_padding:
            self._border_h_padding = value
            self.borderHPaddingChanged.emit()

    @Property(int, notify=borderVPaddingChanged)
    def borderVPadding(self) -> int:
        return self._border_v_padding

    @borderVPadding.setter
    def borderVPadding(self, value: int) -> None:
        try:
            value = int(value)
        except Exception:
            value = 0
        value = max(0, min(10, value))
        if value != self._border_v_padding:
            self._border_v_padding = value
            self.borderVPaddingChanged.emit()

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
        key = (font, self._width, self._justify, self._direction)
        figure = self._figures.get(key)
        if figure is None:
            figure = pyfiglet.Figlet(
                font=font, width=self._width,
                justify=self._justify, direction=self._direction,
            )
            self._figures[key] = figure
        return figure

    def _preview_figure(self, font: str):
        figure = self._preview_figures.get(font)
        if figure is None:
            figure = pyfiglet.Figlet(font=font, width=self.FIGLET_WIDTH)
            self._preview_figures[font] = figure
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

    def _apply_output(self, raw: str) -> None:
        self._raw_output = raw
        bordered = _apply_border(
            raw, self._border_style,
            self._border_h_padding, self._border_v_padding,
        )
        if bordered != self._output:
            self._output = bordered
            self.outputChanged.emit()

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
            rendered = _normalize_preview(self._preview_figure(font).renderText(sample))
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
            self._set_error(
                self.tr(
                    "pages.asciiArt.msgPyfigletMissing",
                    "pyfiglet is not installed (add it to project dependencies).",
                )
            )
            self._set_status(
                self.tr("pages.asciiArt.msgUnavailable", "Unavailable")
            )
            return
        text = self._input
        if not text:
            self._set_status(self.tr("pages.asciiArt.msgEnterText", "Enter text to convert"))
            self._raw_output = ""
            self._apply_output("")
            return
        try:
            rendered = self._figure(self._font).renderText(text)
        except Exception as e:
            self._set_error(str(e))
            self._set_status(self.tr("pages.asciiArt.msgError", "Error"))
            self._raw_output = ""
            self._apply_output("")
            return
        self._apply_output(rendered.rstrip("\n"))
        self._set_status("")

    @Slot()
    def processAction(self) -> None:
        self.process()

    @Slot(int)
    def setWidth(self, value: int) -> None:
        self.width = value
        if self._input:
            self.process()

    @Slot(str)
    def setJustify(self, value: str) -> None:
        self.justify = value
        if self._input:
            self.process()

    @Slot(str)
    def setDirection(self, value: str) -> None:
        self.direction = value
        if self._input:
            self.process()

    @Slot(str)
    def setBorderStyle(self, value: str) -> None:
        self.borderStyle = value
        if self._raw_output:
            self._apply_output(self._raw_output)
        elif self._input:
            self.process()

    @Slot(int)
    def setBorderHPadding(self, value: int) -> None:
        self.borderHPadding = value
        if self._raw_output:
            self._apply_output(self._raw_output)

    @Slot(int)
    def setBorderVPadding(self, value: int) -> None:
        self.borderVPadding = value
        if self._raw_output:
            self._apply_output(self._raw_output)

    @Slot()
    def clear(self) -> None:
        self.input = ""
        self._raw_output = ""
        self._output = ""
        self.outputChanged.emit()
        self._set_error("")
        self._set_status("")

    @Slot()
    def copyOutput(self) -> None:
        if not self._output:
            return
        try:
            QGuiApplication.clipboard().setText(self._output)
            self._set_status(self.tr("pages.asciiArt.msgCopied", "Copied"))
        except Exception as e:
            self._set_error(str(e))

    @Slot(str, str)
    def exportSvg(self, path: str, color: str) -> None:
        self._set_error("")
        self._set_status("")
        if not self._output:
            self._set_error(
                self.tr(
                    "pages.asciiArt.msgGenerateFirst",
                    "Generate ASCII art before exporting SVG.",
                )
            )
            return

        target = str(path or "").strip()
        if target.startswith("file://"):
            target = QUrl(target).toLocalFile()
        if not target:
            self._set_error(
                self.tr(
                    "pages.asciiArt.msgChooseLocation",
                    "Choose where to save the SVG.",
                )
            )
            return

        target_path = Path(target).expanduser()
        if target_path.suffix.lower() != ".svg":
            target_path = target_path.with_suffix(".svg")

        try:
            svg = render_ascii_svg(self._output, color)
            target_path.write_text(svg, encoding="utf-8")
        except Exception as e:
            self._set_error(self.tr("pages.asciiArt.msgSaveFailed", "Could not save the SVG: {error}", error=str(e)))
            return

        self._set_status(self.tr("pages.asciiArt.msgSaved", "Saved {name}", name=target_path.name))
