# fastapi.middleware

Built-in ASGI security, origin policy, compression, TLS redirection, and request file cleanup middleware classes imported from `fastapi.middleware.*` and registered via `app.add_middleware()`. FastAPI composes user-registered middlewares in reverse registration order outside `ExceptionMiddleware` and `AsyncExitStackMiddleware`.

```drawlib align=center code=hide file=fastapi_middleware_catalog.png caption="FastAPI Built-in ASGI Middleware Pipeline Registered via app.add_middleware()"
from drawlib.canvas import save, setup
from drawlib.diagrams.architecture import ArchitectureDiagram, Node, NodeGroup, PhosphorIcon
from drawlib.styles import Colors, Styles

setup(width=160, height=64)

_ = Colors
d = ArchitectureDiagram(
    node_style=Styles.Dark,
    node_text_style=Styles.DarkBold.patch(text_size=10.0),
    edge_style=Styles.Dark.patch(line_width=1.5),
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
)

client = d.add(
    Node(
        "ASGI Client\n(HTTP / WS)",
        icon=PhosphorIcon.GLOBE,
        width=26,
        height=15,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(18, 40),
)

stack = d.add(
    NodeGroup(
        "FastAPI Middleware Stack (fastapi.middleware)",
        width=114,
        height=54,
        style=Styles.SecondaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left", valign="top"),
    ),
    xy=(41, 5),
)

https_mw = stack.add(
    Node(
        "HTTPSRedirect\nMiddleware",
        icon=PhosphorIcon.LOCK,
        width=28,
        height=15,
        card_style=Styles.Neutral,
    ),
    xy=(20, 35),
)
host_mw = stack.add(
    Node(
        "TrustedHost\nMiddleware",
        icon=PhosphorIcon.SHIELD_CHECK,
        width=28,
        height=15,
        card_style=Styles.Neutral,
    ),
    xy=(57, 35),
)
cors_mw = stack.add(
    Node(
        "CORSMiddleware",
        icon=PhosphorIcon.ARROWS_LEFT_RIGHT,
        width=28,
        height=15,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
        card_style=Styles.PrimaryFlat,
    ),
    xy=(94, 35),
)
gzip_mw = stack.add(
    Node(
        "GZipMiddleware",
        icon=PhosphorIcon.FILE_ZIP,
        width=28,
        height=15,
        card_style=Styles.Neutral,
    ),
    xy=(94, 12),
)
exit_mw = stack.add(
    Node(
        "AsyncExitStack\nMiddleware",
        icon=PhosphorIcon.STACK,
        width=28,
        height=15,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(57, 12),
)
router = stack.add(
    Node(
        "FastAPI Router\n& Endpoints",
        icon=PhosphorIcon.CODE,
        width=28,
        height=15,
        card_style=Styles.Neutral,
    ),
    xy=(20, 12),
)

client.connect(https_mw, padding=1.2)
https_mw.connect(host_mw, padding=1.0)
host_mw.connect(cors_mw, padding=1.0)
cors_mw.connect(gzip_mw, padding=1.0)
gzip_mw.connect(exit_mw, padding=1.0)
exit_mw.connect(router, padding=1.0)

d.draw(xy=(0, 0))
save()
```

---

## `class` CORSMiddleware

Cross-Origin Resource Sharing (CORS) middleware imported from `fastapi.middleware.cors` (re-exporting `starlette.middleware.cors.CORSMiddleware`). Evaluates browser `Origin` headers, answers `OPTIONS` preflight requests, and attaches `Access-Control-*` response headers. Always declare an explicit HTTPS origin allow-list when enabling `allow_credentials=True` — never combine `allow_origins=["*"]` with `allow_credentials=True`.

```python
class CORSMiddleware:
    def __init__(
        self,
        app: ASGIApp,
        allow_origins: Collection[str] = (),
        allow_methods: Collection[str] = ("GET",),
        allow_headers: Collection[str] = (),
        allow_credentials: bool = False,
        allow_origin_regex: str | None = None,
        allow_private_network: bool = False,
        expose_headers: Collection[str] = (),
        max_age: int = 600,
    ) -> None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `app` | `ASGIApp` | *(Required)* | Next ASGI application in the middleware chain (supplied automatically by `app.add_middleware()`). |
| `allow_origins` | `Collection[str]` | `()` | Explicit allow-list of permitted browser origins (for example, `["https://app.example.com"]`). Must list concrete origins when `allow_credentials=True`. |
| `allow_methods` | `Collection[str]` | `("GET",)` | HTTP methods allowed for cross-origin requests (prefer explicit lists such as `["GET", "POST"]`). |
| `allow_headers` | `Collection[str]` | `()` | Request headers permitted in cross-origin preflight checks (such as `["Authorization", "Content-Type"]`). `Accept`, `Accept-Language`, `Content-Language`, and `Content-Type` are always allowed for simple CORS requests. |
| `allow_credentials` | `bool` | `False` | Permits cookies and `Authorization` credentials on cross-origin requests; requires explicit `allow_origins` without wildcards. |
| `allow_origin_regex` | `str \| None` | `None` | Optional regular expression matched against `Origin` (for example, `r"^https://.*\.example\.com$"`). |
| `allow_private_network` | `bool` | `False` | Responds with `Access-Control-Allow-Private-Network: true` when `Access-Control-Request-Private-Network: true` is present on preflight requests. |
| `expose_headers` | `Collection[str]` | `()` | Non-safelisted response headers exposed to browser JavaScript. |
| `max_age` | `int` | `600` | Maximum duration in seconds (`Access-Control-Max-Age`) that browsers cache preflight responses. |

### Example

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.testclient import TestClient

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://app.example.com", "https://admin.example.com"],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type"],
    expose_headers=["X-Request-Id"],
    max_age=600,
)


@app.get("/profile")
def get_profile() -> dict[str, str]:
    return {"status": "ok"}


client = TestClient(app)
allowed = client.get("/profile", headers={"Origin": "https://app.example.com"})
assert allowed.headers["access-control-allow-origin"] == "https://app.example.com"
assert allowed.headers["access-control-allow-credentials"] == "true"

blocked = client.get("/profile", headers={"Origin": "https://untrusted.example.net"})
assert "access-control-allow-origin" not in blocked.headers
```

