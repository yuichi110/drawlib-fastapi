# fastapi.openapi

OpenAPI `3.1.0` (JSON Schema `2020-12`) schema generation (`fastapi.openapi.utils`), interactive documentation HTML builders (`fastapi.openapi.docs`), schema reference constants (`fastapi.openapi.constants`), and Pydantic v2 specification models (`fastapi.openapi.models`).

```drawlib align=center code=hide file=fastapi_openapi_api_map.png caption="FastAPI OpenAPI Generator, Interactive Docs Builders, Reference Constants, and Pydantic v2 Model Hierarchy"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.lines import line
from drawlib.smartarts import CardList, Panel
from drawlib.styles import Colors, Styles

setup(width=188, height=88)

left_panel = Panel(
    "Generator, Docs & Constants",
    description="",
    style=Styles.Neutral,
    header_style=Styles.SecondaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.file_code,
    icon_style=Styles.DarkBold,
    header_variant="filled",
    header_height=8.5,
)
left_panel.draw((6.0, 5.0), width=84.0, height=78.0)
l_xy, l_w, l_h = left_panel.get_content_box((6.0, 5.0), width=84.0, height=78.0, padding=(3.5, 3.0))

left_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.SecondaryNeutral,
    badge_text_style=Styles.DarkBold.patch(text_size=10.0),
    icon_style=Styles.DarkBold,
    spacing=2.4,
)
left_cards.add(
    "openapi.utils",
    "get_openapi() -> OpenAPI 3.1 dict",
    badge_text="GEN",
    icon=phosphor.gear_six,
    style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=10.5),
    description_style=Styles.White.patch(text_size=10.0),
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
)
left_cards.add(
    "openapi.docs",
    "Swagger UI • OAuth2 • ReDoc HTML",
    badge_text="UI",
    icon=phosphor.browser,
)
left_cards.add(
    "openapi.constants",
    "METHODS_WITH_BODY • REF_PREFIX",
    badge_text="REF",
    icon=phosphor.hash,
)
left_cards.draw(l_xy, width=l_w, height=l_h)

line((91.5, 44.0), (96.5, 44.0), arrow_head="->", style=Styles.PrimaryBold.patch(line_width=1.8))

right_panel = Panel(
    "openapi.models Hierarchy",
    description="",
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.tree_structure,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
right_panel.draw((98.0, 5.0), width=84.0, height=78.0)
r_xy, r_w, r_h = right_panel.get_content_box((98.0, 5.0), width=84.0, height=78.0, padding=(3.5, 2.5))

right_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.5),
    description_style=Styles.Muted.patch(text_size=10.0),
    badge_style=Styles.PrimaryNeutral,
    badge_text_style=Styles.PrimaryBold.patch(text_size=10.0),
    icon_style=Styles.PrimaryBold,
    spacing=1.8,
)
right_cards.add(
    "OpenAPI",
    "openapi • info • servers • paths",
    badge_text="ROOT",
    icon=phosphor.globe,
)
right_cards.add(
    "Info / Contact / License",
    "Metadata • SPDX • Server URL",
    badge_text="META",
    icon=phosphor.info,
)
right_cards.add(
    "PathItem / Operation",
    "HTTP verbs • Parameter • Responses",
    badge_text="PATH",
    icon=phosphor.signpost,
)
right_cards.add(
    "Components / Schema",
    "JSON Schema 2020-12 • SecurityScheme",
    badge_text="COMP",
    icon=phosphor.cube,
)
right_cards.draw(r_xy, width=r_w, height=r_h)

save()
```

---

## `def` get_openapi()

Inspects `APIRoute` routes and optional webhooks in `fastapi.openapi.utils`, extracts Pydantic v2 input/output JSON schemas, parameters, request bodies, streaming `itemSchema` definitions (SSE and JSONL), `422` validation schemas, and security schemes, validates the assembled document via `fastapi.openapi.models.OpenAPI`, and returns a JSON-serializable `dict[str, Any]`.

