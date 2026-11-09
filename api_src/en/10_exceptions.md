# fastapi.exceptions

HTTP, WebSocket, request/response validation, and dependency-scope exception classes imported from `fastapi.exceptions`, paired with built-in ASGI exception handlers in `fastapi.exception_handlers`. FastAPI maps client-facing protocol and validation failures to structured HTTP responses or WebSocket close frames while surfacing response contract and dependency graph misconfigurations as explicit server errors.

```drawlib align=center code=hide file=fastapi_exceptions_hierarchy.png caption="FastAPI Exception Class Hierarchy and Built-in Exception Handlers"
from drawlib.canvas import save, setup
from drawlib.diagrams.architecture import ArchitectureDiagram, Node, NodeGroup, PhosphorIcon
from drawlib.styles import Colors, Styles

setup(width=176, height=98)

_ = Colors
d = ArchitectureDiagram(
    node_style=Styles.Dark,
    node_text_style=Styles.DarkBold.patch(text_size=10.0),
    edge_style=Styles.Dark.patch(line_width=1.5),
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
)

exc_group = d.add(
    NodeGroup(
        "Exception Hierarchy (fastapi.exceptions)",
        width=96,
        height=88,
        style=Styles.SecondaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left", valign="top"),
    ),
    xy=(5, 5),
)

http_exc = exc_group.add(
    Node(
        "HTTPException",
        icon=PhosphorIcon.WARNING_CIRCLE,
        width=30,
        height=12,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
        card_style=Styles.PrimaryFlat,
    ),
    xy=(20, 72),
)
ws_exc = exc_group.add(
    Node(
        "WebSocketException",
        icon=PhosphorIcon.PLUGS,
        width=30,
        height=12,
        card_style=Styles.Neutral,
    ),
    xy=(20, 56),
)
val_base = exc_group.add(
    Node(
        "ValidationException",
        icon=PhosphorIcon.SHIELD_WARNING,
        width=30,
        height=12,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(20, 36.5),
)
fa_err = exc_group.add(
    Node(
        "FastAPIError",
        icon=PhosphorIcon.WARNING,
        width=30,
        height=12,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(20, 9),
)

req_val = exc_group.add(
    Node(
        "RequestValidationError",
        icon=PhosphorIcon.GIT_BRANCH,
        width=38,
        height=11.5,
        card_style=Styles.Neutral,
    ),
    xy=(71, 54),
)
ws_val = exc_group.add(
    Node(
        "WebSocketRequest\nValidationError",
        icon=PhosphorIcon.GIT_BRANCH,
        width=38,
        height=13,
        card_style=Styles.Neutral,
    ),
    xy=(71, 36.5),
)
resp_val = exc_group.add(
    Node(
        "ResponseValidationError",
        icon=PhosphorIcon.GIT_BRANCH,
        width=38,
        height=11.5,
        card_style=Styles.Neutral,
    ),
    xy=(71, 21.5),
)
dep_err = exc_group.add(
    Node(
        "DependencyScopeError",
        icon=PhosphorIcon.GIT_BRANCH,
        width=38,
        height=11.5,
        card_style=Styles.Neutral,
    ),
    xy=(71, 9),
)

handler_group = d.add(
    NodeGroup(
        "Handlers (fastapi.exception_handlers)",
        width=58,
        height=88,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left", valign="top"),
    ),
    xy=(113, 5),
)

h_http = handler_group.add(
    Node(
        "http_exception_\nhandler()",
        icon=PhosphorIcon.WRENCH,
        icon_size=5.5,
        width=44,
        height=14,
        card_style=Styles.White,
    ),
    xy=(29, 72),
)
h_req = handler_group.add(
    Node(
        "request_validation_\nexception_handler()",
        icon=PhosphorIcon.WRENCH,
        icon_size=5.5,
        width=44,
        height=14,
        card_style=Styles.White,
    ),
    xy=(29, 54),
)
h_ws = handler_group.add(
    Node(
        "websocket_request_\nvalidation_exception_\nhandler()",
        icon=PhosphorIcon.WRENCH,
        icon_size=5.5,
        width=44,
        height=17.5,
        card_style=Styles.White,
    ),
    xy=(29, 36.5),
)

val_base.fork([req_val, ws_val, resp_val], at_x=48.5, padding=1.0)
fa_err.connect(dep_err, padding=1.0)
http_exc.connect(h_http, label="JSON / status", padding=1.2)
req_val.connect(h_req, label="422", padding=1.2)
ws_val.connect(h_ws, label="WS 1008", padding=1.2)

d.draw(xy=(0, 0))
save()
```

