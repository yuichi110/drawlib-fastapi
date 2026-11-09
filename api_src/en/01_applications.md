# fastapi.applications

The `fastapi.applications` module defines the `FastAPI` ASGI application class (subclassing `starlette.applications.Starlette`), orchestrating OpenAPI 3.1.0 metadata, interactive documentation routes (`/docs`, `/redoc`), lifespan management, native OpenTelemetry instrumentation, middleware stacks, exception handlers, router composition, and HTTP/WebSocket path operation decorators.

```drawlib align=center code=hide file=fastapi_app_api_surface.png caption="FastAPI Application Class API Surface — Constructor, Hooks, Routing, Composition & OpenAPI"
from drawlib.canvas import save, setup
from drawlib.diagrams.architecture import ArchitectureDiagram, Node, NodeGroup, PhosphorIcon
from drawlib.styles import Colors, Styles

setup(width=184, height=88)

_ = Colors

d = ArchitectureDiagram(
    node_style=Styles.PrimaryBold,
    node_text_style=Styles.DarkBold.patch(text_size=10.2),
    edge_style=Styles.DarkBold.patch(line_width=1.5),
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.White,
)

left_grp = d.add(
    NodeGroup(
        "1. Init & Lifecycle Hooks",
        width=54,
        height=78,
        style=Styles.Neutral.patch(shape_r=2.0),
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left", valign="top"),
    ),
    xy=(4.0, 5.0),
)
ctor = left_grp.add(
    Node(
        "Metadata & Lifespan\ntitle, lifespan, telemetry",
        icon=PhosphorIcon.GEAR,
        icon_size=6.5,
        width=44,
        height=18,
        card_style=Styles.White.patch(shape_r=2.0),
    ),
    xy=(27.0, 58.0),
)
mw = left_grp.add(
    Node(
        "Middleware Stack\nadd_middleware, @middleware",
        icon=PhosphorIcon.STACK,
        icon_size=6.5,
        width=44,
        height=18,
        card_style=Styles.White.patch(shape_r=2.0),
    ),
    xy=(27.0, 36.0),
)
exc = left_grp.add(
    Node(
        "Exception Handlers\nadd_exception_handler",
        icon=PhosphorIcon.SHIELD_WARNING,
        icon_size=6.5,
        width=44,
        height=18,
        card_style=Styles.White.patch(shape_r=2.0),
    ),
    xy=(27.0, 14.0),
)

app_node = d.add(
    Node(
        "FastAPI\nASGI App Core",
        icon=PhosphorIcon.ROCKET_LAUNCH,
        icon_size=7.5,
        width=34,
        height=22,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=11.0),
        card_style=Styles.PrimaryFlat.patch(shape_r=2.5),
    ),
    xy=(92.0, 44.0),
)

right_grp = d.add(
    NodeGroup(
        "2. Routing, Mounts & Schema",
        width=54,
        height=78,
        style=Styles.PrimaryNeutral.patch(shape_r=2.0),
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left", valign="top"),
    ),
    xy=(126.0, 5.0),
)
routes = right_grp.add(
    Node(
        "HTTP & WS Decorators\nget..delete, api_route, ws",
        icon=PhosphorIcon.CODE,
        icon_size=6.5,
        width=44,
        height=18,
        card_style=Styles.White.patch(shape_r=2.0),
    ),
    xy=(27.0, 58.0),
)
comp = right_grp.add(
    Node(
        "App Composition\ninclude_router, mount, SPA",
        icon=PhosphorIcon.GIT_MERGE,
        icon_size=6.5,
        width=44,
        height=18,
        card_style=Styles.White.patch(shape_r=2.0),
    ),
    xy=(27.0, 36.0),
)
schema = right_grp.add(
    Node(
        "OpenAPI 3.1 Schema\nopenapi(), /docs, /redoc",
        icon=PhosphorIcon.FILE_CODE,
        icon_size=6.5,
        width=44,
        height=18,
        card_style=Styles.SecondaryNeutral.patch(shape_r=2.0),
    ),
    xy=(27.0, 14.0),
)

app_node.fork([ctor, mw, exc], at_x=66.5, padding=(0.0, 1.2))
app_node.fork([routes, comp, schema], at_x=117.5, padding=(0.0, 1.2))

d.draw(xy=(0.0, 0.0))
save()
```

