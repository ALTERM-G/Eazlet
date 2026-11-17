import math

from PySide6.QtCore import QSize

from eazlet.backend.color_wheel_provider import ColorWheelImageProvider


def _wheel(size: int = 360):
    provider = ColorWheelImageProvider()
    return provider.requestImage("wheel", QSize(), QSize(size, size))


def test_wheel_size_and_transparent_background(qapp):
    image = _wheel()
    assert (image.width(), image.height()) == (360, 360)
    assert image.pixelColor(0, 0).alpha() == 0


def test_wheel_center_is_white(qapp):
    image = _wheel()
    center = image.pixelColor(180, 180)
    assert min(center.red(), center.green(), center.blue()) >= 240


def test_wheel_hue_matches_picker_angles(qapp):
    image = _wheel()
    center = 180
    radius = 144
    for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1)):
        color = image.pixelColor(center + dx * radius, center + dy * radius)
        hue = color.getHsvF()[0] * 360
        expected = (math.degrees(math.atan2(dy, dx)) + 360) % 360
        assert abs((hue - expected + 180) % 360 - 180) < 5


def test_wheel_clamps_requested_size(qapp):
    image = _wheel(1)
    assert image.width() >= 32
