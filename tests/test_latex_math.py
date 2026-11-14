import pytest

from eazlet.backend.latex_math import (
    LatexParseError,
    parse_latex_equation,
    parse_latex_expression,
    parse_latex_integral,
    parse_latex_variable,
)


def test_parse_fraction_and_grouping():
    assert parse_latex_expression(r"\frac{a}{b}") == "((a)/(b))"
    assert parse_latex_expression(r"\dfrac{x + 1}{x - 1}") == "(((x + 1))/((x - 1)))"


def test_parse_roots():
    assert parse_latex_expression(r"\sqrt{x}") == "sqrt(x)"
    assert parse_latex_expression(r"\sqrt[3]{x}") == "((x)^(1/(3)))"
    assert parse_latex_expression(r"\sqrt[n]{x}") == "((x)^(1/(n)))"


def test_parse_powers():
    assert parse_latex_expression(r"x^{2}") == "(x)^(2)"
    assert parse_latex_expression(r"x^2") == "(x)^(2)"
    assert parse_latex_expression(r"e^{x}") == "(E)^(x)"


def test_parse_implicit_multiplication():
    assert parse_latex_expression("2x") == "(2 * x)"
    assert parse_latex_expression("xy") == "(x * y)"
    assert parse_latex_expression("(x + 1)(x - 1)") == "((x + 1) * (x - 1))"


def test_parse_explicit_multiplication_commands():
    assert parse_latex_expression(r"3 \cdot x") == "(3 * x)"
    assert parse_latex_expression(r"3 \times x") == "(3 * x)"
    assert parse_latex_expression(r"\frac{6}{2} \div 3") == "(((6)/(2)) / 3)"


def test_parse_functions():
    assert parse_latex_expression(r"\sin(x)") == "sin(x)"
    assert parse_latex_expression(r"\cos x") == "cos(x)"
    assert parse_latex_expression(r"\ln(x)") == "log(x)"
    assert parse_latex_expression(r"\log(x)") == "log(x)"
    assert parse_latex_expression(r"\exp(x)") == "exp(x)"


def test_parse_function_powers():
    assert parse_latex_expression(r"\sin^2 x") == "(sin(x))^(2)"
    assert parse_latex_expression(r"\sin(x)^2") == "(sin(x))^(2)"
    assert parse_latex_expression(r"\sin x^2") == "sin((x)^(2))"


def test_parse_bare_function_argument_binds_juxtaposed_factors():
    assert parse_latex_expression(r"\sin 2x") == "sin((2 * x))"
    assert parse_latex_expression(r"\cos 2\theta") == "cos((2 * theta))"
    assert parse_latex_expression(r"\sin 2(x + 1)") == "sin((2 * (x + 1)))"
    assert parse_latex_expression(r"\sin \frac{x}{2}") == "sin(((x)/(2)))"


def test_parse_bare_function_argument_stops_at_next_function():
    assert parse_latex_expression(r"\sin x \cos x") == "(sin(x) * cos(x))"
    assert parse_latex_expression(r"\sin 2x \cos 3x") == "(sin((2 * x)) * cos((3 * x)))"


def test_parse_gamma_function():
    assert parse_latex_expression(r"\Gamma(x)") == "gamma(x)"
    assert parse_latex_expression(r"\Gamma(n + 1)") == "gamma((n + 1))"


def test_gamma_without_argument_is_rejected():
    with pytest.raises(LatexParseError, match="needs an argument"):
        parse_latex_expression(r"\Gamma")


@pytest.mark.parametrize(
    "source",
    [
        r"\frac{d}{dx} x^2",
        r"\frac{df}{dx}",
        r"\frac{d}{d\theta} \theta^2",
        r"\frac{d f}{d x}",
        r"\frac{d\,f}{d\,x}",
        r"\frac{\mathrm{d}}{\mathrm{d}x} x^2",
    ],
)
def test_rejects_derivative_notation(source):
    with pytest.raises(LatexParseError, match="Derivative notation"):
        parse_latex_expression(source)


def test_ordinary_fractions_are_not_mistaken_for_derivatives():
    assert parse_latex_expression(r"\frac{d}{2}") == "((d)/(2))"
    assert parse_latex_expression(r"\frac{1}{dx}") == "((1)/((d * x)))"


def test_parse_constants_and_greek_letters():
    assert parse_latex_expression(r"\pi") == "pi"
    assert parse_latex_expression(r"\infty") == "oo"
    assert parse_latex_expression("i") == "I"
    assert parse_latex_expression("e^{x}") == "(E)^(x)"
    assert parse_latex_expression(r"\alpha + \beta") == "(alpha + beta)"
    assert parse_latex_expression(r"\lambda + 1") == "(lambda + 1)"


