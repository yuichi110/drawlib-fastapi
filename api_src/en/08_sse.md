# fastapi.sse

Server-Sent Events (SSE) streaming response marker, validated event payload model, UTF-8 wire-format serializer, and automatic idle keep-alive constant imported from `fastapi.sse` (`EventSourceResponse`, `ServerSentEvent`, `format_sse_event()`, and `KEEPALIVE_COMMENT`). FastAPI streams sync or async generator path operations over `text/event-stream` on any HTTP method (`GET`, `POST`, etc.) while decoupling generator iteration from keep-alive heartbeats.

```drawlib align=center code=hide file=fastapi_sse_api_flow.png caption="FastAPI Server-Sent Events Streaming Pipeline and Keep-Alive Architecture"
from drawlib.canvas import save, setup
from drawlib.diagrams.architecture import ArchitectureDiagram, Node, NodeGroup, PhosphorIcon
from drawlib.styles import Colors, Styles

setup(width=164, height=62)

_ = Colors
d = ArchitectureDiagram(
    node_style=Styles.Dark,
    node_text_style=Styles.DarkBold.patch(text_size=10.5),
    edge_style=Styles.Dark.patch(line_width=1.5),
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
)

gen_node = d.add(
    Node(
        "Generator Route\n(yield items)",
        icon=PhosphorIcon.CODE,
        width=26,
        height=15,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(18, 40),
)

pipeline = d.add(
    NodeGroup(
        "FastAPI SSE Pipeline (fastapi.sse)",
        width=88,
        height=52,
        style=Styles.SecondaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left", valign="top"),
    ),
    xy=(39, 5),
)

sse_model = pipeline.add(
    Node(
        "ServerSentEvent",
        icon=PhosphorIcon.PACKAGE,
        width=28,
        height=14,
        card_style=Styles.Neutral,
    ),
    xy=(20, 35),
)
formatter = pipeline.add(
    Node(
        "format_sse_event()",
        icon=PhosphorIcon.FILE_CODE,
        width=28,
        height=14,
        card_style=Styles.Neutral,
    ),
    xy=(68, 35),
)
keepalive = pipeline.add(
    Node(
        "KEEPALIVE_COMMENT\n(: ping / 15s)",
        icon=PhosphorIcon.CLOCK,
        width=28,
        height=15,
        card_style=Styles.Neutral,
    ),
    xy=(20, 12),
)
response = pipeline.add(
    Node(
        "EventSourceResponse\n(text/event-stream)",
        icon=PhosphorIcon.BROADCAST,
        width=28,
        height=15,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
        card_style=Styles.PrimaryFlat,
    ),
    xy=(68, 12),
)

client = d.add(
    Node(
        "SSE Client\n(GET / POST)",
        icon=PhosphorIcon.TERMINAL_WINDOW,
        width=24,
        height=15,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(147, 17),
)

gen_node.connect(sse_model, label="yield", padding=1.2)
sse_model.connect(formatter, label="UTF-8", padding=1.2)
formatter.connect(response, padding=1.2)
keepalive.connect(response, label="idle", padding=1.2)
response.connect(client, label="SSE", padding=1.2)

d.draw(xy=(0, 0))
save()
```

---

## `class` EventSourceResponse

Streaming response class inheriting from `starlette.responses.StreamingResponse` with `media_type = "text/event-stream"` (also re-exported from `fastapi.responses`). Pass `response_class=EventSourceResponse` on a sync or async generator path operation using `yield` to stream Server-Sent Events on any HTTP method (`GET`, `POST`, etc., including protocols such as MCP). FastAPI's routing layer serializes yielded items, sets `Cache-Control: no-cache` and `X-Accel-Buffering: no`, and emits OpenAPI `text/event-stream` item schemas.

```python
class EventSourceResponse(StreamingResponse):
    media_type = "text/event-stream"

    def __init__(
        self,
        content: ContentStream,
        status_code: int = 200,
        headers: Mapping[str, str] | None = None,
        media_type: str | None = None,
        background: BackgroundTask | None = None,
    ) -> None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `content` | `ContentStream` | *(Required)* | Sync or async byte/string iterator when instantiating `EventSourceResponse` directly. When passed as `response_class=EventSourceResponse`, FastAPI constructs the SSE byte stream automatically from items yielded by the path operation. |
| `status_code` | `int` | `200` | HTTP status code returned in the initial streaming response header frame. |
| `headers` | `Mapping[str, str] \| None` | `None` | Optional response headers merged alongside `Cache-Control: no-cache` and `X-Accel-Buffering: no`. |
| `media_type` | `str \| None` | `None` | Media type override; defaults to the class attribute `"text/event-stream"`. |
| `background` | `BackgroundTask \| None` | `None` | Optional background task executed after the event stream finishes closing. |

### Example

```python
from collections.abc import AsyncIterator

from fastapi import FastAPI
from fastapi.sse import EventSourceResponse, ServerSentEvent
from fastapi.testclient import TestClient

app = FastAPI()


@app.post("/mcp/events", response_class=EventSourceResponse)
async def stream_task_events() -> AsyncIterator[ServerSentEvent | dict[str, str]]:
    yield {"status": "started"}
    yield ServerSentEvent(event="done", data={"ok": True}, id="evt-2")


