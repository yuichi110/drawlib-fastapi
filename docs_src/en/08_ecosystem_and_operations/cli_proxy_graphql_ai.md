# FastAPI CLI, Reverse Proxies, GraphQL & AI Development

FastAPI `v0.162.2` unifies local-to-production server operations (`fastapi dev` / `fastapi run` and ASGI `--root-path` proxy routing), hybrid `Strawberry` GraphQL sub-routers sharing `Depends()`, and bundled AI coding agent skills (`uvx library-skills` + `PEP 727` `Doc()` + SSE/JSONL streaming).

```drawlib align=center code=fold file=cli_and_reverse_proxy_topology.png caption="FastAPI CLI Modes (fastapi dev vs fastapi run) & Reverse Proxy Path Prefix (--root-path) Topology"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.lines import line
from drawlib.shapes import rectangle
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=198, height=90, dpi=150)

text(
    (99.0, 85.0),
    "FastAPI CLI Modes & Reverse Proxy (--root-path) Operational Topology",
    style=Styles.DarkBold.patch(text_size=13.0),
)

# Left Panel: FastAPI CLI
cli_panel = Panel(
    "1. FastAPI CLI (fastapi[standard])",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.terminal_window,
    icon_style=Styles.SecondaryBold,
    header_variant="filled",
    header_height=8.5,
)
cli_panel.draw((4.0, 5.0), width=82.0, height=74.0)
l_xy, l_w, l_h = cli_panel.get_content_box((4.0, 5.0), width=82.0, height=74.0, padding=(3.5, 3.0))

cl_cli = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.SecondaryBold,
    direction="vertical",
    spacing=2.8,
)
cl_cli.add(
    "[tool.fastapi] Entrypoint",
    "pyproject.toml -> 'app.main:app'",
    badge_text="TOML",
    icon=phosphor.file_code,
)
cl_cli.add(
    "fastapi dev",
    "127.0.0.1 • Reload • FASTAPI_ENV=dev",
    badge_text="DEV",
    icon=phosphor.code,
    style=Styles.SecondaryNeutral,
)
cl_cli.add(
    "fastapi run",
    "Prod Uvicorn • --workers • --proxy-headers",
    badge_text="RUN",
    icon=phosphor.rocket_launch,
    style=Styles.PrimaryNeutral,
    badge_style=Styles.PrimaryFlat,
    badge_text_style=Styles.WhiteBold.patch(text_size=10.0),
    icon_style=Styles.WhiteBold,
)
cl_cli.draw(xy=l_xy, width=l_w, height=l_h)

# Right Panel: Behind a Reverse Proxy & --root-path
proxy_panel = Panel(
    "2. TLS Reverse Proxy & --root-path /api/v1",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.globe,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
proxy_panel.draw((90.0, 5.0), width=104.0, height=74.0)

# Top ingress boxes inside Right Panel
rectangle((115.0, 58.5), width=42.0, height=15.5, style=Styles.White.patch(shape_r=1.8))
text((115.0, 61.5), "TLS Edge Proxy", style=Styles.DarkBold.patch(text_size=10.5))
text((115.0, 55.8), "Strips /api/v1", style=Styles.Dark.patch(text_size=10.0))

line((136.5, 58.5), (144.5, 58.5), arrow_head="->", style=Styles.PrimaryBold.patch(line_width=1.8))

rectangle((167.5, 58.5), width=45.0, height=15.5, style=Styles.PrimaryFlat.patch(shape_r=1.8))
text((167.5, 61.5), "--root-path /api/v1", style=Styles.WhiteBold.patch(text_size=10.5))
text((167.5, 55.8), "scope['root_path']", style=Styles.White.patch(text_size=10.0))

line((167.5, 50.5), (167.5, 44.5), arrow_head="->", style=Styles.DarkBold.patch(line_width=1.6))

# Middle OpenAPI resolution card
rectangle((142.0, 35.5), width=96.0, height=16.5, style=Styles.PrimaryNeutral.patch(shape_r=1.8))
phosphor.file_text((100.0, 35.5), width=5.0, style=Styles.PrimaryBold)
text(
    (105.5, 38.5),
    "Per-Request OpenAPI & Swagger UI Resolution",
    style=Styles.DarkBold.patch(text_size=10.5, halign="left"),
)
text(
    (105.5, 32.5),
    "servers: [{'url': '/api/v1'}]  •  /docs -> /api/v1/openapi.json",
    style=Styles.Dark.patch(text_size=10.0, halign="left"),
)

# Bottom Edge Middleware & v0.146.0 Deprecation card
rectangle((142.0, 15.5), width=96.0, height=16.5, style=Styles.SecondaryNeutral.patch(shape_r=1.8))
phosphor.shield_check((100.0, 15.5), width=5.0, style=Styles.SecondaryBold)
text(
    (105.5, 18.5),
    "Edge Middleware & v0.146.0+ Server Rule",
    style=Styles.DarkBold.patch(text_size=10.5, halign="left"),
)
text(
    (105.5, 12.5),
    "TrustedHost • HTTPSRedirect • GZip  •  Avoid app root_path",
    style=Styles.Dark.patch(text_size=10.0, halign="left"),
)

save()
```

