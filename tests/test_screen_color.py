import subprocess
from pathlib import Path

from PySide6.QtCore import QBuffer, QIODevice
from PySide6.QtGui import QColor, QImage

from eazlet.backend import screen_color


def _png_bytes(color: str) -> bytes:
    image = QImage(1, 1, QImage.Format_ARGB32)
    image.setPixelColor(0, 0, QColor(color))
    buffer = QBuffer()
    buffer.open(QIODevice.OpenModeFlag.WriteOnly)
    image.save(buffer, "PNG")
    return bytes(buffer.data())


def test_parse_point_handles_slurp_output():
    assert screen_color._parse_point("120,45 1x1\n") == (120, 45)
    assert screen_color._parse_point("12.5,8.5") == (12, 8)
    assert screen_color._parse_point("") is None
    assert screen_color._parse_point("garbage") is None


def test_wayland_pick_uses_slurp_point_and_grim_pixel(monkeypatch):
    monkeypatch.setenv("WAYLAND_DISPLAY", "wayland-1")
    monkeypatch.delenv("DISPLAY", raising=False)
    monkeypatch.setattr(screen_color.shutil, "which", lambda name: f"/usr/bin/{name}")
    monkeypatch.setattr(
        screen_color,
        "_run",
        lambda command: subprocess.CompletedProcess(command, 0, "88,99 1x1\n", ""),
    )
    monkeypatch.setattr(
        screen_color.subprocess,
        "run",
        lambda *args, **kwargs: subprocess.CompletedProcess(
            args[0], 0, _png_bytes("#336699"), b""
        ),
    )

    assert screen_color.pick_screen_color() == "#336699"


def test_wayland_pick_handles_cancelled_selection(monkeypatch):
    monkeypatch.setenv("WAYLAND_DISPLAY", "wayland-1")
    monkeypatch.setattr(screen_color.shutil, "which", lambda name: f"/usr/bin/{name}")
    monkeypatch.setattr(
        screen_color,
        "_run",
        lambda command: subprocess.CompletedProcess(command, 1, "", ""),
    )

    assert screen_color.pick_screen_color() is None


def test_worker_reports_picked_color(qapp):
    worker = screen_color.ScreenColorWorker(lambda: "#ABCDEF")
    picked: list[str] = []
    worker.picked.connect(picked.append)

    worker.run()

    assert picked == ["#ABCDEF"]


def test_worker_reports_failure(qapp):
    def fail() -> str:
        raise RuntimeError("picker unavailable")

    worker = screen_color.ScreenColorWorker(fail)
    failed: list[str] = []
    worker.failed.connect(failed.append)

    worker.run()

    assert failed and "picker unavailable" in failed[0]


def test_color_picker_icon_is_registered():
    library = (
        Path(__file__).resolve().parent.parent
        / "src/eazlet/resources/style/SVGLibrary.qml"
    ).read_text()
    assert "colorPicker" in library
    assert "color_picker.svg" in library
