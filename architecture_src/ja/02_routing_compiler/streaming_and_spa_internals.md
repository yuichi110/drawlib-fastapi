# ジェネレータ配信（SSE / JSONL）と SPA ルータ内部実装

通常のリクエスト／レスポンス型 JSON エンドポイントに加え、FastAPI `v0.162.2` は `fastapi/routing.py` と `fastapi/sse.py` の内部に 2 つの特化型ランタイムパイプラインを備えています。1 つは `yield` パスオペレーションから要素単位の型検証付き JSON Lines（`application/jsonl`）や PEP 789 準拠の Server-Sent Events（`text/event-stream`）を生成し、ストリーム完了まで `fastapi_inner_astack` を維持する**ネイティブジェネレータ配信機構**、もう 1 つは通常の API ルート群の後段でパストラバーサル防御と `Accept` ヘッダ判定を伴って静的アセットおよび HTML5 History フォールバックを配信する**低優先度 SPA エンジン**（`APIRouter.frontend()` / `_FrontendRouteGroup`）です。

```drawlib align=center code=hide file=generator_dispatch_branches.png caption="コンパイル時の戻り値アノテーション解析・ジェネレータ配信分岐・AsyncExitStack 寿命管理フロー"
from drawlib.canvas import save, setup
from drawlib.diagrams.flow import Data, Decision, End, FlowDiagram, Process, Start
from drawlib.styles import Colors, Styles

setup(width=170, height=112)

flow = FlowDiagram(
    node_style=Styles.Neutral,
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.DarkBold.patch(text_size=10.0),
    width=160,
    height=102,
    lane_orientation="vertical",
)

# 3 Vertical Swimlanes: 48 + 58 + 54 = 160 (centerlines at X = 24, 77, 133)
flow.add_lane(
    "1. Compile-Time Inspect",
    width=48,
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
)
flow.add_lane(
    "2. Closure Dispatch Branch",
    width=58,
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
)
flow.add_lane(
    "3. Wire Framing & ExitStack",
    width=54,
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
)

# Lane 1 Nodes (X = 24)
ep = flow.add(
    Start(
        "Endpoint Signature\n& Return Annotation",
        width=38,
        height=9.5,
        style=Styles.PrimaryFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
    ),
    xy=(24, 87),
)
is_gen = flow.add(
    Decision(
        "Uses yield?\n(gen / async_gen)",
        width=38,
        height=14,
        style=Styles.PrimaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    ),
    xy=(24, 67),
)
item_field = flow.add(
    Process(
        "get_stream_item_type()\n-> stream_item_field",
        width=38,
        height=12,
        style=Styles.Neutral,
        text_style=Styles.Dark.patch(text_size=10.0),
    ),
    xy=(24, 31),
)

# Lane 2 Nodes (X = 78, width = 42 -> left edge = 57)
ret_branch = flow.add(
    Process(
        "Standard return\nresponse_field.serialize_json()",
        width=42,
        height=11,
        style=Styles.Neutral,
        text_style=Styles.Dark.patch(text_size=10.0),
    ),
    xy=(78, 67),
)
sse_branch = flow.add(
    Process(
        "is_sse_stream\n_sse_producer_cm + 15s Ping",
        width=42,
        height=11.5,
        style=Styles.PrimaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    ),
    xy=(78, 48),
)
jsonl_branch = flow.add(
    Process(
        "is_json_stream\n_serialize_data(item) + b'\\n'",
        width=42,
        height=11.5,
        style=Styles.SecondaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    ),
    xy=(78, 31),
)
raw_branch = flow.add(
    Process(
        "Custom response_class\nRaw chunk iterator + sleep(0)",
        width=42,
        height=11,
        style=Styles.Neutral,
        text_style=Styles.Dark.patch(text_size=10.0),
    ),
    xy=(78, 13),
)

# Lane 3 Nodes (X = 130)
json_wire = flow.add(
    Data(
        "application/json\nFull Array / Object",
        width=38,
        height=11,
        style=Styles.Neutral,
        text_style=Styles.Dark.patch(text_size=10.0),
    ),
    xy=(130, 67),
)
sse_wire = flow.add(
    Data(
        "text/event-stream\nformat_sse_event()",
        width=38,
        height=11.5,
        style=Styles.AccentFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
    ),
    xy=(130, 48),
)
jsonl_wire = flow.add(
    Data(
        "application/jsonl\nNDJSON Byte Stream",
        width=38,
        height=11.5,
        style=Styles.Neutral,
        text_style=Styles.Dark.patch(text_size=10.0),
    ),
    xy=(130, 31),
)
astack = flow.add(
    End(
        "Close inner_astack\nAfter Stream Ends",
        width=38,
        height=11,
        style=Styles.PrimaryFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
    ),
    xy=(130, 13),
)

# Clean non-overlapping edges (terminal segments >= 7.9u)
ep.connect(is_gen, start_side="bottom", end_side="top", padding=0.6)
is_gen.connect(ret_branch, label="No", start_side="right", end_side="left", padding=0.6)
is_gen.connect(item_field, label="Yes", start_side="bottom", end_side="top", padding=0.6)

item_field.fork([sse_branch, jsonl_branch, raw_branch], at_x=48.5, padding=0.6)

ret_branch.connect(json_wire, start_side="right", end_side="left", padding=0.6)
sse_branch.connect(sse_wire, start_side="right", end_side="left", padding=0.6)
jsonl_branch.connect(jsonl_wire, start_side="right", end_side="left", padding=0.6)
raw_branch.connect(astack, start_side="right", end_side="left", padding=0.6)
jsonl_wire.connect(astack, start_side="bottom", end_side="top", padding=0.6)
sse_wire.connect(astack, start_side="right", end_side="right", padding=0.6).via(
    (155, 48), (155, 13)
)

flow.draw(xy=(5.0, 5.0))
save()
```

