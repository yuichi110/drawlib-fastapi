# NativeTelemetry, Lazy Runtime & Exception Spans

FastAPI `v0.162.2` ships a built-in OpenTelemetry subsystem under `fastapi/telemetry/` (`__init__.py`, `_api.py`, `_asgi.py`, and `_runtime.py`). Depending only on the lightweight `opentelemetry-api` package in core dependencies, FastAPI stays a zero-overhead no-op when unconfigured while automatically instrumenting W3C trace propagation, low-cardinality route spans, child operation spans, HTTP server metrics, and deduplicated exception telemetry once an OpenTelemetry SDK provider is active.

```drawlib align=center code=hide file=native_telemetry_dual_middleware.png caption="Dual-Layer Collaboration Between NativeTelemetry (L1) and ExceptionTelemetryMiddleware (L3)"
from drawlib.canvas import setup
from drawlib.diagrams.architecture import (
    ArchitectureDiagram,
    Node,
    NodeGroup,
    PhosphorIcon,
)
from drawlib.styles import Colors, Styles

d = ArchitectureDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.0),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
)

client = d.add(
    Node(
        "HTTP / WS Client\n(W3C traceparent)",
        width=28,
        height=17,
        icon=PhosphorIcon.GLOBE,
        icon_size=7.0,
        card_style=Styles.Neutral,
    ),
    xy=(14.0, 58.0),
)

stack_grp = d.add(
    NodeGroup(
        title="FastAPI ASGI Stack & Exception Correlation",
        padding=6.0,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left"),
    ),
    xy=(52.0, 6.0),
)

native = stack_grp.add(
    Node(
        "L1: NativeTelemetry\n(SERVER Span)",
        width=34,
        height=17,
        icon=PhosphorIcon.PULSE,
        icon_size=7.0,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
        card_style=Styles.PrimaryFlat,
    ),
    xy=(23.0, 52.0),
)

srv_err = stack_grp.add(
    Node(
        "L2: ServerError\n(Sends 500 Body)",
        width=30,
        height=17,
        icon=PhosphorIcon.SHIELD_WARNING,
        icon_size=7.0,
        card_style=Styles.Neutral,
    ),
    xy=(84.0, 52.0),
)

exc_tel = stack_grp.add(
    Node(
        "L3: ExceptionTelemetry\n(Logs _exceptions)",
        width=38,
        height=17,
        icon=PhosphorIcon.BUG,
        icon_size=7.0,
        card_style=Styles.SecondaryNeutral,
    ),
    xy=(146.0, 52.0),
)

exc_mw = stack_grp.add(
    Node(
        "L5: ExceptionMiddleware\n(Absorbs 4xx / 422)",
        width=42,
        height=17,
        icon=PhosphorIcon.FUNNEL,
        icon_size=7.0,
        card_style=Styles.Neutral,
    ),
    xy=(146.0, 15.0),
)

router_n = stack_grp.add(
    Node(
        "L7: APIRouter\n(_route_selected)",
        width=30,
        height=17,
        icon=PhosphorIcon.GIT_BRANCH,
        icon_size=7.0,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(84.0, 15.0),
)

tel_state = stack_grp.add(
    Node(
        "_RequestTelemetry\nscope & OTel Context",
        width=34,
        height=17,
        icon=PhosphorIcon.DATABASE,
        icon_size=7.0,
        card_style=Styles.SecondaryNeutral,
    ),
    xy=(23.0, 15.0),
)

d.connect(client, native, label="Headers", padding=1.2)
d.connect(native, srv_err, label="wrap send", padding=1.2)
d.connect(srv_err, exc_tel, label="call", padding=1.2)
d.connect(exc_tel, exc_mw, label="L4->L5", padding=1.2)
d.connect(exc_mw, router_n, label="route", padding=1.2)
d.connect(router_n, tel_state, label="http.route", padding=1.2)
d.connect(tel_state, native, label="error.type", padding=1.2)

diag_w, diag_h = d.get_size()
setup(width=int(diag_w) + 12, height=int(diag_h) + 12)
d.draw(xy=(6.0, 6.0))
```

---

## 1. Zero-SDK Core Design and Lazy Runtime Binding (`_runtime.py`)

A core design goal of `fastapi/telemetry/` is avoiding heavyweight SDK imports or per-request overhead for applications that do not export telemetry. FastAPI achieves this by separating **API-level instrumentation** from **SDK/exporter initialization**:

