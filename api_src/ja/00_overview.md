# FastAPI パッケージ概要

FastAPI `v0.162.2` は、Python の標準型アノテーション、Pydantic v2 によるデータ検証、Starlette のルーティング基盤、および OpenAPI 3.1.0 スキーマの自動生成を組み合わせて HTTP・Server-Sent Events (SSE)・WebSocket API を構築する高速な ASGI Web フレームワークです。

```drawlib align=center code=hide file=fastapi_package_overview.png caption="FastAPI v0.162.2 パッケージ構成と 15 モジュール群"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Colors, Styles

setup(width=188, height=96)

_ = Colors  # Ensure design token import availability

col_specs = [
    (
        4.0,
        "1. Core App & Input",
        Styles.PrimaryNeutral,
        Styles.PrimaryFlat,
        Styles.WhiteBold.patch(text_size=11.0),
        phosphor.rocket_launch,
        Styles.WhiteBold,
        [
            ("applications", "FastAPI app & lifespan", phosphor.rocket_launch, True),
            ("routing", "APIRouter, APIRoute, Mount", phosphor.git_branch, False),
            ("params", "Path, Query, Header, Body", phosphor.sliders_horizontal, False),
            ("dependencies", "Depends() & async DI graph", phosphor.tree_structure, False),
            ("security", "Security(), OAuth2, APIKey", phosphor.shield_check, False),
        ],
    ),
    (
        65.5,
        "2. Transport & Payloads",
        Styles.Neutral,
        Styles.SecondaryNeutral,
        Styles.DarkBold.patch(text_size=11.0),
        phosphor.arrows_left_right,
        Styles.PrimaryBold,
        [
            ("requests / websockets", "Request & WebSocket I/O", phosphor.arrows_left_right, False),
            ("responses", "JSON, HTML, File, Stream", phosphor.paper_plane_tilt, False),
            ("sse", "EventSourceResponse & SSE", phosphor.broadcast, False),
            ("datastructures", "UploadFile, URL, Headers", phosphor.database, False),
            ("exceptions", "HTTP & validation errors", phosphor.warning_octagon, False),
        ],
    ),
    (
        127.0,
        "3. Ops, Schema & Tooling",
        Styles.Neutral,
        Styles.SecondaryNeutral,
        Styles.DarkBold.patch(text_size=11.0),
        phosphor.wrench,
        Styles.PrimaryBold,
        [
            ("middleware", "CORS, GZip, Host, WSGI", phosphor.stack, False),
            ("telemetry", "TelemetryConfig & OTel", phosphor.pulse, False),
            ("openapi", "OpenAPI 3.1, Docs & ReDoc", phosphor.file_code, False),
            ("background / encoders", "staticfiles & templating", phosphor.squares_four, False),
            ("testclient / cli", "TestClient & fastapi CLI", phosphor.terminal_window, False),
        ],
    ),
]

for x0, title, body_style, hdr_style, hdr_text_style, hdr_icon, hdr_icon_style, items in col_specs:
    panel = Panel(
        title,
        "",
        style=body_style,
        header_style=hdr_style,
        text_style=hdr_text_style,
        icon=hdr_icon,
        icon_style=hdr_icon_style,
        header_variant="filled",
        header_height=8.5,
    )
    panel.draw((x0, 4.0), width=57.0, height=88.0, align="bottom_left")
    inner_xy, inner_w, inner_h = panel.get_content_box(
        (x0, 4.0),
        width=57.0,
        height=88.0,
        padding=(2.8, 2.8),
        align="bottom_left",
    )

    cards = CardList(
        style=Styles.White,
        text_style=Styles.DarkBold.patch(text_size=10.5),
        description_style=Styles.Muted.patch(text_size=10.0),
        badge_shape="rounded_rect",
        badge_style=Styles.PrimaryNeutral,
        icon_style=Styles.PrimaryBold,
        direction="vertical",
        spacing=2.2,
    )
    for mod_name, mod_desc, mod_icon, is_focal in items:
        if is_focal:
            cards.add(
                mod_name,
                mod_desc,
                icon=mod_icon,
                badge_style=Styles.PrimaryFlat,
                icon_style=Styles.WhiteBold,
            )
        else:
            cards.add(mod_name, mod_desc, icon=mod_icon)
    cards.draw(inner_xy, width=inner_w, height=inner_h, align="bottom_left")

save()
```