---

## `class` HTTPException

Client-facing HTTP error subclassing `starlette.exceptions.HTTPException` (also re-exported directly from `fastapi`). Unlike Starlette's base class, FastAPI's `HTTPException` accepts any JSON-serializable object (`str`, `dict`, `list`) in `detail` and serializes it under `{"detail": ...}` with optional custom response `headers`.

```python
class HTTPException(StarletteHTTPException):
    def __init__(
        self,
        status_code: int,
        detail: Any = None,
        headers: Mapping[str, str] | None = None,
    ) -> None: ...
```

### Parameters & Attributes

| Parameter / Attribute | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `status_code` | `int` | *(Required)* | HTTP status code returned to the client (for example, `401`, `403`, `404`, `409`). |
| `detail` | `Any` | `None` | JSON-serializable error payload placed under `"detail"`; defaults to the standard HTTP status phrase when `None`. |
| `headers` | `Mapping[str, str] \| None` | `None` | Optional response headers (such as `{"WWW-Authenticate": "Bearer"}` or `{"Retry-After": "30"}`). |

### Example

```python
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

app = FastAPI()
ITEMS = {"item-1": "Keyboard"}


@app.get("/items/{item_id}")
def get_item(item_id: str) -> dict[str, str]:
    if item_id not in ITEMS:
        raise HTTPException(
            status_code=404,
            detail={"code": "ITEM_NOT_FOUND", "item_id": item_id},
            headers={"X-Error-Code": "ITEM_NOT_FOUND"},
        )
    return {"name": ITEMS[item_id]}


client = TestClient(app)
res = client.get("/items/missing")
assert res.status_code == 404
assert res.headers["x-error-code"] == "ITEM_NOT_FOUND"
assert res.json() == {"detail": {"code": "ITEM_NOT_FOUND", "item_id": "missing"}}
```

---

## `class` WebSocketException

WebSocket error exception subclassing `starlette.exceptions.WebSocketException` (also re-exported from `fastapi`). Raising `WebSocketException` inside a `@app.websocket()` route or its dependencies closes the WebSocket session with the specified RFC 6455 close `code` and optional UTF-8 `reason`.

```python
class WebSocketException(StarletteWebSocketException):
    def __init__(
        self,
        code: int,
        reason: str | None = None,
    ) -> None: ...
```

### Parameters & Attributes

| Parameter / Attribute | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `code` | `int` | *(Required)* | Valid RFC 6455 WebSocket closing code (for example, `status.WS_1008_POLICY_VIOLATION`). |
| `reason` | `str \| None` | `None` | Optional UTF-8 close reason string sent to the WebSocket peer. |

### Example

```python
import pytest
from starlette.websockets import WebSocketDisconnect

from fastapi import FastAPI, WebSocket, WebSocketException, status
from fastapi.testclient import TestClient

app = FastAPI()


@app.websocket("/ws")
async def ws_route(websocket: WebSocket, token: str | None = None) -> None:
    if token != "valid-session":
        raise WebSocketException(
            code=status.WS_1008_POLICY_VIOLATION,
            reason="Missing or invalid session token",
        )
    await websocket.accept()


client = TestClient(app)
with pytest.raises(WebSocketDisconnect) as exc_info:
    with client.websocket_connect("/ws"):
        pass
assert exc_info.value.code == status.WS_1008_POLICY_VIOLATION
```

---

## `class` ValidationException

Common base exception (`Exception`) for FastAPI request, WebSocket, and response validation failures. Stores the sequence of Pydantic/FastAPI error dictionaries alongside optional `endpoint_ctx` source metadata (`EndpointContext` with `function`, `path`, `file`, `line`) formatted into human-readable trace messages by `__str__()`.

