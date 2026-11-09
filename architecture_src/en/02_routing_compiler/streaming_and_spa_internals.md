# Generator Streaming (SSE / JSONL) & SPA Router Internals

Beyond request-response JSON endpoints, FastAPI `v0.162.2` compiles two specialized runtime pipelines directly inside `fastapi/routing.py` and `fastapi/sse.py`: **native generator streaming**—which turns `yield` path operations into per-item validated JSON Lines (`application/jsonl`) or PEP 789-safe Server-Sent Events (`text/event-stream`) while holding `fastapi_inner_astack` open until stream completion—and the **low-priority SPA engine** (`APIRouter.frontend()` / `_FrontendRouteGroup`), which serves static assets and HTML5 history fallbacks behind normal API routes with strict traversal and `Accept`-header guards.

```drawlib align=center code=hide file=generator_dispatch_branches.png caption="Compile-Time Return Annotation Inspection, Generator Streaming Branches & AsyncExitStack Lifetime"
from drawlib.canvas import save, setup
from drawlib.diagrams.flow import Data, Decision, End, FlowDiagram, Process, Start
from drawlib.styles import Colors, Styles

setup(width=170, height=112)

flow = FlowDiagram(
    node_style=Styles.Neutral,
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.DarkBold.patch(text_size=10.0),
    width=160,
    height=102,
    lane_orientation="vertical",
)

# 3 Vertical Swimlanes: 48 + 58 + 54 = 160 (centerlines at X = 24, 77, 133)
flow.add_lane(
    "1. Compile-Time Inspect",
    width=48,
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
)
flow.add_lane(
    "2. Closure Dispatch Branch",
    width=58,
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
)
flow.add_lane(
    "3. Wire Framing & ExitStack",
    width=54,
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
)

# Lane 1 Nodes (X = 24)
ep = flow.add(
    Start(
        "Endpoint Signature\n& Return Annotation",
        width=38,
        height=9.5,
        style=Styles.PrimaryFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
    ),
    xy=(24, 87),
)
is_gen = flow.add(
    Decision(
        "Uses yield?\n(gen / async_gen)",
        width=38,
        height=14,
        style=Styles.PrimaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    ),
    xy=(24, 67),
)
item_field = flow.add(
    Process(
        "get_stream_item_type()\n-> stream_item_field",
        width=38,
        height=12,
        style=Styles.Neutral,
        text_style=Styles.Dark.patch(text_size=10.0),
    ),
    xy=(24, 31),
)

# Lane 2 Nodes (X = 78, width = 42 -> left edge = 57)
ret_branch = flow.add(
    Process(
        "Standard return\nresponse_field.serialize_json()",
        width=42,
        height=11,
        style=Styles.Neutral,
        text_style=Styles.Dark.patch(text_size=10.0),
    ),
    xy=(78, 67),
)
sse_branch = flow.add(
    Process(
        "is_sse_stream\n_sse_producer_cm + 15s Ping",
        width=42,
        height=11.5,
        style=Styles.PrimaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    ),
    xy=(78, 48),
)
jsonl_branch = flow.add(
    Process(
        "is_json_stream\n_serialize_data(item) + b'\\n'",
        width=42,
        height=11.5,
        style=Styles.SecondaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    ),
    xy=(78, 31),
)
raw_branch = flow.add(
    Process(
        "Custom response_class\nRaw chunk iterator + sleep(0)",
        width=42,
        height=11,
        style=Styles.Neutral,
        text_style=Styles.Dark.patch(text_size=10.0),
    ),
    xy=(78, 13),
)

# Lane 3 Nodes (X = 130)
json_wire = flow.add(
    Data(
        "application/json\nFull Array / Object",
        width=38,
        height=11,
        style=Styles.Neutral,
        text_style=Styles.Dark.patch(text_size=10.0),
    ),
    xy=(130, 67),
)
sse_wire = flow.add(
    Data(
        "text/event-stream\nformat_sse_event()",
        width=38,
        height=11.5,
        style=Styles.AccentFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
    ),
    xy=(130, 48),
)
jsonl_wire = flow.add(
    Data(
        "application/jsonl\nNDJSON Byte Stream",
        width=38,
        height=11.5,
        style=Styles.Neutral,
        text_style=Styles.Dark.patch(text_size=10.0),
    ),
    xy=(130, 31),
)
astack = flow.add(
    End(
        "Close inner_astack\nAfter Stream Ends",
        width=38,
        height=11,
        style=Styles.PrimaryFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
    ),
    xy=(130, 13),
)

# Clean non-overlapping edges (terminal segments >= 7.9u)
ep.connect(is_gen, start_side="bottom", end_side="top", padding=0.6)
is_gen.connect(ret_branch, label="No", start_side="right", end_side="left", padding=0.6)
is_gen.connect(item_field, label="Yes", start_side="bottom", end_side="top", padding=0.6)

item_field.fork([sse_branch, jsonl_branch, raw_branch], at_x=48.5, padding=0.6)

ret_branch.connect(json_wire, start_side="right", end_side="left", padding=0.6)
sse_branch.connect(sse_wire, start_side="right", end_side="left", padding=0.6)
jsonl_branch.connect(jsonl_wire, start_side="right", end_side="left", padding=0.6)
raw_branch.connect(astack, start_side="right", end_side="left", padding=0.6)
jsonl_wire.connect(astack, start_side="bottom", end_side="top", padding=0.6)
sse_wire.connect(astack, start_side="right", end_side="right", padding=0.6).via(
    (155, 48), (155, 13)
)

flow.draw(xy=(5.0, 5.0))
save()
```