```python
from collections.abc import Sequence
from typing import Any
from starlette.routing import BaseRoute
from fastapi import routing
from fastapi.openapi.utils import get_openapi


def get_openapi(
    *,
    title: str,
    version: str,
    openapi_version: str = "3.1.0",
    summary: str | None = None,
    description: str | None = None,
    routes: Sequence[BaseRoute | routing.RouteContext],
    webhooks: Sequence[BaseRoute | routing.RouteContext] | None = None,
    tags: list[dict[str, Any]] | None = None,
    servers: list[dict[str, str | Any]] | None = None,
    terms_of_service: str | None = None,
    contact: dict[str, str | Any] | None = None,
    license_info: dict[str, str | Any] | None = None,
    separate_input_output_schemas: bool = True,
    external_docs: dict[str, Any] | None = None,
) -> dict[str, Any]: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `title` | `str` | *Required* | Required API title written to `info.title`. |
| `version` | `str` | *Required* | Required application API version string written to `info.version`. |
| `openapi_version` | `str` | `"3.1.0"` | OpenAPI specification version written to the top-level `openapi` key. |
| `summary` | `str \| None` | `None` | Short OpenAPI 3.1 summary written to `info.summary`. |
| `description` | `str \| None` | `None` | Markdown-capable description written to `info.description`. |
| `routes` | `Sequence[BaseRoute \| RouteContext]` | *Required* | Application route sequence (`app.routes`) scanned for `APIRoute` operations with `include_in_schema=True`. |
| `webhooks` | `Sequence[BaseRoute \| RouteContext] \| None` | `None` | Optional webhook routes (`app.webhooks.routes`) emitted under top-level `webhooks`. |
| `tags` | `list[dict[str, Any]] \| None` | `None` | Top-level tag metadata dictionaries (`name`, `description`, `externalDocs`). |
| `servers` | `list[dict[str, str \| Any]] \| None` | `None` | Base server descriptors (`url`, `description`, `variables`). |
| `terms_of_service` | `str \| None` | `None` | URL string written to `info.termsOfService`. |
| `contact` | `dict[str, str \| Any] \| None` | `None` | Contact metadata (`name`, `url`, `email`) written to `info.contact`. |
| `license_info` | `dict[str, str \| Any] \| None` | `None` | License metadata (`name`, `identifier`, or `url`) written to `info.license`. |
| `separate_input_output_schemas` | `bool` | `True` | Emit distinct `-Input` / `-Output` component schemas when Pydantic model validation and serialization schemas differ (for example fields with defaults). |
| `external_docs` | `dict[str, Any] \| None` | `None` | External documentation object (`url`, optional `description`) written to top-level `externalDocs`. |

### Example

```python
from typing import Any
from fastapi import FastAPI
from fastapi.openapi.utils import get_openapi

app = FastAPI()


@app.get("/widgets/{widget_id}")
def read_widget(widget_id: int) -> dict[str, int]:
    return {"widget_id": widget_id}


def custom_openapi() -> dict[str, Any]:
    if app.openapi_schema:
        return app.openapi_schema
    schema = get_openapi(
        title="Inventory Service",
        version="2.4.0",
        summary="Warehouse inventory API",
        routes=app.routes,
    )
    schema["info"]["x-service-tier"] = "gold"
    app.openapi_schema = schema
    return app.openapi_schema


app.openapi = custom_openapi  # type: ignore[method-assign]

generated = app.openapi()
assert generated["openapi"] == "3.1.0"
assert generated["info"]["x-service-tier"] == "gold"
assert "/widgets/{widget_id}" in generated["paths"]
```

---

## `def` get_swagger_ui_html()

Generates the `HTMLResponse` in `fastapi.openapi.docs` that boots Swagger UI (`SwaggerUIBundle`). Useful when disabling default CDN endpoints (`docs_url=None`) to serve self-hosted JavaScript/CSS bundles or inject custom Swagger UI and OAuth2 settings. Embedded JSON configuration values are escaped for `<`, `>`, and `&` to prevent `<script>` tag injection.

```python
from typing import Any
from starlette.responses import HTMLResponse
from fastapi.openapi.docs import get_swagger_ui_html


