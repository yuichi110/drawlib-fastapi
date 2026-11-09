# 遅延 `get_openapi()`・JSON Schema `$defs` 集約・Docs UI 生成

FastAPI は OpenAPI `3.1.0`（JSON Schema Draft `2020-12` 準拠）を手書きの YAML 資産ではなく、ルーティングと型注釈から自動導出される第一級のコンパイルターゲットとして扱います。Python モジュールのインポート時に JSON Schema 生成コストを支払うのではなく、`FastAPI.openapi()` が初回アクセス時にスキーマ全体を遅延合成してメモ化し、ルートや組み込み済み `APIRouter` ツリーに変更が加わった際にのみキャッシュを自動的に無効化します。

```drawlib align=center code=hide file=lazy_openapi_synthesis_pipeline.png caption="FastAPI.openapi() のバージョン連動キャッシュと5段階の get_openapi() 合成パイプライン"
from drawlib.canvas import setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, ChevronProcess, Panel
from drawlib.styles import Colors, Styles

setup(width=180, height=88)

pipeline = ChevronProcess(
    style=Styles.Neutral,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    corner_angle=60.0,
    spacing=1.6,
    flat_left_end=True,
)
pipeline.add("1. Version Gate", description="_get_routes_version")
pipeline.add(
    "2. Harvest Fields",
    description="get_fields_from_routes",
    style=Styles.SecondaryNeutral,
)
pipeline.add(
    "3. Bundle $defs",
    description="GenerateJsonSchema",
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
)
pipeline.add(
    "4. Build Paths",
    description="routes & webhooks",
    style=Styles.PrimaryNeutral,
)
pipeline.add("5. Validate & Cache", description="OpenAPI(**output)")
pipeline.draw(xy=(4.0, 70.0), width=172.0, height=14.0)

cache_panel = Panel(
    "Lazy Cache & Invalidation",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.5),
    icon=phosphor.arrows_clockwise,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.5,
)
cache_panel.draw((4.0, 4.0), width=84.0, height=62.0)
c_xy, c_w, c_h = cache_panel.get_content_box(
    (4.0, 4.0), width=84.0, height=62.0, padding=(3.5, 3.0)
)

cache_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.DarkBold,
    spacing=2.2,
)
cache_cards.add(
    "Zero Import-Time Cost",
    "openapi_schema starts as None at __init__",
    badge_text="Cold",
    icon=phosphor.snowflake,
)
cache_cards.add(
    "Recursive Version Sum",
    "_get_routes_version walks _IncludedRouter",
    badge_text="Ver",
    icon=phosphor.git_merge,
)
cache_cards.add(
    "O(1) Dict Reuse",
    "Returns cached dict until routes mutate",
    badge_text="Hit",
    icon=phosphor.lightning,
)
cache_cards.draw(c_xy, width=c_w, height=c_h)

harvest_panel = Panel(
    "Field & Route Harvesting",
    style=Styles.PrimaryNeutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.5),
    icon=phosphor.magnifying_glass,
    icon_style=Styles.White,
    header_variant="filled",
    header_height=8.5,
)
harvest_panel.draw((92.0, 4.0), width=84.0, height=62.0)
h_xy, h_w, h_h = harvest_panel.get_content_box(
    (92.0, 4.0), width=84.0, height=62.0, padding=(3.5, 3.0)
)

harvest_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    spacing=2.2,
)
harvest_cards.add(
    "Validation ModelFields",
    "body_field + Dependant path/query/header",
    badge_text="In",
    icon=phosphor.sign_in,
)
harvest_cards.add(
    "Serialization ModelFields",
    "response_field + stream_item_field",
    badge_text="Out",
    icon=phosphor.sign_out,
)
harvest_cards.add(
    "Callbacks & Webhooks",
    "Unified into shared components.schemas",
    badge_text="Hook",
    icon=phosphor.webhooks_logo,
)
harvest_cards.draw(h_xy, width=h_w, height=h_h)
```

---

## 1. 遅延メモ化と `_openapi_routes_version` によるキャッシュ無効化

`fastapi/applications.py` の `FastAPI.__init__()` は、`self.openapi_version = "3.1.0"`、`self.openapi_schema = None`、`self._openapi_routes_version = None` を初期設定します。ルータやエンドポイントを登録している最中には、JSON Schema 生成処理は一切走りません。

ユーザーコード・テストコード、あるいは `GET /openapi.json` リクエストから `app.openapi()` が呼ばれると、`self.openapi_schema` を返す前に 2 つの不変条件が検査されます。

