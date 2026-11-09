# Enterprise DI Aliases, Lifespan Management & Test Pyramid

Maintaining sub-second test feedback and deterministic resource cleanup across **500+ endpoints and 100,000+ LOC** requires separating **process-scoped infrastructure** (`lifespan`), **request-scoped Unit-of-Work wiring** (`Annotated[..., Depends]`), **pure domain exceptions** (`@app.exception_handler`), and **hermetic contract tests** (`app.dependency_overrides`).

```drawlib align=center code=hide file=enterprise_di_lifespan_flow.png caption="Two-Tier Lifespan & Request-Scoped Dependency Injection Flow with RFC 9457 Domain Error Translation"
from drawlib.canvas import save, setup
from drawlib.diagrams.architecture import ArchitectureDiagram, Node, NodeGroup, PhosphorIcon
from drawlib.styles import Styles
from drawlib.text import text

setup(width=180, height=88, dpi=150)

text(
    (90, 82.5),
    "Enterprise Lifespan, Scoped DI Wiring & RFC 9457 Exception Boundary",
    style=Styles.DarkBold.patch(text_size=13.5),
)

diag = ArchitectureDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.2),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.DarkBold.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
)

# Zone 1: Process Lifespan (Once per Worker)
life_grp = diag.add(
    NodeGroup(
        title="1. Process Lifespan (app.state)",
        width=46,
        height=65,
        style=Styles.SecondaryNeutral.patch(shape_r=2.0),
        text_style=Styles.SecondaryBold.patch(halign="left", text_size=10.8),
    ),
    (6, 8),
)
life_node = life_grp.add(
    Node(
        "Lifespan Hook\n(Startup / Shutdown)",
        width=36,
        height=18,
        icon=PhosphorIcon.STACK,
        card_style=Styles.White,
    ),
    (23, 44),
)
pool_node = life_grp.add(
    Node(
        "AppContainer\n(DB Pool & HTTPX)",
        width=36,
        height=18,
        icon=PhosphorIcon.DATABASE,
        card_style=Styles.White,
    ),
    (23, 16),
)

# Zone 2: Per-Request DI Graph (Annotated Aliases)
di_grp = diag.add(
    NodeGroup(
        title="2. Per-Request DI (Depends)",
        width=52,
        height=65,
        style=Styles.PrimaryNeutral.patch(shape_r=2.0),
        text_style=Styles.PrimaryBold.patch(halign="left", text_size=10.8),
    ),
    (64, 8),
)
uow_node = di_grp.add(
    Node(
        "DbSessionDep\n(yield, scope='function')",
        width=42,
        height=18,
        icon=PhosphorIcon.ARROWS_CLOCKWISE,
        card_style=Styles.White,
    ),
    (26, 44),
)
route_node = di_grp.add(
    Node(
        "3-Line APIRouter\n+ CurrentActorDep",
        width=42,
        height=18,
        icon=PhosphorIcon.PLUGS_CONNECTED,
        card_style=Styles.PrimaryFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.2),
        style=Styles.WhiteBold,
    ),
    (26, 16),
)

# Zone 3: Pure Domain & RFC 9457 Edge
dom_grp = diag.add(
    NodeGroup(
        title="3. Domain & ASGI Edge",
        width=46,
        height=65,
        style=Styles.Neutral.patch(shape_r=2.0),
        text_style=Styles.DarkBold.patch(halign="left", text_size=10.8),
    ),
    (128, 8),
)
uc_node = dom_grp.add(
    Node(
        "OrderUseCase\n(Pure Domain Logic)",
        width=36,
        height=18,
        icon=PhosphorIcon.CUBE,
        card_style=Styles.White,
    ),
    (23, 44),
)
err_node = dom_grp.add(
    Node(
        "DomainError ->\nRFC 9457 JSON",
        width=36,
        height=18,
        icon=PhosphorIcon.SHIELD_WARNING,
        card_style=Styles.DangerNeutral,
        text_style=Styles.DangerBold.patch(text_size=10.2),
        style=Styles.DangerBold,
    ),
    (23, 16),
)

# Connections across lifecycle tiers
diag.connect(life_node, pool_node, label="owns")
diag.connect(pool_node, uow_node, label="pool", routing="orthogonal")
diag.connect(uow_node, route_node, label="injects")
diag.connect(route_node, uc_node, label="calls", routing="orthogonal")
diag.connect(uc_node, err_node, label="raises")

diag.draw()
save()
```

