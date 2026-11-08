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

# Preserve docs/reports/ (PNI501 report) across docs/ builds
PRESERVE_DIR=""
if [ -d "docs/reports" ]; then
    mkdir -p .drawlib/scratch
    PRESERVE_DIR=".drawlib/scratch/_preserved_reports_$$"
    rm -rf "$PRESERVE_DIR"
    cp -a "docs/reports" "$PRESERVE_DIR"
fi

echo "Building FastAPI Visual Architecture Guide HTML site -> docs/ ..."
$DRAWLIB_CMD build html docs_src/ -o docs/ -s docs_src/styles.py -u docs_src/utils.py

if [ -n "$PRESERVE_DIR" ] && [ -d "$PRESERVE_DIR" ]; then
    mkdir -p docs
    if [ ! -d "docs/reports" ]; then
        mv "$PRESERVE_DIR" "docs/reports"
    else
        rm -rf "$PRESERVE_DIR"
    fi
fi

touch docs/.nojekyll
echo "HTML site build complete: docs/"
