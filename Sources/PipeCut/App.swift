import SwiftUI
import SceneKit
import PipeCutCore

@main struct PipeCutApp: App {
 init() {
  if let i=CommandLine.arguments.firstIndex(of:"--export-samples"),CommandLine.arguments.count>i+1 {
   do {let dir=URL(fileURLWithPath:CommandLine.arguments[i+1]);try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true);let s=try Solution(Parameters());for hole in [false,true] {let name=hole ? "main-hole":"branch-cut";try Drawing().pdf(s,hole:hole,to:dir.appendingPathComponent(name+".pdf"));try Drawing().dxf(s,hole:hole).write(to:dir.appendingPathComponent(name+".dxf"),atomically:true,encoding:.utf8)};exit(0)}catch{print(error);exit(1)}
  }
 }
 var body: some Scene {WindowGroup {ContentView().frame(minWidth:1100,minHeight:720)}}
}
struct ContentView: View {
 @State private var p=Parameters()
 @State private var drawing=Drawing()
 @State private var hole=false
 @State private var message=""
 var result:Result<Solution,Error>{Result {try Solution(p)}}
 var body: some View {
  HSplitView {
   VStack(alignment:.leading,spacing:10) {
    Text("PipeCut 0.1").font(.largeTitle)
    Text("Экспериментальный геометрический шаблон").foregroundStyle(.secondary)
    field("Основная: наружный Ø, мм",$p.mainDiameter)
    field("Стенка основной, мм",$p.mainWall)
    field("Ответвление: наружный Ø, мм",$p.branchDiameter)
    field("Стенка ответвления, мм",$p.branchWall)
    field("Угол, °",$p.angle)
    Slider(value:$p.angle,in:30...90)
    field("Смещение осей, мм",$p.offset)
    field("Осевой отступ (зазор), мм",$p.gap)
    Toggle("Контуры реза",isOn:$drawing.contours)
    Toggle("Стенки: справочные линии",isOn:$drawing.walls)
    Toggle("Осевые",isOn:$drawing.axes)
    Toggle("Калибр 100 мм",isOn:$drawing.dimensions)
    Toggle("Метки совмещения",isOn:$drawing.marks)
    Button("Сбросить параметры"){p=Parameters()}
    Text("Зазор — отступ вдоль оси ответвления. Не постоянный нормальный зазор. Штриховые линии — справочные, не команды реза. Перед изготовлением нужна проверка на образце.").font(.caption)
   }.padding().frame(minWidth:300,idealWidth:330,maxWidth:380)
   VStack {
    switch result {
    case .success(let s):
     let world=scene(s)
     SceneHost(world:world).frame(minHeight:260)
     Text("3D: тяните мышью для вращения, колесо — масштаб. Контур стыка показан зелёным.").font(.caption)
     Picker("Развёртка",selection:$hole){Text("Ответвление").tag(false);Text("Отверстие основной").tag(true)}.pickerStyle(.segmented)
     Canvas {ctx,size in
      let lines=drawing.lines(s,hole:hole), pts=lines.flatMap{$0.1}
      if let x0=pts.map(\.x).min(),let x1=pts.map(\.x).max(),let y0=pts.map(\.y).min(),let y1=pts.map(\.y).max(){
       let scale=min((size.width-30)/max(1,x1-x0),(size.height-30)/max(1,y1-y0))
       for (layer,ps) in lines {var path=Path();for (i,q) in ps.enumerated(){let t=CGPoint(x:15+(q.x-x0)*scale,y:size.height-15-(q.y-y0)*scale);if i==0 {path.move(to:t)}else{path.addLine(to:t)}};ctx.stroke(path,with:.color(layer == "CUT" ? .black:.gray),style:StrokeStyle(lineWidth:layer == "CUT" ? 1.5:0.7,dash:layer == "WALL_REFERENCE" ? [4,3]:[]))}
      }
     }.frame(minHeight:200).background(.white)
     Text(String(format:"D %.2f × %.2f; d %.2f × %.2f мм; угол %.2f°; смещение %.2f; зазор %.2f мм. Калибр = 100 мм.",p.mainDiameter,p.mainWall,p.branchDiameter,p.branchWall,p.angle,p.offset,p.gap)).font(.caption)
     HStack {Button("Экспорт PDF 1:1"){export(s,pdf:true)};Button("Экспорт DXF (мм)"){export(s,pdf:false)}}
    case .failure(let e):Text(e.localizedDescription).foregroundStyle(.red).padding()
    }
    Text(message).font(.caption).textSelection(.enabled)
   }.padding()
  }
 }
 func field(_ title:String,_ value:Binding<Double>)->some View {HStack {Text(title).font(.caption).frame(maxWidth:.infinity,alignment:.leading);TextField(title,value:value,format:.number).labelsHidden().textFieldStyle(.roundedBorder).frame(width:85)}}
 func export(_ s:Solution,pdf:Bool){let panel=NSSavePanel();panel.nameFieldStringValue=(hole ? "main-hole":"branch-cut")+(pdf ? ".pdf":".dxf");if panel.runModal() == .OK,let url=panel.url {do {if pdf {try drawing.pdf(s,hole:hole,to:url)}else{try drawing.dxf(s,hole:hole).write(to:url,atomically:true,encoding:.utf8)};message="Сохранено: \(url.path). PDF печатать 100%, без подгонки; проверить калибр 100 мм."}catch{message=error.localizedDescription}}}
 func scene(_ s:Solution)->SCNScene {
  let scene=SCNScene(), scale=1/s.p.mainDiameter
  func cylinder(_ radius:Double,_ height:Double,_ color:NSColor)->SCNNode {let g=SCNCylinder(radius:radius*scale,height:height*scale);g.radialSegmentCount=96;g.firstMaterial?.diffuse.contents=color;g.firstMaterial?.transparency=0.45;return SCNNode(geometry:g)}
  let main=cylinder(p.mainDiameter/2,p.mainDiameter*2,.systemBlue);main.eulerAngles.z = .pi/2;scene.rootNode.addChildNode(main)
  let a=p.angle * .pi/180
  var vertices:[SCNVector3]=[]
  for sample in s.outer {
   for t in [sample.t+p.gap,s.datum+100] {
    let r=p.branchDiameter/2, phi=sample.phi
    vertices.append(SCNVector3((t*cos(a)+r*cos(phi)*sin(a))*scale,(p.offset+r*sin(phi))*scale,(t*sin(a)-r*cos(phi)*cos(a))*scale))
   }
  }
  var triangles:[Int32]=[]
  for i in 0..<s.outer.count-1 {let j=Int32(2*i);triangles += [j,j+1,j+2,j+1,j+3,j+2]}
  let mesh=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices)],elements:[SCNGeometryElement(indices:triangles,primitiveType:.triangles)])
  mesh.firstMaterial?.diffuse.contents=NSColor.systemOrange;mesh.firstMaterial?.isDoubleSided=true;mesh.firstMaterial?.transparency=0.6
  scene.rootNode.addChildNode(SCNNode(geometry:mesh))
  let points=s.outer.map{SCNVector3($0.point.x*scale,$0.point.y*scale,$0.point.z*scale)}
  let indices=(0..<points.count-1).flatMap{[Int32($0),Int32($0+1)]}
  let g=SCNGeometry(sources:[SCNGeometrySource(vertices:points)],elements:[SCNGeometryElement(indices:indices,primitiveType:.line)]);g.firstMaterial?.diffuse.contents=NSColor.systemGreen;g.firstMaterial?.lightingModel = .constant
  scene.rootNode.addChildNode(SCNNode(geometry:g))
  let camera=SCNNode();camera.camera=SCNCamera();camera.position=SCNVector3(2,2,3);camera.look(at:SCNVector3(0,0,0.4));scene.rootNode.addChildNode(camera)
  return scene
 }
}

struct SceneHost:NSViewRepresentable {
 let world:SCNScene
 func makeNSView(context:Context)->SCNView {let view=SCNView();view.allowsCameraControl=true;view.autoenablesDefaultLighting=true;view.backgroundColor = .white;return view}
 func updateNSView(_ view:SCNView,context:Context){view.scene=world;view.pointOfView=world.rootNode.childNodes.last;view.isPlaying=true}
}
