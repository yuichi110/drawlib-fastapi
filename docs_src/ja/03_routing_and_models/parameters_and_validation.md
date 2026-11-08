# Path・Query・Header・Cookie・Body 検証パイプライン

FastAPI はルート登録時に Python の型注釈・`Annotated[T, ...]` メタデータ・Pydantic v2 モデルを解析し、事前構築された `Dependant` ツリーおよび Rust 製 `ModelField` バリデータへとコンパイルすることで、リクエストごとの署名リフレクションを排除しつつ入力検証と OpenAPI 3.1 スキーマ生成を単一の定義に統合します。

```drawlib align=center code=fold file=param_classification_engine.png caption="get_dependant() および analyze_param() によるルート登録時のパラメータ分類パイプライン"
from drawlib.canvas import save, setup
from drawlib.icons import code, phosphor
from drawlib.lines import line, lines
from drawlib.shapes import rectangle
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=174, height=92, dpi=150)

# Title Banner
code.fastapi((11, 86.5), width=5.2, style=Styles.Primary)
text(
    (16.5, 86.5),
    "Registration-Time Parameter Classification: get_dependant() -> analyze_param()",
    style=Styles.DarkBold.patch(text_size=12.5, halign="left"),
)

# 1. Left Panel: Signature & Annotated Unpacking
p1 = Panel(
    "1. Signature & Annotated",
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.magnifying_glass,
    icon_style=Styles.PrimaryBold,
    header_height=8.5,
)
p1.draw((5, 6), width=54, height=74)
c1_xy, c1_w, c1_h = p1.get_content_box((5, 6), width=54, height=74, padding=(3.0, 3.5))

cl1 = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.PrimaryNeutral,
    icon_style=Styles.PrimaryBold,
    direction="vertical",
    spacing=3.5,
    show_arrows=True,
    arrow_style=Styles.DarkBold,
)
cl1.add(
    "inspect.signature()",
    "PEP 695 TypeAlias unwrap\nvia typing-inspection",
    icon=phosphor.code,
)
cl1.add(
    "Annotated[T, ...]",
    "Extracts Param, Body,\nDepends & PEP 727 Doc()",
    icon=phosphor.code_block,
)
cl1.add(
    "Non-Field Bypass",
    "Depends -> Dependant DAG\nRequest -> direct slot",
    icon=phosphor.git_branch,
    style=Styles.SecondaryNeutral,
)
cl1.draw(c1_xy, width=c1_w, height=c1_h)

# Connector from Panel 1 to Panel 2 (6.0 units)
line((59, 43), (65, 43), arrow_head="->", style=Styles.DarkBold)

# 2. Center Panel: 4-Stage Inference & Routing
p2 = Panel(
    "2. Source Resolution Rules",
    style=Styles.Neutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.0),
    icon=phosphor.arrows_split,
    icon_style=Styles.White,
    header_height=8.5,
)
p2.draw((65, 6), width=50, height=74)

gates = [
    (62.5, "Rule A: {name} in Path?", "Matched against route template", Styles.PrimaryNeutral),
    (46.5, "Rule B: UploadFile / File()?", "Streamed binary or file list", Styles.White),
    (30.5, "Rule C: Complex / Body()?", "BaseModel, dict, Form() or Body()", Styles.White),
    (14.5, "Rule D: Scalar or Param Model?", "int/str/UUID or Query(BaseModel)", Styles.SecondaryNeutral),
]
for idx, (gy, gtitle, gsub, gst) in enumerate(gates):
    rectangle((90, gy), width=43, height=11.5, style=gst.patch(shape_r=1.8))
    text((90, gy + 2.2), gtitle, style=Styles.DarkBold.patch(text_size=10.5))
    text((90, gy - 2.6), gsub, style=Styles.Dark.patch(text_size=10.0))
    if idx < len(gates) - 1:
        next_gy = gates[idx + 1][0]
        line((90, gy - 5.8), (90, next_gy + 5.8), arrow_head="->", style=Styles.MutedBold)

# 3. Right Panel: Compiled ModelField Targets
p3 = Panel(
    "3. Compiled ModelField Slots",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.cpu,
    icon_style=Styles.DarkBold,
    header_height=8.5,
)
p3.draw((121, 6), width=48, height=74)

targets = [
    (62.5, "dependant.path_params", "Required scalar TypeAdapter", Styles.White, False),
    (46.5, "SpooledTemporaryFile", "Closed via AsyncExitStack", Styles.White, False),
    (30.5, "dependant.body_params", "Body_<id> or Body(embed=True)", Styles.PrimaryFlat, True),
    (14.5, "query / header / cookie", "Flattens BaseModel; _ -> -", Styles.White, False),
]
for (ty, ttitle, tsub, tst, is_focal) in targets:
    rectangle((145, ty), width=42, height=11.5, style=tst.patch(shape_r=1.8))
    t_head = Styles.WhiteBold if is_focal else Styles.DarkBold
    t_body = Styles.White if is_focal else Styles.Dark
    text((145, ty + 2.2), ttitle, style=t_head.patch(text_size=10.5))
    text((145, ty - 2.6), tsub, style=t_body.patch(text_size=10.0))
    lines([(111.5, ty), (124.0, ty)], arrow_head="->", style=Styles.PrimaryBold if is_focal else Styles.DarkBold)

save()
```

