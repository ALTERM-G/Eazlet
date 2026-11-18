import json
from pathlib import Path

from PySide6.QtCore import QObject, QPointF, QUrl
from PySide6.QtGui import QFont
from PySide6.QtQml import QJSValue, QQmlExpression

import run

ROOT = Path(__file__).resolve().parent.parent
HOME_INDEX = 0

def class_name(obj):
    return obj.metaObject().className().split("_QML")[0]


def evaluate(engine, obj, expression):
    expr = QQmlExpression(engine.contextForObject(obj), obj, expression)
    value = expr.evaluate()
    if isinstance(value, tuple):
        value, has_error = value
        if has_error:
            raise RuntimeError(expr.error().toString())
    if isinstance(value, QJSValue):
        value = value.toVariant()
    return value


def load_home(qapp, qtbot):
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
    stack.setProperty("currentIndex", HOME_INDEX)
    qtbot.wait(200)

    page = stack.childItems()[HOME_INDEX].property("item")
    assert page is not None
    return engine, window, page, stack


def find_child(page, object_name):
    matches = [
        child
        for child in page.findChildren(QObject)
        if child.property("objectName") == object_name
    ]
    assert len(matches) == 1
    return matches[0]


def test_home_is_a_flat_page_without_cards(qapp, qtbot):
    engine, window, page, stack = load_home(qapp, qtbot)
    source = (ROOT / "src/eazlet/ui/pages/Home.qml").read_text()

    assert "Surface" not in source
    # Only the bare QtQuick text editor is used; the component with its card
    # background is not.
    assert source.count("TextEdit {") == 1
    assert "QQ.TextEdit {" in source
    # The only Rectangle is the thin divider between the header and terminal.
    assert source.count("Rectangle {") == 1
    assert find_child(page, "homeSeparator").property("height") > 0
    assert not [
        child
        for child in page.findChildren(QObject)
        if child.property("objectName") == "workplaceSurface"
    ]


def test_home_shows_banner_svg_and_bold_tagline(qapp, qtbot):
    engine, window, page, stack = load_home(qapp, qtbot)
    banner = find_child(page, "homeBanner")
    tagline = find_child(page, "homeTagline")

    svg_text = str(banner.property("svgText"))
    assert "<svg" in svg_text
    assert "Eazlet ASCII art" in svg_text
    assert str(banner.property("sourceUri")).startswith("data:image/svg+xml;utf8,")
    assert f"fill:{banner.property('fillColor').name()}" in str(
        banner.property("themedSvg")
    )
    assert evaluate(engine, banner, "banner.fillColor === Theme.themeColor") is True
    assert tagline.property("text") == "Simple tools. Easy workflow."
    assert tagline.property("font").weight() == QFont.Bold

    source = (ROOT / "src/eazlet/ui/pages/Home.qml").read_text()
    assert "EazletBanner {" in source
    assert "bannerText" not in source


def test_banner_svg_is_registered_and_scales_without_overflowing(qapp, qtbot):
    engine, window, page, stack = load_home(qapp, qtbot)
    banner = find_child(page, "homeBanner")

    qmldir = (ROOT / "src/eazlet/ui/components/qmldir").read_text()
    assert "EazletBanner 1.0 brand/EazletBanner.qml" in qmldir
    assert (ROOT / "src/eazlet/ui/components/brand/EazletBanner.qml").exists()

    assert evaluate(engine, banner, "banner.width") > 0
    assert evaluate(engine, banner, "banner.height") > 0
    assert evaluate(engine, banner, "banner.width") <= evaluate(
        engine, banner, "banner.parent.width"
    )
    source_size = evaluate(engine, banner, "banner.children[0].sourceSize.width")
    assert source_size == 6 * 399

    initial_width = evaluate(engine, banner, "banner.width")
    evaluate(engine, window, "LayoutMetrics.scaleFactor = 2; 1")
    qtbot.wait(200)
    assert evaluate(engine, banner, "banner.width") > initial_width
    assert evaluate(engine, banner, "banner.children[0].sourceSize.width") == source_size
    evaluate(engine, window, "LayoutMetrics.scaleFactor = 1; 1")
    qtbot.wait(200)

    window.resize(900, 700)
    qtbot.wait(200)
    assert evaluate(engine, banner, "banner.width") <= evaluate(
        engine, banner, "banner.parent.width"
    )
    assert evaluate(engine, banner, "banner.children[0].sourceSize.width") == source_size