```python
class ValidationException(Exception):
    def __init__(
        self,
        errors: Sequence[Any],
        *,
        endpoint_ctx: EndpointContext | None = None,
    ) -> None: ...

    def errors(self) -> Sequence[Any]: ...
```

### Parameters & Methods

| Member | Type / Signature | Description |
| :--- | :--- | :--- |
| `errors` | `Sequence[Any]` | Sequence of structured validation error dictionaries captured during parsing or serialization. |
| `endpoint_ctx` | `EndpointContext \| None` | Optional `TypedDict` recording `function`, `path`, `file`, and `line` for diagnostic tracebacks. |
| `errors()` | `def errors(self) -> Sequence[Any]` | Returns the underlying `Sequence[Any]` of structured validation errors. |

### Example

```python
from fastapi.exceptions import ValidationException

exc = ValidationException(
    [{"type": "int_parsing", "loc": ("query", "limit"), "msg": "Invalid integer"}],
    endpoint_ctx={
        "function": "list_users",
        "path": "GET /users",
        "file": "routes.py",
        "line": 42,
    },
)
assert len(exc.errors()) == 1
assert "GET /users" in str(exc)
assert 'File "routes.py", line 42, in list_users' in str(exc)
```

---

## `class` RequestValidationError

Subclass of `ValidationException` raised when an HTTP request's path parameters, query parameters, headers, cookies, form fields, or JSON body fail validation or JSON decoding. Carries the raw parsed `body` alongside `errors()` and is handled by `request_validation_exception_handler()` (`422 Unprocessable Content`) by default.

```python
class RequestValidationError(ValidationException):
    def __init__(
        self,
        errors: Sequence[Any],
        *,
        body: Any = None,
        endpoint_ctx: EndpointContext | None = None,
    ) -> None: ...
```

### Parameters & Attributes

| Member | Type / Signature | Description |
| :--- | :--- | :--- |
| `errors()` | `def errors(self) -> Sequence[Any]` | Inherited method returning the list of Pydantic/FastAPI validation error dicts (`loc`, `msg`, `type`, `input`). |
| `body` | `Any` | Parsed request payload (or raw document string on `JSONDecodeError`) attached to the exception (`None` when no body was parsed). |
| `endpoint_ctx` | `EndpointContext \| None` | Optional endpoint source metadata (`function`, `path`, `file`, `line`). |

### Example

```python
from pydantic import BaseModel

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.testclient import TestClient

app = FastAPI()


class OrderIn(BaseModel):
    quantity: int


@app.exception_handler(RequestValidationError)
async def custom_validation_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content={"error_count": len(exc.errors()), "received_body": exc.body},
    )


@app.post("/orders")
def create_order(order: OrderIn) -> OrderIn:
    return order


client = TestClient(app)
res = client.post("/orders", json={"quantity": "not-an-int"})
assert res.status_code == 422
assert res.json() == {"error_count": 1, "received_body": {"quantity": "not-an-int"}}
```

---

## `class` ResponseValidationError

Subclass of `ValidationException` raised when the value returned (or yielded in a typed stream) by a path operation fails `response_model` or return-type validation. Because response contract mismatches represent a server-side bug rather than client error, FastAPI lets `ResponseValidationError` propagate as an unhandled `500 Internal Server Error` unless explicitly caught.

```python
class ResponseValidationError(ValidationException):
    def __init__(
        self,
        errors: Sequence[Any],
        *,
        body: Any = None,
        endpoint_ctx: EndpointContext | None = None,
    ) -> None: ...
```

### Parameters & Attributes

| Member | Type / Signature | Description |
| :--- | :--- | :--- |
| `errors()` | `def errors(self) -> Sequence[Any]` | Returns the list of response schema validation errors (typically anchored at `loc=("response", ...)`). |
| `body` | `Any` | Raw unvalidated object returned or yielded by the endpoint function. |
| `endpoint_ctx` | `EndpointContext \| None` | Endpoint function, route path, file, and line metadata included in server logs. |

### Example

```python
import pytest
from pydantic import BaseModel

from fastapi import FastAPI
from fastapi.exceptions import ResponseValidationError
from fastapi.testclient import TestClient

app = FastAPI()


class UserOut(BaseModel):
    id: int


@app.get("/user", response_model=UserOut)
def read_broken_user() -> dict[str, str]:
    return {"id": "not-an-integer"}


client = TestClient(app)
with pytest.raises(ResponseValidationError) as exc_info:
    client.get("/user")
assert exc_info.value.body == {"id": "not-an-integer"}
assert exc_info.value.errors()[0]["loc"] == ("response", "id")
```

