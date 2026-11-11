# Response Serialization, Status Codes & OpenAPI 3.1

FastAPI enforces outbound API contracts through automatic response validation and filtering—stripping sensitive fields and emitting UTF-8 JSON bytes in a single Pydantic v2 Rust pass—while lazily synthesizing OpenAPI 3.1.0 specifications with split input/output JSON Schema 2020-12 definitions.

```drawlib align=center code=hide file=response_serialization_pipeline.png caption="Outbound Response Validation, Filtering & Rust TypeAdapter Serialization Pipeline"
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

Decoupling internal persistence models from outbound DTOs prevents accidental credential leaks while maximizing serialization throughput via Pydantic's compiled Rust core.

## 1. Response Validation, Filtering & Serialization

When registering a path operation, FastAPI resolves the outbound response contract according to a strict precedence chain:

| Declaration Pattern | Active Response Contract | Runtime Serialization Path |
| :--- | :--- | :--- |
| `@app.get(..., response_model=PublicDTO)` | `PublicDTO` (overrides return hint) | Validates & strips fields, then emits UTF-8 bytes via Rust `TypeAdapter.dump_json()` |
| `async def ep(...) -> PublicDTO:` (no `response_model`) | `PublicDTO` (from return annotation) | Return annotation automatically acts as the response validation & OpenAPI contract |
| `@app.get(..., response_model=None)` or `-> Response` | Disabled | Skips response schema validation; allows `Response \| dict` unions and uses `jsonable_encoder()` for plain objects |
| Endpoint returns a `Response` instance at runtime | *(Bypassed for that call)* | Sends the `Response` instance directly without `response_model` filtering |

Whenever a response contract is active and `response_class` remains the default `JSONResponse`, FastAPI executes a streamlined three-step outbound pass:

1. **Contract Validation & Security Filtering**: FastAPI validates the returned object (`ORM` entity, `BaseModel`, or `dict`) against the response model using `from_attributes=True` (inline on the event loop for `async def` routes, or in a worker threadpool for sync `def` routes). Unlisted attributes—such as `hashed_password` or `totp_secret`—are stripped automatically, and contract mismatches raise a server-side `ResponseValidationError` (`500`) rather than leaking malformed payloads.
2. **One-Pass Rust JSON Bytes (`TypeAdapter.dump_json`)**: Instead of building intermediate Python dictionaries and calling `json.dumps()`, FastAPI serializes the validated value directly through Pydantic v2's `TypeAdapter.dump_json()`—applying `response_model_include`, `response_model_exclude`, `response_model_by_alias`, `response_model_exclude_unset`, `response_model_exclude_defaults`, and `response_model_exclude_none`—and wraps the UTF-8 `bytes` directly in `Response(media_type="application/json")`.
3. **Status-Code Body Rules & Header Merging**: Any headers or `Set-Cookie` directives recorded on an injected `response: Response` parameter are merged onto the final response, while bodyless HTTP status codes (`204`, `205`, `304`, `1xx`) always emit an empty body (`b""`).

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

Rather than slowing down application startup, `app.openapi()` synthesizes the OpenAPI `3.1.0` specification lazily on the first `/openapi.json` request (or direct `app.openapi()` call) and caches the generated dictionary in memory. If dynamic routers or webhooks are added later, FastAPI automatically invalidates and rebuilds the cached schema on the next access.

OpenAPI synthesis proceeds through three stages:

1. **Schema Cache & Route Discovery**: FastAPI walks every included `APIRoute` and `@app.webhooks` operation, collecting request body models, primary `response_model` contracts, custom status-code models from `responses={...}`, streaming item schemas, callbacks, and all parameters declared across nested `Depends()` and `Security()` functions.
2. **Split Input/Output JSON Schema 2020-12**: With `separate_input_output_schemas=True` (the default on `FastAPI`), Pydantic v2 generates separate validation and serialization JSON Schemas under `#/components/schemas/`. Whenever a model's input and output representations differ—such as `Decimal` fields (accepting `number | string` on input, emitting exact `string` on output), `@computed_field` properties, or `serialization_alias`—OpenAPI automatically emits distinct `<Model>-Input` and `<Model>-Output` component schemas.
3. **Operation & Error Contract Merging**: FastAPI deduplicates shared dependency parameters, assigns each route's `operationId`, merges custom `responses={404: ..., 409: ...}` definitions alongside the default success `status_code`, and automatically adds `422` (`HTTPValidationError`) whenever parameters or request bodies exist.

```drawlib align=center code=hide file=openapi_31_synthesis_flow.png caption="Lazy OpenAPI 3.1.0 Synthesis: Schema Cache, Route Discovery, Split Input/Output Schemas & Operation Assembly"
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

For inbound parameter and multipart body binding rules, revisit [Path, Query, Header, Cookie & Body](parameters_and_validation.md). Next, explore how FastAPI resolves hierarchical `Depends()` graphs in [Dependency Graph, Caching & Scopes](../04_dependencies_and_security/dependency_injection.md), or how `itemSchema` powers streaming OpenAPI contracts in [Native SSE, JSONL & WebSockets](../05_async_and_realtime/sse_websockets_streaming.md).
