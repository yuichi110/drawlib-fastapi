# APIRouter, APIRoute & Handler Closure Compilation

FastAPI's routing engine (`fastapi/routing.py`) operates as an ahead-of-time **closure compiler** built atop Starlette's `Router` and `Route` primitives. Rather than reflecting over Python type annotations or rebuilding Pydantic validators on every HTTP request, `APIRouter` and `APIRoute` inspect endpoint signatures once during registration (or lazy router inclusion), synthesize dedicated `Dependant` graphs and `ModelField` adapters, and freeze those artifacts inside a specialized `async def app(request: Request) -> Response` closure wrapped by FastAPI's dual-stack `request_response()` ASGI adapter.

```drawlib align=center code=hide file=apiroute_closure_compiler.png caption="End-to-End APIRoute & Handler Closure Compilation Pipeline"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.lines import line
from drawlib.smartarts import CardList, ChevronProcess, Panel
from drawlib.styles import Colors, Styles
from drawlib.text import text

setup(width=160, height=94)

# Top pipeline stages: Compile-time registration to ASGI adapter
stages = ChevronProcess(
    style=Styles.Neutral,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    corner_angle=60.0,
    spacing=1.8,
    flat_left_end=True,
)
stages.add("1. @router.post()", description="add_api_route()")
stages.add(
    "2. Compile Route State",
    description="_populate_api_route_state()",
    style=Styles.PrimaryNeutral,
)
stages.add(
    "3. get_route_handler()",
    description="get_request_handler()",
    style=Styles.SecondaryNeutral,
)
stages.add(
    "4. request_response()",
    description="ASGI self.app",
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
)
stages.draw(xy=(6.0, 74.0), width=148.0, height=14.0)

# Left Panel: Compile-Time Frozen Artifacts on APIRoute / _EffectiveRouteContext
left_panel = Panel(
    "Compile-Time Route State",
    "",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.5),
    icon=phosphor.gear,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.5,
)
left_panel.draw((6.0, 6.0), width=68.0, height=62.0)
l_xy, l_w, l_h = left_panel.get_content_box(
    (6.0, 6.0), width=68.0, height=62.0, padding=(3.5, 3.0)
)

compile_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    spacing=2.2,
)
compile_cards.add(
    "dependant: Dependant",
    "Signature + router Depends DAG",
    icon=phosphor.git_branch,
)
compile_cards.add(
    "body_field: ModelField",
    "Body_<unique_id> or Form model",
    icon=phosphor.package,
)
compile_cards.add(
    "response_field: ModelField",
    "TypeAdapter(mode='serialization')",
    icon=phosphor.check_circle,
)
compile_cards.add(
    "_EffectiveRouteContext",
    "ContextVar hook for included routes",
    icon=phosphor.stack,
)
compile_cards.draw(l_xy, width=l_w, height=l_h)

# Center Closure Capture Bridge
line((75.5, 37.0), (84.5, 37.0), arrow_head="->", style=Styles.PrimaryBold)
text((80.0, 41.0), "captures", style=Styles.PrimaryBold.patch(text_size=10.0))

# Right Panel: Per-Request Execution Inside ASGI Closure
right_panel = Panel(
    "Runtime Handler Closure",
    "",
    style=Styles.PrimaryNeutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.5),
    icon=phosphor.lightning,
    icon_style=Styles.WhiteBold,
    header_variant="filled",
    header_height=8.5,
)
right_panel.draw((86.0, 6.0), width=68.0, height=62.0)
r_xy, r_w, r_h = right_panel.get_content_box(
    (86.0, 6.0), width=68.0, height=62.0, padding=(3.5, 3.0)
)

runtime_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.SecondaryNeutral,
    icon_style=Styles.DarkBold,
    show_arrows=True,
    arrow_style=Styles.PrimaryBold,
    spacing=2.4,
)
runtime_cards.add(
    "Dual AsyncExitStack",
    "inner_astack + function_astack",
    icon=phosphor.brackets_curly,
)
runtime_cards.add(
    "Body & Strict MIME Gate",
    "form() / json() / CSRF guard",
    icon=phosphor.shield_check,
)
runtime_cards.add(
    "solve_dependencies()",
    "Resolve DAG & run endpoint",
    icon=phosphor.play,
)
runtime_cards.add(
    "serialize_response()",
    "Rust serialize_json() + bg tasks",
    icon=phosphor.export,
    badge_style=Styles.AccentFlat,
    icon_style=Styles.WhiteBold,
)
runtime_cards.draw(r_xy, width=r_w, height=r_h)

save()
```

