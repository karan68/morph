#if canImport(AppKit)
import AppKit
import SwiftUI
import AVKit
import AVFoundation
import Engines
import Jobs
import Capabilities
import A11y

/// Timeline with start/end handles and a playhead (spec mockup 10). Handles are accessible adjustable
/// elements ("Start, 3.1 seconds, adjustable" — spec §6 A10).
struct TrimTimeline<Background: View>: View {
    let duration: Double
    @Binding var start: Double
    @Binding var end: Double
    let playhead: Double
    let step: Double
    @ViewBuilder let background: () -> Background
    @State private var dragOrigin: (Double, Double)?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x = { (t: Double) in CGFloat(duration > 0 ? t / duration : 0) * w }
            ZStack(alignment: .topLeading) {
                background().frame(width: w, height: geo.size.height).clipShape(RoundedRectangle(cornerRadius: 8))
                // dim outside selection
                Rectangle().fill(Color.white.opacity(0.55)).frame(width: max(0, x(start)), height: geo.size.height)
                Rectangle().fill(Color.white.opacity(0.55)).frame(width: max(0, w - x(end)), height: geo.size.height).offset(x: x(end))
                // selection frame with thick side handles
                RoundedRectangle(cornerRadius: 8).strokeBorder(Color(Theme.accent), lineWidth: 3)
                    .frame(width: max(28, x(end) - x(start)), height: geo.size.height).offset(x: x(start))
                    .allowsHitTesting(false)
                handle(at: x(start), height: geo.size.height, leading: true)
                    .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                        if dragOrigin == nil { dragOrigin = (start, end) }
                        start = min(max(0, dragOrigin!.0 + Double(g.translation.width / w) * duration), end - step)
                    }.onEnded { _ in dragOrigin = nil })
                    .accessibilityElement()
                    .accessibilityLabel("Start")
                    .accessibilityValue(String(format: "%.1f seconds", start))
                    .accessibilityAdjustableAction { dir in
                        start = dir == .increment ? min(end - step, start + 0.1) : max(0, start - 0.1)
                    }
                handle(at: x(end) - 14, height: geo.size.height, leading: false)
                    .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                        if dragOrigin == nil { dragOrigin = (start, end) }
                        end = max(min(duration, dragOrigin!.1 + Double(g.translation.width / w) * duration), start + step)
                    }.onEnded { _ in dragOrigin = nil })
                    .accessibilityElement()
                    .accessibilityLabel("End")
                    .accessibilityValue(String(format: "%.1f seconds", end))
                    .accessibilityAdjustableAction { dir in
                        end = dir == .increment ? min(duration, end + 0.1) : max(start + step, end - 0.1)
                    }
                Rectangle().fill(Color.white).frame(width: 2, height: geo.size.height)
                    .shadow(color: .black.opacity(0.3), radius: 0.5).offset(x: x(playhead) - 1).allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    func handle(at x: CGFloat, height: CGFloat, leading: Bool) -> some View {
        RoundedRectangle(cornerRadius: leading ? 8 : 8).fill(Color(Theme.accent)).frame(width: 14, height: height)
            .overlay(RoundedRectangle(cornerRadius: 1.5).fill(Color.white).frame(width: 3, height: 20))
            .offset(x: x)
            .contentShape(Rectangle())
    }
}

/// Keyboard shortcuts inside trim windows (macOS 13 has no .onKeyPress): ← → step, I/O set start/end, Space play.
final class KeyMonitor: ObservableObject {
    private var token: Any?
    func install(_ handler: @escaping (NSEvent) -> Bool) {
        token = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            if NSApp.keyWindow?.firstResponder is NSTextView { return e } // typing in a field
            return handler(e) ? nil : e
        }
    }
    deinit { if let t = token { NSEvent.removeMonitor(t) } }
}

// MARK: Trim Video (spec mockup 10)