FastAPI のすべての HTTP エンドポイントおよび依存関数は、ルーターへのパスオペレーション登録時に一度だけ `get_dependant()` を通過し、宣言的な型ヒントから決定論的な実行時抽出器へと変換されます。

## 1. ルート登録時のパラメータ分類エンジン（`analyze_param`）

`fastapi/dependencies/utils.py` 内の `get_dependant()` は、`get_typed_signature()` で前方参照を解決し、`get_path_param_names()` でパス内の `{param}` プレースホルダを抽出したうえで、各引数を `analyze_param()` に委譲します。

1. **PEP 695 型エイリアスと `Annotated` の展開**: `typing-inspection` の `is_typealiastype(annotation)` を用いて Python 3.12+ の `type MyParam = Annotated[...]` 構文を展開した後、`Annotated[T, ...]` のメタデータを走査します。FastAPI 固有のマーカー（`Param`・`Body`・`Depends`・`Security`）は Pydantic の `Field` 制約や PEP 727 の `Doc()` ドキュメント文字列とともに `copy_field_info()` で複製されます。なお `Annotated` 使用時は、デフォルト値はマーカー内部ではなく通常の `= default` 構文で指定する規約が強制されます。
2. **フレームワーク型と依存関数のバイパス**: `Depends` / `Security` は子 `Dependant` ノードとして再帰的に構築され、`Request`・`Response`・`BackgroundTasks`・`WebSocket`・`HTTPConnection`・`SecurityScopes` などのフレームワークオブジェクトは `add_non_field_param_to_dependency()` によって検証フィールドを作らず `Dependant` の専用スロットへ直接束縛されます。
3. **4 段階の決定論的デフォルト推論**: 明示的な `Query()` や `Body()` マーカーが省略された場合、`analyze_param()` は引数の位置と型から以下の優先順位で抽出元を決定します。

| 優先度 | `analyze_param()` における一致条件 | 推論されるマーカー | 格納先の `Dependant` バケット |
| :--- | :--- | :--- | :--- |
| **1** | 引数名がルートパスの `{param}` と一致 | `Path()` | `dependant.path_params`（常時必須・スカラー型限定） |
| **2** | 型が `UploadFile` または `UploadFile` のシーケンス | `File()` | `dependant.body_params`（`multipart/form-data`） |
| **3** | 複合型（`BaseModel`・`Mapping`・`dataclass`・`list[Model]`） | `Body()` | `dependant.body_params`（`application/json`） |
| **4** | スカラー型またはスカラーの配列（`int`・`str`・`UUID`・`list[str]`） | `Query()` | `dependant.query_params` |

4. **ヘッダ名の自動正規化と構造化 `Param` モデル**: `Header(convert_underscores=True)`（既定）は Python の `snake_case` 引数名（例: `x_trace_id`）を標準的な HTTP ハイフン区切り（`x-trace-id`）へ自動変換します。さらに Pydantic の `BaseModel` に `Query()`・`Header()`・`Cookie()` を付与（`Annotated[FilterModel, Query()]`）すると、`_get_param_model()` が OpenAPI 上では個別パラメータとして展開しつつ、実行時の `request_params_to_args()` では `ConfigDict(extra="forbid")` を含むモデル全体の検証を一括適用します。

### マルチソース抽出と構造化 Query フィルタモデル