### トップレベル再エクスポート (`fastapi`)

`fastapi` パッケージ直下（`fastapi/__init__.py`）からのインポートで、主要なアプリケーションクラス、パラメータ宣言関数、依存性マーカー、送受信オブジェクト、ステータス定数にアクセスできます。

| カテゴリ | トップレベルシンボル (`from fastapi import ...`) | 定義元サブモジュール |
| :--- | :--- | :--- |
| **アプリケーション・ルーティング** | `FastAPI`, `APIRouter` | `fastapi.applications`, `fastapi.routing` |
| **パラメータ記述子** | `Path`, `Query`, `Header`, `Cookie`, `Body`, `Form`, `File` | `fastapi.param_functions` |
| **依存性注入・セキュリティ** | `Depends`, `Security` | `fastapi.param_functions` |
| **通信・ストリーミング** | `Request`, `Response`, `WebSocket`, `WebSocketDisconnect` | `fastapi.requests`, `fastapi.responses`, `fastapi.websockets` |
| **ファイル・バックグラウンド処理** | `UploadFile`, `BackgroundTasks` | `fastapi.datastructures`, `fastapi.background` |
| **例外・ステータスコード** | `HTTPException`, `WebSocketException`, `status`, `__version__` | `fastapi.exceptions`, `starlette.status`, `fastapi` |

### API・CLI リファレンス一覧（全 16 ページ）

FastAPI `v0.162.2` の全公開クラス、関数、定数、型エイリアス、CLI コマンドを以下の 16 ページに分けて体系的に収録しています。

| ページ | モジュール / 対象範囲 | 主な収録シンボル・内容 |
| :--- | :--- | :--- |
| [00. FastAPI パッケージ概要](00_overview.md) | `fastapi`, `fastapi.status`, `fastapi.types` | `__version__`、HTTP / WebSocket ステータス定数、`DecoratedCallable`、`IncEx` |
| [01. fastapi.applications](01_applications.md) | `fastapi.applications` | `FastAPI`、HTTP/WS デコレータ、`include_router()`、`mount()`、`frontend()`、ミドルウェア、`openapi()` |
| [02. fastapi.routing](02_routing.md) | `fastapi.routing` | `APIRouter`、`APIRoute`、`APIRoute.get_route_handler()`、`APIWebSocketRoute`、`Mount` |
| [03. fastapi.params](03_parameters.md) | `fastapi.param_functions`, `fastapi.params`, `annotated_doc` | `Path()`、`Query()`、`Header()`、`Cookie()`、`Body()`、`Form()`、`File()`、`Doc()` |
| [04. fastapi.dependencies](04_dependencies.md) | `fastapi.param_functions`, `fastapi.dependencies` | `Depends()`、`Dependant`、非同期・ジェネレータ依存性解決、`dependency_overrides` |
| [05. fastapi.security](05_security.md) | `fastapi.security` | `Security()`、`SecurityScopes`、OAuth2 フロー、`APIKey*`、`HTTPBearer`、`HTTPBasic`、`OpenIdConnect` |
| [06. fastapi.requests & websockets](06_requests_websockets.md) | `fastapi.requests`, `fastapi.websockets` | `Request`、`HTTPConnection`、`WebSocket`、`WebSocketDisconnect`、`WebSocketState` |
| [07. fastapi.responses](07_responses.md) | `fastapi.responses` | `Response`、`JSONResponse`、`HTMLResponse`、`RedirectResponse`、`StreamingResponse`、`FileResponse`、`ORJSONResponse` |
| [08. fastapi.sse](08_sse.md) | `fastapi.sse` | `EventSourceResponse`、`ServerSentEvent`、`format_sse_event()` |
| [09. fastapi.datastructures](09_datastructures.md) | `fastapi.datastructures` | `UploadFile`、`URL`、`Address`、`Headers`、`QueryParams`、`FormData`、`State`、`Default()` |
| [10. fastapi.exceptions](10_exceptions.md) | `fastapi.exceptions`, `fastapi.exception_handlers` | `HTTPException`、`WebSocketException`、`RequestValidationError`、`ResponseValidationError` |
| [11. fastapi.middleware](11_middleware.md) | `fastapi.middleware.*` | `CORSMiddleware`、`GZipMiddleware`、`HTTPSRedirectMiddleware`、`TrustedHostMiddleware`、`WSGIMiddleware` |
| [12. fastapi.telemetry](12_telemetry.md) | `fastapi.telemetry` | `TelemetryConfig` およびネイティブ OpenTelemetry トレーシング・メトリクス・ログ統合 |
| [13. fastapi.openapi](13_openapi.md) | `fastapi.openapi.*` | `get_openapi()`、OpenAPI 3.1.0 スキーマモデル、Swagger UI / ReDoc HTML 生成ヘルパー |
| [14. ユーティリティ群](14_utilities.md) | `background`, `encoders`, `concurrency`, `staticfiles`, `templating`, `utils` | `BackgroundTasks`、`jsonable_encoder()`、`run_in_threadpool()`、`StaticFiles`、`Jinja2Templates` |
| [15. テスト・CLI](15_testing_and_cli.md) | `fastapi.testclient`, `fastapi.cli` | `TestClient`、`fastapi dev`、`fastapi run` |

