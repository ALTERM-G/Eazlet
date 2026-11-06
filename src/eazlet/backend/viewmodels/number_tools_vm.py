import ctypes
import math
import os
import sys

from PySide6.QtCore import Property, QThread, Signal, Slot
from PySide6.QtGui import QGuiApplication

from .base_vm import BaseVM

_DIGITS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
_DIGIT_MAP = {c: i for i, c in enumerate(_DIGITS)}
_DIGIT_MAP.update({c.lower(): i for i, c in enumerate(_DIGITS) if c.isalpha()})

_INT64_MIN = -(2**63)
_INT64_MAX = 2**63 - 1


def _load_native():
    base = os.path.join(os.path.dirname(__file__), "..", "native")
    candidates = []
    if sys.platform == "win32":
        candidates.append(os.path.join(base, "numbertools.dll"))
    elif sys.platform == "darwin":
        candidates.append(os.path.join(base, "libnumbertools.dylib"))
    candidates.append(os.path.join(base, "libnumbertools.so"))
    for path in candidates:
        path = os.path.abspath(path)
        if os.path.exists(path):
            try:
                lib = ctypes.CDLL(path)
                _bind(lib)
                return lib
            except Exception:
                continue
    return None


def _bind(lib):
    lib.nt_gcd.argtypes = [ctypes.c_int64, ctypes.c_int64]
    lib.nt_gcd.restype = ctypes.c_int64
    lib.nt_lcm.argtypes = [ctypes.c_int64, ctypes.c_int64]
    lib.nt_lcm.restype = ctypes.c_int64
    lib.nt_bezout.argtypes = [
        ctypes.c_int64,
        ctypes.c_int64,
        ctypes.POINTER(ctypes.c_int64),
        ctypes.POINTER(ctypes.c_int64),
    ]
    lib.nt_bezout.restype = ctypes.c_int64
    lib.nt_format_base.argtypes = [ctypes.c_int64, ctypes.c_int]
    lib.nt_format_base.restype = ctypes.c_void_p
    lib.nt_free.argtypes = [ctypes.c_void_p]
    lib.nt_free.restype = None
    lib.nt_factor_create.argtypes = [ctypes.c_int64]
    lib.nt_factor_create.restype = ctypes.c_void_p
    lib.nt_factor_step.argtypes = [ctypes.c_void_p, ctypes.c_int64, ctypes.POINTER(ctypes.c_int)]
    lib.nt_factor_step.restype = ctypes.c_double
    lib.nt_factor_count.argtypes = [ctypes.c_void_p]
    lib.nt_factor_count.restype = ctypes.c_int
    lib.nt_factor_prime.argtypes = [ctypes.c_void_p, ctypes.c_int]
    lib.nt_factor_prime.restype = ctypes.c_uint64
    lib.nt_factor_exp.argtypes = [ctypes.c_void_p, ctypes.c_int]
    lib.nt_factor_exp.restype = ctypes.c_int
    lib.nt_factor_destroy.argtypes = [ctypes.c_void_p]
    lib.nt_factor_destroy.restype = None
    if hasattr(lib, "nt_factor_divisors"):
        lib.nt_factor_divisors.argtypes = [
            ctypes.c_void_p,
            ctypes.POINTER(ctypes.c_uint64),
            ctypes.c_int,
        ]
        lib.nt_factor_divisors.restype = ctypes.c_int
    lib.nt_divisors.argtypes = [ctypes.c_int64, ctypes.POINTER(ctypes.c_uint64), ctypes.c_int]
    lib.nt_divisors.restype = ctypes.c_int


_NATIVE = _load_native()


def _fits_i64(n: int) -> bool:
    return _INT64_MIN <= n <= _INT64_MAX


