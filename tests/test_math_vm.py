import shutil

import pytest

from eazlet.backend.viewmodels.math_vm import (
    MathVM,
    _compute_math,
    _differentiate_expression,
    _dvipng_color,
    _expand_expression,
    _factor_expression,
    _integrate_expression,
    _limit_expression,
    _normalize_latex_source,
    _parse_expression,
    _render_latex_png,
    _simplify_expression,
    _solve_equation,
    _validate_equation,
    _validate_expression,
    _validate_variable,
)

LATEX_AVAILABLE = bool(shutil.which("latex") and shutil.which("dvipng"))


def test_simplify_cancels_common_factor():
    original, simplified = _simplify_expression("(x^2 - 1)/(x - 1)")
    assert original == "(x^2 - 1)/(x - 1)"
    assert simplified == "x + 1"


def test_simplify_trigonometric_identity():
    assert _simplify_expression("sin(x)^2 + cos(x)^2")[1] == "1"


def test_simplify_implicit_multiplication():
    assert _simplify_expression("2x + 3x")[1] == "5*x"


def test_simplify_power_notation():
    assert _simplify_expression("2^10")[1] == "1024"


def test_simplify_combines_fractions():
    assert _simplify_expression("1/x + 1/y")[1] == "(x + y)/(x*y)"


def test_simplify_keeps_unknown_names_as_symbols():
    _, simplified = _simplify_expression("2 alpha + alpha")
    assert simplified == "3*alpha"


def test_parse_expression_does_not_expose_builtins():
    with pytest.raises(ValueError):
        _simplify_expression("__import__('os')")
    with pytest.raises(ValueError):
        _simplify_expression("open('secret')")


def test_validate_rejects_empty_expression():
    with pytest.raises(ValueError, match="Enter an expression"):
        _validate_expression("   ")


def test_validate_rejects_equation():
    with pytest.raises(ValueError, match="not an equation"):
        _validate_expression("x = 2")


def test_validate_rejects_unsupported_characters():
    with pytest.raises(ValueError, match="Unsupported character"):
        _validate_expression("x + [1, 2]")
    with pytest.raises(ValueError, match="Unsupported character"):
        _validate_expression("x + 1 # comment")


def test_validate_rejects_attribute_access():
    with pytest.raises(ValueError, match="Unsupported use of '\\.'"):
        _validate_expression("x.y")


def test_validate_rejects_reserved_words():
    with pytest.raises(ValueError, match="reserved word"):
        _validate_expression("import + os")


def test_validate_rejects_long_expression():
    with pytest.raises(ValueError, match="too long"):
        _validate_expression("x" * 501)


def test_parse_expression_returns_symbols():
    sympy = pytest.importorskip("sympy")
    parsed = _parse_expression(sympy, "x + 2")
    assert str(parsed) == "x + 2"


def test_vm_reports_validation_errors_without_starting_worker():
    vm = MathVM()
    vm.setExpression("x = 2")
    vm.process()
    assert vm.computing is False
    assert "not an equation" in vm.error
    assert vm.status == "Error"


def test_vm_clear_and_example():
    vm = MathVM()
    vm.loadExample()
    assert vm.expression == "(x^2 - 1)/(x - 1)"
    vm.clear()
    assert vm.expression == ""
    assert vm.result == ""
    assert vm.error == ""
    assert vm.status == "Ready"


def test_vm_simplifies_in_worker(qtbot):
    vm = MathVM()
    vm.setExpression("(x^2 - 1)/(x - 1)")
    vm.process()
    with qtbot.waitSignal(vm.resultChanged, timeout=15000):
        pass
    assert vm.error == ""
    assert vm.status == "Simplified"
    assert "Simplified: x + 1" in vm.result
