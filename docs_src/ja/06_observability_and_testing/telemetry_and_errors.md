# ネイティブ OpenTelemetry と例外処理

FastAPI `v0.162.2` は、外部モンキーパッチ不要のネイティブ OpenTelemetry 計装（`fastapi.telemetry` の `TelemetryConfig` と `get_telemetry_data()`）を本体に組み込み、クライアント起因の `4xx` / `422` エラーとサーバー側の契約違反である `500` エラーを 2 段階の例外境界で明確に分離します。

```drawlib align=center code=hide file=native_otel_architecture.png caption="FastAPI v0.162.2 ネイティブ OpenTelemetry パイプライン：ルートスパン・4 つの子操作スパン・コンテキスト参照"
from drawlib.canvas import save, setup
from drawlib.diagrams.architecture import ArchitectureDiagram, Node, NodeGroup, PhosphorIcon
from drawlib.styles import Styles
from drawlib.text import text

setup(width=182, height=104)

text(
    (91.0, 99.0),
    "FastAPI v0.162.2 Native Telemetry Pipeline (fastapi.telemetry)",
    style=Styles.DarkBold.patch(text_size=13.2),
)

d = ArchitectureDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.2),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.DarkBold.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
)

caller = d.add(
    Node("Caller\n(traceparent)", width=24, height=18, icon=PhosphorIcon.GLOBE, icon_size=7.0),
    xy=(13.0, 52.0),
)

# Central FastAPI Runtime Group (bottom-left at (32, 4))
runtime = d.add(
    NodeGroup(
        title="FastAPI TelemetryConfig",
        padding=5.5,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=10.8, halign="left"),
    ),
    xy=(32.0, 4.0),
)

root_span = runtime.add(
    Node(
        "Root Server Span\nGET /orders/{order_id}",
        width=34,
        height=17,
        icon=PhosphorIcon.ACTIVITY,
        icon_size=7.0,
        card_style=Styles.PrimaryFlat,
        style=Styles.WhiteBold,
        text_style=Styles.WhiteBold.patch(text_size=10.2),
    ),
    xy=(22.5, 58.0),
)

ctx_reader = runtime.add(
    Node(
        "get_telemetry_data()\nrequest • body • values",
        width=34,
        height=17,
        icon=PhosphorIcon.DATABASE,
        icon_size=7.0,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(22.5, 20.0),
)

# Nested Operation Spans Group inside runtime (global left = 32 + 52 = 84)
ops = runtime.add(
    NodeGroup(
        title="operation_spans=True",
        padding=4.5,
        style=Styles.White,
        text_style=Styles.PrimaryBold.patch(text_size=10.5, halign="left"),
    ),
    xy=(52.0, 5.0),
)
s_dep = ops.add(Node("fastapi.dependencies", width=34, height=10.5, card_style=Styles.PrimaryNeutral), xy=(21.5, 56.5))
s_end = ops.add(Node("fastapi.endpoint", width=34, height=10.5, card_style=Styles.Neutral), xy=(21.5, 41.5))
s_ser = ops.add(Node("fastapi.serialization", width=34, height=10.5, card_style=Styles.Neutral), xy=(21.5, 26.5))
s_bg = ops.add(Node("fastapi.background_task", width=34, height=10.5, card_style=Styles.SecondaryNeutral), xy=(21.5, 11.5))

# Right OpenTelemetry SDK Providers Group
otel_sdk = d.add(
    NodeGroup(
        title="OpenTelemetry SDK",
        padding=5.0,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=10.8, halign="left"),
    ),
    xy=(138.0, 9.0),
)
p_trace = otel_sdk.add(
    Node("TracerProvider\nSpans & Status", width=26, height=16, icon=PhosphorIcon.TREE_STRUCTURE, icon_size=6.5, card_style=Styles.PrimaryNeutral),
    xy=(18.0, 56.0),
)
p_meter = otel_sdk.add(
    Node("MeterProvider\nduration & active", width=26, height=16, icon=PhosphorIcon.CHART_BAR, icon_size=6.5),
    xy=(18.0, 34.0),
)
p_logs = otel_sdk.add(
    Node("LoggerProvider\n422 WARN / 500 ERR", width=26, height=16, icon=PhosphorIcon.WARNING_CIRCLE, icon_size=6.5, card_style=Styles.SecondaryNeutral),
    xy=(18.0, 12.0),
)

d.connect(caller, root_span, padding=1.2)
d.connect(root_span, ctx_reader, label="Context", padding=1.2)
j_root = d.junction((78.0, 62.0))
d.connect(root_span, j_root, arrow="-", padding=(1.2, 0.0))
j_rows = [d.junction((78.0, gy)) for gy in (65.5, 50.5, 35.5, 20.5)]
d.connect(j_root, j_rows[0], arrow="-")
d.connect(j_root, j_rows[1], arrow="-")
d.connect(j_rows[1], j_rows[2], arrow="-")
d.connect(j_rows[2], j_rows[3], arrow="-")
for j_row, child_span in zip(j_rows, (s_dep, s_end, s_ser, s_bg)):
    d.connect(j_row, child_span, padding=(0.0, 1.2))
d.connect(s_dep, p_trace, padding=1.2)
d.connect(s_ser, p_meter, padding=1.2)
d.connect(s_bg, p_logs, padding=1.2)

d.draw(xy=(3.0, 3.0))
save()
```

