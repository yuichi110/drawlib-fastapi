# FastAPI Visual Architecture Guide & PNI501 Diagnostic Demo (`drawlib-fastapi`)

> **Unofficial Technical Showcase — Built with [Drawlib](https://www.drawlib.com/) & [PNI501](https://pypi.org/project/pni501/)**
>
> This repository is an **independent, unofficial** visual documentation and automated software diagnostic demonstration honoring **[FastAPI](https://fastapi.tiangolo.com/)** (`v0.162.2`, tag `3adc94ef`).
> For official FastAPI documentation, tutorials, and release notes, always visit **[https://fastapi.tiangolo.com/](https://fastapi.tiangolo.com/)**.

---

## Live Demo

- **FastAPI Visual Architecture Guide (`docs/`)**: [https://fastapi.drawlib.com/](https://fastapi.drawlib.com/) (English & 日本語)
- **PNI501 Engineering & Architecture Diagnostic Report (`docs/reports/pni501/`)**: [https://fastapi.drawlib.com/reports/pni501/](https://fastapi.drawlib.com/reports/pni501/) ([PDF](https://fastapi.drawlib.com/reports/pni501/pni501.pdf))

---

## What This Repository Demonstrates

1. **Zero-Pollution Documentation & Audit via `uvx`**:
   `fastapi/`, `tests/`, `pyproject.toml`, and `uv.lock` are kept unmodified from upstream FastAPI `v0.162.2`—neither `drawlib` nor `pni501` is added to `pyproject.toml`. Everything compiles cleanly via ephemeral `uvx` tool environments.
2. **Deterministic Pre-Documentation Code Analysis (`pni501`)**:
   Static Python AST semantics, module dependency DAGs, typing coverage, and complexity hotspots are extracted automatically via `uvx --from pni501 pni` (`reports_src/pni501_src/` -> `docs/reports/pni501/`).
3. **Illustrated Documentation as Code (`drawlib`)**:
   Bilingual (`en` / `ja`) visual architecture pages (`docs_src/` -> `docs/`) render high-DPI technical diagrams, sequence flows, DAG layouts, and APNG/GIF animations directly from version-controlled Markdown + Python blocks.

---

## Repository Layout

```text
drawlib-fastapi/
├── fastapi/                  # Upstream FastAPI v0.162.2 framework source (MIT License)
├── tests/                    # Upstream FastAPI v0.162.2 test suite (MIT License)
├── pyproject.toml            # Upstream FastAPI v0.162.2 PEP 621 manifest (unmodified)
├── uv.lock                   # Upstream FastAPI v0.162.2 lockfile (unmodified)
├── LICENSE-FASTAPI           # Upstream MIT License (Copyright (c) 2018 Sebastián Ramírez)
├── LICENSE                   # Apache-2.0 License for original Drawlib/PNI501 showcase assets
├── .pni/                     # PNI501 workflow & audit configuration
├── reports_src/
│   └── pni501_src/           # PNI501 diagnostic report Drawlib source (type = "doc")
├── docs_src/                 # FastAPI Visual Architecture Guide Drawlib source (type = "site")
└── docs/                     # Compiled HTML portal & PNI501 report (GitHub Pages root)
    ├── index.html
    └── reports/
        └── pni501/
```

---

## Reproducing Locally with `uvx`

```bash
# Build everything (Bilingual Visual Guide + PNI501 HTML/PDF Report + Link Check)
./build.sh

# Or build each portal individually:
./docs_src/build.sh
uvx --from pni501 pni report build pni501 \
  --src-dir reports_src \
  --html-output-dir docs/reports/pni501 \
  --output-dir docs/reports/pni501 \
  -f html -f pdf

# Preview locally & verify zero broken links
uvx drawlib serve docs/ --check
uvx drawlib serve docs/
```

---

## Licensing & Trademark Notice

- **Upstream FastAPI Snapshot (`fastapi/`, `tests/`, `pyproject.toml`, `uv.lock`)**:
  Copyright (c) 2018 Sebastián Ramírez. Distributed under the **MIT License** — see [`LICENSE-FASTAPI`](./LICENSE-FASTAPI).
- **Original Visual Documentation, Diagrams & PNI501 Showcase (`docs_src/`, `reports_src/`, `docs/`, `.pni/`, build scripts)**:
  Copyright (c) 2026 Yuichi Ito. Distributed under the **Apache License, Version 2.0** — see [`LICENSE`](./LICENSE).
- **Trademark Attribution**:
  FastAPI is a registered trademark of Sebastián Ramírez. This project is an independent technical showcase built with [Drawlib](https://www.drawlib.com/) and [PNI501](https://pypi.org/project/pni501/) and is not affiliated with, sponsored by, or endorsed by Sebastián Ramírez or the official FastAPI project.
