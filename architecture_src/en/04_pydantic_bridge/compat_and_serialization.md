# `fastapi/_compat/v2.py`, `ModelField`, Body Slicing & `serialize_response()`

FastAPI isolates Pydantic's internal validation, schema generation, and Rust serialization APIs behind a dedicated adapter package: `fastapi/_compat/` (`__init__.py`, `shared.py`, and `v2.py`). In FastAPI `v0.162.2`, legacy `pydantic.v1` support has been retired (`PydanticV1NotSupportedError`), making `v2.py` the single active engine while preserving `ModelField` as the uniform abstraction representing every query parameter, header, request body, and response model across routing, dependency resolution, and OpenAPI 3.1 synthesis.

```drawlib align=center code=hide file=modelfield_typeadapter_bridge.png caption="The fastapi/_compat/v2.py adapter boundary: wrapping FieldInfo and Pydantic v2 TypeAdapter inside ModelField for validation, Rust JSON serialization, and OpenAPI schema generation."
from drawlib.canvas import setup
from drawlib.diagrams.architecture import ArchitectureDiagram, Node, NodeGroup, PhosphorIcon
from drawlib.styles import Colors, Styles

setup(width=192, height=112)

d = ArchitectureDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.5),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
    title="Pydantic v2 Bridge: ModelField, TypeAdapter & Body Synthesis",
)

in_grp = d.add(
    NodeGroup(
        title="Route Declarations",
        padding=5.5,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left"),
    ),
    xy=(4.0, 4.0),
)
param_decl = in_grp.add(
    Node(
        "Params & Return Types\nFieldInfo + Annotations",
        width=35,
        height=16,
        icon=PhosphorIcon.CODE,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(23.0, 68.0),
)
flat_decl = in_grp.add(
    Node(
        "Single Body Model\nembed=False (Flat)",
        width=35,
        height=16,
        icon=PhosphorIcon.FILE_TEXT,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(23.0, 41.0),
)
multi_decl = in_grp.add(
    Node(
        "Multi Body / Form / File\nembed=True",
        width=35,
        height=16,
        icon=PhosphorIcon.PACKAGE,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(23.0, 14.0),
)

compat_grp = d.add(
    NodeGroup(
        title="fastapi/_compat/v2.py",
        padding=5.5,
        style=Styles.PrimaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left"),
    ),
    xy=(63.0, 4.0),
)
mf_core = compat_grp.add(
    Node(
        "ModelField.__post_init__\nTypeAdapter(Annotated)",
        width=40,
        height=16,
        icon=PhosphorIcon.CPU,
        icon_size=6.5,
        card_style=Styles.PrimaryFlat,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.5),
    ),
    xy=(25.5, 68.0),
)
body_router = compat_grp.add(
    Node(
        "_get_body_field()\nPassthrough vs Composite",
        width=40,
        height=16,
        icon=PhosphorIcon.ARROWS_SPLIT,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(25.5, 41.0),
)
synth_model = compat_grp.add(
    Node(
        "create_body_model()\nBody_<unique_id>",
        width=40,
        height=16,
        icon=PhosphorIcon.WRENCH,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(25.5, 14.0),
)

out_grp = d.add(
    NodeGroup(
        title="Runtime & OpenAPI",
        padding=5.5,
        style=Styles.SecondaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left"),
    ),
    xy=(127.0, 4.0),
)
val_engine = out_grp.add(
    Node(
        "field.validate()\nvalidate_python + loc",
        width=38,
        height=16,
        icon=PhosphorIcon.SHIELD_CHECK,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(24.5, 68.0),
)
ser_engine = out_grp.add(
    Node(
        "serialize_json()\nRust dump_json() bytes",
        width=38,
        height=16,
        icon=PhosphorIcon.LIGHTNING,
        icon_size=6.5,
        card_style=Styles.AccentFlat,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.5),
    ),
    xy=(24.5, 41.0),
)
oas_engine = out_grp.add(
    Node(
        "get_definitions()\nGenerateJsonSchema $defs",
        width=38,
        height=16,
        icon=PhosphorIcon.TABLE,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(24.5, 14.0),
)

d.connect(param_decl, mf_core, padding=1.2)
d.connect(flat_decl, body_router, padding=1.2)
d.connect(multi_decl, synth_model, padding=1.2)

d.connect(synth_model, body_router, label="BaseModel", padding=1.2)
d.connect(body_router, mf_core, label="body_field", padding=1.2)

j_r_top = d.junction(xy=(120.0, 72.0))
j_r_mid = d.junction(xy=(120.0, 45.0))
j_r_bot = d.junction(xy=(120.0, 18.0))
d.connect(mf_core, j_r_top, arrow="-", padding=(1.2, 0.0))
d.connect(j_r_top, j_r_bot, arrow="-")
j_r_top.connect(val_engine, padding=(0.0, 1.2))
j_r_mid.connect(ser_engine, padding=(0.0, 1.2))
j_r_bot.connect(oas_engine, padding=(0.0, 1.2))

d.draw(xy=(6.0, 5.0))
```

