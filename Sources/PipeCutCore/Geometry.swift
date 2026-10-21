import Foundation
public struct V3: Sendable { public var x,y,z: Double }
public struct P2: Sendable { public var x,y: Double; public init(_ x:Double,_ y:Double){self.x=x;self.y=y} }
public struct Parameters: Sendable {
 public var mainDiameter=200.0, mainWall=6.0, branchDiameter=100.0, branchWall=4.0, angle=60.0, offset=0.0, gap=0.0
 public init() {}
 public func validate() throws {
  let all=[mainDiameter,mainWall,branchDiameter,branchWall,angle,offset,gap]
  guard all.allSatisfy({$0.isFinite}), mainDiameter > 0, mainDiameter <= 5000, branchDiameter > 0, branchDiameter <= mainDiameter, mainWall > 0, mainWall < mainDiameter/2, branchWall > 0, branchWall < branchDiameter/2, (30...90).contains(angle), (0...20).contains(gap) else { throw GeometryError.invalid }
  // A single near-side closed saddle must intersect both main surfaces for every generator.
  guard abs(offset)+branchDiameter/2 < mainDiameter/2-mainWall-0.001 else {throw GeometryError.topology}
 }
}
public enum GeometryError: Error, LocalizedError {
 case invalid, topology
 public var errorDescription:String? { switch self {case .invalid: return "Проверьте диаметры, толщины, угол 30–90° и зазор 0–20 мм (D ≤ 5000 мм)."; case .topology:return "Для 0.1 требуется |смещение| + d/2 < D/2 − толщина основной трубы. Иначе замкнутая врезка не поддерживается."} }
}
public struct Sample: Sendable {public let phi,t:Double; public let point:V3}
public struct Solution: Sendable {
 public let p:Parameters
 public let outer,inner,mainInner:[Sample]
 public init(_ p:Parameters, count:Int=1440) throws {
  try p.validate(); guard count>=32 && count<=100000 else {throw GeometryError.invalid};self.p=p
  outer=Self.intersect(p, radius:p.branchDiameter/2, mainRadius:p.mainDiameter/2,count:count)
  inner=Self.intersect(p, radius:p.branchDiameter/2-p.branchWall, mainRadius:p.mainDiameter/2,count:count)
  mainInner=Self.intersect(p, radius:p.branchDiameter/2, mainRadius:p.mainDiameter/2-p.mainWall,count:count)
 }
 // Main axis X. Branch axis (cos a,0,sin a), foot (0,offset,0).
 static func intersect(_ p:Parameters,radius r:Double,mainRadius R:Double,count:Int)->[Sample]{
  let a=p.angle * .pi/180, s=sin(a), c=cos(a)
  return (0...count).map { i in
   let phi=Double(i)*2 * .pi/Double(count), y=p.offset+r*sin(phi)
   let z=sqrt(max(0,R*R-y*y)), t=(z+r*cos(phi)*c)/s
   return Sample(phi:phi,t:t,point:V3(x:t*c+r*cos(phi)*s,y:y,z:z))
  }
 }
 public var datum:Double {(outer.map(\.t).max() ?? 0)+50}
 public var branch:[P2] {outer.map{P2(p.branchDiameter/2*$0.phi,datum-$0.t-p.gap)}}
 public var branchInner:[P2] {inner.map{P2(p.branchDiameter/2*$0.phi,datum-$0.t-p.gap)}}
 public var hole:[P2] {outer.map{P2($0.point.x,p.mainDiameter/2*atan2($0.point.y,$0.point.z))}}
 public var holeInner:[P2] {mainInner.map{P2($0.point.x,p.mainDiameter/2*atan2($0.point.y,$0.point.z))}}
}