## 1. ネイティブ `fastapi.telemetry` のアーキテクチャ

従来の外部 ASGI ミドルウェアによる計装では生の ASGI メッセージしか観測できず、依存性注入や Pydantic 直列化、入力検証エラーの内訳までは追跡できませんでした。FastAPI `v0.162.2` では `FastAPI(telemetry=TelemetryConfig(...))` を渡すだけで、OpenTelemetry セマンティック規約（`1.44.0`）に準拠した詳細なシグナルがネイティブに出力されます。

1. **ルート HTTP / WebSocket スパン（`tracing=True`）**: W3C `traceparent` と `baggage` を抽出し、署名付き URL クエリ（`sig`、`X-Amz-Signature`、`X-Goog-Signature` など）を自動マスクした上で、ルート確定時にスパン名を `"{METHOD} {http.route}"`（例: `GET /orders/{order_id}`）へ更新します。
2. **4 つの子操作スパン（`operation_spans=True`）**: リクエスト処理の各フェーズを専用の子スパンで個別に計測します。
   - `fastapi.dependencies`: `Depends()` 依存グラフ全体の解決時間。
   - `fastapi.endpoint`: エンドポイント実行時間（`async def` コルーチンの `await` またはワーカースレッドプール実行）。
   - `fastapi.serialization`: レスポンス検証（`response_model`）および Pydantic の Rust 製 JSON 直列化時間。
   - `fastapi.background_task`: [`BackgroundTasks`](../05_async_and_realtime/concurrency_and_middleware.md) 内の各バックグラウンド処理。
3. **メトリクスと構造化ログ（`metrics=True`, `logs=True`）**: `http.server.request.duration` ヒストグラムと `http.server.active_requests` カウンターを記録し、`422` 入力検証失敗時には `WARN` イベント（`fastapi.validation.failed`）、未処理例外時には `ERROR` イベント（`http.server.request.exception`）を送出します。
4. **同期コンテキスト参照（`get_telemetry_data()`）**: リクエスト処理中に限り、読み取り専用の `TelemetryData`（`request`、`websocket`、`body`、`values`、`errors`）をカスタム SpanProcessor / LogProcessor 等から安全に参照できます。生ペイロードをデフォルトで外部エクスポートせず、レスポンス完了と同時にコンテキスト参照を即座にクリアしてメモリリークを防ぎます。