---

## `class` FastAPI

Main ASGI application entrypoint (`from fastapi import FastAPI`), inheriting from `starlette.applications.Starlette`. Initializes an internal `APIRouter`, registers default `HTTPException`, `RequestValidationError`, and `WebSocketRequestValidationError` handlers, configures native OpenTelemetry instrumentation, and mounts automatic `/openapi.json`, `/docs` (Swagger UI), and `/redoc` (ReDoc) endpoints via `setup()`.

```python
from fastapi import FastAPI

class FastAPI(Starlette):
    def __init__(
        self,
        *,
        telemetry: TelemetryConfig | None = None,
        debug: bool = False,
        routes: list[BaseRoute] | None = None,  # deprecated
        title: str = "FastAPI",
        summary: str | None = None,
        description: str = "",
        version: str = "0.1.0",
        openapi_url: str | None = "/openapi.json",
        openapi_tags: list[dict[str, Any]] | None = None,
        servers: list[dict[str, str | Any]] | None = None,
        dependencies: Sequence[Depends] | None = None,
        default_response_class: type[Response] = Default(JSONResponse),
        redirect_slashes: bool = True,
        docs_url: str | None = "/docs",
        redoc_url: str | None = "/redoc",
        swagger_ui_oauth2_redirect_url: str | None = "/docs/oauth2-redirect",
        swagger_ui_init_oauth: dict[str, Any] | None = None,
        middleware: Sequence[Middleware] | None = None,
        exception_handlers: dict[
            int | type[Exception],
            Callable[[Request, Any], Coroutine[Any, Any, Response]],
        ] | None = None,
        on_startup: Sequence[Callable[[], Any]] | None = None,
        on_shutdown: Sequence[Callable[[], Any]] | None = None,
        lifespan: Lifespan[AppType] | None = None,
        terms_of_service: str | None = None,
        contact: dict[str, str | Any] | None = None,
        license_info: dict[str, str | Any] | None = None,
        root_path: str = "",  # deprecated
        root_path_in_servers: bool = True,
        responses: dict[int | str, dict[str, Any]] | None = None,
        callbacks: list[BaseRoute] | None = None,
        webhooks: APIRouter | None = None,
        deprecated: bool | None = None,
        include_in_schema: bool = True,
        swagger_ui_parameters: dict[str, Any] | None = None,
        generate_unique_id_function: Callable[[APIRoute], str] = Default(generate_unique_id),
        separate_input_output_schemas: bool = True,
        openapi_external_docs: dict[str, Any] | None = None,
        strict_content_type: bool = True,
    ) -> None: ...
```

