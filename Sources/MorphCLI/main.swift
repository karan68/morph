import AppKit
import Foundation
import ImageIO
import PDFKit
import Capabilities
import Jobs
import Engines

// morph-cli — drives the same engines as the app, for golden-matrix tests on CI (spec §12).
//   morph-cli caps                                  JSON: M1 conversion targets per input (this OS), tools, unavailable targets
//   morph-cli convert <input> <target>              writes beside input using the app's naming rules; prints output path
//   morph-cli tool <id> <input…> [--preset P] [--goal preset|targetSize|percentage] [--pct N] [--bytes N]
//                                  [--start S --end E] [--aspect 1:1] [--no-meta]
//   morph-cli verify <input> <output> <kind> <target>   kind = convert|<toolId>; prints JSON {ok, detail}
//   morph-cli tag-image <input> <output>             writes a copy with EXIF/GPS/TIFF tags containing "MorphSecret"
//   morph-cli metadata <file>                        prints metadata rows (Metadata window data)

_ = NSApplication.shared
NSApp.setActivationPolicy(.prohibited)

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(Data((msg + "\n").utf8))
    exit(1)
}

func json(_ obj: Any) -> String {
    let d = try! JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys, .prettyPrinted])
    return String(decoding: d, as: UTF8.self)
}

func registry() -> CapabilityRegistry { CapabilityRegistry(unavailableTargets: ImageEngine.unavailableTargets) }

func opt(_ args: [String], _ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

func toolOptions(_ id: String, _ args: [String]) -> ToolOptions {
    switch id {
    case "compress":
        var o = CompressOptions()
        if let p = opt(args, "--preset"), let v = CompressOptions.Preset(rawValue: p.capitalized) { o.preset = v }
        if let g = opt(args, "--goal") { o.goal = g == "targetSize" ? .targetSize : g == "percentage" ? .percentage : .preset }
        if let n = opt(args, "--pct").flatMap(Int.init) { o.percentage = n }
        if let n = opt(args, "--bytes").flatMap(Int64.init) { o.targetBytes = n }
        if args.contains("--no-meta") { o.keepMetadata = false }
        return .compress(o)
    case "cropImage":
        var o = CropOptions()
        if let a = opt(args, "--aspect"), let v = CropAspect(rawValue: a) { o.aspect = v }
        return .crop(o)
    case "trimVideo", "trimAudio":
        return .trim(TrimOptions(start: opt(args, "--start").flatMap(Double.init) ?? 0, end: opt(args, "--end").flatMap(Double.init) ?? 1))
    default:
        return .none
    }
}

// MARK: verification

struct Check { var ok = true; var notes: [String] = [] }

func imageInfo(_ url: URL) -> (w: Int, h: Int, type: String)? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(src) > 0,
          let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else { return nil }
    var w = p[kCGImagePropertyPixelWidth] as? Int ?? 0, h = p[kCGImagePropertyPixelHeight] as? Int ?? 0
    if let o = p[kCGImagePropertyOrientation] as? Int, o >= 5 { swap(&w, &h) }
    return (w, h, (CGImageSourceGetType(src) as String?) ?? "")
}

let expectedImageUTI: [String: String] = ["jpg": "public.jpeg", "png": "public.png", "heic": "public.heic", "tiff": "public.tiff",
                                          "bmp": "com.microsoft.bmp", "avif": "public.avif", "webp": "org.webmproject.webp"]
let expectedAudioCodec: [String: [String]] = ["mp3": ["mp3"], "m4a": ["aac"], "wav": ["pcm_s16le", "pcm_s24le"], "flac": ["flac"],
                                              "ogg": ["vorbis"], "opus": ["opus"], "aiff": ["pcm_s16be", "pcm_s24be"], "wma": ["wmav2"]]
let expectedVideoCodec: [String: [String]] = ["mp4": ["h264", "hevc"], "mov": ["h264", "hevc"], "mkv": ["h264"], "webm": ["vp9"],
                                              "avi": ["mpeg4"], "wmv": ["wmv2"], "gif": ["gif"]]

