# レスポンス直列化・ステータスコード・OpenAPI 3.1

FastAPI は自動レスポンス検証およびフィルタリングによって出力契約を厳格に強制し、機密フィールドの除去から UTF-8 JSON バイト列への変換までを Pydantic v2 の単一 Rust パスで実行するとともに、入出力分割型の JSON Schema 2020-12 を備えた OpenAPI 3.1.0 仕様を遅延合成します。

```drawlib align=center code=hide file=response_serialization_pipeline.png caption="出力レスポンスの検証・機密フィールド除去・Rust TypeAdapter 高速直列化パイプライン"
from drawlib.canvas import save, setup
from drawlib.icons import code, phosphor
from drawlib.lines import line, lines
from drawlib.shapes import rectangle
from drawlib.smartarts import ChevronProcess
from drawlib.styles import Styles
from drawlib.text import text

setup(width=168, height=92, dpi=150)

# Title Banner
code.fastapi((11, 86.5), width=5.2, style=Styles.Primary)
text(
    (16.5, 86.5),
    "Outbound Response Pipeline: Validation, Filtering & TypeAdapter Fast Path",
    style=Styles.DarkBold.patch(text_size=12.5, halign="left"),
)

# Top 5-Stage Macro Pipeline
macro = ChevronProcess(
    style=Styles.Neutral,
    text_style=Styles.DarkBold.patch(text_size=10.3),
    description_style=Styles.Dark.patch(text_size=10.0),
    corner_angle=60.0,
    spacing=1.4,
    flat_left_end=True,
)
macro.add("1. Endpoint Return", description="ORM / Model / dict")
macro.add("2. Route Contract", description="Model vs Response", style=Styles.PrimaryNeutral)
macro.add(
    "3. Validate & Filter",
    description="Drop secret fields",
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.3),
    description_style=Styles.White.patch(text_size=10.0),
)
macro.add("4. Rust dump_json", description="1-pass UTF-8 bytes", style=Styles.SecondaryNeutral)
macro.add("5. Header Merge", description="Injected Response")
macro.draw((6, 68), width=156, height=13)

# Bottom Detailed 3-Track Execution Architecture
# Left Source Card (x=6..36, y=8..60)
rectangle((21, 34), width=30, height=52, style=Styles.PrimaryNeutral.patch(shape_r=2.0))
phosphor.code((21, 52.5), width=6.0, style=Styles.PrimaryBold)
text((21, 44.5), "Endpoint Result", style=Styles.DarkBold.patch(text_size=11.0))
text(
    (21, 26.5),
    "• async def: inline\n• def: threadpool\n• Captures mutated\n  response.headers\n• Attaches injected\n  BackgroundTasks",
    style=Styles.Dark.patch(text_size=10.0),
)

# Track A (Top, y=53): Rust Fast-Path Serialization
# Track B (Middle, y=34): jsonable_encoder Fallback
# Track C (Bottom, y=15): Direct Response Subclass Bypass
tracks = [
    (
        53,
        ("response_model / -> T", "Validate & filter fields", Styles.White, False),
        ("TypeAdapter.dump_json()", "exclude_unset / by_alias", Styles.PrimaryFlat, True),
        ("Response(bytes)", "Merges response.headers", Styles.SecondaryNeutral, False),
    ),
    (
        34,
        ("response_model=None", "Unconstrained return", Styles.Neutral, False),
        ("jsonable_encoder()", "Python dict conversion", Styles.White, False),
        ("JSONResponse", "Merges response.headers", Styles.SecondaryNeutral, False),
    ),
    (
        15,
        ("Return Response", "304 / File / Custom", Styles.Neutral, False),
        ("Bypass Serialization", "Skips response_model", Styles.PrimaryNeutral, False),
        ("Direct ASGI Send", "Keeps BackgroundTasks", Styles.White, False),
    ),
]

# Orthogonal trunk fan-out from Left Source Card right edge (x=36) -> trunk (x=42) -> Col 1 left edge (x=48)
line((36, 34), (42, 34), style=Styles.DarkBold)
lines([(42, 15), (42, 53)], style=Styles.DarkBold)

for ty, s1, s2, s3 in tracks:
    line((42, ty), (48, ty), arrow_head="->", style=Styles.PrimaryBold if ty == 53 else Styles.DarkBold)

    # Col 1: cx=65, w=34 -> x=48..82
    rectangle((65, ty), width=34, height=13.5, style=s1[2].patch(shape_r=1.8))
    text((65, ty + 2.4), s1[0], style=Styles.DarkBold.patch(text_size=10.3))
    text((65, ty - 2.6), s1[1], style=Styles.Dark.patch(text_size=10.0))

    # Gap 82 -> 89 (7.0 units)
    line((82, ty), (89, ty), arrow_head="->", style=Styles.PrimaryBold if ty == 53 else Styles.DarkBold)

    # Col 2: cx=106, w=34 -> x=89..123
    rectangle((106, ty), width=34, height=13.5, style=s2[2].patch(shape_r=1.8))
    c2_h = Styles.WhiteBold if s2[3] else Styles.DarkBold
    c2_b = Styles.White if s2[3] else Styles.Dark
    text((106, ty + 2.4), s2[0], style=c2_h.patch(text_size=10.3))
    text((106, ty - 2.6), s2[1], style=c2_b.patch(text_size=10.0))

    # Gap 123 -> 130 (7.0 units)
    line((123, ty), (130, ty), arrow_head="->", style=Styles.PrimaryBold if ty == 53 else Styles.DarkBold)

    # Col 3: cx=146, w=32 -> x=130..162
    rectangle((146, ty), width=32, height=13.5, style=s3[2].patch(shape_r=1.8))
    text((146, ty + 2.4), s3[0], style=Styles.DarkBold.patch(text_size=10.3))
    text((146, ty - 2.6), s3[1], style=Styles.Dark.patch(text_size=10.0))

save()
```

