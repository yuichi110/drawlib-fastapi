# JWT (PyJWT + Argon2) & WebSocket Security

Production FastAPI `v0.162.2` services pair memory-hard **`pwdlib` Argon2id** password hashing (with **`DUMMY_HASH`** anti-enumeration) and stateless **`PyJWT`** bearer verification for HTTP APIs, while extending the exact same `Security()` and `SecurityScopes` dependency graph to **`WebSocket`** handshakes via Starlette's shared `HTTPConnection` abstraction (`v0.144.0+`).

```drawlib align=center code=fold file=jwt_argon2_auth_pipeline.png caption="End-to-End OAuth2 + pwdlib Argon2id (DUMMY_HASH) + PyJWT Signing & Stateless Verification Pipeline"
from drawlib.canvas import save, setup
from drawlib.diagrams.architecture import ArchitectureDiagram, Node, PhosphorIcon
from drawlib.icons import phosphor
from drawlib.lines import line
from drawlib.shapes import rectangle
from drawlib.smartarts import Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=184, height=112, dpi=150)

# Top Lane: Phase 1 — POST /token Credential Verification & JWT Issuance
issue_panel = Panel(
    "1. Token Issuance Pipeline — POST /token (pwdlib Argon2id + PyJWT Sign)",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.2),
    icon=phosphor.key,
    icon_style=Styles.SecondaryBold,
    header_variant="filled",
    header_height=9.0,
)
issue_panel.draw((4.0, 60.0), width=176.0, height=47.0, align="bottom_left")

# Bottom Lane: Phase 2 — Protected Route Stateless Decode & Scope Check
verify_panel = Panel(
    "2. Protected Endpoint Verification — Security(..., scopes) & jwt.decode()",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.2),
    icon=phosphor.shield_check,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=9.0,
)
verify_panel.draw((4.0, 4.0), width=176.0, height=50.0, align="bottom_left")

arch = ArchitectureDiagram(
    width=184.0,
    height=112.0,
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.0),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
)

# Phase 1 Nodes (cy = 79.0, inside y in [62.0, 96.0])
n_form = arch.add(
    Node(
        "POST /token\nForm Credentials",
        width=33.0,
        height=21.0,
        icon=PhosphorIcon.USER_CIRCLE,
        icon_size=5.6,
        card_style=Styles.White,
    ),
    xy=(24.5, 79.0),
)

n_argon = arch.add(
    Node(
        "pwdlib Argon2id\nverify() + DUMMY_HASH\n(Anti-Enumeration)",
        width=43.0,
        height=23.0,
        icon=PhosphorIcon.SHIELD_CHECK,
        icon_size=5.6,
        style=Styles.White,
        card_style=Styles.PrimaryFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
    ),
    xy=(70.5, 79.0),
)

n_encode = arch.add(
    Node(
        'jwt.encode("HS256")\nsub, scopes, iat, exp',
        width=39.0,
        height=21.0,
        icon=PhosphorIcon.STAMP,
        icon_size=5.6,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(119.5, 79.0),
)

n_jwt_out = arch.add(
    Node(
        "200 Bearer JWT\naccess_token",
        width=29.0,
        height=21.0,
        icon=PhosphorIcon.KEY,
        icon_size=5.6,
        card_style=Styles.SecondaryNeutral,
    ),
    xy=(161.5, 79.0),
)

# Phase 2 Nodes (cy = 24.5, inside y in [6.0, 43.0])
n_route = arch.add(
    Node(
        "Protected Route\nSecurity(..., scopes)",
        width=35.0,
        height=22.0,
        icon=PhosphorIcon.LOCK_KEY,
        icon_size=5.6,
        card_style=Styles.White,
    ),
    xy=(25.5, 24.5),
)

n_decode = arch.add(
    Node(
        'jwt.decode(["HS256"])\nVerify exp, sub & scopes',
        width=44.0,
        height=23.0,
        icon=PhosphorIcon.FILE_LOCK,
        icon_size=5.6,
        style=Styles.White,
        card_style=Styles.PrimaryFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
    ),
    xy=(73.0, 24.5),
)

arch.draw(xy=(0.0, 0.0))

# Phase 1 Horizontal Connectors (all gaps = 8.0 units)
line((41.5, 79.0), (48.5, 79.0), arrow_head="->", style=Styles.DarkBold)
line((92.5, 79.0), (99.5, 79.0), arrow_head="->", style=Styles.DarkBold)
line((139.5, 79.0), (146.5, 79.0), arrow_head="->", style=Styles.PrimaryBold)

# Phase 2 Connector + 3 Outcome Cards on Right (x in [111.0, 176.0], cx = 143.5)
line((43.5, 24.5), (50.5, 24.5), arrow_head="->", style=Styles.DarkBold)
line((95.5, 24.5), (103.0, 24.5), style=Styles.DarkBold)
line((103.0, 12.0), (103.0, 37.0), style=Styles.DarkBold)

outcomes = [
    (
        37.0,
        Styles.PrimaryNeutral,
        Styles.PrimaryBold,
        "200 OK — Active UserPublic Injected",
    ),
    (
        24.5,
        Styles.White,
        Styles.DangerBold,
        "401 Unauthorized — Expired / Invalid (Bearer)",
    ),
    (
        12.0,
        Styles.SecondaryNeutral,
        Styles.WarningBold,
        '403 Forbidden — Missing Scope (scope="...")',
    ),
]
for cy, card_st, arrow_st, label in outcomes:
    line((103.0, cy), (110.5, cy), arrow_head="->", style=arrow_st)
    rectangle((143.5, cy), width=65.0, height=9.2, style=card_st.patch(shape_r=1.6))
    text((143.5, cy), label, style=Styles.DarkBold.patch(text_size=10.0))

save()
```

