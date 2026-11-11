# FastAPI の設計思想と基本概念

FastAPI（`v0.162.2`）は、**「Python 標準の型アノテーションを単一の実行可能な契約（Single Executable Contract）とする」** という明快かつ強力な設計思想に基づいています。1 つの関数シグネチャから HTTP パラメータ抽出、実行時バリデーション、依存性注入、エディタ補完・静的型検査、そして OpenAPI スキーマ生成が一貫して駆動されます。

```drawlib align=center code=hide file=fastapi_design_pillars.png caption="FastAPI v0.162.2 の設計基盤 — Python 型ヒントから ASGI ルーティング・Pydantic v2・OpenAPI 3.1・OpenTelemetry への統合"
from drawlib.canvas import save, setup
from drawlib.diagrams.architecture import (
    ArchitectureDiagram,
    CnativeIcon,
    CodeIcon,
    Node,
    PhosphorIcon,
)
from drawlib.icons import phosphor
from drawlib.lines import line, lines
from drawlib.shapes import rectangle
from drawlib.smartarts import Panel
from drawlib.styles import Styles

setup(width=188, height=88, dpi=150)

outer = Panel(
    "FastAPI v0.162.2 — Type-Driven Architecture Pillars",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=12.0),
    icon=phosphor.compass,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
outer.draw((4.0, 4.0), width=180.0, height=80.0)

# Subtle dashed bands for Top Developer Surface and Bottom Runtime Pillars
rectangle((94.0, 64.0), width=168.0, height=18.5, style=Styles.SecondaryDashed.patch(shape_r=2.0))
rectangle((94.0, 15.0), width=168.0, height=18.5, style=Styles.MutedDashed.patch(shape_r=2.0))

diag = ArchitectureDiagram(
    node_style=Styles.PrimaryBold,
    node_text_style=Styles.DarkBold.patch(text_size=10.5),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.White,
)

# Top Row: Python Typing Standards (centers at y=64.0, bottom edge at y=56.75)
diag.add(
    Node(
        "Python Type Hints\nAnnotated[T, ...]",
        width=48,
        height=14.5,
        icon=CodeIcon.PYTHON,
        icon_size=5.6,
    ),
    (38, 64.0),
)
diag.add(
    Node(
        "Pydantic BaseModel\n& Depends() Callables",
        width=48,
        height=14.5,
        icon=PhosphorIcon.CODE,
        icon_size=5.6,
    ),
    (94, 64.0),
)
diag.add(
    Node(
        "Inline API Docs\nPEP 727 Doc()",
        width=48,
        height=14.5,
        icon=PhosphorIcon.FILE_DOC,
        icon_size=5.6,
    ),
    (150, 64.0),
)

# Center Engine Hub (y=39.5, top=47.0, bottom=32.0)
diag.add(
    Node(
        "FastAPI v0.162.2 Type-Driven Engine\nRouting  ·  Validation  ·  Dependency Graph",
        width=78,
        height=15.0,
        icon=CodeIcon.FASTAPI,
        icon_size=6.2,
        card_style=Styles.PrimaryFlat,
        text_style=Styles.WhiteBold.patch(text_size=11.0),
        style=Styles.WhiteBold,
    ),
    (94, 39.5),
)

# Bottom Row: Four Core Runtime Capabilities (y=15.0, top=22.25)
diag.add(
    Node(
        "Starlette ASGI\nRouting & Lifecycle",
        width=37,
        height=14.5,
        icon=PhosphorIcon.LIGHTNING,
        icon_size=5.6,
        card_style=Styles.PrimaryNeutral,
    ),
    (31, 15.0),
)
diag.add(
    Node(
        "Pydantic v2\nSchema & Validator",
        width=39,
        height=14.5,
        icon=CodeIcon.PYDANTIC,
        icon_size=5.6,
        card_style=Styles.PrimaryNeutral,
    ),
    (73, 15.0),
)
diag.add(
    Node(
        "OpenAPI 3.1.0\nSwagger UI & ReDoc",
        width=39,
        height=14.5,
        icon=CodeIcon.OPENAPI,
        icon_size=5.6,
        card_style=Styles.PrimaryNeutral,
    ),
    (116, 15.0),
)
diag.add(
    Node(
        "OpenTelemetry\nBuilt-in Tracing",
        width=35,
        height=14.5,
        icon=CnativeIcon.OPENTELEMETRY,
        icon_size=5.6,
        card_style=Styles.SecondaryNeutral,
    ),
    (157, 15.0),
)

diag.draw()

# Symmetrical top-to-bottom bus connectors
lines([(38.0, 56.75), (38.0, 52.5), (150.0, 52.5), (150.0, 56.75)], style=Styles.DarkBold)
line((94.0, 56.75), (94.0, 47.2), arrow_head="->", style=Styles.DarkBold)

line((94.0, 32.0), (94.0, 28.5), style=Styles.DarkBold)
line((31.0, 28.5), (157.0, 28.5), style=Styles.DarkBold)
for bx in (31.0, 73.0, 116.0, 157.0):
    line((bx, 28.5), (bx, 22.4), arrow_head="->", style=Styles.DarkBold)

save()
```

