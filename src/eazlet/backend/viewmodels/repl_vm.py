import sys

from PySide6.QtCore import Property, QByteArray, QObject, QProcess, Signal, Slot

PROMPT = ">>> "


class ReplVM(QObject):
    outputChanged = Signal()
    runningChanged = Signal()
    replError = Signal(str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._output = PROMPT
        self._prompt_pending = True
        self._startup_buffer = ""
        self._process = QProcess(self)
        self._process.setProcessChannelMode(QProcess.MergedChannels)
        self._process.readyReadStandardOutput.connect(self._read_output)
        self._process.stateChanged.connect(self._on_state_changed)
        self._process.errorOccurred.connect(self._on_process_error)

    @Property(str, notify=outputChanged)
    def output(self) -> str:
        return self._output

    @Property(bool, notify=runningChanged)
    def running(self) -> bool:
        return self._process.state() == QProcess.Running

    def _read_output(self) -> None:
        data = bytes(self._process.readAllStandardOutput())
        if not data:
            return
        text = data.decode("utf-8", errors="replace")

        if self._prompt_pending:
            buffered = self._startup_buffer + text
            if len(buffered) < len(PROMPT):
                self._startup_buffer = buffered
                return
            if buffered.startswith(PROMPT):
                buffered = buffered[len(PROMPT) :]
            self._startup_buffer = ""
            self._prompt_pending = False
            text = buffered

        self._output += text
        self.outputChanged.emit()

    def _on_state_changed(self, _state: QProcess.ProcessState) -> None:
        self.runningChanged.emit()

    def _on_process_error(self, error: QProcess.ProcessError) -> None:
        if error == QProcess.FailedToStart:
            message = self._process.errorString()
            self._output += f"[could not start Python: {message}]\n"
            self.outputChanged.emit()
            self.replError.emit(message)

    @Slot()
    def start(self) -> None:
        if self._process.state() != QProcess.NotRunning:
            return
        self._prompt_pending = True
        self._startup_buffer = ""
        self._process.start(sys.executable, ["-u", "-i", "-q"])
        self._process.waitForStarted(3000)

    @Slot(str)
    def submit(self, command: str) -> None:
        self.start()
        self._output += command + "\n"
        self.outputChanged.emit()
        self._process.write(QByteArray((command + "\n").encode("utf-8")))

    @Slot()
    def clear(self) -> None:
        self._output = PROMPT
        self.outputChanged.emit()

    @Slot()
    def restart(self) -> None:
        self.stop()
        self._output = PROMPT
        self.outputChanged.emit()
        self.start()

    @Slot()
    def stop(self) -> None:
        if self._process.state() == QProcess.Running:
            self._process.kill()
            self._process.waitForFinished(2000)
