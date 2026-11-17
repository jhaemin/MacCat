import Foundation

/// Forehead/cheek widths measured on the original 314px atlas cells.
/// Keep one scale throughout each activity so blinking cannot resize the cat.
enum IllustrationScale {
    static func factor(design: CatDesign, activity: CatActivity) -> Double {
        let widths: (walk: Double, seated: Double, carried: Double)
        switch design {
        case .cheese: widths = (95, 110, 99)
        case .milk: widths = (98, 114, 105)
        case .tuxedo: widths = (95, 109, 99)
        case .calico: widths = (98, 114, 109)
        case .siamese: widths = (98, 111, 104)
        case .cloud: widths = (94, 109, 100)
        case .cocoa: widths = (93, 108, 97)
        case .peach: widths = (93, 107, 97)
        }
        switch activity {
        case .sit, .groom: return widths.walk / widths.seated
        case .carried: return widths.walk / widths.carried
        // The curled sleeping pose uses a larger, tilted head in every coat.
        // Calibrated against the walking/seated head, not the whole silhouette.
        case .sleep: return 0.84
        default: return 1
        }
    }
}
