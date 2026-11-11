# pydantic-settings & SQL Databases

FastAPI `v0.162.2` pairs typed 12-Factor environment configuration (`pydantic-settings` with `@lru_cache` dependency caching) and unified relational ORM/schema models (`SQLModel` with per-request `yield` sessions) so external infrastructure remains 100% swappable in tests via `app.dependency_overrides`.

```drawlib align=center code=hide file=pydantic_settings_di_flow.png caption="Typed 12-Factor Configuration Pipeline: Environment Sources -> BaseSettings -> @lru_cache DI -> Hermetic Test Override"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.lines import line
from drawlib.shapes import rectangle
from drawlib.smartarts import ChevronProcess, Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=194, height=86, dpi=150)

text(
    (97.0, 81.0),
    "Typed 12-Factor Configuration Pipeline & Zero-Mutation Test Isolation",
    style=Styles.DarkBold.patch(text_size=13.0),
)

# Upper Production Pipeline Panel
prod_panel = Panel(
    "Production Runtime — Parse Once & Inject via Annotated Dependency",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.gear,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
prod_panel.draw((4.0, 33.0), width=186.0, height=43.0)

pipeline = ChevronProcess(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    corner_angle=64.0,
    spacing=1.8,
    flat_left_end=True,
)
pipeline.add("1. Config Sources", description="OS Env • .env • Secrets")
pipeline.add(
    "2. BaseSettings",
    description="ConfigDict • SecretStr",
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
)
pipeline.add(
    "3. @lru_cache",
    description="get_settings() Read Once",
    style=Styles.PrimaryNeutral,
)
pipeline.add(
    "4. SettingsDep",
    description="Annotated[..., Depends()]",
    style=Styles.SecondaryNeutral,
)
pipeline.draw(xy=(8.0, 39.0), width=178.0, height=22.0)

# Lower Guardrail & Test Override Band
rectangle((49.5, 15.0), width=91.0, height=20.0, style=Styles.SecondaryNeutral.patch(shape_r=2.0))
phosphor.lock_key((10.5, 18.0), width=5.2, style=Styles.SecondaryBold)
text(
    (16.0, 18.5),
    "Precedence & SecretStr Masking",
    style=Styles.DarkBold.patch(text_size=10.8, halign="left"),
)
text(
    (16.0, 11.5),
    "kwargs > OS env > .env > defaults  •  repr() -> '**********'",
    style=Styles.Dark.patch(text_size=10.0, halign="left"),
)

rectangle((144.5, 15.0), width=91.0, height=20.0, style=Styles.PrimaryNeutral.patch(shape_r=2.0))
phosphor.flask((105.5, 18.0), width=5.2, style=Styles.PrimaryBold)
text(
    (111.0, 18.5),
    "Hermetic pytest Override",
    style=Styles.DarkBold.patch(text_size=10.8, halign="left"),
)
text(
    (111.0, 11.5),
    "dependency_overrides[get_settings] • Zero env edit",
    style=Styles.Dark.patch(text_size=10.0, halign="left"),
)

# Override injection connector into SettingsDep stage
line((162.0, 25.0), (162.0, 38.0), arrow_head="->", style=Styles.PrimaryBold.patch(line_width=1.8))

save()
```

## 1. Typed 12-Factor Configuration with `pydantic-settings`

Hardcoding URLs or scattering untyped `os.getenv()` calls across modules hides missing environment variables until a cold code path executes in production. Installing `fastapi[standard]` includes `pydantic-settings >=2.0.0`, allowing your application to validate environment variables, `.env` files, and mounted secret files through the exact same Rust-backed Pydantic v2 engine used for HTTP request bodies.

### Source Precedence, `SettingsConfigDict` & `SecretStr`

When `BaseSettings` initializes, it merges configuration sources in strict priority order so explicit test keyword arguments and container environment variables always win over local developer `.env` files:

| Priority | Configuration Source | Typical Operational Usage |
| :--- | :--- | :--- |
| **1 (Highest)** | Explicit `__init__` keyword arguments | `Settings(app_name="Test API")` inside `pytest` dependency overrides |
| **2** | OS Environment Variables (`os.environ`) | Kubernetes `ConfigMap` / `Secret` env vars & Cloud Run runtime config |
| **3** | `.env` dotenv file (`env_file=".env"`) | Local developer workstation defaults (excluded via `.gitignore`) |
| **4** | Mounted secret directory (`secrets_dir`) | Container secret volume mounts (`secrets_dir="/run/secrets"`) |
| **5 (Lowest)** | Class field default values | Safe non-sensitive defaults (`items_per_user: int = 50`) |

Two defensive rules eliminate configuration leaks and startup crashes in shared environments:

