import Foundation
import Jobs

/// SRT ↔ VTT and subtitle → TXT, keeping cue timing (M1 subtitle paths: 4).
public enum Subtitles {
    public struct Cue: Equatable {
        public var start: Double   // seconds
        public var end: Double
        public var text: String     // may contain line breaks
    }

    public static func parse(_ raw: String) throws -> [Cue] {
        var s = raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        if s.hasPrefix("\u{FEFF}") { s.removeFirst() }
        var cues: [Cue] = []
        let blocks = s.components(separatedBy: "\n\n")
        for block in blocks {
            var lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            while let f = lines.first, f.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeFirst() }
            guard !lines.isEmpty else { continue }
            let first = lines[0].trimmingCharacters(in: .whitespaces)
            if first.hasPrefix("WEBVTT") || first.hasPrefix("NOTE") || first == "STYLE" || first == "REGION" { continue }
            guard let ti = lines.firstIndex(where: { $0.contains("-->") }), ti <= 1 else { continue }
            let parts = lines[ti].components(separatedBy: "-->")
            guard parts.count == 2,
                  let start = timestamp(parts[0].trimmingCharacters(in: .whitespaces)),
                  let end = timestamp(parts[1].trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init) ?? "")
            else { continue }
            let text = lines[(ti + 1)...].joined(separator: "\n").trimmingCharacters(in: .newlines)
            cues.append(Cue(start: start, end: end, text: text))
        }
        if cues.isEmpty { throw JobFailure("No subtitle cues found. The file may not be SRT or WebVTT.") }
        return cues
    }

    /// Accepts `hh:mm:ss,mmm`, `hh:mm:ss.mmm` and `mm:ss.mmm`.
    static func timestamp(_ t: String) -> Double? {
        let parts = t.replacingOccurrences(of: ",", with: ".").split(separator: ":")
        guard parts.count == 2 || parts.count == 3 else { return nil }
        let nums = parts.compactMap { Double($0) }
        guard nums.count == parts.count else { return nil }
        return nums.count == 3 ? nums[0] * 3600 + nums[1] * 60 + nums[2] : nums[0] * 60 + nums[1]
    }

    static func format(_ seconds: Double, separator: String) -> String {
        let ms = Int((seconds * 1000).rounded())
        let h = ms / 3_600_000, m = (ms / 60_000) % 60, s = (ms / 1000) % 60, r = ms % 1000
        return String(format: "%02d:%02d:%02d%@%03d", h, m, s, separator, r)
    }

    public static func srt(_ cues: [Cue]) -> String {
        cues.enumerated().map { i, c in
            "\(i + 1)\n\(format(c.start, separator: ",")) --> \(format(c.end, separator: ","))\n\(c.text)\n"
        }.joined(separator: "\n")
    }

    public static func vtt(_ cues: [Cue]) -> String {
        "WEBVTT\n\n" + cues.map { c in
            "\(format(c.start, separator: ".")) --> \(format(c.end, separator: "."))\n\(c.text)\n"
        }.joined(separator: "\n")
    }

    /// Plain words only: tags (`<i>`, `<c.x>`, `{\an8}`) removed, one cue per line group.
    public static func plainText(_ cues: [Cue]) -> String {
        cues.map { c in
            var t = c.text
            t = t.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: "\\{\\\\[^}]*\\}", with: "", options: .regularExpression)
            return t.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }.joined(separator: "\n") + "\n"
    }

    /// Converts `input` to `target` (srt | vtt | txt) and writes UTF-8 to `output`.
    public static func convert(input: URL, target: String, output: URL) throws {
        let data = try Data(contentsOf: input)
        let raw = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        let cues = try parse(raw)
        let text: String
        switch target {
        case "srt": text = srt(cues)
        case "vtt": text = vtt(cues)
        case "txt": text = plainText(cues)
        default: throw JobFailure("Subtitles can't be converted to \(target.uppercased()).")
        }
        try Data(text.utf8).write(to: output)
    }
}