## 1. Password Hashing (`pwdlib` Argon2id) & Stateless `PyJWT` Tokens

Modern FastAPI deployments standardize on **`pwdlib[argon2]`** (`PasswordHash.recommended()`) and **`PyJWT`** (`import jwt`) rather than legacy `passlib` or `python-jose`, avoiding `bcrypt` 72-byte truncation pitfalls and unmaintained cryptographic wrappers. Combining `pwdlib` and `PyJWT` inside the [Authentication & OAuth2 Scopes](security_and_auth.md) dependency tree requires four defensive invariants:

| Security Control | Recommended Implementation | Vulnerability Prevented |
| :--- | :--- | :--- |
| **Memory-Hard Password KDF** | `PasswordHash.recommended()` (`pwdlib[argon2]`) | Defeats GPU/ASIC offline cracking with Argon2id memory-hardness and unique random per-user salts |
| **Anti-Enumeration `DUMMY_HASH`** | Precompute `DUMMY_HASH = password_hash.hash(...)` at startup; run `password_hash.verify(pw, DUMMY_HASH)` when user is missing | Eliminates ~`50ms+` response-time discrepancy between unknown usernames and wrong passwords |
| **Algorithm Pinning & Required Claims** | `jwt.decode(token, KEY, algorithms=["HS256"], options={"require": ["sub", "iat", "exp"]})` | Blocks `"alg": "none"` signature bypasses, RS256/HS256 public-key confusion, and Immortal tokens |
| **Key Entropy & Zero Hardcoding** | Load `256-bit+` keys from KMS / environment ([pydantic-settings](../08_ecosystem_and_operations/settings_and_databases.md)); never commit fallback literals | Prevents offline JWT forgery from leaked repository source code |

### 1.1 Production `/token` Issuance, `DUMMY_HASH` & `get_current_active_user`

In the implementation below, `authenticate_user()` always runs a full Argon2id verification pass even when `username` does not exist in `users_db`. Downstream, `get_current_user()` decodes the JWT with an explicit `algorithms=["HS256"]` allowlist, maps `ExpiredSignatureError` and `InvalidTokenError` to RFC 6750 `401 Unauthorized` responses, and enforces accumulated `SecurityScopes` (`403 Forbidden` on missing permissions) before `get_current_active_user()` checks account suspension state:

