# fastapi.routing

`fastapi.routing` モジュールは、モジュール単位のルート構成を担う `APIRouter`、Pydantic 検証付き HTTP パスオペレーションを表す `APIRoute`、依存性注入対応の WebSocket ルート `APIWebSocketRoute`、低優先度の静的フロントエンド配信 `frontend()`、および ASGI サブアプリを統合する `Mount` を提供します。

```drawlib align=center code=hide file=fastapi_routing_classes.png caption="FastAPI ルーティングクラス階層とコンポジション（APIRouter, APIRoute, APIWebSocketRoute, Mount）"
from drawlib.canvas import save, setup
from drawlib.diagrams.class_diagram import ClassDiagram, ClassNode
from drawlib.fonts import FontRoboto, FontSourceCode
from drawlib.styles import Colors, Styles

setup(width=190, height=92)

_ = Colors

cd = ClassDiagram(
    node_style=Styles.Neutral.patch(text_font=FontSourceCode.ROBOTO_MONO, text_size=10.0),
    header_style=Styles.PrimaryNeutral.patch(text_font=FontRoboto.ROBOTO_BOLD, text_size=10.8),
    edge_style=Styles.DarkBold.patch(line_width=1.5),
    edge_text_style=Styles.Dark.patch(text_size=10.0),
)

router_cls = cd.add(
    ClassNode(
        "APIRouter",
        width=78.0,
        row_height=3.8,
        header_style=Styles.PrimaryFlat.patch(
            text_color=Colors.White,
            text_font=FontRoboto.ROBOTO_BOLD,
            text_size=11.2,
        ),
    )
    .add_attribute("prefix", "str", default_value='""')
    .add_attribute("dependencies", "list[Depends]")
    .add_method("get..delete", "path: str", "Callable")
    .add_method("include_router", "router: APIRouter", "None")
    .add_method("frontend", "path, directory", "None"),
    xy=(95.0, 70.5),
)

api_route_cls = cd.add(
    ClassNode(
        "APIRoute",
        width=56.0,
        row_height=3.8,
        header_style=Styles.PrimaryNeutral.patch(text_font=FontRoboto.ROBOTO_BOLD, text_size=11.0),
    )
    .add_attribute("path", "str")
    .add_attribute("methods", "set[str]")
    .add_attribute("dependant", "Dependant")
    .add_method("get_route_handler", "", "Callable"),
    xy=(33.0, 21.0),
)

ws_route_cls = cd.add(
    ClassNode(
        "APIWebSocketRoute",
        width=56.0,
        row_height=3.8,
        header_style=Styles.SecondaryNeutral.patch(text_font=FontRoboto.ROBOTO_BOLD, text_size=11.0),
    )
    .add_attribute("path", "str")
    .add_attribute("endpoint", "Callable")
    .add_attribute("dependencies", "list[Depends]")
    .add_method("matches", "scope", "tuple"),
    xy=(95.0, 21.0),
)

mount_cls = cd.add(
    ClassNode(
        "Mount",
        width=56.0,
        row_height=3.8,
        header_style=Styles.SecondaryNeutral.patch(text_font=FontRoboto.ROBOTO_BOLD, text_size=11.0),
    )
    .add_attribute("path", "str")
    .add_attribute("app", "ASGIApp")
    .add_attribute("name", "str | None")
    .add_method("handle", "scope, recv, send", "None"),
    xy=(157.0, 21.0),
)

cd.connect(
    router_cls,
    api_route_cls,
    "composition",
    label="HTTP routes (0..*)",
    directed=True,
    start_side="left",
    end_side="top",
)
cd.connect(
    router_cls,
    ws_route_cls,
    "composition",
    label="WS routes (0..*)",
    directed=True,
    start_side="bottom",
    end_side="top",
)
cd.connect(
    router_cls,
    mount_cls,
    "aggregation",
    label="ASGI mounts (0..*)",
    directed=True,
    start_side="right",
    end_side="top",
)

cd.draw(xy=(0.0, 0.0))
save()
```

---

## `class` APIRouter

モジュール分割用のルータークラス（`from fastapi import APIRouter` または `from fastapi.routing import APIRouter`）であり、`starlette.routing.Router` を継承します。複数ファイルに分割した HTTP / WebSocket パスオペレーションに対して共通の `prefix`、`tags`、`dependencies`、`responses`、`lifespan`、`route_class` を付与し、`FastAPI` アプリや親 `APIRouter` へ統合します。