1. **Configure `SettingsConfigDict(env_file=".env", extra="ignore")`**: Local developer `.env` files frequently contain auxiliary variables for Docker Compose or frontend tooling. Setting `extra="ignore"` prevents unrelated keys from raising a `ValidationError` on boot.
2. **Wrap Credentials in `SecretStr`**: Storing API keys, database passwords, or webhook signing keys as `SecretStr` redacts them to `'**********'` whenever `Settings` is formatted into logs, tracebacks, or structured telemetry, requiring explicit `.get_secret_value()` access at the call site.

### Why `@lru_cache` + `Depends()` Beats Module Globals

Instantiating `settings = Settings()` at module import time forces every test module that imports `app.main` to have production environment variables present immediately, and makes parallel `pytest-xdist` tests race if they mutate `os.environ`.

Wrapping `Settings()` in `@lru_cache def get_settings() -> Settings:` and injecting `SettingsDep = Annotated[Settings, Depends(get_settings)]` gives you the best of both worlds (extending the [Dependant DAG & Caching](../04_dependencies_and_security/dependency_injection.md) pattern):

- **Parsed Once in Production**: `@lru_cache` reads `.env` from disk and runs Pydantic validation only on the first call, serving subsequent requests from memory in nanoseconds.
- **Zero-Env-Mutation Test Isolation**: Tests replace `app.dependency_overrides[get_settings]` with a function returning `Settings(...)` directly via constructor arguments—never touching `.env` or `os.environ` (and calling `get_settings.cache_clear()` only if testing `get_settings` itself).

```python
from functools import lru_cache
from typing import Annotated

from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient
from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Billing Ledger API"
    admin_email: str = "ops@example.com"
    items_per_user: int = 50
    webhook_signing_secret: SecretStr = SecretStr("whsec_dev_placeholder")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()


SettingsDep = Annotated[Settings, Depends(get_settings)]

app = FastAPI(title="Settings Demo")


@app.get("/info")
def read_service_info(settings: SettingsDep) -> dict[str, str | int | bool]:
    return {
        "app_name": settings.app_name,
        "admin_email": settings.admin_email,
        "items_per_user": settings.items_per_user,
        "masked_repr": str(settings.webhook_signing_secret),
        "has_signing_key": len(settings.webhook_signing_secret.get_secret_value()) > 0,
    }


def test_settings_dependency_override_isolation() -> None:
    def get_settings_override() -> Settings:
        return Settings(
            app_name="Test Billing API",
            admin_email="ci-test@example.com",
            webhook_signing_secret=SecretStr("whsec_test_isolated_key"),
        )

    app.dependency_overrides[get_settings] = get_settings_override
    try:
        with TestClient(app) as client:
            res = client.get("/info")
            assert res.status_code == 200
            assert res.json() == {
                "app_name": "Test Billing API",
                "admin_email": "ci-test@example.com",
                "items_per_user": 50,
                "masked_repr": "**********",
                "has_signing_key": True,
            }
    finally:
        app.dependency_overrides.clear()
```

---

## 2. Relational Persistence & Hermetic Testing with `SQLModel`

Created by the author of FastAPI (`@tiangolo`), **`SQLModel`** unifies **SQLAlchemy 2.0** and **Pydantic v2** under a single class hierarchy so database table definitions and HTTP validation schemas share field types, constraints, and editor autocomplete without duplicating boilerplate.

