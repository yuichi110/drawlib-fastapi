# PNI Software Health Diagnostic Report

**FastAPI `v0.162.2`** — *Automated Architecture, Static AST, Hermetic Runtime & Supply-Chain Diagnostic*

This independent technical showcase evaluates **FastAPI `v0.162.2`** (created by Sebastián Ramírez / [`@tiangolo`](https://github.com/tiangolo), MIT License) across 7 software engineering dimensions using [PNI501](https://pypi.org/project/pni501/) and [Drawlib](https://www.drawlib.com/). All upstream framework modules, test suites, and dependency manifests are inspected unmodified in zero-pollution hermetic environments.

```drawlib align=center code=fold file=pni_cover_scorecard.png caption="FastAPI v0.162.2 — PNI501 Overall Engineering Health Scorecard"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.smartarts import KpiCards, Panel
from drawlib.styles import Colors, Styles

setup(width=146, height=58, dpi=150)

white_card = Styles.Neutral.patch(shape_fill_color=Colors.White)

outer = Panel(
    "FastAPI v0.162.2 — Health Scorecard",
    "PNI501 (wf-682a5ab5) · Python >=3.10..3.14 · py.typed",
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral.patch(shape_line_width=1.2),
    text_style=Styles.DarkBold.patch(text_size=12.0),
    description_style=Styles.Muted.patch(text_size=10.0),
    icon=phosphor.gauge,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=9.0,
)
outer.draw((4.5, 4.5), width=137.0, height=49.0, align="bottom_left")
inner_xy, inner_w, inner_h = outer.get_content_box(
    (4.5, 4.5),
    width=137.0,
    height=49.0,
    padding=(3.5, 3.0),
    align="bottom_left",
)

kpis = KpiCards(
    style=white_card,
    metric_style=Styles.DarkBold.patch(text_size=14.0),
    text_style=Styles.DarkBold.patch(text_size=11.2),
    description_style=Styles.Muted.patch(text_size=10.0),
    accent_style=Styles.PrimaryFlat,
    icon_style=Styles.PrimaryBold,
    accent_position="left_pill",
    metric_layout="left_column",
    metric_width_ratio=0.30,
    spacing=3.5,
)

kpis.add(
    "93 / 100",
    "Overall Score (Grade S)",
    "52 modules · 19,837 LOC · Python",
    style=Styles.PrimaryFlat,
    metric_style=Styles.WhiteBold.patch(text_size=14.0),
    text_style=Styles.WhiteBold.patch(text_size=11.2),
    description_style=Styles.White.patch(text_size=10.0),
    accent_style=Styles.WhiteFlat,
    icon=phosphor.check_circle,
    icon_style=Styles.WhiteBold,
)
kpis.add(
    "10 / 15",
    "Rule Compliance (0 FAIL)",
    "10 PASS · 5 WARN · 8 findings (3M, 5L)",
    accent_style=Styles.PrimaryFlat,
    icon=phosphor.clipboard_text,
    icon_style=Styles.PrimaryBold,
)
kpis.add(
    "96.4%",
    "Hermetic Line Coverage",
    "3,216 passed · 91.0% branch · offline",
    accent_style=Styles.SuccessFlat,
    icon=phosphor.shield_check,
    icon_style=Styles.SuccessBold,
)
kpis.add(
    "0 CVEs",
    "0 Core CVEs · 0 CWE Sinks",
    "6 core deps clean · 0 secrets · 0 IaC",
    accent_style=Styles.SuccessFlat,
    icon=phosphor.lock_key,
    icon_style=Styles.SuccessBold,
)

kpis.draw(inner_xy, width=inner_w, height=inner_h, columns=2, align="bottom_left")

save()
```

| Diagnostic Attribute | Verified Metadata & Audit Baseline |
| :--- | :--- |
| **Target Project** | `fastapi` (`v0.162.2`, tag `3adc94ef`, Python `>=3.10..3.14`, packaged PEP 561 `fastapi/py.typed`) |
| **Target Language & Profile** | `python` (`library` — High-performance ASGI 3.0 web API framework & OpenAPI 3.1 compiler) |
| **Upstream License & Attribution** | MIT License (`LICENSE-FASTAPI`; Copyright © Sebastián Ramírez — FastAPI® is a registered trademark of Sebastián Ramírez) |
| **Diagnostic Workflow** | `pni501` (Workflow Run ID `wf-682a5ab5`, category `audit`) |
| **Evaluated At** | `2026-11-08T12:21:21+00:00` (`2026-11-08T12:21:21.280043+00:00`) |
| **Overall Score & Grade** | **93 / 100 (Grade S)** — `10 / 15` rules `PASS`, `5 WARN`, `0 FAIL` (`8` findings: `0` CRITICAL, `0` HIGH, `3` MEDIUM, `5` LOW) |
| **Analyzed Codebase Scope** | `52` source modules (`19,837` LOC, `121` classes, `438` functions) & `273` core test modules (`3,216` hermetic tests passed under `--network=none`) |

> **Unofficial Engineering Showcase Notice**: This diagnostic report is an independent automated analysis generated with [PNI501](https://pypi.org/project/pni501/) and [Drawlib](https://www.drawlib.com/) to celebrate FastAPI's engineering design and is not affiliated with or endorsed by Sebastián Ramírez or the official [FastAPI project](https://fastapi.tiangolo.com/).
