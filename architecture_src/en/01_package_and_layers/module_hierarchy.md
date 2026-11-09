# 5-Tier Module Hierarchy, Starlette Shims & PEP 727 Doc()

FastAPI `v0.162.2` packs routing compilation, recursive dependency injection, Pydantic v2 validation, native Server-Sent Events, OpenTelemetry instrumentation, and OpenAPI `3.1.0` schema generation into just **`52` Python files (`19,837` LOC) with `0` circular imports**. Internally, every top-level import flows strictly downward across five architectural tiers while exposing an ergonomic, static-type-checked facade over Starlette, Pydantic v2, and `annotated-doc` (`PEP 727`).

```drawlib align=center code=hide file=five_tier_package_dag.png caption="FastAPI v0.162.2 Strict 5-Tier Acyclic Package Topology (52 Python Modules, Zero Circular Imports)"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Colors, Styles

setup(width=196, height=96, dpi=150)

# Left Panel: 5-Tier Top-Down Module DAG
p_dag = Panel(
    "5-Tier Acyclic Module DAG",
    "",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.stack,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
p_dag.draw((4.0, 4.0), width=120.0, height=88.0)
dx, dw, dh = p_dag.get_content_box((4.0, 4.0), width=120.0, height=88.0, padding=(3.5, 3.0))

tiers = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    direction="vertical",
    spacing=2.6,
    show_arrows=True,
    arrow_style=Styles.DarkBold.patch(line_arrow_head_scale=10, line_width=1.4),
)
tiers.add(
    "Tier 4 · Public Entrypoints & App Facade",
    "applications.py (FastAPI) · __init__.py · cli.py · __main__.py",
    badge_text="T4",
    icon=phosphor.rocket_launch,
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
    badge_style=Styles.White,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
)
tiers.add(
    "Tier 3 · Routing Compiler & OpenAPI Synthesis",
    "routing.py (APIRouter, APIRoute) · openapi/{utils,docs}.py",
    badge_text="T3",
    icon=phosphor.git_branch,
    style=Styles.PrimaryNeutral,
)
tiers.add(
    "Tier 2 · DI Solver, Security, SSE & Telemetry",
    "dependencies/* · security/* · telemetry/* · sse.py · responses.py",
    badge_text="T2",
    icon=phosphor.shield_check,
    style=Styles.SecondaryNeutral,
    badge_style=Styles.White.patch(shape_line_color=Colors.Gray4),
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
)
tiers.add(
    "Tier 1 · Pydantic v2 Bridge, Encoders & Params",
    "_compat/{v2,shared}.py · encoders.py · params.py · param_functions.py",
    badge_text="T1",
    icon=phosphor.brackets_curly,
    style=Styles.PrimaryNeutral,
)
tiers.add(
    "Tier 0 · Leaf Types, Exceptions, Constants & Shims",
    "types.py · exceptions.py · datastructures.py · requests.py · middleware/*",
    badge_text="T0",
    icon=phosphor.file_code,
    style=Styles.White,
)
tiers.draw(xy=dx, width=dw, height=dh)

# Right Panel: Cycle-Prevention Engineering Guards
p_guards = Panel(
    "Zero-Cycle Guards",
    "",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.check_circle,
    icon_style=Styles.SecondaryBold,
    header_variant="filled",
    header_height=8.5,
)
p_guards.draw((128.0, 4.0), width=64.0, height=88.0)
gx, gw, gh = p_guards.get_content_box((128.0, 4.0), width=64.0, height=88.0, padding=(3.5, 3.0))

guards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.4),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.SecondaryBold,
    direction="vertical",
    spacing=3.0,
)
guards.add(
    "TYPE_CHECKING Guard",
    "utils.py quotes 'APIRoute'",
    badge_text="G1",
    icon=phosphor.file_code,
)
guards.add(
    "Deferred Call Imports",
    "_compat/v2 & datastructures",
    badge_text="G2",
    icon=phosphor.arrows_split,
)
guards.add(
    "Leaf Constant Split",
    "constants.py & models.py",
    badge_text="G3",
    icon=phosphor.plugs,
)
guards.add(
    "Verified AST Topology",
    "52 files · 19,837 LOC · 0 cycles",
    badge_text="OK",
    icon=phosphor.check_circle,
    style=Styles.SecondaryNeutral,
    badge_style=Styles.White.patch(shape_line_color=Colors.Gray4),
)
guards.draw(xy=gx, width=gw, height=gh)

save()
```

