import json

from eazlet.backend.viewmodels.text_tools_vm import (
    REGEX_PRESETS,
    TextToolsVM,
    change_case,
    delimited_to_json,
    delimited_to_markdown,
    extract_column,
    json_to_delimited,
    line_operation,
    multi_replace,
    normalize_whitespace,
    preset_for,
    regex_find,
    regex_replace,
    regex_split,
    replace_literal,
    reverse_text,
    shuffle_text,
    sort_text,
)


def test_change_case_modes():
    text = "hello world. next ONE!"
    assert change_case(text, "Upper") == "HELLO WORLD. NEXT ONE!"
    assert change_case(text, "Lower") == "hello world. next one!"
    assert change_case(text, "Title") == "Hello World. Next One!"
    assert change_case(text, "Swap") == "HELLO WORLD. NEXT one!"
    assert change_case(text, "Capitalize") == "Hello world. next one!"
    assert change_case(text, "Sentence") == "Hello world. Next one!"
    assert change_case(text, "Unknown") == text


def test_normalize_whitespace_options():
    text = "  a\t\tb  \r\n\n   c   "
    assert normalize_whitespace(text, ["Trim"]) == "a\t\tb\n\nc"
    assert normalize_whitespace(text, ["Collapse"]) == " a b\n\nc "
    collapsed = normalize_whitespace(text, ["Trim", "Collapse"])
    assert collapsed == "a b\n\nc"
    assert "\r" not in normalize_whitespace(text, [])


def test_reverse_units():
    text = "one two\nthree"
    assert reverse_text(text, "Characters") == text[::-1]
    assert reverse_text(text, "Words") == "three two one"
    assert reverse_text(text, "Lines") == "three\none two"


def test_line_operations():
    text = "a\n\na\n b \n"
    assert line_operation(text, "Remove blank lines") == "a\na\n b "
    assert line_operation(text, "Remove duplicate lines") == "a\n\n b "
    assert line_operation(text, "Trim each line") == "a\n\na\nb"
    assert line_operation("x\ny", "Number lines") == "1. x\n2. y"
    assert line_operation("x\ny", "Number lines", start=5) == "5. x\n6. y"
    assert line_operation("x\ny", "Prefix / suffix", "- ", "!") == "- x!\n- y!"


def test_replace_literal_options():
    text = "Cat cat CAT"
    assert replace_literal(text, "cat", "dog") == "Cat dog CAT"
    assert replace_literal(text, "cat", "dog", case_sensitive=False) == "dog dog dog"
    assert replace_literal(text, "cat", "dog", case_sensitive=False,
                           replace_all=False) == "dog cat CAT"
    assert replace_literal(text, "", "x") == text
    assert replace_literal("a.b", ".", "-") == "a-b"


def test_multi_replace_swaps_atomically():
    rules = [
        {"find": "X", "replace": "A", "enabled": True},
        {"find": "A", "replace": "X", "enabled": True},
    ]
    replaced = multi_replace("X A XX AA", rules)
    assert replaced["ok"] is True
    assert replaced["text"] == "A X AA XX"
    assert replaced["count"] == 6

    swapped = multi_replace("cat dog", [
        {"find": "cat", "replace": "dog"},
        {"find": "dog", "replace": "cat"},
    ])
    assert swapped["text"] == "dog cat"


def test_multi_replace_literal_regex_word_and_case_options():
    assert multi_replace("a.b aXb", [{"find": ".", "replace": "-"}])["text"] == "a-b aXb"
    assert multi_replace("cat scatter", [
        {"find": "cat", "replace": "dog"},
    ], whole_word=True)["text"] == "dog scatter"
    assert multi_replace("Cat cat", [
        {"find": "cat", "replace": "dog"},
    ], case_sensitive=False)["text"] == "dog dog"
    assert multi_replace("a1 b22", [
        {"find": r"([a-z]+)(\d+)", "replace": r"$2-$1"},
    ], regex_mode=True)["text"] == "1-a 22-b"


