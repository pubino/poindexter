#!/bin/zsh
# Archive, sign with Developer ID, notarize and staple. Produces in macos/build/release/:
#   Poindexter-VERSION.zip  (stapled app, used by Sparkle)
#   Poindexter-VERSION.dmg  (signed, notarized, stapled; for first-time downloads)
# Usage: scripts/notarize.sh VERSION
source "${0:A:h}/common.sh"
load_env
require_env DEVELOPMENT_TEAM NOTARY_PROFILE SPARKLE_PUBLIC_KEY
version="${1:?usage: notarize.sh VERSION}"
build=$(build_number "$version")
out="$BUILD_DIR/release"
archive="$BUILD_DIR/Poindexter.xcarchive"
identity="Developer ID Application"

security find-identity -v -p codesigning | grep -q "$identity: .*($DEVELOPMENT_TEAM)" \
  || die "no '$identity' certificate for team $DEVELOPMENT_TEAM in your keychain"
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
  || die "notarytool profile '$NOTARY_PROFILE' not found; see README (xcrun notarytool store-credentials)"

rm -rf "$out" "$archive"
mkdir -p "$out"
generate_icon
generate_project

xcodebuild -project "$PROJECT" -scheme Poindexter -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" -clonedSourcePackagesDirPath "$BUILD_DIR/SourcePackages" \
  -archivePath "$archive" archive -quiet \
  MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" CODE_SIGN_IDENTITY="$identity" OTHER_CODE_SIGN_FLAGS=--timestamp \
  SPARKLE_PUBLIC_KEY="$SPARKLE_PUBLIC_KEY"

plist="$BUILD_DIR/ExportOptions.plist"
cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>$identity</string>
  <key>teamID</key><string>$DEVELOPMENT_TEAM</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$archive" -exportPath "$out/export" -exportOptionsPlist "$plist" -quiet
app="$out/export/Poindexter.app"
codesign --verify --deep --strict "$app"

print "Notarizing app…"
ditto -c -k --keepParent "$app" "$out/notarize.zip"
xcrun notarytool submit "$out/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$app"
rm "$out/notarize.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$out/Poindexter-$version.zip"

print "Building and notarizing DMG…"
staging="$out/dmg"
mkdir -p "$staging"
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
hdiutil create -volname "Poindexter $version" -srcfolder "$staging" -ov -format UDZO \
  "$out/Poindexter-$version.dmg" -quiet
rm -rf "$staging"
codesign --sign "$identity" --timestamp "$out/Poindexter-$version.dmg"
xcrun notarytool submit "$out/Poindexter-$version.dmg" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$out/Poindexter-$version.dmg"

spctl --assess --type execute --verbose "$app"
spctl --assess --type open --context context:primary-signature --verbose "$out/Poindexter-$version.dmg"
print "Ready: $out/Poindexter-$version.zip and .dmg"
