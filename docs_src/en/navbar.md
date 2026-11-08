# FastAPI Visual Guide

- [Overview & Architecture Map](index.md)

## 1. Introduction & Quickstart
- [Why FastAPI & Design Philosophy](01_getting_started/overview.md)
- [Quickstart & Interactive OpenAPI](01_getting_started/quickstart.md)

## 2. Scaling to 100k+ LOC
- [Bounded Contexts & Layering](02_enterprise_architecture/modular_design.md)
- [Enterprise DI, Lifespan & Testing](02_enterprise_architecture/di_lifespan_testing.md)

## 3. Routing, Validation & Models
- [Path, Query, Header, Cookie & Body](03_routing_and_models/parameters_and_validation.md)
- [Response Serialization & OpenAPI 3.1](03_routing_and_models/responses_and_openapi.md)

## 4. Dependency Injection & Security
- [Dependant DAG, Caching & Scopes](04_dependencies_and_security/dependency_injection.md)
- [Authentication & OAuth2 Scopes](04_dependencies_and_security/security_and_auth.md)

## 5. Async, Middleware & Streaming
- [ASGI Middleware & Threadpool](05_async_and_realtime/concurrency_and_middleware.md)
- [Native SSE, JSONL & WebSockets](05_async_and_realtime/sse_websockets_streaming.md)

## 6. Observability, Errors & Testing
- [Native OpenTelemetry & Exceptions](06_observability_and_testing/telemetry_and_errors.md)
- [Testing Patterns & Production ASGI](06_observability_and_testing/testing_and_deployment.md)

## Diagnostic & Upstream Links
- [PNI501 Diagnostic Report](https://fastapi.drawlib.com/reports/pni501/)
- [Official FastAPI Docs](https://fastapi.tiangolo.com/)
- [Demo Source (GitHub)](https://github.com/yuichi110/drawlib-fastapi)
