# pydantic-settings 設定管理と SQL データベース

FastAPI `v0.162.2` は、`pydantic-settings` と `@lru_cache` による型安全な 12-Factor 環境変数管理と、`SQLModel` およびリクエスト単位の `yield` セッションによる RDB 永続化を組み合わせることで、`app.dependency_overrides` を通じて本番インフラをテスト環境から 100% 差し替え可能にします。

```drawlib align=center code=fold file=pydantic_settings_di_flow.png caption="型安全な 12-Factor 設定パイプライン：環境変数ソース -> BaseSettings -> @lru_cache DI -> 環境変数を汚さないテスト分離"
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

## 1. `pydantic-settings` による型安全な 12-Factor 設定管理

接続先 URL のハードコードや型のない `os.getenv()` 呼び出しを各モジュールに散在させると、必須環境変数の欠落が本番の特定経路を踏むまで発覚しません。`fastapi[standard]` に同梱される `pydantic-settings >=2.0.0` を用いれば、環境変数・`.env` ファイル・シークレットマウントを HTTP リクエスト検証と同一の Rust 製 Pydantic v2 エンジンで厳密に型検証できます。

### 設定ソースの優先順位・`SettingsConfigDict`・`SecretStr`

`BaseSettings` の初期化時には以下の優先順位で設定ソースがマージされるため、テストコードからの明示的なキーワード引数やコンテナ環境変数が開発用の `.env` より常に優先されます。

| 優先度 | 設定ソース | 主な運用ユースケース |
| :--- | :--- | :--- |
| **1（最高）** | `__init__` の明示的キーワード引数 | `pytest` の DI オーバーライド内での `Settings(app_name="Test API")` |
| **2** | OS 環境変数（`os.environ`） | Kubernetes の `ConfigMap` / `Secret` や Cloud Run の実行時設定 |
| **3** | `.env` ファイル（`env_file=".env"`） | ローカル開発環境のデフォルト設定（`.gitignore` で除外） |
| **4** | シークレットディレクトリ（`secrets_dir`） | コンテナのシークレットボリュームマウント（`secrets_dir="/run/secrets"`） |
| **5（最低）** | クラスフィールドのデフォルト値 | 非機密項目の安全な既定値（`items_per_user: int = 50` など） |

実運用では次の 2 つの防御ルールを徹底することで、起動時クラッシュや認証情報の漏洩を防ぎます。

1. **`SettingsConfigDict(env_file=".env", extra="ignore")` を指定する**: 開発環境の `.env` には Docker Compose やフロントエンド用の変数が混在しやすいため、`extra="ignore"` を指定して無関係なキーによる起動時の `ValidationError` を防ぎます。
2. **機密情報を `SecretStr` でラップする**: API キー・DB パスワード・Webhook 署名鍵を `SecretStr` 型として宣言すると、ログ出力やトレースバック表示時に自動で `'**********'` にマスクされ、利用箇所で明示的に `.get_secret_value()` を呼んだときのみ平文を取り出せます。

### モジュールグローバル変数より `@lru_cache` + `Depends()` が優れる理由

モジュール読み込み時に `settings = Settings()` を即座に生成してしまうと、`app.main` を `import` するすべてのテストで本番相当の環境変数が必須となり、`pytest-xdist` による並列テストで `os.environ` を書き換えた際に競合が発生します。

`@lru_cache def get_settings() -> Settings:` でラップし、`SettingsDep = Annotated[Settings, Depends(get_settings)]` として注入する設計（[Dependant DAG・キャッシュ・yield スコープ](../04_dependencies_and_security/dependency_injection.md) の応用）により、性能とテスト容易性を両立できます。

- **本番環境では初回のみパース**: `@lru_cache` によりディスク上の `.env` 読み込みと Pydantic 検証は初回リクエスト時の 1 回だけに抑えられ、2 回目以降はメモリからナノ秒単位で返却されます。
- **環境変数を一切汚さないテスト分離**: テスト側では `app.dependency_overrides[get_settings]` に `Settings(...)` を直接返す関数を登録するだけで済み、`.env` や `os.environ` に一切触れずに完全分離された設定を注入できます（`get_settings` 自体をテストする場合のみ `get_settings.cache_clear()` を呼びます）。

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

## 2. `SQLModel` による RDB 永続化とインメモリ分離テスト

FastAPI 作者（`@tiangolo`）が設計した **`SQLModel`** は、**SQLAlchemy 2.0** と **Pydantic v2** を単一のクラス階層へ統合し、DB テーブル定義と HTTP バリデーションスキーマの間でフィールド型・制約・エディタ補完を重複なく共有します。

```drawlib align=center code=fold file=sqlmodel_session_and_testing.png caption="FastAPI + SQLModel マルチモデル階層・リクエスト単位の Session yield ライフサイクル・StaticPool SQLite テスト分離"
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

