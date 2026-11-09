# fastapi.middleware

`fastapi.middleware.*` からインポートし、`app.add_middleware()` で登録する組み込み ASGI ミドルウェアクラス群（CORS 制御、Host ヘッダー検証、GZip 圧縮、HTTPS リダイレクト、およびリクエスト単位のファイルクリーンアップ）のリファレンスです。ユーザー登録ミドルウェアは登録順の逆順でラップされ、`ExceptionMiddleware` および `AsyncExitStackMiddleware` の外側で実行されます。

```drawlib align=center code=hide file=fastapi_middleware_catalog.png caption="app.add_middleware() による FastAPI 組み込み ASGI ミドルウェアパイプライン"
from drawlib.canvas import save, setup
from drawlib.diagrams.architecture import ArchitectureDiagram, Node, NodeGroup, PhosphorIcon
from drawlib.styles import Colors, Styles

setup(width=160, height=64)

_ = Colors
d = ArchitectureDiagram(
    node_style=Styles.Dark,
    node_text_style=Styles.DarkBold.patch(text_size=10.0),
    edge_style=Styles.Dark.patch(line_width=1.5),
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
)

client = d.add(
    Node(
        "ASGI Client\n(HTTP / WS)",
        icon=PhosphorIcon.GLOBE,
        width=26,
        height=15,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(18, 40),
)

stack = d.add(
    NodeGroup(
        "FastAPI Middleware Stack (fastapi.middleware)",
        width=114,
        height=54,
        style=Styles.SecondaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left", valign="top"),
    ),
    xy=(41, 5),
)

https_mw = stack.add(
    Node(
        "HTTPSRedirect\nMiddleware",
        icon=PhosphorIcon.LOCK,
        width=28,
        height=15,
        card_style=Styles.Neutral,
    ),
    xy=(20, 35),
)
host_mw = stack.add(
    Node(
        "TrustedHost\nMiddleware",
        icon=PhosphorIcon.SHIELD_CHECK,
        width=28,
        height=15,
        card_style=Styles.Neutral,
    ),
    xy=(57, 35),
)
cors_mw = stack.add(
    Node(
        "CORSMiddleware",
        icon=PhosphorIcon.ARROWS_LEFT_RIGHT,
        width=28,
        height=15,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
        card_style=Styles.PrimaryFlat,
    ),
    xy=(94, 35),
)
gzip_mw = stack.add(
    Node(
        "GZipMiddleware",
        icon=PhosphorIcon.FILE_ZIP,
        width=28,
        height=15,
        card_style=Styles.Neutral,
    ),
    xy=(94, 12),
)
exit_mw = stack.add(
    Node(
        "AsyncExitStack\nMiddleware",
        icon=PhosphorIcon.STACK,
        width=28,
        height=15,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(57, 12),
)
router = stack.add(
    Node(
        "FastAPI Router\n& Endpoints",
        icon=PhosphorIcon.CODE,
        width=28,
        height=15,
        card_style=Styles.Neutral,
    ),
    xy=(20, 12),
)

client.connect(https_mw, padding=1.2)
https_mw.connect(host_mw, padding=1.0)
host_mw.connect(cors_mw, padding=1.0)
cors_mw.connect(gzip_mw, padding=1.0)
gzip_mw.connect(exit_mw, padding=1.0)
exit_mw.connect(router, padding=1.0)

d.draw(xy=(0, 0))
save()
```

---

## `class` CORSMiddleware

`fastapi.middleware.cors` からインポート可能な Cross-Origin Resource Sharing（CORS）ミドルウェアです（実体は `starlette.middleware.cors.CORSMiddleware`）。ブラウザの `Origin` ヘッダーを検証し、`OPTIONS` プリフライト要求への応答および `Access-Control-*` ヘッダーの付与を行います。`allow_credentials=True` を有効化する際は必ず信頼済み HTTPS オリジンの明示的な許可リストを指定し、`allow_origins=["*"]` と `allow_credentials=True` を絶対に併用しないでください。

