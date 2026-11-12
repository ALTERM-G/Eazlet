import base64
import keyword
import os
import re
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path

from PySide6.QtCore import Property, QObject, QThread, QUrl, Signal, Slot

from .base_vm import BaseVM

MAX_EXPRESSION_LENGTH = 500
MAX_LATEX_LENGTH = 4000
LATEX_TIMEOUT_SECONDS = 30

_ALLOWED_CHARACTERS = frozenset(
    "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+-*/^(). ,\t\n"
)
_EQUATION_CHARACTERS = _ALLOWED_CHARACTERS | frozenset("=")
_IDENTIFIER_RE = re.compile(r"[A-Za-z][A-Za-z0-9]*")
_DECIMAL_RE = re.compile(r"(?:\d+\.\d*|\.\d+)")

# Only the functions and constants returned by _function_table() are exposed
# to the parser. Everything else is treated as a variable, which keeps SymPy
# from evaluating arbitrary Python names from user input.
SAMPLE_EXPRESSION = "(x^2 - 1)/(x - 1)"

MATH_MODES = [
    "Simplify",
    "Expand",
    "Factor",
    "Solve",
    "Derivative",
    "Integral",
    "Limit",
    "LaTeX → PNG",
]
LATEX_MODE = "LaTeX → PNG"

SAMPLE_EXPRESSIONS = {
    "Simplify": SAMPLE_EXPRESSION,
    "Expand": "(x + 1)^3",
    "Factor": "x^2 - 1",
    "Solve": "x^2 - 4 = 0",
    "Derivative": "x^3 - 3*x + 2",
    "Integral": "x*sin(x)",
    "Limit": "sin(x)/x",
}
SAMPLE_LATEX = r"\frac{x^2 - 1}{x - 1} = x + 1"

_ACTION_LABELS = {
    "Simplify": "Simplify",
    "Expand": "Expand",
    "Factor": "Factor",
    "Solve": "Solve",
    "Derivative": "Differentiate",
    "Integral": "Integrate",
    "Limit": "Evaluate",
    LATEX_MODE: "Render PNG",
}

_RUNNING_STATUS = {
    "Simplify": "Simplifying…",
    "Expand": "Expanding…",
    "Factor": "Factoring…",
    "Solve": "Solving…",
    "Derivative": "Differentiating…",
    "Integral": "Integrating…",
    "Limit": "Evaluating…",
}

_RESULT_LABELS = {
    "Simplify": ("Simplified", "Simplified"),
    "Expand": ("Expanded", "Expanded"),
    "Factor": ("Factored", "Factored"),
    "Solve": ("Solutions", "Solved"),
    "Derivative": ("Derivative", "Differentiated"),
    "Integral": ("Integral", "Integrated"),
    "Limit": ("Limit", "Evaluated"),
}

# Commands that can read/write files, run shell escapes, define macros, or
# otherwise reach outside the formula being rendered. Shell escape is also
# disabled on the LaTeX command line, but rejecting these up front keeps the
# error messages readable and blocks file access primitives.
_FORBIDDEN_LATEX_COMMANDS = frozenset(
    {
        "afterassignment",
        "aftergroup",
        "bibliography",
        "bibliographystyle",
        "catcode",
        "chardef",
        "closein",
        "closeout",
        "countdef",
        "csname",
        "def",
        "dimendef",
        "directlua",
        "documentclass",
        "dump",
        "edef",
        "else",
        "endcsname",
        "endinput",
        "errmessage",
        "everydisplay",
        "everymath",
        "everypar",
        "expandafter",
        "fi",
        "futurelet",
        "gdef",
        "global",
        "href",
        "if",
        "ifcase",
        "ifcat",
        "ifdefined",
        "ifdim",
        "iffalse",
        "ifhbox",
        "ifhmode",
        "ifinner",
        "ifmmode",
        "ifnum",
        "ifodd",
        "iftrue",
        "ifvbox",
        "ifvmode",
        "ifvoid",
        "ifx",
        "immediate",
        "include",
        "includeonly",
        "includegraphics",
        "input",
        "latelua",
        "let",
        "loop",
        "lowercase",
        "lua",
        "makeatletter",
        "makeatother",
        "message",
        "muskipdef",
        "newcommand",
        "newread",
        "newwrite",
        "noexpand",
        "openin",
        "openout",
        "or",
        "output",
        "parindent",
        "providecommand",
        "read",
        "repeat",
        "renewcommand",
        "scantokens",
        "shipout",
        "show",
        "showthe",
        "skipdef",
        "special",
        "string",
        "toks",
        "toksdef",
        "typein",
        "typeout",
        "uppercase",
        "url",
        "usepackage",
        "verb",
        "write",
        "xdef",
    }
)
_LATEX_COMMAND_RE = re.compile(r"\\([A-Za-z@]+)")
_LATEX_ENVIRONMENT_RE = re.compile(r"\\(begin|end)\s*\{([^{}]*)\}")
_LATEX_CONTROL_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")

