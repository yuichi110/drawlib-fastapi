# fastapi.security

`fastapi.security` は、受信した HTTP 接続から認証情報を抽出する呼び出し可能クラス、資格情報モデル、およびフォームパーサーを提供し、標準的なセキュリティスキーム（OAuth2、HTTP Basic/Bearer/Digest、API キー、OpenID Connect）を OpenAPI（`/openapi.json` および `/docs`）へ自動登録します。

```drawlib align=center code=hide file=fastapi_security_schemes_map.png caption="FastAPI 標準セキュリティ抽出クラスと資格情報ヘルパーの分類"
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

`OAuth2` を継承する OAuth2 パスワードフロー向け Bearer トークン抽出クラスです。`Depends()` または `Security()` に指定すると、`Authorization: Bearer <token>` ヘッダーから `<token>` 文字列（`auto_error=False` 時は未指定で `None`）を抽出し、OpenAPI に `tokenUrl` を指す OAuth2 `password` フローを登録します。

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

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `tokenUrl` | `str` | *(必須)* | クライアントが資格情報をトークンと交換する相対または絶対 URL（通常 `OAuth2PasswordRequestForm` を持つエンドポイント）。 |
| `scheme_name` | `str \| None` | `None` | OpenAPI `components.securitySchemes` 内のカスタム識別名（省略時は `"OAuth2PasswordBearer"`）。 |
| `scopes` | `dict[str, str] \| None` | `None` | OpenAPI スキーマに公開する `{スコープ名: 説明}` の辞書。 |
| `description` | `str \| None` | `None` | OpenAPI ドキュメントに表示されるセキュリティスキームの説明文。 |
| `auto_error` | `bool` | `True` | ヘッダー未指定または非 Bearer 時に `WWW-Authenticate: Bearer` 付きで `HTTPException(401)` を送出します（`False` 時は `None` を返却）。 |
| `refreshUrl` | `str \| None` | `None` | OpenAPI メタデータに記載するトークン更新用エンドポイント URL。 |

### 使用例

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

`OAuth2` を継承する OAuth2 認可コードフロー（Authorization Code Flow）向け Bearer トークン抽出クラスです。`Authorization` ヘッダーから Bearer トークンを抽出しつつ、外部 IdP と連携する OpenAPI の `authorizationCode` フロー URL（`authorizationUrl`、`tokenUrl`、任意の `refreshUrl`）を設定します。

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

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `authorizationUrl` | `str` | *(必須)* | ブラウザリダイレクト先の IdP 認可エンドポイント URL。 |
| `tokenUrl` | `str` | *(必須)* | 認可コードをアクセストークンと交換するトークンエンドポイント URL。 |
| `refreshUrl` | `str \| None` | `None` | OpenAPI に記載する任意のトークンリフレッシュ URL。 |
| `scheme_name` | `str \| None` | `None` | OpenAPI セキュリティスキーム名（省略時は `"OAuth2AuthorizationCodeBearer"`）。 |
| `scopes` | `dict[str, str] \| None` | `None` | この認可コードフローで定義する `{スコープ名: 説明}` の辞書。 |
| `description` | `str \| None` | `None` | OpenAPI セキュリティスキームの説明文。 |
| `auto_error` | `bool` | `True` | 未指定または非 Bearer 時に自動で `401 Unauthorized` を返します（`False` 時は `None` を返却）。 |

### 使用例

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

OAuth2 パスワードフローのトークン発行エンドポイント向けフォームデータ依存クラス（`application/x-www-form-urlencoded` または `multipart/form-data`）です。リクエストボディから `username`、`password`、任意の `grant_type`、空白区切りの `scope`、`client_id`、`client_secret` を抽出し、`scope` を `self.scopes: list[str]` に分割します。

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

### パラメータ・属性

| 名前 | フォーム / 属性 | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- | :--- |
| `grant_type` | Form & 属性 | `str \| None` | `None` | `OAuth2PasswordRequestForm` では省略可能。送信する場合は `^password$` に一致する必要があります。 |
| `username` | Form & 属性 | `str` | *(必須)* | RFC 6749 で定められた固定フィールド名 `username`。 |
| `password` | Form & 属性 | `str` | *(必須)* | RFC 6749 で定められた固定フィールド名 `password`（OpenAPI 上は `format: "password"`）。 |
| `scope` / `scopes` | Form `scope` -> 属性 `scopes` | `str` -> `list[str]` | `""` -> `[]` | 空白区切りの `scope` 文字列を `scope.split()` で分割し `self.scopes` に格納します。 |
| `client_id` | Form & 属性 | `str \| None` | `None` | フォームボディで送信される任意の OAuth2 クライアント ID。 |
| `client_secret` | Form & 属性 | `str \| None` | `None` | フォームボディで送信される任意の OAuth2 クライアントシークレット。 |

### 使用例

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

`OAuth2PasswordRequestForm` の厳格版サブクラスです。RFC 6749 の仕様どおりフォームフィールド `grant_type="password"` の送信を必須とし、`grant_type` が省略されたリクエストを `422 Unprocessable Content` で拒否します。

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

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `grant_type` | `str` | *(必須)* | 必須フィールドであり、`^password$` に一致する必要があります。 |
| `username` | `str` | *(必須)* | 必須の `username` フォームフィールド。 |
| `password` | `str` | *(必須)* | 必須の `password` フォームフィールド。 |
| `scope` | `str` | `""` | 空白区切りのスコープ文字列（`self.scopes: list[str]` に分割）。 |
| `client_id` | `str \| None` | `None` | 任意の OAuth2 クライアント ID。 |
| `client_secret` | `str \| None` | `None` | 任意の OAuth2 クライアントシークレット。 |

### 使用例

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

`SecurityBase` を継承する OAuth2 セキュリティスキームの基底クラスです。任意の OpenAPI `OAuthFlows`（`implicit`、`password`、`clientCredentials`、`authorizationCode`）を構成でき、依存関数として呼び出されると生の `Authorization` ヘッダー文字列を返します。

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

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `flows` | `OAuthFlows \| dict[str, dict[str, Any]]` | `OAuthFlows()` | `clientCredentials`、`implicit`、`password`、`authorizationCode` を構成する OpenAPI OAuth2 フローモデルまたは辞書。 |
| `scheme_name` | `str \| None` | `None` | OpenAPI 内のセキュリティスキーム名（省略時は `"OAuth2"`）。 |
| `description` | `str \| None` | `None` | OpenAPI セキュリティスキームのメタデータ説明文。 |
| `auto_error` | `bool` | `True` | `Authorization` ヘッダーが存在しない場合に `HTTPException(401)` を送出します（`False` 時は `None`）。 |

### 使用例

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

HTTP Bearer 認証スキーム（`Authorization: Bearer <credentials>`）です。`Authorization` スキームが大文字・小文字を問わず `"bearer"` であることを検証し、`scheme` と `credentials` を保持する `HTTPAuthorizationCredentials` モデルを返します。

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

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `bearerFormat` | `str \| None` | `None` | OpenAPI ドキュメント上でトークン形式を示す任意のヒント文字列（例: `"JWT"`）。 |
| `scheme_name` | `str \| None` | `None` | OpenAPI セキュリティスキーム識別名（省略時は `"HTTPBearer"`）。 |
| `description` | `str \| None` | `None` | OpenAPI 向けの説明文。 |
| `auto_error` | `bool` | `True` | 未指定または非 Bearer 時に `401 Unauthorized` を送出します（`False` 時は `None` を返却）。 |

### 使用例

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

HTTP Basic 認証スキーム（RFC 7617）です。Base64 エンコードされた `Authorization: Basic <base64(username:password)>` ヘッダーをデコードし、`HTTPBasicCredentials` インスタンスを注入します。タイミング攻撃を防ぐため、`username` と `password` の検証には必ず `secrets.compare_digest()` を使用してください。

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

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `scheme_name` | `str \| None` | `None` | OpenAPI セキュリティスキーム識別名（省略時は `"HTTPBasic"`）。 |
| `realm` | `str \| None` | `None` | `WWW-Authenticate: Basic realm="<realm>"` に含める任意の Basic 認証レルム名。 |
| `description` | `str \| None` | `None` | OpenAPI ドキュメントに含める説明文。 |
| `auto_error` | `bool` | `True` | 未指定時に `401 Unauthorized` を送出します（不正な Base64 値の場合は常に `401` を送出）。 |

### 使用例

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

OpenAPI 統合向けの HTTP Digest 認証スキームスタブ（RFC 7616）です。`Authorization` ヘッダーが `"Digest"` スキームで始まることを確認して `HTTPAuthorizationCredentials` を返します（完全な Digest nonce / ハッシュ検証を行う場合は `HTTPDigest` をサブクラス化して実装します）。

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

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `scheme_name` | `str \| None` | `None` | OpenAPI セキュリティスキーム識別名（省略時は `"HTTPDigest"`）。 |
| `description` | `str \| None` | `None` | OpenAPI セキュリティスキームの説明文。 |
| `auto_error` | `bool` | `True` | `Authorization: Digest ...` ヘッダーがない場合に `401 Unauthorized` を送出します（`False` 時は `None`）。 |

### 使用例

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

`HTTPBearer` および `HTTPDigest` 依存クラスが返す Pydantic `BaseModel` です。HTTP の `Authorization` ヘッダー値を最初の空白で分割した `scheme` と `credentials` を保持します。

```python
class HTTPAuthorizationCredentials(BaseModel):
    scheme: str
    credentials: str
