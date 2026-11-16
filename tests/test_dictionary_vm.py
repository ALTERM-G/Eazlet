import pytest

from eazlet.backend.viewmodels import dictionary_vm
from eazlet.backend.viewmodels.dictionary_vm import DictionaryVM, _parse_entries

SAMPLE_PAYLOAD = [
    {
        "word": "hello",
        "phonetic": "həˈləʊ",
        "origin": "early 19th century",
        "meanings": [
            {
                "partOfSpeech": "noun",
                "definitions": [
                    {
                        "definition": "an utterance of hello",
                        "example": "she said hello",
                        "synonyms": ["greeting", " "],
                    }
                ],
            },
            {
                "partOfSpeech": "verb",
                "definitions": [
                    {"definition": "say hello to", "synonyms": []},
                ],
            },
        ],
    },
    {
        "word": "hello",
        "phonetics": [{"text": "/həˈloʊ/"}],
        "meanings": [
            {
                "partOfSpeech": "noun",
                "definitions": [
                    {"definition": "a greeting", "example": "", "synonyms": []},
                ],
            }
        ],
    },
]


def test_parse_entries_groups_by_part_of_speech():
    result = _parse_entries(SAMPLE_PAYLOAD)

    assert result["word"] == "hello"
    assert result["phonetic"] == "həˈləʊ"
    assert result["origin"] == "early 19th century"
    assert [entry["partOfSpeech"] for entry in result["entries"]] == ["noun", "verb"]

    noun = result["entries"][0]
    assert len(noun["definitions"]) == 2
    assert noun["definitions"][0] == {
        "definition": "an utterance of hello",
        "example": "she said hello",
        "synonyms": ["greeting"],
    }
    assert noun["definitions"][1]["definition"] == "a greeting"


def test_parse_entries_falls_back_to_phonetics_text():
    payload = [
        {
            "word": "hello",
            "phonetics": [{"text": ""}, {"text": "/həˈloʊ/"}],
            "meanings": [
                {
                    "partOfSpeech": "noun",
                    "definitions": [{"definition": "a greeting"}],
                }
            ],
        }
    ]

    assert _parse_entries(payload)["phonetic"] == "/həˈloʊ/"


def test_parse_entries_skips_empty_definitions_and_missing_fields():
    payload = [
        {
            "meanings": [
                {
                    "partOfSpeech": "noun",
                    "definitions": [
                        {"definition": ""},
                        {"example": "no text"},
                        {"definition": "usable"},
                    ],
                },
                {"partOfSpeech": "verb", "definitions": []},
            ]
        }
    ]

    result = _parse_entries(payload)
    assert result["word"] == ""
    assert result["phonetic"] == ""
    assert result["origin"] == ""
    assert len(result["entries"]) == 1
    assert result["entries"][0]["partOfSpeech"] == "noun"
    assert [d["definition"] for d in result["entries"][0]["definitions"]] == ["usable"]


@pytest.mark.parametrize("payload", [[], {}, {"title": "No Definitions Found"}, None])
def test_parse_entries_rejects_payloads_without_definitions(payload):
    with pytest.raises(ValueError):
        _parse_entries(payload)


def test_vm_requires_a_word():
    vm = DictionaryVM()
    vm.search()

    assert vm.searching is False
    assert vm.hasResult is False
    assert vm.status == "Ready"
    assert vm.error == "Enter a word to look up."


def test_vm_reports_fetch_failure(monkeypatch, qtbot):
    def fail(word):
        raise ValueError('No definitions found for "zzzz".')

    monkeypatch.setattr(dictionary_vm, "_fetch_entries", fail)

    vm = DictionaryVM()
    vm.setWord("zzzz")
    vm.search()

    with qtbot.waitSignal(vm.errorChanged, timeout=5000):
        pass

    assert vm.searching is False
    assert vm.hasResult is False
    assert vm.status == "Error"
    assert "No definitions" in vm.error


def test_format_output_renders_a_single_selectable_block():
    result = _parse_entries(SAMPLE_PAYLOAD)

    text = dictionary_vm._format_output(
        result["word"], result["phonetic"], result["origin"], result["entries"]
    )

    assert text.splitlines()[0] == "hello  həˈləʊ"
    assert "Origin: early 19th century" in text
    assert "\nnoun\n1. an utterance of hello" in text
    assert '   \u201Cshe said hello\u201D' in text
    assert "   Synonyms: greeting" in text
    assert "\nverb\n1. say hello to" in text


def test_vm_searches_in_worker(monkeypatch, qtbot):
    monkeypatch.setattr(
        dictionary_vm, "_fetch_entries", lambda word: SAMPLE_PAYLOAD
    )

    vm = DictionaryVM()
    vm.setWord("hello")
    vm.search()

    with qtbot.waitSignal(vm.hasResultChanged, timeout=5000):
        pass

    assert vm.searching is False
    assert vm.error == ""
    assert vm.status == "Found"
    assert vm.hasResult is True
    assert vm.phonetic == "həˈləʊ"
    assert vm.origin == "early 19th century"
    assert vm.entries[0]["partOfSpeech"] == "noun"
    assert len(vm.entries[0]["definitions"]) == 2
    assert vm.output.startswith("hello  həˈləʊ")
    assert "1. an utterance of hello" in vm.output


def test_vm_trims_the_search_word(monkeypatch, qtbot):
    seen = {}

    def fetch(word):
        seen["word"] = word
        return SAMPLE_PAYLOAD

    monkeypatch.setattr(dictionary_vm, "_fetch_entries", fetch)

    vm = DictionaryVM()
    vm.setWord("  hello  ")
    vm.search()

    with qtbot.waitSignal(vm.hasResultChanged, timeout=5000):
        pass

    assert seen["word"] == "hello"
    assert vm.word == "hello"


def test_vm_clear(monkeypatch, qtbot):
    monkeypatch.setattr(
        dictionary_vm,
        "_fetch_entries",
        lambda word: [{**entry, "word": word} for entry in SAMPLE_PAYLOAD],
    )

    vm = DictionaryVM()
    vm.setWord("serendipity")
    vm.search()

    with qtbot.waitSignal(vm.hasResultChanged, timeout=5000):
        pass

    assert vm.word == "serendipity"
    assert vm.hasResult is True

    vm.clear()

    assert vm.word == ""
    assert vm.entries == []
    assert vm.hasResult is False
    assert vm.phonetic == ""
    assert vm.origin == ""
    assert vm.output == ""
    assert vm.error == ""
    assert vm.status == "Ready"
