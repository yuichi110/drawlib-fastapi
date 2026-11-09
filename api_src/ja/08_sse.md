# fastapi.sse

`fastapi.sse` モジュールで提供される Server-Sent Events（SSE）ストリーミングレスポンス、イベント検証モデル、UTF-8 ワイヤフォーマット変換関数、および無通信時キープアライブ定数（`EventSourceResponse`、`ServerSentEvent`、`format_sse_event()`、`KEEPALIVE_COMMENT`）のリファレンスです。FastAPI は同期・非同期ジェネレータのパスオペレーションを任意の HTTP メソッド（`GET`、`POST` など）で `text/event-stream` として配信し、ジェネレータ反復とハートビート送出を独立したタスクで安全に制御します。

```drawlib align=center code=hide file=fastapi_sse_api_flow.png caption="FastAPI Server-Sent Events ストリーミングパイプラインとキープアライブ構成"
from drawlib.canvas import save, setup
from drawlib.diagrams.architecture import ArchitectureDiagram, Node, NodeGroup, PhosphorIcon
from drawlib.styles import Colors, Styles

setup(width=164, height=62)

_ = Colors
d = ArchitectureDiagram(
    node_style=Styles.Dark,
    node_text_style=Styles.DarkBold.patch(text_size=10.5),
    edge_style=Styles.Dark.patch(line_width=1.5),
    edge_text_style=Styles.Dark.patch(text_size=10.0),
    node_card_style=Styles.Neutral,
)

gen_node = d.add(
    Node(
        "Generator Route\n(yield items)",
        icon=PhosphorIcon.CODE,
        width=26,
        height=15,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(18, 40),
)

pipeline = d.add(
    NodeGroup(
        "FastAPI SSE Pipeline (fastapi.sse)",
        width=88,
        height=52,
        style=Styles.SecondaryNeutral,
        text_style=Styles.DarkBold.patch(text_size=11.0, halign="left", valign="top"),
    ),
    xy=(39, 5),
)

sse_model = pipeline.add(
    Node(
        "ServerSentEvent",
        icon=PhosphorIcon.PACKAGE,
        width=28,
        height=14,
        card_style=Styles.Neutral,
    ),
    xy=(20, 35),
)
formatter = pipeline.add(
    Node(
        "format_sse_event()",
        icon=PhosphorIcon.FILE_CODE,
        width=28,
        height=14,
        card_style=Styles.Neutral,
    ),
    xy=(68, 35),
)
keepalive = pipeline.add(
    Node(
        "KEEPALIVE_COMMENT\n(: ping / 15s)",
        icon=PhosphorIcon.CLOCK,
        width=28,
        height=15,
        card_style=Styles.Neutral,
    ),
    xy=(20, 12),
)
response = pipeline.add(
    Node(
        "EventSourceResponse\n(text/event-stream)",
        icon=PhosphorIcon.BROADCAST,
        width=28,
        height=15,
        style=Styles.White,
        text_style=Styles.WhiteBold.patch(text_size=10.0),
        card_style=Styles.PrimaryFlat,
    ),
    xy=(68, 12),
)

client = d.add(
    Node(
        "SSE Client\n(GET / POST)",
        icon=PhosphorIcon.TERMINAL_WINDOW,
        width=24,
        height=15,
        card_style=Styles.PrimaryNeutral,
    ),
    xy=(147, 17),
)

gen_node.connect(sse_model, label="yield", padding=1.2)
sse_model.connect(formatter, label="UTF-8", padding=1.2)
formatter.connect(response, padding=1.2)
keepalive.connect(response, label="idle", padding=1.2)
response.connect(client, label="SSE", padding=1.2)

d.draw(xy=(0, 0))
save()
```

---

## `class` EventSourceResponse

`starlette.responses.StreamingResponse` を継承し、`media_type = "text/event-stream"` を既定とするストリーミングレスポンスクラスです（`fastapi.responses` からも再エクスポートされています）。`yield` を用いる同期・非同期ジェネレータのパスオペレーションに `response_class=EventSourceResponse` を指定すると、MCP などの `POST` ストリームを含む任意の HTTP メソッドで SSE を配信します。ルーティング層が自動的に各アイテムをシリアライズし、`Cache-Control: no-cache` と `X-Accel-Buffering: no` ヘッダーおよび OpenAPI の `text/event-stream` スキーマを付与します。

