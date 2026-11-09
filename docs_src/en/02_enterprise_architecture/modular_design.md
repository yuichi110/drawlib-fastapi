# Bounded Contexts, Package Structure & Inward Layering

Scaling a Python backend past **100,000 lines of code (LOC)** and dozens of engineers requires shifting from horizontal technical folders (`routers/`, `models/`, `schemas/`) to **domain-aligned Bounded Contexts** governed by strict inward dependency rules. FastAPI `v0.162.2` supports this transition natively through composable `APIRouter` trees, `Protocol`-friendly dependency injection, and strict Pydantic v2 boundary contracts.

```drawlib align=center code=hide file=enterprise_bounded_contexts.png caption="Anti-Pattern Horizontal Layer Sprawl vs. 100k+ LOC Modular Monolith by Bounded Context"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.lines import line
from drawlib.shapes import rectangle
from drawlib.smartarts import Panel, TreeNode
from drawlib.styles import Styles
from drawlib.text import text

setup(width=164, height=82, dpi=150)

text(
    (82, 76.5),
    "Package Topology at Scale: Horizontal Sprawl vs. Bounded Contexts",
    style=Styles.DarkBold.patch(text_size=13.5),
)

# Left Panel: Anti-Pattern (>15k LOC Horizontal Layer Sprawl)
left_panel = Panel(
    "Anti-Pattern: Horizontal Layer Sprawl",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.DangerNeutral.patch(shape_r=2.0),
    text_style=Styles.DangerBold.patch(text_size=11.0),
    icon=phosphor.warning,
    icon_style=Styles.DangerBold,
    header_variant="filled",
    header_height=8.5,
)
left_panel.draw(xy=(5, 6), width=74, height=65)

bad_tree = TreeNode(
    "app/  (100+ files per folder)",
    text_style=Styles.DarkBold.patch(text_size=10.5),
    line_style=Styles.MutedBold,
    line_horizontal_margin=3.0,
    line_horizontal_length=3.2,
    line_vertical_margin=5.2,
)
bad_tree.add("routers/   (85 endpoints mixed)", text_style=Styles.Dark.patch(text_size=10.2))
bad_tree.add("models/    (90 coupled ORM tables)", text_style=Styles.Dark.patch(text_size=10.2))
bad_tree.add("schemas/   (140 shared DTOs)", text_style=Styles.Dark.patch(text_size=10.2))
bad_tree.add("crud/      (cross-domain SQL joins)", text_style=Styles.Dark.patch(text_size=10.2))
bad_tree.draw(xy=(9.5, 58.0))

rectangle(
    (42, 18.0),
    width=66,
    height=19.0,
    style=Styles.DangerNeutral.patch(shape_r=1.5),
)
text(
    (42, 23.8),
    "Failure Modes Past ~15,000 LOC",
    style=Styles.DangerBold.patch(text_size=10.5),
)
text(
    (42, 14.8),
    "• Shotgun surgery across 4+ giant folders\n• Circular imports between crud/ & models/\n• Implicit DB joins block service extraction",
    style=Styles.Dark.patch(text_size=10.0),
)

# Right Panel: Target 100k+ LOC Modular Monolith
right_panel = Panel(
    "100k+ LOC Target: Bounded Context Slices",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.PrimaryFlat.patch(shape_r=2.0),
    text_style=Styles.WhiteBold.patch(text_size=11.0),
    icon=phosphor.shield_check,
    icon_style=Styles.WhiteBold,
    header_variant="filled",
    header_height=8.5,
)
right_panel.draw(xy=(85, 6), width=74, height=65)

good_tree = TreeNode(
    "src/  (Modular Monolith)",
    text_style=Styles.PrimaryBold.patch(text_size=10.5),
    line_style=Styles.PrimaryBold,
    line_horizontal_margin=3.0,
    line_horizontal_length=3.2,
    line_vertical_margin=5.2,
)
good_tree.add("orders/    (router, use_cases, domain, infra)", text_style=Styles.Dark.patch(text_size=10.2))
good_tree.add("billing/   (router, use_cases, domain, infra)", text_style=Styles.Dark.patch(text_size=10.2))
good_tree.add("identity/  (router, use_cases, domain, infra)", text_style=Styles.Dark.patch(text_size=10.2))
good_tree.add("shared/    (uow, problem_json, telemetry)", text_style=Styles.Dark.patch(text_size=10.2))
good_tree.draw(xy=(89.5, 58.0))

# Mini inward-dependency diagram inside right panel footer
rectangle((102, 22.0), width=24, height=8.0, style=Styles.PrimaryNeutral.patch(shape_r=1.5), text="orders/", text_style=Styles.DarkBold.patch(text_size=10.2))
rectangle((142, 22.0), width=24, height=8.0, style=Styles.PrimaryNeutral.patch(shape_r=1.5), text="billing/", text_style=Styles.DarkBold.patch(text_size=10.2))
rectangle((122, 11.2), width=42, height=7.6, style=Styles.SecondaryNeutral.patch(shape_r=1.5), text="shared/ + Public Ports", text_style=Styles.DarkBold.patch(text_size=10.0))

line((102, 18.0), (112, 15.0), arrow_head="->", style=Styles.PrimaryBold)
line((142, 18.0), (132, 15.0), arrow_head="->", style=Styles.PrimaryBold)

save()
```

