# 6. Deep Dive: Security, Supply Chain & API Surface

FastAPI `v0.162.2` maintains an exemplary framework security posture (`security_vulnerability_audit`: **91/100, Grade S**; `security` axis: **92/100**): all `6` core runtime dependencies carry **zero CVEs**, deterministic SAST scanning across `52` source modules (`19,837` LOC) detects **zero CWE-classified dangerous execution sinks**, and Trivy + AST scans confirm **zero hardcoded secrets** and **zero container IaC misconfigurations**. Vulnerability findings are strictly isolated to `7` transitive advisories in the development/optional `uv.lock` (`1` HIGH in `dnspython@2.8.0 -> 2.9.0`) and `398` OS-layer advisories inside the ephemeral `debian 12.13` CI test image.

```drawlib align=center code=fold file=supply_chain_cve_comparison.png caption="Vulnerability Isolation Across Core FastAPI Wheel, Dev/Optional uv.lock, and Ephemeral Debian 12.13 Test OS"
from drawlib.canvas import save, setup
from drawlib.charts.bar import BarChart
from drawlib.icons import phosphor
from drawlib.smartarts import KpiCards, Panel
from drawlib.styles import Styles

setup(width=146, height=68, dpi=150)

# Left: Grouped BarChart comparing Severity Counts across the 3 Artifact Scopes
chart = BarChart(
    axis_line_style=Styles.MutedDashed,
    categories=["CRITICAL", "HIGH", "MEDIUM", "LOW"],
    width=88.0,
    height=46.5,
    title="Trivy SCA Vulnerability Counts by Artifact Boundary & Severity",
    title_style=Styles.BlackBold.patch(text_size=11.8),
    orientation="vertical",
    bar_mode="group",
    bar_width_ratio=0.76,
    bar_r=0.8,
    axis_text_style=Styles.DarkBold.patch(text_size=10.0),
    grid_style=Styles.MutedThin,
    value_text_style=Styles.DarkBold.patch(text_size=9.8),
    value_format="{:.0f}",
)
chart.add_series("Core Wheel (6 pkgs)", [0, 0, 0, 0], style=Styles.PrimaryFlat)
chart.add_series("Dev/Optional uv.lock", [0, 1, 5, 1], style=Styles.WarningFlat)
chart.add_series("Test OS (Debian 12.13)", [9, 74, 169, 139], style=Styles.SecondaryNeutral)
chart.configure_y_axis(min_value=0.0, max_value=195.0, tick_step=50.0, label="CVE Count")
chart.draw(xy=(5.5, 15.0))
chart.draw_legend(
    xy=(7.5, 8.0),
    text_style=Styles.DarkBold.patch(text_size=10.0),
    orientation="horizontal",
    item_gap=4.2,
)

# Right: Boundary Isolation Summary Panel
panel = Panel(
    "Blast-Radius Isolation",
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
    icon=phosphor.package,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
panel.draw((96.5, 6.0), width=44.0, height=56.5)
r_xy, r_w, r_h = panel.get_content_box(
    (96.5, 6.0), width=44.0, height=56.5, padding=(2.5, 2.5)
)

kpis = KpiCards(
    style=Styles.White,
    metric_style=Styles.PrimaryBold.patch(text_size=15.5),
    text_style=Styles.DarkBold.patch(text_size=10.2),
    description_style=Styles.Muted.patch(text_size=9.5),
    accent_style=Styles.PrimaryFlat,
    accent_position="left_pill",
    metric_layout="left_column",
    metric_width_ratio=0.32,
    spacing=2.4,
)
kpis.add("0", "Core Runtime Deps", "Zero consumer CVEs")
kpis.add(
    "7",
    "Dev/Optional Lock",
    "1 High: dnspython 2.9",
    accent_style=Styles.WarningFlat,
    metric_style=Styles.WarningBold.patch(text_size=15.5),
)
kpis.add(
    "398",
    "Ephemeral Test OS",
    "CI harness image only",
    accent_style=Styles.SecondaryFlat,
    metric_style=Styles.DarkBold.patch(text_size=15.0),
)
kpis.draw(xy=r_xy, width=r_w, height=r_h, columns=1)

save()
```

---

