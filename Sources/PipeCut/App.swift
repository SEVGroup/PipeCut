import SwiftUI
import SceneKit
import PipeCutCore

@main struct PipeCutApp: App {
    init() {
        if let i = CommandLine.arguments.firstIndex(of: "--export-samples"), CommandLine.arguments.count > i + 1 {
            do {
                let dir = URL(fileURLWithPath: CommandLine.arguments[i + 1])
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let s = try Solution(Parameters())
                for hole in [false, true] {
                    let name = hole ? "main-hole" : "branch-cut"
                    try Drawing().pdf(s, hole: hole, to: dir.appendingPathComponent(name + ".pdf"))
                    try Drawing().dxf(s, hole: hole).write(to: dir.appendingPathComponent(name + ".dxf"), atomically: true, encoding: .utf8)
                }
                exit(0)
            } catch { print(error); exit(1) }
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView().frame(minWidth: 1120, minHeight: 780).preferredColorScheme(.dark)
        }.defaultSize(width: 1360, height: 900).windowStyle(.hiddenTitleBar)
    }
}

enum Workshop {
    static let background = Color(red: 0.075, green: 0.085, blue: 0.095)
    static let panel = Color(red: 0.105, green: 0.117, blue: 0.128)
    static let raised = Color(red: 0.14, green: 0.155, blue: 0.17)
    static let line = Color.white.opacity(0.09)
    static let text = Color(red: 0.90, green: 0.92, blue: 0.94)
    static let muted = Color(red: 0.56, green: 0.60, blue: 0.64)
    static let orange = Color(red: 1, green: 0.43, blue: 0.09)
}

struct ContentView: View {
    @State private var p = Parameters()
    @State private var drawing = Drawing()
    @State private var message = "Готово к работе"
    @State private var viewMode = "Перспектива"
    @State private var cameraRevision = 0
    @State private var showGrid = true
    @State private var showLayers = false
    private var result: Result<Solution, Error> { Result { try Solution(p) } }

    var body: some View {
        let calculation = result
        VStack(spacing: 0) {
            header
            Rectangle().fill(Workshop.line).frame(height: 1)
            HStack(spacing: 0) {
                toolRail
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        if case .success(let s) = calculation {
                            WorkshopScene(solution: s, mode: viewMode, revision: cameraRevision, grid: showGrid)
                        } else {
                            Workshop.background
                            if case .failure(let error) = calculation {
                                VStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle").font(.system(size: 30)).foregroundStyle(Workshop.orange)
                                    Text("Проверьте параметры").font(.title3.weight(.semibold))
                                    Text(error.localizedDescription).foregroundStyle(Workshop.muted).multilineTextAlignment(.center).frame(maxWidth: 420)
                                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        viewportOverlay(valid: (try? calculation.get()) != nil)
                    }.frame(minHeight: 300, maxHeight: .infinity).clipped()
                    templates(calculation).frame(height: 264)
                }
                Rectangle().fill(Workshop.line).frame(width: 1)
                inspector(calculation).frame(width: 294)
            }
            statusBar
        }
        .background(Workshop.background).foregroundStyle(Workshop.text).tint(Workshop.orange)
    }

