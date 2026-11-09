# fastapi.responses

`fastapi.responses` re-exports Starlette's ASGI response classes (`Response`, `JSONResponse`, `HTMLResponse`, `PlainTextResponse`, `RedirectResponse`, `StreamingResponse`, `FileResponse`) alongside FastAPI's legacy `@deprecated` JSON subclasses (`ORJSONResponse`, `UJSONResponse`). Path operations can return any `Response` instance directly or declare `response_class=...` on the route decorator to customize status codes, `Content-Type` headers, cookies, streaming chunks, and background tasks.

```drawlib align=center code=hide file=fastapi_responses_hierarchy.png caption="FastAPI Response Hierarchy, Default Media Types & Delivery Modes"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.lines import line
from drawlib.shapes import rectangle
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Colors, Styles
from drawlib.text import text

setup(width=184, height=62)

_ = Colors
rectangle((92, 51.5), width=98, height=10, style=Styles.PrimaryFlat.patch(shape_r=2.0))
phosphor.arrow_bend_up_left((49, 51.5), width=5.2, style=Styles.WhiteBold)
text(
    (95, 51.5),
    "Response (status_code, headers, set_cookie, background)",
    style=Styles.WhiteBold.patch(text_size=10.8),
)

line((92, 46.5), (92, 42.0), style=Styles.DarkBold.patch(line_width=1.6))
line((33, 42.0), (151, 42.0), style=Styles.DarkBold.patch(line_width=1.6))
for target_x in (33.0, 92.0, 151.0):
    line((target_x, 42.0), (target_x, 37.2), arrow_head="->", style=Styles.DarkBold.patch(line_width=1.5))

columns = [
    (
        (5.0, 5.5),
        "Formatted Payloads",
        Styles.PrimaryNeutral,
        phosphor.code,
        [
            "JSONResponse (application/json)",
            "HTMLResponse (text/html)",
            "PlainTextResponse (text/plain)",
        ],
    ),
    (
        (64.0, 5.5),
        "Redirect, Stream & File",
        Styles.Neutral,
        phosphor.file_arrow_down,
        [
            "RedirectResponse (307 Location)",
            "StreamingResponse (chunks)",
            "FileResponse (stat / Range)",
        ],
    ),
    (
        (123.0, 5.5),
        "Deprecated JSON",
        Styles.Neutral,
        phosphor.warning_circle,
        [
            "ORJSONResponse (@deprecated)",
            "UJSONResponse (@deprecated)",
            "Pydantic v2 return models",
        ],
    ),
]

for xy, title, body_style, icon_fn, items in columns:
    panel = Panel(
        title,
        "",
        style=body_style,
        header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
        text_style=Styles.DarkBold.patch(text_size=10.6),
        icon=icon_fn,
        icon_style=Styles.DarkBold,
        header_variant="filled",
        header_height=7.5,
    )
    panel.draw(xy, width=56.0, height=31.0, align="bottom_left")
    c_xy, c_w, c_h = panel.get_content_box(xy, width=56.0, height=31.0, padding=(2.5, 2.2))
    cards = CardList(
        style=Styles.White,
        text_style=Styles.DarkBold.patch(text_size=10.0),
        badge_style=Styles.SecondaryNeutral,
        badge_text_style=Styles.DarkBold.patch(text_size=10.0),
        spacing=1.5,
    )
    for idx, label in enumerate(items, start=1):
        cards.add(label, badge_text=str(idx))
    cards.draw(c_xy, width=c_w, height=c_h)

save()
```

---

## `class` Response

Base ASGI HTTP response class (`from fastapi import Response` or `from fastapi.responses import Response`). Encodes `str` or `bytes` payloads using `charset = "utf-8"`, computes `content-length` and `content-type` inside `raw_headers`, manages `Set-Cookie` headers via `set_cookie()` and `delete_cookie()`, and runs an optional `background` task after transmitting the response body.

