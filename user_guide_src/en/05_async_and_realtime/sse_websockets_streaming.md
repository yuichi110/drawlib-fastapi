# Native SSE, JSONL & WebSockets

FastAPI `v0.162.2` ships three first-class real-time and streaming primitives out of the box—native Server-Sent Events (`EventSourceResponse`), typed JSON Lines (`AsyncIterator[Model]`), and full-duplex `WebSocket` endpoints—with automatic Pydantic serialization, proxy anti-buffering headers, and cooperative cancellation checkpoints.

```drawlib align=center code=hide file=streaming_modes_comparison.png caption="FastAPI v0.162.2 Built-In Realtime & Generator Streaming Modes Compared"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=174, height=78)

text(
    (87.0, 73.0),
    "FastAPI v0.162.2 Native Streaming & Realtime Protocols",
    style=Styles.DarkBold.patch(text_size=13.5),
)

# Column 1: Native SSE (Focal Primary Panel)
p_sse = Panel(
    "1. SSE",
    "text/event-stream",
    style=Styles.PrimaryNeutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.0),
    description_style=Styles.White.patch(text_size=10.0),
    icon=phosphor.broadcast,
    icon_style=Styles.WhiteBold,
    header_height=9.0,
)
p_sse.draw((4.0, 5.0), width=52.0, height=62.0)
xy1, w1, h1 = p_sse.get_content_box((4.0, 5.0), width=52.0, height=62.0, padding=(3.0, 3.0))

cl_sse = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_style=Styles.PrimaryFlat,
    badge_text_style=Styles.WhiteBold.patch(text_size=10.0),
    spacing=2.2,
)
cl_sse.add("EventSourceResponse", "GET or POST for LLM & MCP", badge_text="A")
cl_sse.add("ServerSentEvent", "JSON data, raw_data, id, retry", badge_text="B")
cl_sse.add("Anti-Buffer & Ping", "no-cache, X-Accel + 15s ping", badge_text="C")
cl_sse.draw(xy1, width=w1, height=h1)

# Column 2: Native JSON Lines (Neutral Panel)
p_jsonl = Panel(
    "2. JSONL",
    "application/jsonl",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    description_style=Styles.Dark.patch(text_size=10.0),
    icon=phosphor.list_numbers,
    icon_style=Styles.SecondaryBold,
    header_height=9.0,
)
p_jsonl.draw((61.0, 5.0), width=52.0, height=62.0)
xy2, w2, h2 = p_jsonl.get_content_box((61.0, 5.0), width=52.0, height=62.0, padding=(3.0, 3.0))

cl_jsonl = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.SecondaryBold.patch(text_size=10.0),
    spacing=2.2,
)
cl_jsonl.add("AsyncIterator[Model]", "Zero response_class needed", badge_text="A")
cl_jsonl.add("Per-Item Validation", "Pydantic Rust JSON + \\n", badge_text="B")
cl_jsonl.add("Cancel Checkpoint", "await anyio.sleep(0) per row", badge_text="C")
cl_jsonl.draw(xy2, width=w2, height=h2)

# Column 3: Bidirectional WebSockets (Neutral Panel)
p_ws = Panel(
    "3. WebSocket",
    "ws:// & wss://",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    description_style=Styles.Dark.patch(text_size=10.0),
    icon=phosphor.arrows_left_right,
    icon_style=Styles.SecondaryBold,
    header_height=9.0,
)
p_ws.draw((118.0, 5.0), width=52.0, height=62.0)
xy3, w3, h3 = p_ws.get_content_box((118.0, 5.0), width=52.0, height=62.0, padding=(3.0, 3.0))

cl_ws = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    spacing=2.2,
)
cl_ws.add("@app.websocket", "Full-duplex text, bytes, JSON", badge_text="A")
cl_ws.add("Handshake DI", "Depends, Query & Cookie auth", badge_text="B")
cl_ws.add("Clean Teardown", "WebSocketDisconnect (1000)", badge_text="C")
cl_ws.draw(xy3, width=w3, height=h3)

save()
```

## 1. Choosing the Right Streaming Protocol

Before writing a streaming endpoint, match your client topology and framing guarantees to the simplest protocol that fits:

| Capability | Native SSE (`EventSourceResponse`) | Native JSON Lines (`AsyncIterator[T]`) | `WebSocket` (`@app.websocket`) |
| :--- | :--- | :--- | :--- |
| **Directionality** | Server-to-client push (`GET` or `POST`) | Server-to-client chunked HTTP | Full-duplex bidirectional |
| **Wire Media Type** | `text/event-stream` | `application/jsonl` | Stateful RFC 6455 frames |
| **Auto-Reconnect** | Built into browser `EventSource` (`Last-Event-ID`) | Client-managed HTTP retry | Client-managed backoff |
| **Keep-Alive Pings** | Automatic `: ping` comment every `15s` | Chunk-driven | Protocol ping/pong frames |
| **Ideal Workload** | LLM token streams, MCP over `POST`, live feeds | Bulk dataset exports, service-to-service pipelines | Collaborative rooms, live telemetry control |

