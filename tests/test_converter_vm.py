import zipfile
from pathlib import Path

import pytest

from eazlet.backend.viewmodels.converter_vm import ConverterVM

DOC_TARGETS = {
    "txt": ["md", "html", "pdf"],
    "md": ["txt", "html", "pdf"],
    "html": ["txt", "md", "pdf"],
    "docx": ["txt", "md", "html", "pdf"],
    "odt": ["txt", "md", "html", "pdf"],
    "rtf": ["txt", "md", "html", "pdf"],
    "pdf": ["txt", "md", "html"],
}


@pytest.fixture
def vm(monkeypatch):
    monkeypatch.setattr(ConverterVM, "_probe_encoders", lambda self: None)
    monkeypatch.setattr(ConverterVM, "_format_available", lambda self, fmt: True)
    monkeypatch.setattr(ConverterVM, "DOC_TARGETS", DOC_TARGETS)
    return ConverterVM()


def test_add_file_replaces_the_previous_file(vm):
    vm.addFile("/tmp/clip.mp4")
    assert len(vm.files) == 1
    assert vm.sourceFormat == "mp4"
    assert vm.sourceCategory == "video"

    vm.addFile("/tmp/song.mp3")
    assert len(vm.files) == 1
    assert vm.files[0]["path"] == "/tmp/song.mp3"
    assert vm.sourceFormat == "mp3"
    assert vm.sourceCategory == "audio"


def test_file_urls_are_decoded(vm):
    vm.addFile("file:///tmp/my%20video.mp4")

    assert vm.files[0]["path"] == "/tmp/my video.mp4"
    assert vm.files[0]["name"] == "my video.mp4"
    assert vm.sourceFormat == "mp4"


def test_video_targets_include_video_and_audio_but_not_the_source(vm):
    vm.addFile("movie.mkv")

    targets = vm.validTargetFormats
    assert "mp4" in targets
    assert "webm" in targets
    assert "mp3" in targets
    assert "flac" in targets
    assert "mkv" not in targets
    assert vm.targetFormat == targets[0]


def test_audio_targets_only_contain_audio_formats(vm):
    vm.addFile("track.flac")

    targets = vm.validTargetFormats
    assert targets
    assert set(targets) <= set(ConverterVM.AUDIO_FORMATS)
    assert "flac" not in targets
    assert "mp4" not in targets


def test_image_aliases_are_canonicalized(vm):
    vm.addFile("photo.JPEG")

    assert vm.sourceFormat == "jpg"
    assert vm.sourceCategory == "image"
    assert "jpg" not in vm.validTargetFormats
    assert "jpeg" not in vm.validTargetFormats
    assert "png" in vm.validTargetFormats


def test_document_target_matrix(vm):
    vm.addFile("notes.txt")
    assert vm.validTargetFormats == ["md", "html", "pdf"]

    vm.addFile("readme.markdown")
    assert vm.sourceFormat == "md"
    assert vm.validTargetFormats == ["txt", "html", "pdf"]

    vm.addFile("page.htm")
    assert vm.sourceFormat == "html"
    assert vm.validTargetFormats == ["txt", "md", "pdf"]

    vm.addFile("manual.pdf")
    assert vm.sourceFormat == "pdf"
    assert vm.validTargetFormats == ["txt", "md", "html"]

    vm.addFile("report.docx")
    assert vm.sourceFormat == "docx"
    assert vm.sourceCategory == "document"
    assert vm.validTargetFormats == ["txt", "md", "html", "pdf"]

    vm.addFile("letter.odt")
    assert vm.sourceCategory == "document"
    assert vm.validTargetFormats == ["txt", "md", "html", "pdf"]

    vm.addFile("memo.rtf")
    assert vm.sourceCategory == "document"
    assert vm.validTargetFormats == ["txt", "md", "html", "pdf"]


def test_svg_is_an_image_input(vm):
    vm.addFile("icon.svg")

    assert vm.sourceFormat == "svg"
    assert vm.sourceCategory == "image"
    assert "png" in vm.validTargetFormats
    assert "jpg" in vm.validTargetFormats
    assert "svg" not in vm.validTargetFormats


def test_unsupported_file_has_no_targets(vm):
    vm.addFile("data.xyz")

    assert vm.sourceFormat == "xyz"
    assert vm.sourceCategory == "unsupported"
    assert vm.validTargetFormats == []
    assert vm.targetFormat == ""
    assert vm.status == "Unsupported file type"


def test_removing_or_clearing_resets_targets(vm):
    vm.addFile("notes.txt")
    assert vm.validTargetFormats

    vm.removeFile(0)
    assert vm.files == []
    assert vm.validTargetFormats == []
    assert vm.targetFormat == ""

    vm.addFile("notes.txt")
    vm.clearFiles()
    assert vm.files == []
    assert vm.validTargetFormats == []
    assert vm.targetFormat == ""


