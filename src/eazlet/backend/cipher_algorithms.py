from __future__ import annotations

import base64
import binascii
import codecs
import math
import quopri
import re
import urllib.parse
from collections.abc import Callable
from dataclasses import dataclass

ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
POLYBIUS_ALPHABET = "ABCDEFGHIKLMNOPQRSTUVWXYZ"
TRIFID_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ."
ADFGX_ALPHABET = "ABCDEFGHIKLMNOPQRSTUVWXYZ"
ADFGVX_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
DEFAULT_SUBSTITUTION = "QWERTYUIOPASDFGHJKLZXCVBNM"

BASE58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
BASE62_ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
BASE91_ALPHABET = (
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    "!#$%&()*+,./:;<=>?@[]^_`{|}~\""
)
XXENCODE_ALPHABET = (
    "+-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
)

MORSE_CODE = {
    "A": ".-",
    "B": "-...",
    "C": "-.-.",
    "D": "-..",
    "E": ".",
    "F": "..-.",
    "G": "--.",
    "H": "....",
    "I": "..",
    "J": ".---",
    "K": "-.-",
    "L": ".-..",
    "M": "--",
    "N": "-.",
    "O": "---",
    "P": ".--.",
    "Q": "--.-",
    "R": ".-.",
    "S": "...",
    "T": "-",
    "U": "..-",
    "V": "...-",
    "W": ".--",
    "X": "-..-",
    "Y": "-.--",
    "Z": "--..",
    "1": ".----",
    "2": "..---",
    "3": "...--",
    "4": "....-",
    "5": ".....",
    "6": "-....",
    "7": "--...",
    "8": "---..",
    "9": "----.",
    "0": "-----",
}
REVERSE_MORSE = {value: key for key, value in MORSE_CODE.items()}

BACON_CODE = {
    letter: format(index, "05b").replace("0", "A").replace("1", "B")
    for index, letter in enumerate(ALPHABET)
}
REVERSE_BACON = {value: key for key, value in BACON_CODE.items()}

LEET_ENCODE = {"a": "4", "e": "3", "i": "1", "o": "0", "s": "5", "t": "7"}
LEET_DECODE = {value: key for key, value in LEET_ENCODE.items()}


# ---------------------------------------------------------------------------
# Encodings
# ---------------------------------------------------------------------------


def base64_encode(text: str) -> str:
    return base64.b64encode(text.encode("utf-8")).decode("ascii")


def base64_decode(text: str) -> str:
    cleaned = "".join(text.split())
    cleaned += "=" * (-len(cleaned) % 4)
    return base64.b64decode(cleaned).decode("utf-8")


def base32_encode(text: str) -> str:
    return base64.b32encode(text.encode("utf-8")).decode("ascii")


def base32_decode(text: str) -> str:
    cleaned = "".join(text.split()).upper()
    cleaned += "=" * (-len(cleaned) % 8)
    return base64.b32decode(cleaned).decode("utf-8")


def base85_encode(text: str) -> str:
    return base64.b85encode(text.encode("utf-8")).decode("ascii")


def base85_decode(text: str) -> str:
    return base64.b85decode("".join(text.split())).decode("utf-8")


def _base_n_encode(text: str, alphabet: str) -> str:
    data = text.encode("utf-8")
    value = int.from_bytes(data, "big") if data else 0
    output = ""
    while value:
        value, remainder = divmod(value, len(alphabet))
        output = alphabet[remainder] + output
    leading = len(data) - len(data.lstrip(b"\0"))
    return alphabet[0] * leading + output


