import shutil

import pytest

from eazlet.backend.latex_math import LatexParseError
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
    _prepare_math_input,
    _render_latex_png,
    _simplify_expression,
    _solve_equation,
    _validate_equation,
    _validate_expression,
    _validate_variable,
)

LATEX_AVAILABLE = bool(shutil.which("latex") and shutil.which("dvipng"))


def test_simplify_cancels_common_factor():
    original, simplified = _simplify_expression(r"\frac{x^2 - 1}{x - 1}")
    assert original == r"\frac{x^2 - 1}{x - 1}"
    assert simplified == "x + 1"


def test_simplify_trigonometric_identity():
    assert _simplify_expression(r"\sin(x)^2 + \cos(x)^2")[1] == "1"


def test_simplify_implicit_multiplication():
    assert _simplify_expression("2x + 3x")[1] == "5 x"


def test_simplify_power_notation():
    assert _simplify_expression("2^{10}")[1] == "1024"


def test_simplify_combines_fractions():
    assert _simplify_expression(r"\frac{1}{x} + \frac{1}{y}")[1] == r"\frac{x + y}{x y}"


def test_simplify_factors_rational_result():
    original = (
        r"\frac{x^2-5x+6}{x^2-9}\times\frac{x^2+6x+9}{x^2-4x+4}"
        r"\div\frac{x^2-4}{x^2-3x}"
    )
    assert _simplify_expression(original)[1] == (
        r"\frac{x \left(x - 3\right) \left(x + 3\right)}"
        r"{\left(x - 2\right)^{2} \left(x + 2\right)}"
    )


def test_simplify_greek_letters():
    assert _simplify_expression(r"2\alpha + \alpha")[1] == r"3 \alpha"


def test_simplify_rejects_plain_function_names():
    with pytest.raises(LatexParseError, match="Unknown name"):
        _simplify_expression("sin(x)")


def test_simplify_binds_bare_function_argument():
    assert _simplify_expression(r"\sin 2x")[1] == r"\sin{\left(2 x \right)}"


def test_simplify_keeps_adjacent_functions_separate():
    assert _simplify_expression(r"\sin x \cos x")[1] == (
        r"\frac{\sin{\left(2 x \right)}}{2}"
    )


def test_simplify_supports_the_gamma_function():
    assert _simplify_expression(r"\Gamma(x)")[1] == r"\Gamma\left(x\right)"


def test_simplify_rejects_derivative_notation():
    with pytest.raises(LatexParseError, match="Derivative notation"):
        _simplify_expression(r"\frac{d}{dx} x^2")


def test_simplify_rejects_unsafe_input():
    with pytest.raises(ValueError):
        _simplify_expression(r"\input{secret}")
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


def test_parse_expression_handles_keyword_symbol_names():
    sympy = pytest.importorskip("sympy")
    parsed = _parse_expression(sympy, "lambda + 1")
    assert str(parsed) == "lambda + 1"


def test_vm_reports_validation_errors_without_starting_worker():
    vm = MathVM()
    vm.setExpression("x = 2")
    vm.process()
    assert vm.computing is False
    assert "not an equation" in vm.error
    assert vm.status == "Error"


def test_vm_clear():
    vm = MathVM()
    vm.setExpression("x^2")
    vm.clear()
    assert vm.expression == ""
    assert vm.result == ""
    assert vm.error == ""
    assert vm.status == "Ready"


def test_vm_simplifies_in_worker(qtbot):
    vm = MathVM()
    vm.setExpression(r"\frac{x^2 - 1}{x - 1}")
    vm.process()
    with qtbot.waitSignal(vm.resultChanged, timeout=15000):
        pass
    assert vm.error == ""
    assert vm.status == "Simplified"
    assert "Simplified: x + 1" in vm.result


def test_expand_expression():
    assert _expand_expression(r"(x + 1)^{3}")[1] == "x^{3} + 3 x^{2} + 3 x + 1"


def test_factor_expression():
    assert _factor_expression(r"x^{2} - 1")[1] == r"\left(x - 1\right) \left(x + 1\right)"


def test_solve_equation_returns_sorted_solutions():
    assert _solve_equation(r"x^2 - 4 = 0", "x")[1] == "-2, 2"


def test_solve_equation_uses_requested_variable():
    assert _solve_equation(r"a + b = 2", "a")[1] == "2 - b"


def test_solve_equation_with_complex_solutions():
    assert _solve_equation(r"x^2 + 1 = 0", "x")[1] == "- i, i"


def test_differentiate_expression():
    assert _differentiate_expression(r"\sin(x)", "x")[1] == r"\cos{\left(x \right)}"


def test_differentiate_inverse_sine_notation():
    # \sin^{-1} x is arcsin x, not 1/sin x.
    assert _differentiate_expression(r"\sin^{-1}(x)", "x")[1] == (
        r"\frac{1}{\sqrt{1 - x^{2}}}"
    )


def test_integrate_expression_adds_constant():
    assert _integrate_expression(r"\int x \, dx", "x")[1] == r"\frac{x^{2}}{2} + C"


