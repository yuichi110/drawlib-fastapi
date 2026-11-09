# fastapi.datastructures

Spooled file upload wrapper, immutable ASGI request containers, mutable application/request state namespace, and default-override sentinel helpers imported from `fastapi.datastructures` (`UploadFile`, `URL`, `Headers`, `QueryParams`, `FormData`, `State`, `Address`, `Default()`, and `DefaultPlaceholder`).

```drawlib align=center code=hide file=fastapi_datastructures_map.png caption="FastAPI Request Data Structures, Spooled UploadFile Lifecycle, State, and Default Sentinels"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Colors, Styles

setup(width=162, height=62)

_ = Colors

upload_panel = Panel(
    "UploadFile",
    description="",
    style=Styles.PrimaryNeutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.0),
    icon=phosphor.file_arrow_up,
    icon_style=Styles.WhiteBold,
    header_variant="filled",
    header_height=8.5,
)
upload_panel.draw((5.0, 5.0), width=48.0, height=52.0)
u_xy, u_w, u_h = upload_panel.get_content_box((5.0, 5.0), width=48.0, height=52.0, padding=(3.0, 2.8))

upload_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.PrimaryFlat,
    badge_text_style=Styles.WhiteBold.patch(text_size=10.0),
    spacing=2.0,
)
upload_cards.add("Spooled File", "RAM to temp disk", badge_text="1")
upload_cards.add("Metadata", "filename, size, headers", badge_text="2")
upload_cards.add("Async I/O", "read, write, seek, close", badge_text="3")
upload_cards.draw(u_xy, width=u_w, height=u_h)

req_panel = Panel(
    "Request Containers",
    description="",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.cube,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.5,
)
req_panel.draw((57.0, 5.0), width=48.0, height=52.0)
r_xy, r_w, r_h = req_panel.get_content_box((57.0, 5.0), width=48.0, height=52.0, padding=(3.0, 2.8))

req_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.SecondaryNeutral,
    icon_style=Styles.DarkBold,
    spacing=2.0,
)
req_cards.add("URL & Address", "Components & host:port", icon=phosphor.link)
req_cards.add("Headers & QueryParams", "Case-folded & multi-dict", icon=phosphor.list_bullets)
req_cards.add("FormData", "Fields + UploadFile items", icon=phosphor.file_text)
req_cards.draw(r_xy, width=r_w, height=r_h)

state_panel = Panel(
    "State & Sentinels",
    description="",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.sliders,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.5,
)
state_panel.draw((109.0, 5.0), width=48.0, height=52.0)
s_xy, s_w, s_h = state_panel.get_content_box((109.0, 5.0), width=48.0, height=52.0, padding=(3.0, 2.8))

state_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.SecondaryNeutral,
    icon_style=Styles.DarkBold,
    spacing=2.0,
)
state_cards.add("State", "Mutable app/request attrs", icon=phosphor.database)
state_cards.add("Default(value)", "Typed sentinel factory", icon=phosphor.tag)
state_cards.add("DefaultPlaceholder", "Detects overridden values", icon=phosphor.gear)
state_cards.draw(s_xy, width=s_w, height=s_h)

save()
```

---

## `class` UploadFile

Multipart file upload wrapper subclassing `starlette.datastructures.UploadFile` with Pydantic v2 core and OpenAPI binary schema hooks (`type: "string"`, `contentMediaType: "application/octet-stream"`). Uses a `SpooledTemporaryFile` held in memory up to the spool threshold before spilling to disk, exposes async threadpool-backed file methods alongside the underlying synchronous `file` handle, and is automatically closed after the request via `AsyncExitStackMiddleware`.

```python
class UploadFile(StarletteUploadFile):
    file: BinaryIO
    filename: str | None
    size: int | None
    headers: Headers
    content_type: str | None

    def __init__(
        self,
        file: BinaryIO,
        *,
        size: int | None = None,
        filename: str | None = None,
        headers: Headers | None = None,
    ) -> None: ...

    async def write(self, data: bytes) -> None: ...
    async def read(self, size: int = -1) -> bytes: ...
    async def seek(self, offset: int) -> None: ...
    async def close(self) -> None: ...
```

### Attributes & Methods