## 6.1 Supply-Chain Hygiene, Packaging & Governance Baseline

FastAPI's PEP 621 `pyproject.toml` manifest and dependency architecture (`dependencies` axis: **96/100**) minimize downstream supply-chain exposure by keeping the default `pip install fastapi` footprint ultra-lean while isolating optional runtime integrations (`[standard]`, `[opentelemetry]`, `[all]`) and PEP 735 `[dependency-groups]` (`dev`, `tests`, `docs`, `translations`, `github-actions`) behind a reproducible `uv.lock`.

| Supply-Chain & Governance Gate | Metric / Value | Verdict | Architectural & Compliance Evidence |
| :--- | :--- | :--- | :--- |
| **Deterministic Lockfile (`has_lockfile`)** | `True` (`uv.lock`) | **`PASS`** | Reproducible multi-group dependency graph committed under `uv` |
| **Core Runtime Dependencies (`dependencies_count`)** | `6` packages | **`PASS`** | Ultra-lean ASGI, validation, typing, inline docs, and OTel API surface |
| **Unpinned Specifiers (`unpinned_dependencies_count`)** | **`0`** | **`PASS`** | Every dependency declares an explicit SemVer `>=` floor without upper-cap lock-in |
| **Dual Licensing Clarity (`has_license`)** | `True` | **`PASS`** | Repository Apache-2.0 `LICENSE` + upstream FastAPI MIT `LICENSE-FASTAPI` |
| **Committed / Hardcoded Secrets** | **`0` files / `0` literals** | **`PASS`** | Clean across both Trivy secret scanner and deterministic AST literal inspection |
| **AST Dangerous Sinks (`ast_dangerous_sinks_count`)** | **`0`** | **`PASS`** | Zero `CWE-78`/`89`/`94`/`502`/`22` execution or deserialization sinks in `fastapi/` |
| **Standalone HTTP Endpoints (`api_endpoints_count`)** | **`0`** | **`PASS`** | Reusable `library` archetype; binds zero network ports upon import |
| **Repo Governance (`SECURITY.md` / Dependabot)** | `False` / `False` | `WARN` | Omitted in this standalone showcase snapshot (upstream FastAPI publishes GitHub Security Advisories) |

### Core Wheel Runtime Dependency Inventory (`0` CVEs)

| Core Package | `pyproject.toml` Constraint | Resolved `uv.lock` | Primary Architectural Responsibility | Trivy CVEs |
| :--- | :--- | :--- | :--- | :--- |
| `starlette` | `>=0.46.0` | `1.7.0` | Asynchronous ASGI 3.0 routing, lifespan, WebSockets, middleware & `TestClient` | **`0`** |
| `pydantic` | `>=2.9.0` | `2.13.5` | Rust-backed `pydantic-core` `TypeAdapter` validation, serialization & JSON Schema | **`0`** |
| `typing-extensions` | `>=4.8.0` | `4.16.0` | Backported typing constructs (`Annotated`, `@deprecated`, `TypedDict`, `TypeAliasType`) | **`0`** |
| `typing-inspection` | `>=0.4.2` | `0.4.4` | High-speed runtime `Annotated` and generic signature introspection for `Dependant` DAGs | **`0`** |
| `annotated-doc` | `>=0.0.2` | `0.0.5` | Zero-overhead PEP 727 `Doc("...")` inline parameter documentation carrier | **`0`** |
| `opentelemetry-api` | `>=1.44.0` | `1.45.1` | Vendor-neutral distributed tracing & metrics API (`no-op` until an OTel SDK is configured) | **`0`** |

---

## 6.2 Vulnerability Triage: Core Wheel vs. `uv.lock` vs. Test Harness OS

Containerized Trivy `0.69.3` scanning (`engine=docker`, `scanned_filesystem=True`, `scanned_resolved_image=True` against `.pni/dockerfiles/Dockerfile`) flagged an overall scan status of `failed` due to `405` combined advisories (`7` application lockfile + `398` OS base-image). Separating these results by deployment boundary is essential for accurate risk assessment:

| Artifact Scope | CRITICAL | HIGH | MEDIUM | LOW | Total | Downstream Consumer Impact & Remediation |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **1. FastAPI Core Runtime Wheel (`6` pkgs)** | **`0`** | **`0`** | **`0`** | **`0`** | **`0`** | **None**: Downstream `fastapi` installations resolve clean latest SemVer-compatible packages |
| **2. Transitive Dev / Optional `uv.lock`** | **`0`** | `1` | `5` | `1` | `7` | **Dev/CI Only**: `dnspython@2.8.0` (via optional `email-validator`); upgrade via `uv lock --upgrade-package dnspython` (`>=2.9.0`) |
| **3. Ephemeral Test Harness OS (`debian 12.13`)** | `9` | `74` | `169` | `139` | `398` | **None (Never Shipped)**: Air-gapped `bookworm-slim` pytest runner; refresh via `apt-get upgrade -y` or `trixie-slim` |

### Top Pre-Sorted CRITICAL & HIGH Vulnerability Advisories

The table below renders the exact pre-sorted top `CRITICAL` and `HIGH` Trivy findings across `uv.lock` and the `debian 12.13` test-harness container image, including exact installed and upstream fixed versions:

| Severity | CVE ID | Package & Installed Version | Ecosystem | Fixed Version | Advisory Summary |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`CRITICAL`** | `CVE-2026-42010` | `libgnutls30@3.7.9-2+deb12u5` | `debian` | `3.7.9-2+deb12u7` | `gnutls`: Authentication Bypass via NUL Character in Username |
| **`CRITICAL`** | `CVE-2026-31789` | `libssl3@3.0.18-1~deb12u2` | `debian` | `3.0.19-1~deb12u2` | `openssl`: Heap buffer overflow on 32-bit systems from large X.509 certificate processing |
| **`CRITICAL`** | `CVE-2026-31789` | `openssl@3.0.18-1~deb12u2` | `debian` | `3.0.19-1~deb12u2` | `openssl`: Heap buffer overflow on 32-bit systems from large X.509 certificate processing |
| **`CRITICAL`** | `CVE-2026-8376` | `perl-base@5.36.0-7+deb12u3` | `debian` | `5.36.0-7+deb12u4` | `perl`: Heap buffer overflow when compiling regular expressions on 32-bit builds |
| **`CRITICAL`** | `CVE-2023-45853` | `zlib1g@1:1.2.13.dfsg-1` | `debian` | *(no upstream fix)* | `zlib`: Integer overflow and resultant heap-based buffer overflow in `zipOpenNewFileInZip4_6` |
| **`CRITICAL`** | `CVE-2026-33845` | `libgnutls30@3.7.9-2+deb12u5` | `debian` | `3.7.9-2+deb12u7` | `gnutls`: Denial of Service via DTLS zero-length fragment |
| **`CRITICAL`** | `CVE-2025-7458` | `libsqlite3-0@3.40.1-2+deb12u2` | `debian` | *(no upstream fix)* | `sqlite`: SQLite integer overflow |
| **`CRITICAL`** | `CVE-2026-13221` | `perl-base@5.36.0-7+deb12u3` | `debian` | `5.36.0-7+deb12u4` | `perl`: Incorrect regular expression processing via large regular expressions |
| **`CRITICAL`** | `CVE-2026-42496` | `perl-base@5.36.0-7+deb12u3` | `debian` | `5.36.0-7+deb12u4` | `perl-archive-tar`: Path traversal via crafted symlinks allows arbitrary file access |
| **`HIGH`** | `CVE-2026-114605` | `dnspython@2.8.0` | `uv` | **`2.9.0`** | `dnspython`: Denial of Service via excessive DNS compression pointer traversal (`CVSS 7.5`) |
| **`HIGH`** | `CVE-2026-45447` | `libssl3@3.0.18-1~deb12u2` | `debian` | `3.0.20-1~deb12u2` | `openssl`: Heap Use-After-Free in OpenSSL `PKCS7_verify()` |
| **`HIGH`** | `CVE-2026-16742` | `libsystemd0@252.39-1~deb12u1` | `debian` | *(no upstream fix)* | `systemd`: `systemd-homed` local privilege escalation via missing home-record signature check |
| **`HIGH`** | `CVE-2026-16742` | `libudev1@252.39-1~deb12u1` | `debian` | *(no upstream fix)* | `systemd`: `systemd-homed` local privilege escalation via missing home-record signature check |
| **`HIGH`** | `CVE-2026-45447` | `openssl@3.0.18-1~deb12u2` | `debian` | `3.0.20-1~deb12u2` | `openssl`: Heap Use-After-Free in OpenSSL `PKCS7_verify()` |
| **`HIGH`** | `CVE-2026-76844` | `zlib1g@1:1.2.13.dfsg-1` | `debian` | *(no upstream fix)* | `webpack-dev-middleware` / `zlib1g` metadata match: Information Disclosure via Path Traversal |

