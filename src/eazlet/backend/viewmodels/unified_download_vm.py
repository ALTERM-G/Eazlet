import json
import os
import re
import shutil
from pathlib import Path
from urllib.parse import urlparse

from PySide6.QtCore import Property, QObject, QProcess, Signal, Slot
from PySide6.QtGui import QDesktopServices

from .base_vm import BaseVM

SOCIAL_DOMAINS = (
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
)

# Domain-specific downloaders. Insertion order is the detection order, so the
# dedicated tools come before yt-dlp and gallery-dl, which support many of the
# same hosts but are less precise about what the user is after.
DOWNLOADERS = {
    "khinsider-dl": {
        "label": "khinsider-dl",
        "title": "Khinsider Download",
        "hint": "Paste a downloads.khinsider.com album link to download its soundtrack.",
        "domains": ("downloads.khinsider.com", "khinsider.com"),
        "binaries": ("khidl", "khinsider.py", "khinsider-dl"),
        "requires_ffmpeg": False,
    },
    "spotdl": {
        "label": "spotDL",
        "title": "Spotify Download",
        "hint": "Paste a Spotify track, album, or playlist link. spotDL saves the tracks as MP3.",
        "domains": ("open.spotify.com", "spotify.com"),
        "binaries": ("spotdl", "spotDL"),
        "requires_ffmpeg": True,
    },
    "bandcamp-dl": {
        "label": "bandcamp-dl",
        "title": "Bandcamp Download",
        "hint": "Paste a Bandcamp track or album link to download it with bandcamp-dl.",
        "domains": ("bandcamp.com",),
        "binaries": ("bandcamp-dl",),
        "requires_ffmpeg": False,
    },
    "yt-dlp": {
        "label": "yt-dlp",
        "title": "Social Media Download",
        "hint": (
            "Paste a video or track link from a supported site, choose a format, "
            "then download."
        ),
        # yt-dlp is the fallback for Bandcamp when bandcamp-dl is not installed.
        "domains": (*SOCIAL_DOMAINS, "bandcamp.com"),
        "binaries": ("yt-dlp",),
        "requires_ffmpeg": False,
    },
    "gallery-dl": {
        "label": "gallery-dl",
        "title": "Gallery Download",
        "hint": "Paste an image gallery link to download it with gallery-dl.",
        "domains": (
            "pixiv.net",
            "danbooru.donmai.us",
            "gelbooru.com",
            "safebooru.org",
            "deviantart.com",
            "artstation.com",
            "imgur.com",
            "flickr.com",
            "tumblr.com",
            "pinterest.com",
            "pin.it",
            "newgrounds.com",
            "mangadex.org",
            "webtoons.com",
            "patreon.com",
        ),
        "binaries": ("gallery-dl",),
        "requires_ffmpeg": False,
    },
}

DOWNLOADER_CHOICES = [
    {"id": "auto", "label": "Auto (by URL)"},
    {"id": "direct", "label": "Direct file"},
    *(
        {"id": tool_id, "label": spec["label"]}
        for tool_id, spec in DOWNLOADERS.items()
    ),
]


def _host_of(url: str) -> str:
    source = (url or "").strip()
    if not source:
        return ""
    if "://" not in source:
        source = "https://" + source
    try:
        host = urlparse(source).hostname or ""
    except ValueError:
        return ""
    return host[4:] if host.startswith("www.") else host


def detect_downloader(url: str, available: set[str] | None = None) -> str:
    """Pick the downloader for a URL, falling back to a plain file download.

    When ``available`` is given, tools that are not installed are skipped so a
    host that yt-dlp can also handle keeps working without the dedicated tool.
    """

    host = _host_of(url)
    if not host:
        return "direct"
    matches = [
        tool_id
        for tool_id, spec in DOWNLOADERS.items()
        if any(host == d or host.endswith("." + d) for d in spec["domains"])
    ]
    if not matches:
        return "direct"
    if available is not None:
        for tool_id in matches:
            if tool_id in available:
                return tool_id
    return matches[0]


