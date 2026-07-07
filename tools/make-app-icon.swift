// Builds AppIcon.appiconset from the provided artwork at
// latch-icon/ios/AppIcon-1024.png, wrapped in a macOS-style rounded tile
// (small transparent margin + soft shadow) so it looks native in the Dock.
//
//   swift tools/make-app-icon.swift            # 512 + 128 previews to icon-previews/
//   swift tools/make-app-icon.swift --emit     # also writes the .xcassets PNGs

import AppKit

let sourcePath = "latch-icon/ios/AppIcon-1024.png"
let previewDir = "icon-previews"
let outDir = "Latch/Assets.xcassets/AppIcon.appiconset"
let emit = CommandLine.arguments.contains("--emit")

guard let source = NSImage(contentsOfFile: sourcePath),
      let master = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("could not load \(sourcePath) — run from the repo root")
}

func makeContext(_ px: Int) -> CGContext {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setAllowsAntialiasing(true); ctx.interpolationQuality = .high
    return ctx
}
func writePNG(_ img: CGImage, _ path: String) {
    let rep = NSBitmapImageRep(cgImage: img)
    let data = rep.representation(using: .png, properties: [:])!
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try! data.write(to: URL(fileURLWithPath: path)); print("wrote \(path)")
}

func renderIcon(_ px: Int) -> CGImage {
    let ctx = makeContext(px); let p = CGFloat(px)
    let inset = p * 0.055                 // small margin so it sits like other Dock icons
    let t = p - 2 * inset
    let corner = t * 0.2237              // Big Sur-ish continuous corner
    let rect = CGRect(x: inset, y: inset, width: t, height: t)

    // Soft drop shadow beneath the tile.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -p * 0.01), blur: p * 0.025,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.28))
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil))
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1)); ctx.fillPath()
    ctx.restoreGState()

    // Clip to the rounded tile and draw the artwork edge-to-edge.
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil))
    ctx.clip()
    ctx.draw(master, in: rect)
    ctx.restoreGState()

    return ctx.makeImage()!
}

writePNG(renderIcon(512), "\(previewDir)/app-icon.png")
writePNG(renderIcon(128), "\(previewDir)/app-icon-128.png")

if emit {
    for px in [16, 32, 64, 128, 256, 512, 1024] {
        writePNG(renderIcon(px), "\(outDir)/icon_\(px).png")
    }
    let contents = """
    {
      "images" : [
        { "filename" : "icon_16.png",   "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
        { "filename" : "icon_32.png",   "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
        { "filename" : "icon_32.png",   "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
        { "filename" : "icon_64.png",   "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
        { "filename" : "icon_128.png",  "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
        { "filename" : "icon_256.png",  "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
        { "filename" : "icon_256.png",  "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
        { "filename" : "icon_512.png",  "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
        { "filename" : "icon_512.png",  "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
        { "filename" : "icon_1024.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
      ],
      "info" : { "author" : "xcode", "version" : 1 }
    }
    """
    try! contents.write(toFile: "\(outDir)/Contents.json", atomically: true, encoding: .utf8)
    print("wrote \(outDir)/Contents.json")
}