## 1. コンパイル時のジェネレータ検出と `stream_item_field` 合成

`_populate_api_route_state()` の実行時、FastAPI はラップ解除されたエンドポイント関数が同期または非同期ジェネレータであるかを判定します（`is_generator = _is_async_gen_callable(route.dependant.call) or _is_gen_callable(route.dependant.call)`）。このコンパイル時フラグによって、戻り値型のコンパイルは 4 つの実行モードに分岐します。

| エンドポイント形式と `response_class` | `is_sse_stream` | `is_json_stream` | 生成される `ModelField` | 送信 `Content-Type` と OpenAPI 3.2 スキーマ |
| :--- | :--- | :--- | :--- | :--- |
| `return` を用いる通常の `def` / `async def`（`list[Item]`） | `False` | `False` | `response_field`（`Response_<id>`） | `application/json`（配列一括直列化・`schema`） |
| `yield` + `Default(JSONResponse)`（既定） | `False` | `True` | `stream_item_field`（`StreamItem_<id>`） | `application/jsonl`（1行ごとの `itemSchema`） |
| `yield` + `EventSourceResponse` | `True` | `False` | `stream_item_field`（`ServerSentEvent` 以外） | `text/event-stream`（`_SSE_EVENT_SCHEMA` / `itemSchema`） |
| `yield` + 明示的な `StreamingResponse` 等 | `False` | `False` | `None`（`response_model = None`） | カスタム `media_type`（生チャンク透過配信） |

ジェネレータエンドポイントで `response_model` が既定の `Default(None)` のままである場合、`get_stream_item_type(return_annotation)` は `get_origin(annotation)` が `_STREAM_ORIGINS`（`{AsyncIterable, AsyncIterator, AsyncGenerator, Iterable, Iterator, Generator}`）に含まれるかを検査します。

- **型引数付きストリーム型（`AsyncIterable[Item]`、`Generator[Item, None, None]` など）**: `type_args[0]`（`Item`）を `route.stream_item_type` として抽出し、単一コンテナではなく逐次配信であることを示すため `route.response_model = None` に設定したうえで、`route.stream_item_field = create_model_field(name="StreamItem_" + route.unique_id, type_=Item, mode="serialization")` を構築します。
- **型引数なしのストリーム型（`-> AsyncIterable`、`-> Iterable`）**: `get_stream_item_type()` が `Any` を返すため、`stream_item_type = Any` として `TypeAdapter(Any)` 経由で JSONL／SSE ストリーミングが有効化されます。
- **`ServerSentEvent` の除外**: 戻り値型が `AsyncIterable[ServerSentEvent]` の場合、`ServerSentEvent` はドメインデータではなくトランスポート層のフレームラッパであるため、`not lenient_issubclass(stream_item, ServerSentEvent)` によって検証および OpenAPI データモデル生成から除外されます。

