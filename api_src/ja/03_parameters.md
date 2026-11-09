# fastapi.params

`fastapi.params` および `fastapi.param_functions` モジュール（`fastapi` 直下にも再エクスポート）は、Pydantic v2 の `FieldInfo` を基盤とする宣言的パラメータ記述子 `Path()`・`Query()`・`Header()`・`Cookie()`・`Body()`・`Form()`・`File()` と、`typing.Annotated`（`PEP 593` / `PEP 727`）向けのインライン説明メタデータ `annotated_doc.Doc()` を提供します。

```drawlib align=center code=hide file=fastapi_parameter_descriptors.png caption="FastAPI リクエストパラメータ記述子と Annotated メタデータ（Path, Query, Header, Cookie, Body, Form, File, Doc）"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Colors, Styles

setup(width=184, height=84)

_ = Colors

left_panel = Panel(
    "1. URL & Header Extractors",
    "",
    style=Styles.PrimaryNeutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.0),
    icon=phosphor.sliders_horizontal,
    icon_style=Styles.WhiteBold,
    header_variant="filled",
    header_height=8.5,
)
left_panel.draw((4.0, 4.0), width=85.5, height=76.0, align="bottom_left")
l_xy, l_w, l_h = left_panel.get_content_box(
    (4.0, 4.0),
    width=85.5,
    height=76.0,
    padding=(3.0, 3.0),
    align="bottom_left",
)

left_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.8),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.PrimaryNeutral,
    icon_style=Styles.PrimaryBold,
    direction="vertical",
    spacing=2.4,
)
left_cards.add(
    "Path(...)",
    "Required URL template segment ({item_id})",
    icon=phosphor.signpost,
    badge_style=Styles.PrimaryFlat,
    icon_style=Styles.WhiteBold,
)
left_cards.add(
    "Query(...)",
    "URL query string (?skip=0&limit=20)",
    icon=phosphor.magnifying_glass,
)
left_cards.add(
    "Header(...)",
    "HTTP header (auto underscore-to-hyphen)",
    icon=phosphor.list_bullets,
)
left_cards.add(
    "Cookie(...)",
    "Cookie header key-value or Pydantic model",
    icon=phosphor.cookie,
)
left_cards.draw(l_xy, width=l_w, height=l_h, align="bottom_left")

right_panel = Panel(
    "2. Body, Forms & Metadata",
    "",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.brackets_curly,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
right_panel.draw((94.5, 4.0), width=85.5, height=76.0, align="bottom_left")
r_xy, r_w, r_h = right_panel.get_content_box(
    (94.5, 4.0),
    width=85.5,
    height=76.0,
    padding=(3.0, 3.0),
    align="bottom_left",
)

right_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.8),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.PrimaryNeutral,
    icon_style=Styles.PrimaryBold,
    direction="vertical",
    spacing=2.4,
)
right_cards.add(
    "Body(...)",
    "JSON payload field (application/json)",
    icon=phosphor.brackets_curly,
)
right_cards.add(
    "Form(...)",
    "Form payload (x-www-form-urlencoded)",
    icon=phosphor.textbox,
)
right_cards.add(
    "File(...)",
    "Multipart upload (bytes | UploadFile)",
    icon=phosphor.file_arrow_up,
)
right_cards.add(
    "Annotated[T, Doc(...)]",
    "Inline PEP 727 parameter documentation",
    icon=phosphor.note_pencil,
)
right_cards.draw(r_xy, width=r_w, height=r_h, align="bottom_left")

save()
```

---

## `def` Path()

**必須の URL パスセグメント**パラメータを宣言する関数です（`from fastapi import Path`）。実行時には `fastapi.params.Path`（`ParamTypes.path`）記述子を返しつつ、`Annotated[T, Path(...)]` 内で静的型チェッカーと調和するよう戻り値型は `Any` として定義されています。パスパラメータは常に必須です。

