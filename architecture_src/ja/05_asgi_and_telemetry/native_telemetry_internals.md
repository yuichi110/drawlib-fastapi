# NativeTelemetry・遅延ランタイム・例外スパン記録

FastAPI `v0.162.2` は、`fastapi/telemetry/`（`__init__.py`・`_api.py`・`_asgi.py`・`_runtime.py`）に組み込みの OpenTelemetry サブシステムを備えています。コア依存パッケージを軽量な `opentelemetry-api` のみに限定することで、SDK 未設定時にはオーバーヘッドゼロの no-op として振る舞う一方、OpenTelemetry SDK プロバイダが有効化されると W3C トレース伝播・低カーディナリティなルートスパン・子オペレーションスパン・HTTP サーバーメトリクス・重複排除された例外テレメトリを自動的に計測します。

```drawlib align=center code=hide file=native_telemetry_dual_middleware.png caption="NativeTelemetry（L1）と ExceptionTelemetryMiddleware（L3）の二層連携アーキテクチャ"
from drawlib.canvas import setup
from drawlib.diagrams.architecture import (
    ArchitectureDiagram,
    Node,
    NodeGroup,
    PhosphorIcon,
)
from drawlib.styles import Colors, Styles

d = ArchitectureDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.0),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
)

client = d.add(
    Node(
        "HTTP / WS Client\n(W3C traceparent)",
        width=28,
        height=17,
        icon=PhosphorIcon.GLOBE,
        icon_size=7.0,
        card_style=Styles.Neutral,
    ),
    xy=(14.0, 58.0),
)

stack_grp = d.add(
    NodeGroup(
        title="FastAPI ASGI Stack & Exception Correlation",
        padding=6.0,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left"),
    ),
    xy=(52.0, 6.0),
)

native = stack_grp.add(
    Node(
        "L1: NativeTelemetry\n(SERVER Span)",
        width=34,
        height=17,
        icon=PhosphorIcon.PULSE,
        icon_size=7.0,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
        card_style=Styles.PrimaryFlat,
    ),
    xy=(23.0, 52.0),
)

srv_err = stack_grp.add(
    Node(
        "L2: ServerError\n(Sends 500 Body)",
        width=30,
        height=17,
        icon=PhosphorIcon.SHIELD_WARNING,
        icon_size=7.0,
        card_style=Styles.Neutral,
    ),
    xy=(84.0, 52.0),
)

exc_tel = stack_grp.add(
    Node(
        "L3: ExceptionTelemetry\n(Logs _exceptions)",
        width=38,
        height=17,
        icon=PhosphorIcon.BUG,
        icon_size=7.0,
        card_style=Styles.SecondaryNeutral,
    ),
    xy=(146.0, 52.0),
)

exc_mw = stack_grp.add(
    Node(
        "L5: ExceptionMiddleware\n(Absorbs 4xx / 422)",
        width=42,
        height=17,
        icon=PhosphorIcon.FUNNEL,
        icon_size=7.0,
        card_style=Styles.Neutral,
    ),
    xy=(146.0, 15.0),
)

router_n = stack_grp.add(
    Node(
        "L7: APIRouter\n(_route_selected)",
        width=30,
        height=17,
        icon=PhosphorIcon.GIT_BRANCH,
        icon_size=7.0,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(84.0, 15.0),
)

tel_state = stack_grp.add(
    Node(
        "_RequestTelemetry\nscope & OTel Context",
        width=34,
        height=17,
        icon=PhosphorIcon.DATABASE,
        icon_size=7.0,
        card_style=Styles.SecondaryNeutral,
    ),
    xy=(23.0, 15.0),
)

d.connect(client, native, label="Headers", padding=1.2)
d.connect(native, srv_err, label="wrap send", padding=1.2)
d.connect(srv_err, exc_tel, label="call", padding=1.2)
d.connect(exc_tel, exc_mw, label="L4->L5", padding=1.2)
d.connect(exc_mw, router_n, label="route", padding=1.2)
d.connect(router_n, tel_state, label="http.route", padding=1.2)
d.connect(tel_state, native, label="error.type", padding=1.2)

diag_w, diag_h = d.get_size()
setup(width=int(diag_w) + 12, height=int(diag_h) + 12)
d.draw(xy=(6.0, 6.0))
```

