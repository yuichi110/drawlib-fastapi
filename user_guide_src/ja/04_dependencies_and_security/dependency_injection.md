# 依存関係グラフ・リクエスト単位キャッシュ・yield スコープ

FastAPI `v0.162.2` はすべてのパスオペレーションとサブ依存関数を有向非巡回グラフ（DAG）として構成し、リクエスト単位の依存結果キャッシュと関数スコープ／リクエストスコープの 2 段階による `yield` クリーンアップタイミングを厳密に制御します。

```drawlib align=center code=hide file=dependant_dag_cache.png caption="依存関係グラフ（DAG）の解決とリクエスト単位キャッシュ（use_cache=True と use_cache=False）の共有構造"
from drawlib.canvas import save, setup
from drawlib.diagrams.architecture import ArchitectureDiagram, Node, PhosphorIcon
from drawlib.icons import phosphor
from drawlib.lines import line
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Styles

setup(width=166, height=98, dpi=150)

# Left Zone: Outer Panel framing the Multi-Level Dependency Graph
dag_panel = Panel(
    "Per-Request Dependency Graph (DAG)",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.5),
    icon=phosphor.tree_structure,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=9.5,
)
dag_panel.draw((4.0, 5.0), width=102.0, height=88.0, align="bottom_left")

dag = ArchitectureDiagram(
    width=96.0,
    height=75.0,
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.5),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
)

endpoint = dag.add(
    Node(
        "POST /billing/invoices\n(Path Operation)",
        width=40,
        height=13,
        icon=PhosphorIcon.GLOBE,
        icon_size=5.8,
        style=Styles.White,
        card_style=Styles.PrimaryFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.5),
    ),
    xy=(48.0, 66.5),
)

billing = dag.add(
    Node(
        "BillingService\nDepends()",
        width=32,
        height=13,
        icon=PhosphorIcon.RECEIPT,
        icon_size=5.8,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(25.0, 41.5),
)

audit = dag.add(
    Node(
        "AuditLogger\nDepends()",
        width=32,
        height=13,
        icon=PhosphorIcon.SCROLL,
        icon_size=5.8,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(71.0, 41.5),
)

db_dep = dag.add(
    Node(
        "get_db_session()\nuse_cache=True (1x)",
        width=29,
        height=13.5,
        icon=PhosphorIcon.DATABASE,
        icon_size=5.5,
        card_style=Styles.SecondaryNeutral,
    ),
    xy=(15.5, 9.0),
)

settings_dep = dag.add(
    Node(
        "get_settings()\nuse_cache=True (1x)",
        width=28,
        height=13.5,
        icon=PhosphorIcon.GEAR,
        icon_size=5.5,
        card_style=Styles.White,
    ),
    xy=(48.0, 9.0),
)

nonce_dep = dag.add(
    Node(
        "generate_nonce()\nuse_cache=False (2x)",
        width=29,
        height=13.5,
        icon=PhosphorIcon.ARROW_CLOCKWISE,
        icon_size=5.5,
        card_style=Styles.WarningNeutral,
    ),
    xy=(80.5, 9.0),
)

# Root fan-out (|dx|=23 < |dy|=25 -> clean bottom-to-top anchors)
dag.connect(endpoint, billing, routing="direct", padding=1.0)
dag.connect(endpoint, audit, routing="direct", padding=1.0)
dag.draw(xy=(7.0, 6.5))

# Sub-dependency edges across open canvas corridor y=[23.0, 41.0]
# 1. First-time executions from BillingService (solid dark strokes)
line((28.0, 41.0), (20.0, 23.0), arrow_head="->", style=Styles.DarkBold)
line((32.0, 41.0), (52.5, 23.0), arrow_head="->", style=Styles.DarkBold)

# 2. Per-request cache hits from AuditLogger (dashed primary strokes)
line((74.0, 41.0), (25.0, 23.0), arrow_head="->", style=Styles.PrimaryDashedBold)
line((78.0, 41.0), (57.5, 23.0), arrow_head="->", style=Styles.PrimaryDashedBold)

# 3. Uncached fresh invocations with use_cache=False (warning strokes)
line((36.0, 41.0), (85.0, 23.0), arrow_head="->", style=Styles.WarningBold)
line((82.0, 41.0), (90.0, 23.0), arrow_head="->", style=Styles.WarningBold)

# Right Zone: Per-Request Cache Mechanics Panel
cache_panel = Panel(
    "Per-Request Cache",
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.5),
    icon=phosphor.stack,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=9.5,
)
cache_panel.draw((110.0, 5.0), width=52.0, height=88.0, align="bottom_left")
c_xy, c_w, c_h = cache_panel.get_content_box(
    (110.0, 5.0),
    width=52.0,
    height=88.0,
    padding=(3.0, 3.0),
    align="bottom_left",
)

cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_style=Styles.PrimaryFlat,
    badge_text_style=Styles.WhiteBold.patch(text_size=10.0),
    spacing=2.5,
)
cards.add(
    "Callable + Scopes Key",
    "Keyed by (callable,\noauth_scopes, scope)",
    badge_text="1",
)
cards.add(
    "Solid -> Dashed Hit",
    "use_cache=True runs 1x;\nAuditLogger reuses same DB",
    badge_text="2",
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
)
cards.add(
    "use_cache=False",
    "Skips cache lookup; runs\ngenerate_nonce() 2x freshly",
    badge_text="3",
    badge_style=Styles.WarningNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
)
cards.add(
    "Threadpool Dispatch",
    "async def awaits directly;\ndef runs in AnyIO worker",
    badge_text="4",
    badge_style=Styles.Neutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
)
cards.draw(c_xy, width=c_w, height=c_h)

save()
```

