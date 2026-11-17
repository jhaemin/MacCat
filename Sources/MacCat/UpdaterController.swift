import AppKit
import Sparkle

@MainActor
final class UpdaterController {
    private let controller: SPUStandardUpdaterController

    init() {
        // Command-line development builds have no application bundle/feed.
        controller = SPUStandardUpdaterController(
            startingUpdater: Bundle.main.bundleIdentifier == "dev.jhaemin.MacCat",
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func makeMenuItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: "업데이트 확인…",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        item.target = controller
        return item
    }
}
