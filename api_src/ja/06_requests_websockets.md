# fastapi.requests & websockets

FastAPI は Starlette の ASGI 接続プリミティブを `fastapi.requests`（`Request`、`HTTPConnection`）および `fastapi.websockets`（`WebSocket`、`WebSocketDisconnect`、`WebSocketState`）として公開します。HTTP の `Request` ハンドラーと全二重通信の `WebSocket` エンドポイントはどちらも共通基底クラス `HTTPConnection` を継承し、ヘッダー、クエリ・パスパラメータ、Cookie、クライアントアドレス、アプリケーション状態へ統一的にアクセスできます。

```drawlib align=center code=hide file=fastapi_http_ws_connections.png caption="Request と WebSocket のライフサイクルを統合する HTTPConnection クラス階層"
from drawlib.canvas import save, setup
from drawlib.diagrams.class_diagram import ClassDiagram, ClassNode
from drawlib.fonts import FontRoboto, FontSourceCode
from drawlib.styles import Colors, Styles

setup(width=164, height=84)

_ = Colors
cd = ClassDiagram(
    node_style=Styles.Neutral.patch(text_font=FontSourceCode.ROBOTO_MONO, text_size=10.0),
    header_style=Styles.PrimaryNeutral.patch(text_font=FontRoboto.ROBOTO_BOLD, text_size=10.8),
    edge_style=Styles.DarkBold,
    edge_text_style=Styles.Dark.patch(text_size=10.0),
)

conn_cls = cd.add(
    ClassNode(
        "HTTPConnection (Mapping)",
        width=60.0,
        row_height=3.6,
        header_style=Styles.PrimaryFlat.patch(
            text_color=Colors.White,
            text_font=FontRoboto.ROBOTO_BOLD,
            text_size=10.8,
        ),
    )
    .add_attribute("scope", "Scope")
    .add_attribute("url / base_url", "URL")
    .add_attribute("headers / query_params", "Headers | QueryParams")
    .add_attribute("path_params / cookies", "dict")
    .add_method("url_for", "name: str, **params", "URL"),
    xy=(52.0, 62.0),
)

state_cls = cd.add(
    ClassNode(
        "WebSocketState (Enum)",
        width=42.0,
        row_height=3.6,
        header_style=Styles.SecondaryNeutral.patch(
            text_font=FontRoboto.ROBOTO_BOLD,
            text_size=10.8,
        ),
    )
    .add_attribute("CONNECTING", "int", default_value="0")
    .add_attribute("CONNECTED", "int", default_value="1")
    .add_attribute("DISCONNECTED", "int", default_value="2")
    .add_attribute("RESPONSE", "int", default_value="3"),
    xy=(136.0, 62.0),
)

req_cls = cd.add(
    ClassNode("Request", width=45.0, row_height=3.6)
    .add_attribute("method", "str")
    .add_method("body / json", "", "Awaitable")
    .add_method("form", "", "FormData")
    .add_method("stream", "", "AsyncGenerator")
    .add_method("is_disconnected", "", "bool"),
    xy=(28.5, 20.0),
)

ws_cls = cd.add(
    ClassNode("WebSocket", width=46.0, row_height=3.6)
    .add_attribute("client_state", "WebSocketState")
    .add_method("accept / close", "", "None")
    .add_method("receive_text/bytes/json", "", "Any")
    .add_method("iter_text/bytes/json", "", "AsyncIter")
    .add_method("send_text/bytes/json", "data", "None"),
    xy=(81.0, 20.0),
)

disc_cls = cd.add(
    ClassNode(
        "WebSocketDisconnect",
        width=40.0,
        row_height=3.6,
        header_style=Styles.SecondaryNeutral.patch(
            text_font=FontRoboto.ROBOTO_BOLD,
            text_size=10.8,
        ),
    )
    .add_attribute("code", "int", default_value="1000")
    .add_attribute("reason", "str", default_value='""'),
    xy=(138.0, 20.0),
)

cd.connect(req_cls, conn_cls, "inheritance", start_side="top", end_side="bottom")
cd.connect(ws_cls, conn_cls, "inheritance", start_side="top", end_side="bottom")
cd.connect(ws_cls, state_cls, "association", directed=True, start_side="top", end_side="bottom")
cd.connect(ws_cls, disc_cls, "dependency", label="raises", start_side="right", end_side="left")

cd.draw(xy=(0.0, 0.0))
save()
```

