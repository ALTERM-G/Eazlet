from pathlib import Path

from PySide6.QtCore import QObject, Qt, QUrl
from PySide6.QtQml import QQmlExpression

import run

ROOT = Path(__file__).resolve().parent.parent
UI = ROOT / "src" / "eazlet" / "ui"
COMPONENTS = UI / "components"
PAGES = UI / "pages"

# Archive keeps its original handler; its source file is intentionally not
# touched by this refactor. TabBar's `interactive: false` is unrelated
# (it suppresses swipe navigation, not wheel scrolling).
WHEEL_PAGES = [
    "AsciiArt",
    "Cipher",
    "Colors",
    "Converter",
    "DownloadUnified",
    "Generators",
    "Mathematics",
    "NumberTools",
    "Organizer",
    "TextAnalysis",
    "TierList",
]

THUMB_HOSTS = [
    COMPONENTS / "controls" / "AppScrollBar.qml",
    COMPONENTS / "controls" / "TextEdit.qml",
    COMPONENTS / "controls" / "ComboBox.qml",
    COMPONENTS / "popups" / "PreviewBrowser.qml",
]


def class_name(obj):
    return obj.metaObject().className().split("_QML")[0]


def iter_items(item):
    yield item
    for child in item.childItems():
        yield from iter_items(child)


def evaluate(engine, obj, expression):
    expr = QQmlExpression(engine.contextForObject(obj), obj, expression)
    value = expr.evaluate()
    if isinstance(value, tuple):
        value = value[0]
    assert not expr.hasError(), expr.error().toString()
    return value


def test_shared_components_are_registered():
    qmldir = (COMPONENTS / "qmldir").read_text()
    assert "ScrollBarThumb 1.0 controls/ScrollBarThumb.qml" in qmldir
    assert "WheelScrollArea 1.0 controls/WheelScrollArea.qml" in qmldir


def test_thumb_visual_lives_only_in_shared_component():
    thumb_source = (COMPONENTS / "controls" / "ScrollBarThumb.qml").read_text()
    assert "bar.pressed ? Theme.themeColor" in thumb_source
    assert "bar.hovered ? Theme.borderColor" in thumb_source
    assert "bar.active || bar.hovered" in thumb_source

    for path in THUMB_HOSTS:
        source = path.read_text()
        assert "ScrollBarThumb" in source, path
        # No copy of the pressed/hovered/opacity styling should remain.
        assert ".pressed ? Theme.themeColor" not in source, path
        assert "opacity: (" not in source, path


def test_pages_use_shared_wheel_handler():
    for name in WHEEL_PAGES:
        source = (PAGES / f"{name}.qml").read_text()
        assert "onWheel:" not in source, name
        assert "interactive: false" not in source, name
        assert "acceptedButtons: Qt.NoButton" in source, name
        assert "WheelScrollArea {" in source, name


def test_archive_is_left_untouched():
    source = (PAGES / "Archive.qml").read_text()
    assert "onWheel: function" in source
    assert "interactive: false" in source


def test_text_edit_chains_page_scrolling():
    source = (COMPONENTS / "controls" / "TextEdit.qml").read_text()
    assert "target: view.contentItem" in source
    assert "fallback: control.pageFlickable()" in source


def test_tier_list_pool_keeps_smaller_scroll_step():
    source = (PAGES / "TierList.qml").read_text()
    assert source.count("WheelScrollArea {") == 2
    assert "step: LayoutMetrics.unit * 12" in source


def test_controls_use_shared_wheel_handler():
    combo = (COMPONENTS / "controls" / "ComboBox.qml").read_text()
    assert "onWheel:" not in combo
    assert "acceptedButtons: Qt.NoButton" in combo
    assert "Components.WheelScrollArea" in combo

    settings = (COMPONENTS / "settings" / "Settings.qml").read_text()
    assert "onWheel:" not in settings
    assert 'property: "acceptedButtons"' in settings
    assert "value: Qt.NoButton" in settings
    assert "WheelScrollArea {" in settings


def test_page_flickable_stays_interactive_without_mouse_drag(qapp, qtbot):
    engine = run.build_engine()
    engine.load(QUrl.fromLocalFile(str(UI / "main.qml")))
    assert engine.rootObjects(), "main.qml failed to load"
    window = engine.rootObjects()[0]
    window.resize(1400, 900)
    stack = next(
        child
        for child in window.findChildren(QObject)
        if class_name(child).startswith("QQuickStackLayout")
    )
    stack.setProperty("currentIndex", 5)  # Cipher has overflowing content
    qtbot.wait(300)
    page = stack.childItems()[5].property("item")
    assert page is not None

    scrollers = [
        item
        for item in iter_items(page)
        if item.property("step") is not None and item.property("target") is not None
    ]
    assert scrollers, "Cipher should use a shared WheelScrollArea"

    scroller = scrollers[0]
    flick = scroller.property("target")
    assert evaluate(engine, flick, "interactive") is True
    assert flick.property("acceptedButtons") == Qt.NoButton
    assert float(scroller.property("step")) > 0

    # Make overflow explicit so the assertion does not depend on the current
    # scale factor or window size.
    flick.setProperty("contentHeight", flick.height() + 500)
    flick.setProperty("contentY", 0)
    # The trailing literal keeps QQmlExpression happy: a bare void call reports
    # an "undefined result" error even though it ran.
    evaluate(engine, scroller, "scrollBy(-120); 1")
    assert flick.property("contentY") > 0