```

### 属性

| フィールド | 型 | 説明 |
| :--- | :--- | :--- |
| `scheme` | `str` | 最初の空白より前にある認可スキーム文字列（例: `"Bearer"`、`"Digest"`）。 |
| `credentials` | `str` | 最初の空白以降に続くトークンまたは認証パラメータ文字列。 |

### 使用例

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

`HTTPBasic` が返す Pydantic `BaseModel` であり、Base64 デコードされた HTTP Basic `Authorization` ヘッダーから抽出された `username` と `password` を保持します。

```python
class HTTPBasicCredentials(BaseModel):
    username: str
    password: str
```

### 属性

| フィールド | 型 | 説明 |
| :--- | :--- | :--- |
| `username` | `str` | 最初の `":"` 区切り文字より前のデコード済み HTTP Basic ユーザー名。 |
| `password` | `str` | 最初の `":"` 区切り文字より後のデコード済み HTTP Basic パスワード。 |

### 使用例

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

指定した HTTP リクエストヘッダー（`request.headers.get(name)`）から API キーを抽出し、OpenAPI に `in: "header"` の API キースキームを登録します。未指定時はデフォルトで `WWW-Authenticate: APIKey` ヘッダー付きの `401 Unauthorized` を送出します。

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

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `name` | `str` | *(必須)* | 読み取る HTTP ヘッダー名（ASGI ヘッダーでは大文字・小文字非依存、例: `"X-API-Key"`）。 |
| `scheme_name` | `str \| None` | `None` | OpenAPI セキュリティスキーム識別名（省略時は `"APIKeyHeader"`）。 |
| `description` | `str \| None` | `None` | OpenAPI ドキュメントに表示される説明文。 |
| `auto_error` | `bool` | `True` | 未指定または空文字のときに `401 Unauthorized` を送出します（`False` 時は `None`）。 |

### 使用例

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

指定した URL クエリパラメータ（`request.query_params.get(name)`）から API キーを抽出し、OpenAPI に `in: "query"` の API キースキームを登録します。機密性の高い認証情報ではアクセスログやブラウザ履歴への残存を防ぐため、`APIKeyHeader` または `HTTPBearer` の使用を推奨します。

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

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `name` | `str` | *(必須)* | 検査するクエリパラメータ名（例: `"sig"`）。 |
| `scheme_name` | `str \| None` | `None` | OpenAPI セキュリティスキーム識別名（省略時は `"APIKeyQuery"`）。 |
| `description` | `str \| None` | `None` | OpenAPI ドキュメントに表示される説明文。 |
| `auto_error` | `bool` | `True` | 未指定時に `401 Unauthorized`（`WWW-Authenticate: APIKey`）を送出します（`False` 時は `None`）。 |

### 使用例

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

HTTP の `Cookie` ヘッダー（`request.cookies.get(name)`）からセッション識別子や API キーを抽出し、OpenAPI に `in: "cookie"` の API キースキームを登録します。Cookie ベース認証では、`__Host-` プレフィックス・`HttpOnly`・`Secure`・`SameSite` 属性の付与と、状態変更リクエストに対する CSRF トークン検証を併用してください。

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

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `name` | `str` | *(必須)* | `request.cookies` から抽出する Cookie 名（例: `"__Host-session"`）。 |
| `scheme_name` | `str \| None` | `None` | OpenAPI セキュリティスキーム識別名（省略時は `"APIKeyCookie"`）。 |
| `description` | `str \| None` | `None` | OpenAPI ドキュメントに表示される説明文。 |
| `auto_error` | `bool` | `True` | Cookie が未指定または空の場合に `401 Unauthorized` を送出します（`False` 時は `None`）。 |

### 使用例

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

`SecurityBase` を継承する OpenID Connect（OIDC）ディスカバリセキュリティスキームです。OpenAPI に `openIdConnectUrl` を持つ `openIdConnect` スキームを登録し、受信リクエストから生の `Authorization` ヘッダー値を抽出します（JWKS 署名検証を行う場合はサブクラス化して実装します）。

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

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `openIdConnectUrl` | `str` | *(必須)* | OIDC ディスカバリドキュメント URL（通常 `https://.../.well-known/openid-configuration`）。 |
| `scheme_name` | `str \| None` | `None` | OpenAPI セキュリティスキーム識別名（省略時は `"OpenIdConnect"`）。 |
| `description` | `str \| None` | `None` | OpenAPI ドキュメントに表示される説明文。 |
| `auto_error` | `bool` | `True` | `Authorization` 未指定時に `401 Unauthorized`（`WWW-Authenticate: Bearer`）を送出します（`False` 時は `None`）。 |

