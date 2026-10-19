#if canImport(ImageIO) && canImport(AppKit)
import AppKit
import ImageIO
import UniformTypeIdentifiers
import Jobs
import Capabilities

/// Image conversions and tools (spec §7.2 engine routing):
/// ImageIO encodes JPG/PNG/HEIC/TIFF/BMP/AVIF/PDF, libwebp (via bundled FFmpeg) encodes WebP, WebKit reads SVG.
public enum ImageEngine {
    static let utType: [String: String] = [
        "jpg": "public.jpeg", "png": "public.png", "heic": "public.heic", "tiff": "public.tiff",
        "bmp": "com.microsoft.bmp", "avif": "public.avif", "pdf": "com.adobe.pdf",
    ]

    /// Output formats this macOS can write (AVIF/HEIC availability varies by OS and hardware, spec R5).
    public static let writableTargets: Set<String> = {
        let ids = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])
        var set: Set<String> = ["webp", "pdf"] // WebP via libwebp; PDF via Core Graphics
        for (fmt, uti) in utType where ids.contains(uti) { set.insert(fmt) }
        return set
    }()

    public static var unavailableTargets: Set<String> {
        Set(["jpg", "png", "heic", "tiff", "bmp", "avif", "webp", "pdf"]).subtracting(writableTargets)
    }

    // MARK: Decode

    struct Decoded {
        let image: CGImage            // pixels with EXIF orientation applied
        let source: CGImageSource?    // nil for SVG
        let properties: [CFString: Any]
    }

    @MainActor static func decodeSVG(_ url: URL) async throws -> Decoded {
        Decoded(image: try await SVGRasterizer.rasterize(url), source: nil, properties: [:])
    }

    static func decode(_ url: URL) async throws -> Decoded {
        if Formats.isSVG(url) { return try await decodeSVG(url) }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(src) > 0 else {
            throw JobFailure("Morph couldn't read “\(url.lastPathComponent)”. The image may be damaged.")
        }
        let props = (CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]) ?? [:]
        let w = props[kCGImagePropertyPixelWidth] as? Int ?? 0, h = props[kCGImagePropertyPixelHeight] as? Int ?? 0
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(w, h, 1),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let img = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else {
            throw JobFailure("Morph couldn't decode “\(url.lastPathComponent)”.")
        }
        return Decoded(image: img, source: src, properties: props)
    }

    public static func pixelSize(_ url: URL) async throws -> CGSize {
        let d = try await decode(url)
        return CGSize(width: d.image.width, height: d.image.height)
    }

    // MARK: Encode

    /// Encodes `image` as `format` to `out`. `properties` are written as metadata (orientation is reset to 1
    /// because pixels are already oriented).
    static func encode(_ image: CGImage, format: String, to out: URL, quality: Double = 0.9,
                       properties: [CFString: Any] = [:], context: JobContext?) async throws {
        switch format {
        case "webp":
            try await encodeWebP(image, to: out, quality: quality, context: context)
        case "pdf":
            try encodePDF(image, dpi: (properties[kCGImagePropertyDPIWidth] as? Double) ?? 72, to: out)
        default:
            guard let uti = utType[format] else { throw JobFailure("Images can't be saved as \(format.uppercased()).") }
            guard writableTargets.contains(format) else {
                throw JobFailure("This version of macOS can't save \(format.uppercased()) images.")
            }
            guard let dest = CGImageDestinationCreateWithURL(out as CFURL, uti as CFString, 1, nil) else {
                throw JobFailure("Morph couldn't create the \(format.uppercased()) file.")
            }
            var props = properties
            props[kCGImagePropertyOrientation] = 1
            if let t = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                var tt = t; tt[kCGImagePropertyTIFFOrientation] = 1; props[kCGImagePropertyTIFFDictionary] = tt
            }
            if ["jpg", "heic", "avif"].contains(format) { props[kCGImageDestinationLossyCompressionQuality] = quality }
            if format == "jpg" || format == "bmp" { props[kCGImageDestinationBackgroundColor] = CGColor(gray: 1, alpha: 1) }
            if format == "tiff" {
                var t = (props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]) ?? [:]
                t[kCGImagePropertyTIFFCompression] = 5 // LZW, lossless
                props[kCGImagePropertyTIFFDictionary] = t
            }
            let img = (format == "jpg" || format == "bmp") ? flatten(image) : image
            CGImageDestinationAddImage(dest, img, props as CFDictionary)
            guard CGImageDestinationFinalize(dest) else {
                throw JobFailure("macOS couldn't encode this image as \(format.uppercased()).")
            }
        }
    }

    /// Composites over white (JPEG/BMP have no alpha).
    static func flatten(_ image: CGImage) -> CGImage {
        guard image.alphaInfo != .none, image.alphaInfo != .noneSkipLast, image.alphaInfo != .noneSkipFirst,
              let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return image }
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return ctx.makeImage() ?? image
    }

    static func encodePDF(_ image: CGImage, dpi: Double, to out: URL) throws {
        let scale = 72 / max(1, dpi)
        var box = CGRect(x: 0, y: 0, width: Double(image.width) * scale, height: Double(image.height) * scale)
        guard let ctx = CGContext(out as CFURL, mediaBox: &box, nil) else { throw JobFailure("Morph couldn't create the PDF.") }
        ctx.beginPDFPage(nil)
        ctx.draw(image, in: box)
        ctx.endPDFPage()
        ctx.closePDF()
    }

    static func pngData(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { throw JobFailure("PNG encode failed.") }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw JobFailure("PNG encode failed.") }
        return data as Data
    }

    static func encodeWebP(_ image: CGImage, to out: URL, quality: Double, context: JobContext?) async throws {
        let tmp = out.deletingLastPathComponent().appendingPathComponent(".morph-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try pngData(image).write(to: tmp)
        var args = try FFmpeg.recipeArgs("image.webp", source: nil)
        if let qi = args.firstIndex(of: "-quality"), qi + 1 < args.count { args[qi + 1] = String(Int((quality * 100).rounded())) }
        try await FFmpeg.run(input: tmp, output: out, args: args, duration: nil, context: context)
    }

    // MARK: Conversion

    public static func convert(_ input: URL, to format: String, output: URL, context: JobContext?) async throws {
        let src = Formats.isSVG(input) ? nil : CGImageSourceCreateWithURL(input as CFURL, nil)
        // Same-pipeline fast path keeps metadata, colour profile and orientation exactly (ImageIO formats only).
        let upright: Bool = {
            guard let src = src, let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else { return false }
            return ((p[kCGImagePropertyOrientation] as? Int) ?? 1) == 1
        }()
        // Fast path only for upright images: otherwise pixels must be rotated, because not every format/viewer
        // honours the orientation tag (e.g. PNG).
        if upright, let src = src, let uti = utType[format], format != "pdf", writableTargets.contains(format),
           let dest = CGImageDestinationCreateWithURL(output as CFURL, uti as CFString, 1, nil) {
            var opts: [CFString: Any] = [:]
            if ["jpg", "heic", "avif"].contains(format) { opts[kCGImageDestinationLossyCompressionQuality] = 0.9 }
            if format == "jpg" || format == "bmp" {
                // Alpha must be flattened onto white; go through pixels.
                let d = try await decode(input)
                try await encode(d.image, format: format, to: output, properties: d.properties, context: context)
                return
            }
            CGImageDestinationAddImageFromSource(dest, src, 0, opts as CFDictionary)
            if CGImageDestinationFinalize(dest) { return }
        }
        let d = try await decode(input)
        try await encode(d.image, format: format, to: output, properties: d.properties, context: context)
    }

    // MARK: Crop

    public static func crop(_ input: URL, options: CropOptions, output: URL, context: JobContext?) async throws {
        let fmt = Formats.format(of: input) ?? "png"
        let d = try await decode(input)
        let W = Double(d.image.width), H = Double(d.image.height)
        let r = options.rect ?? options.aspect.centeredRect(width: W, height: H)
        let rect = CGRect(x: max(0, r.x), y: max(0, r.y), width: min(W - max(0, r.x), r.w), height: min(H - max(0, r.y), r.h)).integral
        guard rect.width >= 1, rect.height >= 1, var cropped = d.image.cropping(to: rect) else {
            throw JobFailure("The crop area is empty.")
        }
        if let s = options.outputSize, s.w > 0, s.h > 0 { cropped = resize(cropped, width: s.w, height: s.h) }
        let outFmt = writableTargets.contains(fmt) ? fmt : "png"
        try await encode(cropped, format: outFmt, to: output, quality: 0.92, properties: stripSize(d.properties), context: context)
    }

    static func stripSize(_ p: [CFString: Any]) -> [CFString: Any] {
        var p = p
        p.removeValue(forKey: kCGImagePropertyPixelWidth); p.removeValue(forKey: kCGImagePropertyPixelHeight)
        return p
    }

    static func resize(_ image: CGImage, width: Int, height: Int) -> CGImage {
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage() ?? image
    }

    static func scaled(_ image: CGImage, maxDimension: Int) -> CGImage {
        let m = max(image.width, image.height)
        guard maxDimension > 0, m > maxDimension else { return image }
        let s = Double(maxDimension) / Double(m)
        return resize(image, width: max(1, Int((Double(image.width) * s).rounded())), height: max(1, Int((Double(image.height) * s).rounded())))
    }

    // MARK: Compress

    /// Encodes at a given quality/scale into memory and returns the bytes (for estimates and target-size search).
    static func encodeToData(_ image: CGImage, format: String, quality: Double, properties: [CFString: Any], context: JobContext?) async throws -> Data {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("morph-est-\(UUID().uuidString).\(format == "jpg" ? "jpg" : format)")
        defer { try? FileManager.default.removeItem(at: tmp) }
        if format == "png" {
            return try pngData(image)
        }
        try await encode(image, format: format, to: tmp, quality: quality, properties: properties, context: context)
        return try Data(contentsOf: tmp)
    }

    /// PNG "Strong"/"Smallest": 256-colour palette via FFmpeg palettegen/paletteuse (lossy, like palette quantizers).
    static func quantizedPNG(_ image: CGImage, context: JobContext?) async throws -> Data {
        let dir = FileManager.default.temporaryDirectory
        let a = dir.appendingPathComponent("morph-q-\(UUID().uuidString).png"), b = dir.appendingPathComponent("morph-q-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: a); try? FileManager.default.removeItem(at: b) }
        try pngData(image).write(to: a)
        try await FFmpeg.run(input: a, output: b, args: ["-vf", "split[x][y];[x]palettegen=reserve_transparent=1:max_colors=256[p];[y][p]paletteuse=dither=sierra2_4a", "-frames:v", "1"], duration: nil, context: context)
        return try Data(contentsOf: b)
    }

    /// Produces compressed bytes for `input` per options (used for both the estimate and the real write).
    public static func compressedData(_ input: URL, options: CompressOptions, context: JobContext?) async throws -> Data {
        let fmt = Formats.format(of: input) ?? "jpg"
        let originalSize = (try? FileManager.default.attributesOfItem(atPath: input.path)[.size] as? NSNumber)?.int64Value ?? 0
        let d = try await decode(input)
        let props = options.keepMetadata ? stripSize(d.properties) : [:]
        var image = scaled(d.image, maxDimension: options.maxDimension.rawValue)
        let target = options.targetSize(original: originalSize)

        func encode(_ img: CGImage, q: Double) async throws -> Data {
            switch fmt {
            case "png":
                return options.goal == .preset && options.preset == .balanced ? try pngData(img) : try await quantizedPNG(img, context: context)
            case "tiff", "bmp":
                return try await encodeToData(img, format: fmt, quality: 1, properties: props, context: context)
            default:
                return try await encodeToData(img, format: fmt, quality: q, properties: props, context: context)
            }
        }

        guard let target = target else { return try await encode(image, q: options.presetQuality) }
        let lossy = ["jpg", "heic", "webp", "avif"].contains(fmt)
        // Target size: binary-search quality (lossy), then step dimensions down if still too big.
        for _ in 0..<6 {
            try context?.checkCancelled()
            if lossy {
                var lo = 0.05, hi = 0.95
                var best: Data?
                for _ in 0..<7 {
                    let mid = (lo + hi) / 2
                    let data = try await encode(image, q: mid)
                    if Int64(data.count) <= target { best = data; lo = mid } else { hi = mid }
                }
                if let best = best { return best }
            } else {
                let data = try await encode(image, q: 1)
                if Int64(data.count) <= target { return data }
            }
            guard image.width > 64, image.height > 64 else { break }
            image = resize(image, width: Int(Double(image.width) * 0.8), height: Int(Double(image.height) * 0.8))
        }
        return try await encode(image, q: 0.05)
    }

    // MARK: Metadata

    /// Removes metadata. JPEG/PNG/GIF/WebP are stripped losslessly at the container level; other formats are
    /// re-encoded without metadata (TIFF/BMP lossless; HEIC/AVIF at maximum quality).
    public static func removeMetadata(_ input: URL, output: URL, context: JobContext?) async throws {
        let fmt = Formats.format(of: input) ?? ""
        let map: [String: MetadataStrip.Format] = ["jpg": .jpeg, "png": .png, "gif": .gif, "webp": .webp]
        if let f = map[fmt] {
            try MetadataStrip.strip(try Data(contentsOf: input), format: f).write(to: output)
            return
        }
        let d = try await decode(input)
        var keep: [CFString: Any] = [:]
        if let p = d.properties[kCGImagePropertyProfileName] { keep[kCGImagePropertyProfileName] = p }
        try await encode(d.image, format: writableTargets.contains(fmt) ? fmt : "png", to: output, quality: 1, properties: keep, context: context)
    }

    /// Flattened metadata for the Metadata window: (group, key, value).
    public static func readMetadata(_ url: URL) -> [(group: String, key: String, value: String)] {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any] else { return [] }
        var rows: [(String, String, String)] = []
        for (k, v) in props.sorted(by: { $0.key < $1.key }) {
            if let dict = v as? [String: Any] {
                let group = k.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
                for (k2, v2) in dict.sorted(by: { $0.key < $1.key }) { rows.append((group, k2, describe(v2))) }
            } else {
                rows.append(("File", k, describe(v)))
            }
        }
        return rows
    }

    static func describe(_ v: Any) -> String {
        if let a = v as? [Any] { return a.map { describe($0) }.joined(separator: ", ") }
        if let d = v as? [String: Any] { return d.map { "\($0.key): \(describe($0.value))" }.sorted().joined(separator: "; ") }
        return "\(v)"
    }
}

extension Formats {
    public static func isSVG(_ url: URL) -> Bool { url.pathExtension.lowercased() == "svg" }
}
#endif
