// Generates AppIcon.appiconset from the pixel-art rooster in images/wakeup-rooster.png,
// centered on an orange-gradient rounded rectangle (full-bleed, like the previous icon).
//
// Usage (from the repo root):
//   swift tools/make-app-icon.swift

import AppKit

let sourcePath = "images/wakeup-rooster.png"
let outDir = "Latch/Assets.xcassets/AppIcon.appiconset"

guard let source = NSImage(contentsOfFile: sourcePath),
      let sourceCG = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("could not load \(sourcePath) — run from the repo root")
}

func makeContext(_ px: Int) -> CGContext {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    return CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                     bytesPerRow: 0, space: cs,
                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func writePNG(_ img: CGImage, _ path: String) {
    let rep = NSBitmapImageRep(cgImage: img)
    let data = rep.representation(using: .png, properties: [:])!
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                             withIntermediateDirectories: true)
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

// 1024px master
let master: CGImage = {
    let px = 1024
    let ctx = makeContext(px)

    // Rounded-rect background with vertical orange gradient
    let rect = CGRect(x: 0, y: 0, width: px, height: px)
    let path = CGPath(roundedRect: rect, cornerWidth: 180, cornerHeight: 180, transform: nil)
    ctx.addPath(path)
    ctx.clip()
    let colors = [
        CGColor(red: 1.00, green: 0.72, blue: 0.30, alpha: 1),  // #FFB84D top
        CGColor(red: 0.94, green: 0.44, blue: 0.00, alpha: 1),  // #EF7000 bottom
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 200, y: 1024),
                           end: CGPoint(x: 824, y: 0),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // Pixel-art rooster, nearest-neighbor so the pixels stay crisp
    ctx.interpolationQuality = .none
    let roosterSize: CGFloat = 720
    let x = (CGFloat(px) - roosterSize) / 2
    let y = (CGFloat(px) - roosterSize) / 2
    ctx.draw(sourceCG, in: CGRect(x: x, y: y, width: roosterSize, height: roosterSize))

    return ctx.makeImage()!
}()

// Downscale master to each icon size
func scaled(_ px: Int) -> CGImage {
    let ctx = makeContext(px)
    ctx.interpolationQuality = .high
    ctx.draw(master, in: CGRect(x: 0, y: 0, width: px, height: px))
    return ctx.makeImage()!
}

for px in [16, 32, 64, 128, 256, 512, 1024] {
    writePNG(px == 1024 ? master : scaled(px), "\(outDir)/icon_\(px).png")
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
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
try! contents.write(toFile: "\(outDir)/Contents.json", atomically: true, encoding: .utf8)
print("wrote \(outDir)/Contents.json")
