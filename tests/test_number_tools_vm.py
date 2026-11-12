import pytest

from eazlet.backend.viewmodels.number_tools_vm import (
    _apply_bitwise,
    _bezout,
    _divisors_from_factors_py,
    _fmt_base,
    _format_binary,
    _gcd,
    _lcm,
    _parse_bitwise_width,
    _prime_factors_py,
    _signed_from_width,
)


def test_base_formatting_has_no_prefixes():
    assert _fmt_base(255, 2) == "11111111"
    assert _fmt_base(255, 8) == "377"
    assert _fmt_base(255, 16) == "FF"
    assert _fmt_base(255, 43) == "5e"
    assert _fmt_base(100, 100) == "(1 0)_100"


def test_gcd_lcm_and_bezout():
    assert _gcd(48, 18) == 6
    assert _lcm(12, 18) == 36
    assert _lcm(0, 42) == 0
    g, s, t = _bezout(48, 18)
    assert g == 6
    assert 48 * s + 18 * t == g


def test_prime_factorization_and_divisors():
    pf = _prime_factors_py(360)
    assert pf == [(2, 3), (3, 2), (5, 1)]
    divs = _divisors_from_factors_py(pf)
    assert len(divs) == 24
    assert divs[0] == 1
    assert divs[-1] == 360
    assert all(360 % d == 0 for d in divs)


def test_python_fallback_factors_large_semiprime():
    n = 1000003 * 1000033
    assert _prime_factors_py(n) == [(1000003, 1), (1000033, 1)]


def test_python_fallback_handles_bigint():
    n = 2**64 + 13
    pf = _prime_factors_py(n)
    product = 1
    for p, e in pf:
        product *= p**e
    assert product == n


def test_parse_bitwise_width():
    assert _parse_bitwise_width("8-bit") == 8
    assert _parse_bitwise_width("16") == 16
    assert _parse_bitwise_width("64-bit") == 64
    with pytest.raises(ValueError):
        _parse_bitwise_width("12-bit")
    with pytest.raises(ValueError):
        _parse_bitwise_width("wide")


def test_bitwise_logical_ops():
    assert _apply_bitwise("AND", 0b1100, 0b1010, 8) == 0b1000
    assert _apply_bitwise("OR", 0b1100, 0b1010, 8) == 0b1110
    assert _apply_bitwise("XOR", 0b1100, 0b1010, 8) == 0b0110
    assert _apply_bitwise("NOT", 0b1010, 0, 8) == 0xF5


def test_bitwise_shifts_and_rotates():
    assert _apply_bitwise("Shift left", 1, 3, 8) == 8
    assert _apply_bitwise("Shift right", 16, 2, 8) == 4
    # Shifting past the width yields zero rather than growing the number.
    assert _apply_bitwise("Shift left", 1, 9, 8) == 0
    assert _apply_bitwise("Rotate left", 0b10000001, 1, 8) == 0b00000011
    assert _apply_bitwise("Rotate right", 0b00000011, 1, 8) == 0b10000001
    assert _apply_bitwise("Rotate left", 5, 8, 8) == 5


def test_bitwise_masks_to_width():
    assert _apply_bitwise("AND", 0x1FF, 0x1FF, 8) == 0xFF
    assert _apply_bitwise("NOT", 0, 0, 16) == 0xFFFF
    assert _apply_bitwise("NOT", 0, 0, 32) == 0xFFFFFFFF
    assert _apply_bitwise("NOT", 0, 0, 64) == 0xFFFFFFFFFFFFFFFF


def test_bitwise_rejects_negative_inputs():
    with pytest.raises(ValueError):
        _apply_bitwise("AND", -1, 5, 8)
    with pytest.raises(ValueError):
        _apply_bitwise("OR", 5, -1, 8)


def test_signed_conversion_and_binary_grouping():
    assert _signed_from_width(0xFF, 8) == -1
    assert _signed_from_width(0x7F, 8) == 127
    assert _signed_from_width(0xFFFF, 16) == -1
    assert _format_binary(0b1010, 8) == "0000 1010"
    assert _format_binary(0xFFFF, 16) == "1111 1111 1111 1111"
