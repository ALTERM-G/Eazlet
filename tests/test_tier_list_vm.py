import pytest
from PySide6.QtGui import QImage

from eazlet.backend.viewmodels.tier_list_vm import DEFAULT_TIERS, TierListVM


@pytest.fixture
def vm():
    return TierListVM()


def make_image(path, color=0xFFFF0000):
    image = QImage(8, 8, QImage.Format.Format_RGB32)
    image.fill(color)
    assert image.save(str(path))
    return path


@pytest.fixture
def images(tmp_path):
    return [
        make_image(tmp_path / "one.png", 0xFFFF0000),
        make_image(tmp_path / "two.png", 0xFF00FF00),
    ]


def test_starts_with_tier_maker_defaults(vm):
    assert [tier["name"] for tier in vm.tiers] == [name for name, _ in DEFAULT_TIERS]
    assert [tier["color"] for tier in vm.tiers] == [color for _, color in DEFAULT_TIERS]
    assert vm.itemCount == 0
    assert vm.pool == []
    assert vm.tierCount == len(DEFAULT_TIERS)


def test_defaults_include_d_and_f(vm):
    names = [tier["name"] for tier in vm.tiers]
    assert "D" in names
    assert "F" in names


def test_add_files_puts_images_in_unranked_pool(vm, images):
    vm.addFiles([str(path) for path in images])

    assert vm.itemCount == 2
    assert vm.poolCount == 2
    assert [item["name"] for item in vm.pool] == ["one.png", "two.png"]
    assert all(item["url"].startswith("file://") for item in vm.pool)
    assert all(tier["items"] == [] for tier in vm.tiers)


def test_add_files_accepts_file_urls(vm, images):
    from PySide6.QtCore import QUrl

    vm.addFiles([QUrl.fromLocalFile(str(images[0])).toString()])

    assert vm.itemCount == 1
    assert vm.pool[0]["name"] == "one.png"


def test_add_files_accepts_qurl_objects_from_dialogs(vm, images):
    from PySide6.QtCore import QUrl

    # FileDialog.selectedFiles and DropArea.urls are QUrl values, not strings.
    vm.addFiles([QUrl.fromLocalFile(str(path)) for path in images])

    assert vm.itemCount == 2
    assert [item["name"] for item in vm.pool] == ["one.png", "two.png"]


def test_add_files_skips_missing_and_non_images(vm, tmp_path):
    text = tmp_path / "notes.txt"
    text.write_text("not an image")

    vm.addFiles([str(text), str(tmp_path / "missing.png")])

    assert vm.itemCount == 0
    assert "No supported images" in vm.message


def test_assign_item_and_move_between_tiers(vm, images):
    vm.addFiles([str(images[0]), str(images[1])])
    first_id = vm.pool[0]["id"]

    assert vm.assignItem(first_id, vm.tiers[0]["id"]) is True
    assert vm.poolCount == 1
    assert [item["id"] for item in vm.tiers[0]["items"]] == [first_id]

    assert vm.assignItem(first_id, vm.tiers[1]["id"]) is True
    assert vm.tiers[0]["items"] == []
    assert [item["id"] for item in vm.tiers[1]["items"]] == [first_id]

    assert vm.assignItem(first_id, "") is True
    assert vm.pool[-1]["id"] == first_id
    assert vm.tiers[1]["items"] == []


def test_assign_item_at_orders_and_reorders(vm, images):
    vm.addFiles([str(path) for path in images])
    ids = [item["id"] for item in vm.pool]
    tier_id = vm.tiers[0]["id"]

    vm.assignItem(ids[0], tier_id)
    vm.assignItem(ids[1], tier_id)
    assert [item["id"] for item in vm.tiers[0]["items"]] == ids

    # Move the second image in front of the first one.
    vm.assignItemAt(ids[1], tier_id, 0)
    assert [item["id"] for item in vm.tiers[0]["items"]] == [ids[1], ids[0]]

    # Dropping an item after itself is a no-op.
    vm.assignItemAt(ids[0], tier_id, 2)
    assert [item["id"] for item in vm.tiers[0]["items"]] == [ids[1], ids[0]]


