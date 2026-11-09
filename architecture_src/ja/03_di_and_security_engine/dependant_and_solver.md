# Dependant DAG コンパイルと `solve_dependencies()`

FastAPI の依存性注入（DI）エンジンは、シグネチャのリフレクション処理とリクエスト実行処理を **ルート登録時のコンパイルフェーズ**（`fastapi/dependencies/utils.py` の `get_dependant()` と `analyze_param()`）と **リクエスト単位の再帰解決フェーズ**（`fastapi/dependencies/models.py` の `Dependant` と `solve_dependencies()`）の 2 段階に分離しています。すべてのエンドポイントとサブ依存関係は起動時に一度だけ省メモリな有向非巡回グラフ（`Dependant` DAG）へとコンパイルされるため、実行時には事前分類済みの `ModelField` バケットの走査、3 要素タプルによるキャッシュ再利用、ツリー全体のバリデーションエラー集約、そして 2 階層の `AsyncExitStack` によるジェネレータ終了制御を決定論的に高速実行できます。

```drawlib align=center code=hide file=dependant_compilation_dag.png caption="Python 関数シグネチャから slots=True の Dependant DAG および 3 要素タプル DependencyCacheKey へのコンパイル時変換構造。"
from drawlib.canvas import setup
from drawlib.diagrams.architecture import ArchitectureDiagram, Node, NodeGroup, PhosphorIcon
from drawlib.styles import Colors, Styles

setup(width=176, height=112)

d = ArchitectureDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.5),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
    title="Compile-Time Dependant DAG & Cache Key Synthesis",
)

sig = d.add(
    Node(
        "Endpoint Signature\nget_typed_signature()",
        width=32,
        height=18,
        icon=PhosphorIcon.CODE,
        icon_size=7.0,
        card_style=Styles.PrimaryFlat,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.5),
    ),
    xy=(18.0, 68.0),
)
analyzer = d.add(
    Node(
        "analyze_param()\nAnnotated & Defaults",
        width=32,
        height=18,
        icon=PhosphorIcon.FUNNEL,
        icon_size=7.0,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(18.0, 32.0),
)

root_grp = d.add(
    NodeGroup(
        title="Root Dependant (slots=True)",
        padding=6.0,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left"),
    ),
    xy=(48.0, 4.0),
)
buckets = root_grp.add(
    Node(
        "ModelField Buckets\npath / query / body",
        width=34,
        height=16,
        icon=PhosphorIcon.TABLE,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(23.0, 68.0),
)
special = root_grp.add(
    Node(
        "Framework Slots\nRequest / Tasks / Scopes",
        width=34,
        height=16,
        icon=PhosphorIcon.PLUGS_CONNECTED,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(23.0, 41.0),
)
sub_list = root_grp.add(
    Node(
        "dependencies: list\nChild Dependant Nodes",
        width=34,
        height=16,
        icon=PhosphorIcon.GIT_BRANCH,
        icon_size=6.5,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(23.0, 14.0),
)

sub_grp = d.add(
    NodeGroup(
        title="Sub-Dependants & Cache",
        padding=6.0,
        style=Styles.SecondaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left"),
    ),
    xy=(112.0, 4.0),
)
auth_dep = sub_grp.add(
    Node(
        "Security Dependant\nown + parent scopes",
        width=36,
        height=16,
        icon=PhosphorIcon.SHIELD_CHECK,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(24.0, 68.0),
)
db_dep = sub_grp.add(
    Node(
        "Generator Dependant\ncomputed_scope='request'",
        width=36,
        height=16,
        icon=PhosphorIcon.DATABASE,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(24.0, 41.0),
)
cache_node = sub_grp.add(
    Node(
        "DependencyCacheKey\n(call, scopes, scope)",
        width=36,
        height=16,
        icon=PhosphorIcon.KEY,
        icon_size=6.5,
        card_style=Styles.AccentFlat,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.5),
    ),
    xy=(24.0, 14.0),
)

d.connect(sig, analyzer, label="inspect", padding=1.5)

j_l_mid = d.junction(xy=(40.0, 32.0))
j_l_top = d.junction(xy=(40.0, 72.0))
j_l_slot = d.junction(xy=(40.0, 45.0))
j_l_bot = d.junction(xy=(40.0, 18.0))
d.connect(analyzer, j_l_mid, arrow="-", padding=(1.5, 0.0))
d.connect(j_l_bot, j_l_top, arrow="-")
j_l_top.connect(buckets, padding=(0.0, 1.5))
j_l_slot.connect(special, padding=(0.0, 1.5))
j_l_bot.connect(sub_list, padding=(0.0, 1.5))

j_r_bot = d.junction(xy=(102.0, 18.0))
j_r_mid = d.junction(xy=(102.0, 45.0))
j_r_top = d.junction(xy=(102.0, 72.0))
d.connect(sub_list, j_r_bot, arrow="-", padding=(1.5, 0.0))
d.connect(j_r_bot, j_r_top, arrow="-")
j_r_top.connect(auth_dep, padding=(0.0, 1.5))
j_r_mid.connect(db_dep, padding=(0.0, 1.5))

d.connect(auth_dep, db_dep, label="Depends", padding=1.2)
d.connect(db_dep, cache_node, label="_get_cache_key()", padding=1.2)

d.draw(xy=(6.0, 5.0))
```

