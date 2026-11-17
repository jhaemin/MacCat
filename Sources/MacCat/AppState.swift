import AppKit
import Combine

final class AppState: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var design: CatDesign { didSet { defaults.set(design.rawValue, forKey: "design") } }
    @Published var size: CatSize { didSet { defaults.set(size.rawValue, forKey: "size") } }
    @Published var area: RoamingArea { didSet { defaults.set(area.rawValue, forKey: "area") } }
    @Published var speed: Double { didSet { defaults.set(speed, forKey: "speed") } }
    @Published var paused = false
    @Published var hidden = false
    @Published var clickThrough: Bool { didSet { defaults.set(clickThrough, forKey: "clickThrough") } }
    @Published var activity: CatActivity = .sit
    @Published var reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    init() {
        design = CatDesign(rawValue: defaults.integer(forKey: "design")) ?? .cheese
        size = CatSize(rawValue: defaults.object(forKey: "size") as? Int ?? 1) ?? .medium
        area = RoamingArea(rawValue: defaults.integer(forKey: "area")) ?? .everywhere
        let savedSpeed = defaults.object(forKey: "speed") as? Double ?? 42
        speed = savedSpeed.isFinite ? min(70, max(22, savedSpeed)) : 42
        clickThrough = defaults.bool(forKey: "clickThrough")
    }

    func nextDesign() { design = CatDesign(rawValue: (design.rawValue + 1) % CatDesign.allCases.count)! }
}
