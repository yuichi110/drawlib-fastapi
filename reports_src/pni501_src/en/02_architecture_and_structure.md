# 2. Architecture & Source Code Structure

FastAPI `v0.162.2` organizes **52 Python source modules** (**19,837 LOC**, **121 classes**, **438 functions**) into a disciplined **5-Tier Declarative ASGI Compiler & Type-Driven Adapter** architecture (**91/100**, Grade **S**). Rather than relying on import-time global registries or reflection-heavy request dispatch, FastAPI compiles standard Python type annotations and PEP 727 `Annotated[..., Doc()]` metadata at route-registration time into pre-built `Dependant` directed acyclic graphs (DAGs), Pydantic v2 `ModelField` validators, and asynchronous Starlette ASGI closures.

```drawlib align=center code=fold file=arch_source_tree.png caption="FastAPI v0.162.2 Source Package Tree & Subsystem LOC Distribution (52 Modules, 19,837 LOC)"
from drawlib.canvas import save, setup
from drawlib.fonts import FontMonoSpace, FontRoboto
from drawlib.icons import phosphor
from drawlib.smartarts import Panel, Table, TreeNode
from drawlib.styles import Colors, Styles
from drawlib.text import text

setup(width=146, height=84, dpi=150)

text(
    (73.0, 80.2),
    "FastAPI v0.162.2 — Physical Package Layout & Subsystem Inventory (52 Modules · 19,837 LOC)",
    style=Styles.DarkBold.patch(text_font=FontRoboto.ROBOTO_BOLD, text_size=13.0),
)

# Left Panel: Physical Package Hierarchy (TreeNode anchored Top-Left)
left_panel = Panel(
    "Package Tree (fastapi/)",
    "PEP 561 py.typed",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_font=FontRoboto.ROBOTO_BOLD, text_size=11.0),
    description_style=Styles.Muted.patch(text_font=FontRoboto.ROBOTO_REGULAR, text_size=9.5),
    icon=phosphor.folder_open,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=7.8,
)
left_panel.draw((4.0, 4.5), width=56.0, height=72.0, align="bottom_left")

TreeNode.register_drawing_item(
    name="pkg_dir",
    location="before",
    padding_width=3.8,
    function=phosphor.folder,
    style=Styles.Primary.patch(icon_color=Colors.Primary, icon_style="fill"),
    args={"width": 2.7},
)
TreeNode.register_drawing_item(
    name="py_mod",
    location="before",
    padding_width=3.8,
    function=phosphor.file_code,
    style=Styles.Dark.patch(icon_color=Colors.Dark),
    args={"width": 2.6},
)
TreeNode.register_drawing_item(
    name="typed_marker",
    location="before",
    padding_width=3.8,
    function=phosphor.shield_check,
    style=Styles.Success.patch(icon_color=Colors.Success),
    args={"width": 2.6},
)

root = TreeNode(
    "fastapi/ (52 files · 19,837 LOC)",
    text_style=Styles.DarkBold.patch(text_font=FontMonoSpace.ROBOTO_MONO_BOLD, text_size=9.6),
    line_style=Styles.Muted.patch(line_width=1.1),
    line_horizontal_margin=2.2,
    line_horizontal_length=2.4,
    line_vertical_margin=4.05,
).set_drawing_item("pkg_dir")

mod_text = Styles.Dark.patch(text_font=FontMonoSpace.ROBOTO_MONO_REGULAR, text_size=9.5)
sub_text = Styles.DarkBold.patch(text_font=FontMonoSpace.ROBOTO_MONO_BOLD, text_size=9.5)

root.add("applications.py (4,118 LOC)", text_style=mod_text).set_drawing_item("py_mod")
root.add("routing.py (5,726 LOC)", text_style=mod_text).set_drawing_item("py_mod")
root.add("param_functions.py (2,430 LOC)", text_style=mod_text).set_drawing_item("py_mod")
root.add("params.py (763 LOC)", text_style=mod_text).set_drawing_item("py_mod")
root.add("encoders.py & sse.py (523 LOC)", text_style=mod_text).set_drawing_item("py_mod")

deps_dir = root.add("dependencies/ (3 · 1,487 LOC)", text_style=sub_text).set_drawing_item("pkg_dir")
deps_dir.add("models.py & utils.py", text_style=mod_text).set_drawing_item("py_mod")

oas_dir = root.add("openapi/ (5 · 1,291 LOC)", text_style=sub_text).set_drawing_item("pkg_dir")
oas_dir.add("utils.py, models.py, docs.py", text_style=mod_text).set_drawing_item("py_mod")

root.add("security/ (7 · 1,294 LOC)", text_style=sub_text).set_drawing_item("pkg_dir")
root.add("telemetry/ (4 · 869 LOC)", text_style=sub_text).set_drawing_item("pkg_dir")
root.add("_compat/ (3 · 617 LOC)", text_style=sub_text).set_drawing_item("pkg_dir")
root.add("middleware/ (7 · 24 LOC)", text_style=sub_text).set_drawing_item("pkg_dir")
root.add("py.typed & Starlette facades", text_style=mod_text).set_drawing_item("typed_marker")

root.draw(xy=(7.0, 66.5))

# Right Panel: Subsystem LOC & Architectural Tier Mapping (Table anchored Top-Left)
right_panel = Panel(
    "Subsystem Inventory by Tier",
    "LOC & Core Symbols",
    style=Styles.White,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_font=FontRoboto.ROBOTO_BOLD, text_size=11.0),
    description_style=Styles.White.patch(text_font=FontRoboto.ROBOTO_REGULAR, text_size=9.5),
    icon=phosphor.table,
    icon_style=Styles.White,
    header_variant="filled",
    header_height=7.8,
)
right_panel.draw((63.0, 4.5), width=79.0, height=72.0, align="bottom_left")

tbl_body = Styles.Dark.patch(text_font=FontRoboto.ROBOTO_REGULAR, text_size=9.6)
tbl_code = Styles.DarkBold.patch(text_font=FontMonoSpace.ROBOTO_MONO_REGULAR, text_size=9.5)
tbl_hdr = Styles.DarkBold.patch(text_font=FontRoboto.ROBOTO_BOLD, text_size=10.0)

tbl = Table(
    cell_style=Styles.White,
    text_style=tbl_body,
    header_cell_style=Styles.SecondaryNeutral,
    header_text_style=tbl_hdr,
    border_style=Styles.MutedThin,
)
tbl.set_style_cell_evenodd(
    even_color=Colors.Light,
    even_text_style=tbl_body,
    odd_color=Colors.White,
    odd_text_style=tbl_body,
)
tbl.set_style_cell_header(
    background_color=Colors.SecondaryNeutral,
    text_style=tbl_hdr,
)
tbl.set_style_cell(
    background_color=Colors.Light,
    text_style=tbl_code,
    rows=[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    columns=[0],
)

inventory_rows = [
    ["Module / Subpackage", "Tier", "LOC", "Key Types & Responsibility"],
    ["applications.py", "T5", "4,118", "FastAPI app, lifespan & docs routes"],
    ["param_functions.py", "T5", "2,430", "Query, Path, Body, Depends, Doc()"],
    ["routing.py", "T4", "5,726", "APIRouter, APIRoute, SSE/WS engine"],
    ["openapi/ (5)", "T4", "1,291", "OpenAPI 3.1.0, Swagger UI & ReDoc"],
    ["sse.py & handlers", "T4", "218", "EventSourceResponse & 422 JSON"],
    ["dependencies/ (3)", "T3", "1,487", "Dependant & solve_dependencies()"],
    ["security/ (7)", "T3", "1,294", "OAuth2, HTTPBearer, APIKey, OIDC"],
    ["telemetry/ & mw/", "T2", "924", "NativeTelemetry & AsyncExitStack"],
    ["params.py & core", "T1", "1,566", "Param descriptors, encoders, utils"],
    ["_compat/ (3)", "T1", "617", "Pydantic v2 ModelField & schemas"],
]

tbl.draw_flexible(
    xy=(65.5, 66.5),
    column_widths=[22.5, 6.5, 8.0, 37.0],
    row_heights=[5.8] + [5.4] * 10,
    data=inventory_rows,
    align="top_left",
)

save()
```

