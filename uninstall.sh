#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
KITTY_DIR="$CONFIG_HOME/kitty"
WEZTERM_DIR="$CONFIG_HOME/wezterm"

MARKER_BEGIN="# herdr-mode begin"
MARKER_END="# herdr-mode end"

TARGETS=()

usage() {
	cat <<'EOF'
Usage: ./uninstall.sh <kitty|wezterm>...

Remove only the herdr-mode include block and the symlinks this repo created.
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
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

same_path() {
	local a="$1"
	local b="$2"
	local real_a real_b
	real_a="$(realpath "$a" 2>/dev/null || true)"
	real_b="$(realpath "$b" 2>/dev/null || true)"
	[[ -n "$real_a" && -n "$real_b" && "$real_a" == "$real_b" ]]
}

remove_our_symlink() {
	local dest="$1"
	local src="$2"
	if [[ -L "$dest" ]] && same_path "$dest" "$src"; then
		rm "$dest"
		echo "removed $dest"
	elif [[ -e "$dest" ]]; then
		echo "left $dest in place (not a herdr-mode symlink)"
	fi
}

remove_marked_block() {
	local file="$1"
	if [[ ! -f "$file" ]] || ! grep -q "$MARKER_BEGIN" "$file"; then
		return
	fi
	local tmp
	tmp="$(mktemp)"
	awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" '
		$0 == begin { skip = 1; next }
		skip && $0 == end { skip = 0; next }
		skip { next }
		{ print }
	' "$file" >"$tmp"
	# Drop a leftover blank line at EOF from the inserted block.
	awk 'NR==1{prev=$0; next} {print prev; prev=$0} END{if (prev != "") print prev}' "$tmp" >"${tmp}.out"
	mv "${tmp}.out" "$file"
	rm -f "$tmp"
	echo "removed herdr-mode include from $file"
}

uninstall_kitty() {
	remove_marked_block "$KITTY_DIR/kitty.conf"
	remove_our_symlink "$KITTY_DIR/herdr-mode.conf" "$ROOT/integrations/kitty/herdr-mode.conf"
	remove_our_symlink "$KITTY_DIR/herdr-mode-logo.conf" "$ROOT/integrations/kitty/herdr-mode-logo.conf"
	remove_our_symlink "$KITTY_DIR/herdr-logo.png" "$ROOT/assets/herdr-logo.png"
}

uninstall_wezterm() {
	remove_our_symlink "$WEZTERM_DIR/herdr_mode.lua" "$ROOT/integrations/wezterm/herdr_mode.lua"
	if [[ -f "$WEZTERM_DIR/wezterm.lua" ]] && grep -q 'herdr_mode' "$WEZTERM_DIR/wezterm.lua"; then
		cat <<EOF
wezterm: remove the herdr_mode require / install() calls from
  $WEZTERM_DIR/wezterm.lua
those lines were not auto-deleted.
EOF
	fi
}

for target in "${TARGETS[@]}"; do
	case "$target" in
	kitty) uninstall_kitty ;;
	wezterm) uninstall_wezterm ;;
	esac
done
