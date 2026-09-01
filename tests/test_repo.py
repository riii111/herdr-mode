from pathlib import Path
import sys


REPO_ROOT = Path(__file__).resolve().parents[1]

REQUIRED = [
    "README.md",
    "LICENSE",
    "NOTICE",
    "install.sh",
    "uninstall.sh",
    "assets/herdr-logo.png",
    "integrations/kitty/herdr-mode.conf",
    "integrations/kitty/herdr-mode-logo.conf",
    "integrations/wezterm/herdr_mode.lua",
    "examples/herdr-config.toml",
]

SHIPPED_GLOBS = (
    "README.md",
    "LICENSE",
    "NOTICE",
    "install.sh",
    "uninstall.sh",
    ".github/**/*",
    "integrations/**/*",
    "examples/**/*",
    "assets/**/*",
)

USER_PATH_MARKERS = ("/Users/", "/home/", "/opt/homebrew/")


def iter_shipped_text_files(root: Path):
    seen = set()
    for pattern in SHIPPED_GLOBS:
        for path in root.glob(pattern):
            if not path.is_file() or path in seen:
                continue
            if path.suffix == ".png":
                continue
            seen.add(path)
            yield path


def main():
    for relative in REQUIRED:
        assert (REPO_ROOT / relative).exists(), relative

    notice = (REPO_ROOT / "NOTICE").read_text()
    assert "Herdr logo © Herdr contributors, licensed under Apache-2.0. Modified for visibility." in notice
    assert "https://github.com/herdrdev/herdr/blob/v0.8.0/assets/logo.png" in notice

    readme = (REPO_ROOT / "README.md").read_text()
    assert "Ctrl+;" in readme
    assert "0.8.2" in readme

    example = (REPO_ROOT / "examples/herdr-config.toml").read_text()
    assert 'window_title = "herdr:{workspace}"' in example
    assert 'prefix = "ctrl+semicolon"' in example

    lua = (REPO_ROOT / "integrations/wezterm/herdr_mode.lua").read_text()
    assert lua.count('PREFIX = "\\x1b[59;5u"') == 1
    assert "leader" not in lua
    assert "TMUX_ACTIVE" not in lua
    assert "render-right-status" not in lua

    for path in iter_shipped_text_files(REPO_ROOT):
        text = path.read_text(errors="replace")
        for marker in USER_PATH_MARKERS:
            assert marker not in text, f"{marker} found in {path.relative_to(REPO_ROOT)}"

    print("repo layout test: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