```python
from fastapi import APIRouter

class APIRouter(routing.Router):
    def __init__(
        self,
        *,
        prefix: str = "",
        tags: list[str | Enum] | None = None,
        dependencies: Sequence[Depends] | None = None,
        default_response_class: type[Response] = Default(JSONResponse),
        responses: dict[int | str, dict[str, Any]] | None = None,
        callbacks: list[BaseRoute] | None = None,
        routes: list[BaseRoute] | None = None,  # deprecated
        redirect_slashes: bool = True,
        default: ASGIApp | None = None,
        dependency_overrides_provider: Any | None = None,
        route_class: type[APIRoute] = APIRoute,
        on_startup: Sequence[Callable[[], Any]] | None = None,
        on_shutdown: Sequence[Callable[[], Any]] | None = None,
        lifespan: Lifespan[Any] | None = None,
        deprecated: bool | None = None,
        include_in_schema: bool = True,
        generate_unique_id_function: Callable[[APIRoute], str] = Default(generate_unique_id),
        strict_content_type: bool = Default(True),
    ) -> None: ...
```

### コンストラクタ引数

| 引数 | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `prefix` | `str` | `""` | このルーターに登録される全オペレーションへ付与されるパスプレフィックス（`"/"` で始まり、末尾は `"/"` 以外）。 |
| `tags` | `list[str \| Enum] \| None` | `None` | このルーター内の全パスオペレーションに継承される OpenAPI タグ一覧。 |
| `dependencies` | `Sequence[Depends] \| None` | `None` | このルーター内の全オペレーション実行前に評価される共通 `Depends()` / `Security()` リスト。 |
| `default_response_class` | `type[Response]` | `Default(JSONResponse)` | このルーター内のオペレーションに継承される既定 `Response` サブクラス。 |
| `responses` | `dict[int \| str, dict[str, Any]] \| None` | `None` | ルーター内の全オペレーションへマージされる共通 OpenAPI レスポンス定義。 |
| `callbacks` | `list[BaseRoute] \| None` | `None` | ルーター内のオペレーションに継承される OpenAPI コールバックルート一覧。 |
| `routes` | `list[BaseRoute] \| None` | `None` | *非推奨。* Starlette 互換ルートリスト。通常は `@router.get()` 等で登録します。 |
| `redirect_slashes` | `bool` | `True` | 末尾スラッシュ違いのリクエストに対して `307 Temporary Redirect` を返すかどうか。 |
| `default` | `ASGIApp \| None` | `None` | いずれのルートにも一致しなかった場合のフォールバック ASGI ハンドラ（既定は `404`）。 |
| `dependency_overrides_provider` | `Any \| None` | `None` | `dependency_overrides` を提供する親 `FastAPI` アプリへの内部参照。 |
| `route_class` | `type[APIRoute]` | `APIRoute` | このルーターの `add_api_route()` や各 HTTP デコレータが生成するカスタム `APIRoute` サブクラス。 |
| `on_startup` | `Sequence[Callable[[], Any]] \| None` | `None` | レガシーな起動時フック一覧。新規コードでは `lifespan` を使用します。 |
| `on_shutdown` | `Sequence[Callable[[], Any]] \| None` | `None` | レガシーな終了時フック一覧。新規コードでは `lifespan` を使用します。 |
| `lifespan` | `Lifespan[Any] \| None` | `None` | `include_router()` 時に親ルーター・親アプリの `lifespan` と自動合成されるコンテキストマネージャ。 |
| `deprecated` | `bool \| None` | `None` | `True` の場合、このルーター内の全オペレーションを OpenAPI 上で非推奨にします。 |
| `include_in_schema` | `bool` | `True` | このルーター内のオペレーションを OpenAPI スキーマに含めるかどうか。 |
| `generate_unique_id_function` | `Callable[[APIRoute], str]` | `Default(generate_unique_id)` | このルーター内のオペレーションに対する `operationId` 自動生成関数。 |
| `strict_content_type` | `bool` | `Default(True)` | リクエストボディを JSON として解析する際に JSON 系 `Content-Type` ヘッダを必須とするかどうか。 |

### 使用例

```python
from fastapi import APIRouter, FastAPI

router = APIRouter(
    prefix="/orders",
    tags=["orders"],
    responses={404: {"description": "Order not found"}},
)


@router.get("/{order_id}")
def read_order(order_id: str) -> dict[str, str]:
    return {"order_id": order_id, "status": "shipped"}


app = FastAPI()
app.include_router(router)
```

