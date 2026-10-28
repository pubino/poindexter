#!/bin/zsh
# Remove local build products: Python venv, Swift/Xcode build dirs, generated project, caches.
# Safe to re-run.
set -euo pipefail
cd "${0:A:h}/.."
rm -rf .venv .pytest_cache .mypy_cache .ruff_cache \
  macos/.build macos/build macos/Poindexter.xcodeproj \
  macos/App/Assets.xcassets/AppIcon.appiconset/*.png(N)
echo "Cleaned."