- **Deferred Proxy Detection (`_api.py`)**: Installing `fastapi` pulls in `opentelemetry-api>=1.44.0`, whose default global providers are lightweight no-op proxies listed in `_DEFERRED_PROVIDERS`: `ProxyTracerProvider`, `_ProxyMeterProvider`, and `ProxyLoggerProvider`. The helper `_unconfigured(provider)` checks `(type(provider).__module__, type(provider).__name__) in _DEFERRED_PROVIDERS`.
- **Hot-Path Gate (`NativeTelemetry.enabled()`)**: When `tracer_provider`, `meter_provider`, and `logger_provider` in `self._telemetry` are `None` and all three global providers satisfy `_unconfigured(...)`, `NativeTelemetry.enabled()` returns `False`. `FastAPI.__call__` immediately short-circuits to `await super().__call__(scope, receive, send)` without allocating `_RequestTelemetry`, parsing headers, or wrapping `send`/`receive`.
- **Lazy SDK & OTLP Import on Lifespan Startup (`_runtime.py`)**: Optional packages `opentelemetry-sdk` and `opentelemetry-exporter-otlp-proto-http` (installed via `fastapi[opentelemetry]` or `fastapi[standard]`) are imported lazily inside `_configure_from_environment(config)` only during `lifespan.startup`, and only when `auto_configure=True` (or `FASTAPI_OTEL_AUTO_CONFIGURE=true`) with `OTEL_SDK_DISABLED != "true"` and a valid `http`/`https` `OTEL_EXPORTER_OTLP_*` (`http/protobuf`) endpoint.
- **Provider Ownership Safety (`_owned` & `_configured`)**: Under a re-entrant `_lock`, `_configure_from_environment()` attaches `BatchSpanProcessor(OTLPSpanExporter(...))`, `PeriodicExportingMetricReader(OTLPMetricExporter(...))`, and `BatchLogRecordProcessor(OTLPLogExporter(...))` at most once per `(signal, provider)` pair. Only components instantiated by FastAPI are appended to `_owned`—flushed via `await run_sync(_flush)` on `lifespan.shutdown.complete` (or startup/shutdown failure) and closed via `atexit.register(_shutdown)`. User-supplied providers are never shut down by FastAPI.

```drawlib align=center code=hide file=lazy_otel_runtime_binding.png caption="Zero-SDK Default Fast Path vs Lifespan Lazy OTLP Auto-Configuration in _runtime.py"
from drawlib.canvas import setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, ChevronProcess, Panel
from drawlib.styles import Colors, Styles

setup(width=176, height=88)

pipeline = ChevronProcess(
    style=Styles.Neutral,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    corner_angle=60.0,
    spacing=1.8,
    flat_left_end=True,
)
pipeline.add("1. Import Time", description="opentelemetry-api")
pipeline.add(
    "2. lifespan.startup",
    description="Lazy OTLP Setup",
    style=Styles.SecondaryNeutral,
)
pipeline.add(
    "3. Request Gate",
    description="enabled() Check",
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
)
pipeline.add(
    "4. Shutdown / Exit",
    description="_flush & _shutdown",
    style=Styles.PrimaryNeutral,
)
pipeline.draw(xy=(4.0, 70.0), width=168.0, height=14.0)

noop_panel = Panel(
    "Default No-Op Fast Path",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.5),
    icon=phosphor.lightning_slash,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.5,
)
noop_panel.draw((4.0, 4.0), width=82.0, height=62.0)
n_xy, n_w, n_h = noop_panel.get_content_box(
    (4.0, 4.0), width=82.0, height=62.0, padding=(3.5, 3.0)
)

noop_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.DarkBold,
    spacing=2.2,
)
noop_cards.add(
    "Deferred Proxy Providers",
    "ProxyTracer / Meter / LoggerProvider",
    badge_text="API",
    icon=phosphor.plugs,
)
noop_cards.add(
    "_unconfigured() is True",
    "NativeTelemetry.enabled() returns False",
    badge_text="Gate",
    icon=phosphor.shield_check,
)
noop_cards.add(
    "Direct super().__call__",
    "Zero span, wrapper, or context overhead",
    badge_text="0ms",
    icon=phosphor.fast_forward,
)
noop_cards.draw(n_xy, width=n_w, height=n_h)

sdk_panel = Panel(
    "Active SDK & OTLP Export",
    style=Styles.PrimaryNeutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.5),
    icon=phosphor.broadcast,
    icon_style=Styles.White,
    header_variant="filled",
    header_height=8.5,
)
sdk_panel.draw((90.0, 4.0), width=82.0, height=62.0)
s_xy, s_w, s_h = sdk_panel.get_content_box(
    (90.0, 4.0), width=82.0, height=62.0, padding=(3.5, 3.0)
)

sdk_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    spacing=2.2,
)
sdk_cards.add(
    "Lazy SDK Import",
    "Loads opentelemetry.sdk only when enabled",
    badge_text="SDK",
    icon=phosphor.package,
)
sdk_cards.add(
    "OTLP http/protobuf",
    "BatchSpan / Log & PeriodicMetricReader",
    badge_text="OTLP",
    icon=phosphor.export,
)
sdk_cards.add(
    "Owned Lifecycle (_owned)",
    "Flushes on shutdown; preserves user SDKs",
    badge_text="Safe",
    icon=phosphor.lock_key,
)
sdk_cards.draw(s_xy, width=s_w, height=s_h)
```