### Constructor Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `telemetry` | `TelemetryConfig \| None` | `None` | Native OpenTelemetry configuration dictionary (`tracing`, `metrics`, `logs`, `operation_spans`, `auto_configure`, `exclude`, custom providers). |
| `debug` | `bool` | `False` | Enables detailed traceback responses on unhandled `500` server errors (inherited from Starlette). |
| `routes` | `list[BaseRoute] \| None` | `None` | *Deprecated.* Starlette compatibility route list; prefer `@app.get()` / `app.include_router()`. |
| `title` | `str` | `"FastAPI"` | API title written to `info.title` in the generated OpenAPI document and documentation UIs. |
| `summary` | `str \| None` | `None` | Short OpenAPI 3.1.0 summary (`info.summary`) displayed beneath the API title. |
| `description` | `str` | `""` | Rich CommonMark Markdown description (`info.description`) rendered in `/docs` and `/redoc`. |
| `version` | `str` | `"0.1.0"` | Application API version string (`info.version`), distinct from `fastapi.__version__`. |
| `openapi_url` | `str \| None` | `"/openapi.json"` | URL serving the generated OpenAPI JSON schema. Setting `None` disables `/openapi.json`, `/docs`, and `/redoc`. |
| `openapi_tags` | `list[dict[str, Any]] \| None` | `None` | Tag metadata dictionaries (`name`, `description`, `externalDocs`) controlling tag order and docs in Swagger UI. |
| `servers` | `list[dict[str, str \| Any]] \| None` | `None` | Target server entries (`url`, `description`, `variables`) emitted in the OpenAPI `servers` array. |
| `dependencies` | `Sequence[Depends] \| None` | `None` | Global `Depends()` / `Security()` list executed for every HTTP and WebSocket path operation in the app. |
| `default_response_class` | `type[Response]` | `Default(JSONResponse)` | Default `Response` subclass used when endpoints return plain Python objects or Pydantic models. |
| `redirect_slashes` | `bool` | `True` | Automatically issues `307 Temporary Redirect` when trailing slashes differ from a registered route. |
| `docs_url` | `str \| None` | `"/docs"` | Path serving interactive Swagger UI documentation (`None` disables Swagger UI). |
| `redoc_url` | `str \| None` | `"/redoc"` | Path serving ReDoc API documentation (`None` disables ReDoc). |
| `swagger_ui_oauth2_redirect_url` | `str \| None` | `"/docs/oauth2-redirect"` | OAuth2 callback URL handled by Swagger UI's "Authorize" flow. |
| `swagger_ui_init_oauth` | `dict[str, Any] \| None` | `None` | Initial OAuth2 client options (`clientId`, `appName`, `usePkceWithAuthorizationCodeGrant`) passed to Swagger UI. |
| `middleware` | `Sequence[Middleware] \| None` | `None` | Pre-wrapped Starlette `Middleware(...)` entries applied when building the middleware stack. |
| `exception_handlers` | `dict[int \| type[Exception], Callable] \| None` | `None` | Initial mapping of HTTP status codes or exception classes to async/sync handler callables. |
| `on_startup` | `Sequence[Callable[[], Any]] \| None` | `None` | Legacy startup hook list; prefer `lifespan` async context managers. |
| `on_shutdown` | `Sequence[Callable[[], Any]] \| None` | `None` | Legacy shutdown hook list; prefer `lifespan` async context managers. |
| `lifespan` | `Lifespan[AppType] \| None` | `None` | Async (or sync generator) context manager managing startup/shutdown resources and typed request state. |
| `terms_of_service` | `str \| None` | `None` | URL to the API's Terms of Service (`info.termsOfService`). |
| `contact` | `dict[str, str \| Any] \| None` | `None` | Contact metadata dictionary (`name`, `url`, `email`) written to `info.contact`. |
| `license_info` | `dict[str, str \| Any] \| None` | `None` | License metadata (`name`, plus mutually exclusive SPDX `identifier` or `url`) written to `info.license`. |
| `root_path` | `str` | `""` | *Deprecated.* Reverse-proxy mount prefix; configure via `fastapi run --root-path` instead. |
| `root_path_in_servers` | `bool` | `True` | Automatically prepends any ASGI `root_path` to the generated OpenAPI `servers` list. |
| `responses` | `dict[int \| str, dict[str, Any]] \| None` | `None` | Additional OpenAPI response definitions merged into every path operation in the application. |
| `callbacks` | `list[BaseRoute] \| None` | `None` | OpenAPI callback route definitions attached to all path operations. |
| `webhooks` | `APIRouter \| None` | `None` | `APIRouter` whose path operations document OpenAPI 3.1.0 `webhooks` (`app.webhooks`). |
| `deprecated` | `bool \| None` | `None` | Marks all path operations in the application as deprecated in OpenAPI when `True`. |
| `include_in_schema` | `bool` | `True` | Controls whether application routes are included in OpenAPI generation by default. |
| `swagger_ui_parameters` | `dict[str, Any] \| None` | `None` | Direct configuration dictionary passed to Swagger UI (`deepLinking`, `persistAuthorization`, `docExpansion`, etc.). |
| `generate_unique_id_function` | `Callable[[APIRoute], str]` | `Default(generate_unique_id)` | Customizes automatic OpenAPI `operationId` generation (useful for client SDK codegen). |
| `separate_input_output_schemas` | `bool` | `True` | Emits distinct `<Model>-Input` and `<Model>-Output` JSON Schemas when field defaults differ between validation and serialization. |
| `openapi_external_docs` | `dict[str, Any] \| None` | `None` | Top-level OpenAPI `externalDocs` dictionary (`url` and optional `description`). |
| `strict_content_type` | `bool` | `True` | Rejects parsing request bodies as JSON when no `Content-Type` header is sent (mitigating localhost CSRF). |