1. **コールドキャッシュ判定（`not self.openapi_schema`）**: 初回呼び出し時に OpenAPI 辞書全体を合成し、`self.openapi_schema` に保存します。
2. **再帰的ルート変更バージョン判定（`self._openapi_routes_version != routes_version`）**: `fastapi/routing.py` の `self.router._get_routes_version()` を呼び出します。各 `APIRouter` は単調増加カウンタ `self._routes_version` を保持しており、`add_route()`・`add_api_route()`・`add_websocket_route()`・`include_router()`・`frontend()` の実行時に `_mark_routes_changed()` でインクリメントします。重要な点として、`_get_routes_version(seen)` は入れ子の `_IncludedRouter` を再帰的にたどって `_routes_version` を合算（`seen: set[int]` で循環参照も防止）するため、`app.include_router()` 済みの子ルータへ後から動的にルートを追加した場合でも、ルート `FastAPI` の OpenAPI キャッシュは自動的に再合成されます。

---

## 2. `get_openapi()` の内部構造：フィールド収集・`FieldMap`・`$defs` 重複排除

`fastapi/openapi/utils.py` の `get_openapi()` は、`fastapi/_compat/v2.py` および `fastapi/openapi/constants.py` と連携し、5 つの確定的なパスでスキーマを組み立てます。

1. **全 `ModelField` の収集（`get_fields_from_routes()`）**: `routing.iter_route_contexts(list(routes) + list(webhooks or []))` を走査し、`include_in_schema=True` のすべての `APIRoute` から入力側フィールド（`body_field` と `get_flat_params(api_route.dependant)`、いずれも `mode="validation"`）、出力側フィールド（`response_field`、追加ステータスの `response_fields.values()`、JSONL/SSE 配信用の `stream_item_field`、いずれも `mode="serialization"`）、さらに `api_route.callbacks` のフィールドを再帰的に収集します。
2. **入れ子モデルの平坦化（`get_flat_models_from_fields()` と `get_model_name_map()`）**: ジェネリック型・Union・`BaseModel` フィールド・`Enum` サブクラスを再帰的に探索して `TypeModelSet` を構築し、`re.sub(r"[^a-zA-Z0-9.\-_]", "_", name)` でスキーマ名を正規化します。
3. **単一パスでの `$defs` 一括生成（`get_definitions()` と `GenerateJsonSchema`）**: `fastapi/_compat/v2.py` の `get_definitions()` は、`REF_TEMPLATE = "#/components/schemas/{model}"` を指定した FastAPI 独自の `GenerateJsonSchema` サブクラス（`bytes_schema()` で `contentMediaType: "application/octet-stream"` を出力）を生成します。`ModelField.__hash__` が `id(self)` を返すため、各 `(ModelField, mode)` ペアは一意の辞書キーとして機能します。全フィールドと入れ子モデルを `schema_generator.generate_definitions(inputs=inputs)` に一括投入することで、1 回の Pydantic パスで次の 2 構造を得ます。
   - **`field_mapping`（`FieldMap`）**: 各 `(ModelField, "validation" | "serialization")` タプルをインライン JSON Schema または `{"$ref": "#/components/schemas/..."}` 参照へ対応付けるマップ。
   - **`definitions`**: 重複排除済みのグローバルコンポーネントスキーマ辞書（モデル docstring 内のフォームフィード `\f` 以降は `description.split("\f")[0]` で切り詰められます）。
4. **オペレーション・Callback・Webhook・ストリーミング合成（`get_openapi_path()`）**:
   - **依存関係 DAG とセキュリティ定義**: `_get_openapi_dependency_data(route.dependant)` がルートごとに `Dependant` グラフを 1 度だけ走査（`_get_cache_key` で重複訪問を排除）し、`_get_openapi_security_definitions()` が同一 `scheme_name` の OAuth2 スコープをマージして `components["securitySchemes"]` とオペレーション単位の `security` 配列を構築します。
   - **パラメータ・リクエストボディ・`422` エラースキーマ**: `_get_openapi_operation_parameters()` は同一 `(in, name)` で必須指定（`required=True`）が任意指定より優先されるよう統合します。`METHODS_WITH_BODY`（`GET`, `HEAD`, `POST`, `PUT`, `DELETE`, `PATCH`）では `requestBody` を生成し、パラメータまたはボディを持つすべてのオペレーションに `#/components/schemas/HTTPValidationError` および `ValidationError` を参照する `422` レスポンスを自動付与します。
   - **ストリーミング・Callbacks・Webhooks**: ジェネレータルートのうち `is_json_stream` は `application/jsonl` の `itemSchema` を、`is_sse_stream` は `text/event-stream` の `_SSE_EVENT_SCHEMA`（`contentMediaType: "application/json"`, `contentSchema`）を出力します。ルート単位の `callbacks` は `get_openapi_path()` を再帰呼び出しし、`app.webhooks.routes` は OpenAPI 3.1 トップレベルの `output["webhooks"]` を形成します。
