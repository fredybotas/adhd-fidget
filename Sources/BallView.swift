import AppKit

final class BallView: NSView {

    // MARK: - Particle

    private struct Particle {
        var pos: CGPoint
        var oldPos: CGPoint
        var pinned: Bool

        init(_ pos: CGPoint, pinned: Bool = false) {
            self.pos = pos; self.oldPos = pos; self.pinned = pinned
        }
    }

    // MARK: - Config

    private let segCount    = 16
    private let totalLen:   CGFloat = 220
    private let grav:       CGFloat = 700
    private let damping:    CGFloat = 0.9994   // per-frame position-delta decay
    private let iters               = 10       // constraint iterations
    private let breakSpeed: CGFloat = 1600     // px/s throw to snap rope
    private let breakRatio: CGFloat = 1.52     // dist-from-anchor / totalLen to snap rope
    private let bounceE:    CGFloat = 0.65
    private let floorFric:  CGFloat = 0.80

    let ballRadius: CGFloat = 28
    let anchor: CGPoint

    // MARK: - State

    private var parts: [Particle] = []
    private var segLen: CGFloat = 0

    private var isFree  = false
    private var freePos = CGPoint.zero
    private var freeVel = CGPoint.zero

    private var dragging     = false
    private var freeDragging = false
    private var dragSamples: [(CGPoint, CFTimeInterval)] = []

    private var animationLink: CADisplayLink?
    private var lastTime: CFTimeInterval = 0

    // MARK: - Init

    init(frame: NSRect, anchor: CGPoint) {
        self.anchor = anchor
        super.init(frame: frame)
        buildChain()
    }

    required init?(coder: NSCoder) { fatalError() }
    deinit { animationLink?.invalidate() }

    private func buildChain() {
        segLen = totalLen / CGFloat(segCount)
        parts = (0...segCount).map { i in
            let y = anchor.y - totalLen * CGFloat(i) / CGFloat(segCount)
            return Particle(CGPoint(x: anchor.x, y: y), pinned: i == 0)
        }
    }

    // MARK: - Display link

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil, animationLink == nil {
            let link = self.displayLink(target: self, selector: #selector(tick(_:)))
            link.add(to: .main, forMode: .common)
            animationLink = link
        } else if window == nil {
            animationLink?.invalidate(); animationLink = nil; lastTime = 0
        }
    }

    @objc private func tick(_ dl: CADisplayLink) {
        let now = dl.timestamp
        if lastTime == 0 { lastTime = now; return }
        let dt = CGFloat(min(now - lastTime, 1.0 / 30.0))
        lastTime = now
        if isFree { stepFree(dt: dt) } else { stepChain(dt: dt) }
        needsDisplay = true
    }

    // MARK: - Rope physics (Verlet + constraints)

    private func stepChain(dt: CGFloat) {
        let n = parts.count
        for i in 1..<n {
            if dragging && i == n - 1 { continue }
            let vx = (parts[i].pos.x - parts[i].oldPos.x) * damping
            let vy = (parts[i].pos.y - parts[i].oldPos.y) * damping
            let old = parts[i].pos
            parts[i].pos.x += vx
            parts[i].pos.y += vy - grav * dt * dt
            parts[i].oldPos = old
        }

        for _ in 0..<iters {
            for i in 0..<segCount { satisfyConstraint(i, i + 1) }
        }
    }

    private func satisfyConstraint(_ i: Int, _ j: Int) {
        let dx = parts[j].pos.x - parts[i].pos.x
        let dy = parts[j].pos.y - parts[i].pos.y
        let d  = hypot(dx, dy)
        guard d > 0 else { return }
        let corr = (d - segLen) / d
        let iFixed = parts[i].pinned
        let jFixed = parts[j].pinned || (dragging && j == parts.count - 1)
        switch (iFixed, jFixed) {
        case (false, false):
            parts[i].pos.x += dx * corr * 0.5;  parts[i].pos.y += dy * corr * 0.5
            parts[j].pos.x -= dx * corr * 0.5;  parts[j].pos.y -= dy * corr * 0.5
        case (true, false):
            parts[j].pos.x -= dx * corr;         parts[j].pos.y -= dy * corr
        case (false, true):
            parts[i].pos.x += dx * corr;         parts[i].pos.y += dy * corr
        default: break
        }
    }

