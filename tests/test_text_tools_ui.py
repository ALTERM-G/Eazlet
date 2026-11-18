import json
from pathlib import Path

import pytest
from PySide6.QtCore import QObject, Qt, QUrl
from PySide6.QtQml import QQmlExpression

import run

ROOT = Path(__file__).resolve().parent.parent
UI = ROOT / "src" / "eazlet" / "ui"
RESOURCES = ROOT / "src" / "eazlet" / "resources"
MAIN_QML = UI / "main.qml"
TEXT_TOOLS_INDEX = 14


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
        value, has_error = value
        assert not has_error, expr.error().toString()
    return value


@pytest.fixture
def text_tools_page(qapp, qtbot):
    engine = run.build_engine()
    engine.load(QUrl.fromLocalFile(str(MAIN_QML)))
    assert engine.rootObjects(), "main.qml failed to load"

    window = engine.rootObjects()[0]
    window.resize(1400, 900)
    stack = next(
        child
        for child in window.findChildren(QObject)
        if class_name(child).startswith("QQuickStackLayout")
    )
    stack.setProperty("currentIndex", TEXT_TOOLS_INDEX)
    qtbot.wait(300)

    page = stack.childItems()[TEXT_TOOLS_INDEX].property("item")
    assert page is not None, "Text Tools page failed to load"
    return engine, window, page


def test_text_tools_is_registered_everywhere():
    main = MAIN_QML.read_text()
    pages = [line for line in main.splitlines() if 'source: "pages/' in line]
    assert pages[-1].strip() == '{ source: "pages/TextTools.qml" }'

    sidebar = (UI / "components" / "layout" / "SideBar.qml").read_text()
    assert '{ label: "Text Tools", icon: "textTools" }' in sidebar
    assert "case \"textTools\": return SVGLibrary.textTools" in sidebar

    library = (RESOURCES / "style" / "SVGLibrary.qml").read_text()
    assert "textTools" in library
    assert (RESOURCES / "assets" / "icons" / "labels" / "Text_tools.svg").exists()

    controller = (ROOT / "src" / "eazlet" / "backend" / "controller.py").read_text()
    assert "TextToolsVM" in controller
    bootstrap = (ROOT / "src" / "eazlet" / "bootstrap.py").read_text()
    assert 'setContextProperty("textToolsVM"' in bootstrap


def test_page_uses_shared_layout_and_scrolling(text_tools_page):
    engine, window, page = text_tools_page

    surfaces = [item for item in iter_items(page)
                if item.property("objectName") == "workplaceSurface"]
    assert len(surfaces) == 1

    scrollers = [item for item in iter_items(page)
                 if item.property("step") is not None
                 and item.property("target") is not None]
    assert scrollers, "page should use WheelScrollArea"

    controller = next(item for item in iter_items(page)
                      if item.property("objectName") == "controlsScroll")
    assert controller.property("acceptedButtons") == Qt.NoButton
    assert evaluate(engine, page, "toolContent.width > 0") is True
    assert evaluate(engine, page, "controlsScroll.contentHeight > 0") is True

    bars = [item for item in iter_items(page)
            if item.property("autoGutter") is not None]
    assert bars and all(item.property("autoGutter") is False for item in bars)

    tabs = next(item for item in iter_items(page)
                if item.property("tabData") is not None)
    assert evaluate(engine, tabs, "tabData.length") == 5

    output_panels = [item for item in iter_items(page)
                     if item.property("objectName") == "outputPanel"]
    assert len(output_panels) == 1, "page should keep one persistent output panel"
    assert evaluate(engine, page, "outputEdit.visible") is True
    assert evaluate(engine, page, "outputEdit.width > 0 && outputEdit.height > 0") is True
    assert evaluate(engine, page, "outputPanel.x > controlsScroll.x") is True

    assert evaluate(engine, page, "inputCard.height > 0") is True
    assert evaluate(engine, page, "inputEdit.visible") is True
    assert evaluate(engine, page, "inputEdit.width > 0 && inputEdit.height > 0") is True

    evaluate(engine, page, "controlsScroll.contentY = controlsScroll.contentHeight")
    assert evaluate(engine, page, "inputEdit.visible && inputEdit.height > 0") is True

    assert engine.rootContext().contextProperty("textToolsVM") is not None


