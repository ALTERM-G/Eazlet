from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MATHEMATICS = ROOT / "src" / "eazlet" / "ui" / "pages" / "Mathematics.qml"


def test_latex_preview_frame_is_square():
    source = MATHEMATICS.read_text()
    preview = source.split("id: latexPreview", 1)[1].split("Canvas {", 1)[0]

    assert "radius: 0" in preview
    assert "LayoutMetrics.radius" not in preview
