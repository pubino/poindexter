#!/bin/zsh
# Create/refresh the local .venv and install the `pdf2pptx` command. Safe to re-run.
set -euo pipefail
cd "${0:A:h}/.."
command -v uv >/dev/null || { echo "uv is required: brew install uv" >&2; exit 1; }
uv sync --frozen
echo "Installed. Run: $PWD/.venv/bin/pdf2pptx talk.pdf"
