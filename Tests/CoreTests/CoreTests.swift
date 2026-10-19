import XCTest
@testable import Capabilities
@testable import Jobs
@testable import Engines
@testable import DragKit

final class CapabilityTests: XCTestCase {
    func testMatrixTotalsMatchSpec() {
        XCTAssertEqual(CapabilityMatrix.conversions.values.map(\.count).reduce(0, +), 275)
        XCTAssertEqual(CapabilityMatrix.conversions.count, 45)
        XCTAssertEqual(CapabilityMatrix.toolDefs.count, 26)
        XCTAssertEqual(CapabilityMatrix.actionOrder.count, 6)
    }

    /// Spec §4.2 M1: images 57, audio 56, video 48 (incl. GIF), subtitles 4, archives 9 = 174.
    func testM1ConversionScopeIs174() {
        let reg = CapabilityRegistry()
        var perFamily: [FormatFamily: Int] = [:]
        for (input, targets) in CapabilityMatrix.conversions {
            guard let fam = Formats.family(of: input), reg.enabledConversionFamilies.contains(fam) else { continue }
            perFamily[fam, default: 0] += targets.count
        }
        XCTAssertEqual(perFamily[.image], 57)
        XCTAssertEqual(perFamily[.audio], 56)
        XCTAssertEqual(perFamily[.video], 48)
        XCTAssertEqual(perFamily[.subtitle], 4)
        XCTAssertEqual(perFamily[.archive], 9)
        XCTAssertEqual(perFamily.values.reduce(0, +), 174)
    }

    func item(_ name: String, dir: Bool = false) -> DraggedItem {
        DraggedItem(url: URL(fileURLWithPath: "/tmp/\(name)"), isDirectory: dir)
    }

    func testWheelTargets() {
        let reg = CapabilityRegistry()
        XCTAssertEqual(reg.targets(for: .conversions, items: [item("a.heic")]), ["jpg", "png", "webp", "tiff", "avif", "bmp", "pdf"])
        XCTAssertEqual(reg.targets(for: .tools, items: [item("a.mov")]), ["compress", "removeMetadata", "muteVideo", "trimVideo"])
        XCTAssertEqual(reg.targets(for: .tools, items: [item("a.jpg"), item("b.jpg")]), ["compress", "removeMetadata", "cropImage"])
        XCTAssertEqual(reg.targets(for: .tools, items: [item("x.gif")]), ["removeMetadata"])
        XCTAssertEqual(reg.targets(for: .conversions, items: [item("p.zip")]), ["tar", "gz"])
        XCTAssertEqual(reg.targets(for: .conversions, items: [item("a.jpg"), item("b.png")]), [])
        XCTAssertEqual(reg.targets(for: .actions, items: [item("Invoices", dir: true)]).count, 6)
        XCTAssertEqual(reg.targets(for: .conversions, items: [item("doc.pdf")]), [], "PDF conversions are M2/M3")
        XCTAssertEqual(reg.targets(for: .tools, items: [item("doc.pdf")]), ["compress", "removeMetadata"])
        let noAVIF = CapabilityRegistry(unavailableTargets: ["avif"])
        XCTAssertFalse(noAVIF.targets(for: .conversions, items: [item("a.png")]).contains("avif"))
    }

    func testFormatDetection() {
        XCTAssertEqual(Formats.format(of: URL(fileURLWithPath: "/x/a.JPEG")), "jpg")
        XCTAssertEqual(Formats.format(of: URL(fileURLWithPath: "/x/a.tar.gz")), "gz")
        XCTAssertEqual(Formats.format(of: URL(fileURLWithPath: "/x/a.tgz")), "gz")
        XCTAssertEqual(Formats.format(of: URL(fileURLWithPath: "/x/a.tif")), "tiff")
        XCTAssertNil(Formats.format(of: URL(fileURLWithPath: "/x/a.xyz")))
        XCTAssertNil(Formats.format(of: URL(fileURLWithPath: "/x/README")))
    }

    func testEmptyText() {
        let reg = CapabilityRegistry()
        XCTAssertEqual(reg.emptyText(for: .tools, items: [item("r.txt")], keys: [:]), "No editing tools for TXT.\nTap ⇧ to convert or ⌃ for actions.")
    }
}

