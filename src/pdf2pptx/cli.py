"""Command-line entry point: ``pdf2pptx talk.pdf [more.pdf ...]``."""

from __future__ import annotations

import argparse
import os
import sys
from collections.abc import Sequence
from pathlib import Path

from pdf2pptx import __version__
from pdf2pptx.convert import MAX_DPI, MIN_DPI, ConversionError, ImageFormat, Options, convert


def _env_int(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if raw is None or raw == "":
        return default
    try:
        return int(raw)
    except ValueError:
        raise SystemExit(f"pdf2pptx: error: {name} must be an integer, got {raw!r}") from None


def _env_format(name: str, default: ImageFormat) -> ImageFormat:
    raw = os.environ.get(name, "") or default
    if raw not in ("png", "jpeg"):
        raise SystemExit(f"pdf2pptx: error: {name} must be png or jpeg, got {raw!r}")
    return raw  # type: ignore[return-value]


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="pdf2pptx",
        description="Convert PDF presentations to PowerPoint (each page becomes a slide image).",
    )
    p.add_argument("inputs", nargs="+", type=Path, metavar="PDF")
    p.add_argument(
        "-o",
        "--output",
        type=Path,
        help="output .pptx (single input) or directory (default: next to each PDF)",
    )
    p.add_argument(
        "--dpi",
        type=int,
        default=_env_int("PDF2PPTX_DPI", 220),
        help=f"pixels per inch of slide, {MIN_DPI}-{MAX_DPI} (default: %(default)s)",
    )
    p.add_argument(
        "--format",
        dest="image_format",
        choices=["png", "jpeg"],
        default=_env_format("PDF2PPTX_FORMAT", "png"),
        help="slide image format; jpeg gives smaller files for photo-heavy decks",
    )
    p.add_argument(
        "--collapse-overlays",
        action="store_true",
        help="beamer: keep only the final overlay step of each frame",
    )
    p.add_argument("--no-notes", action="store_true", help="don't copy page text into notes")
    p.add_argument("-f", "--force", action="store_true", help="overwrite existing outputs")
    p.add_argument("-q", "--quiet", action="store_true")
    p.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    return p


def resolve_output(src: Path, output: Path | None, many: bool) -> Path:
    if output is None:
        return src.with_suffix(".pptx")
    if many or output.is_dir():
        return output / f"{src.stem}.pptx"
    if output.suffix.lower() != ".pptx":
        raise ConversionError(f"output file must end in .pptx: {output}")
    return output


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    opts = Options(
        dpi=args.dpi,
        image_format=args.image_format,
        notes=not args.no_notes,
        collapse_overlays=args.collapse_overlays,
    )
    many = len(args.inputs) > 1
    if many and args.output is not None and args.output.suffix.lower() == ".pptx":
        print("pdf2pptx: error: with several inputs, -o must be a directory", file=sys.stderr)
        return 2

    failures = 0
    for src in args.inputs:
        try:
            opts.validate()
            dst = resolve_output(src, args.output, many)
            if dst.exists() and not args.force:
                raise ConversionError(f"{dst} already exists (use --force to overwrite)")
            result = convert(src, dst, opts)
        except ConversionError as exc:
            failures += 1
            print(f"pdf2pptx: error: {exc}", file=sys.stderr)
            continue
        if not args.quiet:
            print(
                f"{src} -> {result.output} ({result.slides} slides from {result.pdf_pages} pages)"
            )
    return 1 if failures else 0