## 1. Compile-Time State Synthesis (`APIRoute.__init__` & `_populate_api_route_state`)

Every HTTP verb decorator on `APIRouter` (`@router.get()`, `@router.post()`, `@router.put()`, `@router.delete()`, `@router.patch()`, `@router.options()`, `@router.head()`, `@router.trace()`) delegates through `APIRouter.api_route()` to `APIRouter.add_api_route()`. `add_api_route()` merges the router's immediate `prefix`, `tags`, `dependencies`, `responses`, `callbacks`, `default_response_class`, `generate_unique_id_function`, and `strict_content_type` with the decorator's arguments, then instantiates `route_class` (`APIRoute` by default).

Inside `APIRoute.__init__`, FastAPI delegates state construction to `_populate_api_route_state(route, path, endpoint, ...)` so that both direct `APIRoute` instances and lazy `_EffectiveRouteContext` clones share identical compilation logic:

| Compiled Attribute | Producer Function | Role in FastAPI `v0.162.2` |
| :--- | :--- | :--- |
| `path_regex`, `path_format`, `param_convertors` | `starlette.routing.compile_path(path)` | Compiles `{param:type}` segments into a regex, normalized OpenAPI path template, and Starlette convertors. |
| `unique_id` | `operation_id or generate_unique_id(route)` | Deterministic identifier (`<name><path_format>_<method>`) used for OpenAPI `operationId` and synthetic Pydantic model names. |
| `dependant`, `_embed_body_fields` | `_build_dependant_with_parameterless_dependencies()` | Calls `get_dependant(path=path_format, call=endpoint, scope="function")`, prepends router/decorator `Depends` at index `0` in reverse so outer-to-inner declaration order is preserved, flattens `body_params`, and computes `_should_embed_body_fields()`. |
| `body_field` | `_get_body_field()` | Returns the single `ModelField` directly when `_embed_body_fields=False`, or synthesizes a composite `Body_<unique_id>` Pydantic model (`create_body_model`) for multi-parameter JSON bodies, `Body(embed=True)`, or `Form`/`File` uploads. |
| `response_field`, `response_fields` | `create_model_field(..., mode="serialization")` | Wraps `response_model` (or inferred return annotation, unless `issubclass(ret, Response)`) in `Response_<unique_id>` using Pydantic v2's `TypeAdapter` in `"serialization"` mode; builds per-status `Response_<code>_<unique_id>` fields for `responses={...}`. |
| `stream_item_field`, `is_sse_stream`, `is_json_stream` | `get_stream_item_type()` + `create_model_field()` | For `yield` generator endpoints, extracts `T` from `AsyncIterable[T]` / `Iterable[T]` (excluding `ServerSentEvent`) into `StreamItem_<unique_id>` (`mode="serialization"`) and sets streaming dispatch flags. |
| `app` | `request_response(self.get_route_handler())` | Freezes the compiled route handler closure inside FastAPI's ASGI `Scope`/`Receive`/`Send` adapter. |

