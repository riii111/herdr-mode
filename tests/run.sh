#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 "$ROOT/tests/test_repo.py"
python3 "$ROOT/tests/test_kitty_herdr_mode.py"
