import AppKit

let args = CommandLine.arguments
if let index = args.firstIndex(of: "--render-motion"), index + 1 < args.count {
    do { try DevTools.renderMotionComparison(to: args[index + 1]) }
    catch { fputs("Motion render failed: \(error)\n", stderr); exit(1) }
    exit(0)
}
if let index = args.firstIndex(of: "--render-previews"), index + 1 < args.count {
    do { try DevTools.renderPreviews(to: args[index + 1]) }
    catch { fputs("Render failed: \(error)\n", stderr); exit(1) }
    exit(0)
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