def test_multi_replace_disabled_empty_and_invalid_rules():
    assert multi_replace("X A", [{"find": "X", "replace": "A", "enabled": False}])["ok"] is False
    mixed_rules = [
        {"find": "X", "replace": ""},
        {"find": "", "replace": "?"},
    ]
    assert multi_replace("X A", mixed_rules)["text"] == " A"
    invalid = multi_replace("x", [{"find": "[", "replace": "y"}], regex_mode=True)
    assert invalid["ok"] is False
    assert invalid["error"]


def test_regex_find_groups_and_flags():
    found = regex_find("a1 b22 c333", r"([a-z])(\d+)", [])
    assert found["ok"] is True
    assert found["count"] == 3
    assert found["matches"][1] == {
        "value": "b22",
        "start": 3,
        "end": 6,
        "groups": ["b", "22"],
        "named": {},
    }

    assert regex_find("Hello\nworld", "^world", [])["count"] == 0
    assert regex_find("Hello\nworld", "^world", ["Multiline"])["count"] == 1
    assert regex_find("ABC", "abc", ["IgnoreCase"])["count"] == 1
    assert regex_find("a\nb", "a.b", ["DotAll"])["count"] == 1


def test_regex_find_reports_invalid_pattern():
    found = regex_find("text", "[", [])
    assert found["ok"] is False
    assert found["error"]
    assert found["matches"] == []
    assert regex_find("text", "", [])["ok"] is False


def test_regex_replace_group_references():
    text = "Ada 36, Bob 29"
    pattern = r"(\w+) (\d+)"
    assert regex_replace(text, pattern, r"$2:$1", [])["text"] == "36:Ada, 29:Bob"
    assert regex_replace(text, pattern, r"\2-\1", [])["text"] == "36-Ada, 29-Bob"
    first = regex_replace(text, pattern, "X", [], replace_all=False)
    assert first["text"] == "X, Bob 29"
    assert first["count"] == 1
    assert regex_replace(text, "[", "x", [])["ok"] is False


def test_regex_split():
    split = regex_split("a, b;;c", r"[,;]\s*", [])
    assert split["parts"] == ["a", "b", "", "c"]
    assert split["count"] == 4
    assert regex_split("a1b2c", r"\d", [], 1)["parts"] == ["a", "b2c"]


def test_presets_are_usable():
    names = [item["name"] for item in REGEX_PRESETS]
    assert "Email address" in names
    preset = preset_for("Email address")
    assert preset["pattern"] and preset["description"]
    assert preset_for("missing") == {"pattern": "", "description": ""}
    assert regex_find("mail me at a.b@example.com", preset["pattern"], [])["count"] == 1


def test_sort_text_keys_and_orders():
    assert sort_text("b\na\nc", "Lines", "Alphabetic", "Ascending") == "a\nb\nc"
    assert sort_text("b\na\nc", "Lines", "Alphabetic", "Descending") == "c\nb\na"
    assert sort_text("file10\nfile2\nfile1", "Lines", "Natural", "Ascending") == (
        "file1\nfile2\nfile10"
    )
    assert sort_text("x10\nx2\nx1", "Lines", "Numeric", "Ascending") == (
        "x1\nx2\nx10"
    )
    assert sort_text("aaa\nb\ncc", "Lines", "Length", "Ascending") == "b\ncc\naaa"


def test_sort_text_units_unique_and_case():
    assert sort_text("z b a", "Words", "Alphabetic", "Ascending") == "a b z"
    assert sort_text("cba", "Characters", "Alphabetic", "Ascending") == "abc"
    assert sort_text("a\nb\na\nA", "Lines", "Alphabetic", "Ascending",
                     unique=True) == "a\nb"
    assert sort_text("a\nb\na\nA", "Lines", "Alphabetic", "Ascending",
                     case_sensitive=True, unique=True) == "A\na\nb"
    assert sort_text("a\nB\nc", "Lines", "Alphabetic", "Ascending",
                     case_sensitive=True) == "B\na\nc"


