import colorsys
import re
import secrets

from PySide6.QtCore import Property, QObject, QThread, Signal, Slot
from PySide6.QtGui import QGuiApplication

from ..screen_color import ScreenColorWorker, pick_screen_color
from .base_vm import BaseVM

COLOR_NAMES = (
    ("Black", (0, 0, 0)),
    ("White", (255, 255, 255)),
    ("Gray", (128, 128, 128)),
    ("Silver", (192, 192, 192)),
    ("Red", (255, 0, 0)),
    ("Maroon", (128, 0, 0)),
    ("Orange", (255, 165, 0)),
    ("Gold", (255, 215, 0)),
    ("Yellow", (255, 255, 0)),
    ("Olive", (128, 128, 0)),
    ("Lime", (0, 255, 0)),
    ("Green", (0, 128, 0)),
    ("Teal", (0, 128, 128)),
    ("Aqua", (0, 255, 255)),
    ("Blue", (0, 0, 255)),
    ("Navy", (0, 0, 128)),
    ("Purple", (128, 0, 128)),
    ("Fuchsia", (255, 0, 255)),
    ("Pink", (255, 192, 203)),
    ("Brown", (165, 42, 42)),
    ("Beige", (245, 245, 220)),
    ("Coral", (255, 127, 80)),
    ("Salmon", (250, 128, 114)),
    ("Chocolate", (210, 105, 30)),
    ("Khaki", (240, 230, 140)),
    ("Lavender", (230, 230, 250)),
    ("Turquoise", (64, 224, 208)),
    ("Indigo", (75, 0, 130)),
    ("Violet", (238, 130, 238)),
    ("Crimson", (220, 20, 60)),
    ("Tan", (210, 180, 140)),
    ("Ivory", (255, 255, 240)),
    ("Steel Blue", (70, 130, 180)),
    ("Dodger Blue", (30, 144, 255)),
    ("Cornflower Blue", (100, 149, 237)),
)

NUMBER_RE = re.compile(r"-?\d+(?:\.\d+)?")


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


