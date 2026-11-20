import json
import urllib.error
import urllib.parse
import urllib.request

from PySide6.QtCore import Property, QObject, QThread, Signal, Slot

from .base_vm import BaseVM

API_ROOT = "https://api.dictionaryapi.dev/api/v2/entries/en/"


def _fetch_entries(word: str, timeout: float = 10.0) -> object:
    url = API_ROOT + urllib.parse.quote(word, safe="")
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "Eazlet/1.0",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read()
    except urllib.error.HTTPError as error:
        if error.code == 404:
            raise ValueError(f'No definitions found for "{word}".') from error
        raise ValueError(f"Dictionary lookup failed ({error.code}).") from error
    except urllib.error.URLError as error:
        raise ValueError(f"Could not reach the dictionary service: {error.reason}") from error

    try:
        return json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError("The dictionary returned an unreadable response.") from error


def _parse_entries(payload: object) -> dict:
    if not isinstance(payload, list) or not payload:
        raise ValueError("No definitions found.")

    word = ""
    phonetic = ""
    origin = ""
    order: list[str] = []
    grouped: dict[str, dict] = {}

    for entry in payload:
        if not isinstance(entry, dict):
            continue

        if not word:
            word = str(entry.get("word") or "").strip()
        if not phonetic:
            phonetic = str(entry.get("phonetic") or "").strip()
        if not phonetic:
            for item in entry.get("phonetics") or []:
                if isinstance(item, dict) and str(item.get("text") or "").strip():
                    phonetic = str(item["text"]).strip()
                    break
        if not origin:
            origin = str(entry.get("origin") or "").strip()

        for meaning in entry.get("meanings") or []:
            if not isinstance(meaning, dict):
                continue
            part = str(meaning.get("partOfSpeech") or "other").strip() or "other"
            definitions = []
            for definition in meaning.get("definitions") or []:
                if not isinstance(definition, dict):
                    continue
                text = str(definition.get("definition") or "").strip()
                if not text:
                    continue
                synonyms = [
                    str(item).strip()
                    for item in definition.get("synonyms") or []
                    if str(item).strip()
                ]
                definitions.append(
                    {
                        "definition": text,
                        "example": str(definition.get("example") or "").strip(),
                        "synonyms": synonyms,
                    }
                )
            if not definitions:
                continue
            if part not in grouped:
                grouped[part] = {"partOfSpeech": part, "definitions": []}
                order.append(part)
            grouped[part]["definitions"].extend(definitions)

    if not grouped:
        raise ValueError("No definitions found.")

    return {
        "word": word,
        "phonetic": phonetic,
        "origin": origin,
        "entries": [grouped[part] for part in order],
    }


def _format_output(word: str, phonetic: str, origin: str, entries: list) -> str:
    heading = str(word or "").strip()
    phonetic = str(phonetic or "").strip()
    if phonetic:
        heading = f"{heading}  {phonetic}".strip()

    blocks: list[str] = []
    if heading:
        blocks.append(heading)
    origin = str(origin or "").strip()
    if origin:
        blocks.append(f"Origin: {origin}")

    for entry in entries or []:
        if not isinstance(entry, dict):
            continue
        definitions = entry.get("definitions") or []
        if not definitions:
            continue
        lines = [str(entry.get("partOfSpeech") or "other")]
        for index, definition in enumerate(definitions, start=1):
            if not isinstance(definition, dict):
                continue
            if index > 1:
                lines.append("")
            lines.append(f"{index}. {definition.get('definition') or ''}".rstrip())
            example = str(definition.get("example") or "").strip()
            if example:
                lines.append(f"   \u201C{example}\u201D")
            synonyms = [
                str(item).strip()
                for item in definition.get("synonyms") or []
                if str(item).strip()
            ]
            if synonyms:
                lines.append("   Synonyms: " + ", ".join(synonyms))
        blocks.append("\n".join(lines))

    return "\n\n".join(blocks)