```python
from fastapi import Path

def Path(
    default: Any = ...,
    *,
    default_factory: Callable[[], Any] | None = _Unset,
    alias: str | None = _Unset,
    alias_priority: int | None = _Unset,
    validation_alias: str | AliasPath | AliasChoices | None = _Unset,
    serialization_alias: str | None = _Unset,
    title: str | None = _Unset,
    description: str | None = _Unset,
    gt: float | None = None,
    ge: float | None = None,
    lt: float | None = None,
    le: float | None = None,
    min_length: int | None = None,
    max_length: int | None = None,
    pattern: str | re.Pattern[str] | None = None,
    regex: str | None = None,  # deprecated
    discriminator: str | Discriminator | None = _Unset,
    strict: bool | None = _Unset,
    validate_default: bool | None = _Unset,
    union_mode: Literal["smart", "left_to_right"] | None = _Unset,
    fail_fast: bool | None = _Unset,
    multiple_of: float | None = _Unset,
    allow_inf_nan: bool | None = _Unset,
    max_digits: int | None = _Unset,
    decimal_places: int | None = _Unset,
    examples: list[Any] | None = _Unset,
    example: Any | None = _Unset,  # deprecated
    openapi_examples: dict[str, Example] | None = None,
    deprecated: deprecated | str | bool | None = _Unset,
    include_in_schema: bool = True,
    json_schema_extra: dict[str, Any] | Callable[[dict[str, Any]], None] | None = _Unset,
) -> Any: ...
```

### 引数

| 引数 | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `default` | `Any` | `...` | 常に `...`（`Ellipsis`）である必要があります。URL パスセグメントは必須であるため、他のデフォルト値を渡すと `AssertionError` が送出されます。 |
| `default_factory` | `Callable[[], Any] \| None` | `_Unset` | `FieldInfo` 互換用パラメータ（常に必須の `Path` パラメータでは使用されません）。 |
| `alias` | `str \| None` | `_Unset` | URL パステンプレートからの抽出および OpenAPI スキーマ出力に使われる別名。 |
| `alias_priority` | `int \| None` | `_Unset` | Pydantic `FieldInfo` へ渡されるエイリアス優先度。 |
| `validation_alias` / `serialization_alias` | `str \| AliasPath \| AliasChoices \| None` / `str \| None` | `_Unset` | Pydantic の入力検証時・出力シリアライズ時専用のエイリアス指定。 |
| `title` / `description` | `str \| None` | `_Unset` | OpenAPI / JSON Schema に出力される人間向けのタイトルおよび説明文。 |
| `gt`, `ge`, `lt`, `le` | `float \| None` | `None` | 数値パラメータに対する大小比較制約（`>`、`>=`、`<`、`<=`）。 |
| `multiple_of`, `allow_inf_nan`, `max_digits`, `decimal_places` | `float \| bool \| int \| None` | `_Unset` | 倍数制約、`inf`/`nan` 許容設定、および `Decimal` の桁数・小数点以下桁数制約。 |
| `min_length`, `max_length` | `int \| None` | `None` | 文字列長（またはコレクション要素数）の最小値・最大値制約。 |
| `pattern` | `str \| re.Pattern[str] \| None` | `None` | 文字列に対する正規表現パターン制約（`regex` は FastAPI `0.100.0` 以降非推奨）。 |
| `discriminator`, `strict`, `validate_default`, `union_mode`, `fail_fast` | `...` | `_Unset` | Pydantic v2 のタグ付き Union 判別子、厳格型検査、Union 評価順序（`"smart"` / `"left_to_right"`）、コレクション即時失敗モード。 |
| `examples` / `openapi_examples` | `list[Any] \| None` / `dict[str, Example] \| None` | `_Unset` / `None` | JSON Schema の `examples` リスト、または Swagger UI で選択表示できる名前付き OpenAPI `Example` 辞書（`example` は非推奨）。 |
| `deprecated` | `deprecated \| str \| bool \| None` | `_Unset` | パラメータを OpenAPI 上で非推奨としてマークします（`True` または非推奨メッセージ）。 |
| `include_in_schema` | `bool` | `True` | このパラメータを自動生成される OpenAPI スキーマに含めるかどうか。 |
| `json_schema_extra` | `dict[str, Any] \| Callable \| None` | `_Unset` | 生成される JSON Schema に追加する拡張プロパティ辞書またはスキーマ変更関数。 |

