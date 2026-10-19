#if canImport(AppKit)
import AppKit
import Capabilities
import A11y

/// What a wheel shows. `targets` are format ids (conversions) or tool/action ids.
public struct WheelContent {
    public var mode: WheelMode
    public var targets: [String]
    public var emptyText: String
    public var thumbnail: NSImage?
    public var chipText: String?
    /// Glyph for each mode's configured key (legend).
    public var keyGlyphs: [WheelMode: String]
    public init(mode: WheelMode, targets: [String], emptyText: String, thumbnail: NSImage?, chipText: String?, keyGlyphs: [WheelMode: String]) {
        self.mode = mode; self.targets = targets; self.emptyText = emptyText
        self.thumbnail = thumbnail; self.chipText = chipText; self.keyGlyphs = keyGlyphs
    }

    public func label(_ i: Int) -> String {
        let t = targets[i]
        switch mode {
        case .conversions: return Formats.label(t)
        case .tools: return CapabilityRegistry.title(forTool: t)
        case .actions: return CapabilityRegistry.title(forAction: t)
        }
    }

    /// Accessible name: "Convert to PNG", "Trim Video", "AirDrop" (spec §6 A1).
    public func accessibleName(_ i: Int) -> String {
        let t = targets[i]
        switch mode {
        case .conversions: return "Convert to \(Formats.label(t))"
        case .tools: return CapabilityRegistry.name(forTool: t)
        case .actions: return CapabilityRegistry.name(forAction: t)
        }
    }

    public var menuLabel: String {
        switch mode {
        case .conversions: return "Choose a conversion format"
        case .tools: return "Choose a file tool"
        case .actions: return "Choose a file action"
        }
    }
}

public protocol WheelViewDelegate: AnyObject {
    func wheelView(_ view: WheelView, didHighlight index: Int?)
    /// Drop or Return on a petal.
    func wheelView(_ view: WheelView, didChoose index: Int, droppedURLs: [URL]?)
    func wheelViewDidCancel(_ view: WheelView)
    /// Keyboard mode: a configured modifier was tapped.
    func wheelView(_ view: WheelView, didTapModifierFor mode: WheelMode)
    func wheelViewDragExited(_ view: WheelView)
}

/// The radial menu (spec mockups 03–06, §5.4 geometry, §5.5 motion, §6 accessibility).
public final class WheelView: NSView {
    public weak var delegate: WheelViewDelegate?
    public private(set) var content: WheelContent
    public private(set) var highlighted: Int?
    public var keyboardMode = false { didSet { needsDisplay = true } }
    /// Modifier key → wheel mode mapping, used in keyboard mode.
    public var modifierModes: [NSEvent.ModifierFlags.RawValue: WheelMode] = [:]
    private var flash: Int?
    private var petalElements: [PetalElement] = []
    private var lastFlags: NSEvent.ModifierFlags = []

    public static let legendHeight: CGFloat = 44
    public static let size = NSSize(width: WheelGeometry.size + 40, height: WheelGeometry.size + 20 + legendHeight)
    /// Wheel centre in view coordinates (flipped).
    public var center: CGPoint { CGPoint(x: bounds.midX, y: 20 / 2 + WheelGeometry.size / 2) }

    public init(content: WheelContent) {
        self.content = content
        super.init(frame: NSRect(origin: .zero, size: Self.size))
        wantsLayer = true
        layer?.backgroundColor = .clear
        registerForDraggedTypes([.fileURL])
        setAccessibilityElement(true)
        setAccessibilityRole(.menu)
        rebuildAccessibility()
    }

    required init?(coder: NSCoder) { fatalError() }

    public override var isFlipped: Bool { true }
    public override var acceptsFirstResponder: Bool { true }
    public override var isOpaque: Bool { false }

    public func setContent(_ c: WheelContent, animated: Bool) {
        content = c
        highlighted = nil
        if animated, !DisplayOptions.shared.reduceMotion, let layer = layer {
            let t = CATransition()
            t.type = .fade
            t.duration = 0.12
            layer.add(t, forKey: "switch")
        }
        rebuildAccessibility()
        needsDisplay = true
        if keyboardMode, !c.targets.isEmpty { setHighlight(0) }
    }

    public func setHighlight(_ i: Int?) {
        guard i != highlighted else { return }
        highlighted = i
        needsDisplay = true
        petalElements.enumerated().forEach { $0.element.isHighlighted = $0.offset == i }
        delegate?.wheelView(self, didHighlight: i)
        if let i = i, i < petalElements.count {
            NSAccessibility.post(element: petalElements[i], notification: .focusedUIElementChanged)
        }
    }

