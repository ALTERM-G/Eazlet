from PySide6.QtGui import QGuiApplication

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
    assert vm.insights == []
    assert vm.reportText == ""


def test_insights_and_report_are_generated():
    vm = TextAnalysisVM()
    vm.input = SAMPLE
    vm.process()

    assert len(vm.insights) >= 4
    assert any("Readability" in insight for insight in vm.insights)
    assert any("frequent" in insight for insight in vm.insights)
    assert vm.reportText.startswith("Text Analysis Report")
    assert "Words: 19" in vm.reportText
    assert "Insights:" in vm.reportText
    assert "hello" in vm.reportText


def test_load_sample_populates_input_and_analyzes():
    vm = TextAnalysisVM()
    vm.loadSample()

    assert vm.input == TextAnalysisVM.SAMPLE_TEXT
    assert vm.hasResults is True
    assert vm.status == "Sample loaded"
    assert vm.stats
    assert vm.insights
    assert vm.reportText


def test_load_file_reads_txt_and_analyzes(tmp_path):
    path = tmp_path / "notes.txt"
    path.write_text(SAMPLE, encoding="utf-8")

    vm = TextAnalysisVM()
    vm.loadFile(str(path))

    assert vm.input == SAMPLE
    assert vm.hasResults is True
    assert vm.error == ""
    assert vm.status == "Loaded notes.txt"
    assert vm.stats


def test_load_file_reads_markdown(tmp_path):
    path = tmp_path / "readme.md"
    path.write_text("# Heading\n\nSome analysable words here.", encoding="utf-8")

    vm = TextAnalysisVM()
    vm.loadFile(path.as_uri())

    assert vm.input.startswith("# Heading")
    assert vm.hasResults is True
    assert vm.status == "Loaded readme.md"


def test_load_file_rejects_unsupported_types(tmp_path):
    path = tmp_path / "document.pdf"
    path.write_bytes(b"%PDF-1.7")

    vm = TextAnalysisVM()
    vm.loadFile(str(path))

    assert vm.input == ""
    assert vm.hasResults is False
    assert "Unsupported file type" in vm.error
    assert vm.status == "Nothing loaded"


def test_load_file_reports_missing_file(tmp_path):
    vm = TextAnalysisVM()
    vm.loadFile(str(tmp_path / "missing.txt"))

    assert vm.hasResults is False
    assert vm.error.startswith("Could not read missing.txt")
    assert vm.status == "Nothing loaded"


def test_copy_report_writes_to_clipboard(qtbot):
    vm = TextAnalysisVM()
    vm.input = SAMPLE
    vm.process()

    vm.copyReport()

    clipboard = QGuiApplication.instance().clipboard()
    assert vm.status == "Report copied to clipboard"
    assert clipboard.text() == vm.reportText
