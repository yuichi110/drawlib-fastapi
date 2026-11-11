# SPA frontend()・静的配信・テンプレート・マウント統合

FastAPI `v0.162.2` は、新設された低優先度静的ルーティング機構 `app.frontend()` / `router.frontend()` を軸に、モダンな Single-Page Application（SPA）配信、サーバーサイド HTML テンプレート、独立した ASGI サブアプリケーション、そしてレガシー WSGI アプリの段階的移行を単一プロセス上でシームレスに統合します。

```drawlib align=center code=hide file=spa_frontend_routing_priority.png caption="FastAPI v0.162.2 の app.frontend() / router.frontend() 優先順位ディスパッチとブラウザ HTML フォールバック判定"
from drawlib.canvas import save, setup
from drawlib.icons import code, phosphor
from drawlib.lines import line, lines
from drawlib.shapes import rectangle
from drawlib.smartarts import ChevronProcess, Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=188, height=98, dpi=150)

outer = Panel(
    "FastAPI v0.162.2 — app.frontend() & router.frontend() Low-Priority Dispatch",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=12.0),
    icon=phosphor.compass,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
outer.draw((4.0, 4.0), width=180.0, height=90.0)

# Top 4-Stage SPA Dispatch Evaluation Order
stages = ChevronProcess(
    style=Styles.Neutral,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    corner_angle=60.0,
    spacing=1.6,
    flat_left_end=True,
)
stages.add("1. Normal Routes", description="API Routes, WS & Mount", style=Styles.SecondaryNeutral)
stages.add("2. Router DI Gate", description="Depends() & Longest Path", style=Styles.PrimaryNeutral)
stages.add("3. Static Lookup", description="dist/ File & Dir Index", style=Styles.Neutral)
stages.add(
    "4. Fallback Gate",
    description="404.html / Accept HTML",
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
)
stages.draw(xy=(8.0, 70.0), width=172.0, height=12.5)

# Left Ingress Card (cx=23, cy=36.5, w=30, h=53 -> x=8..38, y=10..63)
rectangle((23.0, 36.5), width=30.0, height=53.0, style=Styles.PrimaryNeutral.patch(shape_r=2.0))
code.fastapi((23.0, 55.5), width=5.6, style=Styles.Primary)
text((23.0, 47.5), "ASGI Request", style=Styles.DarkBold.patch(text_size=11.0))
text(
    (10.2, 27.5),
    "• GET /api/items\n• GET /assets/app.js\n• GET /dashboard\n   Accept: text/html\n• GET /missing.js\n   Accept: */*",
    style=Styles.Dark.patch(text_size=10.0, halign="left"),
)

# 4 Outcome Tracks (y = 56.5, 43.2, 29.9, 16.6)
tracks = [
    (
        56.5,
        ("1. API or Mount Match?", "@app.get / WS / Mount", Styles.SecondaryNeutral, False),
        ("Execute API Route", "Never shadowed by '/'", Styles.White, False),
        ("200 / API JSON 404", "API 404s stay JSON", Styles.SecondaryNeutral, False),
        False,
    ),
    (
        43.2,
        ("2. File in dist/?", "Static Asset Lookup", Styles.Neutral, False),
        ("Direct FileResponse", "Threadpool stat + ETag", Styles.White, False),
        ("200 OK Static Asset", "dist/assets/app.js", Styles.PrimaryNeutral, False),
        False,
    ),
    (
        29.9,
        ("3. Accept: text/html?", "HTML Navigation Check", Styles.PrimaryNeutral, False),
        ("SPA Shell Fallback", "Serves dist/index.html", Styles.PrimaryFlat, True),
        ("200 OK Client Router", "React / Vue / Svelte", Styles.PrimaryNeutral, False),
        True,
    ),
    (
        16.6,
        ("4. Non-HTML / Missing", "Accept: */* or q=0", Styles.Neutral, False),
        ("Skip index.html", "Or serve dist/404.html", Styles.White, False),
        ("404 Not Found", "Prevents '<' JS syntax bug", Styles.Neutral, False),
        False,
    ),
]

# Orthogonal trunk x=38 -> x=44 -> 4 tracks entering x=50 (6.0u arrow gap)
line((38.0, 36.5), (44.0, 36.5), style=Styles.DarkBold)
lines([(44.0, 16.6), (44.0, 56.5)], style=Styles.DarkBold)

for ty, c1, c2, c3, is_focal in tracks:
    arr_style = Styles.PrimaryBold if is_focal else Styles.DarkBold
    line((44.0, ty), (50.0, ty), arrow_head="->", style=arr_style)

    # Column 1: cx=68.5, w=37 -> x=50..87
    rectangle((68.5, ty), width=37.0, height=11.0, style=c1[2].patch(shape_r=1.6))
    text((68.5, ty + 2.2), c1[0], style=Styles.DarkBold.patch(text_size=10.2))
    text((68.5, ty - 2.4), c1[1], style=Styles.Dark.patch(text_size=10.0))

    # Gap 87 -> 94 (7.0u)
    line((87.0, ty), (94.0, ty), arrow_head="->", style=arr_style)

    # Column 2: cx=113.5, w=39 -> x=94..133
    rectangle((113.5, ty), width=39.0, height=11.0, style=c2[2].patch(shape_r=1.6))
    h_st = Styles.WhiteBold if c2[3] else Styles.DarkBold
    b_st = Styles.White if c2[3] else Styles.Dark
    text((113.5, ty + 2.2), c2[0], style=h_st.patch(text_size=10.2))
    text((113.5, ty - 2.4), c2[1], style=b_st.patch(text_size=10.0))

    # Gap 133 -> 140 (7.0u)
    line((133.0, ty), (140.0, ty), arrow_head="->", style=arr_style)

    # Column 3: cx=160.0, w=40 -> x=140..180
    rectangle((160.0, ty), width=40.0, height=11.0, style=c3[2].patch(shape_r=1.6))
    text((160.0, ty + 2.2), c3[0], style=Styles.DarkBold.patch(text_size=10.2))
    text((160.0, ty - 2.4), c3[1], style=Styles.Dark.patch(text_size=10.0))

save()
```