---

## `const` fastapi.__version__

インストールされている FastAPI リリースを識別するセマンティックバージョン文字列（`PEP 440` / `PEP 396`）です。ヘルスチェックエンドポイント、テレメトリメタデータ、実行時の互換性検証に利用できます。

```python
from fastapi import __version__

__version__: str = "0.162.2"
```

### 属性

| 定数名 | 型 | 値 | 説明 |
| :--- | :--- | :--- | :--- |
| `fastapi.__version__` | `str` | `"0.162.2"` | パッケージルートで公開されている FastAPI のバージョン文字列。 |

### 使用例

```python
from fastapi import FastAPI, __version__

app = FastAPI(title="Inventory API", version=__version__)


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok", "framework_version": __version__}
```

---

## `module` fastapi.status

IANA HTTP ステータスコード（`RFC 9110`）および WebSocket クローズフレームコード（`RFC 6455`）の名前付き整数定数を提供する `starlette.status` の再エクスポートです。パスオペレーションデコレータの `status_code=`、`Response`、`HTTPException`、`WebSocketException` に渡すことでエディタ補完を効かせた明快なコード記述が可能になります。

```python
from fastapi import status

status.HTTP_200_OK: int = 200
status.HTTP_201_CREATED: int = 201
status.HTTP_204_NO_CONTENT: int = 204
status.HTTP_422_UNPROCESSABLE_CONTENT: int = 422
status.WS_1000_NORMAL_CLOSURE: int = 1000
status.WS_1008_POLICY_VIOLATION: int = 1008
```

### HTTP ステータス定数 (`100`–`511`)

