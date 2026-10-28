from __future__ import annotations

from pathlib import Path

import pytest

from tests.pdfgen import make_pdf


@pytest.fixture
def beamer_pdf(tmp_path: Path) -> Path:
    """4 pages; pages 1-2 are two overlay steps of the same frame (label "1")."""
    return make_pdf(
        tmp_path / "talk.pdf",
        ["Intro step one", "Intro step two", "Results E=mc2", "Thanks"],
        labels=["1", "1", "2", "3"],
    )