def _base_n_decode(text: str, alphabet: str) -> str:
    cleaned = "".join(text.split())
    leading = len(cleaned) - len(cleaned.lstrip(alphabet[0]))
    value = 0
    for character in cleaned:
        value = value * len(alphabet) + alphabet.index(character)
    data = value.to_bytes((value.bit_length() + 7) // 8, "big") if value else b""
    return (b"\x00" * leading + data).decode("utf-8")


def base58_encode(text: str) -> str:
    return _base_n_encode(text, BASE58_ALPHABET)


def base58_decode(text: str) -> str:
    return _base_n_decode(text, BASE58_ALPHABET)


def base62_encode(text: str) -> str:
    return _base_n_encode(text, BASE62_ALPHABET)


def base62_decode(text: str) -> str:
    return _base_n_decode(text, BASE62_ALPHABET)


def base91_encode(text: str) -> str:
    data = text.encode("utf-8")
    buffer = 0
    bit_count = 0
    output: list[str] = []
    for byte in data:
        buffer |= byte << bit_count
        bit_count += 8
        if bit_count > 13:
            value = buffer & 8191
            if value > 88:
                buffer >>= 13
                bit_count -= 13
            else:
                value = buffer & 16383
                buffer >>= 14
                bit_count -= 14
            output.append(BASE91_ALPHABET[value % 91])
            output.append(BASE91_ALPHABET[value // 91])
    if bit_count:
        output.append(BASE91_ALPHABET[buffer % 91])
        if bit_count > 7 or buffer > 90:
            output.append(BASE91_ALPHABET[buffer // 91])
    return "".join(output)


def base91_decode(text: str) -> str:
    value = -1
    buffer = 0
    bit_count = 0
    output = bytearray()
    for character in text:
        if character not in BASE91_ALPHABET:
            continue
        digit = BASE91_ALPHABET.index(character)
        if value < 0:
            value = digit
            continue
        value += digit * 91
        buffer |= value << bit_count
        bit_count += 13 if (value & 8191) > 88 else 14
        while bit_count > 7:
            output.append(buffer & 255)
            buffer >>= 8
            bit_count -= 8
        value = -1
    if value + 1:
        output.append((buffer | (value << bit_count)) & 255)
    return output.decode("utf-8")


def hex_encode(text: str) -> str:
    return text.encode("utf-8").hex()


def hex_decode(text: str) -> str:
    return bytes.fromhex("".join(text.split())).decode("utf-8")


def binary_encode(text: str) -> str:
    return " ".join(f"{byte:08b}" for byte in text.encode("utf-8"))


def binary_decode(text: str) -> str:
    cleaned = "".join(text.split())
    if len(cleaned) % 8:
        raise ValueError("Binary input must contain whole bytes")
    return bytes(int(cleaned[index : index + 8], 2) for index in range(0, len(cleaned), 8)).decode(
        "utf-8"
    )


def octal_encode(text: str) -> str:
    return " ".join(f"{byte:03o}" for byte in text.encode("utf-8"))


def octal_decode(text: str) -> str:
    parts = text.split()
    if len(parts) == 1 and len(parts[0]) % 3 == 0:
        cleaned = parts[0]
        parts = [cleaned[index : index + 3] for index in range(0, len(cleaned), 3)]
    return bytes(int(part, 8) for part in parts).decode("utf-8")


def decimal_encode(text: str) -> str:
    return " ".join(str(byte) for byte in text.encode("utf-8"))


def decimal_decode(text: str) -> str:
    return bytes(int(part) for part in text.split()).decode("utf-8")


def url_encode(text: str) -> str:
    return urllib.parse.quote(text)


def url_decode(text: str) -> str:
    return urllib.parse.unquote(text)


def punycode_encode(text: str) -> str:
    return text.encode("punycode").decode("ascii")


def punycode_decode(text: str) -> str:
    return text.encode("ascii").decode("punycode")


def uuencode(text: str) -> str:
    data = text.encode("utf-8")
    lines = [
        binascii.b2a_uu(data[index : index + 45]).decode("ascii").rstrip("\n")
        for index in range(0, len(data), 45)
    ]
    return "\n".join(lines)


def uudecode(text: str) -> str:
    output = bytearray()
    for line in text.splitlines():
        line = line.rstrip()
        if not line or line.startswith("begin ") or line == "end":
            continue
        output.extend(binascii.a2b_uu(line))
    return output.decode("utf-8")


def xxencode(text: str) -> str:
    data = text.encode("utf-8")
    lines: list[str] = []
    for start in range(0, len(data), 45):
        chunk = data[start : start + 45]
        line = [XXENCODE_ALPHABET[len(chunk)]]
        for index in range(0, len(chunk), 3):
            group = chunk[index : index + 3].ljust(3, b"\0")
            value = int.from_bytes(group, "big")
            for shift in (18, 12, 6, 0):
                line.append(XXENCODE_ALPHABET[(value >> shift) & 63])
        lines.append("".join(line))
    return "\n".join(lines)


def xxdecode(text: str) -> str:
    output = bytearray()
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("begin ") or line == "end":
            continue
        length = XXENCODE_ALPHABET.index(line[0])
        chunk = bytearray()
        for index in range(1, len(line), 4):
            block = line[index : index + 4]
            if len(block) < 4:
                break
            value = 0
            for character in block:
                value = (value << 6) | XXENCODE_ALPHABET.index(character)
            chunk.extend(value.to_bytes(3, "big"))
        output.extend(chunk[:length])
    return output.decode("utf-8")


def quoted_printable_encode(text: str) -> str:
    return quopri.encodestring(text.encode("utf-8")).decode("ascii")


def quoted_printable_decode(text: str) -> str:
    return quopri.decodestring(text.encode("ascii")).decode("utf-8")


def morse_encode(text: str) -> str:
    words: list[str] = []
    for word in text.upper().split():
        encoded = []
        for character in word:
            code = MORSE_CODE.get(character)
            if code is None:
                raise ValueError(f"Morse does not support {character!r}")
            encoded.append(code)
        words.append(" ".join(encoded))
    return " / ".join(words)


def morse_decode(text: str) -> str:
    words: list[str] = []
    for word in re.split(r"\s*/\s*", text.strip()):
        if not word:
            continue
        letters = []
        for code in word.split():
            letter = REVERSE_MORSE.get(code)
            if letter is None:
                raise ValueError(f"Unknown Morse code {code!r}")
            letters.append(letter)
        words.append("".join(letters))
    return " ".join(words)


def reverse_text(text: str) -> str:
    return text[::-1]


# ---------------------------------------------------------------------------
# Classical ciphers
# ---------------------------------------------------------------------------


def _alpha_key(key: str) -> str:
    value = "".join(character for character in (key or "") if character.isalpha())
    if not value:
        raise ValueError("Enter a key for this cipher")
    return value.upper()


def _columnar_key(key: str) -> str:
    value = "".join(character for character in (key or "") if character.isalnum())
    if not value:
        raise ValueError("Enter a key for this cipher")
    return value


def _shift_character(character: str, shift: int) -> str:
    if "a" <= character <= "z":
        return chr((ord(character) - ord("a") + shift) % 26 + ord("a"))
    if "A" <= character <= "Z":
        return chr((ord(character) - ord("A") + shift) % 26 + ord("A"))
    return character


def rot13(text: str) -> str:
    return codecs.decode(text, "rot_13")


def rot47(text: str) -> str:
    return "".join(
        chr(33 + ((ord(character) - 33 + 47) % 94))
        if 33 <= ord(character) <= 126
        else character
        for character in text
    )


def caesar_encode(text: str, shift: int = 3) -> str:
    return "".join(_shift_character(character, shift % 26) for character in text)


def caesar_decode(text: str, shift: int = 3) -> str:
    return "".join(_shift_character(character, -shift % 26) for character in text)


def atbash(text: str) -> str:
    return "".join(
        chr(ord("z") - (ord(character) - ord("a")))
        if "a" <= character <= "z"
        else chr(ord("Z") - (ord(character) - ord("A")))
        if "A" <= character <= "Z"
        else character
        for character in text
    )


def _affine_parameters(key: str) -> tuple[int, int]:
    raw = (key or "5,8").strip()
    parts = [part.strip() for part in raw.split(",")]
    try:
        if len(parts) == 1:
            a, b = int(parts[0]), 8
        elif len(parts) == 2:
            a, b = int(parts[0]), int(parts[1])
        else:
            raise ValueError
    except ValueError as exc:
        raise ValueError("Affine key must be a,b (for example 5,8)") from exc
    a %= 26
    b %= 26
    if math.gcd(a, 26) != 1:
        raise ValueError("Affine 'a' must be coprime with 26")
    return a, b


def affine_encode(text: str, key: str = "") -> str:
    a, b = _affine_parameters(key)

    def transform(character: str) -> str:
        if "a" <= character <= "z":
            return chr((a * (ord(character) - ord("a")) + b) % 26 + ord("a"))
        if "A" <= character <= "Z":
            return chr((a * (ord(character) - ord("A")) + b) % 26 + ord("A"))
        return character

    return "".join(transform(character) for character in text)


def affine_decode(text: str, key: str = "") -> str:
    a, b = _affine_parameters(key)
    inverse = pow(a, -1, 26)

    def transform(character: str) -> str:
        if "a" <= character <= "z":
            return chr((inverse * (ord(character) - ord("a") - b)) % 26 + ord("a"))
        if "A" <= character <= "Z":
            return chr((inverse * (ord(character) - ord("A") - b)) % 26 + ord("A"))
        return character

    return "".join(transform(character) for character in text)


def _vigenere_transform(text: str, key: str, decrypt: bool) -> str:
    letters = _alpha_key(key)
    output: list[str] = []
    key_index = 0
    for character in text:
        if character.isalpha():
            shift = ord(letters[key_index % len(letters)]) - ord("A")
            output.append(_shift_character(character, -shift if decrypt else shift))
            key_index += 1
        else:
            output.append(character)
    return "".join(output)


def vigenere_encode(text: str, key: str = "") -> str:
    return _vigenere_transform(text, key, decrypt=False)


def vigenere_decode(text: str, key: str = "") -> str:
    return _vigenere_transform(text, key, decrypt=True)


def beaufort(text: str, key: str = "") -> str:
    letters = _alpha_key(key)
    output: list[str] = []
    key_index = 0
    for character in text:
        if character.isalpha():
            base = ord("a") if character.islower() else ord("A")
            shift = ord(letters[key_index % len(letters)]) - ord("A")
            value = (shift - (ord(character) - base)) % 26
            output.append(chr(base + value))
            key_index += 1
        else:
            output.append(character)
    return "".join(output)


def autokey_encode(text: str, key: str = "") -> str:
    letters = _alpha_key(key)
    stream = list(letters)
    plaintext_letters: list[str] = []
    output: list[str] = []
    key_index = 0
    for character in text:
        if character.isalpha():
            base = ord("a") if character.islower() else ord("A")
            shift = ord(stream[key_index]) - ord("A")
            value = (ord(character) - base + shift) % 26
            output.append(chr(base + value))
            plaintext_letters.append(character.upper())
            stream.append(character.upper())
            key_index += 1
        else:
            output.append(character)
    return "".join(output)


def autokey_decode(text: str, key: str = "") -> str:
    letters = _alpha_key(key)
    stream = list(letters)
    output: list[str] = []
    key_index = 0
    for character in text:
        if character.isalpha():
            base = ord("a") if character.islower() else ord("A")
            shift = ord(stream[key_index]) - ord("A")
            value = (ord(character) - base - shift) % 26
            plaintext = chr(base + value)
            output.append(plaintext)
            stream.append(plaintext.upper())
            key_index += 1
        else:
            output.append(character)
    return "".join(output)


def _playfair_square(key: str) -> tuple[list[str], dict[str, tuple[int, int]]]:
    letters = "".join(character for character in (key or "").upper() if character.isalpha())
    letters = letters.replace("J", "I")
    square: list[str] = []
    for character in letters + ALPHABET.replace("J", ""):
        if character not in square:
            square.append(character)
    positions = {character: divmod(index, 5) for index, character in enumerate(square)}
    return square, positions


def _playfair_digraphs(text: str) -> list[tuple[str, str]]:
    letters = [character for character in text.upper().replace("J", "I") if character.isalpha()]
    pairs: list[tuple[str, str]] = []
    index = 0
    while index < len(letters):
        first = letters[index]
        second = letters[index + 1] if index + 1 < len(letters) else ""
        if not second:
            pairs.append((first, "X"))
            index += 1
        elif first == second:
            pairs.append((first, "X" if first != "X" else "Q"))
            index += 1
        else:
            pairs.append((first, second))
            index += 2
    return pairs


def _playfair_transform_pair(
    pair: tuple[str, str],
    square: list[str],
    positions: dict[str, tuple[int, int]],
    decrypt: bool,
) -> str:
    first, second = pair
    first_row, first_column = positions[first]
    second_row, second_column = positions[second]
    if first_row == second_row:
        delta = -1 if decrypt else 1
        first_column = (first_column + delta) % 5
        second_column = (second_column + delta) % 5
    elif first_column == second_column:
        delta = -1 if decrypt else 1
        first_row = (first_row + delta) % 5
        second_row = (second_row + delta) % 5
    else:
        first_column, second_column = second_column, first_column
    return square[first_row * 5 + first_column] + square[second_row * 5 + second_column]


def _playfair_transform(text: str, key: str, decrypt: bool) -> str:
    square, positions = _playfair_square(key)
    return "".join(
        _playfair_transform_pair(pair, square, positions, decrypt)
        for pair in _playfair_digraphs(text)
    )


def playfair_encode(text: str, key: str = "") -> str:
    return _playfair_transform(text, key, decrypt=False)


def playfair_decode(text: str, key: str = "") -> str:
    return _playfair_transform(text, key, decrypt=True)


def baconian_encode(text: str) -> str:
    words: list[str] = []
    for word in re.findall(r"[A-Za-z]+", text):
        words.append("".join(BACON_CODE[character.upper()] for character in word))
    return " ".join(words)


def baconian_decode(text: str) -> str:
    words: list[str] = []
    for word in re.findall(r"[A-Za-z]+", text):
        letters = []
        for index in range(0, len(word) - 4, 5):
            code = word[index : index + 5].upper()
            letter = REVERSE_BACON.get(code)
            if letter is None:
                raise ValueError(f"Unknown Baconian group {code!r}")
            letters.append(letter)
        words.append("".join(letters))
    return " ".join(words)


def polybius_encode(text: str) -> str:
    words: list[str] = []
    for word in re.findall(r"[A-Za-z]+", text.upper()):
        encoded = []
        for character in word:
            index = POLYBIUS_ALPHABET.index("I" if character == "J" else character)
            encoded.append(f"{index // 5 + 1}{index % 5 + 1}")
        words.append("".join(encoded))
    return " ".join(words)


def polybius_decode(text: str) -> str:
    words: list[str] = []
    for word in re.findall(r"\d+", text):
        if len(word) % 2:
            raise ValueError("Polybius input must contain pairs of digits")
        letters = []
        for index in range(0, len(word), 2):
            row = int(word[index]) - 1
            column = int(word[index + 1]) - 1
            if not (0 <= row < 5 and 0 <= column < 5):
                raise ValueError("Polybius coordinates must be between 1 and 5")
            letters.append(POLYBIUS_ALPHABET[row * 5 + column])
        words.append("".join(letters))
    return " ".join(words)


def _sanitize_polybius(text: str) -> list[str]:
    return [
        "I" if character == "J" else character
        for character in text.upper()
        if "A" <= character <= "Z"
    ]


def _chunks(items: list[str], size: int) -> list[list[str]]:
    return [items[index : index + size] for index in range(0, len(items), size)]


def bifid_encode(text: str, period: int = 5) -> str:
    letters = _sanitize_polybius(text)
    output: list[str] = []
    for block in _chunks(letters, max(1, period)):
        rows = [POLYBIUS_ALPHABET.index(character) // 5 for character in block]
        columns = [POLYBIUS_ALPHABET.index(character) % 5 for character in block]
        numbers = rows + columns
        for index in range(0, len(numbers), 2):
            output.append(POLYBIUS_ALPHABET[numbers[index] * 5 + numbers[index + 1]])
    return "".join(output)


def bifid_decode(text: str, period: int = 5) -> str:
    letters = [character for character in text.upper() if character in POLYBIUS_ALPHABET]
    output: list[str] = []
    for block in _chunks(letters, max(1, period)):
        numbers: list[int] = []
        for character in block:
            index = POLYBIUS_ALPHABET.index(character)
            numbers.extend((index // 5, index % 5))
        split = len(block)
        rows = numbers[:split]
        columns = numbers[split:]
        for row, column in zip(rows, columns, strict=False):
            output.append(POLYBIUS_ALPHABET[row * 5 + column])
    return "".join(output)


def trifid_encode(text: str, period: int = 5) -> str:
    letters = [character for character in text.upper() if character in TRIFID_ALPHABET]
    output: list[str] = []
    for block in _chunks(letters, max(1, period)):
        layers: list[int] = []
        rows: list[int] = []
        columns: list[int] = []
        for character in block:
            index = TRIFID_ALPHABET.index(character)
            layers.append(index // 9)
            rows.append((index % 9) // 3)
            columns.append(index % 3)
        flat = layers + rows + columns
        for index in range(0, len(flat), 3):
            output.append(TRIFID_ALPHABET[flat[index] * 9 + flat[index + 1] * 3 + flat[index + 2]])
    return "".join(output)


def trifid_decode(text: str, period: int = 5) -> str:
    letters = [character for character in text.upper() if character in TRIFID_ALPHABET]
    output: list[str] = []
    for block in _chunks(letters, max(1, period)):
        flat: list[int] = []
        for character in block:
            index = TRIFID_ALPHABET.index(character)
            flat.extend((index // 9, (index % 9) // 3, index % 3))
        size = len(block)
        layers = flat[:size]
        rows = flat[size : size * 2]
        columns = flat[size * 2 :]
        for layer, row, column in zip(layers, rows, columns, strict=False):
            output.append(TRIFID_ALPHABET[layer * 9 + row * 3 + column])
    return "".join(output)


def _columnar_order(key: str) -> list[int]:
    return sorted(range(len(key)), key=lambda index: (key[index], index))


def columnar_encode(text: str, key: str = "") -> str:
    keyword = _columnar_key(key)
    columns = [""] * len(keyword)
    for index, character in enumerate(text):
        columns[index % len(keyword)] += character
    return "".join(columns[index] for index in _columnar_order(keyword))


def columnar_decode(text: str, key: str = "") -> str:
    keyword = _columnar_key(key)
    size = len(keyword)
    lengths = [
        len(text) // size + (1 if index < len(text) % size else 0)
        for index in range(size)
    ]
    columns = [""] * size
    position = 0
    for index in _columnar_order(keyword):
        columns[index] = text[position : position + lengths[index]]
        position += lengths[index]
    output: list[str] = []
    for row in range(max(lengths, default=0)):
        for column in columns:
            if row < len(column):
                output.append(column[row])
    return "".join(output)


def _adfg_encode(text: str, key: str, alphabet: str, labels: str) -> str:
    letters = [
        character
        for character in text.upper()
        if character in alphabet or (character == "J" and "J" not in alphabet and "I" in alphabet)
    ]
    ordered = ["I" if character == "J" else character for character in letters]
    encoded = "".join(
        labels[alphabet.index(character) // len(labels)]
        + labels[alphabet.index(character) % len(labels)]
        for character in ordered
    )
    return columnar_encode(encoded, key)


def _adfg_decode(text: str, key: str, alphabet: str, labels: str) -> str:
    coordinates = columnar_decode("".join(text.split()), key)
    if len(coordinates) % 2:
        raise ValueError("Encoded coordinates must contain pairs")
    output: list[str] = []
    for index in range(0, len(coordinates), 2):
        row = labels.index(coordinates[index])
        column = labels.index(coordinates[index + 1])
        output.append(alphabet[row * len(labels) + column])
    return "".join(output)


def adfgx_encode(text: str, key: str = "") -> str:
    return _adfg_encode(text, key, ADFGX_ALPHABET, "ADFGX")


def adfgx_decode(text: str, key: str = "") -> str:
    return _adfg_decode(text, key, ADFGX_ALPHABET, "ADFGX")


def adfgvx_encode(text: str, key: str = "") -> str:
    return _adfg_encode(text, key, ADFGVX_ALPHABET, "ADFGVX")


def adfgvx_decode(text: str, key: str = "") -> str:
    return _adfg_decode(text, key, ADFGVX_ALPHABET, "ADFGVX")


def _hill_matrix(key: str) -> tuple[int, int, int, int]:
    parts = [part for part in re.split(r"[,;\s]+", (key or "").strip()) if part]
    if len(parts) != 4:
        raise ValueError("Hill key must contain four numbers (a,b,c,d)")
    try:
        a, b, c, d = (int(part) for part in parts)
    except ValueError as exc:
        raise ValueError("Hill key must contain four numbers (a,b,c,d)") from exc
    determinant = (a * d - b * c) % 26
    if math.gcd(determinant, 26) != 1:
        raise ValueError("Hill matrix is not invertible modulo 26")
    return a % 26, b % 26, c % 26, d % 26


def hill_encode(text: str, key: str = "") -> str:
    a, b, c, d = _hill_matrix(key)
    letters = [ord(character) - ord("A") for character in text.upper() if character.isalpha()]
    if not letters:
        return ""
    if len(letters) % 2:
        letters.append(ord("X") - ord("A"))
    output: list[str] = []
    for index in range(0, len(letters), 2):
        first, second = letters[index], letters[index + 1]
        output.append(chr((a * first + b * second) % 26 + ord("A")))
        output.append(chr((c * first + d * second) % 26 + ord("A")))
    return "".join(output)


def hill_decode(text: str, key: str = "") -> str:
    a, b, c, d = _hill_matrix(key)
    determinant = (a * d - b * c) % 26
    inverse = pow(determinant, -1, 26)
    inverse_matrix = (
        (d * inverse) % 26,
        (-b * inverse) % 26,
        (-c * inverse) % 26,
        (a * inverse) % 26,
    )
    letters = [ord(character) - ord("A") for character in text.upper() if character.isalpha()]
    if len(letters) % 2:
        raise ValueError("Hill ciphertext must contain an even number of letters")
    output: list[str] = []
    for index in range(0, len(letters), 2):
        first, second = letters[index], letters[index + 1]
        output.append(chr((inverse_matrix[0] * first + inverse_matrix[1] * second) % 26 + ord("A")))
        output.append(chr((inverse_matrix[2] * first + inverse_matrix[3] * second) % 26 + ord("A")))
    return "".join(output)


def _substitution_alphabet(key: str) -> str:
    value = "".join(character for character in (key or "").upper() if character.isalpha())
    if not value:
        value = DEFAULT_SUBSTITUTION
    if len(value) != 26 or set(value) != set(ALPHABET):
        raise ValueError("Substitution key must be a permutation of A-Z")
    return value


def substitution_encode(text: str, key: str = "") -> str:
    alphabet = _substitution_alphabet(key)
    output: list[str] = []
    for character in text:
        if "a" <= character <= "z":
            output.append(alphabet[ord(character) - ord("a")].lower())
        elif "A" <= character <= "Z":
            output.append(alphabet[ord(character) - ord("A")])
        else:
            output.append(character)
    return "".join(output)


def substitution_decode(text: str, key: str = "") -> str:
    alphabet = _substitution_alphabet(key)
    reverse = {character: ALPHABET[index] for index, character in enumerate(alphabet)}
    output: list[str] = []
    for character in text:
        if "a" <= character <= "z":
            output.append(reverse.get(character.upper(), character).lower())
        elif "A" <= character <= "Z":
            output.append(reverse.get(character, character))
        else:
            output.append(character)
    return "".join(output)


def rail_fence_encode(text: str, rails: int = 3) -> str:
    if rails < 2:
        return text
    pattern = _rail_pattern(len(text), rails)
    rows = [""] * rails
    for character, rail in zip(text, pattern, strict=False):
        rows[rail] += character
    return "".join(rows)


def rail_fence_decode(text: str, rails: int = 3) -> str:
    if rails < 2:
        return text
    pattern = _rail_pattern(len(text), rails)
    counts = [pattern.count(rail) for rail in range(rails)]
    rows: list[list[str]] = []
    position = 0
    for count in counts:
        rows.append(list(text[position : position + count]))
        position += count
    indexes = [0] * rails
    output: list[str] = []
    for rail in pattern:
        output.append(rows[rail][indexes[rail]])
        indexes[rail] += 1
    return "".join(output)


def _rail_pattern(length: int, rails: int) -> list[int]:
    if rails < 2:
        return [0] * length
    pattern: list[int] = []
    rail = 0
    direction = 1
    for _ in range(length):
        pattern.append(rail)
        if rail == 0:
            direction = 1
        elif rail == rails - 1:
            direction = -1
        rail += direction
    return pattern


def scytale_encode(text: str, turns: int = 5) -> str:
    return columnar_encode(text, ALPHABET[: max(2, turns)])


def scytale_decode(text: str, turns: int = 5) -> str:
    return columnar_decode(text, ALPHABET[: max(2, turns)])


def leetspeak_encode(text: str) -> str:
    return "".join(LEET_ENCODE.get(character.lower(), character) for character in text)


def leetspeak_decode(text: str) -> str:
    return "".join(LEET_DECODE.get(character, character) for character in text)


def xor_text(text: str, key: str = "", *, decode: bool = False) -> str:
    key_bytes = (key or "A").encode("utf-8")
    if decode:
        data = bytes.fromhex("".join(text.split()))
    else:
        data = text.encode("utf-8")
    output = bytes(byte ^ key_bytes[index % len(key_bytes)] for index, byte in enumerate(data))
    return output.decode("utf-8") if decode else output.hex()


@dataclass(frozen=True)
class CipherSpec:
    encode: Callable[..., str]
    decode: Callable[..., str]
    uses_key: bool = False
    uses_shift: bool = False
    uses_rails: bool = False
    uses_turns: bool = False
    uses_period: bool = False
    key_hint: str = ""
    hint: str = ""


ENCODING_SPECS: dict[str, tuple[Callable[[str], str], Callable[[str], str]]] = {
    "Base64": (base64_encode, base64_decode),
    "Base32": (base32_encode, base32_decode),
    "Base85": (base85_encode, base85_decode),
    "Base58": (base58_encode, base58_decode),
    "Base62": (base62_encode, base62_decode),
    "Base91": (base91_encode, base91_decode),
    "Hex": (hex_encode, hex_decode),
    "Binary": (binary_encode, binary_decode),
    "Octal": (octal_encode, octal_decode),
    "Decimal": (decimal_encode, decimal_decode),
    "URL Encode/Decode": (url_encode, url_decode),
    "Punycode": (punycode_encode, punycode_decode),
    "UUencode": (uuencode, uudecode),
    "XXencode": (xxencode, xxdecode),
    "Quoted Printable": (quoted_printable_encode, quoted_printable_decode),
    "Morse": (morse_encode, morse_decode),
    "Reverse": (reverse_text, reverse_text),
}

CLASSICAL_SPECS: dict[str, CipherSpec] = {
    "ROT13": CipherSpec(rot13, rot13),
    "ROT47": CipherSpec(rot47, rot47, hint="ROT47 rotates printable ASCII characters."),
    "Caesar": CipherSpec(
        caesar_encode,
        caesar_decode,
        uses_shift=True,
        hint="The shift is applied to letters only.",
    ),
    "Atbash": CipherSpec(atbash, atbash),
    "Affine": CipherSpec(
        affine_encode,
        affine_decode,
        uses_key=True,
        key_hint="a,b (e.g. 5,8)",
        hint="Use a,b where a is coprime with 26.",
    ),
    "Vigenere": CipherSpec(
        vigenere_encode,
        vigenere_decode,
        uses_key=True,
        key_hint="Keyword (e.g. LEMON)",
    ),
    "Beaufort": CipherSpec(
        beaufort,
        beaufort,
        uses_key=True,
        key_hint="Keyword",
        hint="Beaufort uses the same operation for encoding and decoding.",
    ),
    "Autokey": CipherSpec(
        autokey_encode,
        autokey_decode,
        uses_key=True,
        key_hint="Primer keyword",
    ),
    "Playfair": CipherSpec(
        playfair_encode,
        playfair_decode,
        uses_key=True,
        key_hint="Keyword",
        hint="I and J share a cell; X pads repeated pairs.",
    ),
    "Baconian": CipherSpec(
        baconian_encode,
        baconian_decode,
        hint="Each letter becomes five A/B symbols.",
    ),
    "Polybius": CipherSpec(
        polybius_encode,
        polybius_decode,
        hint="Letters become row/column pairs on a 5x5 square.",
    ),
    "Bifid": CipherSpec(
        bifid_encode,
        bifid_decode,
        uses_period=True,
        hint="Period controls how many letters are processed per block.",
    ),
    "Trifid": CipherSpec(
        trifid_encode,
        trifid_decode,
        uses_period=True,
        hint="Period controls how many letters are processed per block.",
    ),
    "ADFGVX": CipherSpec(
        adfgvx_encode,
        adfgvx_decode,
        uses_key=True,
        key_hint="Transposition keyword",
        hint="Uses a 6x6 alphabet plus ADFGVX coordinates.",
    ),
    "ADFGX": CipherSpec(
        adfgx_encode,
        adfgx_decode,
        uses_key=True,
        key_hint="Transposition keyword",
        hint="Uses a 5x5 alphabet plus ADFGX coordinates.",
    ),
    "Hill": CipherSpec(
        hill_encode,
        hill_decode,
        uses_key=True,
        key_hint="a,b,c,d (2x2 matrix)",
        hint="The 2x2 matrix must be invertible modulo 26.",
    ),
    "Simple Substitution": CipherSpec(
        substitution_encode,
        substitution_decode,
        uses_key=True,
        key_hint="26-letter alphabet (optional)",
        hint="Defaults to a QWERTY alphabet when no key is given.",
    ),
    "Rail Fence": CipherSpec(
        rail_fence_encode,
        rail_fence_decode,
        uses_rails=True,
        hint="Rails controls the zig-zag depth.",
    ),
    "Transposition Columnar": CipherSpec(
        columnar_encode,
        columnar_decode,
        uses_key=True,
        key_hint="Keyword",
        hint="Columns are read in keyword alphabetical order.",
    ),
    "Scytale": CipherSpec(
        scytale_encode,
        scytale_decode,
        uses_turns=True,
        hint="Turns is the number of columns used by the wrap.",
    ),
    "Leetspeak": CipherSpec(
        leetspeak_encode,
        leetspeak_decode,
        hint="Decoding uses the most common substitution for each digit.",
    ),
    "XOR": CipherSpec(
        lambda text, key="": xor_text(text, key),
        lambda text, key="": xor_text(text, key, decode=True),
        uses_key=True,
        key_hint="Key (optional)",
        hint="XOR output is hex-encoded so it stays copyable.",
    ),
}