---

## 1. Deterministic Process Lifespan vs. Import-Time Globals

One of the costliest anti-patterns in large Python backends is instantiating database engines, Redis clients, or `httpx.AsyncClient` pools as **module-level globals** executed the moment Python imports a file (`engine = create_async_engine(os.environ["DB_URL"])`).

### Software Engineering Principle: Zero Import-Time I/O

At 100,000+ LOC, module-import side effects trigger cascading operational failures:

- **Broken Test Collection & CLI Tooling**: Importing any schema or helper transitively opens live TCP sockets or crashes immediately when production environment variables are absent during `pytest --collect-only` or OpenAPI export scripts.
- **Unsafe Multi-Worker Process Forking**: Process managers (such as Gunicorn with Uvicorn workers) import the application before `fork()`; sockets or event-loop locks created prior to forking corrupt child worker file descriptors.
- **Leaked Connections on Rollout**: Without an explicit teardown hook, in-flight connection pools and telemetry batch exporters drop data abruptly during Kubernetes `SIGTERM` pod drains.

### Applying FastAPI: `@asynccontextmanager lifespan` + Typed `AppContainer`

FastAPI `v0.162.2` delegates process startup and shutdown to a standard Python `@asynccontextmanager` passed via `FastAPI(lifespan=lifespan)`. Encapsulate shared long-lived pools inside a typed `AppContainer` dataclass attached to `app.state.container`, wrapping `yield` in `try ... finally` so resources always close cleanly even if an unhandled startup or runtime error occurs:

```python
# src/shared/lifespan.py — Deterministic startup/shutdown without module-import I/O
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from dataclasses import dataclass, field

from fastapi import FastAPI


@dataclass
class ConnectionPool:
    dsn: str
    is_open: bool = False
    events: list[str] = field(default_factory=list)

    async def startup(self) -> None:
        self.is_open = True
        self.events.append("pool_opened")

    async def close(self) -> None:
        self.is_open = False
        self.events.append("pool_closed")


@dataclass
class AppContainer:
    """Strongly typed holder for process-scoped infrastructure pools."""

    db_pool: ConnectionPool
    order_repo: InMemoryOrderRepository
    stock_by_sku: dict[str, int]


def create_enterprise_app(pool: ConnectionPool | None = None) -> FastAPI:
    managed_pool = pool or ConnectionPool(
        dsn="postgresql+asyncpg://127.0.0.1:5432/orders"
    )

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        await managed_pool.startup()
        app.state.container = AppContainer(
            db_pool=managed_pool,
            order_repo=InMemoryOrderRepository(),
            stock_by_sku={"SKU-PRO-10": 5},
        )
        try:
            yield
        finally:
            await managed_pool.close()

    return FastAPI(title="Enterprise Commerce Platform", lifespan=lifespan)
```

---

## 2. Composable `Annotated` Dependency Aliases & Scoped Unit-of-Work

When an API grows to **500+ route operations**, repeating `db: AsyncSession = Depends(get_db_session)` and `actor: User = Depends(get_current_actor)` in every endpoint signature creates massive boilerplate and makes refactoring dependency graphs painful.

### Software Engineering Principle: Constructor Injection & Explicit Unit-of-Work

Enterprise applications separate **object graph wiring** from **HTTP controller signatures**:

- **Thin Transport Controllers**: Route functions should validate HTTP inputs, delegate to a single injected Application `UseCase`, and return a result in **3 to 5 lines of code**.
- **Atomic Unit-of-Work (UoW) Transactions**: Every mutating request should acquire a transaction session, commit atomically if the use case succeeds, roll back immediately on any exception, and release the connection back to the pool **before** the client receives a `200`/`201` confirmation.