## 1. FastAPI CLI, Reverse Proxies (`--root-path`) & Edge Middleware

Installing `pip install "fastapi[standard]"` equips the `fastapi` command (`fastapi.cli:main` delegating to `fastapi-cli`), replacing ad-hoc shell scripts with standardized local development, production ASGI execution, and optional managed cloud deployment (`uv run fastapi deploy`).

### Declaring `[tool.fastapi]` & Comparing `fastapi dev` vs `fastapi run`

Rather than repeating module paths on every command line, register your application object once in `pyproject.toml`:

```toml
[tool.fastapi]
entrypoint = "my_app.main:app"
```

With `entrypoint` configured, `fastapi dev` and `fastapi run` apply distinct security and concurrency defaults tailored to each environment:

| Capability | `fastapi dev` (Local Development) | `fastapi run` (Production Runtime) |
| :--- | :--- | :--- |
| **Default Bind Address** | `127.0.0.1:8000` (safe local loopback only) | `0.0.0.0:8000` (container interface; restrict behind proxy) |
| **Auto-Reload & Watchers** | **Enabled** (restarts instantaneously on file edits) | **Disabled** (zero filesystem polling overhead) |
| **`FASTAPI_ENV` Variable** | Sets `FASTAPI_ENV="development"` if unset | Unset (`app.frontend(check_dir="auto")` enforces build check) |
| **Scaling & Proxy Flags** | Single reload process | `--workers N`, `--proxy-headers`, `--root-path /api/v1` |

### Reverse Proxies & the `v0.146.0` Deprecation of `FastAPI(root_path=...)`

In microservice gateways (Nginx, Traefik, Envoy, Cloud Load Balancing), an external proxy frequently routes `https://api.example.com/api/v1/catalog` to an internal container while **stripping the `/api/v1` prefix** so the container receives `/catalog`. Without knowing that external prefix, Swagger UI (`/docs`) would try to fetch `/openapi.json` at the root domain instead of `/api/v1/openapi.json` and fail with `404`.

Starting in **FastAPI `v0.146.0`** (and enforced with `FastAPIDeprecationWarning` in `v0.162.2`), passing `FastAPI(root_path="/api/v1")` in Python code is **deprecated**. Mount prefixes belong to deployment topology—not application source code—so configure the ASGI server via CLI instead:

```bash
fastapi run --proxy-headers --root-path /api/v1
```

Inside `FastAPI.setup()`, `v0.162.2` reads `req.scope.get("root_path", "")` dynamically on every `/openapi.json`, `/docs`, and `/redoc` request:

1. **Zero Cache Poisoning**: `app.openapi()` caches the base OpenAPI `3.1.0` dictionary once, and the `/openapi.json` route shallow-copies that dictionary per request to prepend `{"url": "/api/v1"}` to `servers` (unless `root_path_in_servers=False`)—ensuring a spoofed or tenant-specific `root_path` never mutates `app.openapi_schema` for other requests.
2. **Automatic Docs UI Rewriting**: Swagger UI (`/docs`), OAuth2 redirect (`/docs/oauth2-redirect`), and ReDoc (`/redoc`) automatically prefix `openapi_url` with `root_path` (`/api/v1/openapi.json`).

