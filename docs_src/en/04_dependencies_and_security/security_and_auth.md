# Authentication, OAuth2 Scopes & Credential Extractors

FastAPI `v0.162.2`'s `fastapi.security` module unifies runtime credential extraction and OpenAPI 3.1 schema generation: every `SecurityBase` dependency parses incoming HTTP credentials in the `Dependant` DAG while automatically populating `components.securitySchemes` and Swagger UI's interactive **"Authorize"** modal.

```drawlib align=center code=fold file=security_schemes_architecture.png caption="Dual-Role Architecture of fastapi.security: Runtime DI Credential Extraction & OpenAPI 3.1 securitySchemes"
from drawlib.canvas import save, setup
from drawlib.diagrams.architecture import ArchitectureDiagram, Node, PhosphorIcon
from drawlib.icons import phosphor
from drawlib.lines import line, lines
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Styles

setup(width=168, height=98, dpi=150)

# Center Panel: fastapi.security SecurityBase Subclasses
sec_panel = Panel(
    "fastapi.security (SecurityBase Classes)",
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.5),
    icon=phosphor.shield_check,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=9.5,
)
sec_panel.draw((38.0, 5.0), width=68.0, height=88.0, align="bottom_left")

arch = ArchitectureDiagram(
    width=106.0,
    height=88.0,
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.0),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
)

http_req = arch.add(
    Node(
        "HTTP Request\nHeader / Cookie\n/ Query",
        width=26,
        height=20,
        icon=PhosphorIcon.GLOBE,
        icon_size=6.0,
        card_style=Styles.Neutral,
    ),
    xy=(17.0, 46.0),
)

oauth2_node = arch.add(
    Node(
        "OAuth2PasswordBearer &\nOAuth2AuthorizationCodeBearer",
        width=58,
        height=13.5,
        icon=PhosphorIcon.KEY,
        icon_size=5.4,
        style=Styles.White,
        card_style=Styles.PrimaryFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
    ),
    xy=(72.0, 72.5),
)

http_node = arch.add(
    Node(
        "HTTPBearer, HTTPBasic\n& HTTPDigest",
        width=58,
        height=13.5,
        icon=PhosphorIcon.LOCK_KEY,
        icon_size=5.4,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(72.0, 54.5),
)

apikey_node = arch.add(
    Node(
        "APIKeyHeader, APIKeyCookie\n& APIKeyQuery",
        width=58,
        height=13.5,
        icon=PhosphorIcon.COOKIE,
        icon_size=5.4,
        card_style=Styles.SecondaryNeutral,
    ),
    xy=(72.0, 36.5),
)

oidc_node = arch.add(
    Node(
        "OpenIdConnect\n(.well-known Discovery)",
        width=58,
        height=13.5,
        icon=PhosphorIcon.IDENTIFICATION_BADGE,
        icon_size=5.4,
        card_style=Styles.White,
    ),
    xy=(72.0, 18.5),
)

arch.draw(xy=(0.0, 0.0))

# Left Fan-Out Bus from HTTP Request (x=30.0 -> spine x=35.0 -> nodes x=42.5)
line((30.5, 46.0), (35.0, 46.0), style=Styles.DarkBold)
line((35.0, 18.5), (35.0, 72.5), style=Styles.DarkBold)
for ny in (72.5, 54.5, 36.5, 18.5):
    line((35.0, ny), (42.5, ny), arrow_head="->", style=Styles.DarkBold)

# Right Dual-Output Panels: (1) Runtime DI & (2) OpenAPI 3.1 Schema
rt_panel = Panel(
    "1. Runtime DI (__call__)",
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.user_check,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=9.0,
)
rt_panel.draw((118.0, 51.0), width=46.0, height=42.0, align="bottom_left")
rt_xy, rt_w, rt_h = rt_panel.get_content_box(
    (118.0, 51.0),
    width=46.0,
    height=42.0,
    padding=(2.5, 2.5),
    align="bottom_left",
)

rt_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.0),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_style=Styles.PrimaryFlat,
    badge_text_style=Styles.WhiteBold.patch(text_size=10.0),
    spacing=2.0,
)
rt_cards.add("Credential Parse", "Extracts token/key or 401", badge_text="A")
rt_cards.add("SecurityScopes", "Merges DAG OAuth2 scopes", badge_text="B")
rt_cards.draw(rt_xy, width=rt_w, height=rt_h)

oa_panel = Panel(
    "2. OpenAPI 3.1 (.model)",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.browser,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=9.0,
)
oa_panel.draw((118.0, 5.0), width=46.0, height=42.0, align="bottom_left")
oa_xy, oa_w, oa_h = oa_panel.get_content_box(
    (118.0, 5.0),
    width=46.0,
    height=42.0,
    padding=(2.5, 2.5),
    align="bottom_left",
)

oa_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.0),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    spacing=2.0,
)
oa_cards.add("securitySchemes", "Emits OpenAPI 3.1 JSON", badge_text="C")
oa_cards.add("Swagger Authorize", "Powers /docs login modal", badge_text="D")
oa_cards.draw(oa_xy, width=oa_w, height=oa_h)

# Right Convergence Spine (nodes x=101.5 -> spine x=110.5 -> panels x=117.5)
for ny in (72.5, 54.5, 36.5, 18.5):
    line((101.5, ny), (110.5, ny), style=Styles.DarkBold)
line((110.5, 18.5), (110.5, 72.5), style=Styles.DarkBold)
line((110.5, 68.0), (117.5, 68.0), arrow_head="->", style=Styles.PrimaryBold)
lines([(110.5, 26.0), (117.5, 26.0)], arrow_head="->", style=Styles.DarkBold)

save()
```