def get_swagger_ui_html(
    *,
    openapi_url: str,
    title: str,
    swagger_js_url: str = "https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui-bundle.js",
    swagger_css_url: str = "https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui.css",
    swagger_favicon_url: str = "https://fastapi.tiangolo.com/img/favicon.png",
    oauth2_redirect_url: str | None = None,
    init_oauth: dict[str, Any] | None = None,
    swagger_ui_parameters: dict[str, Any] | None = None,
) -> HTMLResponse: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `openapi_url` | `str` | *Required* | URL from which Swagger UI fetches the OpenAPI JSON document (typically `app.openapi_url` or prefixed with `root_path`). |
| `title` | `str` | *Required* | Browser `<title>` string rendered inside the HTML `<head>`. |
| `swagger_js_url` | `str` | jsDelivr `swagger-ui-dist@5` JS | Script URL for `swagger-ui-bundle.js` (override for offline/self-hosted assets). |
| `swagger_css_url` | `str` | jsDelivr `swagger-ui-dist@5` CSS | Stylesheet URL for `swagger-ui.css`. |
| `swagger_favicon_url` | `str` | FastAPI favicon URL | Shortcut icon URL rendered in `<link rel="shortcut icon">`. |
| `oauth2_redirect_url` | `str \| None` | `None` | Relative path combined with `window.location.origin` for `oauth2RedirectUrl`. |
| `init_oauth` | `dict[str, Any] \| None` | `None` | Dictionary serialized into `ui.initOAuth(...)` (`clientId`, `scopes`, `usePkceWithAuthorizationCodeGrant`, etc.). |
| `swagger_ui_parameters` | `dict[str, Any] \| None` | `None` | Overrides merged onto a shallow copy of `swagger_ui_default_parameters`. |

### Example

```python
from fastapi import FastAPI
from fastapi.openapi.docs import get_swagger_ui_html
from fastapi.responses import HTMLResponse
from fastapi.testclient import TestClient

app = FastAPI(docs_url=None)


@app.get("/internal-docs", include_in_schema=False)
def custom_swagger_ui() -> HTMLResponse:
    return get_swagger_ui_html(
        openapi_url=app.openapi_url or "/openapi.json",
        title="Internal API Docs",
        swagger_js_url="/static/swagger-ui-bundle.js",
        swagger_css_url="/static/swagger-ui.css",
        swagger_ui_parameters={"persistAuthorization": True},
    )


client = TestClient(app)
res = client.get("/internal-docs")
assert res.status_code == 200
assert "/static/swagger-ui-bundle.js" in res.text
assert '"persistAuthorization": true' in res.text
```

---

## `def` get_swagger_ui_oauth2_redirect_html()

Returns the standalone `HTMLResponse` in `fastapi.openapi.docs` implementing Swagger UI's OAuth2 authorization callback page (served automatically at `app.swagger_ui_oauth2_redirect_url`, defaulting to `/docs/oauth2-redirect`). Validates OAuth2 `state`, handles authorization codes or implicit/PKCE tokens via `window.opener.swaggerUIRedirectOauth2`, and closes the popup window.

```python
from starlette.responses import HTMLResponse
from fastapi.openapi.docs import get_swagger_ui_oauth2_redirect_html


def get_swagger_ui_oauth2_redirect_html() -> HTMLResponse: ...
```

### Signature Details

| Element | Type | Description |
| :--- | :--- | :--- |
| **Parameters** | *(none)* | Accepts no arguments. |
| **Returns** | `HTMLResponse` | HTML `200 OK` document containing the Swagger UI OAuth2 callback script. |

### Example

```python
from fastapi import FastAPI
from fastapi.openapi.docs import get_swagger_ui_oauth2_redirect_html
from fastapi.responses import HTMLResponse
from fastapi.testclient import TestClient

app = FastAPI(docs_url=None, swagger_ui_oauth2_redirect_url="/custom/oauth2-redirect")


@app.get("/custom/oauth2-redirect", include_in_schema=False)
def oauth2_redirect() -> HTMLResponse:
    return get_swagger_ui_oauth2_redirect_html()


client = TestClient(app)
resp = client.get("/custom/oauth2-redirect")
assert resp.status_code == 200
assert "Swagger UI: OAuth2 Redirect" in resp.text
```