## 2. ランタイム配信パイプライン：JSONL・SSE TaskGroup・`fastapi_inner_astack`

### 2.1 共通の要素単位検証（`_serialize_data`）と JSONL 改行フレーミング

`get_request_handler()` の内部では、JSONL と SSE の双方が内部ヘルパ `_serialize_data(data: Any) -> bytes` を共有しています。
- `stream_item_field` が設定されている場合、`yield` された各要素は `stream_item_field.validate(data, {}, loc=("response",))` で逐次検証され（スキーマ違反時はストリーム途中でも `ResponseValidationError` を送出）、`response_model_include`、`response_model_exclude`、`by_alias`、`exclude_unset`、`exclude_defaults`、`exclude_none` を適用した `stream_item_field.serialize_json(...)` によって UTF-8 JSON バイト列へ直接変換されます。
- `stream_item_field` が `None` の場合は、`jsonable_encoder(data)` に続けて `_normalize_non_finite_floats(data)`（`NaN`、`Infinity`、`-Infinity` を JSON `null` へ正規化）を通し、`json.dumps(...).encode("utf-8")` で直列化します。

**`is_json_stream`**（`application/jsonl`）分岐では、`gen = dependant.call(**solved_result.values)` を非同期ジェネレータ用の `_async_stream_jsonl()` または同期ジェネレータ用の `_sync_stream_jsonl()`（`StreamingResponse` 側で Starlette のスレッドプールにより反復）で包み、直列化済みバイト列の末尾に `b"\n"` を付与します。非同期ジェネレータラッパ（明示的 `StreamingResponse` 用の `_async_stream_raw` も同様）は、各 `yield` の直後に必ず **`await anyio.sleep(0)`** を実行して `anyio` のキャンセルチェックポイントを挿入し、一度も待機しない高速なプロデューサであってもクライアント切断時に確実にキャンセルが伝播するように設計されています。

さらに、`request_response()` が `await response(scope, receive, send)` の**外側**で `scope["fastapi_inner_astack"]` を保持しているため、非同期 SQLAlchemy セッションなどの `scope="request"` な `yield` 依存関係は `StreamingResponse` の全チャンク送信中も開いたまま維持され、ストリーム完了または切断後に初めて `finally` ブロックでクリーンアップされます。

### 2.2 `fastapi/sse.py`：`EventSourceResponse`・`ServerSentEvent` と PEP 789 安全な TaskGroup

`fastapi/sse.py` は Server-Sent Events 向けの公開型とワイヤフォーマット変換器を提供します。
- **`EventSourceResponse(StreamingResponse)`**: `media_type = "text/event-stream"` を宣言するマーカサブクラスです。`GET` だけでなく **`POST` を含む任意の HTTP メソッド**で動作するため、Model Context Protocol（MCP）のように `POST` レスポンス上で SSE を流すプロトコルにもそのまま対応します。
- **`ServerSentEvent(BaseModel)`**: 単一イベントを表す Pydantic モデルで、`data: Any = None`（常に JSON 直列化され、`"hello"` はワイヤ上で引用符付きの `data: "hello"` となる）、`raw_data: str | None = None`（JSON 変換を行わない生文字列。`@model_validator(mode="after")` により `data` との同時指定を禁止）、単一行制約付きの `event`、NULL 文字禁止かつ単一行制約付きの `id`、`retry: int | None`（`Field(ge=0)`）、キープアライブ等に使われる `comment: str | None` を備えます。
- **`format_sse_event()`**: `_split_sse_lines()` で SSE 仕様の改行コード（`\r\n`、`\r`、`\n`）のみを分割し、`: <comment>`、`event: <event>`、行ごとの `data: <line>`、`id: <id>`、`retry: <retry>` を組み立て、イベント終端である `\n\n` を付与した UTF-8 `bytes` を返します。

