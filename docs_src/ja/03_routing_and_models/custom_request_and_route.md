# カスタム Request と APIRoute クラスの拡張

`APIRoute.get_route_handler()` と Starlette の `Request` をサブクラス化すると、ルーターのパス照合が成功した**直後**かつ FastAPI が JSON デコードや Pydantic 検証を実行する**直前**に処理を挟み込むことができ、ルーター単位での透過的 `gzip` 解凍・生バイト列に対する HMAC 署名検証・オペレーション別レイテンシ計測・構造化 `422` エラー拡張を実現できます。

```drawlib align=center code=hide file=custom_apiroute_interception.png caption="インターセプト境界の比較: グローバル ASGI ミドルウェアとルーター単位の APIRoute.get_route_handler()"
from drawlib.canvas import save, setup
from drawlib.icons import code, phosphor
from drawlib.lines import line
from drawlib.shapes import rectangle
from drawlib.smartarts import Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=174, height=96, dpi=150)

# Title Banner
code.fastapi((10.5, 90.5), width=5.2, style=Styles.Primary)
text(
    (16.0, 90.5),
    "Interception Architecture: Global ASGI Middleware vs Router-Scoped Custom APIRoute",
    style=Styles.DarkBold.patch(text_size=12.2, halign="left"),
)

# Lane A: Global ASGI Middleware (Pre-Routing)
p_asgi = Panel(
    "A. Global ASGI Middleware — Pre-Routing Transport Layer",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.globe,
    icon_style=Styles.DarkBold,
    header_height=8.0,
)
p_asgi.draw((5, 49), width=164, height=35)

asgi_steps = [
    (24.5, "1. Every Request", "Static files, /healthz\n& unmatched 404 scans", Styles.White, False),
    (64.5, "2. ASGI Middleware", "Raw (scope, receive)\nNo matched route yet", Styles.White, False),
    (104.5, "3. Router Scan", "Starlette iterates all\nMount & APIRoute rules", Styles.White, False),
    (144.5, "4. Scope Tradeoff", "Global cost; cannot wrap\none router's 422 errors", Styles.SecondaryNeutral, False),
]
for idx, (cx, st_title, st_sub, st_fill, _) in enumerate(asgi_steps):
    rectangle((cx, 62.5), width=33, height=16.0, style=st_fill.patch(shape_r=1.8))
    text((cx, 65.5), st_title, style=Styles.DarkBold.patch(text_size=10.4))
    text((cx, 60.0), st_sub, style=Styles.Dark.patch(text_size=10.0))
    if idx < len(asgi_steps) - 1:
        line((cx + 16.5, 62.5), (asgi_steps[idx + 1][0] - 16.5, 62.5), arrow_head="->", style=Styles.DarkBold)

# Lane B: APIRouter(route_class=CustomRoute) (Post-Match, Pre-Validation)
p_route = Panel(
    "B. APIRouter(route_class=CustomRoute) — Post-Match, Pre-Validation Hook",
    style=Styles.Neutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.0),
    icon=phosphor.git_branch,
    icon_style=Styles.White,
    header_height=8.0,
)
p_route.draw((5, 6), width=164, height=38)

route_steps = [
    (24.5, "1. Matched Route", "Fires ONLY on target\nAPIRouter endpoints", Styles.PrimaryNeutral, False),
    (64.5, "2. Custom Handler", "Swaps GzipRequest &\nverifies raw body HMAC", Styles.PrimaryFlat, True),
    (104.5, "3. original_handler", "Built-in route handler\nJSON + Depends + Model", Styles.White, False),
    (144.5, "4. 422 & Latency", "Catches ValidationError\n& sets X-Response-Time", Styles.SecondaryNeutral, False),
]
for idx, (cx, rt_title, rt_sub, rt_fill, is_focal) in enumerate(route_steps):
    rectangle((cx, 21.0), width=33, height=18.5, style=rt_fill.patch(shape_r=1.8))
    t_h = Styles.WhiteBold if is_focal else Styles.DarkBold
    t_b = Styles.White if is_focal else Styles.Dark
    text((cx, 24.4), rt_title, style=t_h.patch(text_size=10.4))
    text((cx, 18.2), rt_sub, style=t_b.patch(text_size=10.0))
    if idx < len(route_steps) - 1:
        arr_st = Styles.PrimaryBold if idx in (0, 1) else Styles.DarkBold
        line((cx + 16.5, 21.0), (route_steps[idx + 1][0] - 16.5, 21.0), arrow_head="->", style=arr_st)

save()
```