```python
class EventSourceResponse(StreamingResponse):
    media_type = "text/event-stream"

    def __init__(
        self,
        content: ContentStream,
        status_code: int = 200,
        headers: Mapping[str, str] | None = None,
        media_type: str | None = None,
        background: BackgroundTask | None = None,
    ) -> None: ...
```

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `content` | `ContentStream` | *(必須)* | `EventSourceResponse` を直接インスタンス化する際の同期・非同期バイト／文字列イテレータ。`response_class=EventSourceResponse` として指定した場合は、パスオペレーションが `yield` した要素から FastAPI が自動的に SSE バイトストリームを生成します。 |
| `status_code` | `int` | `200` | ストリーミング開始時のレスポンスヘッダーで返す HTTP ステータスコード。 |
| `headers` | `Mapping[str, str] \| None` | `None` | `Cache-Control: no-cache` および `X-Accel-Buffering: no` と併せて送出する任意の追加レスポンスヘッダー。 |
| `media_type` | `str \| None` | `None` | メディアタイプの上書き指定。省略時はクラス属性 `"text/event-stream"` が使用されます。 |
| `background` | `BackgroundTask \| None` | `None` | イベントストリームのクローズ完了後に実行する任意のバックグラウンドタスク。 |

### 使用例

```python
from collections.abc import AsyncIterator

from fastapi import FastAPI
from fastapi.sse import EventSourceResponse, ServerSentEvent
from fastapi.testclient import TestClient

app = FastAPI()


@app.post("/mcp/events", response_class=EventSourceResponse)
async def stream_task_events() -> AsyncIterator[ServerSentEvent | dict[str, str]]:
    yield {"status": "started"}
    yield ServerSentEvent(event="done", data={"ok": True}, id="evt-2")


client = TestClient(app)
response = client.post("/mcp/events")
assert response.status_code == 200
assert response.headers["content-type"].startswith("text/event-stream")
assert response.headers["cache-control"] == "no-cache"
assert response.headers["x-accel-buffering"] == "no"
assert 'data: {"status":"started"}' in response.text
assert 'event: done\ndata: {"ok": true}\nid: evt-2' in response.text
```

---

## `class` ServerSentEvent

`EventSourceResponse` エンドポイントから `yield` される単一の SSE フレームを表す Pydantic `BaseModel` です。通常の Python オブジェクト（`dict`、`list`、`BaseModel` など）を直接 `yield` した場合は自動的に JSON エンコードされて `data:` に格納されますが、`ServerSentEvent` を用いることで JSON エンコード対象の `data` と非エンコード文字列 `raw_data` の使い分け、カスタム `event` 名、再接続用の `id`・`retry`、および `:` コメント行を精密に指定できます。

```python
class ServerSentEvent(BaseModel):
    data: Any = None
    raw_data: str | None = None
    event: str | None = None
    id: str | None = None
    retry: int | None = None
    comment: str | None = None
```

### フィールドとバリデータ

| フィールド | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `data` | `Any` | `None` | JSON シリアライズ可能なイベントペイロード（`BaseModel`、`dict`、`list`、`str`、`int` など）。プレーン文字列を含め**常に** JSON 文字列化されます（`data="hello"` は `data: "hello"` として出力）。`raw_data` とは排他指定です（`_check_data_exclusive`）。 |
| `raw_data` | `str \| None` | `None` | JSON エンコードを行わずそのまま `data:` フィールドに出力する整形済み文字列（HTML フラグメント、CSV 行、独自テキスト形式など）。`data` とは排他指定です。 |
| `event` | `str \| None` | `None` | ブラウザ側の `EventSource.addEventListener(event, ...)` に対応するイベント種別名。`\r` や `\n` を含まない単一行であることが検証されます（`_check_event_single_line`）。 |
| `id` | `str \| None` | `None` | 自動再接続時にクライアントが `Last-Event-ID` ヘッダーで再送するイベント ID。単一行かつ NULL 文字（`\0`）を含まないことが検証されます（`_check_id_valid`）。 |
| `retry` | `int \| None` | `None` | 切断後の再接続待機時間（**ミリ秒**）。`Field(ge=0)` により `0` 以上の整数であることが検証されます。 |
| `comment` | `str \| None` | `None` | SSE ワイヤフォーマット上で各行の先頭に `: ` を付与して送出するコメント文字列（`EventSource` クライアントでは無視されます）。 |

