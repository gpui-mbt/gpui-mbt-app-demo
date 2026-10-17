#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
if [[ ! -f "$ROOT_DIR/moon.work" && -f "$ROOT_DIR/../gpui.mbt/moon.mod" ]]; then
  "$ROOT_DIR/scripts/use-local-gpui.sh" >/dev/null
fi
moon build --target js --release --deny-warn src/web
cp _build/js/release/build/gpui_mbt/app_demo/src/web/web.js web/moonbit.js
echo "Web demo: $ROOT_DIR/web/index.html"