FastAPI で横断的関心事を実装する際は、ASGI ライフサイクルの**どの時点**で介入する必要があるか、そして**どの範囲のルーター**に適用すべきかに応じて拡張フックを選択します。

## 1. ASGI ミドルウェアと `APIRoute.get_route_handler()` のライフサイクル

`APIRouter` に登録される各パスオペレーションは `APIRoute` インスタンス（または `APIRouter(route_class=...)` に指定したカスタムサブクラス）を生成し、`self.get_route_handler()` を呼び出してリクエストハンドラを構築します。さらに子ルーターを `app.include_router()` で統合する際も、**ルーターのプレフィックスおよび依存関係の継承**が自動適用されたうえで統合先ごとに `get_route_handler()` が構築されるため、親ルーターから引き継いだ設定を含むハンドラを確実にラップでき、他の兄弟ルーターには一切影響を与えません。

FastAPI 標準のルートハンドラ内部における実行順序を理解すると、`Depends()` ではなくカスタム `APIRoute` が必要となる場面が明確になります。

1. **ボディ読み取りと JSON デコード（`await request.body()` / `await request.json()`）**が**最初**に実行され、JSON 構文が不正な場合は即座に `RequestValidationError(type="json_invalid")` が送出されます。
2. **依存関係の解決とパラメータ検証**はその**後**に実行されます。したがって、`Depends()` 関数では `request.json()` が失敗する前に `gzip` 圧縮ストリームを解凍することはできず、ボディやパラメータ検証が送出する `RequestValidationError` を捕捉することもできません。

| 比較軸 | グローバル純粋 ASGI ミドルウェア | `APIRouter(route_class=CustomRoute)` | `Depends()` / `Security()` |
| :--- | :--- | :--- | :--- |
| **実行タイミング** | ルーティング前（`404`・`/static`・全ルーターで常時実行） | ルート照合成功後、**JSON 解析および `Depends()` の直前** | FastAPI による JSON／Form 解析の**後** |
| **適用スコープの粒度** | `FastAPI` アプリ全体（またはマウントされたサブアプリ） | 対象の `APIRouter` サブツリーのみ（`route_class=...`） | アプリ・`APIRouter`・ルート `dependencies`・個別引数 |
| **`Request`（`body()`）の差し替え** | 低レベル ASGI `receive` ラッパーの手動実装が必要 | ネイティブ対応（`CustomRequest(request.scope, request.receive)`） | 不可（すでに `request.json()` が実行済み） |
| **`RequestValidationError` の捕捉** | 不可（アプリ全体の `@app.exception_handler` で処理） | **可能**（`try: await original_route_handler(request)` で捕捉） | 不可（エンドポイント実行前の検証段階で送出されるため） |
| **ルートメタデータへの参照** | ルーティング前のため `scope["route"]` 未確定 | `self.operation_id`・`self.path`・`self.tags`・`self.name` を直接参照 | `request.scope["route"]` 経由のみ |

## 2. 透過的 `GzipRequest`・`422` エラー拡張・Webhook HMAC 検証ルート

カスタム `Request` サブクラスとカスタム `APIRoute` を組み合わせることで、各エンドポイントの関数シグネチャを一切汚さずにストリーム変換や暗号学的署名検証を組み込めます。