## 1. 依存関係グラフ（DAG）の構築と解決の仕組み

FastAPI はルート登録時に一度だけエンドポイントのシグネチャ・`Annotated[..., Depends()]` マーカー・`Security()` 宣言を解析し、不変の依存関係グラフを構築します。リクエスト処理時のホットパスでは型リフレクションを行わず、事前構築済みの DAG を深さ優先で走査して各依存を解決します。

| 依存関係システムの機能 | 宣言パターン | リクエスト実行時の動作 |
| :--- | :--- | :--- |
| **サブ依存グラフ（DAG）** | `Annotated[T, Depends(fn)]` / `Depends()` | 末端のパラメータ（`Path`・`Query`・`Header`・`Cookie`・`Body`）および子依存を先に検証・解決してから親 Callable を呼び出します。 |
| **リクエスト単位キャッシュ** | `Depends(fn, use_cache=True)` *（既定）* | `(callable, oauth_scopes, scope)` をキーとしてリクエストごとに戻り値を保持し、ダイヤモンド依存の分岐間で結果を共有します。 |
| **グラフ全体の一括差し替え** | `app.dependency_overrides[orig] = mock` | ルーター・認可ガード・入れ子のクラス依存にまたがる任意の依存ノードをテストやステージング環境で一括置換します。 |
| **実行ディスパッチ** | `async def` / `def` / `yield` | `async def` はイベントループ上で直接 `await` し、同期 `def` はワーカースレッドプールで実行し、`yield` は自動解放を予約します。 |

### 1.1 リクエスト単位キャッシュ（`use_cache=True` と `use_cache=False`）

実践的なレイヤード設計では、エンドポイントが `BillingService` と `AuditLogger` の両方を注入し、その双方が `get_db_session` と `get_settings` に依存するような「ひし形（ダイヤモンド）依存」が頻出します。FastAPI はデフォルトで `Depends(..., use_cache=True)` を有効にしており、各 HTTP リクエストまたは WebSocket セッションの生存期間にわたってリクエスト単位の依存キャッシュ（Callable とスコープの組で管理）を保持します。

- **リクエスト内シングルトン共有（`use_cache=True`）**: 先に解決される `BillingService` が `get_db_session()` を 1 回だけ実行し、そのセッションを当該リクエスト用にキャッシュします。直後に同一リクエスト内で `AuditLogger` が `get_db_session` を要求すると、FastAPI はキャッシュから同一の Python オブジェクト（`billing.db is billing.audit.db`）を返し、複数サービス間のトランザクション整合性を保証します。
- **毎回新規実行（`use_cache=False`）**: `Depends(generate_trace_nonce, use_cache=False)` を指定するとキャッシュ参照をスキップし、注入箇所ごとに毎回新しく関数を呼び出します。
- **OAuth2 スコープを考慮したキャッシュ分離**: サブ依存が `SecurityScopes` を受け取る場合（詳細は [認証・OAuth2 スコープ認可・抽出器](security_and_auth.md) を参照）、累積された OAuth2 スコープもキャッシュキーへ組み込まれるため、要求スコープの異なる呼び出し同士が誤って共有されることはありません。

> [!IMPORTANT]
> FastAPI の依存関数や Pydantic モデルをネストしたローカルスコープ内で定義するモジュールでは、`from __future__ import annotations` の使用を避けてください。FastAPI はルート登録時に `Annotated[T, Depends(...)]` の型メタデータを評価するため、解決不能なローカルシンボルを参照する文字列化アノテーションは依存として認識されず、必須クエリパラメータ（`422 Unprocessable Content`）として扱われます。

