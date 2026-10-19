#if canImport(WebKit) && canImport(AppKit)
import AppKit
import WebKit
import Jobs
import Capabilities

/// Rasterizes SVG with WebKit (spec §7.2: "resvg or WKWebView snapshot"; Morph uses WKWebView — no extra dependency).
/// Transparent areas stay transparent: the page is rendered twice (white and black backdrop) and alpha is
/// recovered per pixel, so no private WebKit API is needed.
@MainActor
public final class SVGRasterizer: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<Void, Error>?

    public static func rasterize(_ url: URL, maxDimension: Double = 4096) async throws -> CGImage {
        let r = SVGRasterizer()
        return try await r.run(url, maxDimension: maxDimension)
    }

    private func run(_ url: URL, maxDimension: Double) async throws -> CGImage {
        let svg = try String(contentsOf: url, encoding: .utf8)
        let size = Self.intrinsicSize(svg) ?? CGSize(width: 1024, height: 1024)
        let scale = min(1, maxDimension / max(size.width, size.height))
        let w = max(1, (size.width * scale).rounded()), h = max(1, (size.height * scale).rounded())
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: w, height: h), configuration: config)
        wv.navigationDelegate = self
        webView = wv
        guard let white = try await render(svg: svg, base: url, w: w, h: h, background: "#fff"),
              let black = try await render(svg: svg, base: url, w: w, h: h, background: "#000") else {
            throw JobFailure("Morph couldn't draw this SVG.")
        }
        return try Self.mergeAlpha(white: white, black: black)
    }

    private func render(svg: String, base: URL, w: Double, h: Double, background: String) async throws -> CGImage? {
        guard let wv = webView else { return nil }
        let b64 = Data(svg.utf8).base64EncodedString()
        let html = """
        <!doctype html><html><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'">
        <style>html,body{margin:0;padding:0;background:\(background);overflow:hidden}
        img{display:block;width:\(Int(w))px;height:\(Int(h))px}</style></head>
        <body><img src="data:image/svg+xml;base64,\(b64)"></body></html>
        """
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            continuation = c
            // No base URL + CSP above: the SVG can't pull remote resources (spec §7.3, local-only).
            wv.loadHTMLString(html, baseURL: nil)
        }
        // Give the image decode a frame to settle.
        try await Task.sleep(nanoseconds: 50_000_000)
        let cfg = WKSnapshotConfiguration()
        cfg.rect = CGRect(x: 0, y: 0, width: w, height: h)
        cfg.snapshotWidth = NSNumber(value: w)
        let image: NSImage = try await withCheckedThrowingContinuation { c in
            wv.takeSnapshot(with: cfg) { img, err in
                if let img = img { c.resume(returning: img) } else { c.resume(throwing: err ?? JobFailure("SVG snapshot failed.")) }
            }
        }
        var rect = CGRect(x: 0, y: 0, width: w, height: h)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume(); continuation = nil
    }
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error); continuation = nil
    }
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error); continuation = nil
    }

    /// width/height attributes (px or unitless), else viewBox.
    nonisolated static func intrinsicSize(_ svg: String) -> CGSize? {
        guard let tagRange = svg.range(of: "<svg[^>]*>", options: .regularExpression) else { return nil }
        let tag = String(svg[tagRange])
        func attr(_ name: String) -> String? {
            guard let r = tag.range(of: "\\s\(name)\\s*=\\s*[\"']([^\"']+)[\"']", options: .regularExpression) else { return nil }
            let m = String(tag[r])
            return m.split(separator: "=", maxSplits: 1).last.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"' ")) }
        }
        func px(_ s: String?) -> Double? {
            guard let s = s, !s.hasSuffix("%") else { return nil }
            return Double(s.replacingOccurrences(of: "px", with: "").trimmingCharacters(in: .whitespaces))
        }
        if let w = px(attr("width")), let h = px(attr("height")), w > 0, h > 0 { return CGSize(width: w, height: h) }
        if let vb = attr("viewBox") {
            let n = vb.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
            if n.count == 4, n[2] > 0, n[3] > 0 { return CGSize(width: n[2], height: n[3]) }
        }
        return nil
    }

    /// alpha = 1 − (white − black); colour = black / alpha (premultiplied on black).
    nonisolated static func mergeAlpha(white: CGImage, black: CGImage) throws -> CGImage {
        let w = white.width, h = white.height
        guard black.width == w, black.height == h else { return white }
        func pixels(_ img: CGImage) -> [UInt8]? {
            var buf = [UInt8](repeating: 0, count: w * h * 4)
            guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
            return buf
        }
        guard let pw = pixels(white), let pb = pixels(black) else { return white }
        var out = [UInt8](repeating: 0, count: w * h * 4)
        for i in stride(from: 0, to: out.count, by: 4) {
            let a = 255 - min(255, max(0, (Int(pw[i]) - Int(pb[i]) + Int(pw[i + 1]) - Int(pb[i + 1]) + Int(pw[i + 2]) - Int(pb[i + 2])) / 3))
            out[i] = pb[i]; out[i + 1] = pb[i + 1]; out[i + 2] = pb[i + 2]   // premultiplied colour = render on black
            out[i + 3] = UInt8(a)
        }
        let provider = CGDataProvider(data: Data(out) as CFData)!
        guard let img = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return white }
        return img
    }
}
#endif
