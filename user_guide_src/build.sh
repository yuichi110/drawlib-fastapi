#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Building Bilingual User Guide HTML Site (user_guide_src/ -> docs/user_guide/) ==="
"$SCRIPT_DIR/build_html.sh"

echo "Build completed successfully!"
