# `SecurityBase` 階層・`HTTPConnection`・`SecurityScopes`

FastAPI は認証・認可機構を独立した WSGI/ASGI ミドルウェアとしてではなく、`Dependant` 依存性注入グラフのファーストクラスなノードとして実装しています。`fastapi/security/` 配下のすべての組み込みクラスは `SecurityBase`（`fastapi/security/base.py`）を継承し、**実行時の非同期クレデンシャル抽出器**（`async def __call__(self, request: HTTPConnection)`）と **コンパイル時の OpenAPI 3.1 `SecurityScheme` モデル保持器**（`self.model` と `self.scheme_name`）という 2 つの役割を同時に担います。これに `Security(..., scopes=[...])` と Starlette の `HTTPConnection` 基底クラスが組み合わさることで、単一のセキュリティ依存関係が HTTP エンドポイント、WebSocket ハンドシェイク、OAuth2 スコープ階層、および複数方式の OR 認証チェーン全体で一貫して機能します。

```drawlib align=center code=hide file=security_base_class_hierarchy.png caption="fastapi/security/ における SecurityBase クラス階層：すべての具象抽出器が OpenAPI の SecurityBaseModel と HTTPConnection 呼び出し可能オブジェクトを兼ね備える。"
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

## 1. `SecurityBase` の二面性設計

`fastapi/security/base.py` は `model: SecurityBaseModel` と `scheme_name: str` の 2 属性のみを宣言するわずか 7 行の基底クラスです。この最小限の契約によって、互いに疎結合な 2 つのサブシステムが橋渡しされます。

1. **実行時 DI 呼び出し可能オブジェクト（`solve_dependencies`）**: すべての具象サブクラスは `async def __call__(self, request: HTTPConnection) -> ...` を実装します。`oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/token")` のようなインスタンスを `Depends(oauth2_scheme)` や `Security(oauth2_scheme, scopes=[...])` に渡すと、`get_dependant()` が `oauth2_scheme.__call__` を解析して `http_connection_param_name = "request"` を記録し、通常の非同期依存ノードとして実行します。
2. **コンパイル時 OpenAPI 記述子（`get_openapi`）**: OpenAPI スキーマ合成時（`fastapi/openapi/utils.py`）、`_is_security_scheme(dependant=...)` は `inspect.unwrap(_impartial(call))` でアンラップした対象が `isinstance(unwrapped, SecurityBase)` を満たすかを判定します。一致した各ノードについて `_get_openapi_security_definitions()` が `security_scheme.model` を `jsonable_encoder(..., by_alias=True, exclude_none=True)` で直列化して `components.securitySchemes[scheme_name]` に登録し、集約された OAuth2 スコープを各オペレーションの `security` 配列へ統合します。

| 系統とモジュール | 具象抽出器（`v0.162.2`） | OpenAPI `self.model` 型 | 実行時の戻り値と `401` チャレンジヘッダ |
| :--- | :--- | :--- | :--- |
| **`OAuth2`** (`oauth2.py`) | `OAuth2PasswordBearer`, `OAuth2AuthorizationCodeBearer` | `OAuth2Model` (`flows.password` / `flows.authorizationCode`) | 生の Bearer トークン `str`（`Authorization: Bearer <param>`）；`WWW-Authenticate: Bearer`。 |
| **`HTTPBase`** (`http.py`) | `HTTPBearer`, `HTTPBasic`, `HTTPDigest` | `HTTPBearerModel` / `HTTPBaseModel` (`scheme="basic" \| "digest"`) | `HTTPAuthorizationCredentials` またはデコード済み `HTTPBasicCredentials`；`Bearer`, `Basic` (+ `realm`), `Digest`。 |
| **`APIKeyBase`** (`api_key.py`) | `APIKeyHeader`, `APIKeyCookie`, `APIKeyQuery` | `APIKey` (`in`: `header`, `cookie`, `query`) | `check_api_key()` で検証したキー文字列 `str`；`WWW-Authenticate: APIKey`（RFC 9110 準拠）。 |
| **`OpenIdConnect`** (`open_id_connect_url.py`) | `OpenIdConnect` | `OpenIdConnectModel` (`openIdConnectUrl`) | `Authorization` ヘッダ文字列 `str`（OpenAPI 連携用スタブ）；`WWW-Authenticate: Bearer`。 |

なお、`fastapi/security/oauth2.py` の `OAuth2PasswordRequestForm` および `OAuth2PasswordRequestFormStrict` は `SecurityBase` を継承 **しません**。これらは保護対象リソースではなくトークン発行エンドポイント向けに `__init__` で `Form()` フィールド（`grant_type`, `username`, `password`, 空白区切りの `scope`, `client_id`, `client_secret`）を受け取る通常のクラス依存関係です。同様に、`HTTPDigest` と `OpenIdConnect` はヘッダ抽出と OpenAPI 定義登録を担うスタブであり、暗号学的な Digest 検証や OIDC ディスカバリ検証は利用者側サブクラスで実装する設計となっています。

## 2. Starlette `HTTPConnection` による `Request` と `WebSocket` の統合

`oauth2.py`, `http.py`, `api_key.py`, `open_id_connect_url.py` のすべての `__call__` メソッドには、共通して重要な型アノテーション上の設計が施されています。