---

## `class` WebSocketRequestValidationError

Subclass of `ValidationException` raised when path, query, header, or cookie parameters declared on a `@app.websocket()` endpoint fail validation before entering the route body. Handled by `websocket_request_validation_exception_handler()` by default.

```python
class WebSocketRequestValidationError(ValidationException):
    def __init__(
        self,
        errors: Sequence[Any],
        *,
        endpoint_ctx: EndpointContext | None = None,
    ) -> None: ...
```

### Parameters & Methods

| Member | Type / Signature | Description |
| :--- | :--- | :--- |
| `errors()` | `def errors(self) -> Sequence[Any]` | Returns the list of validation error dictionaries collected while resolving WebSocket parameters. |
| `endpoint_ctx` | `EndpointContext \| None` | Optional WebSocket endpoint location metadata (`function`, `path`, `file`, `line`). |

### Example

```python
import pytest
from starlette.websockets import WebSocketDisconnect

from fastapi import FastAPI, WebSocket, status
from fastapi.testclient import TestClient

app = FastAPI()


@app.websocket("/rooms/{room_id}")
async def join_room(websocket: WebSocket, room_id: int) -> None:
    await websocket.accept()


client = TestClient(app)
with pytest.raises(WebSocketDisconnect) as exc_info:
    with client.websocket_connect("/rooms/not-an-int"):
        pass
assert exc_info.value.code == status.WS_1008_POLICY_VIOLATION
```

---

## `class` FastAPIError

Base `RuntimeError` subclass raised for framework configuration and route registration errors at application startup or route definition time (for example, invalid `response_model` types that cannot be converted into Pydantic fields, or unsupported Pydantic v1 models via `PydanticV1NotSupportedError`).

```python
class FastAPIError(RuntimeError): ...
```

### Inheritance

| Base Class | Known Subclasses | Typical Trigger |
| :--- | :--- | :--- |
| `RuntimeError` | `DependencyScopeError`, `PydanticV1NotSupportedError` | Invalid route annotations, non-Pydantic response field types without `response_model=None`, or invalid dependency scope graphs. |

### Example

```python
import pytest

from fastapi import FastAPI, Response
from fastapi.exceptions import FastAPIError

app = FastAPI()

with pytest.raises(FastAPIError):

    @app.get("/invalid-union")
    def bad_return_annotation() -> dict[str, str] | Response:
        return {"ok": "true"}
```

---

## `class` DependencyScopeError

Subclass of `FastAPIError` raised during dependency graph construction when a generator (`yield`) dependency with `scope="request"` declares a sub-dependency with narrower `scope="function"`. Prevents outer request-scoped teardown code from referencing resources that have already exited at function scope.

```python
class DependencyScopeError(FastAPIError): ...
```

### Scope Rule

| Parent `yield` Scope | Sub-dependency `scope` | Result |
| :--- | :--- | :--- |
| `"function"` | `"function"` or `"request"` | Valid — inner resource outlives or matches parent cleanup. |
| `"request"` | `"request"` | Valid — both exit stacks unwind after response transmission. |
| `"request"` | `"function"` | Raises `DependencyScopeError` at route registration time. |

### Example

```python
from collections.abc import Generator
from typing import Annotated
import pytest

from fastapi import Depends, FastAPI
from fastapi.exceptions import DependencyScopeError

app = FastAPI()


def inner_dep() -> Generator[str, None, None]:
    yield "inner"


def outer_dep(
    val: Annotated[str, Depends(inner_dep, scope="function")],
) -> Generator[str, None, None]:
    yield val


with pytest.raises(DependencyScopeError):

    @app.get("/scope-mismatch")
    def endpoint(res: Annotated[str, Depends(outer_dep, scope="request")]) -> str:
        return res
```

---

## `async def` http_exception_handler()