final class NamingTests: XCTestCase {
    func testBaseName() {
        XCTAssertEqual(Naming.baseName("kyoto-trip.heic"), "kyoto-trip")
        XCTAssertEqual(Naming.baseName("project.tar.gz"), "project")
        XCTAssertEqual(Naming.baseName("project.tgz"), "project")
        XCTAssertEqual(Naming.baseName("README"), "README")
        XCTAssertEqual(Naming.baseName(".hidden"), ".hidden")
    }

    func testStems() {
        let heic = URL(fileURLWithPath: "/t/kyoto-trip.heic")
        XCTAssertTrue(Naming.conversionStem(source: heic, target: "png") == ("kyoto-trip", "png"))
        XCTAssertTrue(Naming.conversionStem(source: URL(fileURLWithPath: "/t/p.zip"), target: "gz") == ("p", "tar.gz"))
        XCTAssertTrue(Naming.toolStem(source: URL(fileURLWithPath: "/t/harbor.mov"), tool: "trimVideo") == ("harbor Trimmed", "mov"))
        XCTAssertTrue(Naming.toolStem(source: URL(fileURLWithPath: "/t/a.wav"), tool: "compress") == ("a Compressed", "flac"))
        XCTAssertTrue(Naming.toolStem(source: URL(fileURLWithPath: "/t/p.zip"), tool: "extractArchive") == ("p Extracted", nil))
        XCTAssertTrue(Naming.toolStem(source: URL(fileURLWithPath: "/t/x.jpg"), tool: "removeMetadata") == ("x No Metadata", "jpg"))
    }

    func testCandidates() {
        XCTAssertEqual(Naming.candidate(stem: "a", ext: "png", attempt: 1), "a.png")
        XCTAssertEqual(Naming.candidate(stem: "a", ext: "png", attempt: 2), "a 2.png")
        XCTAssertEqual(Naming.candidate(stem: "a Clips", ext: nil, attempt: 3), "a Clips 3")
    }

    func testAllocatorNeverHandsOutTheSameNameUnderConcurrency() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("morph-alloc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertTrue(FileManager.default.createFile(atPath: dir.appendingPathComponent("photo.png").path, contents: Data([1])))
        let urls = try await withThrowingTaskGroup(of: URL.self) { group -> [URL] in
            for _ in 0..<20 { group.addTask { try await NameAllocator.shared.reserve(in: dir, stem: "photo", ext: "png") } }
            return try await group.reduce(into: []) { $0.append($1) }
        }
        XCTAssertEqual(Set(urls.map(\.lastPathComponent)).count, 20)
        XCTAssertFalse(urls.map(\.lastPathComponent).contains("photo.png"), "existing file must never be reused")
        XCTAssertTrue(urls.map(\.lastPathComponent).contains("photo 2.png"))
        // release removes only empty placeholders
        await NameAllocator.shared.release(urls[0])
        XCTAssertFalse(FileManager.default.fileExists(atPath: urls[0].path))
        let folder = try await NameAllocator.shared.reserve(in: dir, stem: "photo Extracted", ext: nil)
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDir) && isDir.boolValue)
    }

    func testSafeWriteCommitReplacesOnlyPlaceholder() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("morph-sw-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let dest = try await NameAllocator.shared.reserve(in: dir, stem: "out", ext: "tar.gz")
        let tmp = SafeWrite.tempURL(for: dest)
        XCTAssertTrue(tmp.lastPathComponent.hasPrefix(".morph-") && tmp.lastPathComponent.hasSuffix(".tar.gz"))
        try Data("hello".utf8).write(to: tmp)
        try SafeWrite.commit(tmp, to: dest)
        XCTAssertEqual(try String(contentsOf: dest, encoding: .utf8), "hello")
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmp.path))
    }
}