---

## 1. SDK 非依存コア設計と遅延ランタイム結合（`_runtime.py`）

`fastapi/telemetry/` の設計上の最重要方針は、テレメトリを送信しないアプリケーションに対して重い SDK インポートやリクエスト単位のオーバーヘッドを一切課さないことです。FastAPI は **API レベルの計装**と **SDK・エクスポータ初期化**を明確に分離することでこれを実現しています。

- **遅延プロキシプロバイダの判定（`_api.py`）**: `fastapi` 本体が依存するのは `opentelemetry-api>=1.44.0` のみであり、その初期グローバルプロバイダは `_DEFERRED_PROVIDERS` に列挙された軽量な no-op プロキシ（`ProxyTracerProvider`・`_ProxyMeterProvider`・`ProxyLoggerProvider`）です。`_unconfigured(provider)` は `(type(provider).__module__, type(provider).__name__) in _DEFERRED_PROVIDERS` で未設定状態を判定します。
- **ホットパスのゲート判定（`NativeTelemetry.enabled()`）**: `self._telemetry` の明示プロバイダがすべて `None` であり、かつ 3 シグナルのグローバルプロバイダがすべて `_unconfigured(...)` を満たす場合、`NativeTelemetry.enabled()` は `False` を返します。このとき `FastAPI.__call__` は `_RequestTelemetry` の生成もヘッダ解析も `send`/`receive` のラップも行わず、即座に `await super().__call__(scope, receive, send)` へ短絡します。
- **Lifespan 起動時の SDK・OTLP 遅延インポート（`_runtime.py`）**: オプションパッケージ `opentelemetry-sdk` と `opentelemetry-exporter-otlp-proto-http`（`fastapi[opentelemetry]` または `fastapi[standard]` で導入）は、モジュール読み込み時にはインポートされません。`lifespan.startup` イベント時に呼ばれる `_configure_from_environment(config)` の内部で、`auto_configure=True`（または `FASTAPI_OTEL_AUTO_CONFIGURE=true`）かつ `OTEL_SDK_DISABLED != "true"` かつ有効な `http`/`https` の `OTEL_EXPORTER_OTLP_*`（`http/protobuf`）エンドポイントが存在するときに限り、遅延インポートされます。
- **プロバイダ所有権の保護（`_owned` と `_configured`）**: 再入ロック `_lock` の保護下で、`_configure_from_environment()` は `(signal, provider)` の組ごとに 1 度だけ `BatchSpanProcessor(OTLPSpanExporter(...))`・`PeriodicExportingMetricReader(OTLPMetricExporter(...))`・`BatchLogRecordProcessor(OTLPLogExporter(...))` を登録します。FastAPI 自身が生成したコンポーネントのみが `_owned` に記録され、`lifespan.shutdown.complete`（および起動・終了失敗時）に `await run_sync(_flush)` でフラッシュされ、プロセス終了時に `atexit.register(_shutdown)` で閉じられます。アプリケーション側から渡されたプロバイダを FastAPI が勝手にシャットダウンすることはありません。

