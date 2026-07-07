// Renders three candidate app-icon octopus styles to icon-previews/.
// Nothing is written to the asset catalog — this is for review only.
//   swift tools/icon-options.swift

import AppKit

let previewDir = "icon-previews"

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
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r/255, green: g/255, blue: b/255, alpha: a)
}

// Tile with gradient background; body drawn in a 100x100 y-up space.
func tile(_ px: Int, _ top: CGColor, _ bottom: CGColor, _ body: (CGContext) -> Void) -> CGImage {
    let ctx = makeContext(px); let p = CGFloat(px)
    let inset = p * 0.098, t = p - 2*inset, corner = (p - 2*inset) * 0.2237
    let rect = CGRect(x: inset, y: inset, width: t, height: t)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -p*0.012), blur: p*0.03, color: rgb(0,20,40,0.35))
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil))
    ctx.setFillColor(rgb(0,0,0)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)); ctx.clip()
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: [top, bottom] as CFArray, locations: [0,1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: p), end: CGPoint(x: 0, y: inset), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.translateBy(x: inset, y: inset); ctx.scaleBy(x: t/100, y: t/100)
    body(ctx)
    ctx.restoreGState()
    return ctx.makeImage()!
}

// MARK: cubic-bezier tapered tentacle (the anti-mop weapon)

func cubic(_ p0:(CGFloat,CGFloat),_ p1:(CGFloat,CGFloat),_ p2:(CGFloat,CGFloat),_ p3:(CGFloat,CGFloat),_ t:CGFloat)->(CGFloat,CGFloat){
    let m=1-t
    let x=m*m*m*p0.0+3*m*m*t*p1.0+3*m*t*t*p2.0+t*t*t*p3.0
    let y=m*m*m*p0.1+3*m*m*t*p1.1+3*m*t*t*p2.1+t*t*t*p3.1
    return (x,y)
}
func deriv(_ p0:(CGFloat,CGFloat),_ p1:(CGFloat,CGFloat),_ p2:(CGFloat,CGFloat),_ p3:(CGFloat,CGFloat),_ t:CGFloat)->(CGFloat,CGFloat){
    let m=1-t
    let x=3*m*m*(p1.0-p0.0)+6*m*t*(p2.0-p1.0)+3*t*t*(p3.0-p2.0)
    let y=3*m*m*(p1.1-p0.1)+6*m*t*(p2.1-p1.1)+3*t*t*(p3.1-p2.1)
    return (x,y)
}
// Filled tentacle following a cubic centerline, width tapering base->tip.
func tentacle(_ ctx:CGContext,_ p0:(CGFloat,CGFloat),_ p1:(CGFloat,CGFloat),_ p2:(CGFloat,CGFloat),_ p3:(CGFloat,CGFloat), wBase:CGFloat, wTip:CGFloat, suckers:CGColor?=nil){
    let N=28
    var left:[CGPoint]=[]; var right:[CGPoint]=[]; var mids:[(CGFloat,CGFloat)]=[]
    for i in 0...N {
        let t=CGFloat(i)/CGFloat(N)
        let c=cubic(p0,p1,p2,p3,t); let d=deriv(p0,p1,p2,p3,t)
        let len=max(0.0001, (d.0*d.0+d.1*d.1).squareRoot())
        let nx = -d.1/len, ny = d.0/len
        let w=(wBase+(wTip-wBase)*t)/2
        left.append(CGPoint(x:c.0+nx*w,y:c.1+ny*w))
        right.append(CGPoint(x:c.0-nx*w,y:c.1-ny*w))
        mids.append(c)
    }
    ctx.beginPath()
    ctx.move(to:left[0])
    for pt in left.dropFirst(){ ctx.addLine(to:pt) }
    // round the tip
    ctx.addArc(center:CGPoint(x:p3.0,y:p3.1), radius:max(0.4,wTip/2), startAngle:0, endAngle:.pi*2, clockwise:false)
    for pt in right.reversed(){ ctx.addLine(to:pt) }
    ctx.closePath(); ctx.fillPath()
    if let sc=suckers {
        ctx.setFillColor(sc)
        for tt in stride(from:0.45, through:0.92, by:0.16){
            let c=mids[Int(round(CGFloat(tt)*CGFloat(N)))]
            let r=1.9-CGFloat(tt)*0.7
            ctx.fillEllipse(in:CGRect(x:c.0-r,y:c.1-r,width:2*r,height:2*r))
        }
    }
}
func dot(_ ctx:CGContext,_ x:CGFloat,_ y:CGFloat,_ r:CGFloat){ ctx.fillEllipse(in:CGRect(x:x-r,y:y-r,width:2*r,height:2*r)) }

// MARK: Option A — Curly cartoon octopus (coral, arms curl every which way)

