#!/bin/zsh
# Checks the appcast that release.sh publishes: valid XML, Markdown notes embedded verbatim, no
# release-notes link (which Sparkle would load in a web view), and only sparkle: names that the
# bundled Sparkle actually reads. Run after a build, which fetches Sparkle.
source "${0:A:h}/common.sh"
need xmllint
sparkle_bin="$BUILD_DIR/SourcePackages/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework/Versions/B/Sparkle"
[[ -f "$sparkle_bin" ]] || die "Sparkle not found; run scripts/build.sh first"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { print -u2 -- "test-appcast: FAIL: $*"; exit 1; }
xpath() { xmllint --xpath "$1" "$tmp/appcast.xml"; }

print -r -- $'## What\'s new\n\n- **Settings** has an Updates tab & asks <first> launch\n- "Quotes" stay' > "$tmp/notes.md"
GITHUB_REPO=example/app write_appcast "$tmp/appcast.xml" 1.2.3 10203 \
  https://example.com/App-1.2.3.zip 'sparkle:edSignature="SIG" length="42"' "$tmp/notes.md"

xmllint --noout "$tmp/appcast.xml" || fail "appcast is not well-formed XML"
[[ "$(xpath 'string(//*[local-name()="description"])')" == "$(<"$tmp/notes.md")" ]] \
  || fail "notes are not embedded verbatim"
[[ "$(xpath 'string(//*[local-name()="description"]/@*[local-name()="format"])')" == markdown ]] \
  || fail "notes are not marked markdown"
# Sparkle silently ignores names it doesn't know, e.g. sparkle:descriptionFormat in 2.10.
strings -a "$sparkle_bin" > "$tmp/known.txt"
for name in ${(u)${(f)"$(grep -oE 'sparkle:[A-Za-z]+' "$tmp/appcast.xml")"}}; do
  grep -qxF "$name" "$tmp/known.txt" || fail "Sparkle doesn't read $name"
done
[[ "$(xpath 'count(//*[local-name()="releaseNotesLink" or local-name()="fullReleaseNotesLink"])')" == 0 ]] \
  || fail "appcast still links to release notes"
[[ "$(xpath 'string(//*[local-name()="enclosure"]/@*[local-name()="edSignature"])')" == SIG ]] \
  || fail "signature attributes missing"
[[ "$(xpath 'string(//*[local-name()="version"])')" == 10203 ]] || fail "build number missing"

print -r -- 'bad ]]> notes' > "$tmp/bad.md"
if (GITHUB_REPO=example/app write_appcast "$tmp/bad.xml" 1.2.3 10203 u s "$tmp/bad.md") 2>/dev/null; then
  fail "notes containing ']]>' were accepted"
fi
print "test-appcast: 8 checks passed"