## 1. Dual-Role Design of `fastapi.security`

Unlike traditional middleware that intercepts every URL path indiscriminately, FastAPI integrates security directly into the [Dependant DAG](dependency_injection.md). Every security class in `fastapi/security/*` inherits from `SecurityBase` and fulfills two responsibilities from a single Python instance:

1. **Runtime Credential Extractor (`async def __call__(self, request: HTTPConnection)`)**: Parses the `Authorization` header, custom header, cookie, or query parameter. When `auto_error=True` (default), missing or malformed credentials immediately abort the request with `401 Unauthorized` and a spec-compliant `WWW-Authenticate` challenge header; when `auto_error=False`, the extractor returns `None` so downstream dependencies can implement multi-scheme fallbacks or optional authentication.
2. **OpenAPI 3.1 Metadata Provider (`self.model` & `self.scheme_name`)**: During `/openapi.json` generation, `_get_openapi_security_definitions()` (`fastapi/openapi/utils.py`) walks every route's `Dependant` tree, serializes `security_scheme.model` into `components.securitySchemes`, attaches operation-level `security` requirements, and enables the lock icons and **"Authorize"** dialog in Swagger UI (`/docs`).

| Security Class (`fastapi.security`) | Extracted Location & Format | Return Type (`auto_error=True`) | OpenAPI 3.1 `type` / `scheme` |
| :--- | :--- | :--- | :--- |
| **`OAuth2PasswordBearer`** | `Authorization: Bearer <token>` | `str` (raw bearer token) | `oauth2` (`flows.password`) |
| **`OAuth2AuthorizationCodeBearer`** | `Authorization: Bearer <token>` | `str` (raw bearer token) | `oauth2` (`flows.authorizationCode`) |
| **`HTTPBearer`** | `Authorization: Bearer <token>` | `HTTPAuthorizationCredentials` | `http` (`scheme: "bearer"`) |
| **`HTTPBasic`** | `Authorization: Basic <b64>` | `HTTPBasicCredentials` (`username`, `password`) | `http` (`scheme: "basic"`) |
| **`APIKeyHeader` / `Cookie` / `Query`** | Named header, cookie, or query param | `str` (raw API key) | `apiKey` (`in: header \| cookie \| query`) |
| **`OpenIdConnect`** | `Authorization` header + discovery URL | `str` (raw header; subclass to verify JWT) | `openIdConnect` (`openIdConnectUrl`) |

## 2. OAuth2 Bearer Flows & Hierarchical `SecurityScopes`