## 1. Why `fastapi/_compat/` Isolates Pydantic Internals

Pydantic v2 replaced v1's per-field `ModelField` runtime with whole-type `TypeAdapter` instances backed by `pydantic-core` Rust validators and `CoreSchema` trees. Rather than scattering `TypeAdapter`, `FieldInfo` cloning, and private `pydantic._internal` calls throughout `routing.py`, `dependencies/utils.py`, and `openapi/utils.py`, FastAPI encapsulates all Pydantic interaction inside two modules:

- **`fastapi/_compat/shared.py`**: Pure type-introspection predicates (`lenient_issubclass`, `field_annotation_is_scalar`, `field_annotation_is_sequence`, `field_annotation_is_scalar_sequence`, `is_uploadfile_or_nonable_uploadfile_annotation`, `is_bytes_or_nonable_bytes_annotation`) used during compile-time parameter classification.
- **`fastapi/_compat/v2.py`**: Implements `ModelField`, custom `GenerateJsonSchema` (overriding `bytes_schema` to emit OpenAPI 3.1 `contentMediaType: "application/octet-stream"` and `contentEncoding: "base64"`), `get_definitions()` (separating `"validation"` and `"serialization"` `$defs` schemas when `separate_input_output_schemas=True`), `evaluate_forwardref()`, and `create_body_model()`.

### 1.1 Anatomy of `ModelField` (`v2.py`)

`ModelField` is a `@dataclass` holding `field_info: FieldInfo`, `name: str`, `mode: Literal["validation", "serialization"] = "validation"`, and `config: ConfigDict | None = None` (with `__hash__` returning `id(self)` so instances can key schema dictionaries):

1. **Startup `TypeAdapter` Compilation (`__post_init__`)**: Extracts `(annotation, metadata, attributes)` from `self.field_info` via `asdict()`, suppresses Pydantic 2.12+ `UnsupportedFieldAttributeWarning` when standalone `Field(alias=...)` metadata is present, reconstructs `Annotated[annotation, *metadata, Field(**attributes)]`, and compiles `self._type_adapter = TypeAdapter(..., config=self.config)` once at route registration.
2. **Location-Prefixed Validation (`validate`)**: Calls `self._type_adapter.validate_python(value, from_attributes=True)` (enabling ORM object validation automatically). When `ValidationError` is raised, `_regenerate_error_with_loc()` strips Pydantic documentation URLs (`include_url=False`) and prepends FastAPI's contextual location tuple—such as `("query", "limit")`, `("body", "item")`, or `("response",)`—to every error's `"loc"` path.
3. **Dual Serialization Modes (`serialize` vs `serialize_json`)**: `serialize()` invokes `self._type_adapter.dump_python(value, mode=mode, ...)` to produce JSON-safe Python `dict`/`list` structures, whereas `serialize_json()` invokes `self._type_adapter.dump_json(value, ...)` to serialize **directly into UTF-8 JSON `bytes` inside Rust**, eliminating intermediate Python dictionary allocation and `json.dumps()` overhead.

## 2. Body Slicing, `embed=True` & `create_body_model()`

HTTP has only a single request payload stream, yet a FastAPI endpoint and its sub-dependencies may declare multiple `Body()`, `Form()`, or `File()` parameters simultaneously. FastAPI reconciles this through a two-stage compile-and-slice design:

