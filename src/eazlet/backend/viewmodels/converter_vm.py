import html
import os
import re
import shutil
import subprocess
from pathlib import Path

from PySide6.QtCore import Property, QObject, QProcess, QUrl, Signal, Slot
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
    sourceChanged = Signal()

    VIDEO_FORMATS = ["mp4", "webm", "mkv", "avi", "mov", "flv", "gif"]
    AUDIO_FORMATS = ["mp3", "aac", "flac", "wav", "ogg", "m4a", "opus"]
    IMAGE_FORMATS = ["jpg", "png", "webp", "bmp", "tiff", "avif", "ico"]
    DOC_FORMATS = ["txt", "md", "html", "pdf"]
    ALL_FORMATS = VIDEO_FORMATS + AUDIO_FORMATS + IMAGE_FORMATS + DOC_FORMATS

    # Input extensions are grouped separately from output formats: we can read
    # more container types than we offer as targets.
    FORMAT_ALIASES = {
        "jpeg": "jpg",
        "jpe": "jpg",
        "jfif": "jpg",
        "tif": "tiff",
        "htm": "html",
        "markdown": "md",
        "m4v": "mp4",
        "aif": "aiff",
    }
    VIDEO_INPUTS = {
        "mp4", "webm", "mkv", "avi", "mov", "flv", "wmv", "mpg", "mpeg",
        "3gp", "ogv", "ts", "mts", "m2ts", "vob",
    }
    AUDIO_INPUTS = {
        "mp3", "aac", "flac", "wav", "ogg", "m4a", "opus", "wma", "aiff",
        "alac", "amr",
    }
    IMAGE_INPUTS = {
        "jpg", "png", "webp", "bmp", "tiff", "avif", "ico", "gif", "heic", "heif",
    }
    DOC_INPUTS = {"txt", "md", "html", "pdf"}

    # Only conversions the document pipeline actually implements.
    DOC_TARGETS = {
        "txt": ["md", "html"],
        "md": ["txt", "html"],
        "html": ["txt"],
        "pdf": ["txt"] if shutil.which("pdftotext") else [],
    }

    # Each target needs at least one encoder from every group to be offered.
    ENCODER_CANDIDATES = {
        "mp3": (("libmp3lame", "mp3"),),
        "aac": (("aac",),),
        "m4a": (("aac",),),
        "ogg": (("libvorbis", "vorbis"),),
        "opus": (("libopus", "opus"),),
        "avif": (("libaom-av1", "libaom"),),
        "webp": (("libwebp", "webp"),),
        "mp4": (("libx264", "h264"), ("aac",)),
        "mov": (("libx264", "h264"), ("aac",)),
        "flv": (("libx264", "h264"), ("aac",)),
        "webm": (("libvpx-vp9", "vp9"), ("libopus", "opus")),
    }

    @classmethod
    def canonical_format(cls, ext: str) -> str:
        ext = (ext or "").lower().lstrip(".")
        return cls.FORMAT_ALIASES.get(ext, ext)

    @classmethod
    def category_for(cls, ext: str) -> str:
        fmt = cls.canonical_format(ext)
        if fmt in cls.VIDEO_INPUTS:
            return "video"
        if fmt in cls.AUDIO_INPUTS:
            return "audio"
        if fmt in cls.IMAGE_INPUTS:
            return "image"
        if fmt in cls.DOC_INPUTS:
            return "document"
        return "unsupported"

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._files = []
        self._output_dir = str(Path.home() / "Downloads")
        self._converting = False
        self._progress = 0.0
        self._status = "Idle"
        self._error = ""
        self._target_format = ""
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
            result = subprocess.run(
                ["ffmpeg", "-hide_banner", "-encoders"],
                capture_output=True,
                timeout=5,
            )
            out = result.stdout.decode("utf-8", "replace") + result.stderr.decode(
                "utf-8", "replace"
            )
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

    @Property(str, notify=sourceChanged)
    def sourceFormat(self):
        if not self._files:
            return ""
        return self.canonical_format(self._files[0].get("ext", ""))

    @Property(str, notify=sourceChanged)
    def sourceCategory(self):
        if not self._files:
            return ""
        return self.category_for(self._files[0].get("ext", ""))

    def _format_available(self, fmt):
        fmt = self.canonical_format(fmt)
        if fmt in self.DOC_FORMATS:
            return True
        if shutil.which("ffmpeg") is None:
            return False
        groups = self.ENCODER_CANDIDATES.get(fmt)
        if not groups:
            return True
        return all(any(self._has_encoder(name) for name in group) for group in groups)

    def _targets_for(self, category, source):
        if category == "video":
            candidates = self.VIDEO_FORMATS + self.AUDIO_FORMATS
        elif category == "audio":
            candidates = self.AUDIO_FORMATS
        elif category == "image":
            candidates = self.IMAGE_FORMATS
        elif category == "document":
            candidates = self.DOC_TARGETS.get(source, [])
        else:
            return []

        targets = []
        for fmt in candidates:
            target = self.canonical_format(fmt)
            if target == source or target in targets:
                continue
            if self._format_available(target):
                targets.append(target)
        return targets

    def _refresh_targets(self):
        if self._files:
            source = self.canonical_format(self._files[0].get("ext", ""))
            category = self.category_for(source)
        else:
            source, category = "", ""
        self._valid_target_formats = self._targets_for(category, source)
        self.validTargetFormatsChanged.emit()

        target = self._target_format
        if target not in self._valid_target_formats:
            target = self._valid_target_formats[0] if self._valid_target_formats else ""
        if target != self._target_format:
            self._target_format = target
            self.targetFormatChanged.emit()

    def _after_file_change(self):
        self._failed_files = []
        self._error = ""
        self._progress = 0.0
        self.filesChanged.emit()
        self.sourceChanged.emit()
        self.errorChanged.emit()
        self.progressChanged.emit()
        self._refresh_targets()

        if not self._files:
            self._status = "Idle"
        elif self.sourceCategory == "unsupported":
            self._status = "Unsupported file type"
        elif self._valid_target_formats:
            self._status = "Ready"
        else:
            self._status = "No conversion available"
        self.statusChanged.emit()

    @Slot(str)
    def addFile(self, path):
        if not path or self._converting:
            return
        p = path.strip()
        if p.startswith("file:"):
            local = QUrl(p).toLocalFile()
            if local:
                p = local
        if not p:
            return

        ext = Path(p).suffix.lower().lstrip(".")
        self._files = [
            {
                "path": p,
                "name": Path(p).name,
                "ext": ext,
                "format": self.canonical_format(ext),
                "category": self.category_for(ext),
            }
        ]
        self._after_file_change()

    @Slot(int)
    def removeFile(self, index):
        if self._converting:
            return
        if 0 <= index < len(self._files):
            self._files.pop(index)
            self._after_file_change()

    @Slot()
    def clearFiles(self):
        if self._converting:
            return
        self._files = []
        self._after_file_change()

    @Slot()
    def chooseOutputDir(self):
        pass

    @Slot()
    def openOutputDir(self):
        try:
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
                capture_output=True,
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
        if self._converting:
            return
        if not self._files:
            self._error = "Select a file to convert"
            self.errorChanged.emit()
            return
        if self._target_format not in self._valid_target_formats:
            self._error = "Choose a valid output format"
            self.errorChanged.emit()
            return
        category = self.category_for(self._files[0].get("ext", ""))
        if category == "unsupported":
            self._error = "Unsupported file type"
            self.errorChanged.emit()
            return
        if category == "document":
            if self.sourceFormat == "pdf" and shutil.which("pdftotext") is None:
                self._error = "pdftotext not found in PATH"
                self.errorChanged.emit()
                return
        elif shutil.which("ffmpeg") is None:
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
                    failed = ", ".join(Path(x).name for x in self._failed_files[:3])
                    self._error = f"Failed: {failed}" + (
                        "..." if len(self._failed_files) > 3 else ""
                    )
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
        src_ext = self.canonical_format(f.get("ext", ""))
        base = Path(f["path"]).stem
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
        if self.category_for(src_ext) == "document":
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

    @staticmethod
    def _html_to_text(content):
        content = re.sub(r"(?is)<(script|style)\b.*?>.*?</\1>", "", content)
        content = re.sub(r"(?i)<br\s*/?>", "\n", content)
        content = re.sub(r"(?i)</(p|div|h[1-6]|li|tr)>", "\n", content)
        content = re.sub(r"<[^>]+>", "", content)
        content = html.unescape(content)
        lines = [line.strip() for line in content.splitlines()]
        return "\n".join(line for line in lines if line)

    def _convert_doc(self, src, dst):
        try:
            src_fmt = self.canonical_format(Path(src).suffix)
            dst_fmt = self.canonical_format(Path(dst).suffix)
            if dst_fmt not in self.DOC_TARGETS.get(src_fmt, []):
                raise ValueError(f"Unsupported document conversion: {src_fmt} -> {dst_fmt}")

            if src_fmt == "pdf":
                if shutil.which("pdftotext") is None:
                    raise RuntimeError("pdftotext not found in PATH")
                result = subprocess.run(
                    ["pdftotext", "-layout", "-enc", "UTF-8", src, dst],
                    capture_output=True,
                    timeout=120,
                )
                if result.returncode != 0:
                    message = result.stderr.decode("utf-8", "replace").strip()
                    raise RuntimeError(message[:200] or "pdftotext failed")
            else:
                with open(src, encoding="utf-8", errors="ignore") as f:
                    content = f.read()
                if dst_fmt == "html":
                    output = (
                        "<!DOCTYPE html>\n<html>\n<head>\n"
                        '<meta charset="utf-8">\n'
                        f"<title>{html.escape(Path(src).stem)}</title>\n"
                        "</head>\n<body>\n<pre>"
                        + html.escape(content)
                        + "</pre>\n</body>\n</html>\n"
                    )
                elif dst_fmt == "txt" and src_fmt == "html":
                    output = self._html_to_text(content)
                else:
                    output = content
                with open(dst, "w", encoding="utf-8") as f:
                    f.write(output)

            self._current_index += 1
            self._convert_next()
            return
        except Exception as e:
            self._error = str(e)[:240]
            self.errorChanged.emit()
        self._failed_files.append(src)
        self._current_index += 1
        self._convert_next()

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
            lowered = line.lower()
            if not self._error and (
                "error" in lowered
                or "unknown encoder" in lowered
                or "does not support" in lowered
                or "no such filter" in lowered
                or "invalid" in lowered
            ):
                err = line.strip()
                if "unknown encoder" in lowered:
                    err = (
                        "Unsupported encoder for this format. "
                        "Try a different format or install missing codecs."
                    )
                elif "does not support" in lowered:
                    err = "Format/codec not supported by this ffmpeg build."
                elif "no such filter" in lowered:
                    err = "Unsupported filter/operation for this conversion."
                if len(err) > 240:
                    err = err[:240] + "..."
                self._error = err
                self.errorChanged.emit()

    def _on_finished(self, code, status):
        if not self._converting:
            return
        if code == 0:
            if self._error:
                self._error = ""
                self.errorChanged.emit()
            self._current_index += 1
            self._convert_next()
            return
        try:
            if self._current_index < len(self._files):
                self._failed_files.append(self._files[self._current_index].get("path"))
        except Exception:
            pass
        if not self._error:
            name = "file"
            if self._current_index < len(self._files):
                name = Path(self._files[self._current_index].get("name", "file")).name
            self._error = f"Conversion failed for {name}"
            self.errorChanged.emit()
        self._current_index += 1
        self._convert_next()
        self._process = None

    @Slot()
    def cancel(self):
        self._converting = False
        process = self._process
        self._process = None
        if process is not None:
            try:
                process.kill()
                process.waitForFinished(1000)
            except Exception:
                pass
        self._status = "Cancelled"
        self._error = ""
        self._progress = 0.0
        self.convertingChanged.emit()
        self.statusChanged.emit()
        self.errorChanged.emit()
        self.progressChanged.emit()
