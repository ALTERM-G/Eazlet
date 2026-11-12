import base64
import ipaddress
import re
import string
import uuid

from PySide6.QtGui import QImage

from eazlet.backend.viewmodels.generators_vm import (
    QR_PREVIEW_SCALE,
    QR_QUIET_ZONE,
    GeneratorsVM,
)


def test_password_is_generated_from_selected_character_sets():
    vm = GeneratorsVM()
    assert len(vm.password) == 20
    assert any(c in string.ascii_uppercase for c in vm.password)
    assert any(c in string.ascii_lowercase for c in vm.password)
    assert any(c in string.digits for c in vm.password)
    assert any(not c.isalnum() for c in vm.password)
    assert vm.passwordStrength in {"Strong", "Very strong"}
    assert vm.passwordEntropy > 0


def test_password_respects_length_and_selected_sets():
    vm = GeneratorsVM()
    vm.passwordLength = 32
    vm.includeSymbols = False
    vm.generatePassword()

    assert len(vm.password) == 32
    assert not re.search(r"[^A-Za-z0-9]", vm.password)

    vm.includeUppercase = False
    vm.includeLowercase = False
    vm.includeDigits = False
    vm.generatePassword()

    assert vm.password == ""
    assert vm.passwordError == "Select at least one character set."


def test_password_length_is_clamped():
    vm = GeneratorsVM()
    vm.passwordLength = 1
    assert vm.passwordLength == 8
    vm.passwordLength = 999
    assert vm.passwordLength == 128


def test_lorem_generates_requested_number_of_items():
    vm = GeneratorsVM()
    assert vm.loremText.startswith("Lorem ipsum dolor sit amet")

    vm.loremType = "Sentences"
    vm.loremAmount = 4
    vm.generateLorem()
    assert vm.loremText.count(".") == 4

    vm.loremType = "Words"
    vm.loremAmount = 6
    vm.generateLorem()
    assert len(vm.loremText.rstrip(".").split()) == 6


def test_lorem_amount_limits_follow_the_selected_type():
    vm = GeneratorsVM()
    assert vm.loremType == "Paragraphs"
    assert vm.loremMaxAmount == 50

    vm.loremAmount = 500
    assert vm.loremAmount == 50

    vm.loremType = "Sentences"
    assert vm.loremMaxAmount == 250
    assert vm.loremAmount == 50
    vm.loremAmount = 200
    assert vm.loremAmount == 200

    vm.loremType = "Words"
    assert vm.loremMaxAmount == 500
    vm.loremAmount = 400
    assert vm.loremAmount == 400

    vm.loremType = "Paragraphs"
    assert vm.loremAmount == 50


def test_random_numbers_are_in_range_and_can_be_unique():
    vm = GeneratorsVM()
    vm.randomMin = 5
    vm.randomMax = 15
    vm.randomCount = 8
    vm.randomUnique = True
    vm.generateRandom()

    values = [int(value) for value in vm.randomOutput.split(", ")]
    assert len(values) == 8
    assert len(set(values)) == 8
    assert all(5 <= value <= 15 for value in values)
    assert vm.randomError == ""


def test_random_numbers_validate_range_and_uniqueness():
    vm = GeneratorsVM()
    vm.randomMin = 20
    vm.randomMax = 10
    vm.generateRandom()
    assert vm.randomError == "Minimum cannot be greater than maximum."

    vm.randomMin = 1
    vm.randomMax = 3
    vm.randomCount = 10
    vm.randomUnique = True
    vm.generateRandom()
    assert vm.randomError == "Cannot generate that many unique numbers in this range."


def test_random_numbers_can_be_sorted():
    vm = GeneratorsVM()
    vm.randomMin = 1
    vm.randomMax = 1000
    vm.randomCount = 25
    vm.randomSort = "Ascending"
    vm.generateRandom()
    values = [int(value) for value in vm.randomOutput.split(", ")]
    assert values == sorted(values)

    vm.randomSort = "Descending"
    vm.generateRandom()
    values = [int(value) for value in vm.randomOutput.split(", ")]
    assert values == sorted(values, reverse=True)


def test_random_strings_respect_length_count_and_character_sets():
    vm = GeneratorsVM()
    vm.randomStringLength = 24
    vm.randomStringCount = 3
    vm.randomStringSymbols = False
    vm.generateRandomString()

    values = vm.randomStringOutput.splitlines()
    assert len(values) == 3
    assert all(len(value) == 24 for value in values)
    assert all(re.fullmatch(r"[A-Za-z0-9]+", value) for value in values)
    assert vm.randomStringError == ""


