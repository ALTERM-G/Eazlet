import os
import hashlib
from collections import defaultdict
from pathlib import Path

from PySide6.QtCore import Property, QObject, Signal, Slot
from PySide6.QtGui import QDesktopServices

from .base_vm import BaseVM


class OrganizerVM(BaseVM):
    folderChanged = Signal()
    scanningChanged = Signal()
    filesChanged = Signal()
    duplicatesChanged = Signal()
    statusChanged = Signal()
    errorChanged = Signal()
    progressChanged = Signal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._folder = str(Path.home() / "Downloads")
        self._scanning = False
        self._files = []
        self._duplicates = []
        self._status = "Idle"
        self._error = ""
        self._progress = 0.0

    @Property(str, notify=folderChanged)
    def folder(self):
        return self._folder

    @folder.setter
    def folder(self, value):
        if value:
            p = value.replace("file://", "").strip()
            if p != self._folder:
                self._folder = p
                self.folderChanged.emit()

    @Property(bool, notify=scanningChanged)
    def scanning(self):
        return self._scanning

    @Property(list, notify=filesChanged)
    def files(self):
        return self._files

    @Property(list, notify=duplicatesChanged)
    def duplicates(self):
        return self._duplicates

    @Property(str, notify=statusChanged)
    def status(self):
        return self._status

    @Property(str, notify=errorChanged)
    def error(self):
        return self._error

    @Property(float, notify=progressChanged)
    def progress(self):
        return self._progress

    @Slot()
    def openFolder(self):
        try:
            from PySide6.QtCore import QUrl
            QDesktopServices.openUrl(QUrl.fromLocalFile(os.path.abspath(self._folder)))
        except Exception:
            pass

    def _hash_file(self, path):
        h = hashlib.md5()
        try:
            with open(path, "rb") as f:
                for chunk in iter(lambda: f.read(8192), b""):
                    h.update(chunk)
            return h.hexdigest()
        except Exception:
            return None

    @Slot()
    def scan(self):
        if self._scanning:
            return
        if not os.path.isdir(self._folder):
            self._error = "Folder not found"
            self.errorChanged.emit()
            return
        self._error = ""
        self._status = "Scanning..."
        self._scanning = True
        self._progress = 0.0
        self._files = []
        self._duplicates = []
        self.scanningChanged.emit()
        self.statusChanged.emit()
        self.errorChanged.emit()
        self.progressChanged.emit()
        self.filesChanged.emit()
        self.duplicatesChanged.emit()
        try:
            all_files = []
            for root, dirs, files in os.walk(self._folder):
                for fn in files:
                    full = os.path.join(root, fn)
                    try:
                        st = os.stat(full)
                        all_files.append({"path": full, "name": fn, "size": st.st_size, "dir": root})
                    except Exception:
                        continue
            self._files = all_files
            self.filesChanged.emit()
            self._status = f"Found {len(all_files)} files. Checking duplicates..."
            self.statusChanged.emit()
            # group by size first
            by_size = defaultdict(list)
            for f in all_files:
                by_size[f["size"]].append(f)
            candidates = []
            for sz, lst in by_size.items():
                if sz > 0 and len(lst) > 1:
                    candidates.extend(lst)
            # hash candidates
            hashes = defaultdict(list)
            total = len(candidates)
            for i, f in enumerate(candidates):
                h = self._hash_file(f["path"])
                if h:
                    hashes[h].append(f)
                self._progress = (i + 1) / total if total > 0 else 1.0
                self.progressChanged.emit()
            dup_groups = []
            for h, lst in hashes.items():
                if len(lst) > 1:
                    dup_groups.append({"hash": h, "files": lst})
            self._duplicates = dup_groups
            self.duplicatesChanged.emit()
            self._progress = 1.0
            self._status = f"Done. {len(dup_groups)} duplicate groups found"
            self.progressChanged.emit()
            self.statusChanged.emit()
        except Exception as e:
            self._error = str(e)[:200]
            self.errorChanged.emit()
            self._status = "Failed"
            self.statusChanged.emit()
        finally:
            self._scanning = False
            self.scanningChanged.emit()

    @Slot(str)
    def renameSequential(self, pattern="file"):
        if self._scanning:
            return
        if not os.path.isdir(self._folder):
            self._error = "Folder not found"
            self.errorChanged.emit()
            return
        if not pattern or not pattern.strip():
            pattern = "file"
        pattern = pattern.strip().replace("/", "_").replace("\\", "_")
        self._error = ""
        self._status = "Renaming..."
        self.statusChanged.emit()
        self.errorChanged.emit()
        try:
            items = []
            for root, dirs, files in os.walk(self._folder):
                # only top level
                for fn in files:
                    items.append(os.path.join(root, fn))
                break
            items.sort()
            count = 0
            for i, full in enumerate(items):
                ext = Path(full).suffix
                new_name = f"{pattern} {i+1}{ext}"
                new_path = os.path.join(self._folder, new_name)
                if os.path.normcase(new_path) == os.path.normcase(full):
                    continue
                if os.path.exists(new_path):
                    # try to find unique
                    j = 1
                    while True:
                        cand = os.path.join(self._folder, f"{pattern} {i+1} ({j}){ext}")
                        if not os.path.exists(cand) or os.path.normcase(cand) == os.path.normcase(full):
                            if not os.path.exists(cand):
                                new_path = cand
                            break
                        j += 1
                        if j > 1000:
                            break
                try:
                    if os.path.exists(new_path) and os.path.normcase(new_path) != os.path.normcase(full):
                        continue
                    os.rename(full, new_path)
                    count += 1
                except Exception:
                    continue
            self._status = f"Renamed {count} files"
            self.statusChanged.emit()
            self.scan()
        except Exception as e:
            self._error = str(e)[:200]
            self.errorChanged.emit()
            self._status = "Failed"
            self.statusChanged.emit()
