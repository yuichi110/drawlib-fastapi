# APIRouter・APIRoute とハンドラクロージャ合成

FastAPI のルーティングエンジン（`fastapi/routing.py`）は、Starlette の `Router` および `Route` プリミティブ上に構築された**事前コンパイル型クロージャ合成器（Ahead-of-Time Closure Compiler）**として動作します。HTTP リクエストのたびに Python の型アノテーションをリフレクションしたり Pydantic バリデータを再構築したりするのではなく、`APIRouter` と `APIRoute` はルート登録時（または遅延ルータ統合時）に一度だけエンドポイントのシグネチャを解析し、専用の `Dependant` グラフと `ModelField` アダプタを合成したうえで、それらを `async def app(request: Request) -> Response` クロージャ内に束縛し、FastAPI 独自の二重スタック型 `request_response()` ASGI アダプタでラップします。

```drawlib align=center code=hide file=apiroute_closure_compiler.png caption="APIRoute の事前状態合成から get_request_handler() クロージャ・ASGI アダプタ生成までの全体パイプライン"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.lines import line
from drawlib.smartarts import CardList, ChevronProcess, Panel
from drawlib.styles import Colors, Styles
from drawlib.text import text

setup(width=160, height=94)

# Top pipeline stages: Compile-time registration to ASGI adapter
stages = ChevronProcess(
    style=Styles.Neutral,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    corner_angle=60.0,
    spacing=1.8,
    flat_left_end=True,
)
stages.add("1. @router.post()", description="add_api_route()")
stages.add(
    "2. Compile Route State",
    description="_populate_api_route_state()",
    style=Styles.PrimaryNeutral,
)
stages.add(
    "3. get_route_handler()",
    description="get_request_handler()",
    style=Styles.SecondaryNeutral,
)
stages.add(
    "4. request_response()",
    description="ASGI self.app",
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
)
stages.draw(xy=(6.0, 74.0), width=148.0, height=14.0)

# Left Panel: Compile-Time Frozen Artifacts on APIRoute / _EffectiveRouteContext
left_panel = Panel(
    "Compile-Time Route State",
    "",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.5),
    icon=phosphor.gear,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.5,
)
left_panel.draw((6.0, 6.0), width=68.0, height=62.0)
l_xy, l_w, l_h = left_panel.get_content_box(
    (6.0, 6.0), width=68.0, height=62.0, padding=(3.5, 3.0)
)

compile_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    spacing=2.2,
)
compile_cards.add(
    "dependant: Dependant",
    "Signature + router Depends DAG",
    icon=phosphor.git_branch,
)
compile_cards.add(
    "body_field: ModelField",
    "Body_<unique_id> or Form model",
    icon=phosphor.package,
)
compile_cards.add(
    "response_field: ModelField",
    "TypeAdapter(mode='serialization')",
    icon=phosphor.check_circle,
)
compile_cards.add(
    "_EffectiveRouteContext",
    "ContextVar hook for included routes",
    icon=phosphor.stack,
)
compile_cards.draw(l_xy, width=l_w, height=l_h)

# Center Closure Capture Bridge
line((75.5, 37.0), (84.5, 37.0), arrow_head="->", style=Styles.PrimaryBold)
text((80.0, 41.0), "captures", style=Styles.PrimaryBold.patch(text_size=10.0))

# Right Panel: Per-Request Execution Inside ASGI Closure
right_panel = Panel(
    "Runtime Handler Closure",
    "",
    style=Styles.PrimaryNeutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.5),
    icon=phosphor.lightning,
    icon_style=Styles.WhiteBold,
    header_variant="filled",
    header_height=8.5,
)
right_panel.draw((86.0, 6.0), width=68.0, height=62.0)
r_xy, r_w, r_h = right_panel.get_content_box(
    (86.0, 6.0), width=68.0, height=62.0, padding=(3.5, 3.0)
)

runtime_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.SecondaryNeutral,
    icon_style=Styles.DarkBold,
    show_arrows=True,
    arrow_style=Styles.PrimaryBold,
    spacing=2.4,
)
runtime_cards.add(
    "Dual AsyncExitStack",
    "inner_astack + function_astack",
    icon=phosphor.brackets_curly,
)
runtime_cards.add(
    "Body & Strict MIME Gate",
    "form() / json() / CSRF guard",
    icon=phosphor.shield_check,
)
runtime_cards.add(
    "solve_dependencies()",
    "Resolve DAG & run endpoint",
    icon=phosphor.play,
)
runtime_cards.add(
    "serialize_response()",
    "Rust serialize_json() + bg tasks",
    icon=phosphor.export,
    badge_style=Styles.AccentFlat,
    icon_style=Styles.WhiteBold,
)
runtime_cards.draw(r_xy, width=r_w, height=r_h)

save()
```

