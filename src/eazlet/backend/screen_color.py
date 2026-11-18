from __future__ import annotations

import os
import shutil
import subprocess
import time
from collections.abc import Callable

from PySide6.QtCore import QObject, QPoint, Signal, Slot
from PySide6.QtGui import QGuiApplication, QImage


def _run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
    )


def _parse_point(output: str) -> tuple[int, int] | None:
    parts = output.strip().split()
    if not parts or "," not in parts[0]:
        return None
    x_text, _, y_text = parts[0].partition(",")
    try:
        return int(float(x_text)), int(float(y_text))
    except ValueError:
        return None


def _wayland_color() -> str | None:
    slurp = shutil.which("slurp")
    grim = shutil.which("grim")
    if not slurp or not grim:
        return None

    selection = _run([slurp, "-p"])
    point = _parse_point(selection.stdout)
    if point is None:
        return None

    x, y = point
    capture = subprocess.run(
        [grim, "-g", f"{x},{y} 1x1", "-t", "png", "-"],
        check=False,
        capture_output=True,
    )
    image = QImage.fromData(capture.stdout, "PNG")
    if image.isNull():
        return None
    return image.pixelColor(image.width() // 2, image.height() // 2).name().upper()


def _x11_color() -> str | None:
    xdotool = shutil.which("xdotool")
    if not xdotool:
        return None

    time.sleep(1.0)
    location = _run([xdotool, "getmouselocation", "--shell"])
    values: dict[str, str] = {}
    for line in location.stdout.splitlines():
        key, _, value = line.partition("=")
        values[key.strip()] = value.strip()
    try:
        point = QPoint(int(values["X"]), int(values["Y"]))
    except (KeyError, ValueError):
        return None

    screen = QGuiApplication.screenAt(point) or QGuiApplication.primaryScreen()
    if screen is None:
        return None
    image = screen.grabWindow(0, point.x(), point.y(), 1, 1)
    if image.isNull():
        return None
    return image.pixelColor(0, 0).name().upper()


def pick_screen_color() -> str | None:
    if os.environ.get("WAYLAND_DISPLAY"):
        return _wayland_color()
    if os.environ.get("DISPLAY"):
        return _x11_color()
    return None


class ScreenColorWorker(QObject):
    picked = Signal(str)
    failed = Signal(str)
    done = Signal()

    def __init__(
        self,
        picker: Callable[[], str | None] | None = None,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self._picker = picker or pick_screen_color

    @Slot()
    def run(self) -> None:
        try:
            color = self._picker()
        except Exception as exc:
            self.failed.emit(str(exc))
        else:
            if color:
                self.picked.emit(color)
            else:
                self.failed.emit("Color picking was cancelled or unavailable.")
        self.done.emit()
