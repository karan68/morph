import Foundation

/// Format families. M1 implements conversions for image, audio, video (incl. GIF), subtitle and archive inputs (spec §4.2).
public enum FormatFamily: String, CaseIterable {
    case image, audio, video, pdf, slides, spreadsheet, document, subtitle, archive
}

public enum WheelMode: String, CaseIterable {
    case conversions, tools, actions
}

/// One dragged item as seen by the registry.
public struct DraggedItem: Equatable {
    public let url: URL
    public let isDirectory: Bool
    public let format: String?

    public init(url: URL, isDirectory: Bool) {
        self.url = url
        self.isDirectory = isDirectory
        self.format = isDirectory ? nil : Formats.format(of: url)
    }
}

public enum Formats {
    static let images = ["jpg", "png", "webp", "heic", "tiff", "svg", "avif", "bmp"]
    static let audio = ["mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "wma"]
    static let video = ["mp4", "mov", "mkv", "webm", "avi", "wmv", "gif"]
    static let subtitles = ["srt", "vtt"]
    static let archives = ["zip", "tar", "gz", "rar"]
    static let spreadsheets = ["xlsx", "xls", "ods", "csv", "tsv"]
    static let slides = ["ppt", "pptx"]
    static let documents = ["docx", "pages", "md", "rtf", "rtfd", "textClipping", "txt", "epub", "html"]

    /// Extension aliases → canonical matrix format id.
    static let aliases: [String: String] = [
        "jpeg": "jpg", "jpe": "jpg", "tif": "tiff", "aif": "aiff", "aifc": "aiff",
        "tgz": "gz", "markdown": "md", "textclipping": "textClipping", "heif": "heic",
    ]

    /// Canonical format id for a file URL, or nil if Morph doesn't know it.
    public static func format(of url: URL) -> String? {
        let name = url.lastPathComponent.lowercased()
        if name.hasSuffix(".tar.gz") || name.hasSuffix(".tgz") { return "gz" }
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { return nil }
        let id = aliases[ext] ?? ext
        return CapabilityMatrix.conversions[id] != nil || id == "html" ? id : nil
    }

    public static func family(of format: String) -> FormatFamily? {
        if images.contains(format) { return .image }
        if audio.contains(format) { return .audio }
        if video.contains(format) { return .video }
        if format == "pdf" { return .pdf }
        if slides.contains(format) { return .slides }
        if spreadsheets.contains(format) { return .spreadsheet }
        if subtitles.contains(format) { return .subtitle }
        if archives.contains(format) { return .archive }
        if documents.contains(format) { return .document }
        return nil
    }

    /// Label shown on petals and in UI ("GZIP" for gz, upper-case otherwise).
    public static func label(_ format: String) -> String {
        switch format {
        case "gz": return "GZIP"
        case "textClipping": return "CLIPPING"
        default: return format.uppercased()
        }
    }

    /// File extension written for an output format.
    public static func fileExtension(for format: String) -> String {
        format == "gz" ? "tar.gz" : format
    }
}

/// Decides which petals a wheel shows for a drag. Follows the rules in spec §4.3:
/// same-format selections get conversions + tools (multi-file tools when >1 item); mixed/folders get actions only.
public struct CapabilityRegistry {
    /// M1 scope (spec §4.2): conversion inputs from these families only.
    public static let m1ConversionFamilies: Set<FormatFamily> = [.image, .audio, .video, .subtitle, .archive]
    /// M1 tools (spec §4.2): Compress, Metadata, Crop Image, Trim Video/Audio, Mute, Extract.
    public static let m1Tools: Set<String> = ["compress", "removeMetadata", "cropImage", "trimVideo", "trimAudio", "muteVideo", "extractArchive"]

    public var enabledConversionFamilies: Set<FormatFamily>
    public var enabledTools: Set<String>
    /// Output formats the running OS can't write (e.g. AVIF on older macOS). Hidden from wheels.
    public var unavailableTargets: Set<String>

    public init(enabledConversionFamilies: Set<FormatFamily> = m1ConversionFamilies,
                enabledTools: Set<String> = m1Tools,
                unavailableTargets: Set<String> = []) {
        self.enabledConversionFamilies = enabledConversionFamilies
        self.enabledTools = enabledTools
        self.unavailableTargets = unavailableTargets
    }

    /// The single shared format of the selection, or nil for mixed / folders / unknown.
    public static func commonFormat(_ items: [DraggedItem]) -> String? {
        guard let first = items.first?.format, !items.contains(where: { $0.isDirectory || $0.format != first }) else { return nil }
        return first
    }

    public func targets(for mode: WheelMode, items: [DraggedItem]) -> [String] {
        guard !items.isEmpty else { return [] }
        switch mode {
        case .actions:
            return CapabilityMatrix.actionOrder
        case .conversions:
            guard let f = Self.commonFormat(items), let fam = Formats.family(of: f), enabledConversionFamilies.contains(fam) else { return [] }
            return (CapabilityMatrix.conversions[f] ?? []).filter { !unavailableTargets.contains($0) }
        case .tools:
            guard let f = Self.commonFormat(items), let t = CapabilityMatrix.tools[f] else { return [] }
            let list = items.count > 1 ? t.multi : t.single
            return list.filter { enabledTools.contains($0) }
        }
    }

    /// Plain-language empty-state text. `keys` maps each mode to the glyph of its configured key.
    public func emptyText(for mode: WheelMode, items: [DraggedItem], keys: [WheelMode: String]) -> String {
        let conv = keys[.conversions] ?? "⇧", act = keys[.actions] ?? "⌃"
        guard let f = Self.commonFormat(items) else {
            return "Mixed selection.\nTap \(act) for file actions."
        }
        let label = Formats.label(f)
        switch mode {
        case .tools: return "No editing tools for \(label).\nTap \(conv) to convert or \(act) for actions."
        case .conversions: return "No conversions for \(label).\nTap \(act) for file actions."
        case .actions: return ""
        }
    }

    public static func title(forTool id: String) -> String { CapabilityMatrix.toolDefs[id]?.title ?? id.uppercased() }
    public static func name(forTool id: String) -> String { CapabilityMatrix.toolDefs[id]?.name ?? id }
    public static func title(forAction id: String) -> String { CapabilityMatrix.actionDefs[id]?.title ?? id.uppercased() }
    public static func name(forAction id: String) -> String { CapabilityMatrix.actionDefs[id]?.name ?? id }
}