## 1. `app.frontend()` と `router.frontend()` によるネイティブ SPA 配信

従来、React・Vue・Svelte などのビルド成果物（`dist/`）を `app.mount("/", StaticFiles(directory="dist", html=True))` でルート `"/"` に配信しようとすると、「先にマウントすると `@app.get("/api/...")` を覆い隠してしまう」「クライアントサイドルート（`/dashboard/analytics` 等）をブラウザでリロードすると `404` になる」という 2 つの課題がつきまとっていました。

FastAPI `v0.162.2` では、`app.frontend()`（および `app.router.frontend()` / `router.frontend()`）によってこれらがフレームワーク標準機能として解決されました。`"/"` 配下を無差別に捕捉する貪欲な `Mount` ではなく、専用の **低優先度 SPA フロントエンドルーター** として登録されるため、アプリケーション全体（インクルードされた全 `APIRouter` を含む）の API ルート・WebSocket・マウント・末尾スラッシュリダイレクトがすべて不一致だった場合にのみフロントエンド探索が実行されます。

| パラメータ / 指定値 | 既定値 | `app.frontend()` / `router.frontend()` の実行時挙動 |
| :--- | :--- | :--- |
| **`fallback="auto"`** | はい | `directory` 直下に `404.html` があれば `404` で返し、なければ HTML ナビゲーション要求時に `index.html`（`200`）へフォールバック（どちらも無ければ `404`） |
| **`fallback="index.html"`** | いいえ | `404.html` が共存していても HTML ナビゲーション要求には常に `index.html`（`200`）を返却。`check_dir` 有効時は起動時に `index.html` の存在を検証 |
| **`fallback="404.html"`** | いいえ | 対象プレフィックス配下の未検出パスに対してカスタム静的 `404.html` をステータス `404` で返却。起動時にファイル存在を検証 |
| **`fallback=None`** | いいえ | フォールバックを無効化。実在するビルドファイルおよびサブディレクトリ `index.html` のみを配信し、未検出時は通常の JSON `404` を返却 |
| **`check_dir="auto"`** | はい | `FASTAPI_ENV="development"`（`fastapi dev` 実行時に自動設定）では警告のみで起動時チェックをスキップし、本番環境ではディレクトリ欠落時に `RuntimeError` で即時停止 |

