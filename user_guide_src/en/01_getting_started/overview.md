# Why FastAPI & Design Philosophy

FastAPI (`v0.162.2`) is built around a simple yet powerful premise: **standard Python type annotations serve as the single executable contract** for HTTP parameter extraction, runtime data validation, dependency injection, editor autocompletion, static type checking, and OpenAPI schema generation.

```drawlib align=center code=hide file=fastapi_design_pillars.png caption="FastAPI v0.162.2 Design Pillars — Turning Python Type Hints into ASGI Routing, Pydantic v2 Validation, OpenAPI 3.1, and OpenTelemetry"
from drawlib.canvas import save, setup
from drawlib.diagrams.architecture import (
    ArchitectureDiagram,
    CnativeIcon,
    CodeIcon,
    Node,
    PhosphorIcon,
)
from drawlib.icons import phosphor
from drawlib.lines import line, lines
from drawlib.shapes import rectangle
from drawlib.smartarts import Panel
from drawlib.styles import Styles

setup(width=188, height=88, dpi=150)

outer = Panel(
    "FastAPI v0.162.2 — Type-Driven Architecture Pillars",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=12.0),
    icon=phosphor.compass,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
outer.draw((4.0, 4.0), width=180.0, height=80.0)

# Subtle dashed bands for Top Developer Surface and Bottom Runtime Pillars
rectangle((94.0, 64.0), width=168.0, height=18.5, style=Styles.SecondaryDashed.patch(shape_r=2.0))
rectangle((94.0, 15.0), width=168.0, height=18.5, style=Styles.MutedDashed.patch(shape_r=2.0))

diag = ArchitectureDiagram(
    node_style=Styles.PrimaryBold,
    node_text_style=Styles.DarkBold.patch(text_size=10.5),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.White,
)

# Top Row: Python Typing Standards (centers at y=64.0, bottom edge at y=56.75)
diag.add(
    Node(
        "Python Type Hints\nAnnotated[T, ...]",
        width=48,
        height=14.5,
        icon=CodeIcon.PYTHON,
        icon_size=5.6,
    ),
    (38, 64.0),
)
diag.add(
    Node(
        "Pydantic BaseModel\n& Depends() Callables",
        width=48,
        height=14.5,
        icon=PhosphorIcon.CODE,
        icon_size=5.6,
    ),
    (94, 64.0),
)
diag.add(
    Node(
        "Inline API Docs\nPEP 727 Doc()",
        width=48,
        height=14.5,
        icon=PhosphorIcon.FILE_DOC,
        icon_size=5.6,
    ),
    (150, 64.0),
)

# Center Engine Hub (y=39.5, top=47.0, bottom=32.0)
diag.add(
    Node(
        "FastAPI v0.162.2 Type-Driven Engine\nRouting  ·  Validation  ·  Dependency Graph",
        width=78,
        height=15.0,
        icon=CodeIcon.FASTAPI,
        icon_size=6.2,
        card_style=Styles.PrimaryFlat,
        text_style=Styles.WhiteBold.patch(text_size=11.0),
        style=Styles.WhiteBold,
    ),
    (94, 39.5),
)

# Bottom Row: Four Core Runtime Capabilities (y=15.0, top=22.25)
diag.add(
    Node(
        "Starlette ASGI\nRouting & Lifecycle",
        width=37,
        height=14.5,
        icon=PhosphorIcon.LIGHTNING,
        icon_size=5.6,
        card_style=Styles.PrimaryNeutral,
    ),
    (31, 15.0),
)
diag.add(
    Node(
        "Pydantic v2\nSchema & Validator",
        width=39,
        height=14.5,
        icon=CodeIcon.PYDANTIC,
        icon_size=5.6,
        card_style=Styles.PrimaryNeutral,
    ),
    (73, 15.0),
)
diag.add(
    Node(
        "OpenAPI 3.1.0\nSwagger UI & ReDoc",
        width=39,
        height=14.5,
        icon=CodeIcon.OPENAPI,
        icon_size=5.6,
        card_style=Styles.PrimaryNeutral,
    ),
    (116, 15.0),
)
diag.add(
    Node(
        "OpenTelemetry\nBuilt-in Tracing",
        width=35,
        height=14.5,
        icon=CnativeIcon.OPENTELEMETRY,
        icon_size=5.6,
        card_style=Styles.SecondaryNeutral,
    ),
    (157, 15.0),
)

diag.draw()

# Symmetrical top-to-bottom bus connectors
lines([(38.0, 56.75), (38.0, 52.5), (150.0, 52.5), (150.0, 56.75)], style=Styles.DarkBold)
line((94.0, 56.75), (94.0, 47.2), arrow_head="->", style=Styles.DarkBold)

line((94.0, 32.0), (94.0, 28.5), style=Styles.DarkBold)
line((31.0, 28.5), (157.0, 28.5), style=Styles.DarkBold)
for bx in (31.0, 73.0, 116.0, 157.0):
    line((bx, 28.5), (bx, 22.4), arrow_head="->", style=Styles.DarkBold)

save()
```

