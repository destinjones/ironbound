#!/usr/bin/env bash
# Export the browser build of Ironbound.
#
#   GODOT=/path/to/godot tools/web/export.sh [OUT_DIR]
#
# Needs Godot 4.7.2 with the web export templates installed (only
# web_nothreads_release.zip is used). OUT_DIR defaults to build/web; the Website
# workflow exports into site/web so the game is published at <site>/web/.
# Serve the folder over http (python3 -m http.server -d build/web) to try it:
# the build is single-threaded, so it needs no special server headers.
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/build/web}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

cd "$ROOT"
COMMIT="$(git rev-parse --short=10 HEAD 2>/dev/null || echo unknown)"
BRANCH="${BUILD_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)}"
VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
printf '{"commit": "%s", "branch": "%s", "version": "%s"}\n' "$COMMIT" "$BRANCH" "$VERSION" > build_info.json

# The first import pass can log errors for scenes whose dependencies are not imported
# yet, so it runs twice.
"$GODOT" --headless --path . --import || true
"$GODOT" --headless --path . --import

rm -f "$OUT"/index.*
"$GODOT" --headless --path . --export-release "Web" "$OUT/index.html"
[ -s "$OUT/index.pck" ] && [ -s "$OUT/index.wasm" ] || { echo "web export produced nothing" >&2; exit 1; }
du -h "$OUT"/index.pck "$OUT"/index.wasm
