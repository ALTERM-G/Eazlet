from eazlet.backend.viewmodels.organizer_vm import OrganizerVM


def test_rename_target_count_only_counts_top_level_files(tmp_path):
    (tmp_path / "one.txt").write_text("one", encoding="utf-8")
    (tmp_path / "two.md").write_text("two", encoding="utf-8")
    nested = tmp_path / "nested"
    nested.mkdir()
    (nested / "three.txt").write_text("three", encoding="utf-8")

    vm = OrganizerVM()
    vm.folder = str(tmp_path)

    assert vm.renameTargetCount() == 2


def test_rename_target_count_is_zero_for_missing_folder(tmp_path):
    vm = OrganizerVM()
    vm.folder = str(tmp_path / "missing")

    assert vm.renameTargetCount() == 0
