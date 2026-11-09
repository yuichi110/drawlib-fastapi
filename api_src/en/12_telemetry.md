# fastapi.telemetry

Native OpenTelemetry configuration, per-request contextual state, and synchronous processor lookup imported from `fastapi.telemetry` (`TelemetryConfig`, `TelemetryData`, and `get_telemetry_data()`). FastAPI instruments W3C trace propagation, low-cardinality route spans, child operation spans, HTTP server metrics, and structured validation or exception log events while remaining a zero-overhead no-op when no SDK provider is configured.

```drawlib align=center code=hide file=fastapi_telemetry_api.png caption="FastAPI Native OpenTelemetry Configuration, Child Operation Spans, and Synchronous TelemetryData Lookup"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.lines import line
from drawlib.smartarts import CardList, ChevronProcess, Panel
from drawlib.styles import Colors, Styles

setup(width=188, height=88)

spans = ChevronProcess(
    style=Styles.Neutral,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    corner_angle=60.0,
    spacing=1.8,
    flat_left_end=True,
)
spans.add("SERVER Span", description="HTTP / WS Route")
spans.add(
    "fastapi.dependencies",
    description="DI & Security",
    style=Styles.SecondaryNeutral,
)
spans.add(
    "fastapi.endpoint",
    description="Route Callable",
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
)
spans.add(
    "serialization / task",
    description="Response & Background",
    style=Styles.PrimaryNeutral,
)
spans.draw(xy=(6.0, 67.0), width=176.0, height=15.0)

cfg_panel = Panel(
    "TelemetryConfig",
    description="",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.sliders,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.5,
)
cfg_panel.draw((6.0, 5.0), width=84.0, height=57.0)
c_xy, c_w, c_h = cfg_panel.get_content_box((6.0, 5.0), width=84.0, height=57.0, padding=(3.5, 3.0))

cfg_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.DarkBold,
    spacing=2.0,
)
cfg_cards.add(
    "Providers & Signal Flags",
    "tracer / meter / logger + booleans",
    badge_text="OTEL",
    icon=phosphor.plugs,
)
cfg_cards.add(
    "operation_spans & exclude",
    "Child spans • ASGI scope predicate",
    badge_text="SPAN",
    icon=phosphor.git_branch,
)
cfg_cards.add(
    "auto_configure",
    "Lifespan OTLP http/protobuf setup",
    badge_text="ENV",
    icon=phosphor.broadcast,
)
cfg_cards.draw(c_xy, width=c_w, height=c_h)

line((91.5, 33.5), (96.5, 33.5), arrow_head="->", style=Styles.PrimaryBold.patch(line_width=1.8))

data_panel = Panel(
    "get_telemetry_data()",
    description="",
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.pulse,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
data_panel.draw((98.0, 5.0), width=84.0, height=57.0)
d_xy, d_w, d_h = data_panel.get_content_box((98.0, 5.0), width=84.0, height=57.0, padding=(3.5, 3.0))

data_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    spacing=2.0,
)
data_cards.add(
    "request & websocket",
    "Active ASGI connection handles",
    badge_text="CONN",
    icon=phosphor.globe,
)
data_cards.add(
    "body & values",
    "Parsed payload • resolved kwargs",
    badge_text="DATA",
    icon=phosphor.brackets_curly,
)
data_cards.add(
    "errors (Cleared on Exit)",
    "Validation dicts • returns None after",
    badge_text="SYNC",
    icon=phosphor.shield_warning,
)
data_cards.draw(d_xy, width=d_w, height=d_h)

save()
```

---

## `class` TelemetryConfig

`TypedDict(total=False)` mapping passed to `FastAPI(telemetry={...})` to configure native OpenTelemetry tracing, metrics, structured exception/validation log records, child operation spans, environment-based OTLP exporter registration, and per-scope exclusion. Omitted keys retain their defaults, existing SDK providers and exporters are preserved, and application-supplied providers are never shut down by FastAPI.

```python
from collections.abc import Callable, MutableMapping
from typing import Any
from opentelemetry._logs import LoggerProvider
from opentelemetry.metrics import MeterProvider
from opentelemetry.trace import TracerProvider
from typing_extensions import TypedDict


class TelemetryConfig(TypedDict, total=False):
    tracer_provider: TracerProvider | None
    meter_provider: MeterProvider | None
    logger_provider: LoggerProvider | None
    tracing: bool
    metrics: bool
    logs: bool
    operation_spans: bool
    auto_configure: bool
    exclude: Callable[[MutableMapping[str, Any]], bool] | None
```