```drawlib align=center code=hide file=lazy_otel_runtime_binding.png caption="_runtime.py におけるデフォルトのゼロオーバーヘッド経路と Lifespan 遅延 OTLP 自動構成の対比"
from drawlib.canvas import setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, ChevronProcess, Panel
from drawlib.styles import Colors, Styles

setup(width=176, height=88)

pipeline = ChevronProcess(
    style=Styles.Neutral,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    corner_angle=60.0,
    spacing=1.8,
    flat_left_end=True,
)
pipeline.add("1. Import Time", description="opentelemetry-api")
pipeline.add(
    "2. lifespan.startup",
    description="Lazy OTLP Setup",
    style=Styles.SecondaryNeutral,
)
pipeline.add(
    "3. Request Gate",
    description="enabled() Check",
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
)
pipeline.add(
    "4. Shutdown / Exit",
    description="_flush & _shutdown",
    style=Styles.PrimaryNeutral,
)
pipeline.draw(xy=(4.0, 70.0), width=168.0, height=14.0)

noop_panel = Panel(
    "Default No-Op Fast Path",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.5),
    icon=phosphor.lightning_slash,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.5,
)
noop_panel.draw((4.0, 4.0), width=82.0, height=62.0)
n_xy, n_w, n_h = noop_panel.get_content_box(
    (4.0, 4.0), width=82.0, height=62.0, padding=(3.5, 3.0)
)

noop_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.DarkBold,
    spacing=2.2,
)
noop_cards.add(
    "Deferred Proxy Providers",
    "ProxyTracer / Meter / LoggerProvider",
    badge_text="API",
    icon=phosphor.plugs,
)
noop_cards.add(
    "_unconfigured() is True",
    "NativeTelemetry.enabled() returns False",
    badge_text="Gate",
    icon=phosphor.shield_check,
)
noop_cards.add(
    "Direct super().__call__",
    "Zero span, wrapper, or context overhead",
    badge_text="0ms",
    icon=phosphor.fast_forward,
)
noop_cards.draw(n_xy, width=n_w, height=n_h)

sdk_panel = Panel(
    "Active SDK & OTLP Export",
    style=Styles.PrimaryNeutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.5),
    icon=phosphor.broadcast,
    icon_style=Styles.White,
    header_variant="filled",
    header_height=8.5,
)
sdk_panel.draw((90.0, 4.0), width=82.0, height=62.0)
s_xy, s_w, s_h = sdk_panel.get_content_box(
    (90.0, 4.0), width=82.0, height=62.0, padding=(3.5, 3.0)
)

sdk_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    spacing=2.2,
)
sdk_cards.add(
    "Lazy SDK Import",
    "Loads opentelemetry.sdk only when enabled",
    badge_text="SDK",
    icon=phosphor.package,
)
sdk_cards.add(
    "OTLP http/protobuf",
    "BatchSpan / Log & PeriodicMetricReader",
    badge_text="OTLP",
    icon=phosphor.export,
)
sdk_cards.add(
    "Owned Lifecycle (_owned)",
    "Flushes on shutdown; preserves user SDKs",
    badge_text="Safe",
    icon=phosphor.lock_key,
)
sdk_cards.draw(s_xy, width=s_w, height=s_h)
```

---

## 2. `NativeTelemetry` のスパン・コンテキスト・メトリクス機構（`_asgi.py`）

アクティブな HTTP または WebSocket スコープで `NativeTelemetry.__call__` が実行されると（`config["exclude"](scope)` で除外されておらず、かつ `_legacy_otel()` が既存の `OpenTelemetryMiddleware` を検出しない場合）、リクエストライフサイクル全体にわたって以下の 5 段階を制御します。

1. **W3C コンテキスト抽出とクエリサニタイズ**: `propagate.extract(Headers(scope=scope), getter=_HEADERS_GETTER)` により受信ヘッダから `traceparent`・`tracestate`・複数行 `baggage` を `parent` として抽出し、`otel_context.attach(parent)` でアタッチします。`_HTTP_METHODS`（または `OTEL_INSTRUMENTATION_HTTP_KNOWN_METHODS`）に含まれない未知の HTTP メソッドは `"_OTHER"` に正規化（元の値は `http.request.method_original` に保持）し、`_SENSITIVE_QUERY_PARAMETERS`（`X-Amz-Signature`・`X-Amz-Credential`・`X-Amz-Security-Token`・`sig`・`X-Goog-Signature`）は `url.query` 上で `"REDACTED"` にマスクします。
2. **ルート `SpanKind.SERVER` スパン開始と `_RequestTelemetry` 格納**: スキーマ URL `https://opentelemetry.io/schemas/1.44.0` のもとで `tracer.start_span(span_method, context=parent, kind=SpanKind.SERVER, attributes=span_attributes)` を開始します。未一致の `404` スキャンアクセスでスパン名のカーディナリティが爆発しないよう、初期スパン名はメソッド名のみ（`"GET"`・`"POST"`・`"WS"`）とします。生成された `_RequestTelemetry` は ASGI ルーティング層から参照する `scope["fastapi.telemetry"]` と、ワーカースレッドからも `get_telemetry_data()` で参照可能な `otel_context`（キー `_REQUEST_TELEMETRY_KEY = "fastapi.request"`）の双方へ同時に格納されます。
3. **低カーディナリティなルート名更新（`_route_selected()`）**: `APIRouter.app` がルートに一致すると（`Mount` 経由時は `_mount_prefix` を連結しながら）、`_route_selected(scope=scope, path=route.path_format, mount=...)` が呼ばれます。ここでスパン属性 `http.route` が設定され、`span.update_name(f"{span_method} {route}")` によって `"GET /items/{item_id}"` のようなルートテンプレート名へと更新されます。
4. **細粒度な子オペレーションスパン（`_operation()`）**: `operation_spans=True`（デフォルト）のとき、`_traced_operation()` は `code.function.name = f"{module}.{qualname}"` 属性付きで `fastapi.dependencies`・`fastapi.endpoint`・`fastapi.serialization`・`fastapi.background_task` の子スパンを生成します。
5. **Exemplar 相関メトリクスとゼロ保持クリーンアップ**: `NativeTelemetry._instruments()` は `http.server.request.duration`（秒単位の `Histogram`、境界 `_DURATION_BUCKETS` は `0.005`〜`10.0`）と `http.server.active_requests`（`UpDownCounter`）を生成します。`finish()` 内では、`SERVER` スパンがまだカレントである間に `duration.record(...)` を記録してから `span.end()` を呼ぶため、メトリクス Exemplar とトレース ID が正確に紐づきます。最後に外側の `finally:` ブロックで `request_telemetry.data = None` および `_exceptions.clear()` を実行し、保持されたコンテキストからリクエスト本文や引数がリークしないよう消去します。

