# パラメータモデル合成・特殊型・スキーマ例示

FastAPI `v0.157.0`〜`v0.162.2` は、Pydantic パラメータモデル（`Query()`・`Header()`・`Cookie()`・`Form()`）を合成・省略可能・判別共用体対応の抽出器へと拡張するとともに、JSON `null` と省略キーの厳密な区別、HTML チェックボックス `Form` の既定値解決、標準ライブラリ／Pydantic の拡張データ型、および 3 階層の OpenAPI 3.1 例示機構を統合します。

```drawlib align=center code=hide file=parameter_models_composition.png caption="FastAPI v0.157–v0.162 パラメータモデル合成アーキテクチャ: 複数モデル抽出・Optional/Union 解決・兄弟モデル間の extra='forbid' 規則"
from drawlib.canvas import save, setup
from drawlib.icons import code, phosphor
from drawlib.lines import line
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Styles
from drawlib.text import text

setup(width=180, height=96, dpi=150)

# Title Banner
code.fastapi((10.5, 90.5), width=5.2, style=Styles.Primary)
text(
    (16.0, 90.5),
    "Parameter Model Composition (v0.157–v0.162): Multi-Model, Optional/Union & Extra Policy",
    style=Styles.DarkBold.patch(text_size=12.2, halign="left"),
)

# 1. Left Panel: Parameter Model Sources
p1 = Panel(
    "1. Parameter Model Sources",
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.sliders_horizontal,
    icon_style=Styles.PrimaryBold,
    header_height=8.5,
)
p1.draw((5, 6), width=52, height=78)
c1_xy, c1_w, c1_h = p1.get_content_box((5, 6), width=52, height=78, padding=(2.8, 3.0))

cl1 = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.PrimaryNeutral,
    icon_style=Styles.PrimaryBold,
    direction="vertical",
    spacing=2.6,
)
cl1.add(
    "Query(BaseModel)",
    "Flattens OpenAPI params;\ncomposes across Depends()",
    icon=phosphor.magnifying_glass,
)
cl1.add(
    "Header(BaseModel)",
    "Per-model _ -> - mapping;\npreserves model_fields",
    icon=phosphor.list_bullets,
)
cl1.add(
    "Cookie(BaseModel)",
    "Structured session & UI\nprefs from Cookie header",
    icon=phosphor.cookie,
)
cl1.add(
    "Form(BaseModel)",
    "Synthesizes allOf schema;\nURL-encoded & multipart",
    icon=phosphor.table,
    style=Styles.SecondaryNeutral,
)
cl1.draw(c1_xy, width=c1_w, height=c1_h)

# Arrow 1 -> 2 (6.0 units)
line((57, 45), (63, 45), arrow_head="->", style=Styles.DarkBold)

# 2. Center Panel: Independent Slice Extraction
p2 = Panel(
    "2. Independent Slice Extraction",
    style=Styles.Neutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.0),
    icon=phosphor.cpu,
    icon_style=Styles.White,
    header_height=8.5,
)
p2.draw((63, 6), width=54, height=78)
c2_xy, c2_w, c2_h = p2.get_content_box((63, 6), width=54, height=78, padding=(2.8, 3.2))

cl2 = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    direction="vertical",
    spacing=3.4,
    show_arrows=True,
    arrow_style=Styles.DarkBold,
)
cl2.add(
    "Optional Model | None",
    "Checks own_names overlap;\nomitted: None, partial: 422",
    badge_text="Opt",
)
cl2.add(
    "Discriminated Form Union",
    "BeforeValidator reshapes\nrepeated keys per branch",
    badge_text="Uni",
    style=Styles.SecondaryNeutral,
)
cl2.add(
    "Forward Remaining Keys",
    "Forwards unclaimed keys\nfor model extra checks",
    badge_text="Ext",
)
cl2.draw(c2_xy, width=c2_w, height=c2_h)

# Arrow 2 -> 3 (6.0 units)
line((117, 45), (123, 45), arrow_head="->", style=Styles.DarkBold)

# 3. Right Panel: Extra Policy & v0.160 Rule
p3 = Panel(
    "3. Extra Policy & v0.160 Rule",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.shield_check,
    icon_style=Styles.DarkBold,
    header_height=8.5,
)
p3.draw((123, 6), width=52, height=78)
c3_xy, c3_w, c3_h = p3.get_content_box((123, 6), width=52, height=78, padding=(2.8, 3.2))

cl3 = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    direction="vertical",
    spacing=3.4,
)
cl3.add(
    'extra="ignore" (Default)',
    "Safe for sibling models\n& shared Depends() slices",
    badge_text="OK",
    badge_style=Styles.PrimaryFlat,
    badge_text_style=Styles.WhiteBold.patch(text_size=10.0),
)
cl3.add(
    'Single extra="forbid"',
    "Rejects typos (422) if one\nmodel owns entire source",
    badge_text="1x",
)
cl3.add(
    'Sibling extra="forbid"!',
    "v0.160+: Model A rejects\nModel B keys -> 422 error!",
    badge_text="422",
    style=Styles.SecondaryNeutral,
    badge_style=Styles.DangerFlat,
    badge_text_style=Styles.WhiteBold.patch(text_size=10.0),
)
cl3.draw(c3_xy, width=c3_w, height=c3_h)

save()
```

