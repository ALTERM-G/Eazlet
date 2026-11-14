import pytest

from eazlet.backend.viewmodels.unified_download_vm import (
    UnifiedDownloadVM,
    detect_downloader,
)


@pytest.mark.parametrize(
    ("url", "expected"),
    [
        ("https://www.youtube.com/watch?v=abc", "yt-dlp"),
        ("https://youtu.be/abc", "yt-dlp"),
        ("https://soundcloud.com/artist/track", "yt-dlp"),
        ("youtube.com/watch?v=abc", "yt-dlp"),
        ("https://open.spotify.com/track/abc", "spotdl"),
        ("https://spotify.com/album/abc", "spotdl"),
        ("https://artist.bandcamp.com/album/foo", "bandcamp-dl"),
        ("https://bandcamp.com/track/foo", "bandcamp-dl"),
        (
            "https://downloads.khinsider.com/game-soundtracks/album/foo",
            "khinsider-dl",
        ),
        ("https://www.khinsider.com/game-soundtracks/album/foo", "khinsider-dl"),
        ("https://www.pixiv.net/en/artworks/123", "gallery-dl"),
        ("https://www.deviantart.com/user/art/piece", "gallery-dl"),
        ("https://example.com/archive.zip", "direct"),
        ("ftp://example.com/archive.zip", "direct"),
        ("", "direct"),
        ("not a url", "direct"),
    ],
)
def test_detect_downloader(url, expected):
    assert detect_downloader(url) == expected


def test_detection_ignores_www_and_subdomains():
    assert detect_downloader("https://music.youtube.com/watch?v=abc") == "yt-dlp"
    assert detect_downloader("https://www.bandcamp.com/album/foo") == "bandcamp-dl"


def test_detection_skips_tools_that_are_not_installed():
    url = "https://artist.bandcamp.com/album/foo"
    assert detect_downloader(url, {"bandcamp-dl", "yt-dlp"}) == "bandcamp-dl"
    assert detect_downloader(url, {"yt-dlp"}) == "yt-dlp"
    # Nothing installed: keep the most specific tool so the error names it.
    assert detect_downloader(url, set()) == "bandcamp-dl"
    assert detect_downloader("https://open.spotify.com/track/abc", {"yt-dlp"}) == "spotdl"


def test_vm_falls_back_to_yt_dlp_without_bandcamp_dl(monkeypatch):
    monkeypatch.setattr(
        "eazlet.backend.viewmodels.unified_download_vm.shutil.which",
        lambda name: "/usr/bin/yt-dlp" if name == "yt-dlp" else None,
    )
    monkeypatch.setattr(UnifiedDownloadVM, "fetchFormats", lambda self: None)
    vm = UnifiedDownloadVM()
    vm.url = "https://artist.bandcamp.com/album/foo"
    assert vm.downloader == "yt-dlp"
    assert vm.autoDetect is True


def test_vm_starts_in_auto_direct_mode():
    vm = UnifiedDownloadVM()
    assert vm.downloader == "direct"
    assert vm.autoDetect is True
    assert vm.mode == "direct"
    assert vm.title == "Direct Download"


def test_vm_auto_detects_tool_from_url():
    vm = UnifiedDownloadVM()
    vm.url = "https://open.spotify.com/track/abc"
    assert vm.downloader == "spotdl"
    assert vm.autoDetect is True
    assert vm.title == "Spotify Download"
    assert vm.supportsFormats is False
    assert vm.mode == "social"


def test_vm_detects_plain_file_url_as_direct():
    vm = UnifiedDownloadVM()
    vm.url = "https://example.com/archive.zip"
    assert vm.downloader == "direct"
    assert vm.title == "Direct Download"


def test_vm_manual_downloader_wins_over_detection():
    vm = UnifiedDownloadVM()
    vm.setDownloader("gallery-dl")
    assert vm.autoDetect is False
    vm.url = "https://example.com/archive.zip"
    assert vm.downloader == "gallery-dl"
    assert vm.title == "Gallery Download"


def test_vm_switching_back_to_auto_redetects():
    vm = UnifiedDownloadVM()
    vm.setDownloader("bandcamp-dl")
    vm.url = "https://example.com/archive.zip"
    assert vm.downloader == "bandcamp-dl"
    vm.setDownloader("auto")
    assert vm.autoDetect is True
    assert vm.downloader == "direct"


def test_vm_rejects_unknown_downloader():
    vm = UnifiedDownloadVM()
    vm.setDownloader("not-a-downloader")
    assert vm.downloader == "direct"
    assert vm.autoDetect is True


def test_vm_yt_dlp_supports_formats():
    vm = UnifiedDownloadVM()
    vm.setDownloader("yt-dlp")
    assert vm.supportsFormats is True
    assert vm.title == "Social Media Download"


@pytest.mark.parametrize(
    ("tool_id", "binary", "url", "expected"),
    [
        (
            "gallery-dl",
            "/usr/bin/gallery-dl",
            "https://example.com/gallery",
            ["-d", "/tmp/out", "https://example.com/gallery"],
        ),
        (
            "spotdl",
            "/usr/bin/spotdl",
            "https://open.spotify.com/track/abc",
            ["download", "https://open.spotify.com/track/abc"],
        ),
        (
            "bandcamp-dl",
            "/usr/bin/bandcamp-dl",
            "https://artist.bandcamp.com/album/foo",
            ["https://artist.bandcamp.com/album/foo", "--base-dir", "/tmp/out"],
        ),
        (
            "khinsider-dl",
            "/usr/bin/khidl",
            "https://downloads.khinsider.com/game-soundtracks/album/foo",
            [
                "download",
                "https://downloads.khinsider.com/game-soundtracks/album/foo",
                "/tmp/out",
            ],
        ),
        (
            "khinsider-dl",
            "/usr/bin/khinsider.py",
            "https://downloads.khinsider.com/game-soundtracks/album/foo",
            ["https://downloads.khinsider.com/game-soundtracks/album/foo", "/tmp/out"],
        ),
    ],
)
def test_tool_arguments(tool_id, binary, url, expected):
    assert UnifiedDownloadVM._tool_arguments(tool_id, url, "/tmp/out", binary) == expected


def test_missing_tool_reports_error(monkeypatch):
    monkeypatch.setattr(
        "eazlet.backend.viewmodels.unified_download_vm.shutil.which",
        lambda name: None,
    )
    vm = UnifiedDownloadVM()
    vm._start_tool("gallery-dl")
    assert vm.error.startswith("gallery-dl not found in PATH")
    assert vm.downloading is False
    assert vm.status == "Failed"


def test_spotdl_requires_ffmpeg(monkeypatch):
    monkeypatch.setattr(
        "eazlet.backend.viewmodels.unified_download_vm.shutil.which",
        lambda name: "/usr/bin/spotdl" if name == "spotdl" else None,
    )
    vm = UnifiedDownloadVM()
    vm._start_tool("spotdl")
    assert "ffmpeg not found in PATH" in vm.error
    assert vm.downloading is False


def test_stderr_warnings_do_not_fail_a_successful_tool():
    vm = UnifiedDownloadVM()
    vm._stderr_tail = "WARNING: some tracks were skipped"
    vm._on_finished(0, None)
    assert vm.error == ""
    assert vm.status == "Done"


def test_stderr_tail_becomes_the_failure_message():
    vm = UnifiedDownloadVM()
    vm._stderr_tail = "ERROR: album not found"
    vm._on_finished(1, None)
    assert vm.error == "ERROR: album not found"
    assert vm.status == "Failed"
