from PySide6.QtCore import QUrl

from eazlet.backend.viewmodels.archive_vm import ArchiveVM


def make_files(tmp_path, names):
    paths = []
    for name in names:
        path = tmp_path / name
        path.write_text("sample")
        paths.append(path)
    return paths


def test_add_files_adds_every_path_in_one_update(tmp_path):
    files = make_files(tmp_path, ["alpha.txt", "beta.txt", "gamma.zip"])
    folder = tmp_path / "assets"
    folder.mkdir()

    vm = ArchiveVM()
    changes = []
    vm.filesChanged.connect(lambda: changes.append(1))

    vm.addFiles([f.as_uri() for f in files] + [str(folder), None, ""])

    assert [f["name"] for f in vm.files] == [
        "alpha.txt",
        "beta.txt",
        "gamma.zip",
        "assets",
    ]
    assert vm.files[3]["isDir"] is True
    assert changes == [1]


def test_add_files_skips_duplicates(tmp_path):
    (path,) = make_files(tmp_path, ["alpha.txt"])

    vm = ArchiveVM()
    vm.addFiles([str(path), str(path), path.as_uri()])

    assert len(vm.files) == 1


def test_add_files_accepts_qurl_values(tmp_path):
    files = make_files(tmp_path, ["alpha.txt", "beta.txt"])

    vm = ArchiveVM()
    vm.addFiles([QUrl.fromLocalFile(str(path)) for path in files])

    assert [f["path"] for f in vm.files] == [str(path) for path in files]


def test_add_file_decodes_percent_encoded_url(tmp_path):
    path = tmp_path / "with space.txt"
    path.write_text("sample")

    vm = ArchiveVM()
    vm.addFile(path.as_uri())

    assert vm.files[0]["path"] == str(path)
    assert vm.files[0]["name"] == "with space.txt"


def test_add_file_still_supports_single_paths(tmp_path):
    (path,) = make_files(tmp_path, ["alpha.txt"])

    vm = ArchiveVM()
    vm.addFile(str(path))

    assert [f["name"] for f in vm.files] == ["alpha.txt"]