---

## 1. Why Horizontal Layer Folders Collapse Past 15,000 LOC

In a 2,000-LOC tutorial or prototype, grouping files by technical role—`app/routers/`, `app/models/`, `app/schemas/`, and `app/crud/`—feels tidy because every folder contains only three or four modules. Once an engineering organization scales past **15,000 to 100,000+ LOC**, that same layout violates **Common Closure Principle (CCP)**: code that changes together for a single business requirement is scattered across the entire repository.

### Software Engineering Principles: Cohesion & Bounded Contexts

Large-scale maintainability rests on three foundational software engineering laws:

- **Vertical Cohesion over Technical Categorization**: Adding a single capability (such as partial order refunds) should modify files inside `src/orders/` and nowhere else, minimizing Git merge conflicts across parallel squads.
- **Explicit Context Boundaries (DDD Bounded Contexts)**: An `Account` in `identity/` (credentials, MFA, OAuth scopes) is fundamentally different from an `Account` in `billing/` (tax ID, ledger balance, invoice terms). Separating packages prevents a bloated, 80-column "God `User` Table" shared by every team.
- **Zero Cross-Context ORM Joins**: Bounded contexts communicate exclusively through explicit application ports or domain events—never by importing another context's SQLAlchemy table into a `JOIN` query. Preserving data autonomy lets you extract a high-load slice (like `billing/`) into a standalone microservice later without rewriting business logic.

### Applying FastAPI: Hierarchical `APIRouter` Composition

FastAPI's `APIRouter` is a lightweight route-registration tree, not a rigid controller base class. Each bounded context owns its internal package hierarchy and exports **only** a thin `router` object to the top-level composition root (`src/main.py`):

```text
src/
├── main.py                      # ASGI composition root (lifespan, exception handlers, v1_router)
├── shared/                      # Cross-cutting infrastructure (telemetry, RFC 9457 errors, UoW base)
├── identity/                    # Bounded Context: Authentication & Tenant RBAC
│   ├── domain/                  # Pure entities, value objects, DomainError subclasses
│   ├── application/             # UseCases & Protocol ports
│   ├── infrastructure/          # SQLAlchemy / OIDC adapters
│   └── presentation/            # FastAPI APIRouter,Annotated DI wiring, Pydantic DTOs
├── orders/                      # Bounded Context: Order Lifecycle & Inventory Reservation
│   ├── domain/
│   ├── application/
│   ├── infrastructure/
│   └── presentation/
└── billing/                     # Bounded Context: Invoicing & Payment Capture
    ├── domain/
    ├── application/
    ├── infrastructure/
    └── presentation/
```

---

## 2. The Inward Dependency Rule (Clean & Hexagonal Architecture)

Organizing folders by domain is only half of the battle. Inside each bounded context (`src/orders/`), dependencies must point **strictly inward** toward business rules—never outward toward HTTP transport details or database drivers.

