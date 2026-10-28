# syntax=docker/dockerfile:1
FROM ghcr.io/astral-sh/uv:0.13.6 AS uv

FROM python:3.13.9-slim-bookworm@sha256:b685a4fa58bb19d1814d78a1ec0f0208f351452724f78b20212c984d6e124a34 AS base
COPY --from=uv /uv /usr/local/bin/uv
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=never \
    UV_PROJECT_ENVIRONMENT=/opt/venv PATH=/opt/venv/bin:$PATH
WORKDIR /app
COPY pyproject.toml uv.lock README.md ./
COPY src ./src

# Runtime image: `docker run --rm -v "$PWD:/work" pdf2pptx talk.pdf`
FROM base AS runtime
RUN uv sync --frozen --no-dev
RUN useradd --create-home --uid 1000 app
USER app
WORKDIR /work
ENTRYPOINT ["pdf2pptx"]

# Test image: lint, types and tests; the default command fails on any problem.
FROM base AS test
RUN uv sync --frozen
COPY tests ./tests
CMD ["sh", "-c", "ruff format --check . && ruff check . && mypy && pytest -q"]
