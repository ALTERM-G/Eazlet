"""Text transformations, regex/pattern matching, sorting and text/data conversion.

The heavy lifting lives in module-level pure functions so the behaviour can be
tested without a Qt event loop. ``TextToolsVM`` is a thin Qt wrapper that
returns a uniform result map to QML::

    {"ok": bool, "error": str, "text": str, "count": int,
     "matches": list, "parts": list}
"""

from __future__ import annotations

import csv
import io
import json
import random
import re

from PySide6.QtCore import Property, Slot

from .base_vm import BaseVM

CASE_MODES = ["Upper", "Lower", "Title", "Sentence", "Swap", "Capitalize"]
WHITESPACE_OPTIONS = ["Trim", "Collapse", "Expand tabs"]
REVERSE_UNITS = ["Characters", "Words", "Lines"]
LINE_OPERATIONS = [
    "Remove blank lines",
    "Remove duplicate lines",
    "Trim each line",
    "Number lines",
    "Prefix / suffix",
]
SORT_UNITS = ["Lines", "Words", "Characters", "Columns"]
SORT_KEYS = ["Alphabetic", "Natural", "Numeric", "Length"]
SORT_ORDERS = ["Ascending", "Descending"]
REGEX_FLAGS = ["IgnoreCase", "Multiline", "DotAll"]
DELIMITERS = [
    {"id": "comma", "name": "Comma", "value": ","},
    {"id": "tab", "name": "Tab", "value": "\t"},
    {"id": "semicolon", "name": "Semicolon", "value": ";"},
    {"id": "pipe", "name": "Pipe", "value": "|"},
    {"id": "space", "name": "Space", "value": " "},
]

REGEX_PRESETS = [
    {
        "name": "Email address",
        "pattern": r"[\w.+-]+@[\w-]+\.[\w.-]+",
        "description": "Matches a typical email address.",
    },
    {
        "name": "URL",
        "pattern": r"https?://[^\s]+",
        "description": "Matches an http or https URL.",
    },
    {
        "name": "IPv4 address",
        "pattern": r"\b(?:\d{1,3}\.){3}\d{1,3}\b",
        "description": "Matches a dotted IPv4 address.",
    },
    {
        "name": "Hex colour",
        "pattern": r"#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})\b",
        "description": "Matches a 3 or 6 digit hex colour.",
    },
    {
        "name": "Date YYYY-MM-DD",
        "pattern": r"\b\d{4}-\d{2}-\d{2}\b",
        "description": "Matches an ISO style date.",
    },
    {
        "name": "Number",
        "pattern": r"[-+]?(?:\d+\.?\d*|\.\d+)",
        "description": "Matches an integer or decimal number.",
    },
    {
        "name": "Quoted string",
        "pattern": r'"([^"\\]|\\.)*"',
        "description": "Matches a double quoted string.",
    },
    {
        "name": "Whitespace run",
        "pattern": r"\s+",
        "description": "Matches one or more whitespace characters.",
    },
]

_FLAG_MAP = {
    "IgnoreCase": re.IGNORECASE,
    "Multiline": re.MULTILINE,
    "DotAll": re.DOTALL,
}
_MAX_MATCHES = 500


def result(text: str = "", *, ok: bool = True, error: str = "", count: int = 0,
           matches: list | None = None, parts: list | None = None) -> dict:
    """Build the uniform result map consumed by the QML page."""
    return {
        "ok": ok,
        "error": error,
        "text": text,
        "count": count,
        "matches": matches or [],
        "parts": parts or [],
    }


# --------------------------------------------------------------------------
# Transform
# --------------------------------------------------------------------------
def change_case(text: str, mode: str) -> str:
    if mode == "Upper":
        return text.upper()
    if mode == "Lower":
        return text.lower()
    if mode == "Title":
        return text.title()
    if mode == "Swap":
        return text.swapcase()
    if mode == "Capitalize":
        return text.capitalize()
    if mode == "Sentence":
        lowered = text.lower()
        return re.sub(
            r'(^|[.!?]+["\')]?\s+)([a-z])',
            lambda match: match.group(1) + match.group(2).upper(),
            lowered,
        )
    return text


