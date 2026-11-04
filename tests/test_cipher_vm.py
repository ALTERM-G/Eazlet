import hashlib

import pytest

from eazlet.backend.viewmodels.cipher_vm import CipherVM


def test_cipher_categories_partition_algorithms():
    categorized = CipherVM.ENCODINGS + CipherVM.CLASSICAL_CIPHERS + CipherVM.HASH_ALGORITHMS
    assert categorized == CipherVM.CIPHERS
    assert len(categorized) == len(set(categorized))


def test_encoding_requires_reversible_output():
    vm = CipherVM()
    vm.encodingAlgorithm = "Base64"
    vm.input = "hello"
    vm.processEncoding()
    assert vm.output == "aGVsbG8="

    vm.mode = "decode"
    vm.input = vm.output
    vm.processEncoding()
    assert vm.output == "hello"


def test_classical_cipher_uses_key_and_mode():
    vm = CipherVM()
    vm.cipherAlgorithm = "Vigenere"
    vm.key = "LEMON"
    vm.input = "attackatdawn"
    vm.processCipher()
    assert vm.output == "lxfopvefrnhr"

    vm.mode = "decode"
    vm.input = vm.output
    vm.processCipher()
    assert vm.output == "attackatdawn"


def test_hash_uses_selected_algorithm():
    vm = CipherVM()
    vm.hashAlgorithm = "SHA256"
    vm.input = "abc"
    vm.hashInput()
    assert vm.output == hashlib.sha256(b"abc").hexdigest()


@pytest.mark.parametrize("algorithm", CipherVM.ENCRYPTION_ALGORITHMS)
def test_encryption_round_trip(algorithm, monkeypatch):
    monkeypatch.setattr(CipherVM, "KDF_ITERATIONS", 1_000)
    vm = CipherVM()
    vm.encryptionAlgorithm = algorithm
    vm.passphrase = "correct horse battery staple"
    vm.input = "secret message"
    vm.encrypt()
    assert vm.error == ""
    assert vm.output
    assert vm.output != vm.input

    encrypted = vm.output
    vm.input = encrypted
    vm.decrypt()
    assert vm.error == ""
    assert vm.output == "secret message"


def test_encryption_requires_passphrase():
    vm = CipherVM()
    vm.input = "secret message"
    vm.encrypt()
    assert vm.error == "Enter a passphrase"
    assert vm.output == ""


def test_decryption_rejects_wrong_passphrase(monkeypatch):
    monkeypatch.setattr(CipherVM, "KDF_ITERATIONS", 1_000)
    vm = CipherVM()
    vm.passphrase = "right"
    vm.input = "secret message"
    vm.encrypt()
    encrypted = vm.output

    vm.passphrase = "wrong"
    vm.input = encrypted
    vm.decrypt()
    assert vm.error
    assert vm.output != "secret message"
