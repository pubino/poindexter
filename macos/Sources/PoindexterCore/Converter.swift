import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

public enum ConversionError: LocalizedError, Equatable {
    case notFound(String)
    case notPDF(String)
    case locked(String)
    case unreadable(String)
    case noPages(String)
    case invalidOption(String)
    case renderFailed(page: Int)
    case outputTooLarge

    public var errorDescription: String? {
        switch self {
        case .notFound(let p): "File not found: \(p)"
        case .notPDF(let p): "Not a PDF file: \(p)"
        case .locked(let p): "PDF is password-protected: \(p)"
        case .unreadable(let p): "Could not open PDF: \(p)"
        case .noPages(let p): "PDF has no pages: \(p)"
        case .invalidOption(let m): m
        case .renderFailed(let n): "Could not render page \(n)"
        case .outputTooLarge: "Presentation is too large (over 4 GB)"
        }
    }
}

public struct ConversionOptions: Sendable, Equatable {
    public static let dpiRange = 50...600

    public var dpi = 220
    public var format: SlideImage.Format = .png
    public var jpegQuality = 0.9
    public var notes = true
    public var collapseOverlays = false

    public init(
        dpi: Int = 220, format: SlideImage.Format = .png, jpegQuality: Double = 0.9,
        notes: Bool = true, collapseOverlays: Bool = false
    ) {
        self.dpi = dpi
        self.format = format
        self.jpegQuality = jpegQuality
        self.notes = notes
        self.collapseOverlays = collapseOverlays
    }

    func validate() throws {
        guard Self.dpiRange.contains(dpi) else {
            throw ConversionError.invalidOption("DPI must be between 50 and 600, got \(dpi)")
        }
        guard (0.01...1).contains(jpegQuality) else {
            throw ConversionError.invalidOption("JPEG quality must be between 0.01 and 1")
        }
    }
}

public struct ConversionResult: Sendable, Equatable {
    public var output: URL
    public var pdfPages: Int
    public var slides: Int
}

public enum Converter {
    static let emuPerInch = 914_400
    /// PowerPoint's default slide height; width follows the PDF's aspect ratio.
    static let slideHeightInches = 7.5
    /// PowerPoint rejects slide dimensions outside 1–56 inches.
    static let slideInchesRange = 1.0...56.0