> [!NOTE]
> **Removal of Legacy `secure_cloned_response_field`**: In Pydantic v1 versions of FastAPI, `APIRoute` maintained both `response_field` and a cloned `secure_cloned_response_field` (`create_cloned_field`) to strip arbitrary sub-fields safely. Because FastAPI `v0.162.2` runs exclusively on Pydantic v2 (`PydanticV1NotSupportedError` rejects v1 models in `create_model_field()`), `v2.ModelField(mode="serialization")` compiles a single Rust-backed `TypeAdapter` that enforces field filtering, aliases, and validation natively without cloning models.

## 2. The Runtime Handler Closure (`get_request_handler` & `request_response`)

### 2.1 Dual AsyncExitStack & Swallowed-Exception Guard in `request_response()`

`APIRoute.__init__` finishes with `self.app = request_response(self.get_route_handler())`. FastAPI vendors and customizes Starlette's `request_response()` in `fastapi/routing.py` to manage two distinct `AsyncExitStack` lifecycles inside `scope` before delegating exception translation to Starlette's `wrap_app_handling_exceptions(app, request)`:

1. **`scope["fastapi_inner_astack"]` (Outer Request Stack)**: Encompasses both `response = await f(request)` **and** `await response(scope, receive, send)`. Dependencies with `yield` using `scope="request"` (the default for request-wide resources such as database sessions consumed by streaming responses) remain alive until every response byte has been transmitted over ASGI `send`.
2. **`scope["fastapi_function_astack"]` (Inner Function Stack)**: Encloses only `response = await f(request)`. Dependencies explicitly configured with `Depends(..., scope="function")` exit immediately after the endpoint returns its `Response` object, before body streaming begins.
3. **`response_awaited` Integrity Check**: A boolean flag `response_awaited` is set to `True` only after `await response(scope, receive, send)` completes. If `request_stack.__aexit__` suppresses an exception (because a buggy `yield` dependency caught `Exception` in a bare `except:` block without re-raising) before `response` was ever awaited, FastAPI explicitly raises `FastAPIError("Response not awaited...")` instead of silently hanging the HTTP connection.

### 2.2 Body Parsing, Strict Content-Type CSRF Gate & Dependency Solving

`APIRoute.get_route_handler()` passes the route's compiled attributes into `get_request_handler()`, which precomputes five invariants outside the per-request hot path (`is_coroutine`, `is_body_form`, `actual_response_class`, `is_sse_stream`, and `actual_strict_content_type`) and returns `async def app(request: Request) -> Response`:

- **Multipart & Form Cleanup (`fastapi_middleware_astack`)**: The closure fetches `file_stack = request.scope.get("fastapi_middleware_astack")` (installed by `AsyncExitStackMiddleware`). When `body_field` is present and `is_body_form` is `True` (`isinstance(body_field.field_info, params.Form)`, which covers both `Form()` and `File()` since `File` subclasses `Form`), FastAPI awaits `body = await request.form()` and pushes `body.close` onto `file_stack` so temporary `SpooledTemporaryFile` handles are guaranteed to close even if validation fails.
- **JSON Parsing & Strict Content-Type CSRF Defense**: For non-form `body_field` routes, FastAPI reads `body_bytes = await request.body()`. When non-empty, it inspects `request.headers.get("content-type")` via `email.message.Message`:
  - If `Content-Type` is `application/json` or `application/*+json` (such as `application/problem+json` or `application/vnd.api+json`), it parses `await request.json()`.
  - If `Content-Type` is **missing**, FastAPI checks `actual_strict_content_type` (`True` by default). When `True`, headerless payloads are left as raw `bytes` (causing Pydantic dict/model validation to reject them with `422`), preventing browsers from exploiting simple `fetch()` requests without `Content-Type` to bypass CORS preflight checks against `localhost` services. Setting `strict_content_type=False` restores permissive JSON parsing for headerless legacy clients.
  - Malformed JSON raises `json.JSONDecodeError`, which FastAPI converts into `RequestValidationError` with `type="json_invalid"`, byte offset `loc=("body", e.pos)`, and cached source metadata from `_extract_endpoint_context(dependant.call)`, firing the `_validation_failed()` telemetry hook.