## 1. `Dependant` データクラスとフィールド構成

`fastapi/dependencies/models.py` の `Dependant` は `@dataclass(slots=True)` として定義されています。インスタンスごとの `__dict__` を排除することで、数百のルートや多段のルータ依存チェーンを持つ大規模アプリケーションでもメモリフットプリントを最小限に抑えます。各 `Dependant` ノードは、呼び出し対象の入力を 5 つの `ModelField` バケット、子 `dependencies` リスト、6 つのフレームワーク注入スロット、および OAuth2 スコープ属性に分割して保持します。

| フィールド分類 | `Dependant` の属性（`v0.162.2`） | `solve_dependencies()` における実行時の役割 |
| :--- | :--- | :--- |
| **検証対象リクエスト引数** | `path_params`, `query_params`, `header_params`, `cookie_params` (`list[ModelField]`) | `request_params_to_args()` により `request.path_params`, `query_params`, `headers`, `cookies` から抽出・検証。 |
| **検証対象ボディ引数** | `body_params` (`list[ModelField]`) | `request_body_to_args()` により解析済み JSON または `FormData`（`Body`, `Form`, `File`）を検証。 |
| **サブ依存関係エッジ** | `dependencies` (`list[Dependant]`) | `self.call` 実行前に深さ優先（DFS）で解決。ルートデコレータの `dependencies=[Depends(...)]` も先頭に挿入される。 |
| **コネクション注入スロット** | `request_param_name`, `websocket_param_name`, `http_connection_param_name` (`str \| None`) | `Request`（HTTP 専用）、`WebSocket`（WS 専用）、または両者を統合する Starlette の `HTTPConnection` を直接注入。 |
| **フレームワーク文脈スロット** | `response_param_name`, `background_tasks_param_name`, `security_scopes_param_name` (`str \| None`) | ヘッダ・ステータス集約用の共有 `Response`、`BackgroundTasks` キュー、または `SecurityScopes` を注入。 |
| **呼び出し・スコープメタ情報** | `name`, `call`, `use_cache`, `path`, `scope`, `own_oauth_scopes`, `parent_oauth_scopes` | 引数バインド名、キャッシュ可否、ジェネレータ終了スタックの寿命境界、および上位からの OAuth2 スコープ継承を制御。 |

### 1.1 `computed_scope` と 3 要素タプル `DependencyCacheKey`

`Dependant` が `slots=True` を採用しているため、FastAPI は寿命スコープとキャッシュキーを `fastapi/dependencies/models.py` 内の純粋ヘルパー関数で算出します。呼び出し可能オブジェクトの種別判定は、`id(call)` でハッシュ化するラッパー `_CallIdentity` と `@lru_cache(maxsize=4096)` によって、`__hash__` を実装しない呼び出し可能インスタンスに対しても $O(1)$ で動作します。