### Key Instance Attributes

| Attribute | Type | Description |
| :--- | :--- | :--- |
| `app.router` | `APIRouter` | Root `APIRouter` storing registered routes, dependencies, and lifespan handlers. |
| `app.webhooks` | `APIRouter` | Dedicated `APIRouter` for documenting OpenAPI 3.1.0 `webhooks` (e.g., `@app.webhooks.post("order-paid")`). |
| `app.dependency_overrides` | `dict[Callable, Callable]` | Maps production dependency callables to replacement callables during testing. |
| `app.state` | `starlette.datastructures.State` | Application-wide state container shared across requests. |
| `app.openapi_version` | `str` | OpenAPI specification version string emitted by `app.openapi()` (defaults to `"3.1.0"`). |
| `app.openapi_schema` | `dict[str, Any] \| None` | Cached OpenAPI schema dictionary; automatically invalidated when routes are added. |

### Example

```python
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from fastapi import FastAPI


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[dict[str, str]]:
    app.state.started = True
    yield {"region": "us-east-1"}


app = FastAPI(
    title="Payments API",
    summary="Idempotent ledger and settlement endpoints.",
    version="2.4.0",
    lifespan=lifespan,
    license_info={"name": "Apache 2.0", "identifier": "Apache-2.0"},
    telemetry={"tracing": True, "metrics": True},
)
```

---

## `method` FastAPI.get() / post() / put() / patch() / delete()

HTTP path operation decorators registering an endpoint function on `app.router` for a single HTTP verb. FastAPI exposes eight verb decorators with identical keyword parameters: `app.get()`, `app.post()`, `app.put()`, `app.patch()`, `app.delete()`, `app.options()`, `app.head()`, and `app.trace()`.

