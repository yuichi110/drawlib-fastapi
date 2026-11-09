# Middleware Onion & AnyIO Threadpool Concurrency

Every HTTP request, WebSocket session, and ASGI lifespan event entering a `FastAPI` instance passes through `FastAPI.__call__` in `fastapi/applications.py`. Rather than rebuilding wrapper closures on every request, FastAPI lazily compiles a deterministic 7-layer ASGI middleware onion once on the first HTTP or WebSocket call, separating outer crash recovery (`500`) from inner application exception handling (`4xx` / `422`) and offloading synchronous callables onto AnyIO worker threads.

```drawlib align=center code=hide file=seven_layer_asgi_stack.png caption="The 7-Layer ASGI Middleware Onion Compiled by FastAPI.__call__ and build_middleware_stack()"
from drawlib.canvas import setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Colors, Styles

setup(width=176, height=94)

left_panel = Panel(
    "7-Layer ASGI Stack",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.5),
    icon=phosphor.stack,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.5,
)
left_panel.draw((4.0, 4.0), width=92.0, height=86.0)
l_xy, l_w, l_h = left_panel.get_content_box(
    (4.0, 4.0), width=92.0, height=86.0, padding=(3.5, 2.8)
)

onion_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.DarkBold,
    spacing=1.5,
)
onion_cards.add(
    "NativeTelemetry (FastAPI.__call__)",
    "Starts SERVER span, W3C context & HTTP metrics",
    badge_text="L1",
    icon=phosphor.pulse,
    style=Styles.PrimaryNeutral,
)
onion_cards.add(
    "ServerErrorMiddleware",
    "Outermost 500 safety net & Exception handler",
    badge_text="L2",
    icon=phosphor.shield_warning,
)
onion_cards.add(
    "ExceptionTelemetryMiddleware",
    "Records unhandled error.type before 500 body",
    badge_text="L3",
    icon=phosphor.bug,
    style=Styles.SecondaryNeutral,
)
onion_cards.add(
    "self.user_middleware (LIFO)",
    "Reverse add_middleware() registration order",
    badge_text="L4",
    icon=phosphor.arrows_down_up,
)
onion_cards.add(
    "ExceptionMiddleware",
    "Converts HTTPException & 422 into JSONResponse",
    badge_text="L5",
    icon=phosphor.funnel,
)
onion_cards.add(
    "AsyncExitStackMiddleware",
    "Pushes FormData & UploadFile close callbacks",
    badge_text="L6",
    icon=phosphor.folder_open,
    style=Styles.SecondaryNeutral,
)
onion_cards.add(
    "APIRouter -> APIRoute",
    "Matches route, updates span & runs closure",
    badge_text="L7",
    icon=phosphor.git_branch,
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
    badge_style=Styles.White,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
)
onion_cards.draw(l_xy, width=l_w, height=l_h)

right_panel = Panel(
    "Boundary & Scope Rules",
    style=Styles.PrimaryNeutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.5),
    icon=phosphor.scales,
    icon_style=Styles.White,
    header_variant="filled",
    header_height=8.5,
)
right_panel.draw((100.0, 4.0), width=72.0, height=86.0)
r_xy, r_w, r_h = right_panel.get_content_box(
    (100.0, 4.0), width=72.0, height=86.0, padding=(3.5, 3.0)
)

rule_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    spacing=2.5,
)
rule_cards.add(
    "Lazy Build Once",
    "middleware_stack stays None until 1st call",
    badge_text="Init",
    icon=phosphor.lightning,
)
rule_cards.add(
    "Outer 500 Guard",
    "Catches crashes raised in user_middleware",
    badge_text="L2",
    icon=phosphor.warning_octagon,
)
rule_cards.add(
    "Inner 4xx/422 Guard",
    "CORS & GZip wrap 4xx/422 JSON responses",
    badge_text="L5",
    icon=phosphor.check_circle,
)
rule_cards.add(
    "3 AsyncExitStacks",
    "Middleware file + request & function scopes",
    badge_text="Ctx",
    icon=phosphor.stack_simple,
)
rule_cards.draw(r_xy, width=r_w, height=r_h)
```

---

## 1. `FastAPI.__call__` Entry Dispatch and Lazy Stack Compilation

