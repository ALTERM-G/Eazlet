from typing import TYPE_CHECKING

from PySide6.QtCore import Property, QObject, Signal

if TYPE_CHECKING:
    from .controller import Controller


class LanguageManager(QObject):
    dataChanged = Signal()

    def __init__(self, controller: "Controller", parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._controller = controller
        self._data: dict = {}
        self._controller.languageChanged.connect(self._reload)
        self._reload()

    def _section(self, name: str) -> dict:
        value = self._data.get(name, {})
        return value if isinstance(value, dict) else {}

    def _reload(self) -> None:
        self._data = self._controller.get_language_data()
        self.dataChanged.emit()

    @Property("QVariantMap", notify=dataChanged)
    def titles(self) -> dict:
        return self._section("titles")

    @Property("QVariantMap", notify=dataChanged)
    def tabs(self) -> dict:
        return self._section("tabs")

    @Property("QVariantMap", notify=dataChanged)
    def labels(self) -> dict:
        return self._section("labels")

    @Property("QVariantMap", notify=dataChanged)
    def shortcuts(self) -> dict:
        return self._section("shortcuts")

    @Property("QVariantMap", notify=dataChanged)
    def sidebar(self) -> dict:
        return self._section("sidebar")

    @Property("QVariantMap", notify=dataChanged)
    def common(self) -> dict:
        return self._section("common")

    @Property("QVariantMap", notify=dataChanged)
    def home(self) -> dict:
        return self._section("home")

    @Property("QVariantMap", notify=dataChanged)
    def pages(self) -> dict:
        return self._section("pages")

    @Property("QVariantMap", notify=dataChanged)
    def placeholders(self) -> dict:
        return self._section("placeholders")

    @Property("QVariantMap", notify=dataChanged)
    def messages(self) -> dict:
        return self._section("messages")

    @Property("QVariantMap", notify=dataChanged)
    def options(self) -> dict:
        return self._section("options")

    @Property(str, notify=dataChanged)
    def greeting(self) -> str:
        return self._data.get("greeting", "Have Fun !")

    @Property(str, notify=dataChanged)
    def language(self) -> str:
        return self._data.get("language", "English")

    @Property("QVariantList", notify=dataChanged)
    def languages(self) -> list:
        value = self._data.get(
            "languages", ["English", "French", "Spanish", "German", "Italian"]
        )
        return value if isinstance(value, list) else []
