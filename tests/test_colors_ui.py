from pathlib import Path

from PySide6.QtCore import QObject, QUrl

import run

ROOT = Path(__file__).resolve().parent.parent
COLORS_INDEX = 12


def class_name(obj):
    return obj.metaObject().className().split("_QML")[0]


def test_colors_page_has_screen_picker_button(qapp, qtbot):
    engine = run.build_engine()
    engine.load(QUrl.fromLocalFile(str(ROOT / "src/eazlet/ui/main.qml")))
    assert engine.rootObjects()

    window = engine.rootObjects()[0]
    window.resize(1400, 900)
    stack = next(
        child
        for child in window.findChildren(QObject)
        if class_name(child).startswith("QQuickStackLayout")
    )
    stack.setProperty("currentIndex", COLORS_INDEX)
    qtbot.wait(200)

    page = stack.childItems()[COLORS_INDEX].property("item")
    assert page is not None

    buttons = [
        child
        for child in page.findChildren(QObject)
        if child.property("buttonText") == "Pick from screen"
    ]
    assert len(buttons) == 1
    assert str(buttons[0].property("iconPath")).endswith("color_picker.svg")