以下の検証済みエンドポイントは、`Path` 制約、未宣言クエリキーを拒否する Pydantic `Query()` フィルタモデル、`Header` のアンダースコア自動変換、および型付き `Cookie` デフォルト値を単一の署名で統合しています。

```python
from typing import Annotated, Literal

from annotated_doc import Doc
from fastapi import Cookie, FastAPI, Header, Path, Query
from pydantic import BaseModel, ConfigDict, Field

app = FastAPI(title="Catalog Service", version="1.0.0")


class CatalogFilterParams(BaseModel):
    model_config = ConfigDict(extra="forbid")

    limit: int = Field(20, ge=1, le=100, description="Maximum items per page")
    offset: int = Field(0, ge=0, description="Zero-based pagination offset")
    sort_by: Literal["created_at", "price_cents"] = "created_at"
    tags: list[str] = []


@app.get("/catalog/{item_id}")
async def get_catalog_item(
    item_id: Annotated[
        int,
        Path(ge=1, description="Positive catalog item ID"),
        Doc("Unique numeric identifier matched from the URL path template."),
    ],
    filters: Annotated[
        CatalogFilterParams,
        Query(),
        Doc("Structured query filter model forbidding undeclared query keys."),
    ],
    x_trace_id: Annotated[
        str,
        Header(min_length=8, description="Distributed trace correlation header"),
        Doc("Automatically converted from x_trace_id to x-trace-id."),
    ],
    preferred_currency: Annotated[
        Literal["USD", "EUR", "JPY"],
        Cookie(description="ISO-4217 display currency preference"),
    ] = "USD",
) -> dict[str, object]:
    return {
        "item_id": item_id,
        "filters": filters.model_dump(),
        "trace_id": x_trace_id,
        "currency": preferred_currency,
    }
```

実行時には `solve_dependencies()` が Path・Query・Header・Cookie の検証結果とエラーを単一のリストへ集約します。`item_id=0` や未定義の `?debug=1` などが渡された場合でも、最初のエラーで中断せず発生箇所付きの全エラー（`("query", "debug")`、`("path", "item_id")`）を 1 つの `RequestValidationError`（`422 Unprocessable Content`）として返却します。

## 2. 複合 JSON Body・Form データ・Multipart ストリーム

ルートまたは依存関数が 1 つ以上のボディ引数を宣言すると、`_populate_api_route_state()` は `_should_embed_body_fields()` と `_get_body_field()` を評価し、HTTP ペイロードのデコード方式および OpenAPI スキーマ構造を決定します。

- **単一モデル直結と合成 `Body` エンベロープ**: `embed=True` を指定しない単一の `BaseModel` 引数は JSON ルートオブジェクト（`loc=("body",)`）に直接対応します。一方、**複数の `Body` 引数**が存在する場合や単一引数に `Body(embed=True)` が指定された場合は、`_get_body_field()` が `create_body_model()` を呼び出して合成スキーマ `Body_<route.unique_id>` を自動生成し、引数名をトップレベル JSON キーとするエンベロープ構造を要求します。既定の `strict_content_type=True` により、`get_request_handler()` は JSON デコード前に `application/json`（または `application/*+json`）ヘッダを厳密に検証します。
- **URL エンコード `Form()` と Multipart `UploadFile` のライフサイクル**: `Form()` や `File()` を使用すると起動時に `ensure_multipart_is_installed()`（`python-multipart > 0.0.12`）が検証されます。リクエスト処理時は `body = await request.form()` がフォーム項目を解析し、アップロードファイルを `SpooledTemporaryFile`（1 MiB までメモリ保持、超過分をディスクへスプール）で裏打ちされた Starlette の `UploadFile` にラップします。同時に `AsyncExitStackMiddleware`（`scope["fastapi_middleware_astack"]`）へ `file_stack.push_async_callback(body.close)` が登録されるため、正常応答時も例外送出時も一時ファイル記述子が確実にクローズされます。

