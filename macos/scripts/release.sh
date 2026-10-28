#!/bin/zsh
# Build, notarize and publish a GitHub release with the Sparkle appcast.
# Usage: scripts/release.sh VERSION [--dry-run]
#   --dry-run  does everything locally (including notarization) but creates no tag or release.
source "${0:A:h}/common.sh"
load_env
require_env GITHUB_REPO
version="${1:?usage: release.sh VERSION [--dry-run]}"
dry_run=false
[[ "${2:-}" == "--dry-run" ]] && dry_run=true
build=$(build_number "$version")
# User-facing Markdown notes, shown in Sparkle's update window and on the GitHub release.
notes="$MACOS_DIR/release-notes/$version.md"
[[ -s "$notes" ]] || die "write the release notes first: $notes"
tag="v$version"
out="$BUILD_DIR/release"
need gh

cd "$REPO_DIR"
if ! $dry_run; then
  [[ -z "$(git status --porcelain)" ]] || die "working tree is not clean"
  [[ "$(git rev-parse --abbrev-ref HEAD)" == main ]] || die "release from main"
  git fetch -q origin main
  [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || die "main is not in sync with origin"
  ! git rev-parse -q --verify "refs/tags/$tag" >/dev/null || die "tag $tag already exists"
fi

# CI runs on Linux only, so the Swift tests and app build are gated here instead.
"${0:A:h}/test.sh"
"${0:A:h}/notarize.sh" "$version"

zip="$out/Poindexter-$version.zip"
sig=$("$BUILD_DIR/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update" \
  --account "${SPARKLE_KEY_ACCOUNT:-ed25519}" "$zip")
[[ "$sig" == *edSignature=* ]] || die "sign_update failed (is the Sparkle private key in your keychain?)"
url="https://github.com/$GITHUB_REPO/releases/download/$tag/Poindexter-$version.zip"
write_appcast "$out/appcast.xml" "$version" "$build" "$url" "$sig" "$notes"

# Unversioned copy so releases/latest/download/Poindexter.dmg (the GitHub Pages download
# button) always resolves to the newest release.
cp "$out/Poindexter-$version.dmg" "$out/Poindexter.dmg"

if $dry_run; then
  print "Dry run: would tag $tag and upload:"
  ls -l "$out"/Poindexter-$version.{zip,dmg} "$out/Poindexter.dmg" "$out/appcast.xml"
  exit 0
fi
git tag -a "$tag" -m "Poindexter $version"
git push origin "$tag"
gh release create "$tag" -R "$GITHUB_REPO" --title "Poindexter $version" --notes-file "$notes" \
  "$out/Poindexter-$version.dmg" "$out/Poindexter.dmg" "$zip" "$out/appcast.xml"
print "Published: https://github.com/$GITHUB_REPO/releases/tag/$tag"
