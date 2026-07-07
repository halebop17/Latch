// Round 2 candidates: all based on Option A, on a darker-blue ground.
// D = Option A as-is · E = A + bold emoji outline/face · F = faithful emoji octopus.
// Review only — writes to icon-previews/.
//   swift tools/icon-options2.swift

import AppKit

let previewDir = "icon-previews"

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
func rgb(_ r: CGFloat,_ g: CGFloat,_ b: CGFloat,_ a: CGFloat = 1) -> CGColor { CGColor(red:r/255,green:g/255,blue:b/255,alpha:a) }

// cubic-bezier tapered tentacle (draws in current ctx, 100x100 y-up space)
func cubic(_ p0:(CGFloat,CGFloat),_ p1:(CGFloat,CGFloat),_ p2:(CGFloat,CGFloat),_ p3:(CGFloat,CGFloat),_ t:CGFloat)->(CGFloat,CGFloat){
    let m=1-t
    return (m*m*m*p0.0+3*m*m*t*p1.0+3*m*t*t*p2.0+t*t*t*p3.0, m*m*m*p0.1+3*m*m*t*p1.1+3*m*t*t*p2.1+t*t*t*p3.1)
}
func deriv(_ p0:(CGFloat,CGFloat),_ p1:(CGFloat,CGFloat),_ p2:(CGFloat,CGFloat),_ p3:(CGFloat,CGFloat),_ t:CGFloat)->(CGFloat,CGFloat){
    let m=1-t
    return (3*m*m*(p1.0-p0.0)+6*m*t*(p2.0-p1.0)+3*t*t*(p3.0-p2.0), 3*m*m*(p1.1-p0.1)+6*m*t*(p2.1-p1.1)+3*t*t*(p3.1-p2.1))
}
func tentacle(_ ctx:CGContext,_ p0:(CGFloat,CGFloat),_ p1:(CGFloat,CGFloat),_ p2:(CGFloat,CGFloat),_ p3:(CGFloat,CGFloat), wBase:CGFloat, wTip:CGFloat, suckers:CGColor?=nil){
    let N=28; var left:[CGPoint]=[]; var right:[CGPoint]=[]; var mids:[(CGFloat,CGFloat)]=[]
    for i in 0...N {
        let t=CGFloat(i)/CGFloat(N); let c=cubic(p0,p1,p2,p3,t); let d=deriv(p0,p1,p2,p3,t)
        let len=max(0.0001,(d.0*d.0+d.1*d.1).squareRoot()); let nx = -d.1/len, ny = d.0/len
        let w=(wBase+(wTip-wBase)*t)/2
        left.append(CGPoint(x:c.0+nx*w,y:c.1+ny*w)); right.append(CGPoint(x:c.0-nx*w,y:c.1-ny*w)); mids.append(c)
    }
    ctx.beginPath(); ctx.move(to:left[0]); for p in left.dropFirst(){ctx.addLine(to:p)}
    ctx.addArc(center:CGPoint(x:p3.0,y:p3.1), radius:max(0.4,wTip/2), startAngle:0, endAngle:.pi*2, clockwise:false)
    for p in right.reversed(){ctx.addLine(to:p)}; ctx.closePath(); ctx.fillPath()
    if let sc=suckers { ctx.setFillColor(sc)
        for tt in stride(from:0.45,through:0.92,by:0.16){ let c=mids[Int(round(CGFloat(tt)*CGFloat(N)))]; let r=1.9-CGFloat(tt)*0.7
            ctx.fillEllipse(in:CGRect(x:c.0-r,y:c.1-r,width:2*r,height:2*r)) } }
}
func dot(_ ctx:CGContext,_ x:CGFloat,_ y:CGFloat,_ r:CGFloat){ ctx.fillEllipse(in:CGRect(x:x-r,y:y-r,width:2*r,height:2*r)) }
func ell(_ ctx:CGContext,_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat){ ctx.fillEllipse(in:CGRect(x:x-w/2,y:y-h/2,width:w,height:h)) }