```drawlib align=center code=fold file=multipart_and_composite_body.png caption="ペイロード解析アーキテクチャと比較: 複合 JSON Body・URL エンコード Form・Multipart UploadFile"
from drawlib.canvas import save, setup
from drawlib.icons import code, phosphor
from drawlib.lines import line
from drawlib.shapes import rectangle
from drawlib.smartarts import Panel, Table
from drawlib.styles import Colors, Styles
from drawlib.text import text

setup(width=168, height=96, dpi=150)

# Title Banner
code.pydantic((11, 90.5), width=5.0, style=Styles.Primary)
text(
    (16.5, 90.5),
    "Payload Decoding Architecture: Composite JSON Body vs Form & Multipart Streams",
    style=Styles.DarkBold.patch(text_size=12.5, halign="left"),
)

# Top 3 Architecture Lanes
lanes = [
    (
        6,
        "1. Composite JSON (Body)",
        Styles.PrimaryFlat,
        Styles.WhiteBold,
        phosphor.code_block,
        Styles.White,
        "await request.json()",
        "strict_content_type=True",
        "Body_<unique_id> Envelope",
        "Multi-model or Body(embed=True)",
        Styles.PrimaryNeutral,
    ),
    (
        59,
        "2. URL-Encoded (Form)",
        Styles.PrimaryNeutral,
        Styles.DarkBold,
        phosphor.table,
        Styles.PrimaryBold,
        "await request.form()",
        "python-multipart > 0.0.12",
        "Form() Scalar & BaseModel",
        "_extract_form_body() mapping",
        Styles.SecondaryNeutral,
    ),
    (
        112,
        "3. Multipart Stream (File)",
        Styles.SecondaryNeutral,
        Styles.DarkBold,
        phosphor.cloud_arrow_up,
        Styles.DarkBold,
        "UploadFile + SpooledTemp",
        "1 MiB RAM -> disk rollover",
        "AsyncExitStackMiddleware",
        "push_async_callback(body.close)",
        Styles.PrimaryNeutral,
    ),
]

for lx, ltitle, hstyle, htxt, licon, icostyle, top1, top2, bot1, bot2, botstyle in lanes:
    p = Panel(
        ltitle,
        style=Styles.Neutral,
        header_style=hstyle,
        text_style=htxt.patch(text_size=10.8),
        icon=licon,
        icon_style=icostyle,
        header_height=8.0,
    )
    p.draw((lx, 44), width=50, height=41)
    cx = lx + 25
    rectangle((cx, 69.5), width=44, height=10.5, style=Styles.White.patch(shape_r=1.6))
    text((cx, 71.5), top1, style=Styles.DarkBold.patch(text_size=10.5))
    text((cx, 67.2), top2, style=Styles.Dark.patch(text_size=10.0))

    line((cx, 64.2), (cx, 58.2), arrow_head="->", style=Styles.DarkBold)

    rectangle((cx, 52.5), width=44, height=11.0, style=botstyle.patch(shape_r=1.6))
    text((cx, 54.7), bot1, style=Styles.DarkBold.patch(text_size=10.5))
    text((cx, 50.1), bot2, style=Styles.Dark.patch(text_size=10.0))

# Bottom Comparison Matrix Table
matrix = Table(
    cell_style=Styles.White,
    text_style=Styles.Dark.patch(text_size=10.0),
    header_cell_style=Styles.PrimaryFlat,
    header_text_style=Styles.WhiteBold.patch(text_size=10.5),
    border_style=Styles.MutedThin,
)
matrix.set_style_cell_evenodd(
    Colors.White,
    Styles.Dark.patch(text_size=10.0),
    Styles.Neutral.shape_fill_color,
    Styles.Dark.patch(text_size=10.0),
)
matrix.set_style_cell_rowheader(
    Styles.PrimaryNeutral.shape_fill_color,
    Styles.DarkBold.patch(text_size=10.2),
)
matrix.set_style_cell_header(
    Styles.PrimaryFlat.shape_fill_color,
    Styles.WhiteBold.patch(text_size=10.5),
)
matrix.draw_flexible(
    xy=(6, 6),
    column_widths=[30.0, 42.0, 42.0, 42.0],
    row_heights=[8.2, 8.0, 8.0, 8.0],
    data=[
        ["Dimension", "JSON Body()", "URL-Encoded Form()", "Multipart File() / UploadFile"],
        ["Media Type", "application/json (+json)", "application/x-www-form-urlencoded", "multipart/form-data"],
        ["OpenAPI Schema", "Direct T or Body_<route_id>", "Body_<route_id> (form props)", "Body_<route_id> (binary str)"],
        ["Memory & Cleanup", "Buffered bytes -> JSON dict", "FormData ImmutableMultiDict", "1 MiB RAM spool + ExitStack"],
    ],
    align="bottom_left",
)

save()
```

### 複合 Body エンベロープ・`Body(embed=True)`・PEP 727 `Doc()`