### Applying FastAPI: `Annotated` Type Aliases & `Depends(..., scope="function")`

Define reusable `Annotated` type aliases (`ContainerDep`, `DbSessionDep`, `CurrentActorDep`, `OrderUseCaseDep`) once in `presentation/dependencies.py`. Crucially, FastAPI `v0.162.2` supports `Depends(get_uow_session, scope="function")` on generator (`yield`) dependencies—executing the post-`yield` `commit()` / `rollback()` / `close()` block **immediately after the route function finishes and before the HTTP response is sent** (see [Dependant DAG, Caching & Scopes](../04_dependencies_and_security/dependency_injection.md) for full `scope` mechanics):

```python
# src/orders/presentation/dependencies.py — Composable Annotated DI aliases
from collections.abc import AsyncIterator
from dataclasses import dataclass
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status


@dataclass
class UnitOfWorkSession:
    pool: ConnectionPool

    async def commit(self) -> None:
        self.pool.events.append("uow_committed")

    async def rollback(self) -> None:
        self.pool.events.append("uow_rolled_back")

    async def close(self) -> None:
        self.pool.events.append("uow_closed")


@dataclass(frozen=True, slots=True)
class AuthenticatedActor:
    actor_id: str
    tenant_id: str


def get_container(request: Request) -> AppContainer:
    container: AppContainer = request.app.state.container
    return container


ContainerDep = Annotated[AppContainer, Depends(get_container)]


async def get_uow_session(container: ContainerDep) -> AsyncIterator[UnitOfWorkSession]:
    session = UnitOfWorkSession(pool=container.db_pool)
    try:
        yield session
        await session.commit()
    except Exception:
        await session.rollback()
        raise
    finally:
        await session.close()


# scope="function" commits/rolls back BEFORE sending HTTP bytes to the client!
DbSessionDep = Annotated[UnitOfWorkSession, Depends(get_uow_session, scope="function")]


async def get_current_actor(
    x_actor_id: Annotated[str, Header(min_length=3)],
    x_tenant_id: Annotated[str, Header(min_length=3)],
) -> AuthenticatedActor:
    if not x_actor_id.startswith("usr_"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid actor token.",
        )
    return AuthenticatedActor(actor_id=x_actor_id, tenant_id=x_tenant_id)


CurrentActorDep = Annotated[AuthenticatedActor, Depends(get_current_actor)]


def get_order_repo(container: ContainerDep) -> OrderRepositoryPort:
    return container.order_repo


OrderRepoDep = Annotated[OrderRepositoryPort, Depends(get_order_repo)]


def get_order_use_case(
    container: ContainerDep,
    repo: OrderRepoDep,
    uow: DbSessionDep,
) -> EnterpriseOrderUseCase:
    return EnterpriseOrderUseCase(
        repo=repo, uow=uow, stock_by_sku=container.stock_by_sku
    )


OrderUseCaseDep = Annotated[EnterpriseOrderUseCase, Depends(get_order_use_case)]

# Route signatures remain 3-line thin across 500+ endpoints:
router = APIRouter(prefix="/v1/orders", tags=["orders"])


@router.post("", response_model=OrderReadDTO, status_code=status.HTTP_201_CREATED)
async def create_order(
    payload: OrderCreateDTO,
    actor: CurrentActorDep,
    use_case: OrderUseCaseDep,
) -> OrderEntity:
    return await use_case.place_order(actor, payload)
```

---

## 3. Translating Domain Exceptions to RFC 9457 Problem Details

As established in [Bounded Contexts & Layering](modular_design.md), domain entities and use cases raise pure Python exceptions (`OrderNotFoundError`, `InsufficientInventoryError`, `TenantAccessDeniedError`) rather than `fastapi.HTTPException`.

### Applying FastAPI: Centralized `@app.exception_handler(DomainError)`

Register a single `@app.exception_handler(DomainError)` at the ASGI composition root to translate domain exceptions into standardized **RFC 9457 Problem Details (`application/problem+json`)** responses without leaking internal SQL queries or stack traces (see [Native OpenTelemetry & Exceptions](../06_observability_and_testing/telemetry_and_errors.md) for tracing correlation):

