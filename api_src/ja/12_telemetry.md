# fastapi.telemetry

`fastapi.telemetry` からインポートされるネイティブ OpenTelemetry 設定、リクエスト単位のコンテキスト状態、および同期プロセッサ向け参照 API（`TelemetryConfig`、`TelemetryData`、`get_telemetry_data()`）のリファレンスです。SDK プロバイダ未設定時はゼロオーバーヘッドの no-op として動作し、有効化時には W3C トレース伝播、ルート単位の低カーディナリティ SERVER スパン、子オペレーションスパン、HTTP サーバーメトリクス、バリデーション失敗・未捕捉例外ログイベントを自動計測します。

```drawlib align=center code=hide file=fastapi_telemetry_api.png caption="FastAPI ネイティブ OpenTelemetry 設定・子オペレーションスパン・TelemetryData の同期参照"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.lines import line
from drawlib.smartarts import CardList, ChevronProcess, Panel
from drawlib.styles import Colors, Styles

setup(width=188, height=88)

spans = ChevronProcess(
    style=Styles.Neutral,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    corner_angle=60.0,
    spacing=1.8,
    flat_left_end=True,
)
spans.add("SERVER Span", description="HTTP / WS Route")
spans.add(
    "fastapi.dependencies",
    description="DI & Security",
    style=Styles.SecondaryNeutral,
)
spans.add(
    "fastapi.endpoint",
    description="Route Callable",
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
)
spans.add(
    "serialization / task",
    description="Response & Background",
    style=Styles.PrimaryNeutral,
)
spans.draw(xy=(6.0, 67.0), width=176.0, height=15.0)

cfg_panel = Panel(
    "TelemetryConfig",
    description="",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.sliders,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.5,
)
cfg_panel.draw((6.0, 5.0), width=84.0, height=57.0)
c_xy, c_w, c_h = cfg_panel.get_content_box((6.0, 5.0), width=84.0, height=57.0, padding=(3.5, 3.0))

cfg_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.DarkBold,
    spacing=2.0,
)
cfg_cards.add(
    "Providers & Signal Flags",
    "tracer / meter / logger + booleans",
    badge_text="OTEL",
    icon=phosphor.plugs,
)
cfg_cards.add(
    "operation_spans & exclude",
    "Child spans • ASGI scope predicate",
    badge_text="SPAN",
    icon=phosphor.git_branch,
)
cfg_cards.add(
    "auto_configure",
    "Lifespan OTLP http/protobuf setup",
    badge_text="ENV",
    icon=phosphor.broadcast,
)
cfg_cards.draw(c_xy, width=c_w, height=c_h)

line((91.5, 33.5), (96.5, 33.5), arrow_head="->", style=Styles.PrimaryBold.patch(line_width=1.8))

data_panel = Panel(
    "get_telemetry_data()",
    description="",
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.pulse,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
data_panel.draw((98.0, 5.0), width=84.0, height=57.0)
d_xy, d_w, d_h = data_panel.get_content_box((98.0, 5.0), width=84.0, height=57.0, padding=(3.5, 3.0))

data_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    spacing=2.0,
)
data_cards.add(
    "request & websocket",
    "Active ASGI connection handles",
    badge_text="CONN",
    icon=phosphor.globe,
)
data_cards.add(
    "body & values",
    "Parsed payload • resolved kwargs",
    badge_text="DATA",
    icon=phosphor.brackets_curly,
)
data_cards.add(
    "errors (Cleared on Exit)",
    "Validation dicts • returns None after",
    badge_text="SYNC",
    icon=phosphor.shield_warning,
)
data_cards.draw(d_xy, width=d_w, height=d_h)

save()
```

---

## `class` TelemetryConfig

`FastAPI(telemetry={...})` に渡してネイティブ OpenTelemetry のトレーシング、メトリクス、バリデーション／例外ログイベント、子オペレーションスパン、環境変数からの OTLP エクスポーター自動構成、およびスコープ除外条件を制御する `TypedDict(total=False)` です。省略したキーはデフォルト値を維持し、既存の SDK プロバイダやエクスポーターは保持されます（アプリ側が渡したプロバイダを FastAPI が勝手にシャットダウンすることはありません）。

```python
from collections.abc import Callable, MutableMapping
from typing import Any
from opentelemetry._logs import LoggerProvider
from opentelemetry.metrics import MeterProvider
from opentelemetry.trace import TracerProvider
from typing_extensions import TypedDict


class TelemetryConfig(TypedDict, total=False):
    tracer_provider: TracerProvider | None
    meter_provider: MeterProvider | None
    logger_provider: LoggerProvider | None
    tracing: bool
    metrics: bool
    logs: bool
    operation_spans: bool
    auto_configure: bool
    exclude: Callable[[MutableMapping[str, Any]], bool] | None
```

### 設定キー一覧