```python
class Response:
    media_type: str | None = None
    charset: str = "utf-8"

    def __init__(
        self,
        content: Any = None,
        status_code: int = 200,
        headers: Mapping[str, str] | None = None,
        media_type: str | None = None,
        background: BackgroundTask | None = None,
    ) -> None: ...

    def set_cookie(
        self,
        key: str,
        value: str = "",
        max_age: int | None = None,
        expires: datetime | str | int | None = None,
        path: str | None = "/",
        domain: str | None = None,
        secure: bool = False,
        httponly: bool = False,
        samesite: Literal["lax", "strict", "none"] | None = "lax",
        partitioned: bool = False,
    ) -> None: ...

    def delete_cookie(
        self,
        key: str,
        path: str = "/",
        domain: str | None = None,
        secure: bool = False,
        httponly: bool = False,
        samesite: Literal["lax", "strict", "none"] | None = "lax",
        partitioned: bool = False,
    ) -> None: ...
```

### Parameters, Attributes & Methods

| Name | Kind | Type / Default | Description |
| :--- | :--- | :--- | :--- |
| `content` | Parameter | `Any = None` | `bytes`, `memoryview`, or `str` encoded via `render(content)` into `self.body`. |
| `status_code` | Param / Attr | `int = 200` | HTTP response status code sent in `http.response.start`. |
| `headers` | Param / Prop | `MutableHeaders` | Case-insensitive mutable view backed by `self.raw_headers`. |
| `raw_headers` | Attribute | `list[tuple[bytes, bytes]]` | Lowercased Latin-1 `(name, value)` byte pairs transmitted to the ASGI server. |
| `media_type` | Param / Attr | `str \| None = None` | MIME type used to populate `Content-Type` (`; charset=utf-8` appended automatically for `text/*`). |
| `background` | Param / Attr | `BackgroundTask \| None = None` | Starlette `BackgroundTask` / `BackgroundTasks` executed after `http.response.body` completes. |
| `set_cookie()` | Method | `None` | Appends a `Set-Cookie` header to `raw_headers` (harden session cookies with `__Host-` prefix, `secure=True`, `httponly=True`, and `samesite="lax"` or `"strict"`). |
| `delete_cookie()` | Method | `None` | Expires an existing cookie immediately by calling `set_cookie(..., max_age=0, expires=0)`. |

### Example

```python
import secrets

from fastapi import FastAPI, Response
from fastapi.testclient import TestClient

app = FastAPI()


@app.post("/auth/cookie-login")
def login_with_cookie(response: Response) -> dict[str, str]:
    session_token = secrets.token_urlsafe(24)
    response.status_code = 201
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.set_cookie(
        key="__Host-session",
        value=session_token,
        max_age=3600,
        path="/",
        secure=True,
        httponly=True,
        samesite="lax",
    )
    return {"status": "established"}


@app.post("/auth/cookie-logout")
def logout_cookie() -> Response:
    resp = Response(content=b"", status_code=204)
    resp.delete_cookie(key="__Host-session", path="/", secure=True, httponly=True)
    return resp


client = TestClient(app)
login_res = client.post("/auth/cookie-login")
assert login_res.status_code == 201
assert "HttpOnly" in login_res.headers["set-cookie"]
assert any(k == b"set-cookie" for k, _ in login_res.headers.raw)

logout_res = client.post("/auth/cookie-logout")
assert logout_res.status_code == 204
assert "Max-Age=0" in logout_res.headers["set-cookie"]
```

---

## `class` JSONResponse

Serializes Python data structures to UTF-8 JSON bytes using standard-library `json.dumps(..., ensure_ascii=False, allow_nan=False, separators=(",", ":"))` with default `media_type = "application/json"`. Useful when returning custom status codes or headers directly without a Pydantic model, or inside custom exception handlers (`@app.exception_handler`).

