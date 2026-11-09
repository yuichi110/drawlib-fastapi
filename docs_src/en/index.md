# FastAPI v0.162.2 — Practical User Guide

FastAPI (`v0.162.2`) is a high-performance, type-driven ASGI web framework that turns standard Python `>=3.10` type annotations into boundary input validation, hierarchical dependency injection, Rust-backed Pydantic v2 serialization, and interactive OpenAPI `3.1.0` documentation. This unofficial bilingual developer guide walks systematically from your first endpoint to `100,000+` LOC production architectures.

```drawlib align=center code=hide file=fastapi_lifecycle_anim.png caption="FastAPI v0.162.2 Request Lifecycle — One-Time Route Registration Through Per-Request ASGI Execution"
from drawlib.anim import Animation
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.shapes import rectangle
from drawlib.smartarts import ChevronProcess, Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=184, height=68, dpi=150)
anim = Animation(fps=0.5)

stages = [
    ("1. Route\nRegistration", "Type Hints & Doc()"),
    ("2. Schema &\nOpenAPI Prep", "Pydantic v2 & 3.1"),
    ("3. Validation &\nDependencies", "Inputs & Depends()"),
    ("4. Endpoint\nExecution", "async / threadpool"),
    ("5. Response &\nCleanup", "JSON & yield Exit"),
]

stage_notes = [
    (
        phosphor.code,
        "Step 1/5 [Route Registration] — Declare Annotated inputs, Depends(), Doc() & BaseModel types.",
    ),
    (
        phosphor.gear,
        "Step 2/5 [Startup] — Inspect signatures once and build Pydantic v2 validators & OpenAPI 3.1.",
    ),
    (
        phosphor.git_branch,
        "Step 3/5 [Request Ingress] — Validate HTTP parameters/body and resolve Depends() graphs.",
    ),
    (
        phosphor.lightning,
        "Step 4/5 [Endpoint Execution] — Await async def on event loop or run def in a threadpool.",
    ),
    (
        phosphor.check_circle,
        "Step 5/5 [Response & Cleanup] — Validate & serialize JSON via Pydantic v2 and exit yield.",
    ),
]

for step in range(len(stages)):
    is_last = step == len(stages) - 1
    with anim.frame(duration=4.0 if is_last else 2.0, clear=True):
        outer = Panel(
            "FastAPI v0.162.2 — One-Time Startup Setup & Per-Request Execution",
            style=Styles.Neutral.patch(shape_r=2.0),
            header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
            text_style=Styles.DarkBold.patch(text_size=12.0),
            icon=phosphor.rocket_launch,
            icon_style=Styles.PrimaryBold,
            header_variant="filled",
            header_height=8.5,
        )
        outer.draw((4.0, 4.0), width=176.0, height=60.0)

        # Phase baseline bands (always visible from Frame 1)
        s_style = Styles.SecondaryNeutral if step <= 1 else Styles.Neutral
        r_style = Styles.PrimaryNeutral if step >= 2 else Styles.Neutral
        rectangle((40.5, 24.5), width=65.0, height=8.0, style=s_style.patch(shape_r=1.5))
        text(
            (40.5, 24.5),
            "Import & Startup Phase (Executed Once)",
            style=Styles.DarkBold.patch(text_size=10.5),
        )
        rectangle((126.0, 24.5), width=100.0, height=8.0, style=r_style.patch(shape_r=1.5))
        text(
            (126.0, 24.5),
            "Per-Request ASGI Execution (Zero Signature Inspection)",
            style=Styles.DarkBold.patch(text_size=10.5),
        )

        # All 5 stages stay visible; only the active spotlight advances calmly
        proc = ChevronProcess(
            style=Styles.White,
            text_style=Styles.DarkBold.patch(text_size=10.5),
            description_style=Styles.Muted.patch(text_size=10.0),
            corner_angle=62.0,
            spacing=1.8,
            flat_left_end=True,
        )
        for i, (title, desc) in enumerate(stages):
            if i == step:
                c_style = Styles.PrimaryFlat
                t_style = Styles.WhiteBold.patch(text_size=10.5)
                d_style = Styles.White.patch(text_size=10.0)
            elif i < step:
                c_style = Styles.SecondaryNeutral if i < 2 else Styles.PrimaryNeutral
                t_style = Styles.DarkBold.patch(text_size=10.5)
                d_style = Styles.Dark.patch(text_size=10.0)
            else:
                c_style = Styles.White
                t_style = Styles.DarkBold.patch(text_size=10.5)
                d_style = Styles.Muted.patch(text_size=10.0)
            proc.add(
                title,
                description=desc,
                style=c_style,
                text_style=t_style,
                description_style=d_style,
            )
        proc.draw(xy=(8.0, 32.0), width=168.0, height=19.5)

        # Active step callout bar at bottom
        rectangle((92.0, 12.5), width=168.0, height=9.5, style=Styles.White.patch(shape_r=1.5))
        note_icon, note_text = stage_notes[step]
        note_icon((14.0, 12.5), width=5.2, style=Styles.PrimaryBold)
        text(
            (20.0, 12.5),
            note_text,
            style=Styles.DarkBold.patch(text_size=10.5, halign="left"),
        )

save()
```

