# Custom Request & APIRoute Classes

Subclassing `APIRoute.get_route_handler()` and Starlette's `Request` lets you intercept requests **after** router matching yet **before** FastAPI decodes JSON or runs Pydantic validation—enabling router-scoped `gzip` decompression, raw-byte HMAC verification, per-operation latency headers, and structured `422` validation error wrapping.

```drawlib align=center code=hide file=custom_apiroute_interception.png caption="Interception Boundary Comparison: Global ASGI Middleware vs Router-Scoped APIRoute.get_route_handler()"
from drawlib.canvas import save, setup
from drawlib.icons import code, phosphor
from drawlib.lines import line
from drawlib.shapes import rectangle
from drawlib.smartarts import Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=174, height=96, dpi=150)

# Title Banner
code.fastapi((10.5, 90.5), width=5.2, style=Styles.Primary)
text(
    (16.0, 90.5),
    "Interception Architecture: Global ASGI Middleware vs Router-Scoped Custom APIRoute",
    style=Styles.DarkBold.patch(text_size=12.2, halign="left"),
)

# Lane A: Global ASGI Middleware (Pre-Routing)
p_asgi = Panel(
    "A. Global ASGI Middleware — Pre-Routing Transport Layer",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.globe,
    icon_style=Styles.DarkBold,
    header_height=8.0,
)
p_asgi.draw((5, 49), width=164, height=35)

asgi_steps = [
    (24.5, "1. Every Request", "Static files, /healthz\n& unmatched 404 scans", Styles.White, False),
    (64.5, "2. ASGI Middleware", "Raw (scope, receive)\nNo matched route yet", Styles.White, False),
    (104.5, "3. Router Scan", "Starlette iterates all\nMount & APIRoute rules", Styles.White, False),
    (144.5, "4. Scope Tradeoff", "Global cost; cannot wrap\none router's 422 errors", Styles.SecondaryNeutral, False),
]
for idx, (cx, st_title, st_sub, st_fill, _) in enumerate(asgi_steps):
    rectangle((cx, 62.5), width=33, height=16.0, style=st_fill.patch(shape_r=1.8))
    text((cx, 65.5), st_title, style=Styles.DarkBold.patch(text_size=10.4))
    text((cx, 60.0), st_sub, style=Styles.Dark.patch(text_size=10.0))
    if idx < len(asgi_steps) - 1:
        line((cx + 16.5, 62.5), (asgi_steps[idx + 1][0] - 16.5, 62.5), arrow_head="->", style=Styles.DarkBold)

# Lane B: APIRouter(route_class=CustomRoute) (Post-Match, Pre-Validation)
p_route = Panel(
    "B. APIRouter(route_class=CustomRoute) — Post-Match, Pre-Validation Hook",
    style=Styles.Neutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.0),
    icon=phosphor.git_branch,
    icon_style=Styles.White,
    header_height=8.0,
)
p_route.draw((5, 6), width=164, height=38)

route_steps = [
    (24.5, "1. Matched Route", "Fires ONLY on target\nAPIRouter endpoints", Styles.PrimaryNeutral, False),
    (64.5, "2. Custom Handler", "Swaps GzipRequest &\nverifies raw body HMAC", Styles.PrimaryFlat, True),
    (104.5, "3. original_handler", "Built-in route handler\nJSON + Depends + Model", Styles.White, False),
    (144.5, "4. 422 & Latency", "Catches ValidationError\n& sets X-Response-Time", Styles.SecondaryNeutral, False),
]
for idx, (cx, rt_title, rt_sub, rt_fill, is_focal) in enumerate(route_steps):
    rectangle((cx, 21.0), width=33, height=18.5, style=rt_fill.patch(shape_r=1.8))
    t_h = Styles.WhiteBold if is_focal else Styles.DarkBold
    t_b = Styles.White if is_focal else Styles.Dark
    text((cx, 24.4), rt_title, style=t_h.patch(text_size=10.4))
    text((cx, 18.2), rt_sub, style=t_b.patch(text_size=10.0))
    if idx < len(route_steps) - 1:
        arr_st = Styles.PrimaryBold if idx in (0, 1) else Styles.DarkBold
        line((cx + 16.5, 21.0), (route_steps[idx + 1][0] - 16.5, 21.0), arrow_head="->", style=arr_st)

save()
```

Choosing the right extension hook in FastAPI depends on **when** during the ASGI lifecycle your logic must execute and **how broadly** it should apply across routers.

## 1. ASGI Middleware vs `APIRoute.get_route_handler()` Lifecycle