### 使用例

```python
from typing import Annotated
from fastapi import FastAPI, Path

app = FastAPI()


@app.get("/items/{item_id}")
def get_item(
    item_id: Annotated[int, Path(title="Item ID", ge=1, le=1_000_000)],
) -> dict[str, int]:
    return {"item_id": item_id}
```

---

## `def` Query()

**URL クエリ文字列**パラメータを宣言する関数です（`from fastapi import Query`）。単一スカラー型、`list[str]` などの複数値クエリ（`?tag=a&tag=b`）、および Pydantic `BaseModel` を用いた構造化フィルタモデル（`Annotated[FilterParams, Query()]`）に対応しています。

```python
from fastapi import Query

def Query(
    default: Any = Undefined,
    *,
    default_factory: Callable[[], Any] | None = _Unset,
    alias: str | None = _Unset,
    alias_priority: int | None = _Unset,
    validation_alias: str | AliasPath | AliasChoices | None = _Unset,
    serialization_alias: str | None = _Unset,
    title: str | None = _Unset,
    description: str | None = _Unset,
    gt: float | None = None,
    ge: float | None = None,
    lt: float | None = None,
    le: float | None = None,
    min_length: int | None = None,
    max_length: int | None = None,
    pattern: str | re.Pattern[str] | None = None,
    regex: str | None = None,  # deprecated
    discriminator: str | Discriminator | None = _Unset,
    strict: bool | None = _Unset,
    validate_default: bool | None = _Unset,
    union_mode: Literal["smart", "left_to_right"] | None = _Unset,
    fail_fast: bool | None = _Unset,
    multiple_of: float | None = _Unset,
    allow_inf_nan: bool | None = _Unset,
    max_digits: int | None = _Unset,
    decimal_places: int | None = _Unset,
    examples: list[Any] | None = _Unset,
    example: Any | None = _Unset,  # deprecated
    openapi_examples: dict[str, Example] | None = None,
    deprecated: deprecated | str | bool | None = _Unset,
    include_in_schema: bool = True,
    json_schema_extra: dict[str, Any] | Callable[[dict[str, Any]], None] | None = _Unset,
) -> Any: ...
```

### 主な引数

| 引数 | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `default` | `Any` | `Undefined` | クエリ文字列省略時の既定値（`Annotated[int, Query(ge=0)] = 0` のように Python 引数のデフォルト値で指定する書き方が推奨されます）。 |
| `default_factory` | `Callable[[], Any] \| None` | `_Unset` | リクエストごとに動的なデフォルト値を生成する引数なしファクトリ関数（`list` 等）。 |
| `alias` | `str \| None` | `_Unset` | Python 識別子として使えない文字を含む URL クエリキーの別名（例: `alias="item-query"`）。 |
| 検証・OpenAPI 引数群 | `...` | *(`Path()` と同一)* | 数値境界（`gt`..`le`、`multiple_of`）、文字列制約（`min_length`、`max_length`、`pattern`）、コレクション（`fail_fast`）、OpenAPI 設定（`examples`、`openapi_examples`、`deprecated`、`include_in_schema`）をすべてサポートします。 |

### 使用例

```python
from typing import Annotated
from fastapi import FastAPI, Query

app = FastAPI()


@app.get("/search")
def search_items(
    q: Annotated[str | None, Query(min_length=2, max_length=50, pattern=r"^[a-zA-Z0-9_-]+$")] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
) -> dict[str, str | int | None]:
    return {"q": q, "limit": limit}
```