## FastAPI v0.162.2 at a Glance

Rather than bolting routing, input validation, dependency injection, and API documentation together as separate plugins, FastAPI unifies them around standard Python type hints so your runtime behavior and external contracts never drift apart:

| Capability Area | `v0.162.2` Standard & Tooling | Practical Benefit for Application Teams |
| :--- | :--- | :--- |
| **Supported Python Versions** | Python `>=3.10` (`3.10` – `3.14`) | Full `PEP 561` `py.typed` static type checking and `PEP 727` `Doc()` inline metadata |
| **Validation & Serialization** | Pydantic v2 (`>=2.9`, Rust `pydantic-core`) | High-throughput boundary validation, parameter models, and typed JSON serialization |
| **API Contracts & Docs UI** | OpenAPI `3.1.0` & JSON Schema `2020-12` | Automatic `/openapi.json`, interactive Swagger UI (`/docs`), ReDoc (`/redoc`), and SDK codegen |
| **Dependency Injection & Auth** | `Depends()`, `Security()`, `yield` lifecycles | Per-request result caching, deterministic resource cleanup, OAuth2 scopes, and WebSocket auth |
| **Streaming, SPA & Tracing** | `fastapi.sse`, `frontend()`, `fastapi.telemetry` | Built-in Server-Sent Events, single-page app serving, and zero-patch OpenTelemetry tracing |
| **Core Runtime Dependencies** | `6` direct packages (`pyproject.toml`) | `starlette`, `pydantic`, `typing-extensions`, `typing-inspection`, `annotated-doc`, `opentelemetry-api` |

### Single Source of Truth in 20 Lines

A single endpoint signature simultaneously defines URL extraction, regex and length constraints, inline OpenAPI parameter documentation, response validation, and static type checking:

```python
from typing import Annotated

from annotated_doc import Doc
from fastapi import FastAPI, Path, Query
from pydantic import BaseModel

app = FastAPI(title="Catalog Service", version="1.0.0")


class ProductSummary(BaseModel):
    sku: str
    price_cents: int
    currency: str


@app.get("/products/{sku}", response_model=ProductSummary)
async def read_product(
    sku: Annotated[str, Path(min_length=3, max_length=32), Doc("Warehouse SKU code.")],
    currency: Annotated[str, Query(pattern="^[A-Z]{3}$"), Doc("ISO 4217 currency.")] = "USD",
) -> ProductSummary:
    return ProductSummary(sku=sku, price_cents=4900, currency=currency)
```

## 8-Chapter · 20-Page Developer Curriculum

This guide spans **8 chapters and 20 pages**, progressing systematically from your first validated endpoint to `100,000+` LOC modular monoliths, custom `APIRoute` wrappers, `pwdlib` Argon2id + `PyJWT` + WebSocket `Security()`, native Server-Sent Events (`fastapi.sse`), built-in OpenTelemetry tracing (`fastapi.telemetry`), SPA `frontend()` mounts & SDK codegen, and `pydantic-settings` + SQL + AI/MCP operations:

