# Eazlet

QML + PySide6 desktop application generated from the QML-PySide6 template.

## Requirements

- Python >= 3.11
- PySide6 >= 6.10.1

## Installation

```bash
pip install -e ".[dev]"
# or
uv sync --extra dev
```

## Running

```bash
python run.py
# or, after install:
eazlet
```

## Project structure

```text
src/eazlet/
  backend/     # Controller, viewmodels, language manager
  resources/   # QML singletons, assets (fonts, icons, themes, languages)
  ui/          # QML components, main.qml
```

## Development

- Lint (Python): `ruff check .`
- Tests: `pytest -q`
- Lint (QML): `qmllint -I src/eazlet/ui <files>`