func verify(input: URL, output: URL, kind: String, target: String) async -> Check {
    var c = Check()
    func bad(_ s: String) { c.ok = false; c.notes.append(s) }
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: output.path, isDirectory: &isDir) else { bad("missing output"); return c }
    let size = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? NSNumber)?.int64Value ?? 0
    if !isDir.boolValue && size == 0 { bad("empty output") }
    let inFmt = Formats.format(of: input) ?? ""
    let fam = Formats.family(of: inFmt)

    switch kind {
    case "convert":
        if fam == .image {
            if target == "pdf" {
                guard let doc = PDFDocument(url: output), doc.pageCount == 1 else { bad("not a 1-page PDF"); break }
            } else {
                guard let o = imageInfo(output) else { bad("ImageIO can't read output"); break }
                if o.type != expectedImageUTI[target] { bad("type \(o.type)") }
                if inFmt != "svg", let i = imageInfo(input), (i.w, i.h) != (o.w, o.h) { bad("size \(o.w)x\(o.h) != \(i.w)x\(i.h)") }
                c.notes.append("\(o.w)x\(o.h)")
            }
        } else if fam == .audio || (fam == .video && target == "mp3") {
            guard let o = try? await FFmpeg.probe(output), let a = o.audio else { bad("no audio stream"); break }
            if !(expectedAudioCodec[target] ?? []).contains(a.codec) { bad("codec \(a.codec)") }
            if let di = try? await FFmpeg.probe(input).duration, let d = o.duration, abs(di - d) > 0.2 { bad(String(format: "duration %.2f vs %.2f", d, di)) }
            c.notes.append(a.codec)
        } else if fam == .video {
            guard let o = try? await FFmpeg.probe(output), let v = o.video else { bad("no video stream"); break }
            let srcCodec = (try? await FFmpeg.probe(input))?.video?.codec ?? ""
            var allowed = expectedVideoCodec[target] ?? []
            if ["mp4", "mov"].contains(inFmt), ["mp4", "mov"].contains(target) { allowed.append(srcCodec) } // passthrough
            if !allowed.contains(v.codec) { bad("codec \(v.codec)") }
            if let di = try? await FFmpeg.probe(input).duration, let d = o.duration, abs(di - d) > (target == "gif" || inFmt == "gif" ? 0.6 : 0.3) {
                bad(String(format: "duration %.2f vs %.2f", d, di))
            }
            c.notes.append(v.codec)
        } else if fam == .subtitle {
            let inCues = (try? Subtitles.parse(String(contentsOf: input, encoding: .utf8)))?.count ?? -1
            if target == "txt" {
                if ((try? String(contentsOf: output, encoding: .utf8)) ?? "").isEmpty { bad("empty text") }
            } else {
                let outCues = (try? Subtitles.parse(String(contentsOf: output, encoding: .utf8)))?.count ?? -2
                if inCues != outCues { bad("cues \(outCues) vs \(inCues)") }
            }
        } else if fam == .archive {
            let a = await listArchive(input), b = await listArchive(output)
            if a.isEmpty || a != b { bad("entries differ: \(b.count) vs \(a.count)") }
        }
    case "compress":
        if fam == .image, let o = imageInfo(output), let i = imageInfo(input), o.type != i.type || (o.w, o.h) != (i.w, i.h) {
            bad("image changed type/size")
        }
        c.notes.append("\(size) bytes")
    case "removeMetadata":
        let rows = await Engine.readMetadata(output)
        if rows.contains(where: { $0.value.contains("MorphSecret") || $0.key.contains("MorphSecret") }) { bad("metadata still present") }
        c.notes.append("\(rows.count) rows left")
    case "cropImage":
        guard let o = imageInfo(output) else { bad("unreadable"); break }
        if o.w != o.h { bad("not square: \(o.w)x\(o.h)") }
    case "trimVideo", "trimAudio":
        guard let o = try? await FFmpeg.probe(output), let d = o.duration else { bad("unreadable"); break }
        let want = Double(target) ?? 1.5
        if abs(d - want) > 0.15 { bad(String(format: "duration %.3f, want %.3f", d, want)) }
        c.notes.append(String(format: "%.3fs", d))
    case "muteVideo":
        guard let o = try? await FFmpeg.probe(output) else { bad("unreadable"); break }
        if o.audio != nil { bad("audio still present") }
        if o.video == nil { bad("video missing") }
    case "extractArchive":
        if !isDir.boolValue { bad("not a folder") }
        let n = (try? FileManager.default.subpathsOfDirectory(atPath: output.path).count) ?? 0
        if n == 0 { bad("folder empty") }
        c.notes.append("\(n) entries")
    default:
        bad("unknown kind \(kind)")
    }
    return c
}