## 1. コンパイル時のルート状態合成（`APIRoute.__init__` と `_populate_api_route_state`）

`APIRouter` が備えるすべての HTTP メソッドデコレータ（`@router.get()`、`@router.post()`、`@router.put()`、`@router.delete()`、`@router.patch()`、`@router.options()`、`@router.head()`、`@router.trace()`）は、`APIRouter.api_route()` を経由して `APIRouter.add_api_route()` に集約されます。`add_api_route()` はルータ自身が保持する `prefix`、`tags`、`dependencies`、`responses`、`callbacks`、`default_response_class`、`generate_unique_id_function`、`strict_content_type` をデコレータ引数と統合し、`route_class`（既定は `APIRoute`）をインスタンス化します。

`APIRoute.__init__` の内部では、直接登録された `APIRoute` と遅延生成される `_EffectiveRouteContext` が完全に同一のコンパイル処理を通るよう、状態構築ロジックが `_populate_api_route_state(route, path, endpoint, ...)` へ切り出されています。

| コンパイル済み属性 | 生成関数 | FastAPI `v0.162.2` における役割 |
| :--- | :--- | :--- |
| `path_regex`, `path_format`, `param_convertors` | `starlette.routing.compile_path(path)` | `{param:type}` セグメントを正規表現、OpenAPI 用パス形式、Starlette 型コンバータへ変換します。 |
| `unique_id` | `operation_id or generate_unique_id(route)` | `<name><path_format>_<method>` から決定論的に生成される識別子で、OpenAPI の `operationId` や合成モデル名の接尾辞に使われます。 |
| `dependant`, `_embed_body_fields` | `_build_dependant_with_parameterless_dependencies()` | `get_dependant(path=path_format, call=endpoint, scope="function")` を実行後、ルータ／デコレータの `Depends` を逆順でインデックス `0` に先頭挿入して外側から内側への宣言順を維持し、`body_params` と `_should_embed_body_fields()` を算出します。 |
| `body_field` | `_get_body_field()` | `_embed_body_fields=False` の単一ボディでは元の `ModelField` をそのまま返し、複数ボディ引数・`Body(embed=True)`・`Form`/`File` アップロード時は複合モデル `Body_<unique_id>`（`create_body_model`）を合成します。 |
| `response_field`, `response_fields` | `create_model_field(..., mode="serialization")` | `response_model`（未指定時は戻り値型アノテーション。ただし `Response` サブクラスを除く）から Pydantic v2 `TypeAdapter` の `"serialization"` モードを用いた `Response_<unique_id>` を生成し、`responses={...}` 用のステータス別フィールド群も構築します。 |
| `stream_item_field`, `is_sse_stream`, `is_json_stream` | `get_stream_item_type()` + `create_model_field()` | `yield` ジェネレータエンドポイントに対し、`AsyncIterable[T]` / `Iterable[T]` から要素型 `T`（`ServerSentEvent` を除く）を抽出して `StreamItem_<unique_id>`（`mode="serialization"`）を生成し、配信分岐フラグを設定します。 |
| `app` | `request_response(self.get_route_handler())` | コンパイル済みルートハンドラクロージャを FastAPI の ASGI `Scope`/`Receive`/`Send` アダプタへ凍結します。 |