---

## 2.1 System Profile, Core Dependency Stack & External Integrations

FastAPI operates purely as an embeddable **library runtime** (`runtime_types = ["library"]`, Python `>=3.10..3.14`) with a packaged PEP 561 `fastapi/py.typed` marker for strict downstream static type checking (`mypy`, `pyright`, and `ty`). Its core installation surface is intentionally constrained to **six SemVer-floored runtime packages** (`0` unpinned specifiers, `0` core runtime CVEs), delegating transport servers, multipart parsers, and alternative JSON serializers to optional extras (`[standard]`, `[all]`) and PEP 735 `[dependency-groups]`.

| Core Dependency (`pyproject.toml`) | Version Floor | Architectural Role in FastAPI `v0.162.2` | Primary Consumer Modules |
| :--- | :--- | :--- | :--- |
| `starlette` | `>=0.46.0` | Asynchronous ASGI 3.0 lifecycle, HTTP/WebSocket routing primitives, middleware wrapping, `Request`/`Response`, `BackgroundTasks`, and `TestClient`. | `applications.py`, `routing.py`, `middleware/*`, `responses.py` |
| `pydantic` *(+ `pydantic-core`)* | `>=2.9.0` | Rust-backed `TypeAdapter` validation, response serialization, composite body models, and `GenerateJsonSchema` OpenAPI `$defs` generation. | `_compat/v2.py`, `_compat/shared.py`, `params.py`, `openapi/models.py` |
| `typing-inspection` | `>=0.4.2` | High-speed runtime introspection of `Annotated[T, ...]` qualifiers, `Union` branches, and generic type aliases during route compilation. | `dependencies/utils.py`, `_compat/v2.py` |
| `typing-extensions` | `>=4.8.0` | Backported typing constructs (`Annotated`, `TypedDict`, `Literal`, `override`) ensuring uniform behavior across Python `3.10` through `3.14`. | `types.py`, `params.py`, `param_functions.py`, `applications.py` |
| `annotated-doc` | `>=0.0.2` | PEP 727 `Doc("...")` inline parameter documentation co-located directly inside public callable signatures for rich IDE hover tooltips. | `applications.py`, `routing.py`, `param_functions.py` |
| `opentelemetry-api` | `>=1.44.0` | Zero-vendor-lock-in distributed tracing spans, route-template attributes, runtime lifespan hooks, and exception telemetry recording. | `telemetry/_asgi.py`, `telemetry/_runtime.py`, `telemetry/_api.py` |

### External Integration Boundaries