---

## `class` Request

受信した HTTP リクエストを表すクラス（`from fastapi import Request` または `from fastapi.requests import Request`）です。パスオペレーションや依存関数に `request: Request` を注入することで、他の引数の OpenAPI パラメータ検証を維持したまま、生のヘッダー、クライアント接続情報、任意の `request.state` 属性、およびボディストリームへ直接アクセスできます。

```python
class Request(HTTPConnection[StateT]):
    def __init__(
        self,
        scope: Scope,
        receive: Receive = empty_receive,
        send: Send = empty_send,
    ) -> None: ...
```

### 属性

| 属性 | 型 | 説明 |
| :--- | :--- | :--- |
| `method` | `str` | ASGI スコープから取得される大文字の HTTP メソッド（例: `"GET"`、`"POST"`）。 |
| `url` | `starlette.datastructures.URL` | `.scheme`、`.netloc`、`.path`、`.query`、`.port` を備える解析済みリクエスト URL。 |
| `base_url` | `starlette.datastructures.URL` | ASGI `root_path` を考慮したアプリケーションのルート URL。 |
| `headers` | `starlette.datastructures.Headers` | 大文字・小文字を区別しない不変マルチ辞書形式の HTTP リクエストヘッダー。 |
| `query_params` | `starlette.datastructures.QueryParams` | 解析済み URL クエリ文字列パラメータの不変マルチ辞書（`.get()`、`.getlist()`）。 |
| `path_params` | `dict[str, Any]` | URL パスから抽出されたルートパスパラメータの辞書。 |
| `cookies` | `dict[str, str]` | `Cookie` ヘッダーから解析された Cookie の辞書。 |
| `client` | `Address \| None` | 接続元ピアの `Address(host: str, port: int)` 名前付きタプル（不明な場合は `None`）。 |
| `app` | `FastAPI \| Any` | 実行中の ASGI `FastAPI` アプリケーションインスタンス（`scope["app"]`）。 |
| `state` | `starlette.datastructures.State` | ミドルウェアや依存関数間でリクエスト固有データを共有する名前空間（例: `request.state.request_id`）。 |
| `scope` | `Scope`（`MutableMapping[str, Any]`） | 生の ASGI HTTP 接続スコープ辞書。 |

### 非同期・同期メソッド

| メソッド | シグネチャ | 説明 |
| :--- | :--- | :--- |
| `body()` | `async def body(self) -> bytes` | HTTP リクエストボディ全体を `bytes` として読み取り、インスタンス内にキャッシュします。 |
| `json()` | `async def json(self) -> Any` | `await self.body()` を読み取り、`json.loads()` でデシリアライズした結果を返します。 |
| `form()` | `def form(self, *, max_files: int \| float = 1000, max_fields: int \| float = 1000, max_part_size: int = 1048576) -> AwaitableOrContextManager[FormData]` | `multipart/form-data` または `application/x-www-form-urlencoded` を解析します（`await request.form()` または `async with request.form() as form:` として使用）。 |
| `stream()` | `def stream(self) -> AsyncGenerator[bytes, None]` | ペイロード全体をメモリに溜め込まず、`async for chunk in request.stream():` でチャンク単位に順次取得します。 |
| `is_disconnected()` | `async def is_disconnected(self) -> bool` | ASGI `receive` チャネルを非ブロッキングで確認し、クライアント切断済みかどうかを返します。 |
| `close()` | `async def close(self) -> None` | `request.form()` 解析中に開かれた一時 `UploadFile` ハンドルをクローズします。 |
| `url_for()` | `def url_for(self, name: str, /, **path_params: Any) -> URL` | 名前付きルート `name` と `path_params` から絶対 `URL` を逆引き生成します。 |

