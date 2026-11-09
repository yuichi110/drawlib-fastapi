# `fastapi/_compat/v2.py`・`ModelField`・ボディ分割と `serialize_response()`

FastAPI は、Pydantic 内部のバリデーション、JSON Schema 生成、および Rust 製シリアライザ API を専用のアダプタパッケージ `fastapi/_compat/`（`__init__.py`, `shared.py`, `v2.py`）の背後に隔離しています。FastAPI `v0.162.2` では旧 `pydantic.v1` サポートが廃止（`PydanticV1NotSupportedError`）され `v2.py` に一本化されていますが、クエリパラメータ・ヘッダ・リクエストボディ・レスポンスモデルのすべてを単一のインターフェースとして扱う抽象層 `ModelField` は引き続きルーティング・DI 解決・OpenAPI 3.1 合成の中核を担っています。

```drawlib align=center code=hide file=modelfield_typeadapter_bridge.png caption="fastapi/_compat/v2.py のアダプタ境界：FieldInfo と Pydantic v2 の TypeAdapter を ModelField に内包し、検証・Rust JSON 直列化・OpenAPI 生成へ統一提供する。"
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

## 1. なぜ `fastapi/_compat/` で Pydantic 内部実装を隔離するのか

Pydantic v2 では、v1 時代のフィールド単位の `ModelField` が廃止され、`pydantic-core`（Rust 実装）の `CoreSchema` ツリーを駆動する `TypeAdapter` 中心のアーキテクチャへ刷新されました。FastAPI は `routing.py`、`dependencies/utils.py`、`openapi/utils.py` の各所に `TypeAdapter` や `FieldInfo` 複製ロジック、あるいは `pydantic._internal` への呼び出しを散在させることを避け、Pydantic 連携を 2 つのモジュールに集約しています。

- **`fastapi/_compat/shared.py`**: コンパイル時の引数分類で使われる純粋な型検査述語群（`lenient_issubclass`, `field_annotation_is_scalar`, `field_annotation_is_sequence`, `field_annotation_is_scalar_sequence`, `is_uploadfile_or_nonable_uploadfile_annotation`, `is_bytes_or_nonable_bytes_annotation`）を提供します。
- **`fastapi/_compat/v2.py`**: `ModelField`、カスタム `GenerateJsonSchema`（OpenAPI 3.1 向けに `bytes_schema` を拡張し `contentMediaType: "application/octet-stream"` や `contentEncoding: "base64"` を出力）、`get_definitions()`（`separate_input_output_schemas=True` 時に `"validation"` 用と `"serialization"` 用の `$defs` スキーマを分離生成）、`evaluate_forwardref()`、および `create_body_model()` を実装します。

### 1.1 `ModelField`（`v2.py`）の内部構造

`ModelField` は `field_info: FieldInfo`、`name: str`、`mode: Literal["validation", "serialization"] = "validation"`、`config: ConfigDict | None = None` を保持する `@dataclass` です（スキーマ辞書のキーとして扱えるよう `__hash__` は `id(self)` を返します）。

1. **起動時の `TypeAdapter` 構築（`__post_init__`）**: `asdict(self.field_info)` で `(annotation, metadata, attributes)` を抽出し、Pydantic 2.12 以降で単体 `Field(alias=...)` 利用時に発生する `UnsupportedFieldAttributeWarning` を抑制した上で、`Annotated[annotation, *metadata, Field(**attributes)]` を再構築してルート登録時に一度だけ `self._type_adapter = TypeAdapter(..., config=self.config)` をコンパイルします。
2. **ロケーション接頭辞付きバリデーション（`validate`）**: `self._type_adapter.validate_python(value, from_attributes=True)` を呼び出し、ORM インスタンスからの属性読み取りも標準でサポートします。`ValidationError` 発生時には `_regenerate_error_with_loc()` がエラー URL を除外（`include_url=False`）しつつ、`("query", "limit")`、`("body", "item")`、`("response",)` といった FastAPI 文脈の `loc` タプルを各エラーの先頭へ付与します。
3. **2 系統のシリアライズメソッド（`serialize` と `serialize_json`）**: `serialize()` は `self._type_adapter.dump_python(value, mode=mode, ...)` により JSON 互換の Python `dict`/`list` を生成するのに対し、`serialize_json()` は `self._type_adapter.dump_json(value, ...)` を呼び出して **Rust 層で直接 UTF-8 の JSON `bytes` へ一括変換** し、中間 Python 辞書の生成と `json.dumps()` のコストを完全に省きます。

## 2. ボディ分割・`embed=True`・`create_body_model()`

HTTP リクエストのボディストリームは 1 本しかありませんが、FastAPI ではエンドポイントや複数のサブ依存関係にまたがって複数の `Body()`、`Form()`、`File()` 引数を同時に宣言できます。FastAPI はコンパイル時の合成と実行時のスライス検証を組み合わせることでこれを解決しています。

| エンドポイントのボディ宣言パターン | `_should_embed_body_fields()` | `APIRoute.body_field`（`_get_body_field`） | `request_body_to_args()` の実行時検証 |
| :--- | :--- | :--- | :--- |
| **単一 `BaseModel`（`item: Item`）** | `False` | `body_params[0]` をそのまま採用（`annotation is Item`） | ルート JSON 全体を `loc=("body",)` として直接検証。 |
| **`Body(embed=True)` 付き単一モデル** | `True` | `{"item": Item}` を包む `Body_<unique_id>` を動的合成 | `body.get("item")` を取り出し `loc=("body", "item")` で検証。 |
| **複数 `Body()` / サブ依存ボディ併用** | `True` | 全フィールドを統合した複合モデル `Body_<unique_id>` を合成 | 各 `Dependant` が自身の `body_params` に該当するキーのみをスライス検証。 |
| **スカラー `Form()` / `File()` 引数** | `True` | 優先順 `File` > `Form` > `Body` で `Body_<unique_id>` を合成 | `_extract_form_body()` で抽出し、`_read_file_bytes()` でファイル位置を巻き戻す。 |

`fastapi/dependencies/utils.py` には、特に重要な 2 つの設計上の不変条件があります。

- **`APIRoute.body_field` はメディアタイプ判定と OpenAPI 生成専用**: `_get_body_field()` の docstring に明記されている通り、`create_body_model(fields=..., model_name="Body_" + name)`（内部で `pydantic.create_model()` を呼び出す）は、フォームデータ判定（`isinstance(body_field.field_info, params.Form)`）と統合 OpenAPI `requestBody` スキーマ生成のために使われます。実行時の `solve_dependencies()` は `Body_<unique_id>` をインスタンス化 **せず**、各 `Dependant` が `request_body_to_args()` で自身の `body_params` だけを個別に検証するため、複数のサブ依存関係が同一 JSON ボディの異なるキーを安全に分担できます。
- **共有 `UploadFile` の非破壊読み取り（`_read_file_bytes`）**: `File()` 引数が `bytes` 型として宣言されている場合、`_read_file_bytes()` は `position = file.file.tell()` を記録して `await file.read()` を実行した後、`finally` ブロックで必ず `await file.seek(position)` を呼び出し、同じアップロードファイルを参照する後続の依存関係が空データを読み取らないよう保護します。

## 3. レスポンス直列化パイプライン：`serialize_response()` と `jsonable_encoder()`

`get_request_handler()`（`fastapi/routing.py`）内で `run_endpoint_function()` が `raw_response` を返すと、FastAPI は戻り値の型とルート設定に応じて最速かつ安全な直列化経路を選択します。

1. **`Response` インスタンスの直接パススルー**: `isinstance(raw_response, Response)` が `True` の場合（`StreamingResponse`、`FileResponse`、構築済み `JSONResponse` などを直接返した場合）、未設定であれば `solved_result.background_tasks` を引き継ぐだけで `serialize_response()` を一切通さずそのまま返却します。
2. **型付き `response_field` による検証と直列化（`field is not None`）**: `response_model=None` が明示されるか戻り値型が `Response` サブクラスでない限り、`APIRoute` は `route.response_field = create_model_field(..., mode="serialization")` を構築します。`serialize_response()` 内部では次の処理が行われます。
   - 非同期エンドポイントではイベントループ上で `field.validate(response_content, {}, loc=("response",))` を実行し、同期 `def` エンドポイントでは CPU 負荷の高いモデル変換でループを止めないよう `await run_in_threadpool(field.validate, ...)` へオフロードします。
   - 検証エラーが発生した場合は `ResponseValidationError`（HTTP `500 Internal Server Error`）を送出し、未検証の内部属性が外部へ漏洩することを防ぎます。
   - **Rust ワンパス高速経路（`use_dump_json=True`）**: `response_class` がデフォルト（`DefaultPlaceholder(JSONResponse)`）のまま変更されていない場合、`get_request_handler()` は `dump_json=True` を指定します。`serialize_response()` は `field.serialize_json(...)`（`include`, `exclude`, `by_alias`, `exclude_unset`, `exclude_defaults`, `exclude_none` を適用）で得た UTF-8 `bytes` を直接 `Response(content=content, media_type="application/json")` に格納して返します。
   - **カスタム `response_class` 経路（`use_dump_json=False`）**: 独自の `response_class` が指定されている場合は `field.serialize(...)`（`dump_python(mode="json")`）で Python オブジェクトへ変換し、`actual_response_class(content, **response_args)` へ渡します。
3. **型指定なし時のフォールバック（`fastapi/encoders.py` の `jsonable_encoder`）**: `response_field is None` の場合、`serialize_response()` は `jsonable_encoder(response_content)` へフォールバックします。この関数は `BaseModel`（`model_dump(mode="json")`）、`dataclass`（`dataclasses.asdict`）、`Enum`（`.value`）、`PurePath`、`dict`（`sqlalchemy_safe=True` 時に SQLAlchemy 内部状態キー `_sa*` を自動除外）、イテラブル・ジェネレータ、および `ENCODERS_BY_TYPE`（`datetime`/`date`/`time` $\rightarrow$ `isoformat()`、`timedelta` $\rightarrow$ `total_seconds()`、`Decimal` $\rightarrow$ 指数 $\ge 0$ なら `int` それ以外は `float`、`UUID` / `IPv4Address` / `Url` $\rightarrow$ `str`）を再帰変換し、最終的に `dict(obj)` と `vars(obj)` を試みます。

```drawlib align=center code=hide file=serialize_response_decision_tree.png caption="get_request_handler() と serialize_response() の分岐決定木：Response 直接返却、response_field 検証、Rust dump_json 高速経路、および jsonable_encoder() フォールバック。"
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

## 4. `APIRoute.body_field` 合成と `serialize_response()` のコード検証

以下のスニペットでは、単一モデルと複数ボディ引数における `APIRoute.body_field` の違い、および `serialize_response(dump_json=True)`（Rust による `bytes` 直接生成）と `jsonable_encoder()` フォールバックの挙動を検証します。

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

`APIRoute` が `body_field` と `response_field` をルートごとのハンドラクロージャへ組み込む仕組みについては [APIRouter・APIRoute とクロージャ合成](../02_routing_compiler/apiroute_and_closures.md) を、`get_definitions()` が `ModelField` 群から OpenAPI 3.1 の JSON Schema を生成する処理については [get_openapi()・$defs 集約・Docs UI](../06_openapi_and_docs/openapi_synthesis_engine.md) を参照してください。