> [!NOTE]
> **旧 `secure_cloned_response_field` の廃止理由**: Pydantic v1 時代の FastAPI では、レスポンスの余剰サブフィールドを安全に除去するため `response_field` とは別にクローンモデル `secure_cloned_response_field`（`create_cloned_field`）を保持していました。FastAPI `v0.162.2` は Pydantic v2 専用（`create_model_field()` 内で v1 モデルに対し `PydanticV1NotSupportedError` を送出）へ完全移行しており、`v2.ModelField(mode="serialization")` が単一の Rust 製 `TypeAdapter` でフィールドフィルタリング・エイリアス変換・検証を一括実行するため、モデル複製は不要となりました。

## 2. ランタイムハンドラクロージャ（`get_request_handler` と `request_response`）

### 2.1 `request_response()` における二重 `AsyncExitStack` と例外握り潰し検知

`APIRoute.__init__` の末尾では `self.app = request_response(self.get_route_handler())` が構築されます。FastAPI は `fastapi/routing.py` 内で Starlette の `request_response()` を独自にフォーク・拡張し、Starlette の `wrap_app_handling_exceptions(app, request)` へ例外処理を委譲する内側に、寿命の異なる 2 つの `AsyncExitStack` を `scope` 上に展開します。

1. **`scope["fastapi_inner_astack"]`（外側リクエストスタック）**: `response = await f(request)` **および** `await response(scope, receive, send)` の双方を包みます。デフォルトの `scope="request"` で動作する `yield` 依存関係（ストリーミング配信中に参照される DB セッションなど）は、ASGI `send` で全レスポンスチャンクの送信が完了するまでクローズされずに維持されます。
2. **`scope["fastapi_function_astack"]`（内側関数スタック）**: `response = await f(request)` のみを包みます。明示的に `Depends(..., scope="function")` が指定された `yield` 依存関係は、エンドポイントが `Response` オブジェクトを返した直後（ボディ配信が始まる前）に即座にクリーンアップされます。
3. **`response_awaited` 整合性ガード**: `await response(scope, receive, send)` の完了後にのみ `response_awaited = True` が記録されます。もし `yield` 依存関係が裸の `except:` や `except Exception:` で例外を捕捉したまま再送出しなかった場合、`request_stack.__aexit__` が例外を抑制してレスポンス未送信のまま抜けてしまうため、FastAPI は `FastAPIError("Response not awaited...")` を明示的に送出して無言の通信ハングを防ぎます。

### 2.2 ボディ解析・厳格 `Content-Type` による CSRF 防御・依存解決

`APIRoute.get_route_handler()` はコンパイル済み属性群を `get_request_handler()` に渡し、リクエストごとのホットパス外で 5 つの不変条件（`is_coroutine`、`is_body_form`、`actual_response_class`、`is_sse_stream`、`actual_strict_content_type`）を事前計算したうえで、`async def app(request: Request) -> Response` クロージャを返します。

- **Multipart／Form の自動クローズ（`fastapi_middleware_astack`）**: クロージャは `AsyncExitStackMiddleware` が注入した `file_stack = request.scope.get("fastapi_middleware_astack")` を取得します。`body_field` が存在し `is_body_form` が真（`File` は `Form` のサブクラスであるため `isinstance(body_field.field_info, params.Form)` でフォームとファイル双方を網羅）の場合、`body = await request.form()` を待機した直後に `file_stack.push_async_callback(body.close)` を登録し、後続のバリデーション成否に関わらず一時ファイルハンドルを確実に解放します。
- **JSON 解析と `strict_content_type` による CSRF 防御**: 非フォームの `body_field` ルートでは `body_bytes = await request.body()` を読み込みます。空でない場合、`email.message.Message` で `request.headers.get("content-type")` を解析します。
  - `Content-Type` が `application/json` または `application/*+json`（`application/problem+json` や `application/vnd.api+json` など）であれば `await request.json()` を実行します。
  - `Content-Type` ヘッダが**欠落**している場合、`actual_strict_content_type`（既定値 `True`）を参照します。`True` のときは生バイト列 `body_bytes` のまま保持し（後続の Pydantic 辞書／モデル検証で `422` 拒否）、ブラウザから `Content-Type` なしの単純リクエストを送って CORS プリフライトを回避する `localhost` 向け CSRF 攻撃を遮断します。`strict_content_type=False` を指定した場合のみ、ヘッダなしクライアントとの後方互換として JSON 解析を試みます。
  - 不正な JSON 文字列による `json.JSONDecodeError` は、`_extract_endpoint_context(dependant.call)` のキャッシュ済みソース位置情報とバイト位置 `loc=("body", e.pos)` を付与した `RequestValidationError`（`type="json_invalid"`）に変換され、`_validation_failed()` テレメトリフックが発火します。
