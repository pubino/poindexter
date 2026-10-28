#!/bin/zsh
# Build (Debug) and launch the app.
source "${0:A:h}/common.sh"
"${0:A:h}/build.sh"
open "$BUILD_DIR/DerivedData/Build/Products/Debug/Poindexter.app"
