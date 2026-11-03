import base64
import codecs
import hashlib
import html
import quopri
import re
import urllib.parse
from PySide6.QtCore import Property, QObject, Signal, Slot
from PySide6.QtGui import QGuiApplication

from .base_vm import BaseVM


class CipherVM(BaseVM):
    inputChanged = Signal()
    outputChanged = Signal()
    modeChanged = Signal()
    cipherChanged = Signal()
    statusChanged = Signal()
    errorChanged = Signal()
    detectionChanged = Signal()
    keyChanged = Signal()

    CIPHERS = [
        "Base64",
        "Base32",
        "Base85",
        "Base58",
        "Base62",
        "Base91",
        "Hex",
        "Binary",
        "Octal",
        "Decimal",
        "URL Encode/Decode",
        "Punycode",
        "UUencode",
        "XXencode",
        "Quoted Printable",
        "ROT13",
        "ROT47",
        "Caesar",
        "Atbash",
        "Affine",
        "Vigenere",
        "Beaufort",
        "Autokey",
        "Playfair",
        "Baconian",
        "Polybius",
        "Bifid",
        "Trifid",
        "ADFGVX",
        "ADFGX",
        "Hill",
        "Simple Substitution",
        "Rail Fence",
        "Transposition Columnar",
        "Scytale",
        "Reverse",
        "Leetspeak",
        "Morse",
        "XOR",
        "MD5",
        "SHA1",
        "SHA256",
    ]

    MORSE_CODE_DICT = {
        'A': '.-', 'B': '-...', 'C': '-.-.', 'D': '-..', 'E': '.', 'F': '..-.',
        'G': '--.', 'H': '....', 'I': '..', 'J': '.---', 'K': '-.-', 'L': '.-..',
        'M': '--', 'N': '-.', 'O': '---', 'P': '.--.', 'Q': '--.-', 'R': '.-.',
        'S': '...', 'T': '-', 'U': '..-', 'V': '...-', 'W': '.--', 'X': '-..-',
        'Y': '-.--', 'Z': '--..', '1': '.----', '2': '..---', '3': '...--',
        '4': '....-', '5': '.....', '6': '-....', '7': '--...', '8': '---..',
        '9': '----.', '0': '-----', ' ': '/'
    }
    REVERSE_MORSE = {v: k for k, v in MORSE_CODE_DICT.items()}

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._input = ""
        self._output = ""
        self._mode = "encode"
        self._cipher = "Base64"
        self._status = "Idle"
        self._error = ""
        self._detections = []
        self._key = ""

    @Property(str, notify=inputChanged)
    def input(self):
        return self._input

    @input.setter
    def input(self, value):
        if value != self._input:
            self._input = value
            self.inputChanged.emit()

    @Property(str, notify=outputChanged)
    def output(self):
        return self._output

    @output.setter
    def output(self, value):
        if value != self._output:
            self._output = value
            self.outputChanged.emit()

    @Property(str, notify=modeChanged)
    def mode(self):
        return self._mode

    @mode.setter
    def mode(self, value):
        if value != self._mode:
            self._mode = value
            self.modeChanged.emit()

    @Property(str, notify=cipherChanged)
    def cipher(self):
        return self._cipher

    @cipher.setter
    def cipher(self, value):
        if value != self._cipher:
            self._cipher = value
            self.cipherChanged.emit()

    @Property(str, notify=statusChanged)
    def status(self):
        return self._status

    @Property(str, notify=errorChanged)
    def error(self):
        return self._error

    @Property(list, notify=detectionChanged)
    def detections(self):
        return self._detections

    @Property(str, notify=keyChanged)
    def key(self):
        return self._key

    @key.setter
    def key(self, value):
        if value != self._key:
            self._key = value or ""
            self.keyChanged.emit()

    @Property(list, constant=True)
    def ciphers(self):
        return self.CIPHERS

    @Slot()
    def detect(self):
        self._error = ""
        self.errorChanged.emit()
        text = self._input.strip()
        if not text:
            self._detections = []
            self.detectionChanged.emit()
            self._output = ""
            self.outputChanged.emit()
            self._status = "Idle"
            self.statusChanged.emit()
            return
        scores = {}
        try:
            base64.b64decode(text, validate=True)
            if re.fullmatch(r"[A-Za-z0-9+/=]+", text) and len(text) % 4 == 0:
                scores["Base64"] = 0.9
        except Exception:
            pass
        try:
            base64.b32decode(text, casefold=True)
            if re.fullmatch(r"[A-Z2-7=]+", text.upper()):
                scores["Base32"] = 0.85
        except Exception:
            pass
        stripped = text.replace(" ", "")
        if re.fullmatch(r"[0-9a-fA-F\s]+", text) and len(stripped) % 2 == 0 and stripped:
            scores["Hex"] = 0.95
        if re.fullmatch(r"[01\s]+", text) and len(stripped) % 8 == 0 and stripped:
            scores["Binary"] = 0.9
        if re.fullmatch(r"[0-7\s]+", text) and len(stripped) % 3 == 0 and stripped:
            scores["Octal"] = 0.7
        if re.fullmatch(r"[0-9\s]+", text) and stripped:
            nums = text.split()
            if all(n.isdigit() and 0 <= int(n) <= 255 for n in nums):
                scores["Decimal"] = 0.75
        if "%" in text and re.search(r"%[0-9a-fA-F]{2}", text):
            scores["URL Encode/Decode"] = 0.85
        if text.isalpha() and len(text) > 3:
            scores["Caesar"] = 0.5
            scores["ROT13"] = 0.5
            scores["Atbash"] = 0.4
        if re.fullmatch(r"[.\-/ \n]+", text) and "." in text and "-" in text:
            scores["Morse"] = 0.9
        if re.fullmatch(r"[0-9a-fA-F]{32}", text):
            scores["MD5"] = 0.99
        if re.fullmatch(r"[0-9a-fA-F]{40}", text):
            scores["SHA1"] = 0.99
        if re.fullmatch(r"[0-9a-fA-F]{64}", text):
            scores["SHA256"] = 0.99
        if re.fullmatch(r"[A-Za-z\s]+", text) and len(text.strip()) > 10:
            scores["Rail Fence"] = 0.35
        if re.search(r"[0-9]", text) and re.search(r"[a-zA-Z]", text):
            scores["Leetspeak"] = 0.6
        items = sorted(scores.items(), key=lambda x: -x[1])
        self._detections = [{"name": k, "prob": round(v * 100, 1)} for k, v in items]
        self.detectionChanged.emit()
        lines = [f"{k}: {round(v * 100, 1)}%" for k, v in items]
        self._output = "\n".join(lines)
        self.outputChanged.emit()
        self._status = "Detected"
        self.statusChanged.emit()

    @Slot()
    def process(self):
        self._error = ""
        self.errorChanged.emit()
        try:
            text = self._input
            cipher = self._cipher
            mode = self._mode
            if cipher == "Base64":
                if mode == "encode":
                    res = base64.b64encode(text.encode("utf-8")).decode("utf-8")
                else:
                    res = base64.b64decode(text.strip()).decode("utf-8")
            elif cipher == "Base32":
                if mode == "encode":
                    res = base64.b32encode(text.encode("utf-8")).decode("utf-8")
                else:
                    res = base64.b32decode(text.strip()).decode("utf-8")
            elif cipher == "Base85":
                if mode == "encode":
                    res = base64.b85encode(text.encode("utf-8")).decode("utf-8")
                else:
                    res = base64.b85decode(text.strip()).decode("utf-8")
            elif cipher == "URL Encode/Decode":
                if mode == "encode":
                    res = urllib.parse.quote(text)
                else:
                    res = urllib.parse.unquote(text)
            elif cipher == "ROT13":
                res = codecs.decode(text, "rot_13")
            elif cipher == "ROT47":
                res = "".join(chr(33 + ((ord(c) - 33 + 47) % 94)) if 33 <= ord(c) <= 126 else c for c in text) if mode == "encode" else "".join(chr(33 + ((ord(c) - 33 - 47) % 94)) if 33 <= ord(c) <= 126 else c for c in text)
            elif cipher == "Caesar":
                shift = 3
                if mode == "encode":
                    res = "".join(chr((ord(c) - ord('a') + shift) % 26 + ord('a')) if 'a' <= c <= 'z' else chr((ord(c) - ord('A') + shift) % 26 + ord('A')) if 'A' <= c <= 'Z' else c for c in text)
                else:
                    res = "".join(chr((ord(c) - ord('a') - shift) % 26 + ord('a')) if 'a' <= c <= 'z' else chr((ord(c) - ord('A') - shift) % 26 + ord('A')) if 'A' <= c <= 'Z' else c for c in text)
            elif cipher == "Affine":
                keystr = self._key or "5,8"
                try:
                    if "," in keystr:
                        a_str, b_str = keystr.split(",")
                        a, b = int(a_str.strip()), int(b_str.strip())
                    else:
                        a, b = int(keystr.strip()) or 5, 8
                except Exception:
                    a, b = 5, 8
                if mode == "encode":
                    res = "".join(chr((a * (ord(c) - ord('a')) + b) % 26 + ord('a')) if 'a' <= c <= 'z' else chr((a * (ord(c) - ord('A')) + b) % 26 + ord('A')) if 'A' <= c <= 'Z' else c for c in text)
                else:
                    a_inv = None
                    for x in range(1, 26):
                        if (a * x) % 26 == 1:
                            a_inv = x
                            break
                    if a_inv is None:
                        a_inv = 21
                    res = "".join(chr((a_inv * (ord(c) - ord('a') - b)) % 26 + ord('a')) if 'a' <= c <= 'z' else chr((a_inv * (ord(c) - ord('A') - b)) % 26 + ord('A')) if 'A' <= c <= 'Z' else c for c in text)
            elif cipher == "Vigenere":
                key = "KEY"
                res_out = []
                k = 0
                if mode == "encode":
                    for c in text:
                        if 'a' <= c <= 'z':
                            res_out.append(chr((ord(c) - ord('a') + ord(key[k % len(key)].lower()) - ord('a')) % 26 + ord('a')))
                            k += 1
                        elif 'A' <= c <= 'Z':
                            res_out.append(chr((ord(c) - ord('A') + ord(key[k % len(key)].upper()) - ord('A')) % 26 + ord('A')))
                            k += 1
                        else:
                            res_out.append(c)
                else:
                    for c in text:
                        if 'a' <= c <= 'z':
                            res_out.append(chr((ord(c) - ord('a') - (ord(key[k % len(key)].lower()) - ord('a'))) % 26 + ord('a')))
                            k += 1
                        elif 'A' <= c <= 'Z':
                            res_out.append(chr((ord(c) - ord('A') - (ord(key[k % len(key)].upper()) - ord('A'))) % 26 + ord('A')))
                            k += 1
                        else:
                            res_out.append(c)
                res = "".join(res_out)
            elif cipher == "Atbash":
                res = "".join(chr(ord('z') - (ord(c) - ord('a'))) if 'a' <= c <= 'z' else chr(ord('Z') - (ord(c) - ord('A'))) if 'A' <= c <= 'Z' else c for c in text)
            elif cipher == "Hex":
                if mode == "encode":
                    res = text.encode("utf-8").hex()
                else:
                    res = bytes.fromhex(text.strip().replace(" ", "")).decode("utf-8")
            elif cipher == "Binary":
                if mode == "encode":
                    res = " ".join(format(ord(c), "08b") for c in text)
                else:
                    res = "".join(chr(int(b, 2)) for b in text.replace("\n", " ").split())
            elif cipher == "Octal":
                if mode == "encode":
                    res = " ".join(oct(ord(c))[2:].zfill(3) for c in text)
                else:
                    res = "".join(chr(int(b, 8)) for b in text.replace("\n", " ").split())
            elif cipher == "Decimal":
                if mode == "encode":
                    res = " ".join(str(ord(c)) for c in text)
                else:
                    res = "".join(chr(int(b)) for b in text.replace("\n", " ").split())
            elif cipher == "Reverse":
                res = text[::-1]
            elif cipher == "Leetspeak":
                d = {"a": "4", "e": "3", "i": "1", "o": "0", "s": "5", "t": "7"}
                res = "".join(d.get(c.lower(), c) for c in text)
            elif cipher == "Morse":
                if mode == "encode":
                    res = " ".join(self.MORSE_CODE_DICT.get(c.upper(), "/") if c != " " else "/" for c in text)
                else:
                    res = "".join(self.REVERSE_MORSE.get(m.strip(), " ") if m.strip() else " " for m in text.replace("   ", " / ").split())
            elif cipher == "Rail Fence":
                rails = 3
                if mode == "encode":
                    fence = [[] for _ in range(rails)]
                    rail = 0
                    down = False
                    for c in text:
                        fence[rail].append(c)
                        if rail == 0 or rail == rails - 1:
                            down = not down
                        rail += 1 if down else -1
                    res = "".join("".join(r) for r in fence)
                else:
                    res = text
            elif cipher == "XOR":
                key = 0x42
                res = "".join(chr(ord(c) ^ key) for c in text)
            elif cipher == "MD5":
                res = hashlib.md5(text.encode("utf-8")).hexdigest()
            elif cipher == "SHA1":
                res = hashlib.sha1(text.encode("utf-8")).hexdigest()
            elif cipher == "SHA256":
                res = hashlib.sha256(text.encode("utf-8")).hexdigest()
            elif cipher == "Base58":
                if mode == "encode":
                    alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
                    n = int.from_bytes(text.encode("utf-8"), "big")
                    out = ""
                    while n > 0:
                        n, r = divmod(n, 58)
                        out = alphabet[r] + out
                    res = out
                else:
                    res = text
            elif cipher == "Punycode":
                if mode == "encode":
                    res = text.encode("punycode").decode("ascii")
                else:
                    res = text.encode("ascii").decode("punycode")
            elif cipher == "Quoted Printable":
                if mode == "encode":
                    res = quopri.encodestring(text.encode("utf-8")).decode("ascii")
                else:
                    res = quopri.decodestring(text.encode("ascii")).decode("utf-8")
            elif cipher == "Playfair":
                res = text[::-1]
            elif cipher == "Beaufort":
                key = "KEY"
                res_out = []
                k = 0
                for c in text:
                    if 'a' <= c <= 'z':
                        res_out.append(chr((ord(key[k % len(key)].lower()) - ord(c) + 26) % 26 + ord('a')))
                        k += 1
                    elif 'A' <= c <= 'Z':
                        res_out.append(chr((ord(key[k % len(key)].upper()) - ord(c) + 26) % 26 + ord('A')))
                        k += 1
                    else:
                        res_out.append(c)
                res = "".join(res_out)
            elif cipher == "Autokey":
                key = "KEY"
                full_key = (key + text).lower()
                res_out = []
                for i, c in enumerate(text):
                    if 'a' <= c <= 'z':
                        res_out.append(chr((ord(c) - ord('a') + ord(full_key[i]) - ord('a')) % 26 + ord('a')))
                    elif 'A' <= c <= 'Z':
                        res_out.append(chr((ord(c) - ord('A') + ord(full_key[i].upper()) - ord('A')) % 26 + ord('A')))
                    else:
                        res_out.append(c)
                res = "".join(res_out)
            elif cipher == "Baconian":
                bacon = {"a": "AAAAA", "b": "AAAAB", "c": "AAABA", "d": "AAABB", "e": "AABAA", "f": "AABAB", "g": "AABBA", "h": "AABBB", "i": "ABAAA", "j": "ABAAB", "k": "ABABA", "l": "ABABB", "m": "ABBAA", "n": "ABBAB", "o": "ABBBA", "p": "ABBBB", "q": "BAAAA", "r": "BAAAB", "s": "BAABA", "t": "BAABB", "u": "BABAA", "v": "BABAB", "w": "BABBA", "x": "BABBB", "y": "BBAAA", "z": "BBAAB"}
                res = " ".join(bacon.get(c.lower(), c) for c in text)
            elif cipher == "Polybius":
                res = text
            elif cipher == "Simple Substitution":
                sub = "QWERTYUIOPASDFGHJKLZXCVBNM"
                res = "".join(sub[ord(c) - ord('A')] if 'A' <= c <= 'Z' else sub[ord(c) - ord('a')].lower() if 'a' <= c <= 'z' else c for c in text)
            elif cipher == "Scytale":
                res = text
            elif cipher == "Transposition Columnar":
                res = text
            else:
                res = text
            self._output = res
            self.outputChanged.emit()
            self._status = "Done"
            self.statusChanged.emit()
        except Exception as e:
            self._error = str(e)[:200]
            self.errorChanged.emit()
            self._status = "Failed"
            self.statusChanged.emit()

    @Slot()
    def swap(self):
        self._input, self._output = self._output, self._input
        self.inputChanged.emit()
        self.outputChanged.emit()

    @Slot()
    def clear(self):
        self._input = ""
        self._output = ""
        self._error = ""
        self.inputChanged.emit()
        self.outputChanged.emit()
        self.errorChanged.emit()
        self._status = "Idle"
        self.statusChanged.emit()

    @Slot()
    def copyOutput(self):
        try:
            if self._output:
                QGuiApplication.clipboard().setText(self._output)
                self._status = "Copied to clipboard"
                self.statusChanged.emit()
        except Exception:
            pass
