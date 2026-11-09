# ミドルウェア7層構造と AnyIO スレッドプール並行制御

`FastAPI` インスタンスへ到達するすべての HTTP リクエスト、WebSocket セッション、および ASGI lifespan イベントは、`fastapi/applications.py` の `FastAPI.__call__` を通過します。FastAPI はリクエストごとにラッパークロージャを再構築するのではなく、最初の HTTP または WebSocket 呼び出し時に確定的な 7 層 ASGI ミドルウェア構造（オニオンモデル）を 1 度だけ遅延構築し、外側のクラッシュ復旧（`500`）と内側のアプリケーション例外処理（`4xx` / `422`）を分離しつつ、同期関数を AnyIO ワーカースレッドへ安全にオフロードします。

```drawlib align=center code=hide file=seven_layer_asgi_stack.png caption="FastAPI.__call__ と build_middleware_stack() が構築する7層 ASGI ミドルウェア構造"
from drawlib.canvas import setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Colors, Styles

setup(width=176, height=94)

left_panel = Panel(
    "7-Layer ASGI Stack",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.5),
    icon=phosphor.stack,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.5,
)
left_panel.draw((4.0, 4.0), width=92.0, height=86.0)
l_xy, l_w, l_h = left_panel.get_content_box(
    (4.0, 4.0), width=92.0, height=86.0, padding=(3.5, 2.8)
)

onion_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.DarkBold,
    spacing=1.5,
)
onion_cards.add(
    "NativeTelemetry (FastAPI.__call__)",
    "Starts SERVER span, W3C context & HTTP metrics",
    badge_text="L1",
    icon=phosphor.pulse,
    style=Styles.PrimaryNeutral,
)
onion_cards.add(
    "ServerErrorMiddleware",
    "Outermost 500 safety net & Exception handler",
    badge_text="L2",
    icon=phosphor.shield_warning,
)
onion_cards.add(
    "ExceptionTelemetryMiddleware",
    "Records unhandled error.type before 500 body",
    badge_text="L3",
    icon=phosphor.bug,
    style=Styles.SecondaryNeutral,
)
onion_cards.add(
    "self.user_middleware (LIFO)",
    "Reverse add_middleware() registration order",
    badge_text="L4",
    icon=phosphor.arrows_down_up,
)
onion_cards.add(
    "ExceptionMiddleware",
    "Converts HTTPException & 422 into JSONResponse",
    badge_text="L5",
    icon=phosphor.funnel,
)
onion_cards.add(
    "AsyncExitStackMiddleware",
    "Pushes FormData & UploadFile close callbacks",
    badge_text="L6",
    icon=phosphor.folder_open,
    style=Styles.SecondaryNeutral,
)
onion_cards.add(
    "APIRouter -> APIRoute",
    "Matches route, updates span & runs closure",
    badge_text="L7",
    icon=phosphor.git_branch,
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
    badge_style=Styles.White,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
)
onion_cards.draw(l_xy, width=l_w, height=l_h)

right_panel = Panel(
    "Boundary & Scope Rules",
    style=Styles.PrimaryNeutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.5),
    icon=phosphor.scales,
    icon_style=Styles.White,
    header_variant="filled",
    header_height=8.5,
)
right_panel.draw((100.0, 4.0), width=72.0, height=86.0)
r_xy, r_w, r_h = right_panel.get_content_box(
    (100.0, 4.0), width=72.0, height=86.0, padding=(3.5, 3.0)
)

rule_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    spacing=2.5,
)
rule_cards.add(
    "Lazy Build Once",
    "middleware_stack stays None until 1st call",
    badge_text="Init",
    icon=phosphor.lightning,
)
rule_cards.add(
    "Outer 500 Guard",
    "Catches crashes raised in user_middleware",
    badge_text="L2",
    icon=phosphor.warning_octagon,
)
rule_cards.add(
    "Inner 4xx/422 Guard",
    "CORS & GZip wrap 4xx/422 JSON responses",
    badge_text="L5",
    icon=phosphor.check_circle,
)
rule_cards.add(
    "3 AsyncExitStacks",
    "Middleware file + request & function scopes",
    badge_text="Ctx",
    icon=phosphor.stack_simple,
)
rule_cards.draw(r_xy, width=r_w, height=r_h)
```

---

## 1. `FastAPI.__call__` の分岐制御とスタック遅延構築