// Render an octopus (100x100 y-up) to its own transparent image of size px.
func octoImage(_ px:Int,_ draw:(CGContext)->Void)->CGImage{
    let ctx=makeContext(px); ctx.scaleBy(x:CGFloat(px)/100,y:CGFloat(px)/100); draw(ctx); return ctx.makeImage()!
}
// Solid-black silhouette of an image (same alpha) — for dilating an outline.
func blacken(_ img:CGImage,_ px:Int)->CGImage{
    let ctx=makeContext(px); let r=CGRect(x:0,y:0,width:px,height:px)
    ctx.draw(img,in:r); ctx.setBlendMode(.sourceIn); ctx.setFillColor(rgb(20,20,22)); ctx.fill(r); return ctx.makeImage()!
}

// Tile with darker-blue gradient; composites the octopus image, optionally with a bold outline.
func tile(_ px:Int,_ outlined:Bool,_ draw:(CGContext)->Void)->CGImage{
    let ctx=makeContext(px); let p=CGFloat(px)
    let inset=p*0.098, t=p-2*inset, corner=t*0.2237
    let rect=CGRect(x:inset,y:inset,width:t,height:t)
    ctx.saveGState()
    ctx.setShadow(offset:CGSize(width:0,height:-p*0.012),blur:p*0.03,color:rgb(0,10,30,0.4))
    ctx.addPath(CGPath(roundedRect:rect,cornerWidth:corner,cornerHeight:corner,transform:nil)); ctx.setFillColor(rgb(0,0,0)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect:rect,cornerWidth:corner,cornerHeight:corner,transform:nil)); ctx.clip()
    let g=CGGradient(colorsSpace:CGColorSpace(name:CGColorSpace.sRGB)!,colors:[rgb(36,92,158),rgb(8,28,58)] as CFArray,locations:[0,1])!
    ctx.drawLinearGradient(g,start:CGPoint(x:0,y:p),end:CGPoint(x:0,y:inset),options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])
    let ti=Int(t.rounded()); let img=octoImage(ti,draw); let dst=CGRect(x:inset,y:inset,width:CGFloat(ti),height:CGFloat(ti))
    if outlined {
        let black=blacken(img,ti); let s=t*0.032
        var offs:[(CGFloat,CGFloat)]=[]
        for i in 0..<20 { let a=CGFloat(i)*(.pi/10); offs.append((s*cos(a),s*sin(a))) }
        for o in offs { ctx.draw(black,in:dst.offsetBy(dx:o.0,dy:o.1)) }
    }
    ctx.draw(img,in:dst)
    ctx.restoreGState()
    return ctx.makeImage()!
}

// Option A arm centerlines (left; mirrored for right)
let armsA:[[(CGFloat,CGFloat)]]=[
    [(35,52),(18,46),(9,30),(20,20)],
    [(39,49),(26,34),(18,17),(31,11)],
    [(44,47),(39,29),(31,12),(43,9)],
    [(47,46),(47,28),(43,11),(50,8)],
]