| 定数名 | 値 | 分類および主な API 用途 |
| :--- | :--- | :--- |
| `HTTP_100_CONTINUE` .. `HTTP_103_EARLY_HINTS` | `100`–`103` | 情報レスポンス（WebSocket アップグレード時の `101 Switching Protocols`、`103 Early Hints` など）。 |
| `HTTP_200_OK` | `200` | `GET`・`POST`・`PUT`・`PATCH`・`DELETE` における標準の成功ステータス。 |
| `HTTP_201_CREATED` | `201` | リソースの新規作成成功（`POST` エンドポイントで一般的）。 |
| `HTTP_202_ACCEPTED` | `202` | 非同期バックグラウンド処理（`BackgroundTasks` やジョブキュー）の受付完了。 |
| `HTTP_204_NO_CONTENT` | `204` | レスポンスボディを持たない更新・削除の成功。 |
| `HTTP_206_PARTIAL_CONTENT` | `206` | `Range` ヘッダを用いた部分バイト範囲レスポンス（`FileResponse` 等）。 |
| `HTTP_301_MOVED_PERMANENTLY` / `HTTP_302_FOUND` | `301` / `302` | 恒久的・一時的 URL リダイレクト（一部クライアントでメソッドが `GET` に変化する場合あり）。 |
| `HTTP_303_SEE_OTHER` | `303` | `POST` 処理完了後に参照用 `GET` URI へ誘導するリダイレクト。 |
| `HTTP_304_NOT_MODIFIED` | `304` | 条件付きキャッシュヒット（`ETag` / `If-None-Match`）。ボディは空である必要があります。 |
| `HTTP_307_TEMPORARY_REDIRECT` / `HTTP_308_PERMANENT_REDIRECT` | `307` / `308` | HTTP メソッドを維持するリダイレクト（`307` は `RedirectResponse` や `redirect_slashes` の既定値）。 |
| `HTTP_400_BAD_REQUEST` | `400` | 不正なリクエスト構文またはドメインルール違反。 |
| `HTTP_401_UNAUTHORIZED` | `401` | 未認証または無効な認証情報（`WWW-Authenticate` ヘッダと併用）。 |
| `HTTP_403_FORBIDDEN` | `403` | 認証済みだが必要な権限または OAuth2 スコープが不足。 |
| `HTTP_404_NOT_FOUND` | `404` | 対象リソースまたはルートパスが存在しない。 |
| `HTTP_405_METHOD_NOT_ALLOWED` | `405` | パスは一致するが対象の HTTP メソッドが未登録。 |
| `HTTP_409_CONFLICT` | `409` | 一意制約違反または楽観的ロック競合。 |
| `HTTP_413_CONTENT_TOO_LARGE` | `413` | ペイロードサイズ上限超過（非推奨の `HTTP_413_REQUEST_ENTITY_TOO_LARGE` を置換）。 |
| `HTTP_414_URI_TOO_LONG` | `414` | リクエスト URI 長上限超過（非推奨の `HTTP_414_REQUEST_URI_TOO_LONG` を置換）。 |
| `HTTP_415_UNSUPPORTED_MEDIA_TYPE` | `415` | 未対応の `Content-Type` ヘッダによるリクエスト。 |
| `HTTP_416_RANGE_NOT_SATISFIABLE` | `416` | 無効なバイト範囲指定（非推奨の `HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE` を置換）。 |
| `HTTP_422_UNPROCESSABLE_CONTENT` | `422` | FastAPI の `RequestValidationError` 既定ステータス（非推奨の `HTTP_422_UNPROCESSABLE_ENTITY` を置換）。 |
| `HTTP_429_TOO_MANY_REQUESTS` | `429` | レート制限超過（`Retry-After` ヘッダと併用）。 |
| `HTTP_500_INTERNAL_SERVER_ERROR` | `500` | 未処理のサーバー例外、または `ResponseValidationError` によるレスポンス契約違反。 |
| `HTTP_502_BAD_GATEWAY` / `HTTP_503_SERVICE_UNAVAILABLE` / `HTTP_504_GATEWAY_TIMEOUT` | `502`–`504` | 上流サービス障害、メンテナンス・過負荷遮断、または上流タイムアウト。 |
| `HTTP_511_NETWORK_AUTHENTICATION_REQUIRED` | `511` | キャプティブポータル等のネットワーク認証が必要（`5xx` 番台の上限定数）。 |

### WebSocket クローズコード定数 (`1000`–`1015`)

| 定数名 | 値 | 説明 |
| :--- | :--- | :--- |
| `WS_1000_NORMAL_CLOSURE` | `1000` | WebSocket セッションの正常終了。 |
| `WS_1001_GOING_AWAY` | `1001` | サーバー停止やブラウザのページ離脱に伴う切断。 |
| `WS_1002_PROTOCOL_ERROR` | `1002` | WebSocket プロトコル違反による切断。 |
| `WS_1003_UNSUPPORTED_DATA` | `1003` | 未対応のフレームデータ型（テキスト専用の箇所にバイナリを受信した場合など）。 |
| `WS_1005_NO_STATUS_RCVD` / `WS_1006_ABNORMAL_CLOSURE` | `1005` / `1006` | ステータスコード欠落またはトランスポート異常切断を表す予約コード。 |
| `WS_1007_INVALID_FRAME_PAYLOAD_DATA` | `1007` | 非 UTF-8 テキストフレームまたはスキーマ不整合データ。 |
| `WS_1008_POLICY_VIOLATION` | `1008` | ポリシー・認証違反（`WebSocketRequestValidationError` の既定コード）。 |
| `WS_1009_MESSAGE_TOO_BIG` | `1009` | 許容サイズを超えるフレームメッセージ。 |
| `WS_1010_MANDATORY_EXT` | `1010` | クライアントが必須とした WebSocket 拡張がネゴシエートされなかった場合。 |
| `WS_1011_INTERNAL_ERROR` | `1011` | サーバー内部の予期しない例外によるセッション終了。 |
| `WS_1012_SERVICE_RESTART` / `WS_1013_TRY_AGAIN_LATER` | `1012` / `1013` | サーバー再起動中または一時的な過負荷（バックオフ後の再接続が可能）。 |
| `WS_1014_BAD_GATEWAY` / `WS_1015_TLS_HANDSHAKE` | `1014` / `1015` | 上流ゲートウェイエラー（`1014`）または予約済み TLS ハンドシェイク失敗（`1015`）。 |