### 使用例

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

OpenAPI と統合されるすべての FastAPI セキュリティ依存クラスの抽象基底クラス（`fastapi.security.base.SecurityBase`）です。ルート解析時に FastAPI は `isinstance(dependant.call, SecurityBase)` を判定し、`self.model` を OpenAPI スキーマの `components.securitySchemes[self.scheme_name]` に自動登録します。

```python
class SecurityBase:
    model: SecurityBaseModel
    scheme_name: str
```

### 属性

| 属性 | 型 | 説明 |
| :--- | :--- | :--- |
| `model` | `fastapi.openapi.models.SecurityBase` | Pydantic 製の OpenAPI セキュリティモデル（`APIKey`、`HTTPBase`、`HTTPBearer`、`OAuth2`、または `OpenIdConnect`）。 |
| `scheme_name` | `str` | 生成される OpenAPI 仕様の `components.securitySchemes` に登録されるキー名。 |

### 使用例

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

生の HTTP `Authorization` ヘッダー文字列を最初の半角スペースで `(scheme, param)` に安全に分割するユーティリティ関数（`fastapi.security.utils.get_authorization_scheme_param`）です。`None` や空文字、空白を含まない単一トークンに対しても例外を送出しません。

```python
def get_authorization_scheme_param(
    authorization_header_value: str | None,
) -> tuple[str, str]
```

### パラメータ・戻り値

| 項目 | 型 | 説明 |
| :--- | :--- | :--- |
| `authorization_header_value` | `str \| None` | 生の `Authorization` ヘッダー値（例: `request.headers.get("Authorization")`）。 |
| **戻り値** | `tuple[str, str]` | `(scheme, param.strip())` のタプル。未指定または空文字列の場合は `("", "")` を返します。 |

### 使用例

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