1. **ASGI 3.0 Application Servers**: Uvicorn, Hypercorn, Granian, or Fastar invoke `FastAPI.__call__(scope, receive, send)` directly with zero framework-specific server coupling.
2. **Starlette ASGI Subsystems**: `FastAPI` subclasses `starlette.applications.Starlette`, composing Starlette's `Router`, lifespan context managers, `ServerErrorMiddleware`, `ExceptionMiddleware`, and thin developer re-export facades (`requests.py`, `websockets.py`, `staticfiles.py`, `templating.py`, `testclient.py`).
3. **Pydantic v2 Core Schema Engine**: `fastapi/_compat/v2.py` encapsulates `ModelField`, `TypeAdapter`, and `GenerateJsonSchema`, insulating routing and dependency resolution from internal Pydantic API churn.
4. **OpenTelemetry SDK & OTLP Exporters**: `fastapi/telemetry/_asgi.py` (`NativeTelemetry`, `ExceptionTelemetryMiddleware`) and `_runtime.py` emit low-overhead spans and exception events whenever an OpenTelemetry tracer/meter provider is configured.
5. **Interactive API Documentation Bundles**: `fastapi/openapi/docs.py` serves self-contained HTML entrypoints for Swagger UI (`/docs`, plus OAuth2 redirect support) and ReDoc (`/redoc`) bound to the lazy-synthesized `/openapi.json` document.

---

## 2.2 Five-Tier Declarative Architecture & Boundary Assessment

FastAPI enforces a strict top-down compilation and execution pipeline across **five architectural tiers**, progressing from public developer facades (`Tier 5`) down to Pydantic v2 schema/validation descriptors (`Tier 1`). Figure 2.2 overlays PNI501's deterministic `module_hotspots` risk scores (`0.12` to `0.27`) directly onto the five-tier UML component dependency graph.