## Eliminating Duplicate Validation & Contract Code

In traditional imperative web frameworks, adding or renaming one API field forces engineers to update four separate artifacts: manual `request.args.get(...)` parsing code, a separate validation schema, a response serializer, and a hand-maintained OpenAPI YAML file. Whenever one artifact lags behind, production clients suffer silent contract drift.

| Concern | Imperative Frameworks (4 Artifacts) | FastAPI `v0.162.2` (Single Signature) |
| :--- | :--- | :--- |
| **HTTP Parameter Extraction** | Manual `request.query_params` / `request.json()` lookups | Inferred automatically from path templates, scalars, and `BaseModel` |
| **Boundary Input Validation** | Separate validator classes or ad-hoc `if` checks | Enforced at the boundary via `Path(...)`, `Query(...)`, and Rust `pydantic-core` |
| **Static Type Safety (`mypy` / `pyright`)** | Unchecked `Any` dicts passed into business logic | `PEP 561` `py.typed` preserves exact narrowed types inside the endpoint |
| **OpenAPI & Client SDK Specs** | Hand-edited YAML prone to drift from runtime code | Generated deterministically as OpenAPI `3.1.0` + `PEP 727` `Doc()` descriptions |

## One-Time Startup Setup vs Per-Request Execution

A common misconception is that type-driven frameworks call `inspect.signature()` on every incoming HTTP request. FastAPI avoids per-request Python reflection by splitting execution into **one-time route registration** at startup and a **streamlined per-request execution pipeline** for live traffic:

```drawlib align=center code=hide file=startup_vs_hotpath_split.png caption="One-Time Import/Startup Setup vs Per-Request Execution — Zero Runtime Signature Reflection"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.lines import line
from drawlib.shapes import rectangle
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=200, height=80, dpi=150)

# Left Panel: Startup Setup
p_start = Panel(
    "Phase 1: Import & Startup (Executed Once)",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.5),
    icon=phosphor.gear,
    icon_style=Styles.SecondaryBold,
    header_variant="filled",
    header_height=8.5,
)
p_start.draw((4.0, 4.0), width=86.5, height=72.0)
s_xy, s_w, s_h = p_start.get_content_box((4.0, 4.0), width=86.5, height=72.0, padding=(3.5, 3.0))

cl_start = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.SecondaryBold,
    direction="vertical",
    spacing=4.2,
    show_arrows=True,
    arrow_style=Styles.Dark,
)
cl_start.add(
    "1. Route Registration",
    "Registers @app.get/post & APIRouter paths",
    badge_text="S1",
    icon=phosphor.code,
)
cl_start.add(
    "2. Signature & Type Inspection",
    "Classifies Path, Query, Header, Body & Depends",
    badge_text="S2",
    icon=phosphor.arrows_split,
)
cl_start.add(
    "3. Pydantic v2 Schema & Validator",
    "Compiles Rust validators & serializers once",
    badge_text="S3",
    icon=phosphor.cpu,
)
cl_start.add(
    "4. OpenAPI 3.1 Generation",
    "Prepares JSON Schema, Swagger UI & ReDoc",
    badge_text="S4",
    icon=phosphor.check_circle,
    style=Styles.SecondaryNeutral,
)
cl_start.draw(xy=s_xy, width=s_w, height=s_h)

# Handoff connector between Startup and Per-Request Execution
line((92.0, 36.5), (108.0, 36.5), arrow_head="->", style=Styles.PrimaryBold)
rectangle((100.0, 46.0), width=15.6, height=9.5, style=Styles.PrimaryNeutral.patch(shape_r=1.5))
text((100.0, 46.0), "Ready\nAPIRoute", style=Styles.PrimaryBold.patch(text_size=10.0))

# Right Panel: Per-Request Execution
p_hot = Panel(
    "Phase 2: Per-Request Execution (Live Traffic)",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.5),
    icon=phosphor.lightning,
    icon_style=Styles.WhiteBold,
    header_variant="filled",
    header_height=8.5,
)
p_hot.draw((109.5, 4.0), width=86.5, height=72.0)
h_xy, h_w, h_h = p_hot.get_content_box((109.5, 4.0), width=86.5, height=72.0, padding=(3.5, 3.0))

cl_hot = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    direction="vertical",
    spacing=4.2,
    show_arrows=True,
    arrow_style=Styles.Primary,
)
cl_hot.add(
    "1. Route Match & Input Validation",
    "Validates URL params, headers & JSON body",
    badge_text="R1",
    icon=phosphor.plugs,
)
cl_hot.add(
    "2. Dependency Graph Resolution",
    "Resolves Depends() & Security() with caching",
    badge_text="R2",
    icon=phosphor.git_branch,
    style=Styles.PrimaryNeutral,
)
cl_hot.add(
    "3. Endpoint Execution",
    "Awaits async def or runs def in threadpool",
    badge_text="R3",
    icon=phosphor.lightning,
    style=Styles.PrimaryNeutral,
)
cl_hot.add(
    "4. Response Validation & JSON",
    "Serializes output & runs yield cleanup",
    badge_text="R4",
    icon=phosphor.rocket_launch,
)
cl_hot.draw(xy=h_xy, width=h_w, height=h_h)

save()
```