// MARK: D — Option A, unchanged (coral, cute eyes), just the darker blue ground
func drawD(_ ctx:CGContext){
    let coral=rgb(255,120,102), dark=rgb(224,88,72), light=rgb(255,166,150), suck=rgb(255,200,188)
    ctx.setFillColor(dark)
    for a in armsA { tentacle(ctx,a[0],a[1],a[2],a[3],wBase:13,wTip:1.6,suckers:suck); ctx.setFillColor(dark) }
    for a in armsA { let m=a.map{(100-$0.0,$0.1)}; ctx.setFillColor(dark); tentacle(ctx,m[0],m[1],m[2],m[3],wBase:13,wTip:1.6,suckers:suck) }
    ctx.setFillColor(coral); ctx.fillEllipse(in:CGRect(x:26,y:40,width:48,height:50)); ctx.fillEllipse(in:CGRect(x:23,y:41,width:54,height:20))
    ctx.saveGState(); ctx.setAlpha(0.55); ctx.setFillColor(light); ctx.fillEllipse(in:CGRect(x:33,y:63,width:26,height:19)); ctx.restoreGState()
    ctx.setFillColor(rgb(255,255,255)); dot(ctx,43,64,8.2); dot(ctx,57,64,8.2)
    ctx.setFillColor(rgb(40,52,62)); dot(ctx,44.4,62.7,4.0); dot(ctx,55.6,62.7,4.0)
    ctx.setFillColor(rgb(255,255,255)); dot(ctx,45.8,64.3,1.6); dot(ctx,57,64.3,1.6)
    ctx.setStrokeColor(dark); ctx.setLineWidth(1.8); ctx.setLineCap(.round)
    ctx.beginPath(); ctx.move(to:CGPoint(x:46,y:54)); ctx.addQuadCurve(to:CGPoint(x:54,y:54),control:CGPoint(x:50,y:50.5)); ctx.strokePath()
}

// Emoji face: dot eyes + round siphon "mouth"
func emojiFace(_ ctx:CGContext,_ bodyColor:CGColor){
    ctx.setFillColor(rgb(28,26,30)); ell(ctx,43.5,67,5.4,7.0); ell(ctx,56.5,67,5.4,7.0)   // eyes
    ctx.setFillColor(rgb(28,26,30)); ell(ctx,50,53,10,13.5)                                  // siphon ring
    ctx.setFillColor(bodyColor);     ell(ctx,50,53.4,6.4,9.6)
    ctx.setFillColor(rgb(150,46,24)); ell(ctx,50,51,3.0,4.6)                                 // inner hollow
}

// MARK: E — A's flowing arms + bold black outline + emoji face
func drawE(_ ctx:CGContext){
    let body=rgb(233,86,42), dark=rgb(206,66,30)
    ctx.setFillColor(dark)
    for a in armsA { ctx.setFillColor(dark); tentacle(ctx,a[0],a[1],a[2],a[3],wBase:13,wTip:1.8) }
    for a in armsA { let m=a.map{(100-$0.0,$0.1)}; ctx.setFillColor(dark); tentacle(ctx,m[0],m[1],m[2],m[3],wBase:13,wTip:1.8) }
    ctx.setFillColor(body); ctx.fillEllipse(in:CGRect(x:26,y:40,width:48,height:50)); ctx.fillEllipse(in:CGRect(x:23,y:41,width:54,height:20))
    emojiFace(ctx, body)
}

// MARK: F — faithful emoji octopus: round head, 6 short tentacles, outer pair curling up
func drawF(_ ctx:CGContext){
    let body=rgb(233,86,42)
    let arms:[[(CGFloat,CGFloat)]]=[
        [(34,50),(16,45),(11,61),(18,68)],   // outer, curls up beside head
        [(40,46),(28,32),(20,20),(26,15)],   // mid
        [(46,44),(45,28),(41,14),(47,12)],   // inner
    ]
    ctx.setFillColor(body)
    for a in arms { tentacle(ctx,a[0],a[1],a[2],a[3],wBase:13,wTip:2.2) }
    for a in arms { let m=a.map{(100-$0.0,$0.1)}; tentacle(ctx,m[0],m[1],m[2],m[3],wBase:13,wTip:2.2) }
    ctx.setFillColor(body); ctx.fillEllipse(in:CGRect(x:27,y:42,width:46,height:46)); ctx.fillEllipse(in:CGRect(x:25,y:44,width:50,height:18))
    emojiFace(ctx, body)
}

for (name, outlined, draw) in [("d",false,drawD),("e",true,drawE),("f",true,drawF)] as [(String,Bool,(CGContext)->Void)] {
    writePNG(tile(512, outlined, draw), "\(previewDir)/opt-\(name).png")
    writePNG(tile(64,  outlined, draw), "\(previewDir)/opt-\(name)-64.png")
}