---

## `def` get_redoc_html()

Generates the `HTMLResponse` in `fastapi.openapi.docs` that mounts ReDoc (`<redoc spec-url="...">`) for three-column reference documentation (served by default at `/redoc`). Set `with_google_fonts=False` alongside a local `redoc_js_url` for completely air-gapped environments.

```python
from starlette.responses import HTMLResponse
from fastapi.openapi.docs import get_redoc_html


def get_redoc_html(
    *,
    openapi_url: str,
    title: str,
    redoc_js_url: str = "https://cdn.jsdelivr.net/npm/redoc@2/bundles/redoc.standalone.js",
    redoc_favicon_url: str = "https://fastapi.tiangolo.com/img/favicon.png",
    with_google_fonts: bool = True,
) -> HTMLResponse: ...
```

### Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `openapi_url` | `str` | *Required* | URL passed to `<redoc spec-url="...">` to load the OpenAPI schema. |
| `title` | `str` | *Required* | HTML `<title>` text displayed in the browser tab. |
| `redoc_js_url` | `str` | jsDelivr `redoc@2` standalone JS | Script URL for `redoc.standalone.js`. |
| `redoc_favicon_url` | `str` | FastAPI favicon URL | Shortcut icon URL rendered in `<link rel="shortcut icon">`. |
| `with_google_fonts` | `bool` | `True` | Include the Google Fonts stylesheet (`Montserrat` and `Roboto`) in `<head>`. |

### Example

```python
from fastapi.openapi.docs import get_redoc_html

response = get_redoc_html(
    openapi_url="/openapi.json",
    title="Offline Reference",
    redoc_js_url="/static/redoc.standalone.js",
    with_google_fonts=False,
)
body = bytes(response.body).decode("utf-8")
assert response.status_code == 200
assert '<redoc spec-url="/openapi.json"></redoc>' in body
assert "fonts.googleapis.com" not in body
```

---

## `const` SWAGGER_UI_PARAMETERS

Swagger UI configuration dictionary passed via `FastAPI(swagger_ui_parameters={...})` or `get_swagger_ui_html(swagger_ui_parameters={...})`, backed by the module-level default dictionary `swagger_ui_default_parameters` in `fastapi.openapi.docs`. FastAPI copies `swagger_ui_default_parameters` on every call and merges user overrides on top so omitted defaults stay intact.

```python
from typing import Any
from fastapi.openapi.docs import swagger_ui_default_parameters

swagger_ui_default_parameters: dict[str, Any] = {
    "dom_id": "#swagger-ui",
    "layout": "BaseLayout",
    "deepLinking": True,
    "showExtensions": True,
    "showCommonExtensions": True,
}
```

### Default Keys & Common Overrides

| Key | Source | Default / Typical Value | Description |
| :--- | :--- | :--- | :--- |
| `dom_id` | `swagger_ui_default_parameters` | `"#swagger-ui"` | CSS selector of the container DOM node where `SwaggerUIBundle` mounts. |
| `layout` | `swagger_ui_default_parameters` | `"BaseLayout"` | Active Swagger UI layout name. |
| `deepLinking` | `swagger_ui_default_parameters` | `True` | Updates URL hash fragments automatically when expanding tags and operations. |
| `showExtensions` | `swagger_ui_default_parameters` | `True` | Displays `x-*` vendor specification extension fields. |
| `showCommonExtensions` | `swagger_ui_default_parameters` | `True` | Displays common JSON Schema validation extensions (`pattern`, `maxLength`, `minLength`). |
| `persistAuthorization` | `swagger_ui_parameters` override | `True` | Persists bearer/API-key credentials in `localStorage` across page reloads. |
| `docExpansion` | `swagger_ui_parameters` override | `"list"` / `"none"` / `"full"` | Controls initial collapse state of operations (`"none"` speeds up large specs). |
| `syntaxHighlight` | `swagger_ui_parameters` override | `False` or `{"theme": "monokai"}` | Configures or disables response syntax highlighting. |

