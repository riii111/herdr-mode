from pathlib import Path
import os
import subprocess
import sys


REPO_ROOT = Path(__file__).resolve().parents[1]
KITTY_MODE = REPO_ROOT / "integrations/kitty/herdr-mode.conf"
KITTY_LOGO = REPO_ROOT / "integrations/kitty/herdr-mode-logo.conf"
LOGO_PNG = REPO_ROOT / "assets/herdr-logo.png"
FIXTURE = REPO_ROOT / "tests/fixtures/kitty.conf"

MODE_NAMES = {"herdr", "herdr-copy", "herdr-selection", "herdr-resize"}


def test_files_exist():
    assert KITTY_MODE.is_file()
    assert KITTY_LOGO.is_file()
    assert LOGO_PNG.is_file()
    assert FIXTURE.is_file()


def test_logo_png():
    data = LOGO_PNG.read_bytes()
    assert data.startswith(b"\x89PNG\r\n\x1a\n")
    assert int.from_bytes(data[16:20], "big") == 624
    assert int.from_bytes(data[20:24], "big") == 704
    assert data[25] == 6


def test_prefix_is_centralized():
    text = KITTY_MODE.read_text()
    assert text.count("action_alias herdr_send_prefix send_key ctrl+;") == 1
    assert "send_key ctrl+;" not in text.replace(
        "action_alias herdr_send_prefix send_key ctrl+;", ""
    )


def test_required_modes_and_passthrough():
    text = KITTY_MODE.read_text()
    for mode in MODE_NAMES:
        assert f"--new-mode {mode}" in text
        assert "--on-unknown passthrough" in text
    assert "--when-focus-on title:^herdr" in text
    assert "timeout 0" in text


def test_entry_exit_and_nested_modes():
    text = KITTY_MODE.read_text()
    assert "push_keyboard_mode herdr" in text
    assert "herdr_logo_off : pop_keyboard_mode" in text
    assert "push_keyboard_mode herdr-copy" in text
    assert "push_keyboard_mode herdr-selection" in text
    assert "push_keyboard_mode herdr-resize" in text
    assert "--mode herdr-copy y combine : send_key y : herdr_logo_off : pop_keyboard_mode : pop_keyboard_mode" in text
    assert "--mode herdr-selection enter combine : send_key enter : herdr_logo_off : pop_keyboard_mode : pop_keyboard_mode" in text
    assert "--mode herdr-resize h send_key h" in text
    assert "--mode herdr-resize esc combine : send_key esc : pop_keyboard_mode" in text


def test_main_vim_keys():
    text = KITTY_MODE.read_text()
    for key in ("h", "j", "k", "l"):
        assert f"--mode herdr {key} combine : herdr_send_prefix : send_key {key}" in text


def test_logo_can_be_disabled():
    text = KITTY_LOGO.read_text()
    assert "set-window-logo" in text
    assert "herdr-logo.png" in text
    assert "/Users/" not in text


def test_no_user_absolute_paths():
    for path in (KITTY_MODE, KITTY_LOGO, FIXTURE):
        assert "/Users/" not in path.read_text()
        assert "/opt/homebrew/" not in path.read_text()
        assert "/home/" not in path.read_text()


def test_kitty_load_config():
    if os.environ.get("HERDR_MODE_SKIP_KITTY_LOAD") == "1":
        print("kitty load_config: skipped (HERDR_MODE_SKIP_KITTY_LOAD=1)")
        return
    if not shutil_which("kitty"):
        print("kitty load_config: skipped (kitty not installed)")
        return

    subprocess.run(
        [
            "kitty",
            "+runpy",
            "import runpy; runpy.run_path('tests/kitty_load_config.py', run_name='__main__')",
        ],
        check=True,
        cwd=str(REPO_ROOT),
    )


def shutil_which(name):
    from shutil import which

    return which(name)


def main():
    test_files_exist()
    test_logo_png()
    test_prefix_is_centralized()
    test_required_modes_and_passthrough()
    test_entry_exit_and_nested_modes()
    test_main_vim_keys()
    test_logo_can_be_disabled()
    test_no_user_absolute_paths()
    test_kitty_load_config()
    print("kitty herdr mode test: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
