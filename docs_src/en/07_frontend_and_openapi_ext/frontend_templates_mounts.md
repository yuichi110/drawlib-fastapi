# SPA frontend(), StaticFiles, Templates & Sub-Apps

FastAPI `v0.162.2` unifies modern Single-Page Application (SPA) delivery, server-rendered HTML templates, isolated ASGI sub-applications, and incremental WSGI migrations on a single process—anchored by the native `app.frontend()` and `router.frontend()` low-priority static routing engine.

```drawlib align=center code=hide file=spa_frontend_routing_priority.png caption="FastAPI v0.162.2 app.frontend() & router.frontend() Dispatch Flow — Global API Route Priority & Browser HTML Fallback"
from drawlib.canvas import save, setup
from drawlib.icons import code, phosphor
from drawlib.lines import line, lines
from drawlib.shapes import rectangle
from drawlib.smartarts import ChevronProcess, Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=188, height=98, dpi=150)

outer = Panel(
    "FastAPI v0.162.2 — app.frontend() & router.frontend() Low-Priority Dispatch",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=12.0),
    icon=phosphor.compass,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
outer.draw((4.0, 4.0), width=180.0, height=90.0)

# Top 4-Stage SPA Dispatch Evaluation Order
stages = ChevronProcess(
    style=Styles.Neutral,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    corner_angle=60.0,
    spacing=1.6,
    flat_left_end=True,
)
stages.add("1. Normal Routes", description="API Routes, WS & Mount", style=Styles.SecondaryNeutral)
stages.add("2. Router DI Gate", description="Depends() & Longest Path", style=Styles.PrimaryNeutral)
stages.add("3. Static Lookup", description="dist/ File & Dir Index", style=Styles.Neutral)
stages.add(
    "4. Fallback Gate",
    description="404.html / Accept HTML",
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
)
stages.draw(xy=(8.0, 70.0), width=172.0, height=12.5)

# Left Ingress Card (cx=23, cy=36.5, w=30, h=53 -> x=8..38, y=10..63)
rectangle((23.0, 36.5), width=30.0, height=53.0, style=Styles.PrimaryNeutral.patch(shape_r=2.0))
code.fastapi((23.0, 55.5), width=5.6, style=Styles.Primary)
text((23.0, 47.5), "ASGI Request", style=Styles.DarkBold.patch(text_size=11.0))
text(
    (10.2, 27.5),
    "• GET /api/items\n• GET /assets/app.js\n• GET /dashboard\n   Accept: text/html\n• GET /missing.js\n   Accept: */*",
    style=Styles.Dark.patch(text_size=10.0, halign="left"),
)

# 4 Outcome Tracks (y = 56.5, 43.2, 29.9, 16.6)
tracks = [
    (
        56.5,
        ("1. API or Mount Match?", "@app.get / WS / Mount", Styles.SecondaryNeutral, False),
        ("Execute API Route", "Never shadowed by '/'", Styles.White, False),
        ("200 / API JSON 404", "API 404s stay JSON", Styles.SecondaryNeutral, False),
        False,
    ),
    (
        43.2,
        ("2. File in dist/?", "Static Asset Lookup", Styles.Neutral, False),
        ("Direct FileResponse", "Threadpool stat + ETag", Styles.White, False),
        ("200 OK Static Asset", "dist/assets/app.js", Styles.PrimaryNeutral, False),
        False,
    ),
    (
        29.9,
        ("3. Accept: text/html?", "HTML Navigation Check", Styles.PrimaryNeutral, False),
        ("SPA Shell Fallback", "Serves dist/index.html", Styles.PrimaryFlat, True),
        ("200 OK Client Router", "React / Vue / Svelte", Styles.PrimaryNeutral, False),
        True,
    ),
    (
        16.6,
        ("4. Non-HTML / Missing", "Accept: */* or q=0", Styles.Neutral, False),
        ("Skip index.html", "Or serve dist/404.html", Styles.White, False),
        ("404 Not Found", "Prevents '<' JS syntax bug", Styles.Neutral, False),
        False,
    ),
]

# Orthogonal trunk x=38 -> x=44 -> 4 tracks entering x=50 (6.0u arrow gap)
line((38.0, 36.5), (44.0, 36.5), style=Styles.DarkBold)
lines([(44.0, 16.6), (44.0, 56.5)], style=Styles.DarkBold)

for ty, c1, c2, c3, is_focal in tracks:
    arr_style = Styles.PrimaryBold if is_focal else Styles.DarkBold
    line((44.0, ty), (50.0, ty), arrow_head="->", style=arr_style)

    # Column 1: cx=68.5, w=37 -> x=50..87
    rectangle((68.5, ty), width=37.0, height=11.0, style=c1[2].patch(shape_r=1.6))
    text((68.5, ty + 2.2), c1[0], style=Styles.DarkBold.patch(text_size=10.2))
    text((68.5, ty - 2.4), c1[1], style=Styles.Dark.patch(text_size=10.0))

    # Gap 87 -> 94 (7.0u)
    line((87.0, ty), (94.0, ty), arrow_head="->", style=arr_style)

    # Column 2: cx=113.5, w=39 -> x=94..133
    rectangle((113.5, ty), width=39.0, height=11.0, style=c2[2].patch(shape_r=1.6))
    h_st = Styles.WhiteBold if c2[3] else Styles.DarkBold
    b_st = Styles.White if c2[3] else Styles.Dark
    text((113.5, ty + 2.2), c2[0], style=h_st.patch(text_size=10.2))
    text((113.5, ty - 2.4), c2[1], style=b_st.patch(text_size=10.0))

    # Gap 133 -> 140 (7.0u)
    line((133.0, ty), (140.0, ty), arrow_head="->", style=arr_style)

    # Column 3: cx=160.0, w=40 -> x=140..180
    rectangle((160.0, ty), width=40.0, height=11.0, style=c3[2].patch(shape_r=1.6))
    text((160.0, ty + 2.2), c3[0], style=Styles.DarkBold.patch(text_size=10.2))
    text((160.0, ty - 2.4), c3[1], style=Styles.Dark.patch(text_size=10.0))

save()
```