### Example

```python
from fastapi import FastAPI
from fastapi.openapi.docs import swagger_ui_default_parameters
from fastapi.testclient import TestClient

assert swagger_ui_default_parameters["dom_id"] == "#swagger-ui"
assert swagger_ui_default_parameters["deepLinking"] is True

app = FastAPI(
    swagger_ui_parameters={
        "docExpansion": "none",
        "filter": True,
        "syntaxHighlight": {"theme": "obsidian"},
    }
)

html = TestClient(app).get("/docs").text
assert '"dom_id": "#swagger-ui"' in html
assert '"docExpansion": "none"' in html
assert '"filter": true' in html
```

---

## `const` METHODS_WITH_BODY & REF_PREFIX & REF_TEMPLATE

Module-level constants in `fastapi.openapi.constants` governing which HTTP methods emit `requestBody` entries and how `$ref` JSON Pointers address shared component schemas under `#/components/schemas/`.

```python
from fastapi.openapi.constants import METHODS_WITH_BODY, REF_PREFIX, REF_TEMPLATE

METHODS_WITH_BODY: set[str] = {"GET", "HEAD", "POST", "PUT", "DELETE", "PATCH"}
REF_PREFIX: str = "#/components/schemas/"
REF_TEMPLATE: str = "#/components/schemas/{model}"
```

### Constants

| Constant | Type | Value | Description |
| :--- | :--- | :--- | :--- |
| `METHODS_WITH_BODY` | `set[str]` | `{"GET", "HEAD", "POST", "PUT", "DELETE", "PATCH"}` | Uppercase HTTP methods inspected by `get_openapi_path()` when attaching `operation["requestBody"]`. |
| `REF_PREFIX` | `str` | `"#/components/schemas/"` | Prefix prepended to schema names such as `HTTPValidationError` and `ValidationError`. |
| `REF_TEMPLATE` | `str` | `"#/components/schemas/{model}"` | Format template passed to Pydantic's `GenerateJsonSchema(ref_template=...)` so nested `$ref` pointers target OpenAPI components. |

### Example

```python
from fastapi.openapi.constants import METHODS_WITH_BODY, REF_PREFIX, REF_TEMPLATE

assert "POST" in METHODS_WITH_BODY and "DELETE" in METHODS_WITH_BODY
assert "OPTIONS" not in METHODS_WITH_BODY
assert REF_PREFIX + "HTTPValidationError" == "#/components/schemas/HTTPValidationError"
assert REF_TEMPLATE.format(model="Invoice") == "#/components/schemas/Invoice"
```

---

## `model` OpenAPI

Root Pydantic v2 model in `fastapi.openapi.models` representing a complete OpenAPI `3.1.0` document. Inherits from `BaseModelWithConfig` (`model_config = {"extra": "allow"}`), allowing specification extensions (`x-*`) at the document root while validating structural fields before `get_openapi()` serializes the final dictionary.

```python
from typing import Any
from fastapi.openapi.models import (
    BaseModelWithConfig,
    Components,
    ExternalDocumentation,
    Info,
    PathItem,
    Reference,
    Server,
    Tag,
)


class OpenAPI(BaseModelWithConfig):
    openapi: str
    info: Info
    jsonSchemaDialect: str | None = None
    servers: list[Server] | None = None
    paths: dict[str, PathItem | Any] | None = None
    webhooks: dict[str, PathItem | Reference] | None = None
    components: Components | None = None
    security: list[dict[str, list[str]]] | None = None
    tags: list[Tag] | None = None
    externalDocs: ExternalDocumentation | None = None
```

