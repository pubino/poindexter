"""Write tiny, valid PDFs for tests without any extra dependency."""

from __future__ import annotations

from pathlib import Path


def _esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


def make_pdf(
    path: Path,
    texts: list[str],
    size: tuple[float, float] = (362.83, 272.13),  # beamer default, 128 x 96 mm
    labels: list[str] | None = None,
    sizes: list[tuple[float, float]] | None = None,
) -> Path:
    """One page per entry in ``texts``; ``labels`` sets a page label per page."""
    objs: list[bytes] = []

    def add(body: bytes) -> int:
        objs.append(body)
        return len(objs)

    catalog = add(b"")  # placeholder, filled below
    pages = add(b"")
    font = add(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
    kids = []
    for i, text in enumerate(texts):
        w, h = sizes[i] if sizes else size
        stream = f"BT /F1 24 Tf 20 {h / 2:.2f} Td ({_esc(text)}) Tj ET".encode()
        content = add(b"<< /Length %d >>\nstream\n%s\nendstream" % (len(stream), stream))
        kids.append(
            add(
                f"<< /Type /Page /Parent {pages} 0 R /MediaBox [0 0 {w} {h}] "
                f"/Resources << /Font << /F1 {font} 0 R >> >> /Contents {content} 0 R >>".encode()
            )
        )
    kid_refs = " ".join(f"{k} 0 R" for k in kids)
    objs[pages - 1] = f"<< /Type /Pages /Kids [{kid_refs}] /Count {len(kids)} >>".encode()
    cat = f"<< /Type /Catalog /Pages {pages} 0 R"
    if labels:
        nums = " ".join(f"{i} << /P ({_esc(lbl)}) >>" for i, lbl in enumerate(labels))
        cat += f" /PageLabels << /Nums [{nums}] >>"
    objs[catalog - 1] = (cat + " >>").encode()

    out = bytearray(b"%PDF-1.7\n%\xe2\xe3\xcf\xd3\n")
    offsets = []
    for n, body in enumerate(objs, start=1):
        offsets.append(len(out))
        out += b"%d 0 obj\n%s\nendobj\n" % (n, body)
    xref = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
    for off in offsets:
        out += b"%010d 00000 n \n" % off
    out += b"trailer\n<< /Size %d /Root %d 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (
        len(objs) + 1,
        catalog,
        xref,
    )
    path.write_bytes(bytes(out))
    return path