- **依存関係グラフの解決**: `_operation(name="dependencies", function=dependant.call)` コンテキスト内で `solve_dependencies()` を呼び出し、パス・クエリ・ヘッダ・Cookie・解析済み `body` の検証とサブ依存関係の解決を `fastapi_inner_astack` 上で一括実行します。`solved_result.errors` が 1 件でもあればエンドポイント呼び出し前に `RequestValidationError` を送出します。

### 2.3 エンドポイント実行・Rust `serialize_json` 高速経路・`BackgroundTasks` 統合

`solved_result.errors` が空で、かつジェネレータ配信ではない通常のルートでは、`get_request_handler()` は以下のリクエスト／レスポンス分岐を実行します。

1. **`run_endpoint_function()`**: プロファイラで計測しやすいよう独立関数として定義されています。非同期 `async def` は `_operation(name="endpoint")` 内で直接 `await dependant.call(**values)` を実行し、同期 `def` はイベントループのブロッキングを防ぎつつ OpenTelemetry コンテキストを引き継ぐため `await run_in_threadpool(_run_sync_endpoint, function=dependant.call, arguments=values)` でスレッドプールへオフロードします。
2. **`Response` 直接返却のバイパス**: `isinstance(raw_response, Response)` が真の場合、`serialize_response()` を完全にスキップします。`raw_response.background is None` であれば依存関係経由で登録された `solved_result.background_tasks` を引き継ぎ、`raw_response` をそのまま返します。
3. **Pydantic Rust `dump_json` 高速経路とカスタム `response_class`**: 上記以外では `_build_response_args()` が `background_tasks` と `status_code`（依存関係やエンドポイント内で書き換えられた `solved_result.response.status_code` がデコレータ指定値より優先）を組み立て、直列化経路を選択します。
   - **`use_dump_json = response_field is not None and isinstance(response_class, DefaultPlaceholder)`**: 真の場合、`serialize_response(..., dump_json=True)` が `field.validate()`（同期エンドポイントでは `run_in_threadpool` で実行し、契約違反時は `ResponseValidationError` を送出）に続けて `field.serialize_json(...)` を呼び出します。`pydantic-core` の Rust エンジンが Python の中間 `dict` 生成と `json.dumps()` を完全に省略して UTF-8 JSON `bytes` を直接出力し、素の `Response(content=content, media_type="application/json", **response_args)` に格納します。
   - **通常直列化経路（`use_dump_json=False`）**: `field.serialize(...)` または `response_field is None` 時の `jsonable_encoder(raw_response)` で Python プリミティブへ変換し、`actual_response_class(content, **response_args)`（`ORJSONResponse` や既定の `JSONResponse` など）へ渡します。
4. **ボディ除去とヘッダ統合**: `not is_body_allowed_for_status_code(response.status_code)`（`1xx`、`204`、`205`、`304`）の場合は `response.body = b""` に空化され、最後に `response.headers.raw.extend(solved_result.response.headers.raw)` で注入 `Response` 引数へ追加された `Set-Cookie` やカスタムヘッダがすべて結合されます。

## 3. ネストされた `include_router()`・`_EffectiveRouteContext`・Lifespan 合成

FastAPI `v0.162.2` の `APIRouter.include_router(router, ...)` は、呼び出し時点で子ルータの `APIRoute` を即座に複製するのではなく、自己参照（`self is not router`）および循環参照（`not router._contains_router(self)`）を検証したうえで、不変の `_RouterIncludeContext.for_include(...)` を保持する `_IncludedRouter(original_router=router, include_context=include_context)` ノードを `self.routes` に追加し、`self._routes_version` をインクリメントして Lifespan を合成します。この遅延評価設計により、`include_router()` の呼び出し**後**に子 `APIRouter` へ追加されたルートも、`_get_routes_version()` の変化を通じて自動的に反映されます。

