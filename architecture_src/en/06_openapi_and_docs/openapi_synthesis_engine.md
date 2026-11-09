# Lazy `get_openapi()`, JSON Schema `$defs` & Docs UI

FastAPI treats OpenAPI `3.1.0` (backed by JSON Schema Draft `2020-12`) as a first-class compilation target rather than a hand-written YAML artifact. Instead of paying JSON Schema generation costs during Python module import, `FastAPI.openapi()` lazily synthesizes and memoizes the entire document on first access, invalidating the cache automatically whenever routes or included `APIRouter` trees mutate.

```drawlib align=center code=hide file=lazy_openapi_synthesis_pipeline.png caption="Lazy FastAPI.openapi() Version-Gated Cache and the 5-Stage get_openapi() Synthesis Pipeline"
from drawlib.canvas import setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, ChevronProcess, Panel
from drawlib.styles import Colors, Styles

setup(width=180, height=88)

pipeline = ChevronProcess(
    style=Styles.Neutral,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    corner_angle=60.0,
    spacing=1.6,
    flat_left_end=True,
)
pipeline.add("1. Version Gate", description="_get_routes_version")
pipeline.add(
    "2. Harvest Fields",
    description="get_fields_from_routes",
    style=Styles.SecondaryNeutral,
)
pipeline.add(
    "3. Bundle $defs",
    description="GenerateJsonSchema",
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
)
pipeline.add(
    "4. Build Paths",
    description="routes & webhooks",
    style=Styles.PrimaryNeutral,
)
pipeline.add("5. Validate & Cache", description="OpenAPI(**output)")
pipeline.draw(xy=(4.0, 70.0), width=172.0, height=14.0)

cache_panel = Panel(
    "Lazy Cache & Invalidation",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.5),
    icon=phosphor.arrows_clockwise,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.5,
)
cache_panel.draw((4.0, 4.0), width=84.0, height=62.0)
c_xy, c_w, c_h = cache_panel.get_content_box(
    (4.0, 4.0), width=84.0, height=62.0, padding=(3.5, 3.0)
)

cache_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.DarkBold,
    spacing=2.2,
)
cache_cards.add(
    "Zero Import-Time Cost",
    "openapi_schema starts as None at __init__",
    badge_text="Cold",
    icon=phosphor.snowflake,
)
cache_cards.add(
    "Recursive Version Sum",
    "_get_routes_version walks _IncludedRouter",
    badge_text="Ver",
    icon=phosphor.git_merge,
)
cache_cards.add(
    "O(1) Dict Reuse",
    "Returns cached dict until routes mutate",
    badge_text="Hit",
    icon=phosphor.lightning,
)
cache_cards.draw(c_xy, width=c_w, height=c_h)

harvest_panel = Panel(
    "Field & Route Harvesting",
    style=Styles.PrimaryNeutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.5),
    icon=phosphor.magnifying_glass,
    icon_style=Styles.White,
    header_variant="filled",
    header_height=8.5,
)
harvest_panel.draw((92.0, 4.0), width=84.0, height=62.0)
h_xy, h_w, h_h = harvest_panel.get_content_box(
    (92.0, 4.0), width=84.0, height=62.0, padding=(3.5, 3.0)
)

harvest_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    spacing=2.2,
)
harvest_cards.add(
    "Validation ModelFields",
    "body_field + Dependant path/query/header",
    badge_text="In",
    icon=phosphor.sign_in,
)
harvest_cards.add(
    "Serialization ModelFields",
    "response_field + stream_item_field",
    badge_text="Out",
    icon=phosphor.sign_out,
)
harvest_cards.add(
    "Callbacks & Webhooks",
    "Unified into shared components.schemas",
    badge_text="Hook",
    icon=phosphor.webhooks_logo,
)
harvest_cards.draw(h_xy, width=h_w, height=h_h)
```

---

## 1. Lazy Memoization and `_openapi_routes_version` Invalidation

In `fastapi/applications.py`, `FastAPI.__init__()` sets `self.openapi_version = "3.1.0"`, `self.openapi_schema = None`, and `self._openapi_routes_version = None`. No Pydantic JSON Schema adapters are invoked while routers and endpoints are being registered.

When `app.openapi()` is called (either directly in user/test code or by an HTTP `GET /openapi.json` request), it checks two invariants before returning `self.openapi_schema`:

1. **Cold Cache Check (`not self.openapi_schema`)**: Synthesizes the full OpenAPI dictionary on the very first call and caches it on `self.openapi_schema`.
2. **Recursive Route-Mutation Check (`self._openapi_routes_version != routes_version`)**: Calls `self.router._get_routes_version()` in `fastapi/routing.py`. Every `APIRouter` maintains a monotonically increasing `self._routes_version` counter incremented by `_mark_routes_changed()` inside `add_route()`, `add_api_route()`, `add_websocket_route()`, `include_router()`, and `frontend()`. Crucially, `_get_routes_version(seen)` recursively sums `_routes_version` across every nested `_IncludedRouter` (using `seen: set[int]` to guard against router cycles), so adding a route dynamically to an already-included child `APIRouter` automatically invalidates the root `FastAPI` OpenAPI cache!

---

## 2. Inside `get_openapi()`: Field Harvesting, `FieldMap`, and `$defs` Deduplication

`get_openapi()` in `fastapi/openapi/utils.py` coordinates with `fastapi/_compat/v2.py` and `fastapi/openapi/constants.py` across five deterministic passes:

1. **Harvesting All `ModelField`s (`get_fields_from_routes()`)**: Walks `routing.iter_route_contexts(list(routes) + list(webhooks or []))`, inspecting every `APIRoute` with `include_in_schema=True`. For each route, it collects request-side fields (`body_field` and `get_flat_params(api_route.dependant)`, all carrying `mode="validation"`), response-side fields (`response_field`, additional `response_fields.values()`, and `stream_item_field` for JSONL/SSE generators, all carrying `mode="serialization"`), and recursively harvests `api_route.callbacks`.
2. **Flattening Nested Types (`get_flat_models_from_fields()` & `get_model_name_map()`)**: Recursively traverses generic annotations, unions, `BaseModel` fields, and `Enum` subclasses to build the complete `TypeModelSet`, normalizing schema keys via `re.sub(r"[^a-zA-Z0-9.\-_]", "_", name)`.
3. **Single-Pass `$defs` Generation (`get_definitions()` & `GenerateJsonSchema`)**: In `fastapi/_compat/v2.py`, `get_definitions()` instantiates FastAPI's `GenerateJsonSchema(ref_template=REF_TEMPLATE)` subclass (where `REF_TEMPLATE = "#/components/schemas/{model}"` and `bytes_schema()` emits `contentMediaType: "application/octet-stream"`). Because `ModelField.__hash__` returns `id(self)`, every `(ModelField, mode)` pair acts as a unique lookup key in `inputs`. Passing all collected fields and nested models into `schema_generator.generate_definitions(inputs=inputs)` produces two structures in a single Pydantic pass:
   - **`field_mapping` (`FieldMap`)**: Maps each `(ModelField, "validation" | "serialization")` tuple to its inline JSON Schema or `{"$ref": "#/components/schemas/..."}` pointer.
   - **`definitions`**: The deduplicated global dictionary of named component schemas (with form-feed `\f` characters stripped from model docstrings via `description.split("\f")[0]`).
4. **Operation, Callback, Webhook & Streaming Synthesis (`get_openapi_path()`)**:
   - **Dependency & Security Graph**: `_get_openapi_dependency_data(route.dependant)` walks the `Dependant` DAG once per route (deduplicating via `_get_cache_key`), while `_get_openapi_security_definitions()` merges OAuth2 scopes per `scheme_name` into `components["securitySchemes"]` and per-operation `security` arrays.
   - **Parameters, Request Bodies & `422` Schemas**: `_get_openapi_operation_parameters()` ensures `required=True` parameter declarations override optional duplicates on `(in, name)`. Methods in `METHODS_WITH_BODY` (`GET`, `HEAD`, `POST`, `PUT`, `DELETE`, `PATCH`) attach `requestBody` schemas, and any operation accepting parameters or a body automatically receives a `422` response referencing `#/components/schemas/HTTPValidationError` and `ValidationError`.
   - **Streaming, Callbacks & Webhooks**: Generator routes with `is_json_stream` emit `application/jsonl` `itemSchema`, while `is_sse_stream` routes emit `text/event-stream` `_SSE_EVENT_SCHEMA` (`contentMediaType: "application/json"`, `contentSchema`). Per-route `callbacks` recurse into `get_openapi_path()`, and `app.webhooks.routes` populate top-level OpenAPI 3.1 `output["webhooks"]`.
