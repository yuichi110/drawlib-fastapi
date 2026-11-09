# FastAPI v0.162.2 — 実践ユーザーガイド

FastAPI（`v0.162.2`）は、Python `>=3.10` の標準型ヒントから境界での入力バリデーション、階層的な依存性注入（DI）、Rust 製 `pydantic-core` による高速シリアライズ、そして対話的な OpenAPI `3.1.0` ドキュメントを一貫して生成する型駆動 ASGI Web フレームワークです。本サイトは最初のエンドポイント実装から `100,000+` 行規模の本番アプリケーション設計までを日英バイリンガルで体系的に解説する非公式ユーザーガイドです。

```drawlib align=center code=hide file=fastapi_lifecycle_anim.png caption="FastAPI v0.162.2 リクエスト処理フロー — 起動時 1 回のルート登録からリクエストごとの ASGI 実行まで"
from drawlib.anim import Animation
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.shapes import rectangle
from drawlib.smartarts import ChevronProcess, Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=184, height=68, dpi=150)
anim = Animation(fps=1.6)

stages = [
    ("1. Route\nRegistration", "Type Hints & Doc()"),
    ("2. Schema &\nOpenAPI Prep", "Pydantic v2 & 3.1"),
    ("3. Validation &\nDependencies", "Inputs & Depends()"),
    ("4. Endpoint\nExecution", "async / threadpool"),
    ("5. Response &\nCleanup", "JSON & yield Exit"),
]

stage_notes = [
    (
        phosphor.code,
        "Step 1/5 [Route Registration] — Declare Annotated inputs, Depends(), Doc() & BaseModel types.",
    ),
    (
        phosphor.gear,
        "Step 2/5 [Startup] — Inspect signatures once and build Pydantic v2 validators & OpenAPI 3.1.",
    ),
    (
        phosphor.git_branch,
        "Step 3/5 [Request Ingress] — Validate HTTP parameters/body and resolve Depends() graphs.",
    ),
    (
        phosphor.lightning,
        "Step 4/5 [Endpoint Execution] — Await async def on event loop or run def in a threadpool.",
    ),
    (
        phosphor.check_circle,
        "Step 5/5 [Response & Cleanup] — Validate & serialize JSON via Pydantic v2 and exit yield.",
    ),
]

for step in range(len(stages)):
    is_last = step == len(stages) - 1
    with anim.frame(duration=2.8 if is_last else None, clear=True):
        outer = Panel(
            "FastAPI v0.162.2 — One-Time Startup Setup & Per-Request Execution",
            style=Styles.Neutral.patch(shape_r=2.0),
            header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
            text_style=Styles.DarkBold.patch(text_size=12.0),
            icon=phosphor.rocket_launch,
            icon_style=Styles.PrimaryBold,
            header_variant="filled",
            header_height=8.5,
        )
        outer.draw((4.0, 4.0), width=176.0, height=60.0)

        # Phase baseline bands (always visible from Frame 1)
        s_style = Styles.SecondaryNeutral if step <= 1 else Styles.Neutral
        r_style = Styles.PrimaryNeutral if step >= 2 else Styles.Neutral
        rectangle((40.5, 24.5), width=65.0, height=8.0, style=s_style.patch(shape_r=1.5))
        text(
            (40.5, 24.5),
            "Import & Startup Phase (Executed Once)",
            style=Styles.DarkBold.patch(text_size=10.5),
        )
        rectangle((126.0, 24.5), width=100.0, height=8.0, style=r_style.patch(shape_r=1.5))
        text(
            (126.0, 24.5),
            "Per-Request ASGI Execution (Zero Signature Inspection)",
            style=Styles.DarkBold.patch(text_size=10.5),
        )

        # Animated 5-stage ChevronProcess
        proc = ChevronProcess(
            style=Styles.Neutral,
            text_style=Styles.DarkBold.patch(text_size=10.5),
            description_style=Styles.Dark.patch(text_size=10.0),
            corner_angle=62.0,
            spacing=1.8,
            flat_left_end=True,
        )
        for i, (title, desc) in enumerate(stages):
            if i == step:
                c_style = Styles.PrimaryFlat
                t_style = Styles.WhiteBold.patch(text_size=10.5)
                d_style = Styles.White.patch(text_size=10.0)
            elif i < 2:
                c_style = Styles.SecondaryNeutral
                t_style = Styles.DarkBold.patch(text_size=10.5)
                d_style = Styles.Dark.patch(text_size=10.0)
            else:
                c_style = Styles.PrimaryNeutral
                t_style = Styles.DarkBold.patch(text_size=10.5)
                d_style = Styles.Dark.patch(text_size=10.0)
            proc.add(
                title,
                description=desc,
                style=c_style,
                text_style=t_style,
                description_style=d_style,
                show=(i <= step),
            )
        proc.draw(xy=(8.0, 32.0), width=168.0, height=19.5)

        # Active step callout bar at bottom
        rectangle((92.0, 12.5), width=168.0, height=9.5, style=Styles.White.patch(shape_r=1.5))
        note_icon, note_text = stage_notes[step]
        note_icon((14.0, 12.5), width=5.2, style=Styles.PrimaryBold)
        text(
            (20.0, 12.5),
            note_text,
            style=Styles.DarkBold.patch(text_size=10.5, halign="left"),
        )

save()
```

