from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UI = ROOT / "src" / "eazlet" / "ui"
RESOURCES = ROOT / "src" / "eazlet" / "resources"


def test_swap_icon_registered_and_used():
    library = (RESOURCES / "style" / "SVGLibrary.qml").read_text()
    assert 'property url swap: Qt.resolvedUrl("../assets/icons/actions/swap.svg")' in library
    assert (RESOURCES / "assets" / "icons" / "actions" / "swap.svg").exists()

    cipher = (UI / "pages" / "Cipher.qml").read_text()
    assert cipher.count('iconPath: SVGLibrary.swap') == 2
    assert 'buttonText: "Swap"' in cipher


def test_code_tools_controls_are_centered():
    source = (UI / "pages" / "Cipher.qml").read_text()
    # The four combo boxes and the passphrase/decode rows are centered.
    assert source.count("anchors.horizontalCenter: parent.horizontalCenter") >= 6
    assert source.count("id: encodingCombo") == 1
    assert source.count("id: cipherCombo") == 1
    assert source.count("id: encryptionCombo") == 1
    assert source.count("id: hashCombo") == 1


def test_cipher_io_has_no_duplicate_copy_button():
    source = (UI / "components" / "controls" / "CipherIO.qml").read_text()
    assert 'buttonText: "Copy"' not in source
    assert "showCopyButton: true" in source
