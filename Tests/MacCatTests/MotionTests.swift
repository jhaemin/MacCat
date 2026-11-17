import XCTest
@testable import MacCat

final class MotionTests: XCTestCase {
    let bounds = CGRect(x: -1400, y: 30, width: 1200, height: 700)

    func testTravelStaysInsideScreenAndArrivesWithoutOvershoot() {
        var cat = CatMotion(position: CGPoint(x: -1000, y: 200))
        let target = CGPoint(x: -650, y: 400)
        cat.walk(to: target, bounds: bounds, speed: 42)
        var previous = cat.position
        for _ in 0..<1000 {
            cat.update(dt: 1 / 30, bounds: bounds, speed: 42, paused: false, reducedMotion: false)
            XCTAssertEqual(CatMotion.clamped(cat.position, to: bounds), cat.position)
            XCTAssertLessThanOrEqual(hypot(cat.position.x - previous.x, cat.position.y - previous.y), 2)
            previous = cat.position
            if cat.activity != .walk { break }
        }
        XCTAssertEqual(cat.position.x, target.x, accuracy: 0.001)
        XCTAssertEqual(cat.position.y, target.y, accuracy: 0.001)
    }

    func testPauseFreezesTravelAndResumeIsContinuous() {
        var cat = CatMotion(position: CGPoint(x: -1000, y: 200))
        cat.walk(to: CGPoint(x: -650, y: 400), bounds: bounds, speed: 42)
        for _ in 0..<60 { cat.update(dt: 1 / 30, bounds: bounds, speed: 42, paused: false, reducedMotion: false) }
        let position = cat.position
        let clock = cat.pose.time
        var restingFrames = Set<Int>()
        for _ in 0..<300 {
            cat.update(dt: 1 / 30, bounds: bounds, speed: 42, paused: true, reducedMotion: false)
            restingFrames.insert(CatRenderer.frameIndex(activity: .sit, pose: cat.pose))
        }
        XCTAssertGreaterThan(cat.pose.time, clock)
        XCTAssertTrue(restingFrames.contains(8), "Resting cat opens its eyes")
        XCTAssertTrue(restingFrames.contains(10), "Resting cat still blinks")
        XCTAssertEqual(cat.position, position)
        cat.update(dt: 1 / 30, bounds: bounds, speed: 42, paused: false, reducedMotion: false)
        XCTAssertLessThan(hypot(cat.position.x - position.x, cat.position.y - position.y), 2)
    }

    func testReducedMotionStopsTravelAndClock() {
        var cat = CatMotion(position: CGPoint(x: -1000, y: 200))
        cat.walk(to: CGPoint(x: -650, y: 400), bounds: bounds, speed: 42)
        let position = cat.position
        for _ in 0..<300 { cat.update(dt: 1 / 30, bounds: bounds, speed: 42, paused: false, reducedMotion: true) }
        XCTAssertEqual(cat.position, position)
        XCTAssertEqual(cat.pose.time, 0)
        XCTAssertEqual(cat.pose.walking, 0)
        XCTAssertEqual(cat.pose.sitting, 1)
    }

    func testDisplayRemovalAndResizeRecoverInsideNewBounds() {
        var cat = CatMotion(position: CGPoint(x: -1200, y: 200))
        cat.walk(to: CGPoint(x: -650, y: 400), bounds: bounds, speed: 42)
        let newBounds = CGRect(x: 6, y: 40, width: 900, height: 500)
        cat.update(dt: 1 / 30, bounds: newBounds, speed: 42, paused: false, reducedMotion: false)
        XCTAssertEqual(CatMotion.clamped(cat.position, to: newBounds), cat.position)
        XCTAssertEqual(cat.activity, .sit)
    }

    func testBoundsOnNegativeScreenAndTinyScreen() {
        let frame = CGRect(x: -1440, y: -200, width: 1440, height: 900)
        let cat = CGSize(width: 190, height: 158)
        let full = CatMotion.travelBounds(screen: frame, cat: cat, area: .everywhere)
        XCTAssertGreaterThanOrEqual(full.minX, frame.minX)
        XCTAssertLessThanOrEqual(full.maxX + cat.width, frame.maxX)
        XCTAssertLessThanOrEqual(full.maxY + cat.height, frame.maxY)
        let bottom = CatMotion.travelBounds(screen: frame, cat: cat, area: .bottom)
        XCTAssertEqual(bottom.height, 24)
        let tiny = CatMotion.travelBounds(screen: CGRect(x: 0, y: 0, width: 100, height: 100), cat: cat, area: .everywhere)
        XCTAssertEqual(tiny.size, .zero)
    }

    func testDraggingAndPettingInterruptTravel() {
        var cat = CatMotion(position: CGPoint(x: -1000, y: 200))
        cat.walk(to: CGPoint(x: -650, y: 400), bounds: bounds, speed: 42)
        cat.beginDrag()
        cat.drag(to: CGPoint(x: 500, y: 2000))
        cat.update(dt: 1 / 30, bounds: bounds, speed: 42, paused: false, reducedMotion: false)
        XCTAssertEqual(cat.position, CGPoint(x: 500, y: 2000))
        cat.endDrag(bounds: bounds)
        XCTAssertEqual(cat.position, CGPoint(x: bounds.maxX, y: bounds.maxY))
        cat.pet()
        cat.update(dt: 1 / 30, bounds: bounds, speed: 42, paused: false, reducedMotion: false)
        XCTAssertEqual(cat.activity, .sit)
        XCTAssertGreaterThan(cat.pose.affection, 0)
    }
}