    private var header: some View {
        HStack(spacing: 14) {
            // Space for the native macOS window controls.
            Color.clear.frame(width: 66, height: 1)
            Image(systemName: "circle.hexagongrid.fill").font(.system(size: 22)).foregroundStyle(Workshop.orange)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("PipeCut").font(.system(size: 19, weight: .semibold))
                Text("0.1").font(.system(size: 11, design: .monospaced)).foregroundStyle(Workshop.muted)
            }
            Rectangle().fill(Workshop.line).frame(width: 1, height: 20).padding(.horizontal, 8)
            Text("Врезка двух труб").font(.system(size: 12)).foregroundStyle(Workshop.muted)
            Spacer()
            HStack(spacing: 6) { Circle().fill(Workshop.orange).frame(width: 5, height: 5); Text("Экспериментальная версия") }
                .font(.system(size: 11)).foregroundStyle(Workshop.muted)
            Button { p = Parameters(); cameraRevision += 1; message = "Параметры сброшены" } label: {
                Label("Сбросить", systemImage: "arrow.counterclockwise").font(.system(size: 12))
            }.buttonStyle(.plain).padding(.horizontal, 12).padding(.vertical, 7)
                .background(Workshop.raised, in: RoundedRectangle(cornerRadius: 5))
        }.padding(.horizontal, 16).frame(height: 54).background(Workshop.panel)
    }

    private var toolRail: some View {
        VStack(spacing: 14) {
            railButton("cursorarrow", help: "Свободное вращение") { viewMode = "Перспектива"; cameraRevision += 1 }
            railButton("cube", help: "Изометрия") { viewMode = "Перспектива"; cameraRevision += 1 }
            railButton("arrow.up.left.and.arrow.down.right", help: "Вписать модель") { cameraRevision += 1 }
            Rectangle().fill(Workshop.line).frame(height: 1).padding(.vertical, 3)
            railButton("square.grid.3x3", help: "Показать сетку", active: showGrid) { showGrid.toggle() }
            railButton("slider.horizontal.3", help: "Видимость линий", active: showLayers) { showLayers.toggle() }
                .popover(isPresented: $showLayers) { layerControls.padding(20).frame(width: 250).preferredColorScheme(.dark) }
            Spacer()
            Image(systemName: "ruler").foregroundStyle(Workshop.muted).padding(.bottom, 15).help("Все размеры в миллиметрах")
        }.padding(.top, 18).padding(.horizontal, 10).frame(width: 54).background(Workshop.panel)
            .overlay(alignment: .trailing) { Rectangle().fill(Workshop.line).frame(width: 1) }
    }
    private func railButton(_ icon: String, help: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16, weight: .medium)).frame(width: 32, height: 32)
                .foregroundStyle(active ? Workshop.orange : Workshop.muted)
                .background(active ? Workshop.orange.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 5))
                .overlay { RoundedRectangle(cornerRadius: 5).stroke(active ? Workshop.orange.opacity(0.45) : .clear) }
        }.buttonStyle(.plain).help(help).accessibilityLabel(help)
    }
    private func viewportOverlay(valid: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("МОДЕЛЬ СОЕДИНЕНИЯ", systemImage: "cube.transparent").font(.system(size: 10, weight: .medium)).tracking(1.1)
                Spacer()
                if valid { Text(String(format: "α %.0f°  /  e %.1f мм", p.angle, p.offset)).font(.system(size: 11, design: .monospaced)) }
            }.foregroundStyle(Workshop.muted).padding(20)
            Spacer()
            HStack(spacing: 5) {
                ForEach(["Перспектива", "Спереди", "Сверху"], id: \.self) { mode in
                    Button { viewMode = mode; cameraRevision += 1 } label: {
                        Text(mode).font(.system(size: 10, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 7)
                            .foregroundStyle(viewMode == mode ? Workshop.orange : Workshop.muted)
                            .background(viewMode == mode ? Workshop.orange.opacity(0.12) : Workshop.panel.opacity(0.9), in: RoundedRectangle(cornerRadius: 4))
                    }.buttonStyle(.plain)
                }
                Spacer()
                Text("Вращение — мышь · Масштаб — колесо").font(.system(size: 10)).foregroundStyle(Workshop.muted)
            }.padding(16)
        }.allowsHitTesting(true)
    }

    private func templates(_ calculation: Result<Solution, Error>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Развёртки").font(.system(size: 13, weight: .semibold))
                Text("НАРУЖНЫЕ ПОВЕРХНОСТИ").font(.system(size: 9, weight: .medium)).tracking(1).foregroundStyle(Workshop.muted)
                Spacer()
                Button { showLayers = true } label: { Label("Линии", systemImage: "line.3.horizontal.decrease").font(.system(size: 11)) }.buttonStyle(.plain).foregroundStyle(Workshop.muted)
            }
            HStack(spacing: 12) {
                templateCard("Ответвление", subtitle: "Фигурный рез", hole: false, calculation: calculation)
                templateCard("Основная труба", subtitle: "Контур отверстия", hole: true, calculation: calculation)
            }
        }.padding(16).background(Workshop.panel)
            .overlay(alignment: .top) { Rectangle().fill(Workshop.line).frame(height: 1) }
    }
    private func templateCard(_ title: String, subtitle: String, hole: Bool, calculation: Result<Solution, Error>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 11, weight: .medium))
                Text(subtitle).font(.system(size: 10)).foregroundStyle(Workshop.muted)
                Spacer(minLength: 0)
                Text(hole ? "02" : "01").font(.system(size: 10, design: .monospaced)).foregroundStyle(Workshop.orange)
            }
            if case .success(let s) = calculation { TemplatePlot(solution: s, drawing: drawing, hole: hole) }
            else { Text("Нет контура").font(.caption).foregroundStyle(Workshop.muted).frame(maxWidth: .infinity, maxHeight: .infinity) }
        }.padding(12).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Workshop.background, in: RoundedRectangle(cornerRadius: 6))
            .overlay { RoundedRectangle(cornerRadius: 6).stroke(Workshop.line) }
    }

    private func inspector(_ calculation: Result<Solution, Error>) -> some View {
        VStack(spacing: 0) {
            HStack { Text("Параметры соединения").font(.system(size: 14, weight: .semibold)); Spacer() }.padding(20)
            Rectangle().fill(Workshop.line).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    parameterGroup("Основная труба", icon: "cylinder", number: "01") {
                        numberField("Диаметр, D", $p.mainDiameter)
                        numberField("Стенка, T", $p.mainWall)
                    }
                    Rectangle().fill(Workshop.line).frame(height: 1)
                    parameterGroup("Ответвление", icon: "cylinder.split.1x2", number: "02") {
                        numberField("Диаметр, d", $p.branchDiameter)
                        numberField("Стенка, t", $p.branchWall)
                    }
                    Rectangle().fill(Workshop.line).frame(height: 1)
                    parameterGroup("Угол и положение", icon: "angle", number: "03") {
                        numberField("Угол, α", $p.angle, unit: "°")
                        Slider(value: $p.angle, in: 30...90).controlSize(.mini).accessibilityLabel("Угол соединения")
                        HStack { Text("30°"); Spacer(); Text("90°") }.font(.system(size: 9, design: .monospaced)).foregroundStyle(Workshop.muted)
                        numberField("Смещение, e", $p.offset)
                        numberField("Осевой зазор, g", $p.gap)
                    }
                    DisclosureGroup("Видимость линий") { layerControls.padding(.top, 10) }.font(.system(size: 11))
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Ограничения 0.1", systemImage: "info.circle").font(.system(size: 10, weight: .medium)).foregroundStyle(Workshop.orange)
                        Text("Зазор вдоль оси, не по нормали. Стенки — справочные линии. Перед изготовлением проверьте шаблон на образце.")
                            .font(.system(size: 10)).foregroundStyle(Workshop.muted).lineSpacing(3)
                    }.padding(12).background(Workshop.orange.opacity(0.045), in: RoundedRectangle(cornerRadius: 5))
                }.padding(20)
            }
            exportControls(calculation).padding(16).background(Workshop.background.opacity(0.5))
        }.background(Workshop.panel)
    }
    private func parameterGroup<Content: View>(_ title: String, icon: String, number: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(number).font(.system(size: 9, design: .monospaced)).foregroundStyle(Workshop.orange)
                Text(title).font(.system(size: 12, weight: .semibold))
                Spacer()
                Image(systemName: icon).font(.system(size: 17)).foregroundStyle(Workshop.muted)
            }.padding(.bottom, 2)
            content()
        }
    }
    private func numberField(_ title: String, _ value: Binding<Double>, unit: String = "мм") -> some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: 11)).foregroundStyle(Workshop.muted)
            Spacer(minLength: 0)
            TextField(title, value: value, format: .number.precision(.fractionLength(0...3)))
                .labelsHidden().textFieldStyle(.plain).font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 9).padding(.vertical, 7).frame(width: 88)
                .background(Workshop.raised, in: RoundedRectangle(cornerRadius: 4))
                .overlay { RoundedRectangle(cornerRadius: 4).stroke(Workshop.line) }
            Text(unit).font(.system(size: 10)).foregroundStyle(Workshop.muted).frame(width: 18, alignment: .leading)
        }
    }
    private var layerControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Контуры реза", isOn: $drawing.contours)
            Toggle("Стенки (справочно)", isOn: $drawing.walls)
            Toggle("Осевые", isOn: $drawing.axes)
            Toggle("Калибр 100 мм", isOn: $drawing.dimensions)
            Toggle("Метки совмещения", isOn: $drawing.marks)
        }.toggleStyle(.checkbox).font(.system(size: 11))
    }
    private func exportControls(_ calculation: Result<Solution, Error>) -> some View {
        VStack(spacing: 10) {
            HStack { Image(systemName: "square.and.arrow.up"); Text("Экспорт шаблонов"); Spacer(); Text("мм").foregroundStyle(Workshop.muted) }.font(.system(size: 11, weight: .medium))
            HStack(spacing: 8) {
                exportMenu("PDF 1:1", pdf: true, calculation: calculation)
                exportMenu("DXF", pdf: false, calculation: calculation)
            }
            Text("Выберите шаблон в меню формата").font(.system(size: 9)).foregroundStyle(Workshop.muted)
        }
    }
    private func exportMenu(_ title: String, pdf: Bool, calculation: Result<Solution, Error>) -> some View {
        Menu {
            if case .success(let s) = calculation {
                Button("Ответвление") { export(s, hole: false, pdf: pdf) }
                Button("Отверстие основной трубы") { export(s, hole: true, pdf: pdf) }
            }
        } label: {
            HStack { Image(systemName: pdf ? "doc" : "square.and.arrow.down"); Text(title); Spacer(minLength: 3); Image(systemName: "chevron.down").font(.system(size: 8)) }
                .font(.system(size: 12, weight: .semibold)).padding(.horizontal, 12).frame(height: 36)
                .foregroundStyle(pdf ? Color.black : Workshop.text)
                .background(pdf ? Workshop.orange : Workshop.raised, in: RoundedRectangle(cornerRadius: 5))
        }.menuStyle(.borderlessButton).menuIndicator(.hidden)
            .padding(.horizontal, 10).frame(maxWidth: .infinity, minHeight: 36)
            .background(pdf ? Workshop.orange : Workshop.raised, in: RoundedRectangle(cornerRadius: 5))
            .tint(pdf ? Color.black : Workshop.text)
            .fixedSize(horizontal: false, vertical: true)
            .disabled((try? calculation.get()) == nil || (!drawing.contours && !drawing.walls && !drawing.axes && !drawing.dimensions && !drawing.marks))
    }
    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle().fill((try? result.get()) != nil ? Color.green.opacity(0.8) : Workshop.orange).frame(width: 5, height: 5)
            Text(message).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
            Spacer(minLength: 12)
            Text("Дискретизация: 1440").foregroundStyle(Workshop.muted)
            Rectangle().fill(Workshop.line).frame(width: 1, height: 12).padding(.horizontal, 6)
            Text("Единицы: мм").foregroundStyle(Workshop.muted)
        }.font(.system(size: 10)).padding(.horizontal, 18).frame(height: 30).background(Workshop.panel)
            .overlay(alignment: .top) { Rectangle().fill(Workshop.line).frame(height: 1) }
    }
    private func export(_ s: Solution, hole: Bool, pdf: Bool) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = (hole ? "main-hole" : "branch-cut") + (pdf ? ".pdf" : ".dxf")
        panel.title = hole ? "Отверстие основной трубы" : "Фигурный рез ответвления"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                if pdf { try drawing.pdf(s, hole: hole, to: url) }
                else { try drawing.dxf(s, hole: hole).write(to: url, atomically: true, encoding: .utf8) }
                message = "Сохранено: \(url.lastPathComponent)" + (pdf ? " · Печатать 100%, проверить калибр 100 мм" : " · Единицы: мм")
            } catch { message = error.localizedDescription }
        }
    }
}
