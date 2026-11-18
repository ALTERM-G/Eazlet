import math
from functools import lru_cache
from pathlib import Path

from PySide6.QtGui import (
    QColor,
    QFont,
    QFontDatabase,
    QFontMetricsF,
    QGuiApplication,
    QPainterPath,
)

FONT_PATH = (
    Path(__file__).resolve().parents[1]
    / "resources"
    / "assets"
    / "fonts"
    / "IBM VGA"
    / "Px437_IBM_VGA_8x16.ttf"
)
FONT_PIXEL_SIZE = 16
PADDING = 4


@lru_cache(maxsize=1)
def _font_family() -> str:
    if not FONT_PATH.exists():
        raise FileNotFoundError(f"IBM VGA font not found: {FONT_PATH}")
    if QGuiApplication.instance() is None:
        raise RuntimeError("A QGuiApplication is required to export SVG outlines.")
    font_id = QFontDatabase.addApplicationFont(str(FONT_PATH))
    if font_id == -1:
        raise RuntimeError(f"Could not load the IBM VGA font: {FONT_PATH}")
    families = QFontDatabase.applicationFontFamilies(font_id)
    if not families:
        raise RuntimeError(f"The IBM VGA font has no family name: {FONT_PATH}")
    return families[0]


def _format_number(value: float) -> str:
    number = round(float(value), 3)
    if number == 0:
        number = 0.0
    return f"{number:g}"


def _svg_fill(color: str) -> tuple[str, float]:
    parsed = QColor(str(color or ""))
    if not parsed.isValid():
        parsed = QColor("#ffffff")
    fill = f"#{parsed.red():02x}{parsed.green():02x}{parsed.blue():02x}"
    return fill, parsed.alphaF()


def _path_data(path: QPainterPath, offset_x: float, offset_y: float) -> str:
    parts: list[str] = []
    count = path.elementCount()
    index = 0
    while index < count:
        element = path.elementAt(index)
        kind = element.type
        x = _format_number(element.x + offset_x)
        y = _format_number(element.y + offset_y)

        if kind == QPainterPath.MoveToElement:
            if parts:
                parts.append("Z")
            parts.append(f"M {x} {y}")
            index += 1
        elif kind == QPainterPath.LineToElement:
            parts.append(f"L {x} {y}")
            index += 1
        elif kind == QPainterPath.CurveToElement:
            if index + 2 >= count:
                break
            control2 = path.elementAt(index + 1)
            end = path.elementAt(index + 2)
            cx = _format_number(control2.x + offset_x)
            cy = _format_number(control2.y + offset_y)
            ex = _format_number(end.x + offset_x)
            ey = _format_number(end.y + offset_y)
            parts.append(f"C {x} {y} {cx} {cy} {ex} {ey}")
            index += 3
        else:
            index += 1

    if parts:
        parts.append("Z")
    return " ".join(parts)


def build_art_path(art: str) -> QPainterPath:
    font = QFont(_font_family())
    font.setPixelSize(FONT_PIXEL_SIZE)
    metrics = QFontMetricsF(font)
    baseline = metrics.ascent()
    line_height = metrics.height()

    path = QPainterPath()
    for row, line in enumerate(art.splitlines()):
        visible = line.expandtabs(8).rstrip()
        if not visible:
            continue
        path.addText(0, row * line_height + baseline, font, visible)
    return path


def render_ascii_svg(art: str, color: str) -> str:
    path = build_art_path(art)
    bounds = path.boundingRect()
    if path.elementCount() == 0 or bounds.isEmpty():
        raise ValueError("There is no ASCII art to export.")

    offset_x = PADDING - bounds.left()
    offset_y = PADDING - bounds.top()
    width = math.ceil(bounds.width() + PADDING * 2)
    height = math.ceil(bounds.height() + PADDING * 2)
    data = _path_data(path, offset_x, offset_y)
    fill, opacity = _svg_fill(color)
    opacity_attr = "" if opacity >= 1 else f' fill-opacity="{opacity:.3g}"'

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" '
        f'height="{height}" viewBox="0 0 {width} {height}">\n'
        '  <title>Eazlet ASCII art</title>\n'
        f'  <path fill="{fill}"{opacity_attr} fill-rule="evenodd" d="{data}"/>\n'
        "</svg>\n"
    )