```python
class JSONResponse(Response):
    media_type = "application/json"

    def __init__(
        self,
        content: Any,
        status_code: int = 200,
        headers: Mapping[str, str] | None = None,
        media_type: str | None = None,
        background: BackgroundTask | None = None,
    ) -> None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `content` | `Any` | *(Required)* | JSON-serializable Python value (`dict`, `list`, `str`, `int`, `float`, `bool`, `None`; use `fastapi.encoders.jsonable_encoder` for `datetime`/`UUID`/`BaseModel`). |
| `status_code` | `int` | `200` | HTTP status code (e.g. `202`, `400`, `429`). |
| `headers` | `Mapping[str, str] \| None` | `None` | Additional HTTP response headers. |
| `media_type` | `str \| None` | `None` | Overrides default `"application/json"` (e.g. `"application/problem+json"`). |
| `background` | `BackgroundTask \| None` | `None` | Optional background task run after sending the response. |

### Example

```python
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.testclient import TestClient

app = FastAPI()


@app.post("/jobs")
def enqueue_job() -> JSONResponse:
    return JSONResponse(
        content={"job_id": "job-42", "state": "queued"},
        status_code=202,
        headers={"Cache-Control": "no-store"},
    )


client = TestClient(app)
res = client.post("/jobs")
assert res.status_code == 202
assert res.headers["content-type"] == "application/json"
assert res.headers["cache-control"] == "no-store"
assert res.json() == {"job_id": "job-42", "state": "queued"}
```

---

## `class` HTMLResponse

Renders UTF-8 HTML documents with `media_type = "text/html"` (`Content-Type: text/html; charset=utf-8`). Always escape untrusted user values via `html.escape()` or auto-escaping template engines (such as `Jinja2Templates`) and apply a strict `Content-Security-Policy` header.

```python
class HTMLResponse(Response):
    media_type = "text/html"

    def __init__(
        self,
        content: Any = None,
        status_code: int = 200,
        headers: Mapping[str, str] | None = None,
        media_type: str | None = None,
        background: BackgroundTask | None = None,
    ) -> None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `content` | `Any` | `None` | HTML `str` or `bytes` payload. |
| `status_code` | `int` | `200` | HTTP status code. |
| `headers` | `Mapping[str, str] \| None` | `None` | Security and caching HTTP headers (e.g. `Content-Security-Policy`, `X-Frame-Options`). |
| `media_type` | `str \| None` | `None` | Defaults to `"text/html"`. |
| `background` | `BackgroundTask \| None` | `None` | Optional post-response background task. |

### Example

```python
import html

from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from fastapi.testclient import TestClient

app = FastAPI()


@app.get("/welcome", response_class=HTMLResponse)
def welcome_page(name: str = "Developer") -> HTMLResponse:
    safe_name = html.escape(name, quote=True)
    body = f"<!doctype html><html><body><h1>Hello, {safe_name}</h1></body></html>"
    return HTMLResponse(
        content=body,
        headers={
            "Content-Security-Policy": "default-src 'self'; object-src 'none'",
            "X-Content-Type-Options": "nosniff",
        },
    )


client = TestClient(app)
res = client.get("/welcome", params={"name": "<Admin>"})
assert res.status_code == 200
assert "text/html" in res.headers["content-type"]
assert "&lt;Admin&gt;" in res.text
```

---

## `class` PlainTextResponse

Returns unformatted UTF-8 plain text with `media_type = "text/plain"` (`Content-Type: text/plain; charset=utf-8`), ideal for `/robots.txt`, Prometheus metrics, health probes, or raw log excerpts.

```python
class PlainTextResponse(Response):
    media_type = "text/plain"

    def __init__(
        self,
        content: Any = None,
        status_code: int = 200,
        headers: Mapping[str, str] | None = None,
        media_type: str | None = None,
        background: BackgroundTask | None = None,
    ) -> None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `content` | `Any` | `None` | Plain-text `str` or `bytes` body. |
| `status_code` | `int` | `200` | HTTP status code. |
| `headers` | `Mapping[str, str] \| None` | `None` | Optional HTTP headers. |
| `media_type` | `str \| None` | `None` | Defaults to `"text/plain"`. |
| `background` | `BackgroundTask \| None` | `None` | Optional post-response background task. |

### Example

```python
from fastapi import FastAPI
from fastapi.responses import PlainTextResponse
from fastapi.testclient import TestClient

