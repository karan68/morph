import Foundation

/// Compress tool settings (spec mockup 09: Goal = Preset | Target size | Percentage; Preset = Balanced | Strong | Smallest).
public struct CompressOptions: Equatable {
    public enum Goal: String, CaseIterable { case preset = "Preset", targetSize = "Target size", percentage = "Percentage" }
    public enum Preset: String, CaseIterable { case balanced = "Balanced", strong = "Strong", smallest = "Smallest" }
    /// "Image size" popup. For video this caps the height.
    public enum MaxDimension: Int, CaseIterable {
        case original = 0, px4096 = 4096, px2048 = 2048, px1080 = 1080, px720 = 720
        public var label: String {
            switch self {
            case .original: return "Keep original dimensions"
            case .px4096: return "Longest side 4096 px"
            case .px2048: return "Longest side 2048 px"
            case .px1080: return "Longest side 1080 px"
            case .px720: return "Longest side 720 px"
            }
        }
    }

    public var goal: Goal = .preset
    public var preset: Preset = .balanced
    public var targetBytes: Int64 = 1_000_000
    public var percentage: Int = 50          // reduce by this %
    public var maxDimension: MaxDimension = .original
    public var keepMetadata: Bool = true

    public init() {}

    /// Lossy quality 0…1 for a preset (images).
    public var presetQuality: Double {
        switch preset { case .balanced: return 0.75; case .strong: return 0.55; case .smallest: return 0.35 }
    }

    /// Fraction of the source bitrate kept for a preset (audio/video).
    public var presetBitrateRatio: Double {
        switch preset { case .balanced: return 0.6; case .strong: return 0.4; case .smallest: return 0.25 }
    }

    /// Target size in bytes given the original size, or nil in preset mode.
    public func targetSize(original: Int64) -> Int64? {
        switch goal {
        case .preset: return nil
        case .targetSize: return max(1, targetBytes)
        case .percentage: return max(1, original * Int64(100 - min(95, max(1, percentage))) / 100)
        }
    }
}

/// Aspect presets for Crop Image (Free · 1:1 · 16:9 · 9:16 · 4:3 · 3:4).
public enum CropAspect: String, CaseIterable {
    case free = "Free", square = "1:1", wide = "16:9", tall = "9:16", classic = "4:3", portrait = "3:4"
    public var ratio: Double? {
        switch self {
        case .free: return nil
        case .square: return 1
        case .wide: return 16.0 / 9
        case .tall: return 9.0 / 16
        case .classic: return 4.0 / 3
        case .portrait: return 3.0 / 4
        }
    }

    /// Largest centred rect of this aspect inside w×h (pixels).
    public func centeredRect(width w: Double, height h: Double) -> (x: Double, y: Double, w: Double, h: Double) {
        guard let r = ratio else { return (0, 0, w, h) }
        var cw = w, ch = w / r
        if ch > h { ch = h; cw = h * r }
        return ((w - cw) / 2, (h - ch) / 2, cw.rounded(.down), ch.rounded(.down))
    }
}

public struct CropOptions: Equatable {
    /// Crop rect in oriented pixel space (origin top-left). nil = use `aspect` centred (multi-file).
    public var rect: (x: Double, y: Double, w: Double, h: Double)?
    public var aspect: CropAspect = .free
    /// Optional exact output size (resample after crop).
    public var outputSize: (w: Int, h: Int)?
    public init() {}
    public static func == (a: CropOptions, b: CropOptions) -> Bool {
        a.aspect == b.aspect && a.rect.map { [$0.x, $0.y, $0.w, $0.h] } == b.rect.map { [$0.x, $0.y, $0.w, $0.h] }
            && a.outputSize.map { [$0.w, $0.h] } == b.outputSize.map { [$0.w, $0.h] }
    }
}

public struct TrimOptions: Equatable {
    public var start: Double
    public var end: Double
    public init(start: Double, end: Double) { self.start = start; self.end = end }
}

public enum ToolOptions {
    case none
    case compress(CompressOptions)
    case crop(CropOptions)
    case trim(TrimOptions)
}