```drawlib align=center code=hide file=clean_layering_fastapi_mapping.png caption="Clean/Hexagonal Inward Dependency Rule Mapped to FastAPI v0.162.2 Constructs"
from drawlib.canvas import save, setup
from drawlib.diagrams.architecture import ArchitectureDiagram, Node, NodeGroup, PhosphorIcon
from drawlib.shapes import rectangle
from drawlib.styles import Styles
from drawlib.text import text

setup(width=180, height=84, dpi=150)

text(
    (90, 78.5),
    "Inward Dependency Rule Inside Each Bounded Context (src/orders/)",
    style=Styles.DarkBold.patch(text_size=13.5),
)

diag = ArchitectureDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.5),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.DarkBold.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
)

# 1. Outer Left: HTTP Presentation Layer
pres_grp = diag.add(
    NodeGroup(
        title="1. Presentation (HTTP)",
        width=35,
        height=50,
        style=Styles.PrimaryNeutral.patch(shape_r=2.0),
        text_style=Styles.PrimaryBold.patch(halign="left", text_size=10.8),
    ),
    (6, 22),
)
router_node = pres_grp.add(
    Node(
        "APIRouter &\nPydantic DTOs",
        width=27,
        height=16,
        icon=PhosphorIcon.GLOBE,
        card_style=Styles.White,
    ),
    (17.5, 33),
)
di_node = pres_grp.add(
    Node(
        "Annotated DI &\nError Handlers",
        width=27,
        height=15,
        icon=PhosphorIcon.PLUGS_CONNECTED,
        card_style=Styles.White,
    ),
    (17.5, 12),
)

# 2. Middle Left: Application Layer
app_grp = diag.add(
    NodeGroup(
        title="2. Application",
        width=34,
        height=50,
        style=Styles.SecondaryNeutral.patch(shape_r=2.0),
        text_style=Styles.SecondaryBold.patch(halign="left", text_size=10.8),
    ),
    (52, 22),
)
uc_node = app_grp.add(
    Node(
        "PlaceOrder\nUseCase",
        width=26,
        height=18,
        icon=PhosphorIcon.GEAR,
        card_style=Styles.White,
    ),
    (17.0, 24),
)

# 3. Inner Focal Core: Domain Layer
dom_grp = diag.add(
    NodeGroup(
        title="3. Domain Core (Pure)",
        width=35,
        height=50,
        style=Styles.PrimaryDashed.patch(shape_r=2.0),
        text_style=Styles.PrimaryBold.patch(halign="left", text_size=10.8),
    ),
    (97, 22),
)
ent_node = dom_grp.add(
    Node(
        "OrderEntity &\nDomainError",
        width=27,
        height=16,
        icon=PhosphorIcon.CUBE,
        card_style=Styles.PrimaryFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.5),
        style=Styles.WhiteBold,
    ),
    (17.5, 33),
)
port_node = dom_grp.add(
    Node(
        "RepositoryPort\n(Protocol)",
        width=27,
        height=15,
        icon=PhosphorIcon.SHIELD_CHECK,
        card_style=Styles.PrimaryNeutral,
    ),
    (17.5, 12),
)

# 4. Outer Right: Infrastructure Adapters
infra_grp = diag.add(
    NodeGroup(
        title="4. Infrastructure",
        width=31,
        height=50,
        style=Styles.Neutral.patch(shape_r=2.0),
        text_style=Styles.DarkBold.patch(halign="left", text_size=10.8),
    ),
    (143, 22),
)
orm_node = infra_grp.add(
    Node(
        "SqlAlchemyRepo\n& HTTPX Client",
        width=24,
        height=18,
        icon=PhosphorIcon.DATABASE,
        card_style=Styles.White,
    ),
    (15.5, 24),
)

# Inward Dependency Arrows
diag.connect(router_node, uc_node, label="calls")
diag.connect(di_node, uc_node, routing="orthogonal")
diag.connect(uc_node, ent_node, label="uses")
diag.connect(uc_node, port_node, routing="orthogonal")
diag.connect(orm_node, port_node, label="impl", routing="orthogonal")

diag.draw()

# Bottom Architectural Rule Callout Banner
rectangle(
    (90, 10.5),
    width=168,
    height=9.5,
    style=Styles.Neutral.patch(shape_r=1.5),
)
text(
    (90, 10.5),
    "Golden Rule: Domain Core NEVER imports fastapi, Request, HTTPException, or SQLAlchemy Session globals.",
    style=Styles.DarkBold.patch(text_size=10.8),
)

save()
```

