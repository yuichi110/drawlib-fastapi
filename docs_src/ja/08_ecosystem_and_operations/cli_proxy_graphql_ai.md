# FastAPI CLI・リバースプロキシ・GraphQL・AI 駆動開発

FastAPI `v0.162.2` は、開発から本番までのサーバー運用（`fastapi dev` / `fastapi run` と ASGI `--root-path` プロキシ連携）、`Depends()` を共有する `Strawberry` GraphQL サブルーター、そしてパッケージ同梱の AI エージェントスキル（`uvx library-skills`・`PEP 727` `Doc()`・SSE/JSONL ストリーミング）を一貫した設計で統合します。

```drawlib align=center code=hide file=cli_and_reverse_proxy_topology.png caption="FastAPI CLI 実行モード（fastapi dev vs fastapi run）とリバースプロキシのパスプレフィックス（--root-path）運用トポロジ"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.lines import line
from drawlib.shapes import rectangle
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=198, height=90, dpi=150)

text(
    (99.0, 85.0),
    "FastAPI CLI Modes & Reverse Proxy (--root-path) Operational Topology",
    style=Styles.DarkBold.patch(text_size=13.0),
)

# Left Panel: FastAPI CLI
cli_panel = Panel(
    "1. FastAPI CLI (fastapi[standard])",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.terminal_window,
    icon_style=Styles.SecondaryBold,
    header_variant="filled",
    header_height=8.5,
)
cli_panel.draw((4.0, 5.0), width=82.0, height=74.0)
l_xy, l_w, l_h = cli_panel.get_content_box((4.0, 5.0), width=82.0, height=74.0, padding=(3.5, 3.0))

cl_cli = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.SecondaryBold,
    direction="vertical",
    spacing=2.8,
)
cl_cli.add(
    "[tool.fastapi] Entrypoint",
    "pyproject.toml -> 'app.main:app'",
    badge_text="TOML",
    icon=phosphor.file_code,
)
cl_cli.add(
    "fastapi dev",
    "127.0.0.1 • Reload • FASTAPI_ENV=dev",
    badge_text="DEV",
    icon=phosphor.code,
    style=Styles.SecondaryNeutral,
)
cl_cli.add(
    "fastapi run",
    "Prod Uvicorn • --workers • --proxy-headers",
    badge_text="RUN",
    icon=phosphor.rocket_launch,
    style=Styles.PrimaryNeutral,
    badge_style=Styles.PrimaryFlat,
    badge_text_style=Styles.WhiteBold.patch(text_size=10.0),
    icon_style=Styles.WhiteBold,
)
cl_cli.draw(xy=l_xy, width=l_w, height=l_h)

# Right Panel: Behind a Reverse Proxy & --root-path
proxy_panel = Panel(
    "2. TLS Reverse Proxy & --root-path /api/v1",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.globe,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
proxy_panel.draw((90.0, 5.0), width=104.0, height=74.0)

# Top ingress boxes inside Right Panel
rectangle((115.0, 58.5), width=42.0, height=15.5, style=Styles.White.patch(shape_r=1.8))
text((115.0, 61.5), "TLS Edge Proxy", style=Styles.DarkBold.patch(text_size=10.5))
text((115.0, 55.8), "Strips /api/v1", style=Styles.Dark.patch(text_size=10.0))

line((136.5, 58.5), (144.5, 58.5), arrow_head="->", style=Styles.PrimaryBold.patch(line_width=1.8))

rectangle((167.5, 58.5), width=45.0, height=15.5, style=Styles.PrimaryFlat.patch(shape_r=1.8))
text((167.5, 61.5), "--root-path /api/v1", style=Styles.WhiteBold.patch(text_size=10.5))
text((167.5, 55.8), "scope['root_path']", style=Styles.White.patch(text_size=10.0))

line((167.5, 50.5), (167.5, 44.5), arrow_head="->", style=Styles.DarkBold.patch(line_width=1.6))

# Middle OpenAPI resolution card
rectangle((142.0, 35.5), width=96.0, height=16.5, style=Styles.PrimaryNeutral.patch(shape_r=1.8))
phosphor.file_text((100.0, 35.5), width=5.0, style=Styles.PrimaryBold)
text(
    (105.5, 38.5),
    "Per-Request OpenAPI & Swagger UI Resolution",
    style=Styles.DarkBold.patch(text_size=10.5, halign="left"),
)
text(
    (105.5, 32.5),
    "servers: [{'url': '/api/v1'}]  •  /docs -> /api/v1/openapi.json",
    style=Styles.Dark.patch(text_size=10.0, halign="left"),
)

# Bottom Edge Middleware & v0.146.0 Deprecation card
rectangle((142.0, 15.5), width=96.0, height=16.5, style=Styles.SecondaryNeutral.patch(shape_r=1.8))
phosphor.shield_check((100.0, 15.5), width=5.0, style=Styles.SecondaryBold)
text(
    (105.5, 18.5),
    "Edge Middleware & v0.146.0+ Server Rule",
    style=Styles.DarkBold.patch(text_size=10.5, halign="left"),
)
text(
    (105.5, 12.5),
    "TrustedHost • HTTPSRedirect • GZip  •  Avoid app root_path",
    style=Styles.Dark.patch(text_size=10.0, halign="left"),
)

save()
```