struct TrimVideoView: View {
    let item: URL
    let done: (ToolOptions?) -> Void
    @State private var duration: Double = 0
    @State private var start: Double = 0
    @State private var end: Double = 0
    @State private var playhead: Double = 0
    @State private var fps: Double = 30
    @State private var thumbs: [CGImage] = []
    @State private var still: CGImage?
    @State private var player: AVPlayer?
    @State private var method: VideoEngine.TrimMethod = .losslessEditList
    @State private var startText = ""
    @State private var endText = ""
    @StateObject private var keys = KeyMonitor()
    @State private var observer: Any?

    var avPlayable: Bool { ["mp4", "mov"].contains(Formats.format(of: item) ?? "") }

    var body: some View {
        ToolChrome(title: "Trim Video", primary: "Apply", primaryEnabled: end > start, onReset: { start = 0; end = duration; syncText() }, onCancel: { stop(); done(nil) }, onPrimary: { stop(); done(.trim(TrimOptions(start: start, end: end))) }) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color.black)
                    if let p = player { PlayerView(player: p) } else if let s = still { Image(decorative: s, scale: 1).resizable().scaledToFit() }
                }
                .frame(height: 330).clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Video preview")
                HStack {
                    Text("Drag the ends to trim").foregroundColor(Color(Theme.ink2))
                    Spacer()
                    (Text(timecode(end - start)).bold() + Text(" selected")).font(.system(size: 13).monospacedDigit())
                }
                TrimTimeline(duration: duration, start: $start, end: $end, playhead: playhead, step: 1 / fps) {
                    HStack(spacing: 0) {
                        ForEach(thumbs.indices, id: \.self) { i in
                            Image(decorative: thumbs[i], scale: 1).resizable().scaledToFill().frame(maxWidth: .infinity).clipped()
                        }
                    }
                    .background(Color(Theme.ink).opacity(0.15))
                }
                .frame(height: 64)
                HStack {
                    Text("Start").foregroundColor(Color(Theme.ink2))
                    TextField("", text: $startText, onCommit: commitText).font(.system(size: 13, design: .monospaced)).frame(width: 84)
                        .textFieldStyle(.roundedBorder).accessibilityLabel("Start time")
                    Spacer()
                    Button { stepFrame(-1) } label: { icon("stepBack") }.buttonStyle(MorphButtonStyle()).accessibilityLabel("Previous frame")
                    Button { togglePlay() } label: { icon("play") }.buttonStyle(MorphButtonStyle()).accessibilityLabel("Play selection")
                        .disabled(player == nil)
                    Button { stepFrame(1) } label: { icon("stepFwd") }.buttonStyle(MorphButtonStyle()).accessibilityLabel("Next frame")
                    Spacer()
                    Text("End").foregroundColor(Color(Theme.ink2))
                    TextField("", text: $endText, onCommit: commitText).font(.system(size: 13, design: .monospaced)).frame(width: 84)
                        .textFieldStyle(.roundedBorder).accessibilityLabel("End time")
                }
                Text("Keyboard: ← → step a frame · I O set start / end · Space play").font(.system(size: 12)).foregroundColor(Color(Theme.ink3))
                Text(methodText).foregroundColor(Color(Theme.ink3)).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 620)
        .task { await load() }
        .onChange(of: start) { v in playhead = v; seek(v); syncText() }
        .onChange(of: end) { _ in syncText() }
        .onDisappear { stop() }
    }

    var methodText: AttributedString {
        let stem = Naming.toolStem(source: item, tool: "trimVideo")
        var s = AttributedString("Saves as ")
        var n = AttributedString(Naming.candidate(stem: stem.stem, ext: stem.ext, attempt: 1)); n.font = .system(size: 13, weight: .bold); n.foregroundColor = Color(Theme.ink)
        s += n
        switch method {
        case .losslessEditList: s += AttributedString(". Lossless, frame-accurate cut — the video isn't re-encoded.")
        case .streamCopy: s += AttributedString(". Lossless cut (the start lands on a keyframe).")
        case .reencode: s += AttributedString(". The start isn't on a keyframe in this MKV, so the selection is re-encoded.")
        }
        return s
    }

    func icon(_ n: String) -> some View { Image(nsImage: Icons.image(n, size: 14) ?? NSImage()).renderingMode(.template) }

    func load() async {
        duration = (try? await VideoEngine.duration(item)) ?? 0
        end = duration
        syncText()
        if avPlayable {
            let asset = AVURLAsset(url: item)
            if let track = asset.tracks(withMediaType: .video).first, track.nominalFrameRate > 0 { fps = Double(track.nominalFrameRate) }
            let p = AVPlayer(url: item)
            player = p
            observer = p.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { t in
                playhead = t.seconds
                if t.seconds >= end, p.rate > 0 { p.pause() }
            }
        } else {
            still = try? await VideoEngine.frame(item, at: 0, maxWidth: 1000)
        }
        method = await VideoEngine.trimMethod(for: item, start: start)
        var imgs: [CGImage] = []
        for k in 0..<10 where duration > 0 {
            if let f = try? await VideoEngine.frame(item, at: duration * (Double(k) + 0.5) / 10, maxWidth: 160) { imgs.append(f) }
        }
        thumbs = imgs
        keys.install { e in
            switch e.keyCode {
            case 123: stepFrame(-1); return true
            case 124: stepFrame(1); return true
            case 49: togglePlay(); return true
            default:
                switch e.charactersIgnoringModifiers?.lowercased() {
                case "i": start = min(playhead, end - 1 / fps); return true
                case "o": end = max(playhead, start + 1 / fps); return true
                default: return false
                }
            }
        }
    }

    func syncText() { startText = timecode(start); endText = timecode(end) }

    func commitText() {
        if let s = parseTimecode(startText), s >= 0, s < end { start = s }
        if let e = parseTimecode(endText), e > start, e <= duration { end = e }
        syncText()
    }

    func seek(_ t: Double) {
        if let p = player { p.seek(to: CMTime(seconds: t, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) }
        else { Task { if let f = try? await VideoEngine.frame(item, at: t, maxWidth: 1000) { still = f } } }
        Task { method = await VideoEngine.trimMethod(for: item, start: start) }
    }

    func stepFrame(_ d: Double) {
        playhead = min(max(0, playhead + d / fps), duration)
        seek(playhead)
    }

    func togglePlay() {
        guard let p = player else { return }
        if p.rate > 0 { p.pause() } else {
            if playhead < start || playhead >= end { p.seek(to: CMTime(seconds: start, preferredTimescale: 600)) }
            p.play()
        }
    }

    func stop() {
        player?.pause()
        if let o = observer { player?.removeTimeObserver(o); observer = nil }
    }
}