### Built-in Edge Security & Compression Middlewares

Alongside custom [pure ASGI middlewares](../05_async_and_realtime/concurrency_and_middleware.md), `fastapi.middleware` re-exports battle-tested edge middlewares:

- **`TrustedHostMiddleware(allowed_hosts=[...])`**: Defends against HTTP `Host` header poisoning attacks by rejecting unrecognized `Host` headers with `400 Bad Request`.
- **`HTTPSRedirectMiddleware`**: Enforces `307 Temporary Redirect` from `http://` to `https://` (or `ws://` to `wss://`) when TLS is not already enforced at an upstream load balancer.
- **`GZipMiddleware(minimum_size=1000, compresslevel=5)`**: Compresses responses exceeding `minimum_size` bytes whenever the client sends `Accept-Encoding: gzip`.

```python
import warnings

from fastapi import FastAPI, Request
from fastapi.exceptions import FastAPIDeprecationWarning
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.middleware.httpsredirect import HTTPSRedirectMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.testclient import TestClient


def build_edge_app(*, enforce_https: bool = False) -> FastAPI:
    app = FastAPI(title="Edge Catalog API", version="1.0.0")
    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=["api.example.com", "testserver"],
    )
    app.add_middleware(GZipMiddleware, minimum_size=500, compresslevel=5)
    if enforce_https:
        app.add_middleware(HTTPSRedirectMiddleware)

    @app.get("/catalog")
    def read_catalog(request: Request) -> dict[str, object]:
        return {
            "root_path": request.scope.get("root_path", ""),
            "items": [f"sku-{idx:03d}-enterprise-edition" for idx in range(40)],
        }

    return app


def test_root_path_openapi_servers_and_edge_middlewares() -> None:
    app = build_edge_app()

    # Simulate `fastapi run --root-path /api/v1` via ASGI scope root_path
    with TestClient(app, root_path="/api/v1") as prefixed_client:
        res = prefixed_client.get("/catalog", headers={"Accept-Encoding": "gzip"})
        assert res.status_code == 200
        assert res.headers.get("content-encoding") == "gzip"
        assert res.json()["root_path"] == "/api/v1"

        schema = prefixed_client.get("/openapi.json").json()
        assert schema["servers"] == [{"url": "/api/v1"}]
        assert "/api/v1/openapi.json" in prefixed_client.get("/docs").text

    # Unprefixed requests remain clean; spoofed Host headers return 400
    with TestClient(app) as direct_client:
        assert "servers" not in direct_client.get("/openapi.json").json()
        bad_host = direct_client.get("/catalog", headers={"Host": "evil.attacker.tld"})
        assert bad_host.status_code == 400

    # HTTPSRedirectMiddleware redirects plain HTTP -> HTTPS (307)
    https_app = build_edge_app(enforce_https=True)
    with TestClient(https_app, base_url="http://api.example.com") as http_client:
        redir = http_client.get("/catalog", follow_redirects=False)
        assert redir.status_code == 307
        assert redir.headers["location"] == "https://api.example.com/catalog"

    # Passing root_path to FastAPI(...) emits FastAPIDeprecationWarning
    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        FastAPI(root_path="/legacy")
        assert any(issubclass(w.category, FastAPIDeprecationWarning) for w in caught)
```

---

## 2. Strawberry GraphQL & AI-Native Development Workflow

FastAPI's type-annotation design extends naturally to both typed GraphQL query graphs via **`Strawberry`** and modern **AI Coding Agents / MCP tool ecosystems**.

