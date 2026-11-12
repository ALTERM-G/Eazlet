import base64
import hashlib
import os
import re

from cryptography.exceptions import InvalidTag
from cryptography.fernet import Fernet, InvalidToken
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM, ChaCha20Poly1305
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from PySide6.QtCore import Property, QObject, Signal, Slot
from PySide6.QtGui import QGuiApplication

from ..cipher_algorithms import CLASSICAL_SPECS, ENCODING_SPECS, CipherSpec
from .base_vm import BaseVM


class CipherVM(BaseVM):
    ioChanged = Signal()
    modeChanged = Signal()
    cipherChanged = Signal()
    statusChanged = Signal()
    errorChanged = Signal()
    detectionChanged = Signal()
    keyChanged = Signal()
    encodingAlgorithmChanged = Signal()
    cipherAlgorithmChanged = Signal()
    cipherSettingsChanged = Signal()
    hashAlgorithmChanged = Signal()
    encryptionAlgorithmChanged = Signal()
    passphraseChanged = Signal()
    shiftChanged = Signal()
    railsChanged = Signal()
    turnsChanged = Signal()
    periodChanged = Signal()

    ENCODINGS = list(ENCODING_SPECS)
    CLASSICAL_CIPHERS = list(CLASSICAL_SPECS)
    HASH_ALGORITHMS = ["MD5", "SHA1", "SHA256"]
    CIPHERS = ENCODINGS + CLASSICAL_CIPHERS + HASH_ALGORITHMS

    ENCRYPTION_ALGORITHMS = ["AES-256-GCM", "ChaCha20-Poly1305", "Fernet"]
    ENCRYPTION_MAGIC = b"EZL2"
    KDF_ITERATIONS = 200_000
    SALT_SIZE = 16
    NONCE_SIZE = 12

    HASH_NAMES = {"MD5": "md5", "SHA1": "sha1", "SHA256": "sha256"}

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._mode = "encode"
        self._cipher = "Base64"
        self._status = ""
        self._error = ""
        self._detections: list[dict[str, object]] = []
        self._key = ""
        self._encoding_algorithm = "Base64"
        self._cipher_algorithm = "ROT13"
        self._hash_algorithm = "SHA256"
        self._encryption_algorithm = "AES-256-GCM"
        self._passphrase = ""
        self._shift = 3
        self._rails = 3
        self._turns = 5
        self._period = 5
        self._encoding_input = ""
        self._encoding_output = ""
        self._cipher_input = ""
        self._cipher_output = ""
        self._encryption_input = ""
        self._encryption_output = ""
        self._hash_input = ""
        self._hash_output = ""

    # ------------------------------------------------------------------
    # Per-tab input / output
    # ------------------------------------------------------------------

    def _set_io(self, name: str, value: str) -> None:
        attr = f"_{name}"
        value = value or ""
        if getattr(self, attr) != value:
            setattr(self, attr, value)
            self.ioChanged.emit()

    def _tab_input(self, name: str) -> str:
        return getattr(self, f"_{name}_input")

    def _tab_output(self, name: str) -> str:
        return getattr(self, f"_{name}_output")

    def _set_tab_output(self, name: str, value: str) -> None:
        self._set_io(f"{name}_output", value)

    @Property(str, notify=ioChanged)
    def encodingInput(self):
        return self._encoding_input

    @encodingInput.setter
    def encodingInput(self, value):
        self._set_io("encoding_input", value)

    @Property(str, notify=ioChanged)
    def encodingOutput(self):
        return self._encoding_output

    @encodingOutput.setter
    def encodingOutput(self, value):
        self._set_io("encoding_output", value)

    @Property(str, notify=ioChanged)
    def cipherInput(self):
        return self._cipher_input

    @cipherInput.setter
    def cipherInput(self, value):
        self._set_io("cipher_input", value)

    @Property(str, notify=ioChanged)
    def cipherOutput(self):
        return self._cipher_output

    @cipherOutput.setter
    def cipherOutput(self, value):
        self._set_io("cipher_output", value)

    @Property(str, notify=ioChanged)
    def encryptionInput(self):
        return self._encryption_input

    @encryptionInput.setter
    def encryptionInput(self, value):
        self._set_io("encryption_input", value)

    @Property(str, notify=ioChanged)
    def encryptionOutput(self):
        return self._encryption_output

    @encryptionOutput.setter
    def encryptionOutput(self, value):
        self._set_io("encryption_output", value)

    @Property(str, notify=ioChanged)
    def hashTextInput(self):
        return self._hash_input

    @hashTextInput.setter
    def hashTextInput(self, value):
        self._set_io("hash_input", value)

    @Property(str, notify=ioChanged)
    def hashTextOutput(self):
        return self._hash_output

    @hashTextOutput.setter
    def hashTextOutput(self, value):
        self._set_io("hash_output", value)

    # ------------------------------------------------------------------
    # Core state
    # ------------------------------------------------------------------

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

    # ------------------------------------------------------------------
    # Algorithm selection
    # ------------------------------------------------------------------

    @Property(str, notify=keyChanged)
    def key(self):
        return self._key

    @key.setter
    def key(self, value):
        if value != self._key:
            self._key = value or ""
            self.keyChanged.emit()

    @Property(str, notify=encodingAlgorithmChanged)
    def encodingAlgorithm(self):
        return self._encoding_algorithm

    @encodingAlgorithm.setter
    def encodingAlgorithm(self, value):
        if value and value != self._encoding_algorithm:
            self._encoding_algorithm = value
            self.encodingAlgorithmChanged.emit()

    @Property(str, notify=cipherAlgorithmChanged)
    def cipherAlgorithm(self):
        return self._cipher_algorithm

    @cipherAlgorithm.setter
    def cipherAlgorithm(self, value):
        if value and value != self._cipher_algorithm:
            self._cipher_algorithm = value
            self.cipherAlgorithmChanged.emit()
            self.cipherSettingsChanged.emit()

    @Property(str, notify=hashAlgorithmChanged)
    def hashAlgorithm(self):
        return self._hash_algorithm

    @hashAlgorithm.setter
    def hashAlgorithm(self, value):
        if value and value != self._hash_algorithm:
            self._hash_algorithm = value
            self.hashAlgorithmChanged.emit()

    @Property(str, notify=encryptionAlgorithmChanged)
    def encryptionAlgorithm(self):
        return self._encryption_algorithm

    @encryptionAlgorithm.setter
    def encryptionAlgorithm(self, value):
        if value and value != self._encryption_algorithm:
            self._encryption_algorithm = value
            self.encryptionAlgorithmChanged.emit()

    @Property(str, notify=passphraseChanged)
    def passphrase(self):
        return self._passphrase

    @passphrase.setter
    def passphrase(self, value):
        if value != self._passphrase:
            self._passphrase = value or ""
            self.passphraseChanged.emit()

    # ------------------------------------------------------------------
    # Per-cipher settings
    # ------------------------------------------------------------------

    @Property(int, notify=shiftChanged)
    def shift(self):
        return self._shift

    @shift.setter
    def shift(self, value):
        value = max(1, min(25, int(value)))
        if value != self._shift:
            self._shift = value
            self.shiftChanged.emit()

    @Property(int, notify=railsChanged)
    def rails(self):
        return self._rails

    @rails.setter
    def rails(self, value):
        value = max(2, min(15, int(value)))
        if value != self._rails:
            self._rails = value
            self.railsChanged.emit()

    @Property(int, notify=turnsChanged)
    def turns(self):
        return self._turns

    @turns.setter
    def turns(self, value):
        value = max(2, min(20, int(value)))
        if value != self._turns:
            self._turns = value
            self.turnsChanged.emit()

    @Property(int, notify=periodChanged)
    def period(self):
        return self._period

    @period.setter
    def period(self, value):
        value = max(1, min(20, int(value)))
        if value != self._period:
            self._period = value
            self.periodChanged.emit()

    def _current_spec(self) -> CipherSpec | None:
        return CLASSICAL_SPECS.get(self._cipher_algorithm)

    @Property(bool, notify=cipherSettingsChanged)
    def usesKey(self):
        spec = self._current_spec()
        return bool(spec and spec.uses_key)

    @Property(bool, notify=cipherSettingsChanged)
    def usesShift(self):
        spec = self._current_spec()
        return bool(spec and spec.uses_shift)

    @Property(bool, notify=cipherSettingsChanged)
    def usesRails(self):
        spec = self._current_spec()
        return bool(spec and spec.uses_rails)

    @Property(bool, notify=cipherSettingsChanged)
    def usesTurns(self):
        spec = self._current_spec()
        return bool(spec and spec.uses_turns)

    @Property(bool, notify=cipherSettingsChanged)
    def usesPeriod(self):
        spec = self._current_spec()
        return bool(spec and spec.uses_period)

    @Property(str, notify=cipherSettingsChanged)
    def keyHint(self):
        spec = self._current_spec()
        return spec.key_hint if spec else ""

    @Property(str, notify=cipherSettingsChanged)
    def cipherHint(self):
        spec = self._current_spec()
        return spec.hint if spec else ""

    # ------------------------------------------------------------------
    # Static option lists
    # ------------------------------------------------------------------

    @Property(list, constant=True)
    def ciphers(self):
        return self.CIPHERS

    @Property(list, constant=True)
    def encodings(self):
        return self.ENCODINGS

    @Property(list, constant=True)
    def classicalCiphers(self):
        return self.CLASSICAL_CIPHERS

    @Property(list, constant=True)
    def hashAlgorithms(self):
        return self.HASH_ALGORITHMS

    @Property(list, constant=True)
    def encryptionAlgorithms(self):
        return self.ENCRYPTION_ALGORITHMS

    # ------------------------------------------------------------------
    # Detection
    # ------------------------------------------------------------------

    @Slot()
    def detect(self):
        self._set_error("")
        text = self._encoding_input.strip()
        if not text:
            self._detections = []
            self.detectionChanged.emit()
            self._set_tab_output("encoding", "")
            self._set_status("")
            return

        scores: dict[str, float] = {}
        stripped = "".join(text.split())

        def looks_like_encoding(name: str, maximum: float) -> None:
            encode, decode = ENCODING_SPECS[name]
            try:
                decoded = decode(text)
                reencoded = encode(decoded)
            except Exception:
                return
            if decoded and reencoded.rstrip("=") in {
                "".join(text.split()).rstrip("="),
                "".join(text.split()).upper().rstrip("="),
            }:
                scores[name] = maximum

        for name in ("Base64", "Base32", "Base85", "Base58", "Base62", "Base91"):
            looks_like_encoding(name, 0.9)

        if re.fullmatch(r"[0-9a-fA-F\s]+", text) and len(stripped) % 2 == 0 and stripped:
            scores["Hex"] = 0.95
        if re.fullmatch(r"[01\s]+", text) and len(stripped) % 8 == 0 and stripped:
            scores["Binary"] = 0.9
        if re.fullmatch(r"[0-7\s]+", text) and len(stripped) % 3 == 0 and stripped:
            scores["Octal"] = 0.7
        if re.fullmatch(r"[0-9\s]+", text) and stripped:
            values = text.split()
            if all(value.isdigit() and 0 <= int(value) <= 255 for value in values):
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

        items = sorted(scores.items(), key=lambda item: -item[1])
        self._detections = [{"name": name, "prob": round(value * 100, 1)} for name, value in items]
        self.detectionChanged.emit()
        self._set_tab_output(
            "encoding",
            "\n".join(f"{name}: {round(value * 100, 1)}%" for name, value in items),
        )
        self._set_status("Detected")

    # ------------------------------------------------------------------
    # State helpers
    # ------------------------------------------------------------------

    def _set_error(self, message: str) -> None:
        self._error = message
        self.errorChanged.emit()

    def _set_status(self, value: str) -> None:
        self._status = value
        self.statusChanged.emit()

    def _fail(self, message: str) -> None:
        self._set_error(message or "Operation failed")
        self._set_status("Failed")

    # ------------------------------------------------------------------
    # Processing
    # ------------------------------------------------------------------

    def _run_selected(self, algorithm: str, tab: str) -> None:
        if algorithm != self._cipher:
            self._cipher = algorithm
            self.cipherChanged.emit()
        self._process(tab)

    @Slot()
    def processEncoding(self):
        self._run_selected(self._encoding_algorithm, "encoding")

    @Slot()
    def processCipher(self):
        self._run_selected(self._cipher_algorithm, "cipher")

    @Slot()
    def processHash(self):
        self._run_selected(self._hash_algorithm, "hash")

    def _transform_classical(self, text: str, mode: str) -> str:
        spec = CLASSICAL_SPECS[self._cipher]
        kwargs: dict[str, object] = {}
        if spec.uses_key:
            kwargs["key"] = self._key
        if spec.uses_shift:
            kwargs["shift"] = self._shift
        if spec.uses_rails:
            kwargs["rails"] = self._rails
        if spec.uses_turns:
            kwargs["turns"] = self._turns
        if spec.uses_period:
            kwargs["period"] = self._period
        transform = spec.decode if mode == "decode" else spec.encode
        return transform(text, **kwargs)

    def _process(self, tab: str) -> None:
        self._set_error("")
        try:
            text = self._tab_input(tab)
            cipher = self._cipher
            if cipher in self.HASH_ALGORITHMS:
                result = hashlib.new(self.HASH_NAMES[cipher], text.encode("utf-8")).hexdigest()
            elif cipher in ENCODING_SPECS:
                encode, decode = ENCODING_SPECS[cipher]
                result = (decode if self._mode == "decode" else encode)(text)
            elif cipher in CLASSICAL_SPECS:
                result = self._transform_classical(text, self._mode)
            else:
                raise ValueError(f"Unknown algorithm {cipher!r}")
            self._set_tab_output(tab, result)
            self._set_status("Done")
        except Exception as exc:
            self._fail(str(exc)[:200])

    # ------------------------------------------------------------------
    # Authenticated encryption
    # ------------------------------------------------------------------

    @staticmethod
    def _derive_key(passphrase: str, salt: bytes) -> bytes:
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=CipherVM.KDF_ITERATIONS,
        )
        return kdf.derive(passphrase.encode("utf-8"))

    @Slot()
    def encrypt(self):
        self._set_error("")
        if not self._passphrase:
            self._fail("Enter a passphrase")
            return
        try:
            algorithm = self._encryption_algorithm
            algorithm_id = self.ENCRYPTION_ALGORITHMS.index(algorithm) + 1
            salt = os.urandom(self.SALT_SIZE)
            nonce = os.urandom(self.NONCE_SIZE)
            key = self._derive_key(self._passphrase, salt)
            header = self.ENCRYPTION_MAGIC + bytes([algorithm_id]) + salt + nonce
            if algorithm == "Fernet":
                payload = Fernet(base64.urlsafe_b64encode(key)).encrypt(
                    self._encryption_input.encode("utf-8")
                )
            else:
                aead = (
                    AESGCM(key)
                    if algorithm == "AES-256-GCM"
                    else ChaCha20Poly1305(key)
                )
                payload = aead.encrypt(nonce, self._encryption_input.encode("utf-8"), header)
            self._set_tab_output("encryption", base64.b64encode(header + payload).decode("ascii"))
            self._set_status(f"Encrypted with {algorithm}")
        except Exception as exc:
            self._fail(str(exc)[:200])

    @Slot()
    def decrypt(self):
        self._set_error("")
        if not self._passphrase:
            self._fail("Enter a passphrase")
            return
        try:
            raw = base64.b64decode(self._encryption_input.strip(), validate=True)
            header_size = len(self.ENCRYPTION_MAGIC) + 1 + self.SALT_SIZE + self.NONCE_SIZE
            if len(raw) <= header_size or not raw.startswith(self.ENCRYPTION_MAGIC):
                raise ValueError("Not a valid Eazlet encrypted payload")
            algorithm_id = raw[len(self.ENCRYPTION_MAGIC)]
            if not 1 <= algorithm_id <= len(self.ENCRYPTION_ALGORITHMS):
                raise ValueError("Unsupported encryption algorithm")
            algorithm = self.ENCRYPTION_ALGORITHMS[algorithm_id - 1]
            salt_start = len(self.ENCRYPTION_MAGIC) + 1
            nonce_start = salt_start + self.SALT_SIZE
            salt = raw[salt_start:nonce_start]
            nonce = raw[nonce_start:header_size]
            payload = raw[header_size:]
            key = self._derive_key(self._passphrase, salt)
            if algorithm == "Fernet":
                clear = Fernet(base64.urlsafe_b64encode(key)).decrypt(payload)
            else:
                aead = (
                    AESGCM(key)
                    if algorithm == "AES-256-GCM"
                    else ChaCha20Poly1305(key)
                )
                clear = aead.decrypt(nonce, payload, raw[:header_size])
            self._set_tab_output("encryption", clear.decode("utf-8"))
            self._set_status(f"Decrypted with {algorithm}")
        except (InvalidToken, InvalidTag):
            self._fail("Wrong passphrase or corrupted payload")
        except Exception as exc:
            self._fail(str(exc)[:200])

    # ------------------------------------------------------------------
    # Shared actions
    # ------------------------------------------------------------------

    def _swap(self, tab: str) -> None:
        current_input = self._tab_input(tab)
        current_output = self._tab_output(tab)
        self._set_io(f"{tab}_input", current_output)
        self._set_io(f"{tab}_output", current_input)

    def _clear(self, tab: str) -> None:
        self._set_io(f"{tab}_input", "")
        self._set_io(f"{tab}_output", "")
        self._set_error("")
        self._set_status("")

    @Slot()
    def swapEncoding(self):
        self._swap("encoding")

    @Slot()
    def swapCipher(self):
        self._swap("cipher")

    @Slot()
    def clearEncoding(self):
        self._clear("encoding")

    @Slot()
    def clearCipher(self):
        self._clear("cipher")

    @Slot()
    def clearEncryption(self):
        self._clear("encryption")

    @Slot()
    def clearHash(self):
        self._clear("hash")

    @Slot(str)
    def copyText(self, text):
        try:
            if text:
                QGuiApplication.clipboard().setText(text)
                self._set_status("Copied to clipboard")
        except Exception:
            pass
