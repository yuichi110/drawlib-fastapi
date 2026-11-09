# fastapi.security

`fastapi.security` provides callable authentication extractors, credential models, and form parsers that extract credentials from incoming HTTP connections while automatically registering standard security schemes (OAuth2, HTTP Basic/Bearer/Digest, API Keys, and OpenID Connect) in OpenAPI (`/openapi.json` and `/docs`).

```drawlib align=center code=hide file=fastapi_security_schemes_map.png caption="FastAPI Built-In Security Extractors & Credential Helpers"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.lines import line
from drawlib.shapes import rectangle
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Colors, Styles
from drawlib.text import text

setup(width=156, height=88)

_ = Colors
rectangle((78, 78), width=68, height=10, style=Styles.PrimaryFlat.patch(shape_r=2.0))
phosphor.shield_check((49, 78), width=5.2, style=Styles.WhiteBold)
text((81, 78), "SecurityBase (model, scheme_name)", style=Styles.WhiteBold.patch(text_size=11.0))

line((78, 73), (78, 20.5), style=Styles.DarkBold.patch(line_width=1.6))
line((78, 53.5), (71.5, 53.5), arrow_head="->", style=Styles.DarkBold.patch(line_width=1.5))
line((78, 53.5), (84.5, 53.5), arrow_head="->", style=Styles.DarkBold.patch(line_width=1.5))
line((78, 20.5), (71.5, 20.5), arrow_head="->", style=Styles.DarkBold.patch(line_width=1.5))
line((78, 20.5), (84.5, 20.5), arrow_head="->", style=Styles.DarkBold.patch(line_width=1.5))

specs = [
    (
        (5.0, 39.0),
        "OAuth2 Schemes & Forms",
        Styles.PrimaryNeutral,
        phosphor.key,
        [
            "OAuth2PasswordBearer (password flow)",
            "OAuth2AuthorizationCodeBearer (code flow)",
            "OAuth2PasswordRequestForm (+Strict)",
        ],
    ),
    (
        (85.0, 39.0),
        "HTTP Auth & Credentials",
        Styles.Neutral,
        phosphor.lock_key,
        [
            "HTTPBearer / HTTPBasic / HTTPDigest",
            "HTTPAuthorizationCredentials (scheme, ...)",
            "HTTPBasicCredentials (username, password)",
        ],
    ),
    (
        (5.0, 6.0),
        "API Key Extractors",
        Styles.Neutral,
        phosphor.identification_badge,
        [
            "APIKeyHeader (request.headers)",
            "APIKeyQuery (request.query_params)",
            "APIKeyCookie (request.cookies)",
        ],
    ),
    (
        (85.0, 6.0),
        "OIDC & Scheme Helpers",
        Styles.PrimaryNeutral,
        phosphor.globe,
        [
            "OpenIdConnect (openIdConnectUrl)",
            "OAuth2 (custom flows base class)",
            "get_authorization_scheme_param()",
        ],
    ),
]

for xy, title, body_style, icon_fn, rows in specs:
    panel = Panel(
        title,
        "",
        style=body_style,
        header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
        text_style=Styles.DarkBold.patch(text_size=10.8),
        icon=icon_fn,
        icon_style=Styles.DarkBold,
        header_variant="filled",
        header_height=7.5,
    )
    panel.draw(xy, width=66.0, height=29.0, align="bottom_left")
    c_xy, c_w, c_h = panel.get_content_box(xy, width=66.0, height=29.0, padding=(2.8, 2.2))
    cards = CardList(
        style=Styles.White,
        text_style=Styles.DarkBold.patch(text_size=10.0),
        badge_style=Styles.SecondaryNeutral,
        badge_text_style=Styles.DarkBold.patch(text_size=10.0),
        spacing=1.5,
    )
    for idx, label in enumerate(rows, start=1):
        cards.add(label, badge_text=str(idx))
    cards.draw(c_xy, width=c_w, height=c_h)

save()
```

---

## `class` OAuth2PasswordBearer

OAuth2 password-flow Bearer token extractor inheriting from `OAuth2`. When used in `Depends()` or `Security()`, it reads the `Authorization: Bearer <token>` header, returns `<token>` as a `str` (or `None` when `auto_error=False`), and registers an OAuth2 `password` flow pointing to `tokenUrl` in OpenAPI.

