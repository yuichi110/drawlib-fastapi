# fastapi.dependencies

FastAPI's dependency injection (DI) system resolves hierarchical callable graphs per request, automatically validating sub-dependency parameters, caching results within a request, managing `yield` teardown scopes (`"function"` vs `"request"`), aggregating OAuth2 `SecurityScopes`, and supporting test-time substitution via `FastAPI.dependency_overrides`.

```drawlib align=center code=hide file=fastapi_depends_security_api.png caption="FastAPI Dependency Injection, Security Scopes & Lifecycle Overview"
from drawlib.canvas import save, setup
from drawlib.diagrams.architecture import ArchitectureDiagram, Node, NodeGroup, PhosphorIcon
from drawlib.styles import Colors, Styles

setup(width=156, height=64)

_ = Colors
d = ArchitectureDiagram(
    node_style=Styles.Dark,
    node_text_style=Styles.DarkBold.patch(text_size=10.5),
    edge_style=Styles.Dark.patch(line_width=1.5),
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
)

decl_group = d.add(
    NodeGroup(
        "Declarations",
        width=38,
        height=52,
        style=Styles.SecondaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left", valign="top"),
    ),
    xy=(6, 6),
)
depends_node = decl_group.add(
    Node(
        "Depends()",
        icon=PhosphorIcon.PLUGS_CONNECTED,
        width=28,
        height=15.5,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.5),
        card_style=Styles.PrimaryFlat,
    ),
    xy=(19, 34),
)
security_node = decl_group.add(
    Node(
        "Security()",
        icon=PhosphorIcon.SHIELD_CHECK,
        width=28,
        height=15.5,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(19, 13.5),
)

solver_group = d.add(
    NodeGroup(
        "DI Solver & Scopes",
        width=50,
        height=52,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left", valign="top"),
    ),
    xy=(53, 6),
)
yield_node = solver_group.add(
    Node(
        "yield Cleanup\n(function | request)",
        icon=PhosphorIcon.ARROWS_CLOCKWISE,
        width=36,
        height=15.5,
        card_style=Styles.White,
    ),
    xy=(25, 34),
)
scopes_node = solver_group.add(
    Node(
        "SecurityScopes\n(scopes, scope_str)",
        icon=PhosphorIcon.LIST_CHECKS,
        width=36,
        height=15.5,
        card_style=Styles.White,
    ),
    xy=(25, 13.5),
)

runtime_group = d.add(
    NodeGroup(
        "Execution & Testing",
        width=38,
        height=52,
        style=Styles.SecondaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left", valign="top"),
    ),
    xy=(112, 6),
)
handler_node = runtime_group.add(
    Node(
        "Path Operation",
        icon=PhosphorIcon.CODE,
        width=28,
        height=15.5,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.5),
        card_style=Styles.AccentFlat,
    ),
    xy=(19, 34),
)
override_node = runtime_group.add(
    Node(
        "dependency_overrides",
        icon=PhosphorIcon.SWAP,
        width=28,
        height=15.5,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(19, 13.5),
)

depends_node.connect(yield_node, label="cache", padding=1.2)
yield_node.connect(handler_node, label="inject", padding=1.2)
security_node.connect(scopes_node, label="OAuth2", padding=1.2)
scopes_node.connect(override_node, arrow="<-", label="mock", padding=1.2)

d.draw(xy=(0, 0))
save()
```

---

## `def` Depends()

Declares a sub-dependency parameter or route/router/application-level dependency. At runtime, FastAPI inspects the target `dependency` callable (function, coroutine, generator, async generator, or class), resolves all of its parameters recursively, and injects the returned or yielded value. Called via `fastapi.Depends` (re-exported from `fastapi.param_functions.Depends`), which returns an immutable `fastapi.params.Depends` descriptor.