```drawlib align=center code=fold file=graphql_and_ai_agent_workflow.png caption="Hybrid Strawberry GraphQLRouter with Shared Depends() Context & FastAPI v0.162.2 AI Agent Workflow"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=192, height=90, dpi=150)

text(
    (96.0, 85.0),
    "Strawberry GraphQL DI Integration & FastAPI v0.162.2 AI Agent Workflow",
    style=Styles.DarkBold.patch(text_size=13.0),
)

# Left Panel: Strawberry GraphQL
gql_panel = Panel(
    "1. Strawberry GraphQLRouter + FastAPI DI",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.graph,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
gql_panel.draw((4.0, 5.0), width=90.0, height=74.0)
l_xy, l_w, l_h = gql_panel.get_content_box((4.0, 5.0), width=90.0, height=74.0, padding=(3.5, 3.0))

cl_gql = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    direction="vertical",
    spacing=2.8,
)
cl_gql.add(
    "Shared FastAPI Depends()",
    "OAuth2 Viewer • SQLModel Session • Settings",
    badge_text="DI",
    icon=phosphor.plugs,
)
cl_gql.add(
    "context_getter Bridge",
    "BaseContext injects DI into info.context",
    badge_text="CTX",
    icon=phosphor.arrows_left_right,
    style=Styles.PrimaryNeutral,
)
cl_gql.add(
    "include_router(..., '/graphql')",
    "Typed @strawberry.type alongside REST",
    badge_text="GQL",
    icon=phosphor.brackets_curly,
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
    badge_style=Styles.White,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
)
cl_gql.draw(xy=l_xy, width=l_w, height=l_h)

# Right Panel: Develop with AI Workflow
ai_panel = Panel(
    "2. Develop with AI & Bundled Agent Skills",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.sparkle,
    icon_style=Styles.SecondaryBold,
    header_variant="filled",
    header_height=8.5,
)
ai_panel.draw((98.0, 5.0), width=90.0, height=74.0)
r_xy, r_w, r_h = ai_panel.get_content_box((98.0, 5.0), width=90.0, height=74.0, padding=(3.5, 3.0))

cl_ai = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.SecondaryBold,
    direction="vertical",
    spacing=2.8,
)
cl_ai.add(
    "uvx library-skills",
    "Installs bundled fastapi/.agents/skills",
    badge_text="1",
    icon=phosphor.robot,
    style=Styles.SecondaryNeutral,
)
cl_ai.add(
    "Doc() + OpenAPI 3.1 + llms.txt",
    "PEP 727 contracts for agents & SDKs",
    badge_text="2",
    icon=phosphor.book_open,
)
cl_ai.add(
    "AI & MCP Streaming",
    "POST EventSourceResponse & JSONL yield",
    badge_text="3",
    icon=phosphor.broadcast,
    style=Styles.PrimaryNeutral,
    badge_style=Styles.PrimaryFlat,
    badge_text_style=Styles.WhiteBold.patch(text_size=10.0),
    icon_style=Styles.WhiteBold,
)
cl_ai.draw(xy=r_xy, width=r_w, height=r_h)

save()
```

### Mounting `Strawberry` (`GraphQLRouter`) with Shared `Depends()`

GraphQL excels when frontend views traverse deeply nested object graphs in a single round-trip, while standard REST operations remain simpler for HTTP edge caching, [typed OpenAPI SDK generation](../07_frontend_and_openapi_ext/webhooks_callbacks_sdks.md), file uploads, and status-code semantics. Rather than running a separate GraphQL server, **`Strawberry`** (`strawberry-graphql`) mounts directly onto FastAPI as an `APIRouter` via `GraphQLRouter`:

- **Type-Hint Symmetry**: `@strawberry.type` classes mirror Python `dataclasses` and Pydantic models using native type annotations.
- **Unified Dependency Injection (`context_getter`)**: Subclassing `strawberry.fastapi.BaseContext` and passing an async or sync `context_getter` function lets GraphQL resolvers consume the **exact same FastAPI `Depends()` dependencies** (OAuth2 user extractors, [SQLModel `SessionDep`](settings_and_databases.md), and `SettingsDep`)—meaning `app.dependency_overrides` automatically controls both REST and `/graphql` in `pytest`!

### Developing with AI in FastAPI `v0.162.2` (`library-skills`, `Doc()` & MCP SSE)

Because LLMs pre-trained on older corpora often emit outdated patterns (such as deprecated `ORJSONResponse`, `RootModel`, bare `Depends()` defaults, or legacy `@app.on_event("startup")`), FastAPI `v0.162.2` ships **official, version-pinned AI Agent Skills** directly inside the `fastapi` wheel (`fastapi/.agents/skills/fastapi/SKILL.md` + `references/`):