client = TestClient(app)
response = client.post("/mcp/events")
assert response.status_code == 200
assert response.headers["content-type"].startswith("text/event-stream")
assert response.headers["cache-control"] == "no-cache"
assert response.headers["x-accel-buffering"] == "no"
assert 'data: {"status":"started"}' in response.text
assert 'event: done\ndata: {"ok": true}\nid: evt-2' in response.text
```

---

## `class` ServerSentEvent

Pydantic `BaseModel` representing a single structured Server-Sent Event frame yielded from an `EventSourceResponse` endpoint. Plain Python objects (`dict`, `list`, `BaseModel`) yielded directly are JSON-encoded into `data:`, whereas yielding `ServerSentEvent` grants explicit control over `data` vs unencoded `raw_data`, custom `event` names, reconnection `id` and `retry` headers, and `:` wire comments.

```python
class ServerSentEvent(BaseModel):
    data: Any = None
    raw_data: str | None = None
    event: str | None = None
    id: str | None = None
    retry: int | None = None
    comment: str | None = None
```

### Fields & Validators

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `data` | `Any` | `None` | JSON-serializable payload (`BaseModel`, `dict`, `list`, `str`, `int`, etc.). **Always** JSON-serialized on the wire (`data="hello"` emits `data: "hello"`). Mutually exclusive with `raw_data` (`_check_data_exclusive`). |
| `raw_data` | `str \| None` | `None` | Pre-formatted string written directly to `data:` without JSON encoding (useful for HTML fragments, CSV rows, or custom text protocols). Mutually exclusive with `data`. |
| `event` | `str \| None` | `None` | Optional event type name dispatched to browser `EventSource.addEventListener(event, ...)`. Validated to be a single line with no `\r` or `\n` (`_check_event_single_line`). |
| `id` | `str \| None` | `None` | Optional event identifier echoed by reconnecting clients in the `Last-Event-ID` HTTP header. Must be a single line and must not contain null (`\0`) characters (`_check_id_valid`). |
| `retry` | `int \| None` | `None` | Optional client reconnection delay in **milliseconds**. Validated via `Field(ge=0)` to require a non-negative integer. |
| `comment` | `str \| None` | `None` | Optional comment text prefixed with `: ` on each line in the SSE stream and ignored by `EventSource` listeners. |

### Example

```python
import pytest
from pydantic import ValidationError

from fastapi.sse import ServerSentEvent

json_evt = ServerSentEvent(
    data={"temp_c": 21.5},
    event="telemetry",
    id="msg-101",
    retry=3000,
    comment="sensor-tick",
)
assert json_evt.event == "telemetry"
assert json_evt.retry == 3000

raw_evt = ServerSentEvent(raw_data="<span>ready</span>", event="fragment")
assert raw_evt.raw_data == "<span>ready</span>"
assert raw_evt.data is None

with pytest.raises(ValidationError):
    ServerSentEvent(data="json", raw_data="plain")

with pytest.raises(ValidationError):
    ServerSentEvent(id="bad\x00id")

with pytest.raises(ValidationError):
    ServerSentEvent(event="multi\nline")

with pytest.raises(ValidationError):
    ServerSentEvent(retry=-1)
```

---

## `def` format_sse_event()

Low-level keyword-only serializer that converts pre-serialized string payloads and optional SSE metadata fields into UTF-8 wire-format `bytes`. Multi-line `comment` and `data_str` inputs are split on SSE line terminators (`\r\n`, `\r`, `\n`) into consecutive `: <line>` and `data: <line>` records, and the returned byte sequence always terminates with `\n\n`.

```python
def format_sse_event(
    *,
    data_str: str | None = None,
    event: str | None = None,
    id: str | None = None,
    retry: int | None = None,
    comment: str | None = None,
) -> bytes
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `data_str` | `str \| None` | `None` | Pre-serialized string payload emitted as one or more `data: <line>` records. |
| `event` | `str \| None` | `None` | Optional event type name emitted as `event: <event>`. |
| `id` | `str \| None` | `None` | Optional event identifier emitted as `id: <id>`. |
| `retry` | `int \| None` | `None` | Optional reconnection interval in milliseconds emitted as `retry: <retry>`. |
| `comment` | `str \| None` | `None` | Optional single-line or multi-line comment emitted before event fields as `: <line>`. |

### Example

```python
from fastapi.sse import format_sse_event

wire = format_sse_event(
    comment="heartbeat",
    event="update",
    data_str="line-1\r\nline-2",
    id="42",
    retry=5000,
)
assert wire == (
    b": heartbeat\n"
    b"event: update\n"
    b"data: line-1\n"
    b"data: line-2\n"
    b"id: 42\n"
    b"retry: 5000\n\n"
)
```

---

## `const` KEEPALIVE_COMMENT

UTF-8 wire-format SSE comment constant (`b": ping\n\n"`) automatically transmitted by FastAPI's background keep-alive task whenever an `EventSourceResponse` generator produces no items for `15.0` seconds (`_PING_INTERVAL`). Keeping the TCP stream active prevents intermediate reverse proxies and load balancers from dropping idle SSE connections, while compliant `EventSource` clients silently discard lines starting with `:`.

```python
KEEPALIVE_COMMENT: bytes = b": ping\n\n"
```

### Specification

| Constant | Type | Value | Description |
| :--- | :--- | :--- | :--- |
| `KEEPALIVE_COMMENT` | `bytes` | `b": ping\n\n"` | Standard SSE comment frame emitted automatically every 15 seconds during generator idle periods. |

### Example

```python
from fastapi.sse import KEEPALIVE_COMMENT, format_sse_event

assert KEEPALIVE_COMMENT == b": ping\n\n"
assert format_sse_event(comment="ping") == KEEPALIVE_COMMENT
```