## 1. FastAPI CLI・リバースプロキシ（`--root-path`）・エッジミドルウェア

`pip install "fastapi[standard]"` を導入すると `fastapi` コマンド（`fastapi.cli:main` から `fastapi-cli` へ委譲）が有効になり、独自シェルスクリプトに頼ることなくローカル開発・本番 ASGI 起動・マネージドクラウドへのデプロイ（`uv run fastapi deploy`）を標準化できます。

### `[tool.fastapi]` の宣言と `fastapi dev` vs `fastapi run` の使い分け

コマンド実行のたびにモジュールパスを指定する代わりに、`pyproject.toml` にアプリケーションのエントリポイントを 1 度だけ宣言します。

```toml
[tool.fastapi]
entrypoint = "my_app.main:app"
```

`entrypoint` を定義しておけば、`fastapi dev` と `fastapi run` がそれぞれの環境に最適化されたセキュリティ設定と並行実行オプションを自動適用します。

| 機能・挙動 | `fastapi dev`（ローカル開発モード） | `fastapi run`（本番ランタイム） |
| :--- | :--- | :--- |
| **既定バインドアドレス** | `127.0.0.1:8000`（安全なローカルループバック限定） | `0.0.0.0:8000`（コンテナ待受用・プロキシ背後で保護） |
| **自動リロード監視** | **有効**（ファイル保存時に即座にワーカーを再起動） | **無効**（ファイル監視オーバーヘッドなし） |
| **`FASTAPI_ENV` 環境変数** | 未設定時に `FASTAPI_ENV="development"` を自動設定 | 設定なし（`app.frontend(check_dir="auto")` がビルド成果物を検証） |
| **スケール・プロキシ引数** | 単一リロードプロセス | `--workers N`, `--proxy-headers`, `--root-path /api/v1` |

### リバースプロキシ配下の `--root-path` と `v0.146.0` での `FastAPI(root_path=...)` 非推奨化

マイクロサービスのゲートウェイ構成（Nginx・Traefik・Envoy・Cloud Load Balancing など）では、外部公開 URL `https://api.example.com/api/v1/catalog` の **`/api/v1` プレフィックスをプロキシ側で除去** し、内部コンテナへ `/catalog` として転送する構成が一般的です。このときアプリ側が外部プレフィックスを認識していないと、Swagger UI（`/docs`）が `/api/v1/openapi.json` ではなくルート直下の `/openapi.json` を取得しようとして `404` になります。

**FastAPI `v0.146.0` 以降**（`v0.162.2` では `FastAPIDeprecationWarning` を送出）、Python コード内で `FastAPI(root_path="/api/v1")` を渡す方式は **非推奨（Deprecated）** となりました。URL プレフィックスはアプリケーションコードではなくデプロイトポロジの責務であるため、CLI から ASGI サーバー側へ指定します。

```bash
fastapi run --proxy-headers --root-path /api/v1
```

`FastAPI.setup()` 内部では、`/openapi.json`・`/docs`・`/redoc` への各リクエスト時に `req.scope.get("root_path", "")` を動的に参照します。

1. **キャッシュ汚染の完全防止**: `app.openapi()` はベースとなる OpenAPI `3.1.0` スキーマ辞書を 1 度だけ生成してキャッシュし、`/openapi.json` ルートはリクエストごとに辞書を浅くコピーした上で `servers` の先頭に `{"url": "/api/v1"}` を追加します（`root_path_in_servers=False` で無効化可能）。これにより特定の `root_path` が他リクエストのキャッシュを書き換えることはありません。
2. **Docs UI パスの自動解決**: Swagger UI（`/docs`）、OAuth2 リダイレクト（`/docs/oauth2-redirect`）、ReDoc（`/redoc`）のすべてが `openapi_url` に自動で `root_path`（`/api/v1/openapi.json`）を付与します。

