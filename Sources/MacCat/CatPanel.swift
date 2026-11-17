import AppKit

final class CatView: NSView {
    var design: CatDesign = .cheese
    var pose = CatPose()
    var renderOffset: CGPoint = .zero
    var onPet: (() -> Void)?
    var onNext: (() -> Void)?
    var onDragStart: (() -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onDragEnd: (() -> Void)?
    var menuProvider: (() -> NSMenu)?
    private var mouseStart: CGPoint?
    private var windowStart: CGPoint = .zero
    private var dragging = false

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func accessibilityPerformPress() -> Bool { onPet?(); return true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        ctx.saveGState()
        ctx.translateBy(x: renderOffset.x, y: renderOffset.y)
        CatRenderer.draw(in: ctx, size: bounds.size, design: design, pose: pose)
        ctx.restoreGState()
    }

    /// Hit-test the illustration, so clear corners do not eat desktop clicks.
    func containsCat(_ local: CGPoint) -> Bool {
        CatRenderer.contains(CGPoint(x: local.x - renderOffset.x, y: local.y - renderOffset.y),
                             size: bounds.size, design: design, pose: pose)
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { rightMouseDown(with: event); return }
        mouseStart = NSEvent.mouseLocation
        windowStart = window?.frame.origin ?? .zero
        dragging = false
        if event.clickCount == 2 { onNext?(); mouseStart = nil }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseStart else { return }
        let point = NSEvent.mouseLocation
        if !dragging && hypot(point.x - start.x, point.y - start.y) > 3 {
            dragging = true
            onDragStart?()
        }
        if dragging {
            onDrag?(CGPoint(x: windowStart.x + point.x - start.x, y: windowStart.y + point.y - start.y))
        }
    }

    override func mouseUp(with event: NSEvent) {
        if dragging { onDragEnd?() }
        else if mouseStart != nil { onPet?() }
        dragging = false
        mouseStart = nil
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = menuProvider?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}

final class CatPanel: NSPanel {
    let catView = CatView(frame: .zero)

    init(size: CGSize) {
        super.init(contentRect: CGRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        contentView = catView
        catView.setAccessibilityElement(true)
        catView.setAccessibilityRole(.button)
        catView.setAccessibilityLabel("MacCat 고양이")
        catView.setAccessibilityHelp("클릭해서 쓰다듬기, 드래그로 이동, 우클릭으로 메뉴 열기")
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Keep the window on device pixels and preserve the remaining fraction
    /// inside the drawing; slow walks no longer hop between rounded origins.
    func place(at point: CGPoint) {
        let scale = screen?.backingScaleFactor ?? 2
        let snapped = CGPoint(x: (point.x * scale).rounded() / scale,
                              y: (point.y * scale).rounded() / scale)
        setFrameOrigin(snapped)
        catView.renderOffset = CGPoint(x: point.x - snapped.x, y: snapped.y - point.y)
    }
}
