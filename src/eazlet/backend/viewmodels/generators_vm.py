import base64
import colorsys
import ipaddress
import math
import secrets
import string
import uuid
from pathlib import Path

import qrcode
from PySide6.QtCore import Property, QBuffer, QIODevice, QObject, Qt, QUrl, Signal, Slot
from PySide6.QtGui import QColor, QGuiApplication, QImage, QPainter
from qrcode.constants import ERROR_CORRECT_M
from qrcode.exceptions import DataOverflowError

from .base_vm import BaseVM

PASSWORD_SYMBOLS = "!@#$%^&*()-_=+[]{};:,.?/"
AMBIGUOUS_CHARACTERS = "O0oIl1|"
LOREM_WORDS = (
    "lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor "
    "incididunt ut labore et dolore magna aliqua enim ad minim veniam quis nostrud "
    "exercitation ullamco laboris nisi aliquip ex ea commodo consequat duis aute "
    "irure in reprehenderit voluptate velit esse cillum eu fugiat nulla pariatur "
    "excepteur sint occaecat cupidatat non proident sunt culpa qui officia deserunt "
    "mollit anim id est laborum"
).split()
LOREM_OPENING = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
LOREM_LIMITS = {"Paragraphs": 50, "Sentences": 250, "Words": 500}
QR_RESOLUTIONS = [256, 512, 1024, 2048]
QR_QUIET_ZONE = 2
QR_PREVIEW_SCALE = 8

RANDOM_IP_VERSIONS = ["IPv4", "IPv6"]
RANDOM_ID_FORMATS = ["UUID v4", "Short ID", "Numeric"]
RANDOM_COLOR_FORMATS = ["HEX", "RGB", "HSL"]
RANDOM_COLOR_MAX_COUNT = 24
SHORT_ID_ALPHABET = string.ascii_letters + string.digits
PRIVATE_IPV4_NETWORKS = (
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
)
PUBLIC_IPV4_EXCLUSIONS = tuple(
    ipaddress.ip_network(network)
    for network in (
        "0.0.0.0/8",
        "10.0.0.0/8",
        "100.64.0.0/10",
        "127.0.0.0/8",
        "169.254.0.0/16",
        "172.16.0.0/12",
        "192.0.0.0/24",
        "192.0.2.0/24",
        "192.168.0.0/16",
        "198.18.0.0/15",
        "198.51.100.0/24",
        "203.0.113.0/24",
        "224.0.0.0/4",
        "240.0.0.0/4",
    )
)