class UnifiedDownloadVM(BaseVM):
    urlChanged = Signal()
    destinationChanged = Signal()
    downloaderChanged = Signal()
    autoDetectChanged = Signal()
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

    SOCIAL_DOMAINS = list(SOCIAL_DOMAINS)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._url = ""
        self._destination = str(Path.home() / "Downloads")
        self._downloader = "direct"
        self._manual_downloader = False
        self._available_downloaders = self._installed_downloaders()
        self._formats = []
        self._selected_format = ""
        self._audio_only = False
        self._status = ""
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
        self._stderr_tail = ""
        self._progress_re = re.compile(r"(\d+(?:\.\d+)?)%")
        self._aria_progress_re = re.compile(
            r"\[#\w+\s+([\d.]+)([KMG]i?B)/([\d.]+)([KMG]i?B)\((\d+)%\)"
            r"[^\]]*?DL:([^\s]+)[^\]]*?ETA:([^\]]+)"
        )
        self._aria_progress_re2 = re.compile(
            r"\[#\w+\s+([\d.]+)([KMG]i?B)/([\d.]+)([KMG]i?B)\((\d+)%\)"
        )
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
            self._refresh_downloader()

    @Property(str, notify=destinationChanged)
    def destination(self) -> str:
        return self._destination

    @destination.setter
    def destination(self, value: str) -> None:
        if value != self._destination:
            self._destination = value
            self.destinationChanged.emit()

    @Property(str, notify=downloaderChanged)
    def downloader(self) -> str:
        return self._downloader

    @Property(bool, notify=autoDetectChanged)
    def autoDetect(self) -> bool:
        return not self._manual_downloader

    @Property(list, notify=downloaderChanged)
    def downloaders(self) -> list:
        return DOWNLOADER_CHOICES

    @Property(str, notify=downloaderChanged)
    def title(self) -> str:
        if self._downloader == "direct":
            return "Direct Download"
        return DOWNLOADERS[self._downloader]["title"]

    @Property(str, notify=downloaderChanged)
    def hint(self) -> str:
        if self._downloader == "direct":
            return "Paste a direct file link, choose where to save it, then download."
        return DOWNLOADERS[self._downloader]["hint"]

    @Property(bool, notify=downloaderChanged)
    def supportsFormats(self) -> bool:
        return self._downloader == "yt-dlp"

    @Property(str, notify=downloaderChanged)
    def mode(self) -> str:
        # Kept for QML written against the old two-mode API.
        return "direct" if self._downloader == "direct" else "social"

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

    def _refresh_downloader(self) -> None:
        if self._manual_downloader:
            return
        detected = detect_downloader(self._url, self._available_downloaders)
        self._set_downloader(detected)
        if detected == "yt-dlp" and self._url.strip():
            self.fetchFormats()

    def _set_downloader(self, tool_id: str) -> None:
        if tool_id != "direct" and tool_id not in DOWNLOADERS:
            tool_id = "direct"
        if tool_id == self._downloader:
            return
        self._downloader = tool_id
        self._formats = []
        self._selected_format = ""
        self.selectedFormatChanged.emit()
        self.formatsChanged.emit()
        self.downloaderChanged.emit()

    @Slot(str)
    def setDownloader(self, value: str) -> None:
        choice = (value or "").strip()
        if choice in ("", "auto"):
            if self._manual_downloader:
                self._manual_downloader = False
                self.autoDetectChanged.emit()
            self._refresh_downloader()
            return
        if choice != "direct" and choice not in DOWNLOADERS:
            return
        if self._manual_downloader is False:
            self._manual_downloader = True
            self.autoDetectChanged.emit()
        self._set_downloader(choice)
        if choice == "yt-dlp" and self._url.strip():
            self.fetchFormats()

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
        except Exception:
            pass

    @Slot()
    def chooseDestination(self) -> None:
        pass

    @Slot()
    def fetchFormats(self) -> None:
        if self._downloader != "yt-dlp" or not self._url.strip():
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
                raw = (
                    bytes(self._formats_proc.readAllStandardError()).decode(
                        "utf-8", "replace"
                    )
                    if self._formats_proc
                    else ""
                )
                err = raw
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
                if vcodec == "none":
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
                    res = "?"
                fps_raw = f.get("fps")
                fps_i = 0
                try:
                    if fps_raw is not None:
                        fps_i = int(round(float(fps_raw)))
                except Exception:
                    fps_i = 0
                if not fps_i:
                    note = str(f.get("format_note") or f.get("format") or "")
                    m_fps = re.search(r"(\d{2,3})\s*fps", note, re.IGNORECASE)
                    if m_fps:
                        try:
                            fps_i = int(m_fps.group(1))
                        except Exception:
                            fps_i = 0
                fps_s = f" | {fps_i}fps" if fps_i else ""
                kind = "A+V" if acodec != "none" else "V"
                label = f"{fid} | {ext} | {res}{fps_s} | {kind}"
                fmts.append(
                    {
                        "id": fid,
                        "label": label,
                        "height": height_i,
                        "fps": fps_i,
                        "ext": ext,
                    }
                )

            def sort_key(x):
                ext = str(x.get("ext") or "").lower()
                mp4_pref = 0 if ext == "mp4" else 1
                return (
                    -int(x.get("height") or 0),
                    -int(x.get("fps") or 0),
                    mp4_pref,
                    str(x.get("id") or ""),
                )

            fmts = sorted(fmts, key=sort_key)
            seen = set()
            uniq = []
            for x in fmts:
                k = (x.get("height"), x.get("fps"), x.get("ext"), "A+V" in x["label"])
                bucket = f"{k}"
                count = sum(1 for s in seen if s == bucket)
                if count >= 2:
                    continue
                seen.add(bucket)
                uniq.append(x)
            fmts = uniq[:60]
            self._formats = [{"id": x["id"], "label": x["label"]} for x in fmts]
            self.formatsChanged.emit()
            self._status = "Formats loaded" if fmts else "No formats found"
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
        try:
            import urllib.request

            req = urllib.request.Request(self._url.strip(), headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=5) as resp:
                final = resp.geturl()
                if final and final != self._url.strip():
                    self._url = final
                    self.urlChanged.emit()
                    self._refresh_downloader()
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

        if self._downloader == "yt-dlp":
            self._start_ytdlp()
        elif self._downloader == "direct":
            self._start_aria2()
        else:
            self._start_tool(self._downloader)

    def _fail(self, message: str) -> None:
        self._error = message
        self.errorChanged.emit()
        self._downloading = False
        self.downloadingChanged.emit()
        self._status = "Failed"
        self.statusChanged.emit()

    def _start_process(
        self,
        program: str,
        args: list[str],
        working_directory: str | None = None,
    ) -> None:
        self._stderr_tail = ""
        proc = QProcess(self)
        proc.setProgram(program)
        proc.setArguments(args)
        if working_directory:
            proc.setWorkingDirectory(working_directory)
        proc.readyReadStandardOutput.connect(self._on_stdout)
        proc.readyReadStandardError.connect(self._on_stderr)
        proc.finished.connect(self._on_finished)
        self._process = proc
        proc.start()

    def _start_ytdlp(self) -> None:
        ytdlp = shutil.which("yt-dlp")
        if ytdlp is None:
            self._fail("yt-dlp not found in PATH")
            return
        outtmpl = os.path.join(os.path.abspath(self._destination), "%(title)s.%(ext)s")
        if self._audio_only:
            args = [
                "-x",
                "--audio-format",
                "mp3",
                "--no-playlist",
                "-o",
                outtmpl,
                self._url.strip(),
            ]
        elif self._selected_format:
            if shutil.which("ffmpeg") is None:
                self._fail(
                    "ffmpeg not found in PATH (required to merge video+audio). "
                    "Install ffmpeg or choose a format that doesn't require merging."
                )
                return
            args = [
                "-f",
                self._selected_format + "+bestaudio/best",
                "--no-playlist",
                "--merge-output-format",
                "mp4",
                "-o",
                outtmpl,
                self._url.strip(),
            ]
        else:
            if shutil.which("ffmpeg") is None:
                args = [
                    "-f",
                    "best[ext=mp4]/best",
                    "--no-playlist",
                    "-o",
                    outtmpl,
                    self._url.strip(),
                ]
            else:
                args = [
                    "-f",
                    "bestvideo*+bestaudio/best",
                    "--no-playlist",
                    "--merge-output-format",
                    "mp4",
                    "-o",
                    outtmpl,
                    self._url.strip(),
                ]
        self._start_process(ytdlp, args)

    def _start_aria2(self) -> None:
        aria2 = shutil.which("aria2c")
        if aria2 is None:
            self._fail("aria2c not found in PATH")
            return
        args = [
            "-d",
            os.path.abspath(self._destination),
            self._url.strip(),
            "--summary-interval=1",
            "--continue=true",
            "--max-tries=5",
            "--retry-wait=3",
            "--max-connection-per-server=16",
            "--split=16",
            "--file-allocation=none",
        ]
        self._start_process(aria2, args)

    @staticmethod
    def _resolve_binary(spec: dict) -> str | None:
        for name in spec["binaries"]:
            path = shutil.which(name)
            if path:
                return path
        return None

    @classmethod
    def _installed_downloaders(cls) -> set[str]:
        return {
            tool_id
            for tool_id, spec in DOWNLOADERS.items()
            if cls._resolve_binary(spec) is not None
        }

    @staticmethod
    def _tool_arguments(
        tool_id: str,
        url: str,
        destination: str,
        binary: str = "",
    ) -> list[str]:
        if tool_id == "gallery-dl":
            return ["-d", destination, url]
        if tool_id == "spotdl":
            # spotDL writes its output template relative to the working dir.
            return ["download", url]
        if tool_id == "bandcamp-dl":
            return [url, "--base-dir", destination]
        if tool_id == "khinsider-dl":
            # khinsider-dl installs a `khidl` executable that needs a subcommand;
            # obskyr's khinsider.py takes the album and folder positionally.
            name = os.path.basename(binary)
            if name in ("khidl", "khinsider-dl"):
                return ["download", url, destination]
            return [url, destination]
        raise ValueError(f"Unsupported downloader: {tool_id}")

    def _start_tool(self, tool_id: str) -> None:
        spec = DOWNLOADERS[tool_id]
        binary = self._resolve_binary(spec)
        if binary is None:
            tried = ", ".join(spec["binaries"])
            self._fail(f"{spec['label']} not found in PATH (tried {tried})")
            return
        if spec["requires_ffmpeg"] and shutil.which("ffmpeg") is None:
            self._fail(f"ffmpeg not found in PATH (required by {spec['label']})")
            return
        destination = os.path.abspath(self._destination)
        args = self._tool_arguments(tool_id, self._url.strip(), destination, binary)
        working_directory = destination if tool_id == "spotdl" else None
        self._start_process(binary, args, working_directory)

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

    def _on_stdout(self) -> None:
        if self._process is None:
            return
        data = bytes(self._process.readAllStandardOutput()).decode("utf-8", "replace")
        for line in data.splitlines():
            if self._downloader == "direct":
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
            # Keep the text for the final failure message; tools often print
            # harmless warnings to stderr while still succeeding.
            self._stderr_tail = err
            lines = [line.strip() for line in err.splitlines() if line.strip()]
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
                self._error = self._stderr_tail or f"Process exited with code {code}"
                self.errorChanged.emit()
            if self._status not in ("Failed", "Cancelled"):
                self._status = "Failed"
                self.statusChanged.emit()
        self._process = None