## Strict 5-Tier Acyclic Package Topology

Static AST analysis of `./fastapi/` confirms that module-level `import` and `from ... import` statements form a strict Directed Acyclic Graph (DAG) partitioned into five tiers:

| Tier | Architectural Role | Upstream Modules (`v0.162.2`) | Permitted Internal Imports |
| :--- | :--- | :--- | :--- |
| **Tier 4** | **Application Orchestrator & Public Surface** | `applications.py` (`FastAPI`), `__init__.py` (`21` public symbols + `__version__`), `cli.py`, `__main__.py` | Tiers `0`–`3` (`routing`, `openapi.utils`, `openapi.docs`, `telemetry`, `exception_handlers`, `middleware.asyncexitstack`). |
| **Tier 3** | **Routing Compiler & OpenAPI Synthesis** | `routing.py` (`APIRouter`, `APIRoute`, `APIWebSocketRoute`), `openapi/utils.py` (`get_openapi`), `openapi/docs.py` | Tiers `0`–`2` (`dependencies.*`, `sse`, `telemetry._api`, `encoders`, `_compat`, `params`, `responses`); `openapi/utils.py` reads `routing` to inspect `APIRoute`. |
| **Tier 2** | **DI Solver, Security, Telemetry & Transport** | `dependencies/{models,utils}.py`, `security/{base,api_key,http,oauth2,open_id_connect_url,utils}.py`, `telemetry/{_api,_asgi,_runtime,__init__}.py`, `sse.py`, `responses.py`, `background.py`, `exception_handlers.py` | Tiers `0`–`1` (`_compat`, `params`, `param_functions`, `openapi.models`, `encoders`, `concurrency`, `exceptions`). |
| **Tier 1** | **Pydantic v2 Bridge, Encoders & Descriptors** | `_compat/{__init__,shared,v2}.py`, `encoders.py`, `params.py`, `param_functions.py`, `openapi/models.py`, `utils.py` | Tier `0` (`types`, `exceptions`, `datastructures`, `openapi.constants`, `logger`) plus external `pydantic` / `pydantic_core` / `annotated_doc`. |
| **Tier 0** | **Zero-Internal-Dependency Leaf Modules** | `types.py`, `exceptions.py`, `datastructures.py`, `openapi/constants.py`, `logger.py`, `concurrency.py`, `requests.py`, `websockets.py`, `staticfiles.py`, `templating.py`, `testclient.py`, `middleware/{__init__,asyncexitstack,cors,gzip,httpsredirect,trustedhost,wsgi}.py` | **Zero top-level `fastapi.*` imports** — depend only on Python stdlib, `starlette`, `pydantic`, `anyio`, and `annotated_doc`. |

### How FastAPI Maintains Zero Circular Imports

Three deliberate source-level techniques prevent upward dependency back-edges across `v0.162.2`:

1. **`if TYPE_CHECKING:` Forward-Reference Guards**: `fastapi/utils.py` (Tier 1) defines `generate_unique_id(route: "APIRoute") -> str`, which is imported as a default factory by `routing.py` (Tier 3) and `applications.py` (Tier 4). Importing `APIRoute` unconditionally in `utils.py` would create a `routing -> utils -> routing` cycle; guarding `from .routing import APIRoute` under `if TYPE_CHECKING:` with a stringified `"APIRoute"` annotation keeps runtime module loading strictly one-way.
2. **Call-Site Deferred Function Imports**: Where a lower tier needs a single helper from an adjacent or higher module only during execution, FastAPI defers the import inside the method body:
   - `datastructures.py` (`UploadFile.__get_pydantic_core_schema__`): defers `from ._compat.v2 import with_info_plain_validator_function` so `datastructures.py` remains a pure Tier 0 leaf at import time.
   - `_compat/v2.py` (`is_scalar_field`): defers `from fastapi import params` so `_compat` never cycles back into `params.py` (which imports `Undefined` from `_compat`).
   - `applications.py` (`FastAPI.__call__`): defers `from fastapi.telemetry._runtime import lifespan` until the ASGI `"lifespan"` scope runs.
