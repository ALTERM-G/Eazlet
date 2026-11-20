import sys

from PySide6.QtCore import Property, QByteArray, QObject, QProcess, Signal, Slot

from .base_vm import BaseVM

PROMPT = ">>> "
MAX_OUTPUT_CHARS = 200000


class ReplVM(BaseVM):
    outputChanged = Signal()
    runningChanged = Signal()
    replError = Signal(str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._output = PROMPT
        self._prompt_pending = True
        self._startup_buffer = ""
        self._intentional_stop = False
        self._failed_to_start = False
        self._process = QProcess(self)
        self._process.setProcessChannelMode(QProcess.MergedChannels)
        self._process.readyReadStandardOutput.connect(self._read_output)
        self._process.stateChanged.connect(self._on_state_changed)
        self._process.errorOccurred.connect(self._on_process_error)
        self._process.finished.connect(self._on_finished)

    @Property(str, notify=outputChanged)
    def output(self) -> str:
        return self._output

    @Property(bool, notify=runningChanged)
    def running(self) -> bool:
        return self._process.state() == QProcess.Running

    def _append_output(self, text: str) -> None:
        if not text:
            return
        self._output += text
        if len(self._output) > MAX_OUTPUT_CHARS:
            keep = self._output[-MAX_OUTPUT_CHARS:]
            cut = keep.find("\n")
            self._output = keep[cut + 1 :] if cut >= 0 else keep
        self.outputChanged.emit()

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

        self._append_output(text)

    def _on_state_changed(self, _state: QProcess.ProcessState) -> None:
        self.runningChanged.emit()

    def _on_process_error(self, error: QProcess.ProcessError) -> None:
        if error == QProcess.FailedToStart:
            message = self._process.errorString()
            self._prompt_pending = False
            self._startup_buffer = ""
            self._failed_to_start = True
            msg = self.tr(
                "pages.repl.startError",
                "[could not start Python: {message}]",
                message=message,
            )
            self._append_output(msg + "\n")
            self.replError.emit(message)

    def _on_finished(self, code: int, status: QProcess.ExitStatus) -> None:
        self.runningChanged.emit()
        if self._intentional_stop:
            return
        if self._failed_to_start:
            self._failed_to_start = False
            self._prompt_pending = False
            self._startup_buffer = ""
            return
        if self._prompt_pending and self._startup_buffer == "" and self._output.endswith(PROMPT):
            # Process ended before producing any session output beyond startup handling.
            self._prompt_pending = False
            return
        self._prompt_pending = False
        self._startup_buffer = ""
        msg = self.tr(
            "pages.repl.sessionEnded",
            "[session ended (code {code})]",
            code=code,
        )
        prefix = "" if self._output.endswith("\n") else "\n"
        self._append_output(prefix + msg + "\n")

    @Slot()
    def start(self) -> None:
        if self._process.state() != QProcess.NotRunning:
            return
        self._intentional_stop = False
        self._failed_to_start = False
        self._prompt_pending = True
        self._startup_buffer = ""
        self._process.start(sys.executable, ["-u", "-i", "-q"])

    @Slot(str)
    def submit(self, command: str) -> None:
        if self._process.state() == QProcess.NotRunning:
            self.start()
        self._append_output(command + "\n")
        self.record_history("REPL", "Command", command, "")
        payload = QByteArray((command + "\n").encode("utf-8"))
        if self._process.state() == QProcess.NotRunning:
            # Failed to start; output already echoed and start error will be reported.
            return
        self._process.write(payload)

    @Slot()
    def clear(self) -> None:
        self._output = PROMPT
        self.outputChanged.emit()

    @Slot()
    def restart(self) -> None:
        self._intentional_stop = True
        if self._process.state() != QProcess.NotRunning:
            self._process.kill()
            self._process.waitForFinished(2000)
        self._intentional_stop = False
        self._output = PROMPT
        self._prompt_pending = True
        self._startup_buffer = ""
        self.outputChanged.emit()
        self.start()

    @Slot()
    def stop(self) -> None:
        if self._process.state() == QProcess.NotRunning:
            return
        self._intentional_stop = True
        self._process.kill()
        self._process.waitForFinished(2000)
        self._intentional_stop = False
