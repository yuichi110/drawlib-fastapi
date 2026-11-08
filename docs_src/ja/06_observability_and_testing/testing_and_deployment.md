# 実践テスト手法と本番 ASGI 運用

FastAPI `v0.162.2` は、同期的な `with TestClient(app) as client:` と非同期イベントループ直結の `httpx.ASGITransport` の双方でミリ秒未満のインメモリ統合テストを実現し、本番環境ではリバースプロキシ配下の ASGI ワーカー・ヘルスプローブ・`lifespan` による安全なドレイン終了とシームレスに連携します。

```drawlib align=center code=fold file=testing_modes_architecture.png caption="インメモリ FastAPI 統合テスト構成：同期 TestClient ポータル方式 vs 非同期 httpx.ASGITransport 直結方式"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.lines import line
from drawlib.shapes import rectangle
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=168, height=88)

text(
    (84.0, 83.0),
    "FastAPI In-Memory Integration Testing Modes & Dependency Overrides",
    style=Styles.DarkBold.patch(text_size=13.2),
)

# Left Panel: Sync TestClient
p_sync = Panel(
    "Mode A: Sync TestClient",
    "def test_*()",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    description_style=Styles.Dark.patch(text_size=10.0),
    icon=phosphor.terminal_window,
    icon_style=Styles.SecondaryBold,
    header_height=9.0,
)
p_sync.draw((5.0, 27.0), width=75.0, height=50.0)
l_xy, l_w, l_h = p_sync.get_content_box((5.0, 27.0), width=75.0, height=50.0, padding=(3.0, 2.5))

cl_sync = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.SecondaryBold.patch(text_size=10.0),
    spacing=2.0,
)
cl_sync.add("with TestClient(app) as c:", "Runs lifespan startup & shutdown", badge_text="1")
cl_sync.add("AnyIO Blocking Portal", "Bridges sync pytest to worker loop", badge_text="2")
cl_sync.add("WebSocket Helper", "Built-in c.websocket_connect()", badge_text="3")
cl_sync.draw(l_xy, width=l_w, height=l_h)

# Right Panel: Native Async ASGITransport
p_async = Panel(
    "Mode B: AsyncClient",
    "@pytest.mark.anyio",
    style=Styles.PrimaryNeutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.0),
    description_style=Styles.White.patch(text_size=10.0),
    icon=phosphor.lightning,
    icon_style=Styles.WhiteBold,
    header_height=9.0,
)
p_async.draw((88.0, 27.0), width=75.0, height=50.0)
r_xy, r_w, r_h = p_async.get_content_box((88.0, 27.0), width=75.0, height=50.0, padding=(3.0, 2.5))

cl_async = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_style=Styles.PrimaryFlat,
    badge_text_style=Styles.WhiteBold.patch(text_size=10.0),
    spacing=2.0,
)
cl_async.add("ASGITransport(app=app)", "Zero thread-portal context switch", badge_text="1")
cl_async.add("Async DB Rollbacks", "Shares async SQLAlchemy session", badge_text="2")
cl_async.add("Parallel Concurrency", "anyio.create_task_group() load tests", badge_text="3")
cl_async.draw(r_xy, width=r_w, height=r_h)

# Shared Target FastAPI App + dependency_overrides Banner
line((42.5, 27.0), (42.5, 19.5), arrow_head="->", style=Styles.DarkBold.patch(line_width=1.8))
line((125.5, 27.0), (125.5, 19.5), arrow_head="->", style=Styles.PrimaryBold.patch(line_width=1.8))

rectangle((84.0, 11.5), width=158.0, height=14.5, style=Styles.Neutral.patch(shape_r=2.0))
phosphor.sliders_horizontal((14.0, 11.5), width=5.5, style=Styles.PrimaryBold)
text(
    (87.0, 11.5),
    "Shared In-Memory ASGI App  •  app.dependency_overrides[prod_dep] = fake_dep  (Always .clear() in finally!)",
    style=Styles.DarkBold.patch(text_size=10.5),
)

save()
```

## 1. 同期 `TestClient` vs ネイティブ非同期 `ASGITransport`

どちらのテストハーネスも TCP ソケットを開かずにメモリ上で直接 ASGI メッセージをやり取りしますが、[大規模 DI・Lifespan 管理・テスト戦略](../02_enterprise_architecture/di_lifespan_testing.md) で扱った設計に基づき、テスト対象に応じて使い分けます。