- すべての抽出器は引数名が `request` であっても、`fastapi.Request` ではなく `starlette.requests.HTTPConnection` を用いて `async def __call__(self, request: HTTPConnection) -> ...` と宣言しています。
- Starlette のクラス階層において、`Request`（HTTP）と `WebSocket`（WS）はともに `HTTPConnection` のサブクラスであり、`.headers`, `.query_params`, `.cookies`, `.path_params`, `.scope` への統一された読み取りインターフェースを共有しています。
- コンパイル時の `add_non_field_param_to_dependency()`（`fastapi/dependencies/utils.py`）は `Request`、`WebSocket`、次いで `HTTPConnection` の順にサブクラス判定を行い、`dependant.http_connection_param_name = "request"` を記録します。
- 実行時の `solve_dependencies(request: Request | WebSocket, ...)` は、`isinstance(request, Request)` や `isinstance(request, WebSocket)` の分岐よりも先に無条件で `values[dependant.http_connection_param_name] = request` を注入します。その結果、WebSocket 専用の抽出器を別途用意しなくとも、`@app.websocket("/ws")` ルートのハンドシェイク依存解決で `APIKeyCookie` や `OAuth2PasswordBearer` をそのまま利用できます。

## 3. トップダウン `SecurityScopes` 伝播と `auto_error=False` 合成

### 3.1 `Security(..., scopes=[...])` と `SecurityScopes`

`params.Security` は `params.Depends` を継承する frozen `@dataclass` であり、`scopes: Sequence[str] | None = None` フィールドを追加します。スコープ伝播は `get_dependant()` によるコンパイル時に **親から子へのトップダウン方向** で行われます。

1. 各 `Dependant` ノードにおいて、`get_dependant()` は `current_scopes = (parent_oauth_scopes or []) + (own_oauth_scopes or [])` を算出します。
2. 引数に `Security(sub_call, scopes=["audit:read"])` が指定されていると、子 `get_dependant()` 呼び出しに対して `own_oauth_scopes=["audit:read"]` と `parent_oauth_scopes=current_scopes` が引き渡されます。
3. 末端または中間の依存関数が `security_scopes: SecurityScopes` 引数を宣言していると、`dependant.security_scopes_param_name` が記録されます。`solve_dependencies()` 実行時には `_get_oauth_scopes(dependant=dependant)` によって宣言順を保ったまま重複排除されたスコープ配列から `SecurityScopes` が生成され、RFC 6749 準拠の空白区切り文字列 `security_scopes.scope_str = " ".join(self.scopes)` も同時に構築されます。
4. `SecurityScopes`、`own_oauth_scopes`、または `SecurityBase` を含む経路では `_uses_scopes()` が `True` を返すため、`_get_cache_key()` は `tuple(sorted(set(scopes)))` を `DependencyCacheKey` に組み込み、同一ルート内の異なるブランチで異なるスコープ集合が要求された場合でもキャッシュ衝突を防止します。

### 3.2 `auto_error=False` と論理 OR 認証チェーンの構築

デフォルトの `auto_error=True` では、ヘッダや Cookie の欠落、あるいはスキーム不一致（`HTTPBearer` に `Basic` が送られた場合など）が検出された時点で即座に `HTTPException(status_code=401, detail="Not authenticated", headers={"WWW-Authenticate": ...})` が送出され、`solve_dependencies()` が中断されます（なお `HTTPBasic` には意図的な例外があり、`Authorization: Basic ...` ヘッダ自体が存在するにもかかわらず不正な Base64 や `:` 区切り欠落がある場合は、`auto_error=False` であっても壊れた認証情報が匿名アクセスへ暗黙フォールバックしないよう必ず `401` を送出します）。

API クライアント向けの `OAuth2PasswordBearer(..., auto_error=False)` とブラウザセッション向けの堅牢な `APIKeyCookie(name="__Host-session", auto_error=False)` のように複数の抽出器へ `auto_error=False` を設定すると、未指定の経路は例外を送出せず `None` を返します。これにより上位の複合検証関数で `token or session_id` のような論理 OR フォールバックと `SecurityScopes` 検証を簡潔に記述でき、すべての経路が空のときだけ単一の `401`/`403` を返しつつ、`get_openapi()` には両方の認証スキームを自動出力させることができます。

```drawlib align=center code=hide file=http_connection_scope_propagation.png caption="HTTP と WebSocket を統合する HTTPConnection 注入、トップダウンの SecurityScopes 継承、および auto_error=False による OR 認証合成。"
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

## 4. `SecurityBase.model` と多段 `SecurityScopes` 伝播のコード検証

以下のスニペットでは、OpenAPI 直列化向けの `OAuth2PasswordBearer.model`、末端抽出器における `http_connection_param_name` バインド、および `auto_error=False` の Cookie フォールバックを用いた 3 階層の `Security()` チェーン解決を確認します。

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

`Dependant` ノードの構築とリクエスト内キャッシュキーの算出については [Dependant グラフと solve_dependencies](dependant_and_solver.md) を、`_get_openapi_security_definitions()` による OpenAPI 3.1 `securitySchemes` の出力処理については [get_openapi()・$defs 集約・Docs UI](../06_openapi_and_docs/openapi_synthesis_engine.md) を参照してください。