```python
@app.get(
    path: str,
    *,
    response_model: Any = Default(None),
    status_code: int | None = None,
    tags: list[str | Enum] | None = None,
    dependencies: Sequence[Depends] | None = None,
    summary: str | None = None,
    description: str | None = None,
    response_description: str = "Successful Response",
    responses: dict[int | str, dict[str, Any]] | None = None,
    deprecated: bool | None = None,
    operation_id: str | None = None,
    response_model_include: IncEx | None = None,
    response_model_exclude: IncEx | None = None,
    response_model_by_alias: bool = True,
    response_model_exclude_unset: bool = False,
    response_model_exclude_defaults: bool = False,
    response_model_exclude_none: bool = False,
    include_in_schema: bool = True,
    response_class: type[Response] = Default(JSONResponse),
    name: str | None = None,
    callbacks: list[BaseRoute] | None = None,
    openapi_extra: dict[str, Any] | None = None,
    generate_unique_id_function: Callable[[APIRoute], str] = Default(generate_unique_id),
) -> Callable[[DecoratedCallable], DecoratedCallable]
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `path` | `str` | *(Required)* | URL path template (e.g., `"/items/{item_id}"`). |
| `response_model` | `Any` | `Default(None)` | Pydantic model or type used for response validation, filtering, serialization, and OpenAPI schema; falls back to the function's return annotation when unset (`None` disables response model validation). |
| `status_code` | `int \| None` | `None` | Default HTTP status code returned on success (defaults to `200` when `None`). |
| `tags` | `list[str \| Enum] \| None` | `None` | OpenAPI tags grouping the operation in Swagger UI and ReDoc. |
| `dependencies` | `Sequence[Depends] \| None` | `None` | Route-level `Depends()` / `Security()` callables executed before the endpoint without passing return values into endpoint parameters. |
| `summary` | `str \| None` | `None` | Short operation summary (auto-generated from function name if omitted). |
| `description` | `str \| None` | `None` | CommonMark operation description (extracted from endpoint docstring up to `\f` if omitted). |
| `response_description` | `str` | `"Successful Response"` | Description attached to the primary success response in OpenAPI. |
| `responses` | `dict[int \| str, dict[str, Any]] \| None` | `None` | Additional OpenAPI status-code response schemas, descriptions, headers, or examples. |
| `deprecated` | `bool \| None` | `None` | Marks this path operation as deprecated in OpenAPI. |
| `operation_id` | `str \| None` | `None` | Explicit globally unique OpenAPI `operationId` override. |
| `response_model_include` | `IncEx \| None` | `None` | Whitelist of fields (`set` or nested `dict`) included during Pydantic serialization. |
| `response_model_exclude` | `IncEx \| None` | `None` | Blacklist of fields (`set` or nested `dict`) omitted during Pydantic serialization. |
| `response_model_by_alias` | `bool` | `True` | Serializes Pydantic model fields using field aliases when defined. |
| `response_model_exclude_unset` | `bool` | `False` | Omits fields that were not explicitly populated on the returned model instance. |
| `response_model_exclude_defaults` | `bool` | `False` | Omits fields whose values equal their declared default values. |
| `response_model_exclude_none` | `bool` | `False` | Omits any field whose value is `None`. |
| `include_in_schema` | `bool` | `True` | Includes or hides the operation from the generated OpenAPI schema. |
| `response_class` | `type[Response]` | `Default(JSONResponse)` | Custom `Response` class (such as `HTMLResponse` or `EventSourceResponse`) used to wrap raw return values. |
| `name` | `str \| None` | `None` | Internal route name used by `app.url_path_for()` and `request.url_for()`. |
| `callbacks` | `list[BaseRoute] \| None` | `None` | Router routes documenting out-of-band webhook callbacks triggered by this operation. |
| `openapi_extra` | `dict[str, Any] \| None` | `None` | Arbitrary dictionary deep-merged into the generated OpenAPI Operation Object (e.g., `x-codeSamples`). |
| `generate_unique_id_function` | `Callable[[APIRoute], str]` | `Default(generate_unique_id)` | Per-route override for generating OpenAPI `operationId`. |

### Example

```python
from fastapi import FastAPI, status
from pydantic import BaseModel

app = FastAPI()


class ItemCreate(BaseModel):
    name: str
    price: float


class ItemOut(ItemCreate):
    id: int


@app.post("/items", response_model=ItemOut, status_code=status.HTTP_201_CREATED, tags=["items"])
async def create_item(payload: ItemCreate) -> ItemOut:
    return ItemOut(id=1, **payload.model_dump())