## FastAPI v0.162.2 の主要機能とランタイム構成

FastAPI はルーティング・入力検証・依存性注入（DI）・API ドキュメント生成を別々のプラグインとしてつぎはぎするのではなく、Python 標準の型アノテーションを軸に単一のパイプラインへ統合し、実装コードと外部 API 仕様の乖離を防ぎます。

| 機能領域 | `v0.162.2` 対応規格・基盤 | アプリケーション開発における実用メリット |
| :--- | :--- | :--- |
| **対応 Python バージョン** | Python `>=3.10`（`3.10` ～ `3.14`） | `PEP 561` `py.typed` 静的型検査と `PEP 727` `Doc()` インライン説明記述に標準対応 |
| **入力検証 & シリアライズ** | Pydantic v2（`>=2.9`、Rust 製 `pydantic-core`） | 高速な境界バリデーション、パラメータモデル合成、型安全な JSON 出力直列化 |
| **API 仕様 & 対話型 Docs** | OpenAPI `3.1.0` & JSON Schema `2020-12` | `/openapi.json`・Swagger UI（`/docs`）・ReDoc（`/redoc`）の自動提供とクライアント SDK 生成 |
| **依存性注入（DI） & 認可** | `Depends()`・`Security()`・`yield` ライフサイクル | リクエスト単位の結果キャッシュ、確実なリソース解放、OAuth2 スコープ・WebSocket 認可 |
| **配信・SPA・トレーシング** | `fastapi.sse`・`frontend()`・`fastapi.telemetry` | 標準搭載の Server-Sent Events、SPA 配信ヘルパー、パッチ不要の OpenTelemetry 分散トレース |
| **コア実行時依存パッケージ** | 直接依存 `6` パッケージ（`pyproject.toml`） | `starlette`, `pydantic`, `typing-extensions`, `typing-inspection`, `annotated-doc`, `opentelemetry-api` |

### 20 行で完結する Single Source of Truth

わずか 1 つのエンドポイント関数シグネチャを書くだけで、URL パラメータ抽出、正規表現・文字長バリデーション、OpenAPI パラメータ説明文、レスポンス検証・直列化、そして静的型検査が同時に定義されます。

```python
from typing import Annotated

from annotated_doc import Doc
from fastapi import FastAPI, Path, Query
from pydantic import BaseModel

app = FastAPI(title="Catalog Service", version="1.0.0")


class ProductSummary(BaseModel):
    sku: str
    price_cents: int
    currency: str


@app.get("/products/{sku}", response_model=ProductSummary)
async def read_product(
    sku: Annotated[str, Path(min_length=3, max_length=32), Doc("Warehouse SKU code.")],
    currency: Annotated[str, Query(pattern="^[A-Z]{3}$"), Doc("ISO 4217 currency.")] = "USD",
) -> ProductSummary:
    return ProductSummary(sku=sku, price_cents=4900, currency=currency)
```

## 全 8 章・20 ページのカリキュラムマップ

本ガイドは **全 8 章・20 ページ** にわたり、最初のエンドポイント構築から、`100,000+` 行規模のモジュラーモノリス設計、カスタム `APIRoute` 拡張、`pwdlib` Argon2id + `PyJWT` + WebSocket `Security()` 認可、ネイティブ Server-Sent Events（`fastapi.sse`）、標準搭載の OpenTelemetry 計装（`fastapi.telemetry`）、SPA `frontend()` 配信と SDK 自動生成、そして `pydantic-settings`・SQL DB・AI/MCP 連携までを体系的に解説します。