struct PlayerView: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.player = player
        v.controlsStyle = .none
        v.videoGravity = .resizeAspect
        return v
    }
    func updateNSView(_ v: AVPlayerView, context: Context) {}
}

// MARK: Trim Audio

struct TrimAudioView: View {
    let item: URL
    let done: (ToolOptions?) -> Void
    @State private var duration: Double = 0
    @State private var start: Double = 0
    @State private var end: Double = 0
    @State private var peaks: [Float] = []
    @State private var playhead: Double = 0
    @State private var autoSilence = false
    @State private var player: AVAudioPlayer?
    @State private var timer: Timer?
    @State private var startText = ""
    @State private var endText = ""
    @StateObject private var keys = KeyMonitor()

    var body: some View {
        ToolChrome(title: "Trim Audio", primary: "Apply", primaryEnabled: end > start, onReset: { start = 0; end = duration; autoSilence = false; syncText() }, onCancel: { stop(); done(nil) }, onPrimary: { stop(); done(.trim(TrimOptions(start: start, end: end))) }) {
            VStack(alignment: .leading, spacing: 12) {
                FileHeader(url: item, subtitle: "Duration \(timecode(duration))")
                HStack {
                    Text("Drag the ends to trim").foregroundColor(Color(Theme.ink2))
                    Spacer()
                    (Text(timecode(end - start)).bold() + Text(" selected")).font(.system(size: 13).monospacedDigit())
                }
                TrimTimeline(duration: duration, start: $start, end: $end, playhead: playhead, step: 0.01) {
                    Canvas { ctx, size in
                        guard !peaks.isEmpty else { return }
                        let bw = size.width / CGFloat(peaks.count)
                        for (i, p) in peaks.enumerated() {
                            let h = max(1, CGFloat(p) * size.height * 0.9)
                            ctx.fill(Path(CGRect(x: CGFloat(i) * bw, y: (size.height - h) / 2, width: max(1, bw - 0.5), height: h)), with: .color(Color(Theme.ink2)))
                        }
                    }
                    .background(Color(Theme.ink).opacity(0.05))
                }
                .frame(height: 90)
                .accessibilityLabel("Waveform")
                HStack {
                    Text("Start").foregroundColor(Color(Theme.ink2))
                    TextField("", text: $startText, onCommit: commitText).font(.system(size: 13, design: .monospaced)).frame(width: 84).textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Start time")
                    Spacer()
                    Button { togglePlay() } label: { Image(nsImage: Icons.image("play", size: 14) ?? NSImage()).renderingMode(.template) }
                        .buttonStyle(MorphButtonStyle()).accessibilityLabel("Play selection").disabled(player == nil)
                    Spacer()
                    Text("End").foregroundColor(Color(Theme.ink2))
                    TextField("", text: $endText, onCommit: commitText).font(.system(size: 13, design: .monospaced)).frame(width: 84).textFieldStyle(.roundedBorder)
                        .accessibilityLabel("End time")
                }
                Toggle("Trim silent ends automatically", isOn: $autoSilence).toggleStyle(.checkbox)
                Text("Removes silence only at the beginning and end; pauses inside the recording are kept.").font(.system(size: 12)).foregroundColor(Color(Theme.ink3))
                Text("Keyboard: I O set start / end · Space play").font(.system(size: 12)).foregroundColor(Color(Theme.ink3))
                let stem = Naming.toolStem(source: item, tool: "trimAudio")
                Text("Saves as **\(Naming.candidate(stem: stem.stem, ext: stem.ext, attempt: 1))** next to the original.").foregroundColor(Color(Theme.ink3))
            }
        }
        .frame(width: 600)
        .task { await load() }
        .onChange(of: autoSilence) { on in
            if on { let r = AudioEngine.nonSilentRange(peaks: peaks, duration: duration); start = r.start; end = r.end }
            else { start = 0; end = duration }
            syncText()
            Announcer.say(on ? "Trimmed silent ends: \(timecode(start)) to \(timecode(end))" : "Full length restored")
        }
        .onChange(of: start) { v in playhead = v; syncText() }
        .onChange(of: end) { _ in syncText() }
        .onDisappear { stop() }
    }

