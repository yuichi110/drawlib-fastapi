# ASGI Middleware & Threadpool

FastAPI `v0.162.2` orchestrates every HTTP request and WebSocket connection through a deterministic seven-layer ASGI middleware onion while routing `async def` coroutines onto the single-threaded AnyIO event loop and offloading plain `def` callables to a bounded worker threadpool.

```drawlib align=center code=hide file=asgi_middleware_onion.png caption="FastAPI v0.162.2 ASGI Middleware Onion: From OpenTelemetry Outer Span to Endpoint Execution"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.lines import line
from drawlib.shapes import rectangle
from drawlib.styles import Colors, Styles
from drawlib.text import text

setup(width=176, height=98)

text(
    (88.0, 93.0),
    "FastAPI v0.162.2 Seven-Layer ASGI Middleware Onion (Outer to Inner)",
    style=Styles.DarkBold.patch(text_size=13.0),
)

# 7 Concentric ASGI Layers (outermost L1 -> innermost L7 core)
layers = [
    (88.0, 45.0, 132.0, 80.0, Styles.Neutral.patch(line_style="dashed", shape_r=2.5),
     81.0, "1. OpenTelemetry Outer Span  •  W3C Context, Root Span & Metrics", Styles.DarkBold),
    (88.0, 42.2, 122.0, 69.0, Styles.White.patch(shape_r=2.2, shape_line_color=Colors.Gray5),
     72.5, "2. Unhandled 500 Boundary  •  @app.exception_handler(500) Fallback", Styles.DarkBold),
    (88.0, 39.4, 112.0, 58.0, Styles.PrimaryNeutral.patch(shape_r=2.0),
     64.0, "3. Inner Exception Span Recorder  •  OTel Error Log Before 500", Styles.PrimaryBold),
    (88.0, 36.6, 102.0, 47.0, Styles.SecondaryNeutral.patch(shape_r=2.0),
     55.5, "4. User Middleware (LIFO)  •  TrustedHost, CORS & Pure ASGI Wrappers", Styles.SecondaryBold),
    (88.0, 33.8, 92.0, 36.0, Styles.White.patch(shape_r=1.8, shape_line_color=Colors.Gray5),
     47.0, "5. Handled Error Boundary  •  HTTPException, 422 & Custom", Styles.DarkBold),
    (88.0, 31.0, 82.0, 25.0, Styles.PrimaryNeutral.patch(shape_r=1.8),
     38.5, "6. Request Resource Cleanup  •  Closes Form & UploadFile", Styles.PrimaryBold),
]

for cx, cy, w, h, box_style, label_y, label, txt_style in layers:
    rectangle((cx, cy), width=w, height=h, style=box_style)
    text((cx, label_y), label, style=txt_style.patch(text_size=10.2))

# Core Layer 7: Routing & Endpoint Execution
rectangle((88.0, 26.5), width=66.0, height=13.0, style=Styles.PrimaryFlat.patch(shape_r=1.8))
phosphor.cpu((60.0, 26.5), width=5.2, style=Styles.WhiteBold)
text(
    (91.0, 26.5),
    "7. Router & Endpoint\nDepends() • Endpoint • Validation",
    style=Styles.WhiteBold.patch(text_size=10.5),
)

# Inbound ASGI Request & Outbound ASGI Response arrows piercing into the core
line((3.5, 26.5), (54.5, 26.5), arrow_head="->", style=Styles.PrimaryBold.patch(line_width=2.0))
rectangle((21.0, 34.0), width=33.0, height=9.0, style=Styles.White.patch(shape_r=1.5, shape_line_color=Colors.Gray5))
text((21.0, 34.0), "Inbound ASGI\nscope + receive()", style=Styles.DarkBold.patch(text_size=10.0))

line((121.5, 26.5), (172.5, 26.5), arrow_head="->", style=Styles.SecondaryBold.patch(line_width=2.0))
rectangle((155.0, 34.0), width=33.0, height=9.0, style=Styles.White.patch(shape_r=1.5, shape_line_color=Colors.Gray5))
text((155.0, 34.0), "Outbound ASGI\nsend(start / body)", style=Styles.DarkBold.patch(text_size=10.0))

save()
```

