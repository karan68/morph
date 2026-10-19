import Foundation

/// Carries metadata from a source file into a re-encoded file of the same format, for “Keep camera & date info”
/// when the encoder can't (palette PNG via FFmpeg, WebP via libwebp). Container-level only; pixels untouched.
public enum MetadataCarry {
    // MARK: PNG

    /// Chunk types copied from the source. Colour chunks keep the picture looking the same; the rest is metadata.
    static let pngColour: Set<String> = ["iCCP", "sRGB", "gAMA", "cHRM"]
    static let pngMeta: Set<String> = ["eXIf", "iTXt", "tEXt", "zTXt", "tIME", "pHYs"]

    static func pngChunks(_ d: [UInt8]) -> [(String, ArraySlice<UInt8>)]? {
        guard d.count > 8, d[0] == 0x89, d[1] == 0x50 else { return nil }
        var out: [(String, ArraySlice<UInt8>)] = []
        var i = 8
        while i + 12 <= d.count {
            let n = Int(d[i]) << 24 | Int(d[i + 1]) << 16 | Int(d[i + 2]) << 8 | Int(d[i + 3])
            let end = i + 12 + n
            guard n >= 0, end <= d.count else { return nil }
            out.append((String(decoding: d[(i + 4)..<(i + 8)], as: UTF8.self), d[i..<end]))
            i = end
        }
        return out
    }

    /// Bytes of metadata the source would add (used to leave room when aiming for a target size).
    public static func pngMetadataBytes(_ source: Data) -> Int {
        (pngChunks([UInt8](source)) ?? []).filter { pngMeta.contains($0.0) || pngColour.contains($0.0) }.map(\.1.count).reduce(0, +)
    }

    public static func png(from source: Data, into target: Data) -> Data {
        guard let s = pngChunks([UInt8](source)), let t = pngChunks([UInt8](target)), t.first?.0 == "IHDR" else { return target }
        let carried = s.filter { pngColour.contains($0.0) || pngMeta.contains($0.0) }
        guard !carried.isEmpty else { return target }
        let carriedTypes = Set(carried.map(\.0))
        var out: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        out += t[0].1                                                     // IHDR
        for c in carried where pngColour.contains(c.0) { out += c.1 }     // must precede PLTE/IDAT
        for c in carried where pngMeta.contains(c.0) { out += c.1 }
        let colourReplaced = !carriedTypes.isDisjoint(with: pngColour)
        for c in t.dropFirst() where !carriedTypes.contains(c.0) && !(colourReplaced && pngColour.contains(c.0)) { out += c.1 }
        return Data(out)
    }

    // MARK: WebP

    static func riffChunks(_ d: [UInt8]) -> [(String, [UInt8])]? {
        guard d.count > 12, d[0...3] == [0x52, 0x49, 0x46, 0x46], d[8...11] == [0x57, 0x45, 0x42, 0x50] else { return nil }
        var out: [(String, [UInt8])] = []
        var i = 12
        while i + 8 <= d.count {
            let n = Int(d[i + 4]) | Int(d[i + 5]) << 8 | Int(d[i + 6]) << 16 | Int(d[i + 7]) << 24
            guard i + 8 + n <= d.count else { return nil }
            out.append((String(decoding: d[i..<(i + 4)], as: UTF8.self), Array(d[(i + 8)..<(i + 8 + n)])))
            i += 8 + n + (n & 1)
        }
        return out
    }

    public static func webpMetadataBytes(_ source: Data) -> Int {
        (riffChunks([UInt8](source)) ?? []).filter { ["EXIF", "XMP ", "ICCP"].contains($0.0) }.map { $0.1.count + 8 }.reduce(0, +) + 18
    }

    /// Canvas size and alpha flag from a simple-format WebP (VP8 / VP8L), for building a VP8X header.
    static func canvas(_ chunks: [(String, [UInt8])]) -> (w: Int, h: Int, alpha: Bool)? {
        if let p = chunks.first(where: { $0.0 == "VP8 " })?.1, p.count >= 10 {
            return (Int(p[6]) | (Int(p[7]) & 0x3F) << 8, Int(p[8]) | (Int(p[9]) & 0x3F) << 8, chunks.contains { $0.0 == "ALPH" })
        }
        if let p = chunks.first(where: { $0.0 == "VP8L" })?.1, p.count >= 5 {
            let w = 1 + (Int(p[1]) | (Int(p[2]) & 0x3F) << 8)
            let h = 1 + (Int(p[2]) >> 6 | Int(p[3]) << 2 | (Int(p[4]) & 0x0F) << 10)
            return (w, h, (p[4] >> 4) & 1 == 1)
        }
        return nil
    }

    public static func webp(from source: Data, into target: Data) -> Data {
        guard let s = riffChunks([UInt8](source)), var t = riffChunks([UInt8](target)) else { return target }
        let iccp = s.first { $0.0 == "ICCP" }, exif = s.first { $0.0 == "EXIF" }, xmp = s.first { $0.0 == "XMP " }
        guard iccp != nil || exif != nil || xmp != nil else { return target }
        t.removeAll { ["ICCP", "EXIF", "XMP "].contains($0.0) }
        if t.first?.0 != "VP8X" {
            guard let c = canvas(t) else { return target }
            var x = [UInt8](repeating: 0, count: 10)
            if c.alpha { x[0] |= 0x10 }
            x[4] = UInt8((c.w - 1) & 0xFF); x[5] = UInt8((c.w - 1) >> 8 & 0xFF); x[6] = UInt8((c.w - 1) >> 16 & 0xFF)
            x[7] = UInt8((c.h - 1) & 0xFF); x[8] = UInt8((c.h - 1) >> 8 & 0xFF); x[9] = UInt8((c.h - 1) >> 16 & 0xFF)
            t.insert(("VP8X", x), at: 0)
        }
        if iccp != nil { t[0].1[0] |= 0x20 }
        if exif != nil { t[0].1[0] |= 0x08 }
        if xmp != nil { t[0].1[0] |= 0x04 }
        var ordered: [(String, [UInt8])] = [t[0]]
        if let c = iccp { ordered.append(c) }
        ordered += t.dropFirst()
        if let c = exif { ordered.append(c) }
        if let c = xmp { ordered.append(c) }
        var body: [UInt8] = Array("WEBP".utf8)
        for (cc, p) in ordered {
            let n = p.count
            body += Array(cc.utf8) + [UInt8(n & 0xFF), UInt8(n >> 8 & 0xFF), UInt8(n >> 16 & 0xFF), UInt8(n >> 24 & 0xFF)] + p
            if n & 1 == 1 { body.append(0) }
        }
        let total = body.count
        return Data(Array("RIFF".utf8) + [UInt8(total & 0xFF), UInt8(total >> 8 & 0xFF), UInt8(total >> 16 & 0xFF), UInt8(total >> 24 & 0xFF)] + body)
    }
}