関連する HTTP 入力群を再利用可能な Pydantic `BaseModel` へ構造化することで、エンドポイントの関数署名を簡潔に保ちつつ、クエリ文字列・ヘッダ・Cookie・フォーム全体にわたる `@model_validator` の不変条件を一貫して適用できます。

## 1. パラメータモデルの合成（`Query`・`Header`・`Cookie`・`Form`）

FastAPI `v0.157.0`〜`v0.162.2` では、`fastapi/dependencies/utils.py` の抽出エンジンが単一モデルの束縛から「エンドポイント引数と `Depends()` サブグラフを横断するモジュラー合成」へと拡張されています。

1. **複数モデルの合成と OpenAPI フラット展開**:
   - `Query()`・`Header()`・`Cookie()` では、`_get_param_model()` が `Model` と `Model | None` の双方を展開し、`get_flat_params()` が OpenAPI 上のフラットなパラメータ一覧を出力する一方、実行時は `_request_param_model_to_args()` が各モデルを独立して検証します。
   - `Form()` では、`_get_form_models()` がルート引数と `Depends()` にまたがる複数のフォームモデルを OpenAPI の `allOf` リクエストボディスキーマへ合成し、実行時は `_extract_form_model()` が生の `FormData` からモデル単位で独立抽出します。
2. **モデル単位の `Header(convert_underscores=...)` 分離**:
   - `_request_param_model_to_args()` は `Model.model_fields` のキャッシュを破壊的に書き換えることなく `Header()` 引数ごとに `convert_underscores` を解決するため、同一の `BaseModel` を `Header()`・`Header(convert_underscores=False)`・`Query()` で安全に再利用できます。既定の `loc_by_alias=True` により、検証エラーの `loc` には通信上のハイフン名（例: `["header", "x-retry-attempt"]`）が報告されます。
3. **省略可能な `Model | None = None` と判別共用体 `Form()` モデル**:
   - `Annotated[RangeModel | None, Query()] = None`（または `Header()`・`Cookie()`・`Form()`）と宣言すると、リクエスト中にそのモデルのフィールド（またはエイリアス）が 1 つでも含まれるかが判定されます（`own_names.intersection(received_params)` / `_is_form_model_supplied()`）。該当キーが完全に省略された場合は `Undefined` が渡されて `None` となり、一部だけ送信された場合（例: `max_cents` なしの `?min_cents=500`）はモデル検証が走って不足フィールドに対する `422` が返ります（※ `= None` を省略するとパラメータ自体は必須のままになります）。
   - `Annotated[WebhookForm | EmailForm | None, Form(discriminator="channel")] = None` のような共用体フォームでは、`_add_form_union_validators()` が各分岐へ `BeforeValidator(_normalize_form_model)` を注入し、同名キーの反復送信（`list[str]` と単一 `str`）を分岐ごとの型定義に合わせて正規化します。