final class JobQueueTests: XCTestCase {
    func testRunsAtMostNConcurrentlyAndCancels() async throws {
        let q = JobQueue(maxConcurrent: 2)
        let counter = Counter()
        var jobs: [Job] = []
        for _ in 0..<5 {
            jobs.append(q.enqueue(title: "t", subject: "s") { ctx in
                await counter.enter()
                for _ in 0..<20 { try ctx.checkCancelled(); try await Task.sleep(nanoseconds: 5_000_000) }
                await counter.leave()
                return []
            })
        }
        jobs[4].cancel()
        for _ in 0..<200 where !jobs.allSatisfy({ if case .queued = $0.state { return false }; if case .running = $0.state { return false }; return true }) {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let maxSeen = await counter.max
        XCTAssertLessThanOrEqual(maxSeen, 2)
        XCTAssertEqual(jobs[4].state, .cancelled)
        XCTAssertEqual(jobs[0].state, .succeeded([]))
    }

    actor Counter {
        var now = 0, max = 0
        func enter() { now += 1; max = Swift.max(max, now) }
        func leave() { now -= 1 }
    }
}

final class SubtitleTests: XCTestCase {
    let srt = "\u{FEFF}1\r\n00:00:01,000 --> 00:00:02,500\r\n<i>Hello</i>\r\nworld\r\n\r\n2\r\n00:01:02,250 --> 00:01:04,000\r\n{\\an8}Second\r\n"

    func testSRTtoVTTKeepsTiming() throws {
        let cues = try Subtitles.parse(srt)
        XCTAssertEqual(cues.count, 2)
        XCTAssertEqual(cues[1].start, 62.25, accuracy: 0.0001)
        let vtt = Subtitles.vtt(cues)
        XCTAssertTrue(vtt.hasPrefix("WEBVTT\n\n00:00:01.000 --> 00:00:02.500\n<i>Hello</i>\nworld\n"))
        let back = try Subtitles.parse(vtt)
        XCTAssertEqual(back, cues)
        XCTAssertTrue(Subtitles.srt(back).hasPrefix("1\n00:00:01,000 --> 00:00:02,500\n"))
    }

    func testVTTWithHeaderNotesSettingsAndShortTimestamps() throws {
        let vtt = "WEBVTT - title\nKind: captions\n\nNOTE a comment\n\nintro\n00:05.000 --> 00:06.000 align:start position:10%\nHi\n"
        let cues = try Subtitles.parse(vtt)
        XCTAssertEqual(cues, [Subtitles.Cue(start: 5, end: 6, text: "Hi")])
    }

    func testPlainText() throws {
        XCTAssertEqual(Subtitles.plainText(try Subtitles.parse(srt)), "Hello\nworld\nSecond\n")
    }

    func testRejectsNonSubtitle() {
        XCTAssertThrowsError(try Subtitles.parse("just some text"))
    }
}

final class MetadataStripTests: XCTestCase {
    func seg(_ marker: UInt8, _ body: [UInt8]) -> [UInt8] {
        let n = body.count + 2
        return [0xFF, marker, UInt8(n >> 8), UInt8(n & 0xFF)] + body
    }
    func exif(orientation o: UInt16) -> [UInt8] {
        var e: [UInt8] = Array("Exif".utf8) + [0, 0]
        e += [0x49, 0x49, 0x2A, 0x00, 0x08, 0, 0, 0, 0x02, 0x00]
        e += [0x12, 0x01, 0x03, 0x00, 0x01, 0, 0, 0, UInt8(o), 0, 0, 0]
        e += [0x0F, 0x01, 0x02, 0x00, 0x04, 0, 0, 0, 0x41, 0x42, 0x43, 0x00, 0, 0, 0, 0]
        return e
    }