_ALLOWED_LATEX_ENVIRONMENTS = frozenset(
    {
        "Bmatrix",
        "Vmatrix",
        "aligned",
        "array",
        "bmatrix",
        "cases",
        "gathered",
        "matrix",
        "pmatrix",
        "smallmatrix",
        "split",
        "vmatrix",
    }
)


def _import_sympy():
    import sympy

    return sympy


def _function_table(sympy) -> dict:
    return {
        "sqrt": sympy.sqrt,
        "cbrt": sympy.cbrt,
        "sin": sympy.sin,
        "cos": sympy.cos,
        "tan": sympy.tan,
        "cot": sympy.cot,
        "sec": sympy.sec,
        "csc": sympy.csc,
        "asin": sympy.asin,
        "acos": sympy.acos,
        "atan": sympy.atan,
        "sinh": sympy.sinh,
        "cosh": sympy.cosh,
        "tanh": sympy.tanh,
        "asinh": sympy.asinh,
        "acosh": sympy.acosh,
        "atanh": sympy.atanh,
        "exp": sympy.exp,
        "log": sympy.log,
        "ln": sympy.log,
        "abs": sympy.Abs,
        "factorial": sympy.factorial,
        "gcd": sympy.gcd,
        "lcm": sympy.lcm,
        "floor": sympy.floor,
        "ceil": sympy.ceiling,
        "pi": sympy.pi,
        "E": sympy.E,
        "I": sympy.I,
        "oo": sympy.oo,
    }


def _validate_math_text(text: str, *, allow_equals: bool) -> str:
    expression = (text or "").strip()
    if not expression:
        if allow_equals:
            raise ValueError("Enter an equation to solve")
        raise ValueError("Enter an expression to simplify")

    if len(expression) > MAX_EXPRESSION_LENGTH:
        raise ValueError(f"Expression is too long (maximum {MAX_EXPRESSION_LENGTH} characters)")

    if not allow_equals and "=" in expression:
        raise ValueError("Enter an expression, not an equation (for example: (x^2 - 1)/(x - 1))")

    allowed = _EQUATION_CHARACTERS if allow_equals else _ALLOWED_CHARACTERS
    if any(character not in allowed for character in expression):
        raise ValueError(
            "Unsupported character. Use numbers, variables, functions, and + - * / ^ ( )."
        )

    # A dot is only meaningful as part of a decimal number. Rejecting other
    # uses keeps attribute access out of the parser.
    without_decimals = _DECIMAL_RE.sub("0", expression)
    if "." in without_decimals:
        raise ValueError("Unsupported use of '.'; write decimals like 0.5")

    for name in _IDENTIFIER_RE.findall(expression):
        if keyword.iskeyword(name):
            raise ValueError(f"'{name}' is a reserved word; rename that variable")

    if allow_equals:
        if expression.count("=") != 1:
            raise ValueError("Enter an equation with exactly one '=' (for example: x^2 - 4 = 0)")
        left, right = (side.strip() for side in expression.split("="))
        if not left or not right:
            raise ValueError("Enter both sides of the equation (for example: x^2 - 4 = 0)")

    return expression


def _validate_expression(text: str) -> str:
    return _validate_math_text(text, allow_equals=False)


def _validate_equation(text: str) -> str:
    return _validate_math_text(text, allow_equals=True)


def _validate_variable(text: str) -> str:
    variable = (text or "").strip() or "x"
    if not _IDENTIFIER_RE.fullmatch(variable):
        raise ValueError("Enter a variable name like x, y, or t")
    if keyword.iskeyword(variable):
        raise ValueError(f"'{variable}' is a reserved word; choose another variable")
    return variable


