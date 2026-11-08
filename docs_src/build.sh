#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Building Bilingual HTML Site (docs_src/ -> docs/) ==="
"$SCRIPT_DIR/build_html.sh"

echo "Build completed successfully!"