def test_integrate_expression_uses_ui_variable_without_differential():
    assert _integrate_expression(r"t^2", "t")[1] == r"\frac{t^{3}}{3} + C"


def test_integrate_definite_expression():
    exact = _integrate_expression(r"\int_{0}^{2} x^{2} \, dx", "x")[1]
    assert exact == r"\frac{8}{3} \approx 2.66666666667"


def test_integrate_definite_expression_matches_user_example():
    exact = _integrate_expression(r"\int_{0}^{3} x^3 e^{-2x} \, dx", "x")[1]
    assert exact == (
        r"\frac{3}{8} - \frac{183}{8 e^{6}} \approx 0.318298543959"
    )


def test_integrate_requires_both_bounds():
    with pytest.raises(LatexParseError, match="both a lower and an upper bound"):
        _integrate_expression(r"\int_0 x^2 \, dx", "x")


def test_limit_expression():
    assert _limit_expression(r"\frac{\sin(x)}{x}", "x", "0")[1] == "1"
    assert _limit_expression(r"\frac{1}{x}", "x", r"\infty")[1] == "0"


def test_two_sided_limit_does_not_exist():
    result = _limit_expression(r"\frac{1}{x}", "x", "0")[1]
    assert result.startswith(r"\text{Does not exist}")
    assert r"\lim_{x \to 0^-} = -\infty" in result
    assert r"\lim_{x \to 0^+} = \infty" in result


def test_two_sided_limit_agrees_for_even_pole():
    assert _limit_expression(r"\frac{1}{x^2}", "x", "0")[1] == r"\infty"


def test_two_sided_limit_agrees_at_removable_singularity():
    assert _limit_expression(r"\frac{\sin(x)}{x}", "x", "0")[1] == "1"


def test_compute_math_rejects_unknown_mode():
    with pytest.raises(ValueError, match="Unsupported math tool"):
        _compute_math("Unknown", "x", "x", "0")


def test_prepare_math_input_accepts_latex():
    _prepare_math_input("Simplify", r"\frac{x^2 - 1}{x - 1}", "x", "0")
    _prepare_math_input("Solve", r"x^2 - 4 = 0", "x", "0")
    _prepare_math_input("Integral", r"\int_0^1 x^2 \, dx", "x", "0")
    _prepare_math_input("Limit", r"\frac{\sin(x)}{x}", r"\theta", r"\pi/2")


def test_prepare_math_input_rejects_plain_function_names():
    with pytest.raises(LatexParseError, match="Unknown name"):
        _prepare_math_input("Simplify", "sin(x)", "x", "0")


def test_validate_equation():
    assert _validate_equation("  x^2 - 4 = 0  ") == "x^2 - 4 = 0"


def test_validate_equation_rejects_multiple_equals():
    with pytest.raises(ValueError, match="exactly one '='"):
        _validate_equation("x = y = 2")


def test_validate_equation_rejects_empty_side():
    with pytest.raises(ValueError, match="both sides"):
        _validate_equation("= 2")


def test_validate_equation_rejects_empty_input():
    with pytest.raises(ValueError, match="Enter an equation"):
        _validate_equation("   ")


def test_validate_variable():
    assert _validate_variable("") == "x"
    assert _validate_variable(" alpha ") == "alpha"
    with pytest.raises(ValueError, match="Enter a variable name"):
        _validate_variable("2x")
    with pytest.raises(ValueError, match="reserved word"):
        _validate_variable("import")


def test_vm_switches_math_tools(qtbot):
    vm = MathVM()
    assert vm.mode == "Simplify"
    assert vm.inputLabel == "LaTeX"
    assert vm.requiresVariable is False

    vm.setMode("Solve")
    assert vm.actionLabel == "Solve"
    assert vm.inputLabel == "LaTeX"
    assert vm.requiresVariable is True
    assert vm.requiresPoint is False

    vm.setMode("Limit")
    assert vm.actionLabel == "Evaluate"
    assert vm.requiresPoint is True

    vm.setMode("Solve")
    vm.setExpression(r"x = 2")
    vm.process()
    with qtbot.waitSignal(vm.resultChanged, timeout=15000):
        pass
    assert vm.error == ""
    assert vm.status == "Solved"
    assert "Solutions: 2" in vm.result


def test_vm_accepts_greek_variable(qtbot):
    vm = MathVM()
    vm.setMode("Derivative")
    vm.setExpression(r"\theta^2")
    vm.setVariable(r"\theta")
    vm.process()
    with qtbot.waitSignal(vm.resultChanged, timeout=15000):
        pass
    assert vm.error == ""
    assert "Derivative: 2 \\theta" in vm.result


def test_vm_rejects_invalid_variable_before_worker():
    vm = MathVM()
    vm.setMode("Derivative")
    vm.setExpression("x^2")
    vm.setVariable("2x")
    vm.process()
    assert vm.computing is False
    assert "single variable" in vm.error
    assert vm.status == "Error"


def test_normalize_latex_strips_delimiters():
    assert _normalize_latex_source("  $x^2$  ") == "x^2"
    assert _normalize_latex_source("$$x^2$$") == "x^2"
    assert _normalize_latex_source(r"\[x^2\]") == "x^2"
    assert _normalize_latex_source(r"\(x^2\)") == "x^2"


