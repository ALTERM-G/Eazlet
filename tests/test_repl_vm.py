import pytest

from eazlet.backend.viewmodels.repl_vm import ReplVM


@pytest.fixture
def repl_vm(qapp):
    vm = ReplVM()
    yield vm
    vm.stop()


def test_repl_starts_on_first_command_and_evaluates(repl_vm, qtbot):
    assert repl_vm.running is False
    assert repl_vm.output == ">>> "

    repl_vm.submit("print(6 * 7)")
    qtbot.waitUntil(lambda: "42" in repl_vm.output, timeout=8000)

    assert repl_vm.running is True
    assert ">>> print(6 * 7)" in repl_vm.output
    assert "42" in repl_vm.output


def test_repl_keeps_state_between_commands(repl_vm, qtbot):
    repl_vm.submit("answer = 42")
    qtbot.waitUntil(lambda: repl_vm.output.endswith(">>> "), timeout=8000)

    repl_vm.submit("print(answer + 1)")
    qtbot.waitUntil(lambda: "43" in repl_vm.output, timeout=8000)
    assert ">>> print(answer + 1)" in repl_vm.output


def test_repl_handles_multiline_blocks(repl_vm, qtbot):
    repl_vm.submit("for i in range(2):")
    qtbot.waitUntil(lambda: repl_vm.output.endswith("... "), timeout=8000)

    repl_vm.submit("    print(i)")
    qtbot.waitUntil(lambda: repl_vm.output.endswith("... "), timeout=8000)

    repl_vm.submit("")
    qtbot.waitUntil(lambda: "1" in repl_vm.output, timeout=8000)
    qtbot.waitUntil(lambda: repl_vm.output.endswith(">>> "), timeout=8000)

    assert "...     print(i)" in repl_vm.output


def test_repl_clear_wipes_transcript_but_keeps_state(repl_vm, qtbot):
    repl_vm.submit("value = 7")
    qtbot.waitUntil(lambda: repl_vm.output.endswith(">>> "), timeout=8000)

    repl_vm.clear()
    assert repl_vm.output == ">>> "

    repl_vm.submit("print(value)")
    qtbot.waitUntil(lambda: "7" in repl_vm.output, timeout=8000)
    assert repl_vm.running is True


def test_repl_restart_resets_transcript(repl_vm, qtbot):
    repl_vm.submit("print(1)")
    qtbot.waitUntil(lambda: "1" in repl_vm.output, timeout=8000)

    repl_vm.restart()
    qtbot.waitUntil(lambda: repl_vm.running, timeout=8000)
    assert repl_vm.output.startswith(">>> ")
    assert "print(1)" not in repl_vm.output
