#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Building Bilingual Architecture HTML Site (architecture_src/ -> docs/architecture/) ==="
"$SCRIPT_DIR/build_html.sh"

echo "Build completed successfully!"
