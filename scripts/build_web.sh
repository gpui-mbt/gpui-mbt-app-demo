#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
moon build --target js --release --deny-warn src/web
WEB_JS="$(find _build/js/release/build -type f -path '*/src/web/web.js' -print -quit)"
[[ -n "$WEB_JS" ]] || {
  echo "could not find the generated src/web/web.js under _build/js/release/build" >&2
  exit 1
}
cp "$WEB_JS" web/moonbit.js
echo "Web demo: $ROOT_DIR/web/index.html"