```python
from typing import Annotated

from fastapi import BackgroundTasks, Depends, FastAPI, Header
from fastapi.telemetry import TelemetryConfig, get_telemetry_data
from fastapi.testclient import TestClient
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter
from pydantic import BaseModel

exporter = InMemorySpanExporter()
provider = TracerProvider()
provider.add_span_processor(SimpleSpanProcessor(exporter))

telemetry_cfg: TelemetryConfig = {
    "tracer_provider": provider,
    "tracing": True,
    "operation_spans": True,
    "metrics": False,
    "logs": False,
    "exclude": lambda scope: scope.get("path") == "/healthz",
}
app = FastAPI(title="Orders Service", telemetry=telemetry_cfg)


class OrderOut(BaseModel):
    order_id: int
    tenant: str
    traced_route: bool


async def resolve_tenant(x_tenant: Annotated[str, Header()] = "acme") -> str:
    return x_tenant


@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/orders/{order_id}", response_model=OrderOut)
async def get_order(
    order_id: int,
    tenant: Annotated[str, Depends(resolve_tenant)],
    tasks: BackgroundTasks,
) -> OrderOut:
    tdata = get_telemetry_data()
    has_context = (
        tdata is not None
        and tdata.request is not None
        and tdata.values is not None
    )
    tasks.add_task(lambda: None)
    return OrderOut(order_id=order_id, tenant=tenant, traced_route=has_context)


client = TestClient(app)
assert client.get("/healthz").status_code == 200
assert len(exporter.get_finished_spans()) == 0  # Excluded via scope filter

res = client.get("/orders/99", headers={"X-Tenant": "globex"})
assert res.json()["traced_route"] is True

span_names = {s.name for s in exporter.get_finished_spans()}
assert {
    "GET /orders/{order_id}",
    "fastapi.dependencies",
    "fastapi.endpoint",
    "fastapi.serialization",
    "fastapi.background_task",
}.issubset(span_names)
```

---

## 2. 例外階層と RFC 9457 エラーエンベロープ設計

FastAPI は [ASGI ミドルウェアオニオン](../05_async_and_realtime/concurrency_and_middleware.md) の中で、例外処理を意図的に **2 つの異なるミドルウェア境界** に分割しています。

```drawlib align=center code=hide file=exception_hierarchy_routing.png caption="FastAPI の例外ルーティング：制御されたクライアントエラー（4xx / 422）と内側例外スパン記録・外側 500 フォールバック"
from drawlib.canvas import save, setup
from drawlib.diagrams.flow import End, FlowDiagram, Process
from drawlib.styles import Styles
from drawlib.text import text

setup(width=170, height=92)

text(
    (85.0, 87.5),
    "FastAPI Exception Routing: Handled Client Errors vs Server Contract Breaches",
    style=Styles.DarkBold.patch(text_size=13.0),
)

node_txt = Styles.DarkBold.patch(text_size=10.2)

flow = FlowDiagram(
    node_style=Styles.Neutral.patch(text_size=10.2),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.DarkBold.patch(text_size=10.0),
    width=162,
    height=78,
    lane_orientation="vertical",
)

# 3 Swimlanes: 54 + 54 + 54 = 162 (centerlines X = 27, 81, 135)
flow.add_lane(
    "1. Endpoint & Validation",
    width=54,
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral,
    text_style=Styles.PrimaryBold.patch(text_size=10.5),
    header_size=7.0,
)
flow.add_lane(
    "2. Handled Error Boundary",
    width=54,
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.SecondaryBold.patch(text_size=10.5),
    header_size=7.0,
)
flow.add_lane(
    "3. Outer 500 & Telemetry",
    width=54,
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral,
    text_style=Styles.PrimaryBold.patch(text_size=10.5),
    header_size=7.0,
)

req_val = flow.add(
    Process("RequestValidationError\n(Invalid Input / Body)", width=41, height=13, style=Styles.White, text_style=node_txt),
    xy=(27, 59),
)
dom_err = flow.add(
    Process("HTTPException or\nCustom Domain Error", width=41, height=13, style=Styles.White, text_style=node_txt),
    xy=(27, 37),
)
resp_val = flow.add(
    Process("ResponseValidationError\nor Unhandled Exception", width=41, height=13, style=Styles.SecondaryNeutral, text_style=node_txt),
    xy=(27, 15),
)

h_422 = flow.add(
    Process("422 Problem JSON\n(+ OTel WARN Event)", width=41, height=13, style=Styles.PrimaryNeutral, text_style=node_txt),
    xy=(81, 59),
)
h_4xx = flow.add(
    Process("4xx / 409 JSON\n(Span Not Marked 500)", width=41, height=13, style=Styles.White, text_style=node_txt),
    xy=(81, 37),
)

otel_err = flow.add(
    Process("Inner Exception Recorder\n(OTel ERROR Log + Span Error)", width=45, height=14, style=Styles.PrimaryNeutral, text_style=node_txt),
    xy=(135, 42),
)
srv_500 = flow.add(
    End("Outer 500 Fallback Guard\n(Safe 500 Response)", width=45, height=13, style=Styles.PrimaryFlat, text_style=Styles.WhiteBold.patch(text_size=10.2)),
    xy=(135, 15),
)

req_val.connect(h_422, label="422", padding=1.0)
dom_err.connect(h_4xx, label="4xx", padding=1.0)
resp_val.connect(otel_err, label="Bypasses 4xx", start_side="right", end_side="left", padding=1.0).via((104, 15), (104, 42))
otel_err.connect(srv_500, label="Re-raises", start_side="bottom", end_side="top", padding=1.0)

flow.draw(xy=(4.0, 4.0))
save()
```