def test_sort_text_columns():
    text = "b,2\na,10\nc,1"
    assert sort_text(text, "Columns", "Numeric", "Ascending",
                     delimiter=",", column=1) == "c,1\nb,2\na,10"
    assert sort_text(text, "Columns", "Alphabetic", "Ascending",
                     delimiter=",", column=0) == "a,10\nb,2\nc,1"


def test_sort_text_multiple_columns():
    text = "b,y\na,2\nb,x\na,1"
    assert sort_text(text, "Columns", "Alphabetic", "Ascending",
                     delimiter=",", column=0, secondary_column=1,
                     secondary_order="Ascending") == "a,1\na,2\nb,x\nb,y"
    assert sort_text(text, "Columns", "Alphabetic", "Ascending",
                     delimiter=",", column=0, secondary_column=1,
                     secondary_order="Descending") == "a,2\na,1\nb,y\nb,x"

    # -1 disables the secondary key, keeping the old single-column behaviour.
    assert sort_text(text, "Columns", "Alphabetic", "Ascending",
                     delimiter=",", column=1, secondary_column=-1) == (
        "a,1\na,2\nb,x\nb,y"
    )

    # Unique applies to whole rows before columns are sorted.
    assert sort_text("a,1\na,1\nb,2", "Columns", "Alphabetic", "Ascending",
                     delimiter=",", column=0, unique=True) == "a,1\nb,2"


def test_shuffle_is_seed_deterministic():
    text = "a\nb\nc\nd\ne"
    assert shuffle_text(text, "Lines", 7) == shuffle_text(text, "Lines", 7)
    assert sorted(shuffle_text(text, "Words", 3).split()) == list("abcde")


def test_delimited_to_json_and_markdown():
    text = "name,age\nAda,36\nBob,29"
    parsed = json.loads(delimited_to_json(text, ",", True, False))
    assert parsed == [{"name": "Ada", "age": "36"},
                      {"name": "Bob", "age": "29"}]
    assert "\n  {" in delimited_to_json(text, ",", True, True)
    headerless = json.loads(delimited_to_json("a,1\nb,2", ",", False, False))
    assert headerless == [{"Column 1": "a", "Column 2": "1"},
                          {"Column 1": "b", "Column 2": "2"}]
    assert delimited_to_markdown(text, ",", True) == (
        "| name | age |\n| --- | --- |\n| Ada | 36 |\n| Bob | 29 |"
    )


def test_json_to_delimited_and_extract_column():
    data = '[{"a": 1, "b": 2}, {"a": 3, "b": 4}]'
    assert json_to_delimited(data, ",", "") == "1,2\n3,4"
    assert json_to_delimited(data, "|", "b,a") == "2|1\n4|3"
    assert json_to_delimited('{"a": 1}', ",", "") == "1"
    assert extract_column("a,1\nb,2", ",", 1) == "1\n2"
    assert extract_column("a,1\nb", ",", 1) == "1\n"


def test_vm_slots_return_uniform_result_map():
    vm = TextToolsVM()
    expected = {"ok", "error", "text", "count", "matches", "parts"}
    assert set(vm.applyCase("abc", "Upper")) == expected
    assert set(vm.findRegex("a1", r"\d", [])) == expected
    assert set(vm.sortText("b\na", "Lines", "Alphabetic", "Ascending",
                           False, False, ",", 0)) == expected
    multi = vm.sortTextMulti("b,y\na,2", "Columns", "Alphabetic", "Ascending",
                             False, False, ",", 0, 1, "Descending")
    assert set(multi) == expected
    assert multi["text"] == "a,2\nb,y"
    assert set(vm.delimitedToJson("a,b", ",", True, False)) == expected
    assert vm.jsonToDelimited("not json", ",", "")["ok"] is False
    assert vm.jsonToDelimited("not json", ",", "")["error"]
    assert vm.presetPattern("Email address")
    assert vm.caseModes[0] == "Upper"
    assert vm.regexPresets and vm.delimiters and vm.sortOrders