---

## `method` APIRouter.get() / post() / put() / patch() / delete()

`APIRouter` 上の HTTP メソッドデコレータ群（`router.get()`、`router.post()`、`router.put()`、`router.patch()`、`router.delete()`、`router.options()`、`router.head()`、`router.trace()`）です。各デコレータは内部で `methods=["<VERB>"]` を指定して `router.add_api_route()` を呼び出します。

```python
@router.get(
    path: str,
    *,
    response_model: Any = Default(None),
    status_code: int | None = None,
    tags: list[str | Enum] | None = None,
    dependencies: Sequence[Depends] | None = None,
    summary: str | None = None,
    description: str | None = None,
    response_description: str = "Successful Response",
    responses: dict[int | str, dict[str, Any]] | None = None,
    deprecated: bool | None = None,
    operation_id: str | None = None,
    response_model_include: IncEx | None = None,
    response_model_exclude: IncEx | None = None,
    response_model_by_alias: bool = True,
    response_model_exclude_unset: bool = False,
    response_model_exclude_defaults: bool = False,
    response_model_exclude_none: bool = False,
    include_in_schema: bool = True,
    response_class: type[Response] = Default(JSONResponse),
    name: str | None = None,
    callbacks: list[BaseRoute] | None = None,
    openapi_extra: dict[str, Any] | None = None,
    generate_unique_id_function: Callable[[APIRoute], str] = Default(generate_unique_id),
) -> Callable[[DecoratedCallable], DecoratedCallable]
```

### 引数の継承・合成ルール

| 項目 | 合成ルール |
| :--- | :--- |
| `path` | `router.prefix` の末尾に連結されます（例: `prefix="/users"` と `router.get("")` で `"/users"` を配信）。 |
| `tags`, `dependencies`, `callbacks` | ルーター自身の `tags`・`dependencies`・`callbacks` の末尾に追加されます。 |
| `responses` | `router.responses` の上にルート固有の定義がマージされます（`{**router.responses, **responses}`）。 |
| `response_class`, `generate_unique_id_function` | `get_value_or_default()` により解決され、未指定時はルーター側の既定値を継承します。 |

### 使用例

```python
from fastapi import APIRouter, status

router = APIRouter(prefix="/products", tags=["catalog"])


@router.get("")
def list_products() -> list[dict[str, str]]:
    return [{"sku": "SKU-100"}]


@router.post("", status_code=status.HTTP_201_CREATED)
def add_product(sku: str) -> dict[str, str]:
    return {"sku": sku}
```

---

## `method` APIRouter.include_router()

現在の `APIRouter` の配下へ別の子 `APIRouter` をネストして組み込みます。プレフィックス、タグ、依存関係、レスポンスクラス、OpenAPI レスポンス、および `lifespan` コンテキストを階層的に合成しつつ、自己参照や循環参照のルーター構成を検証時に防止します。

```python
router.include_router(
    router: APIRouter,
    *,
    prefix: str = "",
    tags: list[str | Enum] | None = None,
    dependencies: Sequence[Depends] | None = None,
    default_response_class: type[Response] = Default(JSONResponse),
    responses: dict[int | str, dict[str, Any]] | None = None,
    callbacks: list[BaseRoute] | None = None,
    deprecated: bool | None = None,
    include_in_schema: bool = True,
    generate_unique_id_function: Callable[[APIRoute], str] = Default(generate_unique_id),
) -> None
```

### 引数

| 引数 | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `router` | `APIRouter` | *(必須)* | 組み込む子 `APIRouter`（同一インスタンスや循環参照を含むルーターは不可）。 |
| `prefix` | `str` | `""` | 親ルーターのプレフィックスと子ルートパスの間に挿入する追加プレフィックス。 |
| `tags` | `list[str \| Enum] \| None` | `None` | 子ルーター内の全オペレーションへ伝播する追加 OpenAPI タグ。 |
| `dependencies` | `Sequence[Depends] \| None` | `None` | 子ルーター自身の依存関係より先に実行される追加依存関係。 |
| `default_response_class` | `type[Response]` | `Default(JSONResponse)` | 子ルーターへ継承される既定の `Response` クラス。 |
| `responses` | `dict[int \| str, dict[str, Any]] \| None` | `None` | 子ルーターのレスポンス定義とマージされる追加 OpenAPI レスポンス定義。 |
| `callbacks` | `list[BaseRoute] \| None` | `None` | 子オペレーションへ伝播する OpenAPI コールバック定義。 |
| `deprecated` | `bool \| None` | `None` | `True` の場合、子ルーター内の全オペレーションを非推奨にします。 |
| `include_in_schema` | `bool` | `True` | `False` の場合、子ルーター内の全オペレーションを OpenAPI スキーマから除外します。 |
| `generate_unique_id_function` | `Callable[[APIRoute], str]` | `Default(generate_unique_id)` | 子オペレーションに適用する `operationId` 生成関数。 |

