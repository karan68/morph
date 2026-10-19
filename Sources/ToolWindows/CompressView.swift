#if canImport(AppKit)
import AppKit
import SwiftUI
import Engines
import Capabilities
import Jobs
import A11y

/// Spec mockup 09: Compress tool window.
struct CompressView: View {
    let items: [URL]
    let done: (ToolOptions?) -> Void
    @State private var o = CompressOptions()
    @State private var targetMB: Double = 1
    @State private var estimate: String = "Calculating…"
    @State private var saving: String?
    @State private var subtitle = ""
    @State private var estimateTask: Task<Void, Never>?

    var first: URL { items[0] }
    var format: String { Formats.format(of: first) ?? "" }
    var family: FormatFamily? { Formats.family(of: format) }
    var original: Int64 { items.map(fileSize).reduce(0, +) }
    /// Lossless formats can't aim for an arbitrary size; PDF compression has two levels only.
    var supportsSizeGoals: Bool { !["wav", "flac", "pdf", "tiff", "bmp"].contains(format) }
    var presets: [(CompressOptions.Preset, String)] {
        format == "pdf" ? [(.balanced, "Balanced"), (.strong, "Strong")] : CompressOptions.Preset.allCases.map { ($0, $0.rawValue) }
    }
    var presetHelp: String {
        switch (family, o.preset) {
        case (.pdf?, .balanced): return "Re-saves images inside the PDF as JPEG."
        case (.pdf?, _): return "Also downsamples images for screen viewing."
        case (_, .balanced): return "Smaller file, little visible quality loss."
        case (_, .strong): return "Much smaller file, some visible quality loss."
        case (_, .smallest): return "Smallest file; quality loss is noticeable."
        }
    }

    var body: some View {
        ToolChrome(title: "Compress", primary: "Compress", onReset: { o = CompressOptions(); targetMB = defaultTargetMB }, onCancel: { done(nil) }, onPrimary: apply) {
            VStack(alignment: .leading, spacing: 14) {
                FileHeader(url: first, subtitle: items.count > 1 ? "\(items.count) files · \(formatBytes(original)) total" : subtitle)
                Divider()
                if supportsSizeGoals {
                    Row(label: "Goal") {
                        MorphSegmented(label: "Goal", options: CompressOptions.Goal.allCases.map { ($0, $0.rawValue) }, selection: $o.goal)
                    }
                }
                switch o.goal {
                case .preset:
                    Row(label: "Preset") { MorphSegmented(label: "Preset", options: presets, selection: $o.preset) }
                    Row(label: "") { Text(presetHelp).foregroundColor(Color(Theme.ink3)) }
                case .targetSize:
                    Row(label: "Target size") {
                        TextField("", value: $targetMB, format: .number.precision(.fractionLength(0...2)))
                            .frame(width: 80).textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Target size in megabytes")
                        Text("MB").foregroundColor(Color(Theme.ink2))
                    }
                case .percentage:
                    Row(label: "Reduce by") {
                        Slider(value: Binding(get: { Double(o.percentage) }, set: { o.percentage = Int($0) }), in: 10...90, step: 5)
                            .frame(width: 180).accessibilityValue("\(o.percentage) percent")
                        Text("\(o.percentage)%").font(.system(size: 13).monospacedDigit()).frame(width: 40, alignment: .trailing)
                    }
                }
                if family == .image || family == .video {
                    Row(label: family == .video ? "Video size" : "Image size") {
                        Picker("", selection: $o.maxDimension) {
                            ForEach(CompressOptions.MaxDimension.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        .labelsHidden().frame(width: 230)
                        .accessibilityLabel(family == .video ? "Video size" : "Image size")
                    }
                }
                Row(label: "Metadata") {
                    Toggle(family == .image ? "Keep camera & date info" : "Keep tags", isOn: $o.keepMetadata).toggleStyle(.checkbox)
                }
                Divider()
                HStack {
                    Text("Estimated result").foregroundColor(Color(Theme.ink2))
                    Spacer()
                    Text(estimate).font(.system(size: 13, weight: .bold))
                    if let s = saving {
                        Text(s).font(.system(size: 12, weight: .semibold)).foregroundColor(Color(Theme.teal))
                            .padding(.horizontal, 9).padding(.vertical, 3)
                            .background(Capsule().fill(Color(Theme.tealSoft)))
                    }
                }
                .accessibilityElement(children: .combine)
                Text(savesAs).foregroundColor(Color(Theme.ink3)).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 540)
        .onAppear { load() }
        .onChange(of: o) { _ in scheduleEstimate() }
        .onChange(of: targetMB) { _ in o.targetBytes = Int64(max(0.01, targetMB) * 1_000_000) }
    }

    var defaultTargetMB: Double { max(0.05, (Double(fileSize(first)) / 1_000_000 / 2 * 100).rounded() / 100) }

    var savesAs: AttributedString {
        let stem = Naming.toolStem(source: first, tool: "compress")
        var s = AttributedString("Saves as ")
        var name = AttributedString(Naming.candidate(stem: stem.stem, ext: stem.ext, attempt: 1))
        name.foregroundColor = Color(Theme.ink); name.font = .system(size: 13, weight: .bold)
        s += name
        s += AttributedString(items.count > 1 ? " (and one per file) next to the originals." : " next to the original.")
        return s
    }

    func load() {
        targetMB = defaultTargetMB
        o.targetBytes = Int64(targetMB * 1_000_000)
        if format == "pdf" { o.goal = .preset }
        Task {
            var parts = ["Original \(formatBytes(fileSize(first)))"]
            if family == .image, let size = try? await ImageEngine.pixelSize(first) {
                parts.append("\(Int(size.width)) × \(Int(size.height))")
            } else if family == .audio || family == .video, let info = try? await FFmpeg.probe(first) {
                if let v = info.video, let w = v.width, let h = v.height { parts.append("\(w) × \(h)") }
                if let d = info.duration { parts.append(timecode(d)) }
            }
            subtitle = parts.joined(separator: " · ")
        }
        scheduleEstimate()
    }

    func scheduleEstimate() {
        estimateTask?.cancel()
        estimate = "Calculating…"; saving = nil
        let opts = o, url = first, fam = family, fmt = format
        estimateTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            let orig = fileSize(url)
            var est: Int64?
            switch fam {
            case .image?:
                // Real encode of the actual image (spec mockup 09 note 3 describes a fast trial encode).
                est = (try? await ImageEngine.compressedData(url, options: opts, context: nil)).map { Int64($0.count) }
            case .audio?, .video?:
                if let t = opts.targetSize(original: orig) { est = t }
                else if fmt == "wav" || fmt == "flac" { est = nil }
                else { est = Int64(Double(orig) * opts.presetBitrateRatio) }
            default:
                est = opts.targetSize(original: orig)
            }
            guard !Task.isCancelled else { return }
            if let e = est {
                estimate = "≈ \(formatBytes(e))"
                let pct = orig > 0 ? Int((1 - Double(e) / Double(orig)) * 100) : 0
                saving = pct > 0 ? "−\(pct)%" : nil
                Announcer.say("Estimated result \(formatBytes(e))", priority: .low)
            } else {
                estimate = fmt == "pdf" ? "Depends on the images inside" : "Lossless — size depends on the audio"
            }
        }
    }

    func apply() {
        var opts = o
        if opts.goal == .targetSize { opts.targetBytes = Int64(max(0.01, targetMB) * 1_000_000) }
        done(.compress(opts))
    }
}
#endif