### 使用例

```python
from fastapi import FastAPI, Request
from fastapi.testclient import TestClient

app = FastAPI()


@app.post("/ingest/{source}")
async def ingest_payload(source: str, request: Request) -> dict[str, object]:
    request.state.trace = request.headers.get("x-trace-id", "none")
    chunks = [chunk async for chunk in request.stream() if chunk]
    return {
        "method": request.method,
        "path": request.url.path,
        "path_param": request.path_params["source"],
        "query_tag": request.query_params.get("tag"),
        "trace": request.state.trace,
        "byte_len": sum(len(c) for c in chunks),
        "disconnected": await request.is_disconnected(),
    }


client = TestClient(app)
res = client.post(
    "/ingest/sensor-a?tag=v2",
    content=b"raw-telemetry-bytes",
    headers={"X-Trace-Id": "tr-100"},
)
assert res.status_code == 200
assert res.json() == {
    "method": "POST",
    "path": "/ingest/sensor-a",
    "path_param": "sensor-a",
    "query_tag": "v2",
    "trace": "tr-100",
    "byte_len": 19,
    "disconnected": False,
}
```

---

## `class` HTTPConnection

`Request`（`scope["type"] == "http"`）と `WebSocket`（`scope["type"] == "websocket"`）の共通基底クラス（`from fastapi.requests import HTTPConnection`）であり、基礎となる ASGI `scope` に対する `Mapping[str, Any]` を実装します。FastAPI 依存関数の引数を `conn: HTTPConnection` として宣言すると、同一の依存関数を通常の HTTP ルートと WebSocket ルートの双方で共有できます。

```python
class HTTPConnection(Mapping[str, Any], Generic[StateT]):
    scope: Scope

    def __init__(
        self,
        scope: Scope,
        receive: Receive | None = None,
    ) -> None: ...
```

### 共通インターフェース

| メンバー | 種別 | 戻り値の型 | 説明 |
| :--- | :--- | :--- | :--- |
| `scope` | 属性 | `Scope` | 基礎となる ASGI スコープ辞書（`scope["type"]` は `"http"` または `"websocket"`）。 |
| `app`, `url`, `base_url` | プロパティ | `Any`, `URL`, `URL` | 実行中の ASGI アプリ、完全な接続 URL、およびルートベース URL。 |
| `headers`, `query_params`, `cookies` | プロパティ | `Headers`, `QueryParams`, `dict[str, str]` | HTTP リクエストと WebSocket ハンドシェイクの双方で参照可能なヘッダー・クエリ・Cookie。 |
| `path_params`, `client`, `state` | プロパティ | `dict[str, Any]`, `Address \| None`, `State` | パスパラメータ、クライアントの `(host, port)`、および可変の接続状態オブジェクト。 |
| `session`, `auth`, `user` | プロパティ | `dict[str, Any]`, `Any`, `Any` | Starlette の `SessionMiddleware` や `AuthenticationMiddleware` 導入時に公開される属性。 |
| `url_for(name, **path_params)` | メソッド | `URL` | 名前付きルートから絶対 `URL` を生成します。 |

### 使用例