### 4 分割 `SQLModel` パターン（機密カラム漏洩と Nullable ID の防止）

単一の `table=True` ORM クラスをリクエストやレスポンスの型にそのまま流用すると、`POST` 時の主キー偽装、内部カラム（`secret_name` やパスワードハッシュ）の JSON 漏洩、さらに自動生成 SDK 側で永続化済みレコードの `id` まで `int | null` になってしまうという 3 つの設計上の欠陥が生じます。

責務を 4 つの軽量な `SQLModel` クラスに分割することで、[レスポンス直列化と OpenAPI 3.1](../03_routing_and_models/responses_and_openapi.md) の精度を完全に保ちながらこれらすべてを解消できます。

1. **`HeroBase(SQLModel)`**: 共通の検証付きフィールド（`name`, `age`）を 1 箇所で定義します（既定の `table=False`）。
2. **`Hero(HeroBase, table=True)`**: 物理 SQL テーブルを表します（DB が `session.commit()` で採番するまで Python 上では未確定なため `id: int | None = Field(default=None, primary_key=True)` とし、サーバー専用カラム `secret_name` を保持します）。
3. **`HeroCreate(HeroBase)` & `HeroPublic(HeroBase)`**: API 入出力専用のデータスキーマ（`table=False`）です。`HeroCreate` は `id` 指定を許さず `secret_name` を受け取り、`HeroPublic` は `id: int`（非 null 保証）を宣言しつつ `secret_name` を除外することで、Rust 側のレスポンス直列化時に機密フィールドを確実に除去します。
4. **`HeroUpdate(SQLModel)`**: 更新可能フィールドをすべて `None` デフォルトの任意項目とし、`PATCH` エンドポイントで `hero.model_dump(exclude_unset=True)` と `hero_db.sqlmodel_update(hero_data)` を組み合わせて安全な部分更新を実現します。

### リクエスト単位の `Session` ライフサイクルと `StaticPool` SQLite テスト

データベースの `Session` は状態を持つ Identity Map とトランザクションを保持するため、**リクエスト間でグローバルな `Session` を絶対に共有してはいけません**。必ず `SessionDep = Annotated[Session, Depends(get_session)]` で 1 リクエストごとに新しい `Session(engine)` を `yield` し、同期的な SQLModel ルートは通常の `def` で宣言して FastAPI のワーカースレッドプール上で安全に実行させます。

インメモリ SQLite（`sqlite://`）を用いた `pytest` 統合テストでは、以下の 2 つのエンジン設定が必須となります。

- **`poolclass=StaticPool`**: デフォルトの SQLite はコネクション取得ごとに空の別インメモリ DB を新規作成してしまいます。`StaticPool` を指定することで、フィクスチャの `SQLModel.metadata.create_all(engine)` と `TestClient` 内の全リクエストが単一のインメモリ接続を共有できます。
- **`connect_args={"check_same_thread": False}`**: `pytest` のメインスレッドでテーブルを初期化し、FastAPI のスレッドプールワーカーから同期 `def` エンドポイントを実行するため、スレッド境界をまたぐ SQLite アクセスを明示的に許可します。

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

続いて [FastAPI CLI・プロキシ・GraphQL・AI 連携](cli_proxy_graphql_ai.md) へ進み、`fastapi dev` / `fastapi run`、リバースプロキシ配下の `--root-path` 運用、Strawberry GraphQL ルーター、および `library-skills` を用いた AI 駆動開発を確認してください。
