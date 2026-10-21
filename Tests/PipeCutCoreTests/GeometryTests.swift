import XCTest
import CoreGraphics
@testable import PipeCutCore
final class GeometryTests:XCTestCase {
 func testCylinderResiduals() throws {
  for angle in [30.0,60,90] {for offset in [-15.0,0,15] {
   var p=Parameters();p.angle=angle;p.offset=offset;let s=try Solution(p)
   for q in s.outer {let a=angle * .pi/180
    XCTAssertEqual(q.point.y*q.point.y+q.point.z*q.point.z,10000,accuracy:1e-8)
    let radial=q.point.x*sin(a)-q.point.z*cos(a)
    XCTAssertEqual(radial*radial+pow(q.point.y-offset,2),2500,accuracy:1e-8)
   }
  }}
 }
 func testAnalyticRightAngle() throws {var p=Parameters();p.angle=90;let s=try Solution(p);XCTAssertEqual(s.outer[0].t,100,accuracy:1e-9);XCTAssertEqual(s.outer[360].t,sqrt(7500),accuracy:1e-9);XCTAssertEqual(s.branch.last!.x,100 * .pi,accuracy:1e-9)}
 func testInvalidAndTopology() {var p=Parameters();p.offset=50;XCTAssertThrowsError(try Solution(p));p=Parameters();p.branchDiameter=201;XCTAssertThrowsError(try Solution(p));p=Parameters();p.mainWall = .nan;XCTAssertThrowsError(try Solution(p));p=Parameters();p.angle=29;XCTAssertThrowsError(try Solution(p))}
 func testGapAndWalls() throws {var p=Parameters();let a=try Solution(p);p.gap=3;let b=try Solution(p);XCTAssertEqual(a.datum,b.datum,accuracy:1e-9);XCTAssertEqual(a.branch[0].y-3,b.branch[0].y,accuracy:1e-9);XCTAssertNotEqual(a.inner[0].t,a.outer[0].t);XCTAssertLessThan(a.mainInner[0].t,a.outer[0].t)}
 func testExports() throws {
  let s=try Solution(Parameters()),d=Drawing()
  let dir=FileManager.default.temporaryDirectory.appendingPathComponent("PipeCut-test-\(UUID().uuidString)");try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
  defer {try? FileManager.default.removeItem(at:dir)}
  for hole in [false,true] {let url=dir.appendingPathComponent("test.pdf");try d.pdf(s,hole:hole,to:url)
   let doc=try XCTUnwrap(CGPDFDocument(url as CFURL));XCTAssertEqual(doc.numberOfPages,1)
   let box=try XCTUnwrap(doc.page(at:1)).getBoxRect(.mediaBox),pts=d.lines(s,hole:hole).flatMap{$0.1}
   XCTAssertEqual(box.width,(pts.map(\.x).max()!-pts.map(\.x).min()!+20)*72/25.4,accuracy:0.01)
   let dxf=d.dxf(s,hole:hole);XCTAssertTrue(dxf.contains("$INSUNITS\n70\n4\n"));XCTAssertTrue(dxf.hasSuffix("0\nEOF\n"));XCTAssertTrue(dxf.contains("WALL_REFERENCE"))
  }
  var hidden=d;hidden.walls=false;hidden.marks=false;XCTAssertFalse(hidden.dxf(s,hole:false).contains("WALL_REFERENCE"));XCTAssertFalse(hidden.dxf(s,hole:false).contains("ALIGN"))
 }
 func testConvergence() throws {let p=Parameters(),fine=try Solution(p,count:2880),coarse=try Solution(p,count:1440);for i in coarse.outer.indices {XCTAssertEqual(coarse.outer[i].t,fine.outer[2*i].t,accuracy:1e-10)}}
}