5. **Pydantic Self-Validation (`OpenAPI(**output)`)**: After sorting `components["schemas"]` alphabetically, `get_openapi()` validates the assembled dictionary against `fastapi.openapi.models.OpenAPI` (`Schema`, `PathItem`, `Operation`, `Components`) and serializes it via `jsonable_encoder(..., by_alias=True, exclude_none=True)`.

---

## 3. `separate_input_output_schemas` and Interactive Docs UI (`docs.py`)

```drawlib align=center code=hide file=defs_bundling_and_docs_ui.png caption="Conditional Model-Input / Model-Output Schema Splitting and Automatic Docs UI Routes"
from drawlib.canvas import setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, Panel, Table
from drawlib.styles import Colors, Styles

setup(width=184, height=78)

split_panel = Panel(
    "Input/Output $defs Split",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.5),
    icon=phosphor.git_fork,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.5,
)
split_panel.draw((4.0, 4.0), width=98.0, height=70.0)
l_xy, l_w, l_h = split_panel.get_content_box(
    (4.0, 4.0), width=98.0, height=70.0, padding=(3.5, 3.5)
)

schema_table = Table(
    cell_style=Styles.White,
    text_style=Styles.Dark.patch(text_size=10.0),
    header_cell_style=Styles.PrimaryFlat,
    header_text_style=Styles.WhiteBold.patch(text_size=10.0),
    border_style=Styles.MutedThin,
)
schema_table.draw(
    xy=(l_xy[0], l_xy[1] + l_h),
    width=l_w,
    height=l_h,
    data=[
        ["Model Trait", "Input vs Output", "Schema Key"],
        ["Plain fields", "Identical JSON Schema", "Tag (unified)"],
        ["Decimal field", "number | str vs str", "Item-Input / -Output"],
        ["Field(exclude)", "In props vs omitted", "Item-Input / -Output"],
        ["@computed_field", "Omitted vs in props", "Item-Input / -Output"],
        ["Params / Body", "Auto 422 error schema", "HTTPValidationError"],
    ],
)

docs_panel = Panel(
    "Docs UI Routes (setup())",
    style=Styles.PrimaryNeutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.5),
    icon=phosphor.browsers,
    icon_style=Styles.White,
    header_variant="filled",
    header_height=8.5,
)
docs_panel.draw((106.0, 4.0), width=74.0, height=70.0)
r_xy, r_w, r_h = docs_panel.get_content_box(
    (106.0, 4.0), width=74.0, height=70.0, padding=(3.5, 2.8)
)

docs_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    spacing=1.8,
)
docs_cards.add(
    "/openapi.json",
    "Prepends root_path to servers[]",
    badge_text="JSON",
    icon=phosphor.file_code,
)
docs_cards.add(
    "/docs (Swagger UI)",
    "get_swagger_ui_html + _html_safe_json",
    badge_text="UI",
    icon=phosphor.code_block,
)
docs_cards.add(
    "/docs/oauth2-redirect",
    "Popup token callback relay HTML",
    badge_text="Auth",
    icon=phosphor.key,
)
docs_cards.add(
    "/redoc (ReDoc UI)",
    "get_redoc_html standalone bundle",
    badge_text="Doc",
    icon=phosphor.book_open,
)
docs_cards.draw(r_xy, width=r_w, height=r_h)
```

### When `Model-Input` and `Model-Output` Split vs Coalesce

With `separate_input_output_schemas=True` (default), `get_definitions()` feeds request `ModelField`s into `GenerateJsonSchema` with `mode="validation"` and response `ModelField`s with `mode="serialization"`. Crucially, Pydantic **only emits `-Input` and `-Output` suffixed schemas when the two JSON Schemas actually differ**:

- **Coalesced (`#/components/schemas/Tag`)**: When every field produces the exact same validation and serialization JSON Schema, `GenerateJsonSchema` deduplicates both modes into a single `"Tag"` component—avoiding redundant schema bloat for simple DTOs.
- **Split (`#/components/schemas/Item-Input` & `Item-Output`)**: Whenever input and output representations diverge—for example, `Decimal` (accepts `number | string` on input, serializes as `string`), `Field(exclude=True)` (accepted on input, omitted on output), `@field_serializer` changing return types, `@computed_field` (present only on output), or `ConfigDict(json_schema_serialization_defaults_required=True)`—Pydantic emits distinct `Item-Input` and `Item-Output` definitions so generated TypeScript/Python SDK clients receive exact request and response types.
- **`_has_computed_fields()` Safeguard**: Even if an application opts out via `FastAPI(separate_input_output_schemas=False)`, `_has_computed_fields(field)` in `fastapi/_compat/v2.py` inspects `field._type_adapter.core_schema` for `computed_fields` and still preserves `mode="serialization"` on those models so `@computed_field` properties remain documented in responses.