- **Dependency DAG Resolution**: Inside `_operation(name="dependencies", function=dependant.call)`, `solve_dependencies()` validates path, query, header, cookie, and parsed `body` values while resolving sub-dependencies on `fastapi_inner_astack`. Any accumulated `solved_result.errors` raise `RequestValidationError` prior to endpoint invocation.

### 2.3 Endpoint Execution, Rust `serialize_json` Fast Path & `BackgroundTasks` Merging

When `solved_result.errors` is empty and the route is not a streaming generator, `get_request_handler()` executes the standard request-response branch:

1. **`run_endpoint_function()`**: Separated into a top-level helper for profiler visibility. Async endpoints execute directly via `await dependant.call(**values)` inside `_operation(name="endpoint")`; synchronous `def` endpoints offload via `await run_in_threadpool(_run_sync_endpoint, function=dependant.call, arguments=values)` so blocking I/O does not stall the event loop while preserving OpenTelemetry context.
2. **Direct `Response` Return Bypass**: If `isinstance(raw_response, Response)` is `True`, FastAPI skips `serialize_response()` completely. If `raw_response.background is None`, it attaches `solved_result.background_tasks` (preserving tasks queued via injected `BackgroundTasks` dependencies) and returns `raw_response` untouched.
3. **Pydantic Rust `dump_json` Fast Path vs Custom `response_class`**: Otherwise, `_build_response_args()` merges `background_tasks` and `status_code` (allowing `solved_result.response.status_code` mutated inside dependencies or the endpoint to override the decorator's `status_code`). FastAPI then evaluates:
   - **`use_dump_json = response_field is not None and isinstance(response_class, DefaultPlaceholder)`**: When `True`, `serialize_response(..., dump_json=True)` validates `raw_response` via `field.validate()` (offloaded to `run_in_threadpool` for sync endpoints, raising `ResponseValidationError` on contract mismatch) and calls `field.serialize_json(...)`. Pydantic's Rust core (`pydantic-core`) emits UTF-8 JSON `bytes` directly, which FastAPI wraps in a bare Starlette `Response(content=content, media_type="application/json", **response_args)`—bypassing intermediate Python `dict` allocation and `json.dumps()`!
   - **Fallback Serialization (`use_dump_json=False`)**: Calls `field.serialize(...)` (producing Python primitives) or `jsonable_encoder(raw_response)` when `response_field is None`, passing the result to `actual_response_class(content, **response_args)` (e.g., `ORJSONResponse` or default `JSONResponse`).
4. **Body Stripping & Header Merging**: If `not is_body_allowed_for_status_code(response.status_code)` (`1xx`, `204`, `205`, or `304`), `response.body` is cleared to `b""`. Finally, `response.headers.raw.extend(solved_result.response.headers.raw)` appends every `Set-Cookie` and custom header written to the injected `Response` parameter.

## 3. Nested `include_router()`, `_EffectiveRouteContext` & Lifespan Composition

In FastAPI `v0.162.2`, `APIRouter.include_router(router, ...)` no longer eagerly clones `APIRoute` objects at call time. Instead, after asserting against self-inclusion (`self is not router`) and cyclic router graphs (`not router._contains_router(self)`), it records an immutable `_RouterIncludeContext.for_include(...)` inside a `_IncludedRouter(original_router=router, include_context=include_context)` node appended to `self.routes`, increments `self._routes_version`, and composes lifespans. This lazy architecture ensures that routes registered on a child `APIRouter` *after* `include_router()` is called are still discovered automatically when `_get_routes_version()` changes!

```drawlib align=center code=hide file=include_router_context_merge.png caption="Nested include_router() Context Composition, Outer-to-Inner Dependency Ordering & _merge_lifespan_context"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, Panel, Table
from drawlib.styles import Colors, Styles

setup(width=162, height=92)

# Top Panel: 4-tier Outer-to-Inner Router Inclusion Chain
top_panel = Panel(
    "Outer-to-Inner Inclusion",
    "",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.5),
    icon=phosphor.git_merge,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.0,
)
top_panel.draw((5.0, 50.0), width=152.0, height=37.0)
t_xy, t_w, t_h = top_panel.get_content_box(
    (5.0, 50.0), width=152.0, height=37.0, padding=(3.5, 2.5)
)

chain = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_shape="circle",
    badge_style=Styles.PrimaryNeutral,
    icon_style=Styles.PrimaryBold,
    direction="horizontal",
    show_arrows=True,
    arrow_style=Styles.PrimaryBold,
    spacing=4.0,
)
chain.add("1. FastAPI App", "deps=[D_app]\nlifespan=L_app", icon=phosphor.globe)
chain.add(
    "2. include_router",
    "prefix='/api'\ndeps=[D_inc]",
    icon=phosphor.folder_open,
    badge_style=Styles.SecondaryNeutral,
    icon_style=Styles.DarkBold,
)
chain.add(
    "3. Child Router",
    "prefix='/v1'\ndeps=[D_router]",
    icon=phosphor.share_network,
)
chain.add(
    "4. @router.post",
    "path='/items'\ndeps=[D_route]",
    icon=phosphor.code,
    badge_style=Styles.PrimaryFlat,
    icon_style=Styles.WhiteBold,
)
chain.draw(t_xy, width=t_w, height=t_h)

# Bottom-Left Table: Exact _RouterIncludeContext & _EffectiveRouteContext Merge Rules
merge_table = Table(
    cell_style=Styles.White,
    text_style=Styles.Dark.patch(text_size=10.0),
    header_cell_style=Styles.PrimaryFlat,
    header_text_style=Styles.WhiteBold.patch(text_size=10.5),
    border_style=Styles.MutedThin,
)
merge_table.set_style_cell_evenodd(
    even_color=Colors.Light,
    even_text_style=Styles.Dark.patch(text_size=10.0),
    odd_color=Colors.White,
    odd_text_style=Styles.Dark.patch(text_size=10.0),
)
merge_table.set_style_cell_header(
    background_color=Colors.Primary,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
)
merge_data = [
    ["Field", "Merge Rule", "Effective Value"],
    ["prefix + path", "Outer + inner concat", "'/api/v1/items'"],
    ["dependencies", "Outer-to-inner prepend", "[D_app, D_inc, D_router, D_route]"],
    ["tags / callbacks", "Outer-to-inner extend", "[*outer, *inner, *route]"],
    ["responses", "Dict merge (inner wins)", "{**include_resp, **route_resp}"],
    ["response_class", "get_value_or_default()", "route -> router -> include"],
]
merge_table.draw_flexible(
    xy=(5.0, 45.0),
    column_widths=[27.0, 34.0, 39.0],
    row_heights=[6.8, 6.4, 6.4, 6.4, 6.4, 6.4],
    data=merge_data,
    align="top_left",
)

# Bottom-Right Panel: _merge_lifespan_context State Composition
life_panel = Panel(
    "_merge_lifespan_context",
    "",
    style=Styles.PrimaryNeutral,
    header_style=Styles.SecondaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    icon=phosphor.arrows_clockwise,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.0,
)
life_panel.draw((109.0, 6.0), width=48.0, height=39.0)
lp_xy, lp_w, lp_h = life_panel.get_content_box(
    (109.0, 6.0), width=48.0, height=39.0, padding=(3.0, 2.2)
)

life_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.0),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_shape="rounded_rect",
    badge_style=Styles.Neutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    spacing=1.8,
)
life_cards.add("Enter parent(app)", "Outer async with", badge_text="1")
life_cards.add("Enter child(app)", "Inner async with", badge_text="2")
life_cards.add(
    "Yield merged dict",
    "{**child, **parent}",
    badge_text="3",
    badge_style=Styles.AccentFlat,
    badge_text_style=Styles.WhiteBold.patch(text_size=10.0),
)
life_cards.draw(lp_xy, width=lp_w, height=lp_h)

save()
```

When a request arrives (or OpenAPI iterates routes via `iter_route_contexts()`), `_IncludedRouter.effective_candidates()` acquires `_effective_routes_lock`, combines nested `_RouterIncludeContext` layers via `.combine()`, and builds one `_EffectiveRouteContext` per included route via `_EffectiveRouteContext.from_api_route()`:

- **Outer-to-Inner Dependency Ordering**: `_RouterIncludeContext` concatenates `dependencies=[*parent_router.dependencies, *(include_dependencies or [])]` down every nesting level, and `from_api_route()` appends `*route.dependencies`. Inside `_build_dependant_with_parameterless_dependencies()`, FastAPI iterates `for depends in dependencies[::-1]: dependant.dependencies.insert(0, ...)`, placing all parameterless router/decorator dependencies **ahead** of the endpoint's signature `Depends(...)` parameters in exact outer-to-inner order (`FastAPI` -> outer `APIRouter` -> `include_router()` -> inner `APIRouter` -> `@router.post(dependencies=...)` -> endpoint function signature).
- **Precedence of Defaults & Responses**: `responses` merges via `{**include_context.responses, **route.responses}` so inner status definitions override outer defaults. `response_class`, `generate_unique_id_function`, and `strict_content_type` resolve via `get_value_or_default(route_val, included_router_val, include_context_val)`, picking the most specific non-`DefaultPlaceholder` setting. `deprecated` combines with logical `or`, while `include_in_schema` combines with logical `and`.
- **`_merge_lifespan_context(original_context, nested_context)`**: At `include_router()` time, legacy `on_startup`/`on_shutdown` lists are copied and `self.lifespan_context` is wrapped in a nested `@asynccontextmanager`. During ASGI lifespan startup, `original_context(app)` enters **first** (outer) and `nested_context(app)` enters **second** (inner), tearing down in reverse LIFO order on shutdown. If either yields a state mapping, FastAPI yields `{**(maybe_nested_state or {}), **(maybe_original_state or {})}` so parent lifespan keys take precedence over nested router keys.

## 4. Source-Verified Inspection & Custom `APIRoute` Wrapping

### 4.1 Inspecting Compiled `APIRoute` Fields, `RouteContext` & Lifespan Merging

The following snippet inspects the compiled `ModelField` artifacts on a raw `APIRoute`, composes a 3-level router hierarchy, reads the effective route metadata through `iter_route_contexts(app.routes)`, and verifies both outer-to-inner dependency execution order and `_merge_lifespan_context` state precedence:

```python
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import APIRouter, Depends, FastAPI
from fastapi.routing import APIRoute, _IncludedRouter, iter_route_contexts
from fastapi.testclient import TestClient
from pydantic import BaseModel


class ItemIn(BaseModel):
    title: str
    qty: int


class ItemOut(BaseModel):
    id: int
    title: str
    secret: str | None = None


order: list[str] = []


def make_dep(label: str):
    def _dep() -> str:
        order.append(label)
        return label

    return _dep


@asynccontextmanager
async def app_lifespan(_app: FastAPI) -> AsyncIterator[dict[str, str]]:
    yield {"app_scope": "root", "shared": "parent_wins"}


@asynccontextmanager
async def router_lifespan(_app: FastAPI) -> AsyncIterator[dict[str, str]]:
    yield {"router_scope": "child", "shared": "child_overridden"}


inner = APIRouter(
    prefix="/items",
    tags=["items"],
    dependencies=[Depends(make_dep("inner_router"))],
    lifespan=router_lifespan,
)


@inner.post(
    "/{group}",
    response_model=ItemOut,
    response_model_exclude_none=True,
    responses={409: {"model": dict[str, str]}},
    dependencies=[Depends(make_dep("decorator"))],
)
async def create_item(
    group: str,
    payload: ItemIn,
    sig_dep: str = Depends(make_dep("endpoint_sig")),
) -> dict[str, object]:
    return {"id": 1, "title": f"{group}:{payload.title}:{sig_dep}"}


# 1. Direct APIRoute state compiled at decorator evaluation time
raw_route = inner.routes[0]
assert isinstance(raw_route, APIRoute)
assert raw_route.unique_id == "create_item_items__group__post"
assert raw_route.body_field is not None and raw_route.body_field.name == "payload"
assert raw_route._embed_body_fields is False
assert raw_route.response_field is not None
assert raw_route.response_field.mode == "serialization"
assert 409 in raw_route.response_fields

# 2. Lazy _IncludedRouter composition & effective RouteContext materialization
outer = APIRouter(
    prefix="/v1", tags=["v1"], dependencies=[Depends(make_dep("outer_router"))]
)
outer.include_router(inner, dependencies=[Depends(make_dep("include_call"))])

app = FastAPI(dependencies=[Depends(make_dep("app"))], lifespan=app_lifespan)
app.include_router(outer, prefix="/api")

assert any(isinstance(r, _IncludedRouter) for r in app.router.routes)
eff = next(ctx for ctx in iter_route_contexts(app.routes) if ctx.name == "create_item")
assert eff.path == "/api/v1/items/{group}"
assert eff.tags == ["v1", "items"]

with TestClient(app) as client:
    res = client.post("/api/v1/items/books", json={"title": "ASGI", "qty": 2})
    assert res.json() == {"id": 1, "title": "books:ASGI:endpoint_sig"}
    assert order == [
        "app",
        "outer_router",
        "include_call",
        "inner_router",
        "decorator",
        "endpoint_sig",
    ]
    assert client.app_state["shared"] == "parent_wins"
```

### 4.2 Wrapping `get_request_handler()` via a Custom `APIRoute.get_route_handler()` Subclass

Custom `APIRoute` subclasses override `get_route_handler(self)` to intercept `Request` and `Response` objects around the closure returned by `super().get_route_handler()`. When `_EffectiveRouteContext.from_api_route()` compiles an included route, it temporarily binds `_effective_route_context_var.set(context)` (`ContextVar`) before calling `original_route.get_route_handler()`, ensuring `super().get_route_handler()` builds its closure against the merged `_EffectiveRouteContext` while executing your custom wrapper:

```python
from collections.abc import Coroutine
from typing import Callable

from fastapi import APIRouter, FastAPI, Request, Response
from fastapi.routing import APIRoute
from fastapi.testclient import TestClient


class AuditAPIRoute(APIRoute):
    def get_route_handler(
        self,
    ) -> Callable[[Request], Coroutine[object, object, Response]]:
        original_handler = super().get_route_handler()

        async def custom_handler(request: Request) -> Response:
            response = await original_handler(request)
            response.headers["X-Route-Name"] = self.name
            return response

        return custom_handler


router = APIRouter(route_class=AuditAPIRoute)


@router.get("/ping")
async def ping() -> dict[str, bool]:
    return {"ok": True}


app = FastAPI()
app.include_router(router, prefix="/v2")

resp = TestClient(app).get("/v2/ping")
assert resp.status_code == 200
assert resp.headers["X-Route-Name"] == "ping"
```

Next, explore how `get_request_handler()` dispatches generator endpoints and low-priority SPA frontends in [Generator Streaming & SPA Internals](streaming_and_spa_internals.md), how `Dependant` graphs resolve in [Dependant DAG & solve_dependencies](../03_di_and_security_engine/dependant_and_solver.md), how `ModelField` wraps `TypeAdapter` in [_compat/v2.py, ModelField & Serialization](../04_pydantic_bridge/compat_and_serialization.md), and how `AsyncExitStackMiddleware` frames the outer request stack in [Middleware Onion & Threadpool](../05_asgi_and_telemetry/middleware_and_concurrency.md).