```drawlib align=center code=hide file=guide_chapter_map.png caption="User Guide Curriculum Map — 8 Chapters & 20 Pages from Quickstart to Production Ecosystem"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Styles

setup(width=196, height=88, dpi=150)

left_panel = Panel(
    "Part I — Foundations, Scale & Security (Ch 1–4)",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.compass,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
left_panel.draw((4.0, 4.0), width=91.0, height=80.0)
l_xy, l_w, l_h = left_panel.get_content_box((4.0, 4.0), width=91.0, height=80.0, padding=(3.5, 3.0))

cl_left = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.8),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    direction="vertical",
    spacing=2.4,
)
cl_left.add(
    "Ch 1 · Introduction & Quickstart",
    "Design pillars, request flow & OpenAPI 3.1",
    badge_text="Ch 1",
    icon=phosphor.rocket_launch,
    style=Styles.PrimaryNeutral,
    badge_style=Styles.PrimaryFlat,
    badge_text_style=Styles.WhiteBold.patch(text_size=10.0),
    icon_style=Styles.WhiteBold,
)
cl_left.add(
    "Ch 2 · 100k+ LOC Enterprise Design",
    "Bounded contexts, DI ports & lifespan tests",
    badge_text="Ch 2",
    icon=phosphor.tree_structure,
)
cl_left.add(
    "Ch 3 · Routing, Validation & Models",
    "Param models, extra types & custom APIRoute",
    badge_text="Ch 3",
    icon=phosphor.brackets_curly,
)
cl_left.add(
    "Ch 4 · DI, OAuth2, JWT & WS Security",
    "Depends() graph, Argon2 + PyJWT & WS Security()",
    badge_text="Ch 4",
    icon=phosphor.shield_check,
)
cl_left.draw(xy=l_xy, width=l_w, height=l_h)

right_panel = Panel(
    "Part II — Streaming, OTel, Frontend & Ops (Ch 5–8)",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.stack,
    icon_style=Styles.SecondaryBold,
    header_variant="filled",
    header_height=8.5,
)
right_panel.draw((101.0, 4.0), width=91.0, height=80.0)
r_xy, r_w, r_h = right_panel.get_content_box((101.0, 4.0), width=91.0, height=80.0, padding=(3.5, 3.0))

cl_right = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.8),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.SecondaryBold,
    direction="vertical",
    spacing=2.4,
)
cl_right.add(
    "Ch 5 · Async, SSE & WebSockets",
    "Pure ASGI middleware, SSE, JSONL & sockets",
    badge_text="Ch 5",
    icon=phosphor.broadcast,
)
cl_right.add(
    "Ch 6 · OpenTelemetry & Testing",
    "Native OTel spans, RFC errors & TestClient",
    badge_text="Ch 6",
    icon=phosphor.pulse,
)
cl_right.add(
    "Ch 7 · Frontend, Sub-Apps & OpenAPI",
    "SPA frontend(), mounts, webhooks & SDKs",
    badge_text="Ch 7",
    icon=phosphor.layout,
)
cl_right.add(
    "Ch 8 · Settings, Databases & Ecosystem",
    "pydantic-settings, SQL DBs, CLI & AI/MCP",
    badge_text="Ch 8",
    icon=phosphor.database,
    style=Styles.SecondaryNeutral,
    badge_style=Styles.PrimaryFlat,
    badge_text_style=Styles.WhiteBold.patch(text_size=10.0),
    icon_style=Styles.WhiteBold,
)
cl_right.draw(xy=r_xy, width=r_w, height=r_h)

save()
```

