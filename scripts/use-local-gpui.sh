#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GPUI_DIR="${1:-$ROOT_DIR/../gpui.mbt}"
if [[ ! -f "$GPUI_DIR/moon.mod" ]]; then
  echo "not a gpui.mbt checkout: $GPUI_DIR" >&2
  exit 2
fi
GPUI_DIR="$(cd "$GPUI_DIR" && pwd)"
RELATIVE="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$GPUI_DIR" "$ROOT_DIR")"
cat > "$ROOT_DIR/moon.work" <<WORK
members = [
  ".",
  "$RELATIVE",
]
WORK
echo "wrote $ROOT_DIR/moon.work -> $RELATIVE"