| 比較軸 | `with TestClient(app) as client:` | `httpx.AsyncClient(transport=ASGITransport(app=app))` |
| :--- | :--- | :--- |
| **テスト関数の形式** | 標準的な同期関数 `def test_...()` | 非同期コルーチン `@pytest.mark.anyio async def test_...()` |
| **Lifespan の実行** | `with` ブロック開始時に起動し、終了時にシャットダウンを実行 | 状態を明示制御するか、非同期 lifespan フィクスチャと併用 |
| **リアルタイム通信** | HTTP・SSE・JSONL に加え `client.websocket_connect(...)` を標準提供 | 同一ループ上で HTTP・SSE（`ac.stream(...)`）・JSONL を検証可能 |
| **非同期 DB ロールバック** | ポータル経由で別ループになるため非同期 DB セッション共有に不向き | 非同期 DB トランザクションフィクスチャと **完全に同一のイベントループ** を共有 |

### `with TestClient` による Lifespan 起動と安全な `dependency_overrides` 解放

大規模リポジトリのテストスイートで頻発するフレーキーテストの主な原因は次の 2 点です。

1. **`TestClient` で `with` 文を省略してしまう**: `client = TestClient(app)` を単体で生成すると、`@asynccontextmanager` で定義した `lifespan` の初期化・終了フックが一切実行されません。必ず `with TestClient(app) as client:` として使用します。
2. **`app.dependency_overrides` のテスト間リーク**: `app.dependency_overrides` は `FastAPI` インスタンス上の辞書を直接書き換えるため、`try ... finally: app.dependency_overrides.clear()`（または `yield` 型 pytest フィクスチャ）で確実にリセットし、後続テストへのモック残留を防ぎます。

```python
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from typing import Annotated

from fastapi import Depends, FastAPI, Request, Response, status
from fastapi.testclient import TestClient


def create_production_app() -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
        app.state.db_ready = True
        app.state.events = ["startup:complete"]
        try:
            yield
        finally:
            app.state.db_ready = False
            app.state.events.append("shutdown:complete")

    app = FastAPI(lifespan=lifespan)

    def get_exchange_rate() -> float:
        return 152.40

    app.state.get_exchange_rate = get_exchange_rate

    @app.get("/healthz")
    async def liveness_probe() -> dict[str, str]:
        return {"status": "alive"}

    @app.get("/readyz")
    async def readiness_probe(request: Request, response: Response) -> dict[str, str]:
        if not getattr(request.app.state, "db_ready", False):
            response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
            return {"status": "draining"}
        return {"status": "ready"}

    @app.get("/quotes/usd-jpy")
    async def quote_usd_jpy(
        rate: Annotated[float, Depends(get_exchange_rate)],
    ) -> dict[str, float]:
        return {"usd_jpy": rate}

    return app


app = create_production_app()
app.dependency_overrides[app.state.get_exchange_rate] = lambda: 150.00
try:
    with TestClient(app) as client:
        assert client.get("/readyz").status_code == 200
        assert client.get("/quotes/usd-jpy").json() == {"usd_jpy": 150.0}
finally:
    app.dependency_overrides.clear()

assert app.state.events == ["startup:complete", "shutdown:complete"]
```

### `@pytest.mark.anyio` と `httpx.ASGITransport` によるネイティブ非同期テスト

非同期データベーストランザクションのロールバック検証、[ネイティブ OpenTelemetry スパン](telemetry_and_errors.md) の検査、並行リクエストの競合テストには、`httpx.ASGITransport` でアプリを直接駆動します。

```python
import httpx
import pytest


@pytest.mark.anyio
async def test_async_readiness_transitions() -> None:
    app = create_production_app()
    app.state.db_ready = False  # Simulate cold pool before readiness

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(
        transport=transport, base_url="http://testserver"
    ) as ac:
        assert (await ac.get("/healthz")).status_code == 200
        assert (await ac.get("/readyz")).status_code == 503

        app.state.db_ready = True
        assert (await ac.get("/readyz")).status_code == 200
```

---

## 2. 本番 ASGI トポロジ・ヘルスプローブ・グレースフルシャットダウン

Kubernetes、Cloud Run、systemd などの本番環境では、TLS 終端を行うリバースプロキシやロードバランサーの背後に単一プロセスの Uvicorn ASGI ワーカーを配置し、水平スケーリングはコンテナオーケストレーター側のレプリカ制御に委ねます。

