// Generates the Latch menu bar template icon sets in Latch/Assets.xcassets.
// Three styles, each with an active (filled) and inactive (outline) state:
//   Latch       — StatusActive / StatusInactive (smooth crowing-rooster silhouette)
//   Pixel Latch — StatusActivePixel / StatusInactivePixel (18px sprite)
//   Night Owl     — StatusActiveOwl / StatusInactiveOwl (awake / asleep owl)
// All are black+alpha template images at 18px (@1x) and 36px (@2x).
//
// Usage (from the repo root):
//   swift tools/make-status-icons.swift            # writes previews to icon-previews/
//   swift tools/make-status-icons.swift --emit     # also writes the .xcassets PNGs

import AppKit

let previewDir = "icon-previews"
let assetsDir = "Latch/Assets.xcassets"
let emit = CommandLine.arguments.contains("--emit")

// MARK: - Bitmap helpers

func makeContext(_ px: Int) -> CGContext {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high
    return ctx
}

func writePNG(_ img: CGImage, _ path: String) {
    let rep = NSBitmapImageRep(cgImage: img)
    let data = rep.representation(using: .png, properties: [:])!
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                             withIntermediateDirectories: true)
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

// Outline = filled minus erosion(filled). Erosion via destinationIn over disc offsets.
func outlineFrom(_ filled: CGImage, px: Int, strokePx: CGFloat) -> CGImage {
    let full = CGRect(x: 0, y: 0, width: px, height: px)

    let eroded: CGImage = {
        let ctx = makeContext(px)
        ctx.draw(filled, in: full)
        ctx.setBlendMode(.destinationIn)
        let r = strokePx
        var offsets: [(CGFloat, CGFloat)] = []
        for i in 0..<16 {
            let a = CGFloat(i) * .pi / 8
            offsets.append((r * cos(a), r * sin(a)))
        }
        for i in 0..<8 {
            let a = CGFloat(i) * .pi / 4
            offsets.append((r * 0.5 * cos(a), r * 0.5 * sin(a)))
        }
        for (dx, dy) in offsets {
            ctx.draw(filled, in: full.offsetBy(dx: dx, dy: dy))
        }
        return ctx.makeImage()!
    }()

    let ctx = makeContext(px)
    ctx.draw(filled, in: full)
    ctx.setBlendMode(.destinationOut)
    ctx.draw(eroded, in: full)
    return ctx.makeImage()!
}

// MARK: - Set 1: Latch silhouette (design space 100x100, y-up, facing left)

func drawLatch(_ ctx: CGContext, px: Int, eye: Bool) {
    let s = CGFloat(px) / 100.0
    ctx.saveGState()
    ctx.scaleBy(x: s, y: s)
    ctx.setFillColor(.black)
    ctx.setStrokeColor(.black)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    func poly(_ pts: [(CGFloat, CGFloat)]) {
        ctx.beginPath()
        ctx.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
        for p in pts.dropFirst() { ctx.addLine(to: CGPoint(x: p.0, y: p.1)) }
        ctx.closePath()
        ctx.fillPath()
    }
    func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
        ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2*r, height: 2*r))
    }
    func plume(from: (CGFloat, CGFloat), ctrl: (CGFloat, CGFloat), to: (CGFloat, CGFloat), w: CGFloat) {
        ctx.beginPath()
        ctx.move(to: CGPoint(x: from.0, y: from.1))
        ctx.addQuadCurve(to: CGPoint(x: to.0, y: to.1), control: CGPoint(x: ctrl.0, y: ctrl.1))
        ctx.setLineWidth(w)
        ctx.strokePath()
    }

    // Body — plump egg
    ctx.fillEllipse(in: CGRect(x: 18, y: 10, width: 52, height: 44))

    // Tail — three plumes sharing a fat base inside the body, spreading at the tips
    plume(from: (48, 40), ctrl: (70, 54), to: (80, 74), w: 11)
    plume(from: (50, 34), ctrl: (80, 40), to: (92, 54), w: 10)
    plume(from: (52, 28), ctrl: (86, 24), to: (96, 32), w: 9)

    // Neck bridge from body to head
    poly([(18, 64), (42, 64), (48, 40), (22, 36)])

    // Head — big for cuteness
    circle(30, 72, 15)

    // Comb — three bumps on a base
    poly([(21, 82), (39, 82), (38, 87), (22, 87)])
    circle(22, 86, 5)
    circle(30, 89.5, 5)
    circle(38, 86, 5)

    // Beak — open, crowing left (two wedges hinged inside the head)
    poly([(18, 71), (2, 80), (19, 81)])     // upper
    poly([(18, 71), (5, 60), (19, 62)])     // lower

    // Wattle under chin
    circle(22, 58, 4)

    ctx.restoreGState()

    // Eye — punched hole (active only)
    if eye {
        let e = CGRect(x: (28 - 4.2) * s, y: (76 - 4.2) * s, width: 8.4 * s, height: 8.4 * s)
        ctx.setBlendMode(.clear)
        ctx.fillEllipse(in: e)
        ctx.setBlendMode(.normal)
    }
}