func optionA(_ ctx:CGContext){
    let coral=rgb(255,120,102), dark=rgb(224,88,72), light=rgb(255,166,150), suck=rgb(255,200,188)
    // Left arms (mirrored to right). Cubic centerlines that hook at the tips.
    let L:[[(CGFloat,CGFloat)]]=[
        [(35,52),(18,46),(9,30),(20,20)],
        [(39,49),(26,34),(18,17),(31,11)],
        [(44,47),(39,29),(31,12),(43,9)],
        [(47,46),(47,28),(43,11),(50,8)],
    ]
    ctx.setFillColor(dark)
    for a in L { tentacle(ctx,a[0],a[1],a[2],a[3],wBase:13,wTip:1.6, suckers:suck); ctx.setFillColor(dark) }
    for a in L { let m=a.map{(100-$0.0,$0.1)}; ctx.setFillColor(dark); tentacle(ctx,m[0],m[1],m[2],m[3],wBase:13,wTip:1.6,suckers:suck) }
    // Head
    ctx.setFillColor(coral); ctx.fillEllipse(in:CGRect(x:26,y:40,width:48,height:50))
    ctx.fillEllipse(in:CGRect(x:23,y:41,width:54,height:20))
    ctx.saveGState(); ctx.setAlpha(0.55); ctx.setFillColor(light); ctx.fillEllipse(in:CGRect(x:33,y:63,width:26,height:19)); ctx.restoreGState()
    // Face
    ctx.setFillColor(rgb(255,255,255)); dot(ctx,43,64,8.2); dot(ctx,57,64,8.2)
    ctx.setFillColor(rgb(40,52,62)); dot(ctx,44.4,62.7,4.0); dot(ctx,55.6,62.7,4.0)
    ctx.setFillColor(rgb(255,255,255)); dot(ctx,45.8,64.3,1.6); dot(ctx,57,64.3,1.6)
    ctx.setStrokeColor(dark); ctx.setLineWidth(1.8); ctx.setLineCap(.round)
    ctx.beginPath(); ctx.move(to:CGPoint(x:46,y:54)); ctx.addQuadCurve(to:CGPoint(x:54,y:54),control:CGPoint(x:50,y:50.5)); ctx.strokePath()
}

// MARK: Option B — Chunky kawaii blob (purple, stubby legs)

func optionB(_ ctx:CGContext){
    let body=rgb(150,120,232), dark=rgb(120,92,206), light=rgb(196,178,255)
    // stubby legs = row of rounded bumps under the head
    ctx.setFillColor(dark)
    for x:CGFloat in [24,37,50,63,76]{ dot(ctx,x,32,9.5) }
    // big rounded head/body
    ctx.setFillColor(body); ctx.fillEllipse(in:CGRect(x:18,y:30,width:64,height:56))
    ctx.setFillColor(body); ctx.fill(CGRect(x:18,y:30,width:64,height:22)) // square off the base to seat the legs
    ctx.setFillColor(body); for x:CGFloat in [24,37,50,63,76]{ dot(ctx,x,34,9.5) } // front row lighter (same body) to blend
    // top highlight
    ctx.saveGState(); ctx.setAlpha(0.5); ctx.setFillColor(light); ctx.fillEllipse(in:CGRect(x:30,y:60,width:26,height:18)); ctx.restoreGState()
    // cheeks
    ctx.saveGState(); ctx.setAlpha(0.5); ctx.setFillColor(rgb(255,150,170)); dot(ctx,35,50,5); dot(ctx,65,50,5); ctx.restoreGState()
    // eyes
    ctx.setFillColor(rgb(52,44,86)); dot(ctx,41,58,5.4); dot(ctx,59,58,5.4)
    ctx.setFillColor(rgb(255,255,255)); dot(ctx,42.8,59.8,1.9); dot(ctx,60.8,59.8,1.9)
    // mouth
    ctx.setStrokeColor(rgb(52,44,86)); ctx.setLineWidth(1.6); ctx.setLineCap(.round)
    ctx.beginPath(); ctx.move(to:CGPoint(x:47,y:50)); ctx.addQuadCurve(to:CGPoint(x:53,y:50),control:CGPoint(x:50,y:47)); ctx.strokePath()
}

// MARK: Option C — Emblem: clean white silhouette, symmetric curled crest

func optionC(_ ctx:CGContext){
    // white octopus on deep gradient; symmetric arms curling outward like a crest
    ctx.setFillColor(rgb(255,255,255))
    let L:[[(CGFloat,CGFloat)]]=[
        [(37,48),(17,45),(6,29),(9,45)],   // outer, curls out+up
        [(41,45),(25,31),(13,19),(9,31)],
        [(46,44),(39,27),(30,13),(24,20)],
        [(49,43),(49,25),(45,11),(51,9)],  // inner
    ]
    for a in L { tentacle(ctx,a[0],a[1],a[2],a[3],wBase:12,wTip:1.4) }
    for a in L { let m=a.map{(100-$0.0,$0.1)}; tentacle(ctx,m[0],m[1],m[2],m[3],wBase:12,wTip:1.4) }
    ctx.fillEllipse(in:CGRect(x:27,y:40,width:46,height:50))
    ctx.fillEllipse(in:CGRect(x:24,y:41,width:52,height:19))
    // eyes punched to reveal the gradient
    ctx.setBlendMode(.clear); dot(ctx,43,63,6.4); dot(ctx,57,63,6.4); ctx.setBlendMode(.normal)
}

let sz=512
writePNG(tile(sz, rgb(84,208,224), rgb(24,118,184), optionA), "\(previewDir)/opt-a.png")
writePNG(tile(sz, rgb(201,184,255), rgb(123,108,217), optionB), "\(previewDir)/opt-b.png")
writePNG(tile(sz, rgb(38,70,120),  rgb(14,28,58),   optionC), "\(previewDir)/opt-c.png")
// small-size sanity checks
writePNG(tile(64, rgb(84,208,224), rgb(24,118,184), optionA), "\(previewDir)/opt-a-64.png")
writePNG(tile(64, rgb(201,184,255), rgb(123,108,217), optionB), "\(previewDir)/opt-b-64.png")
writePNG(tile(64, rgb(38,70,120),  rgb(14,28,58),   optionC), "\(previewDir)/opt-c-64.png")