| Member | Signature / Type | Description |
| :--- | :--- | :--- |
| `filename` | `str \| None` | Original client-supplied filename from the multipart `Content-Disposition` header; treat as untrusted input and never pass directly into filesystem paths. |
| `content_type` | `str \| None` | MIME media type extracted from the part's `Content-Type` header (for example, `"application/pdf"` or `"image/png"`). |
| `file` | `BinaryIO` | Underlying standard Python file-like object (`SpooledTemporaryFile`) for synchronous `def` endpoints or libraries requiring a blocking `BinaryIO`. |
| `headers` | `Headers` | Case-insensitive `Headers` mapping associated with the multipart upload part. |
| `size` | `int \| None` | Total uploaded payload size in bytes calculated by the multipart parser. |
| `read()` | `async def read(self, size: int = -1) -> bytes` | Reads up to `size` bytes (or the remaining stream when `-1`) in a worker threadpool. |
| `write()` | `async def write(self, data: bytes) -> None` | Writes `data` bytes to the underlying file object via a worker threadpool. |
| `seek()` | `async def seek(self, offset: int) -> None` | Repositions the file cursor to byte `offset` via a worker threadpool (for example, `await file.seek(0)` to rewind). |
| `close()` | `async def close(self) -> None` | Flushes and closes the underlying temporary file handle via a worker threadpool. |

### Example

```python
import uuid

from fastapi import FastAPI, HTTPException, UploadFile
from fastapi.testclient import TestClient

app = FastAPI()
ALLOWED_TYPES = {"application/pdf": b"%PDF-", "image/png": b"\x89PNG\r\n\x1a\n"}
MAX_UPLOAD_BYTES = 1_048_576


@app.post("/documents")
async def inspect_document(upload: UploadFile) -> dict[str, str | int]:
    magic = ALLOWED_TYPES.get(upload.content_type or "")
    if magic is None:
        raise HTTPException(status_code=415, detail="Unsupported media type")
    header = await upload.read(len(magic))
    if header != magic:
        raise HTTPException(status_code=400, detail="Invalid file signature")
    await upload.seek(0)
    payload = await upload.read(MAX_UPLOAD_BYTES + 1)
    if len(payload) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="File exceeds size limit")
    return {"storage_key": f"{uuid.uuid4().hex}.bin", "bytes": len(payload)}


client = TestClient(app)
res = client.post(
    "/documents",
    files={"upload": ("report.pdf", b"%PDF-1.7 sample", "application/pdf")},
)
assert res.status_code == 200
assert res.json()["bytes"] == 15
```

---

## `class` URL

Immutable URL value object re-exported from `starlette.datastructures.URL` and exposed via `request.url` and `websocket.url`. Parses scheme, host, port, path, and query components lazily and returns new `URL` instances from query/component transformation methods without mutating the original request URL.

```python
class URL:
    def __init__(
        self,
        url: str = "",
        scope: Scope | None = None,
        **components: Any,
    ) -> None: ...
```

### Properties & Methods

