# fastapi.testclient & cli

Synchronous in-process HTTP, WebSocket, and ASGI lifespan testing via `TestClient` (`fastapi.testclient`), paired with the `fastapi` command-line interface (`fastapi.cli` / `fastapi-cli`) for local auto-reload development (`fastapi dev`), production Uvicorn execution (`fastapi run`), and environment diagnostics (`fastapi --version`).

```drawlib align=center code=hide file=fastapi_testing_cli_map.png caption="FastAPI In-Process TestClient (HTTP, WebSocket & Lifespan) and FastAPI CLI Modes (dev vs run)"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Colors, Styles

setup(width=188, height=88)

test_panel = Panel(
    "TestClient (In-Process)",
    description="",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.flask,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.5,
)
test_panel.draw((6.0, 5.0), width=86.0, height=78.0)
t_xy, t_w, t_h = test_panel.get_content_box((6.0, 5.0), width=86.0, height=78.0, padding=(3.5, 3.0))

test_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.DarkBold,
    spacing=2.4,
)
test_cards.add(
    "HTTP & Overrides",
    "httpx.Client • headers • root_path",
    badge_text="HTTP",
    icon=phosphor.globe,
)
test_cards.add(
    "websocket_connect()",
    "Bidirectional JSON / text / bytes",
    badge_text="WS",
    icon=phosphor.plugs_connected,
)
test_cards.add(
    "with TestClient(app):",
    "Runs ASGI lifespan startup & exit",
    badge_text="LIFE",
    icon=phosphor.arrows_clockwise,
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
)
test_cards.draw(t_xy, width=t_w, height=t_h)

cli_panel = Panel(
    "FastAPI CLI (dev & run)",
    description="",
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.terminal_window,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
cli_panel.draw((96.0, 5.0), width=86.0, height=78.0)
c_xy, c_w, c_h = cli_panel.get_content_box((96.0, 5.0), width=86.0, height=78.0, padding=(3.5, 3.0))

cli_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    spacing=2.4,
)
cli_cards.add(
    "[tool.fastapi] & --version",
    "Entrypoint discovery • runtime info",
    badge_text="CLI",
    icon=phosphor.file_code,
)
cli_cards.add(
    "fastapi dev",
    "127.0.0.1:8000 • --reload • dev env",
    badge_text="DEV",
    icon=phosphor.code,
)
cli_cards.add(
    "fastapi run",
    "0.0.0.0:8000 • --workers • --root-path",
    badge_text="PROD",
    icon=phosphor.rocket_launch,
)
cli_cards.draw(c_xy, width=c_w, height=c_h)

save()
```

---

## `class` TestClient

