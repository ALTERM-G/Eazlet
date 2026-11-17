from pathlib import Path
from types import SimpleNamespace

import pytest
from PySide6.QtCore import QObject, QPoint, QPointF, Qt, QUrl
from PySide6.QtGui import QImage
from PySide6.QtQml import QQmlExpression
from PySide6.QtTest import QTest

import run

ROOT = Path(__file__).resolve().parent.parent
MAIN_QML = ROOT / "src" / "eazlet" / "ui" / "main.qml"
TIER_LIST_INDEX = 13


def class_name(obj):
    return obj.metaObject().className().split("_QML")[0]


def iter_items(item):
    """Walk the visual tree; Repeater delegates have no QObject parent."""
    yield item
    for child in item.childItems():
        yield from iter_items(child)


def make_images(tmp_path, count):
    paths = []
    for index in range(count):
        path = tmp_path / f"image{index}.png"
        image = QImage(48, 48, QImage.Format.Format_RGB32)
        image.fill(0x204080 + index * 0x10101)
        assert image.save(str(path))
        paths.append(str(path))
    return paths


@pytest.fixture
def tier_page(qapp, qtbot, tmp_path):
    # The engine has to stay referenced for the whole test: it owns the window.
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
    stack.setProperty("currentIndex", TIER_LIST_INDEX)
    qtbot.wait(400)

    page = stack.childItems()[TIER_LIST_INDEX].property("item")
    vm = engine.rootContext().contextProperty("tierListVM")
    assert vm is not None

    vm.addFiles(make_images(tmp_path, 3))
    qtbot.wait(300)

    return SimpleNamespace(engine=engine, window=window, page=page, vm=vm)


def refresh(page):
    content = page.childItems()[1].childItems()[0].childItems()[0]
    column = next(
        child for child in content.childItems() if class_name(child) == "QQuickColumn"
    )
    board = next(
        child
        for child in column.childItems()
        if class_name(child) == "QQuickRectangle" and child.height() > 200
    )
    rows = [
        child
        for child in board.childItems()[0].childItems()
        if class_name(child) == "QQuickItem"
    ]
    pool_card = page.findChild(QObject, "poolCard")
    assert pool_card is not None
    return rows, pool_card


def scroll_row_into_view(page, row):
    flick = page.findChild(QObject, "boardFlick")
    assert flick is not None
    content = flick.property("contentItem")
    top = content.mapFromItem(row, QPointF(0, 0)).y()
    bottom = top + row.height()
    if top < flick.property("contentY") or bottom > (
        flick.property("contentY") + flick.height()
    ):
        flick.setProperty("contentY", max(0, top - 8))
        QTest.qWait(120)


def thumbnails(flow):
    return [child for child in flow.childItems() if child.width() > 0]


def pool_thumbnails(page):
    _, card = refresh(page)
    flow = next(
        child
        for child in card.findChildren(QObject)
        if class_name(child) == "QQuickFlow"
    )
    return thumbnails(flow)


def tier_thumbnails(page, index):
    rows, _ = refresh(page)
    flow = next(
        child for child in rows[index].childItems() if class_name(child) == "QQuickFlow"
    )
    return thumbnails(flow)


def scene_center(item, fx=0.5, fy=0.5):
    point = item.mapToScene(QPointF(item.width() * fx, item.height() * fy))
    return QPoint(round(point.x()), round(point.y()))


def drag(qtbot, window, start, end):
    QTest.mousePress(window, Qt.LeftButton, Qt.NoModifier, start)
    qtbot.wait(60)
    steps = 14
    for step in range(1, steps + 1):
        QTest.mouseMove(
            window,
            QPoint(
                start.x() + (end.x() - start.x()) * step // steps,
                start.y() + (end.y() - start.y()) * step // steps,
            ),
        )
        qtbot.wait(30)
    QTest.mouseRelease(window, Qt.LeftButton, Qt.NoModifier, end)
    qtbot.wait(500)