---

## `class` TrustedHostMiddleware

Host-header validation middleware imported from `fastapi.middleware.trustedhost` (re-exporting `starlette.middleware.trustedhost.TrustedHostMiddleware`). Mitigates HTTP `Host` header poisoning attacks by rejecting requests whose `Host` header (or ASGI client scope) does not match `allowed_hosts` with `400 Invalid host header`.

```python
class TrustedHostMiddleware:
    def __init__(
        self,
        app: ASGIApp,
        allowed_hosts: Sequence[str] | None = None,
        www_redirect: bool = True,
    ) -> None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `app` | `ASGIApp` | *(Required)* | Next ASGI application wrapped by the middleware. |
| `allowed_hosts` | `Sequence[str] \| None` | `None` | Sequence of permitted hostnames or subdomain wildcard patterns such as `["api.example.com", "*.example.com"]` (defaults to `["*"]` when `None`). |
| `www_redirect` | `bool` | `True` | When `True`, requests matching `example.com` while `"www.example.com"` is in `allowed_hosts` receive a `301` permanent redirect to the `www.` host. |

### Example

```python
from fastapi import FastAPI
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.testclient import TestClient

app = FastAPI()
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["api.example.com", "*.example.com"],
)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "healthy"}


valid_client = TestClient(app, base_url="https://api.example.com")
assert valid_client.get("/health").status_code == 200

evil_client = TestClient(app, base_url="https://spoofed.attacker.org")
assert evil_client.get("/health").status_code == 400
```

---

## `class` GZipMiddleware

Response compression middleware imported from `fastapi.middleware.gzip` (re-exporting `starlette.middleware.gzip.GZipMiddleware`). Compresses HTTP responses whose client sends `Accept-Encoding: gzip`, whose byte length is at least `minimum_size`, and whose `Content-Type` is not in `exclude_content_types` (which excludes `"text/event-stream"` and pre-compressed media formats by default).

```python
class GZipMiddleware:
    def __init__(
        self,
        app: ASGIApp,
        minimum_size: int = 500,
        compresslevel: int = 9,
        thread_minimum_size: int = 131072,
        *,
        exclude_content_types: tuple[str, ...] = (
            "application/gzip",
            "application/x-gzip",
            "application/zip",
            "audio/*",
            "font/woff",
            "font/woff2",
            "image/avif",
            "image/gif",
            "image/jpeg",
            "image/png",
            "image/webp",
            "text/event-stream",
            "video/*",
        ),
    ) -> None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `app` | `ASGIApp` | *(Required)* | Next ASGI application wrapped by the middleware. |
| `minimum_size` | `int` | `500` | Minimum response body size in bytes before gzip compression is applied. |
| `compresslevel` | `int` | `9` | Deflate compression level from `1` (fastest) to `9` (smallest output). |
| `thread_minimum_size` | `int` | `131072` | Payload byte threshold (`128 KiB`) at or above which compression runs in a worker threadpool to avoid blocking the event loop. |
| `exclude_content_types` | `tuple[str, ...]` | `('application/gzip', ..., 'text/event-stream', 'video/*')` | Keyword-only tuple of exact MIME types or `type/*` wildcards skipped from gzip compression (preserving unbuffered SSE streams and binary archives/media). |

### Example

```python
from fastapi import FastAPI
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.testclient import TestClient

app = FastAPI()
app.add_middleware(GZipMiddleware, minimum_size=100, compresslevel=6)


@app.get("/report")
def large_report() -> dict[str, str]:
    return {"payload": "fastapi-gzip-" * 40}


client = TestClient(app)
res = client.get("/report", headers={"Accept-Encoding": "gzip"})
assert res.status_code == 200
assert res.headers["content-encoding"] == "gzip"
assert res.json()["payload"].startswith("fastapi-gzip-")
```