def test_remove_item_from_pool_and_tier(vm, images):
    vm.addFiles([str(path) for path in images])
    ids = [item["id"] for item in vm.pool]
    vm.assignItem(ids[0], vm.tiers[0]["id"])

    assert vm.removeItem(ids[0]) is True
    assert vm.removeItem(ids[0]) is False
    assert vm.itemCount == 1
    assert vm.tiers[0]["items"] == []
    assert [item["id"] for item in vm.pool] == [ids[1]]


def test_remove_tier_keeps_its_images_in_pool(vm, images):
    vm.addFiles([str(images[0])])
    item_id = vm.pool[0]["id"]
    tier_id = vm.tiers[0]["id"]
    vm.assignItem(item_id, tier_id)

    assert vm.removeTier(tier_id) is True

    assert vm.tierCount == len(DEFAULT_TIERS) - 1
    assert [item["id"] for item in vm.pool] == [item_id]


def test_rename_tier(vm):
    tier_id = vm.tiers[0]["id"]

    assert vm.renameTier(tier_id, "  Godlike  ") is True
    assert vm.tiers[0]["name"] == "Godlike"
    assert vm.renameTier(tier_id, "   ") is False
    assert vm.tiers[0]["name"] == "Godlike"


def test_set_tier_color_validates(vm):
    tier_id = vm.tiers[0]["id"]

    assert vm.setTierColor(tier_id, "#123456") is True
    assert vm.tiers[0]["color"] == "#123456"
    assert vm.setTierColor(tier_id, "notacolor") is False
    assert vm.tiers[0]["color"] == "#123456"


def test_add_tier_uses_free_name_and_palette(vm):
    start = vm.tierCount
    used = {tier["name"] for tier in vm.tiers}
    expected = next(letter for letter in "SABCDEFGHIJKLMNOPQRSTUVWXYZ"
                    if letter not in used)
    tier_id = vm.addTier()

    assert tier_id
    assert vm.tierCount == start + 1
    assert vm.tiers[-1]["name"] == expected
    assert vm.tiers[-1]["color"].startswith("#")


def test_add_tier_respects_maximum(vm):
    while vm.tierCount < vm.maxTiers:
        assert vm.addTier()

    assert vm.addTier() == ""
    assert vm.tierCount == vm.maxTiers
    assert "at most" in vm.message


def test_move_tier(vm):
    names = [tier["name"] for tier in vm.tiers]
    tier_id = vm.tiers[0]["id"]

    assert vm.moveTier(tier_id, 1) is True
    assert [tier["name"] for tier in vm.tiers] == names[1:2] + names[0:1] + names[2:]
    assert vm.moveTier(vm.tiers[0]["id"], -1) is False


def test_clear_items_keeps_tiers(vm, images):
    vm.addFiles([str(images[0])])
    vm.assignItem(vm.pool[0]["id"], vm.tiers[0]["id"])
    tier_count = vm.tierCount

    vm.clearItems()

    assert vm.itemCount == 0
    assert vm.pool == []
    assert vm.tierCount == tier_count
    assert all(tier["items"] == [] for tier in vm.tiers)


def test_reset_restores_defaults(vm, images):
    vm.addFiles([str(images[0])])
    vm.renameTier(vm.tiers[0]["id"], "Custom")
    vm.moveTier(vm.tiers[0]["id"], 1)

    vm.reset()

    assert vm.itemCount == 0
    assert [tier["name"] for tier in vm.tiers] == [name for name, _ in DEFAULT_TIERS]
    assert vm.message == ""


def test_remove_last_tier_is_refused(vm):
    while vm.tierCount > 1:
        assert vm.removeTier(vm.tiers[-1]["id"]) is True

    remaining = vm.tiers[0]["id"]
    assert vm.removeTier(remaining) is False
    assert vm.tierCount == 1
    assert "at least one tier" in vm.message