### グローバル優先順位・セグメント境界一致・ルーター DI 保護

自前のキャッチオール `@app.get("/{full_path:path}")` 実装では見落とされがちな以下の 4 つの安全設計が、組み込みの SPA フロントエンドルーターには標準装備されています。

1. **グローバル API 優先と API `404` の保全**: `include_router()` の登録順序に関わらず、通常の API ルート（`@app.get`、`@app.post` 等）と `WebSocket` ハンドラーが常に優先されます。`@app.get("/api/items/{item_id}")` にマッチした上でエンドポイントが `HTTPException(404)` を送出した場合も、SPA の `index.html` にすり替わることなく JSON の `404` 応答がそのまま返ります。
2. **ブラウザ HTML ナビゲーション判定（`Accept` ヘッダー交渉）**: `index.html` フォールバック時は `Accept` ヘッダーのメディアタイプと品質値（`q`）を厳密に解析し、`text/html` または `application/xhtml+xml`（`q != 0`）を明示的に受け入れる `GET` / `HEAD` 要求のみ `index.html`（`200 OK`）を返します。存在しない JS バンドル（`GET /assets/missing.js` / `Accept: */*`）や API 誤 URL（`Accept: application/json`）には正しく `404` を返すため、`<script>` タグが HTML を読み込んで `Unexpected token '<'` で壊れる事故を防ぎます。
3. **セグメント境界での最長プレフィックス選択**: `app.frontend("/", directory="site")` と `router.frontend("/admin", directory="admin_dist")` を併用した場合、パスセグメント境界で一致判定を行い（`/admin` が `/administration` を誤捕捉しない）、最も具体的なプレフィックスを選択します。
4. **保護されたフロントエンドへの依存性注入（DI）適用**: `router.frontend()` はアプリ階層・`include_router()`・`APIRouter(dependencies=[Depends(...)])` の依存関数を外側から内側へ順に解決します。Cookie セッション検証、カスタム `Response` ヘッダー付与、`BackgroundTasks`、テスト時の `app.dependency_overrides` がそのまま機能します。

```python
from pathlib import Path
from fastapi import APIRouter, Depends, FastAPI, HTTPException, Request
from fastapi.testclient import TestClient


def build_spa_service(dist_dir: Path, admin_dist: Path) -> FastAPI:
    app = FastAPI(title="Unified API + SPA Service")

    @app.get("/api/items/{item_id}")
    async def read_item(item_id: int) -> dict[str, object]:
        if item_id == 0:
            raise HTTPException(status_code=404, detail="Item not found")
        return {"item_id": item_id, "source": "api"}

    def require_admin_cookie(request: Request) -> None:
        if request.cookies.get("__Host-admin_session") != "verified-session":
            raise HTTPException(status_code=401, detail="Admin session required")

    admin_router = APIRouter(dependencies=[Depends(require_admin_cookie)])
    admin_router.frontend("/admin", directory=admin_dist, fallback="index.html")
    app.include_router(admin_router)

    # Low-priority SPA mount at "/" never shadows /api/* or /admin/*
    app.frontend("/", directory=dist_dir, fallback="auto")
    return app
```

## 2. SPA `frontend()`・テンプレート・マウント・WSGI の使い分け

1 つの FastAPI ASGI ホストプロセス上で、クライアントサイド描画（SPA）、Jinja2 によるサーバーサイド HTML 描画、サブチーム単位の独立 FastAPI アプリ、そして同期型 WSGI レガシー資産を適材適所で共存させることができます。