Synchronous test client in `fastapi.testclient` (re-exported from Starlette, built on `httpx.Client` + AnyIO's `BlockingPortal`, requiring `httpx` installed via `fastapi[standard]`). Dispatches HTTP and WebSocket calls directly against an ASGI application in memory without opening network sockets. Entering `with TestClient(app) as client:` triggers the ASGI `lifespan` startup and shutdown events (`lifespan.startup` / `lifespan.shutdown`).

```python
from typing import Any, Literal
import httpx
from starlette.types import ASGIApp
from fastapi.testclient import TestClient


class TestClient(httpx.Client):
    def __init__(
        self,
        app: ASGIApp,
        base_url: str = "http://testserver",
        raise_server_exceptions: bool = True,
        root_path: str = "",
        backend: Literal["asyncio", "trio"] = "asyncio",
        backend_options: dict[str, Any] | None = None,
        cookies: httpx._types.CookieTypes | None = None,
        headers: dict[str, str] | None = None,
        follow_redirects: bool = True,
        client: tuple[str, int] = ("testclient", 50000),
    ) -> None: ...
```

### Constructor Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `app` | `ASGIApp` | *Required* | Target `FastAPI` (or ASGI middleware-wrapped) application under test. |
| `base_url` | `str` | `"http://testserver"` | Base URL prepended to relative request paths such as `client.get("/items")`. |
| `raise_server_exceptions` | `bool` | `True` | Re-raise unhandled server exceptions directly in the test caller; set `False` to inspect generated `500 Internal Server Error` HTTP responses instead. |
| `root_path` | `str` | `""` | ASGI `scope["root_path"]` prefix simulating reverse-proxy deployments (`fastapi run --root-path /api/v1`). |
| `backend` | `Literal["asyncio", "trio"]` | `"asyncio"` | AnyIO event loop backend powering the in-process `BlockingPortal`. |
| `backend_options` | `dict[str, Any] \| None` | `None` | Backend-specific options forwarded to `anyio.start_blocking_portal` (for example `{"use_uvloop": True}`). |
| `cookies` | `CookieTypes \| None` | `None` | Default cookies persisted across requests on the underlying `httpx.Client` cookie jar. |
| `headers` | `dict[str, str] \| None` | `None` | Default HTTP headers attached to every request sent by this client instance. |
| `follow_redirects` | `bool` | `True` | Follow `3xx` redirect responses automatically (`TestClient` defaults to `True`, unlike plain `httpx.Client`). |
| `client` | `tuple[str, int]` | `("testclient", 50000)` | Synthetic `(host, port)` tuple exposed via `request.client` / `scope["client"]`. |

### Example

```python
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from fastapi import Depends, FastAPI, Request
from fastapi.testclient import TestClient

lifespan_log: list[str] = []


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    app.state.db_ready = True
    lifespan_log.append("startup")
    yield
    lifespan_log.append("shutdown")


app = FastAPI(lifespan=lifespan)


def get_env_label() -> str:
    return "production"


@app.get("/info")
def info(request: Request, env: str = Depends(get_env_label)) -> dict[str, object]:
    return {
        "ready": request.app.state.db_ready,
        "env": env,
        "root_path": request.scope.get("root_path", ""),
        "client_host": request.client.host if request.client else None,
    }


app.dependency_overrides[get_env_label] = lambda: "test"

with TestClient(
    app,
    root_path="/api/v1",
    headers={"X-Suite": "unit"},
    client=("10.0.0.8", 61000),
) as client:
    res = client.get("/info")
    assert res.status_code == 200
    assert res.json() == {
        "ready": True,
        "env": "test",
        "root_path": "/api/v1",
        "client_host": "10.0.0.8",
    }

app.dependency_overrides.clear()
assert lifespan_log == ["startup", "shutdown"]
```

---

## `method` TestClient.websocket_connect()

Opens an in-process ASGI WebSocket session returning a context-managed `WebSocketTestSession`. Supports custom subprotocol negotiation, headers/cookies via `**kwargs`, and synchronous `send_text` / `send_bytes` / `send_json` plus `receive_text` / `receive_bytes` / `receive_json` methods.

```python
from collections.abc import Sequence
from typing import Any
from starlette.testclient import WebSocketTestSession


def websocket_connect(
    self,
    url: str,
    subprotocols: Sequence[str] | None = None,
    **kwargs: Any,
) -> WebSocketTestSession: ...
```

### Parameters & `WebSocketTestSession` Methods

| Element | Signature / Type | Description |
| :--- | :--- | :--- |
| `url` | `str` | Target WebSocket path or `ws://` URL (for example `"/ws/chat?room=general"`). |
| `subprotocols` | `Sequence[str] \| None = None` | Optional list of `Sec-WebSocket-Protocol` values offered during the handshake. |
| `**kwargs` | `Any` | Extra keyword arguments forwarded to the handshake request (such as `headers={...}`). |
| `session.send_text(data)` / `receive_text()` | `str` | Send or blockingly receive a UTF-8 text WebSocket frame. |
| `session.send_bytes(data)` / `receive_bytes()` | `bytes` | Send or blockingly receive a binary WebSocket frame. |
| `session.send_json(data, mode="text")` / `receive_json(mode="text")` | `Any` | Serialize or deserialize JSON payloads over text or binary WebSocket frames. |
| `session.close(code=1000, reason=None)` | `None` | Initiate a clean client-side WebSocket close frame. |

### Example

```python
from fastapi import FastAPI, WebSocket
from fastapi.testclient import TestClient

app = FastAPI()


@app.websocket("/ws/echo")
async def ws_echo(websocket: WebSocket) -> None:
    chosen = "chat.v2" if "chat.v2" in websocket.scope.get("subprotocols", []) else None
    await websocket.accept(subprotocol=chosen)
    payload = await websocket.receive_json()
    await websocket.send_json({"echo": payload, "subprotocol": chosen})
    await websocket.close()


client = TestClient(app)
with client.websocket_connect("/ws/echo", subprotocols=["chat.v1", "chat.v2"]) as ws:
    ws.send_json({"ping": 1})
    reply = ws.receive_json()
    assert reply == {"echo": {"ping": 1}, "subprotocol": "chat.v2"}
```

---

## `cmd` fastapi dev

Starts a local development Uvicorn server via `fastapi-cli` (installed with `pip install "fastapi[standard]"`). Binds safely to local loopback `127.0.0.1:8000` by default, enables file-watching auto-reload, sets `FASTAPI_ENV="development"` when unset, and resolves the target `FastAPI` instance from `[tool.fastapi] entrypoint` in `pyproject.toml`, `--entrypoint`, or `PATH`.

```bash
fastapi dev [PATH] [OPTIONS]
```

### Arguments & Options

| Argument / Option | Default | Description |
| :--- | :--- | :--- |
| `path` (`[PATH]`) | Auto-discovered | Optional path to a Python module file (`main.py`) or package directory exporting a `FastAPI` app. |
| `--host TEXT` | `"127.0.0.1"` | Network interface to bind; defaults safely to localhost loopback so dev servers are not exposed externally. |
| `--port INTEGER` | `8000` | TCP port on which the development server listens. |
| `--reload / --no-reload` | `--reload` | Watch source files and restart the worker automatically when Python modules change. |
| `--proxy-headers / --no-proxy-headers` | `--proxy-headers` | Parse `X-Forwarded-Proto` and `X-Forwarded-For` headers from local reverse proxies or tunnels. |
| `--root-path TEXT` | `""` | ASGI `root_path` mount prefix injected into `scope["root_path"]` for `/docs` and OpenAPI `servers`. |
| `--app TEXT` | `None` | Variable name of the `FastAPI` object inside the target module (auto-detects `app` or `api` when omitted). |
| `--entrypoint, -e TEXT` | `None` | Explicit `module.path:app_var` import string overriding `[tool.fastapi] entrypoint` in `pyproject.toml`. |

### Configuration & Usage

```toml
# pyproject.toml
[tool.fastapi]
entrypoint = "my_service.main:app"
```

```bash
# Uses [tool.fastapi] entrypoint on http://127.0.0.1:8000 with auto-reload
fastapi dev

# Explicit module path, custom port, and custom FastAPI variable name
fastapi dev src/my_service/api.py --app api --port 8080

# Explicit import string without positional path
fastapi dev --entrypoint my_service.main:app --root-path /dev-api
```

---

## `cmd` fastapi run

Starts a production Uvicorn server via `fastapi-cli` with auto-reload disabled and default container-ready binding on `0.0.0.0:8000`. Supports multi-process scaling (`--workers`), trusted proxy IP filtering (`--forwarded-allow-ips`), and server-side `--root-path` configuration (which replaces the deprecated `FastAPI(root_path=...)` constructor argument).

```bash
fastapi run [PATH] [OPTIONS]
```

### Arguments & Options

| Argument / Option | Default | Description |
| :--- | :--- | :--- |
| `path` (`[PATH]`) | Auto-discovered | Optional path to a Python file or package directory when not using `[tool.fastapi] entrypoint` or `--entrypoint`. |
| `--host TEXT` | `"0.0.0.0"` | Network interface bound by Uvicorn inside containers or VM hosts (place behind a TLS reverse proxy in production). |
| `--port INTEGER` | `8000` | TCP port bound by Uvicorn. |
| `--workers INTEGER` | `None` (single worker) | Number of Uvicorn worker processes to spawn (`WEB_CONCURRENCY` fallback when supported). |
| `--reload / --no-reload` | `--no-reload` | Keep filesystem watchers disabled in production for minimal CPU and memory overhead. |
| `--proxy-headers / --no-proxy-headers` | `--proxy-headers` | Honor `X-Forwarded-Proto` and `X-Forwarded-For` from trusted upstream proxies. |
| `--forwarded-allow-ips TEXT` | `None` (`127.0.0.1` / env) | Comma-separated proxy IPs/CIDRs (or `"*"` behind an isolated ingress) trusted to send `X-Forwarded-*` headers. |
| `--root-path TEXT` | `""` | External URL prefix stripped by an upstream reverse proxy (for example `/api/v1`), dynamically applied to `/openapi.json` and `/docs`. |
| `--app TEXT` | `None` | Explicit `FastAPI` attribute name inside the target module. |
| `--entrypoint, -e TEXT` | `None` | Explicit `module.path:app_var` import string (for example `my_service.main:app`). |

### Usage

```bash
# Production container startup reading [tool.fastapi] entrypoint
fastapi run --workers 4 --port 8000

# Behind a TLS reverse proxy stripping /api/v1 on a trusted internal network
fastapi run --entrypoint my_service.main:app \
    --workers 4 \
    --proxy-headers \
    --forwarded-allow-ips "*" \
    --root-path /api/v1
```

---

## `cmd` fastapi --version

Prints diagnostic version information for the active CLI environment and exits immediately. Entry script `fastapi = "fastapi.cli:main"` delegates to `fastapi_cli.cli:main` when `fastapi[standard]` is installed, or raises a descriptive `RuntimeError` instructing the user to install `"fastapi[standard]"` when only core `fastapi` is present.

```bash
fastapi --version
```

### Behavior & Programmatic Entrypoint

| Item | Value / Behavior | Description |
| :--- | :--- | :--- |
| **Console Script** | `fastapi = "fastapi.cli:main"` | Declared under `[project.scripts]` in `pyproject.toml`. |
| **Required Extra** | `pip install "fastapi[standard]"` | Installs `fastapi-cli[standard]>=0.0.32` and `uvicorn[standard]`. |
| **CLI Output** | OS, Python, `fastapi`, `fastapi-cli` | Prints installed package versions and exits with status code `0`. |
| **Python Version Symbol** | `fastapi.__version__` | Direct runtime version string (`"0.162.2"`), available without `fastapi-cli`. |

### Example

```python
from unittest.mock import patch
import pytest

import fastapi
from fastapi import cli as fastapi_cli_shim

assert fastapi.__version__ == "0.162.2"

# When fastapi_cli is absent, fastapi.cli.main() raises an actionable RuntimeError
with patch.object(fastapi_cli_shim, "cli_main", None):
    with pytest.raises(RuntimeError, match='pip install "fastapi\\[standard\\]"'):
        fastapi_cli_shim.main()
```