5. **Pydantic モデルによる自己検証（`OpenAPI(**output)`）**: `components["schemas"]` を辞書順ソートした後、`fastapi.openapi.models.OpenAPI`（`Schema`・`PathItem`・`Operation`・`Components`）で構造検証を行い、`jsonable_encoder(..., by_alias=True, exclude_none=True)` で最終辞書へ直列化します。

---

## 3. `separate_input_output_schemas` と対話型 Docs UI（`docs.py`）

```drawlib align=center code=hide file=defs_bundling_and_docs_ui.png caption="条件付きの Model-Input / Model-Output スキーマ分割と setup() による自動 Docs UI ルート群"
from drawlib.canvas import setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, Panel, Table
from drawlib.styles import Colors, Styles

setup(width=184, height=78)

split_panel = Panel(
    "Input/Output $defs Split",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.5),
    icon=phosphor.git_fork,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.5,
)
split_panel.draw((4.0, 4.0), width=98.0, height=70.0)
l_xy, l_w, l_h = split_panel.get_content_box(
    (4.0, 4.0), width=98.0, height=70.0, padding=(3.5, 3.5)
)

schema_table = Table(
    cell_style=Styles.White,
    text_style=Styles.Dark.patch(text_size=10.0),
    header_cell_style=Styles.PrimaryFlat,
    header_text_style=Styles.WhiteBold.patch(text_size=10.0),
    border_style=Styles.MutedThin,
)
schema_table.draw(
    xy=(l_xy[0], l_xy[1] + l_h),
    width=l_w,
    height=l_h,
    data=[
        ["Model Trait", "Input vs Output", "Schema Key"],
        ["Plain fields", "Identical JSON Schema", "Tag (unified)"],
        ["Decimal field", "number | str vs str", "Item-Input / -Output"],
        ["Field(exclude)", "In props vs omitted", "Item-Input / -Output"],
        ["@computed_field", "Omitted vs in props", "Item-Input / -Output"],
        ["Params / Body", "Auto 422 error schema", "HTTPValidationError"],
    ],
)

docs_panel = Panel(
    "Docs UI Routes (setup())",
    style=Styles.PrimaryNeutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.5),
    icon=phosphor.browsers,
    icon_style=Styles.White,
    header_variant="filled",
    header_height=8.5,
)
docs_panel.draw((106.0, 4.0), width=74.0, height=70.0)
r_xy, r_w, r_h = docs_panel.get_content_box(
    (106.0, 4.0), width=74.0, height=70.0, padding=(3.5, 2.8)
)

docs_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    spacing=1.8,
)
docs_cards.add(
    "/openapi.json",
    "Prepends root_path to servers[]",
    badge_text="JSON",
    icon=phosphor.file_code,
)
docs_cards.add(
    "/docs (Swagger UI)",
    "get_swagger_ui_html + _html_safe_json",
    badge_text="UI",
    icon=phosphor.code_block,
)
docs_cards.add(
    "/docs/oauth2-redirect",
    "Popup token callback relay HTML",
    badge_text="Auth",
    icon=phosphor.key,
)
docs_cards.add(
    "/redoc (ReDoc UI)",
    "get_redoc_html standalone bundle",
    badge_text="Doc",
    icon=phosphor.book_open,
)
docs_cards.draw(r_xy, width=r_w, height=r_h)
```

### `Model-Input` と `Model-Output` が分割される条件・統合される条件

`separate_input_output_schemas=True`（デフォルト）のとき、`get_definitions()` はリクエスト側 `ModelField` を `mode="validation"`、レスポンス側 `ModelField` を `mode="serialization"` として `GenerateJsonSchema` に渡します。ここで重要なのは、**両モードの JSON Schema が実際に異なるときにだけ `-Input` と `-Output` に分割される** という点です。

- **単一スキーマへの統合（`#/components/schemas/Tag`）**: すべてのフィールドで入力検証時と出力直列化時の JSON Schema が一致する場合、`GenerateJsonSchema` は両モードを単一の `"Tag"` コンポーネントに統合し、単純な DTO モデルでの不要なスキーマ倍増を防ぎます。
- **入出力スキーマの分割（`#/components/schemas/Item-Input` と `Item-Output`）**: たとえば `Decimal`（入力は `number | string` を許容、出力は `string` に直列化）、`Field(exclude=True)`（入力では受け付け、出力からは除外）、戻り値型を変える `@field_serializer`、`@computed_field`（出力のみに存在）、あるいは `ConfigDict(json_schema_serialization_defaults_required=True)` などにより入出力表現が乖離すると、Pydantic は `Item-Input` と `Item-Output` を個別に生成し、自動生成されるクライアント SDK に厳密な型定義を提供します。
- **`_has_computed_fields()` による保護**: 仮に `FastAPI(separate_input_output_schemas=False)` を指定した場合でも、`fastapi/_compat/v2.py` の `_has_computed_fields(field)` が `field._type_adapter.core_schema` 内の `computed_fields` を検出し、該当モデルには引き続き `mode="serialization"` を適用するため、レスポンススキーマから `@computed_field` が欠落することはありません。