    func testJPEGKeepsOrientationICCAndPrimaryImageOnly() throws {
        var b: [UInt8] = [0xFF, 0xD8]
        b += seg(0xE0, Array("JFIF".utf8) + [0, 1, 1, 0, 0, 1, 0, 1, 0, 0])
        b += seg(0xE1, exif(orientation: 6))
        b += seg(0xE1, Array("http://ns.adobe.com/xap/1.0/".utf8) + [0] + Array("<x/>".utf8))
        b += seg(0xE2, Array("ICC_PROFILE".utf8) + [0, 1, 1, 9, 9])
        b += seg(0xED, Array("Photoshop 3.0".utf8) + [0])
        b += seg(0xFE, Array("secret comment".utf8))
        b += seg(0xDB, [0] + Array(repeating: 1, count: 64))
        b += seg(0xDA, [1, 1, 0, 0, 63, 0])
        b += [0x12, 0xFF, 0x00, 0x34, 0xFF, 0xD9]
        b += [0xFF, 0xD8]                      // appended gain map image
        b += seg(0xE1, exif(orientation: 1))
        b += [0xFF, 0xD9]
        let out = [UInt8](try MetadataStrip.strip(Data(b), format: .jpeg))
        let s = String(decoding: out, as: UTF8.self)
        XCTAssertFalse(s.contains("secret"))
        XCTAssertFalse(s.contains("adobe"))
        XCTAssertFalse(s.contains("Photoshop"))
        XCTAssertTrue(s.contains("ICC_PROFILE"))
        XCTAssertTrue(s.contains("JFIF"))
        XCTAssertFalse(s.contains("ABC"), "other EXIF tags removed")
        XCTAssertEqual(Array(out.suffix(2)), [0xFF, 0xD9])
        XCTAssertEqual(out.filter { $0 == 0xD8 }.count, 1, "appended secondary image dropped")
        // minimal EXIF with orientation 6 present, right after JFIF
        let exifAt = out.indices.first { out[$0] == 0xFF && out[$0 + 1] == 0xE1 }!
        let tiff = Array(out[(exifAt + 10)...])
        XCTAssertEqual(MetadataStrip.orientation(tiff: tiff), 6)
        XCTAssertEqual(out[2...3], [0xFF, 0xE0])
    }

    func chunk(_ t: String, _ d: [UInt8]) -> [UInt8] {
        let n = d.count
        return [UInt8(n >> 24), UInt8(n >> 16 & 0xFF), UInt8(n >> 8 & 0xFF), UInt8(n & 0xFF)] + Array(t.utf8) + d + [0, 0, 0, 0]
    }

    func testPNGDropsTextChunks() throws {
        var b: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        b += chunk("IHDR", [UInt8](repeating: 0, count: 13))
        b += chunk("tEXt", Array("Author\0me".utf8))
        b += chunk("iCCP", [1, 2])
        b += chunk("eXIf", [9])
        b += chunk("IDAT", [7, 7])
        b += chunk("IEND", [])
        let s = String(decoding: try MetadataStrip.strip(Data(b), format: .png), as: UTF8.self)
        XCTAssertFalse(s.contains("tEXt")); XCTAssertFalse(s.contains("Author")); XCTAssertFalse(s.contains("eXIf"))
        XCTAssertTrue(s.contains("IHDR")); XCTAssertTrue(s.contains("iCCP")); XCTAssertTrue(s.contains("IDAT")); XCTAssertTrue(s.hasSuffix("IEND\0\0\0\0"))
    }

    func testGIFKeepsLoopDropsCommentsAndXMP() throws {
        var b: [UInt8] = Array("GIF89a".utf8) + [1, 0, 1, 0, 0x00, 0, 0]
        b += [0x21, 0xFE, 5] + Array("hello".utf8) + [0]
        b += [0x21, 0xFF, 11] + Array("NETSCAPE2.0".utf8) + [3, 1, 0, 0, 0]
        b += [0x21, 0xFF, 11] + Array("XMP DataXMP".utf8) + [4] + Array("<x/>".utf8) + [0]
        b += [0x21, 0xF9, 4, 0, 10, 0, 0, 0]
        b += [0x2C, 0, 0, 0, 0, 1, 0, 1, 0, 0, 2, 2, 0x4C, 0x01, 0, 0x3B]
        let s = String(decoding: try MetadataStrip.strip(Data(b), format: .gif), as: UTF8.self)
        XCTAssertFalse(s.contains("hello")); XCTAssertFalse(s.contains("XMP"))
        XCTAssertTrue(s.contains("NETSCAPE2.0")); XCTAssertTrue(s.hasSuffix(";"))
    }