```drawlib align=center code=hide file=guide_chapter_map.png caption="ユーザーガイド全カリキュラムマップ — クイックスタートから本番エコシステムまでの全 8 章・20 ページ構成"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Styles

setup(width=196, height=88, dpi=150)

left_panel = Panel(
    "Part I — Foundations, Scale & Security (Ch 1–4)",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.compass,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
left_panel.draw((4.0, 4.0), width=91.0, height=80.0)
l_xy, l_w, l_h = left_panel.get_content_box((4.0, 4.0), width=91.0, height=80.0, padding=(3.5, 3.0))

cl_left = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.8),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    direction="vertical",
    spacing=2.4,
)
cl_left.add(
    "Ch 1 · Introduction & Quickstart",
    "Design pillars, request flow & OpenAPI 3.1",
    badge_text="Ch 1",
    icon=phosphor.rocket_launch,
    style=Styles.PrimaryNeutral,
    badge_style=Styles.PrimaryFlat,
    badge_text_style=Styles.WhiteBold.patch(text_size=10.0),
    icon_style=Styles.WhiteBold,
)
cl_left.add(
    "Ch 2 · 100k+ LOC Enterprise Design",
    "Bounded contexts, DI ports & lifespan tests",
    badge_text="Ch 2",
    icon=phosphor.tree_structure,
)
cl_left.add(
    "Ch 3 · Routing, Validation & Models",
    "Param models, extra types & custom APIRoute",
    badge_text="Ch 3",
    icon=phosphor.brackets_curly,
)
cl_left.add(
    "Ch 4 · DI, OAuth2, JWT & WS Security",
    "Depends() graph, Argon2 + PyJWT & WS Security()",
    badge_text="Ch 4",
    icon=phosphor.shield_check,
)
cl_left.draw(xy=l_xy, width=l_w, height=l_h)

right_panel = Panel(
    "Part II — Streaming, OTel, Frontend & Ops (Ch 5–8)",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.stack,
    icon_style=Styles.SecondaryBold,
    header_variant="filled",
    header_height=8.5,
)
right_panel.draw((101.0, 4.0), width=91.0, height=80.0)
r_xy, r_w, r_h = right_panel.get_content_box((101.0, 4.0), width=91.0, height=80.0, padding=(3.5, 3.0))

cl_right = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.8),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.SecondaryBold,
    direction="vertical",
    spacing=2.4,
)
cl_right.add(
    "Ch 5 · Async, SSE & WebSockets",
    "Pure ASGI middleware, SSE, JSONL & sockets",
    badge_text="Ch 5",
    icon=phosphor.broadcast,
)
cl_right.add(
    "Ch 6 · OpenTelemetry & Testing",
    "Native OTel spans, RFC errors & TestClient",
    badge_text="Ch 6",
    icon=phosphor.pulse,
)
cl_right.add(
    "Ch 7 · Frontend, Sub-Apps & OpenAPI",
    "SPA frontend(), mounts, webhooks & SDKs",
    badge_text="Ch 7",
    icon=phosphor.layout,
)
cl_right.add(
    "Ch 8 · Settings, Databases & Ecosystem",
    "pydantic-settings, SQL DBs, CLI & AI/MCP",
    badge_text="Ch 8",
    icon=phosphor.database,
    style=Styles.SecondaryNeutral,
    badge_style=Styles.PrimaryFlat,
    badge_text_style=Styles.WhiteBold.patch(text_size=10.0),
    icon_style=Styles.WhiteBold,
)
cl_right.draw(xy=r_xy, width=r_w, height=r_h)

save()
```