### 1.2 多階層サブ依存・クラス依存・パラメータ化 Callable

FastAPI では通常の関数だけでなく、クラスのコンストラクタ（`__init__`）や呼び出し可能インスタンス（`__call__`）もそのまま依存ノードとして利用できます。

1. **クラス依存の省略記法（`Annotated[BillingService, Depends()]`）**: `Depends()` の引数を省略すると、FastAPI はパラメータの型注釈（`BillingService`）を検査し、サブ依存を再帰解決したうえで `__init__` を呼び出します。
2. **パラメータ化された Callable インスタンス（`RoleChecker(["admin", "finance"])`）**: 設定値を受け取るクラスに `async def __call__(self, ...)` を実装することで、クロージャやグローバル変数に頼らず再利用可能な認可ガードを量産できます。
3. **ルーター／アプリ単位のガード（`dependencies=[Depends(...)]`）**: `APIRouter(...)`・`@router.post(..., dependencies=[...])`・`FastAPI(dependencies=[...])` に `dependencies` を渡すと、各エンドポイントの関数シグネチャを汚さずに共通検証や認可ガードを実行できます（リクエスト単位キャッシュも同様に共有されます）。

```python
import secrets
from dataclasses import dataclass
from typing import Annotated

from fastapi import APIRouter, Depends, FastAPI, Header, HTTPException, status


@dataclass(frozen=True)
class AppSettings:
    tenant_header: str = "X-Tenant-ID"
    currency: str = "USD"


def get_settings() -> AppSettings:
    return AppSettings()


session_counter = 0


async def get_db_session() -> dict[str, int | str]:
    global session_counter
    session_counter += 1
    return {"session_id": session_counter, "driver": "asyncpg"}


def generate_trace_nonce() -> str:
    return secrets.token_hex(4)


class AuditLogger:
    def __init__(
        self,
        db: Annotated[dict[str, int | str], Depends(get_db_session)],
        settings: Annotated[AppSettings, Depends(get_settings)],
        nonce: Annotated[str, Depends(generate_trace_nonce, use_cache=False)],
    ) -> None:
        self.db = db
        self.settings = settings
        self.nonce = nonce


class BillingService:
    def __init__(
        self,
        db: Annotated[dict[str, int | str], Depends(get_db_session)],
        settings: Annotated[AppSettings, Depends(get_settings)],
        audit: Annotated[AuditLogger, Depends()],
        nonce: Annotated[str, Depends(generate_trace_nonce, use_cache=False)],
    ) -> None:
        self.db = db
        self.settings = settings
        self.audit = audit
        self.nonce = nonce


class RoleChecker:
    def __init__(self, allowed_roles: list[str]) -> None:
        self.allowed_roles = set(allowed_roles)

    async def __call__(self, x_role: Annotated[str, Header()] = "viewer") -> str:
        if x_role not in self.allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient role privileges",
            )
        return x_role


async def verify_tenant_header(
    settings: Annotated[AppSettings, Depends(get_settings)],
    x_tenant_id: Annotated[str | None, Header()] = None,
) -> str:
    if not x_tenant_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Missing {settings.tenant_header}",
        )
    return x_tenant_id


require_billing_admin = RoleChecker(["admin", "finance"])

billing_router = APIRouter(
    prefix="/billing",
    dependencies=[
        Depends(verify_tenant_header),
        Depends(require_billing_admin),
    ],
)


@billing_router.post("/invoices")
async def create_invoice(
    billing: Annotated[BillingService, Depends()],
) -> dict[str, object]:
    return {
        "db_session_id": billing.db["session_id"],
        "shared_same_db": billing.db is billing.audit.db,
        "distinct_nonces": billing.nonce != billing.audit.nonce,
        "currency": billing.settings.currency,
    }


app = FastAPI()
app.include_router(billing_router)
```

上の構成では `get_settings()` が 3 箇所（`verify_tenant_header`・`AuditLogger`・`BillingService`）で宣言されていますが、リクエスト単位キャッシュによってリクエストあたり 1 回しか実行されず、`billing.db is billing.audit.db` も常に `True` となります。また結合テスト時には `app.dependency_overrides[get_db_session] = override_db` を設定するだけで、DAG 全体の末端ノードを一括差し替えできます（[大規模 DI・Lifespan 管理・テスト戦略](../02_enterprise_architecture/di_lifespan_testing.md) および [実践テスト手法と本番 ASGI 運用](../06_observability_and_testing/testing_and_deployment.md) を参照）。

## 2. `yield` によるリソース管理とクリーンアップスコープ