@pytest.mark.parametrize("source", ["E", "E^x", "I"])
def test_rejects_uppercase_plain_constants(source):
    with pytest.raises(LatexParseError, match="Use lowercase"):
        parse_latex_expression(source)


def test_parse_absolute_value():
    assert parse_latex_expression("|x|") == "abs(x)"
    assert parse_latex_expression(r"\left|\frac{x}{2}\right|") == "abs(((x)/(2)))"
    assert parse_latex_expression("2|x|") == "(2 * abs(x))"


def test_parse_strips_delimiters():
    for source in (r"$x^2$", r"$$x^2$$", r"\[x^2\]", r"\(x^2\)"):
        assert parse_latex_expression(source) == "(x)^(2)"


def test_parse_equation():
    assert parse_latex_equation(r"x^{2} - 4 = 0") == ("((x)^(2) - 4)", "0")


def test_parse_equation_requires_exactly_one_equals():
    with pytest.raises(LatexParseError, match="exactly one"):
        parse_latex_equation(r"x = y = 2")
    with pytest.raises(LatexParseError, match="both sides"):
        parse_latex_equation(r"= 2")


def test_parse_expression_rejects_equation():
    with pytest.raises(LatexParseError, match="not an equation"):
        parse_latex_expression(r"x = 2")


def test_parse_integral_with_bounds():
    parsed = parse_latex_integral(r"\int_{0}^{3} x^{3} e^{-2x} \, dx")
    assert parsed is not None
    assert parsed.variable == "x"
    assert parsed.lower == "0"
    assert parsed.upper == "3"
    assert parsed.integrand == "((x)^(3) * (E)^(((-2) * x)))"


def test_parse_integral_without_bounds():
    parsed = parse_latex_integral(r"\int x\sin(x) dx")
    assert parsed is not None
    assert parsed.variable == "x"
    assert parsed.lower is None
    assert parsed.upper is None
    assert parsed.integrand == "(x * sin(x))"


def test_parse_integral_uses_fallback_variable():
    parsed = parse_latex_integral(r"\int x^2")
    assert parsed is not None
    assert parsed.variable is None


def test_parse_integral_with_greek_differential():
    parsed = parse_latex_integral(r"\int_0^1 \theta \, d\theta")
    assert parsed is not None
    assert parsed.variable == "theta"


def test_parse_integral_requires_both_bounds():
    with pytest.raises(LatexParseError, match="both a lower and an upper bound"):
        parse_latex_integral(r"\int_0 x^2 \, dx")


def test_parse_integral_returns_none_for_plain_expression():
    assert parse_latex_integral(r"x^2") is None


def test_parse_variable():
    assert parse_latex_variable("") == "x"
    assert parse_latex_variable(" x ") == "x"
    assert parse_latex_variable(r"\theta") == "theta"
    assert parse_latex_variable(r"\lambda") == "lambda"
    with pytest.raises(LatexParseError, match="single variable"):
        parse_latex_variable("2x")


@pytest.mark.parametrize("source", ["sin(x)", "pi", "alpha", "2sin(x)", r"\frac{cos(x)}{2}"])
def test_plain_function_and_constant_names_are_rejected(source):
    with pytest.raises(LatexParseError, match="Unknown name"):
        parse_latex_expression(source)


def test_bare_multi_letter_variables_are_split():
    assert parse_latex_expression("abc") == "((a * b) * c)"


def test_rejects_unknown_commands():
    with pytest.raises(LatexParseError, match="Unsupported LaTeX command"):
        parse_latex_expression(r"\foo{x}")


@pytest.mark.parametrize(
    "source",
    [
        r"\input{/etc/passwd}",
        r"\write18{rm -rf /}",
        r"\begin{matrix} x \end{matrix}",
        r"\text{hello}",
        r"\sum_{i=0}^{n} x^i",
        r"\lim_{x \to 0} \frac{\sin(x)}{x}",
        r"\partial x",
    ],
)
def test_rejects_unsafe_or_unsupported_commands(source):
    with pytest.raises(LatexParseError):
        parse_latex_expression(source)


def test_rejects_comments_and_control_characters():
    with pytest.raises(LatexParseError, match="comments"):
        parse_latex_expression("x % comment")
    with pytest.raises(LatexParseError, match="control characters"):
        parse_latex_expression("x\x01")


def test_rejects_empty_and_long_input():
    with pytest.raises(LatexParseError, match="Enter a LaTeX expression"):
        parse_latex_expression("   ")
    with pytest.raises(LatexParseError, match="too long"):
        parse_latex_expression("x" * 501)
