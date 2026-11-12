import hashlib

import pytest

from eazlet.backend.cipher_algorithms import CLASSICAL_SPECS, ENCODING_SPECS
from eazlet.backend.viewmodels.cipher_vm import CipherVM

ENCODING_SAMPLES = {
    "Morse": "SOS HELLO",
    "Punycode": "hello",
    "UUencode": "Hello, World!",
    "XXencode": "Hello, World!",
    "Reverse": "Hello",
}
CLASSICAL_SAMPLES = {
    "Playfair": "ATTACKATDAWN",
    "Baconian": "HELLO",
    "Polybius": "HELLO",
    "Bifid": "HELLOWORLD",
    "Trifid": "HELLOWORLD",
    "ADFGVX": "HELLO123",
    "ADFGX": "HELLO",
    "Hill": "ATTACKATDAWN",
    "Leetspeak": "hello",
}
CLASSICAL_KEYS = {
    "Affine": "5,8",
    "Hill": "3,3,2,7",
    "Simple Substitution": "",
}


def apply_settings(vm, name):
    spec = CLASSICAL_SPECS[name]
    if spec.uses_key:
        vm.key = CLASSICAL_KEYS.get(name, "LEMON")
    if spec.uses_shift:
        vm.shift = 3
    if spec.uses_rails:
        vm.rails = 3
    if spec.uses_turns:
        vm.turns = 5
    if spec.uses_period:
        vm.period = 5


def test_cipher_categories_partition_algorithms():
    categorized = CipherVM.ENCODINGS + CipherVM.CLASSICAL_CIPHERS + CipherVM.HASH_ALGORITHMS
    assert categorized == CipherVM.CIPHERS
    assert len(categorized) == len(set(categorized))


def test_cipher_categories_match_algorithm_tables():
    assert CipherVM.ENCODINGS == list(ENCODING_SPECS)
    assert CipherVM.CLASSICAL_CIPHERS == list(CLASSICAL_SPECS)


def test_tabs_keep_separate_input_and_output():
    vm = CipherVM()

    vm.encodingAlgorithm = "Base64"
    vm.encodingInput = "encoding"
    vm.processEncoding()

    vm.cipherAlgorithm = "Caesar"
    vm.shift = 1
    vm.cipherInput = "cipher"
    vm.processCipher()

    vm.hashAlgorithm = "SHA256"
    vm.hashTextInput = "hash"
    vm.processHash()

    assert vm.encodingInput == "encoding"
    assert vm.encodingOutput == "ZW5jb2Rpbmc="
    assert vm.cipherInput == "cipher"
    assert vm.cipherOutput
    assert vm.hashTextInput == "hash"
    assert vm.hashTextOutput == hashlib.sha256(b"hash").hexdigest()
    assert vm.encryptionInput == ""
    assert vm.encryptionOutput == ""


def test_swap_and_clear_are_per_tab():
    vm = CipherVM()
    vm.encodingInput = "one"
    vm.encodingOutput = "two"
    vm.cipherInput = "three"
    vm.cipherOutput = "four"

    vm.swapEncoding()
    assert vm.encodingInput == "two"
    assert vm.encodingOutput == "one"
    assert vm.cipherInput == "three"
    assert vm.cipherOutput == "four"

    vm.clearEncoding()
    assert vm.encodingInput == ""
    assert vm.encodingOutput == ""
    assert vm.cipherInput == "three"
    assert vm.cipherOutput == "four"


def test_encoding_requires_reversible_output():
    vm = CipherVM()
    vm.encodingAlgorithm = "Base64"
    vm.encodingInput = "hello"
    vm.processEncoding()
    assert vm.encodingOutput == "aGVsbG8="

    vm.mode = "decode"
    vm.encodingInput = vm.encodingOutput
    vm.processEncoding()
    assert vm.encodingOutput == "hello"


@pytest.mark.parametrize("name", list(ENCODING_SPECS))
def test_every_encoding_round_trips(name):
    text = ENCODING_SAMPLES.get(name, "Hello, World! 123")
    vm = CipherVM()
    vm.encodingAlgorithm = name

    vm.mode = "encode"
    vm.encodingInput = text
    vm.processEncoding()
    assert vm.error == ""
    encoded = vm.encodingOutput

    vm.mode = "decode"
    vm.encodingInput = encoded
    vm.processEncoding()
    assert vm.error == ""
    assert vm.encodingOutput == text