複数の Pydantic モデルとスカラー `Body()` フィールドを同一エンドポイントで宣言すると自動的にキー付き JSON エンベロープが構成され、また単一モデルであっても `Body(embed=True)` を指定することで同じキー付きラッパー構造を強制できます。

```python
from typing import Annotated

from annotated_doc import Doc
from fastapi import Body, FastAPI, Path
from pydantic import BaseModel, Field

app = FastAPI(title="Order Fulfillment API", version="1.0.0")


class OrderLine(BaseModel):
    sku: Annotated[str, Field(pattern=r"^SKU-[A-Z0-9]{4}$"), Doc("Warehouse SKU")]
    quantity: Annotated[int, Field(ge=1, le=500), Doc("Units requested")]


class AuditContext(BaseModel):
    actor_id: Annotated[str, Field(min_length=3), Doc("Authenticated operator ID")]
    reason: Annotated[str, Field(min_length=5), Doc("Audit trail justification")]


@app.put("/orders/{order_id}")
async def replace_order(
    order_id: Annotated[str, Path(pattern=r"^ord_[0-9]+$")],
    line: Annotated[OrderLine, Doc("Primary line-item payload")],
    audit: Annotated[AuditContext, Doc("Mandatory audit metadata")],
    priority: Annotated[
        int,
        Body(ge=1, le=5, description="Dispatch priority tier (1=low, 5=urgent)"),
        Doc("Scalar body attribute merged into synthetic Body model"),
    ] = 3,
) -> dict[str, object]:
    return {
        "order_id": order_id,
        "sku": line.sku,
        "quantity": line.quantity,
        "actor_id": audit.actor_id,
        "priority": priority,
    }


@app.post("/orders/quote")
async def quote_single_embedded_body(
    line: Annotated[
        OrderLine,
        Body(embed=True),
        Doc("Forces single BaseModel under top-level {'line': {...}} key"),
    ],
) -> dict[str, object]:
    return {"sku": line.sku, "estimated_cents": line.quantity * 2500}
```

### セキュアな Multipart Form と非同期 `UploadFile` ストリーミング

`Form()` と `File()` は同一のマルチパートパーサーを共有するため、構造化フォーム項目と非同期 `UploadFile` ストリームを同時に受け取りつつ、許可 MIME リスト・最大バイト上限（`await file.read(MAX + 1)`）・マジックバイト検査・UUID によるサーバー側ストレージキー採番（クライアント由来の `file.filename` の非信頼化）を実装できます。

```python
from typing import Annotated, Literal
from uuid import uuid4

from fastapi import FastAPI, File, Form, HTTPException, UploadFile, status

app = FastAPI(title="Document Vault API", version="1.0.0")

ALLOWED_MEDIA_TYPES = {"application/pdf": b"%PDF-", "image/png": b"\x89PNG"}
MAX_UPLOAD_BYTES = 1024 * 1024  # 1 MiB ceiling


@app.post("/documents/upload", status_code=status.HTTP_201_CREATED)
async def upload_document(
    category: Annotated[Literal["invoice", "contract"], Form()],
    file: Annotated[UploadFile, File(description="PDF or PNG document")],
    description: Annotated[str, Form(max_length=120)] = "",
) -> dict[str, object]:
    expected_magic = ALLOWED_MEDIA_TYPES.get(file.content_type or "")
    if expected_magic is None:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Only application/pdf and image/png are permitted",
        )

    payload = await file.read(MAX_UPLOAD_BYTES + 1)
    if len(payload) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail="Uploaded file exceeds 1 MiB limit",
        )
    if not payload.startswith(expected_magic):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File header magic bytes do not match declared Content-Type",
        )

    # Never trust client-controlled file.filename for filesystem or object keys
    storage_key = f"{category}/{uuid4().hex}"
    return {
        "storage_key": storage_key,
        "content_type": file.content_type,
        "size_bytes": len(payload),
        "description": description,
    }
```

入力パラメータとペイロードの検証が完了すると、エンドポイントの戻り値は出力シリアライズおよびスキーマ合成エンジンへと引き渡されます。続いて [レスポンス直列化と OpenAPI 3.1](responses_and_openapi.md) で出力契約の仕組みを、さらに [Dependant DAG・キャッシュ・yield スコープ](../04_dependencies_and_security/dependency_injection.md) で依存グラフの解決機構を解説します。