```python
# src/shared/problem_details.py — Single ASGI boundary mapping DomainError -> RFC 9457
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse


def register_domain_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(DomainError)
    async def handle_domain_error(request: Request, exc: DomainError) -> JSONResponse:
        if isinstance(exc, OrderNotFoundError):
            http_status = status.HTTP_404_NOT_FOUND
            error_type = "https://api.example.com/problems/order-not-found"
            title = "Order Not Found"
        elif isinstance(exc, InsufficientInventoryError):
            http_status = status.HTTP_409_CONFLICT
            error_type = "https://api.example.com/problems/insufficient-inventory"
            title = "Insufficient Inventory"
        elif isinstance(exc, TenantAccessDeniedError):
            http_status = status.HTTP_403_FORBIDDEN
            error_type = "https://api.example.com/problems/tenant-access-denied"
            title = "Tenant Access Denied"
        else:
            http_status = status.HTTP_400_BAD_REQUEST
            error_type = "https://api.example.com/problems/domain-rule-violation"
            title = "Domain Rule Violation"

        return JSONResponse(
            status_code=http_status,
            media_type="application/problem+json",
            content={
                "type": error_type,
                "title": title,
                "status": http_status,
                "detail": str(exc),
                "instance": request.url.path,
            },
        )
```

---

## 4. The 100k+ LOC Test Pyramid & Hermetic `dependency_overrides`

Teams that test every single business branch by booting a real PostgreSQL container and sending HTTP requests through `TestClient` quickly hit a **45-minute CI wall** once the test suite reaches 5,000 cases. Conversely, teams that rely heavily on `unittest.mock.patch("src.orders.crud.db.execute")` suffer brittle tests that break whenever an internal module is renamed.

```drawlib align=center code=hide file=enterprise_test_pyramid.png caption="100k+ LOC Enterprise Test Pyramid: 70% Pure Domain Unit, 20% FastAPI Contract Overrides, 10% Containerized Integration"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, Pyramid
from drawlib.styles import Styles
from drawlib.text import text

setup(width=174, height=86, dpi=150)

text(
    (87, 80.5),
    "Enterprise Test Pyramid for 100k+ LOC FastAPI Systems",
    style=Styles.DarkBold.patch(text_size=13.5),
)

# Left: 3-Tier Testing Pyramid (Base at bottom, vertex_to_base: Top=10%, Mid=20%, Base=70%)
pyramid = Pyramid(
    style=Styles.Neutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
)
pyramid.add(
    "10%\nE2E",
    style=Styles.SecondaryNeutral,
    text_style=Styles.SecondaryBold.patch(text_size=10.5),
)
pyramid.add(
    "20% HTTP Contract\n& DI Overrides",
    style=Styles.PrimaryNeutral,
    text_style=Styles.PrimaryBold.patch(text_size=10.8),
)
pyramid.add(
    "70% Pure Domain & UseCase Unit Tests",
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.0),
)
pyramid.draw(
    xy=(6, 8),
    width=64,
    height=64,
    margin=2.2,
    direction="bottom",
    order="vertex_to_base",
)

# Right: Aligned Tier Specifications via CardList
cards = CardList(
    style=Styles.Neutral.patch(shape_r=1.8),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.SecondaryBold.patch(text_size=10.0),
    icon_style=Styles.SecondaryBold,
    direction="vertical",
    spacing=3.0,
)
cards.add(
    "Containerized Lifespan & DB (~50–200 ms)",
    "Real PostgreSQL/Redis via Testcontainers,\nSQL migrations & lifespan shutdown.",
    badge_text="10%",
    icon=phosphor.database,
)
cards.add(
    "FastAPI Router & Contract Tests (~2–8 ms)",
    "TestClient + app.dependency_overrides:\nDTO 422s, Auth headers & RFC 9457 JSON.",
    badge_text="20%",
    icon=phosphor.plugs_connected,
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
)
cards.add(
    "Pure Domain & UseCase Tests (< 0.5 ms)",
    "In-memory Protocol fakes, zero ASGI/HTTP,\n1,000+ deterministic cases/sec in CI.",
    badge_text="70%",
    icon=phosphor.lightning,
    style=Styles.PrimaryNeutral.patch(shape_r=1.8),
    badge_style=Styles.PrimaryFlat,
    badge_text_style=Styles.WhiteBold.patch(text_size=10.0),
    icon_style=Styles.WhiteBold,
)
cards.draw(xy=(76, 8), width=92, height=64)

save()
```