class GeneratorsVM(BaseVM):
    passwordChanged = Signal()
    passwordLengthChanged = Signal()
    includeUppercaseChanged = Signal()
    includeLowercaseChanged = Signal()
    includeDigitsChanged = Signal()
    includeSymbolsChanged = Signal()
    passwordStrengthChanged = Signal()
    passwordEntropyChanged = Signal()
    passwordErrorChanged = Signal()

    loremTypeChanged = Signal()
    loremAmountChanged = Signal()
    loremTextChanged = Signal()
    loremErrorChanged = Signal()

    randomMinChanged = Signal()
    randomMaxChanged = Signal()
    randomCountChanged = Signal()
    randomUniqueChanged = Signal()
    randomSortChanged = Signal()
    randomOutputChanged = Signal()
    randomErrorChanged = Signal()

    randomStringLengthChanged = Signal()
    randomStringCountChanged = Signal()
    randomStringUppercaseChanged = Signal()
    randomStringLowercaseChanged = Signal()
    randomStringDigitsChanged = Signal()
    randomStringSymbolsChanged = Signal()
    randomStringExcludeAmbiguousChanged = Signal()
    randomStringOutputChanged = Signal()
    randomStringErrorChanged = Signal()

    randomIpVersionChanged = Signal()
    randomIpCountChanged = Signal()
    randomIpPrivateChanged = Signal()
    randomIpOutputChanged = Signal()

    randomIdFormatChanged = Signal()
    randomIdLengthChanged = Signal()
    randomIdCountChanged = Signal()
    randomIdOutputChanged = Signal()

    randomColorFormatChanged = Signal()
    randomColorCountChanged = Signal()
    randomColorListChanged = Signal()
    randomColorCodesChanged = Signal()
    randomColorOutputChanged = Signal()

    qrUrlChanged = Signal()
    qrImageSourceChanged = Signal()
    qrResolutionChanged = Signal()
    qrSavedMessageChanged = Signal()
    qrErrorChanged = Signal()

    LOREM_TYPES = ["Paragraphs", "Sentences", "Words"]
    RANDOM_SORTS = ["As generated", "Ascending", "Descending"]

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._password = ""
        self._password_length = 20
        self._include_uppercase = True
        self._include_lowercase = True
        self._include_digits = True
        self._include_symbols = True
        self._password_strength = ""
        self._password_entropy = 0
        self._password_error = ""

        self._lorem_type = self.LOREM_TYPES[0]
        self._lorem_amount = 3
        self._lorem_text = ""
        self._lorem_error = ""

        self._random_min = 1
        self._random_max = 100
        self._random_count = 10
        self._random_unique = False
        self._random_sort = self.RANDOM_SORTS[0]
        self._random_output = ""
        self._random_error = ""

        self._random_string_length = 16
        self._random_string_count = 5
        self._random_string_uppercase = True
        self._random_string_lowercase = True
        self._random_string_digits = True
        self._random_string_symbols = False
        self._random_string_exclude_ambiguous = False
        self._random_string_output = ""
        self._random_string_error = ""

        self._random_ip_version = RANDOM_IP_VERSIONS[0]
        self._random_ip_count = 5
        self._random_ip_private = False
        self._random_ip_output = ""

        self._random_id_format = RANDOM_ID_FORMATS[0]
        self._random_id_length = 12
        self._random_id_count = 5
        self._random_id_output = ""

        self._random_color_format = RANDOM_COLOR_FORMATS[0]
        self._random_color_count = 1
        self._random_color_values: list[tuple[int, int, int]] = []
        self._random_color_list: list[str] = []
        self._random_color_codes: list[str] = []
        self._random_color_output = ""

        self._qr_url = "https://example.com"
        self._qr_matrix: list[list[bool]] = []
        self._qr_image_source = ""
        self._qr_resolution = QR_RESOLUTIONS[2]
        self._qr_saved_message = ""
        self._qr_error = ""

        self.generatePassword()
        self.generateLorem()
        self.generateRandom()
        self.generateRandomString()
        self.generateRandomIp()
        self.generateRandomId()
        self.generateRandomColor()
        self.generateQr()

    @Property(str, notify=passwordChanged)
    def password(self) -> str:
        return self._password

    @Property(int, notify=passwordLengthChanged)
    def passwordLength(self) -> int:
        return self._password_length

    @passwordLength.setter
    def passwordLength(self, value: int) -> None:
        try:
            length = int(value)
        except (TypeError, ValueError):
            return
        length = max(8, min(128, length))
        if length != self._password_length:
            self._password_length = length
            self.passwordLengthChanged.emit()

    @Property(bool, notify=includeUppercaseChanged)
    def includeUppercase(self) -> bool:
        return self._include_uppercase

    @includeUppercase.setter
    def includeUppercase(self, value: bool) -> None:
        value = bool(value)
        if value != self._include_uppercase:
            self._include_uppercase = value
            self.includeUppercaseChanged.emit()

    @Property(bool, notify=includeLowercaseChanged)
    def includeLowercase(self) -> bool:
        return self._include_lowercase

    @includeLowercase.setter
    def includeLowercase(self, value: bool) -> None:
        value = bool(value)
        if value != self._include_lowercase:
            self._include_lowercase = value
            self.includeLowercaseChanged.emit()

    @Property(bool, notify=includeDigitsChanged)
    def includeDigits(self) -> bool:
        return self._include_digits

    @includeDigits.setter
    def includeDigits(self, value: bool) -> None:
        value = bool(value)
        if value != self._include_digits:
            self._include_digits = value
            self.includeDigitsChanged.emit()

    @Property(bool, notify=includeSymbolsChanged)
    def includeSymbols(self) -> bool:
        return self._include_symbols

    @includeSymbols.setter
    def includeSymbols(self, value: bool) -> None:
        value = bool(value)
        if value != self._include_symbols:
            self._include_symbols = value
            self.includeSymbolsChanged.emit()

    @Property(str, notify=passwordStrengthChanged)
    def passwordStrength(self) -> str:
        return self._password_strength

    @Property(int, notify=passwordEntropyChanged)
    def passwordEntropy(self) -> int:
        return self._password_entropy

    @Property(str, notify=passwordErrorChanged)
    def passwordError(self) -> str:
        return self._password_error

    @Property(str, notify=loremTypeChanged)
    def loremType(self) -> str:
        return self._lorem_type

    @loremType.setter
    def loremType(self, value: str) -> None:
        value = value if value in self.LOREM_TYPES else self.LOREM_TYPES[0]
        if value != self._lorem_type:
            self._lorem_type = value
            self.loremTypeChanged.emit()
            max_amount = LOREM_LIMITS[value]
            if self._lorem_amount > max_amount:
                self._lorem_amount = max_amount
                self.loremAmountChanged.emit()

    @Property(int, notify=loremTypeChanged)
    def loremMaxAmount(self) -> int:
        return LOREM_LIMITS[self._lorem_type]

    @Property(int, notify=loremAmountChanged)
    def loremAmount(self) -> int:
        return self._lorem_amount

    @loremAmount.setter
    def loremAmount(self, value: int) -> None:
        try:
            amount = int(value)
        except (TypeError, ValueError):
            return
        amount = max(1, min(LOREM_LIMITS[self._lorem_type], amount))
        if amount != self._lorem_amount:
            self._lorem_amount = amount
            self.loremAmountChanged.emit()

    @Property(str, notify=loremTextChanged)
    def loremText(self) -> str:
        return self._lorem_text

    @Property(str, notify=loremErrorChanged)
    def loremError(self) -> str:
        return self._lorem_error

    @Property(int, notify=randomMinChanged)
    def randomMin(self) -> int:
        return self._random_min

    @randomMin.setter
    def randomMin(self, value: int) -> None:
        try:
            number = int(value)
        except (TypeError, ValueError):
            return
        if number != self._random_min:
            self._random_min = number
            self.randomMinChanged.emit()

    @Property(int, notify=randomMaxChanged)
    def randomMax(self) -> int:
        return self._random_max

    @randomMax.setter
    def randomMax(self, value: int) -> None:
        try:
            number = int(value)
        except (TypeError, ValueError):
            return
        if number != self._random_max:
            self._random_max = number
            self.randomMaxChanged.emit()

    @Property(int, notify=randomCountChanged)
    def randomCount(self) -> int:
        return self._random_count

    @randomCount.setter
    def randomCount(self, value: int) -> None:
        try:
            count = int(value)
        except (TypeError, ValueError):
            return
        count = max(1, min(1000, count))
        if count != self._random_count:
            self._random_count = count
            self.randomCountChanged.emit()

    @Property(bool, notify=randomUniqueChanged)
    def randomUnique(self) -> bool:
        return self._random_unique

    @randomUnique.setter
    def randomUnique(self, value: bool) -> None:
        value = bool(value)
        if value != self._random_unique:
            self._random_unique = value
            self.randomUniqueChanged.emit()

    @Property(str, notify=randomSortChanged)
    def randomSort(self) -> str:
        return self._random_sort

    @randomSort.setter
    def randomSort(self, value: str) -> None:
        value = value if value in self.RANDOM_SORTS else self.RANDOM_SORTS[0]
        if value != self._random_sort:
            self._random_sort = value
            self.randomSortChanged.emit()

    @Property(str, notify=randomOutputChanged)
    def randomOutput(self) -> str:
        return self._random_output

    @Property(str, notify=randomErrorChanged)
    def randomError(self) -> str:
        return self._random_error

    @Property(int, notify=randomStringLengthChanged)
    def randomStringLength(self) -> int:
        return self._random_string_length

    @randomStringLength.setter
    def randomStringLength(self, value: int) -> None:
        try:
            length = int(value)
        except (TypeError, ValueError):
            return
        length = max(1, min(256, length))
        if length != self._random_string_length:
            self._random_string_length = length
            self.randomStringLengthChanged.emit()

    @Property(int, notify=randomStringCountChanged)
    def randomStringCount(self) -> int:
        return self._random_string_count

    @randomStringCount.setter
    def randomStringCount(self, value: int) -> None:
        try:
            count = int(value)
        except (TypeError, ValueError):
            return
        count = max(1, min(100, count))
        if count != self._random_string_count:
            self._random_string_count = count
            self.randomStringCountChanged.emit()

    @Property(bool, notify=randomStringUppercaseChanged)
    def randomStringUppercase(self) -> bool:
        return self._random_string_uppercase

    @randomStringUppercase.setter
    def randomStringUppercase(self, value: bool) -> None:
        value = bool(value)
        if value != self._random_string_uppercase:
            self._random_string_uppercase = value
            self.randomStringUppercaseChanged.emit()

    @Property(bool, notify=randomStringLowercaseChanged)
    def randomStringLowercase(self) -> bool:
        return self._random_string_lowercase

    @randomStringLowercase.setter
    def randomStringLowercase(self, value: bool) -> None:
        value = bool(value)
        if value != self._random_string_lowercase:
            self._random_string_lowercase = value
            self.randomStringLowercaseChanged.emit()

    @Property(bool, notify=randomStringDigitsChanged)
    def randomStringDigits(self) -> bool:
        return self._random_string_digits

    @randomStringDigits.setter
    def randomStringDigits(self, value: bool) -> None:
        value = bool(value)
        if value != self._random_string_digits:
            self._random_string_digits = value
            self.randomStringDigitsChanged.emit()

    @Property(bool, notify=randomStringSymbolsChanged)
    def randomStringSymbols(self) -> bool:
        return self._random_string_symbols

    @randomStringSymbols.setter
    def randomStringSymbols(self, value: bool) -> None:
        value = bool(value)
        if value != self._random_string_symbols:
            self._random_string_symbols = value
            self.randomStringSymbolsChanged.emit()

    @Property(bool, notify=randomStringExcludeAmbiguousChanged)
    def randomStringExcludeAmbiguous(self) -> bool:
        return self._random_string_exclude_ambiguous

    @randomStringExcludeAmbiguous.setter
    def randomStringExcludeAmbiguous(self, value: bool) -> None:
        value = bool(value)
        if value != self._random_string_exclude_ambiguous:
            self._random_string_exclude_ambiguous = value
            self.randomStringExcludeAmbiguousChanged.emit()

    @Property(str, notify=randomStringOutputChanged)
    def randomStringOutput(self) -> str:
        return self._random_string_output

    @Property(str, notify=randomStringErrorChanged)
    def randomStringError(self) -> str:
        return self._random_string_error

    @Property(str, notify=randomIpVersionChanged)
    def randomIpVersion(self) -> str:
        return self._random_ip_version

    @randomIpVersion.setter
    def randomIpVersion(self, value: str) -> None:
        value = value if value in RANDOM_IP_VERSIONS else RANDOM_IP_VERSIONS[0]
        if value != self._random_ip_version:
            self._random_ip_version = value
            self.randomIpVersionChanged.emit()

    @Property(int, notify=randomIpCountChanged)
    def randomIpCount(self) -> int:
        return self._random_ip_count

    @randomIpCount.setter
    def randomIpCount(self, value: int) -> None:
        try:
            count = int(value)
        except (TypeError, ValueError):
            return
        count = max(1, min(100, count))
        if count != self._random_ip_count:
            self._random_ip_count = count
            self.randomIpCountChanged.emit()

    @Property(bool, notify=randomIpPrivateChanged)
    def randomIpPrivate(self) -> bool:
        return self._random_ip_private

    @randomIpPrivate.setter
    def randomIpPrivate(self, value: bool) -> None:
        value = bool(value)
        if value != self._random_ip_private:
            self._random_ip_private = value
            self.randomIpPrivateChanged.emit()

    @Property(str, notify=randomIpOutputChanged)
    def randomIpOutput(self) -> str:
        return self._random_ip_output

    @Property(str, notify=randomIdFormatChanged)
    def randomIdFormat(self) -> str:
        return self._random_id_format

    @randomIdFormat.setter
    def randomIdFormat(self, value: str) -> None:
        value = value if value in RANDOM_ID_FORMATS else RANDOM_ID_FORMATS[0]
        if value != self._random_id_format:
            self._random_id_format = value
            self.randomIdFormatChanged.emit()

    @Property(int, notify=randomIdLengthChanged)
    def randomIdLength(self) -> int:
        return self._random_id_length

    @randomIdLength.setter
    def randomIdLength(self, value: int) -> None:
        try:
            length = int(value)
        except (TypeError, ValueError):
            return
        length = max(4, min(64, length))
        if length != self._random_id_length:
            self._random_id_length = length
            self.randomIdLengthChanged.emit()

    @Property(int, notify=randomIdCountChanged)
    def randomIdCount(self) -> int:
        return self._random_id_count

    @randomIdCount.setter
    def randomIdCount(self, value: int) -> None:
        try:
            count = int(value)
        except (TypeError, ValueError):
            return
        count = max(1, min(100, count))
        if count != self._random_id_count:
            self._random_id_count = count
            self.randomIdCountChanged.emit()

    @Property(str, notify=randomIdOutputChanged)
    def randomIdOutput(self) -> str:
        return self._random_id_output

    @Property(str, notify=randomColorFormatChanged)
    def randomColorFormat(self) -> str:
        return self._random_color_format

    @randomColorFormat.setter
    def randomColorFormat(self, value: str) -> None:
        value = value if value in RANDOM_COLOR_FORMATS else RANDOM_COLOR_FORMATS[0]
        if value != self._random_color_format:
            self._random_color_format = value
            self.randomColorFormatChanged.emit()
            self._refresh_color_outputs()

    @Property(int, notify=randomColorCountChanged)
    def randomColorCount(self) -> int:
        return self._random_color_count

    @randomColorCount.setter
    def randomColorCount(self, value: int) -> None:
        try:
            count = int(value)
        except (TypeError, ValueError):
            return
        count = max(1, min(RANDOM_COLOR_MAX_COUNT, count))
        if count != self._random_color_count:
            self._random_color_count = count
            self.randomColorCountChanged.emit()

    @Property(list, notify=randomColorListChanged)
    def randomColorList(self) -> list[str]:
        return list(self._random_color_list)

    @Property(list, notify=randomColorCodesChanged)
    def randomColorCodes(self) -> list[str]:
        return list(self._random_color_codes)

    @Property(str, notify=randomColorOutputChanged)
    def randomColorOutput(self) -> str:
        return self._random_color_output

    @Property(str, notify=qrUrlChanged)
    def qrUrl(self) -> str:
        return self._qr_url

    @qrUrl.setter
    def qrUrl(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._qr_url:
            self._qr_url = value
            self.qrUrlChanged.emit()

    @Property(str, notify=qrImageSourceChanged)
    def qrImageSource(self) -> str:
        return self._qr_image_source

    @Property(int, notify=qrResolutionChanged)
    def qrResolution(self) -> int:
        return self._qr_resolution

    @qrResolution.setter
    def qrResolution(self, value: int) -> None:
        try:
            resolution = int(value)
        except (TypeError, ValueError):
            return
        resolution = max(64, min(4096, resolution))
        if resolution != self._qr_resolution:
            self._qr_resolution = resolution
            self.qrResolutionChanged.emit()

    @Property(str, notify=qrSavedMessageChanged)
    def qrSavedMessage(self) -> str:
        return self._qr_saved_message

    @Property(str, notify=qrErrorChanged)
    def qrError(self) -> str:
        return self._qr_error

    @Property(list, constant=True)
    def loremTypes(self) -> list[str]:
        return list(self.LOREM_TYPES)

    @Property(list, constant=True)
    def randomSorts(self) -> list[str]:
        return list(self.RANDOM_SORTS)

    @Property(list, constant=True)
    def qrResolutions(self) -> list[int]:
        return list(QR_RESOLUTIONS)

    @Property(list, constant=True)
    def randomIpVersions(self) -> list[str]:
        return list(RANDOM_IP_VERSIONS)

    @Property(list, constant=True)
    def randomIdFormats(self) -> list[str]:
        return list(RANDOM_ID_FORMATS)

    @Property(list, constant=True)
    def randomColorFormats(self) -> list[str]:
        return list(RANDOM_COLOR_FORMATS)

    def _set_simple(self, attribute: str, signal: Signal, value: str) -> None:
        if getattr(self, attribute) != value:
            setattr(self, attribute, value)
            signal.emit()

    def _set_password_error(self, value: str) -> None:
        self._set_simple("_password_error", self.passwordErrorChanged, value)

    def _set_lorem_error(self, value: str) -> None:
        self._set_simple("_lorem_error", self.loremErrorChanged, value)

    def _set_random_error(self, value: str) -> None:
        self._set_simple("_random_error", self.randomErrorChanged, value)

    def _set_random_string_error(self, value: str) -> None:
        self._set_simple(
            "_random_string_error", self.randomStringErrorChanged, value
        )

    def _set_qr_error(self, value: str) -> None:
        self._set_simple("_qr_error", self.qrErrorChanged, value)

    def _set_qr_saved_message(self, value: str) -> None:
        self._set_simple(
            "_qr_saved_message", self.qrSavedMessageChanged, value
        )

    def _set_password(self, value: str) -> None:
        self._set_simple("_password", self.passwordChanged, value)

    def _set_password_strength(self, value: str) -> None:
        self._set_simple("_password_strength", self.passwordStrengthChanged, value)

    def _set_password_entropy(self, value: int) -> None:
        value = int(value)
        if value != self._password_entropy:
            self._password_entropy = value
            self.passwordEntropyChanged.emit()

    def _set_lorem_text(self, value: str) -> None:
        self._set_simple("_lorem_text", self.loremTextChanged, value)

    def _set_random_output(self, value: str) -> None:
        self._set_simple("_random_output", self.randomOutputChanged, value)

    def _set_random_string_output(self, value: str) -> None:
        self._set_simple(
            "_random_string_output", self.randomStringOutputChanged, value
        )

    def _set_random_ip_output(self, value: str) -> None:
        self._set_simple("_random_ip_output", self.randomIpOutputChanged, value)

    def _set_random_id_output(self, value: str) -> None:
        self._set_simple("_random_id_output", self.randomIdOutputChanged, value)

    def _set_random_color_list(self, value: list[str]) -> None:
        if value != self._random_color_list:
            self._random_color_list = value
            self.randomColorListChanged.emit()

    def _set_random_color_codes(self, value: list[str]) -> None:
        if value != self._random_color_codes:
            self._random_color_codes = value
            self.randomColorCodesChanged.emit()

    def _set_random_color_output(self, value: str) -> None:
        self._set_simple(
            "_random_color_output", self.randomColorOutputChanged, value
        )

    def _set_qr_image_source(self, value: str) -> None:
        self._set_simple("_qr_image_source", self.qrImageSourceChanged, value)

    def _set_qr_matrix(self, matrix: list[list[bool]]) -> None:
        self._qr_matrix = matrix

    @Slot()
    def generatePassword(self) -> None:
        self._set_password_error("")
        character_sets: list[str] = []
        if self._include_uppercase:
            character_sets.append(string.ascii_uppercase)
        if self._include_lowercase:
            character_sets.append(string.ascii_lowercase)
        if self._include_digits:
            character_sets.append(string.digits)
        if self._include_symbols:
            character_sets.append(PASSWORD_SYMBOLS)

        if not character_sets:
            self._set_password("")
            self._set_password_strength("")
            self._set_password_entropy(0)
            self._set_password_error("Select at least one character set.")
            return

        length = self._password_length
        if length < len(character_sets):
            self._set_password("")
            self._set_password_strength("")
            self._set_password_entropy(0)
            self._set_password_error("Password is too short for the selected character sets.")
            return

        alphabet = "".join(character_sets)
        random_source = secrets.SystemRandom()
        characters = [secrets.choice(chars) for chars in character_sets]
        characters.extend(
            secrets.choice(alphabet) for _ in range(length - len(characters))
        )
        random_source.shuffle(characters)
        self._set_password("".join(characters))

        entropy = round(length * math.log2(len(alphabet)))
        self._set_password_entropy(entropy)
        if entropy < 50:
            strength = "Weak"
        elif entropy < 80:
            strength = "Fair"
        elif entropy < 120:
            strength = "Strong"
        else:
            strength = "Very strong"
        self._set_password_strength(strength)

    @Slot()
    def copyPassword(self) -> None:
        if self._password:
            QGuiApplication.clipboard().setText(self._password)

    def _lorem_sentence(self, random_source: secrets.SystemRandom) -> str:
        word_count = random_source.randint(8, 16)
        words = [random_source.choice(LOREM_WORDS) for _ in range(word_count)]
        return " ".join(words).capitalize() + "."

    @Slot()
    def generateLorem(self) -> None:
        self._set_lorem_error("")
        random_source = secrets.SystemRandom()
        amount = self._lorem_amount

        if self._lorem_type == "Words":
            words = [random_source.choice(LOREM_WORDS) for _ in range(amount)]
            self._set_lorem_text(" ".join(words).capitalize() + ".")
            return

        if self._lorem_type == "Sentences":
            sentences = [
                self._lorem_sentence(random_source) for _ in range(amount)
            ]
            self._set_lorem_text(" ".join(sentences))
            return

        paragraphs: list[str] = []
        for index in range(amount):
            sentences = [LOREM_OPENING] if index == 0 else []
            target = random_source.randint(3, 5)
            while len(sentences) < target:
                sentences.append(self._lorem_sentence(random_source))
            paragraphs.append(" ".join(sentences))
        self._set_lorem_text("\n\n".join(paragraphs))

    @Slot()
    def copyLorem(self) -> None:
        if self._lorem_text:
            QGuiApplication.clipboard().setText(self._lorem_text)

    @Slot()
    def generateRandom(self) -> None:
        self._set_random_error("")
        minimum = self._random_min
        maximum = self._random_max
        if minimum > maximum:
            self._set_random_output("")
            self._set_random_error("Minimum cannot be greater than maximum.")
            return

        count = self._random_count
        span = maximum - minimum + 1
        if self._random_unique and count > span:
            self._set_random_output("")
            self._set_random_error(
                "Cannot generate that many unique numbers in this range."
            )
            return

        random_source = secrets.SystemRandom()
        if self._random_unique:
            values = random_source.sample(range(minimum, maximum + 1), count)
        else:
            values = [
                random_source.randint(minimum, maximum) for _ in range(count)
            ]

        if self._random_sort == "Ascending":
            values.sort()
        elif self._random_sort == "Descending":
            values.sort(reverse=True)
        self._set_random_output(", ".join(str(value) for value in values))

    @Slot()
    def copyRandom(self) -> None:
        if self._random_output:
            QGuiApplication.clipboard().setText(self._random_output)

    def _random_string_sets(self) -> list[str]:
        character_sets: list[str] = []
        if self._random_string_uppercase:
            character_sets.append(string.ascii_uppercase)
        if self._random_string_lowercase:
            character_sets.append(string.ascii_lowercase)
        if self._random_string_digits:
            character_sets.append(string.digits)
        if self._random_string_symbols:
            character_sets.append(PASSWORD_SYMBOLS)

        if self._random_string_exclude_ambiguous:
            character_sets = [
                "".join(
                    character
                    for character in characters
                    if character not in AMBIGUOUS_CHARACTERS
                )
                for characters in character_sets
            ]
        return [characters for characters in character_sets if characters]

    @Slot()
    def generateRandomString(self) -> None:
        self._set_random_string_error("")
        character_sets = self._random_string_sets()
        if not character_sets:
            self._set_random_string_output("")
            self._set_random_string_error("Select at least one character set.")
            return

        length = self._random_string_length
        if length < len(character_sets):
            self._set_random_string_output("")
            self._set_random_string_error(
                "Length is too short for the selected character sets."
            )
            return

        alphabet = "".join(character_sets)
        random_source = secrets.SystemRandom()
        values: list[str] = []
        for _ in range(self._random_string_count):
            characters = [secrets.choice(chars) for chars in character_sets]
            characters.extend(
                secrets.choice(alphabet)
                for _ in range(length - len(characters))
            )
            random_source.shuffle(characters)
            values.append("".join(characters))
        self._set_random_string_output("\n".join(values))

    @Slot()
    def copyRandomString(self) -> None:
        if self._random_string_output:
            QGuiApplication.clipboard().setText(self._random_string_output)

    @staticmethod
    def _random_private_ipv4(random_source: secrets.SystemRandom) -> str:
        network = random_source.choice(PRIVATE_IPV4_NETWORKS)
        first_host = int(network.network_address) + 1
        last_host = int(network.broadcast_address) - 1
        return str(ipaddress.ip_address(random_source.randint(first_host, last_host)))

    @staticmethod
    def _random_public_ipv4(random_source: secrets.SystemRandom) -> str:
        while True:
            address = ipaddress.ip_address(random_source.getrandbits(32))
            if not any(address in network for network in PUBLIC_IPV4_EXCLUSIONS):
                return str(address)

    @staticmethod
    def _random_private_ipv6(random_source: secrets.SystemRandom) -> str:
        # Unique local addresses live in fd00::/8.
        value = (0xFD << 120) | random_source.getrandbits(120)
        return str(ipaddress.IPv6Address(value))

    @staticmethod
    def _random_public_ipv6(random_source: secrets.SystemRandom) -> str:
        while True:
            address = ipaddress.IPv6Address(random_source.getrandbits(128))
            if address.is_global:
                return str(address)

    @Slot()
    def generateRandomIp(self) -> None:
        random_source = secrets.SystemRandom()
        if self._random_ip_version == "IPv6":
            if self._random_ip_private:
                generator = self._random_private_ipv6
            else:
                generator = self._random_public_ipv6
        else:
            if self._random_ip_private:
                generator = self._random_private_ipv4
            else:
                generator = self._random_public_ipv4

        values = [
            generator(random_source) for _ in range(self._random_ip_count)
        ]
        self._set_random_ip_output("\n".join(values))

    @Slot()
    def copyRandomIp(self) -> None:
        if self._random_ip_output:
            QGuiApplication.clipboard().setText(self._random_ip_output)

    @Slot()
    def generateRandomId(self) -> None:
        random_source = secrets.SystemRandom()
        values: list[str] = []
        for _ in range(self._random_id_count):
            if self._random_id_format == "UUID v4":
                values.append(str(uuid.uuid4()))
            elif self._random_id_format == "Numeric":
                values.append(
                    "".join(
                        secrets.choice(string.digits)
                        for _ in range(self._random_id_length)
                    )
                )
            else:
                values.append(
                    "".join(
                        random_source.choice(SHORT_ID_ALPHABET)
                        for _ in range(self._random_id_length)
                    )
                )
        self._set_random_id_output("\n".join(values))

    @Slot()
    def copyRandomId(self) -> None:
        if self._random_id_output:
            QGuiApplication.clipboard().setText(self._random_id_output)

    def _format_color(self, color: tuple[int, int, int]) -> str:
        red, green, blue = color
        if self._random_color_format == "RGB":
            return f"rgb({red}, {green}, {blue})"
        if self._random_color_format == "HSL":
            hue, lightness, saturation = colorsys.rgb_to_hls(
                red / 255, green / 255, blue / 255
            )
            return (
                f"hsl({round(hue * 360)}, "
                f"{round(saturation * 100)}%, {round(lightness * 100)}%)"
            )
        return f"#{red:02X}{green:02X}{blue:02X}"

    def _refresh_color_outputs(self) -> None:
        self._set_random_color_list(
            [
                f"#{red:02X}{green:02X}{blue:02X}"
                for red, green, blue in self._random_color_values
            ]
        )
        self._set_random_color_codes(
            [self._format_color(color) for color in self._random_color_values]
        )
        self._set_random_color_output("\n".join(self._random_color_codes))

    @Slot()
    def generateRandomColor(self) -> None:
        random_source = secrets.SystemRandom()
        self._random_color_values = [
            (
                random_source.randrange(256),
                random_source.randrange(256),
                random_source.randrange(256),
            )
            for _ in range(self._random_color_count)
        ]
        self._refresh_color_outputs()

    @Slot()
    def copyRandomColor(self) -> None:
        if self._random_color_output:
            QGuiApplication.clipboard().setText(self._random_color_output)

    @Slot(str)
    def copyColorCode(self, code: str) -> None:
        text = str(code or "").strip()
        if text:
            QGuiApplication.clipboard().setText(text)

    def _render_qr(self, matrix: list[list[bool]], pixel_size: int) -> QImage:
        modules = len(matrix)
        pixel_size = max(modules, int(pixel_size))

        image = QImage(
            pixel_size,
            pixel_size,
            QImage.Format.Format_RGB32,
        )
        image.fill(QColor("white"))
        painter = QPainter(image)
        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(QColor("black"))
        for y, row in enumerate(matrix):
            y0 = round(y * pixel_size / modules)
            y1 = round((y + 1) * pixel_size / modules)
            for x, black in enumerate(row):
                if black:
                    x0 = round(x * pixel_size / modules)
                    x1 = round((x + 1) * pixel_size / modules)
                    painter.drawRect(x0, y0, x1 - x0, y1 - y0)
        painter.end()
        return image

    def _image_data_url(self, image: QImage) -> str:
        buffer = QBuffer()
        if not buffer.open(QIODevice.OpenModeFlag.WriteOnly):
            return ""
        try:
            if not image.save(buffer, "PNG"):
                return ""
            payload = base64.b64encode(bytes(buffer.data())).decode("ascii")
            return f"data:image/png;base64,{payload}"
        finally:
            buffer.close()

    @Slot()
    def generateQr(self) -> None:
        self._set_qr_error("")
        self._set_qr_saved_message("")
        text = self._qr_url.strip()
        if not text:
            self._set_qr_matrix([])
            self._set_qr_image_source("")
            self._set_qr_error("Enter a URL or text to encode.")
            return

        try:
            code = qrcode.QRCode(
                version=None,
                error_correction=ERROR_CORRECT_M,
                box_size=1,
                border=QR_QUIET_ZONE,
            )
            code.add_data(text)
            code.make(fit=True)
            matrix = [list(row) for row in code.get_matrix()]
            image = self._render_qr(matrix, len(matrix) * QR_PREVIEW_SCALE)
            source = self._image_data_url(image)
        except DataOverflowError:
            self._set_qr_matrix([])
            self._set_qr_image_source("")
            self._set_qr_error("Text is too long for a QR code.")
            return
        except Exception:
            self._set_qr_matrix([])
            self._set_qr_image_source("")
            self._set_qr_error("Could not generate the QR code.")
            return

        if not source:
            self._set_qr_matrix([])
            self._set_qr_image_source("")
            self._set_qr_error("Could not render the QR code.")
            return
        self._set_qr_matrix(matrix)
        self._set_qr_image_source(source)

    @Slot(str)
    def saveQr(self, path: str) -> None:
        self._set_qr_saved_message("")
        target = str(path or "").strip()
        if target.startswith("file://"):
            target = QUrl(target).toLocalFile()
        if not target:
            self._set_qr_saved_message("Choose where to save the QR code.")
            return

        target_path = Path(target).expanduser()
        if target_path.suffix.lower() != ".png":
            target_path = target_path.with_suffix(".png")

        if not self._qr_matrix:
            self.generateQr()
            if not self._qr_matrix:
                self._set_qr_saved_message(
                    self._qr_error or "Generate a QR code first."
                )
                return

        image = self._render_qr(self._qr_matrix, self._qr_resolution)
        if image.isNull() or not image.save(str(target_path), "PNG"):
            self._set_qr_saved_message("Could not save the QR code.")
            return
        self._set_qr_saved_message(f"Saved {target_path.name}")