| Endpoint Body Declaration | `_should_embed_body_fields()` | `APIRoute.body_field` (`_get_body_field`) | Runtime Validation in `request_body_to_args()` |
| :--- | :--- | :--- | :--- |
| **Single `BaseModel` (`item: Item`)** | `False` | Unwrapped `body_params[0]` (`annotation is Item`) | Validates root JSON payload directly with `loc=("body",)`. |
| **Single `BaseModel` with `Body(embed=True)`** | `True` | Synthesized `Body_<unique_id>` wrapping `{"item": Item}` | Extracts `body.get("item")` and validates with `loc=("body", "item")`. |
| **Multiple `Body()` / Sub-Dependency Bodies** | `True` | Synthesized `Body_<unique_id>` merging all distinct fields | Each `Dependant` slices only its own declared `body_params` keys from `body`. |
| **Scalar `Form()` or `File()` Parameters** | `True` | Synthesized `Body_<unique_id>` (`File` > `Form` > `Body` priority) | Streams `FormData` via `_extract_form_body()`; seeks `UploadFile` back via `_read_file_bytes()`. |

Two subtle invariants in `fastapi/dependencies/utils.py` deserve particular attention:

- **`APIRoute.body_field` Is for Media-Type Detection & OpenAPI Only**: As noted in `_get_body_field()`'s docstring, `create_body_model(fields=..., model_name="Body_" + name)` (which delegates to `pydantic.create_model()`) is used to detect form/multipart encoding (`isinstance(body_field.field_info, params.Form)`) and to emit the unified OpenAPI `requestBody` schema. At runtime, `solve_dependencies()` does **not** instantiate `Body_<unique_id>`; instead, each `Dependant` validates its own `body_params` slice via `request_body_to_args()`, allowing sub-dependencies and endpoints to consume disjoint keys of the same JSON object or `FormData`.
- **Non-Destructive Shared File Reads (`_read_file_bytes`)**: When a parameter annotates a `File()` upload as `bytes`, `_read_file_bytes()` records `position = file.file.tell()`, awaits `file.read()`, and restores `await file.seek(position)` inside a `finally` block so another dependency sharing the same `UploadFile` does not read an exhausted stream.

## 3. Response Pipeline: `serialize_response()` & `jsonable_encoder()`

After `run_endpoint_function()` returns `raw_response` inside `get_request_handler()` (`fastapi/routing.py`), FastAPI selects the fastest safe serialization path based on the return value and route configuration:

1. **Raw `Response` Passthrough**: If `isinstance(raw_response, Response)` is `True` (e.g., returning a custom `StreamingResponse`, `FileResponse`, or `JSONResponse`), FastAPI attaches `solved_result.background_tasks` if `raw_response.background is None` and returns it untouched—bypassing `serialize_response()` completely.
2. **Typed `response_field` Validation (`field is not None`)**: Unless `response_model=None` was explicitly set or the return annotation is a `Response` subclass, `APIRoute` compiles `route.response_field = create_model_field(..., mode="serialization")`. Inside `serialize_response()`:
   - Async endpoints call `field.validate(response_content, {}, loc=("response",))` inline; sync `def` endpoints offload validation via `await run_in_threadpool(field.validate, ...)` so CPU-heavy model coercion never blocks the event loop.
   - Any validation failure raises `ResponseValidationError` (resulting in HTTP `500 Internal Server Error`), preventing accidental leakage of unvalidated internal attributes.
   - **Rust One-Pass Fast Path (`use_dump_json=True`)**: When `response_class` is the default `DefaultPlaceholder(JSONResponse)`, `get_request_handler()` passes `dump_json=True`. `serialize_response()` calls `field.serialize_json(...)` (respecting `include`, `exclude`, `by_alias`, `exclude_unset`, `exclude_defaults`, and `exclude_none`) and wraps the returned UTF-8 `bytes` directly in `Response(content=content, media_type="application/json")`.
   - **Custom `response_class` Path (`use_dump_json=False`)**: When a custom `response_class` (such as `ORJSONResponse` or a custom XML/YAML responder) is configured, `serialize_response()` calls `field.serialize(...)` (`dump_python(mode="json")`) and passes the Python object to `actual_response_class(content, **response_args)`.
