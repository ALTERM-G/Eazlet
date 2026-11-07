import html
import os
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

from PySide6.QtCore import Property, QMarginsF, QObject, QProcess, QUrl, Signal, Slot
from PySide6.QtGui import (
    QDesktopServices,
    QGuiApplication,
    QImageReader,
    QPageLayout,
    QPageSize,
    QPdfWriter,
    QTextDocument,
)

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

    VIDEO_FORMATS = ["mp4", "webm", "mkv", "avi", "mov", "flv", "wmv", "gif"]
    AUDIO_FORMATS = ["mp3", "aac", "flac", "wav", "ogg", "m4a", "opus", "aiff", "wma"]
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
        "xhtml": "html",
        "markdown": "md",
        "text": "txt",
        "m4v": "mp4",
        "aif": "aiff",
        "oga": "ogg",
        "wave": "wav",
    }
    VIDEO_INPUTS = {
        "mp4", "webm", "mkv", "avi", "mov", "flv", "wmv", "mpg", "mpeg",
        "3gp", "ogv", "ts", "mts", "m2ts", "vob", "m2v", "divx", "xvid",
        "rm", "rmvb", "asf", "dv", "mxf", "f4v",
    }
    AUDIO_INPUTS = {
        "mp3", "aac", "flac", "wav", "ogg", "m4a", "opus", "wma", "aiff",
        "alac", "amr", "mka", "ac3", "dts", "au", "caf", "ape", "wv",
    }
    IMAGE_INPUTS = {
        "jpg", "png", "webp", "bmp", "tiff", "avif", "ico", "gif", "heic",
        "heif", "svg", "apng", "tga", "psd", "dds", "pnm", "xbm", "xpm",
    }
    DOC_INPUTS = {"txt", "md", "html", "pdf", "docx", "odt", "rtf"}

    # Only conversions the document pipeline actually implements.
    DOC_TARGETS = {
        "txt": ["md", "html", "pdf"],
        "md": ["txt", "html", "pdf"],
        "html": ["txt", "md", "pdf"],
        "docx": ["txt", "md", "html", "pdf"],
        "odt": ["txt", "md", "html", "pdf"],
        "rtf": ["txt", "md", "html", "pdf"],
        "pdf": ["txt", "md", "html"] if shutil.which("pdftotext") else [],
    }

    # Each target needs at least one encoder from every group to be offered.
    ENCODER_CANDIDATES = {
        "mp3": (("libmp3lame", "mp3"),),
        "aac": (("aac",),),
        "m4a": (("aac",),),
        "ogg": (("libvorbis", "vorbis"),),
        "opus": (("libopus", "opus"),),
        "aiff": (("pcm_s16be",),),
        "wma": (("wmav2",),),
        "avif": (("libaom-av1", "libaom"),),
        "webp": (("libwebp", "webp"),),
        "mp4": (("libx264", "h264"), ("aac",)),
        "mov": (("libx264", "h264"), ("aac",)),
        "flv": (("libx264", "h264"), ("aac",)),
        "wmv": (("wmv2",), ("wmav2",)),
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
        self._temp_files = []

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
            return True
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

    def _cleanup_temp_files(self):
        for path in self._temp_files:
            try:
                os.unlink(path)
            except OSError:
                pass
        self._temp_files = []

    def _rasterize_svg(self, path):
        """Render an SVG to a temporary PNG so ffmpeg can consume it."""
        if QGuiApplication.instance() is None:
            raise RuntimeError("SVG conversion requires the application to be running")
        reader = QImageReader(path)
        image = reader.read()
        if image.isNull():
            message = reader.errorString() or "unknown error"
            raise RuntimeError(f"Could not read SVG: {message}")
        handle, temp_path = tempfile.mkstemp(prefix="eazlet-svg-", suffix=".png")
        os.close(handle)
        if not image.save(temp_path, "PNG"):
            try:
                os.unlink(temp_path)
            except OSError:
                pass
            raise RuntimeError("Could not rasterize SVG")
        self._temp_files.append(temp_path)
        return temp_path

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
        self._cleanup_temp_files()
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
        src_path = f["path"]
        if src_ext == "svg":
            try:
                src_path = self._rasterize_svg(src_path)
            except Exception as e:
                self._error = str(e)[:240]
                self.errorChanged.emit()
                self._failed_files.append(f["path"])
                self._current_index += 1
                self._convert_next()
                return
        self._duration = self._get_duration(src_path) if shutil.which("ffprobe") else 0
        args = ["-i", src_path, "-y", "-hide_banner", "-nostdin"]
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
            elif self._target_format == "aiff":
                args.extend(["-codec:a", "pcm_s16be"])
            elif self._target_format == "wma":
                args.extend(["-codec:a", "wmav2", "-b:a", "192k"])
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
        elif self._target_format == "wmv":
            args.extend(["-c:v", "wmv2", "-c:a", "wmav2"])
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

    @staticmethod
    def _read_docx_text(src):
        word = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
        with zipfile.ZipFile(src) as archive:
            data = archive.read("word/document.xml")
        root = ET.fromstring(data)
        paragraphs = []
        for paragraph in root.iter(f"{word}p"):
            parts = []
            for node in paragraph.iter():
                tag = node.tag
                if tag == f"{word}t":
                    parts.append(node.text or "")
                elif tag == f"{word}tab":
                    parts.append("\t")
                elif tag in (f"{word}br", f"{word}cr"):
                    parts.append("\n")
            paragraphs.append("".join(parts))
        return "\n".join(paragraphs)

    @staticmethod
    def _read_odt_text(src):
        text_ns = "{urn:oasis:names:tc:opendocument:xmlns:text:1.0}"
        with zipfile.ZipFile(src) as archive:
            data = archive.read("content.xml")
        root = ET.fromstring(data)

        def collect(element):
            parts = [element.text or ""]
            for child in element:
                tag = child.tag
                if tag == f"{text_ns}s":
                    try:
                        count = max(1, int(child.get(f"{text_ns}c", "1")))
                    except ValueError:
                        count = 1
                    parts.append(" " * count)
                elif tag == f"{text_ns}tab":
                    parts.append("\t")
                elif tag in (f"{text_ns}line-break", f"{text_ns}soft-page-break"):
                    parts.append("\n")
                else:
                    parts.append(collect(child))
                parts.append(child.tail or "")
            return "".join(parts)

        blocks = []
        for element in root.iter():
            if element.tag in (f"{text_ns}p", f"{text_ns}h"):
                blocks.append(collect(element))
        return "\n".join(blocks)

    RTF_SKIP_DESTINATIONS = {
        "fonttbl", "colortbl", "stylesheet", "info", "pict", "object",
        "shppict", "header", "footer", "headerl", "headerr", "footerl",
        "footerr", "footnote", "annotation", "fldinst", "themedata",
        "colorschememapping", "datastore", "latentstyles", "listtable",
        "listoverridetable", "rsidtbl", "generator", "xmlnstbl", "filetbl",
        "revtbl", "pgdsctbl", "pn", "pntext",
    }

    @classmethod
    def _rtf_to_text(cls, content):
        if not content:
            return ""
        text = []
        depth = 0
        skip_depth = None
        index = 0
        length = len(content)
        while index < length:
            char = content[index]
            if char == "{":
                depth += 1
                index += 1
                continue
            if char == "}":
                if skip_depth is not None and skip_depth == depth:
                    skip_depth = None
                depth = max(0, depth - 1)
                index += 1
                continue
            if char == "\\":
                index += 1
                if index >= length:
                    break
                token = content[index]
                if token in "\\{}":
                    if skip_depth is None:
                        text.append(token)
                    index += 1
                    continue
                if token == "'":
                    hex_digits = content[index + 1:index + 3]
                    index += 3
                    if skip_depth is None and re.fullmatch(r"[0-9a-fA-F]{2}", hex_digits):
                        text.append(bytes([int(hex_digits, 16)]).decode("cp1252", "replace"))
                    continue
                if token == "*":
                    if skip_depth is None:
                        skip_depth = depth
                    index += 1
                    continue
                if token in "~-_":
                    if skip_depth is None:
                        text.append(" " if token in "~_" else "-")
                    index += 1
                    continue
                match = re.match(r"([a-zA-Z]+)(-?\d+)?[ ]?", content[index:])
                if match is None:
                    index += 1
                    continue
                word = match.group(1)
                number = match.group(2)
                index += match.end()
                if word in cls.RTF_SKIP_DESTINATIONS:
                    if skip_depth is None:
                        skip_depth = depth
                elif word in ("par", "line", "sect", "page"):
                    if skip_depth is None:
                        text.append("\n")
                elif word in ("tab", "cell"):
                    if skip_depth is None:
                        text.append("\t")
                elif word == "u" and number is not None:
                    if skip_depth is None:
                        code = int(number)
                        if code < 0:
                            code += 65536
                        text.append(chr(code))
                    if index < length and content[index] == "?":
                        index += 1
                continue
            if char in "\r\n":
                index += 1
                continue
            if char == "\t" or ord(char) >= 32:
                if skip_depth is None:
                    text.append(char)
            index += 1
        result = "".join(text)
        result = re.sub(r"[ \t]+\n", "\n", result)
        result = re.sub(r"\n{3,}", "\n\n", result)
        return result.strip()

    def _extract_document_text(self, src, src_fmt):
        if src_fmt == "pdf":
            if shutil.which("pdftotext") is None:
                raise RuntimeError("pdftotext not found in PATH")
            result = subprocess.run(
                ["pdftotext", "-layout", "-enc", "UTF-8", src, "-"],
                capture_output=True,
                timeout=120,
            )
            if result.returncode != 0:
                message = result.stderr.decode("utf-8", "replace").strip()
                raise RuntimeError(message[:200] or "pdftotext failed")
            return result.stdout.decode("utf-8", "replace")
        if src_fmt == "docx":
            return self._read_docx_text(src)
        if src_fmt == "odt":
            return self._read_odt_text(src)
        with open(src, encoding="utf-8", errors="ignore") as handle:
            content = handle.read()
        if src_fmt == "rtf":
            return self._rtf_to_text(content)
        if src_fmt == "html":
            return self._html_to_text(content)
        return content

    @staticmethod
    def _text_to_html(text, title):
        return (
            "<!DOCTYPE html>\n<html>\n<head>\n"
            '<meta charset="utf-8">\n'
            f"<title>{html.escape(title)}</title>\n"
            "</head>\n<body>\n<pre>"
            + html.escape(text)
            + "</pre>\n</body>\n</html>\n"
        )

    @staticmethod
    def _write_pdf(text, dst):
        if QGuiApplication.instance() is None:
            raise RuntimeError("PDF export requires the application to be running")
        writer = QPdfWriter(dst)
        writer.setPageSize(QPageSize(QPageSize.A4))
        writer.setPageMargins(QMarginsF(15, 15, 15, 15), QPageLayout.Millimeter)
        writer.setTitle(Path(dst).stem)
        document = QTextDocument()
        document.setPlainText(text)
        document.print_(writer)

    def _convert_doc(self, src, dst):
        try:
            src_fmt = self.canonical_format(Path(src).suffix)
            dst_fmt = self.canonical_format(Path(dst).suffix)
            if dst_fmt not in self.DOC_TARGETS.get(src_fmt, []):
                raise ValueError(f"Unsupported document conversion: {src_fmt} -> {dst_fmt}")

            text = self._extract_document_text(src, src_fmt)
            if dst_fmt == "pdf":
                self._write_pdf(text, dst)
            else:
                if dst_fmt == "html":
                    output = self._text_to_html(text, Path(src).stem)
                else:
                    output = text.rstrip() + "\n"
                with open(dst, "w", encoding="utf-8") as handle:
                    handle.write(output)

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
        self._cleanup_temp_files()
        self._status = "Cancelled"
        self._error = ""
        self._progress = 0.0
        self.convertingChanged.emit()
        self.statusChanged.emit()
        self.errorChanged.emit()
        self.progressChanged.emit()