```drawlib align=center code=hide file=sse_and_websocket_sequence.png caption="Wire Lifecycle Contrast: Unidirectional Native SSE Resume vs Bidirectional WebSocket Session"
from drawlib.canvas import save, setup
from drawlib.diagrams.sequence import Participant, PhosphorIcon, SequenceDiagram
from drawlib.styles import Styles
from drawlib.text import text

setup(width=172, height=144)

text(
    (86.0, 138.5),
    "Native SSE (EventSourceResponse) vs Stateful WebSocket Lifecycle",
    style=Styles.DarkBold.patch(text_size=13.2),
)

d = SequenceDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.5),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
    autonumber=True,
    col_width=56.0,
    step_y=6.6,
)

client = d.add(
    Participant("Browser / SDK Client", width=36, height=13, icon=PhosphorIcon.MONITOR, icon_size=6.0)
)
router = d.add(
    Participant(
        "FastAPI Routing Layer",
        width=38,
        height=13,
        icon=PhosphorIcon.LIGHTNING,
        icon_size=6.0,
        card_style=Styles.PrimaryNeutral,
    )
)
worker = d.add(
    Participant("Async Generator / Room", width=38, height=13, icon=PhosphorIcon.BROADCAST, icon_size=6.0)
)

with d.opt("SSE over POST") as sse_blk:
    sse_blk.style = Styles.Neutral.patch(line_style="dashed")
    sse_blk.text_style = Styles.PrimaryBold.patch(text_size=10.0)
    client.request(router, "POST /v1/chat/stream (Last-Event-ID: 1)")
    router.reply(client, "200 text/event-stream (no-cache, X-Accel-Buffering: no)")
    router.request(worker, "Iterate async generator from index 2")
    worker.reply(router, "yield ServerSentEvent(id='2', event='token', data=...)")
    router.reply(client, "event: token | id: 2 | data: {...}")

with d.opt("WebSocket + DI") as ws_blk:
    ws_blk.style = Styles.Neutral.patch(line_style="dashed")
    ws_blk.text_style = Styles.SecondaryBold.patch(text_size=10.0)
    client.request(router, "GET /ws/rooms/ops?ticket=valid (Upgrade: websocket)")
    router.request(worker, "Depends(verify_ws_ticket) + await ws.accept()")
    router.reply(client, "101 Switching Protocols")
    client.request(worker, "send_json({'text': 'deploy ready'})")
    worker.reply(client, "send_json({'room': 'ops', 'sender': 'member-42'})")
    client.request(worker, "Close Frame (1000) -> except WebSocketDisconnect")

d.draw(xy=(86.0, 67.0), align="center")
save()
```

---

## 2. Native Server-Sent Events (`fastapi.sse`)

FastAPI `v0.162.2` includes a dedicated `fastapi.sse` module (`EventSourceResponse` and `ServerSentEvent`) engineered directly into the routing layer:

- **Works on `GET` and `POST`**: Unlike legacy `EventSource` wrappers restricted to `GET`, `response_class=EventSourceResponse` works on `POST` endpoints—essential for LLM prompt streaming and **MCP (Model Context Protocol)** transports.
- **Proxy & Keep-Alive Hardening**: FastAPI automatically sets `Cache-Control: no-cache` and `X-Accel-Buffering: no` (disabling Nginx proxy buffering) and runs an isolated AnyIO memory-stream keepalive task within the request-scoped cleanup lifecycle (torn down cleanly after the stream finishes) that emits `: ping` every `15` seconds without injecting `CancelledError` into your generator.
- **Structured `ServerSentEvent` Validation**: `data` payloads (Pydantic models, dicts, or strings) are always JSON-encoded, while `raw_data` emits pre-formatted strings verbatim (`[DONE]`, HTML fragments). Single-line constraints on `event` and `id` prevent SSE wire-injection bugs.

