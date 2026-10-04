#!/bin/bash
# Exports the HTML5 build for CrazyGames into build/web and zips it as build/zombie-dorp-web.zip.
# Usage: GODOT=/path/to/godot4.3 tools/export_web.sh
set -e
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
mkdir -p build/web
"$GODOT" --headless --import >/dev/null 2>&1 || true
"$GODOT" --headless --export-release "Web (CrazyGames)" build/web/index.html
(cd build/web && zip -q -r ../zombie-dorp-web.zip .)
echo "Klaar: build/zombie-dorp-web.zip (upload dit bestand op CrazyGames)"