## 1. Native SPA Serving with `app.frontend()` & `router.frontend()`

Historically, serving a React, Vue, or Svelte build at `"/"` via `app.mount("/", StaticFiles(directory="dist", html=True))` forced awkward registration ordering—mounting `"/"` too early shadowed `@app.get("/api/...")`, and `StaticFiles(html=True)` returned `404` whenever a user refreshed a client-side route like `/dashboard/analytics`.

FastAPI `v0.162.2` solves both problems natively with `app.frontend()` (and `app.router.frontend()` / `router.frontend()`). Instead of appending a greedy ASGI `Mount` at `"/"`, FastAPI registers a dedicated **low-priority SPA frontend router** that evaluates **only after** all API routes, WebSocket endpoints, mounts, and trailing-slash redirects across the entire router tree fail to match.

| Parameter & Option | Default | Runtime Behavior in `app.frontend()` / `router.frontend()` |
| :--- | :--- | :--- |
| **`fallback="auto"`** | Yes | Serves `404.html` (`404`) if present in `directory`; else serves `index.html` (`200`) on HTML navigation requests; else raises `404` |
| **`fallback="index.html"`** | No | Serves `index.html` (`200`) on HTML navigation even if `404.html` also exists; validates `index.html` at startup when `check_dir` is enabled |
| **`fallback="404.html"`** | No | Serves `404.html` with HTTP status `404` for any missing path under the frontend prefix; validates `404.html` at startup |
| **`fallback=None`** | No | Disables fallback completely; only exact files and subdirectory `index.html` files resolve, returning JSON `404` otherwise |
| **`check_dir="auto"`** | Yes | Skips startup directory check with a `UserWarning` when `FASTAPI_ENV="development"` (set by `fastapi dev`), and enforces `RuntimeError` in production |

### Global Route Precedence, Segment Specificity & Router Dependencies

The built-in SPA frontend router enforces four production safeguards that hand-rolled catch-all `@app.get("/{full_path:path}")` handlers routinely get wrong:

1. **Global API Precedence & Preserved API `404`s**: Standard API routes (`@app.get`, `@app.post`, etc.) and `WebSocket` handlers always win regardless of `include_router()` registration order. If `@app.get("/api/items/{item_id}")` matches the path and raises `HTTPException(404)`, FastAPI returns that JSON `404`—it never masks backend errors with `dist/index.html`.
2. **Browser HTML Navigation Check (`Accept` Header Negotiation)**: When falling back to `index.html`, FastAPI parses the `Accept` header's media types and quality weights (`q`). Only `GET`/`HEAD` requests explicitly accepting `text/html` or `application/xhtml+xml` (`q != 0`) receive `index.html` (`200 OK`). Missing scripts (`GET /assets/missing.js` with `Accept: */*`) or mistyped API fetches (`Accept: application/json`) receive a clean `404`, preventing browsers from choking on `Uncaught SyntaxError: Unexpected token '<'`.
3. **Longest Segment-Boundary Prefix**: Registering both `app.frontend("/", directory="site")` and `router.frontend("/admin", directory="admin_dist")` matches on strict path segments (`/admin` never intercepts `/administration`) and selects the highest-specificity prefix.
4. **Full Dependency Injection on Protected Frontends**: `router.frontend()` executes app-level, `include_router()`-level, and `APIRouter(dependencies=[Depends(...)])` dependencies in outer-to-inner order—supporting cookie session gates, custom `Response` headers, `BackgroundTasks`, and `app.dependency_overrides` in tests.