def test_random_strings_exclude_ambiguous_characters():
    vm = GeneratorsVM()
    vm.randomStringLength = 200
    vm.randomStringCount = 20
    vm.randomStringExcludeAmbiguous = True
    vm.generateRandomString()

    assert not set(vm.randomStringOutput).intersection("O0oIl1|")


def test_random_strings_require_a_character_set():
    vm = GeneratorsVM()
    vm.randomStringUppercase = False
    vm.randomStringLowercase = False
    vm.randomStringDigits = False
    vm.randomStringSymbols = False
    vm.generateRandomString()

    assert vm.randomStringOutput == ""
    assert vm.randomStringError == "Select at least one character set."


def test_random_ipv4_addresses_are_valid_and_public():
    vm = GeneratorsVM()
    vm.randomIpVersion = "IPv4"
    vm.randomIpPrivate = False
    vm.randomIpCount = 20
    vm.generateRandomIp()

    addresses = [
        ipaddress.ip_address(value) for value in vm.randomIpOutput.splitlines()
    ]
    assert len(addresses) == 20
    assert all(address.version == 4 for address in addresses)
    assert all(address.is_global for address in addresses)


def test_random_ipv4_private_addresses_use_private_ranges():
    vm = GeneratorsVM()
    vm.randomIpVersion = "IPv4"
    vm.randomIpPrivate = True
    vm.randomIpCount = 20
    vm.generateRandomIp()

    addresses = [
        ipaddress.ip_address(value) for value in vm.randomIpOutput.splitlines()
    ]
    assert len(addresses) == 20
    assert all(address.version == 4 for address in addresses)
    assert all(address.is_private for address in addresses)


def test_random_ipv6_addresses_are_valid_and_public():
    vm = GeneratorsVM()
    vm.randomIpVersion = "IPv6"
    vm.randomIpPrivate = False
    vm.randomIpCount = 20
    vm.generateRandomIp()

    addresses = [
        ipaddress.ip_address(value) for value in vm.randomIpOutput.splitlines()
    ]
    assert len(addresses) == 20
    assert all(address.version == 6 for address in addresses)
    assert all(address.is_global for address in addresses)


def test_random_ipv6_private_addresses_use_unique_local_range():
    vm = GeneratorsVM()
    vm.randomIpVersion = "IPv6"
    vm.randomIpPrivate = True
    vm.randomIpCount = 20
    vm.generateRandomIp()

    addresses = [
        ipaddress.ip_address(value) for value in vm.randomIpOutput.splitlines()
    ]
    assert len(addresses) == 20
    assert all(address.version == 6 for address in addresses)
    assert all(address.is_private for address in addresses)


def test_random_ip_settings_are_clamped():
    vm = GeneratorsVM()
    vm.randomIpVersion = "not-a-version"
    assert vm.randomIpVersion == "IPv4"

    vm.randomIpCount = 0
    assert vm.randomIpCount == 1
    vm.randomIpCount = 999
    assert vm.randomIpCount == 100


def test_random_ids_generate_uuid_v4_values():
    vm = GeneratorsVM()
    vm.randomIdFormat = "UUID v4"
    vm.randomIdCount = 20
    vm.generateRandomId()

    values = vm.randomIdOutput.splitlines()
    assert len(values) == 20
    assert len(set(values)) == 20
    assert all(uuid.UUID(value).version == 4 for value in values)


def test_random_short_and_numeric_ids_respect_length_and_count():
    vm = GeneratorsVM()
    vm.randomIdCount = 6

    vm.randomIdFormat = "Short ID"
    vm.randomIdLength = 10
    vm.generateRandomId()
    values = vm.randomIdOutput.splitlines()
    assert len(values) == 6
    assert all(re.fullmatch(r"[A-Za-z0-9]{10}", value) for value in values)

    vm.randomIdFormat = "Numeric"
    vm.randomIdLength = 8
    vm.generateRandomId()
    values = vm.randomIdOutput.splitlines()
    assert len(values) == 6
    assert all(re.fullmatch(r"[0-9]{8}", value) for value in values)


def test_random_id_settings_are_clamped():
    vm = GeneratorsVM()
    vm.randomIdFormat = "not-a-format"
    assert vm.randomIdFormat == "UUID v4"

    vm.randomIdLength = 1
    assert vm.randomIdLength == 4
    vm.randomIdLength = 999
    assert vm.randomIdLength == 64

    vm.randomIdCount = 0
    assert vm.randomIdCount == 1
    vm.randomIdCount = 999
    assert vm.randomIdCount == 100


