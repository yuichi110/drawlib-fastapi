#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Building PNI501 Diagnostic Report HTML & PDF (pni501_src/ -> docs/pni501/) ==="
"$SCRIPT_DIR/build_html.sh"
"$SCRIPT_DIR/build_pdf.sh"

echo "Build completed successfully!"
