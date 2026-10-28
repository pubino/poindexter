#!/bin/zsh
# One-time: create the Sparkle EdDSA key pair. The private key goes into your login keychain;
# the public key is printed for SPARKLE_PUBLIC_KEY in .env. Re-running prints the existing key.
# Back up the private key (generate_keys -x FILE) somewhere safe: losing it means existing
# installs can never update again.
source "${0:A:h}/common.sh"
generate_project
xcodebuild -project "$PROJECT" -resolvePackageDependencies \
  -clonedSourcePackagesDirPath "$BUILD_DIR/SourcePackages" -quiet
"$BUILD_DIR/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys"
