#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
KITTY_DIR="$CONFIG_HOME/kitty"
WEZTERM_DIR="$CONFIG_HOME/wezterm"

MARKER_BEGIN="# herdr-mode begin"
MARKER_END="# herdr-mode end"

NO_LOGO=0
TARGETS=()

usage() {
	cat <<'EOF'
Usage: ./install.sh [--no-logo] <kitty|wezterm>...

Install herdr-mode for the selected terminal(s).
Re-running is safe: symlinks are refreshed and existing config is not replaced.
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--no-logo)
		NO_LOGO=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	kitty | wezterm)
		TARGETS+=("$1")
		shift
		;;
	*)
		echo "unknown argument: $1" >&2
		usage >&2
		exit 1
		;;
	esac
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
	usage >&2
	exit 1
fi

symlink_into() {
	local src="$1"
	local dest="$2"
	mkdir -p "$(dirname "$dest")"
	ln -sfn "$src" "$dest"
	echo "linked $dest -> $src"
}

kitty_block() {
	if [[ "$NO_LOGO" -eq 1 ]]; then
		cat <<'EOF'
action_alias herdr_logo_on noop
action_alias herdr_logo_off noop
include herdr-mode.conf
EOF
	else
		cat <<'EOF'
include herdr-mode-logo.conf
include herdr-mode.conf
EOF
	fi
}

write_marked_block() {
	local file="$1"
	local block="$2"
	local tmp
	tmp="$(mktemp)"
	if [[ -f "$file" ]]; then
		awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" '
			$0 == begin { skip = 1; next }
			skip && $0 == end { skip = 0; next }
			skip { next }
			{ print }
		' "$file" >"$tmp"
		# Trim a trailing blank line left by a previous insert.
		if [[ -s "$tmp" ]] && [[ "$(tail -n 1 "$tmp")" == "" ]]; then
			sed '$d' "$tmp" >"${tmp}.trim"
			mv "${tmp}.trim" "$tmp"
		fi
		if [[ -s "$tmp" ]]; then
			printf '\n' >>"$tmp"
		fi
	fi
	{
		printf '%s\n' "$MARKER_BEGIN"
		printf '%s\n' "$block"
		printf '%s\n' "$MARKER_END"
	} >>"$tmp"
	mkdir -p "$(dirname "$file")"
	mv "$tmp" "$file"
}

upsert_marked_block() {
	local file="$1"
	local block="$2"
	if [[ -f "$file" ]] && grep -q "$MARKER_BEGIN" "$file"; then
		write_marked_block "$file" "$block"
		echo "updated herdr-mode include in $file"
	else
		write_marked_block "$file" "$block"
		echo "added herdr-mode include to $file"
	fi
}

install_kitty() {
	symlink_into "$ROOT/integrations/kitty/herdr-mode.conf" "$KITTY_DIR/herdr-mode.conf"
	symlink_into "$ROOT/integrations/kitty/herdr-mode-logo.conf" "$KITTY_DIR/herdr-mode-logo.conf"
	symlink_into "$ROOT/assets/herdr-logo.png" "$KITTY_DIR/herdr-logo.png"
	upsert_marked_block "$KITTY_DIR/kitty.conf" "$(kitty_block)"
	echo "kitty: reload with kitty, or close and reopen the terminal."
}

print_wezterm_snippet() {
	cat <<'EOF'

Add this to wezterm.lua (before `return config`):

    local herdr_mode = require("herdr_mode")
    config.keys = config.keys or {}
    config.key_tables = config.key_tables or {}
    herdr_mode.install(config.keys, config.key_tables)

    -- Optional indicator: color the active tab from herdr_mode.styles
    -- and herdr_mode.active_mode_for_tab(tab). Disable with:
    -- herdr_mode.install(config.keys, config.key_tables, { indicator = false })

Reload WezTerm after editing.

EOF
}

install_wezterm() {
	symlink_into "$ROOT/integrations/wezterm/herdr_mode.lua" "$WEZTERM_DIR/herdr_mode.lua"
	if [[ -f "$WEZTERM_DIR/wezterm.lua" ]] && grep -Eq "require\\([\"']herdr_mode[\"']\\)" "$WEZTERM_DIR/wezterm.lua"; then
		echo "wezterm: herdr_mode is already required in $WEZTERM_DIR/wezterm.lua"
	else
		echo "wezterm: linked module to $WEZTERM_DIR/herdr_mode.lua"
		echo "wezterm.lua was not modified."
		print_wezterm_snippet
	fi
}

for target in "${TARGETS[@]}"; do
	case "$target" in
	kitty) install_kitty ;;
	wezterm) install_wezterm ;;
	esac
done