1. **Sync Version-Matched Skills via `uvx library-skills`**: Running `uvx library-skills` extracts the exact `.agents/skills/fastapi/` rules bundled with your installed `fastapi` version into your workspace so coding agents automatically apply `Annotated[..., Depends()]`, `app.frontend()`, native OpenTelemetry, `EventSourceResponse`, `SQLModel`, and `Asyncer` (`asyncify` / `syncify`).
2. **Machine-Readable Contracts (`PEP 727 Doc()`, OpenAPI `3.1.0` & `llms.txt`)**: Annotating parameters with `Annotated[str, Doc("...")]` enriches `/openapi.json` (`3.1.0` JSON Schema), allowing agent tool registries, OpenAPI client generators, and `llms.txt` documentation indexes to inspect exact types and constraints without hallucinating parameters.
3. **AI & Model Context Protocol (MCP) Streaming**: FastAPI's native [Server-Sent Events (`EventSourceResponse`) and JSON Lines](../05_async_and_realtime/sse_websockets_streaming.md) work seamlessly on **`POST` as well as `GET`**, making `response_class=EventSourceResponse` with `yield` ready out-of-the-box for LLM token streaming and MCP HTTP+SSE transports.

```python
from collections.abc import AsyncIterable
from typing import Annotated

from annotated_doc import Doc
from fastapi import Depends, FastAPI
from fastapi.sse import EventSourceResponse, ServerSentEvent
from fastapi.testclient import TestClient
from pydantic import BaseModel
import strawberry
from strawberry.fastapi import BaseContext, GraphQLRouter


def get_current_viewer() -> str:
    return "alice@corp.internal"


ViewerDep = Annotated[str, Depends(get_current_viewer)]


class GraphQLContext(BaseContext):
    def __init__(self, viewer: str) -> None:
        super().__init__()
        self.viewer = viewer


async def get_graphql_context(viewer: ViewerDep) -> GraphQLContext:
    return GraphQLContext(viewer=viewer)


@strawberry.type
class BookNode:
    title: str
    author: str
    requested_by: str


@strawberry.type
class QueryRoot:
    @strawberry.field
    def books(self, info: strawberry.Info[GraphQLContext, None]) -> list[BookNode]:
        return [
            BookNode(
                title="FastAPI Architecture",
                author="Sebastián Ramírez",
                requested_by=info.context.viewer,
            )
        ]


graphql_schema = strawberry.Schema(query=QueryRoot)
graphql_router = GraphQLRouter(graphql_schema, context_getter=get_graphql_context)

app = FastAPI(title="Hybrid REST + GraphQL + AI Gateway")
app.include_router(graphql_router, prefix="/graphql", tags=["graphql"])


class AgentPrompt(BaseModel):
    prompt: Annotated[str, Doc("Natural-language instruction sent by the AI agent.")]


@app.post("/ai/stream", response_class=EventSourceResponse)
async def stream_agent_steps(
    body: AgentPrompt,
    viewer: ViewerDep,
) -> AsyncIterable[ServerSentEvent]:
    yield ServerSentEvent(
        event="agent.step",
        id="1",
        data={"viewer": viewer, "accepted_prompt": body.prompt},
    )


def test_strawberry_graphql_di_and_ai_sse() -> None:
    app.dependency_overrides[get_current_viewer] = lambda: "bot@ci.local"
    try:
        with TestClient(app) as client:
            gql_res = client.post(
                "/graphql",
                json={"query": "{ books { title requestedBy } }"},
            )
            assert gql_res.status_code == 200
            assert gql_res.json() == {
                "data": {
                    "books": [
                        {
                            "title": "FastAPI Architecture",
                            "requestedBy": "bot@ci.local",
                        }
                    ]
                }
            }

            sse_res = client.post("/ai/stream", json={"prompt": "Summarize schema"})
            assert sse_res.status_code == 200
            assert sse_res.headers["content-type"].startswith("text/event-stream")
            assert "event: agent.step" in sse_res.text
    finally:
        app.dependency_overrides.clear()
```

Review [pydantic-settings & SQL Databases](settings_and_databases.md) for typed environment configuration and `SQLModel` testing, or return to the [Overview & Architecture Map](../index.md) for the complete FastAPI `v0.162.2` curriculum.
