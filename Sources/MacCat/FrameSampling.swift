import Foundation

/// A continuous point between two painted key poses, not an integer frame.
struct CatFrameSample {
    let from: Int
    let to: Int
    let fraction: Double

    init(_ from: Int, _ to: Int? = nil, _ fraction: Double = 0) {
        self.from = from
        self.to = to ?? from
        self.fraction = min(1, max(0, fraction))
    }
}

enum CatFrameSampling {
    /// One deliberate stretch: lean into it, hold briefly, then relax.
    /// Clamp at the end rather than looping while the activity finishes.
    static func stretchAmount(at time: Double) -> Double {
        let t = max(0, time)
        if t < 0.85 { return smooth(t / 0.85) }
        if t < 1.65 { return 1 }
        return 1 - smooth(min(1, (t - 1.65) / 1.15))
    }

    static func sample(activity: CatActivity, pose: CatPose) -> CatFrameSample {
        switch activity {
        case .walk:
            let phase = max(0, pose.stride).truncatingRemainder(dividingBy: 8)
            let frame = Int(phase)
            // The tucked hind paws overlap in cels 2 and 6. Hold those
            // briefly, giving the remaining quarter to the following pose.
            // Keep all eight cels and the original total stride duration.
            if (frame == 2 || frame == 6), phase - Double(frame) >= 0.75 {
                return CatFrameSample(frame + 1)
            }
            return CatFrameSample(frame)
        case .sleep: return CatFrameSample(11)
        case .stretch: return CatFrameSample(14)
        case .carried: return CatFrameSample(15)
        case .groom:
            let t = 0.5 - 0.5 * cos(pose.stateTime * .pi * 2 * 1.2)
            return CatFrameSample(12, 13, pose.reducedMotion ? 0 : t)
        case .sit:
            if pose.affection > 0 { return CatFrameSample(10) }
            if pose.reducedMotion { return CatFrameSample(8) }
            // Start within even a short rest; do not inherit the walk clock.
            let t = pose.stateTime.truncatingRemainder(dividingBy: 3.7)
            switch t {
            case 0.95..<1.03: return CatFrameSample(9)
            case 1.03..<1.17: return CatFrameSample(10)
            case 1.17..<1.25: return CatFrameSample(9)
            default: return CatFrameSample(8)
            }
        }
    }

    static func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }
}