4. **`v0.160.0` における兄弟モデル間の `extra="forbid"` 規則**:
   - クエリ文字列・HTTP ヘッダ・Cookie・フラットな HTML フォームは、それぞれ通信上で単一の名前空間を共有します。そのため `_request_param_model_to_args()` および `_extract_form_items()` は、自モデル以外の残余キーを各パラメータモデルへ引き渡し、モデル自身の `model_config["extra"]` ポリシーに判定を委ねます。

| パラメータモデルの構成パターン | 推奨される `extra` 設定 | FastAPI `v0.160.0`〜`v0.162.2` における実行時挙動 |
| :--- | :--- | :--- |
| **単一の `Query` / `Cookie` / `Form` モデルが名前空間を独占** | `extra="forbid"` または `"ignore"` | クライアントの未定義キーやタイポを `422 extra_forbidden` で厳格に拒否可能 |
| **同一箇所に複数の兄弟モデル** または **モデル＋スカラー引数／`Depends()` を併用** | `extra="ignore"`（Pydantic 既定） | 各モデルが自身の担当キーのみを検証。`extra="forbid"` を付けると Model A が Model B の正当なキーを未定義キーとみなして `422` で拒否するため要注意 |
| **`Header()` パラメータモデル** | `extra="ignore"`（事実上必須） | クライアントが常時送信する標準ヘッダ（`host`・`user-agent`・`accept` 等）が `extra="forbid"` では `422` となるため |

> [!WARNING]
> 複数のモジュラーな `Query()` や `Form()` スライスに対して未知キー拒否（`extra="forbid"`）を効かせたい場合は、同一ルートに複数の `extra="forbid"` 引数を並べるのではなく、Pydantic の多重継承（`class CombinedQuery(PaginationParams, SortParams): model_config = ConfigDict(extra="forbid")`）で単一モデルに統合してください。また `from __future__ import annotations` 環境下でルート登録時に `BaseModel` 判定を確実に解決させるため、パラメータモデルは関数ローカルではなくモジュールスコープに定義してください。

### 複数 Query モデル・Optional Header/Cookie・判別共用体 Form の統合

以下の検証済みアプリケーションは、`Depends()` 経由の共通ページネーションモデルと省略可能な `Query()`・`Header()`・`Cookie()` モデルの合成、単一モデルでの `extra="forbid"` カーソル検証、および判別共用体 `Form(discriminator="channel")` を統合しています。