---

## `def` Header()

**HTTP リクエストヘッダ**パラメータを宣言する関数です（`from fastapi import Header`）。既定で Python 引数名のアンダースコア（`x_request_id`）を大文字小文字を区別しない標準 HTTP ハイフン形式（`x-request-id`）へ自動変換し、重複ヘッダ用の `list[str]` や Pydantic `BaseModel` ヘッダモデルにも対応します。

```python
from fastapi import Header

def Header(
    default: Any = Undefined,
    *,
    default_factory: Callable[[], Any] | None = _Unset,
    alias: str | None = _Unset,
    alias_priority: int | None = _Unset,
    validation_alias: str | AliasPath | AliasChoices | None = _Unset,
    serialization_alias: str | None = _Unset,
    convert_underscores: bool = True,
    title: str | None = _Unset,
    description: str | None = _Unset,
    gt: float | None = None,
    ge: float | None = None,
    lt: float | None = None,
    le: float | None = None,
    min_length: int | None = None,
    max_length: int | None = None,
    pattern: str | re.Pattern[str] | None = None,
    regex: str | None = None,  # deprecated
    discriminator: str | Discriminator | None = _Unset,
    strict: bool | None = _Unset,
    validate_default: bool | None = _Unset,
    union_mode: Literal["smart", "left_to_right"] | None = _Unset,
    fail_fast: bool | None = _Unset,
    multiple_of: float | None = _Unset,
    allow_inf_nan: bool | None = _Unset,
    max_digits: int | None = _Unset,
    decimal_places: int | None = _Unset,
    examples: list[Any] | None = _Unset,
    example: Any | None = _Unset,  # deprecated
    openapi_examples: dict[str, Example] | None = None,
    deprecated: deprecated | str | bool | None = _Unset,
    include_in_schema: bool = True,
    json_schema_extra: dict[str, Any] | Callable[[dict[str, Any]], None] | None = _Unset,
) -> Any: ...
```

### 主な引数

| 引数 | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `convert_underscores` | `bool` | `True` | 引数名に含まれる `_`（例: `user_agent`）をヘッダ抽出時および OpenAPI 出力時に `-`（`user-agent`）へ自動変換します。 |
| `default` / `alias` | `Any` / `str \| None` | `Undefined` / `_Unset` | ヘッダ未送信時のフォールバック値およびヘッダ名の明示エイリアス。 |
| 検証・OpenAPI 引数群 | `...` | *(`Query()` と同一)* | Pydantic v2 の数値・文字列バリデーション制約および OpenAPI ドキュメントメタデータ一式。 |

### 使用例

```python
from typing import Annotated
from fastapi import FastAPI, Header

app = FastAPI()


@app.get("/trace")
def read_trace_headers(
    user_agent: Annotated[str | None, Header()] = None,
    x_request_id: Annotated[str, Header(min_length=8)] = "req-default01",
) -> dict[str, str | None]:
    return {"user_agent": user_agent, "request_id": x_request_id}
```

---

## `def` Cookie()

**HTTP `Cookie` パラメータ**を宣言する関数です（`from fastapi import Cookie`）。`Cookie` ヘッダから個別の値を抽出・型検証するほか、Pydantic `BaseModel` による構造化 Cookie グループの検証にも対応しています。

