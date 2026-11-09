# `SecurityBase` Hierarchy, `HTTPConnection` & `SecurityScopes`

FastAPI implements authentication and authorization not as separate WSGI/ASGI middleware layers, but as first-class nodes inside the `Dependant` dependency injection graph. Every built-in class under `fastapi/security/` inherits from `SecurityBase` (`fastapi/security/base.py`), serving simultaneously as an **asynchronous runtime credential extractor** (`async def __call__(self, request: HTTPConnection)`) and a **compile-time OpenAPI 3.1 `SecurityScheme` descriptor** (`self.model` and `self.scheme_name`). Paired with `Security(..., scopes=[...])` and Starlette's `HTTPConnection` base class, a single security dependency works uniformly across HTTP endpoints, WebSocket handshakes, OAuth2 scope hierarchies, and multi-scheme fallback chains.

```drawlib align=center code=hide file=security_base_class_hierarchy.png caption="The SecurityBase class hierarchy in fastapi/security/: every concrete extractor pairs an OpenAPI SecurityBaseModel with an HTTPConnection runtime callable."
from drawlib.canvas import setup
from drawlib.diagrams.class_diagram import ClassDiagram, ClassNode
from drawlib.fonts import FontRoboto, FontSourceCode
from drawlib.styles import Colors, Styles

setup(width=218, height=166)

cd = ClassDiagram(
    node_style=Styles.Neutral.patch(text_font=FontSourceCode.ROBOTO_MONO, text_size=10.0),
    header_style=Styles.PrimaryNeutral.patch(text_font=FontRoboto.ROBOTO_BOLD, text_size=10.5),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    title="SecurityBase Class Hierarchy & OpenAPI Model Composition",
)

sec_header = Styles.SecondaryNeutral.patch(text_font=FontRoboto.ROBOTO_BOLD, text_size=10.5)

oidc = cd.add(
    ClassNode("OpenIdConnect", width=58)
    .add_attribute("model", "OpenIdConnectModel")
    .add_method("__call__", "req: HTTPConnection", "str | None"),
    xy=(31.0, 132.0),
)
sec_base = cd.add(
    ClassNode(
        "SecurityBase",
        width=50,
        header_style=Styles.PrimaryFlat.patch(
            text_font=FontRoboto.ROBOTO_BOLD,
            text_size=11.0,
            text_color=Colors.White,
        ),
    )
    .add_attribute("model", "SecurityBaseModel")
    .add_attribute("scheme_name", "str"),
    xy=(31.0, 86.0),
)
oas_model = cd.add(
    ClassNode("SecurityBaseModel", width=50, header_style=sec_header)
    .add_attribute("type_", "SecuritySchemeType")
    .add_attribute("description", "str | None"),
    xy=(31.0, 38.0),
)

oauth2 = cd.add(
    ClassNode("OAuth2", width=52)
    .add_attribute("model", "OAuth2Model")
    .add_attribute("auto_error", "bool", default_value="True"),
    xy=(106.0, 134.0),
)
http_base = cd.add(
    ClassNode("HTTPBase", width=52)
    .add_attribute("model", "HTTPBaseModel")
    .add_attribute("auto_error", "bool", default_value="True"),
    xy=(106.0, 86.0),
)
apikey_base = cd.add(
    ClassNode("APIKeyBase", width=58)
    .add_attribute("model", "APIKey")
    .add_method("check_api_key", "key: str | None", "str | None"),
    xy=(106.0, 31.0),
)

pw_bearer = cd.add(
    ClassNode("OAuth2PasswordBearer", width=56, header_style=sec_header)
    .add_attribute("tokenUrl", "str"),
    xy=(180.0, 143.0),
)
code_bearer = cd.add(
    ClassNode("OAuth2AuthorizationCodeBearer", width=56, header_style=sec_header)
    .add_attribute("authorizationUrl", "str"),
    xy=(180.0, 124.0),
)

http_bearer = cd.add(
    ClassNode("HTTPBearer", width=48, header_style=sec_header)
    .add_attribute("bearerFormat", "str | None"),
    xy=(180.0, 103.0),
)
http_basic = cd.add(
    ClassNode("HTTPBasic", width=48, header_style=sec_header)
    .add_attribute("realm", "str | None"),
    xy=(180.0, 86.0),
)
http_digest = cd.add(
    ClassNode("HTTPDigest", width=48, header_style=sec_header)
    .add_attribute("scheme", "str", default_value="'digest'"),
    xy=(180.0, 69.0),
)

ak_header = cd.add(
    ClassNode("APIKeyHeader", width=48, header_style=sec_header)
    .add_attribute("in_", "APIKeyIn.header"),
    xy=(180.0, 48.0),
)
ak_cookie = cd.add(
    ClassNode("APIKeyCookie", width=48, header_style=sec_header)
    .add_attribute("in_", "APIKeyIn.cookie"),
    xy=(180.0, 31.0),
)
ak_query = cd.add(
    ClassNode("APIKeyQuery", width=48, header_style=sec_header)
    .add_attribute("in_", "APIKeyIn.query"),
    xy=(180.0, 14.0),
)

cd.connect(oidc, sec_base, "inheritance", start_side="bottom", end_side="top")
cd.connect(
    sec_base,
    oas_model,
    "composition",
    label="self.model",
    directed=True,
    start_side="bottom",
    end_side="top",
)

cd.connect(oauth2, sec_base, "inheritance", start_side="left", end_side="right")
cd.connect(http_base, sec_base, "inheritance", start_side="left", end_side="right")
cd.connect(apikey_base, sec_base, "inheritance", start_side="left", end_side="right")

cd.connect(pw_bearer, oauth2, "inheritance", start_side="left", end_side="right")
cd.connect(code_bearer, oauth2, "inheritance", start_side="left", end_side="right")

cd.connect(http_bearer, http_base, "inheritance", start_side="left", end_side="right")
cd.connect(http_basic, http_base, "inheritance", start_side="left", end_side="right")
cd.connect(http_digest, http_base, "inheritance", start_side="left", end_side="right")

cd.connect(ak_header, apikey_base, "inheritance", start_side="left", end_side="right")
cd.connect(ak_cookie, apikey_base, "inheritance", start_side="left", end_side="right")
cd.connect(ak_query, apikey_base, "inheritance", start_side="left", end_side="right")

cd.draw(xy=(4.0, 4.0))
```