    func load() async {
        if let w = try? await AudioEngine.waveform(item, buckets: 420) { peaks = w.peaks; duration = w.duration }
        if let d = try? await FFmpeg.probe(item).duration { duration = d }
        end = duration
        syncText()
        player = try? AVAudioPlayer(contentsOf: item)
        player?.prepareToPlay()
        keys.install { e in
            if e.keyCode == 49 { togglePlay(); return true }
            switch e.charactersIgnoringModifiers?.lowercased() {
            case "i": start = min(playhead, end - 0.01); return true
            case "o": end = max(playhead, start + 0.01); return true
            default: return false
            }
        }
    }

    func syncText() { startText = timecode(start); endText = timecode(end) }

    func commitText() {
        if let s = parseTimecode(startText), s >= 0, s < end { start = s }
        if let e = parseTimecode(endText), e > start, e <= duration { end = e }
        syncText()
    }

    func togglePlay() {
        guard let p = player else { return }
        if p.isPlaying { p.pause(); timer?.invalidate(); return }
        if playhead < start || playhead >= end { p.currentTime = start }
        p.play()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { _ in
            playhead = p.currentTime
            if p.currentTime >= end { p.pause(); timer?.invalidate() }
        }
    }

    func stop() { player?.stop(); timer?.invalidate() }
}
#endif