### Configuration Keys

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `tracer_provider` | `TracerProvider \| None` | `None` | Explicit OpenTelemetry `TracerProvider` for this app; falls back to the global tracer provider when `None`. |
| `meter_provider` | `MeterProvider \| None` | `None` | Explicit OpenTelemetry `MeterProvider` for `http.server.request.duration` (histogram) and `http.server.active_requests` (up-down counter); falls back to the global meter provider when `None`. |
| `logger_provider` | `LoggerProvider \| None` | `None` | Explicit OpenTelemetry `LoggerProvider` for validation and unhandled exception events; falls back to the global logger provider when `None`. |
| `tracing` | `bool` | `True` | Enable `SpanKind.SERVER` spans for HTTP requests (`{METHOD} {http.route}`) and WebSocket connections (`WS {http.route}`), including W3C `traceparent` / `baggage` extraction and sensitive query redaction. |
| `metrics` | `bool` | `True` | Enable HTTP server request duration and active-request metrics (skipped automatically for WebSocket scopes). |
| `logs` | `bool` | `True` | Emit `fastapi.validation.failed` (`WARN`) on `422` / WebSocket validation errors and `http.server.request.exception` or `fastapi.websocket.exception` (`ERROR`) on unhandled exceptions. |
| `operation_spans` | `bool` | `True` | Emit child spans (`fastapi.dependencies`, `fastapi.endpoint`, `fastapi.serialization`, `fastapi.background_task`) annotated with `code.function.name` when tracing is active. |
| `auto_configure` | `bool` | `False` | Lazily register `http/protobuf` OTLP exporters from `OTEL_EXPORTER_OTLP_*` env vars during `lifespan.startup` (requires `fastapi[opentelemetry]` or `fastapi[standard]`). Defaults to `True` when `FASTAPI_OTEL_AUTO_CONFIGURE=true` is set, unless overridden explicitly. |
| `exclude` | `Callable[[MutableMapping[str, Any]], bool] \| None` | `None` | Predicate receiving the raw ASGI `scope`. Returning `True` bypasses telemetry for that request or connection and detaches any inherited parent context for mounted sub-apps. |

### Example

```python
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter

from fastapi import Depends, FastAPI
from fastapi.telemetry import TelemetryConfig
from fastapi.testclient import TestClient

exporter = InMemorySpanExporter()
provider = TracerProvider()
provider.add_span_processor(SimpleSpanProcessor(exporter))

config: TelemetryConfig = {
    "tracer_provider": provider,
    "operation_spans": True,
    "exclude": lambda scope: scope.get("path") == "/healthz",
}
app = FastAPI(telemetry=config)


def get_locale(lang: str = "en") -> str:
    return lang


@app.get("/healthz")
def healthz() -> dict[str, bool]:
    return {"ok": True}


@app.get("/items/{item_id}")
def read_item(item_id: int, lang: str = Depends(get_locale)) -> dict[str, object]:
    return {"item_id": item_id, "lang": lang}


with TestClient(app) as client:
    assert client.get("/healthz").status_code == 200
    assert len(exporter.get_finished_spans()) == 0

    assert client.get("/items/7?lang=ja").status_code == 200

span_names = [span.name for span in exporter.get_finished_spans()]
assert span_names == [
    "fastapi.dependencies",
    "fastapi.endpoint",
    "fastapi.serialization",
    "GET /items/{item_id}",
]
```

---

## `class` TelemetryData

Keyword-only dataclass holding local per-request or per-WebSocket data for synchronous OpenTelemetry `SpanProcessor` and `LogRecordProcessor` integrations. FastAPI populates fields progressively during request handling and never exports them automatically to spans or logs, allowing observability hooks to apply PII scrubbing and redaction rules before recording attributes.

```python
from collections.abc import Sequence
from dataclasses import dataclass
from typing import Any
from starlette.requests import Request
from starlette.websockets import WebSocket


@dataclass(kw_only=True)
class TelemetryData:
    request: Request | None = None
    websocket: WebSocket | None = None
    body: Any = None
    values: dict[str, Any] | None = None
    errors: Sequence[Any] | None = None
```

### Attributes

| Attribute | Type | Default | Lifecycle & Description |
| :--- | :--- | :--- | :--- |
| `request` | `Request \| None` | `None` | Active HTTP `Request` instance, populated as soon as the HTTP route handler begins executing (`None` on WebSocket routes). |
| `websocket` | `WebSocket \| None` | `None` | Active `WebSocket` connection instance, populated when a WebSocket route handler begins executing (`None` on HTTP routes). |
| `body` | `Any` | `None` | Parsed request payload read by FastAPI prior to Pydantic parameter validation (also populated from `RequestValidationError.body` on validation failure). |
| `values` | `dict[str, Any] \| None` | `None` | Validated keyword arguments dictionary passed to the endpoint callable, populated once dependency resolution and validation succeed. |
| `errors` | `Sequence[Any] \| None` | `None` | Sequence of validation error dicts (`exc.errors()`), including raw input values when `RequestValidationError` or `WebSocketRequestValidationError` is raised. |