```python
class CORSMiddleware:
    def __init__(
        self,
        app: ASGIApp,
        allow_origins: Collection[str] = (),
        allow_methods: Collection[str] = ("GET",),
        allow_headers: Collection[str] = (),
        allow_credentials: bool = False,
        allow_origin_regex: str | None = None,
        allow_private_network: bool = False,
        expose_headers: Collection[str] = (),
        max_age: int = 600,
    ) -> None: ...
```

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `app` | `ASGIApp` | *(必須)* | ミドルウェアチェーン内の次の ASGI アプリケーション（`app.add_middleware()` 使用時は自動引き渡し）。 |
| `allow_origins` | `Collection[str]` | `()` | クロスオリジンアクセスを許可する明示的オリジンのリスト（例: `["https://app.example.com"]`）。`allow_credentials=True` 時は具体的なオリジン指定が必須です。 |
| `allow_methods` | `Collection[str]` | `("GET",)` | クロスオリジン要求で許可する HTTP メソッド（`["GET", "POST"]` など必要最小限の明示指定を推奨）。 |
| `allow_headers` | `Collection[str]` | `()` | プリフライト要求で許可するリクエストヘッダー（例: `["Authorization", "Content-Type"]`）。単純要求の標準ヘッダーは常時許可されます。 |
| `allow_credentials` | `bool` | `False` | クロスオリジン要求での Cookie や `Authorization` 資格情報の送信を許可します（ワイルドカードなしの明示 `allow_origins` が必須）。 |
| `allow_origin_regex` | `str \| None` | `None` | `Origin` ヘッダーに対して照合する任意の正規表現パターン（例: `r"^https://.*\.example\.com$"`）。 |
| `allow_private_network` | `bool` | `False` | プリフライト要求に `Access-Control-Request-Private-Network: true` が含まれる場合、`Access-Control-Allow-Private-Network: true` を返します。 |
| `expose_headers` | `Collection[str]` | `()` | ブラウザ側の JavaScript へ公開する追加レスポンスヘッダー名のコレクション。 |
| `max_age` | `int` | `600` | ブラウザがプリフライト応答をキャッシュする最大秒数（`Access-Control-Max-Age`）。 |

### 使用例

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.testclient import TestClient

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://app.example.com", "https://admin.example.com"],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type"],
    expose_headers=["X-Request-Id"],
    max_age=600,
)


@app.get("/profile")
def get_profile() -> dict[str, str]:
    return {"status": "ok"}


client = TestClient(app)
allowed = client.get("/profile", headers={"Origin": "https://app.example.com"})
assert allowed.headers["access-control-allow-origin"] == "https://app.example.com"
assert allowed.headers["access-control-allow-credentials"] == "true"

blocked = client.get("/profile", headers={"Origin": "https://untrusted.example.net"})
assert "access-control-allow-origin" not in blocked.headers
```

---

## `class` TrustedHostMiddleware

`fastapi.middleware.trustedhost` からインポート可能な `Host` ヘッダー検証ミドルウェアです（実体は `starlette.middleware.trustedhost.TrustedHostMiddleware`）。`Host` ヘッダー（または ASGI スコープ）が `allowed_hosts` に一致しないリクエストを `400 Invalid host header` で拒否し、HTTP Host ヘッダーインジェクション攻撃を防御します。

```python
class TrustedHostMiddleware:
    def __init__(
        self,
        app: ASGIApp,
        allowed_hosts: Sequence[str] | None = None,
        www_redirect: bool = True,
    ) -> None: ...
```

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `app` | `ASGIApp` | *(必須)* | ラップ対象の次の ASGI アプリケーション。 |
| `allowed_hosts` | `Sequence[str] \| None` | `None` | 許可するホスト名またはサブドメインワイルドカードのシーケンス（例: `["api.example.com", "*.example.com"]`、`None` 時は `["*"]`）。 |
| `www_redirect` | `bool` | `True` | `True` の場合、`allowed_hosts` に `"www.example.com"` が登録されていれば `example.com` への要求を `www.` 付き URL へ `301` リダイレクトします。 |

### 使用例

```python
from fastapi import FastAPI
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.testclient import TestClient