## 1. Dual-Role Design of `SecurityBase`

`fastapi/security/base.py` is intentionally minimal—just seven lines declaring `model: SecurityBaseModel` and `scheme_name: str`. That minimal contract bridges two distinct subsystems without coupling them directly:

1. **Runtime DI Callable (`solve_dependencies`)**: Every concrete subclass implements `async def __call__(self, request: HTTPConnection) -> ...`. When an instance such as `oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/token")` is passed to `Depends(oauth2_scheme)` or `Security(oauth2_scheme, scopes=[...])`, `get_dependant()` inspects `oauth2_scheme.__call__`, binds `http_connection_param_name = "request"`, and executes the extractor as a standard async dependency node.
2. **Compile-Time OpenAPI Descriptor (`get_openapi`)**: During OpenAPI schema generation (`fastapi/openapi/utils.py`), `_is_security_scheme(dependant=...)` unwraps `dependant.call` via `inspect.unwrap(_impartial(call))` and checks `isinstance(unwrapped, SecurityBase)`. For every matched node, `_get_openapi_security_definitions()` serializes `security_scheme.model` with `jsonable_encoder(..., by_alias=True, exclude_none=True)` into `components.securitySchemes[scheme_name]` and merges accumulated OAuth2 scopes into the operation's `security` array.

| Family & Module | Concrete Extractors (`v0.162.2`) | OpenAPI `self.model` Type | Runtime Return Value & `401` Challenge |
| :--- | :--- | :--- | :--- |
| **`OAuth2`** (`oauth2.py`) | `OAuth2PasswordBearer`, `OAuth2AuthorizationCodeBearer` | `OAuth2Model` (`flows.password` / `flows.authorizationCode`) | Raw bearer token `str` (from `Authorization: Bearer <param>`); `WWW-Authenticate: Bearer`. |
| **`HTTPBase`** (`http.py`) | `HTTPBearer`, `HTTPBasic`, `HTTPDigest` | `HTTPBearerModel` / `HTTPBaseModel` (`scheme="basic" \| "digest"`) | `HTTPAuthorizationCredentials` or decoded `HTTPBasicCredentials`; `Bearer`, `Basic` (+ `realm`), `Digest`. |
| **`APIKeyBase`** (`api_key.py`) | `APIKeyHeader`, `APIKeyCookie`, `APIKeyQuery` | `APIKey` (`in`: `header`, `cookie`, or `query`) | Extracted key `str` via `check_api_key()`; `WWW-Authenticate: APIKey` (per RFC 9110). |
| **`OpenIdConnect`** (`open_id_connect_url.py`) | `OpenIdConnect` | `OpenIdConnectModel` (`openIdConnectUrl`) | Raw `Authorization` header `str` (OpenAPI integration stub); `WWW-Authenticate: Bearer`. |