## 1. The Seven-Layer ASGI Middleware Onion

When an ASGI server such as Uvicorn processes an incoming HTTP request or WebSocket handshake, FastAPI passes it through a deterministic seven-layer ASGI middleware pipeline. Understanding the exact nesting order prevents subtle bugs around CORS headers on `500` responses, OpenTelemetry error correlation, and `contextvars` propagation:

| Layer (Outer to Inner) | Public Surface / Mechanism | Core Responsibility in `v0.162.2` |
| :--- | :--- | :--- |
| **1. OpenTelemetry Outer Span** | `FastAPI(telemetry=...)` | Extracts W3C `traceparent`/`baggage`, starts the root HTTP/WebSocket span, tracks active requests, and populates request telemetry context (`get_telemetry_data()`). |
| **2. Unhandled 500 Boundary** | `@app.exception_handler(500)` / `Exception` | Invokes custom `500` handlers and guarantees a safe `500 Internal Server Error` fallback if an unexpected error escapes inner layers. |
| **3. Inner Exception Span Recorder** | `TelemetryConfig` (`logs=True`) | Records unhandled exceptions on the active span and emits structured OTel `ERROR` logs *before* the outer `500` boundary turns them into an HTTP response. |
| **4. User Middleware Stack** | `app.add_middleware(...)` / `@app.middleware("http")` | Runs application middlewares (`CORSMiddleware`, `TrustedHostMiddleware`, `GZipMiddleware`, pure ASGI classes) in **LIFO order** (last added wraps outermost). |
| **5. Handled Error Boundary** | `@app.exception_handler(...)` | Catches `HTTPException`, `RequestValidationError` (`422`), `WebSocketRequestValidationError` (`1008`), and custom domain exception handlers. |
| **6. Request Resource Cleanup** | `Form` & `UploadFile` lifecycle | Manages temporary multipart file handles *inside* all user middlewares so resources close cleanly within the same `contextvars` scope. |
| **7. Router & Endpoint Execution** | `APIRouter` / `Depends()` | Parses bodies, resolves [Dependency Injection](../04_dependencies_and_security/dependency_injection.md) (with request-scope cleanup after streaming), executes the endpoint, validates responses, and schedules `BackgroundTasks`. |

### Pure ASGI Middleware vs `BaseHTTPMiddleware`