### なぜ `ResponseValidationError` は `422` ではなく `500` になるのか

- **クライアント起因のエラー（`RequestValidationError` -> `422`、`HTTPException` -> `4xx`）**: 内側の制御されたエラー境界（`@app.exception_handler(...)`）で捕捉されます。サーバー自体は仕様どおり正常動作しているため、FastAPI はルートスパンを `500` 異常扱いにせず、入力検証失敗は `WARN` イベントとして記録します。
- **サーバー側の出力契約違反（`ResponseValidationError` -> `500`）**: バックエンド実装が `response_model` の必須フィールド欠落や型不一致データを返した場合、`ResponseValidationError` が発生します。これはクライアントの誤りではなく **サーバー実装のバグ** であるため、`4xx` 例外ハンドラーを素通りして内側の例外スパン記録（`StatusCode.ERROR` とスタックトレースログ）および外側の `500` 防衛境界へ到達し、内部データの漏洩を防ぎつつ CI テストで即座に検知できるよう設計されています。

### RFC 9457（`application/problem+json`）によるエラー応答の標準化

複数チームが開発する大規模 API では、ドメイン固有例外と `RequestValidationError` にカスタムハンドラーを登録し、内部スタックトレースや DB エラー詳細を外部へ漏らさず機械可読な **RFC 9457 Problem Details** 形式に統一します。

```python
from typing import Annotated, Any

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError, ResponseValidationError
from fastapi.responses import JSONResponse
from fastapi.testclient import TestClient
from pydantic import BaseModel, Field
import pytest

app = FastAPI()


class InsufficientInventoryError(Exception):
    def __init__(self, sku: str, requested: int, available: int) -> None:
        self.sku = sku
        self.requested = requested
        self.available = available


@app.exception_handler(InsufficientInventoryError)
async def inventory_error_handler(
    request: Request, exc: InsufficientInventoryError
) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_409_CONFLICT,
        media_type="application/problem+json",
        content={
            "type": "https://api.example.com/problems/insufficient-inventory",
            "title": "Insufficient Inventory",
            "status": 409,
            "detail": f"SKU '{exc.sku}' has {exc.available} units; {exc.requested} requested.",
            "instance": request.url.path,
        },
    )


@app.exception_handler(RequestValidationError)
async def validation_problem_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    fields = [
        {"loc": ".".join(str(p) for p in err["loc"]), "msg": err["msg"]}
        for err in exc.errors()
    ]
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
        media_type="application/problem+json",
        content={
            "type": "https://api.example.com/problems/invalid-parameters",
            "title": "Request Validation Failed",
            "status": 422,
            "instance": request.url.path,
            "errors": fields,
        },
    )


class OrderItem(BaseModel):
    sku: str
    qty: Annotated[int, Field(gt=0)]


class PublicInvoice(BaseModel):
    invoice_id: str
    total_cents: int


@app.post("/reservations")
async def reserve_stock(item: OrderItem) -> dict[str, Any]:
    if item.qty > 5:
        raise InsufficientInventoryError(item.sku, item.qty, available=5)
    return {"reserved": item.sku, "qty": item.qty}


@app.get("/broken-contract", response_model=PublicInvoice)
async def broken_contract() -> Any:
    return {"invoice_id": "inv-001"}  # Missing `total_cents`!


client = TestClient(app)
assert client.post("/reservations", json={"sku": "SSD-2TB", "qty": 0}).status_code == 422
assert client.post("/reservations", json={"sku": "SSD-2TB", "qty": 12}).status_code == 409

with pytest.raises(ResponseValidationError):
    client.get("/broken-contract")
```

最終節の [実践テスト手法と本番 ASGI 運用](testing_and_deployment.md) では、`lifespan` や非同期トランスポートを用いた高速テスト手法と、ヘルスプローブ・グレースフルシャットダウンを備えた本番運用構成を解説します。