    /// Converts `source` to a .pptx at `destination`, written atomically.
    /// `progress(done, total)` is called after each slide is rendered.
    @discardableResult
    public static func convert(
        _ source: URL, to destination: URL, options: ConversionOptions = .init(),
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) throws -> ConversionResult {
        try options.validate()
        let doc = try open(source)
        let indices = selectPages(doc, collapseOverlays: options.collapseOverlays)
        guard let first = doc.page(at: indices[0]) else { throw ConversionError.noPages(source.path) }
        let (wIn, hIn) = try slideSizeInches(displaySize(first))
        let slideW = Int((wIn * Double(emuPerInch)).rounded())
        let slideH = Int((hIn * Double(emuPerInch)).rounded())

        var slides: [SlideImage] = []
        for (n, index) in indices.enumerated() {
            try autoreleasepool {
                guard let page = doc.page(at: index) else { throw ConversionError.renderFailed(page: index + 1) }
                let size = displaySize(page)
                let frame = fit(size, in: (slideW, slideH))
                let data = try render(page, size: size, widthInches: Double(frame.width) / Double(emuPerInch),
                                      options: options, pageNumber: index + 1)
                let text = pageText(page)
                slides.append(SlideImage(
                    data: data, format: options.format, frame: frame,
                    altText: text.isEmpty ? "Slide \(n + 1)" : String(text.prefix(1000)),
                    notes: options.notes ? text : ""))
            }
            progress?(n + 1, indices.count)
        }

        let title = (doc.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String)
            .flatMap { $0.isEmpty ? nil : $0 } ?? source.deletingPathExtension().lastPathComponent
        let writer = PPTXWriter(slideWidth: slideW, slideHeight: slideH, title: title, slides: slides)
        let data = try writer.data()
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: destination, options: .atomic)
        return ConversionResult(output: destination, pdfPages: doc.pageCount, slides: slides.count)
    }

    static func open(_ url: URL) throws -> PDFDocument {
        guard FileManager.default.fileExists(atPath: url.path) else { throw ConversionError.notFound(url.path) }
        let handle = try FileHandle(forReadingFrom: url)
        let head = try handle.read(upToCount: 1024) ?? Data()
        try handle.close()
        // The spec allows junk before the header; 1 KiB is what most readers tolerate.
        guard head.range(of: Data("%PDF-".utf8)) != nil else { throw ConversionError.notPDF(url.path) }
        guard let doc = PDFDocument(url: url) else { throw ConversionError.unreadable(url.path) }
        if doc.isLocked { throw ConversionError.locked(url.path) }
        guard doc.pageCount > 0 else { throw ConversionError.noPages(url.path) }
        return doc
    }

    /// Beamer emits one page per overlay step and gives all steps of a frame the same
    /// page label; collapsing keeps only the last (fully built-up) step of each run.
    static func selectPages(_ doc: PDFDocument, collapseOverlays: Bool) -> [Int] {
        let all = Array(0..<doc.pageCount)
        guard collapseOverlays else { return all }
        let labels = all.map { doc.page(at: $0)?.label ?? "" }
        // PDFKit falls back to "1", "2", … when there are no labels, which never repeat.
        return all.filter { i in
            i == all.count - 1 || labels[i].isEmpty || labels[i] != labels[i + 1]
        }
    }

    static func displaySize(_ page: PDFPage) -> CGSize {
        let box = page.bounds(for: .cropBox).size
        return page.rotation % 180 == 0 ? box : CGSize(width: box.height, height: box.width)
    }

    static func slideSizeInches(_ page: CGSize) throws -> (Double, Double) {
        guard page.width > 0, page.height > 0 else { throw ConversionError.invalidOption("PDF page has zero size") }
        let aspect = page.width / page.height
        var height = slideHeightInches
        var width = height * aspect
        if width > slideInchesRange.upperBound {
            width = slideInchesRange.upperBound
            height = width / aspect
        } else if width < slideInchesRange.lowerBound {
            width = slideInchesRange.lowerBound
            height = width / aspect
        }
        height = min(max(height, slideInchesRange.lowerBound), slideInchesRange.upperBound)
        return (width, height)
    }

    /// Largest frame with the image's aspect ratio centred inside the box.
    static func fit(_ image: CGSize, in box: (Int, Int)) -> Frame {
        let scale = min(Double(box.0) / image.width, Double(box.1) / image.height)
        let w = Int((image.width * scale).rounded())
        let h = Int((image.height * scale).rounded())
        return Frame(x: (box.0 - w) / 2, y: (box.1 - h) / 2, width: w, height: h)
    }

    /// Renders with `dpi` pixels per inch of *slide*: beamer pages are only ~5 in wide,
    /// so rendering at page DPI would look blurry when projected.
    static func render(
        _ page: PDFPage, size: CGSize, widthInches: Double, options: ConversionOptions, pageNumber: Int
    ) throws -> Data {
        let pxW = max(1, Int((widthInches * Double(options.dpi)).rounded()))
        let pxH = max(1, Int((Double(pxW) * size.height / size.width).rounded()))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: pxW, height: pxH, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw ConversionError.renderFailed(page: pageNumber) }
        ctx.setFillColor(.white)
        ctx.fill(CGRect(x: 0, y: 0, width: pxW, height: pxH))
        ctx.interpolationQuality = .high
        ctx.scaleBy(x: CGFloat(pxW) / size.width, y: CGFloat(pxH) / size.height)
        page.draw(with: .cropBox, to: ctx)  // applies the page's /Rotate and box origin

        guard let image = ctx.makeImage() else { throw ConversionError.renderFailed(page: pageNumber) }
        let out = NSMutableData()
        let type = (options.format == .png ? UTType.png : UTType.jpeg).identifier as CFString
        guard let dest = CGImageDestinationCreateWithData(out, type, 1, nil) else {
            throw ConversionError.renderFailed(page: pageNumber)
        }
        var props: [CFString: Any] = [
            kCGImagePropertyDPIWidth: options.dpi, kCGImagePropertyDPIHeight: options.dpi
        ]
        if options.format == .jpeg { props[kCGImageDestinationLossyCompressionQuality] = options.jpegQuality }
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw ConversionError.renderFailed(page: pageNumber) }
        return out as Data
    }

    static func pageText(_ page: PDFPage) -> String {
        (page.string ?? "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
