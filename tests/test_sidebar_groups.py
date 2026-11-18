import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SIDEBAR = ROOT / "src/eazlet/ui/components/layout/SideBar.qml"
ITEM = ROOT / "src/eazlet/ui/components/layout/SideBarItem.qml"


def _entries():
    source = SIDEBAR.read_text()
    block = source.split("property var navItems: [", 1)[1].split("\n    ]", 1)[0]
    entries = []
    for match in re.finditer(
        r'\{ label: "([^"]+)", icon: "([^"]+)", page: (\d+)'
        r"(?:, separator: true)? }",
        block,
    ):
        entries.append(
            (match.group(1), match.group(2), int(match.group(3)),
             ", separator: true" in match.group(0))
        )
    return entries


def sidebar():
    return SIDEBAR.read_text()


def test_sidebar_order_is_grouped_by_purpose():
    labels = [entry[0] for entry in _entries()]
    assert labels == [
        "Home",
        "Code Tools", "Text Tools", "Text Analysis", "Dictionary",
        "Downloader", "Converter", "Archive", "Organizer",
        "Math", "Number Tools",
        "Tier List", "Colors", "Generators", "ASCII Art",
    ]


def test_sidebar_pages_match_stack_indices():
    # Workspace order in main.qml (must not change when regrouping the sidebar).
    pages = {
        "Home": 0, "Downloader": 1, "Converter": 2, "Archive": 3,
        "Organizer": 4, "Code Tools": 5, "Text Analysis": 6, "ASCII Art": 7,
        "Number Tools": 8, "Math": 9, "Generators": 10, "Dictionary": 11,
        "Colors": 12, "Tier List": 13, "Text Tools": 14,
    }
    assert {label: page for label, _, page, _ in _entries()} == pages


def test_separators_mark_group_starts():
    separated = [entry[0] for entry in _entries() if entry[3]]
    assert separated == [
        "Code Tools", "Downloader", "Math", "Tier List",
    ]
    assert "separatorBefore: modelData.separator === true" in sidebar()
    assert "property bool separatorBefore: false" in ITEM.read_text()
    assert "visible: root.separatorBefore && !root.collapsed" in ITEM.read_text()


def test_navigation_uses_page_index_not_display_index():
    source = sidebar()
    assert "sidebar.currentIndex = modelData.page" in source
    assert "sidebar.navigationClicked(modelData.page)" in source
    assert "isActive: sidebar.currentIndex === modelData.page" in source
    assert "function navIndexForPage(page)" in source