def _parse_int(text: str, base: int | None = None) -> int:
    s = (text or "").strip().replace("_", "").replace(" ", "")
    if not s:
        raise ValueError("Enter a number")
    sign = 1
    if s[0] == "+":
        s = s[1:]
    elif s[0] == "-":
        sign = -1
        s = s[1:]
    if not s:
        raise ValueError("Enter a number")
    if base is None:
        if s.startswith(("0x", "0X")):
            return sign * int(s, 16)
        if s.startswith(("0b", "0B")):
            return sign * int(s, 2)
        if s.startswith(("0o", "0O")):
            return sign * int(s, 8)
        return sign * int(s, 10)
    if base < 2:
        raise ValueError("Base must be >= 2")
    if base == 16 and s.startswith(("0x", "0X")):
        s = s[2:]
    elif base == 2 and s.startswith(("0b", "0B")):
        s = s[2:]
    elif base == 8 and s.startswith(("0o", "0O")):
        s = s[2:]
    if not s:
        raise ValueError("Enter a number")
    if base <= 36:
        return sign * int(s, base)
    if base > len(_DIGITS):
        raise ValueError(
            f"Input parsing supports bases up to {len(_DIGITS)} (use 0-9A-Za-z digits)"
        )
    n = 0
    for ch in s:
        v = _DIGIT_MAP.get(ch)
        if v is None or v >= base:
            raise ValueError(f"Invalid digit '{ch}' for base {base}")
        n = n * base + v
    return sign * n


def _fmt_base_py(n: int, base: int) -> str:
    if base < 2:
        raise ValueError("Base must be >= 2")
    sign = "-" if n < 0 else ""
    n = abs(n)
    if n == 0:
        return "0"
    if base == 10:
        return sign + str(n)
    if base <= len(_DIGITS):
        out = []
        while n:
            n, r = divmod(n, base)
            out.append(_DIGITS[r])
        return sign + "".join(reversed(out))
    vals = []
    while n:
        n, r = divmod(n, base)
        vals.append(str(r))
    return sign + "(" + " ".join(reversed(vals)) + f")_{base}"


def _fmt_base(n: int, base: int) -> str:
    if _NATIVE is not None and _fits_i64(n):
        try:
            ptr = _NATIVE.nt_format_base(ctypes.c_int64(n), ctypes.c_int(base))
            if ptr:
                s = ctypes.cast(ptr, ctypes.c_char_p).value.decode("utf-8", "replace")
                _NATIVE.nt_free(ptr)
                return s
        except Exception:
            pass
    return _fmt_base_py(n, base)


def _gcd(a: int, b: int) -> int:
    if _NATIVE is not None and _fits_i64(a) and _fits_i64(b):
        try:
            return int(_NATIVE.nt_gcd(ctypes.c_int64(a), ctypes.c_int64(b)))
        except Exception:
            pass
    return math.gcd(a, b)


def _lcm(a: int, b: int) -> int:
    a, b = abs(a), abs(b)
    if a == 0 or b == 0:
        return 0
    return abs(a // math.gcd(a, b) * b)


def _bezout(a: int, b: int):
    if _NATIVE is not None and _fits_i64(a) and _fits_i64(b):
        try:
            x = ctypes.c_int64()
            y = ctypes.c_int64()
            g = int(
                _NATIVE.nt_bezout(
                    ctypes.c_int64(a), ctypes.c_int64(b), ctypes.byref(x), ctypes.byref(y)
                )
            )
            return g, int(x.value), int(y.value)
        except Exception:
            pass
    old_r, r = a, b
    old_s, s = 1, 0
    old_t, t = 0, 1
    while r != 0:
        q = old_r // r
        old_r, r = r, old_r - q * r
        old_s, s = s, old_s - q * s
        old_t, t = t, old_t - q * t
    if old_r < 0:
        old_r, old_s, old_t = -old_r, -old_s, -old_t
    return old_r, old_s, old_t


def _is_prime_py(n: int) -> bool:
    if n < 2:
        return False
    small = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37)
    for p in small:
        if n == p:
            return True
        if n % p == 0:
            return False
    d = n - 1
    s = 0
    while d % 2 == 0:
        d //= 2
        s += 1
    # deterministic for < 2^64; a few extra bases give high confidence beyond
    bases = (2, 325, 9375, 28178, 450775, 9780504, 1795265022)
    for a in bases:
        if a % n == 0:
            continue
        x = pow(a, d, n)
        if x == 1 or x == n - 1:
            continue
        for _ in range(s - 1):
            x = (x * x) % n
            if x == n - 1:
                break
        else:
            return False
    return True


def _pollard_rho_py(n: int, seed: int = 2) -> int:
    if n % 2 == 0:
        return 2
    if n % 3 == 0:
        return 3
    c = seed
    x = 2
    y = 2
    d = 1
    while d == 1:
        x = (x * x + c) % n
        y = (y * y + c) % n
        y = (y * y + c) % n
        d = math.gcd(abs(x - y), n)
        if d == n:
            c += 1
            x = y = 2
            d = 1
    return d