### 使用例

```python
from fastapi import FastAPI, HTTPException, status

app = FastAPI()
ITEMS: dict[int, str] = {1: "Keyboard"}


@app.post("/items/{item_id}", status_code=status.HTTP_201_CREATED)
def create_item(item_id: int, name: str) -> dict[str, int | str]:
    if item_id in ITEMS:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Item already exists",
        )
    ITEMS[item_id] = name
    return {"id": item_id, "name": name}
```

---

## `type` fastapi.types.DecoratedCallable

FastAPI のルート・WebSocket・ミドルウェア・例外ハンドラ各デコレータの戻り値型に使われる境界付き `TypeVar` です。デコレート対象の関数が持つ引数型・戻り値型シグネチャをそのまま保持し、静的型チェッカー（`mypy`、`pyright`、`ty`）での型推論を維持します。

```python
from collections.abc import Callable
from typing import Any, TypeVar
from fastapi.types import DecoratedCallable

DecoratedCallable = TypeVar("DecoratedCallable", bound=Callable[..., Any])
```

### 型定義の詳細

| シンボル | 定義 | 用途 |
| :--- | :--- | :--- |
| `DecoratedCallable` | `TypeVar("DecoratedCallable", bound=Callable[..., Any])` | `@app.get()`、`@router.post()`、`@app.websocket()`、`@app.middleware()`、`@app.exception_handler()` でエンドポイント関数の型を保持。 |
| `ModelNameMap` | `dict[type[BaseModel] \| type[Enum], str]` | `fastapi.types` 内の補助エイリアス。Pydantic モデルや Enum を OpenAPI コンポーネント名へ対応付けます。 |
| `DependencyCacheKey` | `tuple[Callable[..., Any] \| None, tuple[str, ...], str]` | `fastapi.types` 内の補助エイリアス。リクエスト/関数スコープの DI キャッシュキーを表現します。 |

### 使用例

```python
from collections.abc import Callable
from fastapi import APIRouter
from fastapi.types import DecoratedCallable


def public_get(router: APIRouter, path: str) -> Callable[[DecoratedCallable], DecoratedCallable]:
    return router.get(path, tags=["public"])
```

---

## `type` fastapi.types.IncEx

パスオペレーションデコレータ、`add_api_route()`、`APIRoute` の `response_model_include` および `response_model_exclude` で受け取る再帰的型エイリアス（`pydantic.main.IncEx` の再エクスポート）です。トップレベルの `set` またはネストした `dict` でシリアライズ対象フィールドを制御します。

```python
from collections.abc import Mapping
from fastapi.types import IncEx

type IncEx = (
    set[int]
    | set[str]
    | Mapping[int, IncEx | bool]
    | Mapping[str, IncEx | bool]
)
```

### 指定可能なデータ構造

| 型形状 | 指定例 | シリアライズ時の動作 |
| :--- | :--- | :--- |
| `set[str]` | `{"id", "username"}` | Pydantic モデルまたは `dict` のトップレベル属性名を指定して抽出・除外します。 |
| `set[int]` | `{0, 1}` | `list` や `tuple` をシリアライズする際に対象インデックスを指定します。 |
| `Mapping[str, IncEx \| bool]` | `{"profile": {"email": True}}` | ネストしたサブモデルや辞書を再帰的に辿り、末端フィールド単位で抽出・除外します。 |
| `Mapping[int, IncEx \| bool]` | `{"__all__": {"secret_hash"}}` / `{0: {"name": True}}` | コレクション要素全体または特定インデックス配下のネスト属性へルールを適用します。 |

### 使用例

```python
from fastapi import FastAPI
from fastapi.types import IncEx
from pydantic import BaseModel

app = FastAPI()


class UserOut(BaseModel):
    id: int
    username: str
    internal_notes: str = ""


PUBLIC_FIELDS: IncEx = {"id", "username"}


@app.get("/users/me", response_model=UserOut, response_model_include=PUBLIC_FIELDS)
def get_me() -> UserOut:
    return UserOut(id=1, username="alice", internal_notes="vip-tier")
```
