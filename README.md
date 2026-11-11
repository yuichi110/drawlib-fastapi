# FastAPI User Guide, API Reference, Architecture & PNI501 Audit (`drawlib-fastapi`)

> **Unofficial Multi-Portal Documentation & Diagnostic Suite — Built with [Drawlib](https://www.drawlib.com/) & [PNI501](https://pypi.org/project/pni501/)**
>
> This repository hosts an **independent, unofficial** four-portal documentation, API catalog, internal architecture guide, and software diagnostic showcase covering **[FastAPI](https://fastapi.tiangolo.com/)** (`v0.162.2`, tag `3adc94ef`).
> For official FastAPI documentation, tutorials, and release notes, always visit **[https://fastapi.tiangolo.com/](https://fastapi.tiangolo.com/)**.

---

## Live Portals (`https://fastapi.drawlib.com/`)

- **Showcase Hub (`docs/index.html`)**: [https://fastapi.drawlib.com/](https://fastapi.drawlib.com/) (English & 日本語)
  - Unified portal index linking to all four documentation and diagnostic portals below.
1. **FastAPI User Guide (`user_guide_src/` -> `docs/user_guide/`)**: [https://fastapi.drawlib.com/user_guide/](https://fastapi.drawlib.com/user_guide/) (English & 日本語)
   - Practical user guide, 100k+ LOC enterprise architecture patterns, and complete feature walkthrough backed by `pytest`-verified `v0.162.2` examples (`type = "site"`).
2. **FastAPI API Reference Catalog (`api_src/` -> `docs/api/`)**: [https://fastapi.drawlib.com/api/](https://fastapi.drawlib.com/api/) (English & 日本語)
   - Searchable symbol & CLI catalog (`type = "catalog"`) covering every public class, parameter descriptor, dependency, security extractor, response, SSE/OpenTelemetry API, OpenAPI helper, and CLI command in FastAPI `v0.162.2`.
3. **FastAPI Internal Architecture Guide (`architecture_src/` -> `docs/architecture/`)**: [https://fastapi.drawlib.com/architecture/](https://fastapi.drawlib.com/architecture/) (English & 日本語)
   - Source-level walkthrough of how FastAPI `v0.162.2` works internally (`type = "site"`): 5-tier package topology, `APIRoute` & `get_request_handler()` closure compilation, generator SSE/JSONL & `_FrontendRouteGroup` SPA engine, `Dependant` & `solve_dependencies()` dual `AsyncExitStack`s, `_compat/v2.py` `ModelField` bridge, 7-layer ASGI middleware & `NativeTelemetry`, and lazy `get_openapi()` synthesis.
4. **PNI501 Engineering & Architecture Diagnostic Report (`pni501_src/` -> `docs/pni501/`)**: [https://fastapi.drawlib.com/pni501/](https://fastapi.drawlib.com/pni501/) ([PDF](https://fastapi.drawlib.com/pni501/pni501.pdf))
   - Deterministic 15-stage code, dependency DAG, test coverage, and complexity audit (`93/100 Grade S`, `type = "doc"`).

---

## Repository Layout

```text
drawlib-fastapi/
├── fastapi/                  # Upstream FastAPI v0.162.2 framework source (MIT License, unmodified)
├── tests/                    # Upstream FastAPI v0.162.2 test suite (MIT License, unmodified)
├── pyproject.toml            # Upstream FastAPI v0.162.2 PEP 621 manifest (unmodified)
├── uv.lock                   # Upstream FastAPI v0.162.2 lockfile (unmodified)
├── LICENSE-FASTAPI           # Upstream MIT License (Copyright (c) 2018 Sebastián Ramírez)
├── LICENSE                   # Apache-2.0 License for original documentation, diagrams & audit assets
├── .pni/                     # PNI501 workflow & audit configuration
├── user_guide_src/           # Portal 1: FastAPI User Guide source (bilingual en/ja, type = "site")
├── api_src/                  # Portal 2: FastAPI API Reference source (bilingual en/ja, type = "catalog")
├── architecture_src/         # Portal 3: FastAPI Internal Architecture Guide source (bilingual en/ja, type = "site")
├── pni501_src/               # Portal 4: PNI501 diagnostic report source (type = "doc")
└── docs/                     # Unified compiled GitHub Pages output
    ├── index.html            # Showcase Hub (Portal Index)
    ├── user_guide/           # Portal 1: User Guide
    ├── api/                  # Portal 2: API Reference Catalog
    ├── architecture/         # Portal 3: Internal Architecture Guide
    └── pni501/               # Portal 4: PNI501 HTML & PDF report
```

---

## Reproducing Locally with `uvx`

`fastapi/`, `tests/`, `pyproject.toml`, and `uv.lock` remain unmodified from upstream FastAPI `v0.162.2`; `drawlib` and `pni501` run ephemerally via `uvx`:

```bash
# Build all 4 portals (User Guide + API Catalog + Internal Architecture + PNI501 HTML/PDF) & check links
./build.sh

# Or build each portal individually:
./user_guide_src/build.sh
./api_src/build.sh
./architecture_src/build.sh
./pni501_src/build.sh

# Or via PNI501 CLI:
uvx --from pni501 pni report build pni501 \
  --src-dir . \
  --html-output-dir docs/pni501 \
  --output-dir docs/pni501 \
  -f html -f pdf

# Preview locally & verify zero broken links
uvx drawlib serve docs/ --check
uvx drawlib serve docs/
```

---

## Licensing & Trademark Notice

- **Upstream FastAPI Snapshot (`fastapi/`, `tests/`, `pyproject.toml`, `uv.lock`)**:
  Copyright (c) 2018 Sebastián Ramírez. Distributed under the **MIT License** — see [`LICENSE-FASTAPI`](./LICENSE-FASTAPI).
- **Original Documentation, API Catalog, Diagrams & PNI501 Audit (`user_guide_src/`, `api_src/`, `architecture_src/`, `pni501_src/`, `docs/`, `.pni/`, build scripts)**:
  Copyright (c) 2026 Yuichi Ito. Distributed under the **Apache License, Version 2.0** — see [`LICENSE`](./LICENSE).
- **Trademark Attribution**:
  FastAPI is a registered trademark of Sebastián Ramírez. This repository is an independent community documentation and architecture study built with [Drawlib](https://www.drawlib.com/) and [PNI501](https://pypi.org/project/pni501/) and is not affiliated with, sponsored by, or endorsed by Sebastián Ramírez or the official FastAPI project.
