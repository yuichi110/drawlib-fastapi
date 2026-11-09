# Dependant DAG Compilation & `solve_dependencies()`

FastAPI's dependency injection (DI) engine separates signature reflection from request execution across two phases: **route-registration compilation** (`get_dependant()` and `analyze_param()` in `fastapi/dependencies/utils.py`) and **per-request recursive resolution** (`solve_dependencies()` paired with `Dependant` in `fastapi/dependencies/models.py`). Every endpoint and sub-dependency is compiled once at startup into a memory-compact `Dependant` directed acyclic graph (DAG), enabling runtime execution to traverse pre-classified `ModelField` buckets, memoize results by a 3-tuple cache key, accumulate validation errors across the entire tree, and deterministically unwind generator lifetimes across nested `AsyncExitStack` scopes.

```drawlib align=center code=hide file=dependant_compilation_dag.png caption="Compile-time transformation from Python signature annotations into a slotted Dependant DAG and 3-tuple DependencyCacheKey."
from drawlib.canvas import setup
from drawlib.diagrams.architecture import ArchitectureDiagram, Node, NodeGroup, PhosphorIcon
from drawlib.styles import Colors, Styles

setup(width=176, height=112)

d = ArchitectureDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.5),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
    title="Compile-Time Dependant DAG & Cache Key Synthesis",
)

sig = d.add(
    Node(
        "Endpoint Signature\nget_typed_signature()",
        width=32,
        height=18,
        icon=PhosphorIcon.CODE,
        icon_size=7.0,
        card_style=Styles.PrimaryFlat,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.5),
    ),
    xy=(18.0, 68.0),
)
analyzer = d.add(
    Node(
        "analyze_param()\nAnnotated & Defaults",
        width=32,
        height=18,
        icon=PhosphorIcon.FUNNEL,
        icon_size=7.0,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(18.0, 32.0),
)

root_grp = d.add(
    NodeGroup(
        title="Root Dependant (slots=True)",
        padding=6.0,
        style=Styles.Neutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left"),
    ),
    xy=(48.0, 4.0),
)
buckets = root_grp.add(
    Node(
        "ModelField Buckets\npath / query / body",
        width=34,
        height=16,
        icon=PhosphorIcon.TABLE,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(23.0, 68.0),
)
special = root_grp.add(
    Node(
        "Framework Slots\nRequest / Tasks / Scopes",
        width=34,
        height=16,
        icon=PhosphorIcon.PLUGS_CONNECTED,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(23.0, 41.0),
)
sub_list = root_grp.add(
    Node(
        "dependencies: list\nChild Dependant Nodes",
        width=34,
        height=16,
        icon=PhosphorIcon.GIT_BRANCH,
        icon_size=6.5,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(23.0, 14.0),
)

sub_grp = d.add(
    NodeGroup(
        title="Sub-Dependants & Cache",
        padding=6.0,
        style=Styles.SecondaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left"),
    ),
    xy=(112.0, 4.0),
)
auth_dep = sub_grp.add(
    Node(
        "Security Dependant\nown + parent scopes",
        width=36,
        height=16,
        icon=PhosphorIcon.SHIELD_CHECK,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(24.0, 68.0),
)
db_dep = sub_grp.add(
    Node(
        "Generator Dependant\ncomputed_scope='request'",
        width=36,
        height=16,
        icon=PhosphorIcon.DATABASE,
        icon_size=6.5,
        card_style=Styles.White,
    ),
    xy=(24.0, 41.0),
)
cache_node = sub_grp.add(
    Node(
        "DependencyCacheKey\n(call, scopes, scope)",
        width=36,
        height=16,
        icon=PhosphorIcon.KEY,
        icon_size=6.5,
        card_style=Styles.AccentFlat,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.5),
    ),
    xy=(24.0, 14.0),
)

d.connect(sig, analyzer, label="inspect", padding=1.5)

j_l_mid = d.junction(xy=(40.0, 32.0))
j_l_top = d.junction(xy=(40.0, 72.0))
j_l_slot = d.junction(xy=(40.0, 45.0))
j_l_bot = d.junction(xy=(40.0, 18.0))
d.connect(analyzer, j_l_mid, arrow="-", padding=(1.5, 0.0))
d.connect(j_l_bot, j_l_top, arrow="-")
j_l_top.connect(buckets, padding=(0.0, 1.5))
j_l_slot.connect(special, padding=(0.0, 1.5))
j_l_bot.connect(sub_list, padding=(0.0, 1.5))

j_r_bot = d.junction(xy=(102.0, 18.0))
j_r_mid = d.junction(xy=(102.0, 45.0))
j_r_top = d.junction(xy=(102.0, 72.0))
d.connect(sub_list, j_r_bot, arrow="-", padding=(1.5, 0.0))
d.connect(j_r_bot, j_r_top, arrow="-")
j_r_top.connect(auth_dep, padding=(0.0, 1.5))
j_r_mid.connect(db_dep, padding=(0.0, 1.5))

d.connect(auth_dep, db_dep, label="Depends", padding=1.2)
d.connect(db_dep, cache_node, label="_get_cache_key()", padding=1.2)

d.draw(xy=(6.0, 5.0))
```