def _factor_rec_py(n: int, out: list[int]) -> None:
    if n == 1:
        return
    if _is_prime_py(n):
        out.append(n)
        return
    d = _pollard_rho_py(n)
    if d == n:
        for seed in range(3, 64):
            d = _pollard_rho_py(n, seed)
            if d != n and d != 1:
                break
    if d == n or d == 1:
        f = 2
        while f * f <= n and n % f:
            f = 3 if f == 2 else f + 2
        if f * f > n:
            out.append(n)
            return
        d = f
    _factor_rec_py(d, out)
    _factor_rec_py(n // d, out)


def _prime_factors_py(n: int) -> list[tuple[int, int]]:
    n = abs(n)
    if n < 2:
        return []
    out: list[tuple[int, int]] = []
    # Strip small primes first: avoids deep recursion for things like 2**1000
    # and makes ordinary inputs with small factors very fast.
    for p in (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37):
        if n % p == 0:
            c = 0
            while n % p == 0:
                n //= p
                c += 1
            out.append((p, c))
    if n == 1:
        return out
    raw: list[int] = []
    _factor_rec_py(n, raw)
    raw.sort()
    for p in raw:
        if out and out[-1][0] == p:
            out[-1] = (p, out[-1][1] + 1)
        else:
            out.append((p, 1))
    return out


def _divisors_from_factors_py(pf: list[tuple[int, int]], limit: int = 200000) -> list[int]:
    divs = [1]
    for p, e in pf:
        base = len(divs)
        pe = 1
        for _ in range(e):
            pe *= p
            for i in range(base):
                if len(divs) >= limit:
                    divs.sort()
                    return divs
                divs.append(divs[i] * pe)
    divs.sort()
    return divs


def _divisors_py(n: int) -> list[int]:
    n = abs(n)
    if n == 0:
        return []
    return _divisors_from_factors_py(_prime_factors_py(n))


class _FactorWorker(QThread):
    progressed = Signal(float)
    finishedResult = Signal(object, object, str)

    def __init__(self, n: int, parent=None):
        super().__init__(parent)
        self._n = n

    def run(self):
        try:
            n = self._n
            an = abs(n)
            if an < 2:
                pf = [] if an < 2 else [(an, 1)]
                divs = [1] if an == 1 else []
                self.progressed.emit(1.0)
                self.finishedResult.emit(pf, divs, "")
                return
            if _NATIVE is not None and _fits_i64(an):
                st = _NATIVE.nt_factor_create(ctypes.c_int64(an))
                if not st:
                    raise RuntimeError("Native factorization failed to initialize")
                try:
                    done = ctypes.c_int(0)
                    budget = 500000
                    while not done.value:
                        prog = float(
                            _NATIVE.nt_factor_step(
                                st, ctypes.c_int64(budget), ctypes.byref(done)
                            )
                        )
                        self.progressed.emit(prog)
                    count = int(_NATIVE.nt_factor_count(st))
                    pf = []
                    for i in range(count):
                        p = int(_NATIVE.nt_factor_prime(st, i))
                        e = int(_NATIVE.nt_factor_exp(st, i))
                        pf.append((p, e))
                    if hasattr(_NATIVE, "nt_factor_divisors"):
                        total = int(_NATIVE.nt_factor_divisors(st, None, 0))
                        cap = min(total, 200000)
                        if cap > 0:
                            arr = (ctypes.c_uint64 * cap)()
                            _NATIVE.nt_factor_divisors(st, arr, cap)
                            divs = [int(arr[i]) for i in range(min(total, cap))]
                        else:
                            divs = []
                    else:
                        # Older native lib: generate divisors from factors instead of
                        # trial-dividing n (which is extremely slow for large n).
                        divs = _divisors_from_factors_py(pf)
                finally:
                    _NATIVE.nt_factor_destroy(st)
                self.progressed.emit(1.0)
                self.finishedResult.emit(pf, divs, "")
                return
            pf = _prime_factors_py(an)
            self.progressed.emit(0.7)
            divs = _divisors_from_factors_py(pf)
            self.progressed.emit(1.0)
            self.finishedResult.emit(pf, divs, "")
        except Exception as e:
            self.finishedResult.emit([], [], str(e))


class NumberToolsVM(BaseVM):
    modeChanged = Signal()
    inputAChanged = Signal()
    inputBChanged = Signal()
    fromBaseChanged = Signal()
    toBaseChanged = Signal()
    customFromBaseChanged = Signal()
    customToBaseChanged = Signal()
    operationChanged = Signal()
    outputChanged = Signal()
    statusChanged = Signal()
    errorChanged = Signal()
    computingChanged = Signal()
    progressChanged = Signal()

    MODES = ["Base converter", "GCD / LCM", "Factors & divisors", "Operations"]
    OPS = ["+", "−", "×", "÷", "mod", "pow"]
    BASES = ["Auto", "2 (bin)", "8 (oct)", "10 (dec)", "16 (hex)", "36", "Custom"]
    TO_BASES = ["2 (bin)", "8 (oct)", "10 (dec)", "16 (hex)", "All common", "36", "Custom"]

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self._mode = self.MODES[0]
        self._input_a = ""
        self._input_b = ""
        self._from_base = "Auto"
        self._custom_from_base = "10"
        self._to_base = "All common"
        self._custom_to_base = "43"
        self._operation = "+"
        self._output = ""
        self._status = "Idle"
        self._error = ""
        self._computing = False
        self._progress = 0.0
        self._worker = None
        self._factors_n = 0

    @Property(str, notify=modeChanged)
    def mode(self) -> str:
        return self._mode

    @mode.setter
    def mode(self, value: str) -> None:
        value = value or self.MODES[0]
        if value != self._mode:
            self._mode = value
            self.modeChanged.emit()

    @Property(str, notify=inputAChanged)
    def inputA(self) -> str:
        return self._input_a

    @inputA.setter
    def inputA(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._input_a:
            self._input_a = value
            self.inputAChanged.emit()

    @Property(str, notify=inputBChanged)
    def inputB(self) -> str:
        return self._input_b

    @inputB.setter
    def inputB(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._input_b:
            self._input_b = value
            self.inputBChanged.emit()

    @Property(str, notify=fromBaseChanged)
    def fromBase(self) -> str:
        return self._from_base

    @fromBase.setter
    def fromBase(self, value: str) -> None:
        value = value or "Auto"
        if value != self._from_base:
            self._from_base = value
            self.fromBaseChanged.emit()

    @Property(str, notify=customFromBaseChanged)
    def customFromBase(self) -> str:
        return self._custom_from_base

    @customFromBase.setter
    def customFromBase(self, value: str) -> None:
        value = (value if value is not None else "").strip()
        if value != self._custom_from_base:
            self._custom_from_base = value
            self.customFromBaseChanged.emit()

    @Property(str, notify=toBaseChanged)
    def toBase(self) -> str:
        return self._to_base

    @toBase.setter
    def toBase(self, value: str) -> None:
        value = value or "All common"
        if value != self._to_base:
            self._to_base = value
            self.toBaseChanged.emit()

    @Property(str, notify=customToBaseChanged)
    def customToBase(self) -> str:
        return self._custom_to_base

    @customToBase.setter
    def customToBase(self, value: str) -> None:
        value = (value if value is not None else "").strip()
        if value != self._custom_to_base:
            self._custom_to_base = value
            self.customToBaseChanged.emit()

    @Property(str, notify=operationChanged)
    def operation(self) -> str:
        return self._operation

    @operation.setter
    def operation(self, value: str) -> None:
        value = value or "+"
        if value != self._operation:
            self._operation = value
            self.operationChanged.emit()

    @Property(str, notify=outputChanged)
    def output(self) -> str:
        return self._output

    @Property(str, notify=statusChanged)
    def status(self) -> str:
        return self._status

    @Property(str, notify=errorChanged)
    def error(self) -> str:
        return self._error

    @Property(bool, notify=computingChanged)
    def computing(self) -> bool:
        return self._computing

    @Property(float, notify=progressChanged)
    def progress(self) -> float:
        return self._progress

    @Property(list, constant=True)
    def modes(self) -> list:
        return list(self.MODES)

    @Property(list, constant=True)
    def operations(self) -> list:
        return list(self.OPS)

    @Property(list, constant=True)
    def fromBases(self) -> list:
        return list(self.BASES)

    @Property(list, constant=True)
    def toBases(self) -> list:
        return list(self.TO_BASES)

    def _set_status(self, value: str) -> None:
        if value != self._status:
            self._status = value
            self.statusChanged.emit()

    def _set_error(self, value: str) -> None:
        value = value or ""
        if value != self._error:
            self._error = value
            self.errorChanged.emit()

    def _set_output(self, value: str) -> None:
        value = value or ""
        if value != self._output:
            self._output = value
            self.outputChanged.emit()

    def _set_computing(self, value: bool) -> None:
        if value != self._computing:
            self._computing = value
            self.computingChanged.emit()

    def _set_progress(self, value: float) -> None:
        value = max(0.0, min(1.0, float(value)))
        if abs(value - self._progress) > 1e-6:
            self._progress = value
            self.progressChanged.emit()

    def _custom_base_value(self, which: str) -> int:
        raw = self._custom_to_base if which == "to" else self._custom_from_base
        try:
            b = int(str(raw).strip())
        except Exception as e:
            raise ValueError("Enter a valid custom base (integer >= 2)") from e
        if b < 2:
            raise ValueError("Custom base must be >= 2")
        return b

    def _base_num(self, label: str, which: str = "to") -> int | None:
        if not label or label == "Auto":
            return None
        if label.startswith("2"):
            return 2
        if label.startswith("8"):
            return 8
        if label.startswith("10"):
            return 10
        if label.startswith("16"):
            return 16
        if label.startswith("36"):
            return 36
        if label == "Custom":
            return self._custom_base_value(which)
        return None

    def _parse_a(self) -> int:
        return _parse_int(self._input_a, self._base_num(self._from_base, "from"))

    def _parse_b(self) -> int:
        return _parse_int(self._input_b, self._base_num(self._from_base, "from"))

    @Slot(str)
    def setMode(self, value: str) -> None:
        self.mode = value

    @Slot(str)
    def setInputA(self, value: str) -> None:
        self.inputA = value

    @Slot(str)
    def setInputB(self, value: str) -> None:
        self.inputB = value

    @Slot(str)
    def setFromBase(self, value: str) -> None:
        self.fromBase = value

    @Slot(str)
    def setCustomFromBase(self, value: str) -> None:
        self.customFromBase = value

    @Slot(str)
    def setToBase(self, value: str) -> None:
        self.toBase = value

    @Slot(str)
    def setCustomToBase(self, value: str) -> None:
        self.customToBase = value

    @Slot(str)
    def setOperation(self, value: str) -> None:
        self.operation = value

    @Slot()
    def process(self) -> None:
        if self._computing:
            return
        self._set_error("")
        try:
            if self._mode == "Base converter":
                self._run_base()
            elif self._mode == "GCD / LCM":
                self._run_gcd_lcm()
            elif self._mode == "Factors & divisors":
                self._start_factors()
            elif self._mode == "Operations":
                self._run_ops()
            else:
                self._set_output("")
                self._set_status("Unknown mode")
        except Exception as e:
            self._set_error(str(e))
            self._set_output("")
            self._set_status("Error")
            self._set_computing(False)

    def _run_base(self) -> None:
        n = self._parse_a()
        to = self._to_base
        if to == "All common":
            lines = [
                f"Decimal (10): {n}",
                f"Binary  (2):  {_fmt_base(n, 2)}",
                f"Octal   (8):  {_fmt_base(n, 8)}",
                f"Hex     (16): {_fmt_base(n, 16)}",
            ]
            self._set_output("\n".join(lines))
        else:
            b = self._base_num(to, "to")
            if b is None:
                b = 10
            self._set_output(f"Base {b}: {_fmt_base(n, b)}")
        self._set_status("Done")

    def _parse_int_list(self) -> list[int]:
        raw = (self._input_a or "").replace(",", " ").replace(";", " ")
        parts = [p for p in raw.split() if p]
        if not parts:
            raise ValueError("Enter at least one integer")
        base = self._base_num(self._from_base, "from")
        return [_parse_int(p, base) for p in parts]

    def _run_gcd_lcm(self) -> None:
        nums = self._parse_int_list()
        if len(nums) < 2 and self._input_b.strip():
            nums.append(self._parse_b())
        if len(nums) < 2:
            raise ValueError(
                "Enter at least two integers (space/comma separated, or use both fields)"
            )
        g = nums[0]
        for x in nums[1:]:
            g = _gcd(g, x)
        g = abs(g)
        lcm = abs(nums[0])
        for x in nums[1:]:
            lcm = _lcm(lcm, x)
        lines = [
            f"Numbers: {', '.join(str(x) for x in nums)}",
            f"GCD (PGCD): {g}",
            f"LCM (PPCM): {lcm}",
        ]
        if len(nums) == 2 and g != 0:
            a, b = nums[0], nums[1]
            gg, s, t = _bezout(a, b)
            lines.append(f"Bézout: {a}*({s}) + {b}*({t}) = {gg}")
        self._set_output("\n".join(lines))
        self._set_status("Done")

    def _start_factors(self) -> None:
        n = self._parse_a()
        if n == 0:
            self._set_output("0 has no prime factorization; every non-zero integer divides 0.")
            self._set_status("Done")
            self._set_progress(1.0)
            return
        self._factors_n = n
        self._set_computing(True)
        self._set_progress(0.0)
        self._set_status("Computing…")
        self._set_output("")
        worker = _FactorWorker(n, self)
        worker.progressed.connect(self._on_factor_progress)
        worker.finishedResult.connect(self._on_factor_finished)
        worker.finished.connect(worker.deleteLater)
        self._worker = worker
        worker.start()

    @Slot(float)
    def _on_factor_progress(self, value: float) -> None:
        self._set_progress(value)

    @Slot(object, object, str)
    def _on_factor_finished(self, pf, divs, error: str) -> None:
        self._set_computing(False)
        self._set_progress(1.0)
        self._worker = None
        if error:
            self._set_error(error)
            self._set_output("")
            self._set_status("Error")
            return
        n = self._factors_n
        an = abs(n)
        if an == 1:
            pf_s = "1 (no prime factors)"
            is_prime = False
        elif len(pf) == 1 and pf[0][1] == 1:
            pf_s = f"{an} (prime)"
            is_prime = True
        else:
            pf_s = " × ".join(f"{p}^{e}" if e > 1 else str(p) for p, e in pf)
            is_prime = False
        divs_list = list(divs) if divs else []
        div_count = 1
        for _, e in pf:
            div_count *= e + 1
        lines = [
            f"n: {n}",
            f"Prime: {'yes' if is_prime else 'no'}" if an > 1 else "Prime: n/a (|n| < 2)",
            f"Prime factorization (|n|): {pf_s}",
            f"Number of divisors (|n|): {div_count}",
            "Divisors (|n|): "
            + ", ".join(str(d) for d in divs_list[:60])
            + ("…" if div_count > 60 else ""),
        ]
        self._set_output("\n".join(lines))
        self._set_status("Done")

    def _run_ops(self) -> None:
        a = self._parse_a()
        b = self._parse_b()
        op = self._operation
        if op == "+":
            r = a + b
            res = f"{a} + {b} = {r}"
        elif op == "−":
            r = a - b
            res = f"{a} − {b} = {r}"
        elif op == "×":
            r = a * b
            res = f"{a} × {b} = {r}"
        elif op == "÷":
            if b == 0:
                raise ValueError("Division by zero")
            q, rem = divmod(a, b)
            res = f"{a} ÷ {b} = {q} remainder {rem}\n(Exact: {a}/{b})"
        elif op == "mod":
            if b == 0:
                raise ValueError("Modulo by zero")
            res = f"{a} mod {b} = {a % b}"
        elif op == "pow":
            r = pow(a, b)
            res = f"{a} ^ {b} = {r}"
        else:
            raise ValueError("Unknown operation")
        try:
            if op == "÷":
                primary = divmod(a, b)[0]
                lines = [
                    res,
                    f"Quotient bin: {_fmt_base(primary, 2)}",
                    f"Quotient hex: {_fmt_base(primary, 16)}",
                ]
            else:
                primary = r
                lines = [
                    res,
                    f"Binary: {_fmt_base(primary, 2)}",
                    f"Octal:  {_fmt_base(primary, 8)}",
                    f"Hex:    {_fmt_base(primary, 16)}",
                ]
        except Exception:
            lines = [res]
        self._set_output("\n".join(lines))
        self._set_status("Done")

    @Slot()
    def processAction(self) -> None:
        self.process()

    @Slot()
    def clear(self) -> None:
        if self._computing:
            return
        self.inputA = ""
        self.inputB = ""
        self._set_output("")
        self._set_error("")
        self._set_status("Idle")
        self._set_progress(0.0)

    @Slot()
    def copyOutput(self) -> None:
        if not self._output:
            return
        try:
            QGuiApplication.clipboard().setText(self._output)
            self._set_status("Copied")
        except Exception as e:
            self._set_error(str(e))