@pytest.mark.parametrize("name", list(CLASSICAL_SPECS))
def test_every_classical_cipher_round_trips(name):
    text = CLASSICAL_SAMPLES.get(name, "Attack at dawn!")
    vm = CipherVM()
    vm.cipherAlgorithm = name
    apply_settings(vm, name)

    vm.mode = "encode"
    vm.cipherInput = text
    vm.processCipher()
    assert vm.error == ""
    encoded = vm.cipherOutput

    vm.mode = "decode"
    vm.cipherInput = encoded
    vm.processCipher()
    assert vm.error == ""
    assert vm.cipherOutput == text


def test_xor_round_trips_unicode():
    vm = CipherVM()
    vm.cipherAlgorithm = "XOR"
    vm.key = "secret"
    vm.cipherInput = "héllo 世界"

    vm.processCipher()
    assert vm.error == ""
    encoded = vm.cipherOutput

    vm.mode = "decode"
    vm.cipherInput = encoded
    vm.processCipher()
    assert vm.error == ""
    assert vm.cipherOutput == "héllo 世界"


def test_classical_cipher_uses_key_and_mode():
    vm = CipherVM()
    vm.cipherAlgorithm = "Vigenere"
    vm.key = "LEMON"
    vm.cipherInput = "attackatdawn"
    vm.processCipher()
    assert vm.cipherOutput == "lxfopvefrnhr"

    vm.mode = "decode"
    vm.cipherInput = vm.cipherOutput
    vm.processCipher()
    assert vm.cipherOutput == "attackatdawn"


def test_missing_required_key_reports_error():
    vm = CipherVM()
    vm.cipherAlgorithm = "Vigenere"
    vm.key = ""
    vm.cipherInput = "attackatdawn"
    vm.processCipher()
    assert vm.error == "Enter a key for this cipher"
    assert vm.cipherOutput == ""


def test_cipher_settings_track_the_selected_algorithm():
    vm = CipherVM()

    vm.cipherAlgorithm = "Vigenere"
    assert vm.usesKey
    assert vm.keyHint
    assert not vm.usesShift
    assert not vm.usesRails
    assert not vm.usesTurns
    assert not vm.usesPeriod

    vm.cipherAlgorithm = "Caesar"
    assert not vm.usesKey
    assert vm.usesShift

    vm.cipherAlgorithm = "Rail Fence"
    assert vm.usesRails

    vm.cipherAlgorithm = "Scytale"
    assert vm.usesTurns

    vm.cipherAlgorithm = "Bifid"
    assert vm.usesPeriod


def test_shift_setting_changes_caesar_output():
    vm = CipherVM()
    vm.cipherAlgorithm = "Caesar"
    vm.cipherInput = "abc"

    vm.shift = 1
    vm.processCipher()
    assert vm.cipherOutput == "bcd"

    vm.shift = 5
    vm.processCipher()
    assert vm.cipherOutput == "fgh"


def test_detect_suggests_base64():
    vm = CipherVM()
    vm.encodingInput = "aGVsbG8="
    vm.detect()
    assert vm.status == "Detected"
    assert "Base64" in [item["name"] for item in vm.detections]
    assert "Base64" in vm.encodingOutput


def test_hash_uses_selected_algorithm():
    vm = CipherVM()
    vm.hashAlgorithm = "SHA256"
    vm.hashTextInput = "abc"
    vm.processHash()
    assert vm.hashTextOutput == hashlib.sha256(b"abc").hexdigest()


@pytest.mark.parametrize("algorithm", CipherVM.ENCRYPTION_ALGORITHMS)
def test_encryption_round_trip(algorithm, monkeypatch):
    monkeypatch.setattr(CipherVM, "KDF_ITERATIONS", 1_000)
    vm = CipherVM()
    vm.encryptionAlgorithm = algorithm
    vm.passphrase = "correct horse battery staple"
    vm.encryptionInput = "secret message"
    vm.encrypt()
    assert vm.error == ""
    assert vm.encryptionOutput
    assert vm.encryptionOutput != vm.encryptionInput

    encrypted = vm.encryptionOutput
    vm.encryptionInput = encrypted
    vm.decrypt()
    assert vm.error == ""
    assert vm.encryptionOutput == "secret message"


def test_encryption_requires_passphrase():
    vm = CipherVM()
    vm.encryptionInput = "secret message"
    vm.encrypt()
    assert vm.error == "Enter a passphrase"
    assert vm.encryptionOutput == ""


def test_decryption_rejects_wrong_passphrase(monkeypatch):
    monkeypatch.setattr(CipherVM, "KDF_ITERATIONS", 1_000)
    vm = CipherVM()
    vm.passphrase = "right"
    vm.encryptionInput = "secret message"
    vm.encrypt()
    encrypted = vm.encryptionOutput

    vm.passphrase = "wrong"
    vm.encryptionInput = encrypted
    vm.decrypt()
    assert vm.error
    assert vm.encryptionOutput != "secret message"
