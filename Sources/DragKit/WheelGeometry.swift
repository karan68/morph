import Foundation

/// Wheel geometry shared by drawing and hit-testing (spec §5.4: outer r 160, inner r 62, gap 7, corner 12,
/// backdrop r 168). Coordinates are relative to the wheel centre in a y-down (flipped) space, matching the
/// HTML mockups/prototype (`docs/spec/mockups/src/morph-ui.js`).
public struct WheelGeometry {
    public static let size: Double = 340
    public static let rOut: Double = 160
    public static let rIn: Double = 62
    public static let gap: Double = 7
    public static let corner: Double = 12
    public static let backdrop: Double = 168
    public static let centerRadius: Double = 52
    public static let labelRadius: Double = (rIn + rOut) / 2 + 3

    /// Angle of petal i's centre. Petal 0 points up; order runs clockwise on screen.
    public static func centerAngle(_ i: Int, _ n: Int) -> Double {
        -Double.pi / 2 + Double(i) * 2 * Double.pi / Double(n)
    }

    public static func point(radius r: Double, angle a: Double) -> (x: Double, y: Double) {
        (r * cos(a), r * sin(a))
    }

    /// The inset annular sector that, filled and then stroked with width 2·corner and round joins,
    /// produces a rounded petal. For n == 1 the petal is a full ring (`isRing`).
    public struct Sector {
        public let outerRadius: Double
        public let innerRadius: Double
        public let outerStart: Double
        public let outerEnd: Double
        public let innerStart: Double
        public let innerEnd: Double
        public let isRing: Bool
    }

    public static func sector(_ i: Int, _ n: Int) -> Sector {
        let ro = rOut - corner, ri = rIn + corner
        if n == 1 { return Sector(outerRadius: ro, innerRadius: ri, outerStart: 0, outerEnd: 2 * .pi, innerStart: 0, innerEnd: 2 * .pi, isRing: true) }
        let c = centerAngle(i, n)
        func half(_ r: Double) -> Double { max(0.02, Double.pi / Double(n) - (gap / 2 + corner) / r) }
        return Sector(outerRadius: ro, innerRadius: ri,
                      outerStart: c - half(ro), outerEnd: c + half(ro),
                      innerStart: c - half(ri), innerEnd: c + half(ri), isRing: false)
    }

    public static func labelPoint(_ i: Int, _ n: Int) -> (x: Double, y: Double) {
        n == 1 ? (0, -labelRadius) : point(radius: labelRadius, angle: centerAngle(i, n))
    }

    /// Petal index under a point (relative to centre, y-down), or nil for the centre, the gap ring or outside.
    public static func hitTest(dx: Double, dy: Double, count n: Int) -> Int? {
        let d = (dx * dx + dy * dy).squareRoot()
        guard n > 0, d >= rIn, d <= rOut + 4 else { return nil }
        if n == 1 { return 0 }
        var a = atan2(dy, dx) + Double.pi / 2
        a = a.truncatingRemainder(dividingBy: 2 * .pi)
        if a < 0 { a += 2 * .pi }
        let step = 2 * Double.pi / Double(n)
        return Int((a / step).rounded()) % n
    }

    /// Whether labels should use the denser type size (more than 7 petals).
    public static func isDense(_ n: Int) -> Bool { n > 7 }

    /// Places the wheel centre so the whole ring plus legend stays on screen (prototype: margin = backdrop + 50).
    public static func clampedCenter(x: Double, y: Double, minX: Double, minY: Double, maxX: Double, maxY: Double) -> (x: Double, y: Double) {
        let m = backdrop + 14
        let legend = 56.0
        let cx = Swift.max(minX + m, Swift.min(maxX - m, x))
        let cy = Swift.max(minY + m, Swift.min(maxY - m - legend, y))
        return (cx, cy)
    }
}