> [!NOTE]
> **Container IaC Hardening (`SEC-02`)**: Trivy reported **`0` Dockerfile misconfigurations** (`misconfigurations = []`). The test harness pins `ghcr.io/astral-sh/uv:python3.12-bookworm-slim` by SHA-256 digest, provisions unprivileged user `pni` (`UID 10001`), and runs offline (`--network=none`). Active `.pni/pni.toml` design waiver `DS-0026` appropriately exempts batch `pytest` containers from daemon `HEALTHCHECK` directives.

---

## 6.3 AST Dangerous Code Sinks (CWE) & Built-In Security Architecture

Because FastAPI is an installable framework library (`runtime_types = ["library"]`), it exposes **`0` standalone HTTP endpoints** (`api_endpoints = []`) while providing downstream applications with strongly typed, dependency-injected security extractors across `fastapi/security/*` (all achieving **`100.0%` statement coverage** under hermetic testing).

```drawlib align=center code=fold file=security_posture_surface.png caption="Zero-Sink AST SAST Verification Gates & FastAPI Built-In Security Extractor Primitives"
from drawlib.canvas import save, setup
from drawlib.icons import phosphor
from drawlib.smartarts import CardList, KpiCards, Panel
from drawlib.styles import Styles

setup(width=146, height=72, dpi=150)

# Left Panel: 2x2 SAST, Secret, IaC & Attack-Surface Verification KPIs
left_panel = Panel(
    "SAST & Hardening Gates",
    "AST + Trivy",
    style=Styles.Neutral,
    header_style=Styles.PrimaryNeutral,
    text_style=Styles.DarkBold.patch(text_size=11.0),
    description_style=Styles.Muted.patch(text_size=9.8),
    icon=phosphor.shield_check,
    icon_style=Styles.PrimaryBold,
    header_variant="filled",
    header_height=8.5,
)
left_panel.draw((5.0, 5.5), width=62.0, height=60.5)
l_xy, l_w, l_h = left_panel.get_content_box(
    (5.0, 5.5), width=62.0, height=60.5, padding=(2.8, 2.8)
)

sast_kpis = KpiCards(
    style=Styles.White,
    metric_style=Styles.PrimaryBold.patch(text_size=14.5),
    text_style=Styles.DarkBold.patch(text_size=10.2),
    description_style=Styles.Muted.patch(text_size=9.5),
    accent_style=Styles.PrimaryFlat,
    accent_position="top_bar",
    metric_layout="top_stack",
    spacing=2.8,
)
sast_kpis.add("0 Sinks", "AST CWE SAST", "No eval/shell/SQLi")
sast_kpis.add("0 Secrets", "Secret Hygiene", "Trivy + AST clean")
sast_kpis.add(
    "0 Misconfigs",
    "IaC Hardening",
    "Non-root UID 10001",
    accent_style=Styles.SecondaryFlat,
    metric_style=Styles.SecondaryBold.patch(text_size=14.5),
)
sast_kpis.add(
    "0 Routes",
    "Library Profile",
    "No exposed daemon",
    accent_style=Styles.SecondaryFlat,
    metric_style=Styles.SecondaryBold.patch(text_size=14.5),
)
sast_kpis.draw(xy=l_xy, width=l_w, height=l_h, columns=2)

# Right Panel: Built-In fastapi/security/* Primitives CardList
right_panel = Panel(
    "Built-In Security Extractors",
    "100% Stmt Cov.",
    style=Styles.PrimaryNeutral,
    header_style=Styles.PrimaryFlat,
    text_style=Styles.WhiteBold.patch(text_size=11.0),
    description_style=Styles.White.patch(text_size=9.8),
    icon=phosphor.lock_key,
    icon_style=Styles.WhiteBold,
    header_variant="filled",
    header_height=8.5,
)
right_panel.draw((70.5, 5.5), width=70.5, height=60.5)
r_xy, r_w, r_h = right_panel.get_content_box(
    (70.5, 5.5), width=70.5, height=60.5, padding=(2.8, 2.5)
)

sec_cards = CardList(
    style=Styles.White,
    text_style=Styles.DarkBold.patch(text_size=10.6),
    description_style=Styles.Muted.patch(text_size=9.6),
    badge_shape="rounded_rect",
    badge_style=Styles.PrimaryNeutral,
    icon_style=Styles.PrimaryBold,
    direction="vertical",
    spacing=2.4,
)
sec_cards.add(
    "OAuth2 & SecurityScopes",
    "OAuth2PasswordBearer, AuthCodeBearer\n& fine-grained SecurityScopes DAG",
    icon=phosphor.key,
    badge_style=Styles.PrimaryFlat,
    icon_style=Styles.WhiteBold,
)
sec_cards.add(
    "HTTP Basic, Bearer & Digest",
    "RFC 7617/6750/7616 header parsing\npairing with secrets.compare_digest",
    icon=phosphor.fingerprint,
)
sec_cards.add(
    "APIKey & OpenID Connect",
    "APIKeyHeader/Cookie/Query & OIDC\ndiscovery synthesized to OpenAPI 3.1",
    icon=phosphor.user_check,
)
sec_cards.draw(xy=r_xy, width=r_w, height=r_h)

save()
```

