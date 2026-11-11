#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

export UV_DEFAULT_INDEX="${UV_DEFAULT_INDEX:-https://pypi.org/simple}"

echo "=== [1/5] Building FastAPI User Guide (user_guide_src/ -> docs/user_guide/) ==="
./user_guide_src/build_html.sh

echo "=== [2/5] Building FastAPI API Reference Catalog (api_src/ -> docs/api/) ==="
./api_src/build_html.sh

echo "=== [3/5] Building FastAPI Internal Architecture Guide (architecture_src/ -> docs/architecture/) ==="
./architecture_src/build_html.sh

echo "=== [4/5] Building PNI501 Diagnostic Report (pni501_src/ -> docs/pni501/) ==="
uvx --default-index "$UV_DEFAULT_INDEX" --from pni501 pni report build pni501 \
  --src-dir . \
  --output-dir docs/pni501 \
  --html-output-dir docs/pni501 \
  -f pdf -f html

printf 'fastapi.drawlib.com' > docs/CNAME
touch docs/.nojekyll

echo "=== [5/5] Verifying Link & Asset Integrity across Showcase Hub & all 4 Portals (docs/) ==="
uvx --default-index "$UV_DEFAULT_INDEX" drawlib@0.3.9 serve docs/ --check

echo "Showcase Hub and all 4 portals built and verified with zero broken links!"
