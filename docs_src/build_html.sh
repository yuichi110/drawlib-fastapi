#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PARENT_DIR"

if [ -z "${DRAWLIB_CMD:-}" ]; then
    if command -v drawlib &> /dev/null; then
        DRAWLIB_CMD="drawlib"
    elif command -v uvx &> /dev/null; then
        DRAWLIB_CMD="uvx --default-index ${UV_DEFAULT_INDEX:-https://pypi.org/simple} drawlib@0.3.9"
    else
        DRAWLIB_CMD="drawlib"
    fi
fi

# Preserve sub-portals (docs/reports/ and docs/architecture/) across root docs/ builds
PRESERVE_REPORTS=""
if [ -d "docs/reports" ]; then
    mkdir -p .drawlib/scratch
    PRESERVE_REPORTS=".drawlib/scratch/_preserved_reports_$$"
    rm -rf "$PRESERVE_REPORTS"
    cp -a "docs/reports" "$PRESERVE_REPORTS"
fi

PRESERVE_ARCH=""
if [ -d "docs/architecture" ]; then
    mkdir -p .drawlib/scratch
    PRESERVE_ARCH=".drawlib/scratch/_preserved_arch_$$"
    rm -rf "$PRESERVE_ARCH"
    cp -a "docs/architecture" "$PRESERVE_ARCH"
fi

echo "Building FastAPI User Guide HTML site -> docs/ ..."
$DRAWLIB_CMD build html docs_src/ -o docs/ -s docs_src/styles.py -u docs_src/utils.py

if [ -n "$PRESERVE_REPORTS" ] && [ -d "$PRESERVE_REPORTS" ]; then
    mkdir -p docs
    if [ ! -d "docs/reports" ]; then
        mv "$PRESERVE_REPORTS" "docs/reports"
    else
        rm -rf "$PRESERVE_REPORTS"
    fi
fi

if [ -n "$PRESERVE_ARCH" ] && [ -d "$PRESERVE_ARCH" ]; then
    mkdir -p docs
    if [ ! -d "docs/architecture" ]; then
        mv "$PRESERVE_ARCH" "docs/architecture"
    else
        rm -rf "$PRESERVE_ARCH"
    fi
fi

touch docs/.nojekyll
echo "HTML site build complete: docs/"
