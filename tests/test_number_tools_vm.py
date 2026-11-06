from eazlet.backend.viewmodels.number_tools_vm import (
    _bezout,
    _divisors_from_factors_py,
    _fmt_base,
    _gcd,
    _lcm,
    _prime_factors_py,
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