```python
def Depends(
    dependency: Callable[..., Any] | None = None,
    *,
    use_cache: bool = True,
    scope: Literal["function", "request"] | None = None,
) -> Any
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `dependency` | `Callable[..., Any] \| None` | `None` | Dependable callable to invoke. When omitted (`None`) inside `Annotated[MyClass, Depends()]`, FastAPI infers `MyClass` directly from the parameter type annotation. |
| `use_cache` | `bool` | `True` | Reuses the first resolved value when the same dependency callable appears multiple times in a single request's dependency DAG. Set to `False` to re-execute on each occurrence. |
| `scope` | `Literal["function", "request"] \| None` | `None` | Controls teardown timing for `yield` dependencies. `"function"` runs cleanup right after the path operation function returns (before sending the response); `"request"` runs cleanup after the response is sent to the client. |

### Example

```python
from collections.abc import Generator
from typing import Annotated

from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

app = FastAPI()
events: list[str] = []


def get_db_session() -> Generator[dict[str, str], None, None]:
    events.append("open")
    try:
        yield {"connection": "active"}
    finally:
        events.append("close_before_response")


@app.get("/records")
def list_records(
    db_a: Annotated[dict[str, str], Depends(get_db_session, scope="function")],
    db_b: Annotated[
        dict[str, str],
        Depends(get_db_session, use_cache=True, scope="function"),
    ],
) -> dict[str, bool]:
    return {"cached_same_instance": db_a is db_b}


client = TestClient(app)
res = client.get("/records")
assert res.status_code == 200
assert res.json() == {"cached_same_instance": True}
assert events == ["open", "close_before_response"]
```

---

## `def` Security()

Declares a security sub-dependency with required OAuth2 permission `scopes`. `Security()` behaves identically to `Depends()` at runtime (`fastapi.params.Security` subclasses `fastapi.params.Depends`), while additionally propagating `scopes` into `SecurityScopes` and recording security requirements in the generated OpenAPI schema (`/openapi.json` and `/docs`).

```python
def Security(
    dependency: Callable[..., Any] | None = None,
    *,
    scopes: Sequence[str] | None = None,
    use_cache: bool = True,
) -> Any
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `dependency` | `Callable[..., Any] \| None` | `None` | Security callable or `SecurityBase` scheme instance to resolve for the request. |
| `scopes` | `Sequence[str] \| None` | `None` | OAuth2 scope strings required by the path operation or parent dependency (documented in OpenAPI and aggregated into `SecurityScopes`). |
| `use_cache` | `bool` | `True` | Caches the resolved dependency value per `(callable, tuple(scopes))` key within the current request. |

### Example

```python
from typing import Annotated

from fastapi import FastAPI, HTTPException, Security
from fastapi.security import APIKeyHeader, SecurityScopes
from fastapi.testclient import TestClient

app = FastAPI()
api_key_header = APIKeyHeader(name="X-API-Token")


def verify_scoped_caller(
    security_scopes: SecurityScopes,
    token: Annotated[str, Security(api_key_header)],
) -> dict[str, object]:
    granted = token.split(",")
    for required in security_scopes.scopes:
        if required not in granted:
            raise HTTPException(status_code=403, detail="Insufficient scope")
    return {"scopes": security_scopes.scopes}


@app.get("/reports")
def read_reports(
    auth: Annotated[
        dict[str, object],
        Security(verify_scoped_caller, scopes=["reports:read"]),
    ],
) -> dict[str, object]:
    return auth


client = TestClient(app)
ok = client.get("/reports", headers={"X-API-Token": "reports:read,audit"})
denied = client.get("/reports", headers={"X-API-Token": "profile:read"})
assert ok.status_code == 200
assert ok.json() == {"scopes": ["reports:read"]}
assert denied.status_code == 403
```

---

## `class` SecurityScopes

Special parameter object injected automatically by FastAPI when type-annotated on a dependency function (`security_scopes: SecurityScopes`). It collects all OAuth2 scope strings declared across every `Security(..., scopes=[...])` link in the active dependency chain leading to that callable. Imported from `fastapi.security.SecurityScopes` (defined in `fastapi.security.oauth2`).

```python
class SecurityScopes:
    scopes: list[str]
    scope_str: str

    def __init__(
        self,
        scopes: list[str] | None = None,
    ) -> None: ...
```

