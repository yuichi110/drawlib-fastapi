# FastAPI ビジュアル解説

- [ガイド概要と全体マップ](index.md)

## 1. イントロ & クイックスタート
- [FastAPI の設計思想と内部構造](01_getting_started/overview.md)
- [クイックスタートと自動生成 Docs](01_getting_started/quickstart.md)

## 2. 10万行規模の設計ベストプラクティス
- [境界づけられたコンテキストと階層化](02_enterprise_architecture/modular_design.md)
- [大規模 DI・Lifespan 管理・テスト戦略](02_enterprise_architecture/di_lifespan_testing.md)

## 3. ルーティング・入力検証・スキーマ
- [Path・Query・Header・Cookie・Body](03_routing_and_models/parameters_and_validation.md)
- [レスポンス直列化と OpenAPI 3.1](03_routing_and_models/responses_and_openapi.md)
- [パラメータモデル合成・特殊型・例示](03_routing_and_models/advanced_types_and_models.md)
- [カスタム Request と APIRoute 拡張](03_routing_and_models/custom_request_and_route.md)

## 4. 依存性注入（DI）とセキュリティ
- [Dependant DAG・キャッシュ・yield スコープ](04_dependencies_and_security/dependency_injection.md)
- [認証・OAuth2 スコープ認可・抽出器](04_dependencies_and_security/security_and_auth.md)
- [JWT (PyJWT + Argon2) と WS 認可](04_dependencies_and_security/jwt_and_websocket_security.md)

## 5. 非同期並行・ミドルウェア・ストリーミング
- [ASGI ミドルウェアとスレッドプール制御](05_async_and_realtime/concurrency_and_middleware.md)
- [ネイティブ SSE・JSONL・WebSocket](05_async_and_realtime/sse_websockets_streaming.md)

## 6. 可観測性・例外設計・実践テスト
- [ネイティブ OpenTelemetry と例外処理](06_observability_and_testing/telemetry_and_errors.md)
- [実践テスト手法と本番 ASGI 運用](06_observability_and_testing/testing_and_deployment.md)

## 7. フロントエンド・マウント・OpenAPI 拡張
- [SPA frontend()・静的配信・マウント統合](07_frontend_and_openapi_ext/frontend_templates_mounts.md)
- [Webhooks・Callbacks・SDK 生成・Docs UI](07_frontend_and_openapi_ext/webhooks_callbacks_sdks.md)

## 8. 設定管理・SQL DB・CLI・エコシステム
- [pydantic-settings 設定管理と SQL DB](08_ecosystem_and_operations/settings_and_databases.md)
- [FastAPI CLI・プロキシ・GraphQL・AI 連携](08_ecosystem_and_operations/cli_proxy_graphql_ai.md)

## 診断レポート & 公式リンク
- [PNI501 診断レポート](https://fastapi.drawlib.com/reports/pni501/)
- [FastAPI 公式ドキュメント](https://fastapi.tiangolo.com/)
- [デモのリポジトリ (GitHub)](https://github.com/yuichi110/drawlib-fastapi)
