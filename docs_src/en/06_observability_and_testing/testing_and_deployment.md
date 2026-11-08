# Testing Patterns & Production ASGI

FastAPI `v0.162.2` enables sub-millisecond in-memory integration testing—either synchronously via `with TestClient(app) as client:` or natively on an async event loop via `httpx.ASGITransport`—and pairs cleanly with reverse-proxied ASGI workers, health probes, and graceful `lifespan` draining in production.

```drawlib align=center code=fold file=testing_modes_architecture.png caption="In-Memory FastAPI Testing Architecture: Sync TestClient Portal vs Native Async httpx.ASGITransport"
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

## 1. Synchronous `TestClient` vs Native Async `ASGITransport`

Both testing harnesses speak ASGI directly in memory without opening a TCP socket, yet they target complementary testing scenarios (building on the [Enterprise DI & Lifespan](../02_enterprise_architecture/di_lifespan_testing.md) architecture):

| Criterion | `with TestClient(app) as client:` | `httpx.AsyncClient(transport=ASGITransport(app=app))` |
| :--- | :--- | :--- |
| **Test Function Style** | Standard synchronous `def test_...()` | Coroutine `@pytest.mark.anyio async def test_...()` |
| **Lifespan Execution** | Enters `lifespan` on `with` block entry & exits on `with` exit | State managed explicitly or paired with an async lifespan fixture |
| **Realtime Protocols** | HTTP, SSE, JSONL, and `client.websocket_connect(...)` | HTTP, SSE (`ac.stream(...)`), and JSONL on the active loop |
| **Async DB Transactions** | Separate portal loop complicates shared async DB fixtures | Runs on the **exact same event loop** as async DB rollback fixtures |

### Lifespan Context & Safe `dependency_overrides` Cleanup

Two subtle mistakes cause flaky FastAPI test suites in large repositories:

1. **Omitting the `with` Statement on `TestClient`**: Instantiating `client = TestClient(app)` *without* `with TestClient(app) as client:` skips your `@asynccontextmanager` `lifespan` startup and shutdown hooks completely!
2. **Leaking `app.dependency_overrides` Across Tests**: Because `app.dependency_overrides` mutates a dictionary on the `FastAPI` instance, always clear overrides inside a `try ... finally: app.dependency_overrides.clear()` block (or a `yield` pytest fixture) so test doubles never bleed into subsequent tests.

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

### Native Async Testing with `@pytest.mark.anyio` & `httpx.ASGITransport`

When testing async database rollbacks, [native OpenTelemetry spans](telemetry_and_errors.md), or concurrent request behavior, drive the app directly with `httpx.ASGITransport`:

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

## 2. Production ASGI Topology, Health Probes & Graceful Shutdown

In Kubernetes, Cloud Run, or systemd deployments, place single-process Uvicorn ASGI workers behind a TLS-terminating reverse proxy or load balancer and let the container orchestrator manage horizontal replica scaling:

```drawlib align=center code=fold file=production_asgi_readiness.png caption="Production ASGI Deployment Topology: Reverse Proxy, Uvicorn Worker, Health Probes & Graceful Lifespan Drain"
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

### Production ASGI Operations Checklist

1. **Separate Liveness (`/healthz`) from Readiness (`/readyz`)**:
   - `/healthz` (**Liveness**) must be an instantaneous, dependency-free `200 OK` check confirming the event loop is not deadlocked. Never query external databases inside `/healthz`—a transient DB blip would cause Kubernetes to restart all healthy pods simultaneously!
   - `/readyz` (**Readiness**) verifies `lifespan` warmup state and critical pool readiness, returning `503 Service Unavailable` during startup or graceful drain so load balancers stop routing new traffic without killing in-flight requests. Exclude probe paths from tracing (`exclude=lambda s: s.get("path") in {"/healthz", "/readyz"}`) to keep telemetry clean.
2. **Scale Replicas Horizontally (`1` Process per Container)**: In container orchestrators (Kubernetes, Cloud Run, ECS), run a single `uvicorn` process per container with `--timeout-graceful-shutdown` aligned to `terminationGracePeriodSeconds` so `SIGTERM` cleanly unwinds in-flight [SSE / WebSocket streams](../05_async_and_realtime/sse_websockets_streaming.md) and exits your `lifespan` `finally` block.
3. **Trust Proxy Headers Explicitly**: Bind local sidecar workers to `127.0.0.1` (or restrict `--forwarded-allow-ips` to known load-balancer CIDRs) so `X-Forwarded-For` and `X-Forwarded-Proto` cannot be spoofed by untrusted clients:

```bash
uvicorn app.main:app \
  --host 127.0.0.1 \
  --port 8000 \
  --proxy-headers \
  --timeout-graceful-shutdown 30 \
  --no-access-log
```

Return to the [Overview & Architecture Map](../index.md) to review how all six chapters connect across the FastAPI `v0.162.2` stack.
