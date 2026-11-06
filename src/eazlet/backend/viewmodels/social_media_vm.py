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
                vcodec = f.get("vcodec") or "none"
                acodec = f.get("acodec") or "none"
                if vcodec == "none" and acodec == "none":
                    continue
                height = f.get("height")
                try:
                    height_i = int(height) if height is not None else 0
                except Exception:
                    height_i = 0
                res = f.get("resolution") or f.get("format_note") or ""
                if height_i:
                    res = f"{height_i}p"
                elif isinstance(res, (int, float)):
                    res = f"{int(res)}p"
                elif isinstance(res, str) and res.strip().isdigit():
                    res = f"{res.strip()}p"
                if not res or str(res).lower() == "audio only":
                    res = "audio" if vcodec == "none" else "?"
                fps_raw = f.get("fps")
                fps_i = 0
                try:
                    if fps_raw is not None:
                        fps_i = int(round(float(fps_raw)))
                except Exception:
                    fps_i = 0
                if not fps_i and vcodec != "none":
                    note = str(f.get("format_note") or f.get("format") or "")
                    m_fps = re.search(r"(\d{2,3})\s*fps", note, re.IGNORECASE)
                    if m_fps:
                        try:
                            fps_i = int(m_fps.group(1))
                        except Exception:
                            fps_i = 0
                size = f.get("filesize") or f.get("filesize_approx")
                if isinstance(size, (int, float)) and size > 0:
                    if size >= 1024 * 1024 * 1024:
                        size_s = f" | ~{size / (1024 * 1024 * 1024):.1f}GB"
                    elif size >= 1024 * 1024:
                        size_s = f" | ~{size / (1024 * 1024):.0f}MB"
                    else:
                        size_s = f" | ~{size / 1024:.0f}KB"
                else:
                    size_s = ""
                fps_s = f" | {fps_i}fps" if fps_i else ""
                if vcodec == "none":
                    kind = "audio"
                    abr = f.get("abr")
                    abr_s = f" | {int(abr)}kbps" if isinstance(abr, (int, float)) and abr else ""
                    label = f"{fid} | {ext} | audio{abr_s}{size_s}".strip()
                else:
                    kind = "A+V" if acodec != "none" else "V"
                    label = f"{fid} | {ext} | {res}{fps_s} | {kind}{size_s}".strip()
                fmts.append({"id": fid, "label": label, "height": height_i, "fps": fps_i, "ext": ext, "is_audio": vcodec == "none"})

            def sort_key(x):
                if x.get("is_audio"):
                    return (1, 0, 0, 0, str(x.get("id") or ""))
                ext = str(x.get("ext") or "").lower()
                mp4_pref = 0 if ext == "mp4" else 1
                return (0, -int(x.get("height") or 0), -int(x.get("fps") or 0), mp4_pref, str(x.get("id") or ""))

            fmts = sorted(fmts, key=sort_key)
            seen = set()
            uniq = []
            for x in fmts:
                if x.get("is_audio"):
                    bucket = f"audio-{x.get('ext')}-{x['label']}"
                else:
                    bucket = f"v-{x.get('height')}-{x.get('fps')}-{x.get('ext')}-{'av' in x['label'].lower()}"
                count = sum(1 for s in seen if s == bucket)
                if count >= 2:
                    continue
                seen.add(bucket)
                uniq.append(x)
            fmts = uniq[:80]
            self._formats = [{"id": x["id"], "label": x["label"]} for x in fmts]
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