def test_transform_actions_write_output(text_tools_page):
    engine, window, page = text_tools_page

    evaluate(engine, page, 'inputEdit.text = "hello world"')
    evaluate(engine, page, "toolTabs.currentIndex = 0")
    evaluate(engine, page, "runCase(); 1")
    assert evaluate(engine, page, "outputEdit.text") == "HELLO WORLD"

    evaluate(engine, page, 'inputEdit.text = "b\\na\\n b "')
    page.setProperty("whitespaceOptions", ["Trim", "Collapse"])
    evaluate(engine, page, "runWhitespace(); 1")
    assert evaluate(engine, page, "outputEdit.text") == "b\na\nb"

    evaluate(engine, page, 'inputEdit.text = "one two\\nthree"')
    evaluate(engine, page, "reverseCombo.currentIndex = 2")
    evaluate(engine, page, "runReverse(); 1")
    assert evaluate(engine, page, "outputEdit.text") == "three\none two"


def test_regex_find_populates_match_list(text_tools_page):
    engine, window, page = text_tools_page

    evaluate(engine, page, 'inputEdit.text = "a1 b22 c333"')
    evaluate(engine, page, "toolTabs.currentIndex = 1")
    evaluate(engine, page, 'patternField.text = "\\\\d+"')
    evaluate(engine, page, "runFind(); 1")

    assert evaluate(engine, page, "matchModel.length") == 3
    assert evaluate(engine, page, "outputEdit.text") == "1\n22\n333"
    assert "3 match" in evaluate(engine, page, "statusLabel.text")

    evaluate(engine, page, 'patternField.text = "["')
    evaluate(engine, page, "runFind(); 1")
    assert evaluate(engine, page, "errorLabel.visible") is True
    assert evaluate(engine, page, "outputEdit.text") == ""


def test_regex_matches_highlight_live(text_tools_page):
    engine, window, page = text_tools_page

    evaluate(engine, page, "toolTabs.currentIndex = 1")
    evaluate(engine, page, 'inputEdit.text = "a1 b22 c333"')
    evaluate(engine, page, 'patternField.text = "\\\\d+"')

    assert evaluate(engine, page, "regexMatches.length") == 3
    assert evaluate(engine, page, "inputEdit.matches.length") == 3
    assert evaluate(engine, page, "inputEdit.highlightedHtml()").count("<span") == 3
    assert "3 live match(es)" in evaluate(engine, page, "regexHint.text")

    evaluate(engine, page, 'patternField.text = "["')
    assert evaluate(engine, page, "regexError") != ""
    assert evaluate(engine, page, "inputEdit.matches.length") == 0
    assert evaluate(engine, page, "regexHint.text") == evaluate(engine, page, "regexError")


def test_batch_replace_swaps_atomically(text_tools_page):
    engine, window, page = text_tools_page

    evaluate(engine, page, "toolTabs.currentIndex = 4")
    assert evaluate(engine, page, "replaceRules.length") == 0

    evaluate(engine, page, 'inputEdit.text = "X A XX AA"')
    evaluate(engine, page,
             'replaceRules = [{find: "X", replace: "A", enabled: true},'
             ' {find: "A", replace: "X", enabled: true}]')
    evaluate(engine, page, "runBatchReplace(); 1")

    assert evaluate(engine, page, "outputEdit.text") == "A X AA XX"
    assert "6 replacement(s)" in evaluate(engine, page, "statusLabel.text")

    evaluate(engine, page,
             'replaceRules = [{find: "cat", replace: "dog", enabled: true},'
             ' {find: "dog", replace: "cat", enabled: true}]')
    evaluate(engine, page, 'inputEdit.text = "cat dog"')
    evaluate(engine, page, "runBatchReplace(); 1")
    assert evaluate(engine, page, "outputEdit.text") == "dog cat"

    evaluate(engine, page, "addRule(); 1")
    assert evaluate(engine, page, "replaceRules.length") == 3
    evaluate(engine, page, "removeRule(2); 1")
    assert evaluate(engine, page, "replaceRules.length") == 2


