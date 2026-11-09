# fastapi.dependencies

FastAPI の依存性注入（DI）システムは、リクエスト単位で階層的な呼び出しグラフを解決し、サブ依存パラメータの自動検証、リクエスト内キャッシュ、`yield` クリーンアップスコープ（`"function"` と `"request"`）、OAuth2 の `SecurityScopes` 集約、およびテスト時の `FastAPI.dependency_overrides` による差し替えを提供します。

```drawlib align=center code=hide file=fastapi_depends_security_api.png caption="FastAPI の依存性注入・セキュリティスコープ・ライフサイクル概要"
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

パスオペレーション引数、ルーター、またはアプリケーション全体の依存関係を宣言します。実行時に FastAPI は対象の `dependency` 呼び出し可能オブジェクト（関数、コルーチン、ジェネレータ、非同期ジェネレータ、またはクラス）のシグネチャを再帰的に解析し、解決済みの戻り値または `yield` 値を注入します。`fastapi.Depends`（実体は `fastapi.param_functions.Depends`）は不変データクラス `fastapi.params.Depends` を返します。

```python
def Depends(
    dependency: Callable[..., Any] | None = None,
    *,
    use_cache: bool = True,
    scope: Literal["function", "request"] | None = None,
) -> Any
```

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `dependency` | `Callable[..., Any] \| None` | `None` | 呼び出す依存オブジェクト。`Annotated[MyClass, Depends()]` のように `None` を省略指定した場合、引数の型アノテーション `MyClass` がそのまま使用されます。 |
| `use_cache` | `bool` | `True` | 同一リクエストの依存 DAG 内で同じ呼び出し可能オブジェクトが複数回宣言された場合、初回解決値を再利用します。毎回再実行する場合は `False` を指定します。 |
| `scope` | `Literal["function", "request"] \| None` | `None` | `yield` 依存関係の終了処理タイミングを制御します。`"function"` はパスオペレーション関数終了直後（レスポンス送信前）、`"request"` はクライアントへのレスポンス送信後に後処理を実行します。 |

### 使用例

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

必要な OAuth2 権限スコープ（`scopes`）を伴うセキュリティ依存関係を宣言します。実行時の解決動作は `Depends()` と同等（`fastapi.params.Security` は `fastapi.params.Depends` のサブクラス）ですが、指定した `scopes` を下流の `SecurityScopes` に伝播させ、自動生成される OpenAPI スキーマ（`/openapi.json` および `/docs`）にセキュリティ要件を統合します。

```python
def Security(
    dependency: Callable[..., Any] | None = None,
    *,
    scopes: Sequence[str] | None = None,
    use_cache: bool = True,
) -> Any
```

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `dependency` | `Callable[..., Any] \| None` | `None` | リクエストごとに解決するセキュリティ関数または `SecurityBase` スキームのインスタンス。 |
| `scopes` | `Sequence[str] \| None` | `None` | パスオペレーションや上位依存が要求する OAuth2 スコープ文字列の列（OpenAPI 定義および `SecurityScopes` に反映）。 |
| `use_cache` | `bool` | `True` | 同一リクエスト内で `(callable, tuple(scopes))` キー単位の解決結果をキャッシュして再利用します。 |

### 使用例

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

依存関数の引数に `security_scopes: SecurityScopes` と型アノテーションすることで FastAPI が自動注入する特殊クラスです。現在の依存チェーン上で宣言されたすべての `Security(..., scopes=[...])` のスコープ文字列を一箇所に集約して参照できます。`fastapi.security.SecurityScopes`（定義元は `fastapi.security.oauth2`）からインポートします。

```python
class SecurityScopes:
    scopes: list[str]
    scope_str: str

    def __init__(
        self,
        scopes: list[str] | None = None,
    ) -> None: ...
```

### パラメータ・属性

| 名前 | 種別 | 型 | 説明 |
| :--- | :--- | :--- | :--- |
| `scopes` | 引数 / 属性 | `list[str]` | 現在の依存チェーン全体で要求されているスコープ文字列のリスト（`None` の場合は `[]` に初期化）。 |
| `scope_str` | 属性 | `str` | すべての要求スコープを空白区切りで連結した文字列（`" ".join(self.scopes)`）。RFC 6749 準拠の `WWW-Authenticate` ヘッダー生成に使用します。 |

### 使用例

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

元の依存オブジェクトを代替の呼び出し可能オブジェクトへ対応付ける、`FastAPI` インスタンス上の可変辞書属性です。リクエスト解決時に FastAPI はすべての `Depends()` / `Security()` ターゲットに対して `app.dependency_overrides` を優先参照するため、ルート定義を変更することなく単体・結合テスト用のモック依存へ安全に差し替えられます。

```python
app.dependency_overrides: dict[Callable[..., Any], Callable[..., Any]] = {}
```

### 仕様

| 項目 | 型・パターン | 説明 |
| :--- | :--- | :--- |
| 辞書キー | `Callable[..., Any]` | `Depends(...)` や `Security(...)` で指定された元の依存関数または呼び出し可能オブジェクト。 |
| 辞書値 | `Callable[..., Any]` | 同期・非同期の代替呼び出し可能オブジェクト。代替関数自身の FastAPI 引数（`Query`、`Header`、ネストした `Depends`）も通常どおり解決されます。 |
| テスト後のリセット | `app.dependency_overrides.clear()` | テスト終了後にオーバーライドを消去し、本番用の依存解決へ戻します。 |

### 使用例

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