Because route signatures and `Depends()` callables are analyzed at registration time, you can inspect the synthesized OpenAPI `3.1.0` contract via `app.openapi()` before serving a single HTTP request:

```python
from typing import Annotated

from annotated_doc import Doc
from fastapi import Depends, FastAPI, Path, Query
from pydantic import BaseModel, ConfigDict, Field

app = FastAPI(title="Order Service", version="1.0.0")


class OrderPayload(BaseModel):
    model_config = ConfigDict(extra="forbid")
    sku: str = Field(min_length=3)
    quantity: int = Field(ge=1, le=100)


def get_region(x_region: str = "us-east") -> str:
    return x_region


@app.post("/orders/{order_id}")
async def create_order(
    order_id: Annotated[int, Path(ge=1), Doc("Numeric order identifier.")],
    payload: OrderPayload,
    region: Annotated[str, Depends(get_region)],
    dry_run: Annotated[bool, Query(), Doc("Validate without persisting.")] = False,
) -> dict[str, object]:
    return {"order_id": order_id, "sku": payload.sku, "region": region, "dry_run": dry_run}


schema = app.openapi()
operation = schema["paths"]["/orders/{order_id}"]["post"]
assert [p["name"] for p in operation["parameters"]] == ["order_id", "dry_run", "x_region"]
assert "OrderPayload" in schema["components"]["schemas"]
```

## Core Runtime Dependencies & Public Building Blocks

### Core Runtime Dependency Stack

FastAPI keeps its mandatory installation footprint intentionally minimal—declaring only **six** direct runtime dependencies in `pyproject.toml`:

| Package (`pyproject.toml`) | Minimum Version | Role in FastAPI `v0.162.2` Applications |
| :--- | :--- | :--- |
| **`starlette`** | `>=0.46.0` | High-speed ASGI `3.0` server interface, URL router, `Request`/`Response` primitives, WebSockets, and middleware |
| **`pydantic`** | `>=2.9.0` | Rust-powered `pydantic-core` validation, type coercion, response serialization, and JSON Schema `2020-12` generation |
| **`typing-extensions`** | `>=4.8.0` | Cross-version compatibility for modern typing constructs across Python `3.10` through `3.14` |
| **`typing-inspection`** | `>=0.4.2` | Startup unwrapping of `Annotated[...]`, type aliases, generics, and union type hints |
| **`annotated-doc`** | `>=0.0.2` | `PEP 727` `Doc("...")` support for attaching OpenAPI parameter and endpoint docs inside `Annotated` |
| **`opentelemetry-api`** | `>=1.44.0` | Zero-SDK-overhead tracing hooks powering built-in OpenTelemetry instrumentation (`fastapi.telemetry`) |

### Core Developer Building Blocks

When building services with FastAPI, almost every feature you use comes from five cohesive public API areas:

| Capability Area | Primary Public Symbols | Typical Import Paths |
| :--- | :--- | :--- |
| **App & Modular Routing** | `FastAPI`, `APIRouter`, `APIRoute`, `Request`, `Response`, `lifespan` | `fastapi`, `fastapi.routing` |
| **Parameters, Models & Docs** | `Annotated`, `Path`, `Query`, `Header`, `Cookie`, `Body`, `Form`, `UploadFile`, `BaseModel`, `Doc()` | `fastapi`, `pydantic`, `annotated_doc` |
| **Dependency Injection & Auth** | `Depends`, `Security`, `SecurityScopes`, `OAuth2PasswordBearer`, `APIKeyHeader`, `HTTPBearer` | `fastapi`, `fastapi.security` |
| **Async, Streaming & Realtime** | `BackgroundTasks`, `EventSourceResponse`, `ServerSentEvent`, `WebSocket`, `WebSocketDisconnect` | `fastapi`, `fastapi.sse` |
| **Observability, Errors & Tests** | `HTTPException`, `RequestValidationError`, `TelemetryConfig`, `get_telemetry_data()`, `TestClient` | `fastapi`, `fastapi.exceptions`, `fastapi.telemetry`, `fastapi.testclient` |

Next, put these building blocks into action in **[Quickstart & Interactive OpenAPI](quickstart.md)**, or explore how to structure large engineering codebases in **[Chapter 2: Bounded Contexts & Layering](../02_enterprise_architecture/modular_design.md)**.