class ColorsVM(BaseVM):
    colorChanged = Signal()
    harmonyChanged = Signal()
    harmonyTypeChanged = Signal()
    harmonyCountChanged = Signal()
    inputErrorChanged = Signal()
    pickingChanged = Signal()

    HARMONY_TYPES = [
        "Complementary",
        "Analogous",
        "Triadic",
        "Split complementary",
        "Tetradic",
        "Square",
        "Monochromatic",
    ]
    HARMONY_PATTERNS = {
        "Complementary": ((0, "Base"), (180, "Complement")),
        "Analogous": ((-30, "-30°"), (0, "Base"), (30, "+30°")),
        "Triadic": ((0, "Base"), (120, "+120°"), (240, "+240°")),
        "Split complementary": ((0, "Base"), (150, "+150°"), (210, "+210°")),
        "Tetradic": ((0, "Base"), (60, "+60°"), (180, "+180°"), (240, "+240°")),
        "Square": ((0, "Base"), (90, "+90°"), (180, "+180°"), (270, "+270°")),
    }
    MIN_HARMONY_COUNT = 2
    MAX_HARMONY_COUNT = 5

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._harmony_type = self.HARMONY_TYPES[0]
        self._harmony_count = self.MAX_HARMONY_COUNT
        self._input_error = ""
        self._picking = False
        self._pick_jobs: dict[QThread, ScreenColorWorker] = {}
        self._rgb = (74, 144, 226)
        self._hsv = self._hsv_from_rgb(self._rgb)
        self._hsl = self._hsl_from_rgb(self._rgb)
        self._cmyk = self._cmyk_from_rgb(self._rgb)

    @staticmethod
    def _hsv_from_rgb(rgb: tuple[int, int, int]) -> tuple[float, float, float]:
        hue, saturation, value = colorsys.rgb_to_hsv(*(channel / 255 for channel in rgb))
        return (hue * 360.0, saturation * 100.0, value * 100.0)

    @staticmethod
    def _hsl_from_rgb(rgb: tuple[int, int, int]) -> tuple[float, float, float]:
        hue, lightness, saturation = colorsys.rgb_to_hls(*(channel / 255 for channel in rgb))
        return (hue * 360.0, saturation * 100.0, lightness * 100.0)

    @staticmethod
    def _cmyk_from_rgb(rgb: tuple[int, int, int]) -> tuple[float, float, float, float]:
        red, green, blue = (channel / 255 for channel in rgb)
        black = 1.0 - max(red, green, blue)
        if black >= 1.0:
            return (0.0, 0.0, 0.0, 100.0)
        cyan = (1.0 - red - black) / (1.0 - black)
        magenta = (1.0 - green - black) / (1.0 - black)
        yellow = (1.0 - blue - black) / (1.0 - black)
        return (cyan * 100.0, magenta * 100.0, yellow * 100.0, black * 100.0)

    @staticmethod
    def _hex_from_rgb(rgb: tuple[int, int, int]) -> str:
        return "#{:02X}{:02X}{:02X}".format(*rgb)

    def _commit(self, rgb: tuple[int, int, int], hsv: tuple[float, float, float]) -> None:
        if rgb == self._rgb and hsv == self._hsv:
            return
        self._rgb = rgb
        self._hsv = hsv
        self._hsl = self._hsl_from_rgb(rgb)
        self._cmyk = self._cmyk_from_rgb(rgb)
        self.colorChanged.emit()
        self.harmonyChanged.emit()

    def _set_rgb(self, red: float, green: float, blue: float) -> None:
        rgb = (
            int(round(_clamp(red, 0, 255))),
            int(round(_clamp(green, 0, 255))),
            int(round(_clamp(blue, 0, 255))),
        )
        self._commit(rgb, self._hsv_from_rgb(rgb))

    def _set_hsv(self, hue: float, saturation: float, value: float) -> None:
        hsv = (
            float(hue) % 360.0,
            _clamp(float(saturation), 0.0, 100.0),
            _clamp(float(value), 0.0, 100.0),
        )
        red, green, blue = colorsys.hsv_to_rgb(
            hsv[0] / 360.0, hsv[1] / 100.0, hsv[2] / 100.0
        )
        rgb = (
            int(round(red * 255.0)),
            int(round(green * 255.0)),
            int(round(blue * 255.0)),
        )
        self._commit(rgb, hsv)

    def _set_input_error(self, message: str) -> None:
        if message == self._input_error:
            return
        self._input_error = message
        self.inputErrorChanged.emit()

    @Property(str, notify=colorChanged)
    def hex(self) -> str:
        return self._hex_from_rgb(self._rgb)

    @Property(int, notify=colorChanged)
    def red(self) -> int:
        return self._rgb[0]

    @red.setter
    def red(self, value: int) -> None:
        self._set_rgb(value, self._rgb[1], self._rgb[2])

    @Property(int, notify=colorChanged)
    def green(self) -> int:
        return self._rgb[1]

    @green.setter
    def green(self, value: int) -> None:
        self._set_rgb(self._rgb[0], value, self._rgb[2])

    @Property(int, notify=colorChanged)
    def blue(self) -> int:
        return self._rgb[2]

    @blue.setter
    def blue(self, value: int) -> None:
        self._set_rgb(self._rgb[0], self._rgb[1], value)

    @Property(float, notify=colorChanged)
    def hue(self) -> float:
        return self._hsv[0]

    @hue.setter
    def hue(self, value: float) -> None:
        self._set_hsv(value, self._hsv[1], self._hsv[2])

    @Property(float, notify=colorChanged)
    def saturation(self) -> float:
        return self._hsv[1]

    @saturation.setter
    def saturation(self, value: float) -> None:
        self._set_hsv(self._hsv[0], value, self._hsv[2])

    @Property(float, notify=colorChanged)
    def value(self) -> float:
        return self._hsv[2]

    @value.setter
    def value(self, value: float) -> None:
        self._set_hsv(self._hsv[0], self._hsv[1], value)

    @Property(float, notify=colorChanged)
    def lightness(self) -> float:
        return self._hsl[2]

    @Property(float, notify=colorChanged)
    def hslSaturation(self) -> float:
        return self._hsl[1]

    @Property(bool, notify=colorChanged)
    def isLight(self) -> bool:
        red, green, blue = self._rgb
        luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255.0
        return luminance > 0.6

    @Property(str, notify=colorChanged)
    def colorName(self) -> str:
        closest = min(
            COLOR_NAMES,
            key=lambda entry: sum(
                (entry[1][index] - self._rgb[index]) ** 2 for index in range(3)
            ),
        )
        return closest[0]

    @Property(str, notify=colorChanged)
    def rgbText(self) -> str:
        return "rgb({}, {}, {})".format(*self._rgb)

    @Property(str, notify=colorChanged)
    def hslText(self) -> str:
        hue, saturation, lightness = self._hsl
        return f"hsl({round(hue)}, {round(saturation)}%, {round(lightness)}%)"

    @Property(str, notify=colorChanged)
    def hsvText(self) -> str:
        hue, saturation, value = self._hsv
        return f"hsv({round(hue)}, {round(saturation)}%, {round(value)}%)"

    @Property(str, notify=colorChanged)
    def cmykText(self) -> str:
        cyan, magenta, yellow, black = self._cmyk
        return f"cmyk({round(cyan)}%, {round(magenta)}%, {round(yellow)}%, {round(black)}%)"

    @Property(list, notify=colorChanged)
    def conversions(self) -> list[dict]:
        return [
            {"label": "HEX", "value": self.hex},
            {"label": "RGB", "value": self.rgbText},
            {"label": "HSL", "value": self.hslText},
            {"label": "HSV", "value": self.hsvText},
            {"label": "CMYK", "value": self.cmykText},
        ]

    @Property(list, constant=True)
    def harmonyTypes(self) -> list[str]:
        return self.HARMONY_TYPES

    @Property(str, notify=harmonyTypeChanged)
    def harmonyType(self) -> str:
        return self._harmony_type

    @harmonyType.setter
    def harmonyType(self, value: str) -> None:
        if value not in self.HARMONY_TYPES or value == self._harmony_type:
            return
        self._harmony_type = value
        self.harmonyTypeChanged.emit()
        self.harmonyChanged.emit()

    @Property(int, constant=True)
    def maxHarmonyCount(self) -> int:
        return self.MAX_HARMONY_COUNT

    @Property(int, notify=harmonyCountChanged)
    def harmonyCount(self) -> int:
        return self._harmony_count

    @harmonyCount.setter
    def harmonyCount(self, value: int) -> None:
        count = int(_clamp(int(value), self.MIN_HARMONY_COUNT, self.MAX_HARMONY_COUNT))
        if count == self._harmony_count:
            return
        self._harmony_count = count
        self.harmonyCountChanged.emit()
        self.harmonyChanged.emit()

    def _harmony_color(self, hue: float, lightness_shift: float = 0.0) -> str:
        lightness = _clamp(self._hsl[2] / 100.0 + lightness_shift, 0.05, 0.95)
        red, green, blue = colorsys.hls_to_rgb(
            (hue % 360.0) / 360.0,
            lightness,
            self._hsl[1] / 100.0,
        )
        return self._hex_from_rgb(
            (
                int(round(red * 255.0)),
                int(round(green * 255.0)),
                int(round(blue * 255.0)),
            )
        )

    def _monochromatic_harmony(self) -> list[dict]:
        base_hue, base_saturation, _ = self._hsl
        base_lightness = self._hsl[2] / 100.0
        colors = []

        for index in range(self._harmony_count):
            offset = (index / (self._harmony_count - 1) - 0.5) * 0.6
            lightness = _clamp(base_lightness + offset, 0.05, 0.95)
            delta = lightness - base_lightness

            if abs(delta) < 0.01:
                label = "Base"
            elif delta < 0:
                label = "Dark" if delta <= -0.22 else "Shade"
            else:
                label = "Light" if delta >= 0.22 else "Tint"

            red, green, blue = colorsys.hls_to_rgb(
                base_hue / 360.0, lightness, base_saturation / 100.0
            )
            colors.append(
                {
                    "label": label,
                    "hex": self._hex_from_rgb(
                        (
                            int(round(red * 255.0)),
                            int(round(green * 255.0)),
                            int(round(blue * 255.0)),
                        )
                    ),
                }
            )

        return colors

    @Property(list, notify=harmonyChanged)
    def harmony(self) -> list[dict]:
        if self._harmony_type == "Monochromatic":
            return self._monochromatic_harmony()

        hue = self._hsv[0]
        pattern = self.HARMONY_PATTERNS.get(self._harmony_type, ((0, "Base"),))
        count = self._harmony_count

        if count <= len(pattern):
            if count == len(pattern):
                selected = pattern
            else:
                selected = tuple(
                    pattern[round(index * (len(pattern) - 1) / (count - 1))]
                    for index in range(count)
                )
            return [
                {"label": label, "hex": self._harmony_color(hue + offset)}
                for offset, label in selected
            ]

        colors = [
            {"label": label, "hex": self._harmony_color(hue + offset)}
            for offset, label in pattern
        ]

        for extra in range(count - len(pattern)):
            offset, label = pattern[extra % len(pattern)]
            cycle = extra // len(pattern)
            lightness_shift = 0.15 if cycle % 2 == 0 else -0.15
            suffix = " tint" if lightness_shift > 0 else " shade"
            colors.append(
                {
                    "label": label + suffix,
                    "hex": self._harmony_color(hue + offset, lightness_shift),
                }
            )

        return colors

    @Property(str, notify=inputErrorChanged)
    def inputError(self) -> str:
        return self._input_error

    @Property(bool, notify=pickingChanged)
    def picking(self) -> bool:
        return self._picking

    def _set_picking(self, value: bool) -> None:
        if value == self._picking:
            return
        self._picking = value
        self.pickingChanged.emit()

    @Slot()
    def pickScreenColor(self) -> None:
        if self._picking:
            return
        self._set_picking(True)
        self._set_input_error("Click any pixel on screen to pick its color.")

        worker = ScreenColorWorker(pick_screen_color)
        thread = QThread(self)
        worker.moveToThread(thread)
        thread.started.connect(worker.run)
        worker.picked.connect(self._onScreenColorPicked)
        worker.failed.connect(self._onScreenColorFailed)
        worker.done.connect(thread.quit)
        worker.done.connect(worker.deleteLater)
        thread.finished.connect(thread.deleteLater)
        thread.finished.connect(
            lambda finished=thread: self._pick_jobs.pop(finished, None)
        )
        self._pick_jobs[thread] = worker
        thread.start()

    @Slot(str)
    def _onScreenColorPicked(self, color: str) -> None:
        self.setColor(color)
        self._set_input_error("")
        self._set_picking(False)

    @Slot(str)
    def _onScreenColorFailed(self, message: str) -> None:
        self._set_input_error(message)
        self._set_picking(False)

    @Slot(str, result=bool)
    def setColor(self, value: str) -> bool:
        text = (value or "").strip()
        lowered = text.lower()
        if lowered.startswith("0x"):
            lowered = "#" + lowered[2:]

        hex_match = re.fullmatch(r"#?([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})", lowered)
        if hex_match:
            digits = hex_match.group(1)
            if len(digits) == 3:
                digits = "".join(channel * 2 for channel in digits)
            elif len(digits) == 8:
                digits = digits[:6]
            self._set_rgb(
                int(digits[0:2], 16),
                int(digits[2:4], 16),
                int(digits[4:6], 16),
            )
            self._set_input_error("")
            return True

        for prefix in ("rgba", "rgb"):
            if lowered.startswith(prefix):
                numbers = [float(number) for number in NUMBER_RE.findall(lowered)]
                if len(numbers) >= 3:
                    self._set_rgb(numbers[0], numbers[1], numbers[2])
                    self._set_input_error("")
                    return True

        if lowered.startswith("hsl"):
            numbers = [float(number) for number in NUMBER_RE.findall(lowered)]
            if len(numbers) >= 3:
                red, green, blue = colorsys.hls_to_rgb(
                    (numbers[0] % 360.0) / 360.0,
                    _clamp(numbers[2], 0.0, 100.0) / 100.0,
                    _clamp(numbers[1], 0.0, 100.0) / 100.0,
                )
                self._set_rgb(red * 255.0, green * 255.0, blue * 255.0)
                self._set_input_error("")
                return True

        if lowered.startswith("hsv"):
            numbers = [float(number) for number in NUMBER_RE.findall(lowered)]
            if len(numbers) >= 3:
                self._set_hsv(numbers[0], numbers[1], numbers[2])
                self._set_input_error("")
                return True

        if lowered.startswith("cmyk"):
            numbers = [float(number) for number in NUMBER_RE.findall(lowered)]
            if len(numbers) >= 4:
                cyan, magenta, yellow, black = (
                    _clamp(number, 0.0, 100.0) / 100.0 for number in numbers[:4]
                )
                self._set_rgb(
                    255.0 * (1.0 - cyan) * (1.0 - black),
                    255.0 * (1.0 - magenta) * (1.0 - black),
                    255.0 * (1.0 - yellow) * (1.0 - black),
                )
                self._set_input_error("")
                return True

        self._set_input_error("Use HEX, rgb(), hsl(), hsv(), or cmyk().")
        return False

    @Slot(float, float, float)
    def setHsv(self, hue: float, saturation: float, value: float) -> None:
        self._set_hsv(hue, saturation, value)

    @Slot(int, int, int)
    def setRgb(self, red: int, green: int, blue: int) -> None:
        self._set_rgb(red, green, blue)

    @Slot()
    def randomColor(self) -> None:
        self._set_hsv(
            secrets.randbelow(360),
            55 + secrets.randbelow(46),
            55 + secrets.randbelow(46),
        )
        self._set_input_error("")

    @Slot(str)
    def copyText(self, text: str) -> None:
        app = QGuiApplication.instance()
        if app is not None:
            app.clipboard().setText(str(text))

    @Slot()
    def copyHex(self) -> None:
        self.copyText(self.hex)