---

## 3. `ExceptionTelemetryMiddleware` が `ExceptionMiddleware`・`ServerErrorMiddleware` と協調する理由

ASGI スタックでは、想定内の HTTP エラー、カスタム例外ハンドラ、未処理の `500` クラッシュがそれぞれ異なる層で処理されるため、例外テレメトリの配置には厳密な順序設計が求められます。

- **制御された `4xx` / `422` 例外は `ExceptionMiddleware`（L5）内側で完結**: エンドポイントや依存関数が `HTTPException(404)` や `RequestValidationError`（`422`）を送出した場合、**L5** の `ExceptionMiddleware`（および `request_response()` 内の `wrap_app_handling_exceptions`）がそれを捕捉して通常の HTTP レスポンスへ変換するため、外側の `ExceptionTelemetryMiddleware`（**L3**）へ例外が伝播することはありません。`status_code < 500` の応答に対して `finish()` は `failed = False` と判定し、`SERVER` スパンのステータスを `StatusCode.UNSET`（`error.type` なし）に保ちます（なお `logs=True` の場合、`_validation_failed()` が `fastapi.validation.error_count` 属性付きの `WARN` ログイベント `fastapi.validation.failed` を出力します）。同様に、子スパン用の `_traced_operation()` も `HTTPException`・`RequestValidationError`・`WebSocketException`・`WebSocketRequestValidationError`・正常な WebSocket 切断（`1000`, `1001`）をエラーステータス対象から除外します（カスタム例外ハンドラが `5xx` ステータスを返した場合のみ、`finish()` が `error.type = str(status_code)` と `StatusCode.ERROR` を付与します）。
- **未処理クラッシュと `ServerErrorMiddleware` の `wrapped_send` 順序問題（L2 の内側に L3 を置く理由）**: 未処理の `ZeroDivisionError` が `user_middleware` を突き抜けると、**L2** の `ServerErrorMiddleware` に到達します。ここで重要なのは、`ServerErrorMiddleware` は **例外を再送出する前に `send()` を呼んで HTTP `500` レスポンス本文を最後まで送信し終える** という点です。最終チャンク `send({"type": "http.response.body", "more_body": False})` が `NativeTelemetry.wrapped_send()` を通過した瞬間、`NativeTelemetry` は即座に `finish()` を呼んで `SERVER` スパンを終了させます。この時点ではまだ `ServerErrorMiddleware` から `NativeTelemetry` の `except BaseException:` 節へ例外が戻ってきていません。そこで `ExceptionTelemetryMiddleware` を **L3**（`ServerErrorMiddleware` の直下）に配置することで、**L2** が `500` 応答を送信するよりも先に `_exception(scope=scope, exc=exc)` を実行して `request_telemetry._exceptions` への追加と `http.server.request.exception` `ERROR` ログ出力を完了させ、直後の `finish()` で `error.type = "ZeroDivisionError"` と `StatusCode.ERROR` を確実に記録できます。
- **オブジェクト同一性による二重記録の防止**: `ServerErrorMiddleware` が `500` 応答を送信した後に例外を再送出すると、最外層 `NativeTelemetry`（**L1**）の `except BaseException as exc:` 節も `_exception(scope=scope, exc=exc)` と `finish(exc)` を呼び出します（これは `CancelledError` などの `BaseException` や **L2** 自身のクラッシュも漏らさないためです）。`_exception()` 内部では `if not any(previous is exc for previous in seen):` によってオブジェクト同一性（`is`）で重複判定を行い、`finish()` も `if finished: return` で冪等性を保証しているため、未処理例外が二重にログ記録されたり二重に終了処理されたりすることはありません。