### 自動 Docs UI ジェネレータ（`FastAPI.setup()` と `fastapi/openapi/docs.py`）

`FastAPI.__init__()` の末尾で呼ばれる `self.setup()` は、`self.openapi_url` が有効な場合に最大 4 つの非公開ドキュメントルート（`include_in_schema=False`）を登録します（`openapi_url=None` に設定すると 4 ルートすべてが無効化されます）。

1. **`GET {openapi_url}`（`/openapi.json`）**: `self.openapi()` を呼び出します。リバースプロキシや `Mount` 配下で `req.scope.get("root_path")` が空でなく、かつ `self.root_path_in_servers=True` の場合は、キャッシュ辞書を浅くコピーして `schema["servers"]` の先頭に `{"url": root_path}` を動的に追加します。
2. **`GET {docs_url}`（`/docs` — `get_swagger_ui_html()`）**: `swagger_ui_default_parameters` に `self.swagger_ui_parameters` をマージし、`SwaggerUIBundle`（`swagger-ui-dist@5`）を起動する `HTMLResponse` を返します。埋め込まれる設定キー・パラメータ値・`init_oauth` JSON はすべて `_html_safe_json()` を通過し、`<`・`>`・`&` が `\u003c`・`\u003e`・`\u0026` へエスケープされるため、インライン `<script>` タグからの XSS 脱出が防止されます。
3. **`GET {swagger_ui_oauth2_redirect_url}`（`/docs/oauth2-redirect` — `get_swagger_ui_oauth2_redirect_html()`）**: OAuth2 ポップアップ認証後に `qp.state === sentState` を検証し、認可コードやトークンを親ウィンドウの `window.opener.swaggerUIRedirectOauth2` へ中継する HTML を返します。
4. **`GET {redoc_url}`（`/redoc` — `get_redoc_html()`）**: `redoc@2` スタンドアロンバンドルと任意の Google Fonts（`Montserrat` / `Roboto`）を読み込み、`<redoc spec-url="{openapi_url}"></redoc>` を描画します。

---

## 4. 遅延キャッシュ・ルータ変更検知・入出力スキーマ分割の検証

以下のスニペットは、初回呼び出しまでの遅延メモ化、組み込み済み `APIRouter` への動的ルート追加による自動キャッシュ再構築、および `Item-Input` / `Item-Output` の選択的分割と `Tag` の単一統合を検証します。

```python
from decimal import Decimal

from fastapi import APIRouter, FastAPI
from pydantic import BaseModel, Field


class Tag(BaseModel):
    label: str


class Item(BaseModel):
    name: str
    price: Decimal
    secret_token: str = Field(default="", exclude=True)
    tags: list[Tag] = []


app = FastAPI(title="Inventory API", version="1.0.0")
sub_router = APIRouter(prefix="/v1")


@sub_router.post("/items", response_model=Item)
async def create_item(item: Item) -> Item:
    return item


app.include_router(sub_router)

# 1. 遅延合成: 初回 app.openapi() 呼び出しまで openapi_schema は None
assert app.openapi_schema is None
schema_v1 = app.openapi()
assert app.openapi_schema is schema_v1
assert app.openapi() is schema_v1

# 2. 入出力が乖離する Item は Input/Output に分割され、同一構造の Tag は単一統合
schemas = schema_v1["components"]["schemas"]
assert {"Item-Input", "Item-Output", "Tag"} <= set(schemas)
assert "Tag-Input" not in schemas
assert "secret_token" in schemas["Item-Input"]["properties"]
assert "secret_token" not in schemas["Item-Output"]["properties"]
assert "anyOf" in schemas["Item-Input"]["properties"]["price"]
assert schemas["Item-Output"]["properties"]["price"]["type"] == "string"


# 3. 組み込み済み APIRouter へのルート追加で _get_routes_version() が更新され再合成
@sub_router.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


schema_v2 = app.openapi()
assert schema_v2 is not schema_v1
assert "/v1/health" in schema_v2["paths"]
```

各リクエスト実行時に `ModelField` と `TypeAdapter` がどのようにランタイム検証および Rust ベースの高速 JSON 直列化を行うかについては、[_compat/v2.py・ModelField・直列化](../04_pydantic_bridge/compat_and_serialization.md)を参照してください。