```python
from fastapi import Cookie

def Cookie(
    default: Any = Undefined,
    *,
    default_factory: Callable[[], Any] | None = _Unset,
    alias: str | None = _Unset,
    alias_priority: int | None = _Unset,
    validation_alias: str | AliasPath | AliasChoices | None = _Unset,
    serialization_alias: str | None = _Unset,
    title: str | None = _Unset,
    description: str | None = _Unset,
    gt: float | None = None,
    ge: float | None = None,
    lt: float | None = None,
    le: float | None = None,
    min_length: int | None = None,
    max_length: int | None = None,
    pattern: str | re.Pattern[str] | None = None,
    regex: str | None = None,  # deprecated
    discriminator: str | Discriminator | None = _Unset,
    strict: bool | None = _Unset,
    validate_default: bool | None = _Unset,
    union_mode: Literal["smart", "left_to_right"] | None = _Unset,
    fail_fast: bool | None = _Unset,
    multiple_of: float | None = _Unset,
    allow_inf_nan: bool | None = _Unset,
    max_digits: int | None = _Unset,
    decimal_places: int | None = _Unset,
    examples: list[Any] | None = _Unset,
    example: Any | None = _Unset,  # deprecated
    openapi_examples: dict[str, Example] | None = None,
    deprecated: deprecated | str | bool | None = _Unset,
    include_in_schema: bool = True,
    json_schema_extra: dict[str, Any] | Callable[[dict[str, Any]], None] | None = _Unset,
) -> Any: ...
```

### 主な引数

| 引数 | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `default` | `Any` | `Undefined` | 受信 `Cookie` ヘッダに対象キーが含まれない場合の既定値。 |
| `alias` | `str \| None` | `_Unset` | Python 識別子に使えない記号を含む Cookie 名の指定（例: `"__Host-sid"`）。 |
| 検証・OpenAPI 引数群 | `...` | *(`Query()` と同一)* | Pydantic v2 の全バリデーション制約および OpenAPI パラメータメタデータ。 |

### 使用例

```python
from typing import Annotated
from fastapi import Cookie, FastAPI

app = FastAPI()


@app.get("/preferences")
def get_preferences(
    theme: Annotated[str, Cookie(pattern=r"^(light|dark)$")] = "light",
) -> dict[str, str]:
    return {"theme": theme}
```

---

## `def` Body()

**JSON リクエストボディ**パラメータを宣言する関数です（`from fastapi import Body`）。`int` や `str` などのスカラー引数をクエリパラメータではなく JSON ボディから抽出させたり、単一モデルを `embed=True` でトップレベルキー配下にラップしたり、Pydantic ボディモデルへ `openapi_examples` やバリデーション制約を追加する際に使用します。

```python
from fastapi import Body

def Body(
    default: Any = Undefined,
    *,
    default_factory: Callable[[], Any] | None = _Unset,
    embed: bool | None = None,
    media_type: str = "application/json",
    alias: str | None = _Unset,
    alias_priority: int | None = _Unset,
    validation_alias: str | AliasPath | AliasChoices | None = _Unset,
    serialization_alias: str | None = _Unset,
    title: str | None = _Unset,
    description: str | None = _Unset,
    gt: float | None = None,
    ge: float | None = None,
    lt: float | None = None,
    le: float | None = None,
    min_length: int | None = None,
    max_length: int | None = None,
    pattern: str | re.Pattern[str] | None = None,
    regex: str | None = None,  # deprecated
    discriminator: str | Discriminator | None = _Unset,
    strict: bool | None = _Unset,
    validate_default: bool | None = _Unset,
    union_mode: Literal["smart", "left_to_right"] | None = _Unset,
    fail_fast: bool | None = _Unset,
    multiple_of: float | None = _Unset,
    allow_inf_nan: bool | None = _Unset,
    max_digits: int | None = _Unset,
    decimal_places: int | None = _Unset,
    examples: list[Any] | None = _Unset,
    example: Any | None = _Unset,  # deprecated
    openapi_examples: dict[str, Example] | None = None,
    deprecated: deprecated | str | bool | None = _Unset,
    include_in_schema: bool = True,
    json_schema_extra: dict[str, Any] | Callable[[dict[str, Any]], None] | None = _Unset,
) -> Any: ...
```

### 固有の引数