```drawlib align=center code=hide file=mounts_templates_wsgi_topology.png caption="単一 ASGI ホスト上の統合トポロジ — app.frontend()・Jinja2Templates + StaticFiles・サブアプリ・a2wsgi の比較"
from drawlib.canvas import save, setup
from drawlib.diagrams.architecture import (
    ArchitectureDiagram,
    CodeIcon,
    Node,
    NodeGroup,
    PhosphorIcon,
)
from drawlib.icons import phosphor
from drawlib.lines import line, lines
from drawlib.smartarts import Panel
from drawlib.styles import Styles

setup(width=188, height=98, dpi=150)

outer = Panel(
    "Unified ASGI Host Process  (Uvicorn / Hypercorn  ·  app = FastAPI())",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=12.0),
    icon=phosphor.plugs,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
outer.draw((4.0, 4.0), width=180.0, height=90.0)

diag = ArchitectureDiagram(
    node_style=Styles.PrimaryBold,
    node_text_style=Styles.DarkBold.patch(text_size=10.3),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.White.patch(shape_r=1.5),
)

# Top Focal Dispatcher Node (center at y=75.0 -> bottom=68.0)
diag.add(
    Node(
        "Root FastAPI Router & Middleware Stack\nAPI Routes  ->  app.mount()  ->  SPA frontend()",
        width=86.0,
        height=14.0,
        icon=CodeIcon.FASTAPI,
        icon_size=6.0,
        card_style=Styles.PrimaryFlat.patch(shape_r=1.8),
        text_style=Styles.WhiteBold.patch(text_size=10.8),
        style=Styles.WhiteBold,
    ),
    (94.0, 75.0),
)

# 4 Strategy Columns: x = 8, 52, 96, 140 (width=40, height=48, y=8..56, centers cx=28, 72, 116, 160)
g_spa = diag.add(
    NodeGroup(
        title="1. SPA frontend()",
        width=40.0,
        height=48.0,
        style=Styles.PrimaryNeutral.patch(shape_r=1.8),
        text_style=Styles.DarkBold.patch(halign="left", text_size=10.8),
    ),
    (8.0, 8.0),
)
g_spa.add(
    Node("dist/ Static Build\n& index.html Shell", width=34.0, height=14.0, icon=PhosphorIcon.GLOBE, icon_size=5.2),
    (20.0, 32.0),
)
g_spa.add(
    Node("Accept: text/html\n+ Router Depends()", width=34.0, height=14.0, icon=PhosphorIcon.SHIELD_CHECK, icon_size=5.2),
    (20.0, 13.0),
)

g_ssr = diag.add(
    NodeGroup(
        title="2. SSR + Static",
        width=40.0,
        height=48.0,
        style=Styles.Neutral.patch(shape_r=1.8),
        text_style=Styles.DarkBold.patch(halign="left", text_size=10.8),
    ),
    (52.0, 8.0),
)
g_ssr.add(
    Node("Jinja2Templates\nTemplateResponse", width=34.0, height=14.0, icon=PhosphorIcon.CODE, icon_size=5.2),
    (20.0, 32.0),
)
g_ssr.add(
    Node("/static Mount\nurl_for('static')", width=34.0, height=14.0, icon=PhosphorIcon.FILE_DOC, icon_size=5.2, card_style=Styles.SecondaryNeutral),
    (20.0, 13.0),
)

g_sub = diag.add(
    NodeGroup(
        title="3. Sub-App Mount",
        width=40.0,
        height=48.0,
        style=Styles.SecondaryNeutral.patch(shape_r=1.8),
        text_style=Styles.DarkBold.patch(halign="left", text_size=10.8),
    ),
    (96.0, 8.0),
)
g_sub.add(
    Node("subapi = FastAPI()\nroot_path='/subapi'", width=34.0, height=14.0, icon=CodeIcon.FASTAPI, icon_size=5.2),
    (20.0, 32.0),
)
g_sub.add(
    Node("Isolated OpenAPI\n/subapi/docs", width=34.0, height=14.0, icon=CodeIcon.OPENAPI, icon_size=5.2, card_style=Styles.PrimaryNeutral),
    (20.0, 13.0),
)

g_wsgi = diag.add(
    NodeGroup(
        title="4. Legacy WSGI",
        width=40.0,
        height=48.0,
        style=Styles.Neutral.patch(shape_r=1.8),
        text_style=Styles.DarkBold.patch(halign="left", text_size=10.8),
    ),
    (140.0, 8.0),
)
g_wsgi.add(
    Node("a2wsgi Bridge\nWSGIMiddleware", width=34.0, height=14.0, icon=PhosphorIcon.LIGHTNING, icon_size=5.2),
    (20.0, 32.0),
)
g_wsgi.add(
    Node("Flask / Django\nWorker Threadpool", width=34.0, height=14.0, icon=CodeIcon.PYTHON, icon_size=5.2, card_style=Styles.SecondaryNeutral),
    (20.0, 13.0),
)

diag.draw()

# Orthogonal fan-out bus from Root Node bottom (y=68.0) -> bus (y=62.5) -> group tops (y=56.0, 6.3u terminal gap)
line((94.0, 68.0), (94.0, 62.5), style=Styles.DarkBold)
lines([(28.0, 62.5), (160.0, 62.5)], style=Styles.DarkBold)
for cx in (28.0, 72.0, 116.0, 160.0):
    line((cx, 62.5), (cx, 56.2), arrow_head="->", style=Styles.PrimaryBold if cx == 28.0 else Styles.DarkBold)

save()
```