## 1. Compile-Time Generator Detection & `stream_item_field` Synthesis

During `_populate_api_route_state()`, FastAPI tests whether the unwrapped endpoint callable is a synchronous or asynchronous generator (`is_generator = _is_async_gen_callable(route.dependant.call) or _is_gen_callable(route.dependant.call)`). This compile-time flag splits return-type compilation into four distinct execution modes:

| Endpoint Form & `response_class` | `is_sse_stream` | `is_json_stream` | Compiled `ModelField` | Wire `Content-Type` & OpenAPI 3.2 Schema |
| :--- | :--- | :--- | :--- | :--- |
| `def` / `async def` with `return` (`list[Item]`) | `False` | `False` | `response_field` (`Response_<id>`) | `application/json` (`schema` array accumulation) |
| `yield` + `Default(JSONResponse)` | `False` | `True` | `stream_item_field` (`StreamItem_<id>`) | `application/jsonl` (`itemSchema` per-line model) |
| `yield` + `EventSourceResponse` | `True` | `False` | `stream_item_field` (unless `ServerSentEvent`) | `text/event-stream` (`_SSE_EVENT_SCHEMA` / `itemSchema`) |
| `yield` + explicit `StreamingResponse` | `False` | `False` | `None` (`response_model = None`) | Custom `media_type` (raw chunk passthrough) |

When `response_model` is left at `Default(None)` on a generator endpoint, `get_stream_item_type(return_annotation)` checks whether `get_origin(annotation)` belongs to `_STREAM_ORIGINS` (`{AsyncIterable, AsyncIterator, AsyncGenerator, Iterable, Iterator, Generator}`):

- **Parameterized Stream Types (`AsyncIterable[Item]`, `Generator[Item, None, None]`)**: Extracts `type_args[0]` (`Item`) as `route.stream_item_type`, clears `route.response_model = None` (since the endpoint yields items incrementally rather than returning a single container), and builds `route.stream_item_field = create_model_field(name="StreamItem_" + route.unique_id, type_=Item, mode="serialization")`.
- **Bare Stream Annotations (`-> AsyncIterable`, `-> Iterable`)**: `get_stream_item_type()` returns `Any`, setting `stream_item_type = Any` so items still stream as JSONL/SSE via `TypeAdapter(Any)`.
- **`ServerSentEvent` Exclusion**: If the return type is `AsyncIterable[ServerSentEvent]`, `not lenient_issubclass(stream_item, ServerSentEvent)` skips `stream_item_field` creation because `ServerSentEvent` is a wire-framing envelope rather than a domain payload schema.