3. **Untyped Fallback (`jsonable_encoder` in `fastapi/encoders.py`)**: When `response_field is None`, `serialize_response()` delegates to `jsonable_encoder(response_content)`. It recursively converts `BaseModel` (`model_dump(mode="json")`), `dataclass` (`dataclasses.asdict`), `Enum` (`.value`), `PurePath`, `dict` (stripping SQLAlchemy internal `_sa*` keys when `sqlalchemy_safe=True`), iterables/generators, and `ENCODERS_BY_TYPE` entries (`datetime`/`date`/`time` $\rightarrow$ `isoformat()`, `timedelta` $\rightarrow$ `total_seconds()`, `Decimal` $\rightarrow$ `int` when exponent $\ge 0$ else `float`, `UUID` / `IPv4Address` / `Url` $\rightarrow$ `str`), finally falling back to `dict(obj)` and `vars(obj)`.

```drawlib align=center code=hide file=serialize_response_decision_tree.png caption="Decision flow inside get_request_handler() and serialize_response(): raw Response bypass, response_field validation, Rust dump_json fast path, and jsonable_encoder() fallback."
from drawlib.canvas import setup
from drawlib.diagrams.flow import Data, Decision, End, FlowDiagram, Process, Start
from drawlib.styles import Colors, Styles

setup(width=192, height=116)

flow = FlowDiagram(
    node_style=Styles.Neutral.patch(text_size=10.5),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.DarkBold.patch(text_size=10.0),
    title="Response Validation & Serialization Decision Tree",
)

start = flow.add(
    Start("Endpoint Return\nraw_response", width=32, height=12, style=Styles.PrimaryNeutral.patch(text_size=10.5)),
    xy=(28.0, 86.0),
)
is_resp = flow.add(
    Decision("isinstance(\nResponse)?", width=32, height=16, style=Styles.Neutral.patch(text_size=10.0)),
    xy=(90.0, 86.0),
)
direct_out = flow.add(
    End("Attach Background\n& Return Directly", width=36, height=12, style=Styles.SecondaryNeutral.patch(text_size=10.0)),
    xy=(154.0, 86.0),
)

encoder_fb = flow.add(
    Process("jsonable_encoder()\nDecimal / UUID / strip _sa", width=38, height=14, style=Styles.Neutral.patch(text_size=10.0)),
    xy=(28.0, 60.0),
)
has_field = flow.add(
    Decision("response_field\nDefined?", width=32, height=16, style=Styles.Neutral.patch(text_size=10.0)),
    xy=(90.0, 60.0),
)
validate_step = flow.add(
    Process("field.validate(loc='response')\nasync or run_in_threadpool", width=42, height=14, style=Styles.PrimaryNeutral.patch(text_size=10.0)),
    xy=(154.0, 60.0),
)

json_resp_fb = flow.add(
    End("JSONResponse(\nencoded_data)", width=32, height=12, style=Styles.SecondaryNeutral.patch(text_size=10.0)),
    xy=(28.0, 34.0),
)
dump_mode = flow.add(
    Decision("use_dump_json?\n(Default Class)", width=34, height=16, style=Styles.Neutral.patch(text_size=10.0)),
    xy=(90.0, 34.0),
)
has_err = flow.add(
    Decision("Validation\nErrors?", width=32, height=16, style=Styles.Neutral.patch(text_size=10.0)),
    xy=(154.0, 34.0),
)

py_dict = flow.add(
    End("field.serialize()\ncustom response_class", width=38, height=12, style=Styles.SecondaryNeutral.patch(text_size=10.0)),
    xy=(28.0, 8.0),
)
rust_bytes = flow.add(
    End(
        "field.serialize_json()\nRust UTF-8 bytes",
        width=38,
        height=12,
        style=Styles.PrimaryFlat,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
    ),
    xy=(90.0, 8.0),
)
err_500 = flow.add(
    Data("ResponseValidationError\n(HTTP 500)", width=40, height=12, style=Styles.DangerNeutral.patch(text_size=10.0)),
    xy=(154.0, 8.0),
)

start.connect(is_resp, padding=1.0)
is_resp.connect(direct_out, label="Yes", start_side="right", end_side="left", padding=1.0)
is_resp.connect(has_field, label="No", start_side="bottom", end_side="top", padding=1.0)

has_field.connect(encoder_fb, label="No", start_side="left", end_side="right", padding=1.0)
has_field.connect(validate_step, label="Yes", start_side="right", end_side="left", padding=1.0)

encoder_fb.connect(json_resp_fb, start_side="bottom", end_side="top", padding=1.0)
validate_step.connect(has_err, start_side="bottom", end_side="top", padding=1.0)

has_err.connect(err_500, label="Yes", start_side="bottom", end_side="top", padding=1.0)
has_err.connect(dump_mode, label="No", start_side="left", end_side="right", padding=1.0)

dump_mode.connect(rust_bytes, label="Yes", start_side="bottom", end_side="top", padding=1.0)
dump_mode.connect(py_dict, label="No", start_side="left", end_side="right", padding=1.0).via(
    (59.0, 34.0), (59.0, 8.0)
)

flow.draw(xy=(6.0, 4.0))
```