```drawlib align=center code=hide file=include_router_context_merge.png caption="ネストされた include_router() におけるコンテキスト合成・外側から内側への依存解決順序・_merge_lifespan_context"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, Panel, Table
from drawlib.styles import Colors, Styles

setup(width=162, height=92)

# Top Panel: 4-tier Outer-to-Inner Router Inclusion Chain
top_panel = Panel(
    "Outer-to-Inner Inclusion",
    "",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.5),
    icon=phosphor.git_merge,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.0,
)
top_panel.draw((5.0, 50.0), width=152.0, height=37.0)
t_xy, t_w, t_h = top_panel.get_content_box(
    (5.0, 50.0), width=152.0, height=37.0, padding=(3.5, 2.5)
)

chain = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_shape="circle",
    badge_style=Styles.PrimaryNeutral,
    icon_style=Styles.PrimaryBold,
    direction="horizontal",
    show_arrows=True,
    arrow_style=Styles.PrimaryBold,
    spacing=4.0,
)
chain.add("1. FastAPI App", "deps=[D_app]\nlifespan=L_app", icon=phosphor.globe)
chain.add(
    "2. include_router",
    "prefix='/api'\ndeps=[D_inc]",
    icon=phosphor.folder_open,
    badge_style=Styles.SecondaryNeutral,
    icon_style=Styles.DarkBold,
)
chain.add(
    "3. Child Router",
    "prefix='/v1'\ndeps=[D_router]",
    icon=phosphor.share_network,
)
chain.add(
    "4. @router.post",
    "path='/items'\ndeps=[D_route]",
    icon=phosphor.code,
    badge_style=Styles.PrimaryFlat,
    icon_style=Styles.WhiteBold,
)
chain.draw(t_xy, width=t_w, height=t_h)

# Bottom-Left Table: Exact _RouterIncludeContext & _EffectiveRouteContext Merge Rules
merge_table = Table(
    cell_style=Styles.White,
    text_style=Styles.Dark.patch(text_size=10.0),
    header_cell_style=Styles.PrimaryFlat,
    header_text_style=Styles.WhiteBold.patch(text_size=10.5),
    border_style=Styles.MutedThin,
)
merge_table.set_style_cell_evenodd(
    even_color=Colors.Light,
    even_text_style=Styles.Dark.patch(text_size=10.0),
    odd_color=Colors.White,
    odd_text_style=Styles.Dark.patch(text_size=10.0),
)
merge_table.set_style_cell_header(
    background_color=Colors.Primary,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
)
merge_data = [
    ["Field", "Merge Rule", "Effective Value"],
    ["prefix + path", "Outer + inner concat", "'/api/v1/items'"],
    ["dependencies", "Outer-to-inner prepend", "[D_app, D_inc, D_router, D_route]"],
    ["tags / callbacks", "Outer-to-inner extend", "[*outer, *inner, *route]"],
    ["responses", "Dict merge (inner wins)", "{**include_resp, **route_resp}"],
    ["response_class", "get_value_or_default()", "route -> router -> include"],
]
merge_table.draw_flexible(
    xy=(5.0, 45.0),
    column_widths=[27.0, 34.0, 39.0],
    row_heights=[6.8, 6.4, 6.4, 6.4, 6.4, 6.4],
    data=merge_data,
    align="top_left",
)

# Bottom-Right Panel: _merge_lifespan_context State Composition
life_panel = Panel(
    "_merge_lifespan_context",
    "",
    style=Styles.PrimaryNeutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    icon=phosphor.arrows_clockwise,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.0,
)
life_panel.draw((109.0, 6.0), width=48.0, height=39.0)
lp_xy, lp_w, lp_h = life_panel.get_content_box(
    (109.0, 6.0), width=48.0, height=39.0, padding=(3.0, 2.2)
)

life_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.0),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.Neutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    spacing=1.8,
)
life_cards.add("Enter parent(app)", "Outer async with", badge_text="1")
life_cards.add("Enter child(app)", "Inner async with", badge_text="2")
life_cards.add(
    "Yield merged dict",
    "{**child, **parent}",
    badge_text="3",
    badge_style=Styles.AccentFlat,
    badge_text_style=Styles.WhiteBold.patch(text_size=10.0),
)
life_cards.draw(lp_xy, width=lp_w, height=lp_h)

save()
```