@app.delete("/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["items"])
async def delete_item(item_id: int) -> None:
    return None
```

---

## `method` FastAPI.api_route()

Decorator registering a single endpoint function for an arbitrary list of HTTP methods (`methods=["GET", "POST"]`). For non-decorator imperative registration, `FastAPI.add_api_route(path, endpoint, *, ...)` accepts the same keyword options.

```python
app.api_route(
    path: str,
    *,
    response_model: Any = Default(None),
    status_code: int | None = None,
    tags: list[str | Enum] | None = None,
    dependencies: Sequence[Depends] | None = None,
    summary: str | None = None,
    description: str | None = None,
    response_description: str = "Successful Response",
    responses: dict[int | str, dict[str, Any]] | None = None,
    deprecated: bool | None = None,
    methods: list[str] | None = None,
    operation_id: str | None = None,
    response_model_include: IncEx | None = None,
    response_model_exclude: IncEx | None = None,
    response_model_by_alias: bool = True,
    response_model_exclude_unset: bool = False,
    response_model_exclude_defaults: bool = False,
    response_model_exclude_none: bool = False,
    include_in_schema: bool = True,
    response_class: type[Response] = Default(JSONResponse),
    name: str | None = None,
    openapi_extra: dict[str, Any] | None = None,
    generate_unique_id_function: Callable[[APIRoute], str] = Default(generate_unique_id),
) -> Callable[[DecoratedCallable], DecoratedCallable]
```

### Key Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `path` | `str` | *(Required)* | URL path template matched against incoming HTTP requests. |
| `methods` | `list[str] \| None` | `None` | HTTP verbs handled by the endpoint (defaults to `["GET"]` inside `APIRoute` when `None`). |
| `response_model` .. `generate_unique_id_function` | `...` | *(Same as `get()`)* | Identical serialization, OpenAPI schema, and dependency options as `FastAPI.get()`. |

### Example

```python
from fastapi import FastAPI, Request

app = FastAPI()


@app.api_route("/ping", methods=["GET", "HEAD"], include_in_schema=False)
async def ping(request: Request) -> dict[str, str]:
    return {"method": request.method, "ok": "true"}
```

---

## `method` FastAPI.websocket()

Decorator registering an asynchronous WebSocket endpoint with full FastAPI dependency injection, `Path`/`Query`/`Header`/`Cookie` validation, and `AsyncExitStack` cleanup. Imperative counterpart: `app.add_api_websocket_route(path, endpoint, name=None, *, dependencies=None)`.

```python
app.websocket(
    path: str,
    name: str | None = None,
    *,
    dependencies: Sequence[Depends] | None = None,
) -> Callable[[DecoratedCallable], DecoratedCallable]
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `path` | `str` | *(Required)* | WebSocket URL path template (supports `{param}` path parameters). |
| `name` | `str \| None` | `None` | Optional route identifier for `url_path_for()` lookups (defaults to `endpoint.__name__`). |
| `dependencies` | `Sequence[Depends] \| None` | `None` | Parameterless `Depends()` / `Security()` guards evaluated before accepting or running the session. |

### Example

```python
from fastapi import FastAPI, WebSocket

app = FastAPI()


@app.websocket("/ws/{room}")
async def room_socket(websocket: WebSocket, room: str) -> None:
    await websocket.accept()
    msg = await websocket.receive_text()
    await websocket.send_json({"room": room, "echo": msg})
    await websocket.close()
```

---

## `method` FastAPI.include_router()

Composes an `APIRouter` into the application, prefixing paths, merging `lifespan` context managers, cascading `tags`, `dependencies`, `responses`, and `default_response_class`, and invalidating cached OpenAPI schemas.

```python
app.include_router(
    router: APIRouter,
    *,
    prefix: str = "",
    tags: list[str | Enum] | None = None,
    dependencies: Sequence[Depends] | None = None,
    responses: dict[int | str, dict[str, Any]] | None = None,
    deprecated: bool | None = None,
    include_in_schema: bool = True,
    default_response_class: type[Response] = Default(JSONResponse),
    callbacks: list[BaseRoute] | None = None,
    generate_unique_id_function: Callable[[APIRoute], str] = Default(generate_unique_id),
) -> None
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `router` | `APIRouter` | *(Required)* | Modular `APIRouter` instance to mount into the application's route tree. |
| `prefix` | `str` | `""` | URL prefix prepended to all routes in `router` (must start with `"/"` and must not end with `"/"`). |
| `tags` | `list[str \| Enum] \| None` | `None` | Additional OpenAPI tags prepended to operations inside `router`. |
| `dependencies` | `Sequence[Depends] \| None` | `None` | Dependencies executed before every HTTP and WebSocket route inside `router`. |
| `responses` | `dict[int \| str, dict[str, Any]] \| None` | `None` | Shared OpenAPI response definitions merged with router- and route-level responses. |
| `deprecated` | `bool \| None` | `None` | Marks all routes in the included router as deprecated when `True`. |
| `include_in_schema` | `bool` | `True` | Excludes all operations in `router` from OpenAPI when `False`. |
| `default_response_class` | `type[Response]` | `Default(JSONResponse)` | Fallback `Response` class for operations in `router` that leave `response_class` unset. |
| `callbacks` | `list[BaseRoute] \| None` | `None` | OpenAPI callbacks attached to operations in `router`. |
| `generate_unique_id_function` | `Callable[[APIRoute], str]` | `Default(generate_unique_id)` | Custom `operationId` generator scoped to `router`. |

### Example

```python
from fastapi import APIRouter, FastAPI

users_router = APIRouter()


@users_router.get("/{user_id}")
def get_user(user_id: int) -> dict[str, int]:
    return {"user_id": user_id}


app = FastAPI()
app.include_router(users_router, prefix="/v1/users", tags=["users"])
```

---

## `method` FastAPI.mount()

Mounts an independent ASGI application (such as `StaticFiles`, another `FastAPI` sub-application with its own `/docs` and middleware stack, or a `WSGIMiddleware`-wrapped legacy app) under `path` (inherited from `Starlette.mount`). Mounted sub-apps are isolated from the parent app's OpenAPI schema.

```python
app.mount(
    path: str,
    app: ASGIApp,
    name: str | None = None,
) -> None
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `path` | `str` | *(Required)* | URL prefix stripped and forwarded via ASGI `root_path` to the mounted sub-application. |
| `app` | `ASGIApp` | *(Required)* | Any ASGI 3.0 callable (`FastAPI`, `StaticFiles`, `WSGIMiddleware`, etc.). |
| `name` | `str \| None` | `None` | Route mount name used for reverse URL generation (`request.url_for(name, path=...)`). |

### Example

```python
from fastapi import FastAPI

main_app = FastAPI(title="Gateway")
admin_app = FastAPI(title="Admin Sub-App")


@admin_app.get("/stats")
def admin_stats() -> dict[str, int]:
    return {"active_workers": 4}


main_app.mount("/admin", admin_app, name="admin")
```

---

## `method` FastAPI.frontend()

Serves a compiled Single-Page Application (SPA) or static frontend directory as **low-priority fallback routes**. All normal API path operations, mounted routers, and slash redirects are evaluated first; static files and SPA fallback pages are served only when no API route matches.

```python
app.frontend(
    path: str,
    *,
    directory: str | os.PathLike[str],
    fallback: Literal["auto", "index.html", "404.html"] | None = "auto",
    check_dir: bool | Literal["auto"] = "auto",
) -> None
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `path` | `str` | *(Required)* | URL prefix where the frontend build is served (e.g., `"/"` or `"/app"`). |
| `directory` | `str \| os.PathLike[str]` | *(Required)* | Filesystem path to the built static asset directory (e.g., `"dist"`). |
| `fallback` | `Literal["auto", "index.html", "404.html"] \| None` | `"auto"` | Fallback file behavior for unmatched client-side routes (`"auto"` serves `index.html` or `404.html` when present; `None` disables SPA fallback). |
| `check_dir` | `bool \| Literal["auto"]` | `"auto"` | Verifies `directory` exists at startup (`"auto"` skips the check with a warning when `FASTAPI_ENV="development"`). |

### Example

```python
from pathlib import Path
import tempfile
from fastapi import FastAPI

app = FastAPI()


@app.get("/api/health")
def api_health() -> dict[str, str]:
    return {"status": "healthy"}


with tempfile.TemporaryDirectory() as dist_dir:
    (Path(dist_dir) / "index.html").write_text("<!doctype html><title>App</title>", encoding="utf-8")
    app.frontend("/", directory=dist_dir)
```

---

## `method` FastAPI.add_middleware()

Registers an ASGI middleware class at the outermost layer of `app.user_middleware` (inherited from `Starlette.add_middleware`). Must be called before the application handles its first request (before `middleware_stack` is built).

```python
app.add_middleware(
    middleware_class: _MiddlewareFactory[P],
    *args: P.args,
    **kwargs: P.kwargs,
) -> None
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `middleware_class` | `_MiddlewareFactory[P]` | *(Required)* | ASGI middleware class or factory accepting `(app: ASGIApp, *args, **kwargs)`. |
| `*args`, `**kwargs` | `Any` | — | Positional and keyword configuration arguments forwarded to `middleware_class` upon stack construction. |

### Example

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware

app = FastAPI()
app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://app.example.com"],
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization"],
)
```

---

## `method` FastAPI.middleware()

Decorator shorthand wrapping an `async def dispatch(request, call_next)` function in Starlette's `BaseHTTPMiddleware` and registering it on the application.

```python
app.middleware(
    middleware_type: str,
) -> Callable[[DecoratedCallable], DecoratedCallable]
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `middleware_type` | `str` | *(Required)* | Middleware protocol type; currently `"http"` is the supported value. |