実行時の `is_sse_stream` 分岐では、`gen.__anext__()` を直接 `anyio.fail_after(_PING_INTERVAL)` で囲むことを意図的に避けています（タイムアウト時にユーザジェネレータへ `CancelledError` が注入されてジェネレータ自体が終了してしまうため、またスレッドプール上の同期ジェネレータにも適用するためです）。代わりに FastAPI は `@asynccontextmanager async def _sse_producer_cm()` を **`fastapi_inner_astack`** 上へ登録します（`await async_exit_stack.enter_async_context(_sse_producer_cm())`）。

1. **分離されたメモリストリーム**: `anyio.create_task_group()` の内部で、バッファサイズ `1` の 2 組のチャネル `anyio.create_memory_object_stream[bytes](max_buffer_size=1)`（`send_stream`/`receive_stream` と `send_keepalive`/`receive_keepalive`）を生成します。
2. **Producer タスクと Keepalive タスクの並行実行**: `_producer()` が `gen.__aiter__()`（同期ジェネレータでは `iterate_in_threadpool(gen)`）から要素を取り出して `ServerSentEvent` または一般オブジェクトを SSE バイト列へ変換し `send_stream` に送ります。並行して `_keepalive_inserter()` が `with anyio.fail_after(_PING_INTERVAL):`（`15.0` 秒）付きで `receive_stream.receive()` を待機し、アイドルによる `TimeoutError` 発生時には `KEEPALIVE_COMMENT = b": ping\n\n"` を送出してリバースプロキシのタイムアウト切断を防ぎます。
3. **PEP 789 準拠の終了処理とバッファリング抑止ヘッダ**: `_sse_producer_cm()` をリクエストスコープの `fastapi_inner_astack` に積むことで、非同期ジェネレータの `GeneratorExit` ファイナライズ中ではなく、構造化された `AsyncExitStack` の巻き戻し時に `TaskGroup` を安全にキャンセルします。レスポンスには `_sse_with_checkpoints(sse_receive_stream)` が渡され、`Cache-Control: no-cache` と Nginx のプロキシバッファリングを無効化する `X-Accel-Buffering: no` が自動付与されます。

## 3. SPA エンジン内部構造（`APIRouter.frontend` と `_FrontendRouteGroup`）

`app.frontend(path, directory=..., fallback="auto", check_dir="auto")` および `router.frontend(...)` は、API エンドポイントを覆い隠すことなく Single-Page Application（SPA）の静的ビルド成果物をマウントします。

- **起動時のディレクトリ検証（`_resolve_frontend_check_dir`）**: `check_dir="auto"` の場合、本番環境ではディレクトリおよび明示指定されたフォールバックファイルの存在を起動時に厳格チェック（欠落時は `RuntimeError`）しますが、`FASTAPI_ENV == "development"`（`fastapi dev` 実行時に自動設定）ではフロントエンドの初回ビルド前でも起動できるよう `UserWarning` の警告出力に留めてチェックをスキップします。
- **グローバルな低優先度ディスパッチ順序**: `APIRouter.frontend()` は `self._frontend_routes = _FrontendRouteGroup(...)` を遅延生成し、OpenAPI スキーマ生成対象外の `self._low_priority_routes` へ格納します。`APIRouter.app()` は、ネストされた `_IncludedRouter` を含む**すべての通常ルート**を以下の優先順で評価し終えた後にのみ `_match_low_priority(scope)` を照会します。
  1. 通常ルートの `Match.FULL`（`APIRoute`、`APIWebSocketRoute`、`Mount`）
  2. 通常ルートの `Match.PARTIAL`（API パスに対する `405 Method Not Allowed` はフロントエンドのフォールバックより常に優先）
  3. 通常ルートの `redirect_slashes`（`/api/` への `307 Temporary Redirect` もフロントエンドより優先）
  4. `_match_low_priority(scope)`：セグメント境界を尊重しつつ `_frontend_path_specificity(path)`（`"/"` は `0`、それ以外は `len(path)`）が最長の `_FrontendRoute` を選択し、`_FrontendRouteGroup._solve_dependencies()` でルータ／アプリの `dependencies` を外側から内側の順に実行します。