### Fields

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `openapi` | `str` | *Required* | Semantic version of the OpenAPI specification (for example `"3.1.0"`). |
| `info` | `Info` | *Required* | Required API metadata object (`title`, `version`, etc.). |
| `jsonSchemaDialect` | `str \| None` | `None` | Default `$schema` URI dialect for `Schema` objects in the document. |
| `servers` | `list[Server] \| None` | `None` | Target server base URLs and optional URL template variables. |
| `paths` | `dict[str, PathItem \| Any] \| None` | `None` | Endpoint path templates mapped to `PathItem` objects (or `x-*` extensions). |
| `webhooks` | `dict[str, PathItem \| Reference] \| None` | `None` | Out-of-band OpenAPI 3.1 webhook definitions keyed by webhook name. |
| `components` | `Components \| None` | `None` | Reusable schemas, security schemes, responses, parameters, and headers. |
| `security` | `list[dict[str, list[str]]] \| None` | `None` | Global security requirement objects (`{scheme_name: [scopes...]}`). |
| `tags` | `list[Tag] \| None` | `None` | Tag definitions (`name`, `description`, `externalDocs`) used to group operations. |
| `externalDocs` | `ExternalDocumentation \| None` | `None` | Link to additional external documentation (`url`, `description`). |

### Example

```python
from fastapi import FastAPI
from fastapi.openapi.models import OpenAPI

app = FastAPI(title="Ledger API", version="1.2.0")


@app.get("/ping")
def ping() -> dict[str, str]:
    return {"status": "ok"}


spec = OpenAPI.model_validate(app.openapi())
assert spec.openapi == "3.1.0"
assert spec.info.title == "Ledger API"
assert spec.paths is not None and "/ping" in spec.paths
```

---

## `model` Info / Contact / License / Server

Top-level metadata and deployment endpoint models in `fastapi.openapi.models` (`BaseModelWithConfig`, `extra="allow"`), including `ServerVariable` for parameterized server URLs and OpenAPI `3.1.0` SPDX `License.identifier` support.

```python
from typing import Annotated
from pydantic import AnyUrl, EmailStr, Field
from fastapi.openapi.models import BaseModelWithConfig


class Contact(BaseModelWithConfig):
    name: str | None = None
    url: AnyUrl | None = None
    email: EmailStr | None = None


class License(BaseModelWithConfig):
    name: str
    identifier: str | None = None
    url: AnyUrl | None = None


class Info(BaseModelWithConfig):
    title: str
    summary: str | None = None
    description: str | None = None
    termsOfService: str | None = None
    contact: Contact | None = None
    license: License | None = None
    version: str


class ServerVariable(BaseModelWithConfig):
    enum: Annotated[list[str] | None, Field(min_length=1)] = None
    default: str
    description: str | None = None


class Server(BaseModelWithConfig):
    url: AnyUrl | str
    description: str | None = None
    variables: dict[str, ServerVariable] | None = None
```

### Model Fields

| Model | Key Fields | Required | Description |
| :--- | :--- | :--- | :--- |
| `Info` | `title`, `version`, `summary`, `description`, `termsOfService`, `contact`, `license` | `title`, `version` | Core API identification, Markdown description, legal terms, contact, and license metadata. |
| `Contact` | `name`, `url`, `email` | *(none)* | Organization or maintainer contact details attached to `Info.contact`. |
| `License` | `name`, `identifier`, `url` | `name` | API license; OpenAPI 3.1 supports an SPDX expression in `identifier` (mutually exclusive with `url`). |
| `Server` | `url`, `description`, `variables` | `url` | Base URL (`AnyUrl` or relative/templated `str` such as `"/api/v1"` or `"https://{env}.example.com"`). |
| `ServerVariable` | `default`, `enum`, `description` | `default` | Template substitution rule for `{var}` placeholders in `Server.url` (`enum` requires `min_length=1` if set). |

### Example

```python
from fastapi.openapi.models import Contact, Info, License, Server, ServerVariable

info = Info(
    title="Payments API",
    version="3.0.0",
    summary="Multi-region settlement endpoints",
    contact=Contact(name="Platform Team", url="https://example.com/support"),
    license=License(name="Apache 2.0", identifier="Apache-2.0"),
)
server = Server(
    url="https://{region}.api.example.com/v3",
    description="Regional gateway",
    variables={"region": ServerVariable(default="us", enum=["us", "eu", "apac"])},
)

assert info.license is not None and info.license.identifier == "Apache-2.0"
assert server.variables is not None and server.variables["region"].default == "us"
```

