import SwiftUI
import SceneKit
import simd
import PipeCutCore

struct WorkshopScene: NSViewRepresentable {
    let solution: Solution
    let mode: String
    let revision: Int
    let grid: Bool

    final class Coordinator {
        var key = ""
        var mode = ""
        var revision = -1
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.allowsCameraControl = true
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = NSColor(calibratedRed: 0.075, green: 0.085, blue: 0.095, alpha: 1)
        view.defaultCameraController.worldUp = SCNVector3(0, 0, 1)
        view.defaultCameraController.inertiaEnabled = true
        return view
    }
    func updateNSView(_ view: SCNView, context: Context) {
        let p = solution.p
        let key = "\(p.mainDiameter),\(p.mainWall),\(p.branchDiameter),\(p.branchWall),\(p.angle),\(p.offset),\(p.gap)"
        let rebuild = context.coordinator.key != key
        if rebuild {
            let transform = view.pointOfView?.transform
            view.scene = makeScene(solution)
            view.pointOfView = view.scene?.rootNode.childNode(withName: "camera", recursively: false)
            if let transform, !context.coordinator.key.isEmpty { view.pointOfView?.transform = transform }
            context.coordinator.key = key
        }
        view.scene?.rootNode.childNode(withName: "grid", recursively: false)?.isHidden = !grid
        if context.coordinator.mode != mode || context.coordinator.revision != revision {
            positionCamera(view, mode: mode)
            context.coordinator.mode = mode
            context.coordinator.revision = revision
        }
        view.isPlaying = true
    }
    private func positionCamera(_ view: SCNView, mode: String) {
        guard let camera = view.pointOfView else { return }
        let box = view.scene?.rootNode.childNode(withName: "assembly", recursively: false)?.boundingBox
        let low = box?.min ?? SCNVector3(-1.4,-0.5,-0.5)
        let high = box?.max ?? SCNVector3(1.4,0.5,1.5)
        let target = SCNVector3((low.x+high.x)/2, (low.y+high.y)/2, (low.z+high.z)/2)
        let span = max(high.x-low.x, high.y-low.y, high.z-low.z)
        let factor = max(0.8, span/2.8)
        let aspect = max(1, view.bounds.width / max(1, view.bounds.height))
        let vertical = mode == "Сверху" ? high.y-low.y : high.z-low.z
        camera.camera?.usesOrthographicProjection = mode != "Перспектива"
        camera.camera?.orthographicScale = Double(max(vertical/2, (high.x-low.x)/(2*aspect)) * 1.25)
        switch mode {
        case "Спереди": camera.position = SCNVector3(target.x, target.y-5, target.z)
        case "Сверху": camera.position = SCNVector3(target.x, target.y-0.001, target.z+5)
        default: camera.position = SCNVector3(target.x+2.4*factor, target.y-4.4*factor, target.z+2.6*factor)
        }
        camera.look(at: target, up: SCNVector3(0, 0, 1), localFront: SCNVector3(0, 0, -1))
        view.defaultCameraController.target = target
    }