---

## `class` HTTPSRedirectMiddleware

Transport-security middleware imported from `fastapi.middleware.httpsredirect` (re-exporting `starlette.middleware.httpsredirect.HTTPSRedirectMiddleware`). Intercepts plain `http` and `ws` connections and returns a `307 Temporary Redirect` to the equivalent `https` or `wss` URL while preserving method, path, and query parameters.

```python
class HTTPSRedirectMiddleware:
    def __init__(self, app: ASGIApp) -> None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `app` | `ASGIApp` | *(Required)* | Next ASGI application wrapped by the middleware. |

### Example

```python
from fastapi import FastAPI
from fastapi.middleware.httpsredirect import HTTPSRedirectMiddleware
from fastapi.testclient import TestClient

app = FastAPI()
app.add_middleware(HTTPSRedirectMiddleware)


@app.get("/secure-data")
def secure_data() -> dict[str, bool]:
    return {"encrypted": True}


http_client = TestClient(app, base_url="http://api.example.com")
redirect = http_client.get("/secure-data?v=1", follow_redirects=False)
assert redirect.status_code == 307
assert redirect.headers["location"] == "https://api.example.com/secure-data?v=1"

https_client = TestClient(app, base_url="https://api.example.com")
assert https_client.get("/secure-data").status_code == 200
```

---

## `class` AsyncExitStackMiddleware

FastAPI-native ASGI middleware imported from `fastapi.middleware.asyncexitstack` and automatically mounted as the innermost middleware layer in `FastAPI.build_middleware_stack()` (inside `ExceptionMiddleware` and all user middlewares). Enters a `contextlib.AsyncExitStack` on `scope[context_name]` (`"fastapi_middleware_astack"`) so multipart `FormData` and `UploadFile` handles are guaranteed to close after each request finishes.

```python
class AsyncExitStackMiddleware:
    def __init__(
        self,
        app: ASGIApp,
        context_name: str = "fastapi_middleware_astack",
    ) -> None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `app` | `ASGIApp` | *(Required)* | Inner ASGI application or router invoked inside the `AsyncExitStack` context. |
| `context_name` | `str` | `"fastapi_middleware_astack"` | Key in the ASGI `scope` dictionary storing the active `AsyncExitStack` instance. |

### Example

```python
from contextlib import AsyncExitStack

from fastapi import FastAPI, Request
from fastapi.middleware.asyncexitstack import AsyncExitStackMiddleware
from fastapi.testclient import TestClient

app = FastAPI()
cleanup_log: list[str] = []


@app.get("/check-stack")
def check_stack(request: Request) -> dict[str, bool]:
    stack = request.scope.get("fastapi_middleware_astack")
    assert isinstance(stack, AsyncExitStack)
    stack.callback(cleanup_log.append, "closed")
    return {"active": True}


assert AsyncExitStackMiddleware is not None
client = TestClient(app)
assert client.get("/check-stack").json() == {"active": True}
assert cleanup_log == ["closed"]
```

---

## `deprecated` WSGIMiddleware

Legacy WSGI-to-ASGI adapter re-exported from `starlette.middleware.wsgi.WSGIMiddleware` via `fastapi.middleware.wsgi`. **Deprecated upstream by Starlette**: importing `fastapi.middleware.wsgi` emits `StarletteDeprecationWarning` because `starlette.middleware.wsgi` is scheduled for removal. Migrate to `a2wsgi.WSGIMiddleware` (`from a2wsgi import WSGIMiddleware`) when mounting synchronous WSGI applications (such as Flask or Django) via `app.mount()`.

```python
class WSGIMiddleware:
    def __init__(self, app: Callable[..., Any]) -> None: ...
```

### Parameters & Migration

| Parameter / Item | Type / Replacement | Description |
| :--- | :--- | :--- |
| `app` | `Callable[..., Any]` | Synchronous PEP 3333 WSGI callable `(environ, start_response) -> Iterable[bytes]`. |
| **Recommended Replacement** | `a2wsgi.WSGIMiddleware` | Install `a2wsgi` and mount via `app.mount("/legacy", a2wsgi.WSGIMiddleware(wsgi_app))` to avoid `StarletteDeprecationWarning`. |

### Example

```python
from collections.abc import Iterable
from typing import Any, Callable
import warnings

from fastapi import FastAPI
from fastapi.testclient import TestClient

with warnings.catch_warnings():
    warnings.simplefilter("ignore", DeprecationWarning)
    from fastapi.middleware.wsgi import WSGIMiddleware


def legacy_wsgi_app(
    environ: dict[str, Any], start_response: Callable[..., Any]
) -> Iterable[bytes]:
    start_response("200 OK", [("Content-Type", "text/plain; charset=utf-8")])
    return [b"legacy-ok"]


app = FastAPI()
app.mount("/legacy", WSGIMiddleware(legacy_wsgi_app))

client = TestClient(app)
res = client.get("/legacy/")
assert res.status_code == 200
assert res.text == "legacy-ok"
```