```drawlib align=center code=fold file=arch_layer_thermal_dag.png caption="5-Tier Component Dependency DAG & Thermal Risk Score Overlay (routing.py=0.27, openapi/utils.py=0.27, _compat/v2.py=0.24)"
from drawlib.canvas import save, setup
from drawlib.charts.heatmap import HeatmapOverlay
from drawlib.diagrams.class_diagram import ClassDiagram, ClassNode
from drawlib.fonts import FontMonoSpace, FontRoboto
from drawlib.lines import lines
from drawlib.shapes import rectangle
from drawlib.styles import Colors, Styles
from drawlib.text import text

setup(width=146, height=118, dpi=150)

text(
    (73.0, 113.5),
    "5-Tier Component Dependency DAG & Module Hotspot Thermal Overlay (FastAPI v0.162.2)",
    style=Styles.DarkBold.patch(text_font=FontRoboto.ROBOTO_BOLD, text_size=13.0),
)

# Subtle horizontal tier swimlanes & left-hand tier badges (Z-Layer 1)
tier_specs = [
    (101.0, "Tier 5", "Public Facades"),
    (81.0, "Tier 4", "Routing & OAS"),
    (61.0, "Tier 3", "DI & Security"),
    (41.0, "Tier 2", "ASGI & OTel"),
    (21.0, "Tier 1", "Pydantic v2 Core"),
]
lane_style = Styles.Neutral.patch(
    shape_fill_color=Colors.Gray1.patch(alpha=0.45),
    shape_line_color=Colors.Gray3,
    shape_line_width=0.8,
    shape_r=1.5,
)
badge_style = Styles.SecondaryNeutral.patch(shape_r=1.5, shape_line_width=1.0)

for cy, t_num, t_sub in tier_specs:
    rectangle((87.5, cy), width=110.0, height=15.0, style=lane_style)
    rectangle((16.5, cy), width=22.0, height=12.4, style=badge_style)
    text(
        (16.5, cy + 2.3),
        t_num,
        style=Styles.DarkBold.patch(text_font=FontRoboto.ROBOTO_BOLD, text_size=10.5),
    )
    text(
        (16.5, cy - 2.4),
        t_sub,
        style=Styles.Muted.patch(text_font=FontRoboto.ROBOTO_REGULAR, text_size=9.5),
    )

# 5-Tier ClassDiagram (Z-Layer 2)
cd = ClassDiagram(
    width=146.0,
    height=118.0,
    node_style=Styles.Neutral.patch(
        shape_fill_color=Colors.White,
        shape_line_color=Colors.Gray6,
        text_color=Colors.Dark,
        text_font=FontMonoSpace.ROBOTO_MONO_REGULAR,
        text_size=9.5,
    ),
    header_style=Styles.PrimaryNeutral.patch(
        shape_line_color=Colors.Gray6,
        text_color=Colors.Dark,
        text_font=FontRoboto.ROBOTO_BOLD,
        text_size=10.2,
    ),
    edge_style=Styles.Dark.patch(line_width=1.5),
    edge_text_style=Styles.DarkBold.patch(text_font=FontRoboto.ROBOTO_BOLD, text_size=9.5),
)

hero_hdr = Styles.PrimaryFlat.patch(
    text_color=Colors.White,
    text_font=FontRoboto.ROBOTO_BOLD,
    text_size=10.2,
)
sec_hdr = Styles.SecondaryNeutral.patch(
    shape_line_color=Colors.Gray6,
    text_color=Colors.Dark,
    text_font=FontRoboto.ROBOTO_BOLD,
    text_size=10.2,
)

# Tier 5 (cy=101.0)
app_node = cd.add(
    ClassNode("FastAPI  [0.12]", width=44.0, header_style=hero_hdr)
    .add_attribute("module", "applications.py (4,118)")
    .add_method("__call__", "scope, receive, send", "None"),
    xy=(58.0, 101.0),
)
param_fn_node = cd.add(
    ClassNode("ParamFunctions  [0.12]", width=43.0, header_style=sec_hdr)
    .add_attribute("module", "param_functions.py (2,430)")
    .add_method("Query / Body / Depends", "", "Any"),
    xy=(114.5, 101.0),
)

# Tier 4 (cy=81.0)
route_node = cd.add(
    ClassNode("APIRoute  [risk=0.27]", width=44.0)
    .add_attribute("module", "routing.py (5,726 LOC)")
    .add_method("get_request_handler", "", "Coroutine"),
    xy=(58.0, 81.0),
)
openapi_node = cd.add(
    ClassNode("OpenAPISchema  [risk=0.27]", width=43.0)
    .add_attribute("module", "openapi/utils.py (631)")
    .add_method("get_openapi_path", "route", "tuple"),
    xy=(114.5, 81.0),
)

# Tier 3 (cy=61.0)
dep_node = cd.add(
    ClassNode("Dependant  [0.12]", width=44.0)
    .add_attribute("module", "dependencies/utils.py")
    .add_method("solve_dependencies", "req", "Solved"),
    xy=(58.0, 61.0),
)
sec_node = cd.add(
    ClassNode("OAuth2Bearer  [0.12]", width=43.0, header_style=sec_hdr)
    .add_attribute("module", "security/oauth2.py (603)")
    .add_method("__call__", "request", "str | None"),
    xy=(114.5, 61.0),
)

# Tier 2 (cy=41.0)
mw_node = cd.add(
    ClassNode("AsyncExitStackMW", width=44.0, header_style=sec_hdr)
    .add_attribute("module", "middleware/ & concurrency")
    .add_method("contextmanager_in_threadpool", "", "Any"),
    xy=(58.0, 41.0),
)
otel_node = cd.add(
    ClassNode("NativeTelemetry  [0.12]", width=43.0, header_style=sec_hdr)
    .add_attribute("module", "telemetry/_asgi.py (420)")
    .add_method("__call__", "scope, receive, send", "None"),
    xy=(114.5, 41.0),
)

# Tier 1 (cy=21.0)
v2_node = cd.add(
    ClassNode("ModelField  [risk=0.24]", width=44.0)
    .add_attribute("module", "_compat/v2.py (405 LOC)")
    .add_method("validate", "val, loc", "Validated"),
    xy=(58.0, 21.0),
)
param_node = cd.add(
    ClassNode("Param  [risk=0.18]", width=43.0)
    .add_attribute("module", "params.py (763 LOC)")
    .add_attribute("in_", "ParamTypes (FieldInfo)"),
    xy=(114.5, 21.0),
)

# Downward architectural dependencies (clean dedicated ports & >=6.4 vertical gaps)
cd.connect(app_node, route_node, "composition", directed=True, start_side="bottom", end_side="top")
cd.connect(app_node, otel_node, "dependency", start_side="right", end_side="left")
cd.connect(openapi_node, route_node, "dependency", start_side="left", end_side="right")
cd.connect(route_node, dep_node, "composition", directed=True, start_side="bottom", end_side="top")
cd.connect(openapi_node, sec_node, "dependency", start_side="bottom", end_side="top")
cd.connect(dep_node, sec_node, "dependency", start_side="right", end_side="left")
cd.connect(dep_node, mw_node, "dependency", start_side="bottom", end_side="top")
cd.connect(mw_node, v2_node, "dependency", start_side="bottom", end_side="top")
cd.connect(
    v2_node,
    param_node,
    "association",
    directed=True,
    label="T1 cycle",
    start_side="right",
    end_side="left",
    style=Styles.WarningBold.patch(line_width=1.8),
)

cd.draw(xy=(0.0, 0.0))

# Outer right-hand orthogonal link: ParamFunctions (Tier 5) -> Param (Tier 1)
lines(
    [(136.0, 101.0), (140.8, 101.0), (140.8, 21.0), (136.0, 21.0)],
    arrow_head="->",
    style=Styles.DarkDashed.patch(line_width=1.5),
)

# Thermal Risk HeatmapOverlay (Z-Layer 3 — show_contour_lines=False per PNI guardrail)
overlay = HeatmapOverlay(
    styles=[Styles.PrimaryNeutral, Styles.WarningFlat, Styles.DangerFlat],
    width=146.0,
    height=118.0,
    mode="smooth",
    min_value=0.0,
    max_value=0.30,
    max_alpha=0.35,
    show_contour_lines=False,
)
overlay.add_spot(route_node, value=0.27, radius=16.5)
overlay.add_spot(openapi_node, value=0.27, radius=16.5)
overlay.add_spot(v2_node, value=0.24, radius=15.5)
overlay.add_spot(param_node, value=0.18, radius=14.5)
overlay.add_spot(app_node, value=0.12, radius=13.0)
overlay.add_spot(param_fn_node, value=0.12, radius=13.0)
overlay.add_spot(dep_node, value=0.12, radius=13.0)
overlay.add_spot(sec_node, value=0.12, radius=12.5)
overlay.add_spot(otel_node, value=0.12, radius=12.5)

overlay.draw(xy=(0.0, 0.0))
overlay.draw_colorbar(
    xy=(47.0, 6.2),
    text_style=Styles.Dark.patch(text_font=FontRoboto.ROBOTO_REGULAR, text_size=9.8),
    length=52.0,
    thickness=2.2,
    num_ticks=4,
    value_format="{:.2f}",
    label="PNI501 Module Hotspot Risk Score (0.00 – 0.30)",
)

save()
```

### Five-Tier Layer Specifications

