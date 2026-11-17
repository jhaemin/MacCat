import AppKit
import Combine
import ServiceManagement
import SwiftUI
import QuartzCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let state = AppState()
    private let updater = UpdaterController()
    private var panel: CatPanel!
    private var statusItem: NSStatusItem!
    private var gallery: NSWindow?
    private var motion = CatMotion(position: .zero)
    private var displayLink: CADisplayLink?
    private var lastTime = ProcessInfo.processInfo.systemUptime
    private var cancellables = Set<AnyCancellable>()
    private var observers: [NSObjectProtocol] = []
    private var dragging = false
    private var suspended = false
    private var menuOpen = false
    private var thumbnails: [CatDesign: NSImage] = [:]
    private var lastSaveTime: Double = 0
    private let measuringAnimation = CommandLine.arguments.contains("--measure-animation")
    private var measuredIntervals: [Double] = []
    private var measuredRenderTimes: [Double] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = CatPanel(size: state.size.size)
        restorePosition()
        panel.catView.design = state.design
        panel.catView.onPet = { [weak self] in self?.motion.pet() }
        panel.catView.onNext = { [weak self] in self?.state.nextDesign() }
        panel.catView.onDragStart = { [weak self] in
            self?.dragging = true
            self?.motion.beginDrag()
        }
        panel.catView.onDrag = { [weak self] point in
            self?.motion.drag(to: point)
            self?.panel.setFrameOrigin(point)
        }
        panel.catView.onDragEnd = { [weak self] in
            guard let self else { return }
            self.dragging = false
            self.motion.endDrag(bounds: self.travelBounds)
            self.savePosition()
        }
        panel.catView.menuProvider = { [weak self] in self?.makeMenu() ?? NSMenu() }
        panel.orderFrontRegardless()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "MacCat")
            ?? NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "MacCat")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = "MacCat · 작은 화면 친구"
        statusItem.menu = makeMenu()
        bindState()
        observeSystem()
        if measuringAnimation {
            motion.walk(to: CGPoint(x: travelBounds.maxX, y: motion.position.y), bounds: travelBounds, speed: 42)
        }
        startAnimation()

        if !UserDefaults.standard.bool(forKey: "hasLaunched") || CommandLine.arguments.contains("--show-gallery") {
            showGallery()
            UserDefaults.standard.set(true, forKey: "hasLaunched")
        }
    }

    private var currentScreen: NSScreen? {
        let center = CGPoint(x: motion.position.x + panel.frame.width / 2,
                             y: motion.position.y + panel.frame.height / 2)
        return NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main ?? NSScreen.screens.first
    }
    private var travelBounds: CGRect {
        CatMotion.travelBounds(screen: currentScreen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1280, height: 800),
                               cat: state.size.size, area: state.area)
    }

    private func bindState() {
        state.$design.sink { [weak self] design in
            _ = CatRenderer.atlas(for: design)
            self?.panel.catView.design = design
            self?.panel.catView.needsDisplay = true
        }.store(in: &cancellables)
        state.$size.dropFirst().sink { [weak self] size in
            guard let self else { return }
            let middle = self.panel.frame.midX
            self.panel.setContentSize(size.size)
            let bounds = CatMotion.travelBounds(screen: self.currentScreen?.visibleFrame ?? .zero,
                                                cat: size.size, area: self.state.area)
            self.motion.relocate(to: CatMotion.clamped(CGPoint(x: middle - size.size.width / 2, y: self.motion.position.y), to: bounds))
            self.panel.setFrameOrigin(self.motion.position)
            self.panel.catView.needsDisplay = true
        }.store(in: &cancellables)
        state.$hidden.sink { [weak self] hidden in
            guard let self else { return }
            if hidden { self.panel.orderOut(nil); self.stopAnimation() }
            else { self.panel.orderFrontRegardless(); if !self.suspended { self.startAnimation() } }
        }.store(in: &cancellables)
    }

    private func observeSystem() {
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                 object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.motion.relocate(to: CatMotion.clamped(self.motion.position, to: self.travelBounds))
                self.panel.setFrameOrigin(self.motion.position)
            }
        })
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                                             object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.state.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            }
        })
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.suspended = true; self?.stopAnimation() }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.suspended = false
                    if !self.state.hidden { self.startAnimation() }
                }
            })
        }
    }

    private func startAnimation() {
        guard displayLink == nil else { return }
        lastTime = ProcessInfo.processInfo.systemUptime
        let link = panel.catView.displayLink(target: self, selector: #selector(displayFrame(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }
    private func stopAnimation() { displayLink?.invalidate(); displayLink = nil }

    @objc private func displayFrame(_ link: CADisplayLink) { tick() }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = now - lastTime
        lastTime = now
        if menuOpen { return }
        motion.update(dt: dt, bounds: travelBounds, speed: state.speed,
                      paused: state.paused, reducedMotion: state.reduceMotion)
        panel.place(at: motion.position)
        panel.catView.pose = motion.pose
        panel.catView.needsDisplay = true
        panel.catView.displayIfNeeded()
        if state.activity != motion.activity { state.activity = motion.activity }
        if !dragging {
            let point = panel.catView.convert(panel.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
            panel.ignoresMouseEvents = state.clickThrough || !panel.catView.containsCat(point)
        }
        // Persist occasionally, never on every animation frame.
        if now - lastSaveTime > 10 { savePosition(); lastSaveTime = now }
        if measuringAnimation {
            measuredIntervals.append(dt)
            measuredRenderTimes.append(ProcessInfo.processInfo.systemUptime - now)
            if measuredIntervals.count == 240 {
                let intervals = Array(measuredIntervals.dropFirst(10)).sorted()
                let render = Array(measuredRenderTimes.dropFirst(10)).sorted()
                let fps = Double(intervals.count) / intervals.reduce(0, +)
                print(String(format: "Animation: %.1f fps; interval p95 %.2f ms; render p95 %.2f ms",
                             fps, intervals[Int(Double(intervals.count) * 0.95)] * 1000,
                             render[Int(Double(render.count) * 0.95)] * 1000))
                NSApp.terminate(nil)
            }
        }
    }

    private func restorePosition() {
        if let value = UserDefaults.standard.string(forKey: "catPosition") {
            motion.relocate(to: NSPointFromString(value))
            motion.relocate(to: CatMotion.clamped(motion.position, to: travelBounds))
            panel.setFrameOrigin(motion.position)
        } else { recall() }
    }
    private func savePosition() { UserDefaults.standard.set(NSStringFromPoint(motion.position), forKey: "catPosition") }

    @objc private func recall() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let bounds = CatMotion.travelBounds(screen: screen?.visibleFrame ?? .zero, cat: state.size.size, area: state.area)
        motion.relocate(to: CGPoint(x: bounds.midX, y: bounds.minY + min(35, bounds.height)))
        panel.setFrameOrigin(motion.position)
        if state.hidden { state.hidden = false }
        motion.pet()
        savePosition()
    }

    @objc private func showGallery() {
        if gallery == nil {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 800, height: 644),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "MacCat"
            window.titlebarAppearsTransparent = true
            window.backgroundColor = .hex("FAF8F3")
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: GalleryView(state: state, onRecall: { [weak self] in self?.recall() }))
            window.center()
            gallery = window
        }
        NSApp.activate(ignoringOtherApps: true)
        gallery?.makeKeyAndOrderFront(nil)
    }

    private func menuItem(_ title: String, _ action: Selector?, tag: Int = 0, checked: Bool = false, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self; item.tag = tag; item.state = checked ? .on : .off
        return item
    }
    private func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(); items.forEach(menu.addItem); item.submenu = menu
        return item
    }
    private func makeMenu() -> NSMenu {
        let menu = NSMenu(); menu.delegate = self; populate(menu); return menu
    }
    func menuNeedsUpdate(_ menu: NSMenu) { menu.removeAllItems(); populate(menu) }
    func menuWillOpen(_ menu: NSMenu) { menuOpen = true }
    func menuDidClose(_ menu: NSMenu) { menuOpen = false; lastTime = ProcessInfo.processInfo.systemUptime }

    private func populate(_ menu: NSMenu) {
        menu.addItem(menuItem("고양이 만나기…", #selector(showGallery), key: ","))
        menu.addItem(.separator())
        let label = NSMenuItem(title: "\(state.design.name) · \(state.activity.label)", action: nil, keyEquivalent: "")
        label.isEnabled = false; menu.addItem(label)
        menu.addItem(submenu("고양이", CatDesign.allCases.map { design in
            let item = menuItem(design.name + " — " + design.subtitle, #selector(selectDesign(_:)), tag: design.rawValue, checked: state.design == design)
            if thumbnails[design] == nil { thumbnails[design] = CatRenderer.image(design: design, size: CGSize(width: 36, height: 30)) }
            item.image = thumbnails[design]
            return item
        }))
        menu.addItem(submenu("크기", CatSize.allCases.map {
            menuItem($0.title, #selector(selectSize(_:)), tag: $0.rawValue, checked: state.size == $0)
        }))
        menu.addItem(submenu("산책 영역", RoamingArea.allCases.map {
            menuItem($0.title, #selector(selectArea(_:)), tag: $0.rawValue, checked: state.area == $0)
        }))
        menu.addItem(.separator())
        menu.addItem(menuItem(state.paused ? "산책 계속하기" : "잠깐 쉬기", #selector(togglePause)))
        menu.addItem(menuItem(state.hidden ? "고양이 보여주기" : "잠시 숨기기", #selector(toggleHidden)))
        menu.addItem(menuItem("이리 와", #selector(recall)))
        menu.addItem(menuItem("마우스 클릭 통과", #selector(toggleClickThrough), checked: state.clickThrough))
        menu.addItem(.separator())
        menu.addItem(menuItem("로그인 시 자동 실행", #selector(toggleLogin), checked: SMAppService.mainApp.status == .enabled))
        menu.addItem(updater.makeMenuItem())
        menu.addItem(menuItem("MacCat 종료", #selector(quit), key: "q"))
    }

    @objc private func selectDesign(_ item: NSMenuItem) { state.design = CatDesign(rawValue: item.tag) ?? .cheese }
    @objc private func selectSize(_ item: NSMenuItem) { state.size = CatSize(rawValue: item.tag) ?? .medium }
    @objc private func selectArea(_ item: NSMenuItem) { state.area = RoamingArea(rawValue: item.tag) ?? .everywhere }
    @objc private func togglePause() { state.paused.toggle() }
    @objc private func toggleHidden() { state.hidden.toggle() }
    @objc private func toggleClickThrough() { state.clickThrough.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "자동 실행을 설정하지 못했어요"
            alert.informativeText = "MacCat.app을 응용 프로그램 폴더로 옮긴 뒤 다시 시도해 주세요.\n\(error.localizedDescription)"
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showGallery(); return true }
    func applicationWillTerminate(_ notification: Notification) { stopAnimation(); savePosition() }
}