```python
class OAuth2PasswordBearer(OAuth2):
    def __init__(
        self,
        tokenUrl: str,
        scheme_name: str | None = None,
        scopes: dict[str, str] | None = None,
        description: str | None = None,
        auto_error: bool = True,
        refreshUrl: str | None = None,
    ) -> None: ...

    async def __call__(self, request: HTTPConnection) -> str | None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `tokenUrl` | `str` | *(Required)* | Relative or absolute URL where clients exchange credentials for a token (typically using `OAuth2PasswordRequestForm`). |
| `scheme_name` | `str \| None` | `None` | Custom security scheme identifier in OpenAPI `components.securitySchemes` (defaults to `"OAuth2PasswordBearer"`). |
| `scopes` | `dict[str, str] \| None` | `None` | Mapping of `{scope_name: description}` advertised in the OpenAPI schema. |
| `description` | `str \| None` | `None` | Human-readable scheme description shown in OpenAPI documentation. |
| `auto_error` | `bool` | `True` | Raises `HTTPException(401)` with `WWW-Authenticate: Bearer` if missing or non-Bearer; returns `None` when `False`. |
| `refreshUrl` | `str \| None` | `None` | Optional URL for refreshing expired access tokens in OpenAPI metadata. |

### Example

```python
import secrets
from typing import Annotated

from fastapi import Depends, FastAPI
from fastapi.security import OAuth2PasswordBearer
from fastapi.testclient import TestClient

app = FastAPI()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token", refreshUrl="/auth/refresh")
runtime_token = secrets.token_urlsafe(24)


@app.get("/me")
def read_me(token: Annotated[str, Depends(oauth2_scheme)]) -> dict[str, bool]:
    return {"authenticated": secrets.compare_digest(token, runtime_token)}


client = TestClient(app)
ok = client.get("/me", headers={"Authorization": f"Bearer {runtime_token}"})
unauth = client.get("/me")
assert ok.status_code == 200
assert ok.json() == {"authenticated": True}
assert unauth.status_code == 401
```

---

## `class` OAuth2AuthorizationCodeBearer

OAuth2 authorization-code flow Bearer token extractor inheriting from `OAuth2`. Extracts the Bearer token from the `Authorization` header while configuring OpenAPI `authorizationCode` flow URLs (`authorizationUrl`, `tokenUrl`, and optional `refreshUrl`) for interactive `/docs` login flows with external identity providers.

```python
class OAuth2AuthorizationCodeBearer(OAuth2):
    def __init__(
        self,
        authorizationUrl: str,
        tokenUrl: str,
        refreshUrl: str | None = None,
        scheme_name: str | None = None,
        scopes: dict[str, str] | None = None,
        description: str | None = None,
        auto_error: bool = True,
    ) -> None: ...

    async def __call__(self, request: HTTPConnection) -> str | None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `authorizationUrl` | `str` | *(Required)* | Identity provider authorization endpoint URL for browser redirects. |
| `tokenUrl` | `str` | *(Required)* | Token exchange endpoint URL where authorization codes are redeemed. |
| `refreshUrl` | `str \| None` | `None` | Optional token refresh endpoint URL in OpenAPI. |
| `scheme_name` | `str \| None` | `None` | OpenAPI security scheme name (defaults to `"OAuth2AuthorizationCodeBearer"`). |
| `scopes` | `dict[str, str] \| None` | `None` | Dictionary of `{scope_name: description}` documented for this authorization code flow. |
| `description` | `str \| None` | `None` | Human-readable OpenAPI security scheme description. |
| `auto_error` | `bool` | `True` | Automatically responds with `401 Unauthorized` when missing or non-Bearer; returns `None` if `False`. |

### Example

```python
import secrets
from typing import Annotated

from fastapi import FastAPI, Security
from fastapi.security import OAuth2AuthorizationCodeBearer
from fastapi.testclient import TestClient

app = FastAPI()
auth_code_scheme = OAuth2AuthorizationCodeBearer(
    authorizationUrl="https://idp.example.com/oauth2/authorize",
    tokenUrl="https://idp.example.com/oauth2/token",
    scopes={"openid": "OpenID profile", "projects:read": "Read projects"},
)
issued_token = secrets.token_urlsafe(24)


@app.get("/projects")
def list_projects(
    token: Annotated[
        str,
        Security(auth_code_scheme, scopes=["projects:read"]),
    ],
) -> dict[str, bool]:
    return {"valid_token": secrets.compare_digest(token, issued_token)}


client = TestClient(app)
res = client.get("/projects", headers={"Authorization": f"Bearer {issued_token}"})
assert res.status_code == 200
assert res.json() == {"valid_token": True}
```