func renderLatchActive(_ px: Int) -> CGImage {
    let ctx = makeContext(px)
    drawLatch(ctx, px: px, eye: true)
    return ctx.makeImage()!
}

func renderLatchInactive(_ px: Int, strokePx: CGFloat) -> CGImage {
    let ctx = makeContext(px)
    drawLatch(ctx, px: px, eye: false)
    return outlineFrom(ctx.makeImage()!, px: px, strokePx: strokePx)
}

// MARK: - Set 2: Pixel rooster (18x18 sprite, '#' fill, 'o' eye hole)

let pixelLatchGrid: [String] = [
    "....##..##........",
    "....######........",
    ".####oo###........",
    "..###oo###........",
    "....######........",
    ".....#####.....##.",
    ".....#######..###.",
    "....############..",
    "...############...",
    "...############...",
    "...###########....",
    "....##########....",
    ".....########.....",
    "......######......",
    ".......#..#.......",
    ".......#..#.......",
    "......##..##......",
    "..................",
]

func renderPixel(_ px: Int, grid: [String], punchEye: Bool) -> CGImage {
    let ctx = makeContext(px)
    ctx.setAllowsAntialiasing(false)
    let cell = CGFloat(px) / 18.0
    ctx.setFillColor(.black)
    for (row, line) in grid.enumerated() {
        for (col, ch) in line.enumerated() {
            let filled = ch == "#" || (ch == "o" && !punchEye)
            guard filled else { continue }
            // grid row 0 is top; CG origin is bottom-left
            let y = CGFloat(17 - row) * cell
            ctx.fill(CGRect(x: CGFloat(col) * cell, y: y, width: cell, height: cell))
        }
    }
    return ctx.makeImage()!
}

// 1px-cell border trace of the grid (eye treated as filled so no ring appears)
func pixelOutlineGrid(_ grid: [String]) -> [String] {
    let filled: [[Bool]] = grid.map { $0.map { $0 == "#" || $0 == "o" } }
    func isFilled(_ r: Int, _ c: Int) -> Bool {
        r >= 0 && r < 18 && c >= 0 && c < 18 && filled[r][c]
    }
    return (0..<18).map { r in
        String((0..<18).map { c -> Character in
            guard filled[r][c] else { return "." }
            let interior = isFilled(r-1, c) && isFilled(r+1, c) && isFilled(r, c-1) && isFilled(r, c+1)
            return interior ? "." : "#"
        })
    }
}

// MARK: - Set 3: Night owl (awake = punched round eyes, asleep = outline + closed lids)

func drawOwlBase(_ ctx: CGContext, px: Int) {
    let s = CGFloat(px) / 100.0
    ctx.saveGState()
    ctx.scaleBy(x: s, y: s)
    ctx.setFillColor(.black)

    func poly(_ pts: [(CGFloat, CGFloat)]) {
        ctx.beginPath()
        ctx.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
        for p in pts.dropFirst() { ctx.addLine(to: CGPoint(x: p.0, y: p.1)) }
        ctx.closePath()
        ctx.fillPath()
    }

    // Ear tufts — bases buried inside the dome so they connect
    poly([(30, 64), (18, 92), (48, 76)])
    poly([(70, 64), (82, 92), (52, 76)])
    // Body — tall egg
    ctx.fillEllipse(in: CGRect(x: 22, y: 6, width: 56, height: 76))

    ctx.restoreGState()
}

