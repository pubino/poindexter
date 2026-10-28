import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import PoindexterCore

/// Unpacks a .pptx with the system `unzip`, which also independently validates the archive.
struct Unpacked {
    let root: URL

    init(_ pptx: URL) throws {
        root = pptx.deletingPathExtension().appendingPathExtension("unzipped")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        p.arguments = ["-q", "-o", pptx.path, "-d", root.path]
        try p.run()
        p.waitUntilExit()
        #expect(p.terminationStatus == 0, "unzip failed")
    }

    func xml(_ path: String) throws -> XMLDocument {
        try XMLDocument(contentsOf: root.appendingPathComponent(path))
    }

    func values(_ path: String, _ xpath: String) throws -> [String] {
        try xml(path).nodes(forXPath: xpath).compactMap(\.stringValue)
    }

    func image(_ n: Int, ext: String = "png") throws -> CGImage {
        let url = root.appendingPathComponent("ppt/media/image\(n).\(ext)")
        let src = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try #require(CGImageSourceCreateImageAtIndex(src, 0, nil))
    }
}

func tempDir() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("poindexter-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func beamerPDF(in dir: URL) throws -> URL {
    try PDFFixture.make(dir.appendingPathComponent("talk.pdf"),
                        texts: ["Intro step one", "Intro step two", "Results E=mc2", "Thanks"],
                        labels: ["1", "1", "2", "3"])
}

let emu = Double(Converter.emuPerInch)

@Test func oneFullBleedSlidePerPage() throws {
    let dir = try tempDir()
    let out = dir.appendingPathComponent("talk.pptx")
    let result = try Converter.convert(try beamerPDF(in: dir), to: out)
    #expect(result.pdfPages == 4 && result.slides == 4)

    let pkg = try Unpacked(out)
    let pres = try pkg.xml("ppt/presentation.xml")
    #expect(try pres.nodes(forXPath: "//*[local-name()='sldId']").count == 4)
    let cx = try #require(Double(try pkg.values("ppt/presentation.xml", "//*[local-name()='sldSz']/@cx")[0]))
    let cy = try #require(Double(try pkg.values("ppt/presentation.xml", "//*[local-name()='sldSz']/@cy")[0]))
    #expect(abs(cx / emu - 10.0) < 0.01)  // beamer 4:3 -> 10 x 7.5 in
    #expect(abs(cy / emu - 7.5) < 0.01)
    for n in 1...4 {
        let ext = try pkg.values("ppt/slides/slide\(n).xml", "//*[local-name()='ext']/@cx")
        #expect(ext.contains(String(Int(cx))), "picture should span the slide width")
    }
}

@Test func widescreenDeck() throws {
    let dir = try tempDir()
    let pdf = try PDFFixture.make(dir.appendingPathComponent("w.pdf"), texts: ["a"], size: (1600, 900))
    let out = dir.appendingPathComponent("w.pptx")
    try Converter.convert(pdf, to: out)
    let cx = try #require(Double(try Unpacked(out).values("ppt/presentation.xml", "//*[local-name()='sldSz']/@cx")[0]))
    #expect(abs(cx / emu - 13.333) < 0.01)
}

@Test func resolutionFollowsDPIAndHasContent() throws {
    let dir = try tempDir()
    let out = dir.appendingPathComponent("t.pptx")
    try Converter.convert(try beamerPDF(in: dir), to: out, options: .init(dpi: 100))
    let image = try Unpacked(out).image(1)
    #expect(abs(image.width - 1000) <= 2)  // 10 in * 100 dpi
    #expect(hasDarkAndLightPixels(image))
}

@Test func jpegFormat() throws {
    let dir = try tempDir()
    let out = dir.appendingPathComponent("t.pptx")
    try Converter.convert(try beamerPDF(in: dir), to: out, options: .init(format: .jpeg))
    let pkg = try Unpacked(out)
    _ = try pkg.image(1, ext: "jpeg")
    let target = try pkg.values("ppt/slides/_rels/slide1.xml.rels", "//*[local-name()='Relationship']/@Target")
    #expect(target.contains("../media/image1.jpeg"))
}

@Test func notesAndAltText() throws {
    let dir = try tempDir()
    let out = dir.appendingPathComponent("t.pptx")
    try Converter.convert(try beamerPDF(in: dir), to: out)
    let pkg = try Unpacked(out)
    #expect(try pkg.values("ppt/notesSlides/notesSlide3.xml", "//*[local-name()='t']") == ["Results E=mc2"])
    #expect(try pkg.values("ppt/slides/slide3.xml", "//*[local-name()='cNvPr']/@descr") == ["Results E=mc2"])
}

@Test func noNotesOption() throws {
    let dir = try tempDir()
    let out = dir.appendingPathComponent("t.pptx")
    try Converter.convert(try beamerPDF(in: dir), to: out, options: .init(notes: false))
    #expect(try Unpacked(out).values("ppt/notesSlides/notesSlide1.xml", "//*[local-name()='t']").isEmpty)
}

@Test func collapseOverlaysKeepsLastStep() throws {
    let dir = try tempDir()
    let out = dir.appendingPathComponent("t.pptx")
    let result = try Converter.convert(try beamerPDF(in: dir), to: out, options: .init(collapseOverlays: true))
    #expect(result.pdfPages == 4 && result.slides == 3)
    let pkg = try Unpacked(out)
    let notes = try (1...3).map { try pkg.values("ppt/notesSlides/notesSlide\($0).xml", "//*[local-name()='t']") }
    #expect(notes == [["Intro step two"], ["Results E=mc2"], ["Thanks"]])
}