    // MARK: - Free-ball physics

    private func stepFree(dt: CGFloat) {
        if freeDragging { return }
        freeVel.y -= grav * dt
        freePos.x += freeVel.x * dt
        freePos.y += freeVel.y * dt
        let b = bounds
        if freePos.x - ballRadius < b.minX { freePos.x = b.minX + ballRadius; freeVel.x =  abs(freeVel.x) * bounceE }
        if freePos.x + ballRadius > b.maxX { freePos.x = b.maxX - ballRadius; freeVel.x = -abs(freeVel.x) * bounceE }
        if freePos.y + ballRadius > b.maxY { freePos.y = b.maxY - ballRadius; freeVel.y = -abs(freeVel.y) * bounceE }
        if freePos.y - ballRadius < b.minY {
            freePos.y = b.minY + ballRadius
            freeVel.y = abs(freeVel.y) * bounceE
            freeVel.x *= floorFric
        }
    }

    private func snapRope(vel: CGPoint, at pos: CGPoint) {
        isFree = true; dragging = false; dragSamples = []
        freePos = pos; freeVel = vel
    }

    func resetRope() {
        isFree = false; dragging = false; freeDragging = false; dragSamples = []
        buildChain()
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        if isFree {
            drawBall(ctx, at: freePos)
        } else {
            drawRope(ctx)
            drawBall(ctx, at: parts.last!.pos)
        }
    }