### 使用例

```python
from fastapi import APIRouter, FastAPI

v1_router = APIRouter(prefix="/v1")
billing_router = APIRouter(prefix="/billing", tags=["billing"])


@billing_router.get("/balance")
def get_balance() -> dict[str, int]:
    return {"cents": 4500}


v1_router.include_router(billing_router)
app = FastAPI()
app.include_router(v1_router)
```

---

## `method` APIRouter.add_api_route()

`route_class_override` または `self.route_class` を用いて `APIRoute` インスタンスを命令的に生成し、`self.routes` へ追加します。すべての HTTP メソッドデコレータおよび `api_route()` が内部で呼び出す基盤メソッドです。

```python
router.add_api_route(
    path: str,
    endpoint: Callable[..., Any],
    *,
    response_model: Any = Default(None),
    status_code: int | None = None,
    tags: list[str | Enum] | None = None,
    dependencies: Sequence[Depends] | None = None,
    summary: str | None = None,
    description: str | None = None,
    response_description: str = "Successful Response",
    responses: dict[int | str, dict[str, Any]] | None = None,
    deprecated: bool | None = None,
    methods: set[str] | list[str] | None = None,
    operation_id: str | None = None,
    response_model_include: IncEx | None = None,
    response_model_exclude: IncEx | None = None,
    response_model_by_alias: bool = True,
    response_model_exclude_unset: bool = False,
    response_model_exclude_defaults: bool = False,
    response_model_exclude_none: bool = False,
    include_in_schema: bool = True,
    response_class: type[Response] | DefaultPlaceholder = Default(JSONResponse),
    name: str | None = None,
    route_class_override: type[APIRoute] | None = None,
    callbacks: list[BaseRoute] | None = None,
    openapi_extra: dict[str, Any] | None = None,
    generate_unique_id_function: Callable[[APIRoute], str] | DefaultPlaceholder = Default(generate_unique_id),
    strict_content_type: bool | DefaultPlaceholder = Default(True),
) -> None
```

### 固有の引数

| 引数 | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `endpoint` | `Callable[..., Any]` | *(必須)* | 同期関数、コルーチン関数、ジェネレータ、または非同期ジェネレータのエンドポイント。 |
| `methods` | `set[str] \| list[str] \| None` | `None` | 受け付ける HTTP メソッド集合（`None` の場合は `{"GET"}`）。 |
| `route_class_override` | `type[APIRoute] \| None` | `None` | `self.route_class` を上書きしてこのルート専用に適用する `APIRoute` サブクラス。 |
| `strict_content_type` | `bool \| DefaultPlaceholder` | `Default(True)` | ルート単位での厳格な JSON `Content-Type` チェック設定オーバーライド。 |

### 使用例

```python
from fastapi import APIRouter


def check_liveness() -> dict[str, bool]:
    return {"live": True}


router = APIRouter()
router.add_api_route("/livez", check_liveness, methods=["GET"], tags=["ops"])
```

---

## `method` APIRouter.api_route()

単一のエンドポイント関数をルーター上で複数の HTTP メソッドに一括バインドするための `APIRouter.add_api_route()` デコレータラッパーです。

