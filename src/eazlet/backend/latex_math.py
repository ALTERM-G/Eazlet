"""Convert the LaTeX subset used by the Math workplace into SymPy syntax.

The Math tools accept LaTeX only. This module turns that LaTeX into the small,
plain expression language that :mod:`sympy.parsing.sympy_parser` already
understands, and it rejects everything it cannot represent with a targeted
error instead of guessing.

The parser is deliberately small: scalar, single-variable algebra and calculus
notation. Matrices, sums, products and text commands are reported as
unsupported rather than being parsed into something surprising.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

MAX_LATEX_MATH_LENGTH = 500

_CONTROL_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")

# Commands that only change typography or spacing. They are dropped before
# parsing; none of them can affect the meaning of an expression.
_SKIP_COMMANDS = frozenset(
    {
        "displaystyle",
        "limits",
        "nolimits",
        "right",
        "scriptstyle",
        "scriptscriptstyle",
        "textstyle",
        "left",
    }
)
_SPACING_COMMANDS = frozenset({"quad", "qquad"})
_SPACING_SYMBOLS = frozenset({",", ";", ":", "!", " "})
_CONTROL_SYMBOLS = {"{": "{", "}": "}", "|": "|"}

_GREEK = {
    "alpha": "alpha",
    "beta": "beta",
    "gamma": "gamma",
    "delta": "delta",
    "epsilon": "epsilon",
    "varepsilon": "varepsilon",
    "zeta": "zeta",
    "eta": "eta",
    "theta": "theta",
    "vartheta": "vartheta",
    "iota": "iota",
    "kappa": "kappa",
    "lambda": "lambda",
    "mu": "mu",
    "nu": "nu",
    "xi": "xi",
    "omicron": "omicron",
    "pi": "pi",
    "varpi": "varpi",
    "rho": "rho",
    "varrho": "varrho",
    "sigma": "sigma",
    "varsigma": "varsigma",
    "tau": "tau",
    "upsilon": "upsilon",
    "phi": "phi",
    "varphi": "varphi",
    "chi": "chi",
    "psi": "psi",
    "omega": "omega",
    "Gamma": "Gamma",
    "Delta": "Delta",
    "Theta": "Theta",
    "Lambda": "Lambda",
    "Xi": "Xi",
    "Pi": "Pi",
    "Sigma": "Sigma",
    "Upsilon": "Upsilon",
    "Phi": "Phi",
    "Psi": "Psi",
    "Omega": "Omega",
}

_CONSTANTS = {"infty": "oo", "pi": "pi"}

_FUNCTIONS = {
    "abs": "abs",
    "acos": "acos",
    "acosh": "acosh",
    "arccos": "acos",
    "arccosh": "acosh",
    "arcsin": "asin",
    "arcsinh": "asinh",
    "arctan": "atan",
    "arctanh": "atanh",
    "asin": "asin",
    "asinh": "asinh",
    "atan": "atan",
    "atanh": "atanh",
    "cbrt": "cbrt",
    "cos": "cos",
    "cosh": "cosh",
    "cot": "cot",
    "coth": "coth",
    "csc": "csc",
    "csch": "csch",
    "exp": "exp",
    # Uppercase Gamma is the gamma function, not a variable named Gamma. It is
    # also listed in _GREEK so it can still name a variable in the variable
    # field, but function parsing wins inside expressions.
    "Gamma": "gamma",
    "ln": "log",
    "log": "log",
    "sec": "sec",
    "sech": "sech",
    "sin": "sin",
    "sinh": "sinh",
    "tan": "tan",
    "tanh": "tanh",
}

# \sin^{-1} is inverse sine in standard notation, not the reciprocal.
# Only the -1 exponent is special-cased; \sin^2 x still means (sin x)^2.
_INVERSE_FUNCTIONS = {
    "sin": "asin",
    "cos": "acos",
    "tan": "atan",
    "cot": "acot",
    "sec": "asec",
    "csc": "acsc",
    "sinh": "asinh",
    "cosh": "acosh",
    "tanh": "atanh",
}

_BARE_NAME_HINTS = (
    set(_FUNCTIONS)
    | set(_CONSTANTS)
    | set(_GREEK)
    | {"inf", "infty", "oo"}
)

_UNSUPPORTED_COMMANDS = {
    "begin": "LaTeX environments (matrices, cases, aligned blocks) are not "
    "supported by the compute tools",
    "binom": "Binomial coefficients are not supported by the compute tools",
    "dfrac": "",
    "end": "LaTeX environments are not supported by the compute tools",
    "frac": "",
    "lim": "Limits are handled by the Limit tool; enter the expression and the point",
    "mathbb": "Text and font commands are not supported",
    "mathbf": "Text and font commands are not supported",
    "mathit": "Text and font commands are not supported",
    "mathrm": "Text and font commands are not supported",
    "operatorname": "Only \\operatorname{abs} is supported",
    "partial": "Partial derivatives are not supported",
    "prod": "Products are not supported by the compute tools",
    "sum": "Sums are not supported by the compute tools",
    "text": "Text commands are not supported",
    "tfrac": "",
}

_DIFFERENTIAL_PATTERN = (
    r"(?:\\mathrm\s*\{\s*d\s*\}|\\text\s*\{\s*d\s*\}|d)"
    r"\s*(?P<var>\\[A-Za-z]+|[A-Za-z])"
)
_DIFFERENTIAL_RE = re.compile(_DIFFERENTIAL_PATTERN + r"\s*$")
# Used to detect a differential that is followed by more text, which used to be
# swallowed into the integrand and produced a silently wrong answer.
_TRAILING_DIFFERENTIAL_RE = re.compile(_DIFFERENTIAL_PATTERN)
_TRAILING_SPACING_RE = re.compile(r"(?:\\[,;:!]|\\quad|\\qquad)\s*$")

# Leibniz notation such as \frac{d}{dx} x^2 or \frac{\mathrm{d}}{\mathrm{d}x}.
# The parser would otherwise read it as an ordinary fraction and return a
# confidently wrong answer.
_GAP = r"(?:\s|\\[,;:!])*"
_D = r"(?:\\(?:mathrm|text)\s*\{\s*d\s*\}|d)"
_DERIVATIVE_NOTATION_RE = re.compile(
    rf"\\[dt]?frac\s*\{{\s*{_D}{_GAP}(?:[A-Za-z])?{_GAP}\}}\s*"
    rf"\{{\s*{_D}{_GAP}(?:[A-Za-z]|\\[A-Za-z]+){_GAP}\}}"
)



class LatexParseError(ValueError):
    """Raised when LaTeX cannot be converted into a computable expression."""


@dataclass(frozen=True)
class ParsedIntegral:
    """An integral parsed from LaTeX.

    ``variable`` is ``None`` when the input has no differential, in which case
    the caller should fall back to the variable chosen in the UI.
    """

    integrand: str
    variable: str | None
    lower: str | None
    upper: str | None


def _strip_delimiters(text: str) -> str:
    source = (text or "").strip()
    if not source:
        raise LatexParseError("Enter a LaTeX expression")
    if len(source) > MAX_LATEX_MATH_LENGTH:
        raise LatexParseError(
            f"Expression is too long (maximum {MAX_LATEX_MATH_LENGTH} characters)"
        )
    if _CONTROL_RE.search(source):
        raise LatexParseError("LaTeX input contains unsupported control characters")
    if "%" in source:
        raise LatexParseError("LaTeX comments (%) are not supported")

    for opening, closing in (("$$", "$$"), ("$", "$"), ("\\[", "\\]"), ("\\(", "\\)")):
        if (
            source.startswith(opening)
            and source.endswith(closing)
            and len(source) > len(opening) + len(closing)
        ):
            source = source[len(opening) : -len(closing)].strip()
            break

    if not source:
        raise LatexParseError("Enter a LaTeX expression")
    return source


def _check_bare_names(source: str) -> None:
    """Reject plain names such as ``sin`` or ``pi`` that must be commands.

    Bare multi-letter runs are split into single-letter variables by LaTeX
    convention (``xy`` is ``x*y``). A run that names a function or constant is
    almost always a plain-text habit, and silently treating it as a product
    would produce a confidently wrong answer, so it is reported instead.
    """

    for match in re.finditer(r"(?<!\\)\b([EI])\b", source):
        raise LatexParseError(
            f"Use lowercase '{match.group(1).lower()}' for "
            + ("Euler's number" if match.group(1) == "E" else "the imaginary unit")
        )

    for match in re.finditer(r"(?<![\\A-Za-z])([A-Za-z]+)", source):
        run = match.group(1)
        lowered = run.lower()
        if lowered in _BARE_NAME_HINTS:
            raise LatexParseError(
                f"Unknown name '{run}'. Use LaTeX commands such as \\sin, \\sqrt, "
                "\\exp, \\pi, \\infty, or \\alpha."
            )
        for name in sorted(_BARE_NAME_HINTS, key=len, reverse=True):
            if len(name) >= 2 and lowered.startswith(name) and len(lowered) > len(name):
                raise LatexParseError(
                    f"Did you mean \\{name}...? Plain function names are not supported."
                )


def _check_derivative_notation(source: str) -> None:
    """Reject Leibniz fractions such as ``\\frac{d}{dx}``.

    Without this check the fraction parses as a division and the result is
    silently wrong, so the Derivative tool is pointed at instead.
    """

    if _DERIVATIVE_NOTATION_RE.search(source):
        raise LatexParseError(
            "Derivative notation like \\frac{d}{dx} is not supported. Enter the "
            "expression on its own (for example: x^{2}) and use the Derivative "
            "tool with its variable field."
        )


def _split_top_level(source: str, separator: str) -> list[str]:
    parts: list[str] = []
    depth = 0
    start = 0
    index = 0
    while index < len(source):
        character = source[index]
        if character == "\\":
            index += 2
            continue
        if character == "{":
            depth += 1
        elif character == "}":
            depth = max(0, depth - 1)
        elif character == separator and depth == 0:
            parts.append(source[start:index])
            start = index + 1
        index += 1
    parts.append(source[start:])
    return parts


def _tokenize(source: str) -> list[tuple[str, str]]:
    tokens: list[tuple[str, str]] = []
    index = 0
    length = len(source)

    while index < length:
        character = source[index]

        if character.isspace():
            index += 1
            continue

        if character == "\\":
            if index + 1 >= length:
                raise LatexParseError("LaTeX input cannot end with a backslash")
            if source[index + 1].isalpha():
                end = index + 1
                while end < length and source[end].isalpha():
                    end += 1
                name = source[index + 1 : end]
                index = end
                if name in _SKIP_COMMANDS or name in _SPACING_COMMANDS:
                    continue
                if name in {"ast", "cdot", "times"}:
                    tokens.append(("char", "*"))
                    continue
                if name == "div":
                    tokens.append(("char", "/"))
                    continue
                tokens.append(("cmd", name))
                continue
            symbol = source[index + 1]
            index += 2
            if symbol in _SPACING_SYMBOLS:
                continue
            if symbol in _CONTROL_SYMBOLS:
                tokens.append(("char", _CONTROL_SYMBOLS[symbol]))
                continue
            raise LatexParseError(f"Unsupported LaTeX command: \\{symbol}")

        if character.isdigit() or (
            character == "." and index + 1 < length and source[index + 1].isdigit()
        ):
            end = index
            seen_dot = False
            while end < length:
                current = source[end]
                if current.isdigit():
                    end += 1
                    continue
                if current == "." and not seen_dot:
                    seen_dot = True
                    end += 1
                    continue
                break
            tokens.append(("num", source[index:end]))
            index = end
            continue

        if character.isalpha():
            tokens.append(("letter", character))
            index += 1
            continue

        if character in "+-*/^_()[]|={},":
            tokens.append(("char", character))
            index += 1
            continue

        raise LatexParseError(f"Unsupported character '{character}' in LaTeX input")

    return tokens


def _is_minus_one(expression: str) -> bool:
    """Return True when an exponent is exactly -1, ignoring outer brackets."""

    text = expression.strip()
    while len(text) >= 2 and text[0] == "(" and text[-1] == ")":
        text = text[1:-1].strip()
    return text == "-1"


class _LatexParser:
    def __init__(self, tokens: list[tuple[str, str]]) -> None:
        self._tokens = tokens
        self._position = 0
        self._abs_depth = 0

    def _peek(self) -> tuple[str | None, str | None]:
        if self._position >= len(self._tokens):
            return (None, None)
        return self._tokens[self._position]

    def _take(self) -> tuple[str | None, str | None]:
        token = self._peek()
        self._position += 1
        return token

    def parse(self) -> str:
        node = self._parse_expression()
        if self._position < len(self._tokens):
            kind, value = self._peek()
            if kind == "cmd":
                raise LatexParseError(f"Unsupported LaTeX command: \\{value}")
            raise LatexParseError(f"Unexpected '{value}' in LaTeX input")
        return node

    def _expect(self, character: str) -> None:
        kind, value = self._peek()
        if kind == "char" and value == character:
            self._take()
            return
        found = f"'{value}'" if value is not None else "the end of the input"
        raise LatexParseError(f"Expected '{character}' but found {found}")

    def _parse_expression(self) -> str:
        node = self._parse_term()
        while True:
            kind, value = self._peek()
            if kind == "char" and value in "+-":
                self._take()
                node = f"({node} {value} {self._parse_term()})"
                continue
            return node

    def _parse_term(self) -> str:
        node = self._parse_unary()
        while True:
            kind, value = self._peek()
            if kind == "char" and value in "*/":
                self._take()
                node = f"({node} {value} {self._parse_unary()})"
                continue
            if self._starts_factor():
                node = f"({node} * {self._parse_unary()})"
                continue
            return node

    def _parse_unary(self) -> str:
        kind, value = self._peek()
        if kind == "char" and value in "+-":
            self._take()
            operand = self._parse_unary()
            return operand if value == "+" else f"(-{operand})"
        return self._parse_power()

    def _parse_power(self) -> str:
        base = self._parse_primary()
        kind, value = self._peek()
        if kind == "char" and value == "^":
            self._take()
            return f"({base})^({self._parse_unary()})"
        return base

    def _starts_factor(self) -> bool:
        kind, value = self._peek()
        if kind in {"num", "letter"}:
            return True
        if kind == "char":
            if value == "|":
                return self._abs_depth == 0
            return value in "({"
        if kind == "cmd":
            return (
                value in _FUNCTIONS
                or value in _CONSTANTS
                or value in _GREEK
                or value in {"dfrac", "frac", "operatorname", "sqrt", "tfrac"}
            )
        return False

    def _parse_primary(self) -> str:
        kind, value = self._take()

        if kind == "num":
            return str(value)
        if kind == "letter":
            if value == "e":
                return "E"
            if value == "i":
                return "I"
            return str(value)
        if kind == "char":
            if value == "(":
                node = self._parse_expression()
                self._expect(")")
                return node
            if value == "{":
                node = self._parse_expression()
                self._expect("}")
                return node
            if value == "|":
                self._abs_depth += 1
                node = self._parse_expression()
                self._abs_depth -= 1
                self._expect("|")
                return f"abs({node})"
            raise LatexParseError(f"Unexpected '{value}' in LaTeX input")
        if kind == "cmd":
            return self._parse_command(str(value))

        raise LatexParseError("Unexpected end of LaTeX input")

    def _parse_argument(self) -> str:
        if not self._starts_factor():
            kind, value = self._peek()
            found = f"'{value}'" if value is not None else "the end of the input"
            raise LatexParseError(f"Expected an argument but found {found}")
        return self._parse_power()

    def _parse_function_argument(self) -> str:
        if not self._starts_factor():
            kind, value = self._peek()
            found = f"'{value}'" if value is not None else "the end of the input"
            raise LatexParseError(f"Expected an argument but found {found}")
        kind, value = self._peek()
        # A braced or parenthesised argument ends at its closing delimiter, so a
        # following '^' belongs to the function: \sin(x)^2 is (sin x)^2.
        if kind == "char" and value in "({|":
            return self._parse_primary()
        # A bare argument keeps its own exponent: \sin x^2 is sin(x^2).
        return self._parse_bare_function_argument()

    def _parse_bare_function_argument(self) -> str:
        # So that \sin 2x is sin(2x) and \sin 2(x + 1) is sin(2(x + 1)).
        # A following function starts a new factor instead, so
        # \sin x \cos x stays sin(x) cos(x).
        node = self._parse_power()
        while self._starts_factor():
            kind, value = self._peek()
            if kind == "cmd" and value in _FUNCTIONS:
                break
            node = f"({node} * {self._parse_power()})"
        return node

    def _parse_text_group(self) -> str:
        self._expect("{")
        parts: list[str] = []
        while True:
            kind, value = self._peek()
            if kind is None:
                raise LatexParseError("Missing '}' after \\operatorname")
            if kind == "char" and value == "}":
                self._take()
                return "".join(parts)
            self._take()
            if kind in {"letter", "num"}:
                parts.append(str(value))
            elif kind == "cmd":
                parts.append(str(value))
            else:
                raise LatexParseError("Unsupported argument to \\operatorname")

    def _parse_command(self, name: str) -> str:
        if name in _FUNCTIONS:
            return self._parse_function(name)
        if name in _CONSTANTS:
            return _CONSTANTS[name]
        if name in _GREEK:
            return _GREEK[name]
        if name in {"frac", "dfrac", "tfrac"}:
            numerator = self._parse_argument()
            denominator = self._parse_argument()
            return f"(({numerator})/({denominator}))"
        if name == "sqrt":
            index = None
            kind, value = self._peek()
            if kind == "char" and value == "[":
                self._take()
                index = self._parse_expression()
                self._expect("]")
            argument = self._parse_argument()
            if index is None:
                return f"sqrt({argument})"
            return f"(({argument})^(1/({index})))"
        if name == "operatorname":
            text = self._parse_text_group().strip().lower()
            if text == "abs":
                return f"abs({self._parse_argument()})"
            raise LatexParseError(f"Unsupported operator: \\operatorname{{{text}}}")
        if name == "int":
            raise LatexParseError("Integrals are only supported in the Integral tool")
        if name in _UNSUPPORTED_COMMANDS:
            detail = _UNSUPPORTED_COMMANDS[name]
            raise LatexParseError(detail or f"Unsupported LaTeX command: \\{name}")
        raise LatexParseError(
            f"Unsupported LaTeX command: \\{name}. Supported commands include "
            "\\frac, \\sqrt, \\sin, \\cos, \\tan, \\log, \\exp, \\pi, and \\infty."
        )

    def _parse_function(self, name: str) -> str:
        target = _FUNCTIONS[name]
        if name == "Gamma" and not self._starts_factor():
            raise LatexParseError(
                "\\Gamma is the gamma function and needs an argument, for example "
                "\\Gamma(x)"
            )
        power = None
        kind, value = self._peek()
        if kind == "char" and value == "^":
            self._take()
            power = self._parse_power_argument()
        argument = self._parse_function_argument()
        inverse = _INVERSE_FUNCTIONS.get(target)
        if inverse is not None and power is not None and _is_minus_one(power):
            return f"{inverse}({argument})"
        base = f"{target}({argument})"
        if power is None:
            return base
        return f"({base})^({power})"

    def _parse_power_argument(self) -> str:
        # ``\sin^2 x``: the exponent belongs to the function, not its argument.
        kind, value = self._peek()
        if kind == "char" and value == "{":
            self._take()
            exponent = self._parse_expression()
            self._expect("}")
            return exponent
        kind, value = self._take()
        if kind == "num":
            return str(value)
        if kind == "letter":
            return "E" if value == "e" else ("I" if value == "i" else str(value))
        if kind == "char" and value == "-":
            return f"(-{self._parse_power_argument()})"
        raise LatexParseError("Expected an exponent after '^'")


def parse_latex_expression(text: str) -> str:
    """Convert a standalone LaTeX expression into plain SymPy syntax."""

    source = _strip_delimiters(text)
    _check_bare_names(source)
    _check_derivative_notation(source)
    if len(_split_top_level(source, "=")) > 1:
        raise LatexParseError(
            "Enter an expression, not an equation (for example: \\frac{x^2 - 1}{x - 1})"
        )
    tokens = _tokenize(source)
    if not tokens:
        raise LatexParseError("Enter a LaTeX expression")
    return _LatexParser(tokens).parse()


def parse_latex_equation(text: str) -> tuple[str, str]:
    """Convert a LaTeX equation into two plain SymPy expressions."""

    source = _strip_delimiters(text)
    _check_bare_names(source)
    parts = _split_top_level(source, "=")
    if len(parts) != 2:
        raise LatexParseError(
            "Enter an equation with exactly one '=' (for example: x^2 - 4 = 0)"
        )
    left, right = (part.strip() for part in parts)
    if not left or not right:
        raise LatexParseError(
            "Enter both sides of the equation (for example: x^2 - 4 = 0)"
        )
    return parse_latex_expression(left), parse_latex_expression(right)


def parse_latex_variable(text: str) -> str:
    """Convert a variable name such as ``x`` or ``\\theta`` into a symbol name."""

    source = (text or "").strip()
    if not source:
        return "x"
    source = _strip_delimiters(source)

    command = re.fullmatch(r"\\([A-Za-z]+)", source)
    if command:
        name = command.group(1)
        if name in _GREEK:
            return _GREEK[name]
        raise LatexParseError(f"Unsupported LaTeX command: \\{name}")

    if re.fullmatch(r"[A-Za-z]", source):
        return source
    raise LatexParseError("Choose a single variable like x, y, t, or \\theta")


def _skip_spaces(text: str, position: int) -> int:
    while position < len(text) and text[position].isspace():
        position += 1
    return position


def _take_raw_argument(text: str, position: int) -> tuple[str, int]:
    position = _skip_spaces(text, position)
    if position >= len(text):
        raise LatexParseError("Missing integral bound")

    if text[position] == "{":
        start = position + 1
        depth = 1
        cursor = position + 1
        while cursor < len(text):
            character = text[cursor]
            if character == "\\":
                cursor += 2
                continue
            if character == "{":
                depth += 1
            elif character == "}":
                depth -= 1
                if depth == 0:
                    return text[start:cursor], cursor + 1
            cursor += 1
        raise LatexParseError("Mismatched braces in integral bound")

    if text[position] == "\\":
        match = re.match(r"\\[A-Za-z]+", text[position:])
        if not match:
            raise LatexParseError("Unsupported integral bound")
        end = position + match.end()
        while True:
            next_position = _skip_spaces(text, end)
            if next_position < len(text) and text[next_position] == "{":
                _, end = _take_raw_argument(text, next_position)
                continue
            break
        return text[position:end], end

    if text[position] in "+-":
        sign = text[position]
        argument, end = _take_raw_argument(text, position + 1)
        return sign + argument, end

    match = re.match(r"\d+(?:\.\d*)?|\.\d+|[A-Za-z]", text[position:])
    if not match:
        raise LatexParseError("Unsupported integral bound")
    return match.group(0), position + match.end()


def _strip_trailing_spacing(text: str) -> str:
    result = text.rstrip()
    while True:
        match = _TRAILING_SPACING_RE.search(result)
        if not match:
            return result
        result = result[: match.start()].rstrip()


def _split_differential(body: str) -> tuple[str, str | None]:
    for match in _DIFFERENTIAL_RE.finditer(body):
        previous = body[match.start() - 1] if match.start() > 0 else ""
        if previous and (previous.isalnum() or previous == "\\"):
            continue
        return _strip_trailing_spacing(body[: match.start()]), match.group("var")

    # A differential followed by more text is ambiguous. The old behaviour was
    # to treat the whole remainder as the integrand, so "\int x dx + 1" became
    # the integral of "x*d*x + 1" and returned a confidently wrong answer.
    for match in _TRAILING_DIFFERENTIAL_RE.finditer(body):
        previous = body[match.start() - 1] if match.start() > 0 else ""
        if previous and (previous.isalnum() or previous == "\\"):
            continue
        if body[match.end() :].strip():
            raise LatexParseError(
                "Text after the differential is not supported. Put the whole "
                "integrand before dx, for example \\int (x + 1) \\, dx."
            )

    return _strip_trailing_spacing(body), None


def _plain_variable(variable: str) -> str:
    if variable.startswith("\\"):
        name = variable[1:]
        if name in _GREEK:
            return _GREEK[name]
        raise LatexParseError(f"Unsupported differential variable: {variable}")
    return variable


def parse_latex_integral(text: str) -> ParsedIntegral | None:
    """Parse ``\\int ... dx`` and optional bounds, or return ``None``.

    ``None`` means the input has no integral; callers should treat it as a
    plain expression instead.
    """

    source = _strip_delimiters(text)
    _check_bare_names(source)
    _check_derivative_notation(source)

    match = re.search(r"\\int(?![A-Za-z])", source)
    if not match:
        return None

    prefix = source[: match.start()].strip()
    if prefix and not re.fullmatch(r"(?:\\displaystyle\s*)*", prefix):
        raise LatexParseError("Only a single integral is supported")

    body = source[match.end() :]
    position = 0
    lower = None
    upper = None
    while True:
        position = _skip_spaces(body, position)
        if position >= len(body) or body[position] not in "_^":
            break
        marker = body[position]
        argument, position = _take_raw_argument(body, position + 1)
        if marker == "_":
            if lower is not None:
                raise LatexParseError("An integral can only have one lower bound")
            lower = argument
        else:
            if upper is not None:
                raise LatexParseError("An integral can only have one upper bound")
            upper = argument

    integrand_source, differential = _split_differential(body[position:])
    if not integrand_source.strip():
        raise LatexParseError("Add an integrand after \\int")
    if (lower is None) != (upper is None):
        raise LatexParseError("An integral needs both a lower and an upper bound")

    return ParsedIntegral(
        integrand=parse_latex_expression(integrand_source),
        variable=_plain_variable(differential) if differential else None,
        lower=parse_latex_expression(lower) if lower is not None else None,
        upper=parse_latex_expression(upper) if upper is not None else None,
    )