func renderOwlActive(_ px: Int) -> CGImage {
    let ctx = makeContext(px)
    drawOwlBase(ctx, px: px)
    let s = CGFloat(px) / 100.0

    func punchCircle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
        ctx.setBlendMode(.clear)
        ctx.fillEllipse(in: CGRect(x: (cx - r) * s, y: (cy - r) * s, width: 2*r*s, height: 2*r*s))
        ctx.setBlendMode(.normal)
    }
    // Wide-open eyes: punched rings with pupils
    punchCircle(38, 56, 10)
    punchCircle(62, 56, 10)
    ctx.setFillColor(.black)
    ctx.fillEllipse(in: CGRect(x: (38 - 3.5) * s, y: (55 - 3.5) * s, width: 7*s, height: 7*s))
    ctx.fillEllipse(in: CGRect(x: (62 - 3.5) * s, y: (55 - 3.5) * s, width: 7*s, height: 7*s))
    // Beak notch
    ctx.setBlendMode(.clear)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 44 * s, y: 46 * s))
    ctx.addLine(to: CGPoint(x: 56 * s, y: 46 * s))
    ctx.addLine(to: CGPoint(x: 50 * s, y: 36 * s))
    ctx.closePath()
    ctx.fillPath()
    ctx.setBlendMode(.normal)
    return ctx.makeImage()!
}

func renderOwlInactive(_ px: Int, strokePx: CGFloat) -> CGImage {
    // Outline of the plain silhouette…
    let base: CGImage = {
        let c = makeContext(px)
        drawOwlBase(c, px: px)
        return c.makeImage()!
    }()
    let outline = outlineFrom(base, px: px, strokePx: strokePx)

    // …plus sleepy closed-eye lids and a small filled beak inside the hollow face.
    let ctx = makeContext(px)
    ctx.draw(outline, in: CGRect(x: 0, y: 0, width: px, height: px))
    let s = CGFloat(px) / 100.0
    ctx.setStrokeColor(.black)
    ctx.setLineCap(.round)
    ctx.setLineWidth(max(1.1, 4.5 * s))
    for cx in [CGFloat(38), CGFloat(62)] {
        ctx.beginPath()
        ctx.move(to: CGPoint(x: (cx - 8) * s, y: 58 * s))
        ctx.addQuadCurve(to: CGPoint(x: (cx + 8) * s, y: 58 * s),
                         control: CGPoint(x: cx * s, y: 50 * s))
        ctx.strokePath()
    }
    ctx.setFillColor(.black)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 45 * s, y: 45 * s))
    ctx.addLine(to: CGPoint(x: 55 * s, y: 45 * s))
    ctx.addLine(to: CGPoint(x: 50 * s, y: 37 * s))
    ctx.closePath()
    ctx.fillPath()
    return ctx.makeImage()!
}

// MARK: - Shared path helpers (100x100 y-up space)

