from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LATEST_DMG = "https://github.com/pubino/poindexter/releases/latest/download/Poindexter.dmg"


def test_pages_download_links_to_latest_release() -> None:
    html = (ROOT / "docs" / "index.html").read_text()
    links = re.findall(r'class="download" href="([^"]+)"', html)
    assert links == [LATEST_DMG]


def test_release_uploads_the_unversioned_dmg_the_page_links_to() -> None:
    script = (ROOT / "macos" / "scripts" / "release.sh").read_text()
    upload = script[script.index("gh release create") :]
    assert '"$out/Poindexter.dmg"' in upload.split("\nprint", 1)[0]