## 1. The `Dependant` Dataclass & Field Slots

In `fastapi/dependencies/models.py`, `Dependant` is defined with `@dataclass(slots=True)`. Eliminating per-instance `__dict__` dictionaries keeps memory overhead low even when large applications mount hundreds of routes with deep router- and operation-level sub-dependency chains. Each `Dependant` node partitions a callable's inputs into five `ModelField` validation lists, a child `dependencies` edge list, six framework object injection slots, and OAuth2 scope metadata:

| Field Group | `Dependant` Attributes (`v0.162.2`) | Runtime Role in `solve_dependencies()` |
| :--- | :--- | :--- |
| **Validated Request Params** | `path_params`, `query_params`, `header_params`, `cookie_params` (`list[ModelField]`) | Validated via `request_params_to_args()` against `request.path_params`, `query_params`, `headers`, and `cookies`. |
| **Validated Body Params** | `body_params` (`list[ModelField]`) | Validated via `request_body_to_args()` against parsed JSON or `FormData` (`Body`, `Form`, `File`). |
| **Sub-Dependency Edges** | `dependencies` (`list[Dependant]`) | Traversed depth-first before invoking `self.call`; prepended with parameterless `dependencies=[Depends(...)]` on routes. |
| **Connection Injection Slots** | `request_param_name`, `websocket_param_name`, `http_connection_param_name` (`str \| None`) | Injects `Request` (HTTP only), `WebSocket` (WS only), or Starlette's unified `HTTPConnection` (both HTTP and WS). |
| **Framework Context Slots** | `response_param_name`, `background_tasks_param_name`, `security_scopes_param_name` (`str \| None`) | Injects a shared `Response` header/status collector, `BackgroundTasks` queue, or `SecurityScopes` scope list. |
| **Callable & Scope Metadata** | `name`, `call`, `use_cache`, `path`, `scope`, `own_oauth_scopes`, `parent_oauth_scopes` | Controls parameter binding key, memoization policy, generator exit-stack lifetime, and top-down OAuth2 scope inheritance. |

### 1.1 Computed Scope & the 3-Tuple `DependencyCacheKey`

Because `Dependant` uses `slots=True`, FastAPI computes lifetime scope and cache keys through pure helper functions in `fastapi/dependencies/models.py` backed by an identity-hashed `@lru_cache(maxsize=4096)` (`_CallIdentity`, which hashes `id(call)` so callable objects that do not implement `__hash__` are still classified in $O(1)$ time):

