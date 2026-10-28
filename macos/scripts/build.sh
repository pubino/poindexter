#!/bin/zsh
# Build an unsigned-for-distribution (ad-hoc signed) Debug app into macos/build/. Safe to re-run.
# Usage: scripts/build.sh [--release]
source "${0:A:h}/common.sh"
config=Debug
[[ "${1:-}" == "--release" ]] && config=Release
generate_icon
generate_project
xcodebuild -project "$PROJECT" -scheme Poindexter -configuration "$config" \
  -derivedDataPath "$BUILD_DIR/DerivedData" -clonedSourcePackagesDirPath "$BUILD_DIR/SourcePackages" \
  CODE_SIGN_IDENTITY=- build -quiet
print "Built: $BUILD_DIR/DerivedData/Build/Products/$config/Poindexter.app"