リクエスト到達時（または OpenAPI 生成時の `iter_route_contexts()` 走査時）には、`_IncludedRouter.effective_candidates()` が `_effective_routes_lock` を獲得し、ネストされた `_RouterIncludeContext` を `.combine()` で合成したうえで、`_EffectiveRouteContext.from_api_route()` により各ルートの実効コンテキストを一度だけ構築・キャッシュします。

- **外側から内側への依存解決順序（Outer-to-Inner Ordering）**: `_RouterIncludeContext` は階層ごとに `dependencies=[*parent_router.dependencies, *(include_dependencies or [])]` を連結し、`from_api_route()` が末尾に `*route.dependencies` を追加します。さらに `_build_dependant_with_parameterless_dependencies()` が `for depends in dependencies[::-1]: dependant.dependencies.insert(0, ...)` を実行するため、すべての引数なしルータ／デコレータ依存関係はエンドポイント関数のシグネチャ `Depends(...)` より**前**に、厳密な外側→内側順（`FastAPI` -> 外側 `APIRouter` -> `include_router()` -> 内側 `APIRouter` -> `@router.post(dependencies=...)` -> 関数引数）で評価されます。
- **デフォルト値と `responses` の優先順位**: `responses` は `{**include_context.responses, **route.responses}` で浅くマージされるため、同一ステータスコードではより内側のルート定義が優先されます。`response_class`、`generate_unique_id_function`、`strict_content_type` は `get_value_or_default(route_val, included_router_val, include_context_val)` により最も内側の非 `DefaultPlaceholder` 設定が採用され、`deprecated` は論理和（`or`）、`include_in_schema` は論理積（`and`）で合成されます。
- **`_merge_lifespan_context(original_context, nested_context)`**: `include_router()` 実行時に旧来の `on_startup`/`on_shutdown` ハンドラが転記されると同時に、`self.lifespan_context` がネストされた `@asynccontextmanager` でラップされます。ASGI Lifespan 起動時は親の `original_context(app)` が**外側**、子の `nested_context(app)` が**内側**の順に入り、終了時は逆順（LIFO）でクリーンアップされます。いずれかが状態辞書を `yield` した場合、`{**(maybe_nested_state or {}), **(maybe_original_state or {})}` としてマージされ、キー衝突時は親側の状態値が優先されます。

## 4. ソース検証済みインスペクションとカスタム `APIRoute` 拡張

### 4.1 コンパイル済み `APIRoute` 属性・`RouteContext`・Lifespan マージの検証

次のコードは、単体 `APIRoute` 上に生成された `ModelField` 群を検査したうえで 3 階層のルータを構成し、`iter_route_contexts(app.routes)` から実効メタデータを読み取り、外側→内側の依存実行順序と `_merge_lifespan_context` の状態マージ優先順位を検証します。