```python
router.api_route(
    path: str,
    *,
    response_model: Any = Default(None),
    status_code: int | None = None,
    tags: list[str | Enum] | None = None,
    dependencies: Sequence[Depends] | None = None,
    summary: str | None = None,
    description: str | None = None,
    response_description: str = "Successful Response",
    responses: dict[int | str, dict[str, Any]] | None = None,
    deprecated: bool | None = None,
    methods: list[str] | None = None,
    operation_id: str | None = None,
    response_model_include: IncEx | None = None,
    response_model_exclude: IncEx | None = None,
    response_model_by_alias: bool = True,
    response_model_exclude_unset: bool = False,
    response_model_exclude_defaults: bool = False,
    response_model_exclude_none: bool = False,
    include_in_schema: bool = True,
    response_class: type[Response] = Default(JSONResponse),
    name: str | None = None,
    callbacks: list[BaseRoute] | None = None,
    openapi_extra: dict[str, Any] | None = None,
    generate_unique_id_function: Callable[[APIRoute], str] = Default(generate_unique_id),
) -> Callable[[DecoratedCallable], DecoratedCallable]
```

### 主な引数

| 引数 | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `path` | `str` | *(必須)* | `router.prefix` からの相対ルートパス。 |
| `methods` | `list[str] \| None` | `None` | デコレートした関数で処理する HTTP メソッドのリスト（`["GET", "POST"]` 等）。 |

### 使用例

```python
from fastapi import APIRouter, Request

router = APIRouter()


@router.api_route("/webhook", methods=["POST", "PUT"])
async def receive_webhook(request: Request) -> dict[str, str]:
    return {"verb": request.method}
```

---

## `method` APIRouter.websocket()

`router.prefix` と `router.dependencies` を継承した `APIWebSocketRoute` をルーターへ登録するデコレータです。命令的登録メソッドとして `router.add_api_websocket_route(path, endpoint, name=None, *, dependencies=None)` も備えています。

```python
router.websocket(
    path: str,
    name: str | None = None,
    *,
    dependencies: Sequence[Depends] | None = None,
) -> Callable[[DecoratedCallable], DecoratedCallable]
```

### 引数

| 引数 | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `path` | `str` | *(必須)* | `router.prefix` の後ろへ連結される WebSocket パス。 |
| `name` | `str \| None` | `None` | 内部ルート検索用の識別名。 |
| `dependencies` | `Sequence[Depends] \| None` | `None` | `router.dependencies` と合算されるルート固有の `Depends()` / `Security()` リスト。 |

### 使用例

```python
from fastapi import APIRouter, WebSocket

ws_router = APIRouter(prefix="/realtime")


@ws_router.websocket("/events")
async def stream_events(websocket: WebSocket) -> None:
    await websocket.accept()
    await websocket.send_json({"type": "connected"})
    await websocket.close()
```

---

## `method` APIRouter.frontend()

静的フロントエンドのビルドディレクトリを、ルーターの `prefix` および `dependencies` を継承する低優先度フォールバックルートとして `APIRouter` に登録します。

```python
router.frontend(
    path: str,
    *,
    directory: str | os.PathLike[str],
    fallback: Literal["auto", "index.html", "404.html"] | None = "auto",
    check_dir: bool | Literal["auto"] = "auto",
) -> None
```

### 引数

| 引数 | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `path` | `str` | *(必須)* | `router.prefix` 配下で静的フロントエンドを配信するサブパス。 |
| `directory` | `str \| os.PathLike[str]` | *(必須)* | ビルド済みの HTML / JS / CSS アセットが配置されたディレクトリ。 |
| `fallback` | `Literal["auto", "index.html", "404.html"] \| None` | `"auto"` | 未一致ルートに対する SPA フォールバック動作（`"auto"`、`"index.html"`、`"404.html"`、`None`）。 |
| `check_dir` | `bool \| Literal["auto"]` | `"auto"` | `FASTAPI_ENV="development"` 以外の環境で登録時にディレクトリ存在チェックを行うかどうか。 |

### 使用例

```python
from pathlib import Path
import tempfile
from fastapi import APIRouter, FastAPI

ui_router = APIRouter(prefix="/portal")

with tempfile.TemporaryDirectory() as build_dir:
    (Path(build_dir) / "index.html").write_text("<h1>Portal</h1>", encoding="utf-8")
    ui_router.frontend("/", directory=build_dir, fallback="index.html")

app = FastAPI()
app.include_router(ui_router)
```

---

## `class` APIRoute

FastAPI の HTTP ルート表現クラス（`from fastapi.routing import APIRoute`）であり、`starlette.routing.Route` を継承します。登録時にエンドポイントの型アノテーションを解析し、`Dependant` 依存グラフ、Pydantic リクエスト用 `body_field` / レスポンス用 `response_field` アダプタ、JSONL・SSE ジェネレータ配信フラグ、および OpenAPI `unique_id` を構築します。