3. **Narrow Leaf Splitting (`openapi/constants.py` & `openapi/models.py`)**: Instead of placing `REF_TEMPLATE = "#/components/schemas/{model}"` and Pydantic OpenAPI models (`Example`, `SecurityScheme`) inside `openapi/utils.py` (Tier 3), FastAPI isolates them in `openapi/constants.py` (Tier 0) and `openapi/models.py` (Tier 1). Consequently, `_compat/v2.py`, `params.py`, and `security/*` can reference OpenAPI constants and schema models without importing `openapi/utils.py`.

## The Starlette Facade Pattern & Explicit `X as X` Re-Exports

FastAPI is built directly on Starlette (`starlette>=0.46.0`), `FastAPI` subclasses `starlette.applications.Starlette`, and `APIRoute` subclasses `starlette.routing.Route`. Rather than forcing application code to mix `from fastapi import ...` and `from starlette... import ...`, FastAPI provides dedicated facade modules (`requests.py`, `responses.py`, `websockets.py`, `background.py`, `concurrency.py`, `staticfiles.py`, `templating.py`, `testclient.py`, and `middleware/*`).

Every pass-through shim uses **redundant `X as X` aliasing** (for example, `from starlette.requests import Request as Request` in `fastapi/requests.py` and `from starlette.middleware.cors import CORSMiddleware as CORSMiddleware` in `fastapi/middleware/cors.py`). Under **PEP 484 / PEP 561 stub and `--no-implicit-reexport` rules** enforced by `mypy`, `pyright`, and `ty`, a bare `from pkg import Symbol` marks `Symbol` as private to the importing module, whereas `from pkg import Symbol as Symbol` explicitly declares `Symbol` part of the module's public type-checked API without maintaining brittle `__all__` lists.

| Facade Category | FastAPI Modules & Symbols | Architectural Relationship to Starlette (`v0.162.2`) |
| :--- | :--- | :--- |
| **Pure `X as X` Identity Shims** | `requests.py` (`Request`, `HTTPConnection`), `websockets.py` (`WebSocket`, `WebSocketDisconnect`, `WebSocketState`), `staticfiles.py` (`StaticFiles`), `templating.py` (`Jinja2Templates`), `testclient.py` (`TestClient`), `middleware/{cors,gzip,httpsredirect,trustedhost,wsgi}.py` | Exact runtime class identity (`fastapi.Request is starlette.requests.Request`) with PEP 484 public re-export markers. |
| **Responses + Native SSE & Legacy JSON Shims** | `responses.py` (`Response`, `JSONResponse`, `HTMLResponse`, `PlainTextResponse`, `RedirectResponse`, `StreamingResponse`, `FileResponse`, `EventSourceResponse`, `ORJSONResponse`, `UJSONResponse`) | Re-exports Starlette responses plus `fastapi.sse.EventSourceResponse`. `ORJSONResponse` and `UJSONResponse` subclass `JSONResponse` and carry `@deprecated(..., category=FastAPIDeprecationWarning)` because `ModelField.serialize_json()` now serializes directly to JSON `bytes` in Rust. |
| **Telemetry-Instrumented `BackgroundTasks`** | `background.py` (`BackgroundTasks(StarletteBackgroundTasks)`) | Adds `ParamSpec` + `Doc()` typing on `add_task()` and overrides `__call__()` to wrap every task in `with _operation(name="background_task", function=task.func):`. |
| **Pydantic-Integrated `UploadFile`** | `datastructures.py` (`UploadFile(StarletteUploadFile)`) | Adds `__get_pydantic_core_schema__()` and `__get_pydantic_json_schema__()` (`type: "string", contentMediaType: "application/octet-stream"`) plus `Doc()` attribute annotations. |
| **Deadlock-Safe Threadpool Context** | `concurrency.py` (`contextmanager_in_threadpool` + Starlette `run_in_threadpool`, `iterate_in_threadpool`) | Runs sync `yield` dependency `__exit__` with a dedicated `anyio.CapacityLimiter(1)` (`exit_limiter`) so cleanup never deadlocks behind a saturated worker pool. |
| **Inner File-Cleanup Stack** | `middleware/asyncexitstack.py` (`AsyncExitStackMiddleware`) | FastAPI-native ASGI middleware injecting `scope["fastapi_middleware_astack"]` inside user middleware to close multipart `FormData` / `UploadFile` handles after response completion. |

