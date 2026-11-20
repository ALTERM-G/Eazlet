# Eazlet

Eazlet is a simple, local-first application built with QML and PySide6. Its purpose is to provide users with easy access to a wide range of simple yet useful tools, many of which would otherwise require visiting multiple websites. Rather than relying on numerous scattered online services, Eazlet brings these tools together in one customizable, fast, and convenient application, making everyday tasks easier and more accessible.

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
**Note:** installation script available in the future!

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