```python
from collections.abc import AsyncIterator
from typing import Annotated

from fastapi import FastAPI, Header
from fastapi.sse import EventSourceResponse, ServerSentEvent
from fastapi.testclient import TestClient
from pydantic import BaseModel

app = FastAPI()


class PromptRequest(BaseModel):
    prompt: str


TOKENS = ["FastAPI", "v0.162.2", "streams", "SSE"]


@app.post("/v1/chat/stream", response_class=EventSourceResponse)
async def stream_completion(
    body: PromptRequest,
    last_event_id: Annotated[str | None, Header()] = None,
) -> AsyncIterator[ServerSentEvent]:
    start_idx = int(last_event_id) + 1 if last_event_id is not None else 0
    yield ServerSentEvent(comment="stream-open", retry=3000)
    for idx in range(start_idx, len(TOKENS)):
        yield ServerSentEvent(
            data={"index": idx, "token": TOKENS[idx], "prompt": body.prompt},
            event="token",
            id=str(idx),
        )
    yield ServerSentEvent(raw_data="[DONE]", event="done")


client = TestClient(app)
res = client.post(
    "/v1/chat/stream",
    json={"prompt": "explain sse"},
    headers={"Last-Event-ID": "1"},
)
assert res.headers["content-type"].startswith("text/event-stream")
assert res.headers["x-accel-buffering"] == "no"
assert "id: 2\n" in res.text
```

---

## 3. Native Typed JSON Lines (`application/jsonl`)

When streaming typed records between backend microservices, CLI tools, or data pipelines, simply annotate a generator path operation with `AsyncIterator[MyModel]` (or `Iterator[MyModel]`) without specifying any custom `response_class`:

1. FastAPI automatically selects `media_type="application/jsonl"` and documents the item schema in [OpenAPI 3.1](../03_routing_and_models/responses_and_openapi.md).
2. Each yielded item is validated and serialized directly to UTF-8 JSON bytes (`+ b"\n"`) through Pydantic's Rust `TypeAdapter`. If an item violates the response contract mid-stream, FastAPI raises `ResponseValidationError`.
3. After every yielded chunk on an async generator, FastAPI executes `await anyio.sleep(0)` so client disconnects immediately cancel fast in-memory producers instead of burning CPU until stream exhaustion.

```python
from collections.abc import AsyncIterator

from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import BaseModel

app = FastAPI()


class MetricSample(BaseModel):
    seq: int
    service: str
    latency_ms: float


@app.get("/v1/metrics/export")
async def export_metrics() -> AsyncIterator[MetricSample]:
    samples = [
        MetricSample(seq=1, service="gateway", latency_ms=4.2),
        MetricSample(seq=2, service="billing", latency_ms=11.8),
    ]
    for sample in samples:
        yield sample


client = TestClient(app)
res = client.get("/v1/metrics/export")
assert res.headers["content-type"].startswith("application/jsonl")
rows = [MetricSample.model_validate_json(line) for line in res.text.splitlines() if line]
assert len(rows) == 2
```

---

## 4. Full-Duplex `WebSocket` Endpoints with Dependency Injection

When clients must push low-latency messages back to the server over a single persistent socket, declare `@app.websocket(...)`. WebSocket endpoints share the exact same `Depends()`, `Query()`, `Header()`, and `Cookie()` resolution engine as HTTP routes:

- **Reject Unauthorized Handshakes Early**: Validate tickets or session cookies inside a dependency *before* calling `await ws.accept()`, raising `WebSocketException(code=status.WS_1008_POLICY_VIOLATION)` on failure.
- **Always Catch `WebSocketDisconnect`**: Wrap the receive loop in `try ... except WebSocketDisconnect:` (or `finally:`) so room memberships and pub/sub subscriptions are cleaned up deterministically when clients close tabs or lose connectivity.

```python
from typing import Annotated

from fastapi import (
    Depends,
    FastAPI,
    Query,
    WebSocket,
    WebSocketDisconnect,
    WebSocketException,
    status,
)
from fastapi.testclient import TestClient

app = FastAPI()
events: list[str] = []


async def verify_ws_ticket(
    ticket: Annotated[str | None, Query()] = None,
) -> str:
    if ticket != "valid-ticket":
        raise WebSocketException(
            code=status.WS_1008_POLICY_VIOLATION,
            reason="Invalid or missing ticket",
        )
    return "member-42"


@app.websocket("/ws/rooms/{room_id}")
async def room_socket(
    ws: WebSocket,
    room_id: str,
    member_id: Annotated[str, Depends(verify_ws_ticket)],
) -> None:
    await ws.accept()
    events.append(f"join:{room_id}:{member_id}")
    try:
        while True:
            payload = await ws.receive_json()
            await ws.send_json(
                {"room": room_id, "sender": member_id, "text": payload["text"]}
            )
    except WebSocketDisconnect:
        events.append(f"leave:{room_id}:{member_id}")


client = TestClient(app)
with client.websocket_connect("/ws/rooms/ops?ticket=valid-ticket") as socket:
    socket.send_json({"text": "deploy ready"})
    assert socket.receive_json()["sender"] == "member-42"
assert events == ["join:ops:member-42", "leave:ops:member-42"]
```

Next, see how FastAPI traces every dependency, endpoint, stream, and exception in [Native OpenTelemetry & Exceptions](../06_observability_and_testing/telemetry_and_errors.md).