def normalize_whitespace(text: str, options: list | None = None) -> str:
    options = options or []
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    if "Expand tabs" in options:
        text = text.expandtabs(4)
    if "Collapse" in options:
        text = re.sub(r"[ \t]+", " ", text)
        text = re.sub(r" *\n *", "\n", text)
    if "Trim" in options:
        text = "\n".join(line.strip() for line in text.split("\n"))
    return text


def reverse_text(text: str, unit: str) -> str:
    if unit == "Characters":
        return text[::-1]
    if unit == "Words":
        return " ".join(reversed(text.split()))
    if unit == "Lines":
        return "\n".join(reversed(text.splitlines()))
    return text


def line_operation(text: str, op: str, prefix: str = "", suffix: str = "",
                   number: bool = False, start: int = 1) -> str:
    lines = text.splitlines()
    if op == "Remove blank lines":
        return "\n".join(line for line in lines if line.strip())
    if op == "Remove duplicate lines":
        return "\n".join(dict.fromkeys(lines))
    if op == "Trim each line":
        return "\n".join(line.strip() for line in lines)
    if op == "Number lines":
        return "\n".join(f"{index}. {line}"
                         for index, line in enumerate(lines, start))
    if op == "Prefix / suffix":
        if number:
            return "\n".join(f"{index}. {line}{suffix}"
                             for index, line in enumerate(lines, start))
        return "\n".join(f"{prefix}{line}{suffix}" for line in lines)
    return text


def replace_literal(text: str, find: str, replacement: str,
                    case_sensitive: bool = True, replace_all: bool = True) -> str:
    if not find:
        return text
    flags = 0 if case_sensitive else re.IGNORECASE
    return re.sub(
        re.escape(find),
        lambda _match: replacement,
        text,
        count=0 if replace_all else 1,
        flags=flags,
    )


# --------------------------------------------------------------------------
# Regex & patterns
# --------------------------------------------------------------------------
def compile_pattern(pattern: str, flags: list | None = None) -> re.Pattern:
    mask = 0
    for flag in flags or []:
        mask |= _FLAG_MAP.get(flag, 0)
    return re.compile(pattern, mask)


def regex_find(text: str, pattern: str, flags: list | None = None) -> dict:
    if not pattern:
        return result(ok=False, error="Enter a pattern")
    try:
        compiled = compile_pattern(pattern, flags)
    except re.error as exc:
        return result(ok=False, error=str(exc))

    matches = []
    for match in compiled.finditer(text):
        matches.append({
            "value": match.group(0),
            "start": match.start(),
            "end": match.end(),
            "groups": [group if group is not None else ""
                       for group in match.groups()],
            "named": {name: (value if value is not None else "")
                      for name, value in match.groupdict().items()},
        })
        if len(matches) >= _MAX_MATCHES:
            break
    return result(
        text="\n".join(item["value"] for item in matches),
        count=len(matches),
        matches=matches,
    )


def _expand_replacement(template: str, match: re.Match) -> str:
    """Expand ``\\1`` / ``$1`` / ``${name}`` style group references safely."""
    out: list[str] = []
    index = 0
    while index < len(template):
        char = template[index]
        if char == "\\" and index + 1 < len(template):
            nxt = template[index + 1]
            if nxt.isdigit():
                group_index = int(nxt)
                out.append(match.group(group_index) or ""
                           if group_index <= match.re.groups else "")
                index += 2
                continue
            if nxt == "g" and template[index + 2:index + 3] == "<":
                end = template.find(">", index + 3)
                if end != -1:
                    try:
                        out.append(match.group(template[index + 3:end]) or "")
                    except IndexError:
                        out.append("")
                    index = end + 1
                    continue
            out.append(nxt)
            index += 2
            continue
        if char == "$" and index + 1 < len(template):
            if template[index + 1] == "{":
                end = template.find("}", index + 2)
                if end != -1:
                    try:
                        out.append(match.group(template[index + 2:end]) or "")
                    except IndexError:
                        out.append("")
                    index = end + 1
                    continue
            end = index + 1
            while end < len(template) and (
                template[end].isalnum() or template[end] == "_"
            ):
                end += 1
            token = template[index + 1:end]
            if token.isdigit():
                group_index = int(token)
                out.append(match.group(group_index) or ""
                           if group_index <= match.re.groups else "")
            else:
                try:
                    out.append(match.group(token) or "")
                except IndexError:
                    out.append("")
            index = end
            continue
        out.append(char)
        index += 1
    return "".join(out)