## Parameter Descriptors (`params.py`), Factory Shims & PEP 727 `Doc()`

FastAPI splits parameter and dependency declarations across two cooperating Tier 1 modules—**`fastapi/params.py`** (`800` lines of runtime classes) and **`fastapi/param_functions.py`** (`2,569` lines of public factory functions re-exported in `fastapi/__init__.py`):

```drawlib align=center code=hide file=starlette_pydantic_facade.png caption="Starlette Facade Subclasses & Pydantic FieldInfo / Depends Descriptor Hierarchy with PEP 727 Doc()"
from drawlib.canvas import save, setup
from drawlib.diagrams.architecture import ArchitectureDiagram, Node, NodeGroup
from drawlib.icons import phosphor
from drawlib.styles import Colors, Styles

setup(width=196, height=98, dpi=150)

card_white = Styles.White.patch(shape_r=1.8, shape_line_color=Colors.Gray4)
card_pri = Styles.PrimaryNeutral.patch(shape_r=1.8)
card_sec = Styles.SecondaryNeutral.patch(shape_r=1.8)
card_focal = Styles.PrimaryFlat.patch(shape_r=1.8)

diag = ArchitectureDiagram(
    node_style=Styles.PrimaryBold,
    node_text_style=Styles.DarkBold.patch(text_size=10.0),
    node_card_style=card_white,
    edge_style=Styles.DarkBold.patch(line_arrow_head_scale=11, line_width=1.4),
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    width=188.0,
    height=90.0,
)

# Left Group: Starlette Facade & Value-Add Subclasses
g_star = diag.add(
    NodeGroup(
        title="Starlette Facade (Shims & Subclasses)",
        width=82.0,
        height=86.0,
        style=Styles.Neutral.patch(shape_r=2.0),
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left"),
    ),
    xy=(2.0, 2.0),
)

n_star_base = g_star.add(
    Node(
        "starlette.*\nStarlette · Request · Response",
        width=72.0,
        height=15.0,
        icon=phosphor.plugs,
        icon_size=4.6,
        style=Styles.SecondaryBold,
        card_style=card_sec,
    ),
    xy=(41.0, 68.0),
)
n_shims = g_star.add(
    Node(
        "X as X Shims\nrequests · websockets",
        width=34.0,
        height=16.5,
        icon=phosphor.arrows_split,
        icon_size=4.5,
        style=Styles.DarkBold,
        card_style=card_white,
    ),
    xy=(22.0, 39.5),
)
n_sub = g_star.add(
    Node(
        "Subclasses\nFastAPI · UploadFile\nBackgroundTasks",
        width=34.0,
        height=16.5,
        icon=phosphor.rocket_launch,
        icon_size=4.5,
        style=Styles.PrimaryBold,
        card_style=card_pri,
    ),
    xy=(60.0, 39.5),
)
n_resp = g_star.add(
    Node(
        "responses.py\nSSE & ORJSON",
        width=34.0,
        height=14.0,
        icon=phosphor.broadcast,
        icon_size=4.4,
        style=Styles.DarkBold,
        card_style=card_white,
    ),
    xy=(22.0, 11.5),
)
n_conc = g_star.add(
    Node(
        "concurrency.py\nExit Limiter & Stack",
        width=34.0,
        height=14.0,
        icon=phosphor.gear,
        icon_size=4.4,
        style=Styles.SecondaryBold,
        card_style=card_sec,
    ),
    xy=(60.0, 11.5),
)

n_shims.connect(n_star_base)
n_sub.connect(n_star_base)
n_resp.connect(n_shims)
n_conc.connect(n_sub)

# Right Group: Pydantic FieldInfo + Depends + PEP 727 Factories
g_pyd = diag.add(
    NodeGroup(
        title="Descriptors & PEP 727 Factories (params.py)",
        width=98.0,
        height=86.0,
        style=Styles.Neutral.patch(shape_r=2.0),
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left"),
    ),
    xy=(88.0, 2.0),
)

n_fi = g_pyd.add(
    Node(
        "pydantic.fields.FieldInfo\nConstraints, Aliases & Schema",
        width=57.0,
        height=15.0,
        icon=phosphor.brackets_curly,
        icon_size=4.6,
        style=Styles.SecondaryBold,
        card_style=card_sec,
    ),
    xy=(32.5, 68.0),
)
n_dep = g_pyd.add(
    Node(
        "Depends (dataclass)\nuse_cache · scope",
        width=29.5,
        height=15.0,
        icon=phosphor.shield_check,
        icon_size=4.6,
        style=Styles.SecondaryBold,
        card_style=card_sec,
    ),
    xy=(79.5, 68.0),
)

n_param = g_pyd.add(
    Node(
        "params.Param\nPath · Query\nHeader · Cookie",
        width=27.0,
        height=16.5,
        icon=phosphor.git_branch,
        icon_size=4.5,
        style=Styles.PrimaryBold,
        card_style=card_pri,
    ),
    xy=(17.5, 39.5),
)
n_body = g_pyd.add(
    Node(
        "params.Body\nBody -> Form\n-> File",
        width=27.0,
        height=16.5,
        icon=phosphor.cube,
        icon_size=4.5,
        style=Styles.PrimaryBold,
        card_style=card_pri,
    ),
    xy=(47.5, 39.5),
)
n_sec = g_pyd.add(
    Node(
        "params.Security\nscopes: list[str]",
        width=29.5,
        height=16.5,
        icon=phosphor.shield_check,
        icon_size=4.5,
        style=Styles.PrimaryBold,
        card_style=card_pri,
    ),
    xy=(79.5, 39.5),
)

n_pf_param = g_pyd.add(
    Node(
        "Path() · Query()\nDoc() -> Any",
        width=27.0,
        height=14.0,
        icon=phosphor.book_open,
        icon_size=4.4,
        style=Styles.DarkBold,
        card_style=card_white,
    ),
    xy=(17.5, 11.5),
)
n_pf_body = g_pyd.add(
    Node(
        "Body() · File()\nPEP 727 Doc()",
        width=27.0,
        height=14.0,
        icon=phosphor.book_open,
        icon_size=4.4,
        style=Styles.WhiteBold,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
        card_style=card_focal,
    ),
    xy=(47.5, 11.5),
)
n_pf_dep = g_pyd.add(
    Node(
        "Depends()\nSecurity()",
        width=29.5,
        height=14.0,
        icon=phosphor.book_open,
        icon_size=4.4,
        style=Styles.DarkBold,
        card_style=card_white,
    ),
    xy=(79.5, 11.5),
)

n_param.connect(n_fi)
n_body.connect(n_fi)
n_sec.connect(n_dep)
n_pf_param.connect(n_param)
n_pf_body.connect(n_body)
n_pf_dep.connect(n_sec)

diag.draw(xy=(4.0, 4.0))
save()
```

