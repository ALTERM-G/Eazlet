import json
from pathlib import Path

from PySide6.QtCore import QByteArray, QUrl
from PySide6.QtGui import QColor
from PySide6.QtQml import QJSValue, QQmlExpression
from PySide6.QtSvg import QSvgRenderer

import run
from eazlet.backend.ascii_svg import FONT_PATH, _font_family, render_ascii_svg
from eazlet.backend.viewmodels.ascii_art_vm import AsciiArtVM

ROOT = Path(__file__).resolve().parent.parent


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


def test_bundled_ibm_vga_font_is_used(qapp):
    assert FONT_PATH.exists()
    assert FONT_PATH.name == "Px437_IBM_VGA_8x16.ttf"
    assert _font_family() == "Px437 IBM VGA 8x16"


def test_svg_contains_vector_outlines_only(qapp):
    svg = render_ascii_svg("Hi", "#ff8800")

    assert svg.startswith('<?xml version="1.0" encoding="UTF-8"?>')
    assert '<svg xmlns="http://www.w3.org/2000/svg"' in svg
    assert 'viewBox="0 0' in svg
    assert 'fill="#ff8800"' in svg
    assert "<path" in svg
    assert 'd="M ' in svg
    assert "<text" not in svg
    assert "@font-face" not in svg
    assert "Px437" not in svg


def test_svg_is_renderable(qapp):
    svg = render_ascii_svg("Eazlet", "#ffffff")

    assert QSvgRenderer(QByteArray(svg.encode())).isValid()


def test_svg_uses_alpha_from_theme_color(qapp):
    svg = render_ascii_svg("A", "#80123456")

    assert 'fill="#123456"' in svg
    assert 'fill-opacity="0.502"' in svg


def test_svg_keeps_art_alignment(qapp):
    spaced = render_ascii_svg(" A\n  A", "#ffffff")
    tight = render_ascii_svg("A\nA", "#ffffff")

    assert spaced != tight
    assert spaced.count("Z") == tight.count("Z")


def test_export_svg_writes_file_and_sets_status(qapp, tmp_path):
    vm = AsciiArtVM()
    vm.setInput("Hi")
    vm.process()
    target = tmp_path / "art.svg"

    vm.exportSvg(QUrl.fromLocalFile(str(target)).toString(), "#ffffff")

    assert target.exists()
    assert '<path fill="#ffffff"' in target.read_text()
    assert vm.status == "Saved art.svg"
    assert vm.error == ""


def test_export_svg_adds_svg_suffix(qapp, tmp_path):
    vm = AsciiArtVM()
    vm.setInput("Hi")
    vm.process()

    vm.exportSvg(str(tmp_path / "art.txt"), "#ffffff")

    assert (tmp_path / "art.svg").exists()
    assert not (tmp_path / "art.txt").exists()


def test_export_svg_reports_empty_output(qapp, tmp_path):
    vm = AsciiArtVM()
    target = tmp_path / "art.svg"

    vm.exportSvg(str(target), "#ffffff")

    assert "Generate ASCII art" in vm.error
    assert not target.exists()


def test_export_svg_reports_write_failure(qapp, tmp_path):
    vm = AsciiArtVM()
    vm.setInput("Hi")
    vm.process()
    target = tmp_path / "missing" / "art.svg"

    vm.exportSvg(str(target), "#ffffff")

    assert "Could not save the SVG" in vm.error
    assert not vm.status.startswith("Saved")


def test_qml_export_uses_current_theme_color(qapp, tmp_path):
    engine = run.build_engine()
    engine.load(QUrl.fromLocalFile(str(ROOT / "src/eazlet/ui/main.qml")))
    assert engine.rootObjects()
    window = engine.rootObjects()[0]
    vm = engine.rootContext().contextProperty("asciiArtVM")
    vm.setInput("Hi")
    vm.process()
    color = evaluate(engine, window, "Theme.textColor.toString()")
    target = tmp_path / "theme.svg"

    evaluate(
        engine,
        window,
        "asciiArtVM.exportSvg("
        f"{json.dumps(str(target))}, {json.dumps(color)}); 1",
    )

    assert target.exists()
    expected = QColor(color)
    assert (
        f'fill="#{expected.red():02x}{expected.green():02x}{expected.blue():02x}"'
        in target.read_text()
    )


def test_ascii_art_wires_export_button_to_save_dialog():
    source = (ROOT / "src/eazlet/ui/pages/AsciiArt.qml").read_text()

    assert "import QtQuick.Dialogs" in source
    assert "Lang.pages.asciiArt.exportSvg" in source
    assert 'objectName: "exportSvgButton"' in source
    assert "primary: true" in source
    assert "isometric: true" in source
    assert "id: svgFileDialog" in source
    assert "fileMode: FileDialog.SaveFile" in source
    assert 'defaultSuffix: "svg"' in source
    assert "Lang.pages.asciiArt.svgFilter" in source
    assert "asciiArtVM.exportSvg(" in source
    assert "Theme.textColor.toString()" in source