`FastAPI` は `starlette.applications.Starlette` を継承しており、`__init__()` 時点では `self.middleware_stack: ASGIApp | None = None` のまま初期化します。最初のリクエスト到達まで構築を遅らせることで、起動時に `app.add_middleware()`・`@app.middleware("http")`・`@app.exception_handler()` を任意の順序で登録しても、その都度ラッパーチェーンを再生成せずに済みます。

`fastapi/applications.py` 内の `await app(scope, receive, send)` は、スコープ種別とテレメトリ状態に応じて 3 つの実行経路へ分岐します。

1. **Lifespan フック（`scope["type"] == "lifespan"`）**: `fastapi.telemetry._runtime.lifespan(config=self._telemetry, app=super().__call__, ...)` へ委譲し、`lifespan.startup` 時に環境変数ベースの OTLP 自動構成を実行し、`lifespan.shutdown.complete` 時に FastAPI 管理下のエクスポータをフラッシュします。
2. **非計測ファストパス**: `scope["type"]` が `"http"`・`"websocket"` 以外の場合、マウントされたサブアプリなどで `"fastapi.telemetry"` が既に `scope` に存在する場合、または `self._native_telemetry.enabled()` が `False` の場合は、そのまま `await super().__call__(scope, receive, send)` を呼び出します。親クラスの `Starlette.__call__` が `scope["app"] = self` を設定し、`self.middleware_stack` が `None` なら `self.build_middleware_stack()` で構築して実行します。
3. **計測対象の HTTP / WebSocket パス**: `self._native_telemetry.enabled()` が `True` の場合、`FastAPI.__call__` は先に `self.middleware_stack` を構築し、`_legacy_otel(self.middleware_stack)` で既存の `opentelemetry.instrumentation.asgi.OpenTelemetryMiddleware` の有無を確認したうえで、`super().__call__` を `await self._native_telemetry(...)` で包んで呼び出します。

---

## 2. `build_middleware_stack()` の7層構造（外側から内側へ）

`FastAPI.build_middleware_stack()` は Starlette の標準構築処理をオーバーライドし、`self.user_middleware` の前後に `ExceptionTelemetryMiddleware` と `AsyncExitStackMiddleware` を挿入します。まず `self.exception_handlers` を走査してキー `500` および `Exception` を `ServerErrorMiddleware` 用の `error_handler` に分離し、それ以外の個別例外ハンドラを `ExceptionMiddleware` 用の `exception_handlers` に振り分けます。その後、`middleware` リストを逆順にたどりながら `self.router` を内側から外側へとラップします。

| 層 | クラスとモジュール | Scope / 状態キー | 主な責務 |
| :--- | :--- | :--- | :--- |
| **L1** | `NativeTelemetry` (`fastapi.telemetry._asgi`) | `scope["fastapi.telemetry"]` | `FastAPI.__call__` で `super().__call__` を包み、W3C コンテキスト抽出・`SERVER` スパン開始・HTTP メトリクス記録を担当。 |
| **L2** | `ServerErrorMiddleware` (`starlette.middleware.errors`) | — | `middleware_stack` 最外層。未処理 `Exception` を捕捉し、`500`/`Exception` ハンドラまたはデバッグトレースバックを送信後に再送出。 |
| **L3** | `ExceptionTelemetryMiddleware` (`fastapi.telemetry._asgi`) | `_RequestTelemetry._exceptions` | `L4`〜`L7` から漏れた未処理例外を、`L2` が `500` レスポンス本文を送信してスパンを閉じる前に記録。 |
| **L4** | `self.user_middleware` (`starlette.middleware`) | ユーザー定義 | `add_middleware()` が `self.user_middleware.insert(0, ...)` を行うため、登録の逆順（LIFO）で重なるカスタムミドルウェア群。 |
| **L5** | `ExceptionMiddleware` (`starlette.middleware.exceptions`) | — | `HTTPException`・`RequestValidationError`（`422`）・`WebSocketRequestValidationError`（`1008`）・独自例外ハンドラを処理。 |
| **L6** | `AsyncExitStackMiddleware` (`fastapi.middleware.asyncexitstack`) | `scope["fastapi_middleware_astack"]` | レスポンス送信完了後に `FormData` や `UploadFile` の一時ファイルを確実にクローズするための `AsyncExitStack` を保持。 |
| **L7** | `APIRouter` (`fastapi.routing`) | `scope["router"]`, `scope["route"]` | `APIRoute`・`Mount`・フロントエンドルートを照合し、`_route_selected()` を通知して `request_response()` を実行。 |

### なぜ `ServerErrorMiddleware` は `user_middleware` の外側、`ExceptionMiddleware` は内側なのか

