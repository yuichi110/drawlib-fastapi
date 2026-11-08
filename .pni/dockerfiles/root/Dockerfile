ARG PYTHON_VERSION=3.12
FROM ghcr.io/astral-sh/uv:python${PYTHON_VERSION}-bookworm-slim

ARG EXTRA_APT_PACKAGES=""
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/opt/pni-venv \
    VIRTUAL_ENV=/opt/pni-venv \
    PYTHONPATH="/workspace" \
    PATH="/opt/pni-venv/bin:$PATH"

RUN if [ -n "${EXTRA_APT_PACKAGES}" ]; then \
      apt-get update \
      && apt-get install -y --no-install-recommends ${EXTRA_APT_PACKAGES} \
      && rm -rf /var/lib/apt/lists/*; \
    fi \
    && useradd --uid 10001 --create-home --shell /bin/bash pni \
    && mkdir -p /workspace /out /opt/pni-venv \
    && chown -R pni:pni /workspace /out /opt/pni-venv \
    && chmod 0777 /out

WORKDIR /workspace
COPY --chown=pni:pni pyproject.toml uv.lock README.md LICENSE-FASTAPI /workspace/
COPY --chown=pni:pni fastapi /workspace/fastapi
COPY --chown=pni:pni tests /workspace/tests

RUN cp /workspace/LICENSE-FASTAPI /workspace/LICENSE \
    && uv sync --frozen --group tests --extra all --no-install-project \
    && uv pip install --python /opt/pni-venv/bin/python --no-deps -e . \
    && chown -R pni:pni /workspace /opt/pni-venv \
    && chmod -R a+rwX /workspace /opt/pni-venv

USER pni
CMD ["pytest"]