| 統合メカニズム | 登録 API | 優先順位とスコープ分離 | 最適なユースケース |
| :--- | :--- | :--- | :--- |
| **SPA 静的ビルド配信** | `app.frontend("/", directory="dist")` | 最低優先度（全 API ルート不一致後に評価）・`Depends()` 対応 | `/api` と同居する Vite / React / Vue / Svelte / 静的サイト |
| **名前付き静的マウント** | `app.mount("/static", StaticFiles(...), name="static")` | `/static` プレフィックスの `Mount`・`url_for` 対応 | Jinja2 や自己配信 Swagger UI から参照する CSS / JS / 画像 |
| **サーバーサイド描画** | `Jinja2Templates(directory="templates")` | 標準 HTTP ルート（`response_class=HTMLResponse`） | HTMX フラグメント、メール本文生成、SEO 重視の SSR ページ |
| **独立サブアプリ** | `app.mount("/subapi", subapi)` | 独立した `FastAPI` インスタンス（`root_path="/subapi"`・専用 `/docs`） | マルチバージョン公開 API（`/v2`）、パートナー向け API、管理画面 |
| **レガシー WSGI 統合** | `app.mount("/v1", WSGIMiddleware(flask_app))` | `a2wsgi` により同期 WSGI をワーカースレッド上で実行 | Flask / Django モノリスから FastAPI への段階的マイグレーション |

## 3. `Jinja2Templates` と `StaticFiles` によるサーバーサイド HTML 描画

サーバーサイドレンダリング（SSR）や HTMX ベースの UI を構築する場合は、`jinja2` パッケージを導入し、`fastapi.templating.Jinja2Templates` と名前付き `StaticFiles` マウントを組み合わせます。

- **キーワード引数形式の `TemplateResponse` シグネチャ**: 現行の Starlette / FastAPI では必ず `request=request, name="item.html", context={...}` のキーワード引数形式で呼び出します（旧来の位置引数 `TemplateResponse("item.html", {"request": request})` は非推奨化されています）。
- **`url_for` による逆引きアセット URL 生成**: マウント時に `name="static"` を指定すると、テンプレート内から `{{ url_for('static', path='/styles.css') }}` で `root_path` 対応の URL を安全に生成できます。
- **XSS 自動エスケープと属性クォートの徹底**: Jinja2 は `.html` / `.htm` / `.xml` に対して既定で `autoescape` を有効化します。HTML 属性に変数を埋め込む際は必ず二重引用符で囲み（`data-item-id="{{ id }}"`）、外部入力に対する安易な `| safe` フィルタの適用は避けてください。

```python
from pathlib import Path
from typing import Annotated
from fastapi import FastAPI, Path as PathParam, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates


def create_ssr_app(static_dir: Path, templates_dir: Path) -> FastAPI:
    app = FastAPI()
    app.mount("/static", StaticFiles(directory=static_dir), name="static")
    templates = Jinja2Templates(directory=templates_dir)

    # templates/item.html:
    # <link href="{{ url_for('static', path='/styles.css') }}" rel="stylesheet">
    # <h1 data-item-id="{{ id }}">Item: {{ title }}</h1>
    @app.get("/items/{id}", response_class=HTMLResponse)
    async def read_item_page(
        request: Request,
        id: Annotated[str, PathParam(pattern=r"^[a-zA-Z0-9_-]+$")],
        title: str = "Wireless Keyboard",
    ) -> HTMLResponse:
        return templates.TemplateResponse(
            request=request,
            name="item.html",
            context={"id": id, "title": title},
        )

    return app
```

