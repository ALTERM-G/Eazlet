import json
import os
import re
import shutil
from pathlib import Path
from urllib.parse import urlparse

from PySide6.QtCore import Property, QObject, QProcess, QStandardPaths, Signal, Slot
from PySide6.QtGui import QDesktopServices

from .base_vm import BaseVM


class UnifiedDownloadVM(BaseVM):
    urlChanged = Signal()
    destinationChanged = Signal()
    modeChanged = Signal()
    formatsChanged = Signal()
    statusChanged = Signal()
    downloadingChanged = Signal()
    progressChanged = Signal()
    errorChanged = Signal()
    queueChanged = Signal()
    historyChanged = Signal()
    sizeChanged = Signal()
    speedChanged = Signal()
    etaChanged = Signal()
    audioOnlyChanged = Signal()
    selectedFormatChanged = Signal()

    SOCIAL_DOMAINS = [
        "youtube.com",
        "youtu.be",
        "tiktok.com",
        "instagram.com",
        "facebook.com",
        "fb.watch",
        "x.com",
        "twitter.com",
        "reddit.com",
        "vimeo.com",
        "twitch.tv",
        "soundcloud.com",
        "bilibili.com",
    ]

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._url = ""
        self._destination = str(Path.home() / "Downloads")
        self._mode = "direct"
        self._formats = []
        self._selected_format = ""
        self._audio_only = False
        self._status = "Idle"
        self._downloading = False
        self._progress = 0.0
        self._error = ""
        self._size = ""
        self._speed = ""
        self._eta = ""
        self._queue = []
        self._history = []
        self._process = None
        self._formats_proc = None
        self._progress_re = re.compile(r"(\d+(?:\.\d+)?)%")
        self._aria_progress_re = re.compile(r"\[#\w+\s+([\d.]+)([KMG]i?B)/([\d.]+)([KMG]i?B)\((\d+)%\)[^\]]*?DL:([^\s]+)[^\]]*?ETA:([^\]]+)")
        self._aria_progress_re2 = re.compile(r"\[#\w+\s+([\d.]+)([KMG]i?B)/([\d.]+)([KMG]i?B)\((\d+)%\)")
        self._ytdlp_size_re = re.compile(r"of\s+([\d.]+)([KMG]i?B)")
        self._ytdlp_speed_re = re.compile(r"at\s+([\d.]+)([KMG]i?B)/s")

    @Property(str, notify=urlChanged)
    def url(self) -> str:
        return self._url

    @url.setter
    def url(self, value: str) -> None:
        if value != self._url:
            self._url = value
            self.urlChanged.emit()
            self._detect_mode(value)
            if self._mode == "social" and value.strip():
                self.fetchFormats()

    @Property(str, notify=destinationChanged)
    def destination(self) -> str:
        return self._destination

    @destination.setter
    def destination(self, value: str) -> None:
        if value != self._destination:
            self._destination = value
            self.destinationChanged.emit()

    @Property(str, notify=modeChanged)
    def mode(self) -> str:
        return self._mode

    @Property(list, notify=formatsChanged)
    def formats(self) -> list:
        return self._formats

    @Property(str, notify=selectedFormatChanged)
    def selectedFormat(self) -> str:
        return self._selected_format

    @selectedFormat.setter
    def selectedFormat(self, value: str) -> None:
        if value != self._selected_format:
            self._selected_format = value
            self.selectedFormatChanged.emit()

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

    @Property(str, notify=sizeChanged)
    def size(self) -> str:
        return self._size

    @Property(str, notify=speedChanged)
    def speed(self) -> str:
        return self._speed

    @Property(str, notify=etaChanged)
    def eta(self) -> str:
        return self._eta

    @Property(list, notify=queueChanged)
    def queue(self) -> list:
        return self._queue

    @Property(list, notify=historyChanged)
    def history(self) -> list:
        return self._history

    def _detect_mode(self, url: str) -> None:
        try:
            p = urlparse(url.strip())
            host = p.netloc.lower()
            if host.startswith("www."):
                host = host[4:]
            for d in self.SOCIAL_DOMAINS:
                if host == d or host.endswith("." + d):
                    if self._mode != "social":
                        self._mode = "social"
                        self.modeChanged.emit()
                    self.formats = []
                    self.formatsChanged.emit()
                    return
            if self._mode != "direct":
                self._mode = "direct"
                self.modeChanged.emit()
        except Exception:
            pass

    @Slot(str)
    def setUrl(self, value: str) -> None:
        self.url = value
        if self._mode == "social" and value.strip():
            self.fetchFormats()

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
                if self._mode == "social":
                    self.fetchFormats()
        except Exception:
            pass

    @Slot()
    def chooseDestination(self) -> None:
        pass

    @Slot()
    def fetchFormats(self) -> None:
        if self._mode != "social" or not self._url.strip():
            return
        ytdlp = shutil.which("yt-dlp")
        if ytdlp is None:
            self._error = "yt-dlp not found in PATH"
            self.errorChanged.emit()
            self._status = "Failed"
            self.statusChanged.emit()
            return
        self._error = ""
        self.errorChanged.emit()
        self._status = "Fetching formats..."
        self.statusChanged.emit()
        proc = QProcess(self)
        proc.setProgram(ytdlp)
        proc.setArguments(["-J", "--no-playlist", "--ignore-errors", self._url.strip()])
        proc.finished.connect(self._on_formats_finished)
        proc.start()
        self._formats_proc = proc

    def _on_formats_finished(self, code: int, status) -> None:
        if code != 0:
            try:
                err = bytes(self._formats_proc.readAllStandardError()).decode("utf-8", "replace") if self._formats_proc else ""
                if err.strip():
                    self._error = err.strip()[:240]
                else:
                    self._error = f"yt-dlp exited with code {code}"
                self.errorChanged.emit()
            except Exception:
                self._error = "Failed to fetch formats"
                self.errorChanged.emit()
            self._status = "Failed"
            self.statusChanged.emit()
            self._formats_proc = None
            return
        try:
            if not self._formats_proc:
                return
            data = bytes(self._formats_proc.readAllStandardOutput()).decode("utf-8", "replace")
            try:
                info = json.loads(data)
            except Exception:
                self._error = "Failed to parse formats"
                self.errorChanged.emit()
                self._status = "Failed"
                self.statusChanged.emit()
                self._formats_proc = None
                return
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
                res = f.get("resolution") or f.get("format_note") or ""
                if isinstance(res, int):
                    res = f"{res}p"
                elif isinstance(res, str) and res.isdigit():
                    res = f"{res}p"
                height = f.get("height")
                if height and isinstance(height, int):
                    res = f"{height}p"
                fps = f.get("fps")
                if vcodec != "none" and acodec != "none":
                    label = f"{fid} | {ext} | {res} | {fps if fps else ''}fps | A+V".strip().replace("  ", " ")
                elif vcodec != "none":
                    label = f"{fid} | {ext} | {res} | {fps if fps else ''}fps | V".strip().replace("  ", " ")
                else:
                    continue
                fmts.append({"id": fid, "label": label, "height": height or 0})
            def sort_key(x):
                l = x["label"].lower()
                score = 0
                if "mp4" in l:
                    score -= 10
                h = x.get("height") or 0
                score -= h
                if "60" in l or "50" in l:
                    score -= 1
                return score
            fmts = sorted(fmts, key=sort_key)
            fmts = fmts[:30]
            self._formats = fmts
            self.formatsChanged.emit()
            self._status = "Formats loaded"
            self.statusChanged.emit()
        except Exception as e:
            self._error = str(e)[:240]
            self.errorChanged.emit()
            self._status = "Error"
            self.statusChanged.emit()
        finally:
            self._formats_proc = None

    @Slot()
    def startDownload(self) -> None:
        if self._downloading:
            return
        if not self._url.strip():
            self._error = "Enter a URL"
            self.errorChanged.emit()
            return
        # resolve short URLs
        try:
            import urllib.request

            req = urllib.request.Request(self._url.strip(), headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=5) as resp:
                final = resp.geturl()
                if final and final != self._url.strip():
                    self._url = final
                    self.urlChanged.emit()
                    self._detect_mode(final)
        except Exception:
            pass
        Path(os.path.abspath(self._destination)).mkdir(parents=True, exist_ok=True)
        self._error = ""
        self._progress = 0.0
        self._size = ""
        self._speed = ""
        self._eta = ""
        self._status = "Starting..."
        self._downloading = True
        self.progressChanged.emit()
        self.statusChanged.emit()
        self.downloadingChanged.emit()
        self.errorChanged.emit()
        self.sizeChanged.emit()
        self.speedChanged.emit()
        self.etaChanged.emit()

        if self._mode == "social":
            ytdlp = shutil.which("yt-dlp")
            if ytdlp is None:
                self._error = "yt-dlp not found in PATH"
                self.errorChanged.emit()
                self._downloading = False
                self.downloadingChanged.emit()
                return
            outtmpl = os.path.join(os.path.abspath(self._destination), "%(title)s.%(ext)s")
            if self._audio_only:
                args = ["-x", "--audio-format", "mp3", "--no-playlist", "-o", outtmpl, self._url.strip()]
            elif self._selected_format:
                if shutil.which("ffmpeg") is None:
                    self._error = "ffmpeg not found in PATH (required to merge video+audio). Install ffmpeg or choose a format that doesn't require merging."
                    self.errorChanged.emit()
                    self._downloading = False
                    self.downloadingChanged.emit()
                    return
                args = ["-f", self._selected_format + "+bestaudio/best", "--no-playlist", "--merge-output-format", "mp4", "-o", outtmpl, self._url.strip()]
            else:
                if shutil.which("ffmpeg") is None:
                    # try to fall back to best single stream
                    args = ["-f", "best[ext=mp4]/best", "--no-playlist", "-o", outtmpl, self._url.strip()]
                else:
                    args = ["-f", "bestvideo*+bestaudio/best", "--no-playlist", "--merge-output-format", "mp4", "-o", outtmpl, self._url.strip()]
            proc = QProcess(self)
            proc.setProgram(ytdlp)
            proc.setArguments(args)
            proc.readyReadStandardOutput.connect(self._on_stdout)
            proc.readyReadStandardError.connect(self._on_stderr)
            proc.finished.connect(self._on_finished)
            self._process = proc
            proc.start()
        else:
            aria2 = shutil.which("aria2c")
            if aria2 is None:
                self._error = "aria2c not found in PATH"
                self.errorChanged.emit()
                self._downloading = False
                self.downloadingChanged.emit()
                return
            proc = QProcess(self)
            proc.setProgram(aria2)
            proc.setArguments(["-d", os.path.abspath(self._destination), self._url.strip(), "--summary-interval=1", "--continue=true", "--max-tries=5", "--retry-wait=3", "--max-connection-per-server=16", "--split=16", "--file-allocation=none"])
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
                self._process.waitForFinished(1000)
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

    @Slot()
    def forceDirect(self) -> None:
        if self._mode != "direct":
            self._mode = "direct"
            self.modeChanged.emit()

    @Slot()
    def forceSocial(self) -> None:
        if self._mode != "social":
            self._mode = "social"
            self.modeChanged.emit()

    def _on_stdout(self) -> None:
        if self._process is None:
            return
        data = bytes(self._process.readAllStandardOutput()).decode("utf-8", "replace")
        for line in data.splitlines():
            if self._mode == "direct":
                m = self._aria_progress_re.search(line)
                if m:
                    try:
                        percent = int(m.group(5))
                        self._progress = max(0.0, min(1.0, percent / 100.0))
                        self.progressChanged.emit()
                        self._speed = m.group(6)
                        self._eta = m.group(7).strip()
                        self._size = f"{m.group(1)}{m.group(2)}/{m.group(3)}{m.group(4)}"
                        self.speedChanged.emit()
                        self.etaChanged.emit()
                        self.sizeChanged.emit()
                    except Exception:
                        pass
                else:
                    m2 = self._aria_progress_re2.search(line)
                    if m2:
                        try:
                            percent = int(m2.group(5))
                            self._progress = max(0.0, min(1.0, percent / 100.0))
                            self.progressChanged.emit()
                            self._size = f"{m2.group(1)}{m2.group(2)}/{m2.group(3)}{m2.group(4)}"
                            self.sizeChanged.emit()
                        except Exception:
                            pass
            else:
                m = self._progress_re.search(line)
                if m:
                    try:
                        self._progress = max(0.0, min(1.0, float(m.group(1)) / 100.0))
                        self.progressChanged.emit()
                    except Exception:
                        pass
                ms = self._ytdlp_speed_re.search(line)
                if ms:
                    try:
                        self._speed = f"{ms.group(1)}{ms.group(2)}/s"
                        self.speedChanged.emit()
                    except Exception:
                        pass
                mz = self._ytdlp_size_re.search(line)
                if mz:
                    try:
                        self._size = f"{mz.group(1)}{mz.group(2)}"
                        self.sizeChanged.emit()
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
            err = data.strip()
            if len(err) > 300:
                err = err[:300] + "..."
            if not self._error:
                self._error = err
                self.errorChanged.emit()
            # also update status with last meaningful line
            lines = [l.strip() for l in err.splitlines() if l.strip()]
            if lines:
                self._status = lines[-1]
                self.statusChanged.emit()

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
                self._error = f"Process exited with code {code}"
                self.errorChanged.emit()
            if self._status not in ("Failed", "Cancelled"):
                self._status = "Failed"
                self.statusChanged.emit()
        self._process = None
