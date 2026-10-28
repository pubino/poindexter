import Foundation

/// Writes tiny, valid PDFs (same generator as tests/pdfgen.py) — supports page labels and
/// /Rotate, which Core Graphics' PDF context can't produce.
enum PDFFixture {
    static func make(
        _ url: URL, texts: [String], size: (Double, Double) = (362.83, 272.13),
        sizes: [(Double, Double)]? = nil, labels: [String]? = nil, rotate: Int = 0
    ) throws -> URL {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "(", with: "\\(")
                .replacingOccurrences(of: ")", with: "\\)")
        }
        var objs: [String] = ["", "", "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"]
        var kids: [Int] = []
        for (i, text) in texts.enumerated() {
            let (w, h) = sizes?[i] ?? size
            let stream = "BT /F1 24 Tf 20 \(h / 2) Td (\(esc(text))) Tj ET"
            objs.append("<< /Length \(stream.utf8.count) >>\nstream\n\(stream)\nendstream")
            let content = objs.count
            objs.append("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 \(w) \(h)] /Rotate \(rotate) "
                + "/Resources << /Font << /F1 3 0 R >> >> /Contents \(content) 0 R >>")
            kids.append(objs.count)
        }
        objs[1] = "<< /Type /Pages /Kids [\(kids.map { "\($0) 0 R" }.joined(separator: " "))] /Count \(kids.count) >>"
        var catalog = "<< /Type /Catalog /Pages 2 0 R"
        if let labels {
            let nums = labels.enumerated().map { "\($0.offset) << /P (\(esc($0.element))) >>" }
            catalog += " /PageLabels << /Nums [\(nums.joined(separator: " "))] >>"
        }
        objs[0] = catalog + " >>"

        var out = Data("%PDF-1.7\n".utf8)
        var offsets: [Int] = []
        for (n, body) in objs.enumerated() {
            offsets.append(out.count)
            out.append(Data("\(n + 1) 0 obj\n\(body)\nendobj\n".utf8))
        }
        let xref = out.count
        var tail = "xref\n0 \(objs.count + 1)\n0000000000 65535 f \n"
        for off in offsets { tail += String(format: "%010d 00000 n \n", off) }
        tail += "trailer\n<< /Size \(objs.count + 1) /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF\n"
        out.append(Data(tail.utf8))
        try out.write(to: url)
        return url
    }
}