```python
import os
import secrets
from datetime import datetime, timedelta, timezone
from typing import Annotated

import jwt
from fastapi import Depends, FastAPI, HTTPException, Security, status
from fastapi.security import (
    OAuth2PasswordBearer,
    OAuth2PasswordRequestForm,
    SecurityScopes,
)
from fastapi.testclient import TestClient
from jwt.exceptions import ExpiredSignatureError, InvalidTokenError
from pwdlib import PasswordHash
from pydantic import BaseModel

SECRET_KEY = os.environ.get("JWT_SECRET_KEY") or secrets.token_hex(32)
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 15

password_hash = PasswordHash.recommended()
DUMMY_HASH = password_hash.hash("dummypassword")


class Token(BaseModel):
    access_token: str
    token_type: str


class UserRecord(BaseModel):
    username: str
    hashed_password: str
    scopes: list[str]
    disabled: bool = False


class UserPublic(BaseModel):
    username: str
    scopes: list[str]
    disabled: bool = False


alice_password = secrets.token_urlsafe(12)
users_db: dict[str, UserRecord] = {
    "alice": UserRecord(
        username="alice",
        hashed_password=password_hash.hash(alice_password),
        scopes=["me:read", "reports:export"],
    ),
}

oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/token",
    scopes={
        "me:read": "Read current user profile",
        "reports:export": "Export audit reports",
    },
)


def authenticate_user(
    db: dict[str, UserRecord],
    username: str,
    password: str,
) -> UserRecord | None:
    user = db.get(username)
    if user is None:
        # Always run Argon2id against DUMMY_HASH to defeat timing user-enumeration
        password_hash.verify(password, DUMMY_HASH)
        return None
    if not password_hash.verify(password, user.hashed_password):
        return None
    return user


def create_access_token(
    *,
    subject: str,
    scopes: list[str],
    expires_delta: timedelta,
) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": subject,
        "scopes": scopes,
        "iat": now,
        "exp": now + expires_delta,
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


app = FastAPI()


@app.post("/token", response_model=Token)
async def login_for_access_token(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
) -> Token:
    user = authenticate_user(users_db, form_data.username, form_data.password)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    granted_scopes = [s for s in form_data.scopes if s in user.scopes]
    access_token = create_access_token(
        subject=user.username,
        scopes=granted_scopes,
        expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES),
    )
    return Token(access_token=access_token, token_type="bearer")


async def get_current_user(
    security_scopes: SecurityScopes,
    token: Annotated[str, Depends(oauth2_scheme)],
) -> UserRecord:
    auth_header = (
        f'Bearer scope="{security_scopes.scope_str}"'
        if security_scopes.scopes
        else "Bearer"
    )
    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM],
            options={"require": ["sub", "iat", "exp"]},
        )
    except ExpiredSignatureError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
            headers={"WWW-Authenticate": auth_header},
        ) from exc
    except InvalidTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": auth_header},
        ) from exc

    username = payload.get("sub")
    token_scopes = payload.get("scopes", [])
    if not isinstance(username, str) or not isinstance(token_scopes, list):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": auth_header},
        )
    user = users_db.get(username)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": auth_header},
        )
    for required_scope in security_scopes.scopes:
        if required_scope not in token_scopes:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Not enough permissions (missing {required_scope})",
                headers={"WWW-Authenticate": auth_header},
            )
    return user


async def get_current_active_user(
    current_user: Annotated[
        UserRecord,
        Security(get_current_user, scopes=["me:read"]),
    ],
) -> UserPublic:
    if current_user.disabled:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user",
        )
    return UserPublic(
        username=current_user.username,
        scopes=current_user.scopes,
        disabled=current_user.disabled,
    )


@app.get("/users/me", response_model=UserPublic)
async def read_users_me(
    current_user: Annotated[UserPublic, Depends(get_current_active_user)],
) -> UserPublic:
    return current_user


@app.get("/reports/export")
async def export_audit_report(
    current_user: Annotated[
        UserPublic,
        Security(get_current_active_user, scopes=["reports:export"]),
    ],
) -> dict[str, str]:
    return {"exported_by": current_user.username, "status": "ready"}


client = TestClient(app)
login_res = client.post(
    "/token",
    data={"username": "alice", "password": alice_password, "scope": "me:read"},
)
narrow_jwt = login_res.json()["access_token"]
assert client.get("/users/me", headers={"Authorization": f"Bearer {narrow_jwt}"}).status_code == 200
assert client.get("/reports/export", headers={"Authorization": f"Bearer {narrow_jwt}"}).status_code == 403
```