### 使用例

```python
import pytest
from pydantic import ValidationError

from fastapi.sse import ServerSentEvent

json_evt = ServerSentEvent(
    data={"temp_c": 21.5},
    event="telemetry",
    id="msg-101",
    retry=3000,
    comment="sensor-tick",
)
assert json_evt.event == "telemetry"
assert json_evt.retry == 3000

raw_evt = ServerSentEvent(raw_data="<span>ready</span>", event="fragment")
assert raw_evt.raw_data == "<span>ready</span>"
assert raw_evt.data is None

with pytest.raises(ValidationError):
    ServerSentEvent(data="json", raw_data="plain")

with pytest.raises(ValidationError):
    ServerSentEvent(id="bad\x00id")

with pytest.raises(ValidationError):
    ServerSentEvent(event="multi\nline")

with pytest.raises(ValidationError):
    ServerSentEvent(retry=-1)
```

---

## `def` format_sse_event()

事前シリアライズ済みのデータ文字列と任意の SSE メタデータから UTF-8 エンコード済みのワイヤフォーマット `bytes` を構築するキーワード専用関数です。複数行の `comment` や `data_str` は SSE 仕様の改行コード（`\r\n`、`\r`、`\n`）単位で分割されて連続する `: <line>`・`data: <line>` 行へ展開され、末尾は常にイベント終端を表す `\n\n` で終わります。

```python
def format_sse_event(
    *,
    data_str: str | None = None,
    event: str | None = None,
    id: str | None = None,
    retry: int | None = None,
    comment: str | None = None,
) -> bytes
```

### パラメータ

| パラメータ | 型 | デフォルト | 説明 |
| :--- | :--- | :--- | :--- |
| `data_str` | `str \| None` | `None` | 1 行または複数行の `data: <line>` レコードとして出力する事前シリアライズ済み文字列。 |
| `event` | `str \| None` | `None` | `event: <event>` 行として出力する任意のイベント種別名。 |
| `id` | `str \| None` | `None` | `id: <id>` 行として出力する任意のイベント識別子。 |
| `retry` | `int \| None` | `None` | `retry: <retry>` 行として出力するミリ秒単位の再接続待機時間。 |
| `comment` | `str \| None` | `None` | イベントフィールドの前に `: <line>` 行として出力する単一行または複数行のコメント。 |

### 使用例

```python
from fastapi.sse import format_sse_event

wire = format_sse_event(
    comment="heartbeat",
    event="update",
    data_str="line-1\r\nline-2",
    id="42",
    retry=5000,
)
assert wire == (
    b": heartbeat\n"
    b"event: update\n"
    b"data: line-1\n"
    b"data: line-2\n"
    b"id: 42\n"
    b"retry: 5000\n\n"
)
```

---

## `const` KEEPALIVE_COMMENT

`EventSourceResponse` のジェネレータが `15.0` 秒間（`_PING_INTERVAL`）アイテムを生成せずアイドル状態になった際、FastAPI のバックグラウンドタスクが自動送出する UTF-8 SSE コメント定数（`b": ping\n\n"`）です。無通信時でも定期的にバイトフレームを流すことでリバースプロキシやロードバランサのアイドルタイムアウト切断を防ぎつつ、`:` で始まるコメント行として `EventSource` クライアント側では安全に無視されます。

```python
KEEPALIVE_COMMENT: bytes = b": ping\n\n"
```

### 仕様

| 定数 | 型 | 値 | 説明 |
| :--- | :--- | :--- | :--- |
| `KEEPALIVE_COMMENT` | `bytes` | `b": ping\n\n"` | ジェネレータ無通信時に 15 秒間隔で自動送信される標準 SSE キープアライブコメントフレーム。 |

### 使用例

```python
from fastapi.sse import KEEPALIVE_COMMENT, format_sse_event

assert KEEPALIVE_COMMENT == b": ping\n\n"
assert format_sse_event(comment="ping") == KEEPALIVE_COMMENT
```
