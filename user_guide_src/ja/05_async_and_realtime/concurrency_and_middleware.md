# ASGI ミドルウェアとスレッドプール制御

FastAPI `v0.162.2` は、すべての HTTP リクエストおよび WebSocket 接続を決定論的な 7 層の ASGI ミドルウェアオニオン構造で処理しつつ、`async def` コルーチンはシングルスレッドの AnyIO イベントループ上で直接実行し、通常の `def` 関数は上限付きワーカースレッドプールへ安全にオフロードします。

```drawlib align=center code=hide file=asgi_middleware_onion.png caption="FastAPI v0.162.2 の 7 層 ASGI ミドルウェアオニオン構造（OpenTelemetry 外殻スパンからエンドポイント実行まで）"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.lines import line
from drawlib.shapes import rectangle
from drawlib.styles import Colors, Styles
from drawlib.text import text

setup(width=176, height=98)

text(
    (88.0, 93.0),
    "FastAPI v0.162.2 Seven-Layer ASGI Middleware Onion (Outer to Inner)",
    style=Styles.DarkBold.patch(text_size=13.0),
)

# 7 Concentric ASGI Layers (outermost L1 -> innermost L7 core)
layers = [
    (88.0, 45.0, 132.0, 80.0, Styles.Neutral.patch(line_style="dashed", shape_r=2.5),
     81.0, "1. OpenTelemetry Outer Span  •  W3C Context, Root Span & Metrics", Styles.DarkBold),
    (88.0, 42.2, 122.0, 69.0, Styles.White.patch(shape_r=2.2, shape_line_color=Colors.Gray5),
     72.5, "2. Unhandled 500 Boundary  •  @app.exception_handler(500) Fallback", Styles.DarkBold),
    (88.0, 39.4, 112.0, 58.0, Styles.PrimaryNeutral.patch(shape_r=2.0),
     64.0, "3. Inner Exception Span Recorder  •  OTel Error Log Before 500", Styles.PrimaryBold),
    (88.0, 36.6, 102.0, 47.0, Styles.SecondaryNeutral.patch(shape_r=2.0),
     55.5, "4. User Middleware (LIFO)  •  TrustedHost, CORS & Pure ASGI Wrappers", Styles.SecondaryBold),
    (88.0, 33.8, 92.0, 36.0, Styles.White.patch(shape_r=1.8, shape_line_color=Colors.Gray5),
     47.0, "5. Handled Error Boundary  •  HTTPException, 422 & Custom", Styles.DarkBold),
    (88.0, 31.0, 82.0, 25.0, Styles.PrimaryNeutral.patch(shape_r=1.8),
     38.5, "6. Request Resource Cleanup  •  Closes Form & UploadFile", Styles.PrimaryBold),
]

for cx, cy, w, h, box_style, label_y, label, txt_style in layers:
    rectangle((cx, cy), width=w, height=h, style=box_style)
    text((cx, label_y), label, style=txt_style.patch(text_size=10.2))

# Core Layer 7: Routing & Endpoint Execution
rectangle((88.0, 26.5), width=66.0, height=13.0, style=Styles.PrimaryFlat.patch(shape_r=1.8))
phosphor.cpu((60.0, 26.5), width=5.2, style=Styles.WhiteBold)
text(
    (91.0, 26.5),
    "7. Router & Endpoint\nDepends() • Endpoint • Validation",
    style=Styles.WhiteBold.patch(text_size=10.5),
)

# Inbound ASGI Request & Outbound ASGI Response arrows piercing into the core
line((3.5, 26.5), (54.5, 26.5), arrow_head="->", style=Styles.PrimaryBold.patch(line_width=2.0))
rectangle((21.0, 34.0), width=33.0, height=9.0, style=Styles.White.patch(shape_r=1.5, shape_line_color=Colors.Gray5))
text((21.0, 34.0), "Inbound ASGI\nscope + receive()", style=Styles.DarkBold.patch(text_size=10.0))

line((121.5, 26.5), (172.5, 26.5), arrow_head="->", style=Styles.SecondaryBold.patch(line_width=2.0))
rectangle((155.0, 34.0), width=33.0, height=9.0, style=Styles.White.patch(shape_r=1.5, shape_line_color=Colors.Gray5))
text((155.0, 34.0), "Outbound ASGI\nsend(start / body)", style=Styles.DarkBold.patch(text_size=10.0))

save()
```

