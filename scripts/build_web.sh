#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
moon build --target js --release --deny-warn src/web
cp _build/js/release/build/gpui_mbt/app_demo/src/web/web.js web/moonbit.js
echo "Web demo: $ROOT_DIR/web/index.html"