    private func makeScene(_ s: Solution) -> SCNScene {
        let scene = SCNScene(), p = s.p, scale = 1 / s.p.mainDiameter
        let assembly = SCNNode(); assembly.name = "assembly"; scene.rootNode.addChildNode(assembly)
        let steel = SCNMaterial()
        steel.lightingModel = .blinn
        steel.diffuse.contents = NSColor(calibratedWhite: 0.34, alpha: 1)
        steel.specular.contents = NSColor(calibratedWhite: 0.55, alpha: 1)
        steel.shininess = 0.5
        steel.isDoubleSided = true

        // Build hollow walls and end rims. The main pipe stays intact in the MVP;
        // the orange line indicates the exact outer-surface intersection.
        let n = 180
        var mainVertices: [SCNVector3] = []
        for i in 0...n {
            let phi = Double(i) * 2 * .pi / Double(n)
            for (x, r) in [(-1.4, 0.5), (1.4, 0.5), (-1.4, 0.5 - p.mainWall * scale), (1.4, 0.5 - p.mainWall * scale)] {
                mainVertices.append(SCNVector3(x, r * cos(phi), r * sin(phi)))
            }
        }
        var mainFaces: [Int32] = []
        for i in 0..<n {
            let j = Int32(i * 4)
            for (a, b) in [(Int32(0), Int32(1)), (2, 3), (0, 2), (1, 3)] {
                let face: [Int32] = [j+a, j+b, j+a+4, j+b, j+b+4, j+a+4]
                mainFaces += (a == 0 && b == 1) || (a == 1 && b == 3) ? [face[0],face[2],face[1],face[3],face[5],face[4]] : face
            }
        }
        assembly.addChildNode(surface(mainVertices, mainFaces, steel))

        var branchVertices: [SCNVector3] = []
        let angle = p.angle * .pi / 180
        // Keep the visible barrel proportional for all valid pipe sizes.
        let end = (s.outer.map(\.t).max() ?? 0) + p.gap + p.mainDiameter * 0.85
        for i in stride(from: 0, to: s.outer.count, by: 4) {
            let q = s.outer[i], inner = s.inner[i]
            for (r, t) in [(p.branchDiameter/2, q.t+p.gap), (p.branchDiameter/2, end), (p.branchDiameter/2-p.branchWall, inner.t+p.gap), (p.branchDiameter/2-p.branchWall, end)] {
                branchVertices.append(SCNVector3((t*cos(angle)+r*cos(q.phi)*sin(angle))*scale,
                                                 (p.offset+r*sin(q.phi))*scale,
                                                 (t*sin(angle)-r*cos(q.phi)*cos(angle))*scale))
            }
        }
        var branchFaces: [Int32] = []
        for i in 0..<(branchVertices.count/4 - 1) {
            let j = Int32(i * 4)
            for (a, b) in [(Int32(0), Int32(1)), (2, 3), (1, 3), (0, 2)] {
                let face: [Int32] = [j+a, j+b, j+a+4, j+b, j+b+4, j+a+4]
                branchFaces += (a == 0 && b == 1) || (a == 1 && b == 3) ? [face[0],face[2],face[1],face[3],face[5],face[4]] : face
            }
        }
        assembly.addChildNode(surface(branchVertices, branchFaces, steel))

        let orange = SCNMaterial()
        orange.lightingModel = .constant
        orange.diffuse.contents = NSColor(calibratedRed: 1, green: 0.43, blue: 0.09, alpha: 1)
        let samples = stride(from: 0, to: s.outer.count, by: 6).map { i -> SCNVector3 in
            let q = s.outer[i]
            return SCNVector3((q.point.x+p.gap*cos(angle))*scale, q.point.y*scale, (q.point.z+p.gap*sin(angle))*scale)
        }
        let cut = SCNNode()
        for i in 0..<samples.count-1 {
            let a = samples[i], b = samples[i+1]
            let dx = b.x-a.x, dy = b.y-a.y, dz = b.z-a.z
            let length = sqrt(dx*dx+dy*dy+dz*dz)
            let g = SCNCylinder(radius: 0.003, height: CGFloat(length))
            g.radialSegmentCount = 6; g.materials = [orange]
            let node = SCNNode(geometry: g)
            node.position = SCNVector3((a.x+b.x)/2, (a.y+b.y)/2, (a.z+b.z)/2)
            node.look(at: b, up: SCNVector3(0,0,1), localFront: SCNVector3(0,1,0))
            cut.addChildNode(node)
        }
        assembly.addChildNode(cut)

        var gridPoints: [SCNVector3] = []
        for i in -15...15 {
            let f = Double(i) * 0.2
            gridPoints += [SCNVector3(-3,f,-0.51),SCNVector3(3,f,-0.51),SCNVector3(f,-3,-0.51),SCNVector3(f,3,-0.51)]
        }
        let gridGeometry = SCNGeometry(sources: [SCNGeometrySource(vertices: gridPoints)], elements: [SCNGeometryElement(indices: (0..<gridPoints.count).map(Int32.init), primitiveType: .line)])
        gridGeometry.firstMaterial?.lightingModel = .constant
        gridGeometry.firstMaterial?.diffuse.contents = NSColor(calibratedWhite: 0.20, alpha: 1)
        let gridNode = SCNNode(geometry: gridGeometry); gridNode.name = "grid"
        scene.rootNode.addChildNode(gridNode)

        let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient
        ambient.light?.intensity = 180; ambient.light?.color = NSColor(calibratedWhite: 0.72, alpha: 1)
        scene.rootNode.addChildNode(ambient)
        for (position, intensity) in [(SCNVector3(-2,-3,5),CGFloat(600)),(SCNVector3(3,2,3),CGFloat(350))] {
            let light = SCNNode(); light.light = SCNLight(); light.light?.type = .omni; light.light?.intensity = intensity; light.position = position
            scene.rootNode.addChildNode(light)
        }
        let camera = SCNNode(); camera.name = "camera"; camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 38; camera.camera?.zNear = 0.01; camera.camera?.zFar = 100
        scene.rootNode.addChildNode(camera)
        return scene
    }
    private func surface(_ vertices: [SCNVector3], _ indices: [Int32], _ material: SCNMaterial) -> SCNNode {
        var normals = Array(repeating: SIMD3<Double>(repeating: 0), count: vertices.count)
        for i in stride(from: 0, to: indices.count, by: 3) {
            let a = Int(indices[i]), b = Int(indices[i+1]), c = Int(indices[i+2])
            let va = SIMD3<Double>(Double(vertices[a].x), Double(vertices[a].y), Double(vertices[a].z))
            let vb = SIMD3<Double>(Double(vertices[b].x), Double(vertices[b].y), Double(vertices[b].z))
            let vc = SIMD3<Double>(Double(vertices[c].x), Double(vertices[c].y), Double(vertices[c].z))
            let normal = simd_cross(vb-va, vc-va)
            normals[a] += normal; normals[b] += normal; normals[c] += normal
        }
        let vectors = normals.map { n -> SCNVector3 in
            let v = simd_length_squared(n) > 1e-12 ? simd_normalize(n) : SIMD3<Double>(0,0,1)
            return SCNVector3(v.x,v.y,v.z)
        }
        let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: vectors)], elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        geometry.materials = [material]
        return SCNNode(geometry: geometry)
    }
}