def regex_replace(text: str, pattern: str, replacement: str,
                  flags: list | None = None, replace_all: bool = True) -> dict:
    if not pattern:
        return result(ok=False, error="Enter a pattern")
    try:
        compiled = compile_pattern(pattern, flags)
    except re.error as exc:
        return result(ok=False, error=str(exc))
    try:
        replaced, count = compiled.subn(
            lambda match: _expand_replacement(replacement, match),
            text,
            count=0 if replace_all else 1,
        )
    except re.error as exc:
        return result(ok=False, error=str(exc))
    return result(text=replaced, count=count)


def regex_split(text: str, pattern: str, flags: list | None = None,
                max_split: int = 0) -> dict:
    if not pattern:
        return result(ok=False, error="Enter a pattern")
    try:
        compiled = compile_pattern(pattern, flags)
    except re.error as exc:
        return result(ok=False, error=str(exc))
    parts = compiled.split(text, maxsplit=max_split)
    return result(text="\n".join(parts), count=len(parts), parts=parts)


def multi_replace(text: str, rules: list[dict], *, case_sensitive: bool = False,
                  regex_mode: bool = False, whole_word: bool = False) -> dict:
    """Apply every enabled rule in one pass over the original text.

    Scanning left to right and trying rules in order means the first matching
    rule wins at each position. Replacements are never re-scanned, so swaps
    such as X -> A and A -> X exchange cleanly.
    """
    active: list[tuple[object, str]] = []
    try:
        for rule in rules or []:
            if not isinstance(rule, dict) or rule.get("enabled", True) is False:
                continue
            find = rule.get("find", "")
            if not find:
                continue
            replacement = rule.get("replace", "")
            if regex_mode:
                flags = [] if case_sensitive else ["IgnoreCase"]
                active.append((compile_pattern(find, flags), replacement))
            else:
                active.append((find, replacement))
    except re.error as exc:
        return result(ok=False, error=str(exc))

    if not active:
        return result(ok=False, error="No active rules")

    def is_word_char(char: str) -> bool:
        return char.isalnum() or char == "_"

    out: list[str] = []
    cursor = 0
    count = 0
    index = 0

    while index < len(text):
        chosen = None
        for pattern, replacement in active:
            if regex_mode:
                match = pattern.match(text, index)
                if match is None:
                    continue
                start, end = match.span()
                value = _expand_replacement(replacement, match)
            else:
                candidate = text[index:index + len(pattern)]
                left = candidate if case_sensitive else candidate.casefold()
                right = pattern if case_sensitive else pattern.casefold()
                if left != right:
                    continue
                start, end = index, index + len(pattern)
                value = replacement

            if whole_word:
                before = text[start - 1] if start > 0 else ""
                after = text[end] if end < len(text) else ""
                if is_word_char(before) or is_word_char(after):
                    continue

            chosen = (start, end, value)
            break

        if chosen is None:
            index += 1
            continue

        start, end, value = chosen
        out.append(text[cursor:start])
        out.append(value)
        cursor = end
        count += 1
        index = end if end > index else index + 1

    out.append(text[cursor:])
    return result(text="".join(out), count=count)


def preset_for(name: str) -> dict:
    for preset in REGEX_PRESETS:
        if preset["name"] == name:
            return {"pattern": preset["pattern"],
                    "description": preset["description"]}
    return {"pattern": "", "description": ""}


# --------------------------------------------------------------------------
# Sorters
# --------------------------------------------------------------------------
def _natural_key(value: str, case_sensitive: bool = False) -> list:
    return [int(part) if part.isdigit()
            else (part if case_sensitive else part.casefold())
            for part in re.split(r"(\d+)", value)]


def _numeric_value(value: str) -> float:
    match = re.search(r"[-+]?(?:\d+\.?\d*|\.\d+)", value)
    return float(match.group(0)) if match else float("inf")


