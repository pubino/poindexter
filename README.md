# Poindexter

Turns a PDF presentation (LaTeX beamer or anything else) into a PowerPoint `.pptx`
file. You don't need the LaTeX source.

Each PDF page is rendered at high resolution and placed full-bleed on its own slide,
so equations, fonts, TikZ figures and colours look exactly as they do in the PDF.
Slides are images, so their content can't be edited in PowerPoint. As a convenience:

- each page's text is copied into the **speaker notes**, so it can be searched and copied,
- the same text becomes the image **alt text**, so screen readers have something to read,
- slide size follows the PDF's aspect ratio: 4:3 beamer gives 10 × 7.5 in, 16:9 gives 13.33 × 7.5 in.

Nothing is uploaded anywhere: conversion runs entirely on your machine.

There are two front ends with the same behaviour:

| | For | Engine |
|---|---|---|
| **Poindexter.app** | macOS users: drag and drop, auto-updates | Swift + PDFKit, no third-party code except Sparkle |
| **`pdf2pptx` CLI** | Linux, Docker, scripting | Python + [pypdfium2](https://github.com/pypdfium2-team/pypdfium2) + [python-pptx](https://github.com/scanny/python-pptx) |

## macOS app

Download the latest `Poindexter-x.y.z.dmg` from
[Releases](https://github.com/pubino/poindexter/releases/latest) and drag it to Applications.
It is signed with a Developer ID and notarized by Apple, so it opens without warnings.
Sparkle keeps it up to date: on first launch it asks whether to check for updates
automatically, and **Settings → Updates** changes that later.

Drop PDFs on the window or the Dock icon, or use **Choose PDFs…**. Each `talk.pdf` produces
`talk.pptx` beside it. If that name is taken, the output is `talk 2.pptx`; existing files are
never overwritten. **Settings** (⌘,) has these options:
- one slide per beamer frame, which skips overlay build-up steps,
- PNG or JPEG images,
- resolution,
- whether to copy page text into the speaker notes,
- under **Updates**: automatic checks and how often, automatic download and install, and
  **Check Now**.

Requires macOS 14 or later.

## Command line (macOS / Linux)

```zsh
brew install uv          # once
./scripts/setup.sh       # creates .venv and installs the `pdf2pptx` command

.venv/bin/pdf2pptx talk.pdf                       # -> talk.pptx next to it
.venv/bin/pdf2pptx talk.pdf -o ~/Desktop/deck.pptx
.venv/bin/pdf2pptx *.pdf -o converted/            # batch into a directory
.venv/bin/pdf2pptx talk.pdf --collapse-overlays   # one slide per beamer frame
.venv/bin/pdf2pptx talk.pdf --format jpeg         # smaller file for photo-heavy decks
```

| Option | Default | Meaning |
|---|---|---|
| `--dpi N` | 220 (`PDF2PPTX_DPI`) | Pixels per inch of *slide*. 220 is sharp on a 4K projector. |
| `--format png\|jpeg` | png (`PDF2PPTX_FORMAT`) | PNG keeps text crisp. JPEG is smaller. |
| `--collapse-overlays` | off | Beamer `\pause`/`\only` steps share a page label, so keep only the last step of each frame. |
| `--no-notes` | off | Don't copy page text into the speaker notes. |
| `-f, --force` | off | Overwrite an existing `.pptx`. |

Exit status is 0 only if every input was converted.

### Docker

```zsh
mkdir -p work && cp talk.pdf work/
docker-compose run --rm convert talk.pdf          # -> work/talk.pptx
```

## Development

```zsh
./scripts/test.sh             # Python: ruff format + ruff lint + mypy --strict + pytest
./scripts/test.sh --docker    # same, inside the container
macos/scripts/test.sh         # Swift: swiftlint + core tests + full app build
macos/scripts/run.sh          # build and launch the app (Debug, ad-hoc signed)
./scripts/teardown.sh         # remove venvs, build products and generated files
```

CI runs on Linux runners only (Python, Docker, swiftlint). The Swift tests and app build
need macOS, so run `macos/scripts/test.sh` before pushing app changes. `release.sh` runs
it automatically and won't sign anything if it fails.

The Xcode project is generated from `macos/project.yml` by
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). Don't edit
`Poindexter.xcodeproj` directly. The app icon is drawn by code in
`macos/Sources/make-icon` and is regenerated on every build.

## Releasing the app

This is a Developer ID app, not an App Store app, so Xcode Cloud isn't involved.
Releases are built, signed and notarized locally. One-time setup:

1. **Certificate.** You need a *Developer ID Application* certificate in your login keychain.
   Check with `security find-identity -v -p codesigning`.
2. **Notarization credentials.** Store them once in the keychain under a profile that all your
   locally signed apps can share (`NOTARY_PROFILE`):
   ```zsh
   # Option A: App Store Connect API key (Users and Access → Integrations → Team Keys,
   # role "Developer"). Works well alongside Xcode Cloud.
   xcrun notarytool store-credentials notary \
     --key ~/path/AuthKey_XXXXXXXXXX.p8 --key-id XXXXXXXXXX --issuer <issuer-uuid>
   # Option B: Apple ID with an app-specific password from account.apple.com
   xcrun notarytool store-credentials notary \
     --apple-id you@example.com --team-id W7EJE9LZ23
   ```
3. **Sparkle signing key.** Run `macos/scripts/sparkle-keys.sh`. It prints the public key;
   put that in `.env`. The private key stays in your keychain. Back it up with
   `generate_keys -x`: if it's lost, existing installs can't verify future updates.
4. `cp example.env .env` and fill it in.

Then, from a clean, pushed `main`:

```zsh
macos/scripts/release.sh 0.1.0 --dry-run   # build, sign, notarize, staple; no tag or upload
macos/scripts/release.sh 0.1.0             # tag v0.1.0 and publish DMG, zip and appcast.xml
```

Installed apps check
`https://github.com/pubino/poindexter/releases/latest/download/appcast.xml`. Each release
uploads a fresh `appcast.xml`, and that URL always points at the newest one.

## Limitations

- Slides are pictures. Edits in PowerPoint mean adding text boxes on top of them.
- Animations, embedded video and audio are not carried over. Hyperlinks inside slides don't work.
- Password-protected PDFs are rejected with a clear error. Remove the password first.

## Licence

MIT. Third-party components:
- Sparkle (MIT), bundled in the app.
- pypdfium2/PDFium (Apache-2.0/BSD-3-Clause), python-pptx (MIT), Pillow (MIT-CMU) and
  lxml (BSD-3-Clause), used by the CLI and Docker image.