    func testWebPDropsExifXmpAndClearsFlags() throws {
        func c(_ t: String, _ d: [UInt8]) -> [UInt8] {
            let n = d.count
            return Array(t.utf8) + [UInt8(n & 0xFF), UInt8(n >> 8 & 0xFF), 0, 0] + d + (n & 1 == 1 ? [0] : [])
        }
        var body: [UInt8] = Array("WEBP".utf8)
        body += c("VP8X", [0x0C, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        body += c("VP8 ", [1, 2, 3])
        body += c("EXIF", exif(orientation: 1))
        body += c("XMP ", Array("<x/>".utf8))
        var riff: [UInt8] = Array("RIFF".utf8)
        riff += [UInt8(body.count & 0xFF), UInt8(body.count >> 8), 0, 0]
        riff += body
        let out = [UInt8](try MetadataStrip.strip(Data(riff), format: .webp))
        let s = String(decoding: out, as: UTF8.self)
        XCTAssertFalse(s.contains("EXIF")); XCTAssertFalse(s.contains("XMP "))
        XCTAssertEqual(out[20] & 0x0C, 0, "EXIF/XMP flags cleared")
        XCTAssertEqual(Int(out[4]) | Int(out[5]) << 8, out.count - 8, "RIFF size updated")
    }
}

final class GeometryTests: XCTestCase {
    func testHitTest() {
        XCTAssertNil(WheelGeometry.hitTest(dx: 0, dy: 0, count: 7), "centre cancels")
        XCTAssertEqual(WheelGeometry.hitTest(dx: 0, dy: -110, count: 7), 0, "petal 0 is up")
        XCTAssertEqual(WheelGeometry.hitTest(dx: 110, dy: 0, count: 4), 1, "clockwise on screen (y-down)")
        XCTAssertEqual(WheelGeometry.hitTest(dx: 0, dy: 110, count: 2), 1)
        XCTAssertEqual(WheelGeometry.hitTest(dx: 0, dy: 110, count: 1), 0, "single petal is a full ring")
        XCTAssertNil(WheelGeometry.hitTest(dx: 0, dy: -200, count: 7), "outside ring")
        XCTAssertNil(WheelGeometry.hitTest(dx: 0, dy: -110, count: 0))
    }

    /// Spec §6 A9: smallest petal (9-petal wheel) is ≈70 pt wide at mid-radius and 98 pt deep.
    func testSmallestPetalSize() {
        let mid = (WheelGeometry.rIn + WheelGeometry.rOut) / 2
        let width = 2 * Double.pi * mid / 9 - WheelGeometry.gap
        XCTAssertEqual(width, 70.5, accuracy: 0.5)
        XCTAssertEqual(WheelGeometry.rOut - WheelGeometry.rIn, 98)
    }
}

final class RecipeTests: XCTestCase {
    func testPlaceholdersResolve() throws {
        let info = FFmpeg.parse(["format": ["duration": "10.0", "bit_rate": "5000000"],
                                 "streams": [["codec_type": "video", "codec_name": "h264", "bit_rate": "4000000"],
                                             ["codec_type": "audio", "codec_name": "flac", "bits_per_raw_sample": "24", "sample_fmt": "s32"]]])
        let mp4 = try FFmpeg.recipeArgs("video.mp4", source: info)
        XCTAssertTrue(mp4.contains("4000k"))
        XCTAssertFalse(mp4.joined().contains("{"))
        XCTAssertEqual(try FFmpeg.recipeArgs("audio.wav", source: info), ["-vn", "-c:a", "pcm_s24le"])
        XCTAssertTrue(FFmpegRecipes.all["video.mp4"]!.requiresVideoToolbox)
        XCTAssertFalse(FFmpegRecipes.all["video.webm"]!.requiresVideoToolbox)
        // Every audio/video conversion target in the matrix has a recipe (FFmpeg path).
        for t in ["mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "wma"] { XCTAssertNotNil(FFmpegRecipes.all["audio.\(t)"], t) }
        for t in ["mp4", "mov", "mkv", "webm", "avi", "wmv", "gif", "mp3"] { XCTAssertNotNil(FFmpegRecipes.all["video.\(t)"], t) }
    }

    func testCompressTargets() {
        var o = CompressOptions()
        XCTAssertNil(o.targetSize(original: 1000))
        o.goal = .percentage; o.percentage = 40
        XCTAssertEqual(o.targetSize(original: 1000), 600)
        XCTAssertEqual(CropAspect.square.centeredRect(width: 400, height: 300).w, 300)
    }
}