### Example

```python
from collections.abc import Awaitable, Callable
import time
from fastapi import FastAPI, Request, Response

app = FastAPI()


@app.middleware("http")
async def add_timing_header(
    request: Request,
    call_next: Callable[[Request], Awaitable[Response]],
) -> Response:
    started = time.perf_counter()
    response = await call_next(request)
    response.headers["X-Process-Time"] = f"{time.perf_counter() - started:.4f}"
    return response
```

---

## `method` FastAPI.add_exception_handler()

Imperatively registers a custom sync or async exception handler for a specific `Exception` subclass or HTTP integer status code (inherited from `Starlette.add_exception_handler`).

```python
app.add_exception_handler(
    exc_class_or_status_code: int | type[Exception],
    handler: ExceptionHandler,
) -> None
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `exc_class_or_status_code` | `int \| type[Exception]` | *(Required)* | Target `Exception` subclass (e.g., `ValueError`, `RequestValidationError`) or HTTP status code (e.g., `404`, `500`). |
| `handler` | `Callable[[Request, Exception], Response \| Awaitable[Response]]` | *(Required)* | Callable translating `(request, exc)` into an HTTP `Response`. |

### Example

```python
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


class QuotaExceededError(Exception):
    def __init__(self, limit: int) -> None:
        self.limit = limit


