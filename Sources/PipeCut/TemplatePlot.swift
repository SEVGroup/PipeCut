import SwiftUI
import PipeCutCore

struct TemplatePlot: View {
    let solution: Solution
    let drawing: Drawing
    let hole: Bool

    var body: some View {
        VStack(spacing: 5) {
            Canvas { context, size in
                // The viewport fits selected export lines and preserves aspect ratio.
                var grid = Path()
                for x in stride(from: 0.0, through: size.width, by: 16) {
                    grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: 0.0, through: size.height, by: 16) {
                    grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(.white.opacity(0.035)), lineWidth: 0.5)
                let lines = drawing.lines(solution, hole: hole)
                let points = lines.flatMap { $0.1 }
                guard let x0 = points.map(\.x).min(), let x1 = points.map(\.x).max(),
                      let y0 = points.map(\.y).min(), let y1 = points.map(\.y).max() else {
                    context.draw(Text("Все линии скрыты").font(.system(size: 10)).foregroundColor(Workshop.muted), at: CGPoint(x: size.width / 2, y: size.height / 2))
                    return
                }
                let scale = min((size.width - 28) / max(1, x1 - x0), (size.height - 20) / max(1, y1 - y0))
                let left = (size.width - (x1 - x0) * scale) / 2
                let top = (size.height - (y1 - y0) * scale) / 2
                for (layer, points) in lines {
                    var path = Path()
                    for (i, p) in points.enumerated() {
                        let point = CGPoint(x: left + (p.x - x0) * scale, y: top + (y1 - p.y) * scale)
                        if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                    let color: Color = layer == "CUT" ? Color(red: 0.93, green: 0.83, blue: 0.68) : layer == "ALIGN" ? Workshop.orange : Workshop.muted.opacity(0.7)
                    let dashed = layer == "AXIS" || layer == "WALL_REFERENCE"
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: layer == "CUT" ? 1.5 : 0.7, dash: dashed ? [4, 3] : []))
                }
            }
            HStack {
                Text(hole ? "Ø D \(solution.p.mainDiameter, specifier: "%.1f") мм" : "Окружность \(solution.p.branchDiameter * .pi, specifier: "%.2f") мм")
                Spacer()
                Text(drawing.dimensions ? "Калибр 100 мм" : "мм")
            }.font(.system(size: 9, design: .monospaced)).foregroundStyle(Workshop.muted)
        }
    }
}