| Layer | Module Paths (`52` Total) | Allowed Downward Dependencies | Core Architectural Responsibilities |
| :--- | :--- | :--- | :--- |
| **Tier 5: Public Application & Developer Facades** *(12 files)* | `fastapi/__init__.py`, `__main__.py`, `cli.py`, `applications.py`, `param_functions.py`, `requests.py`, `responses.py`, `websockets.py`, `staticfiles.py`, `templating.py`, `testclient.py`, `background.py` | Tiers `4`, `3`, `2`, `1` | Top-level `FastAPI` ASGI application class, PEP 727 `Doc()`-annotated parameter factory functions (`Query`, `Path`, `Body`, `Header`, `Cookie`, `Form`, `File`, `Depends`, `Security`), CLI stub, and ergonomic Starlette re-export facades. |
| **Tier 4: Routing, Streaming & OpenAPI Synthesis** *(8 files)* | `fastapi/routing.py`, `sse.py`, `openapi/__init__.py`, `openapi/utils.py`, `openapi/docs.py`, `openapi/models.py`, `openapi/constants.py`, `exception_handlers.py` | Tiers `3`, `2`, `1` | Compiles endpoint callables into Starlette ASGI handlers (`APIRouter`, `APIRoute`, `APIWebSocketRoute`), native Server-Sent Events (`EventSourceResponse`, `ServerSentEvent`) & JSONL streaming, HTTP/WebSocket `422` exception handlers, and OpenAPI `3.1.0` / Swagger UI / ReDoc generation. |
| **Tier 3: Dependency Injection & Security Subsystems** *(10 files)* | `fastapi/dependencies/{__init__,utils,models}.py`, `fastapi/security/{__init__,oauth2,http,api_key,open_id_connect_url,base,utils}.py` | Tiers `2`, `1` | Introspects callable signatures via `typing-inspection` into recursive `Dependant` DAGs, resolves per-request sub-dependencies with memoization and `AsyncExitStack` yield teardown, and enforces OAuth2, HTTP Basic/Bearer/Digest, APIKey, and OpenID Connect security schemes. |
| **Tier 2: ASGI Middleware, Concurrency & Native Telemetry** *(12 files)* | `fastapi/middleware/{__init__,asyncexitstack,cors,gzip,httpsredirect,trustedhost,wsgi}.py`, `concurrency.py`, `fastapi/telemetry/{__init__,_asgi,_runtime,_api}.py` | Tier `1` | Orchestrates request-scoped `AsyncExitStackMiddleware` cleanup, synchronous contextmanager worker-thread offloading (`contextmanager_in_threadpool`), Starlette middleware re-exports, and native OpenTelemetry span/exception instrumentation (`NativeTelemetry`). |
| **Tier 1: Pydantic v2 Adapter, Descriptors & Core Types** *(10 files)* | `fastapi/_compat/{__init__,v2,shared}.py`, `params.py`, `datastructures.py`, `encoders.py`, `exceptions.py`, `utils.py`, `types.py`, `logger.py` | *None (`[]` — Leaf Foundation)* | Encapsulates Pydantic v2 `ModelField` / `TypeAdapter` validation and `GenerateJsonSchema` hooks, `FieldInfo` parameter descriptors (`Param` hierarchy), `UploadFile` / `DefaultPlaceholder` data structures, `jsonable_encoder`, and core exception hierarchies. |

### Architectural Boundary & Coupling Assessment

Static AST import-graph verification across all `52` source modules confirms strong downward architectural discipline:

- **Cleanly Guarded Cross-Tier Type Cycles (`2`, Zero Runtime Impact)**: Two upward/peer type-annotation references—`fastapi.dependencies.utils -> fastapi.utils -> fastapi.routing -> fastapi.dependencies.utils` and `fastapi.routing <-> fastapi.utils`—are strictly isolated inside `if TYPE_CHECKING:` blocks, preventing import-time circularity while preserving full static type precision.
- **Localized Intra-Tier-1 Runtime Cycle (`1`)**: Exactly one runtime circular import chain exists inside the foundational leaf tier: `fastapi._compat.v2 -> fastapi.params -> fastapi.datastructures -> fastapi._compat.v2` (driven by runtime `Param` / `UploadFile` / `DefaultPlaceholder` cross-checks). No runtime cycles cross tier boundaries.
- **Private Submodule Boundary Crossings (`4`)**: `fastapi/applications.py`, `fastapi/routing.py`, and `fastapi/background.py` perform four internal imports directly from private underscore modules (`fastapi.telemetry._asgi`, `fastapi.telemetry._runtime`, and `fastapi.telemetry._api`) rather than routing through a package-level `fastapi/telemetry/__init__.py` facade.
- **Zero Global Mutable State (`0`)**: All route trees, OpenAPI schemas, and `dependency_overrides` live on explicit `FastAPI` or `APIRouter` instances, allowing multiple independent applications to coexist cleanly in the same Python process.

---

## 2.3 Pre-Sorted Module Hotspots & Source Module Inventory

### Pre-Sorted Module Hotspots (`module_hotspots`)

PNI501 ranks repository targets by composite static complexity, maintainability, typing, and supply-chain finding density. In FastAPI `v0.162.2`, maximum module risk caps at a modest **`0.27`** (zero `CRITICAL` or `HIGH` source code findings), concentrated in the two intentional compilation/synthesis workhorses (`fastapi/routing.py` and `fastapi/openapi/utils.py`):

