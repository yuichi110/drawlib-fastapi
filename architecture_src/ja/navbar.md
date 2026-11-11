# FastAPI 内部構造

- [アーキテクチャ全体像](index.md)

## 1. パッケージ階層と境界設計
- [5層モジュール構造と Starlette 再公開](01_package_and_layers/module_hierarchy.md)

## 2. ルーティングコンパイラとクロージャ
- [APIRouter・APIRoute とクロージャ合成](02_routing_compiler/apiroute_and_closures.md)
- [ジェネレータ配信と SPA ルータ内部実装](02_routing_compiler/streaming_and_spa_internals.md)

## 3. DI 解決エンジンと認証機構
- [Dependant グラフと solve_dependencies](03_di_and_security_engine/dependant_and_solver.md)
- [SecurityBase 階層と HTTPConnection](03_di_and_security_engine/security_internals.md)

## 4. Pydantic v2 ブリッジ層
- [_compat/v2.py・ModelField・直列化](04_pydantic_bridge/compat_and_serialization.md)

## 5. ASGI スタックとテレメトリ
- [ミドルウェア7層構造とスレッドプール](05_asgi_and_telemetry/middleware_and_concurrency.md)
- [NativeTelemetry と例外スパン記録](05_asgi_and_telemetry/native_telemetry_internals.md)

## 6. OpenAPI 3.1 合成エンジン
- [get_openapi()・$defs 集約・Docs UI](06_openapi_and_docs/openapi_synthesis_engine.md)

## 関連ガイド & 公式リンク
- [ポータル一覧（ショーケース）](https://fastapi.drawlib.com/)
- [FastAPI ユーザーガイド](https://fastapi.drawlib.com/user_guide/)
- [FastAPI API リファレンス](https://fastapi.drawlib.com/api/)
- [PNI501 診断レポート](https://fastapi.drawlib.com/pni501/)
- [FastAPI 公式ドキュメント](https://fastapi.tiangolo.com/)
- [GitHub リポジトリ](https://github.com/yuichi110/drawlib-fastapi)