| 引数 | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `embed` | `bool \| None` | `None` | `True` の場合、`Body` パラメータが 1 つだけでも引数名をキーとする JSON オブジェクト（`{"item": {...}}`）として受け取ります（複数 `Body` 宣言時は自動有効化）。 |
| `media_type` | `str` | `"application/json"` | 生成される OpenAPI の `requestBody.content` に記載されるリクエスト MIME タイプ。 |
| 検証・OpenAPI 引数群 | `...` | *(`Query()` と同一)* | `examples`、`openapi_examples`、数値・文字列境界、`discriminator`、`strict` 等をサポートします。 |

### 使用例

```python
from typing import Annotated
from fastapi import Body, FastAPI
from pydantic import BaseModel

app = FastAPI()


class Ticket(BaseModel):
    subject: str


@app.post("/tickets")
def create_ticket(
    ticket: Annotated[Ticket, Body(embed=True)],
    priority: Annotated[int, Body(ge=1, le=5)] = 3,
) -> dict[str, str | int]:
    return {"subject": ticket.subject, "priority": priority}
```

---

## `def` Form()

**HTML フォームフィールド**または Pydantic フォームモデルを宣言する関数です（`from fastapi import Form`）。`python-multipart` を通じて既定の `application/x-www-form-urlencoded`（同じエンドポイント内で `File()` と併用した場合は `multipart/form-data`）として解析されます。

```python
from fastapi import Form

def Form(
    default: Any = Undefined,
    *,
    default_factory: Callable[[], Any] | None = _Unset,
    media_type: str = "application/x-www-form-urlencoded",
    alias: str | None = _Unset,
    alias_priority: int | None = _Unset,
    validation_alias: str | AliasPath | AliasChoices | None = _Unset,
    serialization_alias: str | None = _Unset,
    title: str | None = _Unset,
    description: str | None = _Unset,
    gt: float | None = None,
    ge: float | None = None,
    lt: float | None = None,
    le: float | None = None,
    min_length: int | None = None,
    max_length: int | None = None,
    pattern: str | re.Pattern[str] | None = None,
    regex: str | None = None,  # deprecated
    discriminator: str | Discriminator | None = _Unset,
    strict: bool | None = _Unset,
    validate_default: bool | None = _Unset,
    union_mode: Literal["smart", "left_to_right"] | None = _Unset,
    fail_fast: bool | None = _Unset,
    multiple_of: float | None = _Unset,
    allow_inf_nan: bool | None = _Unset,
    max_digits: int | None = _Unset,
    decimal_places: int | None = _Unset,
    examples: list[Any] | None = _Unset,
    example: Any | None = _Unset,  # deprecated
    openapi_examples: dict[str, Example] | None = None,
    deprecated: deprecated | str | bool | None = _Unset,
    include_in_schema: bool = True,
    json_schema_extra: dict[str, Any] | Callable[[dict[str, Any]], None] | None = _Unset,
) -> Any: ...
```

### 主な引数

| 引数 | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `media_type` | `str` | `"application/x-www-form-urlencoded"` | OpenAPI に出力されるフォームエンコーディング MIME タイプ（`File()` 併用時は `multipart/form-data`）。 |
| `default` / `alias` | `Any` / `str \| None` | `Undefined` / `_Unset` | 省略時のデフォルト値およびフォームフィールドの別名。 |
| 検証・OpenAPI 引数群 | `...` | *(`Query()` と同一)* | Pydantic v2 の全バリデーション制約および OpenAPI ドキュメント項目をサポートします。 |

### 使用例

```python
from typing import Annotated
from fastapi import FastAPI, Form

app = FastAPI()


@app.post("/login")
def login(
    username: Annotated[str, Form(min_length=3)],
    password: Annotated[str, Form(min_length=8)],
) -> dict[str, str]:
    return {"username": username, "authenticated": str(bool(password))}
```

---

## `def` File()

**マルチパートファイルアップロード**パラメータを宣言する関数です（`from fastapi import File`。`media_type="multipart/form-data"` を持つ `Form` サブクラスを生成）。スプール一時ファイル・ファイル名・Content-Type を扱える `UploadFile`（または複数ファイル用の `list[UploadFile]`）、もしくは小容量データ向けの `bytes` と組み合わせて使用します。