| 章 | ページ構成と主要テーマ | 扱う主な FastAPI API |
| :--- | :--- | :--- |
| **1. イントロ & クイックスタート** | [FastAPI の設計思想と基本概念](01_getting_started/overview.md) · [クイックスタートと自動生成 Docs](01_getting_started/quickstart.md) | `FastAPI`, `Annotated`, `Doc()`, `APIRoute`, Swagger UI & ReDoc |
| **2. 10万行規模の設計ベストプラクティス** | [境界づけられたコンテキストと階層化](02_enterprise_architecture/modular_design.md) · [大規模 DI・Lifespan 管理・テスト戦略](02_enterprise_architecture/di_lifespan_testing.md) | `APIRouter`, `lifespan`, `dependency_overrides`, ドメイン境界分離 |
| **3. ルーティング・入力検証・スキーマ** | [Path・Query・Header・Cookie・Body](03_routing_and_models/parameters_and_validation.md) · [レスポンス直列化と OpenAPI 3.1](03_routing_and_models/responses_and_openapi.md) · [パラメータモデル合成・特殊型・例示](03_routing_and_models/advanced_types_and_models.md) · [カスタム Request と APIRoute 拡張](03_routing_and_models/custom_request_and_route.md) | `Path`, `Query`, `Header`, `Cookie`, `Body`, `BaseModel`, カスタム `APIRoute` |
| **4. 依存性注入（DI）とセキュリティ** | [依存グラフ・キャッシュ・yield スコープ](04_dependencies_and_security/dependency_injection.md) · [認証・OAuth2 スコープ認可・抽出器](04_dependencies_and_security/security_and_auth.md) · [JWT (PyJWT + Argon2) と WS 認可](04_dependencies_and_security/jwt_and_websocket_security.md) | `Depends`, `Security`, `SecurityScopes`, `pwdlib` Argon2id, `PyJWT`, `HTTPConnection` |
| **5. 非同期並行・ミドルウェア・ストリーミング** | [ASGI ミドルウェアとスレッドプール制御](05_async_and_realtime/concurrency_and_middleware.md) · [ネイティブ SSE・JSONL・WebSocket](05_async_and_realtime/sse_websockets_streaming.md) | `run_in_threadpool`, `EventSourceResponse`, `ServerSentEvent`, `WebSocket` |
| **6. 可観測性・例外設計・実践テスト** | [ネイティブ OpenTelemetry と例外処理](06_observability_and_testing/telemetry_and_errors.md) · [実践テスト手法と本番 ASGI 運用](06_observability_and_testing/testing_and_deployment.md) | `TelemetryConfig`, `get_telemetry_data()`, `HTTPException`, `RequestValidationError`, `TestClient` |
| **7. フロントエンド・マウント・OpenAPI 拡張** | [SPA frontend()・静的配信・マウント統合](07_frontend_and_openapi_ext/frontend_templates_mounts.md) · [Webhooks・Callbacks・SDK 生成・Docs UI](07_frontend_and_openapi_ext/webhooks_callbacks_sdks.md) | `frontend()`, `StaticFiles`, `Jinja2Templates`, `app.webhooks`, `callbacks` |
| **8. 設定管理・SQL DB・CLI・エコシステム** | [pydantic-settings 設定管理と SQL DB](08_ecosystem_and_operations/settings_and_databases.md) · [FastAPI CLI・プロキシ・GraphQL・AI 連携](08_ecosystem_and_operations/cli_proxy_graphql_ai.md) | `BaseSettings`, `@lru_cache`, SQL `yield` セッション, `fastapi-cli`, `--proxy-headers` |

## 公式リソースと関連ガイド

- **FastAPI への敬意と公式ドキュメント**: FastAPI は **Sebastián Ramírez 氏（`@tiangolo`）** およびコミュニティによって MIT ライセンスのもと開発・保守されています。公式ドキュメントや最新のリリースノートについては **[https://fastapi.tiangolo.com/](https://fastapi.tiangolo.com/)** および **[github.com/fastapi/fastapi](https://github.com/fastapi/fastapi)** をご参照ください。
- **読み進め方**: まずは **[第 1 章：FastAPI の設計思想と基本概念](01_getting_started/overview.md)** でリクエスト処理モデルの全体像を掴むか、**[クイックスタートと自動生成 Docs](01_getting_started/quickstart.md)** で実際に動作するコードをお試しください。

> **FastAPI 本体のソースコード実装を学びたい方へ**: FastAPI 自体の内部モジュール構造、ルートコンパイラの実装詳細、Pydantic v2 アダプタの仕組みを深掘りしたい場合は、併設の **[FastAPI 内部アーキテクチャ解説ガイド](https://fastapi.drawlib.com/architecture/)** をご覧ください。