### 標準搭載のエッジ防御・圧縮ミドルウェア

独自の [純粋 ASGI ミドルウェア](../05_async_and_realtime/concurrency_and_middleware.md) に加え、`fastapi.middleware` は本番エッジで頻用される標準ミドルウェアを提供しています。

- **`TrustedHostMiddleware(allowed_hosts=[...])`**: 未許可の `Host` ヘッダーを `400 Bad Request` で即座に拒否し、HTTP Host ヘッダーインジェクション攻撃を防御します。
- **`HTTPSRedirectMiddleware`**: 上流ロードバランサーで TLS リダイレクトを行わない構成において、`http://` から `https://`（および `ws://` から `wss://`）への `307 Temporary Redirect` を強制します。
- **`GZipMiddleware(minimum_size=1000, compresslevel=5)`**: クライアントが `Accept-Encoding: gzip` を送信し、かつレスポンスサイズが `minimum_size` バイト以上の場合にペイロードを自動圧縮します。

```python
import warnings

from fastapi import FastAPI, Request
from fastapi.exceptions import FastAPIDeprecationWarning
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.middleware.httpsredirect import HTTPSRedirectMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.testclient import TestClient


def build_edge_app(*, enforce_https: bool = False) -> FastAPI:
    app = FastAPI(title="Edge Catalog API", version="1.0.0")
    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=["api.example.com", "testserver"],
    )
    app.add_middleware(GZipMiddleware, minimum_size=500, compresslevel=5)
    if enforce_https:
        app.add_middleware(HTTPSRedirectMiddleware)

    @app.get("/catalog")
    def read_catalog(request: Request) -> dict[str, object]:
        return {
            "root_path": request.scope.get("root_path", ""),
            "items": [f"sku-{idx:03d}-enterprise-edition" for idx in range(40)],
        }

    return app


def test_root_path_openapi_servers_and_edge_middlewares() -> None:
    app = build_edge_app()

    # Simulate `fastapi run --root-path /api/v1` via ASGI scope root_path
    with TestClient(app, root_path="/api/v1") as prefixed_client:
        res = prefixed_client.get("/catalog", headers={"Accept-Encoding": "gzip"})
        assert res.status_code == 200
        assert res.headers.get("content-encoding") == "gzip"
        assert res.json()["root_path"] == "/api/v1"

        schema = prefixed_client.get("/openapi.json").json()
        assert schema["servers"] == [{"url": "/api/v1"}]
        assert "/api/v1/openapi.json" in prefixed_client.get("/docs").text

    # Unprefixed requests remain clean; spoofed Host headers return 400
    with TestClient(app) as direct_client:
        assert "servers" not in direct_client.get("/openapi.json").json()
        bad_host = direct_client.get("/catalog", headers={"Host": "evil.attacker.tld"})
        assert bad_host.status_code == 400

    # HTTPSRedirectMiddleware redirects plain HTTP -> HTTPS (307)
    https_app = build_edge_app(enforce_https=True)
    with TestClient(https_app, base_url="http://api.example.com") as http_client:
        redir = http_client.get("/catalog", follow_redirects=False)
        assert redir.status_code == 307
        assert redir.headers["location"] == "https://api.example.com/catalog"

    # Passing root_path to FastAPI(...) emits FastAPIDeprecationWarning
    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        FastAPI(root_path="/legacy")
        assert any(issubclass(w.category, FastAPIDeprecationWarning) for w in caught)
```

---

## 2. Strawberry GraphQL 統合と AI ネイティブ開発ワークフロー

FastAPI の型アノテーション中心の設計は、**`Strawberry`** による型安全な GraphQL クエリグラフと、最新の **AI コーディングエージェント / MCP ツール基盤** の双方へ自然に拡張できます。

