# Parameter Models, Extra Types & Schema Examples

FastAPI `v0.157.0`–`v0.162.2` elevates Pydantic parameter models (`Query()`, `Header()`, `Cookie()`, `Form()`) into composable, optional, and union-capable extractors while enforcing strict JSON `null` vs. omitted semantics, HTML checkbox `Form` defaults, rich standard-library/Pydantic data types, and multi-tier OpenAPI 3.1 examples.

```drawlib align=center code=hide file=parameter_models_composition.png caption="FastAPI v0.157–v0.162 Parameter Model Composition: Multi-Model Extraction, Optional/Union Resolution & Sibling extra='forbid' Rule"
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

Grouping related HTTP inputs into reusable Pydantic `BaseModel` classes keeps endpoint signatures concise while preserving full `@model_validator` invariants across query strings, headers, cookies, and form bodies.

## 1. Composing Parameter Models (`Query`, `Header`, `Cookie`, `Form`)

Across FastAPI `v0.157.0`–`v0.162.2`, `fastapi/dependencies/utils.py` generalizes parameter models from isolated single-model annotations into composable building blocks across endpoints and `Depends()` sub-graphs:

1. **Multi-Model Composition & OpenAPI Flattening**:
   - For `Query()`, `Header()`, and `Cookie()`, `_get_param_model()` unwraps both `Model` and `Model | None`, expanding each model's cached fields via `get_flat_params()` into flat OpenAPI parameter entries while validating each model independently inside `_request_param_model_to_args()`.
   - For `Form()`, `_get_form_models()` composes multiple form models (across both route parameters and `Depends()`) into an OpenAPI `allOf` request body schema and extracts each model's fields independently from the raw `FormData` inside `_extract_form_model()`.
2. **Per-Model `Header(convert_underscores=...)` Isolation**:
   - `_request_param_model_to_args()` resolves `convert_underscores` per `Header()` parameter without mutating `Model.model_fields` in place—allowing the same `BaseModel` to be reused across `Header()`, `Header(convert_underscores=False)`, and `Query()`. When `loc_by_alias=True` (default), validation errors automatically report wire-format hyphenated names (such as `["header", "x-retry-attempt"]`).
3. **Optional (`Model | None = None`) & Discriminated Union `Form()` Models**:
   - Declaring `Annotated[RangeModel | None, Query()] = None` (or `Header()`, `Cookie()`, `Form()`) checks whether *any* alias declared on `RangeModel` appears in the incoming request (`own_names.intersection(received_params)` / `_is_form_model_supplied()`). When completely absent, FastAPI passes `Undefined` so the argument resolves to `None`; when partially supplied (for example `?min_cents=500` without `max_cents`), Pydantic validates the model and raises `422` for the missing sibling field. *(Omitting `= None` keeps the parameter required even if its type union includes `None`.)*
   - Declaring `Annotated[WebhookForm | EmailForm | None, Form(discriminator="channel")] = None` triggers `_add_form_union_validators()`, wrapping each union branch in a `BeforeValidator(_normalize_form_model)` so repeated form entries (`list[str]` vs. scalar `str`) are normalized per branch.
4. **The `v0.160.0` Sibling `extra="forbid"` Rule**:
   - Because query parameters, headers, cookies, and flat HTML forms each occupy a single shared namespace on the wire, `_request_param_model_to_args()` and `_extract_form_items()` forward all unclaimed keys in that location to every parameter model so each model's `model_config["extra"]` policy can execute.

| Composition Pattern | Recommended `extra` Policy | Runtime Behavior in FastAPI `v0.160.0`–`v0.162.2` |
| :--- | :--- | :--- |
| **Single `Query` / `Cookie` / `Form` model** (no sibling params in same location) | `extra="forbid"` or `"ignore"` | Rejects unknown client typos (`422 extra_forbidden`) cleanly |
| **Multiple sibling models** or **model + scalar param / `Depends()`** in same location | `extra="ignore"` *(Pydantic default)* | Each model validates its own fields and ignores sibling keys; setting `extra="forbid"` causes Model A to reject Model B's keys with `422`! |
| **`Header()` parameter model** | `extra="ignore"` *(mandatory in practice)* | Clients always send standard HTTP headers (`host`, `user-agent`, `accept`), which trigger `422 extra_forbidden` under `extra="forbid"` |

> [!WARNING]
> If you need strict unknown-key rejection (`extra="forbid"`) across modular `Query()` or `Form()` slices, combine them via Pydantic multiple inheritance (`class CombinedQuery(PaginationParams, SortParams): model_config = ConfigDict(extra="forbid")`) rather than declaring two separate `extra="forbid"` parameters on the same route. Also define parameter models at module scope so stringified annotations (`from __future__ import annotations`) resolve `BaseModel` subclasses during registration.

### Composing Multi-Model Queries, Optional Headers/Cookies & Union Forms

The following verified application composes a shared `Depends()` pagination model with optional `Query()`, `Header()`, and `Cookie()` models, contrasts them with a single-owner `extra="forbid"` cursor endpoint, and parses an optional discriminated union `Form()`:

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

## 2. Rich Python Types, Strict `null` Semantics & OpenAPI 3.1 Examples

Beyond primitive `int`, `str`, and `bool` scalars, FastAPI and Pydantic v2 compile rich domain types directly into Rust validators and JSON Schema 2020-12 formats while enforcing unambiguous distinctions between **omitted inputs**, **explicit JSON `null`**, and **empty HTML form strings**.

```drawlib align=center code=hide file=extra_types_and_null_semantics.png caption="Extra Types Matrix, v0.151 JSON null vs v0.162 Form Checkbox Semantics & 3-Tier OpenAPI 3.1 Examples"
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