def _validate_point(text: str) -> str:
    point = (text or "").strip() or "0"
    return _validate_expression(point)


def _parse_expression(sympy, expression: str):
    from sympy.parsing.sympy_parser import (
        convert_xor,
        implicit_multiplication_application,
        parse_expr,
        standard_transformations,
    )

    local_dict = {
        "Symbol": sympy.Symbol,
        "Integer": sympy.Integer,
        "Float": sympy.Float,
        "Rational": sympy.Rational,
        "Function": sympy.Function,
    }
    local_dict.update(_function_table(sympy))

    for name in _IDENTIFIER_RE.findall(expression):
        if name not in local_dict:
            local_dict[name] = sympy.Symbol(name)

    transformations = standard_transformations + (
        implicit_multiplication_application,
        convert_xor,
    )

    return parse_expr(
        expression,
        local_dict=local_dict,
        global_dict={},
        transformations=transformations,
    )


def _format_expression(expression) -> str:
    return str(expression).replace("**", "^")


def _simplify_expression(text: str) -> tuple[str, str]:
    expression = _validate_expression(text)
    sympy = _import_sympy()
    parsed = _parse_expression(sympy, expression)
    simplified = sympy.simplify(parsed)
    return expression, _format_expression(simplified)


def _expand_expression(text: str) -> tuple[str, str]:
    expression = _validate_expression(text)
    sympy = _import_sympy()
    parsed = _parse_expression(sympy, expression)
    return expression, _format_expression(sympy.expand(parsed))


def _factor_expression(text: str) -> tuple[str, str]:
    expression = _validate_expression(text)
    sympy = _import_sympy()
    parsed = _parse_expression(sympy, expression)
    return expression, _format_expression(sympy.factor(parsed))


def _solve_equation(text: str, variable: str = "x") -> tuple[str, str]:
    equation = _validate_equation(text)
    variable = _validate_variable(variable)
    sympy = _import_sympy()
    left_text, right_text = (side.strip() for side in equation.split("="))
    left = _parse_expression(sympy, left_text)
    right = _parse_expression(sympy, right_text)
    solutions = sympy.solve(sympy.Eq(left, right), sympy.Symbol(variable))
    if isinstance(solutions, dict):
        solutions = list(solutions.values())
    if not solutions:
        return equation, f"No solutions for {variable}"
    solutions = sorted(solutions, key=str)
    return equation, ", ".join(_format_expression(solution) for solution in solutions)


def _differentiate_expression(text: str, variable: str = "x") -> tuple[str, str]:
    expression = _validate_expression(text)
    variable = _validate_variable(variable)
    sympy = _import_sympy()
    parsed = _parse_expression(sympy, expression)
    result = sympy.simplify(sympy.diff(parsed, sympy.Symbol(variable)))
    return expression, _format_expression(result)


def _integrate_expression(text: str, variable: str = "x") -> tuple[str, str]:
    expression = _validate_expression(text)
    variable = _validate_variable(variable)
    sympy = _import_sympy()
    parsed = _parse_expression(sympy, expression)
    result = sympy.integrate(parsed, sympy.Symbol(variable))
    formatted = _format_expression(result)
    if result.has(sympy.Integral):
        return expression, formatted
    return expression, f"{formatted} + C"


def _limit_expression(text: str, variable: str = "x", point: str = "0") -> tuple[str, str]:
    expression = _validate_expression(text)
    variable = _validate_variable(variable)
    point_text = _validate_point(point)
    sympy = _import_sympy()
    parsed = _parse_expression(sympy, expression)
    point_expression = _parse_expression(sympy, point_text)
    result = sympy.limit(parsed, sympy.Symbol(variable), point_expression)
    return expression, _format_expression(result)


def _compute_math(
    mode: str, expression: str, variable: str, point: str
) -> tuple[str, str, str, str]:
    if mode == "Simplify":
        original, result = _simplify_expression(expression)
    elif mode == "Expand":
        original, result = _expand_expression(expression)
    elif mode == "Factor":
        original, result = _factor_expression(expression)
    elif mode == "Solve":
        original, result = _solve_equation(expression, variable)
    elif mode == "Derivative":
        original, result = _differentiate_expression(expression, variable)
    elif mode == "Integral":
        original, result = _integrate_expression(expression, variable)
    elif mode == "Limit":
        original, result = _limit_expression(expression, variable, point)
    else:
        raise ValueError(f"Unsupported math tool: {mode}")

    label, status = _RESULT_LABELS[mode]
    return original, result, label, status