```drawlib align=center code=hide file=graphql_and_ai_agent_workflow.png caption="Depends() コンテキストを共有する Strawberry GraphQLRouter と FastAPI v0.162.2 の AI エージェント開発ワークフロー"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=192, height=90, dpi=150)

text(
    (96.0, 85.0),
    "Strawberry GraphQL DI Integration & FastAPI v0.162.2 AI Agent Workflow",
    style=Styles.DarkBold.patch(text_size=13.0),
)

# Left Panel: Strawberry GraphQL
gql_panel = Panel(
    "1. Strawberry GraphQLRouter + FastAPI DI",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.graph,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
gql_panel.draw((4.0, 5.0), width=90.0, height=74.0)
l_xy, l_w, l_h = gql_panel.get_content_box((4.0, 5.0), width=90.0, height=74.0, padding=(3.5, 3.0))

cl_gql = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    direction="vertical",
    spacing=2.8,
)
cl_gql.add(
    "Shared FastAPI Depends()",
    "OAuth2 Viewer • SQLModel Session • Settings",
    badge_text="DI",
    icon=phosphor.plugs,
)
cl_gql.add(
    "context_getter Bridge",
    "BaseContext injects DI into info.context",
    badge_text="CTX",
    icon=phosphor.arrows_left_right,
    style=Styles.PrimaryNeutral,
)
cl_gql.add(
    "include_router(..., '/graphql')",
    "Typed @strawberry.type alongside REST",
    badge_text="GQL",
    icon=phosphor.brackets_curly,
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
    badge_style=Styles.White,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
)
cl_gql.draw(xy=l_xy, width=l_w, height=l_h)

# Right Panel: Develop with AI Workflow
ai_panel = Panel(
    "2. Develop with AI & Bundled Agent Skills",
    style=Styles.Neutral.patch(shape_r=2.0),
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.sparkle,
    icon_style=Styles.SecondaryBold,
    header_variant="filled",
    header_height=8.5,
)
ai_panel.draw((98.0, 5.0), width=90.0, height=74.0)
r_xy, r_w, r_h = ai_panel.get_content_box((98.0, 5.0), width=90.0, height=74.0, padding=(3.5, 3.0))

cl_ai = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.SecondaryBold,
    direction="vertical",
    spacing=2.8,
)
cl_ai.add(
    "uvx library-skills",
    "Installs bundled fastapi/.agents/skills",
    badge_text="1",
    icon=phosphor.robot,
    style=Styles.SecondaryNeutral,
)
cl_ai.add(
    "Doc() + OpenAPI 3.1 + llms.txt",
    "PEP 727 contracts for agents & SDKs",
    badge_text="2",
    icon=phosphor.book_open,
)
cl_ai.add(
    "AI & MCP Streaming",
    "POST EventSourceResponse & JSONL yield",
    badge_text="3",
    icon=phosphor.broadcast,
    style=Styles.PrimaryNeutral,
    badge_style=Styles.PrimaryFlat,
    badge_text_style=Styles.WhiteBold.patch(text_size=10.0),
    icon_style=Styles.WhiteBold,
)
cl_ai.draw(xy=r_xy, width=r_w, height=r_h)

save()
```

### `Strawberry`（`GraphQLRouter`）のマウントと `Depends()` コンテキスト共有

深くネストした関連データを 1 往復で柔軟に取得したい画面では GraphQL が威力を発揮する一方、HTTP キャッシュ・[OpenAPI からの型付き SDK 生成](../07_frontend_and_openapi_ext/webhooks_callbacks_sdks.md)・ファイルアップロード・明確なステータスコード制御では標準的な REST エンドポイントが優位です。別プロセスで GraphQL サーバーを立てる代わりに、**`Strawberry`**（`strawberry-graphql`）の `GraphQLRouter` を用いれば単一の FastAPI アプリ内に `APIRouter` として統合できます。

- **型ヒントの完全な親和性**: `@strawberry.type` は標準の `dataclasses` や Pydantic モデルと同じ Python 型アノテーションでスキーマを定義します。
- **`context_getter` による DI 統合**: `strawberry.fastapi.BaseContext` を継承し `context_getter` 関数を渡すことで、REST 側と **完全に同一の FastAPI `Depends()` 依存関係**（OAuth2 認証ユーザー、[SQLModel `SessionDep`](settings_and_databases.md)、`SettingsDep`）を `info.context` へ注入でき、`pytest` の `app.dependency_overrides` も REST と `/graphql` の双方へ一括適用されます。

### FastAPI `v0.162.2` における AI 駆動開発（`library-skills`・`Doc()`・MCP SSE）

事前学習済み LLM は古い学習コーパスに引きずられ、非推奨となった `ORJSONResponse`・`RootModel`・素の `Depends()` デフォルト引数・旧式の `@app.on_event("startup")` を出力しがちです。これを防ぐため、FastAPI `v0.162.2` は **バージョン完全一致の公式 AI エージェントスキル** を `fastapi` パッケージ内部（`fastapi/.agents/skills/fastapi/SKILL.md` と `references/`）に直接同梱しています。

