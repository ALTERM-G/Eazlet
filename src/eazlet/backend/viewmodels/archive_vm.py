import os
import shutil
import zipfile
import tarfile
from pathlib import Path

from PySide6.QtCore import Property, QObject, QProcess, Signal, Slot
from PySide6.QtGui import QDesktopServices

from .base_vm import BaseVM


class ArchiveVM(BaseVM):
    filesChanged = Signal()
    outputDirChanged = Signal()
    compressingChanged = Signal()
    extractingChanged = Signal()
    progressChanged = Signal()
    statusChanged = Signal()
    errorChanged = Signal()
    formatChanged = Signal()
    compressionLevelChanged = Signal()

    COMPRESS_FORMATS = ["zip", "tar.gz", "tar.xz", "tar.bz2"]
    EXTRACT_FORMATS = ["zip", "tar", "tar.gz", "tgz", "tar.xz", "txz", "tar.bz2", "tbz2"]

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._files = []
        self._output_dir = str(Path.home() / "Downloads")
        self._compressing = False
        self._extracting = False
        self._progress = 0.0
        self._status = "Idle"
        self._error = ""
        self._format = "zip"
        self._compression_level = 6
        self._extract_path = ""

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

    @Property(bool, notify=compressingChanged)
    def compressing(self):
        return self._compressing

    @Property(bool, notify=extractingChanged)
    def extracting(self):
        return self._extracting

    @Property(float, notify=progressChanged)
    def progress(self):
        return self._progress

    @Property(str, notify=statusChanged)
    def status(self):
        return self._status

    @Property(str, notify=errorChanged)
    def error(self):
        return self._error

    @Property(str, notify=formatChanged)
    def format(self):
        return self._format

    @format.setter
    def format(self, value):
        if value != self._format:
            self._format = value
            self.formatChanged.emit()

    @Property(int, notify=compressionLevelChanged)
    def compressionLevel(self):
        return self._compression_level

    @compressionLevel.setter
    def compressionLevel(self, value):
        v = int(value)
        if v < 1:
            v = 1
        if v > 9:
            v = 9
        if v != self._compression_level:
            self._compression_level = v
            self.compressionLevelChanged.emit()

    @Slot(str)
    def addFile(self, path):
        if not path:
            return
        p = path.replace("file://", "").strip()
        if not p:
            return
        if p not in [f["path"] for f in self._files]:
            self._files.append({"path": p, "name": Path(p).name, "isDir": Path(p).is_dir()})
            self.filesChanged.emit()

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
    def openOutputDir(self):
        try:
            from PySide6.QtCore import QUrl
            QDesktopServices.openUrl(QUrl.fromLocalFile(os.path.abspath(self._output_dir)))
        except Exception:
            pass

    @Slot()
    def compress(self):
        if self._compressing or not self._files:
            self._error = "No files to compress"
            self.errorChanged.emit()
            return
        Path(self._output_dir).mkdir(parents=True, exist_ok=True)
        self._error = ""
        self._progress = 0.0
        self._compressing = True
        self._status = "Compressing..."
        self.progressChanged.emit()
        self.compressingChanged.emit()
        self.statusChanged.emit()
        self.errorChanged.emit()
        try:
            out_name = Path(self._files[0]["name"]).stem
            if len(self._files) > 1:
                out_name = "archive"
            fmt = self._format
            if fmt == "zip":
                out_path = os.path.join(self._output_dir, out_name + ".zip")
                base = Path(out_path).stem
                ddir = Path(out_path).parent
                cand = out_path
                if os.path.exists(cand):
                    i = 1
                    while True:
                        cand = str(ddir / f"{base} ({i}).zip")
                        if not os.path.exists(cand):
                            out_path = cand
                            break
                        i += 1
                        if i > 1000:
                            break
                with zipfile.ZipFile(out_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=self._compression_level) as zf:
                    for f in self._files:
                        p = f["path"]
                        if os.path.isdir(p):
                            for root, dirs, files in os.walk(p):
                                for fn in files:
                                    full = os.path.join(root, fn)
                                    arc = os.path.relpath(full, os.path.dirname(p))
                                    zf.write(full, arc)
                        else:
                            zf.write(p, Path(p).name)
                self._progress = 1.0
                self._status = "Done"
            elif fmt in ["tar.gz", "tgz"]:
                out_path = os.path.join(self._output_dir, out_name + ".tar.gz")
                base = Path(out_path).stem.replace(".tar", "")
                ddir = Path(out_path).parent
                cand = out_path
                if os.path.exists(cand):
                    i = 1
                    while True:
                        cand = str(ddir / f"{base} ({i}).tar.gz")
                        if not os.path.exists(cand):
                            out_path = cand
                            break
                        i += 1
                        if i > 1000:
                            break
                with tarfile.open(out_path, "w:gz") as tf:
                    for f in self._files:
                        p = f["path"]
                        tf.add(p, arcname=Path(p).name)
                self._progress = 1.0
                self._status = "Done"
            elif fmt in ["tar.xz", "txz"]:
                out_path = os.path.join(self._output_dir, out_name + ".tar.xz")
                base = Path(out_path).stem.replace(".tar", "")
                ddir = Path(out_path).parent
                cand = out_path
                if os.path.exists(cand):
                    i = 1
                    while True:
                        cand = str(ddir / f"{base} ({i}).tar.xz")
                        if not os.path.exists(cand):
                            out_path = cand
                            break
                        i += 1
                        if i > 1000:
                            break
                with tarfile.open(out_path, "w:xz") as tf:
                    for f in self._files:
                        p = f["path"]
                        tf.add(p, arcname=Path(p).name)
                self._progress = 1.0
                self._status = "Done"
            elif fmt in ["tar.bz2", "tbz2"]:
                out_path = os.path.join(self._output_dir, out_name + ".tar.bz2")
                base = Path(out_path).stem.replace(".tar", "")
                ddir = Path(out_path).parent
                cand = out_path
                if os.path.exists(cand):
                    i = 1
                    while True:
                        cand = str(ddir / f"{base} ({i}).tar.bz2")
                        if not os.path.exists(cand):
                            out_path = cand
                            break
                        i += 1
                        if i > 1000:
                            break
                with tarfile.open(out_path, "w:bz2") as tf:
                    for f in self._files:
                        p = f["path"]
                        tf.add(p, arcname=Path(p).name)
                self._progress = 1.0
                self._status = "Done"
            else:
                self._error = "Unsupported format"
                self.errorChanged.emit()
                self._status = "Failed"
            self.progressChanged.emit()
            self.statusChanged.emit()
        except Exception as e:
            self._error = str(e)[:200]
            self.errorChanged.emit()
            self._status = "Failed"
            self.statusChanged.emit()
        finally:
            self._compressing = False
            self.compressingChanged.emit()

    @Slot(str)
    def extract(self, archive_path=None):
        if self._extracting:
            return
        path = archive_path or (self._files[0]["path"] if self._files else None)
        if not path:
            self._error = "No archive to extract"
            self.errorChanged.emit()
            return
        p = path.replace("file://", "").strip()
        if not os.path.exists(p):
            self._error = "Archive not found"
            self.errorChanged.emit()
            return
        Path(self._output_dir).mkdir(parents=True, exist_ok=True)
        self._error = ""
        self._progress = 0.0
        self._extracting = True
        self._status = "Extracting..."
        self.progressChanged.emit()
        self.extractingChanged.emit()
        self.statusChanged.emit()
        self.errorChanged.emit()
        try:
            ext = Path(p).suffix.lower()
            name = Path(p).name.lower()
            if name.endswith(".tar.gz") or name.endswith(".tgz"):
                with tarfile.open(p, "r:gz") as tf:
                    tf.extractall(self._output_dir)
            elif name.endswith(".tar.xz") or name.endswith(".txz"):
                with tarfile.open(p, "r:xz") as tf:
                    tf.extractall(self._output_dir)
            elif name.endswith(".tar.bz2") or name.endswith(".tbz2"):
                with tarfile.open(p, "r:bz2") as tf:
                    tf.extractall(self._output_dir)
            elif ext == ".tar":
                with tarfile.open(p, "r:") as tf:
                    tf.extractall(self._output_dir)
            elif ext == ".zip":
                with zipfile.ZipFile(p, "r") as zf:
                    zf.extractall(self._output_dir)
            else:
                self._error = "Unsupported archive format"
                self.errorChanged.emit()
                self._status = "Failed"
                self.extractingChanged.emit()
                self.statusChanged.emit()
                self._extracting = False
                return
            self._progress = 1.0
            self._status = "Done"
            self.progressChanged.emit()
            self.statusChanged.emit()
        except Exception as e:
            self._error = str(e)[:200]
            self.errorChanged.emit()
            self._status = "Failed"
            self.statusChanged.emit()
        finally:
            self._extracting = False
            self.extractingChanged.emit()