app = FastAPI()
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["api.example.com", "*.example.com"],
)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "healthy"}


valid_client = TestClient(app, base_url="https://api.example.com")
assert valid_client.get("/health").status_code == 200

evil_client = TestClient(app, base_url="https://spoofed.attacker.org")
assert evil_client.get("/health").status_code == 400
```

---

## `class` GZipMiddleware

`fastapi.middleware.gzip` からインポート可能なレスポンス圧縮ミドルウェアです（実体は `starlette.middleware.gzip.GZipMiddleware`）。クライアントが `Accept-Encoding: gzip` を送信し、ボディサイズが `minimum_size` 以上かつ `Content-Type` が `exclude_content_types` に該当しない HTTP レスポンスを圧縮します（既定で `"text/event-stream"` や圧縮済みメディア形式は除外されます）。

```python
class GZipMiddleware:
    def __init__(
        self,
        app: ASGIApp,
        minimum_size: int = 500,
        compresslevel: int = 9,
        thread_minimum_size: int = 131072,
        *,
        exclude_content_types: tuple[str, ...] = (
            "application/gzip",
            "application/x-gzip",
            "application/zip",
            "audio/*",
            "font/woff",
            "font/woff2",
            "image/avif",
            "image/gif",
            "image/jpeg",
            "image/png",
            "image/webp",
            "text/event-stream",
            "video/*",
        ),
    ) -> None: ...