```drawlib align=center code=hide file=frontend_route_group_fsm.png caption="APIRouter のルート優先順位と _FrontendRouteGroup による SPA 解決決定木"
from drawlib.canvas import save, setup
from drawlib.diagrams.flow import Data, Decision, End, FlowDiagram, Start
from drawlib.styles import Colors, Styles

setup(width=164, height=128)

flow = FlowDiagram(
    node_style=Styles.Neutral,
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.DarkBold.patch(text_size=10.0),
    width=154,
    height=118,
    lane_orientation="vertical",
)

# 2 Vertical Swimlanes: 77 + 77 = 154 (centerlines at X = 38.5, 115.5)
flow.add_lane(
    "1. Router Priority & Static Lookup",
    width=77,
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
)
flow.add_lane(
    "2. Fallback Cascade & Cache Headers",
    width=77,
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
)

# Row 1 (Y = 101): Entry
req = flow.add(
    Start(
        "Incoming HTTP Request",
        width=46,
        height=9.5,
        style=Styles.PrimaryFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.5),
    ),
    xy=(38.5, 101),
)

# Row 2 (Y = 81): Normal Route Priority Gate
api_chk = flow.add(
    Decision(
        "Normal Route Match?\n(FULL / 405 / 307)",
        width=50,
        height=13,
        style=Styles.PrimaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    ),
    xy=(38.5, 81),
)
api_win = flow.add(
    End(
        "Execute APIRoute\n(Frontend Ignored)",
        width=48,
        height=10,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    ),
    xy=(115.5, 81),
)

# Row 3 (Y = 58): Prefix Specificity, Router Depends & Method Gate
method_chk = flow.add(
    Decision(
        "Longest Prefix + Depends\nMethod in GET / HEAD?",
        width=52,
        height=13,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    ),
    xy=(38.5, 58),
)
bad_method = flow.add(
    Data(
        "405 if Static File Exists\n404 if Fallback-Only",
        width=48,
        height=10.5,
        style=Styles.Neutral,
        text_style=Styles.Dark.patch(text_size=10.0),
    ),
    xy=(115.5, 58),
)

# Row 4 (Y = 35): Traversal-Safe Static File Lookup
stat_chk = flow.add(
    Decision(
        "_lookup_static_resource()\nnormpath + no-symlink",
        width=52,
        height=13,
        style=Styles.SecondaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    ),
    xy=(38.5, 35),
)
serve_asset = flow.add(
    Data(
        "200 File / 307 Dir Slash\nETag + Dep Cache-Control",
        width=50,
        height=11,
        style=Styles.PrimaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    ),
    xy=(115.5, 35),
)

# Row 5 (Y = 12): SPA Navigation Fallback Gate
nav_chk = flow.add(
    Decision(
        "404.html or Navigation?\nAccept: text/html (q!=0)",
        width=54,
        height=13,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    ),
    xy=(38.5, 12),
)
spa_shell = flow.add(
    End(
        "200 index.html / 404.html\nElse HTTPException(404)",
        width=50,
        height=10.5,
        style=Styles.AccentFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
    ),
    xy=(115.5, 12),
)

# Pure vertical & horizontal non-overlapping connections
req.connect(api_chk, start_side="bottom", end_side="top", padding=0.6)
api_chk.connect(api_win, label="Yes", start_side="right", end_side="left", padding=0.6)
api_chk.connect(method_chk, label="No", start_side="bottom", end_side="top", padding=0.6)

method_chk.connect(bad_method, label="No", start_side="right", end_side="left", padding=0.6)
method_chk.connect(stat_chk, label="Yes", start_side="bottom", end_side="top", padding=0.6)

stat_chk.connect(serve_asset, label="Found", start_side="right", end_side="left", padding=0.6)
stat_chk.connect(nav_chk, label="Missing", start_side="bottom", end_side="top", padding=0.6)
nav_chk.connect(spa_shell, label="Fallback", start_side="right", end_side="left", padding=0.6)

flow.draw(xy=(5.0, 5.0))
save()
```

`html=True` かつ `follow_symlink=False` で初期化される `_FrontendStaticFiles(StaticFiles)` の `get_response(path, scope)` は、以下の 4 段階のセキュリティおよびプロトコル規則を適用します。

