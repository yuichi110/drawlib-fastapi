#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

export UV_DEFAULT_INDEX="${UV_DEFAULT_INDEX:-https://pypi.org/simple}"

echo "=== [1/4] Building FastAPI User Guide (docs_src/ -> docs/) ==="
./docs_src/build_html.sh

echo "=== [2/4] Building FastAPI Internal Architecture Guide (architecture_src/ -> docs/architecture/) ==="
./architecture_src/build_html.sh

echo "=== [3/4] Building PNI501 Diagnostic Report (reports_src/pni501_src/ -> docs/reports/pni501/) ==="
uvx --default-index "$UV_DEFAULT_INDEX" --from pni501 pni report build pni501 \
  --src-dir reports_src \
  --output-dir docs/reports/pni501 \
  --html-output-dir docs/reports/pni501 \
  -f pdf -f html

touch docs/.nojekyll

echo "=== [4/4] Verifying Link & Asset Integrity across all 3 Portals (docs/) ==="
uvx --default-index "$UV_DEFAULT_INDEX" drawlib@0.3.9 serve docs/ --check

echo "All 3 portals built and verified with zero broken links!"