内部の永続化モデルと外部向け DTO を明確に分離することで、資格情報の誤漏洩を構造的に防ぎながら、Pydantic のコンパイル済み Rust コアによる高速なシリアライズを実現できます。

## 1. レスポンス検証・機密フィールド除去・高速直列化

パスオペレーション登録時、FastAPI は明確な優先順位規則に従って出力レスポンス契約を決定します。

| エンドポイントの宣言パターン | 適用されるレスポンス契約 | 実行時の直列化パス |
| :--- | :--- | :--- |
| `@app.get(..., response_model=PublicDTO)` | `PublicDTO`（戻り値型注釈より優先） | 検証・機密属性除去後に Rust `TypeAdapter.dump_json()` で UTF-8 バイト列を出力 |
| `async def ep(...) -> PublicDTO:`（`response_model` 省略） | `PublicDTO`（戻り値型注釈から自動採用） | 戻り値の型注釈をそのまま出力検証および OpenAPI スキーマ契約として適用 |
| `@app.get(..., response_model=None)` または `-> Response` | 無効化 | レスポンス検証を抑止し、`Response \| dict` などの Union 返却を許容（辞書等は `jsonable_encoder()` で変換） |
| 実行時に `Response` インスタンスを直接返却 | *(当該呼び出しのみバイパス)* | `response_model` によるフィルタリングをスキップし、`Response` オブジェクトをそのまま送信 |

レスポンス契約が有効であり、`response_class` が既定の `JSONResponse` である場合、FastAPI は以下の 3 ステップで出力処理を実行します。