```python
from typing import Annotated, Any, Literal

from fastapi import Cookie, Depends, FastAPI, Form, Header, Query
from pydantic import BaseModel, ConfigDict, Field, model_validator

app = FastAPI(title="Parameter Model Composition API", version="1.0.0")


class PaginationParams(BaseModel):
    # Keep default extra="ignore" when composing multiple sibling models!
    limit: int = Field(20, ge=1, le=100, description="Maximum rows per page")
    offset: int = Field(0, ge=0, description="Zero-based row offset")
    sort: Literal["recent", "amount"] = "recent"


class AmountRangeParams(BaseModel):
    min_cents: int = Field(ge=0)
    max_cents: int = Field(ge=0)

    @model_validator(mode="after")
    def validate_bounds(self) -> "AmountRangeParams":
        if self.min_cents > self.max_cents:
            raise ValueError("min_cents must not exceed max_cents")
        return self


class TraceHeaders(BaseModel):
    x_correlation_id: str = Field(min_length=8)
    x_retry_attempt: int = Field(0, ge=0, le=5)


class SessionPrefsCookie(BaseModel):
    ui_locale: Literal["en", "ja"] = "en"
    compact_table: bool = False


class StrictCursorQuery(BaseModel):
    # Safe on endpoints where this single model owns the entire query namespace
    model_config = ConfigDict(extra="forbid")

    cursor: str = Field(min_length=4)
    limit: int = Field(25, ge=1, le=100)


class WebhookChannelForm(BaseModel):
    channel: Literal["webhook"]
    endpoint_url: str
    headers_tag: list[str] = Field(default_factory=list)


class EmailChannelForm(BaseModel):
    channel: Literal["email"]
    recipients: list[str]
    digest_only: bool = False


def get_pagination(
    page: Annotated[PaginationParams, Query()],
) -> PaginationParams:
    return page


@app.get("/ledger/entries")
async def list_ledger_entries(
    page: Annotated[PaginationParams, Depends(get_pagination)],
    amount_range: Annotated[AmountRangeParams | None, Query()] = None,
    trace: Annotated[TraceHeaders | None, Header()] = None,
    prefs: Annotated[SessionPrefsCookie | None, Cookie()] = None,
) -> dict[str, Any]:
    return {
        "page": page.model_dump(),
        "amount_range": amount_range.model_dump() if amount_range else None,
        "trace": trace.model_dump() if trace else None,
        "prefs": prefs.model_dump() if prefs else None,
    }


@app.get("/ledger/cursor")
async def list_by_strict_cursor(
    params: Annotated[StrictCursorQuery, Query()],
) -> dict[str, Any]:
    return params.model_dump()


@app.post("/alerts/subscription")
async def upsert_subscription(
    target: Annotated[
        WebhookChannelForm | EmailChannelForm | None,
        Form(discriminator="channel"),
    ] = None,
) -> dict[str, Any]:
    return {"target": target.model_dump() if target else None}
```

## 2. 拡張 Python データ型・厳密な `null` 仕様・OpenAPI 3.1 例示

基本的な `int`・`str`・`bool` に加え、FastAPI と Pydantic v2 は標準ライブラリおよび Pydantic の豊富なドメイン型を Rust バリデータと JSON Schema 2020-12 形式へ直接コンパイルしつつ、**キーの省略**・**明示的な JSON `null`**・**空の HTML フォーム文字列**を厳密に区別します。

