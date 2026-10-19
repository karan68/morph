import XCTest
import ImageIO
@testable import Engines
@testable import Jobs
import Capabilities

/// macOS-only engine tests that don't need the bundled helpers (the golden matrix covers FFmpeg/bsdtar paths).
final class EngineTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("morph-engine-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    func makePNG(width: Int, height: Int, orientation: Int = 1) throws -> URL {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.36, green: 0.28, blue: 0.96, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        let url = dir.appendingPathComponent("t.jpg")
        let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, ctx.makeImage()!, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return url
    }

    func testSVGIntrinsicSize() {
        XCTAssertEqual(SVGRasterizer.intrinsicSize(#"<svg width="200" height="120" xmlns="http://www.w3.org/2000/svg">"#), CGSize(width: 200, height: 120))
        XCTAssertEqual(SVGRasterizer.intrinsicSize(#"<svg viewBox="0 0 24 12">"#), CGSize(width: 24, height: 12))
        XCTAssertEqual(SVGRasterizer.intrinsicSize(#"<svg width="100%" viewBox="0,0,50,40">"#), CGSize(width: 50, height: 40))
        XCTAssertNil(SVGRasterizer.intrinsicSize("<html>"))
    }

    func testRotatedJPEGConvertsToUprightPNG() async throws {
        // 40×20 stored pixels with orientation 6 (rotate 90° CW) → displayed 20×40.
        let src = try makePNG(width: 40, height: 20, orientation: 6)
        let out = dir.appendingPathComponent("t.png")
        try await ImageEngine.convert(src, to: "png", output: out, context: nil)
        let s = CGImageSourceCreateWithURL(out as CFURL, nil)!
        let p = CGImageSourceCopyPropertiesAtIndex(s, 0, nil) as! [CFString: Any]
        XCTAssertEqual(p[kCGImagePropertyPixelWidth] as? Int, 20)
        XCTAssertEqual(p[kCGImagePropertyPixelHeight] as? Int, 40)
        XCTAssertEqual((p[kCGImagePropertyOrientation] as? Int) ?? 1, 1)
    }

    func testCropSquareAndMetadataStripOfJPEG() async throws {
        let src = try makePNG(width: 64, height: 32)
        let crop = dir.appendingPathComponent("c.jpg")
        var o = CropOptions(); o.aspect = .square
        try await ImageEngine.crop(src, options: o, output: crop, context: nil)
        XCTAssertEqual(try ImageEngine.pixelSizeSync(crop), CGSize(width: 32, height: 32))
        let stripped = dir.appendingPathComponent("s.jpg")
        try await ImageEngine.removeMetadata(src, output: stripped, context: nil)
        XCTAssertNotNil(CGImageSourceCreateWithURL(stripped as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
    }

    func testWritableTargetsReported() {
        XCTAssertTrue(ImageEngine.writableTargets.isSuperset(of: ["jpg", "png", "tiff", "bmp", "pdf", "webp"]))
    }
}

extension ImageEngine {
    static func pixelSizeSync(_ url: URL) throws -> CGSize {
        let s = CGImageSourceCreateWithURL(url as CFURL, nil)!
        let p = CGImageSourceCopyPropertiesAtIndex(s, 0, nil) as! [CFString: Any]
        return CGSize(width: p[kCGImagePropertyPixelWidth] as! Int, height: p[kCGImagePropertyPixelHeight] as! Int)
    }
}