1. **出力契約の検証と機密フィールド除去**: 返却値（ORM エンティティ・`BaseModel`・`dict`）に対し `from_attributes=True` でモデル検証を実行します（`async def` ではイベントループ上、同期 `def` ではワーカースレッドプール経由）。公開モデルに定義されていない `hashed_password` や `totp_secret` などの属性は自動的に除去され、契約違反があれば不正データを外部へ返す前にサーバー側の `ResponseValidationError`（`500`）を送出します。
2. **Rust 1 パス JSON バイト列出力（`TypeAdapter.dump_json`）**: Python の中間 `dict` と `json.dumps()` を経由せず、`response_model_include`・`response_model_exclude`・`response_model_by_alias`・`response_model_exclude_unset`・`response_model_exclude_defaults`・`response_model_exclude_none` を適用したうえで Pydantic v2 の `TypeAdapter.dump_json()` を呼び出し、生成された UTF-8 `bytes` を直接 `Response(media_type="application/json")` に格納します。
3. **ステータスコード別のボディ制御とヘッダ統合**: 引数として注入された `response: Response` 上で設定されたヘッダや `Set-Cookie` は最終レスポンスへ自動マージされ、ボディを持たない HTTP ステータス（`204`・`205`・`304`・`1xx`）では空ボディ（`b""`）が強制されます。

### 機密フィールド除去と疎な PATCH 応答（`exclude_unset`）

内部 DB レコードに対して `response_model=UserPublic` を指定することで機密属性の漏洩を防ぎ、部分更新の `PATCH` では `response_model_exclude_unset=True` を併用することで明示的に送信されたフィールドのみを応答に含めることができます。

```python
from typing import Any, Literal

from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="Identity Profile API", version="1.0.0")


class UserRecordDB(BaseModel):
    user_id: str
    username: str
    email: str
    hashed_password: str
    totp_secret: str


class UserPublic(BaseModel):
    user_id: str
    username: str
    email: str


class ProfilePatch(BaseModel):
    display_name: str = "Anonymous"
    bio: str | None = None
    theme: Literal["light", "dark"] = "light"


@app.get("/users/{user_id}", response_model=UserPublic)
async def get_user_profile(user_id: str) -> Any:
    return UserRecordDB(
        user_id=user_id,
        username="alice",
        email="alice@example.com",
        hashed_password="$argon2id$v=19$m=65536,t=3,p=4$redacted",
        totp_secret="JBSWY3DPEHPK3PXP",
    )


@app.patch(
    "/users/{user_id}/preferences",
    response_model=ProfilePatch,
    response_model_exclude_unset=True,
)
async def patch_preferences(user_id: str, patch: ProfilePatch) -> ProfilePatch:
    _ = user_id
    return patch
```

### 注入 `Response` によるヘッダ操作と直接 `Response` バイパス

**`response_model` による検証と高速直列化を維持したまま**カスタムヘッダや堅牢な Cookie（`__Host-` 接頭辞・`httponly=True`・`secure=True`・`samesite="lax"`）を付与したい場合は、引数として `response: Response` を受け取ります。一方、`304 Not Modified` などのようにシリアライズ自体を意図的にバイパスする場合に限り、`Response` サブクラスを直接返却します（複数型を返す場合は `response_model=None` を明示します）。

```python
from typing import Annotated

from fastapi import FastAPI, Header, Response, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

app = FastAPI(title="Session & Cache API", version="1.0.0")


class SessionSummary(BaseModel):
    session_id: str
    active: bool
    internal_signing_kid: str = Field(exclude=True, default="kid_v3")


@app.post("/sessions", response_model=SessionSummary)
async def issue_session(response: Response) -> dict[str, object]:
    response.headers["Cache-Control"] = "no-store"
    response.set_cookie(
        key="__Host-session",
        value="tok_opaque_random",
        httponly=True,
        secure=True,
        samesite="lax",
        path="/",
    )
    return {
        "session_id": "sess_9001",
        "active": True,
        "unlisted_debug_token": "stripped-by-response-model",
    }


@app.get("/health/raw", response_model=None)
async def raw_probe(etag_match: Annotated[str | None, Header()] = None) -> Response:
    if etag_match == '"v1"':
        return Response(status_code=status.HTTP_304_NOT_MODIFIED)
    return JSONResponse(content={"status": "ok"}, headers={"ETag": '"v1"'})
```

## 2. OpenAPI 3.1.0 遅延合成と入出力分割スキーマ

アプリケーションの起動時間を圧迫しないよう、`app.openapi()` は初回の `/openapi.json` リクエスト（または直接の `app.openapi()` 呼び出し）のタイミングで OpenAPI `3.1.0` 仕様を遅延生成し、メモリ上にキャッシュします。後から動的にルーターや Webhook が追加された場合は、次回アクセス時にキャッシュが自動更新されます。

