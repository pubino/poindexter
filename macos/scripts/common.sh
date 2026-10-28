# Sourced by the other scripts. zsh.
set -euo pipefail
MACOS_DIR="${0:A:h:h}"
REPO_DIR="${MACOS_DIR:h}"
BUILD_DIR="$MACOS_DIR/build"
PROJECT="$MACOS_DIR/Poindexter.xcodeproj"
# SwiftPM's default (swift-build) backend trips over sandboxed environments; native is reliable.
SWIFT_FLAGS=(--build-system native --disable-index-store)

die() { print -u2 -- "error: $*"; exit 1; }
need() { command -v "$1" >/dev/null || die "$1 is required (${2:-brew install $1})"; }

# Read KEY=value lines from the repo's .env without executing it.
load_env() {
  local file="$REPO_DIR/.env" line key value
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == \#* || "$line" != *=* ]] && continue
    key="${line%%=*}"; value="${line#*=}"
    [[ "$key" =~ '^[A-Z_][A-Z0-9_]*$' ]] || die ".env: bad key '$key'"
    [[ -z "${(P)key-}" ]] && export "$key=$value"
  done < "$file"
}

require_env() {
  local key
  for key in "$@"; do [[ -n "${(P)key-}" ]] || die "$key is not set (see example.env)"; done
}

# 1.2.3 -> 10203: Sparkle compares CFBundleVersion, which must increase every release.
build_number() {
  [[ "$1" =~ '^([0-9]+)\.([0-9]+)\.([0-9]+)$' ]] || die "version must look like 1.2.3, got '$1'"
  print $(( match[1] * 10000 + match[2] * 100 + match[3] ))
}

generate_icon() {
  local set="$MACOS_DIR/App/Assets.xcassets/AppIcon.appiconset" master="$BUILD_DIR/icon-1024.png" s
  mkdir -p "$BUILD_DIR"
  (cd "$MACOS_DIR" && swift build "${SWIFT_FLAGS[@]}" -c release --product make-icon >/dev/null)
  "$MACOS_DIR/.build/release/make-icon" "$master"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$master" --out "$set/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$master" --out "$set/icon_${s}x${s}@2x.png" >/dev/null
  done
}

generate_project() {
  need xcodegen
  (cd "$MACOS_DIR" && xcodegen generate --quiet)
}

# Writes a one-item Sparkle appcast. The notes are embedded as Markdown, which Sparkle renders
# as formatted text instead of loading a release page in a web view.
# Usage: write_appcast OUT VERSION BUILD ZIP_URL "SIGNATURE_ATTRS" NOTES_FILE
write_appcast() {
  local out=$1 version=$2 build=$3 url=$4 sig=$5 notes=$6 text
  text=$(<"$notes")
  [[ "$text" != *']]>'* ]] || die "$notes must not contain ']]>'"
  cat > "$out" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Poindexter</title>
    <link>https://github.com/${GITHUB_REPO:?}</link>
    <item>
      <title>Version $version</title>
      <description sparkle:format="markdown"><![CDATA[$text]]></description>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$build</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure url="$url" type="application/octet-stream" $sig />
    </item>
  </channel>
</rss>
XML
}