def _sort_key(value: str, key: str, case_sensitive: bool):
    if key == "Natural":
        return value if case_sensitive else _natural_key(value)
    if key == "Numeric":
        text = value if case_sensitive else value.casefold()
        return (_numeric_value(value), text)
    if key == "Length":
        text = value if case_sensitive else value.casefold()
        return (len(value), text)
    return value if case_sensitive else value.casefold()


def split_units(text: str, unit: str) -> list[str]:
    if unit == "Words":
        return text.split()
    if unit == "Characters":
        return list(text)
    return text.splitlines()


def join_units(units: list[str], unit: str) -> str:
    if unit == "Words":
        return " ".join(units)
    if unit == "Characters":
        return "".join(units)
    return "\n".join(units)


def sort_text(text: str, unit: str = "Lines", key: str = "Alphabetic",
              order: str = "Ascending", case_sensitive: bool = False,
              unique: bool = False, delimiter: str = ",", column: int = 0,
              secondary_column: int = -1,
              secondary_order: str = "Ascending") -> str:
    lines = text.splitlines()
    units = list(lines) if unit in ("Lines", "Columns") else split_units(text, unit)

    if unique:
        seen: set[str] = set()
        deduped = []
        for item in units:
            marker = item if case_sensitive else item.casefold()
            if marker not in seen:
                seen.add(marker)
                deduped.append(item)
        units = deduped
        if unit == "Columns":
            lines = units

    reverse = order == "Descending"

    if unit == "Columns":
        def cell(index: int, target: int) -> str:
            row = lines[index].split(delimiter)
            return row[target] if 0 <= target < len(row) else ""

        def column_key(index: int):
            return _sort_key(cell(index, column), key, case_sensitive)

        indices = list(range(len(lines)))
        if secondary_column >= 0:
            def secondary_key(index: int):
                return _sort_key(cell(index, secondary_column), key, case_sensitive)
            # Python's sort is stable, so sorting by the secondary key first
            # produces a primary-then-secondary ordering.
            indices.sort(key=secondary_key,
                         reverse=secondary_order == "Descending")
        indices.sort(key=column_key, reverse=reverse)
        return "\n".join(lines[index] for index in indices)

    units.sort(key=lambda item: _sort_key(item, key, case_sensitive),
               reverse=reverse)
    return join_units(units, unit)


def shuffle_text(text: str, unit: str = "Lines", seed: int | None = None) -> str:
    units = split_units(text, unit)
    random.Random(seed).shuffle(units)
    return join_units(units, unit)


# --------------------------------------------------------------------------
# Text <-> data extras
# --------------------------------------------------------------------------
def _parse_delimited(text: str, delimiter: str) -> list[list[str]]:
    delimiter = delimiter or ","
    return [row for row in csv.reader(io.StringIO(text), delimiter=delimiter)
            if row]


def _header_for(rows: list[list[str]], has_header: bool) -> tuple[list[str], list[list[str]]]:
    if has_header and rows:
        return rows[0], rows[1:]
    width = max((len(row) for row in rows), default=0)
    return [f"Column {index + 1}" for index in range(width)], rows


def _pad(row: list[str], width: int) -> list[str]:
    return row + [""] * (width - len(row))


def delimited_to_json(text: str, delimiter: str = ",", has_header: bool = True,
                      pretty: bool = True) -> str:
    rows = _parse_delimited(text, delimiter)
    header, body = _header_for(rows, has_header)
    objects = [dict(zip(header, _pad(row, len(header)), strict=False))
               for row in body]
    return json.dumps(objects, indent=2 if pretty else None, ensure_ascii=False)


def json_to_delimited(text: str, delimiter: str = ",", fields: str = "") -> str:
    data = json.loads(text)
    if isinstance(data, dict):
        data = [data]
    if not isinstance(data, list):
        raise ValueError("JSON must be an object or an array of objects")
    objects = [item for item in data if isinstance(item, dict)]
    if not objects:
        raise ValueError("No JSON objects found")
    names = [name.strip() for name in fields.split(",") if name.strip()]
    if not names:
        names = list(objects[0].keys())
    return "\n".join(
        delimiter.join(str(obj.get(name, "")) for name in names)
        for obj in objects
    )