app = FastAPI()


@app.get("/robots.txt", response_class=PlainTextResponse)
def robots_txt() -> str:
    return "User-agent: *\nDisallow: /admin/"


client = TestClient(app)
res = client.get("/robots.txt")
assert res.status_code == 200
assert res.headers["content-type"] == "text/plain; charset=utf-8"
assert res.text.startswith("User-agent: *")
```

---

## `class` RedirectResponse

Issues an HTTP redirect by setting the `Location` response header to `url` (URL-quoting safe characters automatically). Defaults to `status_code = 307` (`Temporary Redirect`, preserving the original HTTP method and body); pass `status_code = 303` (`See Other`) when redirecting a `POST` form submission to a `GET` confirmation page.

```python
class RedirectResponse(Response):
    def __init__(
        self,
        url: str | URL,
        status_code: int = 307,
        headers: Mapping[str, str] | None = None,
        background: BackgroundTask | None = None,
    ) -> None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `url` | `str \| starlette.datastructures.URL` | *(Required)* | Target redirect destination placed in the `Location` header (validate against an allow-list if derived from user input). |
| `status_code` | `int` | `307` | Redirect status (`301`, `302`, `303`, `307`, or `308`). |
| `headers` | `Mapping[str, str] \| None` | `None` | Additional HTTP headers included with the redirect response. |
| `background` | `BackgroundTask \| None` | `None` | Optional post-response background task. |

### Example

```python
from fastapi import FastAPI
from fastapi.responses import RedirectResponse
from fastapi.testclient import TestClient

app = FastAPI()


@app.get("/v1/docs-legacy")
def legacy_redirect() -> RedirectResponse:
    return RedirectResponse(url="/v2/reference", status_code=308)


client = TestClient(app)
res = client.get("/v1/docs-legacy", follow_redirects=False)
assert res.status_code == 308
assert res.headers["location"] == "/v2/reference"
```

---

## `class` StreamingResponse

Streams response chunks incrementally from an async iterator (`AsyncIterable[bytes | str]`) or sync iterator (`Iterable[bytes | str]`) without buffering the full payload in memory, while concurrently monitoring `http.disconnect` to cancel generation if the client disconnects early.

```python
class StreamingResponse(Response):
    body_iterator: AsyncIterable[bytes]

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
| `content` | `AsyncIterable[str \| bytes \| memoryview] \| Iterable[str \| bytes \| memoryview]` | *(Required)* | Sync or async generator yielding chunks (strings are encoded using `charset = "utf-8"`). |
| `status_code` | `int` | `200` | HTTP status code. |
| `headers` | `Mapping[str, str] \| None` | `None` | Optional HTTP headers (e.g. `Content-Disposition` for streamed exports). |
| `media_type` | `str \| None` | `None` | MIME type such as `"application/x-ndjson"` or `"text/csv"`. |
| `background` | `BackgroundTask \| None` | `None` | Optional cleanup task executed after the stream finishes. |

### Example

```python
from collections.abc import AsyncIterator
import json

from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from fastapi.testclient import TestClient

app = FastAPI()


async def generate_ndjson() -> AsyncIterator[bytes]:
    for idx in range(1, 4):
        yield (json.dumps({"row": idx}) + "\n").encode("utf-8")


@app.get("/exports/events.ndjson")
def export_events() -> StreamingResponse:
    return StreamingResponse(
        generate_ndjson(),
        media_type="application/x-ndjson",
        headers={"X-Content-Type-Options": "nosniff"},
    )