- **`_get_computed_scope(*, dependant: Dependant) -> str | None`**: Returns `dependant.scope` (`"function"` or `"request"`) when explicitly configured; otherwise inspects `_is_gen_callable(dependant.call)` and `_is_async_gen_callable(dependant.call)` (unwrapping `functools.partial` and `__wrapped__` chains plus callable `__call__` methods) and defaults generator dependencies to `"request"`, returning `None` for non-generator callables.
- **`_get_cache_key(*, dependant: Dependant, uses_scopes_cache: _UsesScopesCache | None = None) -> DependencyCacheKey`**: Produces the 3-tuple `(dependant.call, scopes_for_cache, _get_computed_scope(dependant=dependant) or "")` (`DependencyCacheKey = tuple[Callable[..., Any] | None, tuple[str, ...], str]` in `fastapi/types.py`).
- **Scope Pruning via `_uses_scopes()`**: Crucially, `scopes_for_cache` evaluates to `tuple(sorted(set(_get_oauth_scopes(dependant=dependant))))` **only** when `_uses_scopes()` is `True`—meaning the node declares `own_oauth_scopes`, injects `SecurityScopes`, wraps a `SecurityBase` instance, or has a descendant that uses scopes. For non-security dependencies such as a database session generator (`get_db`), `_uses_scopes()` returns `False` and `scopes_for_cache` collapses to `()`, guaranteeing a single shared DB session per request even when `get_db` is called both directly by an endpoint and nested inside `Security(..., scopes=["projects:read"])`.

## 2. Compile-Time Graph Construction (`get_dependant` & `analyze_param`)

When an `APIRoute` or `APIWebSocketRoute` is instantiated, `_build_dependant_with_parameterless_dependencies()` invokes `get_dependant(path=path, call=call, scope="function")` and prepends any decorator-level `dependencies=[Depends(...)]` in reverse order via `get_parameterless_sub_dependant()` so declaration order is preserved. Inside `get_dependant()`:

1. **Typed Signature Extraction (`get_typed_signature`)**: Calls `inspect.signature(call, eval_str=True)` (falling back to PEP 649 `annotationlib.Format.FORWARDREF` on Python 3.14+ when `TYPE_CHECKING`-only names raise `NameError`) and resolves string `ForwardRef` annotations against the unwrapped function's `__globals__` via `evaluate_forwardref()`.
2. **`Annotated` & Default Unpacking (`analyze_param`)**: Unwraps PEP 695 `type` aliases (`is_typealiastype`), extracts `Annotated[T, ...]` metadata, and selects the last FastAPI marker (`Param`, `Body`, or `Depends`). When a `FieldInfo` marker resides inside `Annotated`, `copy_field_info()` clones it before assigning `param.default` (or `RequiredParam`) so reusable `Annotated` type aliases are never mutated across endpoints. Passing FastAPI markers in both `Annotated` and `=` raises an `AssertionError` at startup.
3. **Class-Dependency Shorthand**: When `Depends()` is written with `dependency=None` (e.g., `Annotated[CommonQueryParams, Depends()]`), `analyze_param()` clones the frozen `Depends` dataclass with `dataclasses.replace(depends, dependency=type_annotation)`.
4. **Implicit Parameter Classification**: If a parameter carries neither `Depends`, a framework injection type (`Request`, `WebSocket`, `HTTPConnection`, `Response`, `BackgroundTasks`, `SecurityScopes`), nor an explicit `Query`/`Path`/`Header`/`Cookie`/`Body` marker, `analyze_param()` classifies it deterministically:
   - `param_name in path_param_names` (parsed from `{...}` placeholders in `path`) $\rightarrow$ `params.Path` (asserted to be a scalar type).
   - `UploadFile` or sequence of `UploadFile` $\rightarrow$ `params.File`.
   - Non-scalar type (`not field_annotation_is_scalar()`, covering `BaseModel`, `Mapping`, non-bytes `Sequence`, `dataclass`, or custom Pydantic schema types) $\rightarrow$ `params.Body`.
   - Any remaining scalar annotation $\rightarrow$ `params.Query`.
5. **Startup Scope Hierarchy Guard (`DependencyScopeError`)**: Before recursing into a child `Depends`, `get_dependant()` checks whether the parent is a generator with `_get_computed_scope(dependant) == "request"` while the child explicitly requests `scope="function"`. Because a `"function"`-scoped resource tears down before response streaming while a `"request"`-scoped parent generator outlives streaming, FastAPI rejects this inverted lifetime at startup with `DependencyScopeError`.

## 3. Runtime Execution in `solve_dependencies()`

On each incoming HTTP request (`get_request_handler`) or WebSocket handshake (`get_websocket_app`), `solve_dependencies()` executes a recursive depth-first post-order walk over `dependant`:

- **Dynamic Dependency Overrides**: For every `sub_dependant` in `dependant.dependencies`, FastAPI checks `dependency_overrides_provider.dependency_overrides` (`app.dependency_overrides`). If `sub_dependant.call` is mapped to a test/mock callable, `solve_dependencies()` dynamically compiles `use_sub_dependant = get_dependant(...)` inheriting `_get_oauth_scopes(sub_dependant)` and `sub_dependant.scope`, while still keying `dependency_cache` by the original `sub_dependant` cache key.
- **Execution Dispatch & Memoization**: After awaiting `solve_dependencies()` for a child's own inputs, if `sub_dependant.use_cache` is `True` and `sub_dependant_cache_key` exists in `dependency_cache`, the cached value is reused immediately. Otherwise FastAPI dispatches by callable kind:
  - **Generators (`yield`)**: Routed to `_solve_generator()`, which wraps async generators with `asynccontextmanager(call)(**sub_values)` and sync generators with `contextmanager_in_threadpool(contextmanager(call)(**sub_values))` before entering the selected `AsyncExitStack`.
  - **Async Coroutines (`async def`)**: Awaited directly on the event loop via `await call(**solved_result.values)`.
  - **Sync Functions & Classes (`def` / `class`)**: Offloaded via Starlette's `await run_in_threadpool(call, **solved_result.values)` so blocking I/O does not stall the ASGI loop.
- **Full-Tree Error Accumulation (No Fail-Fast)**: When a child `Dependant` produces validation errors (`solved_result.errors`), `solve_dependencies()` appends those errors, skips invoking that broken child's `call`, and **continues** evaluating remaining sibling dependencies plus all local `path_params`, `query_params`, `header_params`, `cookie_params`, and `body_params`. Only after the entire `Dependant` tree finishes does `get_request_handler` raise `RequestValidationError(errors)` (HTTP 422) or `WebSocketRequestValidationError`, returning every invalid parameter across headers, query strings, sub-dependencies, and JSON body fields in a single round-trip.

### 3.1 The Dual `AsyncExitStack` Lifetime Architecture

FastAPI `v0.162.2` manages `yield` dependency teardown using **two nested `AsyncExitStack` instances** created inside `request_response()` (`fastapi/routing.py`)—alongside an outer `fastapi_middleware_astack` created by `AsyncExitStackMiddleware` (`fastapi/middleware/asyncexitstack.py`) exclusively to close multipart `FormData` temporary files after the full middleware chain completes:

1. **`fastapi_function_astack` (`scope="function"`)**: Enters just before `response = await f(request)` and **exits immediately after `f(request)` returns the constructed `Response`**, *prior* to `await response(scope, receive, send)`. Generator dependencies configured with `Depends(dep, scope="function")` run their post-`yield` cleanup after `run_endpoint_function()` and `serialize_response()` finish, while HTTP headers have not yet been sent over the socket.
2. **`fastapi_inner_astack` (`scope="request"`, default for `yield` dependencies)**: Wraps both `f(request)` and `await response(scope, receive, send)`, exiting **only after the ASGI response body finishes streaming** (including `StreamingResponse`, JSONL/SSE generators, and response-attached `BackgroundTasks`). If an exception occurs inside the endpoint and a `yield` dependency swallows it with a bare `except:` without re-raising, `response_awaited` remains `False` and `request_response()` raises `FastAPIError("Response not awaited...")` to surface the bug immediately.

