import Foundation

public enum OutputNaming {
    /// `talk.pdf` -> `talk.pptx` beside it, or `talk 2.pptx`, `talk 3.pptx`, … so an
    /// existing presentation is never overwritten.
    public static func uniquePPTX(for pdf: URL, fileManager: FileManager = .default) -> URL {
        let dir = pdf.deletingLastPathComponent()
        let stem = pdf.deletingPathExtension().lastPathComponent
        var candidate = dir.appendingPathComponent("\(stem).pptx")
        var n = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent("\(stem) \(n).pptx")
            n += 1
        }
        return candidate
    }
}