Built-in async HTTP exception handler imported from `fastapi.exception_handlers`. Converts a Starlette or FastAPI `HTTPException` into a `JSONResponse({"detail": exc.detail}, status_code=exc.status_code, headers=headers)`, or returns an empty `Response` when the HTTP status code forbids a message body (such as `204 No Content` or `304 Not Modified`).

```python
async def http_exception_handler(
    request: Request,
    exc: HTTPException,
) -> Response
```

### Parameters

| Parameter | Type | Description |
| :--- | :--- | :--- |
| `request` | `Request` | Active Starlette/FastAPI HTTP `Request` instance. |
| `exc` | `HTTPException` | Raised `HTTPException` carrying `status_code`, `detail`, and optional `headers`. |

### Example

```python
import asyncio
from starlette.requests import Request

from fastapi import HTTPException
from fastapi.exception_handlers import http_exception_handler

scope = {"type": "http", "method": "GET", "path": "/items", "headers": []}
req = Request(scope)

json_resp = asyncio.run(
    http_exception_handler(req, HTTPException(status_code=403, detail="Forbidden"))
)
assert json_resp.status_code == 403
assert json_resp.body == b'{"detail":"Forbidden"}'

empty_resp = asyncio.run(
    http_exception_handler(req, HTTPException(status_code=204))
)
assert empty_resp.status_code == 204
assert empty_resp.body == b""
```

---

## `async def` request_validation_exception_handler()

Built-in async handler imported from `fastapi.exception_handlers` for `RequestValidationError`. Serializes `exc.errors()` via `jsonable_encoder()` into a `422` `JSONResponse({"detail": ...})`; commonly delegated to at the end of custom `@app.exception_handler(RequestValidationError)` hooks after recording metrics or audit logs.

```python
async def request_validation_exception_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse
```

### Parameters

| Parameter | Type | Description |
| :--- | :--- | :--- |
| `request` | `Request` | Active HTTP `Request` that triggered validation failure. |
| `exc` | `RequestValidationError` | Validation exception exposing `exc.errors()` and `exc.body`. |

### Example

```python
import asyncio
import json
from starlette.requests import Request

from fastapi.exception_handlers import request_validation_exception_handler
from fastapi.exceptions import RequestValidationError

scope = {"type": "http", "method": "POST", "path": "/items", "headers": []}
exc = RequestValidationError(
    [{"loc": ("body", "price"), "msg": "Input should be a valid number", "type": "float_parsing"}]
)
resp = asyncio.run(request_validation_exception_handler(Request(scope), exc))
assert resp.status_code == 422
assert json.loads(resp.body) == {
    "detail": [
        {"loc": ["body", "price"], "msg": "Input should be a valid number", "type": "float_parsing"}
    ]
}
```

---

## `async def` websocket_request_validation_exception_handler()

Built-in async handler imported from `fastapi.exception_handlers` for `WebSocketRequestValidationError`. Closes the `WebSocket` connection with code `WS_1008_POLICY_VIOLATION` (`1008`) and passes `jsonable_encoder(exc.errors())` as the close reason.

```python
async def websocket_request_validation_exception_handler(
    websocket: WebSocket,
    exc: WebSocketRequestValidationError,
) -> None
```

### Parameters

| Parameter | Type | Description |
| :--- | :--- | :--- |
| `websocket` | `WebSocket` | Active FastAPI `WebSocket` connection being closed. |
| `exc` | `WebSocketRequestValidationError` | WebSocket parameter validation exception providing `exc.errors()`. |

### Example

```python
import asyncio
from typing import Any

from fastapi.exception_handlers import websocket_request_validation_exception_handler
from fastapi.exceptions import WebSocketRequestValidationError
from fastapi.websockets import WebSocket

sent_messages: list[dict[str, Any]] = []


async def receive() -> dict[str, Any]:
    return {"type": "websocket.connect"}


async def send(message: dict[str, Any]) -> None:
    sent_messages.append(message)


ws = WebSocket({"type": "websocket", "path": "/ws", "headers": []}, receive=receive, send=send)
exc = WebSocketRequestValidationError([{"loc": ("query", "room"), "msg": "Field required"}])
asyncio.run(websocket_request_validation_exception_handler(ws, exc))

assert sent_messages[0]["type"] == "websocket.close"
assert sent_messages[0]["code"] == 1008
```