`FastAPI` inherits from `starlette.applications.Starlette`, initializing `self.middleware_stack: ASGIApp | None = None` during `__init__()`. Deferring compilation until the first inbound request allows applications to call `app.add_middleware()`, `@app.middleware("http")`, and `@app.exception_handler()` in any order during startup without repeatedly rebuilding wrapper chains.

When `await app(scope, receive, send)` executes in `fastapi/applications.py`, it branches across three execution paths:

1. **Lifespan Interception (`scope["type"] == "lifespan"`)**: Delegates to `fastapi.telemetry._runtime.lifespan(config=self._telemetry, app=super().__call__, ...)` so optional OTLP auto-configuration runs on `lifespan.startup` and owned exporters flush on `lifespan.shutdown.complete`.
2. **Untraced Fast Path**: If `scope["type"]` is neither `"http"` nor `"websocket"`, if `"fastapi.telemetry"` is already present in `scope` (such as a mounted sub-application), or if `self._native_telemetry.enabled()` returns `False`, FastAPI awaits `super().__call__(scope, receive, send)` directly. `Starlette.__call__` then sets `scope["app"] = self`, lazily builds `self.middleware_stack = self.build_middleware_stack()` if `None`, and invokes `await self.middleware_stack(scope, receive, send)`.
3. **Instrumented HTTP/WebSocket Path**: When `self._native_telemetry.enabled()` is `True`, `FastAPI.__call__` ensures `self.middleware_stack` is built, checks `_legacy_otel(self.middleware_stack)` to detect `opentelemetry.instrumentation.asgi.OpenTelemetryMiddleware`, and wraps `super().__call__` inside `await self._native_telemetry(...)`.

---

## 2. Anatomy of `build_middleware_stack()` (Outer to Inner)

`FastAPI.build_middleware_stack()` overrides Starlette's builder to inject `ExceptionTelemetryMiddleware` and `AsyncExitStackMiddleware` around `self.user_middleware`. It first partitions `self.exception_handlers`: keys `500` and `Exception` become `error_handler` for `ServerErrorMiddleware`, while all specific exception classes and status codes populate `exception_handlers` for `ExceptionMiddleware`. It then folds the `middleware` list in reverse around `self.router`:

| Layer | Class & Module | Scope / State Key | Primary Responsibility |
| :--- | :--- | :--- | :--- |
| **L1** | `NativeTelemetry` (`fastapi.telemetry._asgi`) | `scope["fastapi.telemetry"]` | Wraps `super().__call__` in `FastAPI.__call__`; extracts W3C context, starts `SERVER` span, and records duration/active metrics. |
| **L2** | `ServerErrorMiddleware` (`starlette.middleware.errors`) | — | Outermost `middleware_stack` layer; catches unhandled `Exception`s, runs `500`/`Exception` handler or debug traceback, sends `500`, and re-raises. |
| **L3** | `ExceptionTelemetryMiddleware` (`fastapi.telemetry._asgi`) | `_RequestTelemetry._exceptions` | Observes unhandled exceptions escaping `L4`–`L7` *before* `L2` sends the `500` response body and closes the root span. |
| **L4** | `self.user_middleware` (`starlette.middleware`) | User-defined | Custom middlewares in reverse registration (LIFO) order: `add_middleware()` calls `self.user_middleware.insert(0, ...)`. |
| **L5** | `ExceptionMiddleware` (`starlette.middleware.exceptions`) | — | Catches `HTTPException`, `RequestValidationError` (`422`), `WebSocketRequestValidationError` (`1008`), and custom typed handlers. |
| **L6** | `AsyncExitStackMiddleware` (`fastapi.middleware.asyncexitstack`) | `scope["fastapi_middleware_astack"]` | Opens an `AsyncExitStack` primarily to close `FormData` and `UploadFile` handles after response streaming finishes. |
| **L7** | `APIRouter` (`fastapi.routing`) | `scope["router"]`, `scope["route"]` | Matches `APIRoute` / `Mount` / frontend routes, calls `_route_selected()`, and enters `request_response()`. |

### Why `ServerErrorMiddleware` Wraps Outside `user_middleware` While `ExceptionMiddleware` Wraps Inside