@Test func collapseWithoutLabelsKeepsEverything() throws {
    let dir = try tempDir()
    let pdf = try PDFFixture.make(dir.appendingPathComponent("p.pdf"), texts: ["a", "b", "c"])
    let result = try Converter.convert(pdf, to: dir.appendingPathComponent("t.pptx"),
                                       options: .init(collapseOverlays: true))
    #expect(result.slides == 3)
}

@Test func mixedPageSizesAreLetterboxed() throws {
    let dir = try tempDir()
    let pdf = try PDFFixture.make(dir.appendingPathComponent("m.pdf"), texts: ["wide", "tall"],
                                  sizes: [(400, 300), (300, 400)])
    let out = dir.appendingPathComponent("t.pptx")
    try Converter.convert(pdf, to: out)
    let pkg = try Unpacked(out)
    let x = try #require(Int(try pkg.values("ppt/slides/slide2.xml", "//*[local-name()='pic']//*[local-name()='off']/@x")[0]))
    #expect(x > 0, "portrait page should be centred with side margins")
}

@Test func rotatedPageRendersUpright() throws {
    let dir = try tempDir()
    let pdf = try PDFFixture.make(dir.appendingPathComponent("r.pdf"), texts: ["Rotated"],
                                  size: (300, 400), rotate: 90)
    let out = dir.appendingPathComponent("t.pptx")
    try Converter.convert(pdf, to: out, options: .init(dpi: 72))
    let image = try Unpacked(out).image(1)
    #expect(image.width > image.height, "/Rotate 90 on a portrait page should display landscape")
    #expect(hasDarkAndLightPixels(image), "rotated content should land on the canvas")
}

@Test func xmlSpecialCharactersAreEscaped() throws {
    let dir = try tempDir()
    let pdf = try PDFFixture.make(dir.appendingPathComponent("x.pdf"), texts: ["a < b & \"c\""])
    let out = dir.appendingPathComponent("t.pptx")
    try Converter.convert(pdf, to: out)
    #expect(try Unpacked(out).values("ppt/notesSlides/notesSlide1.xml", "//*[local-name()='t']") == ["a < b & \"c\""])
}

@Test func controlCharactersAreDropped() {
    #expect(XML.escape("a\u{0}b\u{1B}c\td") == "abc\td")
}

@Test(arguments: [
    ("hello, not a pdf", "Not a PDF"),
    ("%PDF-1.7\ngarbage that is not a real document", "Could not open PDF"),
])
func rejectsBadInput(content: String, message: String) throws {
    let dir = try tempDir()
    let bad = dir.appendingPathComponent("bad.pdf")
    try Data(content.utf8).write(to: bad)
    let out = dir.appendingPathComponent("out.pptx")
    let error = #expect(throws: ConversionError.self) { try Converter.convert(bad, to: out) }
    #expect(error?.localizedDescription.contains(message) == true)
    #expect(!FileManager.default.fileExists(atPath: out.path))
}

@Test func missingInput() throws {
    let dir = try tempDir()
    #expect(throws: ConversionError.notFound(dir.appendingPathComponent("nope.pdf").path)) {
        try Converter.convert(dir.appendingPathComponent("nope.pdf"), to: dir.appendingPathComponent("o.pptx"))
    }
}

@Test(arguments: [ConversionOptions(dpi: 10), ConversionOptions(dpi: 5000), ConversionOptions(jpegQuality: 0)])
func invalidOptions(options: ConversionOptions) throws {
    let dir = try tempDir()
    #expect(throws: ConversionError.self) {
        try Converter.convert(try beamerPDF(in: dir), to: dir.appendingPathComponent("o.pptx"), options: options)
    }
}

@Test func slideSizeClampedToPowerPointLimits() throws {
    let (w, h) = try Converter.slideSizeInches(CGSize(width: 10_000, height: 10))
    #expect(w == 56 && (1...56).contains(h))
}

@Test func fitCentres() {
    let f = Converter.fit(CGSize(width: 1, height: 1), in: (200, 100))
    #expect(f == Frame(x: 50, y: 0, width: 100, height: 100))
}

@Test func zipCRC32KnownValue() {
    #expect(CRC32.checksum(Data("123456789".utf8)) == 0xCBF4_3926)
}

@Test func progressReportsEverySlide() throws {
    final class Box: @unchecked Sendable { var calls: [(Int, Int)] = [] }
    let box = Box()
    let dir = try tempDir()
    try Converter.convert(try beamerPDF(in: dir), to: dir.appendingPathComponent("t.pptx"),
                          options: .init(dpi: 50)) { box.calls.append(($0, $1)) }
    #expect(box.calls.map(\.0) == [1, 2, 3, 4] && box.calls.allSatisfy { $0.1 == 4 })
}

func hasDarkAndLightPixels(_ image: CGImage) -> Bool {
    let w = image.width, h = image.height
    var pixels = [UInt8](repeating: 0, count: w * h)
    guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                              space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0) else { return false }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    return (pixels.max() ?? 0) > 200 && (pixels.min() ?? 255) < 80
}
