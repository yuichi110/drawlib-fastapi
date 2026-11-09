# FastAPI User Guide

- [Guide Overview](index.md)

## 1. Introduction & Quickstart
- [Why FastAPI & Design Philosophy](01_getting_started/overview.md)
- [Quickstart & Interactive OpenAPI](01_getting_started/quickstart.md)

## 2. Scaling to 100k+ LOC
- [Bounded Contexts & Layering](02_enterprise_architecture/modular_design.md)
- [Enterprise DI, Lifespan & Testing](02_enterprise_architecture/di_lifespan_testing.md)

## 3. Routing, Validation & Models
- [Path, Query, Header, Cookie & Body](03_routing_and_models/parameters_and_validation.md)
- [Response Serialization & OpenAPI 3.1](03_routing_and_models/responses_and_openapi.md)
- [Parameter Models, Extra Types & Examples](03_routing_and_models/advanced_types_and_models.md)
- [Custom Request & APIRoute Classes](03_routing_and_models/custom_request_and_route.md)

## 4. Dependency Injection & Security
- [Dependency Graph, Caching & Scopes](04_dependencies_and_security/dependency_injection.md)
- [Authentication & OAuth2 Scopes](04_dependencies_and_security/security_and_auth.md)
- [JWT (PyJWT + Argon2) & WS Security](04_dependencies_and_security/jwt_and_websocket_security.md)

## 5. Async, Middleware & Streaming
- [ASGI Middleware & Threadpool](05_async_and_realtime/concurrency_and_middleware.md)
- [Native SSE, JSONL & WebSockets](05_async_and_realtime/sse_websockets_streaming.md)

## 6. Observability, Errors & Testing
- [Native OpenTelemetry & Exceptions](06_observability_and_testing/telemetry_and_errors.md)
- [Testing Patterns & Production ASGI](06_observability_and_testing/testing_and_deployment.md)

## 7. Frontend, Sub-Apps & OpenAPI
- [SPA frontend(), StaticFiles & Mounts](07_frontend_and_openapi_ext/frontend_templates_mounts.md)
- [Webhooks, Callbacks, SDKs & Docs UI](07_frontend_and_openapi_ext/webhooks_callbacks_sdks.md)

## 8. Settings, Databases & Ecosystem
- [pydantic-settings & SQL Databases](08_ecosystem_and_operations/settings_and_databases.md)
- [FastAPI CLI, Proxies, GraphQL & AI](08_ecosystem_and_operations/cli_proxy_graphql_ai.md)

## Companion Guides & Links
- [FastAPI Internal Architecture](https://fastapi.drawlib.com/architecture/)
- [Official FastAPI Docs](https://fastapi.tiangolo.com/)
- [GitHub Repository](https://github.com/yuichi110/drawlib-fastapi)