## 4. 独立サブアプリケーションと `a2wsgi` によるレガシー WSGI 移行

### 独立サブアプリと ASGI `root_path` の自動伝播

ルート定義を単一の OpenAPI スキーマと共通ミドルウェア層へ統合する `app.include_router()` とは対照的に、`app.mount("/subapi", subapi)` は **完全に独立した別の ASGI アプリケーション** を指定パス配下に接続します。

- **OpenAPI スキーマと Docs UI の完全分離**: 親アプリは親ルートのみを含む `/openapi.json` と `/docs` を公開し、`subapi` は独自の `/subapi/openapi.json` と `/subapi/docs` を独立して提供します。
- **ASGI `root_path` の自動設定**: Starlette の `Mount` が `subapi` 呼び出し時に `scope["root_path"]` へ `"/subapi"` を自動付与するため、`/subapi/docs` の Swagger UI はスキーマ取得先や「Try it out」の送信先 URL を自動的に `/subapi/...` 基準で解決します。
- **`lifespan` 実行に関する注意点**: マウントされたサブアプリの `lifespan` イベントは Starlette の `Mount` からは自動実行されません。共有リソースの初期化は親アプリの `lifespan` に集約するか、`contextlib.AsyncExitStack` でサブアプリの lifespan を明示的に連結してください（詳細は [大規模 DI・Lifespan 管理・テスト戦略](../02_enterprise_architecture/di_lifespan_testing.md) を参照）。

### `a2wsgi.WSGIMiddleware` による段階的 WSGI 移行（ストラングラーパターン）

既存の Flask や Django モノリスを一括書き換えせずに段階的に FastAPI へ移行する場合、レガシー WSGI アプリを特定プレフィックスにマウントし、新規エンドポイントから順に外側の FastAPI 側で非同期実装していくストラングラーパターン（Strangler Fig Pattern）が有効です。Starlette 旧内蔵の `starlette.middleware.wsgi.WSGIMiddleware` は非推奨化されているため、FastAPI 公式ドキュメントでは **`a2wsgi.WSGIMiddleware`**（`pip install a2wsgi`）の利用が推奨されています。`a2wsgi` は非同期イベントループと同期 WSGI ワーカースレッド間のストリーム変換を安全に仲介し、マウントパスを `SCRIPT_NAME` として自動伝播します。

```python
from a2wsgi import WSGIMiddleware
from fastapi import FastAPI, Request
from flask import Flask, jsonify, request as flask_request

# 1. Independent FastAPI sub-application with isolated /subapi/docs
subapi = FastAPI(title="Partner Sub-API", version="2.0.0")


@subapi.get("/sub")
def read_sub(request: Request) -> dict[str, str]:
    return {
        "message": "Hello from sub-application",
        "root_path": request.scope.get("root_path", ""),
    }


# 2. Legacy synchronous Flask (WSGI) application
flask_app = Flask(__name__)


@flask_app.get("/orders")
def legacy_orders():
    return jsonify({"service": "legacy-flask", "script_name": flask_request.script_root})


# 3. Unified FastAPI host mounting both the sub-app and WSGI bridge
app = FastAPI(title="Main Gateway API", version="1.0.0")


@app.get("/app")
def read_main() -> dict[str, str]:
    return {"message": "Hello World from main app"}


app.mount("/subapi", subapi)
app.mount("/v1", WSGIMiddleware(flask_app))
```

次節 **[Webhooks・Callbacks・SDK 生成・Docs UI](webhooks_callbacks_sdks.md)** では、OpenAPI `3.1.0` を活用した非同期イベント仕様の公開、クリーンなクライアント SDK 自動生成、および閉域網向け Swagger UI / ReDoc 自己配信パターンを解説します。リバースプロキシ配下での `--forwarded-allow-ips` 運用については **[FastAPI CLI・プロキシ・GraphQL・AI 連携](../08_ecosystem_and_operations/cli_proxy_graphql_ai.md)** もあわせて参照してください。