### Example

```python
from opentelemetry.sdk._logs import LoggerProvider, LogRecordProcessor, ReadWriteLogRecord
from pydantic import BaseModel

from fastapi import FastAPI
from fastapi.telemetry import TelemetryData, get_telemetry_data
from fastapi.testclient import TestClient

validation_snapshots: list[tuple[object, int]] = []


class ValidationAuditProcessor(LogRecordProcessor):
    def on_emit(self, log_record: ReadWriteLogRecord) -> None:
        data = get_telemetry_data(log_record.log_record.context)
        if isinstance(data, TelemetryData) and data.errors is not None:
            validation_snapshots.append((data.body, len(data.errors)))

    def shutdown(self) -> None:
        return None

    def force_flush(self, timeout_millis: int = 30000) -> bool:
        return True


logger_provider = LoggerProvider()
logger_provider.add_log_record_processor(ValidationAuditProcessor())

app = FastAPI(telemetry={"logger_provider": logger_provider})


class OrderIn(BaseModel):
    sku: str
    qty: int


@app.post("/orders")
def create_order(order: OrderIn) -> dict[str, object]:
    data = get_telemetry_data()
    assert data is not None
    assert data.request is not None and data.request.method == "POST"
    assert data.body == {"sku": "KB-01", "qty": 2}
    assert data.values == {"order": OrderIn(sku="KB-01", qty=2)}
    return {"created": order.sku}


with TestClient(app) as client:
    assert client.post("/orders", json={"sku": "KB-01", "qty": 2}).status_code == 200
    assert client.post("/orders", json={"sku": "KB-01", "qty": "bad"}).status_code == 422

assert validation_snapshots == [({"sku": "KB-01", "qty": "bad"}, 1)]
```

---

## `def` get_telemetry_data()

Reads the active `TelemetryData` instance bound to an OpenTelemetry `Context` (`fastapi.request` context key). Call this function synchronously from route handlers, dependencies, `SpanProcessor.on_start` / `on_end`, or `LogRecordProcessor.on_emit` while FastAPI is handling the request or WebSocket connection; once the ASGI scope finishes, FastAPI clears `data` to `None` so even retained contexts return `None`.

```python
from opentelemetry.context import Context
from fastapi.telemetry import TelemetryData, get_telemetry_data


def get_telemetry_data(context: Context | None = None) -> TelemetryData | None: ...
```

### Parameters & Return Value

| Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `context` | `Context \| None` | `None` | Explicit OpenTelemetry `Context` to inspect (for example `parent_context` in `SpanProcessor.on_start` or `log_record.log_record.context` in `LogRecordProcessor.on_emit`). Uses the current active context when `None`. |
| **Returns** | `TelemetryData \| None` | — | Active `TelemetryData` while FastAPI is synchronously processing the HTTP request or WebSocket connection, or `None` outside an instrumented scope or after request completion. |

### Example

```python
from opentelemetry import context as otel_context
from opentelemetry.context import Context
from opentelemetry.sdk.trace import Span, TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter

from fastapi import FastAPI
from fastapi.telemetry import get_telemetry_data
from fastapi.testclient import TestClient


class EndpointArgTagger(SimpleSpanProcessor):
    def on_start(self, span: Span, parent_context: Context | None = None) -> None:
        data = get_telemetry_data(parent_context)
        if span.name == "fastapi.endpoint" and data and data.values:
            span.set_attribute("app.account_id", str(data.values.get("account_id")))


exporter = InMemorySpanExporter()
provider = TracerProvider()
provider.add_span_processor(EndpointArgTagger(exporter))

app = FastAPI(telemetry={"tracer_provider": provider})
retained_contexts: list[Context] = []


@app.get("/accounts/{account_id}")
def get_account(account_id: str) -> dict[str, str]:
    retained_contexts.append(otel_context.get_current())
    live = get_telemetry_data()
    assert live is not None and live.values == {"account_id": "acct_99"}
    return {"account_id": account_id}


with TestClient(app) as client:
    assert client.get("/accounts/acct_99").status_code == 200

# Cleared immediately after request completion, even on retained contexts
assert get_telemetry_data() is None
assert get_telemetry_data(retained_contexts[0]) is None

ep_span = next(s for s in exporter.get_finished_spans() if s.name == "fastapi.endpoint")
assert ep_span.attributes is not None
assert ep_span.attributes["app.account_id"] == "acct_99"
```