```python
from pathlib import Path
from fastapi import APIRouter, Depends, FastAPI, HTTPException, Request
from fastapi.testclient import TestClient


def build_spa_service(dist_dir: Path, admin_dist: Path) -> FastAPI:
    app = FastAPI(title="Unified API + SPA Service")

    @app.get("/api/items/{item_id}")
    async def read_item(item_id: int) -> dict[str, object]:
        if item_id == 0:
            raise HTTPException(status_code=404, detail="Item not found")
        return {"item_id": item_id, "source": "api"}

    def require_admin_cookie(request: Request) -> None:
        if request.cookies.get("__Host-admin_session") != "verified-session":
            raise HTTPException(status_code=401, detail="Admin session required")

    admin_router = APIRouter(dependencies=[Depends(require_admin_cookie)])
    admin_router.frontend("/admin", directory=admin_dist, fallback="index.html")
    app.include_router(admin_router)

    # Low-priority SPA mount at "/" never shadows /api/* or /admin/*
    app.frontend("/", directory=dist_dir, fallback="auto")
    return app
```

## 2. Choosing Between SPA `frontend()`, Templates, Mounts & WSGI

A single FastAPI ASGI host can combine multiple UI delivery and service-composition strategies side by side, depending on whether rendering happens in the browser, in Jinja2 on the server, in an isolated sub-team FastAPI app, or inside a legacy synchronous WSGI codebase:

```drawlib align=center code=hide file=mounts_templates_wsgi_topology.png caption="Unified ASGI Host Topology — Comparing app.frontend(), Jinja2Templates + StaticFiles, Sub-Apps & a2wsgi"
from drawlib.canvas import save, setup
from drawlib.diagrams.architecture import (
    ArchitectureDiagram,
    CodeIcon,
    Node,
    NodeGroup,
    PhosphorIcon,
)
from drawlib.icons import phosphor
from drawlib.lines import line, lines
from drawlib.smartarts import Panel
from drawlib.styles import Styles

setup(width=188, height=98, dpi=150)

outer = Panel(
    "Unified ASGI Host Process  (Uvicorn / Hypercorn  ·  app = FastAPI())",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=12.0),
    icon=phosphor.plugs,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
outer.draw((4.0, 4.0), width=180.0, height=90.0)

diag = ArchitectureDiagram(
    node_style=Styles.PrimaryBold,
    node_text_style=Styles.DarkBold.patch(text_size=10.3),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.White.patch(shape_r=1.5),
)

# Top Focal Dispatcher Node (center at y=75.0 -> bottom=68.0)
diag.add(
    Node(
        "Root FastAPI Router & Middleware Stack\nAPI Routes  ->  app.mount()  ->  SPA frontend()",
        width=86.0,
        height=14.0,
        icon=CodeIcon.FASTAPI,
        icon_size=6.0,
        card_style=Styles.PrimaryFlat.patch(shape_r=1.8),
        text_style=Styles.WhiteBold.patch(text_size=10.8),
        style=Styles.WhiteBold,
    ),
    (94.0, 75.0),
)

# 4 Strategy Columns: x = 8, 52, 96, 140 (width=40, height=48, y=8..56, centers cx=28, 72, 116, 160)
g_spa = diag.add(
    NodeGroup(
        title="1. SPA frontend()",
        width=40.0,
        height=48.0,
        style=Styles.PrimaryNeutral.patch(shape_r=1.8),
        text_style=Styles.DarkBold.patch(halign="left", text_size=10.8),
    ),
    (8.0, 8.0),
)
g_spa.add(
    Node("dist/ Static Build\n& index.html Shell", width=34.0, height=14.0, icon=PhosphorIcon.GLOBE, icon_size=5.2),
    (20.0, 32.0),
)
g_spa.add(
    Node("Accept: text/html\n+ Router Depends()", width=34.0, height=14.0, icon=PhosphorIcon.SHIELD_CHECK, icon_size=5.2),
    (20.0, 13.0),
)

g_ssr = diag.add(
    NodeGroup(
        title="2. SSR + Static",
        width=40.0,
        height=48.0,
        style=Styles.Neutral.patch(shape_r=1.8),
        text_style=Styles.DarkBold.patch(halign="left", text_size=10.8),
    ),
    (52.0, 8.0),
)
g_ssr.add(
    Node("Jinja2Templates\nTemplateResponse", width=34.0, height=14.0, icon=PhosphorIcon.CODE, icon_size=5.2),
    (20.0, 32.0),
)
g_ssr.add(
    Node("/static Mount\nurl_for('static')", width=34.0, height=14.0, icon=PhosphorIcon.FILE_DOC, icon_size=5.2, card_style=Styles.SecondaryNeutral),
    (20.0, 13.0),
)

g_sub = diag.add(
    NodeGroup(
        title="3. Sub-App Mount",
        width=40.0,
        height=48.0,
        style=Styles.SecondaryNeutral.patch(shape_r=1.8),
        text_style=Styles.DarkBold.patch(halign="left", text_size=10.8),
    ),
    (96.0, 8.0),
)
g_sub.add(
    Node("subapi = FastAPI()\nroot_path='/subapi'", width=34.0, height=14.0, icon=CodeIcon.FASTAPI, icon_size=5.2),
    (20.0, 32.0),
)
g_sub.add(
    Node("Isolated OpenAPI\n/subapi/docs", width=34.0, height=14.0, icon=CodeIcon.OPENAPI, icon_size=5.2, card_style=Styles.PrimaryNeutral),
    (20.0, 13.0),
)

g_wsgi = diag.add(
    NodeGroup(
        title="4. Legacy WSGI",
        width=40.0,
        height=48.0,
        style=Styles.Neutral.patch(shape_r=1.8),
        text_style=Styles.DarkBold.patch(halign="left", text_size=10.8),
    ),
    (140.0, 8.0),
)
g_wsgi.add(
    Node("a2wsgi Bridge\nWSGIMiddleware", width=34.0, height=14.0, icon=PhosphorIcon.LIGHTNING, icon_size=5.2),
    (20.0, 32.0),
)
g_wsgi.add(
    Node("Flask / Django\nWorker Threadpool", width=34.0, height=14.0, icon=CodeIcon.PYTHON, icon_size=5.2, card_style=Styles.SecondaryNeutral),
    (20.0, 13.0),
)

diag.draw()

# Orthogonal fan-out bus from Root Node bottom (y=68.0) -> bus (y=62.5) -> group tops (y=56.0, 6.3u terminal gap)
line((94.0, 68.0), (94.0, 62.5), style=Styles.DarkBold)
lines([(28.0, 62.5), (160.0, 62.5)], style=Styles.DarkBold)
for cx in (28.0, 72.0, 116.0, 160.0):
    line((cx, 62.5), (cx, 56.2), arrow_head="->", style=Styles.PrimaryBold if cx == 28.0 else Styles.DarkBold)

save()
```