    private func drawRope(_ ctx: CGContext) {
        guard parts.count >= 2 else { return }
        let pts = parts.map(\.pos)

        // Catmull-Rom bezier through chain points
        func makePath(ox: CGFloat, oy: CGFloat) -> CGPath {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: pts[0].x + ox, y: pts[0].y + oy))
            for i in 1..<pts.count {
                let p0 = pts[max(0, i - 2)]
                let p1 = pts[i - 1]
                let p2 = pts[i]
                let p3 = pts[min(pts.count - 1, i + 1)]
                path.addCurve(
                    to: CGPoint(x: p2.x + ox, y: p2.y + oy),
                    control1: CGPoint(x: p1.x + (p2.x - p0.x)/6 + ox, y: p1.y + (p2.y - p0.y)/6 + oy),
                    control2: CGPoint(x: p2.x - (p3.x - p1.x)/6 + ox, y: p2.y - (p3.y - p1.y)/6 + oy)
                )
            }
            return path
        }

        ctx.setLineCap(.round)

        // Shadow
        ctx.addPath(makePath(ox: 2, oy: -3))
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.13).cgColor)
        ctx.setLineWidth(3.5); ctx.strokePath()

        // Rope body
        ctx.addPath(makePath(ox: 0, oy: 0))
        ctx.setStrokeColor(NSColor(white: 0.80, alpha: 0.92).cgColor)
        ctx.setLineWidth(2.5); ctx.strokePath()

        // Anchor pin
        let pr: CGFloat = 5
        ctx.setFillColor(NSColor(white: 0.95, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: anchor.x - pr, y: anchor.y - pr, width: pr*2, height: pr*2))
    }

    private func drawBall(_ ctx: CGContext, at pos: CGPoint) {
        let r = ballRadius
        let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r*2, height: r*2)

        // Drop shadow
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 4, height: -7), blur: 18,
                      color: NSColor.black.withAlphaComponent(0.52).cgColor)
        ctx.setFillColor(NSColor(red: 0.04, green: 0.14, blue: 0.65, alpha: 1).cgColor)
        ctx.fillEllipse(in: rect)
        ctx.restoreGState()

        // Sphere — radial gradient, highlight offset upper-left for 3-D illusion
        ctx.saveGState()
        ctx.addEllipse(in: rect); ctx.clip()
        let cs = CGColorSpaceCreateDeviceRGB()
        let sphereGrad = CGGradient(colorsSpace: cs, colors: [
            NSColor(red: 0.90, green: 0.95, blue: 1.00, alpha: 1).cgColor,
            NSColor(red: 0.28, green: 0.55, blue: 0.98, alpha: 1).cgColor,
            NSColor(red: 0.03, green: 0.12, blue: 0.62, alpha: 1).cgColor,
        ] as CFArray, locations: [0, 0.42, 1.0])!
        ctx.drawRadialGradient(sphereGrad,
            startCenter: CGPoint(x: pos.x - r*0.28, y: pos.y + r*0.30), startRadius: 0,
            endCenter:   CGPoint(x: pos.x + r*0.05, y: pos.y - r*0.05), endRadius: r*1.05,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()

        // Rim highlight ring (2px wide)
        ctx.saveGState()
        ctx.addEllipse(in: rect)
        ctx.addEllipse(in: rect.insetBy(dx: 2, dy: 2))
        ctx.clip(using: .evenOdd)
        let rimGrad = CGGradient(colorsSpace: cs, colors: [
            NSColor.white.withAlphaComponent(0.55).cgColor,
            NSColor.white.withAlphaComponent(0.00).cgColor,
        ] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(rimGrad,
            start: CGPoint(x: pos.x - r, y: pos.y + r),
            end:   CGPoint(x: pos.x + r, y: pos.y - r), options: [])
        ctx.restoreGState()

        // Soft specular blob
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.32).cgColor)
        ctx.fillEllipse(in: CGRect(x: pos.x - r*0.50, y: pos.y + r*0.08, width: r*0.68, height: r*0.42))

        // Sharp specular dot
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.90).cgColor)
        ctx.fillEllipse(in: CGRect(x: pos.x - r*0.37, y: pos.y + r*0.30, width: r*0.24, height: r*0.15))
    }

    // MARK: - Hit testing (click-through outside ball)

    override func hitTest(_ point: NSPoint) -> NSView? {
        let pos = isFree ? freePos : (parts.last?.pos ?? .zero)
        return hypot(point.x - pos.x, point.y - pos.y) <= ballRadius + 12 ? self : nil
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let pos = isFree ? freePos : (parts.last?.pos ?? .zero)
        guard hypot(p.x - pos.x, p.y - pos.y) <= ballRadius + 12 else { return }
        if isFree {
            freeDragging = true
            dragSamples = [(p, CACurrentMediaTime())]
            return
        }
        dragging = true
        dragSamples = [(p, CACurrentMediaTime())]
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)

        if freeDragging {
            freePos = p
            dragSamples.append((p, CACurrentMediaTime()))
            if dragSamples.count > 8 { dragSamples.removeFirst() }
            needsDisplay = true
            return
        }

        guard dragging, !isFree else { return }
        let last = parts.count - 1
        parts[last].oldPos = parts[last].pos
        parts[last].pos = p
        dragSamples.append((p, CACurrentMediaTime()))
        if dragSamples.count > 8 { dragSamples.removeFirst() }

        if hypot(p.x - anchor.x, p.y - anchor.y) > totalLen * breakRatio {
            snapRope(vel: recentVelocity(), at: p)
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if freeDragging {
            freeDragging = false
            freeVel = recentVelocity()
            dragSamples = []
            return
        }

        guard dragging else { return }
        dragging = false
        let vel = recentVelocity()
        if hypot(vel.x, vel.y) > breakSpeed {
            snapRope(vel: vel, at: parts.last!.pos)
        } else {
            let dtF: CGFloat = 1.0 / 60.0
            let last = parts.count - 1
            parts[last].oldPos = CGPoint(x: parts[last].pos.x - vel.x * dtF,
                                         y: parts[last].pos.y - vel.y * dtF)
        }
        dragSamples = []
    }

    private func recentVelocity() -> CGPoint {
        guard dragSamples.count >= 2 else { return .zero }
        let a = dragSamples[dragSamples.count - 2]
        let b = dragSamples[dragSamples.count - 1]
        let dt = b.1 - a.1
        guard dt > 0.001 else { return .zero }
        return CGPoint(x: (b.0.x - a.0.x) / CGFloat(dt),
                       y: (b.0.y - a.0.y) / CGFloat(dt))
    }
}