```python
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import APIRouter, Depends, FastAPI
from fastapi.routing import APIRoute, _IncludedRouter, iter_route_contexts
from fastapi.testclient import TestClient
from pydantic import BaseModel


class ItemIn(BaseModel):
    title: str
    qty: int


class ItemOut(BaseModel):
    id: int
    title: str
    secret: str | None = None


order: list[str] = []


def make_dep(label: str):
    def _dep() -> str:
        order.append(label)
        return label

    return _dep


@asynccontextmanager
async def app_lifespan(_app: FastAPI) -> AsyncIterator[dict[str, str]]:
    yield {"app_scope": "root", "shared": "parent_wins"}


@asynccontextmanager
async def router_lifespan(_app: FastAPI) -> AsyncIterator[dict[str, str]]:
    yield {"router_scope": "child", "shared": "child_overridden"}


inner = APIRouter(
    prefix="/items",
    tags=["items"],
    dependencies=[Depends(make_dep("inner_router"))],
    lifespan=router_lifespan,
)


@inner.post(
    "/{group}",
    response_model=ItemOut,
    response_model_exclude_none=True,
    responses={409: {"model": dict[str, str]}},
    dependencies=[Depends(make_dep("decorator"))],
)
async def create_item(
    group: str,
    payload: ItemIn,
    sig_dep: str = Depends(make_dep("endpoint_sig")),
) -> dict[str, object]:
    return {"id": 1, "title": f"{group}:{payload.title}:{sig_dep}"}


# 1. Direct APIRoute state compiled at decorator evaluation time
raw_route = inner.routes[0]
assert isinstance(raw_route, APIRoute)
assert raw_route.unique_id == "create_item_items__group__post"
assert raw_route.body_field is not None and raw_route.body_field.name == "payload"
assert raw_route._embed_body_fields is False
assert raw_route.response_field is not None
assert raw_route.response_field.mode == "serialization"
assert 409 in raw_route.response_fields

# 2. Lazy _IncludedRouter composition & effective RouteContext materialization
outer = APIRouter(
    prefix="/v1", tags=["v1"], dependencies=[Depends(make_dep("outer_router"))]
)
outer.include_router(inner, dependencies=[Depends(make_dep("include_call"))])

app = FastAPI(dependencies=[Depends(make_dep("app"))], lifespan=app_lifespan)
app.include_router(outer, prefix="/api")

assert any(isinstance(r, _IncludedRouter) for r in app.router.routes)
eff = next(ctx for ctx in iter_route_contexts(app.routes) if ctx.name == "create_item")
assert eff.path == "/api/v1/items/{group}"
assert eff.tags == ["v1", "items"]

with TestClient(app) as client:
    res = client.post("/api/v1/items/books", json={"title": "ASGI", "qty": 2})
    assert res.json() == {"id": 1, "title": "books:ASGI:endpoint_sig"}
    assert order == [
        "app",
        "outer_router",
        "include_call",
        "inner_router",
        "decorator",
        "endpoint_sig",
    ]
    assert client.app_state["shared"] == "parent_wins"
```

### 4.2 カスタム `APIRoute.get_route_handler()` サブクラスによるクロージャのラップ

カスタム `APIRoute` サブクラスで `get_route_handler(self)` をオーバーライドすると、`super().get_route_handler()` が生成するクロージャの前後で `Request` と `Response` を自在にフックできます。`_EffectiveRouteContext.from_api_route()` が統合ルートのハンドラを構築する際は、`ContextVar` である `_effective_route_context_var.set(context)` を一時的に束縛してから `original_route.get_route_handler()` を呼び出すため、`include_router()` 経由でマウントされたルートでもマージ済み `_EffectiveRouteContext` に対してカスタムラッパが正しく機能します。

```python
from collections.abc import Coroutine
from typing import Callable

from fastapi import APIRouter, FastAPI, Request, Response
from fastapi.routing import APIRoute
from fastapi.testclient import TestClient


class AuditAPIRoute(APIRoute):
    def get_route_handler(
        self,
    ) -> Callable[[Request], Coroutine[object, object, Response]]:
        original_handler = super().get_route_handler()

        async def custom_handler(request: Request) -> Response:
            response = await original_handler(request)
            response.headers["X-Route-Name"] = self.name
            return response

        return custom_handler


router = APIRouter(route_class=AuditAPIRoute)


@router.get("/ping")
async def ping() -> dict[str, bool]:
    return {"ok": True}


app = FastAPI()
app.include_router(router, prefix="/v2")

resp = TestClient(app).get("/v2/ping")
assert resp.status_code == 200
assert resp.headers["X-Route-Name"] == "ping"
```

続いて、`get_request_handler()` がジェネレータ配信と低優先度 SPA ルータをどのように分岐させるかについては [ジェネレータ配信と SPA ルータ内部実装](streaming_and_spa_internals.md)、`Dependant` グラフの解決アルゴリズムは [Dependant グラフと solve_dependencies](../03_di_and_security_engine/dependant_and_solver.md)、`ModelField` と `TypeAdapter` の統合は [_compat/v2.py・ModelField・直列化](../04_pydantic_bridge/compat_and_serialization.md)、そして外側スタックを支える `AsyncExitStackMiddleware` の構造は [ミドルウェア7層構造とスレッドプール](../05_asgi_and_telemetry/middleware_and_concurrency.md) を参照してください。
