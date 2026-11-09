# fastapi.background & utilities

Post-response task scheduling (`fastapi.background`), recursive JSON-compatible conversion (`fastapi.encoders`), AnyIO worker threadpool execution helpers (`fastapi.concurrency`), ASGI static asset serving (`fastapi.staticfiles`), and Jinja2 server-side HTML rendering (`fastapi.templating`).

```drawlib align=center code=hide file=fastapi_utilities_api_map.png caption="FastAPI BackgroundTasks, AnyIO Threadpool Concurrency, JSON Encoder, StaticFiles, and Jinja2Templates"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Colors, Styles

setup(width=188, height=88)

left_panel = Panel(
    "Background & Concurrency",
    description="",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.lightning,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.5,
)
left_panel.draw((6.0, 5.0), width=86.0, height=78.0)
l_xy, l_w, l_h = left_panel.get_content_box((6.0, 5.0), width=86.0, height=78.0, padding=(3.5, 3.0))

left_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.DarkBold,
    spacing=2.4,
)
left_cards.add(
    "BackgroundTasks",
    "add_task() • post-response spans",
    badge_text="TASK",
    icon=phosphor.clock_clockwise,
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
)
left_cards.add(
    "run_in_threadpool()",
    "Offload sync callables via AnyIO",
    badge_text="SYNC",
    icon=phosphor.cpu,
)
left_cards.add(
    "contextmanager_in_threadpool",
    "Deadlock-safe __exit__ limiter",
    badge_text="CTX",
    icon=phosphor.arrows_clockwise,
)
left_cards.draw(l_xy, width=l_w, height=l_h)

right_panel = Panel(
    "Encoding, Static & Templates",
    description="",
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.toolbox,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
right_panel.draw((96.0, 5.0), width=86.0, height=78.0)
r_xy, r_w, r_h = right_panel.get_content_box((96.0, 5.0), width=86.0, height=78.0, padding=(3.5, 3.0))

right_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    spacing=2.4,
)
right_cards.add(
    "jsonable_encoder()",
    "Models, dataclasses, UUID -> JSON",
    badge_text="JSON",
    icon=phosphor.brackets_curly,
)
right_cards.add(
    "StaticFiles",
    "Mount directory / package assets",
    badge_text="ASGI",
    icon=phosphor.folder_open,
)
right_cards.add(
    "Jinja2Templates",
    "TemplateResponse(request, name)",
    badge_text="HTML",
    icon=phosphor.file_code,
)
right_cards.draw(r_xy, width=r_w, height=r_h)

save()
```

---

## `class` BackgroundTasks

Subclass of Starlette's `BackgroundTasks` defined in `fastapi.background` (re-exported as `from fastapi import BackgroundTasks`). When annotated as a parameter on a route handler or `Depends()` callable, FastAPI injects a shared task collector, merges tasks queued across sub-dependencies and the endpoint, sends the HTTP response first, and then executes each task sequentially inside a `fastapi.background_task` OpenTelemetry child operation span.

```python
from collections.abc import Sequence
from starlette.background import BackgroundTask
from starlette.background import BackgroundTasks as StarletteBackgroundTasks


class BackgroundTasks(StarletteBackgroundTasks):
    def __init__(self, tasks: Sequence[BackgroundTask] | None = None) -> None: ...
    async def __call__(self) -> None: ...
```

### Parameters & Attributes

| Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `tasks` | `Sequence[BackgroundTask] \| None` | `None` | Optional initial sequence of `BackgroundTask` objects when instantiating `BackgroundTasks` manually (for example on a custom `Response(background=...)`). |
| `self.tasks` | `list[BackgroundTask]` | `[]` | Mutable ordered list of scheduled tasks executed sequentially after the response completes. |

### Example

```python
from fastapi import BackgroundTasks, Depends, FastAPI
from fastapi.testclient import TestClient

app = FastAPI()
events: list[str] = []


def record_audit(background_tasks: BackgroundTasks) -> str:
    background_tasks.add_task(events.append, "dependency-audit")
    return "audited"


@app.post("/jobs/{job_id}")
async def enqueue_job(
    job_id: str,
    background_tasks: BackgroundTasks,
    status: str = Depends(record_audit),
) -> dict[str, str]:
    background_tasks.add_task(events.append, f"job:{job_id}")
    return {"job_id": job_id, "status": status}


client = TestClient(app)
res = client.post("/jobs/42")
assert res.status_code == 200
assert events == ["dependency-audit", "job:42"]
```

---

## `method` BackgroundTasks.add_task()

