"""Convert PDF presentations (e.g. LaTeX beamer) to PowerPoint, one image per slide."""

from pdf2pptx.convert import ConversionError, Options, Result, convert

__all__ = ["ConversionError", "Options", "Result", "convert"]
__version__ = "0.1.0"