private func poly(_ ctx: CGContext, _ px: Int, _ pts: [(CGFloat, CGFloat)]) {
    let s = CGFloat(px) / 100.0
    ctx.beginPath()
    ctx.move(to: CGPoint(x: pts[0].0 * s, y: pts[0].1 * s))
    for p in pts.dropFirst() { ctx.addLine(to: CGPoint(x: p.0 * s, y: p.1 * s)) }
    ctx.closePath()
    ctx.fillPath()
}
private func fillCircle(_ ctx: CGContext, _ px: Int, _ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
    let s = CGFloat(px) / 100.0
    ctx.fillEllipse(in: CGRect(x: (cx - r) * s, y: (cy - r) * s, width: 2*r*s, height: 2*r*s))
}
private func fillEllipseR(_ ctx: CGContext, _ px: Int, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
    let s = CGFloat(px) / 100.0
    ctx.fillEllipse(in: CGRect(x: x*s, y: y*s, width: w*s, height: h*s))
}
private func strokeQuad(_ ctx: CGContext, _ px: Int, _ a: (CGFloat,CGFloat), _ c: (CGFloat,CGFloat), _ b: (CGFloat,CGFloat), _ w: CGFloat) {
    let s = CGFloat(px) / 100.0
    ctx.beginPath()
    ctx.move(to: CGPoint(x: a.0*s, y: a.1*s))
    ctx.addQuadCurve(to: CGPoint(x: b.0*s, y: b.1*s), control: CGPoint(x: c.0*s, y: c.1*s))
    ctx.setLineCap(.round)
    ctx.setLineWidth(w * s)
    ctx.strokePath()
}
private func punchHole(_ ctx: CGContext, _ px: Int, _ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
    let s = CGFloat(px) / 100.0
    ctx.setBlendMode(.clear)
    ctx.fillEllipse(in: CGRect(x: (cx-r)*s, y: (cy-r)*s, width: 2*r*s, height: 2*r*s))
    ctx.setBlendMode(.normal)
}

// MARK: - Set 4: Shark (side view, facing left; "must keep swimming or sink")

func sharkFilled(_ px: Int) -> CGImage {
    let ctx = makeContext(px)
    ctx.setFillColor(.black)
    fillEllipseR(ctx, px, 8, 35, 76, 30)                              // body
    poly(ctx, px, [(3, 50), (24, 60), (24, 40)])                      // snout point
    poly(ctx, px, [(74, 58), (99, 77), (86, 50), (97, 25), (74, 42)]) // forked tail
    poly(ctx, px, [(41, 50), (58, 84), (60, 52)])                     // dorsal fin (raked)
    poly(ctx, px, [(38, 50), (26, 18), (52, 48)])                     // pectoral fin
    return ctx.makeImage()!
}
func renderSharkActive(_ px: Int) -> CGImage {
    let ctx = makeContext(px)
    ctx.draw(sharkFilled(px), in: CGRect(x: 0, y: 0, width: px, height: px))
    punchHole(ctx, px, 18, 52, 3.2)   // eye
    return ctx.makeImage()!
}
func renderSharkInactive(_ px: Int, strokePx: CGFloat) -> CGImage {
    outlineFrom(sharkFilled(px), px: px, strokePx: strokePx)
}

// MARK: - Set 5: Meerkat (upright desert sentry, standing watch)

func meerkatFilled(_ px: Int) -> CGImage {
    let ctx = makeContext(px)
    ctx.setFillColor(.black); ctx.setStrokeColor(.black)
    strokeQuad(ctx, px, (58, 26), (78, 20), (82, 4), 6)   // propping tail
    fillEllipseR(ctx, px, 28, 8, 34, 46)                  // belly
    poly(ctx, px, [(34, 40), (56, 40), (52, 66), (38, 66)]) // chest/neck
    fillCircle(ctx, px, 38, 8, 5); fillCircle(ctx, px, 52, 8, 5)  // feet
    let s = CGFloat(px) / 100.0
    ctx.setLineCap(.round); ctx.setLineWidth(5 * s)
    ctx.beginPath(); ctx.move(to: CGPoint(x: 40*s, y: 52*s)); ctx.addLine(to: CGPoint(x: 36*s, y: 40*s)); ctx.strokePath()
    ctx.beginPath(); ctx.move(to: CGPoint(x: 50*s, y: 52*s)); ctx.addLine(to: CGPoint(x: 54*s, y: 40*s)); ctx.strokePath()
    fillCircle(ctx, px, 45, 75, 13)                       // head
    fillCircle(ctx, px, 35, 85, 5); fillCircle(ctx, px, 55, 85, 5)  // ears
    poly(ctx, px, [(41, 66), (49, 66), (45, 60)])         // muzzle
    return ctx.makeImage()!
}
func renderMeerkatActive(_ px: Int) -> CGImage {
    let ctx = makeContext(px)
    ctx.draw(meerkatFilled(px), in: CGRect(x: 0, y: 0, width: px, height: px))
    punchHole(ctx, px, 40, 77, 3.0)   // two alert eyes
    punchHole(ctx, px, 50, 77, 3.0)
    return ctx.makeImage()!
}
func renderMeerkatInactive(_ px: Int, strokePx: CGFloat) -> CGImage {
    outlineFrom(meerkatFilled(px), px: px, strokePx: strokePx)
}