```drawlib align=center code=hide file=extra_types_and_null_semantics.png caption="拡張データ型マトリクス・v0.151 JSON null と v0.162 Form 真偽値仕様・3 階層 OpenAPI 3.1 例示"
from drawlib.canvas import save, setup
from drawlib.icons import code, phosphor
from drawlib.shapes import rectangle
from drawlib.smartarts import CardList, Panel, Table
from drawlib.styles import Colors, Styles
from drawlib.text import text

setup(width=174, height=104, dpi=150)

# Title Banner
code.pydantic((10.5, 98.5), width=5.0, style=Styles.Primary)
text(
    (16.0, 98.5),
    "Rich Extra Types, v0.151–v0.162 Null/Checkbox Semantics & OpenAPI 3.1 Examples",
    style=Styles.DarkBold.patch(text_size=12.2, halign="left"),
)

# Top-Left Panel: Rich Stdlib, Pydantic & Dataclass Types
p_types = Panel(
    "1. Rich Domain Types & Dataclasses",
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.brackets_curly,
    icon_style=Styles.PrimaryBold,
    header_height=8.0,
)
p_types.draw((5, 52), width=80, height=40)

type_cards = [
    (25.5, 78.2, "Enum / StrEnum", "Finite OpenAPI enum", Styles.White),
    (64.5, 78.2, "UUID & Base64Bytes", "RFC 4122 & base64 bytes", Styles.White),
    (25.5, 68.2, "datetime & timedelta", "ISO-8601 & seconds", Styles.White),
    (64.5, 68.2, "Decimal (Split I/O)", "num|str in -> str out", Styles.SecondaryNeutral),
    (25.5, 58.2, "frozenset[T]", "Deduplicated uniqueItems", Styles.White),
    (64.5, 58.2, "@dataclass DTOs", "Zero-BaseModel schemas", Styles.PrimaryNeutral),
]
for cx, cy, t_title, t_sub, t_style in type_cards:
    rectangle((cx, cy), width=36.5, height=8.2, style=t_style.patch(shape_r=1.5))
    text((cx, cy + 1.6), t_title, style=Styles.DarkBold.patch(text_size=10.2))
    text((cx, cy - 2.0), t_sub, style=Styles.Dark.patch(text_size=10.0))

# Top-Right Panel: OpenAPI 3.1 Example Precedence
p_ex = Panel(
    "2. OpenAPI 3.1 Example Tiers",
    style=Styles.Neutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.0),
    icon=phosphor.book_open,
    icon_style=Styles.White,
    header_height=8.0,
)
p_ex.draw((89, 52), width=80, height=40)
ex_xy, ex_w, ex_h = p_ex.get_content_box((89, 52), width=80, height=40, padding=(3.0, 2.4))

cl_ex = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.3),
    description_style=Styles.Dark.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    direction="vertical",
    spacing=1.8,
)
cl_ex.add(
    "Body(openapi_examples={...})",
    "Named scenario selector in /docs UI",
    badge_text="L1",
    badge_style=Styles.PrimaryFlat,
    badge_text_style=Styles.WhiteBold.patch(text_size=10.0),
)
cl_ex.add(
    "ConfigDict(json_schema_extra=...)",
    "Model-wide examples in components",
    badge_text="L2",
)
cl_ex.add(
    "Field(examples=[...])",
    "Property-level JSON Schema 2020-12",
    badge_text="L3",
    style=Styles.SecondaryNeutral,
)
cl_ex.draw(ex_xy, width=ex_w, height=ex_h)

# Bottom Table: v0.151–v0.162 Null, Empty & Default Semantics Matrix
tbl = Table(
    cell_style=Styles.White,
    text_style=Styles.Dark.patch(text_size=10.0),
    header_cell_style=Styles.PrimaryFlat,
    header_text_style=Styles.WhiteBold.patch(text_size=10.3),
    border_style=Styles.MutedThin,
)
tbl.set_style_cell_evenodd(
    even_color=Colors.Light,
    even_text_style=Styles.Dark.patch(text_size=10.0),
    odd_color=Colors.White,
    odd_text_style=Styles.Dark.patch(text_size=10.0),
)
tbl.set_style_cell_header(
    background_color=Styles.PrimaryFlat.shape_fill_color,
    text_style=Styles.WhiteBold.patch(text_size=10.3),
)
tbl.set_style_cell(
    background_color=Styles.SecondaryNeutral.shape_fill_color,
    text_style=Styles.DarkBold.patch(text_size=10.0),
    rows=[2, 4],
)

semantics_rows = [
    ["Input Scenario", "Declaration", "Wire Input", "v0.162.2 Runtime Outcome"],
    ["Omitted JSON Key", "retry_limit: int = 3", "{}", "200 OK -> 3 (unset)"],
    ["Explicit JSON null", "retry_limit: int = 3", '{"retry_limit": null}', "422 int_type (v0.151+)"],
    ["Nullable JSON Key", "memo: str | None = None", '{"memo": null}', "200 OK -> None (set)"],
    ["Unchecked Checkbox", "opt_in: Annotated[bool, Form()] = False", "(field omitted)", "200 OK -> False (v0.162+)"],
    ["Blank Form String", "nick: Annotated[str | None, Form()] = None", 'nick=""', "200 OK -> None (Undefined)"],
]
tbl.draw_flexible(
    xy=(5, 46.5),
    column_widths=[34, 52, 36, 42],
    row_heights=[7.4, 6.5, 6.5, 6.5, 6.5, 6.5],
    data=semantics_rows,
    align="top_left",
)

save()
```

### `v0.151.0`〜`v0.162.2` における特殊型・デフォルト値・真偽値保証