### Why `Domain` Must Never Import `fastapi` or `HTTPException`

A classic trap in growing FastAPI codebases is raising `HTTPException(status_code=409, detail=...)` or accepting `fastapi.Request` deep inside domain services and repositories. That coupling creates three systemic liabilities at 100k+ LOC:

1. **Broken Reusability Across Transports**: The moment you invoke the same order-placement logic from a CLI admin command, a Kafka/PubSub consumer, or a background worker, HTTP status codes (`409`) and `Request` headers make no sense.
2. **Untestable Domain Rules Without HTTP Scaffolding**: Engineers are forced to construct fake Starlette `Request` objects or parse JSON error responses just to unit-test pricing arithmetic.
3. **ORM Session Leakage**: Passing raw SQLAlchemy `AsyncSession` instances into domain entities tempts engineers to trigger lazy-loaded queries mid-calculation, blurring transaction boundaries.

### Pure Domain Ports (`Protocol`) & UseCases in Practice

In modern Python (`3.10+`), you do **not** need heavyweight abstract base class hierarchies or third-party IoC containers to invert dependencies. Define domain entities with `@dataclass(frozen=True, slots=True)` and declare infrastructure seams with `typing.Protocol`:

```python
# src/orders/domain/entities.py — Zero FastAPI, Pydantic, or ORM imports!
from dataclasses import dataclass
from typing import Protocol


class DomainError(Exception):
    """Transport-agnostic base class for business rule violations."""


class InsufficientInventoryError(DomainError):
    def __init__(self, sku: str, requested: int, available: int) -> None:
        self.sku = sku
        self.requested = requested
        self.available = available
        super().__init__(
            f"SKU '{sku}' requested {requested} units, but only {available} available."
        )


@dataclass(frozen=True, slots=True)
class OrderLine:
    sku: str
    quantity: int
    unit_price_cents: int


@dataclass(frozen=True, slots=True)
class OrderEntity:
    order_id: str
    tenant_id: str
    customer_id: str
    lines: tuple[OrderLine, ...]
    status: str = "CONFIRMED"

    @property
    def total_cents(self) -> int:
        return sum(line.quantity * line.unit_price_cents for line in self.lines)


class OrderRepositoryPort(Protocol):
    async def save(self, order: OrderEntity) -> OrderEntity: ...

    async def get_by_id(self, order_id: str) -> OrderEntity | None: ...


# src/orders/application/use_cases.py — Pure orchestration over Protocol ports
class PlaceOrderUseCase:
    def __init__(self, repo: OrderRepositoryPort, stock_by_sku: dict[str, int]) -> None:
        self._repo = repo
        self._stock = stock_by_sku

    async def execute(
        self,
        *,
        order_id: str,
        tenant_id: str,
        customer_id: str,
        lines: list[OrderLine],
    ) -> OrderEntity:
        for item in lines:
            available = self._stock.get(item.sku, 0)
            if item.quantity > available:
                raise InsufficientInventoryError(item.sku, item.quantity, available)
        entity = OrderEntity(
            order_id=order_id,
            tenant_id=tenant_id,
            customer_id=customer_id,
            lines=tuple(lines),
        )
        return await self._repo.save(entity)
```

---

## 3. DTO & Persistence Separation: Preventing Mass-Assignment & Leakage

In rapid prototypes, teams sometimes reuse a single model class (for example, one shared model representing the JSON request body, domain state, database table, and JSON response). In an enterprise system, collapsing those four boundaries creates severe security and schema-evolution hazards.

