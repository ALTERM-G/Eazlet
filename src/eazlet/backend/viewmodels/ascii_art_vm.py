try:
    import pyfiglet
except Exception:  # pragma: no cover
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

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self._input = ""
        self._output = ""
        self._status = "Idle"
        self._error = ""
        if pyfiglet is None:
            self._fonts = ["standard"]
            self._font = "standard"
            self._error = "pyfiglet is not installed (add it to project dependencies)."
            self._status = "Unavailable"
            return
        try:
            fonts = pyfiglet.FigletFont.getFonts()
            self._fonts = sorted(fonts) if fonts else ["standard"]
        except Exception:
            self._fonts = ["standard"]
        self._font = "standard" if "standard" in self._fonts else self._fonts[0]

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

    @Slot(str)
    def setInput(self, value: str) -> None:
        self.input = value

    @Slot(str)
    def setFont(self, value: str) -> None:
        old = self._font
        self.font = value
        if value != old and self._input.strip():
            self.process()

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
            fig = pyfiglet.Figlet(font=self._font)
            rendered = fig.renderText(text)
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