エラー処理を **L2**（`self.user_middleware` の外側）と **L5**（`self.user_middleware` の内側）に二分割している理由は、相反する 2 つの ASGI 要件を同時に満たすためです。

- **ユーザーミドルウェア自身のクラッシュからの保護（L2 が L4 の外側）**: ユーザーミドルウェアはルーティングの前後で認証ヘッダ解析やセッション接続など任意のコードを実行します。もしユーザーミドルウェア内で未処理の `RuntimeError` が発生した場合、内側の **L5**（`ExceptionMiddleware`）は既に通過済みか未到達です。`ServerErrorMiddleware` を **L2** に配置することで、ユーザーミドルウェア内のバグに対しても確実に有効な HTTP `500 Internal Server Error` を返却でき、さらにその直下の **L3** に `ExceptionTelemetryMiddleware` を置くことで、`500` レスポンス送信前に `error.type` を欠落なく記録できます。
- **制御された HTTP エラーに対するミドルウェアヘッダの維持（L5 が L4 の内側）**: `HTTPException(status_code=401)` や `RequestValidationError`（`fastapi/exception_handlers.py` による `422` 応答）といった想定内のアプリケーション例外は、**L5**（および `request_response()` 内の `wrap_app_handling_exceptions`）で捕捉され、**L4** へ戻る前に通常の `JSONResponse` オブジェクトへ変換されます。その結果、外側の `CORSMiddleware` や `GZipMiddleware`、アクセスログミドルウェアは例外ではなく正常な HTTP レスポンスとして後続処理を実行でき、`401` や `422` 応答にも `Access-Control-Allow-Origin` ヘッダが正しく付与されます。

### 3 段階に分離された `AsyncExitStack` スコープ

FastAPI はすべてのリソース解放を **L6** ひとつに押し込めるのではなく、用途と寿命に応じて 3 つの入れ子 `AsyncExitStack` を使い分けています。

1. **`scope["fastapi_middleware_astack"]`（L6 — `AsyncExitStackMiddleware`）**: すべてのユーザーミドルウェアの内側（`BaseHTTPMiddleware` が生成する `contextvars` タスクコンテキストの内側）で開始され、レスポンス完了後に閉じられます。`get_request_handler()` は `file_stack.push_async_callback(body.close)` をここへ登録し、ストリーミング応答中も `UploadFile` の `SpooledTemporaryFile` が閉じられないよう保証します。
2. **`scope["fastapi_function_astack"]`（L7 — `request_response()`）**: `await response(scope, receive, send)` の開始前に終了し、`Depends(..., scope="function")` 指定の `yield` 依存関係をレスポンス送信前にクリーンアップしつつ、`yield` 後の `HTTPException` 送出との互換性を保ちます。
3. **`scope["fastapi_inner_astack"]`（L7 — `request_response()`）**: `await response(scope, receive, send)` 全体を包み、`Depends(..., scope="request")` の `yield` 依存関係（ストリーミングジェネレータが参照する DB セッションなど）を最後のバイト送信完了まで生存させます。

---

## 3. AnyIO スレッドプールへのオフロードと `contextvars` 伝播

FastAPI は非同期イベントループ上で動作するため、ブロッキングな CPU 処理や同期 I/O をイベントループ上で直接実行すると、同一ワーカープロセス上の全同時接続が停止してしまいます。`async def` と通常の `def` の双方を安全に扱うため、FastAPI はルート登録時のコルーチン判定と AnyIO ワーカースレッドへのオフロードを組み合わせています。