```drawlib align=center code=hide file=schema_separation_matrix.png caption="Four-Model Boundary Separation Preventing Mass-Assignment (CWE-915) and Internal Column Leakage"
from drawlib.canvas import save, setup
from drawlib.smartarts import ChevronProcess, Table
from drawlib.styles import Colors, Styles
from drawlib.text import text

setup(width=168, height=84, dpi=150)

text(
    (84, 78.5),
    "Strict Boundary Contracts: Inbound DTO -> Domain -> Persistence -> Outbound DTO",
    style=Styles.DarkBold.patch(text_size=13.0),
)

# Top Pipeline: 4 Distinct Model Boundaries
pipeline = ChevronProcess(
    style=Styles.PrimaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
    description_style=Styles.Dark.patch(text_size=10.0),
    corner_angle=62.0,
    spacing=1.8,
    flat_left_end=True,
)
pipeline.add("1. OrderCreateDTO", description="extra='forbid' (HTTP In)")
pipeline.add(
    "2. OrderEntity",
    description="Frozen Domain Core",
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.0),
    description_style=Styles.White.patch(text_size=10.0),
)
pipeline.add("3. OrderRecord", description="ORM Row (DB Columns)", style=Styles.SecondaryNeutral)
pipeline.add("4. OrderReadDTO", description="response_model (HTTP Out)", style=Styles.Neutral)
pipeline.draw(xy=(6, 56), width=156, height=16)

# Bottom Comparison Matrix Table (Top-Left anchored at y=50)
table = Table(
    cell_style=Styles.White,
    text_style=Styles.Dark.patch(text_size=10.2),
    header_cell_style=Styles.PrimaryFlat,
    header_text_style=Styles.WhiteBold.patch(text_size=10.5),
    border_style=Styles.MutedThin,
)
table.set_style_cell_evenodd(
    even_color=Colors.White,
    even_text_style=Styles.Dark.patch(text_size=10.2),
    odd_color=Colors.Gray1,
    odd_text_style=Styles.Dark.patch(text_size=10.2),
)
table.set_style_cell_header(
    background_color=Colors.Primary,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
)
table.draw_flexible(
    xy=(6, 50),
    column_widths=[32, 30, 44, 50],
    row_heights=[8.5, 8.5, 8.5, 8.5, 8.5],
    data=[
        ["Model Class", "Architectural Layer", "Key Implementation Guard", "Failure Prevented at 100k+ LOC"],
        ["OrderCreateDTO", "Presentation (In)", "BaseModel + extra='forbid'", "Blocks mass-assignment (status='PAID')"],
        ["OrderEntity", "Domain Core", "@dataclass(frozen=True, slots=True)", "Enforces invariants without HTTP/ORM"],
        ["OrderRecord", "Infrastructure", "SQLAlchemy Declarative Row", "Isolates indexes, shards & audit columns"],
        ["OrderReadDTO", "Presentation (Out)", "response_model=OrderReadDTO", "Strips internal_fraud_score & PII fields"],
    ],
)

save()
```

### Applying FastAPI: Strict Inbound `extra="forbid"` & Outbound `response_model`

Pair strict inbound Pydantic DTOs with `response_model=OrderReadDTO` on every `APIRouter` operation so internal persistence fields (`internal_fraud_score`, `shard_routing_key`, password hashes) are structurally stripped before serialization (see [Response Serialization & OpenAPI 3.1](../03_routing_and_models/responses_and_openapi.md) for Rust-backed `TypeAdapter` serialization internals):