1. **HTTP メソッド制限とパストラバーサル防御（`_lookup_static_resource`）**: `scope["fastapi"]["frontend_path"]` を `os.path.normpath` で正規化し、`run_in_threadpool` 内で `self.lookup_path(path)` を呼び出します。`follow_symlink=False` と Starlette の `os.path.commonpath` 境界検証により、`/../`・`%2e%2e`・`%5c` などのトラバーサル文字列やディレクトリ外を指すシンボリックリンクはすべて `404` として拒否されます（`PermissionError` は `401`、`ENAMETOOLONG` は `404` に変換）。また `GET`/`HEAD` 以外のメソッドは、実ファイルまたはディレクトリ内 `index.html` が実在する場合のみ `405` を返し、クライアントサイドルートのみの仮想パスへの `POST` 等には `404` を返します。
2. **ディレクトリ末尾スラッシュの 307 リダイレクト**: `path` が `index.html` を含むサブディレクトリに解決され、かつ `scope["path"]` が `"/"` で終わっていない場合、相対アセットパスの基準ずれを防ぐため `url.path + "/"` への `307` `RedirectResponse` を返します。
3. **フォールバック優先順位と `_is_frontend_navigation_request(scope)`**: 静的ファイルが存在しない場合、次の順でフォールバックを判定します。
   - **`404.html` の優先適用**: `fallback == "404.html"` または（`fallback == "auto"` かつ `404.html` が存在）の場合、`Accept` ヘッダに関わらず `status_code=404` で `404.html` を返します。
   - **`index.html` に対する明示的 HTML ナビゲーション判定**: 上記に該当せず `index.html` が有効な場合、`_is_frontend_navigation_request(scope)` が `_iter_accept_media_types()`（`email.message.Message`）で `Accept` ヘッダを解析し、品質係数 `q != 0` の `text/html` または `application/xhtml+xml` が**明示的に含まれる場合のみ** `200 index.html` を返します。拡張子の有無ではなく `Accept` ヘッダで判定するため、`/users/jane.doe` や `/v/1.2.3` のようなドットを含む SPA ルートでもブラウザ遷移時は正しく `index.html` が返る一方、欠損した JS/CSS サブリソース（`Accept: */*` や `text/css`）には確実に `404` を返し、HTML を JS として読み込ませてしまう事故を防ぎます。
4. **条件付きキャッシュと `Cache-Control` ヘッダ合成**: Starlette の `file_response()` は自動的に `ETag` および `Last-Modified` ヘッダを付与し、`If-None-Match` / `If-Modified-Since` による `304 Not Modified` 応答を処理します。さらに `_FrontendRouteGroup.handle()` は解決済み依存関係の `solved_result.response.headers.raw` を `FileResponse` に統合するため、ルータの `dependencies` を通じてハッシュ付き `/assets/*` バンドルには `public, max-age=31536000, immutable`、フォールバック `index.html` には `no-cache` といった `Cache-Control` ポリシーを宣言的に付与できます。

## 4. ソース検証済みストリーミング・SPA ルーティング検証

### 4.1 `stream_item_field`・JSONL 出力・`format_sse_event()` ワイヤ形式の検証

以下のスニペットは、コンパイル時の `is_json_stream` / `is_sse_stream` / `stream_item_field` 生成結果と、`format_sse_event()` のバイト列エンコード、および `TestClient` による JSONL／SSE レスポンスヘッダ・ペイロードを検証します。

```python
import json
from collections.abc import AsyncIterable

from fastapi import FastAPI
from fastapi.routing import APIRoute
from fastapi.sse import EventSourceResponse, ServerSentEvent, format_sse_event
from fastapi.testclient import TestClient
from pydantic import BaseModel


class MetricChunk(BaseModel):
    step: int
    loss: float
    tag: str | None = None


app = FastAPI()


@app.get("/metrics.jsonl", response_model_exclude_none=True)
async def stream_jsonl() -> AsyncIterable[MetricChunk]:
    yield MetricChunk(step=1, loss=0.42)
    yield MetricChunk(step=2, loss=0.19, tag="converged")


@app.get("/metrics.sse", response_class=EventSourceResponse)
async def stream_sse() -> AsyncIterable[MetricChunk | ServerSentEvent]:
    yield MetricChunk(step=1, loss=0.42)
    yield ServerSentEvent(
        data={"done": True}, event="complete", id="evt-2", retry=5000
    )


routes = {r.path: r for r in app.router.routes if isinstance(r, APIRoute)}
assert routes["/metrics.jsonl"].is_json_stream is True
assert routes["/metrics.jsonl"].stream_item_field is not None
assert routes["/metrics.sse"].is_sse_stream is True

assert format_sse_event(data_str='{"ok":true}', event="tick", id="1") == (
    b'event: tick\ndata: {"ok":true}\nid: 1\n\n'
)

client = TestClient(app)
r_jsonl = client.get("/metrics.jsonl")
assert r_jsonl.headers["content-type"] == "application/jsonl"
assert [json.loads(line) for line in r_jsonl.text.splitlines()] == [
    {"step": 1, "loss": 0.42},
    {"step": 2, "loss": 0.19, "tag": "converged"},
]

r_sse = client.get("/metrics.sse")
assert r_sse.headers["cache-control"] == "no-cache"
assert r_sse.headers["x-accel-buffering"] == "no"
assert 'event: complete\ndata: {"done": true}\nid: evt-2\nretry: 5000\n\n' in r_sse.text
```