class _DictionaryWorker(QThread):
    finishedResult = Signal(object)
    failed = Signal(str)

    def __init__(self, word: str, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._word = word

    def run(self) -> None:
        try:
            result = _parse_entries(_fetch_entries(self._word))
        except Exception as error:
            self.failed.emit(str(error))
            return
        self.finishedResult.emit(result)


class DictionaryVM(BaseVM):
    wordChanged = Signal()
    statusChanged = Signal()
    errorChanged = Signal()
    searchingChanged = Signal()
    phoneticChanged = Signal()
    entriesChanged = Signal()
    originChanged = Signal()
    outputChanged = Signal()
    hasResultChanged = Signal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._word = ""
        self._status = self.tr("pages.dictionary.msgReady", "Ready")
        self._error = ""
        self._searching = False
        self._phonetic = ""
        self._entries: list = []
        self._origin = ""
        self._output = ""
        self._worker = None

    @Property(str, notify=wordChanged)
    def word(self) -> str:
        return self._word

    @word.setter
    def word(self, value: str) -> None:
        self._set_word(value)

    @Property(str, notify=statusChanged)
    def status(self) -> str:
        return self._status

    @Property(str, notify=errorChanged)
    def error(self) -> str:
        return self._error

    @Property(bool, notify=searchingChanged)
    def searching(self) -> bool:
        return self._searching

    @Property(str, notify=phoneticChanged)
    def phonetic(self) -> str:
        return self._phonetic

    @Property(list, notify=entriesChanged)
    def entries(self) -> list:
        return self._entries

    @Property(str, notify=originChanged)
    def origin(self) -> str:
        return self._origin

    @Property(str, notify=outputChanged)
    def output(self) -> str:
        return self._output

    @Property(bool, notify=hasResultChanged)
    def hasResult(self) -> bool:
        return bool(self._entries)

    def _set_word(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._word:
            self._word = value
            self.wordChanged.emit()
        self._refresh_output()

    def _set_status(self, value: str) -> None:
        if value != self._status:
            self._status = value
            self.statusChanged.emit()

    def _set_error(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._error:
            self._error = value
            self.errorChanged.emit()

    def _set_searching(self, value: bool) -> None:
        if bool(value) != self._searching:
            self._searching = bool(value)
            self.searchingChanged.emit()

    def _set_phonetic(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._phonetic:
            self._phonetic = value
            self.phoneticChanged.emit()
        self._refresh_output()

    def _set_origin(self, value: str) -> None:
        value = value if value is not None else ""
        if value != self._origin:
            self._origin = value
            self.originChanged.emit()
        self._refresh_output()

    def _set_entries(self, value: list) -> None:
        value = list(value or [])
        if value != self._entries:
            had_result = bool(self._entries)
            self._entries = value
            self.entriesChanged.emit()
            if had_result != bool(value):
                self.hasResultChanged.emit()
        self._refresh_output()

    def _refresh_output(self) -> None:
        value = _format_output(self._word, self._phonetic, self._origin, self._entries)
        if value != self._output:
            self._output = value
            self.outputChanged.emit()

    @Slot(str)
    def setWord(self, value: str) -> None:
        self._set_word(value)

    @Slot()
    def search(self) -> None:
        if self._searching:
            return

        word = self._word.strip()
        self._set_error("")
        self._set_phonetic("")
        self._set_origin("")
        self._set_entries([])

        if not word:
            self._set_status(self.tr("pages.dictionary.msgReady", "Ready"))
            self._set_error(
                self.tr(
                    "pages.dictionary.msgEnterWord",
                    "Enter a word to look up.",
                )
            )
            return

        self._set_word(word)
        self._set_status(self.tr("pages.dictionary.msgSearching", "Searching…"))
        self._set_searching(True)

        worker = _DictionaryWorker(word, self)
        worker.finishedResult.connect(self._on_finished)
        worker.failed.connect(self._on_failed)
        worker.finished.connect(worker.deleteLater)
        self._worker = worker
        worker.start()

    @Slot(object)
    def _on_finished(self, result: object) -> None:
        self._worker = None
        data = result if isinstance(result, dict) else {}
        self._set_word(str(data.get("word") or self._word))
        self._set_phonetic(str(data.get("phonetic") or ""))
        self._set_origin(str(data.get("origin") or ""))
        self._set_entries(data.get("entries") or [])
        self._set_status(self.tr("pages.dictionary.msgFound", "Found"))
        self._set_searching(False)
        self.record_history("Dictionary", "Search", self._word, self._output)

    @Slot(str)
    def _on_failed(self, error: str) -> None:
        self._worker = None
        self._set_error(
            error
            or self.tr(
                "pages.dictionary.msgLookupFailed",
                "Could not look up this word.",
            )
        )
        self._set_entries([])
        self._set_status(self.tr("pages.dictionary.msgError", "Error"))
        self._set_searching(False)
        self.record_history("Dictionary", "Search", self._word, self._error)

    @Slot()
    def clear(self) -> None:
        if self._searching:
            return

        self._set_word("")
        self._set_phonetic("")
        self._set_origin("")
        self._set_entries([])
        self._set_error("")
        self._set_status(self.tr("pages.dictionary.msgReady", "Ready"))