## 4. Inspecting `APIRoute.body_field` Synthesis & `serialize_response()`

The snippet below compares `APIRoute.body_field` on single-model vs multi-parameter endpoints and contrasts `serialize_response(dump_json=True)` (Rust `bytes` output) against the `jsonable_encoder()` untyped fallback:

```python
import asyncio
from decimal import Decimal
from typing import Annotated
from uuid import UUID

from fastapi import Body, FastAPI
from fastapi._compat import ModelField
from fastapi.encoders import jsonable_encoder
from fastapi.routing import APIRoute, serialize_response
from fastapi.utils import create_model_field
from pydantic import BaseModel, Field


class ItemCreate(BaseModel):
    title: str
    quantity: int = 1


class InvoiceOut(BaseModel):
    invoice_id: UUID = Field(serialization_alias="id")
    amount: Decimal
    note: str | None = None


app = FastAPI()


@app.post("/single")
async def create_single(item: ItemCreate) -> dict[str, str]:
    return {"title": item.title}


@app.post("/multi")
async def create_multi(
    item: ItemCreate,
    priority: Annotated[int, Body(ge=1)],
) -> dict[str, str]:
    return {"title": item.title, "priority": str(priority)}


routes = {r.path: r for r in app.routes if isinstance(r, APIRoute)}

# 1. Single BaseModel stays flat; multi-body synthesizes Body_<unique_id>
assert routes["/single"]._embed_body_fields is False
assert routes["/single"].body_field.field_info.annotation is ItemCreate

assert routes["/multi"]._embed_body_fields is True
synthesized_cls = routes["/multi"].body_field.field_info.annotation
assert synthesized_cls.__name__.startswith("Body_create_multi")
assert set(synthesized_cls.model_fields.keys()) == {"item", "priority"}

# 2. Rust dump_json fast path vs jsonable_encoder() fallback
out_field: ModelField = create_model_field(
    name="Response_Invoice",
    type_=InvoiceOut,
    mode="serialization",
)
sample_uuid = UUID("12345678-1234-5678-1234-567812345678")

raw_bytes = asyncio.run(
    serialize_response(
        field=out_field,
        response_content={"invoice_id": str(sample_uuid), "amount": "19.95"},
        by_alias=True,
        exclude_none=True,
        dump_json=True,
    )
)
assert raw_bytes == b'{"id":"12345678-1234-5678-1234-567812345678","amount":"19.95"}'

fallback_dict = asyncio.run(
    serialize_response(
        field=None,
        response_content={
            "id": sample_uuid,
            "total": Decimal("42"),
            "_sa_instance_state": object(),
        },
    )
)
assert fallback_dict == {
    "id": "12345678-1234-5678-1234-567812345678",
    "total": 42,
}
assert jsonable_encoder(Decimal("42.50")) == 42.5
```

For how `APIRoute` wires `body_field` and `response_field` into its per-route request closure, see [APIRouter, APIRoute & Handler Closure](../02_routing_compiler/apiroute_and_closures.md); for how `get_definitions()` turns `ModelField` lists into OpenAPI 3.1 JSON Schemas, see [get_openapi(), $defs & Docs UI](../06_openapi_and_docs/openapi_synthesis_engine.md).