### 4.2 `_FrontendRouteGroup` の優先順位・トラバーサル防御・`Cache-Control` 合成の検証

次のスニペットは、`Cache-Control` 付与用の依存関係を持つ `APIRouter` に `router.frontend()` で SPA ディレクトリをマウントし、API ルート優先順位・ハッシュ付きアセットへの `immutable` ヘッダ付与・ドット入りクライアントルートへの `no-cache` HTML フォールバック・`*/*` アセット欠損時の `404`・`%2e%2e` トラバーサル遮断を確認します。

```python
from pathlib import Path
from tempfile import TemporaryDirectory

from fastapi import APIRouter, Depends, FastAPI, Request, Response
from fastapi.testclient import TestClient

with TemporaryDirectory() as tmp:
    root = Path(tmp)
    dist = root / "dist"
    (dist / "assets").mkdir(parents=True)
    (dist / "index.html").write_text("<!doctype html><title>SPA</title>")
    (dist / "assets" / "app.8f3a1c.js").write_text("console.log('v1');")
    (root / "secret.txt").write_text("top-secret")

    def spa_cache_policy(request: Request, response: Response) -> None:
        if request.url.path.startswith("/assets/"):
            response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
        else:
            response.headers["Cache-Control"] = "no-cache"

    spa_router = APIRouter(dependencies=[Depends(spa_cache_policy)])
    spa_router.frontend("/", directory=dist, fallback="index.html")

    app = FastAPI()

    @app.get("/api/status")
    async def api_status() -> dict[str, str]:
        return {"service": "healthy"}

    app.include_router(spa_router)
    client = TestClient(app)

    # API route wins even when browser sends Accept: text/html
    assert client.get("/api/status", headers={"accept": "text/html"}).json() == {
        "service": "healthy"
    }

    # Hashed bundle gets ETag + immutable Cache-Control
    asset = client.get("/assets/app.8f3a1c.js")
    assert "etag" in asset.headers
    assert asset.headers["cache-control"] == "public, max-age=31536000, immutable"

    # Dotted client route with Accept: text/html receives no-cache index.html
    nav = client.get("/users/jane.doe", headers={"accept": "text/html"})
    assert nav.status_code == 200 and nav.headers["cache-control"] == "no-cache"

    # Subresource miss (*/*), traversal (%2e%2e), and POST to asset are rejected
    assert client.get("/assets/missing.js", headers={"accept": "*/*"}).status_code == 404
    assert client.get("/%2e%2e/secret.txt").status_code == 404
    assert client.post("/assets/app.8f3a1c.js").status_code == 405
```

コアとなる `APIRoute` クロージャ合成モデルについては [APIRouter・APIRoute とクロージャ合成](apiroute_and_closures.md) を参照してください。また、`yield` 依存関係と `fastapi_inner_astack` の連携や OpenAPI 3.2 `itemSchema` のスキーマ合成については、[Dependant グラフと solve_dependencies](../03_di_and_security_engine/dependant_and_solver.md)、[ミドルウェア7層構造とスレッドプール](../05_asgi_and_telemetry/middleware_and_concurrency.md)、および [get_openapi()・$defs 集約・Docs UI](../06_openapi_and_docs/openapi_synthesis_engine.md) へ進んでください。