```drawlib align=center code=hide file=sqlmodel_session_and_testing.png caption="FastAPI + SQLModel Multi-Model Architecture, Per-Request Session Yield Lifecycle & StaticPool SQLite Test Isolation"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.lines import lines
from drawlib.shapes import rectangle
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=190, height=92, dpi=150)

text(
    (95.0, 87.0),
    "FastAPI + SQLModel Multi-Model Hierarchy & Hermetic StaticPool Testing",
    style=Styles.DarkBold.patch(text_size=13.0),
)

# Left Panel: Multi-Model Schema Inheritance
left_panel = Panel(
    "1. SQLModel Multi-Model Schema Design",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.database,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
left_panel.draw((4.0, 5.0), width=90.0, height=76.0)

# Shared HeroBase card
rectangle((49.0, 63.0), width=80.0, height=13.0, style=Styles.SecondaryNeutral.patch(shape_r=1.8))
text((49.0, 65.5), "HeroBase(SQLModel)  [Shared Fields]", style=Styles.DarkBold.patch(text_size=10.5))
text((49.0, 60.0), "name: str (index)  •  age: int | None", style=Styles.Dark.patch(text_size=10.0))

# Orthogonal fork from HeroBase to Table vs API Schemas
lines([(49.0, 56.5), (49.0, 51.5), (27.5, 51.5), (27.5, 45.5)], arrow_head="->", style=Styles.DarkBold)
lines([(49.0, 56.5), (49.0, 51.5), (70.5, 51.5), (70.5, 45.5)], arrow_head="->", style=Styles.DarkBold)

# Physical DB Table Model (Focal)
rectangle((27.5, 36.0), width=39.0, height=18.5, style=Styles.PrimaryFlat.patch(shape_r=1.8))
text((27.5, 41.2), "Hero (table=True)", style=Styles.WhiteBold.patch(text_size=10.5))
text((27.5, 35.5), "id: int | None (PK)", style=Styles.White.patch(text_size=10.0))
text((27.5, 30.2), "secret_name: str", style=Styles.White.patch(text_size=10.0))

# Create & Public API Schemas
rectangle((70.5, 36.0), width=39.0, height=18.5, style=Styles.PrimaryNeutral.patch(shape_r=1.8))
text((70.5, 41.2), "Create / Public", style=Styles.DarkBold.patch(text_size=10.5))
text((70.5, 35.5), "Create: +secret_name", style=Styles.Dark.patch(text_size=10.0))
text((70.5, 30.2), "Public: id: int (Safe!)", style=Styles.Dark.patch(text_size=10.0))

# Sparse PATCH Schema at bottom
rectangle((49.0, 15.0), width=80.0, height=14.0, style=Styles.White.patch(shape_r=1.8))
text((49.0, 18.0), "HeroUpdate(SQLModel)  [Sparse PATCH]", style=Styles.DarkBold.patch(text_size=10.5))
text((49.0, 12.2), "model_dump(exclude_unset=True) -> sqlmodel_update()", style=Styles.Dark.patch(text_size=10.0))

# Right Panel: Session Yield DI & StaticPool Pytest Isolation
right_panel = Panel(
    "2. Session Lifecycle & StaticPool Tests",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.arrows_split,
    icon_style=Styles.SecondaryBold,
    header_variant="filled",
    header_height=8.5,
)
right_panel.draw((98.0, 5.0), width=88.0, height=76.0)
r_xy, r_w, r_h = right_panel.get_content_box((98.0, 5.0), width=88.0, height=76.0, padding=(3.5, 3.0))

cl_right = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    direction="vertical",
    spacing=2.6,
)
cl_right.add(
    "get_session() Yield DI",
    "with Session(engine) as s: yield s",
    badge_text="1",
    icon=phosphor.plugs,
)
cl_right.add(
    "SessionDep CRUD Route",
    "Sync def in threadpool + commit/refresh",
    badge_text="2",
    icon=phosphor.cpu,
    style=Styles.PrimaryNeutral,
)
cl_right.add(
    "SQLite StaticPool Engine",
    "sqlite:// + check_same_thread=False",
    badge_text="3",
    icon=phosphor.flask,
    style=Styles.SecondaryNeutral,
)
cl_right.add(
    "dependency_overrides",
    "Swap get_session -> isolated memory DB",
    badge_text="4",
    icon=phosphor.check_circle,
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
    badge_style=Styles.White,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
)
cl_right.draw(xy=r_xy, width=r_w, height=r_h)

save()
```

### The 4-Model `SQLModel` Pattern (Preventing Leaks & Nullable IDs)

Exposing a single `table=True` ORM model directly in request and response signatures introduces three classic API flaws: clients can spoof primary keys on `POST`, internal columns (`secret_name`, password hashes) leak in JSON responses, and generated TypeScript SDKs mark `id` as `int | null` even though persisted rows always have an integer `id`.

Splitting responsibilities across four lightweight `SQLModel` classes eliminates all three flaws while keeping [OpenAPI 3.1 response serialization](../03_routing_and_models/responses_and_openapi.md) exact:

1. **`HeroBase(SQLModel)`**: Declares shared validated columns (`name`, `age`) once with `table=False` (the default).
2. **`Hero(HeroBase, table=True)`**: Represents the physical SQL table (`id: int | None = Field(default=None, primary_key=True)` because `id` is `None` in Python until the database assigns it on `session.commit()`, plus server-only columns like `secret_name`).
3. **`HeroCreate(HeroBase)` & `HeroPublic(HeroBase)`**: Pure Pydantic data schemas (`table=False`). `HeroCreate` accepts `secret_name` on input without allowing `id` injection; `HeroPublic` declares `id: int` (strictly non-null in OpenAPI!) and omits `secret_name` so sensitive columns are stripped automatically during Rust response serialization.
4. **`HeroUpdate(SQLModel)`**: Declares all mutable fields as optional (`None` defaults) so `PATCH` handlers can call `hero.model_dump(exclude_unset=True)` and apply sparse updates cleanly with `hero_db.sqlmodel_update(hero_data)`.

### Per-Request `Session` Lifecycle & `StaticPool` SQLite Testing

Database sessions hold stateful identity maps and open transactions, so **never share a `Session` globally across requests**. Instead, yield a fresh `Session(engine)` per request via `SessionDep = Annotated[Session, Depends(get_session)]`, declaring synchronous SQLModel endpoints with standard `def` so FastAPI executes blocking SQL I/O safely on its worker threadpool.

