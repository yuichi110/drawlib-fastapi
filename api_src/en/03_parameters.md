# fastapi.params

The `fastapi.params` and `fastapi.param_functions` modules (re-exported directly from `fastapi`) provide declarative parameter descriptors—`Path()`, `Query()`, `Header()`, `Cookie()`, `Body()`, `Form()`, and `File()`—built atop Pydantic v2 `FieldInfo`, alongside `annotated_doc.Doc()` for `typing.Annotated` (`PEP 593` / `PEP 727`) parameter metadata.

```drawlib align=center code=hide file=fastapi_parameter_descriptors.png caption="FastAPI Request Parameter Descriptors & Annotated Metadata (Path, Query, Header, Cookie, Body, Form, File & Doc)"
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

Declares a **required URL path segment** parameter (`from fastapi import Path`), returning a `fastapi.params.Path` (`ParamTypes.path`) descriptor at runtime while typing as `Any` for static type-checker compatibility inside `Annotated[T, Path(...)]`. Path parameters are always required even if a default is omitted.

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

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `default` | `Any` | `...` | Must remain `...` (`Ellipsis`); passing any other default raises `AssertionError` because URL path segments are always required. |
| `default_factory` | `Callable[[], Any] \| None` | `_Unset` | Compatibility parameter with `FieldInfo`; unused for always-required `Path` segments. |
| `alias` | `str \| None` | `_Unset` | Alternative template name extracted from the URL path and emitted in OpenAPI. |
| `alias_priority` | `int \| None` | `_Unset` | Alias precedence integer passed to Pydantic `FieldInfo`. |
| `validation_alias` / `serialization_alias` | `str \| AliasPath \| AliasChoices \| None` / `str \| None` | `_Unset` | Dedicated Pydantic input-validation or output-serialization alias overrides. |
| `title` / `description` | `str \| None` | `_Unset` | Human-readable parameter title and description emitted in OpenAPI / JSON Schema. |
| `gt`, `ge`, `lt`, `le` | `float \| None` | `None` | Numeric lower/upper bounds (`>`, `>=`, `<`, `<=`) enforced during validation. |
| `multiple_of`, `allow_inf_nan`, `max_digits`, `decimal_places` | `float \| bool \| int \| None` | `_Unset` | Numeric divisor, IEEE `inf`/`nan`, and `Decimal` precision constraints. |
| `min_length`, `max_length` | `int \| None` | `None` | Minimum and maximum character (or collection) length constraints. |
| `pattern` | `str \| re.Pattern[str] \| None` | `None` | Regular expression constraint (`regex` is deprecated since FastAPI `0.100.0`). |
| `discriminator`, `strict`, `validate_default`, `union_mode`, `fail_fast` | `...` | `_Unset` | Pydantic v2 tagged-union, strict coercion, union evaluation order (`"smart"` / `"left_to_right"`), and collection fail-fast controls. |
| `examples` / `openapi_examples` | `list[Any] \| None` / `dict[str, Example] \| None` | `_Unset` / `None` | JSON Schema `examples` list or named OpenAPI `Example` objects rendered in Swagger UI (`example` is deprecated). |
| `deprecated` | `deprecated \| str \| bool \| None` | `_Unset` | Marks the parameter as deprecated in OpenAPI (`True` or deprecation message). |
| `include_in_schema` | `bool` | `True` | Controls whether this parameter is documented in the generated OpenAPI schema. |
| `json_schema_extra` | `dict[str, Any] \| Callable \| None` | `_Unset` | Extra JSON Schema keys or schema mutator hook passed to Pydantic. |

### Example

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

Declares a **URL query string** parameter (`from fastapi import Query`), supporting scalar types, `list[str]` multi-value query parameters (`?tag=a&tag=b`), and Pydantic `BaseModel` filter models (`Annotated[FilterParams, Query()]`).

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

### Key Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `default` | `Any` | `Undefined` | Default value when omitted from the URL query string (prefer standard Python defaults with `Annotated[int, Query(ge=0)] = 0`). |
| `default_factory` | `Callable[[], Any] \| None` | `_Unset` | Zero-argument factory generating dynamic default values per request (such as `list`). |
| `alias` | `str \| None` | `_Unset` | Query key name in the URL when it differs from the Python identifier (e.g., `alias="item-query"`). |
| Validation & OpenAPI kwargs | `...` | *(Same as `Path()`)* | Supports all numeric (`gt`..`le`, `multiple_of`), string (`min_length`, `max_length`, `pattern`), collection (`fail_fast`), and OpenAPI (`examples`, `openapi_examples`, `deprecated`, `include_in_schema`) options. |

### Example

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

Declares an **HTTP request header** parameter (`from fastapi import Header`). Automatically normalizes Python underscores (`x_request_id`) to standard HTTP hyphens (`x-request-id`) case-insensitively unless `convert_underscores=False`, and supports `list[str]` for duplicate headers or Pydantic `BaseModel` header groups.

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

### Key Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `convert_underscores` | `bool` | `True` | Converts `_` in parameter names (such as `user_agent`) to `-` (`user-agent`) during header extraction and OpenAPI generation. |
| `default` / `alias` | `Any` / `str \| None` | `Undefined` / `_Unset` | Optional fallback value and explicit header name override. |
| Validation & OpenAPI kwargs | `...` | *(Same as `Query()`)* | Full Pydantic v2 numeric/string constraints and OpenAPI documentation metadata. |

### Example

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

Declares an **HTTP `Cookie` parameter** (`from fastapi import Cookie`), extracting and validating individual cookie values or a structured Pydantic `BaseModel` of cookies.

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

### Key Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `default` | `Any` | `Undefined` | Default value if the cookie is absent from the incoming `Cookie` header. |
| `alias` | `str \| None` | `_Unset` | Exact cookie key when it contains characters invalid in Python identifiers (e.g., `"__Host-sid"`). |
| Validation & OpenAPI kwargs | `...` | *(Same as `Query()`)* | Full Pydantic v2 validation constraints and OpenAPI parameter metadata. |

### Example

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

Declares a **JSON request body** parameter (`from fastapi import Body`). Distinguishes scalar values (`int`, `str`) from query parameters so they are read from the JSON body, controls single-model key wrapping via `embed=True`, and attaches `openapi_examples` or validation rules to Pydantic body payloads.

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

### Unique Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `embed` | `bool \| None` | `None` | When `True`, wraps even a single `Body` parameter inside a top-level JSON object keyed by the parameter name (`{"item": {...}}`). Enabled automatically when multiple `Body` parameters are declared. |
| `media_type` | `str` | `"application/json"` | Request body MIME type documented in the generated OpenAPI `requestBody.content` map. |
| Validation & OpenAPI kwargs | `...` | *(Same as `Query()`)* | Supports `examples`, `openapi_examples`, numeric/string bounds, `discriminator`, and `strict`. |

### Example

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

Declares an **HTML form field** or Pydantic form model (`from fastapi import Form`), parsed via `python-multipart` using `application/x-www-form-urlencoded` by default (or `multipart/form-data` when combined with `File()` parameters in the same endpoint).

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

### Key Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `media_type` | `str` | `"application/x-www-form-urlencoded"` | Form encoding media type emitted in OpenAPI (`multipart/form-data` when paired with `File()`). |
| `default` / `alias` | `Any` / `str \| None` | `Undefined` / `_Unset` | Optional field default and form field alias name. |
| Validation & OpenAPI kwargs | `...` | *(Same as `Query()`)* | Supports all Pydantic v2 scalar/model constraints and OpenAPI documentation fields. |

### Example

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

Declares a **multipart file upload** parameter (`from fastapi import File`, subclassing `Form` with `media_type="multipart/form-data"`). Pair with `UploadFile` (spooled temporary file streaming with filename and content-type metadata) or `bytes` (in-memory small payloads), as well as `list[UploadFile]` for multi-file uploads.

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

### Key Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `media_type` | `str` | `"multipart/form-data"` | Multipart form encoding used for binary file uploads (`python-multipart` required). |
| `max_length` / `description` | `int \| None` / `str \| None` | `None` / `_Unset` | Byte length cap (for `bytes` uploads) and OpenAPI upload field description. |
| `default` | `Any` | `Undefined` | Set `= None` on `Annotated[UploadFile | None, File()] = None` for optional file uploads. |

### Example

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

Inline documentation metadata marker (`from annotated_doc import Doc`, `PEP 727`) designed for `typing.Annotated[T, Doc("...")]`. FastAPI uses `Doc()` throughout its own public signatures for IDE hover tooltips and extracts `Doc()` descriptions on endpoint parameters when `description=` is not separately specified on `Query()`, `Path()`, `Header()`, `Cookie()`, or `Body()`.

```python
from annotated_doc import Doc

class Doc:
    documentation: str

    def __init__(self, documentation: str, /) -> None: ...
```

### Parameters & Attributes

| Name | Type | Description |
| :--- | :--- | :--- |
| `documentation` | `str` *(positional-only)* | Documentation string literal attached to the `Annotated` type annotation and stored on `self.documentation`. |

### Example

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