Every path operation registered on an `APIRouter` constructs an `APIRoute` instance (or the custom subclass passed to `APIRouter(route_class=...)`) and builds its per-request handler by calling `self.get_route_handler()`. When a child router is mounted via `app.include_router()`, FastAPI applies **router prefix and dependency inheritance**—invoking `get_route_handler()` with the merged parent prefixes, tags, dependencies, and response settings while leaving sibling routers completely untouched.

Understanding the execution order inside FastAPI's built-in route handler explains when you need a custom `APIRoute` instead of `Depends()`:

1. **Body Read & JSON Decoding (`await request.body()` / `await request.json()`)** runs **first**—raising `RequestValidationError(type="json_invalid")` immediately if JSON syntax is malformed.
2. **Dependency Resolution & Parameter Validation** runs **second**—meaning a `Depends()` callable *cannot* decompress a `gzip`-encoded JSON stream before `request.json()` fails, nor can `Depends()` catch `RequestValidationError` raised by body or parameter validation.

| Dimension | Global Pure ASGI Middleware | `APIRouter(route_class=CustomRoute)` | `Depends()` / `Security()` |
| :--- | :--- | :--- | :--- |
| **Execution Timing** | Before routing (runs on `404`s, `/static`, all routers) | After route matching, **before** JSON parsing & `Depends()` | **After** FastAPI decodes the JSON or form body |
| **Scope Granularity** | Entire `FastAPI` app or mounted sub-app | Exact `APIRouter` subtree (`route_class=...`) | App, `APIRouter`, route `dependencies=[...]`, or param |
| **Swap `Request` (`body()`)** | Requires manual low-level ASGI `receive` wrapper | Native: instantiate `CustomRequest(request.scope, request.receive)` | Too late (`request.json()` already ran) |
| **Catch `RequestValidationError`** | No (handled by app-wide `@app.exception_handler`) | **Yes**: `try: await original_route_handler(request)` | No (validation errors are raised before endpoint execution) |
| **Route Metadata Access** | `scope["route"]` not yet populated pre-routing | Direct `self.operation_id`, `self.path`, `self.tags`, `self.name` | Via `request.scope["route"]` only |

## 2. Transparent `GzipRequest`, Error Wrapping & Webhook HMAC Routes

Combining a custom `Request` subclass with a custom `APIRoute` unlocks clean stream transformations and cryptographic pre-validation without polluting endpoint signatures.

```drawlib align=center code=hide file=gzip_and_hmac_route_pipeline.png caption="Runtime Sequence Inside Custom APIRoute: Bounded GzipRequest Decompression, Constant-Time HMAC-SHA256 & 422 Error Enrichment"
from drawlib.canvas import save, setup
from drawlib.diagrams.sequence import Participant, ParticipantGroup, PhosphorIcon, SequenceDiagram
from drawlib.icons import code
from drawlib.styles import Styles
from drawlib.text import text

setup(width=184, height=124, dpi=150)

# Title Banner
code.fastapi((10.5, 118.0), width=5.2, style=Styles.Primary)
text(
    (16.0, 118.0),
    "Custom APIRoute Runtime Sequence: Bounded GzipRequest + HMAC-SHA256 + 422 Wrapping",
    style=Styles.DarkBold.patch(text_size=12.2, halign="left"),
)

d = SequenceDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.3),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.White,
    autonumber=True,
    col_width=44.5,
    step_y=6.5,
)

client = d.add(
    Participant(
        "Webhook Client",
        width=26,
        height=13,
        icon=PhosphorIcon.CLOUD_ARROW_UP,
        icon_size=6.0,
        card_style=Styles.Neutral,
    )
)

router_grp = d.add(
    ParticipantGroup(
        title="APIRouter(route_class=CustomRoute)",
        padding=4.0,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=10.5, halign="left"),
    )
)
custom_route = router_grp.add(
    Participant(
        "Custom APIRoute",
        width=27,
        height=13,
        icon=PhosphorIcon.SHIELD_CHECK,
        icon_size=6.0,
        card_style=Styles.PrimaryNeutral,
    )
)
gzip_req = router_grp.add(
    Participant(
        "GzipRequest",
        width=25,
        height=13,
        icon=PhosphorIcon.FILE_ARCHIVE,
        icon_size=6.0,
    )
)
inner_handler = router_grp.add(
    Participant(
        "original_handler",
        width=30,
        height=13,
        icon=PhosphorIcon.CPU,
        icon_size=6.0,
        card_style=Styles.SecondaryNeutral,
    )
)

client.request(custom_route, "POST Content-Encoding: gzip + X-Hub-Signature")
custom_route.request(gzip_req, "Wrap scope & await request.body()")
gzip_req.reply(custom_route, "Gunzip (<=1 MiB cap) & cache bytes")
d.note(
    "hmac.compare_digest() & perf_counter()",
    over=[custom_route, gzip_req],
    style=Styles.PrimaryNeutral.patch(text_size=10.0),
)

with d.opt("Valid HMAC & <=1 MiB") as ok_blk:
    ok_blk.text_style = Styles.DarkBold.patch(text_size=10.0, halign="left")
    custom_route.request(inner_handler, "await original_route_handler(request)")
    inner_handler.request(gzip_req, "await request.json() [reuses cache]")
    gzip_req.reply(inner_handler, "Decompressed UTF-8 JSON")
    inner_handler.reply(custom_route, "200 Response or RequestValidationError")
    custom_route.reply(
        client,
        "200 / 422 JSON + X-Response-Time-Ms",
        style=Styles.PrimaryBold,
        text_style=Styles.PrimaryBold.patch(text_size=10.0),
    )

with d.opt("Invalid HMAC or >1 MiB") as err_blk:
    err_blk.text_style = Styles.Danger.patch(text_size=10.0, halign="left")
    custom_route.reply(
        client,
        "401 Bad HMAC / 413 Cap Exceeded",
        style=Styles.Danger,
        text_style=Styles.Danger.patch(text_size=10.0),
    )

d.draw(xy=(92.0, 55.0), align="center")
save()
```