`async def` または同期 `def` 内で `yield` を使うジェネレータ依存は、処理を **`yield` 前のセットアップフェーズ** と **`yield` 後のティアダウンフェーズ** に分割します。FastAPI `v0.162.2` では、入れ子になった 2 種類のクリーンアップスコープによって解放タイミングを正確に制御できます。

- **関数スコープのクリーンアップ（`Depends(..., scope="function")`）**: パスオペレーション関数が戻り値を返した **直後**、すなわちレスポンスバイト列のネットワーク送信や `StreamingResponse` のイテレーションが開始される **前** にクリーンアップを実行します。
- **リクエストスコープのクリーンアップ（`Depends(..., scope="request")`、デフォルト）**: パスオペレーションとレスポンス送信の双方を外側から包み、HTTP レスポンス送信・ストリーミングチャンク送出・バックグラウンドタスクが **すべて完了した後** にクリーンアップを実行します。

```drawlib align=center code=hide file=yield_scope_exit_stacks.png caption="FastAPI v0.162.2 のジェネレータ依存クリーンアップライフサイクル：Depends(scope='function') と Depends(scope='request')"
from drawlib.canvas import save, setup
from drawlib.diagrams.sequence import Participant, ParticipantGroup, PhosphorIcon, SequenceDiagram
from drawlib.styles import Style, Styles

setup(width=166, height=134, dpi=150)

seq = SequenceDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.5),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
    col_width=37.0,
    step_y=6.8,
    margin=5.0,
)

client = seq.add(
    Participant(
        "ASGI Client",
        width=23,
        height=13.5,
        icon=PhosphorIcon.GLOBE,
        icon_size=5.8,
    )
)

runtime = seq.add(
    ParticipantGroup(
        title="FastAPI Generator Dependency Scopes",
        padding=4.5,
        style=Styles.Neutral,
        text_style=Style(text_size=11.0),
    )
)

req_stack = runtime.add(
    Participant(
        'scope="request"\n(After Streaming)',
        width=26,
        height=14,
        icon=PhosphorIcon.STACK,
        icon_size=5.8,
        card_style=Styles.SecondaryNeutral,
    )
)

fn_stack = runtime.add(
    Participant(
        'scope="function"\n(Before Response)',
        width=26,
        height=14,
        icon=PhosphorIcon.DATABASE,
        icon_size=5.8,
        card_style=Styles.PrimaryNeutral,
    )
)

endpoint = runtime.add(
    Participant(
        "Endpoint &\nStreaming Body",
        width=26,
        height=14,
        icon=PhosphorIcon.FILE_CODE,
        icon_size=5.8,
        style=Styles.White,
        card_style=Styles.PrimaryFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.5),
    )
)

client.request(req_stack, "1. Enter request-scope setup")
req_stack.request(fn_stack, "2. yield conn -> enter function-scope")
fn_stack.request(endpoint, "3. yield tx -> await endpoint()")

with seq.alt("200 OK") as alt_blk:
    alt_blk.style = Styles.MutedDashed.patch(shape_line_width=1.2)
    alt_blk.text_style = Style(text_size=10.0, halign="left")
    endpoint.reply(fn_stack, "4. Return StreamingResponse")
    seq.note(
        "Function scope exits BEFORE stream:\ncommit tx & release DB lock early!",
        over=[fn_stack, endpoint],
        style=Styles.PrimaryNeutral.patch(text_size=10.0),
    )
    endpoint.reply(
        client,
        "5. Stream CSV chunks to client",
        style=Styles.SuccessBold,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    )
    endpoint.reply(req_stack, "6. Stream complete -> request-scope exit")

with seq.else_("HTTPException") as else_blk:
    else_blk.style = Styles.MutedDashed.patch(shape_line_width=1.2)
    else_blk.text_style = Style(text_size=10.0, halign="left")
    endpoint.reply(
        fn_stack,
        "4b. Raise HTTPException into yield frame",
        style=Styles.DangerBold,
        text_style=Styles.DangerBold.patch(text_size=10.0),
    )
    fn_stack.reply(
        req_stack,
        "5b. try...finally: rollback & re-raise (LIFO)",
        style=Styles.DangerBold,
        text_style=Styles.DangerBold.patch(text_size=10.0),
    )
    req_stack.reply(
        client,
        "6b. Release conn -> send HTTP error JSON",
        style=Styles.DangerBold,
        text_style=Styles.DangerBold.patch(text_size=10.0),
    )

seq.draw(xy=(83.0, 67.0), align="center")
save()
```

### 2.1 `scope="function"` と `scope="request"` の使い分け

