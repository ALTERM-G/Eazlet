import os
from pathlib import Path

from PySide6.QtCore import Property, QObject, QUrl, Signal, Slot
from PySide6.QtGui import QColor, QImageReader

from .base_vm import BaseVM

DEFAULT_TIERS = (
    ("S", "#FF7F7F"),
    ("A", "#FFBF7F"),
    ("B", "#FFDF7F"),
    ("C", "#BFFF7F"),
    ("D", "#7FBFFF"),
    ("F", "#BF7FFF"),
)

TIER_COLORS = (
    "#FF7F7F",
    "#FFBF7F",
    "#FFDF7F",
    "#BFFF7F",
    "#7FBFFF",
    "#BF7FFF",
    "#FF7FFF",
    "#7FFFFF",
    "#FF9F9F",
    "#9FBFFF",
)

IMAGE_SUFFIXES = {
    ".png",
    ".jpg",
    ".jpeg",
    ".bmp",
    ".gif",
    ".webp",
    ".tif",
    ".tiff",
    ".svg",
    ".ico",
}


class TierListVM(BaseVM):
    """State for the tier list editor.

    The view model owns the ordered list of tiers, the images that were added,
    and which tier (or the unranked pool) each image currently belongs to.
    Every mutation emits both notifications so the QML board can rebuild from
    a single snapshot without tracking partial updates.
    """

    tiersChanged = Signal()
    itemsChanged = Signal()
    messageChanged = Signal()

    MAX_TIERS = 12

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._items: dict[str, dict] = {}
        self._tiers: list[dict] = []
        self._pool: list[str] = []
        self._next_item_id = 1
        self._next_tier_id = 1
        self._message = ""
        self._reset_tiers()

    # -- helpers ---------------------------------------------------------
    def _reset_tiers(self) -> None:
        self._tiers = []
        self._next_tier_id = 1
        for name, color in DEFAULT_TIERS:
            self._tiers.append(self._new_tier(name, color))

    def _new_tier(self, name: str, color: str) -> dict:
        tier = {
            "id": f"tier-{self._next_tier_id}",
            "name": name,
            "color": color,
            "items": [],
        }
        self._next_tier_id += 1
        return tier

    def _find_tier(self, tier_id: str) -> dict | None:
        return next((tier for tier in self._tiers if tier["id"] == tier_id), None)

    def _tier_items(self, tier: dict) -> list[str]:
        return tier["items"]

    def _item_view(self, item_id: str) -> dict:
        item = self._items[item_id]
        return {
            "id": item_id,
            "name": item["name"],
            "path": item["path"],
            "url": item["url"],
        }

    def _set_message(self, message: str) -> None:
        if message == self._message:
            return
        self._message = message
        self.messageChanged.emit()

    def _notify(self) -> None:
        self.tiersChanged.emit()
        self.itemsChanged.emit()

    @staticmethod
    def _next_tier_name(used: set[str]) -> str:
        for letter in "SABCDEFGHIJKLMNOPQRSTUVWXYZ":
            if letter not in used:
                return letter
        return f"Tier {len(used) + 1}"

    @staticmethod
    def _normalize_source(source) -> str | None:
        # FileDialog and DropArea hand us QUrl values, while tests and direct
        # calls use plain strings. PySide's str(QUrl) is a repr, not the URL,
        # so handle QUrl explicitly before falling back to text parsing.
        if isinstance(source, QUrl):
            if not source.isValid():
                return None
            if source.isLocalFile():
                path = source.toLocalFile()
            elif source.scheme() == "":
                path = source.path()
            else:
                # Remote URLs are not supported by the board.
                return None
        else:
            text = str(source).strip()
            if not text:
                return None

            url = QUrl(text)
            if url.isLocalFile():
                path = url.toLocalFile()
            elif url.scheme() == "":
                path = text
            else:
                # Remote URLs are not supported by the board.
                return None

        path = os.path.abspath(os.path.expanduser(path))
        if not os.path.isfile(path):
            return None
        return path

    @staticmethod
    def _can_read_image(path: str) -> bool:
        suffix = Path(path).suffix.lower()
        if suffix not in IMAGE_SUFFIXES:
            return False
        return QImageReader(path).canRead()

    # -- properties ------------------------------------------------------
    @Property(list, notify=tiersChanged)
    def tiers(self):
        result = []
        for tier in self._tiers:
            result.append(
                {
                    "id": tier["id"],
                    "name": tier["name"],
                    "color": tier["color"],
                    "items": [self._item_view(i) for i in tier["items"]],
                }
            )
        return result

    @Property(list, notify=itemsChanged)
    def pool(self):
        return [self._item_view(i) for i in self._pool]

    @Property(int, notify=itemsChanged)
    def itemCount(self) -> int:
        return len(self._items)

    @Property(int, notify=itemsChanged)
    def poolCount(self) -> int:
        return len(self._pool)

    @Property(int, notify=tiersChanged)
    def tierCount(self) -> int:
        return len(self._tiers)

    @Property(int, constant=True)
    def maxTiers(self) -> int:
        return self.MAX_TIERS

    @Property(str, notify=messageChanged)
    def message(self) -> str:
        return self._message

    # -- items -----------------------------------------------------------
    @Slot(list)
    def addFiles(self, sources) -> None:
        if not sources:
            return

        added = 0
        skipped = 0
        for source in sources:
            path = self._normalize_source(source)
            if not path or not self._can_read_image(path):
                skipped += 1
                continue

            item_id = f"item-{self._next_item_id}"
            self._next_item_id += 1
            self._items[item_id] = {
                "name": Path(path).name,
                "path": path,
                "url": QUrl.fromLocalFile(path).toString(),
            }
            self._pool.append(item_id)
            added += 1

        if added:
            if skipped:
                msg = self.tr("pages.tierList.msgAddedSkipped", "Added {added} image(s); skipped {skipped} unsupported file(s).")
                self._set_message(msg.replace("{added}", str(added)).replace("{skipped}", str(skipped)))
            else:
                msg = self.tr("pages.tierList.msgAdded", "Added {count} image(s).")
                self._set_message(msg.replace("{count}", str(added)))
            self._notify()
        elif skipped:
            self._set_message(self.tr("pages.tierList.msgNoSupported", "No supported images were found in that selection."))

    @Slot(str)
    def removeItem(self, item_id: str) -> bool:
        if item_id not in self._items:
            return False

        del self._items[item_id]
        if item_id in self._pool:
            self._pool.remove(item_id)
        for tier in self._tiers:
            if item_id in tier["items"]:
                tier["items"].remove(item_id)
        self._notify()
        return True

    @Slot(str, str)
    def assignItem(self, item_id: str, tier_id: str) -> bool:
        return self.assignItemAt(item_id, tier_id, -1)

    @Slot(str, str, int)
    def assignItemAt(self, item_id: str, tier_id: str, index: int) -> bool:
        if item_id not in self._items:
            return False

        if tier_id == "":
            target = self._pool
        else:
            tier = self._find_tier(tier_id)
            if tier is None:
                return False
            target = tier["items"]

        old_index = target.index(item_id) if item_id in target else -1

        if item_id in self._pool:
            self._pool.remove(item_id)
        for tier in self._tiers:
            if item_id in tier["items"]:
                tier["items"].remove(item_id)

        if index < 0:
            position = len(target)
        else:
            position = index
            # The index came from a snapshot that still contained the dragged
            # item, so remove one slot when moving forward inside the same list.
            if old_index >= 0 and old_index < position:
                position -= 1
            position = max(0, min(len(target), position))

        target.insert(position, item_id)
        self._notify()
        return True

    @Slot()
    def clearItems(self) -> None:
        if not self._items and not self._pool:
            return
        self._items = {}
        self._pool = []
        for tier in self._tiers:
            tier["items"] = []
        self._set_message(self.tr("pages.tierList.msgRemovedAll", "Removed all images."))
        self._notify()

    # -- tiers -----------------------------------------------------------
    @Slot(result=str)
    def addTier(self) -> str:
        if len(self._tiers) >= self.MAX_TIERS:
            self._set_message(self.tr("pages.tierList.msgMaxTiers", "A tier list can have at most {max} tiers.").replace("{max}", str(self.MAX_TIERS)))
            return ""

        used = {tier["name"].upper() for tier in self._tiers}
        name = self._next_tier_name(used)
        color = TIER_COLORS[len(self._tiers) % len(TIER_COLORS)]
        tier = self._new_tier(name, color)
        self._tiers.append(tier)
        self._notify()
        return tier["id"]

    @Slot(str)
    def removeTier(self, tier_id: str) -> bool:
        tier = self._find_tier(tier_id)
        if tier is None:
            return False
        if len(self._tiers) <= 1:
            self._set_message(self.tr("pages.tierList.msgKeepOne", "Keep at least one tier so images have somewhere to go."))
            return False

        self._tiers.remove(tier)
        # Images never disappear just because their band was deleted.
        self._pool.extend(tier["items"])
        self._notify()
        return True

    @Slot(str, str)
    def renameTier(self, tier_id: str, name: str) -> bool:
        tier = self._find_tier(tier_id)
        if tier is None:
            return False
        cleaned = str(name).strip()
        if not cleaned or cleaned == tier["name"]:
            return False
        tier["name"] = cleaned
        self._notify()
        return True

    @Slot(str, str)
    def setTierColor(self, tier_id: str, color: str) -> bool:
        tier = self._find_tier(tier_id)
        if tier is None:
            return False
        parsed = QColor(str(color))
        if not parsed.isValid():
            return False
        normalized = parsed.name().upper()
        if normalized == tier["color"]:
            return False
        tier["color"] = normalized
        self._notify()
        return True

    @Slot(str, int)
    def moveTier(self, tier_id: str, delta: int) -> bool:
        tier = self._find_tier(tier_id)
        if tier is None or delta == 0:
            return False
        index = self._tiers.index(tier)
        target = max(0, min(len(self._tiers) - 1, index + delta))
        if target == index:
            return False
        self._tiers.pop(index)
        self._tiers.insert(target, tier)
        self._notify()
        return True

    @Slot()
    def reset(self) -> None:
        self._items = {}
        self._pool = []
        self._next_item_id = 1
        self._reset_tiers()
        self._set_message("")
        self._notify()

    @Slot(str)
    def setMessage(self, message: str) -> None:
        self._set_message(str(message))