```python
from fastapi import File

def File(
    default: Any = Undefined,
    *,
    default_factory: Callable[[], Any] | None = _Unset,
    media_type: str = "multipart/form-data",
    alias: str | None = _Unset,
    alias_priority: int | None = _Unset,
    validation_alias: str | AliasPath | AliasChoices | None = _Unset,
    serialization_alias: str | None = _Unset,
    title: str | None = _Unset,
    description: str | None = _Unset,
    gt: float | None = None,
    ge: float | None = None,
    lt: float | None = None,
    le: float | None = None,
    min_length: int | None = None,
    max_length: int | None = None,
    pattern: str | re.Pattern[str] | None = None,
    regex: str | None = None,  # deprecated
    discriminator: str | Discriminator | None = _Unset,
    strict: bool | None = _Unset,
    validate_default: bool | None = _Unset,
    union_mode: Literal["smart", "left_to_right"] | None = _Unset,
    fail_fast: bool | None = _Unset,
    multiple_of: float | None = _Unset,
    allow_inf_nan: bool | None = _Unset,
    max_digits: int | None = _Unset,
    decimal_places: int | None = _Unset,
    examples: list[Any] | None = _Unset,
    example: Any | None = _Unset,  # deprecated
    openapi_examples: dict[str, Example] | None = None,
    deprecated: deprecated | str | bool | None = _Unset,
    include_in_schema: bool = True,
    json_schema_extra: dict[str, Any] | Callable[[dict[str, Any]], None] | None = _Unset,
) -> Any: ...
```

### 主な引数

| 引数 | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `media_type` | `str` | `"multipart/form-data"` | バイナリファイル送信に使用されるマルチパート MIME タイプ（`python-multipart` が必要）。 |
| `max_length` / `description` | `int \| None` / `str \| None` | `None` / `_Unset` | `bytes` 受け取り時の最大バイト長制約および OpenAPI フィールド説明文。 |
| `default` | `Any` | `Undefined` | 任意アップロードにする場合は `Annotated[UploadFile | None, File()] = None` のように指定します。 |

### 使用例

```python
from typing import Annotated
from fastapi import FastAPI, File, UploadFile

app = FastAPI()


@app.post("/uploads")
async def upload_document(
    document: Annotated[UploadFile, File(description="PDF or CSV report")],
) -> dict[str, str | int]:
    payload = await document.read()
    return {"filename": document.filename or "unnamed", "bytes": len(payload)}
```

---

## `def` annotated_doc.Doc()

`typing.Annotated[T, Doc("...")]` 形式で型アノテーション内に直接ドキュメント文字列を埋め込むメタデータクラスです（`from annotated_doc import Doc`、`PEP 727`）。FastAPI 自身の公開 API シグネチャ全体で IDE ホバー表示のために採用されており、エンドポイント引数でも `Query()`・`Path()`・`Header()`・`Cookie()`・`Body()` 側の `description=` が未指定の場合に説明文として自動抽出されます。

```python
from annotated_doc import Doc

class Doc:
    documentation: str

    def __init__(self, documentation: str, /) -> None: ...
```

### 引数と属性

| 名前 | 型 | 説明 |
| :--- | :--- | :--- |
| `documentation` | `str` *(位置専用引数)* | `Annotated` 型アノテーションに付与され、`self.documentation` に保持される説明文字列リテラル。 |

### 使用例

```python
from typing import Annotated
from annotated_doc import Doc
from fastapi import FastAPI, Query

app = FastAPI()


@app.get("/reports")
def list_reports(
    cursor: Annotated[
        str | None,
        Query(max_length=64),
        Doc("Opaque pagination cursor returned by the previous page."),
    ] = None,
) -> dict[str, str | None]:
    return {"cursor": cursor}
```