```python
from typing import Annotated

from fastapi import Depends, FastAPI, WebSocket
from fastapi.requests import HTTPConnection
from fastapi.testclient import TestClient

app = FastAPI()


def extract_tenant(conn: HTTPConnection) -> str:
    return conn.headers.get("x-tenant-id", "public")


@app.get("/whoami")
def http_whoami(tenant: Annotated[str, Depends(extract_tenant)]) -> dict[str, str]:
    return {"protocol": "http", "tenant": tenant}


@app.websocket("/ws/whoami")
async def ws_whoami(
    websocket: WebSocket,
    tenant: Annotated[str, Depends(extract_tenant)],
) -> None:
    await websocket.accept()
    await websocket.send_json({"protocol": "websocket", "tenant": tenant})
    await websocket.close()


client = TestClient(app)
assert client.get("/whoami", headers={"X-Tenant-Id": "acme"}).json() == {
    "protocol": "http",
    "tenant": "acme",
}
with client.websocket_connect("/ws/whoami", headers={"X-Tenant-Id": "acme"}) as ws:
    assert ws.receive_json() == {"protocol": "websocket", "tenant": "acme"}
```

---

## `class` WebSocket

双方向の ASGI WebSocket 接続を表すクラス（`from fastapi import WebSocket` または `from fastapi.websockets import WebSocket`）です。`HTTPConnection` のすべてのハンドシェイク属性を継承し、接続の承認、テキスト・バイナリ・JSON フレームの送受信および非同期イテレーション、ソケット切断のためのコルーチンメソッドを提供します。

```python
class WebSocket(HTTPConnection[StateT]):
    client_state: WebSocketState
    application_state: WebSocketState

    def __init__(self, scope: Scope, receive: Receive, send: Send) -> None: ...
```

### ライフサイクル属性・メソッド

| メンバー | シグネチャ | 説明 |
| :--- | :--- | :--- |
| `client_state` / `application_state` | `WebSocketState` | クライアント側およびサーバー側の ASGI WebSocket 状態遷移を保持します。 |
| `accept()` | `async def accept(self, subprotocol: str \| None = None, headers: Iterable[tuple[bytes, bytes]] \| None = None) -> None` | WebSocket ハンドシェイクを承認し、`application_state` を `CONNECTED` に遷移させます。 |
| `receive_text()` | `async def receive_text(self) -> str` | 次の UTF-8 テキストフレームを待機し、切断時は `WebSocketDisconnect` を送出します。 |
| `receive_bytes()` | `async def receive_bytes(self) -> bytes` | 次のバイナリフレームを待機し、切断時は `WebSocketDisconnect` を送出します。 |
| `receive_json()` | `async def receive_json(self, mode: str = "text") -> Any` | `"text"` または `"binary"` フレームを受信して JSON としてデコードします。 |
| `iter_text()` | `def iter_text(self) -> AsyncIterator[str]` | `WebSocketDisconnect` が発生するまでテキストメッセージを順次生成する非同期イテレータ。 |
| `iter_bytes()` | `def iter_bytes(self) -> AsyncIterator[bytes]` | `WebSocketDisconnect` が発生するまでバイナリフレームを順次生成する非同期イテレータ。 |
| `iter_json()` | `def iter_json(self) -> AsyncIterator[Any]` | `WebSocketDisconnect` が発生するまでデコード済み JSON を順次生成する非同期イテレータ。 |
| `send_text()` | `async def send_text(self, data: str) -> None` | UTF-8 テキスト WebSocket フレームを送信します。 |
| `send_bytes()` | `async def send_bytes(self, data: bytes) -> None` | バイナリ WebSocket フレームを送信します。 |
| `send_json()` | `async def send_json(self, data: Any, mode: str = "text") -> None` | `data` を UTF-8 JSON にシリアライズし、`"text"` または `"binary"` フレームで送信します。 |
| `close()` | `async def close(self, code: int = 1000, reason: str \| None = None) -> None` | RFC 6455 のステータス `code` と任意の `reason` を持つ `websocket.close` フレームを送信します。 |

### 使用例