Using `@app.middleware("http")` (which wraps Starlette's `BaseHTTPMiddleware`) spawns an extra AnyIO task group per request, copies `contextvars` boundaries, and can add overhead to high-throughput [SSE or JSONL streams](sse_websockets_streaming.md). For production cross-cutting concerns—request timing, correlation IDs, tenant enforcement, or security headers—implement a **pure ASGI middleware** class that intercepts `http.response.start` directly with zero body buffering:

```python
from time import perf_counter

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.testclient import TestClient
from starlette.types import ASGIApp, Message, Receive, Scope, Send


class ProcessTimeMiddleware:
    """Zero-buffering pure ASGI middleware that injects X-Process-Time-Ms."""

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        started = perf_counter()

        async def send_with_timing(message: Message) -> None:
            if message["type"] == "http.response.start":
                elapsed_ms = (perf_counter() - started) * 1000.0
                raw_headers = list(message.get("headers", []))
                raw_headers.append(
                    (b"x-process-time-ms", f"{elapsed_ms:.2f}".encode("latin-1"))
                )
                message = {**message, "headers": raw_headers}
            await send(message)

        await self.app(scope, receive, send_with_timing)


app = FastAPI()

# LIFO wrapping order: TrustedHost (outer) -> CORS -> ProcessTime (inner)
app.add_middleware(ProcessTimeMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://app.example.com"],
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type"],
)
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["api.example.com", "testserver"],
)


@app.get("/ping")
async def ping() -> dict[str, str]:
    return {"status": "ok"}


client = TestClient(app)
res = client.get("/ping", headers={"Origin": "https://app.example.com"})
assert res.status_code == 200
assert "x-process-time-ms" in res.headers
```

> **CORS on Unhandled 500s**: Because the unhandled `500` boundary (Layer 2) wraps *outside* user middlewares added via `app.add_middleware(...)` (Layer 4), an unhandled `500` response generated at Layer 2 bypasses `CORSMiddleware` unless you register a custom `@app.exception_handler(Exception)` or ensure reverse-proxy error responses include explicit origin policies. Never set `allow_origins=["*"]` on authenticated APIs.

---

## 2. Event Loop vs Worker Threadpool & `BackgroundTasks`

FastAPI inspects every endpoint and dependency signature at route registration time to choose between direct event-loop execution (`async def`) and AnyIO worker threadpool offloading (`def`):

```drawlib align=center code=hide file=event_loop_vs_threadpool.png caption="Execution Routing: Single-Threaded Event Loop vs AnyIO Worker Threadpool & BackgroundTasks"
from drawlib.canvas import save, setup
from drawlib.diagrams.flow import Decision, End, FlowDiagram, Process, Start
from drawlib.styles import Styles
from drawlib.text import text

setup(width=166, height=94)

text(
    (83.0, 89.5),
    "FastAPI Concurrency Routing: async def vs plain def & BackgroundTasks",
    style=Styles.DarkBold.patch(text_size=13.0),
)

node_txt = Styles.DarkBold.patch(text_size=10.2)

flow = FlowDiagram(
    node_style=Styles.Neutral.patch(text_size=10.2),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.DarkBold.patch(text_size=10.0),
    width=158,
    height=80,
    lane_orientation="vertical",
)

# 3 Vertical Swimlanes: widths 54 + 54 + 50 = 158 (centerlines X = 27, 81, 133)
flow.add_lane(
    "AnyIO Event Loop (1 Thread)",
    width=54,
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral,
    text_style=Styles.PrimaryBold.patch(text_size=10.5),
    header_size=7.0,
)
flow.add_lane(
    "Worker Threadpool (40 Tokens)",
    width=54,
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.SecondaryBold.patch(text_size=10.5),
    header_size=7.0,
)
flow.add_lane(
    "Post-Response Lifecycle",
    width=50,
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral,
    text_style=Styles.PrimaryBold.patch(text_size=10.5),
    header_size=7.0,
)

start = flow.add(
    Start("Incoming ASGI Request", width=38, height=8.5, style=Styles.PrimaryFlat, text_style=Styles.WhiteBold.patch(text_size=10.2)),
    xy=(27, 66),
)
dispatch = flow.add(
    Decision("Callable\nSignature?", width=34, height=13.5, style=Styles.PrimaryNeutral, text_style=node_txt),
    xy=(27, 49),
)
async_exec = flow.add(
    Process("Await Coroutine Directly\n(Non-Blocking Async I/O)", width=44, height=11.5, style=Styles.White, text_style=node_txt),
    xy=(27, 30.5),
)
pool_enter = flow.add(
    Process("Worker Threadpool Execution\n(Sync def & yield Deps)", width=43, height=11.5, style=Styles.SecondaryNeutral, text_style=node_txt),
    xy=(81, 49),
)
sync_exec = flow.add(
    Process("Run Sync DB Driver /\nBlocking File or CPU Helper", width=43, height=11.5, style=Styles.White, text_style=node_txt),
    xy=(81, 30.5),
)
merge = flow.junction((27, 19.5))
send_resp = flow.add(
    Process("Validate & Send Response\n(HTTP Response Complete)", width=44, height=11.0, style=Styles.PrimaryNeutral, text_style=node_txt),
    xy=(27, 9.5),
)
bg_tasks = flow.add(
    Process("Run BackgroundTasks\n(Traced Sequentially)", width=41, height=11.5, style=Styles.White, text_style=node_txt),
    xy=(133, 30.5),
)
done = flow.add(
    End("ASGI Scope Closed", width=36, height=9.0, style=Styles.SecondaryFlat, text_style=Styles.WhiteBold.patch(text_size=10.2)),
    xy=(133, 9.5),
)

start.connect(dispatch, padding=0.8)
dispatch.connect(async_exec, label="async def", start_side="bottom", end_side="top", padding=0.8)
dispatch.connect(pool_enter, label="plain def", start_side="right", end_side="left", padding=0.8)
pool_enter.connect(sync_exec, padding=0.8)
async_exec.connect(merge, start_side="bottom", padding=(0.8, 0.0))
sync_exec.connect(merge, start_side="bottom", padding=(0.8, 0.0)).via((81, 19.5))
merge.connect(send_resp, end_side="top", padding=(0.0, 0.8))
send_resp.connect(bg_tasks, label="After send()", start_side="right", end_side="left", padding=0.8).via((106.5, 9.5), (106.5, 30.5))
bg_tasks.connect(done, padding=0.8)

flow.draw(xy=(4.0, 4.0))
save()
```

### Golden Rules of Concurrency in FastAPI

1. **`async def` Runs Directly on the Event Loop**: Use `async def` whenever calling `await`-native drivers (`httpx.AsyncClient`, `asyncpg`, `redis.asyncio`, `anyio`). **Never call blocking synchronous functions** (`time.sleep()`, `requests.get()`, synchronous ORM queries, or heavy CPU loops) directly inside `async def`—doing so stalls the entire worker loop and freezes every concurrent request on that process.
2. **Plain `def` & Sync `yield` Dependencies Use the Threadpool**: Declaring a plain `def` route or synchronous `yield` dependency tells FastAPI to run both setup and teardown on the worker threadpool, governed by AnyIO's default `40`-token `CapacityLimiter` per worker process. If an `async def` endpoint must invoke one synchronous helper, offload just that call via `await run_in_threadpool(fn, *args)`.
3. **`BackgroundTasks` Runs In-Process After `send()`**: Tasks added to `BackgroundTasks` execute sequentially *after* the client receives the HTTP response, wrapped in `fastapi.background_task` [OpenTelemetry spans](../06_observability_and_testing/telemetry_and_errors.md). Reserve `BackgroundTasks` for lightweight, best-effort work (audit events, cache invalidation, webhook notifications); use an external durable job queue for retries, multi-minute workflows, or heavy CPU processing.

```python
from collections.abc import Iterator
from typing import Annotated

import anyio
from fastapi import BackgroundTasks, Depends, FastAPI, status
from fastapi.testclient import TestClient
from starlette.concurrency import run_in_threadpool

app = FastAPI()
audit_log: list[str] = []


def compute_digest_sync(payload: str) -> str:
    return f"len:{len(payload)}"


def get_sync_session() -> Iterator[str]:
    # Entered & exited safely on the worker threadpool
    audit_log.append("session:open")
    try:
        yield "tx-101"
    finally:
        audit_log.append("session:close")


@app.get("/reports/sync")
def read_sync_report(
    tx_id: Annotated[str, Depends(get_sync_session)],
) -> dict[str, str]:
    return {"tx_id": tx_id, "summary": compute_digest_sync("quarterly-ledger")}


@app.post("/reports/async", status_code=status.HTTP_202_ACCEPTED)
async def submit_async_report(
    payload: str,
    tasks: BackgroundTasks,
) -> dict[str, str]:
    digest = await run_in_threadpool(compute_digest_sync, payload)
    await anyio.sleep(0)
    tasks.add_task(audit_log.append, f"audit:{digest}")
    return {"accepted": digest}


client = TestClient(app)
assert client.get("/reports/sync").json() == {"tx_id": "tx-101", "summary": "len:16"}
assert client.post("/reports/async", params={"payload": "hello"}).status_code == 202
assert audit_log == ["session:open", "session:close", "audit:len:5"]
```

Continue to [Native SSE, JSONL & WebSockets](sse_websockets_streaming.md) to explore how FastAPI extends this async execution engine to real-time server push and full-duplex streams.