---

## `model` Paths / PathItem / Operation / Parameter

Routing and HTTP operation models in `fastapi.openapi.models`. OpenAPI's Paths Object is represented on `OpenAPI.paths` as `dict[str, PathItem | Any] | None`, mapping each URL template (`"/items/{item_id}"`) to a `PathItem` containing HTTP method `Operation` objects (`get`, `post`, `put`, `delete`, `patch`, `options`, `head`, `trace`) and typed `Parameter` descriptors (`in_` aliased to `"in"`, `schema_` aliased to `"schema"`).

```python
from enum import Enum
from typing import Any
from pydantic import Field
from fastapi.openapi.models import (
    BaseModelWithConfig,
    Example,
    ExternalDocumentation,
    MediaType,
    Reference,
    RequestBody,
    Response,
    Schema,
    Server,
)


class ParameterInType(Enum):
    query = "query"
    header = "header"
    path = "path"
    cookie = "cookie"


class Parameter(BaseModelWithConfig):  # inherits ParameterBase
    name: str
    in_: ParameterInType = Field(alias="in")
    description: str | None = None
    required: bool | None = None
    deprecated: bool | None = None
    style: str | None = None
    explode: bool | None = None
    allowReserved: bool | None = None
    schema_: Schema | Reference | None = Field(default=None, alias="schema")
    example: Any | None = None
    examples: dict[str, Example | Reference] | None = None
    content: dict[str, MediaType] | None = None


class Operation(BaseModelWithConfig):
    tags: list[str] | None = None
    summary: str | None = None
    description: str | None = None
    externalDocs: ExternalDocumentation | None = None
    operationId: str | None = None
    parameters: list[Parameter | Reference] | None = None
    requestBody: RequestBody | Reference | None = None
    responses: dict[str, Response | Any] | None = None
    callbacks: dict[str, dict[str, "PathItem"] | Reference] | None = None
    deprecated: bool | None = None
    security: list[dict[str, list[str]]] | None = None
    servers: list[Server] | None = None


class PathItem(BaseModelWithConfig):
    ref: str | None = Field(default=None, alias="$ref")
    summary: str | None = None
    description: str | None = None
    get: Operation | None = None
    put: Operation | None = None
    post: Operation | None = None
    delete: Operation | None = None
    options: Operation | None = None
    head: Operation | None = None
    patch: Operation | None = None
    trace: Operation | None = None
    servers: list[Server] | None = None
    parameters: list[Parameter | Reference] | None = None
```

### Model Reference

| Construct | Key Fields & Aliases | Description |
| :--- | :--- | :--- |
| `OpenAPI.paths` | `dict[str, PathItem \| Any] \| None` | Maps route path templates (`"/users/{user_id}"`) to `PathItem` definitions. |
| `PathItem` | `ref` (`"$ref"`), `get`..`trace`, `parameters`, `servers` | Groups all HTTP method operations and shared path-level parameters for a single path template. |
| `Operation` | `operationId`, `tags`, `summary`, `parameters`, `requestBody`, `responses`, `callbacks`, `security` | Describes a single HTTP method endpoint, its inputs, status-keyed `Response` map, and security scopes. |
| `Parameter` | `name`, `in_` (`"in"`), `required`, `schema_` (`"schema"`), `examples` | Query, header, path, or cookie parameter (`ParameterInType`); serialize with `by_alias=True, exclude_none=True`. |

### Example

```python
from fastapi.openapi.models import Operation, Parameter, ParameterInType, PathItem, Response, Schema

item_id_param = Parameter(
    name="item_id",
    **{"in": ParameterInType.path, "schema": Schema(type="integer", minimum=1)},
    required=True,
)
path_item = PathItem(
    get=Operation(
        operationId="get_item",
        summary="Fetch item by ID",
        parameters=[item_id_param],
        responses={"200": Response(description="Item found")},
    )
)

dumped = path_item.model_dump(by_alias=True, exclude_none=True)
assert dumped["get"]["parameters"][0]["in"] == ParameterInType.path
assert dumped["get"]["parameters"][0]["schema"] == {"type": "integer", "minimum": 1.0}
```

