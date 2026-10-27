import os
import re
import subprocess
from pathlib import Path

from PySide6.QtCore import Property, QObject, QProcess, Signal, Slot
from PySide6.QtGui import QDesktopServices

from .base_vm import BaseVM


class ConverterVM(BaseVM):
    filesChanged = Signal()
    outputDirChanged = Signal()
    convertingChanged = Signal()
    progressChanged = Signal()
    statusChanged = Signal()
    errorChanged = Signal()
    targetFormatChanged = Signal()

    VIDEO_FORMATS = ["mp4", "webm", "mkv", "avi", "mov", "flv", "gif"]
    AUDIO_FORMATS = ["mp3", "aac", "flac", "wav", "ogg", "m4a", "opus"]
    IMAGE_FORMATS = ["jpg", "jpeg", "png", "webp", "bmp", "tiff", "avif", "ico"]
    DOC_FORMATS = ["pdf", "txt", "md", "html"]

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._files = []
        self._output_dir = str(Path.home() / "Downloads")
        self._converting = False
        self._progress = 0.0
        self._status = "Idle"
        self._error = ""
        self._target_format = "mp4"
        self._process = None
        self._current_index = 0
        self._duration = 0
        self._time_re = re.compile(r"time=(\d+):(\d+):(\d+\.\d+)")
        self._speed_re = re.compile(r"speed=\s*([0-9.]+)x")

    @Property(list, notify=filesChanged)
    def files(self):
        return self._files

    @Property(str, notify=outputDirChanged)
    def outputDir(self):
        return self._output_dir

    @outputDir.setter
    def outputDir(self, value):
        if value != self._output_dir:
            self._output_dir = value
            self.outputDirChanged.emit()

    @Property(bool, notify=convertingChanged)
    def converting(self):
        return self._converting

    @Property(float, notify=progressChanged)
    def progress(self):
        return self._progress

    @Property(str, notify=statusChanged)
    def status(self):
        return self._status

    @Property(str, notify=errorChanged)
    def error(self):
        return self._error

    @Property(str, notify=targetFormatChanged)
    def targetFormat(self):
        return self._target_format

    @targetFormat.setter
    def targetFormat(self, value):
        if value != self._target_format:
            self._target_format = value
            self.targetFormatChanged.emit()

    @Slot(str)
    def addFile(self, path):
        if not path:
            return
        p = path.replace("file://", "").strip()
        if not p:
            return
        if p not in [f["path"] for f in self._files]:
            ext = Path(p).suffix.lower().lstrip(".")
            self._files.append({"path": p, "name": Path(p).name, "ext": ext})
            self.filesChanged.emit()

    @Slot()
    def addFiles(self):
        pass

    @Slot(int)
    def removeFile(self, index):
        if 0 <= index < len(self._files):
            self._files.pop(index)
            self.filesChanged.emit()

    @Slot()
    def clearFiles(self):
        self._files = []
        self.filesChanged.emit()

    @Slot()
    def chooseOutputDir(self):
        pass

    @Slot()
    def openOutputDir(self):
        try:
            from PySide6.QtCore import QUrl

            QDesktopServices.openUrl(QUrl.fromLocalFile(os.path.abspath(self._output_dir)))
        except Exception:
            pass

    def _get_duration(self, filepath):
        try:
            result = subprocess.run(
                [
                    "ffprobe",
                    "-v",
                    "error",
                    "-show_entries",
                    "format=duration",
                    "-of",
                    "default=noprint_wrappers=1:nokey=1",
                    filepath,
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=10,
            )
            s = result.stdout.strip()
            if not s:
                return 0
            return float(s)
        except Exception:
            return 0

    @Slot()
    def convert(self):
        if self._converting or not self._files:
            self._error = "No files to convert"
            self.errorChanged.emit()
            return
        Path(self._output_dir).mkdir(parents=True, exist_ok=True)
        self._error = ""
        self._progress = 0.0
        self._converting = True
        self._current_index = 0
        self.progressChanged.emit()
        self.convertingChanged.emit()
        self.errorChanged.emit()
        self._convert_next()

    def _convert_next(self):
        if self._current_index >= len(self._files):
            self._converting = False
            self._status = "Done"
            self._progress = 1.0
            self.convertingChanged.emit()
            self.statusChanged.emit()
            self.progressChanged.emit()
            return
        f = self._files[self._current_index]
        self._status = f"Converting {f['name']}..."
        self.statusChanged.emit()
        src_ext = f.get("ext", "").lower()
        out_path = os.path.join(self._output_dir, Path(f["name"]).stem + "." + self._target_format)
        if self._target_format in self.DOC_FORMATS and src_ext in self.DOC_FORMATS and src_ext != self._target_format:
            self._convert_doc(f["path"], out_path)
            return
        self._duration = self._get_duration(f["path"])
        args = ["-i", f["path"], "-y", "-hide_banner"]
        if self._target_format in self.AUDIO_FORMATS:
            args.append("-vn")
            if self._target_format == "mp3":
                args.extend(["-codec:a", "libmp3lame", "-q:a", "2"])
            elif self._target_format == "aac":
                args.extend(["-codec:a", "aac", "-b:a", "192k"])
            elif self._target_format == "ogg":
                args.extend(["-codec:a", "libvorbis", "-q:a", "5"])
            elif self._target_format == "opus":
                args.extend(["-codec:a", "libopus", "-b:a", "192k"])
            elif self._target_format == "flac":
                args.extend(["-codec:a", "flac"])
            elif self._target_format == "wav":
                args.extend(["-codec:a", "pcm_s16le"])
            elif self._target_format == "m4a":
                args.extend(["-codec:a", "aac", "-b:a", "192k"])
        elif self._target_format in self.IMAGE_FORMATS:
            if self._target_format in ["jpg", "jpeg"]:
                args.extend(["-q:v", "2"])
            elif self._target_format == "webp":
                args.extend(["-quality", "80"])
            elif self._target_format == "png":
                args.extend(["-compression_level", "6"])
            elif self._target_format == "avif":
                args.extend(["-c:v", "libaom-av1", "-crf", "30"])
        elif self._target_format == "webm":
            args.extend(["-c:v", "libvpx-vp9", "-crf", "32", "-b:v", "0", "-c:a", "libopus"])
        elif self._target_format == "gif":
            args.extend(["-vf", "fps=12,scale=640:-1:flags=lanczos", "-loop", "0"])
        elif self._target_format == "mp4":
            args.extend(["-c:v", "libx264", "-preset", "medium", "-crf", "23", "-c:a", "aac", "-b:a", "192k"])
        args.append(out_path)
        proc = QProcess(self)
        proc.setProgram("ffmpeg")
        proc.setArguments(args)
        proc.readyReadStandardError.connect(self._on_stderr)
        proc.finished.connect(self._on_finished)
        self._process = proc
        proc.start()

    def _convert_doc(self, src, dst):
        try:
            src_ext = Path(src).suffix.lower()
            dst_ext = Path(dst).suffix.lower()
            if src_ext == ".txt" and dst_ext in [".md", ".html"]:
                with open(src, encoding="utf-8", errors="ignore") as f:
                    content = f.read()
                if dst_ext == ".html":
                    html = "<html><body><pre>" + content.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;") + "</pre></body></html>"
                    with open(dst, "w", encoding="utf-8") as f:
                        f.write(html)
                else:
                    with open(dst, "w", encoding="utf-8") as f:
                        f.write(content)
                self._current_index += 1
                self._convert_next()
                return
            if src_ext == ".md" and dst_ext == ".html":
                with open(src, encoding="utf-8", errors="ignore") as f:
                    content = f.read()
                html = "<html><body><pre>" + content.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;") + "</pre></body></html>"
                with open(dst, "w", encoding="utf-8") as f:
                    f.write(html)
                self._current_index += 1
                self._convert_next()
                return
            if src_ext == ".html" and dst_ext == ".txt":
                with open(src, encoding="utf-8", errors="ignore") as f:
                    content = f.read()
                import re as _re
                text = _re.sub(r"<[^>]+>", "", content)
                with open(dst, "w", encoding="utf-8") as f:
                    f.write(text)
                self._current_index += 1
                self._convert_next()
                return
        except Exception as e:
            self._error = str(e)
            self.errorChanged.emit()
        self._converting = False
        self._status = "Failed"
        self.convertingChanged.emit()
        self.statusChanged.emit()

    def _on_stderr(self):
        if self._process is None:
            return
        data = bytes(self._process.readAllStandardError()).decode("utf-8", "replace")
        for line in data.splitlines():
            m = self._time_re.search(line)
            if m and self._duration > 0:
                try:
                    h, mi, s = float(m.group(1)), float(m.group(2)), float(m.group(3))
                    cur = h * 3600 + mi * 60 + s
                    base = self._current_index / len(self._files) if self._files else 0
                    self._progress = base + (cur / self._duration) / len(self._files)
                    self.progressChanged.emit()
                except Exception:
                    pass
            if "error" in line.lower() and not self._error:
                self._error = line[:200]
                self.errorChanged.emit()

    def _on_finished(self, code, status):
        if code == 0:
            self._current_index += 1
            self._convert_next()
        else:
            self._converting = False
            self._status = "Failed"
            if not self._error:
                self._error = f"ffmpeg exited with code {code}"
                self.errorChanged.emit()
            self.convertingChanged.emit()
            self.statusChanged.emit()
            self._process = None

    @Slot()
    def cancel(self):
        if self._process is not None:
            try:
                self._process.kill()
            except Exception:
                pass
        self._converting = False
        self._status = "Cancelled"
        self.convertingChanged.emit()
        self.statusChanged.emit()
        self._process = None