### CWE SAST Audit & Built-In `fastapi/security/*` Subsystems

1. **Zero CWE Execution Sinks (`SEC-04`)**: Deterministic AST scanning across all `52` source files verified complete absence of SQL string interpolation (`CWE-89`), shell command execution (`CWE-78`, zero `os.system` or `subprocess(..., shell=True)`), dynamic code evaluation or unsafe deserialization (`CWE-94` / `CWE-502`, zero `eval`, `exec`, `pickle`, or unsafe `yaml.load`), and unvalidated file traversal (`CWE-22`; `fastapi/routing.py` normalizes mounted SPA static paths via `os.path.realpath` containment checks before serving files).
2. **Co-Located Authorization & OpenAPI 3.1 Contract Generation (`SEC-05`)**: Every security class subclassing `SecurityBase` (`fastapi/security/base.py`) acts simultaneously as an async `Depends()` / `Security()` request validator and an OpenAPI 3.1 `securitySchemes` descriptor—ensuring authorization rules enforced at runtime never drift from published API documentation:

| Security Module | Exported Primitives | Runtime Enforcement & OpenAPI 3.1 Integration | Measured Stmt Cov. |
| :--- | :--- | :--- | :--- |
| `fastapi/security/oauth2.py` | `OAuth2`, `OAuth2PasswordBearer`, `OAuth2AuthorizationCodeBearer`, `OAuth2PasswordRequestForm` (`Strict`), `SecurityScopes` | Extracts Bearer tokens, parses RFC 6749 form credentials, and propagates required `Security(..., scopes=[...])` across nested `Dependant` sub-trees | **`100.0%`** (`66/66`) |
| `fastapi/security/http.py` | `HTTPBasic`, `HTTPBasicCredentials`, `HTTPBearer`, `HTTPDigest`, `HTTPAuthorizationCredentials` | Strictly validates `Authorization` schemes, handles malformed Base64/ASCII payloads with `401 WWW-Authenticate` headers, and structures credentials for constant-time `secrets.compare_digest` checks | **`100.0%`** (`81/81`) |
| `fastapi/security/api_key.py` | `APIKeyHeader`, `APIKeyCookie`, `APIKeyQuery` | Enforces required or optional (`auto_error=False`) API keys across headers, cookies, and query parameters | **`100.0%`** (`42/42`) |
| `fastapi/security/open_id_connect_url.py` | `OpenIdConnect` | Binds OIDC discovery URLs into OpenAPI 3.1 `openIdConnect` security definitions and validates `Authorization` headers | **`100.0%`** (`21/21`) |