---

## `class` OAuth2PasswordRequestForm

Form-data dependency class (`application/x-www-form-urlencoded` or `multipart/form-data`) for OAuth2 password token endpoints. Parses `username`, `password`, optional `grant_type`, space-separated `scope`, `client_id`, and `client_secret` fields from the request body, splitting `scope` into `self.scopes: list[str]`.

```python
class OAuth2PasswordRequestForm:
    grant_type: str | None
    username: str
    password: str
    scopes: list[str]
    client_id: str | None
    client_secret: str | None

    def __init__(
        self,
        *,
        grant_type: str | None = Form(default=None, pattern="^password$"),
        username: str = Form(),
        password: str = Form(),
        scope: str = Form(default=""),
        client_id: str | None = Form(default=None),
        client_secret: str | None = Form(default=None),
    ) -> None: ...
```

### Parameters & Attributes

| Name | Form Field / Attribute | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `grant_type` | Form & Attribute | `str \| None` | `None` | Optional in `OAuth2PasswordRequestForm`; if sent, must match `^password$`. |
| `username` | Form & Attribute | `str` | *(Required)* | Exact `username` form field mandated by RFC 6749. |
| `password` | Form & Attribute | `str` | *(Required)* | Exact `password` form field (`format: "password"` in OpenAPI). |
| `scope` / `scopes` | Form `scope` -> Attr `scopes` | `str` -> `list[str]` | `""` -> `[]` | Space-delimited `scope` form string parsed via `scope.split()` into `self.scopes`. |
| `client_id` | Form & Attribute | `str \| None` | `None` | Optional OAuth2 client identifier submitted in form body. |
| `client_secret` | Form & Attribute | `str \| None` | `None` | Optional OAuth2 client secret submitted in form body. |

### Example

```python
import secrets
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.testclient import TestClient

app = FastAPI()
expected_password = secrets.token_urlsafe(16)


@app.post("/auth/token")
def issue_token(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
) -> dict[str, object]:
    if not (
        secrets.compare_digest(form_data.username, "alice")
        and secrets.compare_digest(form_data.password, expected_password)
    ):
        raise HTTPException(status_code=400, detail="Invalid credentials")
    return {
        "access_token": secrets.token_urlsafe(24),
        "token_type": "bearer",
        "scopes": form_data.scopes,
    }


client = TestClient(app)
res = client.post(
    "/auth/token",
    data={"username": "alice", "password": expected_password, "scope": "read write"},
)
assert res.status_code == 200
assert res.json()["scopes"] == ["read", "write"]
```

---

## `class` OAuth2PasswordRequestFormStrict

Strict subclass of `OAuth2PasswordRequestForm` that enforces RFC 6749 compliance by requiring the client to submit `grant_type="password"` in the form payload (rejecting requests that omit `grant_type` with `422 Unprocessable Content`).

```python
class OAuth2PasswordRequestFormStrict(OAuth2PasswordRequestForm):
    def __init__(
        self,
        grant_type: str = Form(pattern="^password$"),
        username: str = Form(),
        password: str = Form(),
        scope: str = Form(default=""),
        client_id: str | None = Form(default=None),
        client_secret: str | None = Form(default=None),
    ) -> None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `grant_type` | `str` | *(Required)* | Must be submitted and match `^password$`. |
| `username` | `str` | *(Required)* | Required `username` form field. |
| `password` | `str` | *(Required)* | Required `password` form field. |
| `scope` | `str` | `""` | Space-separated scope names split into `self.scopes: list[str]`. |
| `client_id` | `str \| None` | `None` | Optional OAuth2 client identifier. |
| `client_secret` | `str \| None` | `None` | Optional OAuth2 client secret. |

### Example

```python
import secrets
from typing import Annotated

from fastapi import Depends, FastAPI
from fastapi.security import OAuth2PasswordRequestFormStrict
from fastapi.testclient import TestClient

