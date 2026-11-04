from eazlet.backend.viewmodels.text_analysis_vm import TextAnalysisVM


SAMPLE = (
    "Hello world. Hello there!\n\n"
    "This is a simple test of the text analyzer. "
    "It counts words, sentences, and more."
)


def test_blank_input_clears_results():
    vm = TextAnalysisVM()
    vm.process()
    assert vm.hasResults is False
    assert vm.status == "Nothing to analyze"
    assert vm.stats == []


def test_analysis_reports_counts_and_charts():
    vm = TextAnalysisVM()
    vm.input = SAMPLE
    vm.process()

    assert vm.hasResults is True
    assert vm.error == ""
    values = {item["label"]: item["value"] for item in vm.stats}
    assert values["Words"] == "19"
    assert values["Sentences"] == "4"
    assert values["Paragraphs"] == "2"
    assert values["Unique words"] == "18"
    assert 0 <= float(values["Readability"]) <= 100

    assert vm.topWords[0] == {"word": "hello", "count": 2}
    assert vm.topWordMax == 2
    assert sum(item["count"] for item in vm.wordLengths) == 19
    assert sum(item["value"] for item in vm.characterComposition) == len(SAMPLE)
    assert vm.characterTotal == len(SAMPLE)
    assert [item["length"] for item in vm.longestWords] == sorted(
        (item["length"] for item in vm.longestWords), reverse=True
    )
    assert vm.readabilityLabel


def test_punctuation_only_input_is_rejected():
    vm = TextAnalysisVM()
    vm.input = "!!! ... ???"
    vm.process()
    assert vm.hasResults is False
    assert vm.error == "No words found in the input"


def test_clear_resets_everything():
    vm = TextAnalysisVM()
    vm.input = SAMPLE
    vm.process()
    vm.clear()

    assert vm.input == ""
    assert vm.hasResults is False
    assert vm.stats == []
    assert vm.topWords == []
    assert vm.wordLengths == []
    assert vm.characterComposition == []
    assert vm.status == "Waiting for text"
