import Foundation
import Jobs
import Capabilities

/// Lossless, container-level metadata removal (no pixel re-encode) for JPEG, PNG, GIF and WebP.
/// Keeps what's needed to render identically: colour profile, transparency, animation, and EXIF orientation.
public enum MetadataStrip {
    public enum Format { case jpeg, png, gif, webp }

    public static func strip(_ data: Data, format: Format) throws -> Data {
        switch format {
        case .jpeg: return try jpeg(data)
        case .png: return try png(data)
        case .gif: return try gif(data)
        case .webp: return try webp(data)
        }
    }

    static func bad(_ what: String) -> JobFailure { JobFailure("This \(what) file looks damaged. The original is unchanged.") }

    // MARK: EXIF orientation

    /// Orientation (1…8) from a TIFF/EXIF blob, or nil.
    static func orientation(tiff b: [UInt8]) -> UInt16? {
        guard b.count >= 8 else { return nil }
        let le: Bool
        if b[0] == 0x49, b[1] == 0x49 { le = true } else if b[0] == 0x4D, b[1] == 0x4D { le = false } else { return nil }
        func u16(_ i: Int) -> UInt16? { guard i + 1 < b.count else { return nil }; return le ? UInt16(b[i]) | UInt16(b[i + 1]) << 8 : UInt16(b[i]) << 8 | UInt16(b[i + 1]) }
        func u32(_ i: Int) -> UInt32? { guard i + 3 < b.count else { return nil }
            let v = (UInt32(b[i]), UInt32(b[i + 1]), UInt32(b[i + 2]), UInt32(b[i + 3]))
            return le ? v.0 | v.1 << 8 | v.2 << 16 | v.3 << 24 : v.0 << 24 | v.1 << 16 | v.2 << 8 | v.3 }
        guard let ifd = u32(4).map(Int.init), let n = u16(ifd) else { return nil }
        for k in 0..<Int(n) {
            let e = ifd + 2 + k * 12
            if u16(e) == 0x0112, let v = u16(e + 8), (1...8).contains(v) { return v }
        }
        return nil
    }

    /// Minimal big-endian TIFF with one IFD entry: Orientation.
    static func minimalTIFF(orientation o: UInt16) -> [UInt8] {
        [0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08,
         0x00, 0x01,
         0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, UInt8(o >> 8), UInt8(o & 0xFF), 0x00, 0x00,
         0x00, 0x00, 0x00, 0x00]
    }

    // MARK: JPEG

    static func jpeg(_ data: Data) throws -> Data {
        let b = [UInt8](data)
        guard b.count > 4, b[0] == 0xFF, b[1] == 0xD8 else { throw bad("JPEG") }
        var out: [UInt8] = [0xFF, 0xD8]
        var i = 2
        var orient: UInt16?
        var kept: [(UInt8, ArraySlice<UInt8>)] = []
        while i + 4 <= b.count {
            guard b[i] == 0xFF else { throw bad("JPEG") }
            let marker = b[i + 1]
            if marker == 0xFF { i += 1; continue }
            if marker == 0xDA { // SOS: everything after is image data
                for (m, seg) in kept { out += [0xFF, m]; out += seg }
                if let o = orient, o != 1 {
                    let payload: [UInt8] = Array("Exif".utf8) + [0, 0] + minimalTIFF(orientation: o)
                    let len = payload.count + 2
                    let app1: [UInt8] = [0xFF, 0xE1, UInt8(len >> 8), UInt8(len & 0xFF)] + payload
                    // EXIF APP1 goes right after SOI (and after JFIF APP0 if present).
                    let insertAt = (out.count > 4 && out[2] == 0xFF && out[3] == 0xE0) ? 4 + (Int(out[4]) << 8 | Int(out[5])) : 2
                    out.insert(contentsOf: app1, at: insertAt)
                }
                // Keep the primary image only: secondary images appended after EOI (MPF gain maps,
                // depth maps) carry their own metadata. Entropy data byte-stuffs 0xFF, so the first
                // unstuffed FF D9 after SOS is the primary image's end.
                var k = i
                while k + 1 < b.count, !(b[k] == 0xFF && b[k + 1] == 0xD9) { k += 1 }
                out += b[i..<min(b.count, k + 2)]
                return Data(out)
            }
            let len = Int(b[i + 2]) << 8 | Int(b[i + 3])
            guard len >= 2, i + 2 + len <= b.count else { throw bad("JPEG") }
            let seg = b[(i + 2)..<(i + 2 + len)]
            let body = Array(b[(i + 4)..<(i + 2 + len)])
            switch marker {
            case 0xE1:
                if body.starts(with: Array("Exif".utf8) + [0, 0]) { orient = orientation(tiff: Array(body.dropFirst(6))) }
            case 0xE2:
                if body.starts(with: Array("ICC_PROFILE".utf8) + [0]) { kept.append((marker, seg)) }
            case 0xE0:
                if body.starts(with: Array("JFIF".utf8) + [0]) { kept.append((marker, seg)) }
            case 0xE3...0xEF, 0xFE:
                break // APP3–APP15, COM: metadata
            default:
                kept.append((marker, seg))
            }
            i += 2 + len
        }
        throw bad("JPEG")
    }

    // MARK: PNG

