import Foundation

enum CatActivity: String, CaseIterable {
    case walk, sit, groom, sleep, stretch, carried
    var label: String {
        switch self {
        case .walk: return "사뿐사뿐 산책 중"
        case .sit: return "잠깐 쉬어 가는 중"
        case .groom: return "꼼꼼하게 세수 중"
        case .sleep: return "포근한 꿈을 꾸는 중"
        case .stretch: return "쭈욱, 기지개 켜는 중"
        case .carried: return "어디로 데려가나요?"
        }
    }
}

struct CatPose {
    var activity: CatActivity = .sit
    var previousActivity: CatActivity = .sit
    var transition: Double = 1
    var stateTime: Double = 0
    var time: Double = 0
    var stride: Double = 0
    var walking: Double = 0
    var sitting: Double = 1
    var sleeping: Double = 0
    var stretching: Double = 0
    var grooming: Double = 0
    var carried: Double = 0
    var affection: Double = 0
    var facing: Double = 1
    var reducedMotion = false
}

/// All positions use AppKit's screen coordinates. Keeping this separate from
/// windows lets bounds, travel and state transitions be tested without a UI.
struct CatMotion {
    var position: CGPoint
    private(set) var activity: CatActivity = .sit
    private(set) var pose = CatPose()
    private var start: CGPoint
    private var target: CGPoint
    private var elapsed: Double = 0
    private var duration: Double = 2.5
    private var petTime: Double = 0
    private var facingTarget: Double = 1
    private var previousReducedMotion = false

    init(position: CGPoint) {
        self.position = position
        start = position
        target = position
    }

    static func clamped(_ point: CGPoint, to bounds: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX),
                y: min(max(point.y, bounds.minY), bounds.maxY))
    }

    static func travelBounds(screen: CGRect, cat: CGSize, area: RoamingArea) -> CGRect {
        let padding: CGFloat = 6
        let width = max(0, screen.width - cat.width - padding * 2)
        let height = max(0, screen.height - cat.height - padding * 2)
        return CGRect(x: screen.minX + padding, y: screen.minY + padding,
                      width: width, height: area == .bottom ? min(height, 24) : height)
    }

    mutating func relocate(to point: CGPoint) {
        position = point
        start = point
        target = point
        setActivity(.sit, duration: 2)
    }

    mutating func pet() {
        petTime = 2.2
        setActivity(.sit, duration: 3.5)
    }

    mutating func beginDrag() { setActivity(.carried, duration: .infinity) }
    mutating func drag(to point: CGPoint) { position = point }
    mutating func endDrag(bounds: CGRect) { relocate(to: Self.clamped(position, to: bounds)) }

    mutating func rest(_ activity: CatActivity, duration: Double) {
        setActivity(activity, duration: duration)
    }

    mutating func walk(to point: CGPoint, bounds: CGRect, speed: Double) {
        start = Self.clamped(position, to: bounds)
        position = start
        target = Self.clamped(point, to: bounds)
        let distance = hypot(target.x - start.x, target.y - start.y)
        guard distance > 3 else { setActivity(.sit, duration: 2); return }
        if abs(target.x - start.x) > 8 { facingTarget = target.x >= start.x ? 1 : -1 }
        // Mirroring uses the sign, so face the destination before moving.
        pose.facing = facingTarget
        setActivity(.walk, duration: max(1.2, distance / max(12, speed)))
    }

    mutating func update(dt rawDT: Double, bounds: CGRect, speed: Double, paused: Bool, reducedMotion: Bool) {
        let dt = min(max(rawDT, 0), 0.1)
        if activity != .carried {
            let safe = Self.clamped(position, to: bounds)
            if safe != position || (activity == .walk && Self.clamped(target, to: bounds) != target) {
                relocate(to: safe)
            }
        }
        pose.reducedMotion = reducedMotion
        if reducedMotion != previousReducedMotion {
            setActivity(.sit, duration: 2)
            previousReducedMotion = reducedMotion
        }
        // Resting pauses travel, while breathing and blinking keep running.
        if !reducedMotion { pose.time += dt }
        let displayedActivity: CatActivity = activity == .carried ? .carried : (paused || reducedMotion ? .sit : activity)
        if displayedActivity != pose.activity {
            pose.previousActivity = pose.activity
            pose.activity = displayedActivity
            pose.transition = 0
            pose.stateTime = 0
        }
        pose.transition = reducedMotion ? 1 : min(1, pose.transition + dt / 0.16)
        if !reducedMotion { pose.stateTime += dt }
        petTime = max(0, petTime - dt)
        pose.affection = petTime > 0 ? min(1, petTime / 0.35) : 0

        if activity != .carried && !paused && !reducedMotion {
            elapsed += dt
            if activity == .walk {
                let t = min(1, elapsed / duration)
                // A short acceleration/deceleration section leaves the middle
                // at a comfortable steady pace, with no sudden starts or stops.
                let ramp = 0.16
                let progress: Double
                if t < ramp { progress = t * t / (2 * ramp * (1 - ramp)) }
                else if t > 1 - ramp { progress = 1 - pow(1 - t, 2) / (2 * ramp * (1 - ramp)) }
                else { progress = (t - ramp / 2) / (1 - ramp) }
                let next = CGPoint(x: start.x + (target.x - start.x) * progress,
                                   y: start.y + (target.y - start.y) * progress)
                pose.stride += hypot(next.x - position.x, next.y - position.y) / 6
                position = next
            }
            if elapsed >= duration { chooseNext(bounds: bounds, speed: speed) }
        }
        let blend = reducedMotion ? 1 : 1 - exp(-dt * 7)
        func approach(_ value: inout Double, _ goal: Double) { value += (goal - value) * blend }
        approach(&pose.walking, activity == .walk && !paused && !reducedMotion ? 1 : 0)
        approach(&pose.sitting, [.sit, .groom].contains(activity) || paused || reducedMotion ? 1 : 0)
        approach(&pose.sleeping, activity == .sleep && !paused && !reducedMotion ? 1 : 0)
        approach(&pose.stretching, activity == .stretch && !paused && !reducedMotion ? 1 : 0)
        approach(&pose.grooming, activity == .groom && !paused && !reducedMotion ? 1 : 0)
        approach(&pose.carried, activity == .carried ? 1 : 0)
        approach(&pose.facing, facingTarget)
    }

    private mutating func setActivity(_ value: CatActivity, duration: Double) {
        activity = value
        elapsed = 0
        self.duration = duration
    }

    private mutating func chooseNext(bounds: CGRect, speed: Double) {
        if activity == .walk {
            let choice = Int.random(in: 0..<10)
            switch choice {
            case 0: setActivity(.sleep, duration: Double.random(in: 12...22))
            case 1...2: setActivity(.groom, duration: Double.random(in: 3...5))
            case 3: setActivity(.stretch, duration: 2.8)
            default: setActivity(.sit, duration: Double.random(in: 2...5))
            }
        } else if activity == .sleep {
            setActivity(.stretch, duration: 2.8)
        } else {
            // Nearby destinations keep the cat strolling rather than flying
            // diagonally across the entire display in one trip.
            let destination = CGPoint(x: position.x + CGFloat.random(in: -380...380),
                                      y: position.y + CGFloat.random(in: -80...80))
            walk(to: destination, bounds: bounds, speed: speed)
        }
    }
}