While `Depends()` resolves any callable, `Security(callable, scopes=[...])` (`fastapi/param_functions.py`) extends `Depends()` with declarative OAuth2 permission strings. When dependencies are nested across layers—for example, a route requires `scopes=["items:write"]` on `get_current_principal`, which in turn requires `scopes=["me:read"]` on `verify_bearer_claims`—FastAPI merges `parent_oauth_scopes` and `own_oauth_scopes` top-down through `_get_oauth_scopes()` and injects the combined list into a `SecurityScopes` parameter.

```drawlib align=center code=fold file=oauth2_security_scopes_flow.png caption="Hierarchical SecurityScopes Propagation & 401 vs 403 Challenge Semantics Across Nested Dependencies"
from drawlib.canvas import save, setup
from drawlib.diagrams.sequence import Participant, ParticipantGroup, PhosphorIcon, SequenceDiagram
from drawlib.styles import Style, Styles

setup(width=168, height=138, dpi=150)

seq = SequenceDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.0),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
    col_width=38.0,
    step_y=6.6,
    margin=5.0,
)

client = seq.add(
    Participant(
        "API Client",
        width=22,
        height=13.5,
        icon=PhosphorIcon.GLOBE,
        icon_size=5.8,
    )
)

chain = seq.add(
    ParticipantGroup(
        title="FastAPI Security() Scope Accumulation Chain",
        padding=4.5,
        style=Styles.Neutral,
        text_style=Style(text_size=11.0),
    )
)

route_sec = chain.add(
    Participant(
        'POST /items\nscopes=["items:write"]',
        width=27,
        height=14,
        icon=PhosphorIcon.FILE_CODE,
        icon_size=5.6,
        card_style=Styles.Neutral,
    )
)

principal_dep = chain.add(
    Participant(
        'get_current_principal\nscopes+=["me:read"]',
        width=27,
        height=14,
        icon=PhosphorIcon.USER_CHECK,
        icon_size=5.6,
        card_style=Styles.PrimaryNeutral,
    )
)

verifier = chain.add(
    Participant(
        "verify_bearer_claims\n(SecurityScopes)",
        width=27,
        height=14,
        icon=PhosphorIcon.SHIELD_CHECK,
        icon_size=5.6,
        style=Styles.White,
        card_style=Styles.PrimaryFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
    )
)

client.request(route_sec, "1. POST /items (Authorization: Bearer <token>)")
route_sec.request(principal_dep, '2. Pass parent_oauth_scopes=["items:write"]')
principal_dep.request(
    verifier,
    '3. Inject SecurityScopes(["items:write", "me:read"])',
)

with seq.alt("401 Invalid") as blk_401:
    blk_401.style = Styles.MutedDashed.patch(shape_line_width=1.2)
    blk_401.text_style = Style(text_size=10.0, halign="left")
    verifier.reply(
        client,
        '4a. 401 Unauthorized (WWW-Authenticate: Bearer scope="items:write me:read")',
        style=Styles.DangerBold,
        text_style=Styles.DangerBold.patch(text_size=10.0),
    )

with seq.else_("403 Scope") as blk_403:
    blk_403.style = Styles.MutedDashed.patch(shape_line_width=1.2)
    blk_403.text_style = Style(text_size=10.0, halign="left")
    verifier.reply(
        client,
        '4b. 403 Forbidden — Missing items:write (WWW-Authenticate: Bearer scope=...)',
        style=Styles.WarningBold,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    )

with seq.else_("200 Granted") as blk_200:
    blk_200.style = Styles.MutedDashed.patch(shape_line_width=1.2)
    blk_200.text_style = Style(text_size=10.0, halign="left")
    verifier.reply(
        principal_dep,
        "4c. Verified TokenRecord (exp & scopes OK)",
        style=Styles.SuccessBold,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    )
    principal_dep.reply(
        route_sec,
        "5c. Principal(username, scopes)",
        style=Styles.SuccessBold,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    )
    route_sec.reply(
        client,
        "6c. 200 OK (Created Item JSON)",
        style=Styles.SuccessBold,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    )

seq.draw(xy=(84.0, 69.0), align="center")
save()
```

### 2.1 Distinguishing `401 Unauthorized` vs `403 Forbidden`

RFC 6750 and RFC 9110 define distinct status codes for authentication failure versus insufficient authorization scopes:

- **`401 Unauthorized` (Unauthenticated / Invalid Token)**: Returned when the `Authorization` header is missing, malformed, signed with an invalid key, or past its `exp` timestamp. Always include `WWW-Authenticate: Bearer` (or `Bearer scope="..."` when scopes apply).
- **`403 Forbidden` (Authenticated, Insufficient Scope)**: Returned when the token cryptographically identifies a valid principal, but `security_scopes.scopes` contains at least one permission not granted to that token. Including `headers={"WWW-Authenticate": f'Bearer scope="{security_scopes.scope_str}"'}` informs OAuth2 clients which scopes must be requested at `/token`.

### 2.2 End-to-End `/token` Login & Nested `SecurityScopes` Verification

Note that `OAuth2PasswordRequestForm` requires `application/x-www-form-urlencoded` form fields (`username`, `password`, optional space-delimited `scope`) per the OAuth 2.0 specification (parsed via `python-multipart`; see [Path, Query, Header, Cookie & Body](../03_routing_and_models/parameters_and_validation.md)). Always verify password hashes with memory-hard KDFs (`scrypt` or `Argon2`) plus `secrets.compare_digest`, enforce finite token expiration (`exp`), and never hardcode signing keys in source code:

```python
import hashlib
import secrets
import time
from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, Security, status
from fastapi.security import (
    OAuth2PasswordBearer,
    OAuth2PasswordRequestForm,
    SecurityScopes,
)
from pydantic import BaseModel


def hash_password(password: str, salt: bytes) -> bytes:
    return hashlib.scrypt(password.encode("utf-8"), salt=salt, n=16384, r=8, p=1)


@dataclass(frozen=True)
class StoredUser:
    salt: bytes
    pw_hash: bytes
    allowed_scopes: set[str]


class TokenRecord(BaseModel):
    sub: str
    scopes: list[str]
    exp: float


class Principal(BaseModel):
    username: str
    scopes: list[str]


alice_salt = secrets.token_bytes(16)
bootstrap_password = secrets.token_urlsafe(12)
users_db: dict[str, StoredUser] = {
    "alice": StoredUser(
        salt=alice_salt,
        pw_hash=hash_password(bootstrap_password, alice_salt),
        allowed_scopes={"me:read", "items:read", "items:write"},
    )
}
token_store: dict[str, TokenRecord] = {}

oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/token",
    scopes={
        "me:read": "Read current user profile",
        "items:read": "Read inventory items",
        "items:write": "Create or update inventory items",
    },
)

app = FastAPI()


@app.post("/token")
async def issue_token(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
) -> dict[str, str]:
    user = users_db.get(form_data.username)
    candidate_hash = hash_password(
        form_data.password,
        user.salt if user else alice_salt,
    )
    expected_hash = user.pw_hash if user else hash_password("invalid", alice_salt)
    if not user or not secrets.compare_digest(candidate_hash, expected_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    granted = [s for s in form_data.scopes if s in user.allowed_scopes]
    raw_token = secrets.token_urlsafe(24)
    token_store[raw_token] = TokenRecord(
        sub=form_data.username,
        scopes=granted,
        exp=time.time() + 900,
    )
    return {"access_token": raw_token, "token_type": "bearer"}


async def verify_bearer_claims(
    security_scopes: SecurityScopes,
    token: Annotated[str, Depends(oauth2_scheme)],
) -> TokenRecord:
    auth_header = (
        f'Bearer scope="{security_scopes.scope_str}"'
        if security_scopes.scopes
        else "Bearer"
    )
    record = token_store.get(token)
    if record is None or record.exp < time.time():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired bearer token",
            headers={"WWW-Authenticate": auth_header},
        )
    granted_set = set(record.scopes)
    for required_scope in security_scopes.scopes:
        if required_scope not in granted_set:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Not enough permissions (missing {required_scope})",
                headers={"WWW-Authenticate": auth_header},
            )
    return record


async def get_current_principal(
    claims: Annotated[
        TokenRecord,
        Security(verify_bearer_claims, scopes=["me:read"]),
    ],
) -> Principal:
    return Principal(username=claims.sub, scopes=claims.scopes)


@app.post("/items")
async def create_item(
    name: str,
    principal: Annotated[
        Principal,
        Security(get_current_principal, scopes=["items:write"]),
    ],
) -> dict[str, object]:
    return {"item": name, "created_by": principal.username}
```