```drawlib align=center code=hide file=anyio_threadpool_contextvars.png caption="AnyIO ワーカースレッドへのオフロード、CapacityLimiter(1) による終了処理、および contextvars の伝播"
from drawlib.canvas import setup
from drawlib.diagrams.sequence import (
    Participant,
    ParticipantGroup,
    PhosphorIcon,
    SequenceDiagram,
)
from drawlib.styles import Colors, Styles

d = SequenceDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.0),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
    autonumber=True,
    col_width=44.0,
    step_y=7.4,
)

loop_p = d.add(
    Participant(
        "Event Loop\n(AsyncIO)",
        width=28,
        height=15,
        icon=PhosphorIcon.LIGHTNING,
        icon_size=6.0,
        card_style=Styles.PrimaryNeutral,
    )
)

pool_grp = d.add(
    ParticipantGroup(
        title="AnyIO Threadpool",
        padding=4.5,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=10.5, halign="left"),
    )
)
default_pool = pool_grp.add(
    Participant(
        "Default Limiter\n(40 Tokens)",
        width=28,
        height=15,
        icon=PhosphorIcon.CPU,
        icon_size=6.0,
        card_style=Styles.Neutral,
    )
)
exit_pool = pool_grp.add(
    Participant(
        "exit_limiter\nCapacityLimiter(1)",
        width=30,
        height=15,
        icon=PhosphorIcon.LOCK_KEY_OPEN,
        icon_size=6.0,
        card_style=Styles.SecondaryNeutral,
    )
)

worker_fn = d.add(
    Participant(
        "Yield Dep &\nEndpoint Callable",
        width=30,
        height=15,
        icon=PhosphorIcon.CODE,
        icon_size=6.0,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
        card_style=Styles.PrimaryFlat,
    )
)

loop_p.request(default_pool, "run_in_threadpool(cm.__enter__)")
default_pool.request(worker_fn, "Enter sync yield dep (copied ContextVar)")
worker_fn.reply(loop_p, "Yielded resource")

with d.alt("async def") as alt_blk:
    alt_blk.style = Styles.Neutral.patch(line_style="dashed")
    alt_blk.text_style = Styles.DarkBold.patch(text_size=10.0)
    loop_p.request(worker_fn, "Direct await dependant.call(**values) on loop")
    worker_fn.reply(loop_p, "Coroutine result (zero thread hop)")

    d.else_("sync def")
    loop_p.request(default_pool, "run_in_threadpool(_run_sync_endpoint)")
    default_pool.request(worker_fn, "Run sync endpoint (copied ContextVar)")
    worker_fn.reply(loop_p, "Endpoint return value")

loop_p.request(exit_pool, "run_sync(cm.__exit__, limiter=exit_limiter)")
exit_pool.request(worker_fn, "Teardown bypasses 40-token pool")
worker_fn.reply(loop_p, "Resource released without deadlock")

diag_w, diag_h = d.get_size()
setup(width=int(diag_w) + 12, height=int(diag_h) + 12)
d.draw(xy=(6.0, 6.0))
```

### `run_endpoint_function()`（`is_coroutine` と `run_in_threadpool`）

`fastapi/routing.py` の `get_request_handler()` はルートクロージャ生成時に `is_coroutine = _is_coroutine_callable(dependant.call)`（`functools.partial` や呼び出し可能インスタンスも展開して判定）を 1 度だけ評価します。リクエスト実行時、`run_endpoint_function()` はこの事前計算済みフラグで分岐します。

- **`is_coroutine == True`（`async def`）**: `with _operation(name="endpoint", function=dependant.call):` の中で `await dependant.call(**values)` をイベントループ上で直接実行し、スレッド切り替えやコンテキスト複製のコストを一切発生させません。
- **`is_coroutine == False`（`def`）**: Starlette の `await run_in_threadpool(_run_sync_endpoint, function=dependant.call, arguments=values)` を通じて `anyio.to_thread.run_sync`（デフォルト上限 40 トークンの `CapacityLimiter`）へオフロードします。`_run_sync_endpoint` はワーカースレッド内部で `_operation(name="endpoint", ...)` を開くため、OpenTelemetry の子スパンは同期実行の実時間に正確に対応します。

同様の分岐は `solve_dependencies()`（同期サブ依存関数の実行）や `serialize_response()`（`is_coroutine=False` 時のレスポンスモデル検証）でも一貫して適用されています。

### `contextmanager_in_threadpool()` と `CapacityLimiter(1)` によるデッドロック回避

同期ジェネレータ依存関係（`def get_db(): ... yield db ...`）は、前処理と後処理の双方でブロッキング I/O を伴う可能性があります。`fastapi/dependencies/utils.py` の `_solve_generator()` は同期ジェネレータを `contextlib.contextmanager` で包んだうえで、`fastapi/concurrency.py` の `contextmanager_in_threadpool()` に渡します。

- **前処理（`__enter__`）**: AnyIO の共有デフォルトスレッドリミッタ（40 トークン）を使って `yield await run_in_threadpool(cm.__enter__)` を実行します。
- **後処理（`__exit__`）**: 呼び出しごとに専用の `exit_limiter = CapacityLimiter(1)` を新規生成し、`except Exception as e:` 分岐（`cm.__exit__` の例外抑制戻り値も反映）と `else:` 分岐の双方で `await anyio.to_thread.run_sync(cm.__exit__, ..., limiter=exit_limiter)` を実行します。