Appends a callable and its positional/keyword arguments to the post-response execution queue using `ParamSpec` (`P`) type preservation. Accepts both `async def` coroutines (awaited directly on the event loop) and standard `def` functions (offloaded automatically to AnyIO's worker threadpool).

```python
from collections.abc import Callable
from typing import Any
from typing_extensions import ParamSpec

P = ParamSpec("P")


def add_task(
    self,
    func: Callable[P, Any],
    *args: P.args,
    **kwargs: P.kwargs,
) -> None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `func` | `Callable[P, Any]` | *Required* | Synchronous `def` function or `async def` coroutine function invoked after the HTTP response is sent. |
| `*args` | `P.args` | `()` | Positional arguments forwarded to `func`. |
| `**kwargs` | `P.kwargs` | `{}` | Keyword arguments forwarded to `func`. |

### Example

```python
from fastapi import BackgroundTasks, FastAPI
from fastapi.testclient import TestClient

app = FastAPI()
delivered: list[str] = []


def write_receipt(email: str, *, amount: int) -> None:
    delivered.append(f"sync:{email}:{amount}")


async def notify_webhook(channel: str) -> None:
    delivered.append(f"async:{channel}")


@app.post("/checkout")
async def checkout(background_tasks: BackgroundTasks) -> dict[str, bool]:
    background_tasks.add_task(write_receipt, "ops@example.com", amount=2500)
    background_tasks.add_task(notify_webhook, "billing")
    return {"accepted": True}


assert TestClient(app).post("/checkout").json() == {"accepted": True}
assert delivered == ["sync:ops@example.com:2500", "async:billing"]
```

---

## `def` jsonable_encoder()

Recursively converts arbitrary Python structures—Pydantic v2 `BaseModel` instances, standard `dataclasses`, `Enum`, `datetime`/`date`/`time` (ISO-8601), `timedelta` (seconds), `Decimal` (`int` or `float`), `UUID`, `PurePath`, IP addresses/networks, `set`/`frozenset`/`deque`/generators, and ORM objects—into JSON-compatible primitives (`dict`, `list`, `str`, `int`, `float`, `bool`, `None`). Raises `PydanticV1NotSupportedError` if given a legacy `pydantic.v1` model.

```python
from collections.abc import Callable
from typing import Any
from fastapi.encoders import jsonable_encoder
from fastapi.types import IncEx


def jsonable_encoder(
    obj: Any,
    include: IncEx | None = None,
    exclude: IncEx | None = None,
    by_alias: bool = True,
    exclude_unset: bool = False,
    exclude_defaults: bool = False,
    exclude_none: bool = False,
    custom_encoder: dict[Any, Callable[[Any], Any]] | None = None,
    sqlalchemy_safe: bool = True,
) -> Any: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `obj` | `Any` | *Required* | Input Python object, model, dataclass, collection, or scalar to convert into JSON-compatible primitives. |
| `include` | `IncEx \| None` | `None` | Set or nested dict of field/key names to retain on Pydantic models and `dict` mappings. |
| `exclude` | `IncEx \| None` | `None` | Set or nested dict of field/key names to omit from the serialized output. |
| `by_alias` | `bool` | `True` | Serialize Pydantic model fields using their field aliases rather than Python attribute names. |
| `exclude_unset` | `bool` | `False` | Omit Pydantic model fields that were not explicitly provided at instantiation time. |
| `exclude_defaults` | `bool` | `False` | Omit Pydantic model fields whose values equal their declared default values. |
| `exclude_none` | `bool` | `False` | Omit fields and dictionary entries whose value is `None`. |
| `custom_encoder` | `dict[Any, Callable[[Any], Any]] \| None` | `None` | Mapping of `{Type: encoder_fn}` checked before default `ENCODERS_BY_TYPE` rules (supports exact type and `isinstance` lookup). |
| `sqlalchemy_safe` | `bool` | `True` | Drop dictionary keys starting with `"_sa"` (such as `_sa_instance_state`) when encoding ORM instances. |

### Example

```python
from datetime import datetime, timezone
from decimal import Decimal
from uuid import UUID
from pydantic import BaseModel, Field

from fastapi.encoders import jsonable_encoder


class Invoice(BaseModel):
    invoice_id: UUID = Field(alias="id")
    total: Decimal
    issued_at: datetime
    notes: str | None = None
    internal_tag: str = "draft"


inv = Invoice(
    id=UUID("12345678-1234-5678-1234-567812345678"),
    total=Decimal("49.95"),
    issued_at=datetime(2026, 5, 1, 12, 30, tzinfo=timezone.utc),
)

encoded = jsonable_encoder(
    inv,
    exclude={"internal_tag"},
    exclude_none=True,
)
assert encoded == {
    "id": "12345678-1234-5678-1234-567812345678",
    "total": "49.95",
    "issued_at": "2026-05-01T12:30:00Z",
}
assert jsonable_encoder({"fee": Decimal("2.5"), "_sa_instance_state": "skip"}) == {"fee": 2.5}
```

---

## `async def` run_in_threadpool()

Executes a synchronous `def` callable inside AnyIO's worker threadpool (`fastapi.concurrency.run_in_threadpool`, re-exported from Starlette) and awaits its result without blocking the async event loop. Use this inside `async def` route handlers or dependencies whenever calling blocking filesystem, CPU, or synchronous SDK functions directly.

```python
from collections.abc import Callable
from typing import TypeVar
from typing_extensions import ParamSpec
from fastapi.concurrency import run_in_threadpool

P = ParamSpec("P")
T = TypeVar("T")


async def run_in_threadpool(
    func: Callable[P, T],
    *args: P.args,
    **kwargs: P.kwargs,
) -> T: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `func` | `Callable[P, T]` | *Required* | Synchronous callable executed on a worker thread via `anyio.to_thread.run_sync` (preserving `contextvars`). |
| `*args` | `P.args` | `()` | Positional arguments passed to `func`. |
| `**kwargs` | `P.kwargs` | `{}` | Keyword arguments passed to `func` (bound via `functools.partial` when non-empty). |

### Example

```python
import hashlib
from fastapi import FastAPI
from fastapi.concurrency import run_in_threadpool
from fastapi.testclient import TestClient

app = FastAPI()


def compute_digest(payload: bytes, *, rounds: int = 3) -> str:
    digest = payload
    for _ in range(rounds):
        digest = hashlib.sha256(digest).digest()
    return digest.hex()[:16]


@app.post("/digest")
async def create_digest(text: str) -> dict[str, str]:
    short_hash = await run_in_threadpool(compute_digest, text.encode("utf-8"), rounds=5)
    return {"digest": short_hash}


res = TestClient(app).post("/digest", params={"text": "fastapi"})
assert res.status_code == 200
assert len(res.json()["digest"]) == 16
```

---

## `async def` contextmanager_in_threadpool()

Wraps a synchronous context manager (`AbstractContextManager[_T]`) into an `async with`-compatible `@asynccontextmanager` in `fastapi.concurrency` (used internally by FastAPI for `def` dependencies with `yield`). Enters `cm.__enter__` on the standard worker threadpool, while running `cm.__exit__` with a dedicated `anyio.CapacityLimiter(1)` so cleanup and connection-pool release can never deadlock if the shared worker threadpool is saturated.

```python
from collections.abc import AsyncGenerator
from contextlib import AbstractContextManager, asynccontextmanager
from typing import TypeVar
from fastapi.concurrency import contextmanager_in_threadpool

_T = TypeVar("_T")


@asynccontextmanager
async def contextmanager_in_threadpool(
    cm: AbstractContextManager[_T],
) -> AsyncGenerator[_T, None]: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `cm` | `AbstractContextManager[_T]` | *Required* | Synchronous context manager whose `__enter__` and `__exit__` methods are executed off the event loop. |
| **Yields** | `_T` | — | Value returned by `cm.__enter__()`; forwards any raised exception to `cm.__exit__(exc_type, exc, tb)` and suppresses it if `__exit__` returns truthy. |

### Example

```python
import asyncio
from collections.abc import Iterator
from contextlib import contextmanager
from fastapi.concurrency import contextmanager_in_threadpool

lifecycle: list[str] = []


@contextmanager
def sync_unit_of_work(name: str) -> Iterator[str]:
    lifecycle.append(f"enter:{name}")
    try:
        yield f"session:{name}"
    finally:
        lifecycle.append(f"exit:{name}")


async def run_workflow() -> str:
    async with contextmanager_in_threadpool(sync_unit_of_work("orders")) as handle:
        lifecycle.append(f"use:{handle}")
        return handle


result = asyncio.run(run_workflow())
assert result == "session:orders"
assert lifecycle == ["enter:orders", "use:session:orders", "exit:orders"]
```

---

## `class` StaticFiles

ASGI application in `fastapi.staticfiles` (re-exported from Starlette) for serving static files from a filesystem directory or Python package resource directory, typically mounted via `app.mount("/static", StaticFiles(...), name="static")`. Supports `ETag`, `Last-Modified` (`304 Not Modified`), and SPA/static `index.html` serving (`html=True`).

```python
from os import PathLike
from fastapi.staticfiles import StaticFiles


class StaticFiles:
    def __init__(
        self,
        *,
        directory: PathLike[str] | str | None = None,
        packages: list[str | tuple[str, str]] | None = None,
        html: bool = False,
        check_dir: bool = True,
        follow_symlink: bool = False,
    ) -> None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `directory` | `PathLike \| str \| None` | `None` | Filesystem root directory from which static assets are resolved safely against path traversal. |
| `packages` | `list[str \| tuple[str, str]] \| None` | `None` | Python package names (or `(package, subdir)` tuples; defaults to `"statics"`) searched for bundled static files. |
| `html` | `bool` | `False` | Serve `index.html` automatically for directory paths and `404.html` when files are missing. |
| `check_dir` | `bool` | `True` | Verify at instantiation time that `directory` exists (set `False` if the directory is created during build/startup). |
| `follow_symlink` | `bool` | `False` | Allow resolving symbolic links pointing outside the configured static root. |

### Example

```python
from pathlib import Path
from tempfile import TemporaryDirectory
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.testclient import TestClient

with TemporaryDirectory() as tmp:
    asset_dir = Path(tmp)
    (asset_dir / "index.html").write_text("<h1>Docs Portal</h1>", encoding="utf-8")
    (asset_dir / "app.js").write_text("console.log('ready');", encoding="utf-8")

    app = FastAPI()
    app.mount("/site", StaticFiles(directory=asset_dir, html=True), name="site")

    client = TestClient(app)
    assert client.get("/site/").text == "<h1>Docs Portal</h1>"
    assert "console.log('ready');" in client.get("/site/app.js").text
```

---

## `class` Jinja2Templates

Server-side Jinja2 HTML rendering helper in `fastapi.templating` (re-exported from Starlette, requires `jinja2` installed via `fastapi[standard]`). Enables HTML autoescaping by default, registers `url_for()` inside templates, and exposes `TemplateResponse(request=..., name=..., context=...)` with `request` as the required first parameter.

```python
from collections.abc import Callable, Mapping, Sequence
from os import PathLike
from typing import Any
import jinja2
from starlette.background import BackgroundTask
from starlette.requests import Request
from fastapi.templating import Jinja2Templates


class Jinja2Templates:
    def __init__(
        self,
        directory: str | PathLike[str] | Sequence[str | PathLike[str]] | None = None,
        *,
        context_processors: list[Callable[[Request], dict[str, Any]]] | None = None,
        env: jinja2.Environment | None = None,
    ) -> None: ...

    def TemplateResponse(
        self,
        request: Request,
        name: str,
        context: dict[str, Any] | None = None,
        status_code: int = 200,
        headers: Mapping[str, str] | None = None,
        media_type: str | None = None,
        background: BackgroundTask | None = None,
    ) -> Any: ...
```

### Constructor & `TemplateResponse` Parameters

| Target | Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `__init__` | `directory` | `str \| PathLike \| Sequence[...] \| None` | `None` | Template search path(s); mutually exclusive (`^`) with passing a prebuilt `env`. |
| `__init__` | `context_processors` | `list[Callable[[Request], dict[str, Any]]] \| None` | `None` | Functions invoked per request whose returned dictionaries merge into the template context. |
| `__init__` | `env` | `jinja2.Environment \| None` | `None` | Custom `jinja2.Environment` instance (mutually exclusive with `directory`). |
| `TemplateResponse` | `request` | `Request` | *Required* | Active FastAPI `Request` (first argument; automatically inserted into `context["request"]`). |
| `TemplateResponse` | `name` | `str` | *Required* | Template filename relative to `directory` (for example `"item.html"`). |
| `TemplateResponse` | `context` | `dict[str, Any] \| None` | `None` | Template variables dictionary (`request` no longer needs to be duplicated manually inside `context`). |
| `TemplateResponse` | `status_code` | `int` | `200` | HTTP response status code. |
| `TemplateResponse` | `headers` | `Mapping[str, str] \| None` | `None` | Extra HTTP response headers. |
| `TemplateResponse` | `media_type` | `str \| None` | `None` | Override response `Content-Type` (defaults to `"text/html; charset=utf-8"`). |
| `TemplateResponse` | `background` | `BackgroundTask \| None` | `None` | Optional background task attached directly to the response. |

### Example

```python
from pathlib import Path
from tempfile import TemporaryDirectory
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi.testclient import TestClient

with TemporaryDirectory() as tmp:
    tpl_dir = Path(tmp)
    (tpl_dir / "badge.html").write_text(
        "<span data-path='{{ request.url.path }}'>{{ title }}</span>",
        encoding="utf-8",
    )

    templates = Jinja2Templates(directory=tpl_dir)
    app = FastAPI()

    @app.get("/badges/{slug}", response_class=HTMLResponse)
    def render_badge(request: Request, slug: str) -> HTMLResponse:
        return templates.TemplateResponse(
            request=request,
            name="badge.html",
            context={"title": f"Badge <{slug}>"},
        )

    res = TestClient(app).get("/badges/core")
    assert res.status_code == 200
    assert res.text == "<span data-path='/badges/core'>Badge &lt;core&gt;</span>"
```
