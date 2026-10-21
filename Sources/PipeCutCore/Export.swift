import Foundation
import CoreGraphics
public struct Drawing: Sendable {
 public var contours=true, walls=true, axes=true, dimensions=true, marks=true
 public init(){}
 public func lines(_ s:Solution,hole:Bool)->[(String,[P2])] {
  let a=hole ? s.hole:s.branch, b=hole ? s.holeInner:s.branchInner
  let xmin=a.map(\.x).min()!, xmax=a.map(\.x).max()!, ymin=a.map(\.y).min()!, ymax=a.map(\.y).max()!
  var lines:[(String,[P2])]=[]
  if contours {lines.append(("CUT",a))};if walls {lines.append(("WALL_REFERENCE",b))}
  if axes {lines.append(("AXIS",[P2(xmin-5,0),P2(xmax+5,0)]));lines.append(("AXIS",[P2((xmin+xmax)/2,ymin-5),P2((xmin+xmax)/2,ymax+5)]))}
  if marks {for i in [0,a.count/4,a.count/2,3*a.count/4] {let q=a[i];lines.append(("ALIGN",[P2(q.x-2,q.y),P2(q.x+2,q.y)]));lines.append(("ALIGN",[P2(q.x,q.y-2),P2(q.x,q.y+2)]))}}
  if dimensions {lines.append(("CALIBRATION_100_MM",[P2(xmin,ymax+12),P2(xmin+100,ymax+12)]));for x in [xmin,xmin+100] {lines.append(("CALIBRATION_100_MM",[P2(x,ymax+10),P2(x,ymax+14)]))}}
  return lines
 }
 public func dxf(_ s:Solution,hole:Bool)->String {
  var out="0\nSECTION\n2\nHEADER\n9\n$ACADVER\n1\nAC1015\n9\n$INSUNITS\n70\n4\n9\n$MEASUREMENT\n70\n1\n0\nENDSEC\n0\nSECTION\n2\nENTITIES\n"
  for (layer,points) in lines(s,hole:hole) {out += "0\nLWPOLYLINE\n100\nAcDbEntity\n8\n\(layer)\n100\nAcDbPolyline\n90\n\(points.count)\n70\n0\n"; for p in points {out += "10\n\(p.x)\n20\n\(p.y)\n"}}
  return out+"0\nENDSEC\n0\nEOF\n"
 }
 public func pdf(_ s:Solution,hole:Bool,to url:URL) throws {
  let lines=lines(s,hole:hole), points=lines.flatMap{$0.1}
  guard !points.isEmpty else {throw GeometryError.invalid}
  let minX=points.map(\.x).min()!,maxX=points.map(\.x).max()!,minY=points.map(\.y).min()!,maxY=points.map(\.y).max()!, k=72.0/25.4
  var box=CGRect(x:0,y:0,width:(maxX-minX+20)*k,height:(maxY-minY+20)*k)
  guard let ctx=CGContext(url as CFURL,mediaBox:&box,nil) else {throw GeometryError.invalid}
  ctx.beginPDFPage(nil);ctx.scaleBy(x:k,y:k);ctx.translateBy(x:10-minX,y:10-minY)
  for (layer,line) in lines {
   ctx.setLineWidth(layer == "CUT" ? 0.2:0.12)
   ctx.setStrokeColor(gray:layer == "CUT" ? 0:0.45,alpha:1)
   ctx.setLineDash(phase:0,lengths:layer == "WALL_REFERENCE" || layer == "AXIS" ? [2,1]:[])
   ctx.beginPath();for (i,p) in line.enumerated(){if i==0 {ctx.move(to:CGPoint(x:p.x,y:p.y))}else {ctx.addLine(to:CGPoint(x:p.x,y:p.y))}};ctx.strokePath()
  };ctx.endPDFPage();ctx.closePDF()
 }
}