### Automatic Docs UI Generators (`FastAPI.setup()` & `fastapi/openapi/docs.py`)

At the end of `FastAPI.__init__()`, `self.setup()` registers up to four hidden documentation routes (`include_in_schema=False`) gated on `self.openapi_url` (setting `openapi_url=None` disables all four):

1. **`GET {openapi_url}` (`/openapi.json`)**: Invokes `self.openapi()`. If `req.scope.get("root_path")` is non-empty (e.g., behind a reverse proxy or `Mount`) and `self.root_path_in_servers=True`, it shallow-copies the cached dict and prepends `{"url": root_path}` to `schema["servers"]` when not already listed.
2. **`GET {docs_url}` (`/docs` via `get_swagger_ui_html()`)**: Merges `swagger_ui_default_parameters` with `self.swagger_ui_parameters` and renders an `HTMLResponse` booting `SwaggerUIBundle` (`swagger-ui-dist@5`). All embedded JSON configuration keys, parameter values, and `init_oauth` payloads pass through `_html_safe_json()`, which escapes `<`, `>`, and `&` into `\u003c`, `\u003e`, and `\u0026` so untrusted strings cannot break out of the inline `<script>` block.
3. **`GET {swagger_ui_oauth2_redirect_url}` (`/docs/oauth2-redirect` via `get_swagger_ui_oauth2_redirect_html()`)**: Serves the OAuth2 popup callback page that verifies `qp.state === sentState` and forwards authorization codes or tokens to `window.opener.swaggerUIRedirectOauth2`.
4. **`GET {redoc_url}` (`/redoc` via `get_redoc_html()`)**: Renders `<redoc spec-url="{openapi_url}"></redoc>` backed by the `redoc@2` standalone bundle and optional `Montserrat`/`Roboto` Google Fonts.

---

## 4. Verifying Lazy Caching, Router Invalidation, and Schema Divergence

The snippet below verifies cold-start lazy memoization, automatic cache invalidation when a route is added to an already-included `APIRouter`, and selective `Item-Input` / `Item-Output` splitting alongside a unified `Tag` component:

```python
from decimal import Decimal

from fastapi import APIRouter, FastAPI
from pydantic import BaseModel, Field


class Tag(BaseModel):
    label: str


class Item(BaseModel):
    name: str
    price: Decimal
    secret_token: str = Field(default="", exclude=True)
    tags: list[Tag] = []


app = FastAPI(title="Inventory API", version="1.0.0")
sub_router = APIRouter(prefix="/v1")


@sub_router.post("/items", response_model=Item)
async def create_item(item: Item) -> Item:
    return item


app.include_router(sub_router)

# 1. Lazy synthesis: openapi_schema stays None until first app.openapi() call
assert app.openapi_schema is None
schema_v1 = app.openapi()
assert app.openapi_schema is schema_v1
assert app.openapi() is schema_v1

# 2. Divergent Item splits into Item-Input / Item-Output; identical Tag stays unified
schemas = schema_v1["components"]["schemas"]
assert {"Item-Input", "Item-Output", "Tag"} <= set(schemas)
assert "Tag-Input" not in schemas
assert "secret_token" in schemas["Item-Input"]["properties"]
assert "secret_token" not in schemas["Item-Output"]["properties"]
assert "anyOf" in schemas["Item-Input"]["properties"]["price"]
assert schemas["Item-Output"]["properties"]["price"]["type"] == "string"


# 3. Adding a route to an included APIRouter bumps _get_routes_version() & rebuilds
@sub_router.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


schema_v2 = app.openapi()
assert schema_v2 is not schema_v1
assert "/v1/health" in schema_v2["paths"]
```

To trace how `ModelField` and `TypeAdapter` execute runtime validation and Rust-backed JSON serialization on each request, see [_compat/v2.py, ModelField & Serialization](../04_pydantic_bridge/compat_and_serialization.md).