```python
from fastapi.routing import APIRoute

class APIRoute(routing.Route):
    def __init__(
        self,
        path: str,
        endpoint: Callable[..., Any],
        *,
        response_model: Any = Default(None),
        status_code: int | None = None,
        tags: list[str | Enum] | None = None,
        dependencies: Sequence[Depends] | None = None,
        summary: str | None = None,
        description: str | None = None,
        response_description: str = "Successful Response",
        responses: dict[int | str, dict[str, Any]] | None = None,
        deprecated: bool | None = None,
        name: str | None = None,
        methods: set[str] | list[str] | None = None,
        operation_id: str | None = None,
        response_model_include: IncEx | None = None,
        response_model_exclude: IncEx | None = None,
        response_model_by_alias: bool = True,
        response_model_exclude_unset: bool = False,
        response_model_exclude_defaults: bool = False,
        response_model_exclude_none: bool = False,
        include_in_schema: bool = True,
        response_class: type[Response] | DefaultPlaceholder = Default(JSONResponse),
        dependency_overrides_provider: Any | None = None,
        callbacks: list[BaseRoute] | None = None,
        openapi_extra: dict[str, Any] | None = None,
        generate_unique_id_function: Callable[[APIRoute], str] | DefaultPlaceholder = Default(generate_unique_id),
        strict_content_type: bool | DefaultPlaceholder = Default(True),
    ) -> None: ...
```

### 主なイントロスペクション属性

| 属性 | 型 | 説明 |
| :--- | :--- | :--- |
| `path` / `path_format` | `str` | 生のパス文字列および正規化済み URL パステンプレート（例: `"/items/{item_id}"`）。 |
| `methods` | `set[str]` | このルートが受け付ける大文字 HTTP メソッド集合（例: `{"GET"}`）。 |
| `unique_id` | `str` | 解決済み OpenAPI `operationId`（`operation_id` または `generate_unique_id_function(self)` の結果）。 |
| `dependant` | `Dependant` | パス・クエリ・ヘッダ・Cookie・ボディ・サブ依存関係を保持する解析済み依存ツリー。 |
| `body_field` / `response_field` | `ModelField \| None` | リクエストおよびレスポンス検証・シリアライズ用のコンパイル済み Pydantic v2 フィールドアダプタ。 |
| `is_sse_stream` / `is_json_stream` | `bool` | ジェネレータエンドポイントで `EventSourceResponse`（SSE）または既定の JSONL ストリーミングが有効な場合に `True`。 |

### 使用例

```python
from fastapi import FastAPI
from fastapi.routing import APIRoute

app = FastAPI()


@app.get("/users/{user_id}", tags=["users"])
def get_user(user_id: int) -> dict[str, int]:
    return {"user_id": user_id}


api_routes = [r for r in app.routes if isinstance(r, APIRoute)]
assert api_routes[0].path_format == "/users/{user_id}"
assert api_routes[0].methods == {"GET"}
```

---

## `method` APIRoute.get_route_handler()

リクエストボディの読み取り、依存性注入の解決、エンドポイント関数の実行、レスポンスシリアライズを担う非同期ハンドラ `Callable[[Request], Coroutine[Any, Any, Response]]` を返します。`APIRoute` を継承して `get_route_handler()` をオーバーライドすることで、ルート単位での計測・リクエストボディ展開・構造化エラーロギングを実装できます。

```python
route.get_route_handler() -> Callable[[Request], Coroutine[Any, Any, Response]]
```

### 動作仕様

| 項目 | 内容 |
| :--- | :--- |
| 戻り値型 | `Callable[[Request], Coroutine[Any, Any, Response]]` |
| カスタマイズ方法 | 作成した `APIRoute` サブクラスを `APIRouter(route_class=CustomRoute)` または `add_api_route(..., route_class_override=CustomRoute)` に指定します。 |

### 使用例

```python
from collections.abc import Callable, Coroutine
import time
from typing import Any
from fastapi import APIRouter, FastAPI, Request, Response
from fastapi.routing import APIRoute


class TimedRoute(APIRoute):
    def get_route_handler(self) -> Callable[[Request], Coroutine[Any, Any, Response]]:
        original_handler = super().get_route_handler()

        async def custom_handler(request: Request) -> Response:
            start = time.perf_counter()
            response = await original_handler(request)
            response.headers["X-Route-Duration"] = f"{time.perf_counter() - start:.5f}"
            return response

        return custom_handler


router = APIRouter(route_class=TimedRoute)


@router.get("/timed")
async def timed_endpoint() -> dict[str, str]:
    return {"timed": "yes"}


app = FastAPI()
app.include_router(router)
```