| キー | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `tracer_provider` | `TracerProvider \| None` | `None` | このアプリ専用の `TracerProvider`。`None` の場合はグローバルのトレーサープロバイダを使用します。 |
| `meter_provider` | `MeterProvider \| None` | `None` | `http.server.request.duration`（Histogram）および `http.server.active_requests`（UpDownCounter）を記録する `MeterProvider`。`None` の場合はグローバルのメータープロバイダを使用します。 |
| `logger_provider` | `LoggerProvider \| None` | `None` | バリデーション失敗・未捕捉例外イベントを記録する `LoggerProvider`。`None` の場合はグローバルのロガープロバイダを使用します。 |
| `tracing` | `bool` | `True` | HTTP リクエスト（`{METHOD} {http.route}`）および WebSocket 接続（`WS {http.route}`）の `SpanKind.SERVER` スパン、W3C `traceparent` / `baggage` 抽出、機密クエリ文字列マスクを有効化します。 |
| `metrics` | `bool` | `True` | HTTP サーバーリクエスト所要時間および同時処理中リクエスト数の計測を有効化します（WebSocket スコープでは自動的にスキップされます）。 |
| `logs` | `bool` | `True` | `422`／WebSocket バリデーション失敗時に `fastapi.validation.failed`（`WARN`）、未捕捉例外発生時に `http.server.request.exception` または `fastapi.websocket.exception`（`ERROR`）を発行します。 |
| `operation_spans` | `bool` | `True` | トレーシング有効時に子スパン（`fastapi.dependencies`、`fastapi.endpoint`、`fastapi.serialization`、`fastapi.background_task`）と `code.function.name` 属性を発行します。 |
| `auto_configure` | `bool` | `False` | `lifespan.startup` 時に `OTEL_EXPORTER_OTLP_*` 環境変数から `http/protobuf` OTLP エクスポーターを遅延登録します（`fastapi[opentelemetry]` または `fastapi[standard]` が必要）。`FASTAPI_OTEL_AUTO_CONFIGURE=true` 設定時は明示指定がない限り `True` になります。 |
| `exclude` | `Callable[[MutableMapping[str, Any]], bool] \| None` | `None` | 生の ASGI `scope` を受け取る述語関数。`True` を返すと当該リクエスト／接続の計測をスキップし、マウントされたサブアプリへのコンテキスト継承も切り離します。 |

### 使用例

```python
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter

from fastapi import Depends, FastAPI
from fastapi.telemetry import TelemetryConfig
from fastapi.testclient import TestClient

exporter = InMemorySpanExporter()
provider = TracerProvider()
provider.add_span_processor(SimpleSpanProcessor(exporter))

config: TelemetryConfig = {
    "tracer_provider": provider,
    "operation_spans": True,
    "exclude": lambda scope: scope.get("path") == "/healthz",
}
app = FastAPI(telemetry=config)


def get_locale(lang: str = "en") -> str:
    return lang


@app.get("/healthz")
def healthz() -> dict[str, bool]:
    return {"ok": True}


@app.get("/items/{item_id}")
def read_item(item_id: int, lang: str = Depends(get_locale)) -> dict[str, object]:
    return {"item_id": item_id, "lang": lang}


with TestClient(app) as client:
    assert client.get("/healthz").status_code == 200
    assert len(exporter.get_finished_spans()) == 0

    assert client.get("/items/7?lang=ja").status_code == 200

span_names = [span.name for span in exporter.get_finished_spans()]
assert span_names == [
    "fastapi.dependencies",
    "fastapi.endpoint",
    "fastapi.serialization",
    "GET /items/{item_id}",
]
```

---

## `class` TelemetryData

同期実行される OpenTelemetry の `SpanProcessor` や `LogRecordProcessor` 向けに、リクエスト／WebSocket 接続ごとのローカル状態を保持するキーワード専用データクラスです。FastAPI はリクエスト処理の進行に応じて各属性を段階的に格納しますが、PII マスクやリダクション処理を挟めるようデフォルトではスパンやログへ自動出力しません。

```python
from collections.abc import Sequence
from dataclasses import dataclass
from typing import Any
from starlette.requests import Request
from starlette.websockets import WebSocket


@dataclass(kw_only=True)
class TelemetryData:
    request: Request | None = None
    websocket: WebSocket | None = None
    body: Any = None
    values: dict[str, Any] | None = None
    errors: Sequence[Any] | None = None
```

### 属性一覧

| 属性 | 型 | デフォルト | 設定タイミングと説明 |
| :--- | :--- | :--- | :--- |
| `request` | `Request \| None` | `None` | 処理中の HTTP `Request` インスタンス。HTTP ルートハンドラの開始時点で格納されます（WebSocket ルートでは `None`）。 |
| `websocket` | `WebSocket \| None` | `None` | 処理中の `WebSocket` インスタンス。WebSocket ルートハンドラの開始時点で格納されます（HTTP ルートでは `None`）。 |
| `body` | `Any` | `None` | パラメータバリデーション前に FastAPI が読み取ったリクエストボディ（バリデーション失敗時は `RequestValidationError.body` が格納されます）。 |
| `values` | `dict[str, Any] \| None` | `None` | 依存関係解決およびバリデーション完了後にエンドポイント関数へ渡されるキーワード引数辞書。 |
| `errors` | `Sequence[Any] \| None` | `None` | `RequestValidationError` または `WebSocketRequestValidationError` 発生時に格納されるエラー辞書列（`exc.errors()`、元の入力値を含む）。 |

