import Foundation

/// Placement in EMUs (914 400 per inch).
public struct Frame: Sendable, Equatable {
    public var x: Int, y: Int, width: Int, height: Int
}

/// One slide: an image that fills (or is centred in) the slide, plus optional notes.
public struct SlideImage: Sendable {
    public enum Format: String, Sendable { case png, jpeg }

    public var data: Data
    public var format: Format
    public var frame: Frame
    public var altText: String
    public var notes: String
}

/// Writes a minimal but complete PresentationML package: one blank master/layout,
/// a notes master, and one picture per slide.
struct PPTXWriter {
    var slideWidth: Int
    var slideHeight: Int
    var title: String
    var slides: [SlideImage]

    func data() throws -> Data {
        var zip = ZipWriter()
        try zip.add("[Content_Types].xml", xml(contentTypes))
        try zip.add("_rels/.rels", xml(Parts.rootRels))
        try zip.add("docProps/core.xml", xml(coreProps))
        try zip.add("docProps/app.xml", xml(appProps))
        try zip.add("ppt/presentation.xml", xml(presentation))
        try zip.add("ppt/_rels/presentation.xml.rels", xml(presentationRels))
        try zip.add("ppt/presProps.xml", xml(Parts.presProps))
        try zip.add("ppt/viewProps.xml", xml(Parts.viewProps))
        try zip.add("ppt/tableStyles.xml", xml(Parts.tableStyles))
        try zip.add("ppt/theme/theme1.xml", xml(Parts.theme))
        try zip.add("ppt/theme/theme2.xml", xml(Parts.theme))
        try zip.add("ppt/slideMasters/slideMaster1.xml", xml(Parts.slideMaster))
        try zip.add("ppt/slideMasters/_rels/slideMaster1.xml.rels", xml(Parts.slideMasterRels))
        try zip.add("ppt/slideLayouts/slideLayout1.xml", xml(Parts.slideLayout))
        try zip.add("ppt/slideLayouts/_rels/slideLayout1.xml.rels", xml(Parts.slideLayoutRels))
        try zip.add("ppt/notesMasters/notesMaster1.xml", xml(Parts.notesMaster))
        try zip.add("ppt/notesMasters/_rels/notesMaster1.xml.rels", xml(Parts.notesMasterRels))

        for (i, slide) in slides.enumerated() {
            let n = i + 1
            let media = "image\(n).\(slide.format.rawValue)"
            try zip.add("ppt/media/\(media)", slide.data)
            try zip.add("ppt/slides/slide\(n).xml", xml(slideXML(n, slide)))
            try zip.add("ppt/slides/_rels/slide\(n).xml.rels", xml(slideRels(n, media: media)))
            try zip.add("ppt/notesSlides/notesSlide\(n).xml", xml(notesXML(slide.notes)))
            try zip.add("ppt/notesSlides/_rels/notesSlide\(n).xml.rels", xml(notesRels(n)))
        }
        return try zip.finish()
    }

    private func xml(_ body: String) -> Data {
        Data(("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n" + body).utf8)
    }

    // MARK: - Package-level parts

    private var contentTypes: String {
        let ct = "application/vnd.openxmlformats-officedocument.presentationml"
        var overrides = [
            ("/ppt/presentation.xml", "\(ct).presentation.main+xml"),
            ("/ppt/presProps.xml", "\(ct).presProps+xml"),
            ("/ppt/viewProps.xml", "\(ct).viewProps+xml"),
            ("/ppt/tableStyles.xml", "\(ct).tableStyles+xml"),
            ("/ppt/theme/theme1.xml", "application/vnd.openxmlformats-officedocument.theme+xml"),
            ("/ppt/theme/theme2.xml", "application/vnd.openxmlformats-officedocument.theme+xml"),
            ("/ppt/slideMasters/slideMaster1.xml", "\(ct).slideMaster+xml"),
            ("/ppt/slideLayouts/slideLayout1.xml", "\(ct).slideLayout+xml"),
            ("/ppt/notesMasters/notesMaster1.xml", "\(ct).notesMaster+xml"),
            ("/docProps/core.xml", "application/vnd.openxmlformats-package.core-properties+xml"),
            ("/docProps/app.xml", "application/vnd.openxmlformats-officedocument.extended-properties+xml"),
        ]
        for n in slides.indices.map({ $0 + 1 }) {
            overrides.append(("/ppt/slides/slide\(n).xml", "\(ct).slide+xml"))
            overrides.append(("/ppt/notesSlides/notesSlide\(n).xml", "\(ct).notesSlide+xml"))
        }
        let items = overrides.map { "<Override PartName=\"\($0.0)\" ContentType=\"\($0.1)\"/>" }
        return """
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
            <Default Extension="xml" ContentType="application/xml"/>\
            <Default Extension="png" ContentType="image/png"/>\
            <Default Extension="jpeg" ContentType="image/jpeg"/>\
            \(items.joined())</Types>
            """
    }

    private var coreProps: String {
        let now = ISO8601DateFormatter().string(from: Date())
        return """
            <cp:coreProperties \
            xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" \
            xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" \
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">\
            <dc:title>\(XML.escape(title))</dc:title>\
            <dcterms:created xsi:type="dcterms:W3CDTF">\(now)</dcterms:created>\
            <dcterms:modified xsi:type="dcterms:W3CDTF">\(now)</dcterms:modified>\
            </cp:coreProperties>
            """
    }