### Bounded `GzipRequest` & `GzipRoute` Decompression

Starlette's `Request.json()` calls `await self.body()` and memoizes the resulting bytes in memory for the duration of the request. Overriding `async def body(self) -> bytes` on `GzipRequest`—and reading through `gzip.GzipFile.read(MAX_DECOMPRESSED_BYTES + 1)` rather than unbounded `gzip.decompress()`—transparently feeds decompressed UTF-8 JSON to `original_route_handler` while neutralizing zip-bomb denial-of-service payloads with `413 Content Too Large`:

```python
import gzip
import io
from typing import Any, Callable, Coroutine

from fastapi import APIRouter, FastAPI, HTTPException, Request, Response, status
from fastapi.routing import APIRoute
from pydantic import BaseModel

MAX_DECOMPRESSED_BYTES = 1024 * 1024  # 1 MiB decompression ceiling against zip bombs


class GzipRequest(Request):
    async def body(self) -> bytes:
        if not hasattr(self, "_body"):
            raw_body = await super().body()
            encodings = [
                token.strip().lower()
                for header in self.headers.getlist("Content-Encoding")
                for token in header.split(",")
            ]
            if "gzip" in encodings:
                try:
                    with gzip.GzipFile(fileobj=io.BytesIO(raw_body)) as gz_stream:
                        decompressed = gz_stream.read(MAX_DECOMPRESSED_BYTES + 1)
                except (OSError, EOFError) as exc:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Malformed gzip request stream",
                    ) from exc
                if len(decompressed) > MAX_DECOMPRESSED_BYTES:
                    raise HTTPException(
                        status_code=status.HTTP_413_CONTENT_TOO_LARGE,
                        detail="Decompressed payload exceeds 1 MiB limit",
                    )
                raw_body = decompressed
            self._body = raw_body
        return self._body


class GzipRoute(APIRoute):
    def get_route_handler(self) -> Callable[[Request], Coroutine[Any, Any, Response]]:
        original_route_handler = super().get_route_handler()

        async def custom_route_handler(request: Request) -> Response:
            gzip_request = GzipRequest(request.scope, request.receive)
            return await original_route_handler(gzip_request)

        return custom_route_handler


app = FastAPI(title="Telemetry Ingest API", version="1.0.0")
ingest_router = APIRouter(prefix="/ingest", route_class=GzipRoute)


class MetricBatch(BaseModel):
    service: str
    samples: list[float]


@ingest_router.post("/metrics")
async def ingest_metrics(batch: MetricBatch) -> dict[str, Any]:
    return {
        "service": batch.service,
        "count": len(batch.samples),
        "sum": sum(batch.samples),
    }


@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok"}


app.include_router(ingest_router)
```

### Latency Timing, Structured `422` Wrapping & HMAC-SHA256 Verification