| Rank | Target Path | LOC | `risk_score` | Findings | Triggered Rules | Primary Engineering Driver |
| :---: | :--- | ---: | :---: | :--- | :--- | :--- |
| **1** | `fastapi/routing.py` | `5,726` | **`0.27`** | `1 medium` | `common/maintainability` | `get_request_handler` (`cognitive=159`, `408` LOC) unifies body parsing, `solve_dependencies()`, endpoint execution, SSE/JSONL streaming, and response serialization in one hot-path closure. |
| **2** | `fastapi/openapi/utils.py` | `631` | **`0.27`** | `1 medium` | `common/maintainability` | `get_openapi_path` (`cognitive=109`, `230` LOC) merges parameters, request bodies, OAuth2 scopes, callbacks, and status responses in one synthesis pass. |
| **3** | `fastapi/_compat/v2.py` | `405` | **`0.24`** | `2 low` | `common/architecture`, `python/code_quality` | Participates in the intra-Tier-1 runtime import cycle with `params.py` / `datastructures.py` and defines a `values: dict[str, Any] = {}` default in `ModelField.validate`. |
| **4** | `fastapi/params.py` | `763` | **`0.18`** | `1 low` | `python/typing` | Descriptor `__init__` signatures omit explicit `-> None` return annotations across `Param` / `FieldInfo` subclasses (`Path.in_` untyped class attribute). |
| **5** | `uv.lock` | `0` | **`0.15`** | `1 medium` | `common/security_vulnerability` | Transitive optional/dev lockfile entry `dnspython@2.8.0` carries `CVE-2026-114605` (fixed in `2.9.0`; core `fastapi` installs are unaffected). |
| **6** | `fastapi/applications.py` | `4,118` | **`0.12`** | `0` | `—` | Extensive inline PEP 727 `Doc()` reference documentation across `FastAPI.__init__` and HTTP verb decorators; runtime `setup()` cognitive complexity is only `12`. |
| **7** | `fastapi/param_functions.py` | `2,430` | **`0.12`** | `0` | `—` | Pure declarative factory functions (`Path`, `Query`, `Header`, `Cookie`, `Body`, `Form`, `File`, `Depends`, `Security`) rich in `@overload` and `Doc()` metadata. |
| **8** | `fastapi/dependencies/utils.py` | `1,294` | **`0.12`** | `0` | `—` | Recursive signature analyzer (`get_dependant`, `analyze_param`) and async DAG solver (`solve_dependencies`); `routing` type cycle guarded by `TYPE_CHECKING`. |

### Representative Source Module Inventory (`52` Modules, `19,837` LOC)

| Module / Subpackage | Tier | LOC | Public Types | Key Callables & Architectural Role |
| :--- | :---: | ---: | :--- | :--- |
| `fastapi/__init__.py` | T5 | `22` | *(20 PEP 484 `X as X` exports)* | Canonical package entrypoint exporting `FastAPI`, `APIRouter`, `Depends`, `Query`, `Body`, `HTTPException`, `status`, and `UploadFile`. |
| `fastapi/applications.py` | T5 | `4,118` | `FastAPI` | Top-level ASGI application orchestrating middleware stack assembly, OpenTelemetry lifespan wrapping, OpenAPI caching, and route registration. |
| `fastapi/param_functions.py` | T5 | `2,430` | — | Developer-facing `Path`, `Query`, `Header`, `Cookie`, `Body`, `Form`, `File`, `Depends`, and `Security` factory functions. |
| `fastapi/responses.py` & `background.py` | T5 | `126` | `ORJSONResponse`, `UJSONResponse`, `BackgroundTasks` | Optional high-throughput JSON response classes (`76` LOC) and telemetry-aware `BackgroundTasks` subclass (`50` LOC). |
| `fastapi/cli.py` & `__main__.py` | T5 | `12` | — | `main()` CLI entrypoint delegating cleanly to `fastapi_cli.cli.main` (raises `RuntimeError` without `sys.exit` if `[standard]` extra is absent). |
| `fastapi/{requests,websockets,staticfiles,templating,testclient}.py` | T5 | `8` | — | Five 1–3 LOC convenience re-export modules surfacing Starlette's `Request`, `WebSocket`, `StaticFiles`, `Jinja2Templates`, and `TestClient`. |
| `fastapi/routing.py` | T4 | `5,726` | `APIRouter`, `APIRoute`, `APIWebSocketRoute`, `RouteContext` | Core route compiler (`get_request_handler`, `get_websocket_app`, `run_endpoint_function`, `serialize_response`, `iter_route_contexts`). |
| `fastapi/sse.py` | T4 | `190` | `EventSourceResponse`, `ServerSentEvent` | Zero-internal-dependency native Server-Sent Events serializer (`format_sse_event`) and streaming response engine. |
| `fastapi/openapi/utils.py` | T4 | `631` | — | `get_openapi`, `get_openapi_path`, `get_fields_from_routes`, `get_openapi_operation_metadata` — OpenAPI `3.1.0` specification synthesizer. |
| `fastapi/openapi/models.py` & `constants.py` | T4 | `319` | `OpenAPI`, `PathItem`, `Operation`, `Schema`, `Components`, `OAuthFlows` *(+34)* | Strictly typed Pydantic v2 models representing the OpenAPI `3.1.0` & JSON Schema specification (`316` LOC) plus `REF_PREFIX` constants (`3` LOC). |
| `fastapi/openapi/docs.py` | T4 | `341` | — | `get_swagger_ui_html`, `get_redoc_html`, `get_swagger_ui_oauth2_redirect_html` — interactive browser documentation renderers. |
| `fastapi/exception_handlers.py` | T4 | `28` | — | `http_exception_handler`, `request_validation_exception_handler`, `websocket_request_validation_exception_handler`. |
| `fastapi/dependencies/models.py` | T3 | `193` | `Dependant` | Immutable-style dataclass node representing a callable's typed parameters, sub-dependencies, security requirements, and cache key. |
| `fastapi/dependencies/utils.py` | T3 | `1,294` | `ParamDetails`, `SolvedDependency` | `get_dependant`, `analyze_param`, `solve_dependencies`, `request_params_to_args`, `request_body_to_args` — static analyzer and runtime DI executor. |
| `fastapi/security/{oauth2,http,api_key,open_id_connect_url,base,utils}.py` | T3 | `1,294` | `OAuth2PasswordBearer`, `SecurityScopes`, `HTTPBearer`, `HTTPBasic`, `HTTPDigest`, `APIKeyHeader`, `OpenIdConnect` | Seven-file pluggable authentication & scope-enforcement suite integrated natively with `Depends()` / `Security()` (`secrets.compare_digest` in HTTP Basic/Digest). |
| `fastapi/telemetry/{_asgi,_api,_runtime,__init__}.py` | T2 | `869` | `NativeTelemetry`, `ExceptionTelemetryMiddleware`, `TelemetryConfig`, `TelemetryData` | Four-file native OpenTelemetry subsystem (`get_telemetry_data`, `lifespan`) capturing ASGI HTTP/WebSocket spans and uncaught exceptions. |
| `fastapi/concurrency.py` & `middleware/*` | T2 | `55` | `AsyncExitStackMiddleware` | `contextmanager_in_threadpool` (`31` LOC) plus `AsyncExitStackMiddleware` (`12` LOC) and 6 Starlette middleware re-exports (`12` LOC). |
| `fastapi/_compat/{v2,shared,__init__}.py` | T1 | `617` | `ModelField`, `GenerateJsonSchema` | `evaluate_forwardref`, `get_definitions`, `create_body_model`, `lenient_issubclass`, `field_annotation_is_scalar` — Pydantic v2 adapter layer. |
| `fastapi/params.py` | T1 | `763` | `Param`, `ParamTypes`, `Path`, `Query`, `Header`, `Cookie`, `Body`, `Form`, `File`, `Depends`, `Security` | Descriptor subclasses extending Pydantic `FieldInfo` with parameter location (`in_`), media types, and OpenAPI metadata. |
| `fastapi/encoders.py` | T1 | `333` | `Color`, `PyExtraColor` | `jsonable_encoder`, `isoformat`, `decimal_encoder` — recursive Python-object-to-JSON-primitive serializer. |
| `fastapi/exceptions.py` | T1 | `201` | `FastAPIError`, `HTTPException`, `RequestValidationError`, `ResponseValidationError`, `DependencyScopeError` *(+6)* | Structured framework, validation, dependency-scope, and WebSocket exception hierarchy. |
| `fastapi/{datastructures,utils,types,logger}.py` | T1 | `267` | `UploadFile`, `DefaultPlaceholder` | `Default()` sentinel & `UploadFile` wrapper (`141` LOC), `create_model_field` / `deep_dict_update` (`114` LOC), type aliases (`10` LOC), and named `fastapi` logger (`2` LOC). |