```drawlib align=center code=hide file=gzip_and_hmac_route_pipeline.png caption="カスタム APIRoute の実行シーケンス: 上限付き GzipRequest 解凍・定数時間 HMAC-SHA256 検証・422 エラー拡張"
from drawlib.canvas import save, setup
from drawlib.diagrams.sequence import Participant, ParticipantGroup, PhosphorIcon, SequenceDiagram
from drawlib.icons import code
from drawlib.styles import Styles
from drawlib.text import text

setup(width=184, height=124, dpi=150)

# Title Banner
code.fastapi((10.5, 118.0), width=5.2, style=Styles.Primary)
text(
    (16.0, 118.0),
    "Custom APIRoute Runtime Sequence: Bounded GzipRequest + HMAC-SHA256 + 422 Wrapping",
    style=Styles.DarkBold.patch(text_size=12.2, halign="left"),
)

d = SequenceDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.3),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.White,
    autonumber=True,
    col_width=44.5,
    step_y=6.5,
)

client = d.add(
    Participant(
        "Webhook Client",
        width=26,
        height=13,
        icon=PhosphorIcon.CLOUD_ARROW_UP,
        icon_size=6.0,
        card_style=Styles.Neutral,
    )
)

router_grp = d.add(
    ParticipantGroup(
        title="APIRouter(route_class=CustomRoute)",
        padding=4.0,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=10.5, halign="left"),
    )
)
custom_route = router_grp.add(
    Participant(
        "Custom APIRoute",
        width=27,
        height=13,
        icon=PhosphorIcon.SHIELD_CHECK,
        icon_size=6.0,
        card_style=Styles.PrimaryNeutral,
    )
)
gzip_req = router_grp.add(
    Participant(
        "GzipRequest",
        width=25,
        height=13,
        icon=PhosphorIcon.FILE_ARCHIVE,
        icon_size=6.0,
    )
)
inner_handler = router_grp.add(
    Participant(
        "original_handler",
        width=30,
        height=13,
        icon=PhosphorIcon.CPU,
        icon_size=6.0,
        card_style=Styles.SecondaryNeutral,
    )
)

client.request(custom_route, "POST Content-Encoding: gzip + X-Hub-Signature")
custom_route.request(gzip_req, "Wrap scope & await request.body()")
gzip_req.reply(custom_route, "Gunzip (<=1 MiB cap) & cache bytes")
d.note(
    "hmac.compare_digest() & perf_counter()",
    over=[custom_route, gzip_req],
    style=Styles.PrimaryNeutral.patch(text_size=10.0),
)

with d.opt("Valid HMAC & <=1 MiB") as ok_blk:
    ok_blk.text_style = Styles.DarkBold.patch(text_size=10.0, halign="left")
    custom_route.request(inner_handler, "await original_route_handler(request)")
    inner_handler.request(gzip_req, "await request.json() [reuses cache]")
    gzip_req.reply(inner_handler, "Decompressed UTF-8 JSON")
    inner_handler.reply(custom_route, "200 Response or RequestValidationError")
    custom_route.reply(
        client,
        "200 / 422 JSON + X-Response-Time-Ms",
        style=Styles.PrimaryBold,
        text_style=Styles.PrimaryBold.patch(text_size=10.0),
    )

with d.opt("Invalid HMAC or >1 MiB") as err_blk:
    err_blk.text_style = Styles.Danger.patch(text_size=10.0, halign="left")
    custom_route.reply(
        client,
        "401 Bad HMAC / 413 Cap Exceeded",
        style=Styles.Danger,
        text_style=Styles.Danger.patch(text_size=10.0),
    )

d.draw(xy=(92.0, 55.0), align="center")
save()
```

### 上限付き `GzipRequest` と `GzipRoute` による透過解凍