    private var appProps: String {
        """
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">\
        <Application>Poindexter</Application><Slides>\(slides.count)</Slides></Properties>
        """
    }

    private var presentation: String {
        let ids = slides.indices.map { "<p:sldId id=\"\(256 + $0)\" r:id=\"rId\(100 + $0)\"/>" }
        return """
            <p:presentation \(XML.ns) saveSubsetFonts="1">\
            <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>\
            <p:notesMasterIdLst><p:notesMasterId r:id="rId2"/></p:notesMasterIdLst>\
            <p:sldIdLst>\(ids.joined())</p:sldIdLst>\
            <p:sldSz cx="\(slideWidth)" cy="\(slideHeight)"/>\
            <p:notesSz cx="6858000" cy="9144000"/>\
            </p:presentation>
            """
    }

    private var presentationRels: String {
        var rels = [
            ["rId1", "slideMaster", "slideMasters/slideMaster1.xml"],
            ["rId2", "notesMaster", "notesMasters/notesMaster1.xml"],
            ["rId3", "theme", "theme/theme1.xml"],
            ["rId4", "presProps", "presProps.xml"],
            ["rId5", "viewProps", "viewProps.xml"],
            ["rId6", "tableStyles", "tableStyles.xml"],
        ]
        for i in slides.indices {
            rels.append(["rId\(100 + i)", "slide", "slides/slide\(i + 1).xml"])
        }
        return XML.relationships(rels)
    }

    // MARK: - Per-slide parts

    private func slideXML(_ n: Int, _ slide: SlideImage) -> String {
        let f = slide.frame
        return """
            <p:sld \(XML.ns)><p:cSld><p:spTree>\(XML.groupHeader)\
            <p:pic><p:nvPicPr><p:cNvPr id="2" name="Slide \(n)" descr="\(XML.escape(slide.altText))"/>\
            <p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>\
            <p:blipFill><a:blip r:embed="rId2"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>\
            <p:spPr><a:xfrm><a:off x="\(f.x)" y="\(f.y)"/><a:ext cx="\(f.width)" cy="\(f.height)"/></a:xfrm>\
            <a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>\
            </p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>
            """
    }

    private func slideRels(_ n: Int, media: String) -> String {
        XML.relationships([
            ["rId1", "slideLayout", "../slideLayouts/slideLayout1.xml"],
            ["rId2", "image", "../media/\(media)"],
            ["rId3", "notesSlide", "../notesSlides/notesSlide\(n).xml"],
        ])
    }

    private func notesXML(_ text: String) -> String {
        let paragraphs = text.isEmpty
            ? "<a:p><a:endParaRPr lang=\"en-US\"/></a:p>"
            : text.split(separator: "\n", omittingEmptySubsequences: false)
                .map { "<a:p><a:r><a:rPr lang=\"en-US\" dirty=\"0\"/><a:t>\(XML.escape(String($0)))</a:t></a:r></a:p>" }
                .joined()
        return """
            <p:notes \(XML.ns)><p:cSld><p:spTree>\(XML.groupHeader)\
            <p:sp><p:nvSpPr><p:cNvPr id="2" name="Slide Image Placeholder 1"/>\
            <p:cNvSpPr><a:spLocks noGrp="1" noRot="1" noChangeAspect="1"/></p:cNvSpPr>\
            <p:nvPr><p:ph type="sldImg"/></p:nvPr></p:nvSpPr><p:spPr/></p:sp>\
            <p:sp><p:nvSpPr><p:cNvPr id="3" name="Notes Placeholder 2"/>\
            <p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>\
            <p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr><p:spPr/>\
            <p:txBody><a:bodyPr/><a:lstStyle/>\(paragraphs)</p:txBody></p:sp>\
            </p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:notes>
            """
    }

    private func notesRels(_ n: Int) -> String {
        XML.relationships([
            ["rId1", "notesMaster", "../notesMasters/notesMaster1.xml"],
            ["rId2", "slide", "../slides/slide\(n).xml"],
        ])
    }
}

enum XML {
    static let ns = """
        xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" \
        xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
        """

    static let groupHeader = """
        <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\
        <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>\
        <a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
        """

    /// `rels` are (id, type, target) triples.
    static func relationships(_ rels: [[String]]) -> String {
        let base = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        let items = rels.map { "<Relationship Id=\"\($0[0])\" Type=\"\(base)/\($0[1])\" Target=\"\($0[2])\"/>" }
        return "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
            + items.joined() + "</Relationships>"
    }

    /// Escapes markup and drops characters XML 1.0 forbids (PDF text often contains them).
    static func escape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.utf8.count)
        for scalar in s.unicodeScalars {
            switch scalar {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&apos;"
            case "\t", "\n", "\r": out.unicodeScalars.append(scalar)
            default:
                let v = scalar.value
                let allowed = (0x20...0xD7FF).contains(v) || (0xE000...0xFFFD).contains(v)
                    || (0x10000...0x10FFFF).contains(v)
                if allowed { out.unicodeScalars.append(scalar) }
            }
        }
        return out
    }
}