Note that `OAuth2PasswordRequestForm` and `OAuth2PasswordRequestFormStrict` in `fastapi/security/oauth2.py` do **not** inherit from `SecurityBase`: they are regular class dependencies whose `__init__` signatures declare `Form()` fields (`grant_type`, `username`, `password`, space-delimited `scope`, `client_id`, and `client_secret`) for token-issuing endpoints rather than protected resource routes. Similarly, `HTTPDigest` and `OpenIdConnect` extract header strings and register OpenAPI definitions, leaving cryptographic digest or OIDC discovery verification to user subclasses.

## 2. Starlette `HTTPConnection` Unification (`Request` & `WebSocket`)

A subtle detail across `oauth2.py`, `http.py`, `api_key.py`, and `open_id_connect_url.py` is the parameter annotation on every `__call__` method:

- Every extractor declares `async def __call__(self, request: HTTPConnection) -> ...` using `starlette.requests.HTTPConnection` rather than `fastapi.Request`.
- In Starlette's class hierarchy, both `Request` (HTTP) and `WebSocket` (WS) subclass `HTTPConnection`, which provides uniform read-only access to `.headers`, `.query_params`, `.cookies`, `.path_params`, and `.scope`.
- During compile-time analysis, `add_non_field_param_to_dependency()` (`fastapi/dependencies/utils.py`) checks `Request`, then `WebSocket`, and then `HTTPConnection`, recording `dependant.http_connection_param_name = "request"`.
- At runtime, `solve_dependencies(request: Request | WebSocket, ...)` unconditionally binds `values[dependant.http_connection_param_name] = request` before checking `isinstance(request, Request)` or `isinstance(request, WebSocket)`. Consequently, `APIKeyCookie`, `HTTPBearer`, and `OAuth2PasswordBearer` work out of the box inside `@app.websocket("/ws")` routes during handshake dependency resolution without writing separate WebSocket extractors.

## 3. Top-Down `SecurityScopes` Propagation & `auto_error=False` Chains

### 3.1 `Security(..., scopes=[...])` & `SecurityScopes`

`params.Security` is a frozen `@dataclass` subclass of `params.Depends` that adds `scopes: Sequence[str] | None = None`. Scope propagation flows **top-down** during `get_dependant()` compilation:

1. At each `Dependant` node, `get_dependant()` computes `current_scopes = (parent_oauth_scopes or []) + (own_oauth_scopes or [])`.
2. Whenever a parameter uses `Security(sub_call, scopes=["audit:read"])`, FastAPI passes `own_oauth_scopes=["audit:read"]` and `parent_oauth_scopes=current_scopes` into the child `get_dependant()` call.
3. Any leaf or intermediate dependency that declares a `security_scopes: SecurityScopes` parameter has `dependant.security_scopes_param_name` populated. During `solve_dependencies()`, FastAPI instantiates `SecurityScopes(scopes=_get_oauth_scopes(dependant=dependant))`, deduplicating scopes in declaration order and pre-joining `security_scopes.scope_str = " ".join(self.scopes)` per RFC 6749.
4. Because `_uses_scopes()` returns `True` for any node referencing `SecurityScopes`, `own_oauth_scopes`, or `SecurityBase`, `_get_cache_key()` embeds `tuple(sorted(set(scopes)))` into `DependencyCacheKey`, isolating cached evaluations if two branches within the same route demand different scope sets.

### 3.2 `auto_error=False` & Logical-OR Authentication Composition

By default (`auto_error=True`), any missing header/cookie or mismatched scheme (such as `Basic` sent to `HTTPBearer`) immediately raises `HTTPException(status_code=401, detail="Not authenticated", headers={"WWW-Authenticate": ...})`, short-circuiting `solve_dependencies()`. (Note one intentional exception in `HTTPBasic`: if an `Authorization: Basic ...` header *is* present, invalid Base64 or a payload missing the `:` separator always raises `401` even when `auto_error=False`, preventing malformed credentials from silently degrading to anonymous requests.)