def test_random_colors_generate_hex_swatches_and_output():
    vm = GeneratorsVM()
    vm.randomColorFormat = "HEX"
    vm.randomColorCount = 5
    vm.generateRandomColor()

    values = vm.randomColorOutput.splitlines()
    assert len(values) == 5
    assert all(re.fullmatch(r"#[0-9A-F]{6}", value) for value in values)
    assert vm.randomColorList == values


def test_random_colors_can_be_formatted_as_rgb_and_hsl():
    vm = GeneratorsVM()
    vm.randomColorCount = 3

    vm.randomColorFormat = "RGB"
    vm.generateRandomColor()
    assert all(
        re.fullmatch(r"rgb\(\d{1,3}, \d{1,3}, \d{1,3}\)", value)
        for value in vm.randomColorOutput.splitlines()
    )

    vm.randomColorFormat = "HSL"
    vm.generateRandomColor()
    assert all(
        re.fullmatch(r"hsl\(\d{1,3}, \d{1,3}%, \d{1,3}%\)", value)
        for value in vm.randomColorOutput.splitlines()
    )


def test_random_color_codes_follow_the_selected_format():
    vm = GeneratorsVM()
    vm.randomColorCount = 4
    vm.generateRandomColor()

    swatches = list(vm.randomColorList)
    assert vm.randomColorCodes == vm.randomColorOutput.splitlines()
    assert vm.randomColorCodes == swatches

    vm.randomColorFormat = "RGB"
    assert vm.randomColorList == swatches
    assert all(value.startswith("rgb(") for value in vm.randomColorCodes)
    assert vm.randomColorOutput.splitlines() == vm.randomColorCodes

    vm.randomColorFormat = "HSL"
    assert vm.randomColorList == swatches
    assert all(value.startswith("hsl(") for value in vm.randomColorCodes)


def test_random_color_settings_are_clamped():
    vm = GeneratorsVM()
    vm.randomColorFormat = "not-a-format"
    assert vm.randomColorFormat == "HEX"

    vm.randomColorCount = 0
    assert vm.randomColorCount == 1
    vm.randomColorCount = 999
    assert vm.randomColorCount == 24


def test_qr_code_generates_a_png_data_url():
    vm = GeneratorsVM()
    vm.qrUrl = "https://example.com/generators"
    vm.generateQr()

    assert vm.qrError == ""
    assert vm.qrImageSource.startswith("data:image/png;base64,")

    payload = vm.qrImageSource.split(",", 1)[1]
    image = QImage.fromData(base64.b64decode(payload))
    assert not image.isNull()
    assert image.width() == image.height()
    assert image.width() > 100


def test_qr_preview_has_a_small_quiet_zone():
    vm = GeneratorsVM()
    vm.qrUrl = "https://example.com/quiet-zone"
    vm.generateQr()

    payload = vm.qrImageSource.split(",", 1)[1]
    image = QImage.fromData(base64.b64decode(payload))
    margin = QR_QUIET_ZONE * QR_PREVIEW_SCALE
    assert image.pixelColor(margin - 1, margin - 1).lightness() > 200
    assert image.pixelColor(margin, margin).lightness() < 128


def test_qr_code_changes_with_input_and_rejects_empty_text():
    vm = GeneratorsVM()
    vm.qrUrl = "https://example.com/one"
    vm.generateQr()
    first = vm.qrImageSource

    vm.qrUrl = "https://example.com/two"
    vm.generateQr()
    assert vm.qrImageSource != first

    vm.qrUrl = "   "
    vm.generateQr()
    assert vm.qrImageSource == ""
    assert vm.qrError == "Enter a URL or text to encode."


def test_qr_saves_png_at_requested_resolution(tmp_path):
    vm = GeneratorsVM()
    vm.qrUrl = "https://example.com/save"
    vm.qrResolution = 512
    vm.generateQr()

    target = tmp_path / "qr-code.png"
    vm.saveQr(str(target))

    assert target.exists()
    image = QImage(str(target))
    assert not image.isNull()
    assert image.width() == 512
    assert image.height() == 512
    assert image.pixelColor(0, 0).lightness() > 200
    assert vm.qrSavedMessage.startswith("Saved")


def test_qr_save_accepts_file_urls_and_adds_png_suffix(tmp_path):
    vm = GeneratorsVM()
    vm.qrUrl = "https://example.com/url"
    vm.qrResolution = 256
    vm.generateQr()

    target = tmp_path / "from-url"
    vm.saveQr(target.as_uri())

    png_target = target.with_suffix(".png")
    assert png_target.exists()
    image = QImage(str(png_target))
    assert image.width() == 256
    assert image.height() == 256