なぜ `__exit__` に専用の `CapacityLimiter(1)` を割り当てるのでしょうか。たとえば上限 10 接続の DB コネクションプールに対し 50 リクエストが同時到達した状況を考えます。10 リクエストが DB 接続を取得し、残り 40 個のワーカースレッドが `cm.__enter__` 内で空き DB 接続を待機すると、AnyIO のデフォルト 40 トークンが完全に枯渇します。このとき最初の 1 リクエストが処理を完了して `cm.__exit__` で DB 接続を返却しようとした際、もしデフォルトリミッタの空きを待ってしまうと、「`cm.__enter__` は `cm.__exit__` の DB 返却を待ち、`cm.__exit__` は `cm.__enter__` のスレッド解放を待つ」という完全なデッドロックに陥ります。`limiter=exit_limiter` を指定することで、飽和した共有プールを迂回して即座にリソースを解放できます。

### ワーカースレッドへの `contextvars` コピー挙動

`starlette.concurrency.run_in_threadpool` および `anyio.to_thread.run_sync` は、イベントループ側で `contextvars.copy_context()` を取得し、ワーカースレッド内で `context.run(...)` を実行します。

- **下流への自動伝播**: `async` ミドルウェアや `async` 依存関数で設定された `ContextVar`（FastAPI の `_REQUEST_TELEMETRY_KEY` を含む）は、同期 `def` の `yield` 依存関数や同期 `def` エンドポイント内からそのまま読み取ることができます。
- **スナップショット分離の注意点**: `copy_context()` は `run_sync` 呼び出しごとに浅いコピーを作るため、同期 `def` 依存関数内で `my_var.set("new")` を呼んでも書き換わるのはそのワーカースレッド用コピーのみであり、イベントループ側や後続の同期エンドポイント、さらには別々の `run_sync` として動く `cm.__enter__` から `cm.__exit__` へも伝播しません。複数段階をまたいで `ContextVar` を更新したい場合は、`async` ミドルウェアまたは `async def` の `yield` 依存関数内で設定・リセットを行います。

---

## 4. 7層ミドルウェア順序と `ContextVar` 伝播の検証

以下のコードスニペットは、実稼働する `FastAPI()` インスタンス上で初回リクエスト前後の `middleware_stack` 遅延構築、外側から内側 `APIRouter` までの正確なミドルウェア連鎖、およびワーカースレッドへの `ContextVar` 伝播を検証します。

```python
from contextvars import ContextVar
import threading

from fastapi import Depends, FastAPI
from fastapi.telemetry._asgi import NativeTelemetry
from fastapi.testclient import TestClient
from starlette.types import ASGIApp, Receive, Scope, Send

request_id_var: ContextVar[str] = ContextVar("request_id", default="unset")


class FirstUserMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        token = request_id_var.set("req-42")
        try:
            await self.app(scope, receive, send)
        finally:
            request_id_var.reset(token)


class SecondUserMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        await self.app(scope, receive, send)


app = FastAPI()
app.add_middleware(FirstUserMiddleware)
app.add_middleware(SecondUserMiddleware)


def sync_yield_dep():
    yield {
        "dep_thread": threading.current_thread().name,
        "dep_ctx": request_id_var.get(),
    }


@app.get("/threads")
def read_threads(dep: dict[str, str] = Depends(sync_yield_dep)) -> dict[str, str]:
    return {
        **dep,
        "ep_thread": threading.current_thread().name,
        "ep_ctx": request_id_var.get(),
    }


# 1. 遅延構築: 初回 HTTP/WS 呼び出し前は middleware_stack が None
assert app.middleware_stack is None
assert isinstance(app._native_telemetry, NativeTelemetry)

with TestClient(app) as client:
    payload = client.get("/threads").json()
    assert payload["dep_ctx"] == "req-42"
    assert payload["ep_ctx"] == "req-42"
    assert payload["dep_thread"] != threading.main_thread().name

# 2. app.middleware_stack を最外層から最内層 APIRouter まで走査
layers: list[str] = []
cursor: object | None = app.middleware_stack
while cursor is not None:
    layers.append(type(cursor).__name__)
    if cursor is app.router:
        break
    cursor = getattr(cursor, "app", None)

assert layers == [
    "ServerErrorMiddleware",
    "ExceptionTelemetryMiddleware",
    "SecondUserMiddleware",
    "FirstUserMiddleware",
    "ExceptionMiddleware",
    "AsyncExitStackMiddleware",
    "APIRouter",
]
```

続いて、第 1 層（`NativeTelemetry`）と第 3 層（`ExceptionTelemetryMiddleware`）がスパン・メトリクス・例外ログをどのように協調記録するかについては、[NativeTelemetry と例外スパン記録](native_telemetry_internals.md)を参照してください。