Starlette の `Request.json()` は内部で `await self.body()` を呼び出し、読み取ったバイト列をリクエスト期間中メモリ上にキャッシュします。`GzipRequest` で `async def body(self) -> bytes` をオーバーライドし、無制限な `gzip.decompress()` ではなく `gzip.GzipFile.read(MAX_DECOMPRESSED_BYTES + 1)` で展開バイト数に上限を設けることで、gzip 圧縮爆弾（DoS）を `413 Content Too Large` で遮断しつつ、解凍済み UTF-8 JSON を `original_route_handler` へ透過的に引き渡せます。

```python
import gzip
import io
from typing import Any, Callable, Coroutine

from fastapi import APIRouter, FastAPI, HTTPException, Request, Response, status
from fastapi.routing import APIRoute
from pydantic import BaseModel

MAX_DECOMPRESSED_BYTES = 1024 * 1024  # 1 MiB decompression ceiling against zip bombs


class GzipRequest(Request):
    async def body(self) -> bytes:
        if not hasattr(self, "_body"):
            raw_body = await super().body()
            encodings = [
                token.strip().lower()
                for header in self.headers.getlist("Content-Encoding")
                for token in header.split(",")
            ]
            if "gzip" in encodings:
                try:
                    with gzip.GzipFile(fileobj=io.BytesIO(raw_body)) as gz_stream:
                        decompressed = gz_stream.read(MAX_DECOMPRESSED_BYTES + 1)
                except (OSError, EOFError) as exc:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Malformed gzip request stream",
                    ) from exc
                if len(decompressed) > MAX_DECOMPRESSED_BYTES:
                    raise HTTPException(
                        status_code=status.HTTP_413_CONTENT_TOO_LARGE,
                        detail="Decompressed payload exceeds 1 MiB limit",
                    )
                raw_body = decompressed
            self._body = raw_body
        return self._body


class GzipRoute(APIRoute):
    def get_route_handler(self) -> Callable[[Request], Coroutine[Any, Any, Response]]:
        original_route_handler = super().get_route_handler()

        async def custom_route_handler(request: Request) -> Response:
            gzip_request = GzipRequest(request.scope, request.receive)
            return await original_route_handler(gzip_request)

        return custom_route_handler


app = FastAPI(title="Telemetry Ingest API", version="1.0.0")
ingest_router = APIRouter(prefix="/ingest", route_class=GzipRoute)


class MetricBatch(BaseModel):
    service: str
    samples: list[float]


@ingest_router.post("/metrics")
async def ingest_metrics(batch: MetricBatch) -> dict[str, Any]:
    return {
        "service": batch.service,
        "count": len(batch.samples),
        "sum": sum(batch.samples),
    }


@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok"}


app.include_router(ingest_router)
```

### レイテンシ計測・構造化 `422` ラッピング・HMAC-SHA256 署名検証

Webhook 受信エンドポイントでは、JSON デシリアライズを実行する**前**に、受信した**生のバイト列**に対して定数時間比較 `hmac.compare_digest()` で `X-Hub-Signature-256` を検証する必要があります。これにより、偽造されたリクエストに対してスキーマ解析の CPU コストを消費したり内部検証エラーを漏洩したりすることなく `401 Unauthorized` で即座に拒否できます。さらに同じ `APIRoute` サブクラス内で `await original_route_handler(request)` をラップすれば、`X-Response-Time-Ms` ヘッダの付与と、正規送信元のスキーマ不整合（`RequestValidationError`）に対する `operation_id` および長さ制限付き生ボディプレビューを含む構造化 `422` 応答を同時に実装できます。