def test_txt_to_html_conversion_escapes_content(vm, tmp_path):
    source = tmp_path / "notes.txt"
    source.write_text("hello <world> & friends", encoding="utf-8")
    vm.outputDir = str(tmp_path)
    vm.addFile(str(source))
    vm.targetFormat = "html"

    vm.convert()

    output = tmp_path / "notes.html"
    assert output.exists()
    assert output.read_text(encoding="utf-8").count("hello &lt;world&gt; &amp; friends") == 1
    assert vm.status == "Done"
    assert vm.error == ""
    assert vm.progress == 1.0


def test_html_to_txt_conversion_strips_markup(vm, tmp_path):
    source = tmp_path / "page.html"
    source.write_text(
        "<html><body><h1>Title</h1><p>Hello &amp; bye</p>"
        "<script>ignored()</script></body></html>",
        encoding="utf-8",
    )
    vm.outputDir = str(tmp_path)
    vm.addFile(str(source))
    vm.targetFormat = "txt"

    vm.convert()

    output = tmp_path / "page.txt"
    assert output.exists()
    text = output.read_text(encoding="utf-8")
    assert "Title" in text
    assert "Hello & bye" in text
    assert "<h1>" not in text
    assert "ignored()" not in text


def test_single_file_is_kept_while_converting(vm):
    vm.addFile("one.mp4")
    vm._converting = True

    vm.addFile("two.mp4")

    assert len(vm.files) == 1
    assert vm.files[0]["name"] == "one.mp4"


def test_docx_to_txt_extraction(vm, tmp_path):
    source = tmp_path / "report.docx"
    xml = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        "<w:body>"
        "<w:p><w:r><w:t>Hello</w:t></w:r></w:p>"
        "<w:p><w:r><w:t>World</w:t></w:r><w:r><w:tab/><w:t>!</w:t></w:r></w:p>"
        "</w:body></w:document>"
    )
    with zipfile.ZipFile(source, "w") as archive:
        archive.writestr("word/document.xml", xml)
    vm.outputDir = str(tmp_path)
    vm.addFile(str(source))
    vm.targetFormat = "txt"

    vm.convert()

    text = (tmp_path / "report.txt").read_text(encoding="utf-8")
    assert "Hello" in text
    assert "World\t!" in text
    assert vm.status == "Done"


def test_odt_to_html_extraction(vm, tmp_path):
    source = tmp_path / "letter.odt"
    xml = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<office:document-content '
        'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
        'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0">'
        "<office:body><office:text>"
        '<text:h text:style-name="Heading_1">Title</text:h>'
        "<text:p>First<text:tab/>Second</text:p>"
        "</office:text></office:body></office:document-content>"
    )
    with zipfile.ZipFile(source, "w") as archive:
        archive.writestr("content.xml", xml)
    vm.outputDir = str(tmp_path)
    vm.addFile(str(source))
    vm.targetFormat = "html"

    vm.convert()

    output = (tmp_path / "letter.html").read_text(encoding="utf-8")
    assert "Title" in output
    assert "First\tSecond" in output
    assert "<pre>" in output
    assert vm.status == "Done"


def test_rtf_to_text_skips_control_groups(vm):
    text = vm._rtf_to_text(
        r"{\rtf1\ansi{\fonttbl{\f0 Helvetica;}}"
        r"{\*\generator riched20.dll}\f0 Hello\par World\par}"
    )

    assert "Helvetica" not in text
    assert "riched20" not in text
    assert "Hello\nWorld" in text


def test_rtf_to_txt_conversion(vm, tmp_path):
    source = tmp_path / "memo.rtf"
    source.write_text(
        r"{\rtf1\ansi{\fonttbl{\f0 Courier;}}\f0 Line one\par Line two\par}",
        encoding="utf-8",
    )
    vm.outputDir = str(tmp_path)
    vm.addFile(str(source))
    vm.targetFormat = "txt"

    vm.convert()

    text = (tmp_path / "memo.txt").read_text(encoding="utf-8")
    assert text.strip() == "Line one\nLine two"
    assert vm.status == "Done"


def test_svg_rasterizes_to_a_temporary_png(vm, tmp_path, qapp):
    source = tmp_path / "icon.svg"
    source.write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">'
        '<rect width="16" height="16" fill="red"/></svg>',
        encoding="utf-8",
    )

    output = vm._rasterize_svg(str(source))

    assert output.endswith(".png")
    assert Path(output).exists()
    vm._cleanup_temp_files()
    assert not Path(output).exists()


def test_txt_to_pdf_conversion(vm, tmp_path, qapp):
    source = tmp_path / "notes.txt"
    source.write_text("Hello PDF\nSecond line\n", encoding="utf-8")
    vm.outputDir = str(tmp_path)
    vm.addFile(str(source))
    vm.targetFormat = "pdf"

    vm.convert()

    output = tmp_path / "notes.pdf"
    assert output.exists()
    assert output.read_bytes().startswith(b"%PDF")
    assert vm.status == "Done"
    assert vm.error == ""