Inspecting `app.openapi()["paths"]["/items"]["post"]["security"]` yields `[{"OAuth2PasswordBearer": ["items:write", "me:read"]}]`: FastAPI automatically merges the route's `"items:write"` scope with the sub-dependency's `"me:read"` scope in both runtime enforcement and the published OpenAPI 3.1 contract (see [Response Serialization & OpenAPI 3.1](../03_routing_and_models/responses_and_openapi.md)).

## 3. Constant-Time `HTTPBasic` & Multi-Scheme `APIKeyHeader` Fallback

Internal operational endpoints frequently need to support **machine-to-machine API keys** (`X-API-Key`) alongside **browser-friendly HTTP Basic challenges** (`HTTPBasic`). Combining `auto_error=False` on multiple `SecurityBase` extractors lets a single dependency orchestrate fallback authentication cleanly.

### 3.1 Preventing Timing Side-Channels with `secrets.compare_digest`

Never compare passwords or API keys with Python's `==` operator, which short-circuits at the first mismatched byte and leaks prefix length over statistical network measurements. Instead, encode both strings to UTF-8 bytes and evaluate **both** `username` and `password` comparisons unconditionally via `secrets.compare_digest()` before branching:

```python
import os
import secrets
from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, Security, status
from fastapi.security import APIKeyHeader, HTTPBasic, HTTPBasicCredentials


@dataclass(frozen=True)
class OpsAuthSettings:
    basic_user: str
    basic_password: str
    service_api_key: str


ephemeral_pw = os.environ.get("OPS_BASIC_PASSWORD") or secrets.token_urlsafe(16)
ephemeral_key = os.environ.get("OPS_SERVICE_API_KEY") or secrets.token_urlsafe(24)


def get_ops_auth_settings() -> OpsAuthSettings:
    return OpsAuthSettings(
        basic_user="ops_admin",
        basic_password=ephemeral_pw,
        service_api_key=ephemeral_key,
    )


basic_scheme = HTTPBasic(realm="OpsConsole", auto_error=False)
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)


async def require_ops_caller(
    settings: Annotated[OpsAuthSettings, Depends(get_ops_auth_settings)],
    api_key: Annotated[str | None, Security(api_key_header)] = None,
    basic_creds: Annotated[HTTPBasicCredentials | None, Security(basic_scheme)] = None,
) -> dict[str, str]:
    if api_key is not None:
        key_ok = secrets.compare_digest(
            api_key.encode("utf-8"),
            settings.service_api_key.encode("utf-8"),
        )
        if key_ok:
            return {"principal": "automation_bot", "method": "api_key"}

    if basic_creds is not None:
        # Evaluate BOTH digests before branching so username validity never leaks via timing
        user_ok = secrets.compare_digest(
            basic_creds.username.encode("utf-8"),
            settings.basic_user.encode("utf-8"),
        )
        pass_ok = secrets.compare_digest(
            basic_creds.password.encode("utf-8"),
            settings.basic_password.encode("utf-8"),
        )
        if user_ok and pass_ok:
            return {"principal": basic_creds.username, "method": "http_basic"}

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Valid X-API-Key or HTTP Basic credentials required",
        headers={"WWW-Authenticate": 'Basic realm="OpsConsole"'},
    )


app = FastAPI()


@app.get("/ops/health-audit")
async def ops_health_audit(
    caller: Annotated[dict[str, str], Depends(require_ops_caller)],
) -> dict[str, str]:
    return caller
```

> [!TIP]
> When provisioning browser session cookies (`APIKeyCookie`), enforce `__Host-` cookie prefixes, `HttpOnly`, `Secure`, `SameSite="lax"`, and state-changing CSRF defenses, and terminate TLS 1.2+ at your edge proxy. Continue to [ASGI Middleware & Threadpool](../05_async_and_realtime/concurrency_and_middleware.md) for CORS, trusted-host middleware, and ASGI request wrapping.