---

## `model` Components / Schema / SecurityScheme

Reusable specification building blocks in `fastapi.openapi.models`: `Components` stores shared dictionaries, `Schema` implements the full JSON Schema `2020-12` + OpenAPI `3.1.0` vocabulary (`SchemaOrBool = Schema | bool`), and `SecurityScheme` is the union of `APIKey`, `HTTPBase`, `HTTPBearer`, `OAuth2`, and `OpenIdConnect`.

```python
from typing import Any
from pydantic import Field
from fastapi.openapi.models import (
    APIKey,
    BaseModelWithConfig,
    Discriminator,
    Example,
    ExternalDocumentation,
    Header,
    HTTPBase,
    HTTPBearer,
    Link,
    OAuth2,
    OpenIdConnect,
    Parameter,
    PathItem,
    Reference,
    RequestBody,
    Response,
    Schema,
    SchemaOrBool,
    SchemaType,
    XML,
)

SecurityScheme = APIKey | HTTPBase | OAuth2 | OpenIdConnect | HTTPBearer


class Components(BaseModelWithConfig):
    schemas: dict[str, Schema | Reference] | None = None
    responses: dict[str, Response | Reference] | None = None
    parameters: dict[str, Parameter | Reference] | None = None
    examples: dict[str, Example | Reference] | None = None
    requestBodies: dict[str, RequestBody | Reference] | None = None
    headers: dict[str, Header | Reference] | None = None
    securitySchemes: dict[str, SecurityScheme | Reference] | None = None
    links: dict[str, Link | Reference] | None = None
    callbacks: dict[str, dict[str, PathItem] | Reference | Any] | None = None
    pathItems: dict[str, PathItem | Reference] | None = None
```

### Model & Union Reference

| Symbol | Key Fields / Variants | Description |
| :--- | :--- | :--- |
| `Components` | `schemas`, `securitySchemes`, `responses`, `parameters`, `requestBodies`, `headers`, `pathItems` | Container under `#/components/...` referenced by `Reference` (`$ref`). |
| `Schema` | `type` (`SchemaType \| list[SchemaType]`), `properties`, `items`, `prefixItems`, `anyOf`/`oneOf`/`allOf`, `ref` (`"$ref"`), `defs` (`"$defs"`), `discriminator`, `examples` | JSON Schema `2020-12` object supporting nullable union types (`type=["string", "null"]`), `contentMediaType` / `contentSchema`, and OpenAPI `discriminator`. |
| `SecurityScheme` | `APIKey` \| `HTTPBase` \| `HTTPBearer` \| `OAuth2` \| `OpenIdConnect` | Union of OpenAPI 3.1 authentication schemes (`type` aliased on `type_`: `"apiKey"`, `"http"`, `"oauth2"`, `"openIdConnect"`). |

### Example

```python
from fastapi.openapi.models import APIKey, APIKeyIn, Components, HTTPBearer, Schema

components = Components(
    schemas={
        "TokenPayload": Schema(
            type="object",
            properties={
                "sub": Schema(type="string"),
                "nickname": Schema(type=["string", "null"]),
            },
            required=["sub"],
        )
    },
    securitySchemes={
        "BearerAuth": HTTPBearer(bearerFormat="JWT"),
        "PartnerKey": APIKey(**{"in": APIKeyIn.header}, name="X-Partner-Key"),
    },
)

payload = components.model_dump(by_alias=True, exclude_none=True)
assert payload["schemas"]["TokenPayload"]["properties"]["nickname"]["type"] == ["string", "null"]
assert payload["securitySchemes"]["BearerAuth"]["scheme"] == "bearer"
assert payload["securitySchemes"]["PartnerKey"]["name"] == "X-Partner-Key"
```
