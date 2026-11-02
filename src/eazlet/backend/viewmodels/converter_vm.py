import os
import re
import shutil
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
    validTargetFormatsChanged = Signal()

    VIDEO_FORMATS = ["mp4", "webm", "mkv", "avi", "mov", "flv", "gif"]
    AUDIO_FORMATS = ["mp3", "aac", "flac", "wav", "ogg", "m4a", "opus"]
    IMAGE_FORMATS = ["jpg", "jpeg", "png", "webp", "bmp", "tiff", "avif", "ico"]
    DOC_FORMATS = ["pdf", "txt", "md", "html"]

    ALL_FORMATS = VIDEO_FORMATS + AUDIO_FORMATS + IMAGE_FORMATS + DOC_FORMATS

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._files = []
        self._output_dir = str(Path.home() / "Downloads")
        self._converting = False
        self._progress = 0.0
        self._status = "Idle"
        self._error = ""
        self._target_format = "mp4"
        self._valid_target_formats = []
        self._available_encoders = set()
        self._available_decoders = set()
        self._probe_encoders()
        self._process = None
        self._current_index = 0
        self._duration = 0
        self._time_re = re.compile(r"time=(\d+):(\d+):(\d+\.\d+)")
        self._speed_re = re.compile(r"speed=\s*([0-9.]+)x")
        self._failed_files = []

    def _probe_encoders(self):
        try:
            if shutil.which("ffmpeg") is None:
                return
            result = subprocess.run(["ffmpeg", "-hide_banner", "-encoders"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5)
            out = result.stdout.decode("utf-8", "replace") + result.stderr.decode("utf-8", "replace")
            for line in out.splitlines():
                line = line.strip()
                if not line or line.startswith("Encoders:") or line.startswith("------"):
                    continue
                parts = line.split()
                if len(parts) >= 2 and parts[0] in ("V", "A", "S"):
                    enc = parts[1]
                    if enc and not enc.startswith("="):
                        self._available_encoders.add(enc)
        except Exception:
            pass

    def _has_encoder(self, name):
        if not name:
            return True
        if not self._available_encoders:
            return True  # be permissive if probe fails
        return name in self._available_encoders

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

    @Property(list, notify=validTargetFormatsChanged)
    def validTargetFormats(self):
        return self._valid_target_formats

    def _update_valid_formats(self):
        if not self._files:
            self._valid_target_formats = []
            self.validTargetFormatsChanged.emit()
            if self._target_format != "":
                self._target_format = ""
                self.targetFormatChanged.emit()
            return
        exts = [f.get("ext", "").lower() for f in self._files]
        def cat(ext):
            if ext == "gif":
                return "image"
            if ext in self.VIDEO_FORMATS or ext in ["webm", "mkv", "avi", "mov", "flv", "mp4"]:
                return "video"
            if ext in self.AUDIO_FORMATS:
                return "audio"
            if ext in self.IMAGE_FORMATS:
                return "image"
            if ext in self.DOC_FORMATS:
                return "doc"
            return "other"
        cats = set(cat(e) for e in exts if e)
        valid = []
        if len(cats) == 1:
            c = list(cats)[0]
            if c == "video":
                valid = list(dict.fromkeys(self.VIDEO_FORMATS))
            elif c == "audio":
                valid = list(dict.fromkeys(self.AUDIO_FORMATS))
            elif c == "image":
                valid = list(dict.fromkeys(self.IMAGE_FORMATS))
            elif c == "doc":
                valid = list(dict.fromkeys(self.DOC_FORMATS))
            else:
                valid = list(dict.fromkeys(self.ALL_FORMATS))
        else:
            valid = list(dict.fromkeys(self.ALL_FORMATS))
        filtered = []
        for fmt in valid:
            if fmt == "mp3" and not self._has_encoder("libmp3lame"):
                continue
            if fmt == "ogg" and not self._has_encoder("libvorbis"):
                continue
            if fmt == "opus" and not self._has_encoder("libopus"):
                continue
            if fmt == "webm" and (not self._has_encoder("libvpx-vp9") or not self._has_encoder("libopus")):
                pass
            if fmt == "avif" and not self._has_encoder("libaom-av1"):
                continue
            if fmt == "aac" and not self._has_encoder("aac"):
                continue
            filtered.append(fmt)
        if not filtered:
            filtered = list(dict.fromkeys(self.ALL_FORMATS))
        self._valid_target_formats = filtered
        self.validTargetFormatsChanged.emit()
        if not self._target_format or self._target_format not in self._valid_target_formats:
            if self._valid_target_formats:
                self._target_format = self._valid_target_formats[0]
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
            self._update_valid_formats()

    @Slot()
    def addFiles(self):
        pass

    @Slot(int)
    def removeFile(self, index):
        if 0 <= index < len(self._files):
            self._files.pop(index)
            self.filesChanged.emit()
            self._update_valid_formats()

    @Slot()
    def clearFiles(self):
        self._files = []
        self.filesChanged.emit()
        self._update_valid_formats()

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
        if not self._target_format:
            self._error = "No target format"
            self.errorChanged.emit()
            return
        if shutil.which("ffmpeg") is None:
            self._error = "ffmpeg not found in PATH"
            self.errorChanged.emit()
            return
        Path(self._output_dir).mkdir(parents=True, exist_ok=True)
        self._error = ""
        self._progress = 0.0
        self._converting = True
        self._current_index = 0
        self._failed_files = []
        self.progressChanged.emit()
        self.convertingChanged.emit()
        self.errorChanged.emit()
        self._convert_next()

    def _convert_next(self):
        if self._current_index >= len(self._files):
            self._converting = False
            if self._failed_files:
                self._status = f"Done with errors ({len(self._failed_files)} failed)"
                if not self._error:
                    self._error = f"Failed: {', '.join(Path(x).name for x in self._failed_files[:3])}" + ("..." if len(self._failed_files) > 3 else "")
                    self.errorChanged.emit()
            else:
                self._status = "Done"
            self._progress = 1.0
            self.convertingChanged.emit()
            self.statusChanged.emit()
            self.progressChanged.emit()
            self._process = None
            return
        f = self._files[self._current_index]
        self._status = f"Converting {f['name']}..."
        self.statusChanged.emit()
        src_ext = f.get("ext", "").lower()
        base = Path(f["name"]).stem
        out_path = os.path.join(self._output_dir, base + "." + self._target_format)
        if out_path == f["path"]:
            self._current_index += 1
            self._convert_next()
            return
        if os.path.exists(out_path):
            i = 1
            while True:
                candidate = os.path.join(self._output_dir, f"{base} ({i}).{self._target_format}")
                if not os.path.exists(candidate):
                    out_path = candidate
                    break
                i += 1
                if i > 1000:
                    break
        if self._target_format in self.DOC_FORMATS and src_ext in self.DOC_FORMATS and src_ext != self._target_format:
            self._convert_doc(f["path"], out_path)
            return
        self._duration = self._get_duration(f["path"]) if shutil.which("ffprobe") else 0
        args = ["-i", f["path"], "-y", "-hide_banner", "-nostdin"]
        if self._target_format in self.AUDIO_FORMATS:
            args.append("-vn")
            if self._target_format == "mp3":
                if self._has_encoder("libmp3lame"):
                    args.extend(["-codec:a", "libmp3lame", "-q:a", "2"])
                else:
                    args.extend(["-codec:a", "mp3"])
            elif self._target_format == "aac":
                if self._has_encoder("aac"):
                    args.extend(["-codec:a", "aac", "-b:a", "192k"])
                else:
                    args.extend(["-codec:a", "aac", "-b:a", "192k"])
            elif self._target_format == "ogg":
                if self._has_encoder("libvorbis"):
                    args.extend(["-codec:a", "libvorbis", "-q:a", "5"])
                else:
                    args.extend(["-codec:a", "vorbis", "-q:a", "5"])
            elif self._target_format == "opus":
                if self._has_encoder("libopus"):
                    args.extend(["-codec:a", "libopus", "-b:a", "192k"])
                else:
                    args.extend(["-codec:a", "opus", "-b:a", "192k"])
            elif self._target_format == "flac":
                args.extend(["-codec:a", "flac"])
            elif self._target_format == "wav":
                args.extend(["-codec:a", "pcm_s16le"])
            elif self._target_format == "m4a":
                if self._has_encoder("aac"):
                    args.extend(["-codec:a", "aac", "-b:a", "192k"])
                else:
                    args.extend(["-codec:a", "aac", "-b:a", "192k"])
        elif self._target_format in self.IMAGE_FORMATS:
            if self._target_format in ["jpg", "jpeg"]:
                args.extend(["-q:v", "2"])
            elif self._target_format == "webp":
                args.extend(["-quality", "80"])
            elif self._target_format == "png":
                args.extend(["-compression_level", "6"])
            elif self._target_format == "avif":
                if self._has_encoder("libaom-av1"):
                    args.extend(["-c:v", "libaom-av1", "-crf", "30"])
                else:
                    args.extend(["-c:v", "libaom-av1", "-crf", "30"])
            elif self._target_format == "ico":
                pass
        elif self._target_format == "webm":
            v = "libvpx-vp9" if self._has_encoder("libvpx-vp9") else "vp9"
            a = "libopus" if self._has_encoder("libopus") else "opus"
            args.extend(["-c:v", v, "-crf", "32", "-b:v", "0", "-c:a", a])
        elif self._target_format == "gif":
            args.extend(["-vf", "fps=12,scale=640:-1:flags=lanczos", "-loop", "0"])
        elif self._target_format == "mp4":
            v = "libx264" if self._has_encoder("libx264") else "h264"
            a = "aac" if self._has_encoder("aac") else "aac"
            args.extend(["-c:v", v, "-preset", "medium", "-crf", "23", "-c:a", a, "-b:a", "192k"])
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
            if dst_ext != Path(dst).suffix.lower():  # dummy
                pass
            base = Path(dst).stem
            ddir = Path(dst).parent
            cand = dst
            if os.path.exists(cand):
                i = 1
                while True:
                    cand = str(ddir / f"{base} ({i}){Path(dst).suffix}")
                    if not os.path.exists(cand):
                        dst = cand
                        break
                    i += 1
                    if i > 1000:
                        break
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
            self._error = str(e)[:200]
            self.errorChanged.emit()
        self._failed_files.append(src)
        self._current_index += 1
        self._convert_next()
        return

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
                    if self._progress > 1.0:
                        self._progress = 1.0
                    self.progressChanged.emit()
                except Exception:
                    pass
            l = line.lower()
            if not self._error and ("error" in l or "unknown encoder" in l or "does not support" in l or "no such filter" in l or "invalid" in l):
                err = line.strip()
                if "unknown encoder" in l:
                    err = "Unsupported encoder for this format. Try a different format or install missing codecs."
                elif "does not support" in l:
                    err = "Format/codec not supported by this ffmpeg build."
                elif "no such filter" in l:
                    err = "Unsupported filter/operation for this conversion."
                if len(err) > 240:
                    err = err[:240] + "..."
                self._error = err
                self.errorChanged.emit()

    def _on_finished(self, code, status):
        if code == 0:
            self._current_index += 1
            self._convert_next()
            return
        try:
            if self._current_index < len(self._files):
                self._failed_files.append(self._files[self._current_index].get("path"))
        except Exception:
            pass
        if not self._error:
            self._error = f"Conversion failed for {Path(self._files[self._current_index].get('name','file')).name if self._current_index < len(self._files) else 'file'}"
            self.errorChanged.emit()
        self._current_index += 1
        self._convert_next()
        self._process = None

    @Slot()
    def cancel(self):
        if self._process is not None:
            try:
                self._process.kill()
                self._process.waitForFinished(1000)
            except Exception:
                pass
        self._converting = False
        self._status = "Cancelled"
        self.convertingChanged.emit()
        self.statusChanged.emit()
        self._process = None