def test_drag_from_pool_into_a_tier(tier_page, qtbot):
    assert tier_page.vm.poolCount == 3

    rows, _ = refresh(tier_page.page)
    drag(
        qtbot,
        tier_page.window,
        scene_center(pool_thumbnails(tier_page.page)[0]),
        scene_center(rows[0]),
    )

    assert [item["name"] for item in tier_page.vm.tiers[0]["items"]] == ["image0.png"]
    assert tier_page.vm.poolCount == 2
    assert not tier_page.page.property("dragActive")
    assert tier_page.page.property("hoverZone") == "none"


def test_tier_height_stable_when_first_image_dropped(tier_page, qtbot):
    rows, _ = refresh(tier_page.page)
    empty_height = rows[0].height()
    assert not tier_page.vm.tiers[0]["items"]

    drag(
        qtbot,
        tier_page.window,
        scene_center(pool_thumbnails(tier_page.page)[0]),
        scene_center(rows[0]),
    )

    rows, _ = refresh(tier_page.page)
    assert len(tier_page.vm.tiers[0]["items"]) == 1
    assert rows[0].height() == pytest.approx(empty_height, abs=1)


def test_drag_between_tiers_and_back_to_pool(tier_page, qtbot):
    rows, pool_card = refresh(tier_page.page)
    drag(
        qtbot,
        tier_page.window,
        scene_center(pool_thumbnails(tier_page.page)[0]),
        scene_center(rows[0]),
    )
    assert len(tier_page.vm.tiers[0]["items"]) == 1

    # Scroll the board so both the source (row 0) and destination (row 1) are
    # inside the viewport before dragging between them.
    rows, _ = refresh(tier_page.page)
    scroll_row_into_view(tier_page.page, rows[0])
    rows, _ = refresh(tier_page.page)
    drag(
        qtbot,
        tier_page.window,
        scene_center(tier_thumbnails(tier_page.page, 0)[0]),
        scene_center(rows[1]),
    )
    assert tier_page.vm.tiers[0]["items"] == []
    assert [item["name"] for item in tier_page.vm.tiers[1]["items"]] == ["image0.png"]

    drag(
        qtbot,
        tier_page.window,
        scene_center(tier_thumbnails(tier_page.page, 1)[0]),
        scene_center(pool_card),
    )
    assert tier_page.vm.tiers[1]["items"] == []
    assert [item["name"] for item in tier_page.vm.pool][-1] == "image0.png"


def test_reorder_inside_a_tier(tier_page, qtbot):
    for _ in range(2):
        rows, _ = refresh(tier_page.page)
        drag(
            qtbot,
            tier_page.window,
            scene_center(pool_thumbnails(tier_page.page)[0]),
            scene_center(rows[0]),
        )
    assert [item["name"] for item in tier_page.vm.tiers[0]["items"]] == [
        "image0.png",
        "image1.png",
    ]

    thumbs = tier_thumbnails(tier_page.page, 0)
    last = thumbs[-1]
    after_last = last.mapToScene(QPointF(last.width() * 0.85, last.height() * 0.5))
    drag(
        qtbot,
        tier_page.window,
        scene_center(thumbs[0]),
        QPoint(round(after_last.x()), round(after_last.y())),
    )

    assert [item["name"] for item in tier_page.vm.tiers[0]["items"]] == [
        "image1.png",
        "image0.png",
    ]


def test_dropping_outside_the_board_changes_nothing(tier_page, qtbot):
    before = [item["name"] for item in tier_page.vm.pool]

    drag(
        qtbot,
        tier_page.window,
        scene_center(pool_thumbnails(tier_page.page)[0]),
        QPoint(20, 20),
    )

    assert [item["name"] for item in tier_page.vm.pool] == before
    assert tier_page.vm.tiers[0]["items"] == []