1. **拡張ドメイン型と標準 `@dataclass` の直接サポート**:
   - **`Enum` / `StrEnum`**: パス・クエリ・ボディの許容値を有限の OpenAPI `enum` リストへ制約し、リスト外の値を `422` で拒否します（Python 3.11+ では `enum.StrEnum`、3.10 互換コードでは `(str, Enum)` を利用可能）。
   - **`UUID`・`datetime`・`timedelta`・`Decimal`・`frozenset`・`Base64Bytes`**: `timedelta` は秒数または ISO-8601 期間文字列（`"PT15M"`）を受理し、`Decimal` は浮動小数点誤差を防ぎつつ入力（`number | string`）と出力（`string`）で分割された OpenAPI スキーマを生成します。`frozenset[str]` は重複要素を排除した不変集合（`uniqueItems: true`）を生成し、`pydantic.Base64Bytes` は Base64 文字列を `bytes` へ復号します。また標準ライブラリの `@dataclass` も `BaseModel` 継承なしでリクエストボディや `response_model` にそのまま指定可能です。
2. **`v0.151.0` 以降の明示的 JSON `null` 拒否と `strict_content_type`**:
   - JSON オブジェクトから `"retry_limit"` キー自体を省略した場合は `retry_limit: int = 3` のデフォルト値が適用されます（`model_fields_set` には記録されません）。一方、`{"retry_limit": null}` のように明示的な `null` を送信した場合、FastAPI `v0.151.0` 以降はデフォルト値へフォールバックせず `422 int_type` で拒否します（`null` を許容するには `int | None = 3` と明記します）。同様に、モデル引数全体が必須（`instruction: PayoutInstruction`）である場合、全フィールドにデフォルト値があっても空ボディのリクエストは `422 missing` となります。
   - 既定の `strict_content_type=True`（`FastAPI`・`APIRouter`・各ルートデコレータで設定可能）により、`Content-Type: application/json`（または `application/*+json`）がない生ボディは JSON として解釈されません。
3. **`v0.162.0` の HTML フォーム空文字列と未選択チェックボックス処理**:
   - ブラウザは未入力のテキスト欄に空文字列 `""` を送信し、未チェックの `<input type="checkbox">` はキー自体を送信しません（チェック時は `"on"`）。`_get_multidict_value()` は `FormData` の欠損キーおよび `""` を検証前に `Undefined` へ正規化するため、任意のチェックボックス（`marketing_opt_in: Annotated[bool, Form()] = False`）は未送信時に `False`、`"on"` 送信時に `True` となり、必須チェックボックス（`accept_terms: Annotated[bool, Form()]`）は未送信時に確実に `422 missing` を返します。
4. **3 階層の OpenAPI 3.1 例示（Examples）**:
   - フィールド単位の `Field(examples=[...])`、モデル単位の `ConfigDict(json_schema_extra={"examples": [...]})`、およびパラメータ単位の `Body(openapi_examples={...})`（`summary`・`description`・`value`）を組み合わせることで、`components.schemas` の文書化と `/docs`（Swagger UI）上のシナリオ切り替えドロップダウンを同時に提供できます。

### 特殊型・厳密な null/Form 既定値・名前付き OpenAPI 例示の実装

以下の検証済みサービスは、拡張ドメイン型・`@dataclass` レスポンス直列化・3 階層の OpenAPI 3.1 例示・`v0.151.0` の非 null JSON デフォルト仕様・`v0.162.0` の HTML チェックボックス処理を 1 つの API に統合しています。

