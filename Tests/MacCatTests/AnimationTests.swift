import AppKit
import XCTest
@testable import MacCat

final class AnimationTests: XCTestCase {
    private let size = CGSize(width: 190, height: 158)

    private func pixels(_ pose: CatPose) throws -> [UInt8] {
        let image = CatRenderer.image(design: .tuxedo, size: size, pose: pose, scale: 1)
        let cg = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let context = try XCTUnwrap(CGContext(data: nil, width: 190, height: 158, bitsPerComponent: 8,
                                              bytesPerRow: 190 * 4, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cg, in: CGRect(origin: .zero, size: size))
        return Array(UnsafeBufferPointer(start: context.data!.assumingMemoryBound(to: UInt8.self), count: 190 * 158 * 4))
    }

    func testTransitionDoesNotDimSharedOpaqueBody() throws {
        var pose = CatPose()
        pose.activity = .sit
        pose.previousActivity = .sit
        let original = try pixels(pose)
        // An interrupted transition can have identical endpoints. It must
        // preserve the exact opaque drawing, including at 50% progress.
        pose.transition = 0.5
        XCTAssertEqual(try pixels(pose), original)

        pose.activity = .groom
        pose.previousActivity = .sit
        pose.stateTime = 0
        pose.transition = 0
        let a = try pixels(pose)
        pose.transition = 1
        let b = try pixels(pose)
        pose.transition = 0.5
        let halfway = try pixels(pose)
        var count = 0
        for index in stride(from: 3, to: a.count, by: 4) where a[index] > 250 && b[index] > 250 {
            XCTAssertGreaterThan(halfway[index], 248)
            count += 1
        }
        XCTAssertGreaterThan(count, 1000)
    }

    func testReducedMotionDisablesBlinkAndGroomInterpolation() {
        var pose = CatPose()
        pose.reducedMotion = true
        for t in stride(from: 0.0, through: 7.0, by: 0.017) {
            pose.time = t; pose.stateTime = t
            XCTAssertEqual(CatFrameSampling.sample(activity: .sit, pose: pose).from, 8)
            XCTAssertEqual(CatFrameSampling.sample(activity: .groom, pose: pose).fraction, 0)
        }
    }

    func testActivityChangesNeverBlendWithPreviousPose() throws {
        for activity in CatActivity.allCases {
            var pose = CatPose()
            pose.activity = activity
            pose.previousActivity = activity
            pose.stride = 2.375
            pose.stateTime = 0.2
            let expected = try pixels(pose)
            for previous in CatActivity.allCases where previous != activity {
                pose.previousActivity = previous
                for transition in [0.0, 0.25, 0.5, 0.75, 1.0] {
                    pose.transition = transition
                    XCTAssertEqual(try pixels(pose), expected, "\(previous) → \(activity)")
                }
            }
        }
    }

}