def test_banner_svg_renders_and_scales_theme_colored_paths(qapp, qtbot):
    engine, window, page, stack = load_home(qapp, qtbot)
    qtbot.wait(300)
    banner = find_child(page, "homeBanner")
    color = banner.property("fillColor")

    def painted_pixels():
        image = window.grabWindow()
        origin = banner.mapToItem(window.contentItem(), QPointF(0, 0))
        left, top = int(origin.x()), int(origin.y())
        right = min(left + int(banner.property("width")), image.width())
        bottom = min(top + int(banner.property("height")), image.height())
        painted = 0
        for y in range(max(top, 0), bottom):
            for x in range(max(left, 0), right):
                pixel = image.pixelColor(x, y)
                if (
                    abs(pixel.red() - color.red()) < 24
                    and abs(pixel.green() - color.green()) < 24
                    and abs(pixel.blue() - color.blue()) < 24
                ):
                    painted += 1
        return painted

    source = (ROOT / "src/eazlet/ui/components/brand/EazletBanner.qml").read_text()
    assert "Image {" in source
    assert "fillMode: Image.PreserveAspectFit" in source
    assert "encodeURIComponent" in source
    assert "mipmap: true" in source
    assert "PathSvg {" not in source

    evaluate(engine, window, "LayoutMetrics.scaleFactor = 1; 1")
    qtbot.wait(300)
    source_size = evaluate(engine, banner, "banner.children[0].sourceSize.width")
    painted_before = painted_pixels()
    assert painted_before > 500
    # The SVG has internal cut-outs. A solid Shape/PathSvg render fills about
    # 60% of the bounding box; the real SVG fills about 42%.
    assert painted_before / (banner.property("width") * banner.property("height")) < 0.5

    evaluate(engine, window, "LayoutMetrics.scaleFactor = 1.5; 1")
    qtbot.wait(300)
    assert evaluate(engine, banner, "banner.children[0].sourceSize.width") == source_size
    assert painted_pixels() > painted_before
    evaluate(engine, window, "LayoutMetrics.scaleFactor = 1; 1")
    qtbot.wait(300)

    window.resize(900, 700)
    qtbot.wait(300)
    assert evaluate(engine, banner, "banner.children[0].sourceSize.width") == source_size
    assert painted_pixels() > 500


def test_terminal_font_follows_only_monospaced_setting(qapp, qtbot):
    engine, window, page, stack = load_home(qapp, qtbot)
    output = find_child(page, "replOutput")
    prompt = find_child(page, "replPrompt")
    command = find_child(page, "replInput")

    evaluate(engine, window, "Typography.fontFamily = 'Inter'; 1")
    assert evaluate(engine, window, "Typography.fontIsMonospaced") is False
    assert evaluate(engine, window, "Typography.terminalFontFamily") == (
        "JetBrains Mono"
    )
    assert output.property("font").family() == "JetBrains Mono"

    evaluate(engine, window, "Typography.fontFamily = 'Monocraft'; 1")
    assert evaluate(engine, window, "Typography.fontIsMonospaced") is True
    assert evaluate(engine, window, "Typography.terminalFontFamily") == "Monocraft"
    assert output.property("font").family() == "Monocraft"
    assert prompt.property("font").family() == "Monocraft"
    assert command.property("font").family() == "Monocraft"

    source = (ROOT / "src/eazlet/ui/pages/Home.qml").read_text()
    assert source.count("font.family: Typography.terminalFontFamily") == 3
    assert 'font.family: "JetBrains Mono"' not in source

    typography = (ROOT / "src/eazlet/resources/style/Typography.qml").read_text()
    assert "readonly property bool fontIsMonospaced" not in typography
    assert "property bool fontIsMonospaced: false" in typography
    assert "onFontFamilyChanged: updateMonospaced()" in typography