app = FastAPI()
runtime_pw = secrets.token_urlsafe(16)


@app.post("/auth/strict-token")
def strict_login(
    form_data: Annotated[OAuth2PasswordRequestFormStrict, Depends()],
) -> dict[str, str]:
    return {"grant_type": form_data.grant_type or "", "user": form_data.username}


client = TestClient(app)
missing_grant = client.post(
    "/auth/strict-token",
    data={"username": "alice", "password": runtime_pw},
)
valid_grant = client.post(
    "/auth/strict-token",
    data={"grant_type": "password", "username": "alice", "password": runtime_pw},
)
assert missing_grant.status_code == 422
assert valid_grant.status_code == 200
assert valid_grant.json() == {"grant_type": "password", "user": "alice"}
```

---

## `class` OAuth2

Base OAuth2 security scheme class inheriting from `SecurityBase`. Accepts arbitrary OpenAPI `OAuthFlows` (`implicit`, `password`, `clientCredentials`, `authorizationCode`) and extracts the raw `Authorization` header string when called as a dependency.

```python
class OAuth2(SecurityBase):
    def __init__(
        self,
        *,
        flows: OAuthFlows | dict[str, dict[str, Any]] = OAuthFlows(),
        scheme_name: str | None = None,
        description: str | None = None,
        auto_error: bool = True,
    ) -> None: ...

    async def __call__(self, request: HTTPConnection) -> str | None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `flows` | `OAuthFlows \| dict[str, dict[str, Any]]` | `OAuthFlows()` | OpenAPI OAuth2 flows model or dictionary configuring `clientCredentials`, `implicit`, `password`, or `authorizationCode`. |
| `scheme_name` | `str \| None` | `None` | Security scheme name in OpenAPI (defaults to `"OAuth2"`). |
| `description` | `str \| None` | `None` | Description included in OpenAPI security scheme metadata. |
| `auto_error` | `bool` | `True` | Raises `HTTPException(401)` if the `Authorization` header is absent; returns `None` when `False`. |

### Example

```python
import secrets
from typing import Annotated

from fastapi import Depends, FastAPI
from fastapi.security import OAuth2
from fastapi.testclient import TestClient

app = FastAPI()
m2m_oauth2 = OAuth2(
    flows={
        "clientCredentials": {
            "tokenUrl": "https://auth.example.com/oauth/token",
            "scopes": {"metrics:ingest": "Push service metrics"},
        }
    },
    scheme_name="ServiceClientCredentials",
)
service_token = secrets.token_urlsafe(20)


@app.get("/metrics/ping")
def ping_metrics(raw_auth: Annotated[str, Depends(m2m_oauth2)]) -> dict[str, bool]:
    return {"has_bearer": raw_auth.startswith("Bearer ")}


client = TestClient(app)
res = client.get(
    "/metrics/ping",
    headers={"Authorization": f"Bearer {service_token}"},
)
assert res.status_code == 200
assert res.json() == {"has_bearer": True}
```

---

## `class` HTTPBearer

HTTP Bearer authentication scheme (`Authorization: Bearer <credentials>`). Validates that the `Authorization` scheme equals `"bearer"` (case-insensitive) and returns an `HTTPAuthorizationCredentials` model containing `scheme` and `credentials`.

```python
class HTTPBearer(HTTPBase):
    def __init__(
        self,
        *,
        bearerFormat: str | None = None,
        scheme_name: str | None = None,
        description: str | None = None,
        auto_error: bool = True,
    ) -> None: ...

    async def __call__(
        self,
        request: HTTPConnection,
    ) -> HTTPAuthorizationCredentials | None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `bearerFormat` | `str \| None` | `None` | Optional documentation hint for token structure in OpenAPI (e.g. `"JWT"`). |
| `scheme_name` | `str \| None` | `None` | OpenAPI security scheme identifier (defaults to `"HTTPBearer"`). |
| `description` | `str \| None` | `None` | Human-readable scheme description for OpenAPI. |
| `auto_error` | `bool` | `True` | Raises `401 Unauthorized` when missing or non-Bearer; returns `None` if `False`. |

### Example

```python
import secrets
from typing import Annotated

from fastapi import Depends, FastAPI
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.testclient import TestClient