---

## 4. `InMemorySpanExporter` による出力スパン・属性の検証

以下のスニペットは、OpenTelemetry SDK の `TracerProvider` と `InMemorySpanExporter` を `FastAPI(telemetry=...)` に接続し、W3C `traceparent` の継承、低カーディナリティな `http.route` スパン名更新、`404` 時の `UNSET` ステータス維持、および `500` クラッシュ時の `error.type` 記録を検証します。

```python
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter
from opentelemetry.trace import SpanKind, StatusCode

exporter = InMemorySpanExporter()
provider = TracerProvider()
provider.add_span_processor(SimpleSpanProcessor(exporter))

app = FastAPI(telemetry={"tracer_provider": provider})


@app.get("/items/{item_id}")
def get_item(item_id: int) -> dict[str, int]:
    if item_id == 0:
        raise HTTPException(status_code=404, detail="Item not found")
    if item_id < 0:
        raise ZeroDivisionError("negative item crash")
    return {"item_id": item_id}


trace_id_hex = "4bf92f3577b34da6a3ce929d0e0e4736"
traceparent = f"00-{trace_id_hex}-00f067aa0ba902b7-01"

with TestClient(app, raise_server_exceptions=False) as client:
    # 1. 200 OK: W3C traceparent 継承、子オペレーションスパン + 低カーディナリティ名
    assert client.get("/items/7", headers={"traceparent": traceparent}).status_code == 200
    spans = exporter.get_finished_spans()
    assert {"fastapi.dependencies", "fastapi.endpoint", "GET /items/{item_id}"} <= {
        s.name for s in spans
    }
    server_span = next(s for s in spans if s.kind == SpanKind.SERVER)
    assert f"{server_span.context.trace_id:032x}" == trace_id_hex
    assert server_span.attributes["http.route"] == "/items/{item_id}"
    assert server_span.attributes["http.response.status_code"] == 200
    assert server_span.status.status_code == StatusCode.UNSET
    exporter.clear()

    # 2. 制御された 404 HTTPException: L5 で吸収 -> UNSET 維持・error.type なし
    assert client.get("/items/0").status_code == 404
    span_404 = next(s for s in exporter.get_finished_spans() if s.kind == SpanKind.SERVER)
    assert span_404.status.status_code == StatusCode.UNSET
    assert "error.type" not in span_404.attributes
    exporter.clear()

    # 3. 未処理の 500 クラッシュ: L2 の 500 送信前に L3 が ZeroDivisionError を記録
    assert client.get("/items/-1").status_code == 500
    span_500 = next(s for s in exporter.get_finished_spans() if s.kind == SpanKind.SERVER)
    assert span_500.attributes["http.response.status_code"] == 500
    assert span_500.attributes["error.type"] == "ZeroDivisionError"
    assert span_500.status.status_code == StatusCode.ERROR
```

コンパイル済みの `APIRoute` 定義と `ModelField` スキーマから OpenAPI 3.1.0 ドキュメントおよび対話型 UI エンドポイントがどのように合成されるかについては、次章の [get_openapi()・$defs 集約・Docs UI](../06_openapi_and_docs/openapi_synthesis_engine.md)へ進んでください。