OpenAPI 仕様の合成は以下の 3 段階で進行します。

1. **スキーマキャッシュとルート探索**: 公開対象の全 `APIRoute` と `@app.webhooks` オペレーションを走査し、リクエストボディモデル、`response_model`、`responses={...}` で宣言されたステータス別エラーモデル、ストリーミング項目スキーマ、コールバック、および入れ子の `Depends()` / `Security()` 関数群のパラメータを一括収集します。
2. **入出力分割 JSON Schema 2020-12 生成**: 既定の `separate_input_output_schemas=True` により、Pydantic v2 は入力検証用と出力直列化用の JSON Schema を比較して `#/components/schemas/` を生成します。`Decimal` フィールド（入力時は `number | string` を許容し、出力時は厳密な `string` に直列化）や `@computed_field`、`serialization_alias` など入出力で型表現が異なるモデルは、自動的に `<Model>-Input` と `<Model>-Output` へ分割して定義されます。
3. **オペレーションとエラー契約の統合**: 共有依存関数間の重複パラメータを排除し、`operationId` を確定させたうえで、正常系 `status_code` とカスタム `responses={404: ..., 409: ...}` 定義を統合し、入力引数やリクエストボディを持つルートには `422`（`HTTPValidationError`）を自動付与します。

```drawlib align=center code=hide file=openapi_31_synthesis_flow.png caption="OpenAPI 3.1.0 遅延合成フロー: スキーマキャッシュ・ルート探索・入出力分割スキーマ・オペレーション統合"
from drawlib.canvas import save, setup
from drawlib.icons import code, phosphor
from drawlib.lines import line
from drawlib.shapes import rectangle
from drawlib.smartarts import CardList, ChevronProcess, Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=168, height=92, dpi=150)

# Title Banner
code.openapi((11, 86.5), width=5.2, style=Styles.Primary)
text(
    (16.5, 86.5),
    "Lazy OpenAPI 3.1.0 Synthesis & Split Input/Output JSON Schema 2020-12",
    style=Styles.DarkBold.patch(text_size=12.5, halign="left"),
)

# Top 4-Stage Synthesis Pipeline
flow = ChevronProcess(
    style=Styles.Neutral,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    corner_angle=60.0,
    spacing=1.5,
    flat_left_end=True,
)
flow.add("1. Schema Cache", description="Lazy build & refresh")
flow.add("2. Route Discovery", description="Params, body & status", style=Styles.PrimaryNeutral)
flow.add(
    "3. Split Schemas",
    description="JSON Schema 2020-12",
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
)
flow.add("4. Path Operations", description="Merge -> OpenAPI 3.1.0", style=Styles.SecondaryNeutral)
flow.draw((6, 68), width=156, height=13)

# Bottom-Left Panel: Split Input/Output Schema Generation
left_p = Panel(
    "Split Schemas (separate_input_output_schemas)",
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=10.8),
    icon=phosphor.arrows_split,
    icon_style=Styles.PrimaryBold,
    header_height=8.5,
)
left_p.draw((6, 6), width=78, height=57)

rectangle((45, 46.5), width=68, height=10.5, style=Styles.White.patch(shape_r=1.8))
text((45, 48.7), "Pydantic v2 JSON Schema 2020-12", style=Styles.DarkBold.patch(text_size=10.5))
text((45, 44.2), "Compares validation input vs serialization output", style=Styles.Dark.patch(text_size=10.0))

# Arrows down from y=41.2 to y=33.0 (8.2 units gap)
line((26.5, 41.2), (26.5, 33.0), arrow_head="->", style=Styles.DarkBold)
line((63.5, 41.2), (63.5, 33.0), arrow_head="->", style=Styles.PrimaryBold)

rectangle((26.5, 21.0), width=32, height=23.5, style=Styles.PrimaryNeutral.patch(shape_r=1.8))
text((26.5, 28.5), "SkuSpec-Input", style=Styles.DarkBold.patch(text_size=10.8))
text(
    (26.5, 17.5),
    "• requestBody $ref\n• Decimal: num | str\n• Validation aliases",
    style=Styles.Dark.patch(text_size=10.0),
)

rectangle((63.5, 21.0), width=32, height=23.5, style=Styles.PrimaryFlat.patch(shape_r=1.8))
text((63.5, 28.5), "SkuSpec-Output", style=Styles.WhiteBold.patch(text_size=10.8))
text(
    (63.5, 17.5),
    "• responses[201] $ref\n• Decimal: strict str\n• @computed_field",
    style=Styles.White.patch(text_size=10.0),
)

# Bottom-Right Panel: Operation & Custom Status Code Assembly
right_p = Panel(
    "Operation & Error Contract Assembly",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=10.8),
    icon=phosphor.file_code,
    icon_style=Styles.DarkBold,
    header_height=8.5,
)
right_p.draw((89, 6), width=73, height=57)
r_xy, r_w, r_h = right_p.get_content_box((89, 6), width=73, height=57, padding=(3.0, 2.8))

ops = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    direction="vertical",
    spacing=2.4,
)
ops.add(
    "Lazy Schema Cache",
    "Cached after first request;\nrefreshes if routes change",
    badge_text="O(1)",
)
ops.add(
    "Custom Status Merging",
    "Merges status_code=201\nwith responses={404, 409}",
    badge_text="4xx",
    style=Styles.SecondaryNeutral,
)
ops.add(
    "422 & Interactive Docs",
    "Adds HTTPValidationError\n-> /openapi.json & /docs",
    badge_text="3.1",
)
ops.draw(r_xy, width=r_w, height=r_h)

save()
```