client = TestClient(app)
res = client.get("/exports/events.ndjson")
lines = [json.loads(line) for line in res.text.strip().splitlines()]
assert res.status_code == 200
assert res.headers["content-type"] == "application/x-ndjson"
assert lines == [{"row": 1}, {"row": 2}, {"row": 3}]
```

---

## `class` FileResponse

Asynchronously streams a file from the filesystem in `64 KiB` chunks (`chunk_size = 64 * 1024`), automatically computing `Content-Length`, `Last-Modified`, `ETag`, MIME `Content-Type` (via `mimetypes.guess_type`), `Content-Disposition`, and HTTP `Range` / `206 Partial Content` responses. Always resolve paths and verify directory boundaries before passing user-influenced filenames to `FileResponse`.

```python
class FileResponse(Response):
    chunk_size = 64 * 1024

    def __init__(
        self,
        path: str | os.PathLike[str],
        status_code: int = 200,
        headers: Mapping[str, str] | None = None,
        media_type: str | None = None,
        background: BackgroundTask | None = None,
        filename: str | None = None,
        stat_result: os.stat_result | None = None,
        content_disposition_type: str = "attachment",
    ) -> None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `path` | `str \| os.PathLike[str]` | *(Required)* | Verified filesystem path to the target file. |
| `status_code` | `int` | `200` | HTTP status code (`206` automatically used for valid `Range` requests). |
| `headers` | `Mapping[str, str] \| None` | `None` | Additional HTTP headers (e.g. `X-Content-Type-Options: nosniff`). |
| `media_type` | `str \| None` | `None` | Explicit MIME type; inferred from `filename` or `path` when `None` (falls back to `"text/plain"`). |
| `background` | `BackgroundTask \| None` | `None` | Optional background task (useful for deleting temporary export files after delivery). |
| `filename` | `str \| None` | `None` | When set, populates `Content-Disposition: <content_disposition_type>; filename="<filename>"`. |
| `stat_result` | `os.stat_result \| None` | `None` | Optional pre-fetched `os.stat()` result; fetched asynchronously via `anyio.to_thread` if `None`. |
| `content_disposition_type` | `str` | `"attachment"` | Disposition mode (`"attachment"` forces download when `filename` is set; `"inline"` displays in browser). |

### Example

```python
from pathlib import Path
import tempfile

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.testclient import TestClient

with tempfile.TemporaryDirectory() as tmp_dir:
    export_root = Path(tmp_dir).resolve()
    report_path = export_root / "summary.csv"
    report_path.write_text("id,total\n1,42\n", encoding="utf-8")

    app = FastAPI()

    @app.get("/downloads/{report_name}")
    def download_report(report_name: str) -> FileResponse:
        safe_name = Path(report_name).name
        candidate = (export_root / safe_name).resolve()
        if not candidate.is_relative_to(export_root) or not candidate.is_file():
            raise HTTPException(status_code=404, detail="Report not found")
        return FileResponse(
            path=candidate,
            filename=safe_name,
            media_type="text/csv",
            content_disposition_type="attachment",
            headers={"X-Content-Type-Options": "nosniff"},
        )

    client = TestClient(app)
    res = client.get("/downloads/summary.csv")
    assert res.status_code == 200
    assert 'attachment; filename="summary.csv"' in res.headers["content-disposition"]
    assert "etag" in res.headers
    assert res.text == "id,total\n1,42\n"
```

---

## `deprecated` ORJSONResponse

> [!WARNING]
> **Deprecated in FastAPI (`FastAPIDeprecationWarning`)**: `ORJSONResponse` is decorated with `@deprecated(...)` in `v0.162.2`. When a path operation declares a Pydantic return type annotation (`-> Item` or `-> list[Item]`) or `response_model=...`, FastAPI now serializes data directly to JSON `bytes` inside Pydantic v2's Rust core (`pydantic-core`), which is faster and requires no third-party response subclass.

