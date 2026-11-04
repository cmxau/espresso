import CoreGraphics

/// The espresso cup (outlined, tapered body + handle + three steam bars) as stroked centerlines
/// in a y-down 310x258 box; stroke it with `lineWidth`, round caps/joins. Single source for every icon.
enum Cup {
    static let box = CGRect(x: 40, y: 14, width: 310, height: 258)
    static let lineWidth: CGFloat = 24

    static let body: CGPath = {
        let a = CGPoint(x: 52, y: 118), b = CGPoint(x: 292, y: 118)
        let c = CGPoint(x: 262, y: 260), d = CGPoint(x: 82, y: 260)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 172, y: 118))
        p.addArc(tangent1End: b, tangent2End: c, radius: 16)
        p.addArc(tangent1End: c, tangent2End: d, radius: 36)
        p.addArc(tangent1End: d, tangent2End: a, radius: 36)
        p.addArc(tangent1End: a, tangent2End: b, radius: 16)
        p.closeSubpath()
        return p
    }()

    static let handle: CGPath = {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 292, y: 130))
        p.addArc(tangent1End: CGPoint(x: 338, y: 130), tangent2End: CGPoint(x: 338, y: 188), radius: 18)
        p.addArc(tangent1End: CGPoint(x: 338, y: 188), tangent2End: CGPoint(x: 275, y: 188), radius: 18)
        p.addLine(to: CGPoint(x: 275, y: 188))
        return p
    }()

    /// Steam bars; `phase` nil = resting shape, otherwise the bars gently rise and fall.
    static func steam(_ phase: CGFloat?) -> CGPath {
        let xs: [CGFloat] = [127, 172, 217], tops: [CGFloat] = [55, 28, 55]
        let p = CGMutablePath()
        for i in 0..<3 {
            var top = tops[i]
            if let phase { top += 14 * sin(phase + CGFloat(i) * 2.1) }
            p.move(to: CGPoint(x: xs[i], y: 78))
            p.addLine(to: CGPoint(x: xs[i], y: min(max(top, 26), 66)))
        }
        return p
    }
}