### Parameters & Attributes

| Name | Kind | Type | Description |
| :--- | :--- | :--- | :--- |
| `scopes` | Parameter / Attribute | `list[str]` | Ordered list of required scope strings accumulated across the active dependency chain (defaults to `[]` if `None` is passed). |
| `scope_str` | Attribute | `str` | Space-delimited string of all required scopes (`" ".join(self.scopes)`), formatted per RFC 6749 for `WWW-Authenticate` headers. |

### Example

```python
from typing import Annotated

from fastapi import FastAPI, HTTPException, Security
from fastapi.security import OAuth2PasswordBearer, SecurityScopes
from fastapi.testclient import TestClient

app = FastAPI()
oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="token",
    scopes={"users:read": "Read user profile", "items:write": "Modify items"},
)


def require_scopes(
    security_scopes: SecurityScopes,
    token: Annotated[str, Security(oauth2_scheme)],
) -> str:
    authenticate_value = (
        f'Bearer scope="{security_scopes.scope_str}"'
        if security_scopes.scopes
        else "Bearer"
    )
    token_scopes = set(token.split(","))
    if not set(security_scopes.scopes).issubset(token_scopes):
        raise HTTPException(
            status_code=401,
            detail="Not enough permissions",
            headers={"WWW-Authenticate": authenticate_value},
        )
    return security_scopes.scope_str


def get_active_actor(
    scope_str: Annotated[str, Security(require_scopes, scopes=["users:read"])],
) -> str:
    return scope_str


@app.post("/items")
def update_item(
    merged_scopes: Annotated[
        str,
        Security(get_active_actor, scopes=["items:write"]),
    ],
) -> dict[str, str]:
    return {"required": merged_scopes}


client = TestClient(app)
ok = client.post(
    "/items",
    headers={"Authorization": "Bearer users:read,items:write"},
)
missing = client.post(
    "/items",
    headers={"Authorization": "Bearer users:read"},
)
assert ok.status_code == 200
assert ok.json() == {"required": "items:write users:read"}
assert missing.status_code == 401
assert 'scope="items:write users:read"' in missing.headers["www-authenticate"]
```

---

## `attr` FastAPI.dependency_overrides

Mutable dictionary attribute on `FastAPI` instances mapping original dependency callables to replacement callables. During request resolution, FastAPI checks `app.dependency_overrides` before invoking any `Depends()` or `Security()` target, enabling isolated unit and integration tests without mutating route definitions.

```python
app.dependency_overrides: dict[Callable[..., Any], Callable[..., Any]] = {}
```

### Specification

| Aspect | Type / Pattern | Description |
| :--- | :--- | :--- |
| Dictionary Key | `Callable[..., Any]` | Original dependency function or callable object referenced in `Depends(...)` or `Security(...)`. |
| Dictionary Value | `Callable[..., Any]` | Sync or async replacement callable; its own FastAPI parameters (`Query`, `Header`, nested `Depends`) are also resolved normally. |
| Teardown Reset | `app.dependency_overrides.clear()` | Restores production dependency bindings after a test case completes. |

### Example

```python
from typing import Annotated

from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

app = FastAPI()


def get_billing_gateway() -> dict[str, str]:
    raise RuntimeError("External network disabled in unit tests")


@app.get("/checkout/status")
def checkout_status(
    gateway: Annotated[dict[str, str], Depends(get_billing_gateway)],
) -> dict[str, str]:
    return gateway


def mock_billing_gateway(sandbox_mode: bool = True) -> dict[str, str]:
    return {"provider": "sandbox" if sandbox_mode else "live", "status": "ok"}


app.dependency_overrides[get_billing_gateway] = mock_billing_gateway
try:
    client = TestClient(app)
    res = client.get("/checkout/status?sandbox_mode=true")
    assert res.status_code == 200
    assert res.json() == {"provider": "sandbox", "status": "ok"}
finally:
    app.dependency_overrides.clear()
```
