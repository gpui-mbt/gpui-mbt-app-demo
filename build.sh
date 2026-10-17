#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$ROOT_DIR/moon.work" && -f "$ROOT_DIR/../gpui.mbt/moon.mod" ]]; then
  "$ROOT_DIR/scripts/use-local-gpui.sh" >/dev/null
fi
exec "$ROOT_DIR/scripts/build_macos_app.sh" \
  --root "$ROOT_DIR" \
  --gpui-root "${GPUI_ROOT:-$ROOT_DIR/../gpui.mbt}" \
  --name GpuiMacDemo \
  --bundle-id org.gpui.mbt.app_demo \
  --package src/app \
  "$@"
