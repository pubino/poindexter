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

"${0:A:h}/notarize.sh" "$version"

zip="$out/Poindexter-$version.zip"
sig=$("$BUILD_DIR/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update" "$zip")
[[ "$sig" == *edSignature=* ]] || die "sign_update failed (is the Sparkle private key in your keychain?)"
url="https://github.com/$GITHUB_REPO/releases/download/$tag/Poindexter-$version.zip"
cat > "$out/appcast.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Poindexter</title>
    <link>https://github.com/$GITHUB_REPO</link>
    <item>
      <title>Version $version</title>
      <sparkle:releaseNotesLink>https://github.com/$GITHUB_REPO/releases/tag/$tag</sparkle:releaseNotesLink>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$build</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure url="$url" type="application/octet-stream" $sig />
    </item>
  </channel>
</rss>
XML

if $dry_run; then
  print "Dry run: would tag $tag and upload:"
  ls -l "$out"/Poindexter-$version.{zip,dmg} "$out/appcast.xml"
  exit 0
fi
git tag -a "$tag" -m "Poindexter $version"
git push origin "$tag"
gh release create "$tag" -R "$GITHUB_REPO" --title "Poindexter $version" --generate-notes \
  "$out/Poindexter-$version.dmg" "$zip" "$out/appcast.xml"
print "Published: https://github.com/$GITHUB_REPO/releases/tag/$tag"