When `auto_error=False` is passed to multiple extractors—for example, pairing `OAuth2PasswordBearer(..., auto_error=False)` for API clients with a hardened `APIKeyCookie(name="__Host-session", auto_error=False)` for browser sessions—absent credentials return `None` instead of raising. A composite verifier dependency can then evaluate `token or session_id` in Python, enforce `SecurityScopes`, and raise a single `401`/`403` only when all authentication channels are empty, while `get_openapi()` automatically registers both schemes in `components.securitySchemes`.

```drawlib align=center code=hide file=http_connection_scope_propagation.png caption="Unified HTTPConnection injection across HTTP and WebSocket routes, top-down SecurityScopes accumulation, and auto_error=False OR-auth composition."
from drawlib.canvas import setup
from drawlib.diagrams.architecture import ArchitectureDiagram, Node, NodeGroup, PhosphorIcon
from drawlib.styles import Colors, Styles

setup(width=184, height=112)

d = ArchitectureDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.5),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
    title="HTTPConnection Unification, OR-Auth & Scope Inheritance",
)

conn_grp = d.add(
    NodeGroup(
        title="Starlette Transports",
        padding=5.5,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left"),
    ),
    xy=(4.0, 4.0),
)
req_node = conn_grp.add(
    Node(
        "HTTP Request\nget_request_handler()",
        width=34,
        height=16,
        icon=PhosphorIcon.GLOBE,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(22.5, 68.0),
)
http_conn = conn_grp.add(
    Node(
        "HTTPConnection\nheaders / cookies / query",
        width=34,
        height=16,
        icon=PhosphorIcon.SHARE_NETWORK,
        icon_size=6.5,
        card_style=Styles.PrimaryFlat,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.5),
    ),
    xy=(22.5, 41.0),
)
ws_node = conn_grp.add(
    Node(
        "WebSocket Session\nget_websocket_app()",
        width=34,
        height=16,
        icon=PhosphorIcon.PLUGS_CONNECTED,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(22.5, 14.0),
)

or_grp = d.add(
    NodeGroup(
        title="OR-Auth (auto_error=False)",
        padding=5.5,
        style=Styles.SecondaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left"),
    ),
    xy=(62.0, 4.0),
)
bearer_node = or_grp.add(
    Node(
        "OAuth2PasswordBearer\nmissing -> returns None",
        width=36,
        height=16,
        icon=PhosphorIcon.KEY,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(23.5, 68.0),
)
cookie_node = or_grp.add(
    Node(
        "APIKeyCookie\n__Host-session -> str",
        width=36,
        height=16,
        icon=PhosphorIcon.USER_CHECK,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(23.5, 41.0),
)
verifier_node = or_grp.add(
    Node(
        "verify_credentials()\ntoken or session_id",
        width=36,
        height=16,
        icon=PhosphorIcon.SHIELD_CHECK,
        icon_size=6.5,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(23.5, 14.0),
)

scope_grp = d.add(
    NodeGroup(
        title="Top-Down Scope Chain",
        padding=5.5,
        style=Styles.PrimaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left"),
    ),
    xy=(122.0, 4.0),
)
ep_sec = scope_grp.add(
    Node(
        "Endpoint Security()\nown=['audit:read']",
        width=34,
        height=16,
        icon=PhosphorIcon.LOCK_KEY,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(22.5, 68.0),
)
mid_sec = scope_grp.add(
    Node(
        "Sub-Dep Security()\nown=['users:me']",
        width=34,
        height=16,
        icon=PhosphorIcon.SHIELD,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(22.5, 41.0),
)
scopes_box = scope_grp.add(
    Node(
        "SecurityScopes\n'audit:read users:me'",
        width=34,
        height=16,
        icon=PhosphorIcon.KEY,
        icon_size=6.5,
        card_style=Styles.AccentFlat,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.5),
    ),
    xy=(22.5, 14.0),
)

d.connect(req_node, http_conn, label="subclass", padding=1.2)
d.connect(ws_node, http_conn, label="subclass", padding=1.2)

j_bus_mid = d.junction(xy=(55.0, 45.0))
j_bus_top = d.junction(xy=(55.0, 72.0))
d.connect(http_conn, j_bus_mid, arrow="-", padding=(1.2, 0.0))
d.connect(j_bus_mid, j_bus_top, arrow="-")
j_bus_top.connect(bearer_node, padding=(0.0, 1.2))
j_bus_mid.connect(cookie_node, padding=(0.0, 1.2))

d.connect(cookie_node, verifier_node, label="fallback", padding=1.2)

d.connect(ep_sec, mid_sec, label="parent_scopes", padding=1.2)
d.connect(mid_sec, scopes_box, label="_get_oauth_scopes()", padding=1.2)
d.connect(scopes_box, verifier_node, label="inject", padding=1.5)

d.draw(xy=(6.0, 5.0))
```