When testing SQLModel endpoints against an in-memory SQLite database (`sqlite://`), two engine options are mandatory:

- **`poolclass=StaticPool`**: By default, SQLite opens an empty, isolated in-memory database for every new connection checkout. `StaticPool` reuses a single underlying connection across the fixture setup (`SQLModel.metadata.create_all(engine)`) and all `TestClient` requests within that test.
- **`connect_args={"check_same_thread": False}`**: Because `pytest` initializes tables on the main thread while FastAPI dispatches synchronous `def` routes in a worker threadpool thread, `check_same_thread=False` allows SQLite to safely cross that thread boundary during a single request cycle.

```python
from collections.abc import Generator
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.testclient import TestClient
import pytest
from sqlmodel import Field, Session, SQLModel, create_engine, select
from sqlmodel.pool import StaticPool


class HeroBase(SQLModel):
    name: str = Field(index=True, min_length=1, max_length=80)
    age: int | None = Field(default=None, ge=0, le=300, index=True)


class Hero(HeroBase, table=True):
    id: int | None = Field(default=None, primary_key=True)
    secret_name: str


class HeroCreate(HeroBase):
    secret_name: str


class HeroPublic(HeroBase):
    id: int


class HeroUpdate(SQLModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    age: int | None = Field(default=None, ge=0, le=300)
    secret_name: str | None = None


prod_engine = create_engine(
    "sqlite:///./database.db",
    connect_args={"check_same_thread": False},
)


def get_session() -> Generator[Session, None, None]:
    with Session(prod_engine) as session:
        yield session


SessionDep = Annotated[Session, Depends(get_session)]

app = FastAPI(title="SQLModel Heroes API")


@app.post("/heroes/", response_model=HeroPublic, status_code=201)
def create_hero(hero: HeroCreate, session: SessionDep) -> Hero:
    db_hero = Hero.model_validate(hero)
    session.add(db_hero)
    session.commit()
    session.refresh(db_hero)
    return db_hero


@app.get("/heroes/", response_model=list[HeroPublic])
def read_heroes(
    session: SessionDep,
    offset: Annotated[int, Query(ge=0)] = 0,
    limit: Annotated[int, Query(ge=1, le=100)] = 100,
) -> list[Hero]:
    statement = select(Hero).offset(offset).limit(limit)
    return list(session.exec(statement).all())


@app.patch("/heroes/{hero_id}", response_model=HeroPublic)
def update_hero(hero_id: int, hero: HeroUpdate, session: SessionDep) -> Hero:
    hero_db = session.get(Hero, hero_id)
    if not hero_db:
        raise HTTPException(status_code=404, detail="Hero not found")
    hero_data = hero.model_dump(exclude_unset=True)
    hero_db.sqlmodel_update(hero_data)
    session.add(hero_db)
    session.commit()
    session.refresh(hero_db)
    return hero_db


@app.delete("/heroes/{hero_id}")
def delete_hero(hero_id: int, session: SessionDep) -> dict[str, bool]:
    hero_db = session.get(Hero, hero_id)
    if not hero_db:
        raise HTTPException(status_code=404, detail="Hero not found")
    session.delete(hero_db)
    session.commit()
    return {"ok": True}


@pytest.fixture(name="session")
def session_fixture() -> Generator[Session, None, None]:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        yield session


@pytest.fixture(name="client")
def client_fixture(session: Session) -> Generator[TestClient, None, None]:
    def get_session_override() -> Session:
        return session

    app.dependency_overrides[get_session] = get_session_override
    try:
        with TestClient(app) as client:
            yield client
    finally:
        app.dependency_overrides.clear()


def test_sqlmodel_crud_and_secret_filtering(client: TestClient) -> None:
    created = client.post(
        "/heroes/",
        json={"name": "Deadpond", "age": 34, "secret_name": "Dive Wilson"},
    )
    assert created.status_code == 201
    assert created.json() == {"id": 1, "name": "Deadpond", "age": 34}

    patched = client.patch("/heroes/1", json={"age": 35})
    assert patched.status_code == 200
    assert patched.json() == {"id": 1, "name": "Deadpond", "age": 35}

    listed = client.get("/heroes/?offset=0&limit=10")
    assert listed.json() == [{"id": 1, "name": "Deadpond", "age": 35}]

    assert client.delete("/heroes/1").json() == {"ok": True}
    assert client.patch("/heroes/1", json={"age": 36}).status_code == 404
```

Continue to [FastAPI CLI, Proxies, GraphQL & AI](cli_proxy_graphql_ai.md) to explore `fastapi dev` / `fastapi run`, reverse proxy `--root-path` configuration, Strawberry GraphQL routers, and AI-assisted development with `library-skills`.