- **`_get_computed_scope(*, dependant: Dependant) -> str | None`**: `dependant.scope`（`"function"` または `"request"`）が明示指定されていればその値を返し、未指定の場合は `_is_gen_callable(dependant.call)` と `_is_async_gen_callable(dependant.call)`（`functools.partial` や `__wrapped__` チェーン、および `__call__` メソッドを再帰アンラップして検査）に基づき、ジェネレータ依存関係ならデフォルトで `"request"`、通常の関数・コルーチンなら `None` を返します。
- **`_get_cache_key(*, dependant: Dependant, uses_scopes_cache: _UsesScopesCache | None = None) -> DependencyCacheKey`**: `(dependant.call, scopes_for_cache, _get_computed_scope(dependant=dependant) or "")` という **3 要素タプル**（`fastapi/types.py` の `DependencyCacheKey = tuple[Callable[..., Any] | None, tuple[str, ...], str]`）を生成します。
- **`_uses_scopes()` によるスコープ枝刈り最適化**: `scopes_for_cache` が `tuple(sorted(set(_get_oauth_scopes(dependant=dependant))))` になるのは、`_uses_scopes()` が `True`（`own_oauth_scopes` の宣言、`SecurityScopes` の注入、`SecurityBase` インスタンスの呼び出し、または子孫ノードでのスコープ利用のいずれかに該当）の場合 **のみ** です。DB セッション生成ジェネレータ（`get_db`）のような非セキュリティ依存関係では `_uses_scopes()` が `False` となり `scopes_for_cache` が `()` に畳み込まれるため、エンドポイント直下と `Security(..., scopes=["projects:read"])` 配下の両方から呼ばれても同一リクエスト内で確実に 1 つの DB セッションが共有されます。

## 2. コンパイル時の DAG 構築（`get_dependant` と `analyze_param`）

`APIRoute` や `APIWebSocketRoute` の初期化時、`_build_dependant_with_parameterless_dependencies()` は `get_dependant(path=path, call=call, scope="function")` を呼び出し、デコレータ引数の `dependencies=[Depends(...)]` を宣言順が保たれるよう逆順で `get_parameterless_sub_dependant()` により先頭へ挿入します。`get_dependant()` 内部は以下の手順で進行します。

1. **型解決済みシグネチャ抽出（`get_typed_signature`）**: `inspect.signature(call, eval_str=True)` を実行し（`TYPE_CHECKING` 限定の型により `NameError` が発生した場合、Python 3.14 以降では PEP 649 の `annotationlib.Format.FORWARDREF` へフォールバック）、アンラップした関数の `__globals__` を用いて文字列 `ForwardRef` を `evaluate_forwardref()` で実体型へ解決します。
2. **`Annotated` とデフォルト値の展開（`analyze_param`）**: PEP 695 の `type` エイリアス（`is_typealiastype`）を展開した上で `Annotated[T, ...]` のメタデータを走査し、末尾の FastAPI マーカー（`Param`, `Body`, `Depends`）を採用します。`Annotated` 内に `FieldInfo` がある場合、再利用可能な型エイリアスを破壊しないよう `copy_field_info()` で複製してから `param.default`（または `RequiredParam`）を代入します。`Annotated` 内と `=` の両方に FastAPI マーカーを重ねて指定した場合は起動時に `AssertionError` で拒否されます。
3. **クラス依存関係の省略記法解決**: `Depends()` のように `dependency=None` で宣言された場合（例: `Annotated[CommonQueryParams, Depends()]`）、frozen データクラスである `Depends` を `dataclasses.replace(depends, dependency=type_annotation)` で複製し、型アノテーション自身を呼び出し対象に設定します。
4. **暗黙的なパラメータ分類規則**: `Depends` でもフレームワーク注入型（`Request`, `WebSocket`, `HTTPConnection`, `Response`, `BackgroundTasks`, `SecurityScopes`）でもなく、明示的な `Query`/`Path`/`Header`/`Cookie`/`Body` も付与されていない引数は、次の優先順で自動分類されます。
   - `param_name in path_param_names`（パステンプレートの `{...}` から抽出） $\rightarrow$ `params.Path`（スカラー型であることを検証）。
   - `UploadFile` またはそのシーケンス型 $\rightarrow$ `params.File`。
   - 非スカラー型（`not field_annotation_is_scalar()`：`BaseModel`, `Mapping`, `bytes` 以外の `Sequence`, `dataclass`, カスタム Pydantic スキーマ型） $\rightarrow$ `params.Body`。
   - 上記以外のすべてのスカラー型 $\rightarrow$ `params.Query`。
5. **起動時のスコープ逆転ガード（`DependencyScopeError`）**: 子 `Depends` へ再帰する直前に、親ジェネレータの `_get_computed_scope(dependant)` が `"request"` であるにもかかわらず子が `scope="function"` を要求していないかを検査します。レスポンス配信前に閉じられる `"function"` スコープのリソースに、配信完了まで生存する `"request"` スコープの親ジェネレータが依存する寿命逆転バグを起動時に `DependencyScopeError` として即座に検出します。

## 3. `solve_dependencies()` による実行時解決