`scope` を省略した場合、ストリーミング応答のジェネレータ内からも安全にリソースを参照できるようデフォルトで `scope="request"` が選択されます。低速なクライアント回線下で DB コネクションプールの枯渇を防ぐには、用途に応じて `scope="function"` と `scope="request"` を明示的に使い分けます。

| 比較項目 | `Depends(dep, scope="function")` | `Depends(dep, scope="request")` *（`yield` のデフォルト）* |
| :--- | :--- | :--- |
| **クリーンアップ段階** | 関数スコープ（エンドポイント関数が返った直後） | リクエストスコープ（応答送信・ストリーミング完了後） |
| **解放タイミング** | レスポンスバイト列およびストリーミング送信の **開始前** | レスポンス送信・ストリーミング・背景タスクの **完了後** |
| **主な適用場面** | 書き込みトランザクション、行ロック、ハンドラ固有の RPC スパン | `StreamingResponse` や SSE 内で読み取るカーソル、リクエスト全体の監査文脈 |
| **サブ依存の制約** | `"request"` と `"function"` の両方に依存可能 | より寿命の短い `"function"` スコープ依存を子に持つことは不可 |

### 2.2 必須の `try...finally` クリーンアップと例外再送出

あなたの `yield` 依存が開始された **後** に、兄弟となる別の依存関数やエンドポイント本体が例外（`HTTPException` やドメイン例外など）を送出すると、FastAPI は待機中の `yield` 行へ逆順（LIFO）でその例外を伝播させます。本番コードでは次の 2 原則が絶対条件となります。

1. **必ず `try ... finally:` で `yield` を囲む**: `finally:` を使わず `yield` の後ろにそのまま後処理を記述すると、未捕捉例外でリクエストが中断された際にクリーンアップがスキップされ、DB セッションやセマフォがリークします。
2. **`yield` 後に例外を握りつぶさない**: ロールバック処理のために `except Exception:` で捕捉する場合（`except Exception: await tx.rollback(); raise`）も、**必ず例外を再送出（`raise`）** してください。`yield` 後に例外を握りつぶして再送出しないと、FastAPI の例外ハンドラが動作せずレスポンス未生成となり、`500 Internal Server Error` の原因となります。

```python
from collections.abc import AsyncIterator
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.responses import StreamingResponse

events: list[str] = []
app = FastAPI()


async def get_request_connection() -> AsyncIterator[str]:
    events.append("req_conn:enter")
    try:
        yield "conn_pool_1"
    finally:
        events.append("req_conn:exit")


async def get_db_transaction(
    conn: Annotated[str, Depends(get_request_connection, scope="request")],
) -> AsyncIterator[str]:
    events.append(f"fn_tx:enter({conn})")
    try:
        yield "tx_active"
        events.append("fn_tx:commit")
    except Exception:
        events.append("fn_tx:rollback")
        raise
    finally:
        events.append("fn_tx:exit")


@app.get("/reports/export")
async def export_report(
    tx: Annotated[str, Depends(get_db_transaction, scope="function")],
    fail: bool = False,
) -> StreamingResponse:
    events.append(f"endpoint:body({tx})")
    if fail:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Report snapshot locked",
        )

    async def stream_rows() -> AsyncIterator[bytes]:
        events.append("stream:chunk_1")
        yield b"id,amount\n1,250\n"

    return StreamingResponse(stream_rows(), media_type="text/csv")
```

`GET /reports/export` を実行すると、`events` には `["req_conn:enter", "fn_tx:enter(conn_pool_1)", "endpoint:body(tx_active)", "fn_tx:commit", "fn_tx:exit", "stream:chunk_1", "req_conn:exit"]` の順序が記録されます。`"function"` スコープのトランザクションは `stream_rows()` が最初のチャンクを送出する **前** にコミット・解放され、一方で `"request"` スコープのコネクションはストリーミング完了後まで維持されます。また `?fail=true` で `409 Conflict` が発生した場合も、`except` での再送出と `finally:` によって `["req_conn:enter", "fn_tx:enter(conn_pool_1)", "endpoint:body(tx_active)", "fn_tx:rollback", "fn_tx:exit", "req_conn:exit"]` と LIFO 順で確実に解放されます。

続いて次節 [認証・OAuth2 スコープ認可・抽出器](security_and_auth.md) では、`fastapi.security` がこの依存関係グラフの上に資格情報抽出・階層的 `SecurityScopes`・OpenAPI 3.1 `securitySchemes` をどのように統合しているかを解説し、ストリーミングとの組み合わせについては [ネイティブ SSE・JSONL・WebSocket](../05_async_and_realtime/sse_websockets_streaming.md) で掘り下げます。