1. **Two Distinct `FieldInfo` Subtrees + Frozen DI Dataclasses (`fastapi/params.py`)**:
   - **Scalar HTTP Parameters (`Param(FieldInfo)`)**: `Path`, `Query`, `Header`, and `Cookie` inherit from `Param(FieldInfo)` and bind a `ParamTypes` enum discriminator (`ParamTypes.path`, `ParamTypes.query`, `ParamTypes.header`, `ParamTypes.cookie`). `Path.__init__` asserts `default is ...` because URL path segments are unconditionally required, while `Header.__init__` adds `convert_underscores: bool = True`.
   - **Payload Descriptors (`Body(FieldInfo)`)**: `Body` subclasses `pydantic.fields.FieldInfo` **directly** (not `Param`) and adds `embed: bool | None` plus `media_type = "application/json"`. `Form(Body)` specializes `media_type = "application/x-www-form-urlencoded"`, and `File(Form)` specializes `media_type = "multipart/form-data"`.
   - **Dependency Markers (`Depends` & `Security`)**: Rather than subclassing `FieldInfo`, `@dataclass(frozen=True) class Depends` stores `(dependency, use_cache=True, scope=None)`, and `@dataclass(frozen=True) class Security(Depends)` adds `scopes: Sequence[str] | None = None`.