def delimited_to_markdown(text: str, delimiter: str = ",",
                          has_header: bool = True) -> str:
    rows = _parse_delimited(text, delimiter)
    header, body = _header_for(rows, has_header)
    lines = [
        "| " + " | ".join(header) + " |",
        "| " + " | ".join(["---"] * len(header)) + " |",
    ]
    for row in body:
        lines.append("| " + " | ".join(_pad(row, len(header))) + " |")
    return "\n".join(lines)


def extract_column(text: str, delimiter: str = ",", column: int = 0) -> str:
    rows = _parse_delimited(text, delimiter)
    return "\n".join(row[column] if 0 <= column < len(row) else ""
                     for row in rows)


# --------------------------------------------------------------------------
# Qt wrapper
# --------------------------------------------------------------------------
class TextToolsVM(BaseVM):
    # Stable IDs used by logic/QML comparisons; labels are localized for display.
    @Property(list, constant=True)
    def caseModes(self) -> list[str]:
        return list(CASE_MODES)

    @Property(list, constant=True)
    def caseModeOptions(self) -> list[dict]:
        labels = {
            "Upper": self.tr("options.textTools.case.upper", "Upper"),
            "Lower": self.tr("options.textTools.case.lower", "Lower"),
            "Title": self.tr("options.textTools.case.title", "Title"),
            "Sentence": self.tr("options.textTools.case.sentence", "Sentence"),
            "Swap": self.tr("options.textTools.case.swap", "Swap"),
            "Capitalize": self.tr("options.textTools.case.capitalize", "Capitalize"),
        }
        return [{"id": m, "label": labels.get(m, m)} for m in CASE_MODES]

    @Property(list, constant=True)
    def whitespaceOptions(self) -> list[str]:
        return list(WHITESPACE_OPTIONS)

    @Property(list, constant=True)
    def whitespaceOptionItems(self) -> list[dict]:
        labels = {
            "Trim": self.tr("pages.textTools.trim", "Trim"),
            "Collapse": self.tr("pages.textTools.collapse", "Collapse"),
            "Expand tabs": self.tr("pages.textTools.expandTabs", "Expand tabs"),
        }
        return [{"id": m, "label": labels.get(m, m)} for m in WHITESPACE_OPTIONS]

    @Property(list, constant=True)
    def reverseUnits(self) -> list[str]:
        return list(REVERSE_UNITS)

    @Property(list, constant=True)
    def reverseUnitOptions(self) -> list[dict]:
        labels = {
            "Characters": self.tr("options.textTools.reverse.characters", "Characters"),
            "Words": self.tr("options.textTools.reverse.words", "Words"),
            "Lines": self.tr("options.textTools.reverse.lines", "Lines"),
        }
        return [{"id": m, "label": labels.get(m, m)} for m in REVERSE_UNITS]

    @Property(list, constant=True)
    def lineOperations(self) -> list[str]:
        return list(LINE_OPERATIONS)

    @Property(list, constant=True)
    def lineOperationOptions(self) -> list[dict]:
        labels = {
            "Remove blank lines": self.tr("options.textTools.lineOp.removeBlank", "Remove blank lines"),
            "Remove duplicate lines": self.tr("options.textTools.lineOp.removeDuplicates", "Remove duplicate lines"),
            "Trim each line": self.tr("options.textTools.lineOp.trimEach", "Trim each line"),
            "Number lines": self.tr("options.textTools.lineOp.numberLines", "Number lines"),
            "Prefix / suffix": self.tr("options.textTools.lineOp.prefixSuffix", "Prefix / suffix"),
        }
        return [{"id": m, "label": labels.get(m, m)} for m in LINE_OPERATIONS]

    @Property(list, constant=True)
    def sortUnits(self) -> list[str]:
        return list(SORT_UNITS)

    @Property(list, constant=True)
    def sortUnitOptions(self) -> list[dict]:
        labels = {
            "Lines": self.tr("options.textTools.sortUnit.lines", "Lines"),
            "Words": self.tr("options.textTools.sortUnit.words", "Words"),
            "Characters": self.tr("options.textTools.sortUnit.characters", "Characters"),
            "Columns": self.tr("options.textTools.sortUnit.columns", "Columns"),
        }
        return [{"id": m, "label": labels.get(m, m)} for m in SORT_UNITS]

    @Property(list, constant=True)
    def sortKeys(self) -> list[str]:
        return list(SORT_KEYS)

    @Property(list, constant=True)
    def sortKeyOptions(self) -> list[dict]:
        labels = {
            "Alphabetic": self.tr("options.textTools.sortKey.alphabetic", "Alphabetic"),
            "Natural": self.tr("options.textTools.sortKey.natural", "Natural"),
            "Numeric": self.tr("options.textTools.sortKey.numeric", "Numeric"),
            "Length": self.tr("options.textTools.sortKey.length", "Length"),
        }
        return [{"id": m, "label": labels.get(m, m)} for m in SORT_KEYS]

    @Property(list, constant=True)
    def sortOrders(self) -> list[str]:
        return list(SORT_ORDERS)

    @Property(list, constant=True)
    def sortOrderOptions(self) -> list[dict]:
        labels = {
            "Ascending": self.tr("options.textTools.sortOrder.ascending", "Ascending"),
            "Descending": self.tr("options.textTools.sortOrder.descending", "Descending"),
        }
        return [{"id": m, "label": labels.get(m, m)} for m in SORT_ORDERS]

    @Property(list, constant=True)
    def regexFlags(self) -> list[str]:
        return list(REGEX_FLAGS)

    @Property(list, constant=True)
    def regexFlagOptions(self) -> list[dict]:
        labels = {
            "IgnoreCase": self.tr("options.textTools.regexFlag.ignoreCase", "Ignore case"),
            "Multiline": self.tr("options.textTools.regexFlag.multiline", "Multiline"),
            "DotAll": self.tr("options.textTools.regexFlag.dotAll", "Dot matches newline"),
        }
        return [{"id": m, "label": labels.get(m, m)} for m in REGEX_FLAGS]

    @Property(list, constant=True)
    def regexPresets(self) -> list[str]:
        return [preset["name"] for preset in REGEX_PRESETS]

    @Property(list, constant=True)
    def delimiters(self) -> list[dict]:
        labels = {
            "comma": self.tr("options.textTools.delimiter.comma", "Comma"),
            "tab": self.tr("options.textTools.delimiter.tab", "Tab"),
            "semicolon": self.tr("options.textTools.delimiter.semicolon", "Semicolon"),
            "pipe": self.tr("options.textTools.delimiter.pipe", "Pipe"),
            "space": self.tr("options.textTools.delimiter.space", "Space"),
        }
        out = []
        for item in DELIMITERS:
            row = dict(item)
            row["label"] = labels.get(item.get("id"), item["name"])
            out.append(row)
        return out

    @Slot(str, result=str)
    def presetPattern(self, name: str) -> str:
        return preset_for(name)["pattern"]

    @Slot(str, result=str)
    def presetDescription(self, name: str) -> str:
        return preset_for(name)["description"]

    def _localize_error(self, err: dict) -> dict:
        if err.get("ok", True):
            return err
        msg = err.get("error", "") or ""
        mapping = {
            "Enter a pattern": self.tr("pages.textTools.msgEnterPattern", "Enter a pattern"),
            "No active rules": self.tr("pages.textTools.msgNoActiveRules", "No active rules"),
            "Enter text to find": self.tr("pages.textTools.msgEnterTextToFind", "Enter text to find"),
            "No JSON objects found": self.tr("pages.textTools.msgNoJsonObjects", "No JSON objects found"),
        }
        if msg in mapping:
            err = dict(err)
            err["error"] = mapping[msg]
        return err

    @Slot(str, str, result=dict)
    def applyCase(self, text: str, mode: str) -> dict:
        return result(change_case(text, mode))

    @Slot(str, list, result=dict)
    def applyWhitespace(self, text: str, options: list) -> dict:
        return result(normalize_whitespace(text, options))

    @Slot(str, str, result=dict)
    def applyReverse(self, text: str, unit: str) -> dict:
        return result(reverse_text(text, unit))

    @Slot(str, str, str, str, bool, int, result=dict)
    def applyLineOp(self, text: str, op: str, prefix: str, suffix: str,
                    number: bool, start: int) -> dict:
        return result(line_operation(text, op, prefix, suffix, number, start))

    @Slot(str, str, str, bool, bool, result=dict)
    def replaceLiteral(self, text: str, find: str, replacement: str,
                       case_sensitive: bool, replace_all: bool) -> dict:
        if not find:
            return self._localize_error(result(ok=False, error="Enter text to find"))
        return result(replace_literal(text, find, replacement,
                                      case_sensitive, replace_all))

    @Slot(str, list, bool, bool, bool, result=dict)
    def multiReplace(self, text: str, rules: list, case_sensitive: bool,
                     regex_mode: bool, whole_word: bool) -> dict:
        return self._localize_error(multi_replace(text, rules, case_sensitive=case_sensitive,
                             regex_mode=regex_mode, whole_word=whole_word))

    @Slot(str, str, list, result=dict)
    def findRegex(self, text: str, pattern: str, flags: list) -> dict:
        found = self._localize_error(regex_find(text, pattern, flags))
        if not found["ok"]:
            return found
        return result(text=found["text"], count=found["count"],
                      matches=found["matches"])

    @Slot(str, str, str, list, bool, result=dict)
    def replaceRegex(self, text: str, pattern: str, replacement: str,
                     flags: list, replace_all: bool) -> dict:
        return self._localize_error(regex_replace(text, pattern, replacement, flags, replace_all))

    @Slot(str, str, list, int, result=dict)
    def splitRegex(self, text: str, pattern: str, flags: list,
                   max_split: int) -> dict:
        return self._localize_error(regex_split(text, pattern, flags, max_split))

    @Slot(str, str, str, str, bool, bool, str, int, result=dict)
    def sortText(self, text: str, unit: str, key: str, order: str,
                 case_sensitive: bool, unique: bool, delimiter: str,
                 column: int) -> dict:
        return result(sort_text(text, unit, key, order, case_sensitive,
                                unique, delimiter, column))

    @Slot(str, str, str, str, bool, bool, str, int, int, str, result=dict)
    def sortTextMulti(self, text: str, unit: str, key: str, order: str,
                      case_sensitive: bool, unique: bool, delimiter: str,
                      column: int, secondary_column: int,
                      secondary_order: str) -> dict:
        return result(sort_text(text, unit, key, order, case_sensitive,
                                unique, delimiter, column, secondary_column,
                                secondary_order))

    @Slot(str, str, int, result=dict)
    def shuffleText(self, text: str, unit: str, seed: int) -> dict:
        return result(shuffle_text(text, unit, seed or None))

    @Slot(str, str, bool, bool, result=dict)
    def delimitedToJson(self, text: str, delimiter: str, has_header: bool,
                        pretty: bool) -> dict:
        try:
            return result(delimited_to_json(text, delimiter, has_header, pretty))
        except Exception as exc:  # noqa: BLE001 - surfaced to the UI
            return result(ok=False, error=str(exc))

    @Slot(str, str, str, result=dict)
    def jsonToDelimited(self, text: str, delimiter: str, fields: str) -> dict:
        try:
            return result(json_to_delimited(text, delimiter, fields))
        except Exception as exc:  # noqa: BLE001 - surfaced to the UI
            return result(ok=False, error=str(exc))

    @Slot(str, str, bool, result=dict)
    def delimitedToMarkdown(self, text: str, delimiter: str,
                            has_header: bool) -> dict:
        try:
            return result(delimited_to_markdown(text, delimiter, has_header))
        except Exception as exc:  # noqa: BLE001 - surfaced to the UI
            return result(ok=False, error=str(exc))

    @Slot(str, str, int, result=dict)
    def extractColumn(self, text: str, delimiter: str, column: int) -> dict:
        try:
            return result(extract_column(text, delimiter, column))
        except Exception as exc:  # noqa: BLE001 - surfaced to the UI
            return result(ok=False, error=str(exc))
