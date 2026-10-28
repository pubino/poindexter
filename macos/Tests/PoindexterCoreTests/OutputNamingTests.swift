import Foundation
import Testing
@testable import PoindexterCore

@Test func outputNameSitsBesideThePDF() throws {
    let dir = try tempDir()
    let out = OutputNaming.uniquePPTX(for: dir.appendingPathComponent("talk.pdf"))
    #expect(out == dir.appendingPathComponent("talk.pptx"))
}

@Test func outputNameNeverOverwrites() throws {
    let dir = try tempDir()
    try Data("x".utf8).write(to: dir.appendingPathComponent("talk.pptx"))
    try Data("x".utf8).write(to: dir.appendingPathComponent("talk 2.pptx"))
    let out = OutputNaming.uniquePPTX(for: dir.appendingPathComponent("talk.pdf"))
    #expect(out.lastPathComponent == "talk 3.pptx")
}