## 重複コードと仕様乖離（ドリフト）の解消

従来の命令型 Web フレームワークでは、API フィールドを 1 つ追加・変更するたびに「`request` からの手動取得コード」「バリデータ定義」「レスポンス変換 DTO」「手動管理の OpenAPI YAML」という 4 つの成果物を同期して書き換える必要がありました。どこか 1 箇所でも更新が漏れると、本番環境で仕様と実装のサイレントな乖離（ドリフト）が発生します。

| 設計上の関心事 | 従来の命令型フレームワーク（4 箇所の二重管理） | FastAPI `v0.162.2`（単一シグネチャ） |
| :--- | :--- | :--- |
| **HTTP パラメータ抽出** | `request.query_params` や `request.json()` の手動参照 | パステンプレート・スカラ型・`BaseModel` から自動推論 |
| **境界での入力検証** | 別ファイルのバリデータや手続き的な `if` 文 | `Path(...)`・`Query(...)` と Rust 製 `pydantic-core` が境界で強制 |
| **静的型安全性（`mypy` / `pyright`）** | 型なしの `dict[str, Any]` がドメイン層へ流入 | `PEP 561` `py.typed` により絞り込まれた正確な型を関数内で保証 |
| **OpenAPI 仕様書 & SDK 生成** | 手書き YAML が実装コードと乖離しやすい | OpenAPI `3.1.0` + `PEP 727` `Doc()` 説明文として決定論的に自動生成 |

## 起動時の 1 回解析とリクエスト実行フェーズの分離

「型ヒントを使うフレームワークはリクエストごとに遅い `inspect.signature()` を呼んでいるのではないか」と誤解されることがありますが、FastAPI は **ルート登録時の 1 回限りの解析フェーズ** と **本番トラフィックを処理するリクエスト実行パイプライン** を明確に分離しています。

```drawlib align=center code=hide file=startup_vs_hotpath_split.png caption="起動時の 1 回セットアップとリクエスト実行フェーズの分離 — 本番トラフィックにおける署名リフレクションゼロ設計"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.lines import line
from drawlib.shapes import rectangle
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=200, height=80, dpi=150)

# Left Panel: Startup Setup
p_start = Panel(
    "Phase 1: Import & Startup (Executed Once)",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.5),
    icon=phosphor.gear,
    icon_style=Styles.SecondaryBold,
    header_variant="filled",
    header_height=8.5,
)
p_start.draw((4.0, 4.0), width=86.5, height=72.0)
s_xy, s_w, s_h = p_start.get_content_box((4.0, 4.0), width=86.5, height=72.0, padding=(3.5, 3.0))

cl_start = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.SecondaryBold,
    direction="vertical",
    spacing=4.2,
    show_arrows=True,
    arrow_style=Styles.Dark,
)
cl_start.add(
    "1. Route Registration",
    "Registers @app.get/post & APIRouter paths",
    badge_text="S1",
    icon=phosphor.code,
)
cl_start.add(
    "2. Signature & Type Inspection",
    "Classifies Path, Query, Header, Body & Depends",
    badge_text="S2",
    icon=phosphor.arrows_split,
)
cl_start.add(
    "3. Pydantic v2 Schema & Validator",
    "Compiles Rust validators & serializers once",
    badge_text="S3",
    icon=phosphor.cpu,
)
cl_start.add(
    "4. OpenAPI 3.1 Generation",
    "Prepares JSON Schema, Swagger UI & ReDoc",
    badge_text="S4",
    icon=phosphor.check_circle,
    style=Styles.SecondaryNeutral,
)
cl_start.draw(xy=s_xy, width=s_w, height=s_h)

# Handoff connector between Startup and Per-Request Execution
line((92.0, 36.5), (108.0, 36.5), arrow_head="->", style=Styles.PrimaryBold)
rectangle((100.0, 46.0), width=15.6, height=9.5, style=Styles.PrimaryNeutral.patch(shape_r=1.5))
text((100.0, 46.0), "Ready\nAPIRoute", style=Styles.PrimaryBold.patch(text_size=10.0))

# Right Panel: Per-Request Execution
p_hot = Panel(
    "Phase 2: Per-Request Execution (Live Traffic)",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.5),
    icon=phosphor.lightning,
    icon_style=Styles.WhiteBold,
    header_variant="filled",
    header_height=8.5,
)
p_hot.draw((109.5, 4.0), width=86.5, height=72.0)
h_xy, h_w, h_h = p_hot.get_content_box((109.5, 4.0), width=86.5, height=72.0, padding=(3.5, 3.0))

cl_hot = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    direction="vertical",
    spacing=4.2,
    show_arrows=True,
    arrow_style=Styles.Primary,
)
cl_hot.add(
    "1. Route Match & Input Validation",
    "Validates URL params, headers & JSON body",
    badge_text="R1",
    icon=phosphor.plugs,
)
cl_hot.add(
    "2. Dependency Graph Resolution",
    "Resolves Depends() & Security() with caching",
    badge_text="R2",
    icon=phosphor.git_branch,
    style=Styles.PrimaryNeutral,
)
cl_hot.add(
    "3. Endpoint Execution",
    "Awaits async def or runs def in threadpool",
    badge_text="R3",
    icon=phosphor.lightning,
    style=Styles.PrimaryNeutral,
)
cl_hot.add(
    "4. Response Validation & JSON",
    "Serializes output & runs yield cleanup",
    badge_text="R4",
    icon=phosphor.rocket_launch,
)
cl_hot.draw(xy=h_xy, width=h_w, height=h_h)

save()
```