// MARK: - Set 6: Octopus (round mantle + curling arms; "Inky", never rests)

func octopusFilled(_ px: Int) -> CGImage {
    let ctx = makeContext(px)
    ctx.setFillColor(.black); ctx.setStrokeColor(.black)
    fillEllipseR(ctx, px, 24, 44, 52, 50)   // mantle / head dome
    fillEllipseR(ctx, px, 22, 34, 56, 28)   // skirt
    strokeQuad(ctx, px, (30, 42), (18, 26), (10, 34), 9)   // arms
    strokeQuad(ctx, px, (40, 38), (34, 16), (24, 12), 9)
    strokeQuad(ctx, px, (50, 36), (50, 12), (44, 6), 9)
    strokeQuad(ctx, px, (60, 38), (66, 16), (76, 12), 9)
    strokeQuad(ctx, px, (70, 42), (82, 26), (90, 34), 9)
    return ctx.makeImage()!
}
func renderOctopusActive(_ px: Int) -> CGImage {
    let ctx = makeContext(px)
    ctx.draw(octopusFilled(px), in: CGRect(x: 0, y: 0, width: px, height: px))
    punchHole(ctx, px, 40, 66, 5)
    punchHole(ctx, px, 60, 66, 5)
    ctx.setFillColor(.black)
    fillCircle(ctx, px, 40, 66, 2)   // pupils
    fillCircle(ctx, px, 60, 66, 2)
    return ctx.makeImage()!
}
func renderOctopusInactive(_ px: Int, strokePx: CGFloat) -> CGImage {
    outlineFrom(octopusFilled(px), px: px, strokePx: strokePx)
}

// MARK: - Emit
//
// Latch ships three menu bar styles: Octopus (default), Meerkat, Night Owl.
// (The rooster / pixel-rooster / shark drawing code above is retired but kept
// for reference; it is no longer emitted.)

// Previews (144px)
writePNG(renderOctopusActive(144), "\(previewDir)/octopus-active.png")
writePNG(renderOctopusInactive(144, strokePx: 10), "\(previewDir)/octopus-inactive.png")
writePNG(renderMeerkatActive(144), "\(previewDir)/meerkat-active.png")
writePNG(renderMeerkatInactive(144, strokePx: 10), "\(previewDir)/meerkat-inactive.png")
writePNG(renderOwlActive(144), "\(previewDir)/owl-active.png")
writePNG(renderOwlInactive(144, strokePx: 10), "\(previewDir)/owl-inactive.png")

if emit {
    func emitSet(_ imageset: String, _ base: String, _ img18: CGImage, _ img36: CGImage) {
        writePNG(img18, "\(assetsDir)/\(imageset).imageset/\(base)-18.png")
        writePNG(img36, "\(assetsDir)/\(imageset).imageset/\(base)-36.png")
    }
    emitSet("StatusActiveOctopus", "status-active-octopus",
            renderOctopusActive(18), renderOctopusActive(36))
    emitSet("StatusInactiveOctopus", "status-inactive-octopus",
            renderOctopusInactive(18, strokePx: 1.4), renderOctopusInactive(36, strokePx: 2.6))
    emitSet("StatusActiveMeerkat", "status-active-meerkat",
            renderMeerkatActive(18), renderMeerkatActive(36))
    emitSet("StatusInactiveMeerkat", "status-inactive-meerkat",
            renderMeerkatInactive(18, strokePx: 1.4), renderMeerkatInactive(36, strokePx: 2.6))
    emitSet("StatusActiveOwl", "status-active-owl",
            renderOwlActive(18), renderOwlActive(36))
    emitSet("StatusInactiveOwl", "status-inactive-owl",
            renderOwlInactive(18, strokePx: 1.4), renderOwlInactive(36, strokePx: 2.6))
}
