# 4. Audit Standards, Rule Compliance & Findings

PNI501 evaluated FastAPI `v0.162.2` across **6 deterministic audit steps** and **15 engineering compliance rules** spanning static AST maintainability, supply-chain security, PEP 621/561 packaging, library API hygiene, test determinism, and hermetic `--network=none` container execution. Every audit step achieved Grade `A` or `S` (`89/100` to `97/100`), yielding **10 `PASS` rules**, **5 advisory `WARN` rules**, **0 `FAIL` rules**, and **8 consolidated `MEDIUM`/`LOW` location findings** (`0 CRITICAL`, `0 HIGH`).

```drawlib align=center code=fold file=audit_step_scores_bar.png caption="Figure 4.1 — Executed PNI501 Audit Step Score Comparison (Weakest-First Ascending: 89 to 97) & Compliance Posture"
from drawlib.canvas import save, setup
from drawlib.charts.bar import BarChart
from drawlib.icons import phosphor
from drawlib.shapes import rectangle
from drawlib.smartarts import KpiCards
from drawlib.styles import Colors, Styles

setup(width=158, height=74, dpi=150)

# Framing card behind BarChart (neutral baseline)
rectangle(
    (56.0, 37.0),
    width=102.0,
    height=63.0,
    style=Styles.Neutral.patch(shape_r=2.0, shape_fill_color=Colors.White, shape_line_color=Colors.Gray3),
)

# Left: Weakest-First Ascending BarChart (Bottom-Left anchored at xy=(8.0, 12.5))
chart = BarChart(
    axis_line_style=Styles.MutedDashed,
    categories=[
        "python_\nast_\naudit",
        "security_\nvulnerability_\naudit",
        "repo_\nstructure_\naudit",
        "library_\nhygiene_\naudit",
        "python_\ntest_\naudit",
        "container_\nruntime_\naudit",
    ],
    width=96.0,
    height=51.0,
    title="Executed Audit Step Scores (/100, Sorted Weakest -> Strongest)",
    title_style=Styles.DarkBold.patch(text_size=11.5),
    orientation="vertical",
    bar_mode="group",
    bar_width_ratio=0.54,
    bar_r=0.9,
    axis_text_style=Styles.Dark.patch(text_size=9.5),
    grid_style=Styles.MutedThin,
    value_text_style=Styles.DarkBold.patch(text_size=10.0),
    value_format="{:.0f}",
)
chart.add_series("Audit Score", [89.0, 91.0, 93.0, 94.0, 95.0, 97.0], style=Styles.PrimaryFlat)
chart.configure_y_axis(min_value=0.0, max_value=108.0, ticks=[0.0, 20.0, 40.0, 60.0, 80.0, 100.0])
chart.draw(xy=(8.0, 12.5), align="bottom_left")

# Right: Compliance Summary KPI Stack (Bottom-Left anchored at xy=(111.0, 5.5))
kpi = KpiCards(
    style=Styles.Neutral,
    metric_style=Styles.PrimaryBold.patch(text_size=14.5),
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=9.5),
    accent_style=Styles.PrimaryFlat,
    icon_style=Styles.PrimaryBold,
    accent_position="left_pill",
    metric_layout="top_stack",
    spacing=3.0,
)
kpi.add(
    "93 / 100",
    "Overall Grade S",
    "5 Grade S & 1 Grade A steps",
    style=Styles.PrimaryNeutral,
    icon=phosphor.shield_check,
)
kpi.add(
    "10 / 15",
    "Rules Passed (0 FAIL)",
    "10 PASS · 5 WARN · 0 FAIL",
    style=Styles.SecondaryNeutral,
    metric_style=Styles.SecondaryBold.patch(text_size=14.5),
    accent_style=Styles.SecondaryFlat,
    icon=phosphor.check_circle,
    icon_style=Styles.SecondaryBold,
)
kpi.add(
    "0 High+",
    "Zero Critical / High",
    "3 MEDIUM · 5 LOW locations",
    style=Styles.Neutral,
    metric_style=Styles.DarkBold.patch(text_size=14.5),
    accent_style=Styles.DarkFlat,
    icon=phosphor.magnifying_glass,
    icon_style=Styles.DarkBold,
)
kpi.draw(xy=(111.0, 5.5), width=41.5, height=63.0, columns=1, align="bottom_left")

save()
```

---

## 4.1 Executed Audit Step Score Summary (`89 -> 97`)