async def quota_handler(request: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, QuotaExceededError)
    return JSONResponse(status_code=429, content={"detail": f"Limit {exc.limit} exceeded"})


app = FastAPI()
app.add_exception_handler(QuotaExceededError, quota_handler)
```

---

## `method` FastAPI.exception_handler()

Decorator registering a custom exception handler callable for an `Exception` subclass or HTTP status code.

```python
app.exception_handler(
    exc_class_or_status_code: int | type[Exception],
) -> Callable[[DecoratedCallable], DecoratedCallable]
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `exc_class_or_status_code` | `int \| type[Exception]` | *(Required)* | `Exception` class or integer HTTP status code intercepted by the decorated handler. |

### Example

```python
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


class TenantNotFoundError(Exception):
    def __init__(self, tenant_id: str) -> None:
        self.tenant_id = tenant_id


app = FastAPI()


@app.exception_handler(TenantNotFoundError)
async def handle_missing_tenant(request: Request, exc: TenantNotFoundError) -> JSONResponse:
    return JSONResponse(status_code=404, content={"tenant": exc.tenant_id, "error": "not_found"})
```

---

## `method` FastAPI.openapi()

Generates, caches, and returns the application's complete OpenAPI 3.1.0 schema dictionary. Internally invokes `fastapi.openapi.utils.get_openapi()` on first call (or whenever routes have been added/modified since the previous generation) and caches the result on `app.openapi_schema`. Assign a custom function to `app.openapi` to enrich or post-process the generated schema.

```python
app.openapi() -> dict[str, Any]
```

### Return Value & Caching Behavior

| Property | Type | Description |
| :--- | :--- | :--- |
| Return value | `dict[str, Any]` | Complete OpenAPI 3.1.0 specification dictionary served as JSON at `app.openapi_url`. |
| `app.openapi_schema` | `dict[str, Any] \| None` | Cached schema reused across requests until `app.router` route version increments. |

### Example

```python
from typing import Any
from fastapi import FastAPI
from fastapi.openapi.utils import get_openapi

app = FastAPI(title="Billing Service", version="1.2.0")


@app.get("/invoices")
def list_invoices() -> list[dict[str, str]]:
    return [{"id": "inv_01"}]


def custom_openapi() -> dict[str, Any]:
    if app.openapi_schema:
        return app.openapi_schema
    schema = get_openapi(
        title=app.title,
        version=app.version,
        routes=app.routes,
    )
    schema["info"]["x-logo"] = {"url": "https://example.com/logo.svg"}
    app.openapi_schema = schema
    return app.openapi_schema


app.openapi = custom_openapi  # type: ignore[method-assign]
```
