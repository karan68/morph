#if canImport(AppKit)
import AppKit
import SwiftUI
import ImageIO
import Engines
import Jobs
import Capabilities
import A11y

/// Crop Image window: drag the area, pick an aspect, or enter exact output dimensions.
/// For a selection, the chosen aspect is applied as a centred crop to every image.
struct CropImageView: View {
    let items: [URL]
    let done: (ToolOptions?) -> Void
    @State private var image: CGImage?
    @State private var aspect: CropAspect = .free
    @State private var rect = CGRect.zero          // pixel space, origin top-left
    @State private var outW = ""
    @State private var outH = ""
    @State private var dragStart: CGRect?

    var single: Bool { items.count == 1 }
    var pixelSize: CGSize { image.map { CGSize(width: $0.width, height: $0.height) } ?? .zero }

    var body: some View {
        ToolChrome(title: "Crop Image", primary: "Apply", primaryEnabled: !single || rect.width >= 1, onReset: reset, onCancel: { done(nil) }, onPrimary: apply) {
            VStack(alignment: .leading, spacing: 14) {
                if single {
                    preview.frame(width: 500, height: 340)
                } else {
                    FileHeader(url: items[0], subtitle: "\(items.count) images · centred crop at the chosen aspect")
                }
                Row(label: "Aspect") {
                    MorphSegmented(label: "Aspect ratio", options: CropAspect.allCases.map { ($0, $0.rawValue) }, selection: $aspect)
                }
                Row(label: "Output size") {
                    TextField("W", text: $outW).frame(width: 70).textFieldStyle(.roundedBorder).accessibilityLabel("Output width in pixels")
                    Text("×").foregroundColor(Color(Theme.ink3))
                    TextField("H", text: $outH).frame(width: 70).textFieldStyle(.roundedBorder).accessibilityLabel("Output height in pixels")
                    Text("px").foregroundColor(Color(Theme.ink2))
                    Text("Leave empty to keep the cropped size").foregroundColor(Color(Theme.ink3)).font(.system(size: 12))
                }
                if single {
                    Text("Selection: \(Int(rect.width)) × \(Int(rect.height)) px").foregroundColor(Color(Theme.ink3)).font(.system(size: 12).monospacedDigit())
                }
                Text("Saves as **\(Naming.candidate(stem: Naming.toolStem(source: items[0], tool: "cropImage").stem, ext: Naming.toolStem(source: items[0], tool: "cropImage").ext, attempt: 1))** next to the original.")
                    .foregroundColor(Color(Theme.ink3))
            }
        }
        .frame(width: 540)
        .task { await load() }
        .onChange(of: aspect) { a in
            let r = a.centeredRect(width: Double(pixelSize.width), height: Double(pixelSize.height))
            rect = CGRect(x: r.x, y: r.y, width: r.w, height: r.h)
        }
    }

    var preview: some View {
        GeometryReader { geo in
            let s = scale(in: geo.size)
            let ox = (geo.size.width - pixelSize.width * s) / 2, oy = (geo.size.height - pixelSize.height * s) / 2
            let vr = CGRect(x: ox + rect.minX * s, y: oy + rect.minY * s, width: rect.width * s, height: rect.height * s)
            ZStack(alignment: .topLeading) {
                if let img = image {
                    Image(decorative: img, scale: 1).resizable().interpolation(.high)
                        .frame(width: pixelSize.width * s, height: pixelSize.height * s).offset(x: ox, y: oy)
                }
                // Dim outside the crop
                Path { p in p.addRect(CGRect(origin: .zero, size: geo.size)); p.addRect(vr) }
                    .fill(Color.white.opacity(0.55), style: FillStyle(eoFill: true))
                Rectangle().stroke(Color(Theme.accent), lineWidth: 2).frame(width: vr.width, height: vr.height).offset(x: vr.minX, y: vr.minY)
                    .gesture(DragGesture().onChanged { g in move(by: g.translation, scale: s) }.onEnded { _ in dragStart = nil })
                    .accessibilityLabel("Crop area")
                    .accessibilityValue("\(Int(rect.width)) by \(Int(rect.height)) pixels")
                ForEach(0..<4, id: \.self) { corner in
                    let p = CGPoint(x: corner % 2 == 0 ? vr.minX : vr.maxX, y: corner < 2 ? vr.minY : vr.maxY)
                    Circle().fill(Color.white).overlay(Circle().stroke(Color(Theme.accent), lineWidth: 2))
                        .frame(width: 14, height: 14).offset(x: p.x - 7, y: p.y - 7)
                        .gesture(DragGesture().onChanged { g in resize(corner: corner, by: g.translation, scale: s) }.onEnded { _ in dragStart = nil })
                        .accessibilityHidden(true)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(Theme.ink).opacity(0.05)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func scale(in size: CGSize) -> CGFloat {
        guard pixelSize.width > 0 else { return 1 }
        return min(size.width / pixelSize.width, size.height / pixelSize.height)
    }

    func move(by t: CGSize, scale s: CGFloat) {
        if dragStart == nil { dragStart = rect }
        guard let st = dragStart else { return }
        var r = st.offsetBy(dx: t.width / s, dy: t.height / s)
        r.origin.x = min(max(0, r.minX), pixelSize.width - r.width)
        r.origin.y = min(max(0, r.minY), pixelSize.height - r.height)
        rect = r
    }

    func resize(corner: Int, by t: CGSize, scale s: CGFloat) {
        if dragStart == nil { dragStart = rect }
        guard let st = dragStart else { return }
        var minX = st.minX, minY = st.minY, maxX = st.maxX, maxY = st.maxY
        if corner % 2 == 0 { minX += t.width / s } else { maxX += t.width / s }
        if corner < 2 { minY += t.height / s } else { maxY += t.height / s }
        minX = max(0, min(minX, maxX - 8)); maxX = min(pixelSize.width, max(maxX, minX + 8))
        minY = max(0, min(minY, maxY - 8)); maxY = min(pixelSize.height, max(maxY, minY + 8))
        var r = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        if let ratio = aspect.ratio {
            let h = r.width / ratio
            if corner < 2 { r.origin.y = r.maxY - h }
            r.size.height = h
            if r.minY < 0 || r.maxY > pixelSize.height { return }
        }
        rect = r.integral
    }

    func load() async {
        guard single, let src = CGImageSourceCreateWithURL(items[0] as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else { return }
        let w = props[kCGImagePropertyPixelWidth] as? Int ?? 0, h = props[kCGImagePropertyPixelHeight] as? Int ?? 0
        let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                                     kCGImageSourceThumbnailMaxPixelSize: max(w, h, 1)]
        image = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
        reset()
    }

    func reset() {
        aspect = .free
        rect = CGRect(origin: .zero, size: pixelSize)
        outW = ""; outH = ""
    }

    func apply() {
        var o = CropOptions()
        o.aspect = aspect
        if single { o.rect = (Double(rect.minX), Double(rect.minY), Double(rect.width), Double(rect.height)) }
        if let w = Int(outW), let h = Int(outH), w > 0, h > 0 { o.outputSize = (w, h) }
        done(.crop(o))
    }
}
#endif