```drawlib align=center code=hide file=dual_exitstack_lifetimes.png caption="Nested AsyncExitStack lifetimes in request_response(): function-scoped generators close before ASGI streaming, whereas request-scoped generators outlive streaming."
from drawlib.canvas import setup
from drawlib.diagrams.sequence import Participant, PhosphorIcon, SequenceDiagram
from drawlib.styles import Colors, Styles

setup(width=176, height=128)

d = SequenceDiagram(
    node_style=Styles.Primary,
    node_text_style=Styles.DarkBold.patch(text_size=10.5),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
    title="Dual AsyncExitStack Lifetimes Across Request & Streaming",
    autonumber=True,
    col_width=40.0,
    step_y=7.2,
)

asgi = d.add(
    Participant(
        "request_response\nASGI Wrapper",
        width=30,
        height=14,
        icon=PhosphorIcon.GLOBE,
        icon_size=6.5,
        card_style=Styles.Neutral,
    )
)
stacks = d.add(
    Participant(
        "Dual ExitStacks\n(request.scope)",
        width=30,
        height=14,
        icon=PhosphorIcon.ARCHIVE,
        icon_size=6.5,
        card_style=Styles.PrimaryNeutral,
    )
)
solver = d.add(
    Participant(
        "solve_dependencies\n& Endpoint",
        width=30,
        height=14,
        icon=PhosphorIcon.GEAR,
        icon_size=6.5,
        card_style=Styles.PrimaryFlat,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.5),
    )
)
stream = d.add(
    Participant(
        "ASGI Response\n& Stream Body",
        width=30,
        height=14,
        icon=PhosphorIcon.BROADCAST,
        icon_size=6.5,
        card_style=Styles.SecondaryNeutral,
    )
)

asgi.request(stacks, "Enter fastapi_inner_astack (request)")
asgi.request(stacks, "Enter fastapi_function_astack (function)")
stacks.request(solver, "solve_dependencies() DFS walk")
solver.request(stacks, "enter_async_context(yield_cm) by scope")
solver.reply(asgi, "Return serialized Response object")

with d.opt("") as blk1:
    blk1.style = Styles.Neutral.patch(line_style="dashed")
    stacks.reply(
        asgi,
        "Pre-Send: Exit fastapi_function_astack",
        style=Styles.AccentBold,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    )

asgi.request(stream, "await response(scope, receive, send)")
stream.reply(asgi, "Chunks streamed + BackgroundTasks done")

with d.opt("") as blk2:
    blk2.style = Styles.PrimaryNeutral.patch(line_style="dashed")
    stacks.reply(
        asgi,
        "Post-Stream: Exit fastapi_inner_astack",
        style=Styles.PrimaryBold,
        text_style=Styles.DarkBold.patch(text_size=10.0),
    )

d.draw(xy=(6.0, 4.0))
```

## 4. Inspecting Compiled `Dependant` Trees & Cache Keys

You can call `get_dependant()` together with `_get_computed_scope()` and `_get_cache_key()` directly in Python to inspect how FastAPI classifies parameters and prunes unused OAuth2 scopes from shared generator cache keys:

```python
from typing import Annotated, AsyncIterator

from fastapi import Depends, Request, Security
from fastapi.dependencies.models import _get_cache_key, _get_computed_scope
from fastapi.dependencies.utils import get_dependant
from fastapi.security import SecurityScopes


async def get_db() -> AsyncIterator[str]:
    yield "db_conn"


async def require_actor(
    scopes: SecurityScopes,
    db: Annotated[str, Depends(get_db)],
) -> dict[str, object]:
    return {"db": db, "scopes": scopes.scopes}


async def list_projects(
    org_id: int,
    request: Request,
    db: Annotated[str, Depends(get_db)],
    actor: Annotated[
        dict[str, object],
        Security(require_actor, scopes=["projects:read"]),
    ],
    limit: int = 20,
) -> dict[str, object]:
    return {"org_id": org_id, "limit": limit, "db": db, "actor": actor}


root = get_dependant(
    path="/orgs/{org_id}/projects",
    call=list_projects,
    scope="function",
)

assert [f.name for f in root.path_params] == ["org_id"]
assert [f.name for f in root.query_params] == ["limit"]
assert root.request_param_name == "request"

db_direct, actor_dep = root.dependencies
db_nested = actor_dep.dependencies[0]

assert _get_computed_scope(dependant=db_direct) == "request"
# Non-security sub-dependency collapses scopes_for_cache to () in both branches:
assert _get_cache_key(dependant=db_direct) == (get_db, (), "request")
assert _get_cache_key(dependant=db_nested) == (get_db, (), "request")
assert _get_cache_key(dependant=actor_dep) == (
    require_actor,
    ("projects:read",),
    "",
)
```

Next, see [SecurityBase & HTTPConnection](security_internals.md) for how authentication schemes plug into `Dependant` and OpenAPI, and [_compat/v2.py, ModelField & Serialization](../04_pydantic_bridge/compat_and_serialization.md) for how `ModelField` validates each extracted parameter.