app = FastAPI()
bearer_scheme = HTTPBearer(bearerFormat="JWT", auto_error=False)
active_jwt = secrets.token_urlsafe(24)


@app.get("/session")
def inspect_session(
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> dict[str, str]:
    if creds is None:
        return {"mode": "anonymous"}
    is_match = secrets.compare_digest(creds.credentials, active_jwt)
    return {"mode": "authenticated" if is_match else "invalid"}


client = TestClient(app)
anon = client.get("/session")
authed = client.get("/session", headers={"Authorization": f"Bearer {active_jwt}"})
assert anon.json() == {"mode": "anonymous"}
assert authed.json() == {"mode": "authenticated"}
```

---

## `class` HTTPBasic

HTTP Basic authentication scheme (RFC 7617). Decodes Base64 `Authorization: Basic <base64(username:password)>` headers and injects an `HTTPBasicCredentials` instance. Always compare `username` and `password` with `secrets.compare_digest()` to prevent timing side-channel leaks.

```python
class HTTPBasic(HTTPBase):
    def __init__(
        self,
        *,
        scheme_name: str | None = None,
        realm: str | None = None,
        description: str | None = None,
        auto_error: bool = True,
    ) -> None: ...

    async def __call__(
        self,
        request: HTTPConnection,
    ) -> HTTPBasicCredentials | None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `scheme_name` | `str \| None` | `None` | OpenAPI security scheme identifier (defaults to `"HTTPBasic"`). |
| `realm` | `str \| None` | `None` | Optional Basic authentication realm returned in `WWW-Authenticate: Basic realm="<realm>"`. |
| `description` | `str \| None` | `None` | Description included in OpenAPI documentation. |
| `auto_error` | `bool` | `True` | Raises `401 Unauthorized` when missing or malformed; note malformed Base64 always raises `401`. |

### Example

```python
import secrets
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from fastapi.testclient import TestClient

app = FastAPI()
basic_security = HTTPBasic(realm="AdminConsole")
admin_pass = secrets.token_urlsafe(18)


@app.get("/admin/health")
def admin_health(
    credentials: Annotated[HTTPBasicCredentials, Depends(basic_security)],
) -> dict[str, str]:
    user_ok = secrets.compare_digest(credentials.username.encode(), b"ops")
    pass_ok = secrets.compare_digest(
        credentials.password.encode(),
        admin_pass.encode(),
    )
    if not (user_ok and pass_ok):
        raise HTTPException(
            status_code=401,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": 'Basic realm="AdminConsole"'},
        )
    return {"operator": credentials.username}


client = TestClient(app)
res = client.get("/admin/health", auth=("ops", admin_pass))
assert res.status_code == 200
assert res.json() == {"operator": "ops"}
```

---

## `class` HTTPDigest

HTTP Digest authentication scheme stub (RFC 7616) for OpenAPI integration. Checks that the `Authorization` header starts with the `"Digest"` scheme and returns `HTTPAuthorizationCredentials`; full Digest nonce/hash verification requires subclassing `HTTPDigest`.

```python
class HTTPDigest(HTTPBase):
    def __init__(
        self,
        *,
        scheme_name: str | None = None,
        description: str | None = None,
        auto_error: bool = True,
    ) -> None: ...

    async def __call__(
        self,
        request: HTTPConnection,
    ) -> HTTPAuthorizationCredentials | None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `scheme_name` | `str \| None` | `None` | OpenAPI security scheme identifier (defaults to `"HTTPDigest"`). |
| `description` | `str \| None` | `None` | OpenAPI security scheme description. |
| `auto_error` | `bool` | `True` | Raises `401 Unauthorized` if no `Authorization: Digest ...` header is present; returns `None` when `False`. |

### Example

```python
import secrets
from typing import Annotated

from fastapi import Depends, FastAPI
from fastapi.security import HTTPAuthorizationCredentials, HTTPDigest
from fastapi.testclient import TestClient

app = FastAPI()
digest_scheme = HTTPDigest()
nonce_val = secrets.token_hex(8)


@app.get("/digest-check")
def check_digest(
    creds: Annotated[HTTPAuthorizationCredentials, Depends(digest_scheme)],
) -> dict[str, str]:
    return {"scheme": creds.scheme}


client = TestClient(app)
res = client.get(
    "/digest-check",
    headers={"Authorization": f'Digest username="ops", nonce="{nonce_val}"'},
)
assert res.status_code == 200
assert res.json() == {"scheme": "Digest"}
```

---

## `class` HTTPAuthorizationCredentials

Pydantic `BaseModel` returned by `HTTPBearer` and `HTTPDigest` dependencies, representing an HTTP `Authorization` header split on its first space into `scheme` and `credentials`.

```python
class HTTPAuthorizationCredentials(BaseModel):
    scheme: str
    credentials: str
```

### Attributes

| Field | Type | Description |
| :--- | :--- | :--- |
| `scheme` | `str` | Authorization scheme prefix extracted before the first space (e.g. `"Bearer"` or `"Digest"`). |
| `credentials` | `str` | Opaque token or parameter string following the first space in the `Authorization` header. |

### Example

```python
import secrets

from fastapi.security import HTTPAuthorizationCredentials

raw_token = secrets.token_urlsafe(16)
parsed = HTTPAuthorizationCredentials(scheme="Bearer", credentials=raw_token)
assert parsed.scheme == "Bearer"
assert parsed.model_dump() == {"scheme": "Bearer", "credentials": raw_token}
```

---

## `class` HTTPBasicCredentials

Pydantic `BaseModel` returned by `HTTPBasic`, holding the decoded `username` and `password` strings extracted from a Base64 HTTP Basic `Authorization` header.

```python
class HTTPBasicCredentials(BaseModel):
    username: str
    password: str
```

### Attributes

| Field | Type | Description |
| :--- | :--- | :--- |
| `username` | `str` | Decoded HTTP Basic username before the first `":"` separator. |
| `password` | `str` | Decoded HTTP Basic password after the first `":"` separator. |

### Example

```python
import secrets

from fastapi.security import HTTPBasicCredentials

generated_pw = secrets.token_urlsafe(16)
creds = HTTPBasicCredentials(username="service-bot", password=generated_pw)
assert creds.username == "service-bot"
assert secrets.compare_digest(creds.password, generated_pw)
```

---

## `class` APIKeyHeader

Extracts an API key from a named HTTP request header (`request.headers.get(name)`) and documents an `in: "header"` API key security scheme in OpenAPI. Missing keys raise `401 Unauthorized` with `WWW-Authenticate: APIKey` by default.

```python
class APIKeyHeader(APIKeyBase):
    def __init__(
        self,
        *,
        name: str,
        scheme_name: str | None = None,
        description: str | None = None,
        auto_error: bool = True,
    ) -> None: ...

    async def __call__(self, request: HTTPConnection) -> str | None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `name` | `str` | *(Required)* | HTTP header name to read (case-insensitive in ASGI headers, e.g. `"X-API-Key"`). |
| `scheme_name` | `str \| None` | `None` | OpenAPI security scheme identifier (defaults to `"APIKeyHeader"`). |
| `description` | `str \| None` | `None` | Description rendered in OpenAPI documentation. |
| `auto_error` | `bool` | `True` | Raises `401 Unauthorized` when missing or empty; returns `None` if `False`. |

### Example

```python
import os
import secrets
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException
from fastapi.security import APIKeyHeader
from fastapi.testclient import TestClient

app = FastAPI()
header_key_scheme = APIKeyHeader(name="X-Service-Key")
expected_key = os.environ.get("TEST_SERVICE_API_KEY") or secrets.token_urlsafe(24)


@app.get("/v1/inventory")
def get_inventory(
    api_key: Annotated[str, Depends(header_key_scheme)],
) -> dict[str, str]:
    if not secrets.compare_digest(api_key, expected_key):
        raise HTTPException(status_code=403, detail="Invalid API key")
    return {"status": "authorized"}


client = TestClient(app)
res = client.get("/v1/inventory", headers={"X-Service-Key": expected_key})
assert res.status_code == 200
assert res.json() == {"status": "authorized"}
```

---

## `class` APIKeyQuery

Extracts an API key from a named URL query parameter (`request.query_params.get(name)`) and registers an `in: "query"` API key security scheme in OpenAPI. Prefer `APIKeyHeader` or `HTTPBearer` for sensitive credentials so tokens are not recorded in access logs or browser history.

```python
class APIKeyQuery(APIKeyBase):
    def __init__(
        self,
        *,
        name: str,
        scheme_name: str | None = None,
        description: str | None = None,
        auto_error: bool = True,
    ) -> None: ...

    async def __call__(self, request: HTTPConnection) -> str | None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `name` | `str` | *(Required)* | Query string parameter name to inspect (e.g. `"sig"`). |
| `scheme_name` | `str \| None` | `None` | OpenAPI security scheme identifier (defaults to `"APIKeyQuery"`). |
| `description` | `str \| None` | `None` | Description rendered in OpenAPI documentation. |
| `auto_error` | `bool` | `True` | Raises `401 Unauthorized` (`WWW-Authenticate: APIKey`) when absent; returns `None` if `False`. |

### Example

```python
import secrets
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException
from fastapi.security import APIKeyQuery
from fastapi.testclient import TestClient

app = FastAPI()
query_sig_scheme = APIKeyQuery(name="webhook_token", auto_error=True)
valid_query_token = secrets.token_urlsafe(20)


@app.get("/webhooks/verify")
def verify_webhook(
    token: Annotated[str, Depends(query_sig_scheme)],
) -> dict[str, bool]:
    if not secrets.compare_digest(token, valid_query_token):
        raise HTTPException(status_code=403, detail="Forbidden")
    return {"verified": True}


client = TestClient(app)
res = client.get("/webhooks/verify", params={"webhook_token": valid_query_token})
assert res.status_code == 200
assert res.json() == {"verified": True}
```

---

## `class` APIKeyCookie

Extracts a session identifier or key from an HTTP `Cookie` header (`request.cookies.get(name)`) and documents an `in: "cookie"` API key security scheme in OpenAPI. Pair cookie authentication with `__Host-` prefixed, `HttpOnly`, `Secure`, `SameSite` cookies and CSRF validation on state-changing routes.

```python
class APIKeyCookie(APIKeyBase):
    def __init__(
        self,
        *,
        name: str,
        scheme_name: str | None = None,
        description: str | None = None,
        auto_error: bool = True,
    ) -> None: ...

    async def __call__(self, request: HTTPConnection) -> str | None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `name` | `str` | *(Required)* | Cookie key name to extract from `request.cookies` (e.g. `"__Host-session"`). |
| `scheme_name` | `str \| None` | `None` | OpenAPI security scheme identifier (defaults to `"APIKeyCookie"`). |
| `description` | `str \| None` | `None` | Description rendered in OpenAPI documentation. |
| `auto_error` | `bool` | `True` | Raises `401 Unauthorized` when the cookie is missing or empty; returns `None` if `False`. |

### Example

```python
import secrets
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException
from fastapi.security import APIKeyCookie
from fastapi.testclient import TestClient

app = FastAPI()
cookie_scheme = APIKeyCookie(name="__Host-session")
active_session_id = secrets.token_urlsafe(24)


@app.get("/dashboard")
def read_dashboard(
    session_id: Annotated[str, Depends(cookie_scheme)],
) -> dict[str, bool]:
    if not secrets.compare_digest(session_id, active_session_id):
        raise HTTPException(status_code=403, detail="Invalid session")
    return {"active": True}


client = TestClient(app, cookies={"__Host-session": active_session_id})
res = client.get("/dashboard")
assert res.status_code == 200
assert res.json() == {"active": True}
```

---

## `class` OpenIdConnect

OpenID Connect (OIDC) discovery security scheme inheriting from `SecurityBase`. Registers an `openIdConnect` security scheme with `openIdConnectUrl` in OpenAPI and extracts the raw `Authorization` header value from incoming requests (subclass to add JWKS signature verification).

```python
class OpenIdConnect(SecurityBase):
    def __init__(
        self,
        *,
        openIdConnectUrl: str,
        scheme_name: str | None = None,
        description: str | None = None,
        auto_error: bool = True,
    ) -> None: ...

    async def __call__(self, request: HTTPConnection) -> str | None: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `openIdConnectUrl` | `str` | *(Required)* | OIDC discovery document URL (typically `https://.../.well-known/openid-configuration`). |
| `scheme_name` | `str \| None` | `None` | OpenAPI security scheme identifier (defaults to `"OpenIdConnect"`). |
| `description` | `str \| None` | `None` | Description rendered in OpenAPI documentation. |
| `auto_error` | `bool` | `True` | Raises `401 Unauthorized` (`WWW-Authenticate: Bearer`) when `Authorization` is missing; returns `None` if `False`. |

### Example

```python
import secrets
from typing import Annotated

from fastapi import Depends, FastAPI
from fastapi.security import OpenIdConnect
from fastapi.testclient import TestClient

app = FastAPI()
oidc_scheme = OpenIdConnect(
    openIdConnectUrl="https://idp.example.com/.well-known/openid-configuration"
)
id_token = secrets.token_urlsafe(24)


@app.get("/userinfo")
def get_userinfo(auth_header: Annotated[str, Depends(oidc_scheme)]) -> dict[str, bool]:
    return {"received_bearer": auth_header == f"Bearer {id_token}"}


client = TestClient(app)
res = client.get("/userinfo", headers={"Authorization": f"Bearer {id_token}"})
assert res.status_code == 200
assert res.json() == {"received_bearer": True}
```

---

## `class` SecurityBase

Abstract base class (`fastapi.security.base.SecurityBase`) for all OpenAPI-integrated FastAPI security dependencies. During route analysis, FastAPI inspects `isinstance(dependant.call, SecurityBase)` to register `self.model` under `components.securitySchemes[self.scheme_name]` in the OpenAPI schema.

```python
class SecurityBase:
    model: SecurityBaseModel
    scheme_name: str
```

### Attributes

| Attribute | Type | Description |
| :--- | :--- | :--- |
| `model` | `fastapi.openapi.models.SecurityBase` | Pydantic OpenAPI security model (`APIKey`, `HTTPBase`, `HTTPBearer`, `OAuth2`, or `OpenIdConnect`). |
| `scheme_name` | `str` | Key registered under `components.securitySchemes` in the generated OpenAPI specification. |

### Example

```python
import secrets
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException
from fastapi.openapi.models import APIKey, APIKeyIn
from fastapi.requests import HTTPConnection
from fastapi.security.base import SecurityBase
from fastapi.testclient import TestClient


class CustomSignatureHeader(SecurityBase):
    def __init__(self, header_name: str = "X-Signature") -> None:
        self.model = APIKey(**{"in": APIKeyIn.header}, name=header_name)
        self.scheme_name = "CustomSignatureHeader"

    async def __call__(self, request: HTTPConnection) -> str:
        sig = request.headers.get(self.model.name)
        if not sig:
            raise HTTPException(status_code=401, detail="Missing signature")
        return sig


app = FastAPI()
sig_auth = CustomSignatureHeader()
expected_sig = secrets.token_hex(16)


@app.get("/signed")
def verify_signed(sig: Annotated[str, Depends(sig_auth)]) -> dict[str, bool]:
    return {"valid": secrets.compare_digest(sig, expected_sig)}


client = TestClient(app)
res = client.get("/signed", headers={"X-Signature": expected_sig})
schema = app.openapi()
assert res.json() == {"valid": True}
assert "CustomSignatureHeader" in schema["components"]["securitySchemes"]
```

---

## `def` get_authorization_scheme_param()

Utility helper (`fastapi.security.utils.get_authorization_scheme_param`) that safely splits a raw HTTP `Authorization` header string on the first ASCII space into `(scheme, param)` without raising on `None` or malformed single-token values.

```python
def get_authorization_scheme_param(
    authorization_header_value: str | None,
) -> tuple[str, str]
```

### Parameters & Return Value

| Item | Type | Description |
| :--- | :--- | :--- |
| `authorization_header_value` | `str \| None` | Raw `Authorization` header value (e.g. `request.headers.get("Authorization")`). |
| **Returns** | `tuple[str, str]` | `(scheme, param.strip())`, or `("", "")` when `authorization_header_value` is `None` or empty. |

### Example

```python
import secrets

from fastapi.security.utils import get_authorization_scheme_param

ephemeral_token = secrets.token_urlsafe(16)
scheme, param = get_authorization_scheme_param(f"Bearer   {ephemeral_token}  ")
empty_scheme, empty_param = get_authorization_scheme_param(None)

assert scheme == "Bearer"
assert param == ephemeral_token
assert (empty_scheme, empty_param) == ("", "")
```