Webhook receivers must verify `X-Hub-Signature-256` against the **exact raw request bytes** using constant-time `hmac.compare_digest()` *before* JSON deserialization—so forged requests are rejected with `401 Unauthorized` without spending CPU on schema parsing or leaking validation errors. Wrapping `await original_route_handler(request)` in the same `APIRoute` subclass also lets you attach `X-Response-Time-Ms` latency headers and enrich legitimate callers' `422` validation failures with `self.operation_id` and a bounded payload preview:

```python
import hashlib
import hmac
import logging
import os
import secrets
import time
from typing import Any, Callable, Coroutine

from fastapi import APIRouter, FastAPI, HTTPException, Request, Response, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.routing import APIRoute
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)


def load_webhook_secret() -> bytes:
    configured = os.environ.get("WEBHOOK_HMAC_SECRET")
    if configured:
        return configured.encode("utf-8")
    logger.warning("WEBHOOK_HMAC_SECRET unset; using ephemeral instance-isolated key")
    return secrets.token_bytes(32)


WEBHOOK_SECRET: bytes = load_webhook_secret()
MAX_PREVIEW_CHARS = 256


class HmacTimedRoute(APIRoute):
    def get_route_handler(self) -> Callable[[Request], Coroutine[Any, Any, Response]]:
        original_route_handler = super().get_route_handler()
        operation_id = self.operation_id or self.name

        async def custom_route_handler(request: Request) -> Response:
            started = time.perf_counter()

            # 1. Verify HMAC-SHA256 over raw bytes BEFORE Pydantic parses JSON
            raw_body = await request.body()
            provided_sig = request.headers.get("X-Hub-Signature-256", "")
            expected_sig = (
                "sha256="
                + hmac.new(WEBHOOK_SECRET, raw_body, hashlib.sha256).hexdigest()
            )
            if not hmac.compare_digest(expected_sig, provided_sig):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid or missing X-Hub-Signature-256 header",
                )

            # 2. Execute inner FastAPI handler & catch RequestValidationError
            try:
                response = await original_route_handler(request)
            except RequestValidationError as exc:
                elapsed_ms = (time.perf_counter() - started) * 1000.0
                preview = raw_body.decode("utf-8", errors="replace")[:MAX_PREVIEW_CHARS]
                return JSONResponse(
                    status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                    content={
                        "operation_id": operation_id,
                        "detail": exc.errors(),
                        "raw_body_preview": preview,
                    },
                    headers={"X-Response-Time-Ms": f"{elapsed_ms:.2f}"},
                )

            elapsed_ms = (time.perf_counter() - started) * 1000.0
            response.headers["X-Response-Time-Ms"] = f"{elapsed_ms:.2f}"
            return response

        return custom_route_handler


app = FastAPI(title="Signed Webhook Receiver", version="1.0.0")
webhook_router = APIRouter(prefix="/webhooks", route_class=HmacTimedRoute)


class PaymentDeliveredEvent(BaseModel):
    event_id: str
    invoice_id: str
    amount_cents: int = Field(gt=0)


@webhook_router.post("/payments")
async def receive_payment_webhook(
    event: PaymentDeliveredEvent,
) -> dict[str, Any]:
    return {"accepted": True, "event_id": event.event_id}


app.include_router(webhook_router)
```

> [!TIP]
> Because `await request.body()` caches the raw payload bytes in memory on the `Request` instance, calling `await request.body()` inside `HmacTimedRoute` does **not** consume the ASGI stream away from `original_route_handler(request)`—FastAPI's built-in route handler reuses the cached bytes immediately. Avoid eager `request.body()` reads only on multi-megabyte multipart file uploads where `request.stream()` should stream chunks directly to `SpooledTemporaryFile`.

With Chapter 3's routing and model layer complete—spanning [Path, Query, Header, Cookie & Body](parameters_and_validation.md), [Response Serialization & OpenAPI 3.1](responses_and_openapi.md), and [Parameter Models, Extra Types & Examples](advanced_types_and_models.md)—continue to Chapter 4's [Dependency Graph, Caching & Scopes](../04_dependencies_and_security/dependency_injection.md), [ASGI Middleware & Threadpool](../05_async_and_realtime/concurrency_and_middleware.md) for transport-level middleware, [Native OpenTelemetry & Exceptions](../06_observability_and_testing/telemetry_and_errors.md) for app-wide exception handlers, and [Webhooks, Callbacks, SDKs & Docs UI](../07_frontend_and_openapi_ext/webhooks_callbacks_sdks.md) for documenting `@app.webhooks` schemas.