Because stateless JWTs remain valid until `exp`, keep access-token lifetimes short (`5`–`15` minutes) and validate user status (`disabled` or a `token_version` counter in your database/cache) whenever immediate session revocation is required on logout or privilege downgrade.

## 2. WebSocket Authentication & `v0.144.0+` `Security()` Support

Prior to FastAPI `v0.144.0`, built-in `fastapi.security` extractors annotated their `__call__` parameter as `request: Request`, which prevented reusing `OAuth2PasswordBearer` or `APIKeyCookie` directly inside `@app.websocket(...)` routes. Starting in **`v0.144.0` through `v0.162.2`**, every `SecurityBase` subclass (`APIKeyCookie`, `APIKeyQuery`, `APIKeyHeader`, `OAuth2PasswordBearer`, `OAuth2AuthorizationCodeBearer`, `HTTPBearer`, `HTTPBasic`, `OpenIdConnect`) accepts Starlette's **`HTTPConnection`** base class—shared by both `Request` and `WebSocket` (`fastapi/dependencies/utils.py` injects `websocket` into `dependant.http_connection_param_name`).

```drawlib align=center code=fold file=websocket_security_handshake.png caption="WebSocket Authentication Handshake: Browser Cookie/Ticket vs SDK Bearer via SecurityBase(HTTPConnection)"
from drawlib.canvas import save, setup
from drawlib.diagrams.sequence import Participant, ParticipantGroup, PhosphorIcon, SequenceDiagram
from drawlib.styles import Style, Styles

setup(width=182, height=126, dpi=150)

seq = SequenceDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.0),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
    col_width=43.0,
    step_y=6.8,
    margin=5.0,
)

browser = seq.add(
    Participant(
        "Browser SPA\nnew WebSocket(url)",
        width=33,
        height=14,
        icon=PhosphorIcon.BROWSER,
        icon_size=5.6,
        card_style=Styles.Neutral,
    )
)

sdk_client = seq.add(
    Participant(
        "SDK / CLI Client\nCustom Headers",
        width=33,
        height=14,
        icon=PhosphorIcon.TERMINAL_WINDOW,
        icon_size=5.6,
        card_style=Styles.SecondaryNeutral,
    )
)

ws_group = seq.add(
    ParticipantGroup(
        title="FastAPI v0.162.2 WebSocket DI (HTTPConnection)",
        padding=4.5,
        style=Styles.Neutral,
        text_style=Style(text_size=10.8),
    )
)

sec_dep = ws_group.add(
    Participant(
        "SecurityBase\nCookie / Query / Bearer",
        width=35,
        height=14,
        icon=PhosphorIcon.SHIELD_CHECK,
        icon_size=5.6,
        style=Styles.White,
        card_style=Styles.PrimaryFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
    )
)

ws_route = ws_group.add(
    Participant(
        "@app.websocket\nRoom Handler",
        width=32,
        height=14,
        icon=PhosphorIcon.PLUGS_CONNECTED,
        icon_size=5.6,
        card_style=Styles.PrimaryNeutral,
    )
)

with seq.alt("Browser SPA") as blk_browser:
    blk_browser.style = Styles.MutedDashed.patch(shape_line_width=1.2)
    blk_browser.text_style = Style(text_size=10.0, halign="left")
    browser.request(
        sec_dep,
        "1a. Upgrade (__Host-session Cookie + Origin OR ?ticket=1x)",
    )
    sec_dep.request(ws_route, "2a. Verified User")
    ws_route.reply(
        browser,
        "3a. await ws.accept() -> 101 Switching Protocols",
        style=Styles.SuccessBold,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    )

with seq.else_("SDK / CLI") as blk_sdk:
    blk_sdk.style = Styles.MutedDashed.patch(shape_line_width=1.2)
    blk_sdk.text_style = Style(text_size=10.0, halign="left")
    sdk_client.request(sec_dep, "1b. Bearer <jwt>")
    sec_dep.request(ws_route, "2b. Scopes Valid")
    ws_route.reply(
        sdk_client,
        "3b. await ws.accept() -> 101 Switching Protocols",
        style=Styles.SuccessBold,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    )

with seq.else_("Policy Reject") as blk_deny:
    blk_deny.style = Styles.MutedDashed.patch(shape_line_width=1.2)
    blk_deny.text_style = Style(text_size=10.0, halign="left")
    browser.request(
        sec_dep,
        "1c. Missing / Replayed Ticket, Bad Origin or Missing Scope",
    )
    sec_dep.reply(
        browser,
        "2c. WebSocketException(WS_1008_POLICY_VIOLATION)",
        style=Styles.DangerBold,
        text_style=Styles.DangerBold.patch(text_size=10.0),
    )

seq.draw(xy=(91.0, 63.0), align="center")
save()
```

