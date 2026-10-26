import json
import os
import re
import shutil
from pathlib import Path
from urllib.parse import urlparse

from PySide6.QtCore import Property, QObject, QProcess, QStandardPaths, Signal, Slot
from PySide6.QtGui import QDesktopServices

from .base_vm import BaseVM


class DownloadVM(BaseVM):
    urlChanged = Signal()
    destinationChanged = Signal()
    progressChanged = Signal()
    statusChanged = Signal()
    downloadingChanged = Signal()
    errorChanged = Signal()
    queueChanged = Signal()
    historyChanged = Signal()
    filenameChanged = Signal()
    speedChanged = Signal()
    etaChanged = Signal()
    sizeChanged = Signal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._url = ""
        self._destination = str(Path.home() / "Downloads")
        self._progress = 0.0
        self._status = "Idle"
        self._downloading = False
        self._paused = False
        self._error = ""
        self._filename = ""
        self._speed = ""
        self._eta = ""
        self._size = ""
        self._process: QProcess | None = None
        self._queue: list[dict] = []
        self._history: list[dict] = []
        self._current_job: dict | None = None
        self._progress_re = re.compile(
            r"\[#\w+\s+([\d.]+)([KMG]i?B)/([\d.]+)([KMG]i?B)\((\d+)%\)[^\]]*?DL:([^\s]+)[^\]]*?ETA:([^\]]+)"
        )
        self._progress_re2 = re.compile(
            r"\[#\w+\s+([\d.]+)([KMG]i?B)/([\d.]+)([KMG]i?B)\((\d+)%\)"
        )
        self._history_path = (
            Path(__file__).parent.parent.parent / "resources" / "runtime" / "download_history.json"
        )
        self._load_history()

    def _emit_all(self) -> None:
        self.urlChanged.emit()
        self.destinationChanged.emit()
        self.progressChanged.emit()
        self.statusChanged.emit()
        self.downloadingChanged.emit()
        self.errorChanged.emit()
        self.queueChanged.emit()
        self.historyChanged.emit()
        self.filenameChanged.emit()
        self.speedChanged.emit()
        self.etaChanged.emit()
        self.sizeChanged.emit()

    @Property(str, notify=urlChanged)
    def url(self) -> str:
        return self._url

    @url.setter
    def url(self, value: str) -> None:
        if value != self._url:
            self._url = value
            self.urlChanged.emit()

    @Property(str, notify=destinationChanged)
    def destination(self) -> str:
        return self._destination

    @destination.setter
    def destination(self, value: str) -> None:
        if value != self._destination:
            self._destination = value
            self.destinationChanged.emit()

    @Property(float, notify=progressChanged)
    def progress(self) -> float:
        return self._progress

    @Property(str, notify=statusChanged)
    def status(self) -> str:
        return self._status

    @Property(bool, notify=downloadingChanged)
    def downloading(self) -> bool:
        return self._downloading

    @Property(str, notify=errorChanged)
    def error(self) -> str:
        return self._error

    @Property(str, notify=filenameChanged)
    def filename(self) -> str:
        return self._filename

    @Property(str, notify=speedChanged)
    def speed(self) -> str:
        return self._speed

    @Property(str, notify=etaChanged)
    def eta(self) -> str:
        return self._eta

    @Property(str, notify=sizeChanged)
    def size(self) -> str:
        return self._size

    @Property(list, notify=queueChanged)
    def queue(self) -> list:
        return self._queue

    @Property(list, notify=historyChanged)
    def history(self) -> list:
        return self._history

    @Slot(str)
    def setUrl(self, value: str) -> None:
        self.url = value

    @Slot(str)
    def setDestination(self, value: str) -> None:
        self.destination = value

    @Slot()
    def pasteFromClipboard(self) -> None:
        try:
            from PySide6.QtGui import QGuiApplication

            text = QGuiApplication.clipboard().text()
            if text and text.strip():
                self.url = text.strip()
                self.urlChanged.emit()
        except Exception:
            pass

    @Slot()
    def addToQueue(self) -> None:
        if not self._url.strip():
            self._error = "Enter a URL"
            self.errorChanged.emit()
            return
        if not self._is_valid_url(self._url.strip()):
            self._error = "Invalid URL"
            self.errorChanged.emit()
            return
        self._queue.append({"url": self._url.strip(), "destination": self._destination})
        self.queueChanged.emit()
        self._error = ""
        self.errorChanged.emit()
        if not self._downloading:
            self._start_next_in_queue()

    @Slot()
    def clearQueue(self) -> None:
        self._queue = []
        self.queueChanged.emit()

    @Slot(int)
    def removeFromQueue(self, index: int) -> None:
        if 0 <= index < len(self._queue):
            self._queue.pop(index)
            self.queueChanged.emit()

    def _is_valid_url(self, url: str) -> bool:
        try:
            p = urlparse(url)
            return p.scheme in ("http", "https", "ftp", "ftps") and bool(p.netloc)
        except Exception:
            return False

    def _load_history(self) -> None:
        try:
            if self._history_path.exists():
                with open(self._history_path) as f:
                    data = json.load(f)
                if isinstance(data, list):
                    self._history = data
        except Exception:
            self._history = []

    def _save_history(self) -> None:
        try:
            self._history_path.parent.mkdir(parents=True, exist_ok=True)
            with open(self._history_path, "w") as f:
                json.dump(self._history, f, indent=2)
        except Exception:
            pass

    def _add_to_history(self, url: str, path: str) -> None:
        self._history.insert(0, {"url": url, "path": path, "time": __import__("time").time()})
        if len(self._history) > 100:
            self._history = self._history[:100]
        self._save_history()
        self.historyChanged.emit()

    @Slot()
    def openDestination(self) -> None:
        try:
            from PySide6.QtCore import QUrl

            QDesktopServices.openUrl(QUrl.fromLocalFile(os.path.abspath(self._destination)))
        except Exception:
            pass

    @Slot()
    def startDownload(self) -> None:
        if self._downloading:
            return
        if not self._url.strip():
            self._error = "Enter a URL"
            self.errorChanged.emit()
            return
        if not self._is_valid_url(self._url.strip()):
            self._error = "Invalid URL"
            self.errorChanged.emit()
            return
        aria2 = shutil.which("aria2c")
        if aria2 is None:
            self._error = "aria2c not found in PATH"
            self.errorChanged.emit()
            return
        Path(self._destination).mkdir(parents=True, exist_ok=True)
        self._error = ""
        self._progress = 0.0
        self._filename = ""
        self._speed = ""
        self._eta = ""
        self._size = ""
        self._status = "Starting..."
        self._downloading = True
        self._paused = False
        self.progressChanged.emit()
        self.statusChanged.emit()
        self.downloadingChanged.emit()
        self.errorChanged.emit()
        self.filenameChanged.emit()
        self.speedChanged.emit()
        self.etaChanged.emit()
        self.sizeChanged.emit()

        proc = QProcess(self)
        proc.setProgram(aria2)
        proc.setArguments(
            [
                "-d",
                self._destination,
                self._url.strip(),
                "--summary-interval=1",
                "--continue=true",
                "--max-tries=5",
                "--retry-wait=3",
            ]
        )
        proc.readyReadStandardOutput.connect(self._on_stdout)
        proc.readyReadStandardError.connect(self._on_stderr)
        proc.finished.connect(self._on_finished)
        self._process = proc
        proc.start()

    def _start_next_in_queue(self) -> None:
        if self._downloading or not self._queue:
            return
        job = self._queue.pop(0)
        self.queueChanged.emit()
        self._url = job["url"]
        self.urlChanged.emit()
        self._destination = job.get("destination", self._destination)
        self.destinationChanged.emit()
        self._current_job = job
        self.startDownload()

    @Slot()
    def cancel(self) -> None:
        if self._process is not None:
            try:
                self._process.kill()
            except Exception:
                pass
        self._downloading = False
        self._paused = False
        self._status = "Cancelled"
        self.downloadingChanged.emit()
        self.statusChanged.emit()
        self._process = None

    @Slot()
    def pause(self) -> None:
        if self._process is None or self._paused:
            return
        try:
            os.kill(self._process.processId(), __import__("signal").SIGSTOP)
            self._paused = True
            self._status = "Paused"
            self.statusChanged.emit()
        except Exception:
            pass

    @Slot()
    def resume(self) -> None:
        if self._process is None or not self._paused:
            return
        try:
            os.kill(self._process.processId(), __import__("signal").SIGCONT)
            self._paused = False
            self._status = "Resuming..."
            self.statusChanged.emit()
        except Exception:
            pass

    @Slot()
    def retry(self) -> None:
        if self._downloading:
            return
        self.startDownload()

    def _on_stdout(self) -> None:
        if self._process is None:
            return
        data = bytes(self._process.readAllStandardOutput()).decode("utf-8", "replace")
        for line in data.splitlines():
            m = self._progress_re.search(line)
            if m:
                try:
                    percent = int(m.group(5))
                    self._progress = percent / 100.0
                    self.progressChanged.emit()
                    self._speed = m.group(6)
                    self._eta = m.group(7).strip()
                    self.speedChanged.emit()
                    self.etaChanged.emit()
                    self._size = f"{m.group(1)}{m.group(2)}/{m.group(3)}{m.group(4)}"
                    self.sizeChanged.emit()
                except Exception:
                    pass
            else:
                m2 = self._progress_re2.search(line)
                if m2:
                    try:
                        percent = int(m2.group(5))
                        self._progress = percent / 100.0
                        self.progressChanged.emit()
                        self._size = f"{m2.group(1)}{m2.group(2)}/{m2.group(3)}{m2.group(4)}"
                        self.sizeChanged.emit()
                    except Exception:
                        pass
            if line.strip():
                self._status = line.strip()
                self.statusChanged.emit()
                if "File:" in line or "file" in line.lower():
                    # try to extract filename
                    try:
                        if "[" in line and "]" in line:
                            pass
                    except Exception:
                        pass

    def _on_stderr(self) -> None:
        if self._process is None:
            return
        data = bytes(self._process.readAllStandardError()).decode("utf-8", "replace")
        if data.strip():
            self._error = data.strip()
            self.errorChanged.emit()

    def _on_finished(self, code: int, status) -> None:
        was_downloading = self._downloading
        self._downloading = False
        self._paused = False
        self.downloadingChanged.emit()
        if code == 0:
            self._progress = 1.0
            self._status = "Done"
            self.progressChanged.emit()
            self.statusChanged.emit()
            if self._url:
                path = os.path.join(self._destination, os.path.basename(urlparse(self._url).path) or "downloaded")
                self._add_to_history(self._url, path)
        else:
            if not self._error:
                self._error = f"aria2 exited with code {code}"
                self.errorChanged.emit()
            self._status = "Failed"
            self.statusChanged.emit()
        self._process = None
        if was_downloading and self._queue:
            self._start_next_in_queue()