```

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `app` | `ASGIApp` | *(必須)* | ラップ対象の次の ASGI アプリケーション。 |
| `minimum_size` | `int` | `500` | GZip 圧縮を適用する最小レスポンスボディサイズ（バイト）。 |
| `compresslevel` | `int` | `9` | Deflate 圧縮レベル（最速 `1` 〜 最高圧縮率 `9`）。 |
| `thread_minimum_size` | `int` | `131072` | イベントループのブロッキングを避けるためワーカースレッドプールで圧縮を実行する閾値バイト数（既定 `128 KiB`）。 |
| `exclude_content_types` | `tuple[str, ...]` | `('application/gzip', ..., 'text/event-stream', 'video/*')` | GZip 圧縮対象から除外する MIME タイプまたは `type/*` ワイルドカードのキーワード専用タプル（SSE ストリームや圧縮済みアーカイブ・メディアを保護）。 |

### 使用例

```python
from fastapi import FastAPI
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.testclient import TestClient

app = FastAPI()
app.add_middleware(GZipMiddleware, minimum_size=100, compresslevel=6)


@app.get("/report")
def large_report() -> dict[str, str]:
    return {"payload": "fastapi-gzip-" * 40}


client = TestClient(app)
res = client.get("/report", headers={"Accept-Encoding": "gzip"})
assert res.status_code == 200
assert res.headers["content-encoding"] == "gzip"
assert res.json()["payload"].startswith("fastapi-gzip-")
```

---

## `class` HTTPSRedirectMiddleware

`fastapi.middleware.httpsredirect` からインポート可能なトランスポート保護ミドルウェアです（実体は `starlette.middleware.httpsredirect.HTTPSRedirectMiddleware`）。平文の `http` および `ws` リクエストを捕捉し、メソッド・パス・クエリ文字列を維持したまま対応する `https` または `wss` URL への `307 Temporary Redirect` を返します。

```python
class HTTPSRedirectMiddleware:
    def __init__(self, app: ASGIApp) -> None: ...
```

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `app` | `ASGIApp` | *(必須)* | ラップ対象の次の ASGI アプリケーション。 |

### 使用例

```python
from fastapi import FastAPI
from fastapi.middleware.httpsredirect import HTTPSRedirectMiddleware
from fastapi.testclient import TestClient

app = FastAPI()
app.add_middleware(HTTPSRedirectMiddleware)


@app.get("/secure-data")
def secure_data() -> dict[str, bool]:
    return {"encrypted": True}


http_client = TestClient(app, base_url="http://api.example.com")
redirect = http_client.get("/secure-data?v=1", follow_redirects=False)
assert redirect.status_code == 307
assert redirect.headers["location"] == "https://api.example.com/secure-data?v=1"

https_client = TestClient(app, base_url="https://api.example.com")
assert https_client.get("/secure-data").status_code == 200
```

---

## `class` AsyncExitStackMiddleware

`fastapi.middleware.asyncexitstack` で定義され、`FastAPI.build_middleware_stack()` によって `ExceptionMiddleware` や全ユーザーミドルウェアの内側（最内層）に自動組み込みされる FastAPI 固有の ASGI ミドルウェアです。ASGI `scope[context_name]`（既定 `"fastapi_middleware_astack"`）に `contextlib.AsyncExitStack` を保持し、リクエスト完了後に `FormData` や `UploadFile` の一時ファイルハンドルを確実にクローズします。

```python
class AsyncExitStackMiddleware:
    def __init__(
        self,
        app: ASGIApp,
        context_name: str = "fastapi_middleware_astack",
    ) -> None: ...
```

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `app` | `ASGIApp` | *(必須)* | `AsyncExitStack` コンテキスト内で呼び出される内側の ASGI アプリケーションまたはルーター。 |
| `context_name` | `str` | `"fastapi_middleware_astack"` | アクティブな `AsyncExitStack` インスタンスを格納する ASGI `scope` 辞書のキー名。 |

### 使用例

```python
from contextlib import AsyncExitStack

from fastapi import FastAPI, Request
from fastapi.middleware.asyncexitstack import AsyncExitStackMiddleware
from fastapi.testclient import TestClient

app = FastAPI()
cleanup_log: list[str] = []


@app.get("/check-stack")
def check_stack(request: Request) -> dict[str, bool]:
    stack = request.scope.get("fastapi_middleware_astack")
    assert isinstance(stack, AsyncExitStack)
    stack.callback(cleanup_log.append, "closed")
    return {"active": True}


assert AsyncExitStackMiddleware is not None
client = TestClient(app)
assert client.get("/check-stack").json() == {"active": True}
assert cleanup_log == ["closed"]
```

---

## `deprecated` WSGIMiddleware

`fastapi.middleware.wsgi` 経由で `starlette.middleware.wsgi.WSGIMiddleware` を再エクスポートするレガシー WSGI-ASGI アダプタです。**Starlette 上流で非推奨（Deprecated）**となっており、`fastapi.middleware.wsgi` をインポートすると将来の削除を予告する `StarletteDeprecationWarning` が送出されます。Flask や Django などの同期 WSGI アプリを `app.mount()` でマウントする場合は、推奨代替ライブラリである `a2wsgi.WSGIMiddleware`（`from a2wsgi import WSGIMiddleware`）へ移行してください。

```python
class WSGIMiddleware:
    def __init__(self, app: Callable[..., Any]) -> None: ...
```

### パラメータと移行先

| パラメータ / 項目 | 型 / 移行先 | 説明 |
| :--- | :--- | :--- |
| `app` | `Callable[..., Any]` | PEP 3333 準拠の同期 WSGI 呼び出し可能オブジェクト `(environ, start_response) -> Iterable[bytes]`。 |
| **推奨代替クラス** | `a2wsgi.WSGIMiddleware` | `a2wsgi` パッケージを導入し、`app.mount("/legacy", a2wsgi.WSGIMiddleware(wsgi_app))` を使用することで `StarletteDeprecationWarning` を回避できます。 |

### 使用例

```python
from collections.abc import Iterable
from typing import Any, Callable
import warnings

from fastapi import FastAPI
from fastapi.testclient import TestClient

with warnings.catch_warnings():
    warnings.simplefilter("ignore", DeprecationWarning)
    from fastapi.middleware.wsgi import WSGIMiddleware


def legacy_wsgi_app(
    environ: dict[str, Any], start_response: Callable[..., Any]
) -> Iterable[bytes]:
    start_response("200 OK", [("Content-Type", "text/plain; charset=utf-8")])
    return [b"legacy-ok"]


app = FastAPI()
app.mount("/legacy", WSGIMiddleware(legacy_wsgi_app))

client = TestClient(app)
res = client.get("/legacy/")
assert res.status_code == 200
assert res.text == "legacy-ok"
```