HTTP リクエスト（`get_request_handler`）または WebSocket ハンドシェイク（`get_websocket_app`）が到着するたび、`solve_dependencies()` は `dependant` ツリーを深さ優先・帰りがけ順（post-order DFS）で再帰走査します。

- **動的な依存関係オーバーライド**: `dependant.dependencies` 内の各 `sub_dependant` に対し、`dependency_overrides_provider.dependency_overrides`（`app.dependency_overrides`）に差し替え関数が登録されていれば、`_get_oauth_scopes(sub_dependant)` と `sub_dependant.scope` を引き継いだ `use_sub_dependant = get_dependant(...)` を動的に構築して解決しつつ、`dependency_cache` のキーには元の `sub_dependant` のキーを維持します。
- **呼び出しディスパッチとリクエスト内メモ化**: 子ノード自身の依存解決が完了した後、`sub_dependant.use_cache` が `True` かつ `sub_dependant_cache_key` が `dependency_cache` に存在すればキャッシュ値を即座に返します。未キャッシュの場合は呼び出し種別に応じて実行します。
  - **ジェネレータ（`yield`）**: `_solve_generator()` へ委譲し、非同期ジェネレータは `asynccontextmanager(call)(**sub_values)`、同期ジェネレータは `contextmanager_in_threadpool(contextmanager(call)(**sub_values))` でラップして対象の `AsyncExitStack` へ登録します。
  - **非同期コルーチン（`async def`）**: イベントループ上で直接 `await call(**solved_result.values)` を実行します。
  - **同期関数・クラス（`def` / `class`）**: ブロッキング処理でイベントループを止めないよう Starlette の `await run_in_threadpool(call, **solved_result.values)` でワーカースレッドへオフロードします。
- **ツリー全体のエラー集約（Fail-Fast しない設計）**: 子 `Dependant` で検証エラー（`solved_result.errors`）が発生した場合、`solve_dependencies()` はその子関数の呼び出しをスキップしてエラーを追記し、**残りの兄弟依存関係および自身の `path_params`, `query_params`, `header_params`, `cookie_params`, `body_params` の検証を最後まで続行** します。ツリー全体の走査が完了した後に初めて `RequestValidationError(errors)`（HTTP 422）または `WebSocketRequestValidationError` が送出されるため、クライアントは 1 回のレスポンスですべての不正箇所を一括把握できます。

### 3.1 二重 `AsyncExitStack` によるライフタイム制御アーキテクチャ

FastAPI `v0.162.2` は、`fastapi/routing.py` の `request_response()` 内で生成される **入れ子構造の 2 つの `AsyncExitStack`** によって `yield` 依存関係のクリーンアップ時期を制御します（なおマルチパート `FormData` の一時ファイルをミドルウェア完了後に閉じる用途には、`fastapi/middleware/asyncexitstack.py` の `AsyncExitStackMiddleware` が設ける最外殻の `fastapi_middleware_astack` が別途使われます）。

1. **`fastapi_function_astack`（`scope="function"`）**: `response = await f(request)` の直前で開始し、`f(request)` がシリアライズ済みの `Response` オブジェクトを返した **直後**、すなわち `await response(scope, receive, send)` がソケットへ送信を始める **前** に `__aexit__` を実行します。`Depends(dep, scope="function")` を指定したジェネレータでは、エンドポイント実行と `serialize_response()` が終わった段階（レスポンスヘッダ送出前）で確実に `yield` 後の後処理が走ります。
2. **`fastapi_inner_astack`（`scope="request"`、`yield` 依存関係の既定値）**: `f(request)` と `await response(scope, receive, send)` の双方を包んでおり、**ASGI レスポンス本体のストリーミング配信および `BackgroundTasks` がすべて完了した後** に `__aexit__` を実行します。もしエンドポイント内で例外が発生した際に `yield` 依存関係が裸の `except:` 等で例外を握り潰して再送出しなかった場合、`response_awaited` フラグが `False` のまま残るため、`request_response()` が `FastAPIError("Response not awaited...")` を送出して不具合を即座に検知します。