### 使用例

```python
from opentelemetry.sdk._logs import LoggerProvider, LogRecordProcessor, ReadWriteLogRecord
from pydantic import BaseModel

from fastapi import FastAPI
from fastapi.telemetry import TelemetryData, get_telemetry_data
from fastapi.testclient import TestClient

validation_snapshots: list[tuple[object, int]] = []


class ValidationAuditProcessor(LogRecordProcessor):
    def on_emit(self, log_record: ReadWriteLogRecord) -> None:
        data = get_telemetry_data(log_record.log_record.context)
        if isinstance(data, TelemetryData) and data.errors is not None:
            validation_snapshots.append((data.body, len(data.errors)))

    def shutdown(self) -> None:
        return None

    def force_flush(self, timeout_millis: int = 30000) -> bool:
        return True


logger_provider = LoggerProvider()
logger_provider.add_log_record_processor(ValidationAuditProcessor())

app = FastAPI(telemetry={"logger_provider": logger_provider})


class OrderIn(BaseModel):
    sku: str
    qty: int


@app.post("/orders")
def create_order(order: OrderIn) -> dict[str, object]:
    data = get_telemetry_data()
    assert data is not None
    assert data.request is not None and data.request.method == "POST"
    assert data.body == {"sku": "KB-01", "qty": 2}
    assert data.values == {"order": OrderIn(sku="KB-01", qty=2)}
    return {"created": order.sku}


with TestClient(app) as client:
    assert client.post("/orders", json={"sku": "KB-01", "qty": 2}).status_code == 200
    assert client.post("/orders", json={"sku": "KB-01", "qty": "bad"}).status_code == 422

assert validation_snapshots == [({"sku": "KB-01", "qty": "bad"}, 1)]
```

---

## `def` get_telemetry_data()

OpenTelemetry の `Context`（コンテキストキー `fastapi.request`）に紐づく現在の `TelemetryData` を読み取ります。FastAPI が HTTP リクエストや WebSocket 接続を処理している間に、ルートハンドラ、依存関数、`SpanProcessor.on_start` / `on_end`、または `LogRecordProcessor.on_emit` から同期的に呼び出します。ASGI スコープ完了時には内部参照が `None` にクリアされるため、保持された `Context` に対しても完了後は常に `None` を返します。

```python
from opentelemetry.context import Context
from fastapi.telemetry import TelemetryData, get_telemetry_data


def get_telemetry_data(context: Context | None = None) -> TelemetryData | None: ...
```

### パラメータと戻り値

| 名前 | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `context` | `Context \| None` | `None` | 参照対象の OpenTelemetry `Context`（`SpanProcessor.on_start` の `parent_context` や `LogRecordProcessor.on_emit` の `log_record.log_record.context` など）。`None` の場合は現在のアクティブコンテキストを参照します。 |
| **戻り値** | `TelemetryData \| None` | — | リクエストまたは WebSocket 接続の処理中はアクティブな `TelemetryData`、計測対象外スコープまたは処理完了後は `None`。 |

### 使用例

```python
from opentelemetry import context as otel_context
from opentelemetry.context import Context
from opentelemetry.sdk.trace import Span, TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter

from fastapi import FastAPI
from fastapi.telemetry import get_telemetry_data
from fastapi.testclient import TestClient


class EndpointArgTagger(SimpleSpanProcessor):
    def on_start(self, span: Span, parent_context: Context | None = None) -> None:
        data = get_telemetry_data(parent_context)
        if span.name == "fastapi.endpoint" and data and data.values:
            span.set_attribute("app.account_id", str(data.values.get("account_id")))


exporter = InMemorySpanExporter()
provider = TracerProvider()
provider.add_span_processor(EndpointArgTagger(exporter))

app = FastAPI(telemetry={"tracer_provider": provider})
retained_contexts: list[Context] = []


@app.get("/accounts/{account_id}")
def get_account(account_id: str) -> dict[str, str]:
    retained_contexts.append(otel_context.get_current())
    live = get_telemetry_data()
    assert live is not None and live.values == {"account_id": "acct_99"}
    return {"account_id": account_id}


with TestClient(app) as client:
    assert client.get("/accounts/acct_99").status_code == 200

# Cleared immediately after request completion, even on retained contexts
assert get_telemetry_data() is None
assert get_telemetry_data(retained_contexts[0]) is None

ep_span = next(s for s in exporter.get_finished_spans() if s.name == "fastapi.endpoint")
assert ep_span.attributes is not None
assert ep_span.attributes["app.account_id"] == "acct_99"
```
