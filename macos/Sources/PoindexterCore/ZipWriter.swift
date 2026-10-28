import Foundation

/// Minimal ZIP writer (stored entries, no compression) — all an OOXML package needs.
/// Slide images are already compressed PNG/JPEG, so deflating them would gain nothing.
struct ZipWriter {
    private var data = Data()
    private var central = Data()
    private var count: UInt16 = 0

    mutating func add(_ path: String, _ contents: Data) throws {
        let name = Data(path.utf8)
        guard contents.count < Int(UInt32.max), count < UInt16.max else {
            throw ConversionError.outputTooLarge
        }
        let crc = CRC32.checksum(contents)
        let offset = UInt32(data.count)
        let size = UInt32(contents.count)

        // Local file header
        data.appendLE(UInt32(0x0403_4B50))
        data.appendLE(UInt16(20))  // version needed
        data.appendLE(UInt16(0x0800))  // flags: UTF-8 names
        data.appendLE(UInt16(0))  // method: stored
        data.appendLE(UInt16(0))  // mod time
        data.appendLE(UInt16(0x21))  // mod date: 1980-01-01
        data.appendLE(crc)
        data.appendLE(size)
        data.appendLE(size)
        data.appendLE(UInt16(name.count))
        data.appendLE(UInt16(0))
        data.append(name)
        data.append(contents)

        // Central directory record
        central.appendLE(UInt32(0x0201_4B50))
        central.appendLE(UInt16(20))  // version made by
        central.appendLE(UInt16(20))
        central.appendLE(UInt16(0x0800))
        central.appendLE(UInt16(0))
        central.appendLE(UInt16(0))
        central.appendLE(UInt16(0x21))
        central.appendLE(crc)
        central.appendLE(size)
        central.appendLE(size)
        central.appendLE(UInt16(name.count))
        central.appendLE(UInt16(0))  // extra
        central.appendLE(UInt16(0))  // comment
        central.appendLE(UInt16(0))  // disk
        central.appendLE(UInt16(0))  // internal attrs
        central.appendLE(UInt32(0))  // external attrs
        central.appendLE(offset)
        central.append(name)
        count += 1
    }

    func finish() throws -> Data {
        guard data.count + central.count < Int(UInt32.max) else { throw ConversionError.outputTooLarge }
        var out = data
        let centralOffset = UInt32(out.count)
        out.append(central)
        out.appendLE(UInt32(0x0605_4B50))
        out.appendLE(UInt16(0))
        out.appendLE(UInt16(0))
        out.appendLE(count)
        out.appendLE(count)
        out.appendLE(UInt32(central.count))
        out.appendLE(centralOffset)
        out.appendLE(UInt16(0))
        return out
    }
}

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { n in
        var c = UInt32(n)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) in
            for byte in buf { crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
        }
        return crc ^ 0xFFFF_FFFF
    }
}

extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