### Applying FastAPI: Sub-Millisecond Unit Tests + `app.dependency_overrides`

Because our `Domain` and `UseCase` layers depend only on `Protocol` ports, **70% of tests execute directly in memory without touching ASGI or HTTP**. For the **20% HTTP Contract tier**, FastAPI's `app.dependency_overrides` swaps callable dependency keys cleanly by reference—always wrapped in `try ... finally: app.dependency_overrides.clear()` so test state never leaks across cases (see [Testing Patterns & Production ASGI](../06_observability_and_testing/testing_and_deployment.md) for async `httpx.AsyncClient` and load-testing setups):

```python
# tests/orders/test_order_contracts.py — Pure Unit Tier + Hermetic Override Tier
import pytest
from fastapi.testclient import TestClient


# 1. 70% Tier: Pure UseCase unit test (< 0.5 ms, zero ASGI or HTTP overhead)
@pytest.mark.anyio
async def test_place_order_rejects_insufficient_inventory() -> None:
    repo = InMemoryOrderRepository()
    uow = UnitOfWorkSession(pool=ConnectionPool(dsn="memory://unit"))
    use_case = EnterpriseOrderUseCase(
        repo=repo, uow=uow, stock_by_sku={"SKU-PRO-10": 3}
    )
    actor = AuthenticatedActor(actor_id="usr_alice", tenant_id="tnt_acme")

    with pytest.raises(InsufficientInventoryError):
        await use_case.place_order(
            actor,
            OrderCreateDTO(
                customer_id="cust_100",
                lines=[
                    OrderLineInputDTO(
                        sku="SKU-PRO-10", quantity=9, unit_price_cents=1500
                    )
                ],
            ),
        )


# 2. 20% Tier: Hermetic FastAPI contract test with guaranteed override cleanup
def test_http_contract_and_dependency_override_isolation() -> None:
    pool = ConnectionPool(dsn="postgresql+asyncpg://127.0.0.1:5432/orders")
    app = create_enterprise_app(pool=pool)
    headers = {"X-Actor-Id": "usr_alice", "X-Tenant-Id": "tnt_acme"}

    with TestClient(app) as client:
        # Verify domain InsufficientInventoryError -> 409 RFC 9457 Problem Details
        conflict = client.post(
            "/v1/orders",
            headers=headers,
            json={
                "customer_id": "cust_42",
                "lines": [
                    {"sku": "SKU-PRO-10", "quantity": 99, "unit_price_cents": 4000}
                ],
            },
        )
        assert conflict.status_code == 409
        assert conflict.headers["content-type"].startswith("application/problem+json")
        assert conflict.json()["title"] == "Insufficient Inventory"

        # Swap OrderRepositoryPort hermetically without monkeypatching import strings
        isolated_repo = InMemoryOrderRepository()
        app.dependency_overrides[get_order_repo] = lambda: isolated_repo
        try:
            missing = client.get("/v1/orders/ord_9001", headers=headers)
            assert missing.status_code == 404
            assert missing.json()["title"] == "Order Not Found"
        finally:
            app.dependency_overrides.clear()

    # Exiting TestClient context triggers lifespan finally -> pool.close()
    assert pool.is_open is False
```

Next, continue to Chapter 3 ([Path, Query, Header, Cookie & Body](../03_routing_and_models/parameters_and_validation.md)) to explore how FastAPI inspects `Annotated` parameter metadata and compiles high-throughput Pydantic v2 validators under the hood.