    public func flashAndFinish(_ i: Int, completion: @escaping () -> Void) {
        let reduce = DisplayOptions.shared.reduceMotion
        flash = reduce ? nil : i
        needsDisplay = true
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduce ? 0 : 0.12)) { completion() }
    }

    // MARK: Geometry helpers

    func petalPath(_ i: Int, _ n: Int) -> NSBezierPath {
        let s = WheelGeometry.sector(i, n)
        let c = center
        let p = NSBezierPath()
        func pt(_ r: Double, _ a: Double) -> NSPoint { NSPoint(x: c.x + CGFloat(r * cos(a)), y: c.y + CGFloat(r * sin(a))) }
        if s.isRing {
            p.appendOval(in: NSRect(x: c.x - s.outerRadius, y: c.y - s.outerRadius, width: 2 * s.outerRadius, height: 2 * s.outerRadius))
            p.appendOval(in: NSRect(x: c.x - s.innerRadius, y: c.y - s.innerRadius, width: 2 * s.innerRadius, height: 2 * s.innerRadius))
            p.windingRule = .evenOdd
            return p
        }
        let steps = 40
        p.move(to: pt(s.outerRadius, s.outerStart))
        for k in 1...steps { p.line(to: pt(s.outerRadius, s.outerStart + (s.outerEnd - s.outerStart) * Double(k) / Double(steps))) }
        p.line(to: pt(s.innerRadius, s.innerEnd))
        for k in 1...steps { p.line(to: pt(s.innerRadius, s.innerEnd - (s.innerEnd - s.innerStart) * Double(k) / Double(steps))) }
        p.close()
        return p
    }

    func index(at viewPoint: NSPoint) -> Int? {
        WheelGeometry.hitTest(dx: Double(viewPoint.x - center.x), dy: Double(viewPoint.y - center.y), count: content.targets.count)
    }

    // MARK: Drawing

    public override func draw(_ dirtyRect: NSRect) {
        let contrast = DisplayOptions.shared.highContrastStyle
        let c = center
        let n = content.targets.count
        let B = CGFloat(WheelGeometry.backdrop)

        // Backdrop ring
        let backdrop = NSBezierPath(ovalIn: NSRect(x: c.x - B, y: c.y - B, width: 2 * B, height: 2 * B))
        (contrast ? NSColor.white : Theme.rgb(0xFAFAFD, 0.58)).setFill()
        backdrop.fill()
        (contrast ? Theme.ink : NSColor.white.withAlphaComponent(0.85)).setStroke()
        backdrop.lineWidth = contrast ? 2 : 1
        backdrop.stroke()

        if n == 0 {
            drawEmpty(contrast: contrast)
        } else {
            for i in 0..<n { drawPetal(i, n, contrast: contrast) }
            drawCenter(contrast: contrast)
        }
        drawLegend(contrast: contrast)
    }

    func drawPetal(_ i: Int, _ n: Int, contrast: Bool) {
        let path = petalPath(i, n)
        let on = i == highlighted
        let fill = on ? Theme.accent : Theme.petal
        path.lineJoinStyle = .round
        if contrast {
            // 1.5 pt outline (spec mockup 06-D): a wider ink stroke underneath the rounded petal.
            (on ? Theme.accentInk : Theme.ink).setStroke()
            path.lineWidth = CGFloat(WheelGeometry.corner * 2) + 3
            path.stroke()
        }
        fill.setFill(); fill.setStroke()
        path.lineWidth = CGFloat(WheelGeometry.corner * 2)
        path.fill(); path.stroke()
        if i == flash {
            NSColor.white.withAlphaComponent(0.45).setFill(); NSColor.white.withAlphaComponent(0.45).setStroke()
            path.fill(); path.stroke()
        }
        if on && keyboardMode {
            NSColor.white.setStroke()
            let ring = path.copy() as! NSBezierPath
            ring.lineWidth = 3
            ring.stroke()
        }
        // Label
        let lp = WheelGeometry.labelPoint(i, n)
        let lx = center.x + CGFloat(lp.x), ly = center.y + CGFloat(lp.y)
        let color = on ? NSColor.white : Theme.ink
        let dense = WheelGeometry.isDense(n)
        if content.mode == .conversions {
            drawText(content.label(i), at: NSPoint(x: lx, y: ly), size: dense ? 13.5 : 15, weight: .bold, kern: 0.03, color: color)
        } else {
            if let icon = Icons.tinted(content.targets[i], size: 20, color: color) {
                icon.draw(in: NSRect(x: lx - 10, y: ly - 20, width: 20, height: 20), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            }
            drawText(content.label(i), at: NSPoint(x: lx, y: ly + 11), size: dense ? 9.5 : 10.5, weight: .semibold, kern: 0.06, color: color)
        }
    }

    func drawCenter(contrast: Bool) {
        let c = center
        let r = CGFloat(WheelGeometry.centerRadius)
        let circle = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        (contrast ? NSColor.white : NSColor.white.withAlphaComponent(0.55)).setFill()
        circle.fill()
        (contrast ? Theme.ink : NSColor.white.withAlphaComponent(0.9)).setStroke()
        circle.lineWidth = contrast ? 1.5 : 1
        circle.stroke()
        if let i = highlighted, i < content.targets.count {
            drawText(content.label(i), at: c, size: 17, weight: .heavy, kern: 0.03, color: Theme.accentInk)
            return
        }
        if let thumb = content.thumbnail {
            let rect = NSRect(x: c.x - 23, y: c.y - 23 - 14, width: 46, height: 46)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow(); shadow.shadowBlurRadius = 6; shadow.shadowOffset = NSSize(width: 0, height: -2)
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.2); shadow.set()
            NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9).addClip()
            thumb.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
            NSGraphicsContext.restoreGraphicsState()
        }
        if let chip = content.chipText {
            let font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white, .kern: 11.5 * 0.03]
            let size = (chip as NSString).size(withAttributes: attrs)
            let pill = NSRect(x: c.x - size.width / 2 - 9, y: c.y + r - 14 - size.height - 6, width: size.width + 18, height: size.height + 6)
            Theme.chip.setFill()
            NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
            (chip as NSString).draw(at: NSPoint(x: pill.minX + 9, y: pill.minY + 3), withAttributes: attrs)
        }
    }

    func drawEmpty(contrast: Bool) {
        let c = center
        let r: CGFloat = 100
        let circle = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        (contrast ? NSColor.white : Theme.glass).setFill()
        circle.fill()
        (contrast ? Theme.ink : NSColor.white.withAlphaComponent(0.7)).setStroke()
        circle.stroke()
        let para = NSMutableParagraphStyle(); para.alignment = .center; para.lineSpacing = 2
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: Theme.ink2, .paragraphStyle: para]
        let s = content.emptyText as NSString
        let box = NSRect(x: c.x - r + 26, y: c.y - r, width: 2 * r - 52, height: 2 * r)
        let h = s.boundingRect(with: box.size, options: [.usesLineFragmentOrigin], attributes: attrs).height
        s.draw(with: NSRect(x: box.minX, y: c.y - h / 2, width: box.width, height: h), options: [.usesLineFragmentOrigin], attributes: attrs)
    }

    func drawLegend(contrast: Bool) {
        let items: [(WheelMode, String)] = [(.conversions, "Convert"), (.tools, "Tools"), (.actions, "Actions")]
        let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let kfont = NSFont.systemFont(ofSize: 12, weight: .semibold)
        var widths: [CGFloat] = []
        for (m, t) in items {
            let kw = max(26, ((content.keyGlyphs[m] ?? "") as NSString).size(withAttributes: [.font: kfont]).width + 14)
            widths.append(5 + kw + 6 + (t as NSString).size(withAttributes: [.font: font]).width + 9)
        }
        let total = widths.reduce(0, +) + 6 * CGFloat(items.count - 1) + 12
        let top = center.y + CGFloat(WheelGeometry.size / 2) + 4
        let box = NSRect(x: center.x - total / 2, y: top, width: total, height: 36)
        (contrast ? NSColor.white : Theme.glass).setFill()
        let bg = NSBezierPath(roundedRect: box, xRadius: 12, yRadius: 12)
        bg.fill()
        (contrast ? Theme.ink : NSColor.white.withAlphaComponent(0.7)).setStroke()
        bg.stroke()
        var x = box.minX + 6
        for (k, (m, t)) in items.enumerated() {
            let w = widths[k]
            let on = m == content.mode
            let r = NSRect(x: x, y: box.minY + 6, width: w, height: 24)
            if on { Theme.accent.setFill(); NSBezierPath(roundedRect: r, xRadius: 8, yRadius: 8).fill() }
            let glyph = content.keyGlyphs[m] ?? ""
            let kw = max(26, (glyph as NSString).size(withAttributes: [.font: kfont]).width + 14)
            let kr = NSRect(x: r.minX + 5, y: r.minY + 2, width: kw, height: 20)
            NSColor.white.setFill()
            let kp = NSBezierPath(roundedRect: kr, xRadius: 6, yRadius: 6)
            kp.fill()
            if !on { Theme.rgb(0x1C1B22, 0.18).setStroke(); kp.stroke() }
            drawText(glyph, at: NSPoint(x: kr.midX, y: kr.midY), size: 12, weight: .semibold, kern: 0, color: Theme.ink)
            let ta: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: on ? NSColor.white : Theme.ink2]
            let ts = (t as NSString).size(withAttributes: ta)
            (t as NSString).draw(at: NSPoint(x: kr.maxX + 6, y: r.midY - ts.height / 2), withAttributes: ta)
            x += w + 6
        }
    }

    func drawText(_ s: String, at p: NSPoint, size: CGFloat, weight: NSFont.Weight, kern: CGFloat, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .kern: size * kern]
        let ts = (s as NSString).size(withAttributes: attrs)
        (s as NSString).draw(at: NSPoint(x: p.x - ts.width / 2, y: p.y - ts.height / 2), withAttributes: attrs)
    }

    // MARK: Drag destination (spec §7.1: each petal is a drop target)

    func operation(for sender: NSDraggingInfo) -> NSDragOperation {
        let mask = sender.draggingSourceOperationMask
        // Never claim .move: Morph only reads the originals.
        for op in [NSDragOperation.copy, .generic, .link] where mask.contains(op) { return op }
        return mask.isEmpty ? [] : .copy
    }

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { draggingUpdated(sender) }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let p = convert(sender.draggingLocation, from: nil)
        let i = index(at: p)
        setHighlight(i)
        return i == nil ? [] : operation(for: sender)
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        setHighlight(nil)
        delegate?.wheelViewDragExited(self)
    }

    public override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        index(at: convert(sender.draggingLocation, from: nil)) != nil
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let i = index(at: convert(sender.draggingLocation, from: nil)) else { return false }
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        delegate?.wheelView(self, didChoose: i, droppedURLs: urls)
        return true
    }

    // MARK: Keyboard (spec §6 A4)

    public override func keyDown(with event: NSEvent) {
        let n = content.targets.count
        switch event.keyCode {
        case 53: delegate?.wheelViewDidCancel(self)                                  // Esc
        case 36, 76, 49:                                                              // Return, Enter, Space
            if let i = highlighted { delegate?.wheelView(self, didChoose: i, droppedURLs: nil) }
        case 48: delegate?.wheelViewDidCancel(self)                                  // Tab
        case 123, 126, 124, 125, 115, 119:                                           // ← ↑ → ↓ Home End
            guard n > 0 else { return }
            let cur = highlighted ?? 0
            var next: Int
            switch event.keyCode {
            case 115: next = 0
            case 119: next = n - 1
            case 124, 125: next = (cur + 1) % n
            default: next = (cur - 1 + n) % n
            }
            if highlighted == nil { next = 0 }
            setHighlight(next)
        default:
            super.keyDown(with: event)
        }
    }

    public override func flagsChanged(with event: NSEvent) {
        let relevant: NSEvent.ModifierFlags = [.shift, .command, .control, .option]
        let flags = event.modifierFlags.intersection(relevant)
        let newly = flags.subtracting(lastFlags)
        lastFlags = flags
        if flags.rawValue.nonzeroBitCount == 1, newly == flags, let m = modifierModes[flags.rawValue] {
            delegate?.wheelView(self, didTapModifierFor: m)
        }
    }

    public override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if let i = index(at: p) {
            setHighlight(i)
            delegate?.wheelView(self, didChoose: i, droppedURLs: nil)
        } else if hypot(p.x - center.x, p.y - center.y) > CGFloat(WheelGeometry.backdrop) {
            delegate?.wheelViewDidCancel(self)
        }
    }

    // MARK: Accessibility (spec §6 A1)

    func rebuildAccessibility() {
        setAccessibilityLabel(content.targets.isEmpty ? content.emptyText.replacingOccurrences(of: "\n", with: " ") : content.menuLabel)
        petalElements = content.targets.indices.map { i in
            let e = PetalElement(owner: self, index: i)
            e.setAccessibilityLabel(content.accessibleName(i))
            e.setAccessibilityRole(.menuItem)
            e.setAccessibilityParent(self)
            let b = petalPath(i, content.targets.count).bounds
            e.setAccessibilityFrameInParentSpace(NSRect(x: b.minX, y: bounds.height - b.maxY, width: b.width, height: b.height))
            e.setAccessibilityHelp("Item \(i + 1) of \(content.targets.count)")
            return e
        }
        setAccessibilityChildren(petalElements)
    }

    public override func accessibilityChildren() -> [Any]? { petalElements }
}

final class PetalElement: NSAccessibilityElement {
    weak var owner: WheelView?
    let index: Int
    var isHighlighted = false
    init(owner: WheelView, index: Int) { self.owner = owner; self.index = index; super.init() }
    override func isAccessibilityFocused() -> Bool { isHighlighted }
    override func isAccessibilitySelected() -> Bool { isHighlighted }
    override func accessibilityPerformPress() -> Bool {
        guard let o = owner else { return false }
        o.setHighlight(index)
        o.delegate?.wheelView(o, didChoose: index, droppedURLs: nil)
        return true
    }
}
#endif