| Member | Type / Signature | Description |
| :--- | :--- | :--- |
| `scheme`, `netloc`, `path` | `str` | URL protocol scheme (`"http"`, `"https"`, `"ws"`, `"wss"`), network location (`host:port`), and decoded path string. |
| `query`, `fragment` | `str` | Raw URL query string (without `?`) and fragment identifier (without `#`). |
| `hostname`, `port` | `str \| None`, `int \| None` | Parsed lowercase hostname and explicit port number (`None` when using the scheme's default port). |
| `username`, `password` | `str \| None` | Optional userinfo credentials parsed from the authority component. |
| `is_secure` | `bool` | Returns `True` when `scheme` is `"https"` or `"wss"`. |
| `replace()` | `replace(**kwargs: Any) -> URL` | Returns a new `URL` with specified `scheme`, `hostname`, `port`, `path`, `query`, or `fragment` components replaced. |
| `include_query_params()` | `include_query_params(**kwargs: Any) -> URL` | Merges or overwrites individual query keys and returns the updated `URL`. |
| `replace_query_params()` | `replace_query_params(**kwargs: Any) -> URL` | Replaces the entire query string with `kwargs` and returns the updated `URL`. |
| `remove_query_params()` | `remove_query_params(keys: str \| Sequence[str]) -> URL` | Removes one or more query parameter names and returns the updated `URL`. |

### Example

```python
from fastapi.datastructures import URL

base = URL("https://api.example.com:8443/v1/items?page=1&tag=core")
assert base.is_secure is True
assert base.hostname == "api.example.com"
assert base.port == 8443

next_url = base.include_query_params(page=2).remove_query_params("tag")
assert str(next_url) == "https://api.example.com:8443/v1/items?page=2"
```

---

## `class` Headers

Case-insensitive, immutable HTTP header mapping re-exported from `starlette.datastructures.Headers` and exposed on `request.headers`, `websocket.headers`, and `upload_file.headers`. Preserves duplicate header lines in `raw` and supports multi-value retrieval via `getlist()`.

```python
class Headers(Mapping[str, str]):
    def __init__(
        self,
        headers: Mapping[str, str] | None = None,
        raw: list[tuple[bytes, bytes]] | None = None,
        scope: MutableMapping[str, Any] | None = None,
    ) -> None: ...
```

### Parameters & Methods

| Member | Type / Signature | Description |
| :--- | :--- | :--- |
| `headers` | `Mapping[str, str] \| None` | Optional string dictionary encoded into lowercase Latin-1 header pairs. |
| `raw` | `list[tuple[bytes, bytes]]` | Underlying ASGI list of `(lowercase_name_bytes, value_bytes)` tuples. |
| `scope` | `MutableMapping[str, Any] \| None` | Optional ASGI scope dictionary containing `"headers"`. |
| `getlist()` | `getlist(key: str) -> list[str]` | Returns all header values matching `key` (case-insensitive) in wire order. |
| `mutablecopy()` | `mutablecopy() -> MutableHeaders` | Returns a mutable `MutableHeaders` copy suitable for modifying outgoing headers. |

### Example

```python
from fastapi.datastructures import Headers

headers = Headers(
    raw=[
        (b"x-request-id", b"req-77"),
        (b"accept", b"application/json"),
        (b"accept", b"text/event-stream"),
    ]
)
assert headers["X-Request-ID"] == "req-77"
assert headers.getlist("Accept") == ["application/json", "text/event-stream"]
```

---

## `class` QueryParams

Immutable multi-dict mapping for URL query strings re-exported from `starlette.datastructures.QueryParams` and exposed via `request.query_params` and `websocket.query_params`. Indexing `params[key]` returns the last value for `key`, whereas `getlist(key)` and `multi_items()` preserve all repeated occurrences.

```python
class QueryParams(ImmutableMultiDict[str, str]):
    def __init__(
        self,
        *args: ImmutableMultiDict[Any, Any]
        | Mapping[Any, Any]
        | list[tuple[Any, Any]]
        | str
        | bytes,
        **kwargs: Any,
    ) -> None: ...
```

### Methods

| Method | Signature | Description |
| :--- | :--- | :--- |
| `get()` | `get(key: str, default: Any = None) -> str \| Any` | Returns a single string value for `key`, or `default` if absent. |
| `getlist()` | `getlist(key: str) -> list[str]` | Returns all string values bound to repeated occurrences of `key`. |
| `multi_items()` | `multi_items() -> list[tuple[str, str]]` | Returns every `(key, value)` pair in query-string order, including duplicates. |

### Example

```python
from fastapi.datastructures import QueryParams

params = QueryParams("tag=python&tag=async&limit=20")
assert params["limit"] == "20"
assert params.getlist("tag") == ["python", "async"]
assert ("tag", "python") in params.multi_items()
```

---

## `class` FormData

Immutable multi-dict mapping for parsed `application/x-www-form-urlencoded` and `multipart/form-data` payloads, re-exported from `starlette.datastructures.FormData` and returned by `await request.form()`. Stores text fields (`str`) alongside uploaded files (`UploadFile`) and provides an async `close()` method to release all temporary file handles.

```python
class FormData(ImmutableMultiDict[str, str | UploadFile]):
    def __init__(
        self,
        *args: FormData
        | Mapping[str, str | UploadFile]
        | list[tuple[str, str | UploadFile]],
        **kwargs: str | UploadFile,
    ) -> None: ...

    async def close(self) -> None: ...
```

### Methods

| Method | Signature | Description |
| :--- | :--- | :--- |
| `getlist()` | `getlist(key: str) -> list[str \| UploadFile]` | Returns all text fields or `UploadFile` items submitted under `key`. |
| `multi_items()` | `multi_items() -> list[tuple[str, str \| UploadFile]]` | Returns all `(field_name, value)` pairs in submission order. |
| `close()` | `async def close(self) -> None` | Awaits `.close()` on every `UploadFile` value stored inside the form container. |

### Example

```python
import asyncio
import io

from fastapi.datastructures import FormData, UploadFile

upload = UploadFile(file=io.BytesIO(b"hello"), filename="note.txt")
form = FormData([("title", "Quarterly Report"), ("tag", "q1"), ("tag", "finance"), ("file", upload)])

assert form["title"] == "Quarterly Report"
assert form.getlist("tag") == ["q1", "finance"]
asyncio.run(form.close())
```

---

## `class` State

Dynamic attribute container re-exported from `starlette.datastructures.State` and attached to `app.state` (application lifespan scope) and `request.state` / `websocket.state` (per-connection scope). Supports arbitrary attribute assignment, deletion, and `AttributeError` lookup semantics backed by an internal dictionary.

```python
class State:
    def __init__(self, state: dict[str, Any] | None = None) -> None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `state` | `dict[str, Any] \| None` | `None` | Optional initial dictionary backing attribute lookups on the `State` instance. |

### Example

```python
from contextlib import asynccontextmanager
from collections.abc import AsyncIterator

from fastapi import FastAPI, Request
from fastapi.testclient import TestClient


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    app.state.region = "us-east1"
    yield


app = FastAPI(lifespan=lifespan)


@app.get("/region")
def read_region(request: Request) -> dict[str, str]:
    return {"region": request.app.state.region}


with TestClient(app) as client:
    assert client.get("/region").json() == {"region": "us-east1"}
```

---

## `class` Address

Immutable `NamedTuple` (`(host, port)`) re-exported from `starlette.datastructures.Address` and returned by `request.client` and `websocket.client` when the ASGI server populates `scope["client"]`. Note that `request.client` may be `None` when connected over Unix domain sockets or synthetic test scopes.

```python
class Address(NamedTuple):
    host: str
    port: int
```

### Fields

| Field | Type | Description |
| :--- | :--- | :--- |
| `host` | `str` | Client IPv4/IPv6 address or hostname string reported by the ASGI server. |
| `port` | `int` | Client TCP source port reported by the ASGI server. |

### Example

```python
from fastapi.datastructures import Address

addr = Address(host="127.0.0.1", port=54321)
assert addr.host == "127.0.0.1"
assert addr.port == 54321
assert tuple(addr) == ("127.0.0.1", 54321)
```

---

## `def` Default()

Internal sentinel factory that wraps a default `value` inside a `DefaultPlaceholder` while preserving static return type `DefaultType` for type checkers. FastAPI uses `Default(...)` across `FastAPI`, `APIRouter`, and `APIRoute` signatures (such as `response_class: type[Response] = Default(JSONResponse)`) so router-level or app-level defaults can cascade unless explicitly overridden at the route level.

```python
def Default(value: DefaultType) -> DefaultType
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `value` | `DefaultType` | *(Required)* | Fallback default value wrapped inside `DefaultPlaceholder(value)`. |

### Example

```python
from fastapi.datastructures import Default, DefaultPlaceholder
from fastapi.responses import JSONResponse

sentinel = Default(JSONResponse)
assert isinstance(sentinel, DefaultPlaceholder)
assert sentinel.value is JSONResponse
```

---

## `class` DefaultPlaceholder

Internal wrapper class returned by `Default(value)` to distinguish an untouched framework default from an explicitly supplied caller argument, even when the default is truthy. Evaluates truthiness via `bool(self.value)` and compares equal only to another `DefaultPlaceholder` wrapping an equal `.value`.

```python
class DefaultPlaceholder:
    def __init__(self, value: Any) -> None: ...
    def __bool__(self) -> bool: ...
    def __eq__(self, o: object) -> bool: ...
```

### Attributes & Dunder Behavior

| Member | Signature / Type | Description |
| :--- | :--- | :--- |
| `value` | `Any` | Underlying default object wrapped by the placeholder. |
| `__bool__()` | `def __bool__(self) -> bool` | Delegates truthiness checks to `bool(self.value)`. |
| `__eq__()` | `def __eq__(self, o: object) -> bool` | Returns `True` only when `o` is a `DefaultPlaceholder` and `o.value == self.value`. |

### Example

```python
from fastapi.datastructures import DefaultPlaceholder

truthy_default = DefaultPlaceholder(True)
empty_default = DefaultPlaceholder("")

assert bool(truthy_default) is True
assert bool(empty_default) is False
assert truthy_default == DefaultPlaceholder(True)
assert truthy_default != True  # noqa: E712
```
