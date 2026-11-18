from pathlib import Path


def svg_text(svg_file: Path) -> str:
    return Path(svg_file).read_text(encoding="utf-8")