def test_click_to_select_then_click_a_tier(tier_page, qtbot):
    rows, _ = refresh(tier_page.page)
    scroll_row_into_view(tier_page.page, rows[1])
    rows, _ = refresh(tier_page.page)

    QTest.mouseClick(
        tier_page.window,
        Qt.LeftButton,
        Qt.NoModifier,
        scene_center(pool_thumbnails(tier_page.page)[0]),
    )
    qtbot.wait(200)
    assert tier_page.page.property("selectedItemId") != ""

    QTest.mouseClick(
        tier_page.window, Qt.LeftButton, Qt.NoModifier, scene_center(rows[1])
    )
    qtbot.wait(400)

    assert [item["name"] for item in tier_page.vm.tiers[1]["items"]] == ["image0.png"]
    assert tier_page.page.property("selectedItemId") == ""


def test_drag_preview_ghost_shows_predicted_slot(tier_page, qtbot):
    rows, _ = refresh(tier_page.page)
    start = scene_center(pool_thumbnails(tier_page.page)[0])
    end = scene_center(rows[0])

    QTest.mousePress(tier_page.window, Qt.LeftButton, Qt.NoModifier, start)
    qtbot.wait(60)
    steps = 14
    for step in range(1, steps + 1):
        QTest.mouseMove(
            tier_page.window,
            QPoint(
                start.x() + (end.x() - start.x()) * step // steps,
                start.y() + (end.y() - start.y()) * step // steps,
            ),
        )
        qtbot.wait(30)
    qtbot.wait(100)  # hold at the destination

    # The ghost is visible only for the hovered tier and sits at the slot the
    # image would occupy (the first slot of an empty tier == the flow origin).
    assert tier_page.page.property("hoverZone") == "tier"
    ghosts = [
        item for item in iter_items(tier_page.page)
        if item.objectName() == "insertionGhost"
    ]
    visible_ghosts = [ghost for ghost in ghosts if ghost.property("visible")]
    assert len(visible_ghosts) == 1
    ghost = visible_ghosts[0]
    assert ghost.property("opacity") == pytest.approx(0.45)
    border_expr = QQmlExpression(
        tier_page.engine.contextForObject(ghost), ghost, "border.width"
    )
    border_width = border_expr.evaluate()
    if isinstance(border_width, tuple):
        border_width = border_width[0]
    assert border_width == 0
    assert ghost.property("width") > 0 and ghost.property("height") > 0

    flow = next(
        child for child in rows[0].childItems() if class_name(child) == "QQuickFlow"
    )
    assert ghost.x() == pytest.approx(flow.x())

    image = next(
        child
        for child in ghost.childItems()
        if class_name(child) == "QQuickImage"
    )
    assert QUrl(image.property("source")).toLocalFile().endswith("image0.png")

    QTest.mouseRelease(tier_page.window, Qt.LeftButton, Qt.NoModifier, end)
    qtbot.wait(500)
    # The drop rebuilds the delegates, so re-query rather than reuse old refs.
    remaining_ghosts = [
        item for item in iter_items(tier_page.page)
        if item.objectName() == "insertionGhost"
    ]
    assert not any(ghost.property("visible") for ghost in remaining_ghosts)


def test_placeholder_labels_hidden_during_export(tier_page, qtbot):
    def placeholders():
        return [
            item
            for item in iter_items(tier_page.page)
            if item.property("text") == "Drag images here"
        ]

    labels = placeholders()
    assert labels
    assert all(label.property("visible") for label in labels)

    tier_page.page.setProperty("exporting", True)
    qtbot.wait(100)
    assert all(not label.property("visible") for label in labels)

    tier_page.page.setProperty("exporting", False)
    qtbot.wait(100)
    assert all(label.property("visible") for label in labels)