func listArchive(_ url: URL) async -> [String] {
    guard let tar = ToolLocator.url(for: "bsdtar"),
          let r = try? await ProcessRunner.run(tar, ["-t", "-f", url.path]), r.status == 0 else { return [] }
    return String(decoding: r.stdout, as: UTF8.self).split(separator: "\n").map { $0.hasPrefix("./") ? String($0.dropFirst(2)) : String($0) }
        .map { $0.hasSuffix("/") ? String($0.dropLast()) : $0 }.filter { !$0.isEmpty && $0 != "." }.sorted()
}

func tagImage(_ input: URL, _ output: URL) throws {
    guard let src = CGImageSourceCreateWithURL(input as CFURL, nil), let type = CGImageSourceGetType(src),
          let dest = CGImageDestinationCreateWithURL(output as CFURL, type, 1, nil) else { fail("tag-image: can't open") }
    let props: [CFString: Any] = [
        kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "MorphSecret comment", kCGImagePropertyExifLensModel: "MorphSecret lens"],
        kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFArtist: "MorphSecret artist", kCGImagePropertyTIFFOrientation: 1],
        kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 35.0116, kCGImagePropertyGPSLatitudeRef: "N",
                                        kCGImagePropertyGPSLongitude: 135.7681, kCGImagePropertyGPSLongitudeRef: "E"],
        kCGImagePropertyIPTCDictionary: [kCGImagePropertyIPTCCaptionAbstract: "MorphSecret caption"],
    ]
    CGImageDestinationAddImageFromSource(dest, src, 0, props as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { fail("tag-image: finalize failed") }
}

// MARK: main

let args = Array(CommandLine.arguments.dropFirst())
guard let cmd = args.first else { fail("usage: morph-cli caps|convert|tool|verify|tag-image|metadata …") }

Task { @MainActor in
    do {
        switch cmd {
        case "caps":
            let reg = registry()
            var conv: [String: [String]] = [:], tools: [String: [String]] = [:]
            for input in CapabilityMatrix.inputOrder {
                let item = DraggedItem(url: URL(fileURLWithPath: "/x/a.\(Formats.fileExtension(for: input))"), isDirectory: false)
                let c = reg.targets(for: .conversions, items: [item]), t = reg.targets(for: .tools, items: [item])
                if !c.isEmpty { conv[input] = c }
                if !t.isEmpty { tools[input] = t }
            }
            print(json(["conversions": conv, "tools": tools, "unavailableTargets": Array(ImageEngine.unavailableTargets).sorted(),
                        "conversionPaths": conv.values.map(\.count).reduce(0, +),
                        "imageWritableUTIs": (CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [],
                        "macOS": ProcessInfo.processInfo.operatingSystemVersionString]))
        case "convert":
            guard args.count >= 3 else { fail("convert <input> <target>") }
            let out = try await Engine.perform(.convert(target: args[2]), items: [URL(fileURLWithPath: args[1])], context: JobContext.standalone())
            print(out.map(\.path).joined(separator: "\n"))
        case "tool":
            guard args.count >= 3 else { fail("tool <id> <input…>") }
            let id = args[1]
            var inputs: [URL] = []
            var i = 2
            while i < args.count, !args[i].hasPrefix("--") { inputs.append(URL(fileURLWithPath: args[i])); i += 1 }
            let out = try await Engine.perform(.tool(id: id, options: toolOptions(id, args)), items: inputs, context: JobContext.standalone())
            print(out.map(\.path).joined(separator: "\n"))
        case "verify":
            guard args.count >= 5 else { fail("verify <input> <output> <kind> <target>") }
            let c = await verify(input: URL(fileURLWithPath: args[1]), output: URL(fileURLWithPath: args[2]), kind: args[3], target: args[4])
            print(json(["ok": c.ok, "detail": c.notes.joined(separator: "; ")]))
            exit(c.ok ? 0 : 2)
        case "tag-image":
            guard args.count >= 3 else { fail("tag-image <in> <out>") }
            try tagImage(URL(fileURLWithPath: args[1]), URL(fileURLWithPath: args[2]))
        case "metadata":
            guard args.count >= 2 else { fail("metadata <file>") }
            for r in await Engine.readMetadata(URL(fileURLWithPath: args[1])) { print("\(r.group)\t\(r.key)\t\(r.value)") }
        default:
            fail("unknown command \(cmd)")
        }
        exit(0)
    } catch let f as JobFailure {
        fail("FAIL: \(f.message)\n\(f.details)")
    } catch {
        fail("FAIL: \(error)")
    }
}
RunLoop.main.run()