### エラー契約の宣言と OpenAPI 3.1 分割スキーマの検証

`responses={404: {"model": ErrorDetail}, 409: {"model": ErrorDetail}}` を宣言することで正常系の `status_code=201` と並べて型付きエラースキーマを公開でき、さらに `SkuSpec` の `Decimal` フィールドによって `app.openapi()` 内に `SkuSpec-Input` と `SkuSpec-Output` が生成されることをプログラムから直接検証できます。

```python
from decimal import Decimal

from fastapi import FastAPI, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel

app = FastAPI(title="Warehouse SKU API", version="2.0.0")


class ErrorDetail(BaseModel):
    code: str
    message: str


class SkuSpec(BaseModel):
    sku: str
    unit_price: Decimal = Decimal("19.99")


store: dict[str, SkuSpec] = {"SKU-100": SkuSpec(sku="SKU-100")}


@app.post(
    "/skus",
    response_model=SkuSpec,
    status_code=status.HTTP_201_CREATED,
    responses={
        404: {"model": ErrorDetail, "description": "Parent warehouse not found"},
        409: {"model": ErrorDetail, "description": "SKU already exists"},
    },
)
async def register_sku(spec: SkuSpec) -> SkuSpec | JSONResponse:
    if spec.sku in store:
        return JSONResponse(
            status_code=status.HTTP_409_CONFLICT,
            content={"code": "SKU_CONFLICT", "message": f"{spec.sku} already exists"},
        )
    store[spec.sku] = spec
    return spec


openapi_doc = app.openapi()
assert openapi_doc["openapi"] == "3.1.0"
assert "SkuSpec-Input" in openapi_doc["components"]["schemas"]
assert "SkuSpec-Output" in openapi_doc["components"]["schemas"]
assert set(openapi_doc["paths"]["/skus"]["post"]["responses"]) >= {"201", "404", "409", "422"}
```

入力パラメータやマルチパートボディの束縛ルールについては [Path・Query・Header・Cookie・Body](parameters_and_validation.md) を参照してください。続いて、階層的な `Depends()` グラフの解決は [依存グラフ・キャッシュ・yield スコープ](../04_dependencies_and_security/dependency_injection.md)、`itemSchema` を用いたストリーミング OpenAPI 契約は [ネイティブ SSE・JSONL・WebSocket](../05_async_and_realtime/sse_websockets_streaming.md) で詳しく解説します。
