// Headless front end to PoindexterCore, used by scripts and for checking output in PowerPoint.
// Usage: poindexter-cli [--collapse-overlays] [--jpeg] [--dpi N] [--no-notes] input.pdf output.pptx
import Foundation
import PoindexterCore

var options = ConversionOptions()
var paths: [String] = []
var args = CommandLine.arguments.dropFirst()
while let arg = args.popFirst() {
    switch arg {
    case "--collapse-overlays": options.collapseOverlays = true
    case "--jpeg": options.format = .jpeg
    case "--no-notes": options.notes = false
    case "--dpi":
        guard let value = args.popFirst(), let dpi = Int(value) else {
            FileHandle.standardError.write(Data("--dpi needs an integer\n".utf8))
            exit(2)
        }
        options.dpi = dpi
    default: paths.append(arg)
    }
}
guard paths.count == 2 else {
    FileHandle.standardError.write(Data("usage: poindexter-cli [options] input.pdf output.pptx\n".utf8))
    exit(2)
}
do {
    let result = try Converter.convert(URL(fileURLWithPath: paths[0]), to: URL(fileURLWithPath: paths[1]),
                                       options: options)
    print("\(paths[0]) -> \(result.output.path) (\(result.slides) slides from \(result.pdfPages) pages)")
} catch {
    FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
    exit(1)
}