2. **Why `param_functions.py` Returns `Any` While Annotating Parameters with PEP 727 `Doc()`**:
   - **Static Type Checker Compatibility**: If `fastapi.Query` were the class `params.Query`, legacy default syntax `q: str = Query("all")` would fail PEP 484 type checking (`Query` is not assignable to `str`). By exporting factory functions typed `-> Any` from `param_functions.py` (`from .param_functions import Query as Query`), both modern `Annotated[str, Query()]` and default-value `q: str = Query("all")` type-check cleanly while returning `fastapi.params.Query` instances at runtime.
   - **Single-Source Inline API Documentation (`annotated_doc.Doc`)**: Across `param_functions.py`, `applications.py`, `routing.py`, `exceptions.py`, `background.py`, `datastructures.py`, `sse.py`, `telemetry/_api.py`, and `security/*`, FastAPI wraps every public parameter in `Annotated[T, Doc("""...""")]` (`PEP 727`). Language servers and documentation extractors (`griffe-typingdoc`) surface rich per-argument hover docs straight from type signatures, and any `Doc(...)` placed by users inside `Annotated[int, Path(ge=1), Doc("...")]` is preserved inside `field_info.metadata`.

### Verifying Descriptor Inheritance, Facade Identity & PEP 727 Metadata

The following self-contained snippet verifies the runtime class hierarchy in `fastapi.params`, Starlette `X as X` identity versus subclassing, and PEP 727 `Doc()` extraction via `typing.get_type_hints(..., include_extras=True)`:

```python
from typing import get_args, get_type_hints

from annotated_doc import Doc
from fastapi import (
    BackgroundTasks,
    Depends,
    FastAPI,
    File,
    Form,
    HTTPException,
    Query,
    Request,
    Response,
    Security,
    UploadFile,
    WebSocket,
    params as fastapi_params,
)
from fastapi.params import Param, ParamTypes
from pydantic.fields import FieldInfo
from starlette.applications import Starlette
from starlette.background import BackgroundTasks as StarletteBackgroundTasks
from starlette.datastructures import UploadFile as StarletteUploadFile
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.requests import Request as StarletteRequest
from starlette.responses import Response as StarletteResponse
from starlette.websockets import WebSocket as StarletteWebSocket

# 1. Two FieldInfo subtrees (Param vs Body) and frozen Depends -> Security dataclasses
assert [p.value for p in ParamTypes] == ["query", "header", "path", "cookie"]
assert issubclass(Param, FieldInfo)
assert all(
    issubclass(cls, Param)
    for cls in (
        fastapi_params.Path,
        fastapi_params.Query,
        fastapi_params.Header,
        fastapi_params.Cookie,
    )
)
assert issubclass(fastapi_params.File, fastapi_params.Form)
assert issubclass(fastapi_params.Form, fastapi_params.Body)
assert issubclass(fastapi_params.Body, FieldInfo) and not issubclass(fastapi_params.Body, Param)

# 2. Public factories (param_functions.py -> Any) construct params.* instances
q_meta = Query(default="active", min_length=2)
assert type(q_meta) is fastapi_params.Query and q_meta.in_ is ParamTypes.query
sec_meta = Security(lambda: "svc", scopes=["orders:write"])
assert isinstance(sec_meta, fastapi_params.Security) and isinstance(sec_meta, fastapi_params.Depends)
assert isinstance(Depends(), fastapi_params.Depends) and isinstance(File(), fastapi_params.Form)
assert isinstance(Form(), fastapi_params.Body)

# 3. Starlette X as X identity shims vs FastAPI value-add subclasses
assert Request is StarletteRequest and Response is StarletteResponse and WebSocket is StarletteWebSocket
assert issubclass(FastAPI, Starlette) and FastAPI is not Starlette
assert issubclass(BackgroundTasks, StarletteBackgroundTasks)
assert issubclass(UploadFile, StarletteUploadFile)
assert issubclass(HTTPException, StarletteHTTPException)

# 4. PEP 727 annotated_doc.Doc() metadata attached to public factory parameters
ge_annotation = get_type_hints(Query, include_extras=True)["ge"]
doc_entries = [item for item in get_args(ge_annotation) if isinstance(item, Doc)]
assert len(doc_entries) == 1 and "Greater than or equal" in doc_entries[0].documentation
```

---

Next, explore **[Chapter 2: APIRouter, APIRoute & Handler Closure](../02_routing_compiler/apiroute_and_closures.md)** to trace how `_populate_api_route_state()` and `get_request_handler()` compile these descriptors into executable ASGI route closures, or jump to **[Chapter 4: _compat/v2.py, ModelField & Serialization](../04_pydantic_bridge/compat_and_serialization.md)** for the Pydantic v2 `TypeAdapter` bridge, or return to the **[Architecture Overview](../index.md)**.