Legacy `JSONResponse` subclass (`from fastapi.responses import ORJSONResponse`) that delegates `render()` to `orjson.dumps(content, option=orjson.OPT_NON_STR_KEYS | orjson.OPT_SERIALIZE_NUMPY)`. Requires installing `orjson` separately (`pip install orjson`).

```python
@deprecated(..., category=FastAPIDeprecationWarning)
class ORJSONResponse(JSONResponse):
    media_type = "application/json"

    def render(self, content: Any) -> bytes: ...
```

### Migration Details

| Aspect | Legacy `ORJSONResponse` | Recommended `v0.162.2` Pattern |
| :--- | :--- | :--- |
| Deprecation Warning | Emits `FastAPIDeprecationWarning` on instantiation / subclassing | Zero warnings |
| Extra Package | Requires `orjson` installed separately | Built into `pydantic-core` (Rust) |
| Route Signature | `@app.get("/items", response_class=ORJSONResponse)` | `@app.get("/items") def list_items() -> list[Item]:` |

### Example

```python
from fastapi import FastAPI
from fastapi.responses import JSONResponse, ORJSONResponse
from fastapi.testclient import TestClient
from pydantic import BaseModel

assert issubclass(ORJSONResponse, JSONResponse)
assert "ORJSONResponse is deprecated" in getattr(ORJSONResponse, "__deprecated__", "")


class MetricOut(BaseModel):
    service: str
    latency_ms: float


app = FastAPI()


@app.get("/metrics/fast")
def get_fast_metrics() -> list[MetricOut]:
    # Serialized directly to JSON bytes by Pydantic v2's Rust serializer
    return [MetricOut(service="gateway", latency_ms=1.4)]


client = TestClient(app)
res = client.get("/metrics/fast")
assert res.status_code == 200
assert res.json() == [{"service": "gateway", "latency_ms": 1.4}]
```

---

## `deprecated` UJSONResponse

> [!WARNING]
> **Deprecated in FastAPI (`FastAPIDeprecationWarning`)**: `UJSONResponse` is decorated with `@deprecated(...)` in `v0.162.2`. FastAPI serializes validated return models directly to JSON bytes via Pydantic v2's Rust engine without needing `ujson` or a custom response class.

Legacy `JSONResponse` subclass (`from fastapi.responses import UJSONResponse`) that renders payloads using `ujson.dumps(content, ensure_ascii=False).encode("utf-8")`. Requires installing `ujson` separately (`pip install ujson`) and lacks several edge-case IEEE-754 / Unicode guarantees provided by `pydantic-core` and standard `JSONResponse`.

```python
@deprecated(..., category=FastAPIDeprecationWarning)
class UJSONResponse(JSONResponse):
    media_type = "application/json"

    def render(self, content: Any) -> bytes: ...
```

### Migration Details

| Aspect | Legacy `UJSONResponse` | Recommended `v0.162.2` Pattern |
| :--- | :--- | :--- |
| Deprecation Warning | Emits `FastAPIDeprecationWarning` on instantiation / subclassing | Zero warnings |
| Extra Package | Requires `ujson` installed separately | Built into `pydantic-core` (Rust) |
| Route Signature | `@app.get("/users", response_class=UJSONResponse)` | `@app.get("/users", response_model=list[UserOut])` |

### Example

```python
from fastapi import FastAPI
from fastapi.responses import JSONResponse, UJSONResponse
from fastapi.testclient import TestClient
from pydantic import BaseModel

assert issubclass(UJSONResponse, JSONResponse)
assert "UJSONResponse is deprecated" in getattr(UJSONResponse, "__deprecated__", "")


class UserSummary(BaseModel):
    username: str
    active: bool


app = FastAPI()


@app.get("/users/summary", response_model=UserSummary)
def get_user_summary() -> dict[str, object]:
    return {"username": "alice", "active": True}


client = TestClient(app)
res = client.get("/users/summary")
assert res.status_code == 200
assert res.json() == {"username": "alice", "active": True}
```