```python
from fastapi import FastAPI, WebSocket
from fastapi.testclient import TestClient

app = FastAPI()


@app.websocket("/ws/echo/{channel}")
async def websocket_echo(websocket: WebSocket, channel: str) -> None:
    await websocket.accept(subprotocol="json.v1")
    first_payload = await websocket.receive_json()
    await websocket.send_json({"channel": channel, "echo": first_payload})
    async for line in websocket.iter_text():
        await websocket.send_text(f"{channel}:{line}")


client = TestClient(app)
with client.websocket_connect("/ws/echo/alerts", subprotocols=["json.v1"]) as ws:
    ws.send_json({"seq": 1})
    assert ws.receive_json() == {"channel": "alerts", "echo": {"seq": 1}}
    ws.send_text("ping")
    assert ws.receive_text() == "alerts:ping"
```

---

## `class` WebSocketDisconnect

クライアントが WebSocket 接続を閉じた際に `receive_text()`、`receive_bytes()`、`receive_json()` から送出される例外クラスです（`iter_text()`、`iter_bytes()`、`iter_json()` では内部で捕捉されループを正常終了します）。`from fastapi import WebSocketDisconnect` または `from fastapi.websockets import WebSocketDisconnect` からインポートします。

```python
class WebSocketDisconnect(Exception):
    code: int
    reason: str

    def __init__(
        self,
        code: int = 1000,
        reason: str | None = None,
    ) -> None: ...
```

### 属性

| 属性 | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `code` | `int` | `1000` | RFC 6455 の WebSocket クローズステータスコード（例: `1000` 正常終了、`1001` 離脱、`1008` ポリシー違反）。 |
| `reason` | `str` | `""` | 切断理由を表す文字列（`None` が渡された場合は空文字列 `""` に正規化）。 |

### 使用例

```python
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.testclient import TestClient

app = FastAPI()
disconnect_log: list[tuple[int, str]] = []


@app.websocket("/ws/room")
async def room_socket(websocket: WebSocket) -> None:
    await websocket.accept()
    try:
        while True:
            msg = await websocket.receive_text()
            await websocket.send_text(msg.upper())
    except WebSocketDisconnect as exc:
        disconnect_log.append((exc.code, exc.reason))


client = TestClient(app)
with client.websocket_connect("/ws/room") as ws:
    ws.send_text("hello")
    assert ws.receive_text() == "HELLO"
    ws.close(code=1001, reason="client navigating away")

assert disconnect_log[0][0] == 1001
```

---

## `enum` WebSocketState

`websocket.client_state` および `websocket.application_state` の ASGI ライフサイクル状態を表す `enum.Enum` です。`fastapi.websockets.WebSocketState` からインポートします。

```python
class WebSocketState(enum.Enum):
    CONNECTING = 0
    CONNECTED = 1
    DISCONNECTED = 2
    RESPONSE = 3
```

### 列挙メンバー

| メンバー | 値 | 説明 |
| :--- | :--- | :--- |
| `CONNECTING` | `0` | `websocket.connect` / `websocket.accept` 完了前の初期ハンドシェイク状態。 |
| `CONNECTED` | `1` | ハンドシェイク承認後のアクティブな全二重フレーム送受信状態。 |
| `DISCONNECTED` | `2` | `websocket.disconnect` または `websocket.close` 完了後の切断状態。 |
| `RESPONSE` | `3` | ハンドシェイク拒否レスポンス送信中（`send_denial_response`）の遷移状態。 |

### 使用例

```python
from fastapi import FastAPI, WebSocket
from fastapi.testclient import TestClient
from fastapi.websockets import WebSocketState

app = FastAPI()
observed_states: list[WebSocketState] = []


@app.websocket("/ws/state")
async def inspect_ws_state(websocket: WebSocket) -> None:
    observed_states.append(websocket.application_state)
    await websocket.accept()
    observed_states.append(websocket.application_state)
    await websocket.send_text(websocket.client_state.name)
    await websocket.close()
    observed_states.append(websocket.application_state)


client = TestClient(app)
with client.websocket_connect("/ws/state") as ws:
    assert ws.receive_text() == "CONNECTED"

assert observed_states == [
    WebSocketState.CONNECTING,
    WebSocketState.CONNECTED,
    WebSocketState.DISCONNECTED,
]
```