```python
from dataclasses import dataclass
from datetime import datetime, timedelta
from decimal import Decimal
from enum import Enum
from typing import Annotated, Any
from uuid import UUID

from fastapi import Body, FastAPI, Form, status
from pydantic import Base64Bytes, BaseModel, ConfigDict, Field

app = FastAPI(title="Extra Types & Strict Semantics API", version="1.0.0")


class SettlementEnvironment(str, Enum):
    SANDBOX = "sandbox"
    PRODUCTION = "production"


class PayoutInstruction(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra={
            "examples": [
                {
                    "idempotency_key": "550e8400-e29b-41d4-a716-446655440000",
                    "scheduled_at": "2026-11-08T15:00:00Z",
                    "settlement_window": "PT30M",
                    "amount": "1250.50",
                    "scopes": ["payouts:write", "audit:read"],
                    "signature_der": "aGVsbG8td29ybGQ=",
                    "retry_limit": 3,
                    "memo": None,
                }
            ]
        },
    )

    idempotency_key: UUID = Field(
        examples=["550e8400-e29b-41d4-a716-446655440000"],
        description="Client-generated UUIDv4 idempotency token",
    )
    scheduled_at: datetime
    settlement_window: timedelta = timedelta(minutes=30)
    amount: Decimal = Field(gt=Decimal("0"), decimal_places=2)
    scopes: frozenset[str] = frozenset()
    signature_der: Base64Bytes
    # v0.151+: Omitting uses 3, but explicit JSON {"retry_limit": null} raises 422!
    retry_limit: int = Field(3, ge=0, le=10)
    # Explicit union with None allows both omission and JSON {"memo": null}
    memo: str | None = None


@dataclass
class PayoutReceipt:
    environment: SettlementEnvironment
    idempotency_key: UUID
    settled_by: datetime
    amount: Decimal
    unique_scope_count: int
    signature_byte_len: int
    retry_limit: int
    explicit_fields: list[str]


@app.post(
    "/settlements/{env}/payouts",
    response_model=PayoutReceipt,
    status_code=status.HTTP_201_CREATED,
)
async def create_payout(
    env: SettlementEnvironment,
    instruction: Annotated[
        PayoutInstruction,
        Body(
            openapi_examples={
                "instant_wire": {
                    "summary": "Immediate high-priority payout",
                    "description": "Uses explicit retry_limit and two deduplicated scopes.",
                    "value": {
                        "idempotency_key": "550e8400-e29b-41d4-a716-446655440000",
                        "scheduled_at": "2026-11-08T15:00:00Z",
                        "settlement_window": "PT15M",
                        "amount": "499.95",
                        "scopes": ["payouts:write", "payouts:write"],
                        "signature_der": "c2lnLWJ5dGVz",
                        "retry_limit": 5,
                    },
                },
                "minimal_defaults": {
                    "summary": "Minimal payload relying on field defaults",
                    "value": {
                        "idempotency_key": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
                        "scheduled_at": "2026-11-08T18:00:00Z",
                        "amount": "25.00",
                        "signature_der": "c2lnLW1pbg==",
                    },
                },
            }
        ),
    ],
) -> PayoutReceipt:
    return PayoutReceipt(
        environment=env,
        idempotency_key=instruction.idempotency_key,
        settled_by=instruction.scheduled_at + instruction.settlement_window,
        amount=instruction.amount,
        unique_scope_count=len(instruction.scopes),
        signature_byte_len=len(instruction.signature_der),
        retry_limit=instruction.retry_limit,
        explicit_fields=sorted(instruction.model_fields_set),
    )


@app.post("/consents/preferences")
async def submit_consent_form(
    accept_terms: Annotated[bool, Form(description="Mandatory TOS checkbox")],
    marketing_opt_in: Annotated[bool, Form()] = False,
    nickname: Annotated[str | None, Form()] = None,
) -> dict[str, Any]:
    return {
        "accept_terms": accept_terms,
        "marketing_opt_in": marketing_opt_in,
        "nickname": nickname,
    }
```

基本的なパラメータ分類規則や出力 DTO の直列化については [Path・Query・Header・Cookie・Body](parameters_and_validation.md) および [レスポンス直列化と OpenAPI 3.1](responses_and_openapi.md) を参照してください。続いて、Pydantic が JSON を解析する**前**に `gzip` リクエストボディの解凍や Webhook の HMAC 署名検証を行う手法を [カスタム Request と APIRoute 拡張](custom_request_and_route.md) で解説します。
