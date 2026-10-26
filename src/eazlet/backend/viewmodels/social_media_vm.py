import json
import os
import re
import shutil
from pathlib import Path

from PySide6.QtCore import Property, QObject, QProcess, Signal, Slot
from PySide6.QtGui import QDesktopServices

from .base_vm import BaseVM


class SocialMediaVM(BaseVM):
    urlChanged = Signal()
    destinationChanged = Signal()
    formatsChanged = Signal()
    statusChanged = Signal()
    downloadingChanged = Signal()
    progressChanged = Signal()
    errorChanged = Signal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._url = ""
        self._destination = str(Path.home() / "Downloads")
        self._formats = []
        self._selected_format = ""
        self._audio_only = False
        self._status = "Idle"
        self._downloading = False
        self._progress = 0.0
        self._error = ""
        self._process: QProcess | None = None
        self._progress_re = re.compile(r"(\d+(?:\.\d+)?)%")

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

    @Property(list, notify=formatsChanged)
    def formats(self) -> list:
        return self._formats

    selectedFormatChanged = Signal()

    @Property(str, notify=selectedFormatChanged)
    def selectedFormat(self) -> str:
        return self._selected_format

    @selectedFormat.setter
    def selectedFormat(self, value: str) -> None:
        if value != self._selected_format:
            self._selected_format = value
            self.selectedFormatChanged.emit()

    audioOnlyChanged = Signal()

    @Property(bool, notify=audioOnlyChanged)
    def audioOnly(self) -> bool:
        return self._audio_only

    @audioOnly.setter
    def audioOnly(self, value: bool) -> None:
        if bool(value) != self._audio_only:
            self._audio_only = bool(value)
            self.audioOnlyChanged.emit()

    @Property(str, notify=statusChanged)
    def status(self) -> str:
        return self._status

    @Property(bool, notify=downloadingChanged)
    def downloading(self) -> bool:
        return self._downloading

    @Property(float, notify=progressChanged)
    def progress(self) -> float:
        return self._progress

    @Property(str, notify=errorChanged)
    def error(self) -> str:
        return self._error

    @Slot(str)
    def setUrl(self, value: str) -> None:
        self.url = value

    @Slot(str)
    def setDestination(self, value: str) -> None:
        self.destination = value

    @Slot()
    def fetchFormats(self) -> None:
        if not self._url.strip():
            self._error = "Enter a URL"
            self.errorChanged.emit()
            return
        ytdlp = shutil.which("yt-dlp")
        if ytdlp is None:
            self._error = "yt-dlp not found in PATH"
            self.errorChanged.emit()
            return
        self._error = ""
        self.errorChanged.emit()
        self._status = "Fetching formats..."
        self.statusChanged.emit()
        proc = QProcess(self)
        proc.setProgram(ytdlp)
        proc.setArguments(["-J", "--no-playlist", self._url.strip()])
        proc.finished.connect(self._on_formats_finished)
        proc.start()
        self._formats_proc = proc

    def _on_formats_finished(self, code: int, status) -> None:
        if code != 0:
            try:
                err = bytes(self._formats_proc.readAllStandardError()).decode("utf-8", "replace")
                self._error = err[:200] if err else "Failed to fetch formats"
                self.errorChanged.emit()
            except Exception:
                self._error = "Failed to fetch formats"
                self.errorChanged.emit()
            self._status = "Failed to fetch formats"
            self.statusChanged.emit()
            return
        try:
            data = bytes(self._formats_proc.readAllStandardOutput()).decode("utf-8", "replace")
            info = json.loads(data)
            fmts = []
            for f in info.get("formats", []):
                if not f.get("format_id"):
                    continue
                fid = str(f.get("format_id"))
                ext = str(f.get("ext") or "")
                res = f.get("resolution") or f.get("format_note") or f.get("height") or ""
                if isinstance(res, int):
                    res = f"{res}p"
                elif res and isinstance(res, str) and res.isdigit():
                    res = f"{res}p"
                vcodec = f.get("vcodec") or ""
                acodec = f.get("acodec") or ""
                if vcodec == "none" and acodec == "none":
                    continue
                size = f.get("filesize") or f.get("filesize_approx")
                size_s = f" ~{size}" if size else ""
                label = f"{fid} | {ext} | {res} | v:{vcodec[:4]} a:{acodec[:4]}{size_s}".strip()
                fmts.append({"id": fid, "label": label})
            self._formats = fmts
            self.formatsChanged.emit()
            self._status = "Formats loaded" if fmts else "No formats found"
            self.statusChanged.emit()
        except Exception as e:
            self._error = str(e)
            self.errorChanged.emit()
            self._status = "Error"
            self.statusChanged.emit()

    @Slot()
    def startDownload(self) -> None:
        if self._downloading:
            return
        if not self._url.strip():
            self._error = "Enter a URL"
            self.errorChanged.emit()
            return
        ytdlp = shutil.which("yt-dlp")
        if ytdlp is None:
            self._error = "yt-dlp not found in PATH"
            self.errorChanged.emit()
            return
        Path(os.path.abspath(self._destination)).mkdir(parents=True, exist_ok=True)
        self._error = ""
        self._progress = 0.0
        self._status = "Starting..."
        self._downloading = True
        self.progressChanged.emit()
        self.statusChanged.emit()
        self.downloadingChanged.emit()
        self.errorChanged.emit()

        outtmpl = os.path.join(os.path.abspath(self._destination), "%(title)s.%(ext)s")
        if self._audio_only:
            args = ["-x", "--audio-format", "mp3", "-o", outtmpl, self._url.strip()]
        elif self._selected_format:
            args = ["-f", self._selected_format, "-o", outtmpl, self._url.strip()]
        else:
            args = ["-f", "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best", "-o", outtmpl, self._url.strip()]

        proc = QProcess(self)
        proc.setProgram(ytdlp)
        proc.setArguments(args)
        proc.readyReadStandardOutput.connect(self._on_stdout)
        proc.readyReadStandardError.connect(self._on_stderr)
        proc.finished.connect(self._on_finished)
        self._process = proc
        proc.start()

    @Slot()
    def cancel(self) -> None:
        if self._process is not None:
            try:
                self._process.kill()
            except Exception:
                pass
        self._downloading = False
        self._status = "Cancelled"
        self.downloadingChanged.emit()
        self.statusChanged.emit()
        self._process = None

    @Slot()
    def openDestination(self) -> None:
        try:
            from PySide6.QtCore import QUrl

            QDesktopServices.openUrl(QUrl.fromLocalFile(os.path.abspath(self._destination)))
        except Exception:
            pass

    def _on_stdout(self) -> None:
        if self._process is None:
            return
        data = bytes(self._process.readAllStandardOutput()).decode("utf-8", "replace")
        for line in data.splitlines():
            m = self._progress_re.search(line)
            if m:
                try:
                    self._progress = float(m.group(1)) / 100.0
                    self.progressChanged.emit()
                except Exception:
                    pass
            if line.strip():
                self._status = line.strip()
                self.statusChanged.emit()

    def _on_stderr(self) -> None:
        if self._process is None:
            return
        data = bytes(self._process.readAllStandardError()).decode("utf-8", "replace")
        if data.strip():
            self._error = data.strip()
            self.errorChanged.emit()

    def _on_finished(self, code: int, status) -> None:
        self._downloading = False
        self.downloadingChanged.emit()
        if code == 0:
            self._progress = 1.0
            self._status = "Done"
            self.progressChanged.emit()
            self.statusChanged.emit()
        else:
            if not self._error:
                self._error = f"yt-dlp exited with code {code}"
                self.errorChanged.emit()
            self._status = "Failed"
            self.statusChanged.emit()
        self._process = None