## 2. Runtime Streaming Pipelines: JSONL, SSE TaskGroup & `fastapi_inner_astack`

### 2.1 Shared Per-Item Validation (`_serialize_data`) & JSONL Framing

Inside `get_request_handler()`, both JSONL and SSE share an inner `_serialize_data(data: Any) -> bytes` helper:
- When `stream_item_field` is present, each yielded item is validated incrementally via `stream_item_field.validate(data, {}, loc=("response",))` (raising `ResponseValidationError` mid-stream if an item violates the schema) and serialized directly to UTF-8 JSON bytes via `stream_item_field.serialize_json(...)`, honoring `response_model_include`, `response_model_exclude`, `by_alias`, `exclude_unset`, `exclude_defaults`, and `exclude_none`.
- When `stream_item_field` is `None`, FastAPI falls back to `jsonable_encoder(data)` followed by `_normalize_non_finite_floats(data)` (converting `NaN`, `Infinity`, and `-Infinity` floats into JSON `null`) and `json.dumps(...).encode("utf-8")`.

For **`is_json_stream`** (`application/jsonl`), FastAPI wraps `gen = dependant.call(**solved_result.values)` in `_async_stream_jsonl()` (for async generators) or `_sync_stream_jsonl()` (for sync generators, iterated in Starlette's threadpool by `StreamingResponse`), appending `b"\n"` to every serialized item. Async generator wrappers explicitly execute **`await anyio.sleep(0)`** after every `yield` (also applied in raw `_async_stream_raw` for explicit `StreamingResponse` endpoints) to insert an `anyio` cancellation checkpoint—ensuring client disconnects cancel fast CPU-bound producers that never otherwise suspend.

Crucially, because `request_response()` enters `scope["fastapi_inner_astack"]` **outside** `await response(scope, receive, send)`, any request-scoped `yield` dependency (such as an async SQLAlchemy session) stays open throughout the entire `StreamingResponse` body iteration and executes its `finally` block only after the last chunk is sent or the client disconnects.

### 2.2 `fastapi/sse.py`: `EventSourceResponse`, `ServerSentEvent` & PEP 789 Producer TaskGroup

`fastapi/sse.py` defines the public types and wire encoder for Server-Sent Events:
- **`EventSourceResponse(StreamingResponse)`**: Marker subclass setting `media_type = "text/event-stream"`. Works on **any HTTP method** (`GET`, `POST`, etc.), enabling protocols such as Model Context Protocol (MCP) that stream SSE over `POST`.
- **`ServerSentEvent(BaseModel)`**: Structured envelope with `data: Any = None` (always JSON-serialized, so `"hello"` becomes `data: "hello"`), `raw_data: str | None = None` (unquoted raw string, enforced mutually exclusive with `data` via `@model_validator(mode="after")`), single-line `event`, null-free single-line `id`, `retry: int | None` (`Field(ge=0)`), and `comment: str | None`.
- **`format_sse_event()`**: Splits `comment` and `data_str` exclusively on SSE-spec line endings (`\r\n`, `\r`, `\n`) via `_split_sse_lines()`, emits `: <comment>`, `event: <event>`, one `data: <line>` per line, `id: <id>`, and `retry: <retry>`, and terminates every frame with `\n\n` encoded as UTF-8 `bytes`.

At runtime, `is_sse_stream` avoids wrapping `anyio.fail_after(_PING_INTERVAL)` directly around `gen.__anext__()`—which would inject `CancelledError` into a slow user generator on idle timeout and prematurely finalize it! Instead, FastAPI enters `@asynccontextmanager async def _sse_producer_cm()` onto **`fastapi_inner_astack`** (`await async_exit_stack.enter_async_context(_sse_producer_cm())`):

1. **Decoupled Memory Object Streams**: Creates two bounded `anyio.create_memory_object_stream[bytes](max_buffer_size=1)` channels (`send_stream`/`receive_stream` and `send_keepalive`/`receive_keepalive`) inside an `anyio.create_task_group()`.
2. **Producer & Keepalive Tasks**: `_producer()` pulls items from `gen.__aiter__()` (or `iterate_in_threadpool(gen)` for sync generators) and serializes `ServerSentEvent` instances or plain objects into `send_stream`. Concurrently, `_keepalive_inserter()` awaits `receive_stream.receive()` inside `with anyio.fail_after(_PING_INTERVAL):` (`15.0` seconds), forwarding serialized frames or emitting `KEEPALIVE_COMMENT = b": ping\n\n"` on `TimeoutError` to prevent reverse-proxy idle disconnects.
3. **PEP 789-Safe Teardown & Anti-Buffering Headers**: Entering `_sse_producer_cm()` on `fastapi_inner_astack` guarantees the `TaskGroup` cancels cleanly during structured `AsyncExitStack` unwinding rather than inside `GeneratorExit` finalization. The `StreamingResponse` consumes `_sse_with_checkpoints(sse_receive_stream)` and sets `Cache-Control: no-cache` plus `X-Accel-Buffering: no` (disabling Nginx proxy buffering).

## 3. SPA Engine Internals (`APIRouter.frontend` & `_FrontendRouteGroup`)

`app.frontend(path, directory=..., fallback="auto", check_dir="auto")` and `router.frontend(...)` mount static Single-Page Application (SPA) builds without shadowing API endpoints:

- **Startup Directory Validation (`_resolve_frontend_check_dir`)**: When `check_dir="auto"`, FastAPI enforces strict directory and fallback file existence (`RuntimeError`) in production, while downgrading missing build directories to a `UserWarning` when `FASTAPI_ENV == "development"` (set automatically by `fastapi dev` before the frontend bundler has emitted `dist/`).
- **Global Low-Priority Dispatch Order**: `APIRouter.frontend()` lazily creates `self._frontend_routes = _FrontendRouteGroup(...)` and appends it to `self._low_priority_routes` (excluded from OpenAPI schemas). Inside `APIRouter.app()`, incoming requests always evaluate **all** normal `self.routes` (including nested `_IncludedRouter` API routes) in strict priority before touching `_match_low_priority(scope)`:
  1. Normal `Match.FULL` (`APIRoute`, `APIWebSocketRoute`, `Mount`)
  2. Normal `Match.PARTIAL` (`405 Method Not Allowed` on a matched API path beats any frontend fallback!)
  3. `redirect_slashes` on normal routes (`307 Temporary Redirect` to `/api/` beats frontend files!)
  4. `_match_low_priority(scope)`: Selects the matching `_FrontendRoute` with the highest `_frontend_path_specificity(path)` (`0` for `"/"`, `len(path)` otherwise) across segment boundaries, then runs router/app `dependencies` in outer-to-inner order via `_FrontendRouteGroup._solve_dependencies()`.

```drawlib align=center code=hide file=frontend_route_group_fsm.png caption="APIRouter Dispatch Priority & _FrontendRouteGroup SPA Resolution Decision Tree"
from drawlib.canvas import save, setup
from drawlib.diagrams.flow import Data, Decision, End, FlowDiagram, Start
from drawlib.styles import Colors, Styles

setup(width=164, height=128)

flow = FlowDiagram(
    node_style=Styles.Neutral,
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.DarkBold.patch(text_size=10.0),
    width=154,
    height=118,
    lane_orientation="vertical",
)

# 2 Vertical Swimlanes: 77 + 77 = 154 (centerlines at X = 38.5, 115.5)
flow.add_lane(
    "1. Router Priority & Static Lookup",
    width=77,
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
)
flow.add_lane(
    "2. Fallback Cascade & Cache Headers",
    width=77,
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
)

# Row 1 (Y = 101): Entry
req = flow.add(
    Start(
        "Incoming HTTP Request",
        width=46,
        height=9.5,
        style=Styles.PrimaryFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.5),
    ),
    xy=(38.5, 101),
)

# Row 2 (Y = 81): Normal Route Priority Gate
api_chk = flow.add(
    Decision(
        "Normal Route Match?\n(FULL / 405 / 307)",
        width=50,
        height=13,
        style=Styles.PrimaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    ),
    xy=(38.5, 81),
)
api_win = flow.add(
    End(
        "Execute APIRoute\n(Frontend Ignored)",
        width=48,
        height=10,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    ),
    xy=(115.5, 81),
)

# Row 3 (Y = 58): Prefix Specificity, Router Depends & Method Gate
method_chk = flow.add(
    Decision(
        "Longest Prefix + Depends\nMethod in GET / HEAD?",
        width=52,
        height=13,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    ),
    xy=(38.5, 58),
)
bad_method = flow.add(
    Data(
        "405 if Static File Exists\n404 if Fallback-Only",
        width=48,
        height=10.5,
        style=Styles.Neutral,
        text_style=Styles.Dark.patch(text_size=10.0),
    ),
    xy=(115.5, 58),
)

# Row 4 (Y = 35): Traversal-Safe Static File Lookup
stat_chk = flow.add(
    Decision(
        "_lookup_static_resource()\nnormpath + no-symlink",
        width=52,
        height=13,
        style=Styles.SecondaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    ),
    xy=(38.5, 35),
)
serve_asset = flow.add(
    Data(
        "200 File / 307 Dir Slash\nETag + Dep Cache-Control",
        width=50,
        height=11,
        style=Styles.PrimaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    ),
    xy=(115.5, 35),
)

# Row 5 (Y = 12): SPA Navigation Fallback Gate
nav_chk = flow.add(
    Decision(
        "404.html or Navigation?\nAccept: text/html (q!=0)",
        width=54,
        height=13,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    ),
    xy=(38.5, 12),
)
spa_shell = flow.add(
    End(
        "200 index.html / 404.html\nElse HTTPException(404)",
        width=50,
        height=10.5,
        style=Styles.AccentFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
    ),
    xy=(115.5, 12),
)

# Pure vertical & horizontal non-overlapping connections
req.connect(api_chk, start_side="bottom", end_side="top", padding=0.6)
api_chk.connect(api_win, label="Yes", start_side="right", end_side="left", padding=0.6)
api_chk.connect(method_chk, label="No", start_side="bottom", end_side="top", padding=0.6)

method_chk.connect(bad_method, label="No", start_side="right", end_side="left", padding=0.6)
method_chk.connect(stat_chk, label="Yes", start_side="bottom", end_side="top", padding=0.6)

stat_chk.connect(serve_asset, label="Found", start_side="right", end_side="left", padding=0.6)
stat_chk.connect(nav_chk, label="Missing", start_side="bottom", end_side="top", padding=0.6)
nav_chk.connect(spa_shell, label="Fallback", start_side="right", end_side="left", padding=0.6)

flow.draw(xy=(5.0, 5.0))
save()
```

Inside `_FrontendStaticFiles(StaticFiles)` (initialized with `html=True` and `follow_symlink=False`), `get_response(path, scope)` enforces four security and protocol rules:

1. **Method & Traversal Protection (`_lookup_static_resource`)**: Normalizes `scope["fastapi"]["frontend_path"]` via `os.path.normpath` and executes `self.lookup_path(path)` inside `run_in_threadpool`. Because `follow_symlink=False` and Starlette validates `os.path.commonpath`, path traversal payloads (`/../`, `%2e%2e`, `%5c`) and symlinks escaping `directory` resolve to `404` (`PermissionError` maps to `401`; `ENAMETOOLONG` maps to `404`). Non-`GET`/`HEAD` requests return `405` **only** if `_lookup_static_resource` finds a real static file or directory `index.html`; `POST` requests to virtual client-side paths return `404`.
2. **Directory Slash Redirect**: If `path` resolves to a subdirectory containing `index.html` and `scope["path"]` lacks a trailing `"/"`, FastAPI returns a `307` `RedirectResponse` to `url.path + "/"` so relative asset URLs resolve cleanly.
3. **Fallback Cascade & `_is_frontend_navigation_request(scope)`**: When no static file matches:
   - **`404.html` Precedence**: If `fallback == "404.html"` or (`fallback == "auto"` and `404.html` exists), FastAPI serves `404.html` with `status_code=404` for all `GET`/`HEAD` misses.
   - **Explicit HTML Navigation Check for `index.html`**: Otherwise, if `index.html` is configured/present, FastAPI calls `_is_frontend_navigation_request(scope)`, which parses `Accept` media ranges via `_iter_accept_media_types()` (`email.message.Message`). It returns `True` **if and only if** the client explicitly advertises `text/html` or `application/xhtml+xml` with quality `q != 0`. Relying on `Accept` rather than file-extension heuristics ensures dotted SPA routes like `/users/jane.doe` or `/v/1.2.3` receive `200 index.html` on browser navigation, while missing subresources (`/assets/missing.js` sent with `Accept: */*` or `text/css`) cleanly receive `404` instead of corrupting the browser's JS parser with HTML!
4. **Conditional Caching & `Cache-Control` Header Synthesis**: Starlette's `file_response()` automatically populates `ETag` and `Last-Modified` headers (honoring `If-None-Match` / `If-Modified-Since` `304` responses). Because `_FrontendRouteGroup.handle()` merges `solved_result.response.headers.raw` onto the static `FileResponse`, router dependencies can attach differentiated `Cache-Control` headers—such as `public, max-age=31536000, immutable` on fingerprinted `/assets/*` bundles versus `no-cache` on fallback `index.html` responses.

## 4. Source-Verified Streaming & SPA Routing Inspection

### 4.1 Inspecting `stream_item_field`, JSONL Output & `format_sse_event()` Wire Framing

The snippet below verifies compile-time `is_json_stream` / `is_sse_stream` / `stream_item_field` synthesis alongside `format_sse_event()` wire encoding and `TestClient` streaming responses:

```python
import json
from collections.abc import AsyncIterable

from fastapi import FastAPI
from fastapi.routing import APIRoute
from fastapi.sse import EventSourceResponse, ServerSentEvent, format_sse_event
from fastapi.testclient import TestClient
from pydantic import BaseModel


class MetricChunk(BaseModel):
    step: int
    loss: float
    tag: str | None = None


app = FastAPI()


@app.get("/metrics.jsonl", response_model_exclude_none=True)
async def stream_jsonl() -> AsyncIterable[MetricChunk]:
    yield MetricChunk(step=1, loss=0.42)
    yield MetricChunk(step=2, loss=0.19, tag="converged")


@app.get("/metrics.sse", response_class=EventSourceResponse)
async def stream_sse() -> AsyncIterable[MetricChunk | ServerSentEvent]:
    yield MetricChunk(step=1, loss=0.42)
    yield ServerSentEvent(
        data={"done": True}, event="complete", id="evt-2", retry=5000
    )


routes = {r.path: r for r in app.router.routes if isinstance(r, APIRoute)}
assert routes["/metrics.jsonl"].is_json_stream is True
assert routes["/metrics.jsonl"].stream_item_field is not None
assert routes["/metrics.sse"].is_sse_stream is True

assert format_sse_event(data_str='{"ok":true}', event="tick", id="1") == (
    b'event: tick\ndata: {"ok":true}\nid: 1\n\n'
)

client = TestClient(app)
r_jsonl = client.get("/metrics.jsonl")
assert r_jsonl.headers["content-type"] == "application/jsonl"
assert [json.loads(line) for line in r_jsonl.text.splitlines()] == [
    {"step": 1, "loss": 0.42},
    {"step": 2, "loss": 0.19, "tag": "converged"},
]

r_sse = client.get("/metrics.sse")
assert r_sse.headers["cache-control"] == "no-cache"
assert r_sse.headers["x-accel-buffering"] == "no"
assert 'event: complete\ndata: {"done": true}\nid: evt-2\nretry: 5000\n\n' in r_sse.text
```

### 4.2 Verifying `_FrontendRouteGroup` Priority, Traversal Protection & `Cache-Control` Synthesis

This snippet mounts a SPA directory via `router.frontend()` with a `Cache-Control` policy dependency, demonstrating API route priority, fingerprinted `immutable` asset headers, `no-cache` HTML fallback on dotted client routes, `*/*` asset `404` rejection, and `%2e%2e` traversal blocking:

```python
from pathlib import Path
from tempfile import TemporaryDirectory

from fastapi import APIRouter, Depends, FastAPI, Request, Response
from fastapi.testclient import TestClient

with TemporaryDirectory() as tmp:
    root = Path(tmp)
    dist = root / "dist"
    (dist / "assets").mkdir(parents=True)
    (dist / "index.html").write_text("<!doctype html><title>SPA</title>")
    (dist / "assets" / "app.8f3a1c.js").write_text("console.log('v1');")
    (root / "secret.txt").write_text("top-secret")

    def spa_cache_policy(request: Request, response: Response) -> None:
        if request.url.path.startswith("/assets/"):
            response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
        else:
            response.headers["Cache-Control"] = "no-cache"

    spa_router = APIRouter(dependencies=[Depends(spa_cache_policy)])
    spa_router.frontend("/", directory=dist, fallback="index.html")

    app = FastAPI()

    @app.get("/api/status")
    async def api_status() -> dict[str, str]:
        return {"service": "healthy"}

    app.include_router(spa_router)
    client = TestClient(app)

    # API route wins even when browser sends Accept: text/html
    assert client.get("/api/status", headers={"accept": "text/html"}).json() == {
        "service": "healthy"
    }

    # Hashed bundle gets ETag + immutable Cache-Control
    asset = client.get("/assets/app.8f3a1c.js")
    assert "etag" in asset.headers
    assert asset.headers["cache-control"] == "public, max-age=31536000, immutable"

    # Dotted client route with Accept: text/html receives no-cache index.html
    nav = client.get("/users/jane.doe", headers={"accept": "text/html"})
    assert nav.status_code == 200 and nav.headers["cache-control"] == "no-cache"

    # Subresource miss (*/*), traversal (%2e%2e), and POST to asset are rejected
    assert client.get("/assets/missing.js", headers={"accept": "*/*"}).status_code == 404
    assert client.get("/%2e%2e/secret.txt").status_code == 404
    assert client.post("/assets/app.8f3a1c.js").status_code == 405
```

For the core `APIRoute` compilation model, return to [APIRouter, APIRoute & Handler Closure](apiroute_and_closures.md). To trace how `yield` dependencies interact with `fastapi_inner_astack`, continue to [Dependant DAG & solve_dependencies](../03_di_and_security_engine/dependant_and_solver.md), [Middleware Onion & Threadpool](../05_asgi_and_telemetry/middleware_and_concurrency.md), and [get_openapi(), $defs & Docs UI](../06_openapi_and_docs/openapi_synthesis_engine.md).