def test_top_bar_app_label_hidden_only_on_home(qapp, qtbot):
    engine, window, page, stack = load_home(qapp, qtbot)
    top_bar = next(
        child
        for child in window.findChildren(QObject)
        if child.property("showAppTitle") is not None
    )
    app_title = find_child(top_bar, "app_title")

    assert app_title.property("visible") is False

    stack.setProperty("currentIndex", 1)
    qtbot.wait(200)
    assert app_title.property("visible") is True

    source = (ROOT / "src/eazlet/ui/components/layout/TopBar.qml").read_text()
    assert "Lang.titles.appName" in source
    main_source = (ROOT / "src/eazlet/ui/main.qml").read_text()
    assert "showAppTitle: !window.homeActive" in main_source


def test_terminal_output_can_be_selected(qapp, qtbot):
    engine, window, page, stack = load_home(qapp, qtbot)
    output = find_child(page, "replOutput")

    assert output.property("readOnly") is True
    assert output.property("selectByMouse") is True
    assert output.property("font").family() == "JetBrains Mono"


def test_home_input_autocloses_brackets_and_quotes(qapp, qtbot):
    engine, window, page, stack = load_home(qapp, qtbot)

    for opening, closing in (("(", ")"), ("[", "]"), ("{", "}"),
                             ('"', '"'), ("'", "'")):
        literal = json.dumps(opening)
        evaluate(
            engine, page,
            "commandInput.text = ''; commandInput.cursorPosition = 0; "
            f"page.insertPaired({literal}); 1",
        )
        assert evaluate(engine, page, "commandInput.text") == opening + closing
        assert evaluate(engine, page, "commandInput.cursorPosition") == 1

    # Typing the closing character over an existing one moves past it.
    evaluate(
        engine, page,
        "commandInput.text = '()'; commandInput.cursorPosition = 1; "
        "page.skipClosing(')'); 1",
    )
    assert evaluate(engine, page, "commandInput.cursorPosition") == 2
    assert evaluate(engine, page, "commandInput.text") == "()"

    # Backspace on an empty pair removes both characters.
    evaluate(
        engine, page,
        "commandInput.text = '()'; commandInput.cursorPosition = 1; "
        "page.removeEmptyPair(); 1",
    )
    assert evaluate(engine, page, "commandInput.text") == ""


def test_home_clear_command_and_shortcut_wipe_transcript(qapp, qtbot):
    engine, window, page, stack = load_home(qapp, qtbot)
    repl_vm = engine.rootContext().contextProperty("replVM")
    output = find_child(page, "replOutput")

    try:
        evaluate(
            engine, page,
            "commandInput.text = 'clear'; page.submitCommand(); 1",
        )
        assert repl_vm.output == ">>> "
        assert output.property("text") == ""

        evaluate(engine, page, "commandInput.text = 'print(2)'; "
                               "page.submitCommand(); 1")
        qtbot.waitUntil(lambda: "2" in repl_vm.output, timeout=8000)
        evaluate(engine, page, "page.clearTerminal(); 1")
        assert repl_vm.output == ">>> "
    finally:
        repl_vm.stop()


def test_window_uses_text_field_background_only_on_home(qapp, qtbot):
    engine, window, page, stack = load_home(qapp, qtbot)

    assert evaluate(
        engine, window, "window.color === Theme.inputBackgroundColor"
    ) is True
    stack.setProperty("currentIndex", 1)
    qtbot.wait(100)
    assert evaluate(engine, window, "window.color === Theme.backgroundColor") is True


def test_home_repl_executes_python_with_prompt(qapp, qtbot):
    engine, window, page, stack = load_home(qapp, qtbot)
    repl_vm = engine.rootContext().contextProperty("replVM")
    prompt = find_child(page, "replPrompt")
    output = find_child(page, "replOutput")
    command = find_child(page, "replInput")

    assert prompt.property("text") == ">>> "
    assert output.property("text") == ""
    assert command.property("readOnly") is False
    # The input sits next to the prompt at the end of the transcript.
    assert command.property("parent") == prompt.property("parent")
    assert evaluate(
        engine, find_child(page, "replOutputView"),
        "outputView.boundsBehavior === Flickable.StopAtBounds"
    ) is True

    try:
        evaluate(
            engine, page, "commandInput.text = 'print(6 * 7)'; "
                          "page.submitCommand(); 1"
        )
        qtbot.waitUntil(lambda: "42" in repl_vm.output, timeout=8000)
        assert ">>> print(6 * 7)" in output.property("text")
        assert "42" in output.property("text")
        assert repl_vm.running is True
    finally:
        repl_vm.stop()