def test_export_saves_png_and_resets_flag(tier_page, qtbot, tmp_path):
    target = tmp_path / "tier-list.png"
    dialog = next(
        child
        for child in tier_page.page.findChildren(QObject)
        if child.property("title") == "Export tier list as an image"
    )
    dialog.setProperty("selectedFile", QUrl.fromLocalFile(str(target)))

    expression = QQmlExpression(
        tier_page.engine.contextForObject(tier_page.page), tier_page.page, "exportBoard()"
    )
    expression.evaluate()
    assert not expression.hasError(), expression.error().toString()
    qtbot.wait(800)

    assert target.exists()
    exported = QImage(str(target))
    assert not exported.isNull()
    def qml_value(code):
        expr = QQmlExpression(
            tier_page.engine.contextForObject(tier_page.page), tier_page.page, code
        )
        value = expr.evaluate()
        if isinstance(value, tuple):
            value = value[0]
        assert not expr.hasError(), expr.error().toString()
        return value

    scale = qml_value("exportScale")
    board_size = qml_value("Qt.size(board.width, board.height)")
    assert exported.width() == pytest.approx(board_size.width() * scale, abs=1)
    assert exported.height() == pytest.approx(board_size.height() * scale, abs=1)
    assert not tier_page.page.property("exporting")
    assert "exported to" in tier_page.vm.message


def test_toolbar_buttons_match_standard_sizing_and_cursor(tier_page, qtbot):
    """Toolbar buttons use the shared Button.qml with the app's standard size."""
    buttons = {
        item.property("buttonText"): item
        for item in iter_items(tier_page.page)
        if item.property("buttonText")
    }
    assert {"Add images", "Add tier", "Export PNG", "Clear images"} <= buttons.keys()

    for button in buttons.values():
        assert button.property("heightMultiplier") == pytest.approx(1.3)
        assert button.property("isometric")

    # With images present, Export PNG is enabled and shows a pointing cursor.
    export = buttons["Export PNG"]
    assert export.property("enabled")
    mouse_area = next(
        child for child in export.childItems()
        if class_name(child) == "QQuickMouseArea"
    )
    assert mouse_area.property("hoverEnabled")
    assert mouse_area.property("cursorShape") == Qt.PointingHandCursor


def test_no_insertion_line_when_hovering_a_tier(tier_page, qtbot):
    rows, _ = refresh(tier_page.page)

    QTest.mouseMove(tier_page.window, scene_center(rows[0]))
    qtbot.wait(200)

    # The old thin insertion bar was a narrow Rectangle at the flow's left
    # edge; only the borderless ghost preview should remain while dragging.
    thin_bars = [
        item for item in rows[0].childItems()
        if class_name(item) == "QQuickRectangle"
        and 0 < item.width() < 10
        and item.height() > tier_page.page.property("thumbSize")
    ]
    assert thin_bars == []


def test_tier_controls_only_show_on_hover_and_are_clickable(tier_page, qtbot):
    rows, _ = refresh(tier_page.page)
    label = rows[0].childItems()[1]

    color_button = next(
        child
        for child in label.childItems()
        if class_name(child) == "QQuickRectangle"
        and child.width() < label.width() / 2
        and child.height() < label.height() / 2
    )
    assert not color_button.property("visible")

    QTest.mouseMove(tier_page.window, scene_center(label))
    qtbot.wait(250)
    assert color_button.property("visible")

    color_mouse = next(
        child for child in color_button.childItems()
        if class_name(child) == "QQuickMouseArea"
    )
    assert color_mouse.property("cursorShape") == Qt.PointingHandCursor

    control_row = next(
        child for child in label.childItems() if class_name(child) == "QQuickRow"
    )
    controls = [child for child in control_row.childItems() if child.width() > 0]
    assert len(controls) == 3
    assert not controls[0].property("enabled")  # cannot move the first tier up
    for control in controls[1:]:
        assert control.property("enabled")
        mouse_area = next(
            child for child in control.childItems()
            if class_name(child) == "QQuickMouseArea"
        )
        assert mouse_area.property("cursorShape") == Qt.PointingHandCursor