def test_normalize_latex_allows_math_commands_and_matrices():
    source = r"\frac{\sqrt{x}}{2} + \begin{pmatrix} a & b \\ c & d \end{pmatrix}"
    assert _normalize_latex_source(source) == source


def test_normalize_latex_rejects_empty_source():
    with pytest.raises(ValueError, match="Enter LaTeX code"):
        _normalize_latex_source("   ")


def test_normalize_latex_rejects_long_source():
    with pytest.raises(ValueError, match="too long"):
        _normalize_latex_source("x" * 4001)


def test_normalize_latex_rejects_comments():
    with pytest.raises(ValueError, match="comments"):
        _normalize_latex_source("x % comment")


@pytest.mark.parametrize(
    "source",
    [
        r"\input{/etc/passwd}",
        r"\include{secret}",
        r"\includegraphics{secret.png}",
        r"\openin1=secret",
        r"\openout1=secret",
        r"\write18{rm -rf /}",
        r"\read1 to \x",
        r"\def\x{y}",
        r"\newcommand{\x}{y}",
        r"\usepackage{shellesc}",
        r"\catcode`\@=11",
        r"\csname input\endcsname{secret}",
        r"\begin{document}x\end{document}",
        r"\begin{matrix} x \end{pmatrix}",
        r"\begin{matrix} x",
    ],
)
def test_normalize_latex_rejects_unsafe_source(source):
    with pytest.raises(ValueError):
        _normalize_latex_source(source)


def test_normalize_latex_rejects_control_characters():
    with pytest.raises(ValueError, match="control characters"):
        _normalize_latex_source("x\x01")


def test_dvipng_color_conversion():
    assert _dvipng_color("#FF0000", "#FFFFFF", allow_transparent=True) == (
        "rgb 1.0000 0.0000 0.0000"
    )
    assert _dvipng_color("#fff", "#000000", allow_transparent=True) == (
        "rgb 1.0000 1.0000 1.0000"
    )
    assert _dvipng_color("#80FF0000", "#FFFFFF", allow_transparent=True) == (
        "rgb 1.0000 0.0000 0.0000"
    )
    assert _dvipng_color("Transparent", "#FFFFFF", allow_transparent=True) == "Transparent"


def test_dvipng_color_rejects_invalid_values():
    with pytest.raises(ValueError, match="#RRGGBB"):
        _dvipng_color("red", "#FFFFFF", allow_transparent=True)
    with pytest.raises(ValueError, match="visible text colour"):
        _dvipng_color("Transparent", "#000000", allow_transparent=False)


@pytest.mark.skipif(not LATEX_AVAILABLE, reason="latex and dvipng are required")
def test_render_latex_png_uses_resolution():
    small_png, small_width, small_height = _render_latex_png(r"\frac{1}{2}", 150)
    large_png, large_width, large_height = _render_latex_png(r"\frac{1}{2}", 300)
    assert small_png.startswith(b"\x89PNG\r\n\x1a\n")
    assert large_png.startswith(b"\x89PNG\r\n\x1a\n")
    assert small_width > 0 and small_height > 0
    assert large_width > small_width
    assert large_height > small_height


@pytest.mark.skipif(not LATEX_AVAILABLE, reason="latex and dvipng are required")
def test_render_latex_reports_compile_errors():
    with pytest.raises(RuntimeError, match="LaTeX error"):
        _render_latex_png(r"\frac{1}", 150)


@pytest.mark.skipif(not LATEX_AVAILABLE, reason="latex and dvipng are required")
def test_vm_renders_and_saves_latex(qtbot, tmp_path):
    vm = MathVM()
    assert vm.latexAvailable is True
    vm.setMode("LaTeX → PNG")
    vm.setLatexSource(r"\frac{x^2 - 1}{x - 1} = x + 1")
    vm.setLatexResolution(150)
    vm.renderLatex()
    qtbot.waitUntil(
        lambda: not vm.latexRendering and vm.latexStatus == "Rendered",
        timeout=30000,
    )
    assert vm.latexError == ""
    assert vm.latexImageSource.startswith("data:image/png;base64,")
    assert vm.latexDimensions.endswith("px")

    target = tmp_path / "formula"
    vm.saveLatex(str(target))
    saved = tmp_path / "formula.png"
    assert saved.exists()
    assert saved.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
    assert vm.latexSavedMessage.startswith("Saved")
    assert "formula.png" in vm.latexSavedMessage


def test_latex_resolutions_include_a_large_option():
    vm = MathVM()
    assert vm.latexResolutions[-1] == 900
    vm.setLatexResolution(900)
    assert vm.latexResolution == 900


def test_vm_clear_latex_tool():
    vm = MathVM()
    vm.setMode("LaTeX → PNG")
    vm.setLatexSource("x")
    vm.clear()
    assert vm.latexSource == ""
    assert vm.latexImageSource == ""
    assert vm.latexError == ""
    assert vm.latexStatus == "Ready"