| Integration Mechanism | Registration API | Priority & Scope Isolation | Best Fit |
| :--- | :--- | :--- | :--- |
| **SPA Static Build** | `app.frontend("/", directory="dist")` | Lowest priority (evaluated after all API routes); supports `Depends()` | Vite, React, Vue, Svelte, Astro, or static docs co-hosted with `/api` |
| **Named Asset Mount** | `app.mount("/static", StaticFiles(...), name="static")` | Prefix `Mount` at `/static`; enables `url_for("static", ...)` | Versioned CSS/JS/images referenced by Jinja2 or self-hosted Swagger UI |
| **Server-Side Templates** | `Jinja2Templates(directory="templates")` | Standard HTTP route (`response_class=HTMLResponse`) | HTMX fragments, transactional emails, SEO landing pages |
| **Isolated Sub-App** | `app.mount("/subapi", subapi)` | Independent `FastAPI` instance (`root_path="/subapi"`, own `/docs`) | Multi-version public APIs (`/v2`), partner portals, admin micro-apps |
| **Legacy WSGI Mount** | `app.mount("/v1", WSGIMiddleware(flask_app))` | Synchronous WSGI bridged onto worker threads via `a2wsgi` | Incremental Strangler-Fig migration from Flask or Django to FastAPI |

## 3. Server-Rendered HTML with `Jinja2Templates` & `StaticFiles`

When building server-rendered pages or HTMX endpoints, install `jinja2` and pair `fastapi.templating.Jinja2Templates` with a named `StaticFiles` mount:

- **Modern Keyword Signature (`TemplateResponse`)**: Always pass `request=request, name="item.html", context={...}` as keyword arguments (Starlette deprecated the legacy positional `TemplateResponse("item.html", {"request": request})` call signature).
- **Reverse Asset URLs (`url_for`)**: Naming the mount (`name="static"`) lets templates generate proxy-aware URLs via `{{ url_for('static', path='/styles.css') }}`, automatically respecting upstream `root_path` prefixes.
- **XSS Auto-Escaping by Default**: Jinja2 enables `autoescape` automatically for `.html`, `.htm`, and `.xml` templates. Always wrap interpolated HTML attributes in double quotes (`data-item-id="{{ id }}"`) and avoid `| safe` on untrusted strings.

