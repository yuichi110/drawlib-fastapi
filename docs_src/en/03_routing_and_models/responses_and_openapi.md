# Response Serialization, Status Codes & OpenAPI 3.1

FastAPI enforces outbound API contracts through `serialize_response()`—filtering sensitive fields and emitting UTF-8 JSON bytes in a single Pydantic v2 Rust pass—while lazily synthesizing OpenAPI 3.1.0 specifications with split input/output JSON Schema 2020-12 definitions.

```drawlib align=center code=fold file=response_serialization_pipeline.png caption="Outbound Execution & Serialization Pipeline inside get_request_handler() and serialize_response()"
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
    "Outbound Response Pipeline: serialize_response() & Rust TypeAdapter Fast Path",
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
macro.add("2. Branch Check", description="Response vs Field", style=Styles.PrimaryNeutral)
macro.add(
    "3. Validate & Strip",
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
    "• async def: inline\n• def: threadpool\n• Captures mutated\n  response.headers\n• Attaches solved\n  BackgroundTasks",
    style=Styles.Dark.patch(text_size=10.0),
)

# Track A (Top, y=53): Rust Fast-Path Serialization
# Track B (Middle, y=34): jsonable_encoder Fallback
# Track C (Bottom, y=15): Direct Response Subclass Bypass
tracks = [
    (
        53,
        ("route.response_field", "field.validate() + strip", Styles.White, False),
        ("TypeAdapter.dump_json()", "exclude_unset / by_alias", Styles.PrimaryFlat, True),
        ("Response(bytes)", "Merges response.headers", Styles.SecondaryNeutral, False),
    ),
    (
        34,
        ("response_field is None", "Unconstrained return", Styles.Neutral, False),
        ("jsonable_encoder()", "Python dict conversion", Styles.White, False),
        ("JSONResponse", "Merges response.headers", Styles.SecondaryNeutral, False),
    ),
    (
        15,
        ("isinstance(Response)", "304 / File / Custom", Styles.Neutral, False),
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

Decoupling internal persistence models from outbound DTOs prevents accidental credential leaks while maximizing serialization throughput via Pydantic's compiled Rust core.

## 1. Outbound Serialization Pipeline (`serialize_response`)

During route initialization (`_populate_api_route_state()` in `fastapi/routing.py`), FastAPI determines `route.response_field` according to a strict precedence chain:

| Declaration Pattern | `route.response_field` | Runtime Serialization Path in `get_request_handler()` |
| :--- | :--- | :--- |
| `@app.get(..., response_model=PublicDTO)` | `ModelField(mode="serialization")` | Overrides return annotation; validates & runs Rust `TypeAdapter.dump_json()` |
| `async def ep(...) -> PublicDTO:` (no `response_model`) | `ModelField(mode="serialization")` | Return annotation promoted automatically to `response_model` |
| `@app.get(..., response_model=None)` or `-> Response` | `None` | Skips `ModelField` creation; allows `Response | dict` unions |
| Endpoint returns `isinstance(val, Response)` at runtime | *(Bypassed)* | Sends `Response` directly; skips `serialize_response()` |

When `route.response_field` exists and `response_class` remains the default `JSONResponse` (`DefaultPlaceholder`), `get_request_handler()` activates `use_dump_json = True`:

1. **Contract Validation & Security Filtering**: `serialize_response()` validates the returned object (`ORM` entity, `BaseModel`, or `dict`) via `field.validate(..., loc=("response",))` using `from_attributes=True` (executed inline for `async def` routes or via `run_in_threadpool` for sync `def` routes). Unlisted fields—such as `hashed_password` or `totp_secret`—are stripped, and contract mismatches raise a server-side `ResponseValidationError` (`500`) rather than leaking malformed payloads.
2. **One-Pass Rust JSON Bytes (`dump_json`)**: Instead of converting models to intermediate Python dictionaries and calling `json.dumps()`, `field.serialize_json()` invokes `TypeAdapter.dump_json()` with `include`, `exclude`, `by_alias`, `exclude_unset`, `exclude_defaults`, and `exclude_none`, wrapping the resulting UTF-8 `bytes` directly in `Response(media_type="application/json")`.
3. **Status-Code Body Rules & Header Merging**: Any headers or cookies recorded on an injected `response: Response` dependency parameter (`solved_result.response.headers.raw`) are appended onto the final response, and bodyless HTTP statuses (`204`, `205`, `304`, `1xx`) enforce `response.body = b""`.

### Security Field Stripping & Sparse PATCH (`exclude_unset`)

Pairing an internal database model with `response_model=UserPublic` guarantees secret fields never cross the wire, while `response_model_exclude_unset=True` omits default fields that were not explicitly populated in partial `PATCH` payloads:

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

### Injected `Response` Mutation vs Direct `Response` Bypass

Inject `response: Response` as a parameter whenever you need custom headers or hardened cookies (`__Host-` prefix, `httponly=True`, `secure=True`, `samesite="lax"`) **while retaining `response_model` filtering**. Return a raw `Response` instance (with `response_model=None` if mixed with other return types) only when intentionally bypassing serialization—such as `304 Not Modified` cache hits:

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

## 2. Lazy OpenAPI 3.1.0 Synthesis & Split Input/Output Schemas

Rather than slowing down process boot, `FastAPI.openapi()` (`fastapi/applications.py`) synthesizes the OpenAPI `3.1.0` specification lazily on the first `/openapi.json` or `app.openapi()` call and caches it against `router._get_routes_version()` (`_openapi_routes_version`). If dynamic routers or webhooks are mounted later, the route version counter increments and automatically invalidates the cached dictionary.

Inside `get_openapi()` (`fastapi/openapi/utils.py`):

1. **Field Harvesting (`get_fields_from_routes`)**: Walks every included `APIRoute` and webhook context, collecting `body_field` (`mode="validation"`), `response_field`, status-keyed `response_fields` from `responses={...}`, `stream_item_field` (`mode="serialization"`), callbacks, and flattened `Dependant` parameters.
2. **Split Input/Output JSON Schema 2020-12 (`get_definitions`)**: With `separate_input_output_schemas=True` (default), FastAPI feeds both `"validation"` and `"serialization"` `CoreSchema` entries into Pydantic's `GenerateJsonSchema(ref_template="#/components/schemas/{model}")`. Whenever a model's input and output representations differ—such as `Decimal` fields (accepting `number | string` on input, emitting exact `string` on output), `@computed_field` properties, or `serialization_alias`—OpenAPI automatically emits distinct `<Model>-Input` and `<Model>-Output` component schemas.
3. **Operation & Error Merging (`get_openapi_path`)**: Deduplicates parameters across shared dependencies, binds `operationId`, merges custom `responses={404: ..., 409: ...}` via `deep_dict_update()`, and auto-injects `422` (`HTTPValidationError`) whenever parameters or request bodies exist.

```drawlib align=center code=fold file=openapi_31_synthesis_flow.png caption="Lazy OpenAPI 3.1.0 Synthesis: _openapi_routes_version Cache, Split Input/Output Schemas & Path Assembly"
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
flow.add("1. Version Cache", description="_openapi_routes_version")
flow.add("2. Field Harvest", description="get_fields_from_routes()", style=Styles.PrimaryNeutral)
flow.add(
    "3. Split Schemas",
    description="GenerateJsonSchema 2020-12",
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
)
flow.add("4. Path Assembly", description="get_openapi_path() -> 3.1.0", style=Styles.SecondaryNeutral)
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
text((45, 48.7), "Pydantic v2 GenerateJsonSchema", style=Styles.DarkBold.patch(text_size=10.5))
text((45, 44.2), "Evaluates mode='validation' vs mode='serialization'", style=Styles.Dark.patch(text_size=10.0))

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
    "Operation Assembly (get_openapi_path)",
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
    "Versioned Schema Cache",
    "O(1) hit; invalidates on\n_get_routes_version() bump",
    badge_text="O(1)",
)
ops.add(
    "Custom Status Merging",
    "responses={404, 409} merged\nvia deep_dict_update()",
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

### Documenting Error Contracts & Verifying Split OpenAPI 3.1 Schemas

Passing `responses={404: {"model": ErrorDetail}, 409: {"model": ErrorDetail}}` registers typed error schemas alongside `status_code=201`, while `Decimal` on `SkuSpec` triggers `SkuSpec-Input` and `SkuSpec-Output` in `app.openapi()`:

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

For inbound parameter and multipart body classification, revisit [Path, Query, Header, Cookie & Body](parameters_and_validation.md). Next, explore how FastAPI resolves hierarchical `Depends()` graphs in [Dependant DAG, Caching & Scopes](../04_dependencies_and_security/dependency_injection.md), or how `itemSchema` powers streaming OpenAPI contracts in [Native SSE, JSONL & WebSockets](../05_async_and_realtime/sse_websockets_streaming.md).