---

## `class` APIWebSocketRoute

WebSocket ルートクラス（`from fastapi.routing import APIWebSocketRoute`）であり、`starlette.routing.WebSocketRoute` を継承します。パスパラメータをコンパイルして FastAPI の `Dependant` ツリーを構築し、WebSocket エンドポイントでも型検証済みパラメータ、`Depends()` / `Security()` 依存性注入、および `WebSocketRequestValidationError` ハンドリングを利用可能にします。

```python
from fastapi.routing import APIWebSocketRoute

class APIWebSocketRoute(routing.WebSocketRoute):
    def __init__(
        self,
        path: str,
        endpoint: Callable[..., Any],
        *,
        name: str | None = None,
        dependencies: Sequence[Depends] | None = None,
        dependency_overrides_provider: Any | None = None,
    ) -> None: ...
```

### 引数

| 引数 | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `path` | `str` | *(必須)* | WebSocket の URL パステンプレート。 |
| `endpoint` | `Callable[..., Any]` | *(必須)* | `WebSocket` および宣言したパラメータ・依存関係を受け取る非同期コルーチン関数。 |
| `name` | `str \| None` | `None` | ルート識別名（省略時は `get_name(endpoint)`）。 |
| `dependencies` | `Sequence[Depends] \| None` | `None` | セッション開始時に実行される引数なしの `Depends()` / `Security()` リスト。 |
| `dependency_overrides_provider` | `Any \| None` | `None` | `dependency_overrides` を提供する親 `FastAPI` インスタンスへの参照。 |

### 使用例

```python
from fastapi import FastAPI, WebSocket
from fastapi.routing import APIWebSocketRoute


async def ticker_ws(websocket: WebSocket) -> None:
    await websocket.accept()
    await websocket.send_text("BTC:100000")
    await websocket.close()


ws_route = APIWebSocketRoute("/ws/ticker", ticker_ws, name="ticker")
app = FastAPI()
app.router.routes.append(ws_route)
```

---

## `class` Mount

`starlette.routing.Mount` を `fastapi.routing.Mount` として再エクスポートしたサブアプリ・サブルートマウントクラスです。URL プレフィックス（`path`）に一致したリクエストの ASGI `root_path` を更新し、残りのパスを子 `ASGIApp` または `BaseRoute` シーケンスへ委譲します（マウント単位の `middleware` や `max_body_size` も指定可能）。

```python
from fastapi.routing import Mount

class Mount(BaseRoute):
    def __init__(
        self,
        path: str,
        app: ASGIApp | None = None,
        routes: Sequence[BaseRoute] | None = None,
        name: str | None = None,
        *,
        middleware: Sequence[Middleware] | None = None,
        max_body_size: int | None = None,
    ) -> None: ...
```

### 引数

| 引数 | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `path` | `str` | *(必須)* | URL プレフィックス（`""` または `"/"` 始まり。末尾スラッシュは自動で正規化されます）。 |
| `app` | `ASGIApp \| None` | `None` | 委譲先の ASGI 3.0 アプリケーション（`app` または `routes` のいずれかが必須）。 |
| `routes` | `Sequence[BaseRoute] \| None` | `None` | `app` が `None` の場合に Starlette `Router` でラップされるルート一覧。 |
| `name` | `str \| None` | `None` | `url_path_for("<mount_name>:<route_name>")` 形式の逆引きを可能にするマウント名。 |
| `middleware` | `Sequence[Middleware] \| None` | `None` | この `Mount` 配下のリクエストにのみ適用されるミドルウェアリスト。 |
| `max_body_size` | `int \| None` | `None` | Starlette の `RequestBodyLimitMiddleware` により適用される最大リクエストボディバイト数。 |

### 使用例

```python
from fastapi import FastAPI
from fastapi.responses import PlainTextResponse
from fastapi.routing import Mount
from starlette.routing import Route


def legacy_status(request: object) -> PlainTextResponse:
    return PlainTextResponse("OK")


app = FastAPI()
app.router.routes.append(
    Mount("/legacy", routes=[Route("/status", legacy_status)], name="legacy")
)
```