```drawlib align=center code=fold file=production_asgi_readiness.png caption="本番 ASGI デプロイトポロジ：TLS リバースプロキシ・Uvicorn ワーカー・ヘルスプローブ・Lifespan ドレイン終了"
from drawlib.canvas import save, setup
from drawlib.diagrams.architecture import ArchitectureDiagram, GcpIcon, Node, NodeGroup, PhosphorIcon
from drawlib.styles import Styles
from drawlib.text import text

setup(width=176, height=96)

text(
    (88.0, 91.0),
    "Production FastAPI ASGI Topology: TLS Ingress, Probes & Lifespan Drain",
    style=Styles.DarkBold.patch(text_size=13.0),
)

d = ArchitectureDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.2),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.DarkBold.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
)

clients = d.add(
    Node("HTTPS / WSS\nClients", width=24, height=17, icon=PhosphorIcon.USERS, icon_size=6.8),
    xy=(13.0, 62.0),
)
kubelet = d.add(
    Node("Orchestrator\nProbes & SIGTERM", width=26, height=17, icon=PhosphorIcon.HEARTBEAT, icon_size=6.8, card_style=Styles.SecondaryNeutral),
    xy=(14.0, 22.0),
)

edge = d.add(
    NodeGroup(
        title="Edge Ingress",
        padding=4.5,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=10.8, halign="left"),
    ),
    xy=(34.0, 44.0),
)
proxy = edge.add(
    Node(
        "TLS Reverse Proxy\nHeaders & HTTP/2",
        width=28,
        height=18,
        icon=GcpIcon.CLOUD_LOAD_BALANCING,
        icon_size=7.0,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(18.5, 18.0),
)

pod = d.add(
    NodeGroup(
        title="Uvicorn Container",
        padding=5.0,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=10.8, halign="left"),
    ),
    xy=(80.0, 4.0),
)
worker = pod.add(
    Node(
        "FastAPI APIRoute\nHTTP • SSE • WS",
        width=32,
        height=17,
        icon=PhosphorIcon.CPU,
        icon_size=7.0,
        card_style=Styles.PrimaryFlat,
        style=Styles.WhiteBold,
        text_style=Styles.WhiteBold.patch(text_size=10.2),
    ),
    xy=(23.0, 58.0),
)
lifespan_node = pod.add(
    Node(
        "Lifespan Manager\nInit & SIGTERM Drain",
        width=32,
        height=16,
        icon=PhosphorIcon.ARROWS_CLOCKWISE,
        icon_size=6.8,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(23.0, 34.0),
)
probes = pod.add(
    Node(
        "/healthz & /readyz\n200 OK / 503 Drain",
        width=32,
        height=15,
        icon=PhosphorIcon.SHIELD_CHECK,
        icon_size=6.8,
    ),
    xy=(23.0, 12.0),
)

db = d.add(
    Node("PostgreSQL / Redis\nAsync Pool", width=28, height=18, icon=GcpIcon.CLOUD_SQL, icon_size=7.0, card_style=Styles.PrimaryNeutral),
    xy=(155.0, 62.0),
)
cache = d.add(
    Node("Pool Shutdown\nClean Drain", width=28, height=16, icon=PhosphorIcon.PLUGS, icon_size=6.8),
    xy=(155.0, 38.0),
)

d.connect(clients, proxy, padding=1.2)
d.connect(proxy, worker, label="ASGI", padding=1.2)
d.connect(kubelet, probes, label="Probes", padding=1.2)
d.connect(kubelet, lifespan_node, label="SIGTERM", padding=1.2)
d.connect(worker, db, padding=1.2)
d.connect(lifespan_node, cache, label="Close", padding=1.2)

d.draw(xy=(3.0, 3.0))
save()
```

### 本番 ASGI 運用チェックリスト

1. **Liveness（`/healthz`）と Readiness（`/readyz`）を厳格に分離する**:
   - `/healthz`（**生存確認**）は外部 DB 等に一切依存せず、イベントループが応答可能であることだけを即座に `200 OK` で返します。`/healthz` 内で外部 DB を叩くと、一時的な DB 瞬断で健全な全 Pod が一斉再起動する連鎖障害を招きます。
   - `/readyz`（**受信準備確認**）は `lifespan` の初期化完了やコネクションプール状態を検査し、起動直後やシャットダウン開始時には `503 Service Unavailable` を返してロードバランサーからの新規流入を止めます。またテレメトリのノイズを防ぐため、`exclude=lambda s: s.get("path") in {"/healthz", "/readyz"}` でプローブをトレース対象から除外します。
2. **1 コンテナ 1 プロセスで水平スケールさせる**: Kubernetes や Cloud Run では 1 コンテナあたり単一の `uvicorn` プロセスを起動し、`--timeout-graceful-shutdown` を Pod の `terminationGracePeriodSeconds` に合わせることで、`SIGTERM` 受信時に処理中の [SSE / WebSocket ストリーム](../05_async_and_realtime/sse_websockets_streaming.md) を安全に完了させてから `lifespan` の `finally` ブロックでプールを閉じられます。
3. **プロキシヘッダーの信頼境界を明示する**: サイドカー構成では `127.0.0.1` にバインドする（または `--forwarded-allow-ips` を既知のロードバランサー CIDR に限定する）ことで、外部クライアントによる `X-Forwarded-For` や `X-Forwarded-Proto` の偽装を防止します。

```bash
uvicorn app.main:app \
  --host 127.0.0.1 \
  --port 8000 \
  --proxy-headers \
  --timeout-graceful-shutdown 30 \
  --no-access-log
```

全 6 章の全体像を振り返るには、[ガイド概要と全体マップ](../index.md) へ戻って FastAPI `v0.162.2` のアーキテクチャマップを参照してください。