## 4. Verifying `SecurityBase.model` & Nested `SecurityScopes` Propagation

The snippet below inspects `OAuth2PasswordBearer.model` for OpenAPI serialization, verifies `http_connection_param_name` binding on leaf extractors, and runs `solve_dependencies()` across a three-tier `Security()` chain using `auto_error=False` cookie fallback:

```python
import asyncio
from contextlib import AsyncExitStack
import secrets
from typing import Annotated

from fastapi import Depends, Request, Security
from fastapi.dependencies.models import _get_oauth_scopes
from fastapi.dependencies.utils import get_dependant, solve_dependencies
from fastapi.encoders import jsonable_encoder
from fastapi.security import APIKeyCookie, OAuth2PasswordBearer, SecurityScopes
from fastapi.security.base import SecurityBase

bearer_auth = OAuth2PasswordBearer(
    tokenUrl="/oauth/token",
    scopes={"items:read": "Read items"},
    auto_error=False,
)
cookie_auth = APIKeyCookie(name="__Host-session", auto_error=False)

assert isinstance(bearer_auth, SecurityBase)
assert jsonable_encoder(bearer_auth.model, by_alias=True, exclude_none=True) == {
    "type": "oauth2",
    "flows": {
        "password": {
            "tokenUrl": "/oauth/token",
            "scopes": {"items:read": "Read items"},
        }
    },
}


async def verify_credentials(
    security_scopes: SecurityScopes,
    token: Annotated[str | None, Depends(bearer_auth)],
    session_id: Annotated[str | None, Depends(cookie_auth)],
) -> dict[str, object]:
    return {
        "credential": token or session_id,
        "scope_str": security_scopes.scope_str,
    }


async def get_active_principal(
    verified: Annotated[
        dict[str, object],
        Security(verify_credentials, scopes=["users:me"]),
    ],
) -> dict[str, object]:
    return verified


async def read_audit_log(
    principal: Annotated[
        dict[str, object],
        Security(get_active_principal, scopes=["audit:read"]),
    ],
) -> dict[str, object]:
    return principal


root = get_dependant(path="/audit", call=read_audit_log, scope="function")
verify_dep = root.dependencies[0].dependencies[0]
bearer_dep, cookie_dep = verify_dep.dependencies

assert bearer_dep.http_connection_param_name == "request"
assert cookie_dep.http_connection_param_name == "request"
assert _get_oauth_scopes(dependant=verify_dep) == ["audit:read", "users:me"]


async def _solve_with_cookie_fallback() -> dict[str, object]:
    ephemeral_session = secrets.token_urlsafe(16)
    async with AsyncExitStack() as inner_stack, AsyncExitStack() as fn_stack:
        scope = {
            "type": "http",
            "method": "GET",
            "path": "/audit",
            "headers": [
                (b"cookie", f"__Host-session={ephemeral_session}".encode("ascii"))
            ],
            "query_string": b"",
            "path_params": {},
            "fastapi_inner_astack": inner_stack,
            "fastapi_function_astack": fn_stack,
        }
        solved = await solve_dependencies(
            request=Request(scope),
            dependant=root,
            async_exit_stack=inner_stack,
            embed_body_fields=False,
        )
        return solved.values["principal"]


result = asyncio.run(_solve_with_cookie_fallback())
assert result["scope_str"] == "audit:read users:me"
assert isinstance(result["credential"], str)
```

For how `Dependant` nodes and per-request cache keys are compiled and cached, see [Dependant DAG & solve_dependencies](dependant_and_solver.md); for how `_get_openapi_security_definitions()` emits OpenAPI 3.1 `securitySchemes`, see [get_openapi(), $defs & Docs UI](../06_openapi_and_docs/openapi_synthesis_engine.md).