| Chapter | Pages & Core Topics | Key FastAPI APIs Covered |
| :--- | :--- | :--- |
| **1. Introduction & Quickstart** | [Why FastAPI & Design Philosophy](01_getting_started/overview.md) · [Quickstart & Interactive OpenAPI](01_getting_started/quickstart.md) | `FastAPI`, `Annotated`, `Doc()`, `APIRoute`, Swagger UI & ReDoc |
| **2. Scaling to 100k+ LOC** | [Bounded Contexts & Layering](02_enterprise_architecture/modular_design.md) · [Enterprise DI, Lifespan & Testing](02_enterprise_architecture/di_lifespan_testing.md) | `APIRouter`, `lifespan`, `dependency_overrides`, domain boundaries |
| **3. Routing, Validation & Models** | [Path, Query, Header, Cookie & Body](03_routing_and_models/parameters_and_validation.md) · [Response Serialization & OpenAPI 3.1](03_routing_and_models/responses_and_openapi.md) · [Parameter Models, Extra Types & Examples](03_routing_and_models/advanced_types_and_models.md) · [Custom Request & APIRoute Classes](03_routing_and_models/custom_request_and_route.md) | `Path`, `Query`, `Header`, `Cookie`, `Body`, `BaseModel`, custom `APIRoute` |
| **4. Dependency Injection & Security** | [Dependency Graph, Caching & Scopes](04_dependencies_and_security/dependency_injection.md) · [Authentication & OAuth2 Scopes](04_dependencies_and_security/security_and_auth.md) · [JWT (PyJWT + Argon2) & WS Security](04_dependencies_and_security/jwt_and_websocket_security.md) | `Depends`, `Security`, `SecurityScopes`, `pwdlib` Argon2id, `PyJWT`, `HTTPConnection` |
| **5. Async, Middleware & Streaming** | [ASGI Middleware & Threadpool](05_async_and_realtime/concurrency_and_middleware.md) · [Native SSE, JSONL & WebSockets](05_async_and_realtime/sse_websockets_streaming.md) | `run_in_threadpool`, `EventSourceResponse`, `ServerSentEvent`, `WebSocket` |
| **6. Observability, Errors & Testing** | [Native OpenTelemetry & Exceptions](06_observability_and_testing/telemetry_and_errors.md) · [Testing Patterns & Production ASGI](06_observability_and_testing/testing_and_deployment.md) | `TelemetryConfig`, `get_telemetry_data()`, `HTTPException`, `RequestValidationError`, `TestClient` |
| **7. Frontend, Sub-Apps & OpenAPI** | [SPA frontend(), StaticFiles & Mounts](07_frontend_and_openapi_ext/frontend_templates_mounts.md) · [Webhooks, Callbacks, SDKs & Docs UI](07_frontend_and_openapi_ext/webhooks_callbacks_sdks.md) | `frontend()`, `StaticFiles`, `Jinja2Templates`, `app.webhooks`, `callbacks` |
| **8. Settings, Databases & Ecosystem** | [pydantic-settings & SQL Databases](08_ecosystem_and_operations/settings_and_databases.md) · [FastAPI CLI, Proxies, GraphQL & AI](08_ecosystem_and_operations/cli_proxy_graphql_ai.md) | `BaseSettings`, `@lru_cache`, SQL `yield` sessions, `fastapi-cli`, `--proxy-headers` |

## Official Resources & Companion Guides

- **Upstream Attribution & Official Documentation**: FastAPI was created and is maintained by **Sebastián Ramírez (`@tiangolo`)** and the FastAPI community under the MIT License. For authoritative documentation, release notes, and community resources, consult **[https://fastapi.tiangolo.com/](https://fastapi.tiangolo.com/)** and **[github.com/fastapi/fastapi](https://github.com/fastapi/fastapi)**.
- **Where to Start**: Begin with **[Chapter 1: Why FastAPI & Design Philosophy](01_getting_started/overview.md)** to build a clear mental model of FastAPI's request lifecycle, or jump straight into hands-on code in **[Quickstart & Interactive OpenAPI](01_getting_started/quickstart.md)**.

> **Studying FastAPI's Own Source Code?** If you want to explore how FastAPI itself is implemented under the hood—including its internal module layering, route compiler internals, and Pydantic v2 adapter mechanics—visit the companion **[FastAPI Internal Architecture Guide](https://fastapi.drawlib.com/architecture/)**.