エンドポイント関数や `Depends()` の型シグネチャはルート登録時点で解析されるため、HTTP リクエストを 1 件も受け付ける前から `app.openapi()` を呼び出して OpenAPI `3.1.0` 契約を確認できます。

```python
from typing import Annotated

from annotated_doc import Doc
from fastapi import Depends, FastAPI, Path, Query
from pydantic import BaseModel, ConfigDict, Field

app = FastAPI(title="Order Service", version="1.0.0")


class OrderPayload(BaseModel):
    model_config = ConfigDict(extra="forbid")
    sku: str = Field(min_length=3)
    quantity: int = Field(ge=1, le=100)


def get_region(x_region: str = "us-east") -> str:
    return x_region


@app.post("/orders/{order_id}")
async def create_order(
    order_id: Annotated[int, Path(ge=1), Doc("Numeric order identifier.")],
    payload: OrderPayload,
    region: Annotated[str, Depends(get_region)],
    dry_run: Annotated[bool, Query(), Doc("Validate without persisting.")] = False,
) -> dict[str, object]:
    return {"order_id": order_id, "sku": payload.sku, "region": region, "dry_run": dry_run}


schema = app.openapi()
operation = schema["paths"]["/orders/{order_id}"]["post"]
assert [p["name"] for p in operation["parameters"]] == ["order_id", "dry_run", "x_region"]
assert "OrderPayload" in schema["components"]["schemas"]
```

## コア実行時依存パッケージと主要 API 構成

### コア実行時依存スタック

FastAPI は必須ランタイム依存を意図的に最小限へ絞り込んでおり、`pyproject.toml` に宣言された直接依存パッケージはわずか **6 つ** です。

| パッケージ（`pyproject.toml`） | 最小バージョン | FastAPI `v0.162.2` アプリケーションにおける役割 |
| :--- | :--- | :--- |
| **`starlette`** | `>=0.46.0` | 高速な ASGI `3.0` 基盤、URL ルータ、`Request`/`Response` プリミティブ、WebSocket、ミドルウェア群 |
| **`pydantic`** | `>=2.9.0` | Rust 製 `pydantic-core` による高速入力検証・型変換・レスポンス直列化・JSON Schema `2020-12` 生成 |
| **`typing-extensions`** | `>=4.8.0` | Python `3.10` ～ `3.14` 間での最新型ヒント構文の互換性維持 |
| **`typing-inspection`** | `>=0.4.2` | `Annotated[...]`・型エイリアス・ジェネリクス・Union 型の起動時における正確な展開 |
| **`annotated-doc`** | `>=0.0.2` | `PEP 727` `Doc("...")` による `Annotated` 内インライン OpenAPI ドキュメント記述 |
| **`opentelemetry-api`** | `>=1.44.0` | SDK 未導入時にはゼロオーバーヘッドで動作する標準 OpenTelemetry 計装（`fastapi.telemetry`）基盤 |

### アプリケーション構築の 5 大ビルディングブロック

FastAPI で Web サービスを構築する際に利用する公開 API は、次の 5 つの機能領域に整理されています。

| 機能領域 | 主な公開クラス・関数 | 代表的なインポート元 |
| :--- | :--- | :--- |
| **アプリ本体 & モジュラールーティング** | `FastAPI`, `APIRouter`, `APIRoute`, `Request`, `Response`, `lifespan` | `fastapi`, `fastapi.routing` |
| **パラメータ・モデル & ドキュメント** | `Annotated`, `Path`, `Query`, `Header`, `Cookie`, `Body`, `Form`, `UploadFile`, `BaseModel`, `Doc()` | `fastapi`, `pydantic`, `annotated_doc` |
| **依存性注入（DI） & セキュリティ** | `Depends`, `Security`, `SecurityScopes`, `OAuth2PasswordBearer`, `APIKeyHeader`, `HTTPBearer` | `fastapi`, `fastapi.security` |
| **非同期タスク・配信 & リアルタイム** | `BackgroundTasks`, `EventSourceResponse`, `ServerSentEvent`, `WebSocket`, `WebSocketDisconnect` | `fastapi`, `fastapi.sse` |
| **可観測性・例外処理 & テスト** | `HTTPException`, `RequestValidationError`, `TelemetryConfig`, `get_telemetry_data()`, `TestClient` | `fastapi`, `fastapi.exceptions`, `fastapi.telemetry`, `fastapi.testclient` |

次のステップとして、**[クイックスタートと自動生成 Docs](quickstart.md)** で実際に API を立ち上げるか、**[第 2 章：境界づけられたコンテキストと階層化](../02_enterprise_architecture/modular_design.md)** で大規模コードベースの構造化パターンを確認してください。
