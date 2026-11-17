from PySide6.QtCore import QPointF, QRectF, QSize, Qt
from PySide6.QtGui import QColor, QConicalGradient, QImage, QPainter, QRadialGradient
from PySide6.QtQuick import QQuickImageProvider

_MIN_SIDE = 32
_MAX_SIDE = 2048
_HUE_STOPS = 36


class ColorWheelImageProvider(QQuickImageProvider):
    def __init__(self) -> None:
        super().__init__(QQuickImageProvider.ImageType.Image)

    def requestImage(
        self, image_id: str, size: QSize, requested_size: QSize
    ) -> QImage:
        side = requested_size.width() if requested_size.isValid() else 0
        if side <= 0:
            side = size.width()
        side = max(_MIN_SIDE, min(_MAX_SIDE, side or 256))

        image = QImage(side, side, QImage.Format.Format_ARGB32_Premultiplied)
        image.fill(Qt.GlobalColor.transparent)

        painter = QPainter(image)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        painter.setPen(Qt.PenStyle.NoPen)

        rect = QRectF(0.5, 0.5, side - 1.0, side - 1.0)
        center = QPointF(side / 2.0, side / 2.0)
        radius = side / 2.0 - 0.5

        hue = QConicalGradient(center, 0.0)
        for index in range(_HUE_STOPS + 1):
            position = index / _HUE_STOPS
            hue.setColorAt(
                position, QColor.fromHsvF((1.0 - position) % 1.0, 1.0, 1.0)
            )
        painter.setBrush(hue)
        painter.drawEllipse(rect)

        wash = QRadialGradient(center, radius)
        wash.setColorAt(0.0, QColor(255, 255, 255, 255))
        wash.setColorAt(1.0, QColor(255, 255, 255, 0))
        painter.setBrush(wash)
        painter.drawEllipse(rect)

        painter.end()

        size.setWidth(side)
        size.setHeight(side)
        return image
