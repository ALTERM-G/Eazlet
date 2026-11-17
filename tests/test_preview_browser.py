from pathlib import Path
from types import SimpleNamespace

import pytest
from PySide6.QtCore import QObject, QPointF, QUrl
from PySide6.QtQml import QQmlExpression

import run

ROOT = Path(__file__).resolve().parent.parent
MAIN_QML = ROOT / "src" / "eazlet" / "ui" / "main.qml"
ASCII_ART_INDEX = 7


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
def font_browser(qapp, qtbot):
    # The engine must stay referenced for the whole test: it owns the window.
    engine = run.build_engine()
    engine.load(QUrl.fromLocalFile(str(MAIN_QML)))
    assert engine.rootObjects(), "main.qml failed to load"

    window = engine.rootObjects()[0]
    window.resize(1400, 900)
    qtbot.wait(300)

    stack = next(
        child
        for child in window.findChildren(QObject)
        if class_name(child).startswith("QQuickStackLayout")
    )
    stack.setProperty("currentIndex", ASCII_ART_INDEX)
    qtbot.wait(400)
    page = stack.childItems()[ASCII_ART_INDEX].property("item")

    browser = next(
        item for item in page.findChildren(QObject)
        if class_name(item) == "PreviewBrowser"
    )
    browser.open()
    qtbot.wait(500)

    all_items = list(iter_items(window.contentItem()))
    item_list = next(
        item for item in all_items
        if class_name(item) == "QQuickListView"
        and item.property("rowHeight") is not None
    )
    grid_views = [item for item in all_items if class_name(item) == "QQuickGridView"]

    return SimpleNamespace(
        engine=engine,
        window=window,
        browser=browser,
        item_list=item_list,
        all_items=all_items,
        grid_views=grid_views,
    )


def test_font_chooser_uses_horizontal_rows(font_browser):
    assert not font_browser.grid_views, "small GridView cards should be gone"
    item_list = font_browser.item_list
    assert item_list.property("count") > 1

    rows = [
        item for item in iter_items(item_list)
        if class_name(item) == "QQuickRectangle"
        and item.property("selected") is not None
    ]
    assert rows
    for row in rows:
        # A row spans the full list width and is far taller than the old
        # ~113px grid cells, so the FIGlet art has room to be legible.
        assert row.width() == pytest.approx(item_list.width())
        assert row.height() >= item_list.property("rowHeight") - 1
        assert row.height() > 110


def test_preview_art_renders_at_legible_size(font_browser):
    engine = font_browser.engine
    arts = [
        item for item in iter_items(font_browser.item_list)
        if class_name(item) == "QQuickText"
        and item.property("text")
        and "\n" in str(item.property("text"))
        and item.property("scale") != 1.0
    ]
    assert arts, "FIGlet art should be rendered in each row"

    # The rendered size is pixelSize * scale. At least some fonts should be
    # noticeably larger than the old ~11px tiles produced.
    effective_sizes = [evaluate(engine, art, "font.pixelSize * scale") for art in arts]
    assert max(effective_sizes) >= 14


def test_preview_art_is_left_aligned_as_a_character_grid(font_browser):
    # Most FIGlet fonts produce rows of different lengths. Centring each row
    # independently scrambles the art, so the rendered Text must be left
    # aligned (Qt.AlignLeft == 1) even though the block itself is centred.
    visible_art = [
        item for item in iter_items(font_browser.item_list)
        if class_name(item) == "QQuickText"
        and item.property("visible")
        and item.property("text")
        and "\n" in str(item.property("text"))
    ]
    assert visible_art
    for art in visible_art:
        alignment = evaluate(font_browser.engine, art, "horizontalAlignment")
        assert int(alignment) == 1


def test_scrollbar_sits_in_gutter_with_usable_thumb(font_browser):
    bars = [
        item for item in font_browser.all_items
        if class_name(item) == "ScrollBar"
        and item.property("visible")
        and item.width() < 20
    ]
    assert bars
    bar = bars[0]

    assert bar.property("minimumSize") == pytest.approx(0.14)
    # With hundreds of fonts the raw ratio is tiny; the thumb must still be
    # large enough to grab.
    assert bar.property("contentItem").height() >= 60

    pane_right = font_browser.item_list.mapToScene(
        QPointF(font_browser.item_list.width(), 0)
    ).x()
    bar_left = bar.mapToScene(QPointF(0, 0)).x()
    assert bar_left >= pane_right - 1


def test_search_selection_and_apply_still_work(font_browser, qtbot):
    browser = font_browser.browser
    vm = font_browser.engine.rootContext().contextProperty("asciiArtVM")

    browser.setProperty("searchText", "standard")
    qtbot.wait(100)
    engine = font_browser.engine
    count = int(evaluate(engine, browser, "filteredItems.length"))
    assert count > 0
    first = str(evaluate(engine, browser, "filteredItems[0]"))
    assert "standard" in first

    browser.selectItem(first)
    assert browser.property("selectedItem") == first

    browser.applySelected()
    qtbot.wait(100)
    assert vm.property("font") == first


def test_empty_state_shows_when_no_matches(font_browser, qtbot):
    browser = font_browser.browser
    browser.setProperty("searchText", "definitely-not-a-real-font")
    qtbot.wait(100)
    assert int(evaluate(font_browser.engine, browser, "filteredItems.length")) == 0

    labels = [
        item for item in iter_items(font_browser.item_list.parent())
        if class_name(item) == "Label" and item.property("visible")
    ]
    assert labels