```python
# src/orders/presentation/router.py — Strict DTO contracts + hierarchical APIRouter
from dataclasses import dataclass
from typing import Annotated

from fastapi import APIRouter, Depends, FastAPI, status
from pydantic import BaseModel, ConfigDict, Field


class OrderLineInputDTO(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    sku: str = Field(min_length=3, max_length=32, pattern=r"^[A-Z0-9_-]+$")
    quantity: int = Field(gt=0, le=1000)
    unit_price_cents: int = Field(gt=0)


class OrderCreateDTO(BaseModel):
    # Rejects undeclared fields (e.g. status="PAID") with 422 Unprocessable Content
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    customer_id: str = Field(min_length=3, max_length=64)
    lines: list[OrderLineInputDTO] = Field(min_length=1, max_length=50)


@dataclass
class OrderRecord:
    """Persistence row containing sensitive internal metadata."""

    order_id: str
    tenant_id: str
    customer_id: str
    total_cents: int
    status: str
    internal_fraud_score: float = 0.02
    shard_routing_key: str = "shard-ap-northeast-1a"


class OrderReadDTO(BaseModel):
    """Public outbound contract; omits internal_fraud_score & shard_routing_key."""

    model_config = ConfigDict(from_attributes=True)

    order_id: str
    customer_id: str
    total_cents: int
    status: str


orders_router = APIRouter(prefix="/orders", tags=["orders"])


@orders_router.post("", response_model=OrderReadDTO, status_code=status.HTTP_201_CREATED)
async def create_order(
    payload: OrderCreateDTO,
    use_case: Annotated[PlaceOrderUseCase, Depends(get_place_order_use_case)],
) -> OrderRecord:
    entity = await use_case.execute(
        order_id="ord_2026_001",
        tenant_id="tnt_enterprise",
        customer_id=payload.customer_id,
        lines=[
            OrderLine(
                sku=item.sku,
                quantity=item.quantity,
                unit_price_cents=item.unit_price_cents,
            )
            for item in payload.lines
        ],
    )
    return persist_and_load_record(entity)


# src/main.py — Top-level versioned router composition
v1_router = APIRouter(prefix="/api/v1")
v1_router.include_router(orders_router)

app = FastAPI(title="Enterprise Commerce API")
app.include_router(v1_router)
```

---

## 4. Enforcing Architectural Boundaries Mechanically in CI

In a 100k+ LOC repository with 30+ contributors, architectural rules documented only in Markdown wikis inevitably erode under deadline pressure. Treat package boundaries and type contracts as **automated CI fitness functions**.

### Why FastAPI Route & DTO Modules Should Omit `from __future__ import annotations`

Unlike static-only libraries where annotations are erased at runtime, FastAPI `v0.162.2` and Pydantic v2 **introspect function signatures and `Annotated[...]` metadata at import/startup time** (via `typing_inspection` and `get_typed_signature`) to build OpenAPI 3.1 schemas, parameter validators, and dependency DAGs.

> [!IMPORTANT]
> **Enterprise Rule for FastAPI Annotations**: Python `3.10+` natively supports `X | Y` union syntax and `list[str]` / `dict[str, Any]` generics at runtime (and Python `3.14` implements PEP 649 deferred evaluation natively). **Omit `from __future__ import annotations` in FastAPI `router.py`, `dependencies.py`, and Pydantic `schemas.py` modules.** Turning annotations into raw strings breaks runtime resolution whenever a parameter type is defined in a local scope or hidden behind `if TYPE_CHECKING:`.

### Automated Static Governance (`mypy` / `ty`, `ruff` & `import-linter`)

Combine strict static type checking (`mypy --strict` or Astral `ty`, backed by a `py.typed` PEP 561 marker), FastAPI-aware `ruff` rules (`FAST`), and `import-linter` contracts in `pyproject.toml` so illegal cross-context or outward domain imports fail CI immediately:

```toml
# pyproject.toml — Mechanical architectural fitness functions for 100k+ LOC
[tool.mypy]
python_version = "3.12"
strict = true
plugins = ["pydantic.mypy"]
disallow_any_generics = true

[tool.ruff.lint]
select = [
    "E", "F", "I", "B", "UP",
    "FAST",    # FastAPI-specific lint rules (redundant response_model/Depends checks)
    "TID251",  # Banned module-level imports
]

[tool.ruff.lint.per-file-ignores]
# Domain & Application layers must remain 100% framework-free
"src/*/domain/**" = []

[[tool.importlinter.contracts]]
name = "Domain and Application never import FastAPI or SQLAlchemy"
type = "forbidden"
source_modules = ["src.orders.domain", "src.orders.application"]
forbidden_modules = ["fastapi", "starlette", "sqlalchemy"]

[[tool.importlinter.contracts]]
name = "Bounded Contexts remain independent of peer infrastructure"
type = "independence"
modules = [
    "src.orders.infrastructure",
    "src.billing.infrastructure",
    "src.identity.infrastructure",
]
```

With bounded contexts and inward dependency layers locked in place, proceed to [Enterprise DI, Lifespan & Testing](di_lifespan_testing.md) to see how FastAPI wires connection pools, scoped Unit-of-Work sessions, RFC 9457 domain exception handlers, and a sub-second test pyramid across these layers.