### 2.1 Browser DOM Constraints vs `HTTPConnection` Extractors

Even though FastAPI `v0.162.2` supports `OAuth2PasswordBearer` and `APIKeyHeader` on `WebSocket` routes at the server layer, **browser JavaScript clients face a WHATWG DOM constraint**: `new WebSocket(url, protocols)` provides no API to attach custom `Authorization` or `X-API-Key` headers. Choose your handshake credential transport according to the client environment:

| Transport Pattern | `fastapi.security` Extractor | Target Client & Mandatory Hardening |
| :--- | :--- | :--- |
| **`__Host-session` Cookie** | `APIKeyCookie(name="__Host-session", auto_error=False)` | **Same-origin browser SPAs**: Set `HttpOnly; Secure; SameSite=Lax` and **always validate the `Origin` header** against an allowlist to block Cross-Site WebSocket Hijacking (CSWSH), since WebSockets skip CORS preflights |
| **Single-Use Ephemeral Ticket** | `APIKeyQuery(name="ticket", auto_error=False)` | **Cross-origin browser SPAs**: Mint a `30s` random opaque ticket over `POST /ws/tickets` (`Bearer` auth) and `.pop()` it atomically on connect—never pass long-lived JWTs in `?token=` URLs |
| **`Authorization: Bearer` / Header** | `OAuth2PasswordBearer(..., auto_error=False)` / `APIKeyHeader` | **Python/Go workers, CLI tools & native mobile apps**: Attach standard HTTP headers directly on the WebSocket Upgrade request |

### 2.2 Pre-Handshake Rejection (`WS_1008_POLICY_VIOLATION` vs `auto_error=True`)

When `auto_error=True` on a `SecurityBase` extractor and the credential is absent, FastAPI raises `HTTPException(status_code=401)` inside `solve_dependencies()`, aborting the HTTP Upgrade with a `401` denial response (`WebSocketDenialResponse` in `TestClient`). For multi-transport WebSocket endpoints, set `auto_error=False` on each extractor, evaluate `Origin` and `SecurityScopes` inside a unified dependency *before* `await ws.accept()`, and raise `WebSocketException(code=status.WS_1008_POLICY_VIOLATION)` on any policy failure:

```python
import secrets
import time
from datetime import timedelta
from typing import Annotated

import pytest
from fastapi import (
    FastAPI,
    Header,
    Security,
    WebSocket,
    WebSocketDisconnect,
    WebSocketException,
    status,
)
from fastapi.security import (
    APIKeyCookie,
    APIKeyQuery,
    OAuth2PasswordBearer,
    SecurityScopes,
)
from fastapi.testclient import TestClient
from pydantic import BaseModel

ALLOWED_WS_ORIGINS = {"https://app.example.com"}

ws_cookie_scheme = APIKeyCookie(name="__Host-session", auto_error=False)
ws_ticket_scheme = APIKeyQuery(name="ticket", auto_error=False)
ws_bearer_scheme = OAuth2PasswordBearer(tokenUrl="/token", auto_error=False)


class EphemeralTicket(BaseModel):
    username: str
    scopes: list[str]
    exp: float


session_cookies: dict[str, EphemeralTicket] = {}
one_time_tickets: dict[str, EphemeralTicket] = {}

ws_app = FastAPI()


@ws_app.post("/ws/tickets")
async def issue_ws_ticket(
    principal: Annotated[
        UserRecord,
        Security(get_current_user, scopes=["rooms:stream"]),
    ],
) -> dict[str, str]:
    ticket_id = secrets.token_urlsafe(24)
    one_time_tickets[ticket_id] = EphemeralTicket(
        username=principal.username,
        scopes=["rooms:stream"],
        exp=time.time() + 30.0,
    )
    return {"ticket": ticket_id}


async def authenticate_ws_caller(
    security_scopes: SecurityScopes,
    session_id: Annotated[str | None, Security(ws_cookie_scheme)] = None,
    ticket: Annotated[str | None, Security(ws_ticket_scheme)] = None,
    bearer_token: Annotated[str | None, Security(ws_bearer_scheme)] = None,
    origin: Annotated[str | None, Header()] = None,
) -> str:
    username: str | None = None
    granted_scopes: list[str] = []

    if session_id is not None:
        # Enforce strict Origin allowlist on cookie-authenticated browser sockets (anti-CSWSH)
        if origin not in ALLOWED_WS_ORIGINS:
            raise WebSocketException(
                code=status.WS_1008_POLICY_VIOLATION,
                reason="Untrusted Origin for cookie session",
            )
        record = session_cookies.get(session_id)
        if record is not None and record.exp > time.time():
            username, granted_scopes = record.username, record.scopes
    elif ticket is not None:
        # Consume atomically so query tickets cannot be replayed from proxy logs
        record = one_time_tickets.pop(ticket, None)
        if record is not None and record.exp > time.time():
            username, granted_scopes = record.username, record.scopes
    elif bearer_token is not None:
        try:
            payload = jwt.decode(
                bearer_token,
                SECRET_KEY,
                algorithms=[ALGORITHM],
                options={"require": ["sub", "exp"]},
            )
            sub = payload.get("sub")
            scopes = payload.get("scopes", [])
            if isinstance(sub, str) and isinstance(scopes, list):
                username, granted_scopes = sub, [str(s) for s in scopes]
        except InvalidTokenError:
            pass

    if username is None:
        raise WebSocketException(
            code=status.WS_1008_POLICY_VIOLATION,
            reason="Missing or invalid WebSocket credentials",
        )

    for required_scope in security_scopes.scopes:
        if required_scope not in granted_scopes:
            raise WebSocketException(
                code=status.WS_1008_POLICY_VIOLATION,
                reason=f"Missing required scope: {required_scope}",
            )
    return username


@ws_app.websocket("/ws/rooms/{room_id}")
async def secure_room_socket(
    ws: WebSocket,
    room_id: str,
    username: Annotated[
        str,
        Security(authenticate_ws_caller, scopes=["rooms:stream"]),
    ],
) -> None:
    await ws.accept()
    try:
        while True:
            msg = await ws.receive_json()
            await ws.send_json(
                {"room": room_id, "user": username, "echo": msg["text"]}
            )
    except WebSocketDisconnect:
        pass


ws_client = TestClient(ws_app)
users_db["alice"].scopes.append("rooms:stream")
stream_jwt = create_access_token(
    subject="alice",
    scopes=["rooms:stream"],
    expires_delta=timedelta(minutes=5),
)
ticket_val = ws_client.post(
    "/ws/tickets",
    headers={"Authorization": f"Bearer {stream_jwt}"},
).json()["ticket"]

with ws_client.websocket_connect(f"/ws/rooms/ops?ticket={ticket_val}") as socket:
    socket.send_json({"text": "deploy-ok"})
    assert socket.receive_json() == {"room": "ops", "user": "alice", "echo": "deploy-ok"}

with pytest.raises(WebSocketDisconnect) as replay_err:
    with ws_client.websocket_connect(f"/ws/rooms/ops?ticket={ticket_val}"):
        pass
assert replay_err.value.code == status.WS_1008_POLICY_VIOLATION
```

> [!TIP]
> For long-lived `WebSocket` connections (`minutes` to `hours`), re-check token `exp` or revocation events periodically inside the message loop and close expired sessions gracefully with `await ws.close(code=status.WS_1008_POLICY_VIOLATION)`. Next, explore full-duplex room lifecycles and Server-Sent Events in [Native SSE, JSONL & WebSockets](../05_async_and_realtime/sse_websockets_streaming.md) and ASGI origin/CORS layers in [ASGI Middleware & Threadpool](../05_async_and_realtime/concurrency_and_middleware.md).
