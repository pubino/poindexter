#!/bin/zsh
# Lint, unit-test the core, and compile the app. Fails on the first problem.
source "${0:A:h}/common.sh"
need swiftlint
cd "$MACOS_DIR"
swiftlint lint --strict --quiet
swift test "${SWIFT_FLAGS[@]}"
"$MACOS_DIR/scripts/test-appcast.sh"
"$MACOS_DIR/scripts/build.sh"