    static let pngKeep: Set<String> = ["IHDR", "PLTE", "IDAT", "IEND", "tRNS", "gAMA", "cHRM", "sRGB", "iCCP", "sBIT", "pHYs", "bKGD", "acTL", "fcTL", "fdAT", "cICP", "mDCv", "cLLi"]

    static func png(_ data: Data) throws -> Data {
        let b = [UInt8](data)
        let sig: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard b.count > 8, Array(b[0..<8]) == sig else { throw bad("PNG") }
        var out = sig
        var i = 8
        while i + 12 <= b.count {
            let len = Int(b[i]) << 24 | Int(b[i + 1]) << 16 | Int(b[i + 2]) << 8 | Int(b[i + 3])
            let type = String(decoding: b[(i + 4)..<(i + 8)], as: UTF8.self)
            let end = i + 12 + len
            guard len >= 0, end <= b.count else { throw bad("PNG") }
            if pngKeep.contains(type) { out += b[i..<end] }
            i = end
            if type == "IEND" { return Data(out) }
        }
        throw bad("PNG")
    }

    // MARK: GIF

    static func gif(_ data: Data) throws -> Data {
        let b = [UInt8](data)
        guard b.count > 13, b[0] == 0x47, b[1] == 0x49, b[2] == 0x46 else { throw bad("GIF") }
        var i = 13
        if b[10] & 0x80 != 0 { i += 3 * (1 << (Int(b[10] & 0x07) + 1)) }
        guard i <= b.count else { throw bad("GIF") }
        var out = Array(b[0..<i])
        func subBlocksEnd(_ start: Int) throws -> Int {
            var j = start
            while j < b.count {
                let n = Int(b[j]); j += 1
                if n == 0 { return j }
                j += n
            }
            throw bad("GIF")
        }
        while i < b.count {
            switch b[i] {
            case 0x3B:
                out.append(0x3B)
                return Data(out)
            case 0x21:
                guard i + 2 < b.count else { throw bad("GIF") }
                let label = b[i + 1]
                let end = try subBlocksEnd(i + 2)
                var keep = label == 0xF9 || label == 0x01
                if label == 0xFF, i + 13 < b.count, b[i + 2] == 11 {
                    let app = String(decoding: b[(i + 3)..<(i + 14)], as: UTF8.self)
                    keep = app == "NETSCAPE2.0" || app == "ANIMEXTS1.0"
                }
                if keep { out += b[i..<end] }
                i = end
            case 0x2C:
                guard i + 10 <= b.count else { throw bad("GIF") }
                var j = i + 10
                if b[i + 9] & 0x80 != 0 { j += 3 * (1 << (Int(b[i + 9] & 0x07) + 1)) }
                j += 1 // LZW minimum code size
                let end = try subBlocksEnd(j)
                out += b[i..<end]
                i = end
            default:
                throw bad("GIF")
            }
        }
        out.append(0x3B)
        return Data(out)
    }

    // MARK: WebP

    static func webp(_ data: Data) throws -> Data {
        let b = [UInt8](data)
        guard b.count > 12, String(decoding: b[0..<4], as: UTF8.self) == "RIFF", String(decoding: b[8..<12], as: UTF8.self) == "WEBP" else { throw bad("WebP") }
        var chunks: [(String, [UInt8])] = []
        var i = 12
        var orient: UInt16?
        while i + 8 <= b.count {
            let fourcc = String(decoding: b[i..<(i + 4)], as: UTF8.self)
            let size = Int(b[i + 4]) | Int(b[i + 5]) << 8 | Int(b[i + 6]) << 16 | Int(b[i + 7]) << 24
            let end = i + 8 + size
            guard end <= b.count else { throw bad("WebP") }
            let payload = Array(b[(i + 8)..<end])
            if fourcc == "EXIF" {
                let tiff = payload.starts(with: Array("Exif".utf8) + [0, 0]) ? Array(payload.dropFirst(6)) : payload
                orient = orientation(tiff: tiff)
            } else if fourcc != "XMP " {
                chunks.append((fourcc, payload))
            }
            i = end + (size & 1)
        }
        let keepOrientation = (orient ?? 1) != 1
        if keepOrientation { chunks.append(("EXIF", minimalTIFF(orientation: orient!))) }
        if let vi = chunks.firstIndex(where: { $0.0 == "VP8X" }), !chunks[vi].1.isEmpty {
            chunks[vi].1[0] &= ~UInt8(0x04)          // XMP flag off
            if !keepOrientation { chunks[vi].1[0] &= ~UInt8(0x08) } // EXIF flag off
        }
        var body: [UInt8] = Array("WEBP".utf8)
        for (cc, p) in chunks {
            let n = p.count
            body += Array(cc.utf8) + [UInt8(n & 0xFF), UInt8(n >> 8 & 0xFF), UInt8(n >> 16 & 0xFF), UInt8(n >> 24 & 0xFF)] + p
            if n & 1 == 1 { body.append(0) }
        }
        let total = body.count
        return Data(Array("RIFF".utf8) + [UInt8(total & 0xFF), UInt8(total >> 8 & 0xFF), UInt8(total >> 16 & 0xFF), UInt8(total >> 24 & 0xFF)] + body)
    }
}
