#!/bin/zsh
# Run lint, type checks and tests locally, or in Docker with --docker.
set -euo pipefail
cd "${0:A:h}/.."
if [[ "${1:-}" == "--docker" ]]; then
  docker-compose build test
  docker-compose run --rm test
else
  uv sync --frozen
  uv run ruff format --check .
  uv run ruff check .
  uv run mypy
  uv run pytest -q
fi