## 1. 7 層から成る ASGI ミドルウェアオニオン

Uvicorn などの ASGI サーバーが受信した HTTP リクエストや WebSocket ハンドシェイクを処理する際、FastAPI は決定論的な 7 層の ASGI ミドルウェアパイプラインへ順番に処理を渡します。この正確なネスト順序を把握しておくことで、`500` エラー時の CORS ヘッダー欠落、OpenTelemetry の例外ログ相関、`contextvars` の伝播境界にまつわるバグを未然に防げます。

| レイヤー（外側から内側） | 公開 API / 機構 | `v0.162.2` における主な責務 |
| :--- | :--- | :--- |
| **1. OpenTelemetry 外殻スパン** | `FastAPI(telemetry=...)` | W3C `traceparent`/`baggage` の抽出、ルート HTTP/WebSocket スパンの開始、アクティブ接続数の計測、およびリクエストテレメトリコンテキスト（`get_telemetry_data()`）の保持を行います。 |
| **2. 未処理 500 防衛境界** | `@app.exception_handler(500)` / `Exception` | カスタム `500` ハンドラーを実行し、内側の層から漏れた予期せぬ例外に対して安全な `500 Internal Server Error` 応答を保証します。 |
| **3. 内側例外スパン記録** | `TelemetryConfig`（`logs=True`） | 外側の `500` 境界が HTTP 応答へ変換する**直前**に未処理例外をアクティブスパンへ記録し、構造化された OTel `ERROR` ログイベントを送出します。 |
| **4. ユーザーミドルウェア群** | `app.add_middleware(...)` / `@app.middleware("http")` | `CORSMiddleware`、`TrustedHostMiddleware`、`GZipMiddleware`、純粋 ASGI クラスなどを **LIFO（後入れ先出し）順** で実行します（最後に追加したミドルウェアが最も外側を包みます）。 |
| **5. 制御されたエラー境界** | `@app.exception_handler(...)` | `HTTPException`、`RequestValidationError`（`422`）、`WebSocketRequestValidationError`（`1008`）、およびカスタムドメイン例外ハンドラーを捕捉します。 |
| **6. リクエストリソース解放** | `Form` / `UploadFile` ライフサイクル | すべてのユーザーミドルウェアの**内側**かつ同一の `contextvars` スコープ内で、`Form` や `UploadFile` の一時ファイルハンドルを確実にクローズします。 |
| **7. ルーター & エンドポイント実行** | `APIRouter` / `Depends()` | ボディ読取、[依存性注入（DI）](../04_dependencies_and_security/dependency_injection.md)の解決（ストリーム終了後のリクエストスコープ解放を含む）、エンドポイント実行、レスポンス検証、および `BackgroundTasks` の予約を行います。 |

### 純粋な ASGI ミドルウェア vs `BaseHTTPMiddleware`

`@app.middleware("http")`（内部的に Starlette の `BaseHTTPMiddleware` を使用）は、リクエストごとに追加の AnyIO タスクグループを生成して `contextvars` のコピー境界を作るため、高スループットな [SSE や JSONL ストリーミング](sse_websockets_streaming.md) ではオーバーヘッドや制約が生じやすくなります。処理時間計測、相関 ID 付与、テナント検証、セキュリティヘッダー注入などの横断的関心事には、レスポンスボディを一切バッファリングせず `http.response.start` を直接フックする **純粋な ASGI ミドルウェアクラス** の採用が推奨されます。

```python
from time import perf_counter

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.testclient import TestClient
from starlette.types import ASGIApp, Message, Receive, Scope, Send


class ProcessTimeMiddleware:
    """Zero-buffering pure ASGI middleware that injects X-Process-Time-Ms."""

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        started = perf_counter()

        async def send_with_timing(message: Message) -> None:
            if message["type"] == "http.response.start":
                elapsed_ms = (perf_counter() - started) * 1000.0
                raw_headers = list(message.get("headers", []))
                raw_headers.append(
                    (b"x-process-time-ms", f"{elapsed_ms:.2f}".encode("latin-1"))
                )
                message = {**message, "headers": raw_headers}
            await send(message)

        await self.app(scope, receive, send_with_timing)


app = FastAPI()

# LIFO wrapping order: TrustedHost (outer) -> CORS -> ProcessTime (inner)
app.add_middleware(ProcessTimeMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://app.example.com"],
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type"],
)
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["api.example.com", "testserver"],
)


@app.get("/ping")
async def ping() -> dict[str, str]:
    return {"status": "ok"}


client = TestClient(app)
res = client.get("/ping", headers={"Origin": "https://app.example.com"})
assert res.status_code == 200
assert "x-process-time-ms" in res.headers
```