def _normalize_latex_source(text: str) -> str:
    source = (text or "").strip()
    if not source:
        raise ValueError("Enter LaTeX code to render")

    if len(source) > MAX_LATEX_LENGTH:
        raise ValueError(f"LaTeX code is too long (maximum {MAX_LATEX_LENGTH} characters)")

    if _LATEX_CONTROL_RE.search(source):
        raise ValueError("LaTeX code contains unsupported control characters")

    # Accept the delimiters people usually copy from editors and markdown.
    for opening, closing in (("$$", "$$"), ("$", "$"), ("\\[", "\\]"), ("\\(", "\\)")):
        if (
            source.startswith(opening)
            and source.endswith(closing)
            and len(source) > len(opening) + len(closing)
        ):
            source = source[len(opening) : -len(closing)].strip()
            break

    if not source:
        raise ValueError("Enter LaTeX code to render")

    if "%" in source:
        raise ValueError("LaTeX comments (%) are not supported")

    environment_stack: list[str] = []
    for match in _LATEX_ENVIRONMENT_RE.finditer(source):
        action, environment = match.group(1), match.group(2).strip()
        if environment not in _ALLOWED_LATEX_ENVIRONMENTS:
            raise ValueError(f"Unsupported LaTeX environment: {environment or '(empty)'}")
        if action == "begin":
            environment_stack.append(environment)
        elif not environment_stack or environment_stack.pop() != environment:
            raise ValueError(f"Mismatched \\begin and \\end for {environment}")

    if environment_stack:
        raise ValueError(f"Missing \\end for {environment_stack[-1]}")

    without_environments = _LATEX_ENVIRONMENT_RE.sub("", source)
    if re.search(r"\\(begin|end)\b", without_environments):
        raise ValueError("Unsupported use of \\begin or \\end")

    for match in _LATEX_COMMAND_RE.finditer(source):
        name = match.group(1)
        if "@" in name or name.lstrip("@").lower() in _FORBIDDEN_LATEX_COMMANDS:
            raise ValueError(f"Unsupported LaTeX command: \\{name}")

    return source


def _dvipng_color(value: str, default: str, *, allow_transparent: bool) -> str:
    text = str(value or "").strip() or default
    if text.lower() == "transparent":
        if allow_transparent:
            return "Transparent"
        raise ValueError("Choose a visible text colour")

    if text.startswith("#"):
        text = text[1:]
    if len(text) == 3:
        text = "".join(character * 2 for character in text)
    if len(text) == 8:
        # QML colours are #AARRGGBB; dvipng only needs the RGB part.
        text = text[2:]
    if len(text) != 6 or any(character not in "0123456789abcdefABCDEF" for character in text):
        raise ValueError("Choose a colour in #RRGGBB format")

    red, green, blue = (int(text[index : index + 2], 16) / 255 for index in (0, 2, 4))
    return f"rgb {red:.4f} {green:.4f} {blue:.4f}"


def _latex_document(source: str) -> str:
    return "\n".join(
        [
            r"\documentclass[12pt]{article}",
            r"\usepackage{amsmath}",
            r"\usepackage{amssymb}",
            r"\pagestyle{empty}",
            r"\begin{document}",
            r"\begin{displaymath}",
            source,
            r"\end{displaymath}",
            r"\end{document}",
            "",
        ]
    )


def _latex_error(output: str) -> str:
    lines = [line.strip() for line in (output or "").splitlines() if line.strip()]
    for index, line in enumerate(lines):
        if line.startswith("!"):
            message = line[1:].strip()
            if index + 1 < len(lines) and lines[index + 1].startswith("l."):
                message = f"{message} ({lines[index + 1]})"
            return f"LaTeX error: {message}"
    return "LaTeX could not render this formula"


def _png_dimensions(png: bytes) -> tuple[int, int]:
    if len(png) < 24 or png[:8] != b"\x89PNG\r\n\x1a\n" or png[12:16] != b"IHDR":
        raise RuntimeError("LaTeX did not produce a valid PNG image")
    width, height = struct.unpack(">II", png[16:24])
    if width <= 0 or height <= 0:
        raise RuntimeError("LaTeX produced an empty PNG image")
    return width, height