```python
import hashlib
import hmac
import logging
import os
import secrets
import time
from typing import Any, Callable, Coroutine

from fastapi import APIRouter, FastAPI, HTTPException, Request, Response, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.routing import APIRoute
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)


def load_webhook_secret() -> bytes:
    configured = os.environ.get("WEBHOOK_HMAC_SECRET")
    if configured:
        return configured.encode("utf-8")
    logger.warning("WEBHOOK_HMAC_SECRET unset; using ephemeral instance-isolated key")
    return secrets.token_bytes(32)


WEBHOOK_SECRET: bytes = load_webhook_secret()
MAX_PREVIEW_CHARS = 256


class HmacTimedRoute(APIRoute):
    def get_route_handler(self) -> Callable[[Request], Coroutine[Any, Any, Response]]:
        original_route_handler = super().get_route_handler()
        operation_id = self.operation_id or self.name

        async def custom_route_handler(request: Request) -> Response:
            started = time.perf_counter()

            # 1. Verify HMAC-SHA256 over raw bytes BEFORE Pydantic parses JSON
            raw_body = await request.body()
            provided_sig = request.headers.get("X-Hub-Signature-256", "")
            expected_sig = (
                "sha256="
                + hmac.new(WEBHOOK_SECRET, raw_body, hashlib.sha256).hexdigest()
            )
            if not hmac.compare_digest(expected_sig, provided_sig):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid or missing X-Hub-Signature-256 header",
                )

            # 2. Execute inner FastAPI handler & catch RequestValidationError
            try:
                response = await original_route_handler(request)
            except RequestValidationError as exc:
                elapsed_ms = (time.perf_counter() - started) * 1000.0
                preview = raw_body.decode("utf-8", errors="replace")[:MAX_PREVIEW_CHARS]
                return JSONResponse(
                    status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                    content={
                        "operation_id": operation_id,
                        "detail": exc.errors(),
                        "raw_body_preview": preview,
                    },
                    headers={"X-Response-Time-Ms": f"{elapsed_ms:.2f}"},
                )

            elapsed_ms = (time.perf_counter() - started) * 1000.0
            response.headers["X-Response-Time-Ms"] = f"{elapsed_ms:.2f}"
            return response

        return custom_route_handler


app = FastAPI(title="Signed Webhook Receiver", version="1.0.0")
webhook_router = APIRouter(prefix="/webhooks", route_class=HmacTimedRoute)


class PaymentDeliveredEvent(BaseModel):
    event_id: str
    invoice_id: str
    amount_cents: int = Field(gt=0)


@webhook_router.post("/payments")
async def receive_payment_webhook(
    event: PaymentDeliveredEvent,
) -> dict[str, Any]:
    return {"accepted": True, "event_id": event.event_id}


app.include_router(webhook_router)
```

> [!TIP]
> `await request.body()` は読み取った生バイト列を `Request` インスタンス上のメモリにキャッシュするため、`HmacTimedRoute` 内で先に `await request.body()` を呼び出しても後続の `original_route_handler(request)` で ASGI ストリームが枯渇することはなく、標準ルートハンドラはキャッシュ済みのバイト列を即座に再利用します。ただし数メガバイト規模のマルチパートファイルアップロード（`request.stream()` から `SpooledTemporaryFile` へ逐次書き出すルート）では、メモリ一括展開を避けるため `Request.body()` の事前読み取りを行わないルーターへ分離してください。

以上で第 3 章（[Path・Query・Header・Cookie・Body](parameters_and_validation.md)、[レスポンス直列化と OpenAPI 3.1](responses_and_openapi.md)、[パラメータモデル合成・特殊型・例示](advanced_types_and_models.md)、および本ページ）のルーティング・モデル基盤が完結します。続いて第 4 章の [依存グラフ・キャッシュ・yield スコープ](../04_dependencies_and_security/dependency_injection.md)、トランスポート層ミドルウェアを扱う [ASGI ミドルウェアとスレッドプール制御](../05_async_and_realtime/concurrency_and_middleware.md)、アプリ全体の例外ハンドラを扱う [ネイティブ OpenTelemetry と例外処理](../06_observability_and_testing/telemetry_and_errors.md)、および `@app.webhooks` スキーマ文書化を扱う [Webhooks・Callbacks・SDK 生成・Docs UI](../07_frontend_and_openapi_ext/webhooks_callbacks_sdks.md) へ進んでください。