> **未処理 500 エラー時の CORS ヘッダー**: 未処理 `500` 防衛境界（第 2 層）は `app.add_middleware(...)` で追加したユーザーミドルウェア群（第 4 層）の**外側**に位置するため、第 2 層で生成されるデフォルトの `500` レスポンスは `CORSMiddleware` を通過しません。ブラウザ向けに一貫したオリジン制御が必要な場合は、`@app.exception_handler(Exception)` を定義するかリバースプロキシ側で許可オリジンを明示し、認証付き API で `allow_origins=["*"]` を絶対に使用しないでください。

---

## 2. イベントループ vs ワーカースレッドプールと `BackgroundTasks`

FastAPI はルート登録時に関数シグネチャを検査し、イベントループ上での直接実行（`async def`）と AnyIO ワーカースレッドプールへの委譲（`def`）を自動的に振り分けます。

```drawlib align=center code=hide file=event_loop_vs_threadpool.png caption="実行経路の分岐：シングルスレッド イベントループ vs AnyIO ワーカースレッドプールと BackgroundTasks"
from drawlib.canvas import save, setup
from drawlib.diagrams.flow import Decision, End, FlowDiagram, Process, Start
from drawlib.styles import Styles
from drawlib.text import text

setup(width=166, height=94)

text(
    (83.0, 89.5),
    "FastAPI Concurrency Routing: async def vs plain def & BackgroundTasks",
    style=Styles.DarkBold.patch(text_size=13.0),
)

node_txt = Styles.DarkBold.patch(text_size=10.2)

flow = FlowDiagram(
    node_style=Styles.Neutral.patch(text_size=10.2),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.DarkBold.patch(text_size=10.0),
    width=158,
    height=80,
    lane_orientation="vertical",
)

# 3 Vertical Swimlanes: widths 54 + 54 + 50 = 158 (centerlines X = 27, 81, 133)
flow.add_lane(
    "AnyIO Event Loop (1 Thread)",
    width=54,
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral,
    text_style=Styles.PrimaryBold.patch(text_size=10.5),
    header_size=7.0,
)
flow.add_lane(
    "Worker Threadpool (40 Tokens)",
    width=54,
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.SecondaryBold.patch(text_size=10.5),
    header_size=7.0,
)
flow.add_lane(
    "Post-Response Lifecycle",
    width=50,
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral,
    text_style=Styles.PrimaryBold.patch(text_size=10.5),
    header_size=7.0,
)

start = flow.add(
    Start("Incoming ASGI Request", width=38, height=8.5, style=Styles.PrimaryFlat, text_style=Styles.WhiteBold.patch(text_size=10.2)),
    xy=(27, 66),
)
dispatch = flow.add(
    Decision("Callable\nSignature?", width=34, height=13.5, style=Styles.PrimaryNeutral, text_style=node_txt),
    xy=(27, 49),
)
async_exec = flow.add(
    Process("Await Coroutine Directly\n(Non-Blocking Async I/O)", width=44, height=11.5, style=Styles.White, text_style=node_txt),
    xy=(27, 30.5),
)
pool_enter = flow.add(
    Process("Worker Threadpool Execution\n(Sync def & yield Deps)", width=43, height=11.5, style=Styles.SecondaryNeutral, text_style=node_txt),
    xy=(81, 49),
)
sync_exec = flow.add(
    Process("Run Sync DB Driver /\nBlocking File or CPU Helper", width=43, height=11.5, style=Styles.White, text_style=node_txt),
    xy=(81, 30.5),
)
merge = flow.junction((27, 19.5))
send_resp = flow.add(
    Process("Validate & Send Response\n(HTTP Response Complete)", width=44, height=11.0, style=Styles.PrimaryNeutral, text_style=node_txt),
    xy=(27, 9.5),
)
bg_tasks = flow.add(
    Process("Run BackgroundTasks\n(Traced Sequentially)", width=41, height=11.5, style=Styles.White, text_style=node_txt),
    xy=(133, 30.5),
)
done = flow.add(
    End("ASGI Scope Closed", width=36, height=9.0, style=Styles.SecondaryFlat, text_style=Styles.WhiteBold.patch(text_size=10.2)),
    xy=(133, 9.5),
)

start.connect(dispatch, padding=0.8)
dispatch.connect(async_exec, label="async def", start_side="bottom", end_side="top", padding=0.8)
dispatch.connect(pool_enter, label="plain def", start_side="right", end_side="left", padding=0.8)
pool_enter.connect(sync_exec, padding=0.8)
async_exec.connect(merge, start_side="bottom", padding=(0.8, 0.0))
sync_exec.connect(merge, start_side="bottom", padding=(0.8, 0.0)).via((81, 19.5))
merge.connect(send_resp, end_side="top", padding=(0.0, 0.8))
send_resp.connect(bg_tasks, label="After send()", start_side="right", end_side="left", padding=0.8).via((106.5, 9.5), (106.5, 30.5))
bg_tasks.connect(done, padding=0.8)

flow.draw(xy=(4.0, 4.0))
save()
```