---

## 2.4 Entry Points, Runtime Execution Lifecycles, State & Concurrency Model

FastAPI separates **import-time signature compilation** from **request-time asynchronous execution** and **lazy first-hit OpenAPI synthesis**. Figure 2.3 traces these three lifecycles along a vertical execution roadmap.

```drawlib align=center code=fold file=arch_execution_flows.png caption="FastAPI v0.162.2 Core Runtime Lifecycles: Startup Route Compilation, Per-Request DI Dispatch & Lazy OpenAPI Synthesis"
from drawlib.canvas import save, setup
from drawlib.fonts import FontRoboto
from drawlib.icons import phosphor
from drawlib.smartarts import Panel, Roadmap
from drawlib.styles import Styles

setup(width=146, height=74, dpi=150)

frame = Panel(
    "FastAPI v0.162.2 — Core Runtime Execution Lifecycles",
    "ASGI 3.0 + AnyIO",
    style=Styles.White,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_font=FontRoboto.ROBOTO_BOLD, text_size=11.5),
    description_style=Styles.Muted.patch(text_font=FontRoboto.ROBOTO_REGULAR, text_size=9.8),
    icon=phosphor.pulse,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.2,
)
frame.draw((4.0, 4.0), width=138.0, height=66.0, align="bottom_left")
inner_xy, inner_w, inner_h = frame.get_content_box(
    (4.0, 4.0),
    width=138.0,
    height=66.0,
    padding=(4.0, 3.2),
    align="bottom_left",
)

rm = Roadmap(
    style=Styles.Neutral,
    text_style=Styles.DarkBold.patch(text_font=FontRoboto.ROBOTO_BOLD, text_size=10.6),
    description_style=Styles.Dark.patch(text_font=FontRoboto.ROBOTO_REGULAR, text_size=9.6),
    spine_style=Styles.DarkBold,
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_font=FontRoboto.ROBOTO_BOLD, text_size=10.0),
    icon_style=Styles.DarkBold,
    direction="vertical",
    curve_bend=0.0,
    card_shape="rounded_rect",
    spacing=3.0,
)

rm.add(
    "Flow 1 · Startup Route Compilation & Dependant DAG (@app.get, router)",
    "APIRoute -> get_dependant() [typing-inspection] -> ModelField -> handler closure",
    badge_text="Startup",
    icon=phosphor.git_branch,
)

rm.add(
    "Flow 2 · ASGI HTTP / SSE Dispatch, DI & Yield Teardown (FastAPI.__call__)",
    "Telemetry & ExitStackMW -> solve_dependencies() -> loop/threadpool -> SSE/JSON",
    badge_text="Hot Path",
    icon=phosphor.lightning,
    style=Styles.PrimaryNeutral,
    badge_style=Styles.PrimaryFlat,
    badge_text_style=Styles.WhiteBold.patch(text_font=FontRoboto.ROBOTO_BOLD, text_size=10.0),
    icon_style=Styles.PrimaryBold,
)

rm.add(
    "Flow 3 · Lazy OpenAPI 3.1.0 Synthesis & Docs Serving (/openapi.json)",
    "FastAPI.openapi() cache -> GenerateJsonSchema ($defs) -> Swagger UI / ReDoc",
    badge_text="Lazy OAS",
    icon=phosphor.file_code,
)

rm.draw(xy=inner_xy, width=inner_w, height=inner_h, align="bottom_left")

save()
```

