#!/bin/zsh
# Lint, unit-test the core, and compile the app. Fails on the first problem.
source "${0:A:h}/common.sh"
need swiftlint
cd "$MACOS_DIR"
# release.sh runs this first, so a script that can't parse fails here, before anything is signed.
for script in "$MACOS_DIR"/scripts/*.sh; do zsh -n "$script" || die "syntax error in $script"; done
swiftlint lint --strict --quiet
swift test "${SWIFT_FLAGS[@]}"
"$MACOS_DIR/scripts/build.sh"
"$MACOS_DIR/scripts/test-appcast.sh"