1. **`uvx library-skills` によるスキル自動同期**: プロジェクト内で `uvx library-skills` を実行すると、インストール済みの `fastapi` バージョンに同梱された `.agents/skills/fastapi/` ルールがワークスペースへ展開され、コーディングエージェントが `Annotated[..., Depends()]`・`app.frontend()`・ネイティブ OpenTelemetry・`EventSourceResponse`・`SQLModel`・`Asyncer`（`asyncify` / `syncify`）の最新規約を正確に遵守します。
2. **機械可読な契約情報（`PEP 727 Doc()`・OpenAPI `3.1.0`・`llms.txt`）**: `Annotated[str, Doc("...")]` で記述した引数ドキュメントは `/openapi.json`（OpenAPI `3.1.0` JSON Schema）へ出力され、エージェントのツール定義や SDK 生成器、`llms.txt` ドキュメント索引がハルシネーションなく正確なパラメータ型と制約を参照できます。
3. **AI & Model Context Protocol（MCP）ストリーミング**: FastAPI ネイティブの [SSE（`EventSourceResponse`）および JSON Lines](../05_async_and_realtime/sse_websockets_streaming.md) は **`GET` だけでなく `POST` メソッドにも標準対応** しており、LLM トークン配信や MCP の HTTP+SSE トランスポートを `yield` のみで簡潔に実装できます。

```python
from collections.abc import AsyncIterable
from typing import Annotated

from annotated_doc import Doc
from fastapi import Depends, FastAPI
from fastapi.sse import EventSourceResponse, ServerSentEvent
from fastapi.testclient import TestClient
from pydantic import BaseModel
import strawberry
from strawberry.fastapi import BaseContext, GraphQLRouter


def get_current_viewer() -> str:
    return "alice@corp.internal"


ViewerDep = Annotated[str, Depends(get_current_viewer)]


class GraphQLContext(BaseContext):
    def __init__(self, viewer: str) -> None:
        super().__init__()
        self.viewer = viewer


async def get_graphql_context(viewer: ViewerDep) -> GraphQLContext:
    return GraphQLContext(viewer=viewer)


@strawberry.type
class BookNode:
    title: str
    author: str
    requested_by: str


@strawberry.type
class QueryRoot:
    @strawberry.field
    def books(self, info: strawberry.Info[GraphQLContext, None]) -> list[BookNode]:
        return [
            BookNode(
                title="FastAPI Architecture",
                author="Sebastián Ramírez",
                requested_by=info.context.viewer,
            )
        ]


graphql_schema = strawberry.Schema(query=QueryRoot)
graphql_router = GraphQLRouter(graphql_schema, context_getter=get_graphql_context)

app = FastAPI(title="Hybrid REST + GraphQL + AI Gateway")
app.include_router(graphql_router, prefix="/graphql", tags=["graphql"])


class AgentPrompt(BaseModel):
    prompt: Annotated[str, Doc("Natural-language instruction sent by the AI agent.")]


@app.post("/ai/stream", response_class=EventSourceResponse)
async def stream_agent_steps(
    body: AgentPrompt,
    viewer: ViewerDep,
) -> AsyncIterable[ServerSentEvent]:
    yield ServerSentEvent(
        event="agent.step",
        id="1",
        data={"viewer": viewer, "accepted_prompt": body.prompt},
    )


def test_strawberry_graphql_di_and_ai_sse() -> None:
    app.dependency_overrides[get_current_viewer] = lambda: "bot@ci.local"
    try:
        with TestClient(app) as client:
            gql_res = client.post(
                "/graphql",
                json={"query": "{ books { title requestedBy } }"},
            )
            assert gql_res.status_code == 200
            assert gql_res.json() == {
                "data": {
                    "books": [
                        {
                            "title": "FastAPI Architecture",
                            "requestedBy": "bot@ci.local",
                        }
                    ]
                }
            }

            sse_res = client.post("/ai/stream", json={"prompt": "Summarize schema"})
            assert sse_res.status_code == 200
            assert sse_res.headers["content-type"].startswith("text/event-stream")
            assert "event: agent.step" in sse_res.text
    finally:
        app.dependency_overrides.clear()
```

型安全な環境変数管理と `SQLModel` のテスト設計については [pydantic-settings 設定管理と SQL DB](settings_and_databases.md) を振り返るか、[ガイド概要と全体マップ](../index.md) へ戻って FastAPI `v0.162.2` の全体アーキテクチャを参照してください。