### Public Entry Points & Three Execution Lifecycles

FastAPI exposes four canonical entry points: `fastapi/__init__.py` (re-exporting 20 public symbols via explicit PEP 484 `X as X` aliases), `fastapi/applications.py:FastAPI`, `fastapi/routing.py:APIRouter`, and `fastapi/cli.py:main`.

1. **Flow 1 — Startup Route Compilation & `Dependant` DAG Construction**
   - **Trigger**: Decorator registration (`@app.get`, `@router.post`) or router composition (`app.include_router`) at module import / startup time.
   - **Execution Chain**: `FastAPI` / `APIRouter` instantiates an `APIRoute` (or `APIWebSocketRoute`) in `fastapi/routing.py` -> `APIRoute.__init__` invokes `get_dependant()` and `analyze_param()` (`fastapi/dependencies/utils.py`), using `typing-inspection` to classify path, query, header, cookie, body, `Depends()`, and `Security()` parameters -> multi-field or scalar body parameters are compiled into Pydantic v2 `ModelField` / `TypeAdapter` validators (`fastapi/_compat/v2.py`) -> `APIRoute.get_route_handler()` pre-builds the asynchronous ASGI `request_response` closure via `get_request_handler()`, shifting reflection work out of the per-request hot path.
2. **Flow 2 — ASGI HTTP / SSE Request Dispatch, DI Resolution & `AsyncExitStack` Yield Teardown**
   - **Trigger**: Incoming ASGI HTTP or WebSocket `scope` delivered to `FastAPI.__call__(scope, receive, send)`.
   - **Execution Chain**: `NativeTelemetry` (when configured), `ServerErrorMiddleware`, user ASGI middlewares, `ExceptionMiddleware`, and `AsyncExitStackMiddleware` wrap the request -> Starlette's `Router` matches `APIRoute` and invokes its pre-compiled `get_request_handler()` closure -> JSON, form, or multipart request bodies are parsed and `solve_dependencies()` traverses the `Dependant` DAG using a per-request `dependency_cache` while pushing generator `yield` dependencies onto `AsyncExitStack` -> `run_endpoint_function()` awaits `async def` callables directly on the event loop or offloads synchronous `def` callables via `run_in_threadpool` -> `serialize_response()` validates/filters return payloads through Pydantic v2 `ModelField` (or streams `EventSourceResponse` / JSONL chunks), transmits ASGI response frames, unwinds request-scoped `yield` dependencies inside `AsyncExitStackMiddleware`, and executes `BackgroundTasks`.
3. **Flow 3 — Lazy OpenAPI 3.1.0 Schema Synthesis & Interactive Docs Serving**
   - **Trigger**: First `GET /openapi.json` request (or explicit `app.openapi()` invocation) alongside `GET /docs` or `GET /redoc`.
   - **Execution Chain**: `FastAPI.openapi()` checks `self.openapi_schema`; on first-access cache miss, it invokes `get_openapi()` (`fastapi/openapi/utils.py`) -> `get_fields_from_routes()` gathers every input/output `ModelField` across routes and `Dependant` trees, generating deduplicated JSON Schema `$defs` via `GenerateJsonSchema` (`fastapi/_compat/v2.py`) -> `get_openapi_path()` synthesizes operation metadata, security schemes, `requestBody`, callbacks, and status-code responses into an OpenAPI `3.1.0` dictionary cached on `app.openapi_schema` -> `fastapi/openapi/docs.py` serves Swagger UI (`/docs`) or ReDoc (`/redoc`) HTML bound to `openapi_url`.

### State Management, Ephemeral ASGI Scope Storage & Concurrency Model

- **Stateless Process Footprint & In-Memory Metadata**: `FastAPI` maintains zero database or filesystem state. Instance attributes hold only immutable-after-startup route lists (`APIRoute`), `dependency_overrides` mappings for test injection, middleware descriptors, and the lazily populated `self.openapi_schema` dictionary.
- **Two-Stage Ephemeral ASGI Scope Teardown (`fastapi_function_astack` vs. `fastapi_inner_astack`)**: During each request, FastAPI attaches two distinct `contextlib.AsyncExitStack` instances to the mutable ASGI `scope` dictionary alongside a per-request `dependency_cache` keyed by `(call, tuple(security_scopes))`:
  - `scope["fastapi_function_astack"]` (`scope="function"` yield dependencies): Entered before endpoint execution and **exited immediately after endpoint return / response serialization**, allowing `yield` cleanup blocks to raise or transform HTTP exceptions before headers are committed.
  - `scope["fastapi_inner_astack"]` (`scope="request"` yield dependencies, managed by `AsyncExitStackMiddleware`): Remains open across streaming bodies (`StreamingResponse`, `EventSourceResponse`) and **exits only after final ASGI response frames complete**, guaranteeing database sessions or streaming cursors are never closed mid-stream.
- **AnyIO Concurrency & Structured `422` Validation Model**: Backed by Starlette and AnyIO, `async def` endpoints and dependencies run directly on the active `asyncio` or `trio` event loop, while synchronous `def` endpoints and sync generator `yield` dependencies (`contextmanager_in_threadpool` in `fastapi/concurrency.py`) are automatically dispatched to AnyIO worker threads to prevent event-loop stalls. Input or contract violations raise `RequestValidationError`, `WebSocketRequestValidationError`, or `ResponseValidationError` (`fastapi/exceptions.py`), which `fastapi/exception_handlers.py` converts into deterministic HTTP `422` JSON error payloads.
