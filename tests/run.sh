#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LUA="$(command -v lua || command -v lua5.4 || command -v lua5.3 || true)"

if [[ -z "$LUA" ]]; then
	echo "lua is required (lua 5.3 or 5.4)" >&2
	exit 1
fi

python3 "$ROOT/tests/test_repo.py"
python3 "$ROOT/tests/test_kitty_herdr_mode.py"
"$LUA" "$ROOT/tests/test_wezterm_herdr_mode.lua"
"$ROOT/tests/test_install.sh"
