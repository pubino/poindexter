#!/bin/zsh
# Checks the appcast that release.sh publishes: valid XML, plain-text notes embedded verbatim,
# and no release-notes link (which Sparkle would load in a web view).
source "${0:A:h}/common.sh"
need xmllint
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { print -u2 -- "test-appcast: FAIL: $*"; exit 1; }
xpath() { xmllint --xpath "$1" "$tmp/appcast.xml"; }

print -r -- $'- Settings has an Updates tab & asks <first> launch\n- "Quotes" stay' > "$tmp/notes.txt"
GITHUB_REPO=example/app write_appcast "$tmp/appcast.xml" 1.2.3 10203 \
  https://example.com/App-1.2.3.zip 'sparkle:edSignature="SIG" length="42"' "$tmp/notes.txt"

xmllint --noout "$tmp/appcast.xml" || fail "appcast is not well-formed XML"
[[ "$(xpath 'string(//*[local-name()="description"])')" == "$(<"$tmp/notes.txt")" ]] \
  || fail "notes are not embedded verbatim"
[[ "$(xpath 'string(//*[local-name()="description"]/@*[local-name()="descriptionFormat"])')" == plain-text ]] \
  || fail "notes are not marked plain-text"
[[ "$(xpath 'count(//*[local-name()="releaseNotesLink" or local-name()="fullReleaseNotesLink"])')" == 0 ]] \
  || fail "appcast still links to release notes"
[[ "$(xpath 'string(//*[local-name()="enclosure"]/@*[local-name()="edSignature"])')" == SIG ]] \
  || fail "signature attributes missing"
[[ "$(xpath 'string(//*[local-name()="version"])')" == 10203 ]] || fail "build number missing"

print -r -- 'bad ]]> notes' > "$tmp/bad.txt"
if (GITHUB_REPO=example/app write_appcast "$tmp/bad.xml" 1.2.3 10203 u s "$tmp/bad.txt") 2>/dev/null; then
  fail "notes containing ']]>' were accepted"
fi
print "test-appcast: 7 checks passed"
