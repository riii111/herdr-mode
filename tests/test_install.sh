#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$XDG_CONFIG_HOME/kitty" "$XDG_CONFIG_HOME/wezterm"

printf 'font_size 12.0\n' >"$XDG_CONFIG_HOME/kitty/kitty.conf"
printf 'return {}\n' >"$XDG_CONFIG_HOME/wezterm/wezterm.lua"

bash -n "$ROOT/install.sh"
bash -n "$ROOT/uninstall.sh"

"$ROOT/install.sh" kitty
grep -q "# herdr-mode begin" "$XDG_CONFIG_HOME/kitty/kitty.conf"
grep -q "include herdr-mode.conf" "$XDG_CONFIG_HOME/kitty/kitty.conf"
test -L "$XDG_CONFIG_HOME/kitty/herdr-mode.conf"
grep -q "font_size 12.0" "$XDG_CONFIG_HOME/kitty/kitty.conf"

"$ROOT/install.sh" kitty
count="$(grep -c "# herdr-mode begin" "$XDG_CONFIG_HOME/kitty/kitty.conf")"
test "$count" -eq 1

"$ROOT/install.sh" --no-logo kitty
grep -q "action_alias herdr_logo_on noop" "$XDG_CONFIG_HOME/kitty/kitty.conf"
test "$(grep -c "# herdr-mode begin" "$XDG_CONFIG_HOME/kitty/kitty.conf")" -eq 1

"$ROOT/install.sh" wezterm
test -L "$XDG_CONFIG_HOME/wezterm/herdr_mode.lua"
grep -q "return {}" "$XDG_CONFIG_HOME/wezterm/wezterm.lua"
if grep -q "herdr_mode.install" "$XDG_CONFIG_HOME/wezterm/wezterm.lua"; then
	echo "wezterm.lua should not be auto-edited" >&2
	exit 1
fi

"$ROOT/uninstall.sh" kitty wezterm
if grep -q "# herdr-mode begin" "$XDG_CONFIG_HOME/kitty/kitty.conf"; then
	echo "kitty include block was not removed" >&2
	exit 1
fi
grep -q "font_size 12.0" "$XDG_CONFIG_HOME/kitty/kitty.conf"
test ! -e "$XDG_CONFIG_HOME/kitty/herdr-mode.conf"
test ! -e "$XDG_CONFIG_HOME/wezterm/herdr_mode.lua"

echo "install/uninstall test: ok"