### Key Type & Default Guarantees in `v0.151.0`–`v0.162.2`

1. **Rich Domain Types & Standard `@dataclass` Support**:
   - **`Enum` / `StrEnum`**: Restricts path, query, and body fields to a closed OpenAPI `enum` set (`422` on unlisted values).
   - **`UUID`, `datetime`, `timedelta`, `Decimal`, `frozenset`, `Base64Bytes`**: `timedelta` accepts numeric seconds or ISO-8601 durations (`"PT15M"`); `Decimal` avoids IEEE-754 rounding drift and generates split `-Input` (`number | string`) and `-Output` (`string`) OpenAPI schemas; `frozenset[str]` deduplicates elements into an immutable set with `uniqueItems: true`; `pydantic.Base64Bytes` decodes standard base64 payloads into `bytes`; and standard `@dataclass` classes work directly as request bodies or `response_model` targets via `TypeAdapter` without inheriting `BaseModel`.
2. **`v0.151.0` Explicit JSON `null` vs. Omitted Defaults & `strict_content_type`**:
   - Omitting `"retry_limit"` from a JSON object applies `retry_limit: int = 3` (`"retry_limit" not in model.model_fields_set`). Sending `{"retry_limit": null}`, however, explicitly supplies `None`—which FastAPI `v0.151.0`+ rejects with `422 int_type` unless the annotation explicitly includes `| None` (`int | None = 3`). Likewise, a required `BaseModel` body parameter (`instruction: PayoutInstruction`) rejects an empty body even if every field inside the model has a default.
   - By default (`strict_content_type=True` on `FastAPI`, `APIRouter`, and route decorators), `get_request_handler()` requires an `application/json` or `application/*+json` `Content-Type` header before decoding JSON bytes; pass `strict_content_type=False` only when interoperating with legacy callers that omit `Content-Type`.
3. **`v0.162.0` HTML Form Empty Strings & Omitted Checkboxes**:
   - HTML browsers submit `""` for blank text/numeric inputs and omit unchecked `<input type="checkbox">` fields altogether (sending `"on"` when checked). Inside `_get_multidict_value()`, FastAPI normalizes missing `FormData` keys and empty strings `""` to `Undefined` *before* Pydantic runs:
     - Optional checkboxes (`marketing_opt_in: Annotated[bool, Form()] = False`) evaluate to `False` when omitted and `True` when `"on"` is submitted, while required checkboxes (`accept_terms: Annotated[bool, Form()]`) fail with `422 missing` if unchecked.
4. **3-Tier OpenAPI 3.1 Examples**:
   - Combine property-level `Field(examples=[...])`, schema-level `ConfigDict(json_schema_extra={"examples": [...]})`, and parameter-level `Body(openapi_examples={...})` (`summary`, `description`, `value`) to populate both `components.schemas` and interactive scenario dropdowns in `/docs`.

### Extra Types, Strict Null/Form Defaults & Named OpenAPI Examples

The following verified service combines rich domain types, `@dataclass` response serialization, all three OpenAPI 3.1 example tiers, `v0.151.0` non-nullable JSON defaults, and `v0.162.0` HTML form checkbox handling:

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

For baseline parameter classification rules and outbound DTO serialization, revisit [Path, Query, Header, Cookie & Body](parameters_and_validation.md) and [Response Serialization & OpenAPI 3.1](responses_and_openapi.md). When an API needs to transform raw request streams—such as decompressing `gzip` bodies or verifying webhook HMAC digests *before* Pydantic parses JSON—continue to [Custom Request & APIRoute Classes](custom_request_and_route.md).