def _png_data_url(png: bytes) -> str:
    payload = base64.b64encode(png).decode("ascii")
    return f"data:image/png;base64,{payload}"


def _render_latex_png(
    source: str,
    resolution: int = 300,
    background: str = "#FFFFFF",
    foreground: str = "#000000",
) -> tuple[bytes, int, int]:
    latex_source = _normalize_latex_source(source)
    try:
        resolution = int(resolution)
    except (TypeError, ValueError):
        resolution = 300
    resolution = max(72, min(1200, resolution))

    background_color = _dvipng_color(background, "#FFFFFF", allow_transparent=True)
    foreground_color = _dvipng_color(foreground, "#000000", allow_transparent=False)

    latex = shutil.which("latex")
    dvipng = shutil.which("dvipng")
    if not latex or not dvipng:
        raise RuntimeError(
            "LaTeX rendering needs the 'latex' and 'dvipng' commands. "
            "Install a TeX Live package that provides them."
        )

    document = _latex_document(latex_source)

    with tempfile.TemporaryDirectory(prefix="eazlet-latex-") as directory:
        directory_path = Path(directory)
        (directory_path / "formula.tex").write_text(document, encoding="utf-8")

        # Restrict file access to the temporary directory as a second line of
        # defense in addition to rejecting file-related commands above.
        environment = os.environ.copy()
        environment["openin_any"] = "p"
        environment["openout_any"] = "p"

        try:
            compile_result = subprocess.run(
                [
                    latex,
                    "-interaction=nonstopmode",
                    "-halt-on-error",
                    "-no-shell-escape",
                    "formula.tex",
                ],
                cwd=directory_path,
                env=environment,
                capture_output=True,
                text=True,
                errors="replace",
                timeout=LATEX_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired as error:
            raise RuntimeError("LaTeX took too long to render this formula") from error

        if compile_result.returncode != 0:
            raise RuntimeError(_latex_error(compile_result.stdout + "\n" + compile_result.stderr))

        if not (directory_path / "formula.dvi").exists():
            raise RuntimeError("LaTeX did not produce a DVI file")

        try:
            render_result = subprocess.run(
                [
                    dvipng,
                    "-T",
                    "tight",
                    "-D",
                    str(resolution),
                    "-bg",
                    background_color,
                    "-fg",
                    foreground_color,
                    "-o",
                    "formula.png",
                    "formula.dvi",
                ],
                cwd=directory_path,
                env=environment,
                capture_output=True,
                text=True,
                errors="replace",
                timeout=LATEX_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired as error:
            raise RuntimeError("dvipng took too long to render this formula") from error

        if render_result.returncode != 0:
            raise RuntimeError(
                _latex_error(render_result.stdout + "\n" + render_result.stderr)
            )

        png_path = directory_path / "formula.png"
        if not png_path.exists():
            raise RuntimeError("LaTeX did not produce a PNG image")
        png = png_path.read_bytes()

    width, height = _png_dimensions(png)
    return png, width, height


class _MathWorker(QThread):
    finishedResult = Signal(str, str, str, str)
    failed = Signal(str)

    def __init__(
        self,
        mode: str,
        expression: str,
        variable: str,
        point: str,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self._mode = mode
        self._expression = expression
        self._variable = variable
        self._point = point

    def run(self) -> None:
        try:
            original, result, label, status = _compute_math(
                self._mode,
                self._expression,
                self._variable,
                self._point,
            )
        except Exception as error:  # SymPy raises a wide range of parse errors.
            self.failed.emit(str(error))
            return
        self.finishedResult.emit(original, result, label, status)


class _LatexWorker(QThread):
    finishedResult = Signal(str, object, int, int)
    failed = Signal(str)

    def __init__(
        self,
        source: str,
        resolution: int,
        background: str,
        foreground: str,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self._source = source
        self._resolution = resolution
        self._background = background
        self._foreground = foreground

    def run(self) -> None:
        try:
            png, width, height = _render_latex_png(
                self._source,
                self._resolution,
                self._background,
                self._foreground,
            )
        except Exception as error:
            self.failed.emit(str(error))
            return
        self.finishedResult.emit(_png_data_url(png), png, width, height)


class MathVM(BaseVM):
    expressionChanged = Signal()
    resultChanged = Signal()
    statusChanged = Signal()
    errorChanged = Signal()
    computingChanged = Signal()
    modeChanged = Signal()
    variableChanged = Signal()
    pointChanged = Signal()
    latexSourceChanged = Signal()
    latexResolutionChanged = Signal()
    latexBackgroundChanged = Signal()
    latexForegroundChanged = Signal()
    latexImageSourceChanged = Signal()
    latexRenderingChanged = Signal()
    latexErrorChanged = Signal()
    latexStatusChanged = Signal()
    latexDimensionsChanged = Signal()
    latexSavedMessageChanged = Signal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._expression = ""
        self._result = ""
        self._status = "Ready"
        self._error = ""
        self._computing = False
        self._worker = None

        self._mode = MATH_MODES[0]
        self._variable = "x"
        self._point = "0"

        self._latex_source = ""
        self._latex_resolution = 300
        self._latex_resolutions = [72, 96, 150, 200, 300, 450, 600]
        self._latex_background = "#FFFFFF"
        self._latex_foreground = "#000000"
        self._latex_image_source = ""
        self._latex_rendering = False
        self._latex_error = ""
        self._latex_status = "Ready"
        self._latex_dimensions = ""
        self._latex_saved_message = ""
        self._latex_png = b""

        latex = shutil.which("latex")
        dvipng = shutil.which("dvipng")
        self._latex_available = bool(latex and dvipng)
        missing = [
            name
            for name, path in (("latex", latex), ("dvipng", dvipng))
            if not path
        ]
        self._latex_toolchain_error = (
            ""
            if self._latex_available
            else "LaTeX rendering needs the "
            + " and ".join(f"'{name}'" for name in missing)
            + " commands. Install a TeX Live package that provides them."
        )

    @Property(str, notify=expressionChanged)
    def expression(self) -> str:
        return self._expression

    @expression.setter
    def expression(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._expression:
            self._expression = value
            self.expressionChanged.emit()

    @Property(str, notify=resultChanged)
    def result(self) -> str:
        return self._result

    @Property(str, notify=statusChanged)
    def status(self) -> str:
        return self._status

    @Property(str, notify=errorChanged)
    def error(self) -> str:
        return self._error

    @Property(bool, notify=computingChanged)
    def computing(self) -> bool:
        return self._computing

    @Property(list, constant=True)
    def modes(self) -> list:
        return MATH_MODES

    @Property(str, notify=modeChanged)
    def mode(self) -> str:
        return self._mode

    @mode.setter
    def mode(self, value: str) -> None:
        value = value if value in MATH_MODES else MATH_MODES[0]
        if value != self._mode:
            self._mode = value
            self.modeChanged.emit()
            self._set_error("")
            self._set_status("Ready")
            self._set_result("")

    @Property(str, notify=modeChanged)
    def actionLabel(self) -> str:
        return _ACTION_LABELS.get(self._mode, "Compute")

    @Property(str, notify=modeChanged)
    def inputLabel(self) -> str:
        return "Equation" if self._mode == "Solve" else "Expression"

    @Property(bool, notify=modeChanged)
    def requiresVariable(self) -> bool:
        return self._mode in {"Solve", "Derivative", "Integral", "Limit"}

    @Property(bool, notify=modeChanged)
    def requiresPoint(self) -> bool:
        return self._mode == "Limit"

    @Property(str, notify=variableChanged)
    def variable(self) -> str:
        return self._variable

    @variable.setter
    def variable(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._variable:
            self._variable = value
            self.variableChanged.emit()

    @Property(str, notify=pointChanged)
    def point(self) -> str:
        return self._point

    @point.setter
    def point(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._point:
            self._point = value
            self.pointChanged.emit()

    @Property(str, notify=latexSourceChanged)
    def latexSource(self) -> str:
        return self._latex_source

    @latexSource.setter
    def latexSource(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._latex_source:
            self._latex_source = value
            self.latexSourceChanged.emit()

    @Property(int, notify=latexResolutionChanged)
    def latexResolution(self) -> int:
        return self._latex_resolution

    @latexResolution.setter
    def latexResolution(self, value: int) -> None:
        try:
            value = int(value)
        except (TypeError, ValueError):
            return
        value = max(72, min(1200, value))
        if value != self._latex_resolution:
            self._latex_resolution = value
            self.latexResolutionChanged.emit()

    @Property(list, constant=True)
    def latexResolutions(self) -> list:
        return self._latex_resolutions

    @Property(str, notify=latexBackgroundChanged)
    def latexBackground(self) -> str:
        return self._latex_background

    @latexBackground.setter
    def latexBackground(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._latex_background:
            self._latex_background = value
            self.latexBackgroundChanged.emit()

    @Property(str, notify=latexForegroundChanged)
    def latexForeground(self) -> str:
        return self._latex_foreground

    @latexForeground.setter
    def latexForeground(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._latex_foreground:
            self._latex_foreground = value
            self.latexForegroundChanged.emit()

    @Property(str, notify=latexImageSourceChanged)
    def latexImageSource(self) -> str:
        return self._latex_image_source

    @Property(bool, notify=latexRenderingChanged)
    def latexRendering(self) -> bool:
        return self._latex_rendering

    @Property(str, notify=latexErrorChanged)
    def latexError(self) -> str:
        return self._latex_error

    @Property(str, notify=latexStatusChanged)
    def latexStatus(self) -> str:
        return self._latex_status

    @Property(str, notify=latexDimensionsChanged)
    def latexDimensions(self) -> str:
        return self._latex_dimensions

    @Property(str, notify=latexSavedMessageChanged)
    def latexSavedMessage(self) -> str:
        return self._latex_saved_message

    @Property(bool, constant=True)
    def latexAvailable(self) -> bool:
        return self._latex_available

    @Property(str, constant=True)
    def latexToolchainError(self) -> str:
        return self._latex_toolchain_error

    def _set_result(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._result:
            self._result = value
            self.resultChanged.emit()

    def _set_status(self, value: str) -> None:
        if value != self._status:
            self._status = value
            self.statusChanged.emit()

    def _set_error(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._error:
            self._error = value
            self.errorChanged.emit()

    def _set_computing(self, value: bool) -> None:
        if value != self._computing:
            self._computing = value
            self.computingChanged.emit()

    def _set_latex_image_source(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._latex_image_source:
            self._latex_image_source = value
            self.latexImageSourceChanged.emit()

    def _set_latex_rendering(self, value: bool) -> None:
        if value != self._latex_rendering:
            self._latex_rendering = value
            self.latexRenderingChanged.emit()

    def _set_latex_error(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._latex_error:
            self._latex_error = value
            self.latexErrorChanged.emit()

    def _set_latex_status(self, value: str) -> None:
        if value != self._latex_status:
            self._latex_status = value
            self.latexStatusChanged.emit()

    def _set_latex_dimensions(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._latex_dimensions:
            self._latex_dimensions = value
            self.latexDimensionsChanged.emit()

    def _set_latex_saved_message(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._latex_saved_message:
            self._latex_saved_message = value
            self.latexSavedMessageChanged.emit()

    @Slot(str)
    def setExpression(self, value: str) -> None:
        self.expression = value

    @Slot(str)
    def setMode(self, value: str) -> None:
        self.mode = value

    @Slot(str)
    def setVariable(self, value: str) -> None:
        self.variable = value

    @Slot(str)
    def setPoint(self, value: str) -> None:
        self.point = value

    @Slot(str)
    def setLatexSource(self, value: str) -> None:
        self.latexSource = value

    @Slot(int)
    def setLatexResolution(self, value: int) -> None:
        self.latexResolution = value

    @Slot(str)
    def setLatexBackground(self, value: str) -> None:
        self.latexBackground = value

    @Slot(str)
    def setLatexForeground(self, value: str) -> None:
        self.latexForeground = value

    @Slot()
    def process(self) -> None:
        if self._mode == LATEX_MODE:
            self.renderLatex()
            return

        if self._computing:
            return

        self._set_error("")
        try:
            expression = (
                _validate_equation(self._expression)
                if self._mode == "Solve"
                else _validate_expression(self._expression)
            )
            if self.requiresVariable:
                _validate_variable(self._variable)
            if self.requiresPoint:
                _validate_point(self._point)
        except ValueError as error:
            self._set_error(str(error))
            self._set_result("")
            self._set_status("Error")
            return

        self._set_result("")
        self._set_status(_RUNNING_STATUS.get(self._mode, "Working…"))
        self._set_computing(True)

        worker = _MathWorker(
            self._mode,
            expression,
            self._variable,
            self._point,
            self,
        )
        worker.finishedResult.connect(self._on_finished)
        worker.failed.connect(self._on_failed)
        worker.finished.connect(worker.deleteLater)
        self._worker = worker
        worker.start()

    @Slot(str, str, str, str)
    def _on_finished(self, original: str, result: str, label: str, status: str) -> None:
        self._worker = None
        lines = [f"Input:      {original}", f"{label}: {result}"]
        self._set_result("\n".join(lines))
        self._set_status(status)
        self._set_computing(False)

    @Slot(str)
    def _on_failed(self, error: str) -> None:
        self._worker = None
        self._set_error(error or "Could not compute this expression")
        self._set_result("")
        self._set_status("Error")
        self._set_computing(False)

    @Slot()
    def renderLatex(self) -> None:
        if self._latex_rendering:
            return

        self._set_latex_error("")
        self._set_latex_saved_message("")
        if not self._latex_available:
            self._set_latex_error(self._latex_toolchain_error)
            self._set_latex_status("Unavailable")
            return

        try:
            source = _normalize_latex_source(self._latex_source)
            _dvipng_color(self._latex_background, "#FFFFFF", allow_transparent=True)
            _dvipng_color(self._latex_foreground, "#000000", allow_transparent=False)
        except ValueError as error:
            self._set_latex_error(str(error))
            self._set_latex_status("Error")
            return

        self._set_latex_image_source("")
        self._set_latex_dimensions("")
        self._set_latex_status("Rendering…")
        self._set_latex_rendering(True)

        worker = _LatexWorker(
            source,
            self._latex_resolution,
            self._latex_background,
            self._latex_foreground,
            self,
        )
        worker.finishedResult.connect(self._on_latex_finished)
        worker.failed.connect(self._on_latex_failed)
        worker.finished.connect(worker.deleteLater)
        self._worker = worker
        worker.start()

    @Slot(str, object, int, int)
    def _on_latex_finished(
        self,
        data_url: str,
        png: object,
        width: int,
        height: int,
    ) -> None:
        self._worker = None
        try:
            self._latex_png = bytes(png)
        except (TypeError, ValueError):
            self._latex_png = b""
        self._set_latex_image_source(data_url)
        self._set_latex_dimensions(f"{width} × {height} px")
        self._set_latex_status("Rendered")
        self._set_latex_rendering(False)

    @Slot(str)
    def _on_latex_failed(self, error: str) -> None:
        self._worker = None
        self._set_latex_error(error or "Could not render this formula")
        self._set_latex_image_source("")
        self._set_latex_dimensions("")
        self._set_latex_status("Error")
        self._set_latex_rendering(False)

    @Slot(str)
    def saveLatex(self, path: str) -> None:
        self._set_latex_saved_message("")
        target = str(path or "").strip()
        if target.startswith("file://"):
            target = QUrl(target).toLocalFile()
        if not target:
            self._set_latex_saved_message("Choose where to save the PNG.")
            return
        if not self._latex_png:
            self._set_latex_saved_message("Render a formula first.")
            return

        target_path = Path(target).expanduser()
        if target_path.suffix.lower() != ".png":
            target_path = target_path.with_suffix(".png")

        try:
            target_path.write_bytes(self._latex_png)
        except OSError as error:
            self._set_latex_saved_message(f"Could not save the PNG: {error}")
            return

        self._set_latex_saved_message(f"Saved {target_path.name}")

    @Slot()
    def clear(self) -> None:
        if self._computing or self._latex_rendering:
            return

        if self._mode == LATEX_MODE:
            self.latexSource = ""
            self._latex_png = b""
            self._set_latex_image_source("")
            self._set_latex_dimensions("")
            self._set_latex_error("")
            self._set_latex_saved_message("")
            self._set_latex_status("Ready")
            return

        self.expression = ""
        self._set_result("")
        self._set_error("")
        self._set_status("Ready")

    @Slot()
    def loadExample(self) -> None:
        if self._computing or self._latex_rendering:
            return

        if self._mode == LATEX_MODE:
            self.latexSource = SAMPLE_LATEX
            self._latex_png = b""
            self._set_latex_image_source("")
            self._set_latex_dimensions("")
            self._set_latex_error("")
            self._set_latex_saved_message("")
            self._set_latex_status("Ready")
            return

        self.expression = SAMPLE_EXPRESSIONS.get(self._mode, SAMPLE_EXPRESSION)
        self._set_result("")
        self._set_error("")
        self._set_status("Ready")