```python
from pathlib import Path
from typing import Annotated
from fastapi import FastAPI, Path as PathParam, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates


def create_ssr_app(static_dir: Path, templates_dir: Path) -> FastAPI:
    app = FastAPI()
    app.mount("/static", StaticFiles(directory=static_dir), name="static")
    templates = Jinja2Templates(directory=templates_dir)

    # templates/item.html:
    # <link href="{{ url_for('static', path='/styles.css') }}" rel="stylesheet">
    # <h1 data-item-id="{{ id }}">Item: {{ title }}</h1>
    @app.get("/items/{id}", response_class=HTMLResponse)
    async def read_item_page(
        request: Request,
        id: Annotated[str, PathParam(pattern=r"^[a-zA-Z0-9_-]+$")],
        title: str = "Wireless Keyboard",
    ) -> HTMLResponse:
        return templates.TemplateResponse(
            request=request,
            name="item.html",
            context={"id": id, "title": title},
        )

    return app
```

## 4. Isolated Sub-Applications & Legacy WSGI Migration (`a2wsgi`)

### Independent Sub-Apps & Automatic ASGI `root_path` Propagation

Unlike `app.include_router()`, which merges routes into a single OpenAPI schema and shared middleware stack, `app.mount("/subapi", subapi)` attaches a **completely independent ASGI application**:

- **Isolated OpenAPI & Docs UI**: The host app exposes `/openapi.json` and `/docs` containing only host routes, while `subapi` serves its own isolated `/subapi/openapi.json` and `/subapi/docs`.
- **Automatic `root_path` Injection**: Starlette's `Mount` appends `"/subapi"` onto `scope["root_path"]` before invoking `subapi`, so Swagger UI at `/subapi/docs` automatically resolves its schema and interactive "Try it out" requests relative to `/subapi`.
- **Lifespan Note**: Mounted sub-applications do **not** have their `lifespan` events executed automatically by Starlette's `Mount`; initialize shared pools in the top-level host `lifespan` or compose sub-app lifespans explicitly with `contextlib.AsyncExitStack` (see [Enterprise DI, Lifespan & Testing](../02_enterprise_architecture/di_lifespan_testing.md)).

### Strangler-Fig WSGI Migration with `a2wsgi.WSGIMiddleware`

When migrating an existing Flask or Django monolith incrementally to FastAPI, mount the legacy WSGI callable under a prefix while building new async endpoints on the outer FastAPI host. Because Starlette deprecated `starlette.middleware.wsgi.WSGIMiddleware`, FastAPI recommends **`a2wsgi.WSGIMiddleware`** (`pip install a2wsgi`), which streams request/response chunks safely between the async event loop and synchronous WSGI worker threads while populating `SCRIPT_NAME` from the mount prefix:

```python
from a2wsgi import WSGIMiddleware
from fastapi import FastAPI, Request
from flask import Flask, jsonify, request as flask_request

# 1. Independent FastAPI sub-application with isolated /subapi/docs
subapi = FastAPI(title="Partner Sub-API", version="2.0.0")


@subapi.get("/sub")
def read_sub(request: Request) -> dict[str, str]:
    return {
        "message": "Hello from sub-application",
        "root_path": request.scope.get("root_path", ""),
    }


# 2. Legacy synchronous Flask (WSGI) application
flask_app = Flask(__name__)


@flask_app.get("/orders")
def legacy_orders():
    return jsonify({"service": "legacy-flask", "script_name": flask_request.script_root})


# 3. Unified FastAPI host mounting both the sub-app and WSGI bridge
app = FastAPI(title="Main Gateway API", version="1.0.0")


@app.get("/app")
def read_main() -> dict[str, str]:
    return {"message": "Hello World from main app"}


app.mount("/subapi", subapi)
app.mount("/v1", WSGIMiddleware(flask_app))
```

Next, explore how FastAPI extends OpenAPI `3.1.0` for asynchronous event push, client SDK code generation, and air-gapped documentation portals in **[Webhooks, Callbacks, SDKs & Docs UI](webhooks_callbacks_sdks.md)**, or review reverse-proxy `--forwarded-allow-ips` deployment in **[FastAPI CLI, Proxies, GraphQL & AI](../08_ecosystem_and_operations/cli_proxy_graphql_ai.md)**.