```drawlib align=center code=hide file=dual_exitstack_lifetimes.png caption="request_response() における二重 AsyncExitStack の寿命境界：function スコープは ASGI 配信前に閉じ、request スコープはストリーミング完了後に閉じる。"
from drawlib.canvas import setup
from drawlib.diagrams.sequence import Participant, PhosphorIcon, SequenceDiagram
from drawlib.styles import Colors, Styles

setup(width=176, height=128)

d = SequenceDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.5),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
    title="Dual AsyncExitStack Lifetimes Across Request & Streaming",
    autonumber=True,
    col_width=40.0,
    step_y=7.2,
)

asgi = d.add(
    Participant(
        "request_response\nASGI Wrapper",
        width=30,
        height=14,
        icon=PhosphorIcon.GLOBE,
        icon_size=6.5,
        card_style=Styles.Neutral,
    )
)
stacks = d.add(
    Participant(
        "Dual ExitStacks\n(request.scope)",
        width=30,
        height=14,
        icon=PhosphorIcon.ARCHIVE,
        icon_size=6.5,
        card_style=Styles.PrimaryNeutral,
    )
)
solver = d.add(
    Participant(
        "solve_dependencies\n& Endpoint",
        width=30,
        height=14,
        icon=PhosphorIcon.GEAR,
        icon_size=6.5,
        card_style=Styles.PrimaryFlat,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.5),
    )
)
stream = d.add(
    Participant(
        "ASGI Response\n& Stream Body",
        width=30,
        height=14,
        icon=PhosphorIcon.BROADCAST,
        icon_size=6.5,
        card_style=Styles.SecondaryNeutral,
    )
)

asgi.request(stacks, "Enter fastapi_inner_astack (request)")
asgi.request(stacks, "Enter fastapi_function_astack (function)")
stacks.request(solver, "solve_dependencies() DFS walk")
solver.request(stacks, "enter_async_context(yield_cm) by scope")
solver.reply(asgi, "Return serialized Response object")

with d.opt("") as blk1:
    blk1.style = Styles.Neutral.patch(line_style="dashed")
    stacks.reply(
        asgi,
        "Pre-Send: Exit fastapi_function_astack",
        style=Styles.AccentBold,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    )

asgi.request(stream, "await response(scope, receive, send)")
stream.reply(asgi, "Chunks streamed + BackgroundTasks done")

with d.opt("") as blk2:
    blk2.style = Styles.PrimaryNeutral.patch(line_style="dashed")
    stacks.reply(
        asgi,
        "Post-Stream: Exit fastapi_inner_astack",
        style=Styles.PrimaryBold,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    )

d.draw(xy=(6.0, 4.0))
```

## 4. コンパイル済み `Dependant` ツリーとキャッシュキーの検証

Python コードから `get_dependant()`、`_get_computed_scope()`、`_get_cache_key()` を直接呼び出すことで、パラメータの自動分類や共有ジェネレータにおける OAuth2 スコープ枝刈り挙動を確認できます。

```python
from typing import Annotated, AsyncIterator

from fastapi import Depends, Request, Security
from fastapi.dependencies.models import _get_cache_key, _get_computed_scope
from fastapi.dependencies.utils import get_dependant
from fastapi.security import SecurityScopes


async def get_db() -> AsyncIterator[str]:
    yield "db_conn"


async def require_actor(
    scopes: SecurityScopes,
    db: Annotated[str, Depends(get_db)],
) -> dict[str, object]:
    return {"db": db, "scopes": scopes.scopes}


async def list_projects(
    org_id: int,
    request: Request,
    db: Annotated[str, Depends(get_db)],
    actor: Annotated[
        dict[str, object],
        Security(require_actor, scopes=["projects:read"]),
    ],
    limit: int = 20,
) -> dict[str, object]:
    return {"org_id": org_id, "limit": limit, "db": db, "actor": actor}


root = get_dependant(
    path="/orgs/{org_id}/projects",
    call=list_projects,
    scope="function",
)

assert [f.name for f in root.path_params] == ["org_id"]
assert [f.name for f in root.query_params] == ["limit"]
assert root.request_param_name == "request"

db_direct, actor_dep = root.dependencies
db_nested = actor_dep.dependencies[0]

assert _get_computed_scope(dependant=db_direct) == "request"
# Non-security sub-dependency collapses scopes_for_cache to () in both branches:
assert _get_cache_key(dependant=db_direct) == (get_db, (), "request")
assert _get_cache_key(dependant=db_nested) == (get_db, (), "request")
assert _get_cache_key(dependant=actor_dep) == (
    require_actor,
    ("projects:read",),
    "",
)
```

続いて、認証スキームが `Dependant` と OpenAPI スキーマ生成の双方に統合される仕組みは [SecurityBase 階層と HTTPConnection](security_internals.md) を、抽出された各引数を `ModelField` が検証・変換する内部実装は [_compat/v2.py・ModelField・直列化](../04_pydantic_bridge/compat_and_serialization.md) を参照してください。