### FastAPI 並行実行の 3 原則

1. **`async def` はイベントループ上で直接動作する**: 非同期ネイティブドライバ（`httpx.AsyncClient`、`asyncpg`、`redis.asyncio`、`anyio` など）を `await` する場合は `async def` を使用します。**`async def` の内部で同期ブロッキング関数（`time.sleep()`、`requests.get()`、同期 ORM クエリ、重い CPU ループ）を直接呼び出してはなりません**。呼び出すとワーカープロセス全体のイベントループが停止し、他の同時接続リクエストがすべてフリーズします。
2. **通常の `def` と同期 `yield` 依存関係はスレッドプールで実行される**: 通常の `def` エンドポイントや同期 `yield` 依存関数は、AnyIO のデフォルト `40` トークン（`CapacityLimiter`）で制御されたワーカースレッドプール上で前処理・後処理ともに安全に実行されます。`async def` エンドポイント内から一部の同期ヘルパーだけを呼びたい場合は、`await run_in_threadpool(fn, *args)` で明示的にオフロードします。
3. **`BackgroundTasks` はレスポンス送信完了後に順次実行される**: `BackgroundTasks` に登録された処理は、クライアントへ HTTP レスポンスを返し終えた後に `fastapi.background_task` の [OpenTelemetry スパン](../06_observability_and_testing/telemetry_and_errors.md) 付きで順次実行されます。監査ログ記録やキャッシュ更新などの軽量なベストエフォート処理に限定し、再試行保証や長時間ジョブには外部の永続ジョブキューを併用してください。

```python
from collections.abc import Iterator
from typing import Annotated

import anyio
from fastapi import BackgroundTasks, Depends, FastAPI, status
from fastapi.testclient import TestClient
from starlette.concurrency import run_in_threadpool

app = FastAPI()
audit_log: list[str] = []


def compute_digest_sync(payload: str) -> str:
    return f"len:{len(payload)}"


def get_sync_session() -> Iterator[str]:
    # Entered & exited safely on the worker threadpool
    audit_log.append("session:open")
    try:
        yield "tx-101"
    finally:
        audit_log.append("session:close")


@app.get("/reports/sync")
def read_sync_report(
    tx_id: Annotated[str, Depends(get_sync_session)],
) -> dict[str, str]:
    return {"tx_id": tx_id, "summary": compute_digest_sync("quarterly-ledger")}


@app.post("/reports/async", status_code=status.HTTP_202_ACCEPTED)
async def submit_async_report(
    payload: str,
    tasks: BackgroundTasks,
) -> dict[str, str]:
    digest = await run_in_threadpool(compute_digest_sync, payload)
    await anyio.sleep(0)
    tasks.add_task(audit_log.append, f"audit:{digest}")
    return {"accepted": digest}


client = TestClient(app)
assert client.get("/reports/sync").json() == {"tx_id": "tx-101", "summary": "len:16"}
assert client.post("/reports/async", params={"payload": "hello"}).status_code == 202
assert audit_log == ["session:open", "session:close", "audit:len:5"]
```

次節の [ネイティブ SSE・JSONL・WebSocket](sse_websockets_streaming.md) では、この非同期実行基盤の上に構築された 3 つのリアルタイム配信・双方向通信プリミティブを詳しく解説します。
