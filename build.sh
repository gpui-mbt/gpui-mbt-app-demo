#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GPUI_ROOT="${GPUI_ROOT:-$ROOT_DIR/../gpui.mbt}"
if [[ ! -d "$GPUI_ROOT/platform/macos" ]]; then
  echo "macOS native builds need the gpui.mbt native shim sources." >&2
  echo "Set GPUI_ROOT to a gpui.mbt checkout, for example:" >&2
  echo "  GPUI_ROOT=/path/to/gpui.mbt ./build.sh --build" >&2
  exit 2
fi
exec "$ROOT_DIR/scripts/build_macos_app.sh" \
  --root "$ROOT_DIR" \
  --gpui-root "$GPUI_ROOT" \
  --name GpuiMacDemo \
  --bundle-id org.gpui.mbt.app_demo \
  --package src/app \
  "$@"
