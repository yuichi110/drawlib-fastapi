# FastAPI Architecture

- [Architecture Overview](index.md)

## 1. Package Topology & Layers
- [5-Tier Module Hierarchy & Shims](01_package_and_layers/module_hierarchy.md)

## 2. Routing Compiler & Closures
- [APIRouter, APIRoute & Handler Closure](02_routing_compiler/apiroute_and_closures.md)
- [Generator Streaming & SPA Internals](02_routing_compiler/streaming_and_spa_internals.md)

## 3. DI & Security Engine
- [Dependant DAG & solve_dependencies](03_di_and_security_engine/dependant_and_solver.md)
- [SecurityBase & HTTPConnection](03_di_and_security_engine/security_internals.md)

## 4. Pydantic v2 Bridge
- [_compat/v2.py, ModelField & Serialization](04_pydantic_bridge/compat_and_serialization.md)

## 5. ASGI Stack & Telemetry
- [Middleware Onion & Threadpool](05_asgi_and_telemetry/middleware_and_concurrency.md)
- [NativeTelemetry & Runtime Spans](05_asgi_and_telemetry/native_telemetry_internals.md)

## 6. OpenAPI 3.1 Synthesis
- [get_openapi(), $defs & Docs UI](06_openapi_and_docs/openapi_synthesis_engine.md)

## Companion Guides & Links
- [All Portals (Showcase Hub)](https://fastapi.drawlib.com/)
- [FastAPI User Guide](https://fastapi.drawlib.com/user_guide/)
- [FastAPI API Reference](https://fastapi.drawlib.com/api/)
- [PNI501 Diagnostic Report](https://fastapi.drawlib.com/pni501/)
- [Official FastAPI Docs](https://fastapi.tiangolo.com/)
- [GitHub Repository](https://github.com/yuichi110/drawlib-fastapi)
