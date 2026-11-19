from PySide6.QtCore import QObject


class BaseVM(QObject):
    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)

    def tr(self, key: str, default: str = "", **kwargs) -> str:
        parent = self.parent()
        text = None
        if parent is not None and hasattr(parent, "translate"):
            try:
                text = parent.translate(key, default)
            except Exception:
                text = None
        if not isinstance(text, str):
            text = default if default else key
        if kwargs:
            try:
                text = text.format(**kwargs)
            except Exception:
                pass
        return text