Splitting error handling across **L2** (outside `self.user_middleware`) and **L5** (inside `self.user_middleware`) solves two opposing ASGI requirements:

- **Protecting the Server from Middleware Crashes (L2 Outside L4)**: User middlewares execute arbitrary code before and after routing (parsing auth headers, opening Redis sessions, mutating responses). If a user middleware raises an unhandled `RuntimeError`, **L5** (`ExceptionMiddleware`) has already exited or was never reached. Placing `ServerErrorMiddleware` at **L2** guarantees that crashes inside user middleware still produce a valid HTTP `500 Internal Server Error` response—and placing `ExceptionTelemetryMiddleware` at **L3** ensures `error.type` is captured before `ServerErrorMiddleware` sends that `500` body.
- **Preserving Middleware Headers on Handled HTTP Errors (L5 Inside L4)**: Expected application errors such as `HTTPException(status_code=401)` or `RequestValidationError` (`422` via `fastapi/exception_handlers.py`) are caught at **L5** (and inside `request_response()` via Starlette's `wrap_app_handling_exceptions`) and converted into normal `JSONResponse` objects *before* unwinding through **L4**. As a result, outer middlewares like `CORSMiddleware`, `GZipMiddleware`, or custom timing middlewares see a standard HTTP response and properly attach `Access-Control-Allow-Origin` headers to `401` and `422` responses instead of aborting on an uncaught exception.

### The Three Scoped `AsyncExitStack` Instances

FastAPI separates resource cleanup across three nested `AsyncExitStack` scopes rather than closing everything in **L6**:

1. **`scope["fastapi_middleware_astack"]` (L6 — `AsyncExitStackMiddleware`)**: Entered inside all user middlewares (preserving the inner `contextvars` task context created by `BaseHTTPMiddleware`) and exited after the full response completes. `get_request_handler()` registers `file_stack.push_async_callback(body.close)` here so uploaded `SpooledTemporaryFile` handles remain open throughout streaming responses.
2. **`scope["fastapi_function_astack"]` (L7 — `request_response()`)**: Exits *before* `await response(scope, receive, send)` begins, tearing down `Depends(..., scope="function")` `yield` dependencies prior to response streaming while still letting `yield` blocks catch or raise `HTTPException`.
3. **`scope["fastapi_inner_astack"]` (L7 — `request_response()`)**: Wraps `await response(scope, receive, send)`, keeping `Depends(..., scope="request")` `yield` dependencies (such as database sessions consumed by streaming generators) alive until the last response byte is sent.

---

## 3. AnyIO Threadpool Offloading and `contextvars` Semantics

FastAPI runs on an asynchronous event loop, where any blocking CPU or synchronous I/O call would stall all concurrent connections on the worker process. To support both `async def` and plain `def` functions safely, FastAPI pairs compile-time coroutine detection with AnyIO worker-thread offloading.

```drawlib align=center code=hide file=anyio_threadpool_contextvars.png caption="AnyIO Worker Thread Offloading, CapacityLimiter(1) Teardown, and contextvars Propagation"
from drawlib.canvas import setup
from drawlib.diagrams.sequence import (
    Participant,
    ParticipantGroup,
    PhosphorIcon,
    SequenceDiagram,
)
from drawlib.styles import Colors, Styles

d = SequenceDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.0),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
    autonumber=True,
    col_width=44.0,
    step_y=7.4,
)

loop_p = d.add(
    Participant(
        "Event Loop\n(AsyncIO)",
        width=28,
        height=15,
        icon=PhosphorIcon.LIGHTNING,
        icon_size=6.0,
        card_style=Styles.PrimaryNeutral,
    )
)

pool_grp = d.add(
    ParticipantGroup(
        title="AnyIO Threadpool",
        padding=4.5,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=10.5, halign="left"),
    )
)
default_pool = pool_grp.add(
    Participant(
        "Default Limiter\n(40 Tokens)",
        width=28,
        height=15,
        icon=PhosphorIcon.CPU,
        icon_size=6.0,
        card_style=Styles.Neutral,
    )
)
exit_pool = pool_grp.add(
    Participant(
        "exit_limiter\nCapacityLimiter(1)",
        width=30,
        height=15,
        icon=PhosphorIcon.LOCK_KEY_OPEN,
        icon_size=6.0,
        card_style=Styles.SecondaryNeutral,
    )
)

worker_fn = d.add(
    Participant(
        "Yield Dep &\nEndpoint Callable",
        width=30,
        height=15,
        icon=PhosphorIcon.CODE,
        icon_size=6.0,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
        card_style=Styles.PrimaryFlat,
    )
)

loop_p.request(default_pool, "run_in_threadpool(cm.__enter__)")
default_pool.request(worker_fn, "Enter sync yield dep (copied ContextVar)")
worker_fn.reply(loop_p, "Yielded resource")

with d.alt("async def") as alt_blk:
    alt_blk.style = Styles.Neutral.patch(line_style="dashed")
    alt_blk.text_style = Styles.DarkBold.patch(text_size=10.0)
    loop_p.request(worker_fn, "Direct await dependant.call(**values) on loop")
    worker_fn.reply(loop_p, "Coroutine result (zero thread hop)")

    d.else_("sync def")
    loop_p.request(default_pool, "run_in_threadpool(_run_sync_endpoint)")
    default_pool.request(worker_fn, "Run sync endpoint (copied ContextVar)")
    worker_fn.reply(loop_p, "Endpoint return value")

loop_p.request(exit_pool, "run_sync(cm.__exit__, limiter=exit_limiter)")
exit_pool.request(worker_fn, "Teardown bypasses 40-token pool")
worker_fn.reply(loop_p, "Resource released without deadlock")

diag_w, diag_h = d.get_size()
setup(width=int(diag_w) + 12, height=int(diag_h) + 12)
d.draw(xy=(6.0, 6.0))
```

### `run_endpoint_function()` (`is_coroutine` vs `run_in_threadpool`)

When `get_request_handler()` in `fastapi/routing.py` compiles a route closure, it inspects the endpoint once via `is_coroutine = _is_coroutine_callable(dependant.call)` (which unwraps `functools.partial` and callable instances via `fastapi/dependencies/models.py`). At request time, `run_endpoint_function()` dispatches based on that precomputed flag:

- **`is_coroutine == True` (`async def`)**: Executes directly on the event loop via `await dependant.call(**values)` inside `with _operation(name="endpoint", function=dependant.call):`, avoiding any thread switch or context-copy cost.
- **`is_coroutine == False` (`def`)**: Offloads execution via Starlette's `await run_in_threadpool(_run_sync_endpoint, function=dependant.call, arguments=values)`, which delegates to `anyio.to_thread.run_sync` using AnyIO's default 40-thread `CapacityLimiter`. Notice that `_run_sync_endpoint` opens `_operation(name="endpoint", ...)` *inside* the worker thread so the child OpenTelemetry span remains active for the exact synchronous call duration.

The same discipline governs `solve_dependencies()` (calling sync sub-dependencies via `run_in_threadpool`) and `serialize_response()` (validating response models via `run_in_threadpool` when `is_coroutine=False`).

### `contextmanager_in_threadpool()` and `CapacityLimiter(1)` Deadlock Prevention

Synchronous generator dependencies (`def get_db(): ... yield db ...`) cannot be iterated directly on the event loop without risking blocking I/O in both setup and teardown. In `fastapi/dependencies/utils.py`, `_solve_generator()` wraps sync generators with `contextlib.contextmanager` and passes them to `contextmanager_in_threadpool()` in `fastapi/concurrency.py`:

- **Setup (`__enter__`)**: Runs `yield await run_in_threadpool(cm.__enter__)` against AnyIO's shared default thread limiter (40 tokens).
- **Teardown (`__exit__`)**: Allocates a dedicated per-call `exit_limiter = CapacityLimiter(1)` and runs `await anyio.to_thread.run_sync(cm.__exit__, ..., limiter=exit_limiter)` in both the `except Exception as e:` branch (propagating `cm.__exit__`'s boolean exception-suppression result) and the `else:` branch.

Why allocate a fresh `CapacityLimiter(1)` for `__exit__`? Consider a database pool capped at 10 connections under a burst of 50 requests: 10 requests acquire DB sessions, while 40 concurrent worker threads block inside `cm.__enter__` waiting for a free DB connection—exhausting all 40 tokens of AnyIO's default threadpool limiter. When the first active request finishes and attempts to return its DB connection in `cm.__exit__`, waiting on the default limiter would deadlock forever: `cm.__enter__` threads wait for `cm.__exit__` to release a DB connection, while `cm.__exit__` waits for a `cm.__enter__` thread to free an AnyIO token. Passing `limiter=exit_limiter` lets `__exit__` run immediately without contending on the saturated default pool.

### How `contextvars` Copy Into Worker Threads

Both `starlette.concurrency.run_in_threadpool` and `anyio.to_thread.run_sync` capture the calling task's `contextvars.Context` via `contextvars.copy_context()` on the event loop and invoke `context.run(...)` inside the worker thread:

- **Downstream Visibility**: Any `ContextVar` populated by an `async` middleware or `async` dependency (including FastAPI's `_REQUEST_TELEMETRY_KEY` OpenTelemetry context) is automatically visible inside sync `def` `yield` dependencies and sync `def` endpoints.
- **Snapshot Isolation Caveat**: Because `copy_context()` creates a *shallow copy* for each `run_sync` hop, calling `my_var.set("new")` inside a synchronous `def` dependency mutates only that worker call's copied `Context`; the mutation does not propagate back to the event loop, to subsequent sync endpoints, or even from `cm.__enter__` to `cm.__exit__` (which execute in two separate `run_sync` invocations). Mutate `ContextVar` tokens in `async` middlewares or `async def` `yield` dependencies when cross-stage visibility is required.

---

## 4. Verifying the 7-Layer Stack and `ContextVar` Propagation

The snippet below inspects a live `FastAPI()` instance before and after serving a request, verifying lazy `middleware_stack` compilation, the exact outer-to-inner middleware chain down to `APIRouter`, and `ContextVar` propagation into worker threads:

```python
from contextvars import ContextVar
import threading

from fastapi import Depends, FastAPI
from fastapi.telemetry._asgi import NativeTelemetry
from fastapi.testclient import TestClient
from starlette.types import ASGIApp, Receive, Scope, Send

request_id_var: ContextVar[str] = ContextVar("request_id", default="unset")


class FirstUserMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        token = request_id_var.set("req-42")
        try:
            await self.app(scope, receive, send)
        finally:
            request_id_var.reset(token)


class SecondUserMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        await self.app(scope, receive, send)


app = FastAPI()
app.add_middleware(FirstUserMiddleware)
app.add_middleware(SecondUserMiddleware)


def sync_yield_dep():
    yield {
        "dep_thread": threading.current_thread().name,
        "dep_ctx": request_id_var.get(),
    }


@app.get("/threads")
def read_threads(dep: dict[str, str] = Depends(sync_yield_dep)) -> dict[str, str]:
    return {
        **dep,
        "ep_thread": threading.current_thread().name,
        "ep_ctx": request_id_var.get(),
    }


# 1. Lazy compilation: middleware_stack is None until the first HTTP/WS call
assert app.middleware_stack is None
assert isinstance(app._native_telemetry, NativeTelemetry)

with TestClient(app) as client:
    payload = client.get("/threads").json()
    assert payload["dep_ctx"] == "req-42"
    assert payload["ep_ctx"] == "req-42"
    assert payload["dep_thread"] != threading.main_thread().name

# 2. Walk app.middleware_stack from outermost wrapper to innermost APIRouter
layers: list[str] = []
cursor: object | None = app.middleware_stack
while cursor is not None:
    layers.append(type(cursor).__name__)
    if cursor is app.router:
        break
    cursor = getattr(cursor, "app", None)

assert layers == [
    "ServerErrorMiddleware",
    "ExceptionTelemetryMiddleware",
    "SecondUserMiddleware",
    "FirstUserMiddleware",
    "ExceptionMiddleware",
    "AsyncExitStackMiddleware",
    "APIRouter",
]
```

Next, see [NativeTelemetry & Runtime Spans](native_telemetry_internals.md) for a source-level walkthrough of how Layer 1 (`NativeTelemetry`) and Layer 3 (`ExceptionTelemetryMiddleware`) coordinate spans, metrics, and error logs.