def test_text_tools_layout_is_calm_and_consistent(text_tools_page):
    source = (UI / "pages" / "TextTools.qml").read_text()

    assert "loadSample" not in source
    assert "Load sample" not in source
    assert "property var replaceRules: []" in source
    assert "style_2: true" in source
    assert source.count("style_2: true") >= 15
    assert "color: Theme.dividerColor" in source
    assert "SVGLibrary.cross" in source
    assert "IconButton" not in source
    assert "heightMultiplier" not in source
    assert "isometric: true" not in source

    engine, window, page = text_tools_page
    assert evaluate(engine, page, "replaceRules.length") == 0
    assert evaluate(engine, page, "secondaryColumnSpin.from") == -1
    assert evaluate(engine, page, "secondaryColumnSpin.value") == -1
    assert evaluate(engine, page, "controlCard.height > 0") is True


def test_multi_column_sort_ui(text_tools_page):
    engine, window, page = text_tools_page

    evaluate(engine, page, 'inputEdit.text = "b,y\\na,2\\nb,x\\na,1"')
    evaluate(engine, page, "toolTabs.currentIndex = 2")
    evaluate(engine, page, "sortUnitCombo.currentIndex = 3")
    evaluate(engine, page, "sortColumnSpin.value = 0")
    evaluate(engine, page, "secondaryColumnSpin.value = 1")

    evaluate(engine, page, "secondaryOrderCombo.currentIndex = 0")
    evaluate(engine, page, "runSort(); 1")
    assert evaluate(engine, page, "outputEdit.text") == "a,1\na,2\nb,x\nb,y"

    evaluate(engine, page, "secondaryOrderCombo.currentIndex = 1")
    evaluate(engine, page, "runSort(); 1")
    assert evaluate(engine, page, "outputEdit.text") == "a,2\na,1\nb,y\nb,x"

    evaluate(engine, page, "secondaryColumnSpin.value = -1")
    evaluate(engine, page, "sortColumnSpin.value = 1")
    evaluate(engine, page, "runSort(); 1")
    assert evaluate(engine, page, "outputEdit.text") == "a,1\na,2\nb,x\nb,y"


def test_sorter_and_data_actions(text_tools_page):
    engine, window, page = text_tools_page

    evaluate(engine, page, 'inputEdit.text = "b\\na\\nc"')
    evaluate(engine, page, "toolTabs.currentIndex = 2")
    evaluate(engine, page, "runSort(); 1")
    assert evaluate(engine, page, "outputEdit.text") == "a\nb\nc"

    evaluate(engine, page, 'inputEdit.text = "name,age\\nAda,36"')
    evaluate(engine, page, "toolTabs.currentIndex = 3")
    evaluate(engine, page, "runDelimitedToJson(); 1")
    output = evaluate(engine, page, "outputEdit.text")
    assert json.loads(output) == [{"name": "Ada", "age": "36"}]


def test_process_action_follows_active_tab(text_tools_page):
    engine, window, page = text_tools_page

    evaluate(engine, page, 'inputEdit.text = "c\\na\\nb"')
    evaluate(engine, page, "toolTabs.currentIndex = 2")
    evaluate(engine, page, "processAction(); 1")
    assert evaluate(engine, page, "outputEdit.text") == "a\nb\nc"

    evaluate(engine, page, 'inputEdit.text = "X A"')
    evaluate(engine, page, "toolTabs.currentIndex = 4")
    evaluate(engine, page,
             'replaceRules = [{find: "X", replace: "A", enabled: true},'
             ' {find: "A", replace: "X", enabled: true}]')
    evaluate(engine, page, "processAction(); 1")
    assert evaluate(engine, page, "outputEdit.text") == "A X"
