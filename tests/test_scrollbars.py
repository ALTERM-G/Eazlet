from pathlib import Path

import pytest
from PySide6.QtCore import QObject, QPointF, QUrl
from PySide6.QtGui import QImage
from PySide6.QtQml import QQmlExpression

import run

ROOT = Path(__file__).resolve().parent.parent
MAIN_QML = ROOT / "src" / "eazlet" / "ui" / "main.qml"


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


@pytest.fixture
def app_window(qapp, qtbot):
    engine = run.build_engine()
    engine.load(QUrl.fromLocalFile(str(MAIN_QML)))
    assert engine.rootObjects(), "main.qml failed to load"
    window = engine.rootObjects()[0]
    window.resize(1400, 900)
    qtbot.wait(300)
    return engine, window


def page_scrollbars(engine, window, index, qtbot):
    stack = next(
        child
        for child in window.findChildren(QObject)
        if class_name(child).startswith("QQuickStackLayout")
    )
    stack.setProperty("currentIndex", index)
    qtbot.wait(400)
    page = stack.childItems()[index].property("item")
    assert page is not None
    return [item for item in iter_items(page) if class_name(item) == "AppScrollBar"]


def test_app_scrollbar_matches_font_chooser_style(app_window, qtbot):
    engine, window = app_window
    bars = page_scrollbars(engine, window, 13, qtbot)  # Tier List has a long board
    assert bars
    bar = bars[0]

    unit = evaluate(engine, bar, "LayoutMetrics.unit")
    assert bar.property("implicitWidth") == pytest.approx(unit * 1.2)
    assert evaluate(engine, bar, "policy === ScrollBar.AsNeeded")
    assert bar.property("hoverEnabled")
    assert bar.property("padding") == 0

    thumb = bar.property("contentItem")
    radius_m = evaluate(engine, bar, "LayoutMetrics.radius.m")
    assert thumb.property("radius") == pytest.approx(min(thumb.width() / 2, radius_m))
    # Idle state is faintly visible, like the ASCII font chooser's grid bar.
    assert thumb.property("opacity") == pytest.approx(0.55)


@pytest.mark.parametrize("index", [1, 2, 5, 7, 8, 13])
def test_page_scrollbar_sits_in_gutter(app_window, qtbot, index):
    engine, window = app_window
    bars = page_scrollbars(engine, window, index, qtbot)
    assert bars, f"page {index} should have a scroll bar"

    for bar in bars:
        flick = bar.property("flick")
        assert flick is not None
        assert bar.property("gutterHost") is not None
        flick_right = flick.mapToScene(QPointF(flick.width(), 0)).x()
        bar_left = bar.mapToScene(QPointF(0, 0)).x()
        # The bar must start at or after the flickable's right edge: it lives
        # in the workplace margin, never on top of the widgets.
        assert bar_left >= flick_right - 0.5


def test_scrollbar_scales_with_app(app_window, qtbot):
    engine, window = app_window
    bar = page_scrollbars(engine, window, 13, qtbot)[0]

    widths = {}
    for factor in (0.5, 1.0, 1.5):
        evaluate(engine, bar, f"LayoutMetrics.scaleFactor = {factor}; "
                              f"Typography.scaleFactor = {factor}")
        qtbot.wait(200)
        widths[factor] = bar.property("implicitWidth")

    assert widths[0.5] < widths[1.0] < widths[1.5]
    assert widths[1.0] == pytest.approx(widths[0.5] * 2)
    assert widths[1.5] == pytest.approx(widths[0.5] * 3)


def test_scrollbar_thumb_does_not_overlap_content(app_window, qtbot, tmp_path):
    engine, window = app_window
    bar = page_scrollbars(engine, window, 13, qtbot)[0]
    flick = bar.property("flick")

    vm = engine.rootContext().contextProperty("tierListVM")
    path = tmp_path / "image.png"
    image = QImage(48, 48, QImage.Format.Format_RGB32)
    image.fill(0x204080)
    assert image.save(str(path))
    vm.addFiles([str(path)])
    qtbot.wait(300)
    assert bar.property("visible")

    flick_right = flick.mapToScene(QPointF(flick.width(), 0)).x()
    bar_left = bar.mapToScene(QPointF(0, 0)).x()
    assert bar_left > flick_right