All six audit primitives completed deterministically without execution errors. Sorted ascending from lowest score to highest score to spotlight improvement headroom first, FastAPI `v0.162.2` posts five **Grade S** (`>= 90`) ratings and one high **Grade A** (`89/100`) rating:

| Audit Step ID | Score & Grade | Rule Tally (`[pass/warn/fail]`) | Key Diagnostic Synthesis |
| :--- | :-: | :-: | :--- |
| **`python_ast_audit`** | **89 / 100 (A)** | `[pass=4, warn=3, fail=0]` | Across 52 Python modules (`19,837` LOC, `121` classes, `438` functions), FastAPI `v0.162.2` demonstrates exceptional security and typing discipline: `94.5%` callable type safety coverage, packaged PEP 561 `py.typed`, PEP 727 `Annotated[..., Doc()]` inline parameter documentation (`annotated_doc`), zero wildcard imports, zero empty or mismatched docstrings, zero hardcoded secrets, and zero dangerous CWE execution sinks. Structural complexity concentrates intentionally in five core runtime engines—`get_request_handler` (`cognitive=159`), `get_openapi_path` (`cognitive=109`), `NativeTelemetry.__call__` (`cognitive=85`), `analyze_param` (`cognitive=64`), and `solve_dependencies` (`cognitive=33`)—alongside a single runtime import cycle (`fastapi._compat.v2 <-> fastapi.params -> fastapi.datastructures`). |
| **`security_vulnerability_audit`** | **91 / 100 (S)** | `[pass=0, warn=2, fail=0]` | Core runtime dependencies (`starlette`, `pydantic`, `typing-extensions`, `typing-inspection`, `annotated-doc`, `opentelemetry-api`) contain **zero `CRITICAL` or `HIGH` CVEs**, zero hardcoded or committed secrets, zero container IaC misconfigurations, and zero dangerous CWE execution sinks across all 52 source modules. Trivy SCA identified 7 transitive lockfile advisories in `uv.lock` (`0 CRITICAL`, `1 HIGH`: `CVE-2026-114605` in optional `email-validator`'s transitive `dnspython@2.8.0 -> 2.9.0`, `5 MEDIUM`, `1 LOW`)—none affecting downstream consumers due to flexible `>=` SemVer bounds—while the `398` OS package advisories originate solely from the ephemeral Debian `12.13` test harness base image. |
| **`repo_structure_audit`** | **93 / 100 (S)** | `[pass=4, warn=1, fail=0]` | Exhibits exemplary PEP 621 packaging and dependency hygiene: 6 lean runtime dependencies with explicit SemVer lower bounds, zero unpinned specs, isolated PEP 735 `dependency-groups`, a deterministic `uv.lock` lockfile, and a packaged PEP 561 `py.typed` marker across 52 source modules and 273 core test modules. Only repository-level OpenSSF governance files (`SECURITY.md` and Dependabot config) are absent in this standalone showcase snapshot. |
| **`library_hygiene_audit`** | **94 / 100 (S)** | `[pass=2, warn=1, fail=0]` | Exemplifies gold-standard Python library hygiene: explicit PEP 484 `X as X` re-exports in `fastapi/__init__.py` across 20 canonical symbols, zero import-time I/O or network side effects, zero `sys.exit()` calls inside library code (`fastapi/cli.py` raises `RuntimeError` cleanly when `fastapi-cli` is absent), named `logging.getLogger('fastapi')` without `basicConfig` hijacking (`fastapi/logger.py`), and flexible `>=` lower-bound SemVer constraints across all 6 core dependencies. |
| **`python_test_audit`** | **95 / 100 (S)** | `[pass=1, warn=0, fail=0]` | Core framework test suite spans 273 test files and `1,835` test functions with `100.0%` static module test coverage across all 52 source modules (`5.25x` test-to-source file ratio). Strict `pytest` configuration (`--strict-config`, `--strict-markers`, `strict_xfail=true`, `filterwarnings=['error']`, `timeout=20`) enforces high determinism and warning-free execution, with only 2 assertion-free helper/warning test functions identified. |
| **`container_runtime_audit`** | **97 / 100 (S)** | `[pass=2, warn=0, fail=0]` | Hermetic containerized runtime verification (`--network=none`, non-root UID `10001`, Python `3.12`) passed cleanly across all gates: clean frozen `uv.lock` container build (`0.79s` cached), `100%` offline test pass across `3,228` collected items (`3,216` passed, `0` failed, `0` errors, `12` skipped in `265.57s`), `96.4%` measured line coverage (`4,628 / 4,801` statements) and `91.0%` branch coverage across `fastapi/`, and a clean zero-side-effect library import smoke check. |

---

## 4.2 Full 15-Rule Compliance Matrix (`FAIL -> WARN -> PASS`)

Across all 15 evaluated PNI501 engineering standards, FastAPI `v0.162.2` records **`0 FAIL`**, **`5 WARN`**, and **`10 PASS`** checks. The table below preserves the exact pre-sorted compliance order (`WARN` advisories first, followed by `PASS` standards):

| Status | Rule ID | Evaluated By | Diagnostic Evidence & Verification Summary |
| :-: | :--- | :--- | :--- |
| **`[WARN]`** | `common/architecture` | `python_ast_audit` | 1 runtime circular dependency (`fastapi._compat.v2 -> fastapi.params -> fastapi.datastructures -> fastapi._compat.v2`) and 4 private cross-domain imports from `fastapi.applications` / `routing` / `background` into `fastapi.telemetry._asgi` / `_runtime` / `_api`; 2 additional cycles are cleanly guarded under `TYPE_CHECKING`. |
| **`[WARN]`** | `common/maintainability` | `python_ast_audit` | `get_request_handler` (`fastapi/routing.py:397`, `cognitive=159`, `408` LOC), `get_openapi_path` (`fastapi/openapi/utils.py:303`, `cognitive=109`, `230` LOC), `NativeTelemetry.__call__` (`fastapi/telemetry/_asgi.py:228`, `cognitive=85`), `analyze_param` (`fastapi/dependencies/utils.py:409`, `cognitive=64`), and 52 wide ergonomic OpenAPI decorator signatures (`FastAPI.__init__` params=`37`, `get`/`post`/`put`/`delete` params=`23`). |
| **`[WARN]`** | `common/security_vulnerability` | `security_vulnerability_audit` | `dangerous_sinks=[]` across all 52 framework modules; built-in security primitives (`OAuth2`, `HTTPBearer`, `HTTPBasic`/`Digest` using `secrets.compare_digest`, `APIKey`, `OpenIdConnect`) enforce structured credential extraction. `SEC-01` `app_vuln_counts={critical:0, high:1, medium:5, low:1, total:7}` in transitive dev/optional `uv.lock` (`CVE-2026-114605` `dnspython@2.8.0 -> 2.9.0`) with `0` CVEs in core runtime dependencies; `os_vuln_counts=398` in ephemeral Debian `12.13` test harness image; `SEC-02` `misconfigurations=[]`; `SEC-03` `secrets=[]`; `SEC-04` `dangerous_sinks=[]`; `SEC-05` library security extractors enforce validation. |
| **`[WARN]`** | `common/supply_chain` | `repo_structure_audit` | `lockfiles_found=['uv.lock']`, `has_license=true` (`LICENSE` + `LICENSE-FASTAPI`), `ci_supply_chain_issues=[]`, `0` unpinned dependencies, and non-root UID `10001` container harness (`0` IaC misconfigurations); `has_security_policy=false` and `has_dependency_automation=false` because standalone showcase snapshot omits `SECURITY.md` and Dependabot config. |
| **`[WARN]`** | `python/code_quality` | `python_ast_audit` | `empty_docstrings=[]`, `doc_signature_mismatches=[]`, `wildcard_imports=[]`; conventional AST `docstring_coverage_pct=25.2%` because FastAPI adopts PEP 727 `Annotated[..., Doc()]` inline parameter documentation rather than traditional docstring blocks; 1 mutable default (`fastapi/_compat/v2.py:176`) and 3 silent `except-pass` blocks in `fastapi/routing.py:640,1880,2097`. |
| **`[PASS]`** | `common/documentation` | `repo_structure_audit` | `has_readme=true` (59 lines, 6 structured sections covering Purpose, Layout, Reproducible `uvx` Commands, and Licensing) + packaged `fastapi/py.typed` marker; PEP 727 `Annotated[..., Doc()]` inline documentation across all public classes/functions (`FastAPI`, `APIRouter`, `Path`, `Query`, `Body`, `Depends`, `Security`), zero `doc_signature_mismatches`, and zero `empty_docstrings`. |
| **`[PASS]`** | `common/git_workflow` | `repo_structure_audit` | `has_gitignore=true` (`.venv`, `__pycache__`, `.drawlib/`, `.pni/cache/` excluded); clean linear `main` branch with zero conflict markers. |
| **`[PASS]`** | `common/library_guidelines` | `library_hygiene_audit` | `fastapi/__init__.py` uses PEP 484 explicit `from ... import X as X` re-exports (20 public symbols), `fastapi/py.typed` is packaged, `fastapi/logger.py` uses `logging.getLogger('fastapi')` with zero root-logger hijacking, zero `sys.exit()` calls exist in `fastapi/`, and all 6 core dependencies in `pyproject.toml` use flexible `>=` floors without upper-bound caps. |
| **`[PASS]`** | `common/production_readiness` | `container_runtime_audit` | `missing_io_timeouts=0`, native OpenTelemetry span/exception instrumentation in `fastapi/telemetry/_asgi.py` (`94.9%` line, `93.8%` branch coverage), deterministic `AsyncExitStack` teardown, and structured validation exception handlers. |
| **`[PASS]`** | `common/runtime_verification` | `container_runtime_audit` | `RV-01` `harness_build=passed` (`exit_code=0`, `.pni/dockerfiles/root/Dockerfile`); `RV-02` `test_execution=passed` under `--network=none` (`3,216` passed, `0` failed, `0` errors, `12` skipped); `RV-03` measured `line_coverage_pct=96.4%` (`4,628/4,801`) and `branch_coverage_pct=91.0%`; `RV-04` library `smoke_check=passed` (`'Imported fastapi cleanly'`). |
| **`[PASS]`** | `common/security` | `repo_structure_audit` | `committed_secret_files=[]`, `container_hygiene_issues=[]`, non-root UID `10001` configured in `.pni/dockerfiles/root/Dockerfile`; `hardcoded_secrets=[]`, `dangerous_sinks=[]`, `missing_io_timeouts=[]`, `global_state_usages=0`; 1 minor mutable default dict `values={}` in `fastapi/_compat/v2.py:176` (`ModelField.validate`, never mutated in-place). |
| **`[PASS]`** | `python/dependencies` | `repo_structure_audit` | `pyproject.toml` declares 6 explicit SemVer-floored runtime dependencies (`starlette>=0.46.0`, `pydantic>=2.9.0`, `typing-extensions>=4.8.0`, `typing-inspection>=0.4.2`, `annotated-doc>=0.0.2`, `opentelemetry-api>=1.44.0`), `unpinned_dependencies=[]`, isolated `[dependency-groups]` (`dev`, `tests`, `docs`), and committed `uv.lock`. |
| **`[PASS]`** | `python/modern_stack` | `python_ast_audit` | Modern Python `>=3.10..3.14` stack using Pydantic v2 `TypeAdapter`, `typing-inspection`, `annotated-doc` (PEP 727), OpenTelemetry API, and `uv.lock`. The 38 `isort` group notices stem from FastAPI's explicit `[tool.ruff.lint.isort]` `known-third-party=['fastapi','pydantic','starlette']` convention; 6 `os.path` calls remain in `fastapi/routing.py` static SPA path resolution. |
| **`[PASS]`** | `python/testing` | `python_test_audit` | 273 core test files, `1,835` test functions, `module_test_coverage_pct=100.0%`, strict `pytest` settings (`strict_xfail=true`, `filterwarnings=['error']`, `timeout='20'`), and `inline_snapshot` OpenAPI 3.1 schema verification; only 2 assertion-free test functions (`tests/test_multipart_installation.py:141` and `tests/test_webhooks_security.py:34`). |
| **`[PASS]`** | `python/typing` | `python_ast_audit` | `type_safety_coverage_pct=94.5%`, `has_type_marker=true` (`fastapi/py.typed`), strict `mypy` + `ty` configuration in `pyproject.toml`; 29 missing annotations are almost exclusively `__init__ -> None` return omissions in `fastapi/params.py` and `datastructures.py`, plus 5 unscoped `# type: ignore` comments. |

---

## 4.3 Consolidated Location Findings Index (`CRITICAL -> INFO`)

Deduplicating raw tool observations by exact `file:line` yields **8 unique finding locations** (`0 CRITICAL`, `0 HIGH`, `3 MEDIUM`, `5 LOW`, `0 INFO`). Each row below maps a single source or manifest coordinate to its triggered rule ID, diagnostic evidence, and concrete remediation:

```drawlib align=center code=fold file=consolidated_findings_matrix.png caption="Figure 4.2 — Consolidated Location Findings Overview (8 Unique Locations: 0 CRITICAL · 0 HIGH · 3 MEDIUM · 5 LOW)"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.smartarts import Table
from drawlib.styles import Colors, Styles
from drawlib.text import text

setup(width=168, height=110, dpi=150)

phosphor.magnifying_glass((10.0, 104.0), width=4.2, style=Styles.PrimaryBold)
text(
    (84.0, 104.0),
    "Consolidated Location Findings Matrix (8 Unique file:line Coordinates  ·  3 MEDIUM  ·  5 LOW)",
    style=Styles.DarkBold.patch(text_size=11.5),
)

table = Table(
    cell_style=Styles.White,
    text_style=Styles.Dark.patch(text_size=9.5),
    header_cell_style=Styles.PrimaryFlat,
    header_text_style=Styles.WhiteBold.patch(text_size=10.0),
    border_style=Styles.MutedThin,
    has_header=True,
)

# 1. Alternating neutral row fills first
table.set_style_cell_evenodd(
    even_color=Colors.Gray1,
    even_text_style=Styles.Dark.patch(text_size=9.5),
    odd_color=Colors.White,
    odd_text_style=Styles.Dark.patch(text_size=9.5),
)

# 2. Re-apply header row style AFTER set_style_cell_evenodd
table.set_style_cell_header(
    background_color=Colors.Dark,
    text_style=Styles.WhiteBold.patch(text_size=10.0),
)

# 3. Highlight Severity column (rows 1..3 = MEDIUM AmberNeutral, rows 4..8 = LOW SecondaryNeutral)
table.set_style_cell(
    background_color=Colors.AmberNeutral,
    text_style=Styles.DarkBold.patch(text_size=9.5),
    rows=[1, 2, 3],
    columns=[0],
)
table.set_style_cell(
    background_color=Colors.SecondaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=9.5),
    rows=[4, 5, 6, 7, 8],
    columns=[0],
)

table.set_style_border(
    top=Styles.Dark.patch(line_width=1.4),
    top2=Styles.Dark.patch(line_width=1.1),
    bottom=Styles.Dark.patch(line_width=1.4),
    left=Styles.MutedThin,
    right=Styles.MutedThin,
    between_columns=Styles.MutedThin,
    between_rows=Styles.MutedThin,
)

findings_rows = [
    ["Severity", "Location (file:line)", "Rule ID", "Diagnostic Evidence", "Recommended Fix"],
    [
        "[MEDIUM]\n#1",
        "fastapi/openapi/\nutils.py:303",
        "common/maintainability",
        "length=230 LOC, branches=29,\ncognitive=109",
        "Factor response-schema &\ncallback builders into helpers",
    ],
    [
        "[MEDIUM]\n#2",
        "fastapi/routing.py:397",
        "common/maintainability",
        "length=408 LOC, branches=49,\ncognitive=159 (closure=157)",
        "Extract body, DI & response\nstages; keep closure cache",
    ],
    [
        "[MEDIUM]\n#3",
        "uv.lock:1",
        "common/security_vulnerability",
        "CVE-2026-114605 (HIGH 7.5):\ndnspython 2.8.0 -> 2.9.0",
        "Run uv lock --upgrade-package\ndnspython to >=2.9.0",
    ],
    [
        "[LOW]\n#4",
        "fastapi/_compat/\nv2.py:1",
        "common/architecture",
        "1 cycle: _compat.v2 <->\nparams -> datastructures",
        "Guard UploadFile/FieldInfo\nunder TYPE_CHECKING",
    ],
    [
        "[LOW]\n#5",
        "fastapi/_compat/\nv2.py:176",
        "python/code_quality",
        "Mutable default argument\n'values={}' (B006)",
        "Default values=None and\nnormalize inside method",
    ],
    [
        "[LOW]\n#6",
        "fastapi/params.py:30",
        "python/typing",
        "29 missing -> None returns &\n5 unscoped type: ignore",
        "Add -> None on __init__ &\nscope # type: ignore[code]",
    ],
    [
        "[LOW]\n#7",
        "pyproject.toml:1",
        "common/supply_chain",
        "has_security_policy=false,\ndependency_automation=false",
        "Add upstream SECURITY.md\nand Dependabot config",
    ],
    [
        "[LOW]\n#8",
        "tests/test_multipart_\ninstallation.py:141",
        "python/testing",
        "catch_warnings(record=True)\nhas no warning assert",
        "Bind as recorded and assert\nexpected warning explicitly",
    ],
]

# Top-Left anchored Table; Rule ID column width = 38.0 (>= 38 units guardrail)
table.draw_flexible(
    xy=(6.0, 99.5),
    column_widths=[14.0, 33.0, 38.0, 35.0, 36.0],
    row_heights=[8.0, 10.6, 10.6, 10.6, 10.6, 10.6, 10.6, 10.6, 10.6],
    data=findings_rows,
    align="top_left",
)

save()
```

### Detailed Consolidated Location Findings (`1..8`)

| # | Severity | Location (`file:line`) | Rule ID | Diagnostic Evidence | Concrete Fix Recommendation |
| :-: | :-: | :--- | :--- | :--- | :--- |
| **1** | **`[MEDIUM]`** | `fastapi/openapi/utils.py:303` | `common/maintainability` | `length=230 lines, branches=29, cognitive=109` | Factor response-schema assembly and callback operation generation into composable helper functions. |
| **2** | **`[MEDIUM]`** | `fastapi/routing.py:397` | `common/maintainability` | `length=408 lines, branches=49, cognitive=159 (inner app closure at line 428: cognitive=157)` | Extract dedicated helper stages (`_parse_request_body`, `_execute_solved_endpoint`, `_build_validated_response`) while preserving closure pre-computation for hot-path performance. |
| **3** | **`[MEDIUM]`** | `uv.lock:1` | `common/security_vulnerability` | `CVE-2026-114605 (HIGH, CVSS 7.5): dnspython 2.8.0 in uv.lock (fixed in 2.9.0; transitive dependency of optional email-validator)` | Run `uv lock --upgrade-package dnspython` in upstream maintenance cycles to bump locked `dnspython` from `2.8.0` to `>=2.9.0`. |
| **4** | **`[LOW]`** | `fastapi/_compat/v2.py:1` | `common/architecture` | `circular_dependencies=[['fastapi._compat.v2', 'fastapi.params', 'fastapi.datastructures', 'fastapi._compat.v2']]` | Guard type-only `UploadFile` / `FieldInfo` cross-references under `TYPE_CHECKING` or extract shared sentinel types into `fastapi.types`. |
| **5** | **`[LOW]`** | `fastapi/_compat/v2.py:176` | `python/code_quality` | `Mutable default argument 'values={}' (B006)` | Default `values` to `None` and normalize to `{}` or `MappingProxyType` inside the method body to prevent accidental shared-dict mutation. |
| **6** | **`[LOW]`** | `fastapi/params.py:30` | `python/typing` | `29 missing annotations (primarily __init__ -> None return annotations in fastapi/params.py and fastapi/datastructures.py) and 5 unscoped # type: ignore comments` | Add explicit `-> None` return annotations on descriptor `__init__` methods and scope remaining `# type: ignore[code]` directives. |
| **7** | **`[LOW]`** | `pyproject.toml:1` | `common/supply_chain` | `has_security_policy=false, has_dependency_automation=false` | If operating this showcase repository continuously, add a `SECURITY.md` pointing upstream FastAPI security reports to `github.com/fastapi/fastapi/security` and configure Dependabot for GitHub Actions. |
| **8** | **`[LOW]`** | `tests/test_multipart_installation.py:141` | `python/testing` | `with warnings.catch_warnings(record=True): ... contains no assert on captured warnings` | Bind `with warnings.catch_warnings(record=True) as recorded:` and assert the expected warning or clean registration behavior explicitly. |

---

## 4.4 Configured Scope & Accepted Design Waivers (`pni.toml`)

PNI501 explicitly tracks project-level `[[opt_out]]` waivers in `pni.toml` so intentional infrastructure choices remain transparent and auditable rather than silently suppressed. Exactly **1 design waiver** is configured for this diagnostic run:

| Waiver Rule ID | Configured Scope | Matched Findings | Engineering Justification |
| :--- | :--- | :-: | :--- |
| **`DS-0026`** | `[.pni/dockerfiles/**]` | `0` | Hermetic batch test container exits upon `pytest` completion; daemon `HEALTHCHECK` is not applicable. |
