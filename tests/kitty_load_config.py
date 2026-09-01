from pathlib import Path

from kitty.config import load_config


config_path = Path(__file__).resolve().parent / "fixtures/kitty.conf"
options = load_config(str(config_path))
mode_names = {"herdr", "herdr-copy", "herdr-selection", "herdr-resize"}
assert mode_names <= options.keyboard_modes.keys()
for mode_name in mode_names:
    mode = options.keyboard_modes[mode_name]
    assert mode.on_unknown == "passthrough"
    assert mode.timeout == 0


def definitions(mode_name):
    mode = options.keyboard_modes[mode_name]
    return [definition for mappings in mode.keymap.values() for definition in mappings]


entry = [
    definition
    for definition in definitions("")
    if definition.options.when_focus_on == "title:^herdr"
    and "push_keyboard_mode herdr" in definition.definition
]
assert len(entry) == 1
main = {definition.definition for definition in definitions("herdr")}
assert any("push_keyboard_mode herdr-copy" in item for item in main)
assert any("push_keyboard_mode herdr-resize" in item for item in main)
assert any("push_keyboard_mode herdr-selection" in item for item in main)
print("kitty load_config: ok")