---

## 2. `NativeTelemetry` Span, Context, and Metric Mechanics (`_asgi.py`)

When `NativeTelemetry.__call__` executes on an active HTTP or WebSocket scope (and `config["exclude"](scope)` does not exclude it, nor does `_legacy_otel()` detect `OpenTelemetryMiddleware`), it orchestrates five stages across the request lifecycle:

1. **W3C Context Extraction & Sanitization**: `propagate.extract(Headers(scope=scope), getter=_HEADERS_GETTER)` extracts inbound `traceparent`, `tracestate`, and multi-header `baggage` into `parent` and attaches it via `otel_context.attach(parent)`. Unknown HTTP verbs outside `_HTTP_METHODS` (or `OTEL_INSTRUMENTATION_HTTP_KNOWN_METHODS`) normalize to `"_OTHER"` (saving the raw verb in `http.request.method_original`), while `_SENSITIVE_QUERY_PARAMETERS` (`X-Amz-Signature`, `X-Amz-Credential`, `X-Amz-Security-Token`, `sig`, `X-Goog-Signature`) are redacted to `"REDACTED"` in `url.query`.
2. **Root `SpanKind.SERVER` Span & `_RequestTelemetry` Attachment**: `tracer.start_span(span_method, context=parent, kind=SpanKind.SERVER, attributes=span_attributes)` starts the server span under schema URL `https://opentelemetry.io/schemas/1.44.0`—initially named after the bare verb (`"GET"`, `"POST"`, or `"WS"`) so unmatched `404` scanner traffic cannot explode span-name cardinality. FastAPI stores `_RequestTelemetry` in **both** `scope["fastapi.telemetry"]` (for ASGI routing hooks) and `otel_context` under `_REQUEST_TELEMETRY_KEY` (`"fastapi.request"`, accessible via `get_telemetry_data()` across worker threads).
3. **Low-Cardinality Route Resolution (`_route_selected()`)**: As `APIRouter.app` matches a route (or traverses a `Mount`, accumulating `_mount_prefix`), it calls `_route_selected(scope=scope, path=route.path_format, mount=...)`. `_route_selected()` sets `http.route` on the span and calls `span.update_name(f"{span_method} {route}")` (for example, `"GET /items/{item_id}"`).
4. **Child Operation Spans (`_operation()`)**: When `operation_spans=True` (default), `_traced_operation()` creates child spans `fastapi.dependencies`, `fastapi.endpoint`, `fastapi.serialization`, and `fastapi.background_task` tagged with `code.function.name = f"{module}.{qualname}"`.
5. **Exemplar-Aligned Metrics & Zero-Retention Teardown**: `NativeTelemetry._instruments()` registers `http.server.request.duration` (`Histogram` in seconds with `_DURATION_BUCKETS` from `0.005` to `10.0`) and `http.server.active_requests` (`UpDownCounter`). Inside `finish()`, `duration.record(...)` runs *while the server span is still current*—enabling metric exemplars to link latency spikes directly to trace IDs—before calling `span.end()`. Finally, the outer `finally:` block clears `request_telemetry.data = None` and `_exceptions.clear()` so retained OpenTelemetry contexts never leak request bodies or parsed arguments.

---

## 3. Why `ExceptionTelemetryMiddleware` Collaborates with `ExceptionMiddleware` and `ServerErrorMiddleware`

Recording accurate exception telemetry in ASGI is subtle because expected HTTP errors, custom exception handlers, and unhandled `500` crashes unwind at different layers of the middleware onion:

- **Handled `4xx` / `422` Errors Stay Inside `ExceptionMiddleware` (L5)**: When an endpoint or dependency raises `HTTPException(404)` or `RequestValidationError` (`422`), `ExceptionMiddleware` (and `request_response()`'s `wrap_app_handling_exceptions`) catches the exception at **L5** and emits a normal HTTP response before execution ever unwinds to `ExceptionTelemetryMiddleware` (**L3**). For `status_code < 500`, `finish()` evaluates `failed = False`, leaving the `SERVER` span status at `StatusCode.UNSET` with no `error.type` (while `_validation_failed()` emits a `WARN` log event `fastapi.validation.failed` containing `fastapi.validation.error_count` when `logs=True`). Likewise, `_traced_operation()` explicitly ignores `HTTPException`, `RequestValidationError`, `WebSocketException`, `WebSocketRequestValidationError`, and normal WebSocket disconnects (`1000`, `1001`) on child spans—unless custom `@app.exception_handler(...)` returns a `5xx` status code, in which case `finish()` marks the `SERVER` span `StatusCode.ERROR` with `error.type = str(status_code)`.
- **Unhandled Crashes & the `ServerErrorMiddleware` `wrapped_send` Ordering Trap (L3 Inside L2)**: When an unhandled `ZeroDivisionError` escapes `user_middleware`, it reaches `ServerErrorMiddleware` (**L2**). Crucially, `ServerErrorMiddleware` **sends the complete `500` HTTP response body via `send()` before re-raising `exc`**. When `send({"type": "http.response.body", "more_body": False})` passes through `NativeTelemetry.wrapped_send()`, `NativeTelemetry` immediately calls `finish()` and ends the `SERVER` span—*before* Python finishes unwinding out of `ServerErrorMiddleware` into `NativeTelemetry`'s `except BaseException:` block! Placing `ExceptionTelemetryMiddleware` at **L3** (inside `ServerErrorMiddleware`) solves this race: **L3** catches `exc` first, calls `_exception(scope=scope, exc=exc)` to append `exc` to `request_telemetry._exceptions` and emit an `http.server.request.exception` `ERROR` log record, and re-raises `exc` into **L2**. Moments later, when **L2** sends the `500` response and triggers `finish()`, `finish()` reads `errors[-1]` and stamps `error.type = "ZeroDivisionError"` and `StatusCode.ERROR` onto the root span.
- **Identity Deduplication Against Double-Recording**: After sending the `500` response, `ServerErrorMiddleware` re-raises `exc` up to `NativeTelemetry` (**L1**), whose `except BaseException as exc:` block also calls `_exception(scope=scope, exc=exc)` and `finish(exc)` (catching `BaseException`s like `CancelledError` or crashes inside **L2** itself). Because `_exception()` checks `if not any(previous is exc for previous in seen):` using object identity (`is`) and `finish()` guards `if finished: return`, unhandled exceptions are never double-logged or double-ended.

---

## 4. Inspecting Emitted Spans with `InMemorySpanExporter`

The snippet below wires an OpenTelemetry SDK `TracerProvider` and `InMemorySpanExporter` into `FastAPI(telemetry=...)`, verifying W3C `traceparent` inheritance, low-cardinality `http.route` span renaming, `404` `UNSET` status handling, and `500` `error.type` capture:

```python
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter
from opentelemetry.trace import SpanKind, StatusCode

exporter = InMemorySpanExporter()
provider = TracerProvider()
provider.add_span_processor(SimpleSpanProcessor(exporter))

app = FastAPI(telemetry={"tracer_provider": provider})


@app.get("/items/{item_id}")
def get_item(item_id: int) -> dict[str, int]:
    if item_id == 0:
        raise HTTPException(status_code=404, detail="Item not found")
    if item_id < 0:
        raise ZeroDivisionError("negative item crash")
    return {"item_id": item_id}


trace_id_hex = "4bf92f3577b34da6a3ce929d0e0e4736"
traceparent = f"00-{trace_id_hex}-00f067aa0ba902b7-01"

with TestClient(app, raise_server_exceptions=False) as client:
    # 1. 200 OK: W3C traceparent inherited, child spans + low-cardinality route name
    assert client.get("/items/7", headers={"traceparent": traceparent}).status_code == 200
    spans = exporter.get_finished_spans()
    assert {"fastapi.dependencies", "fastapi.endpoint", "GET /items/{item_id}"} <= {
        s.name for s in spans
    }
    server_span = next(s for s in spans if s.kind == SpanKind.SERVER)
    assert f"{server_span.context.trace_id:032x}" == trace_id_hex
    assert server_span.attributes["http.route"] == "/items/{item_id}"
    assert server_span.attributes["http.response.status_code"] == 200
    assert server_span.status.status_code == StatusCode.UNSET
    exporter.clear()

    # 2. Handled 404 HTTPException: absorbed at L5 -> UNSET span status, no error.type
    assert client.get("/items/0").status_code == 404
    span_404 = next(s for s in exporter.get_finished_spans() if s.kind == SpanKind.SERVER)
    assert span_404.status.status_code == StatusCode.UNSET
    assert "error.type" not in span_404.attributes
    exporter.clear()

    # 3. Unhandled 500 crash: L3 records ZeroDivisionError before L2 sends 500 body
    assert client.get("/items/-1").status_code == 500
    span_500 = next(s for s in exporter.get_finished_spans() if s.kind == SpanKind.SERVER)
    assert span_500.attributes["http.response.status_code"] == 500
    assert span_500.attributes["error.type"] == "ZeroDivisionError"
    assert span_500.status.status_code == StatusCode.ERROR
```

For how FastAPI turns those same compiled `APIRoute` definitions and `ModelField` schemas into OpenAPI 3.1.0 documents and interactive UI endpoints, continue to [OpenAPI 3.1 Synthesis](../06_openapi_and_docs/openapi_synthesis_engine.md).
