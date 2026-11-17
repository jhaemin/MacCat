import AppKit
import XCTest
@testable import MacCat

final class RendererTests: XCTestCase {
    func testAllEightAtlasesHaveSixteenUsableTransparentFrames() {
        for design in CatDesign.allCases {
            let atlas = CatRenderer.atlas(for: design)
            XCTAssertEqual(atlas.frames.count, 16)
            for (index, frame) in atlas.frames.enumerated() {
                XCTAssertGreaterThan(frame.width, 250)
                XCTAssertGreaterThan(frame.height, 250)
                XCTAssertFalse(atlas.isOpaque(frame: index, u: 0, v: 0))
                XCTAssertTrue(atlas.isOpaque(frame: index, u: 0.55, v: 0.65))
            }
        }
    }

    func testHitTestingMatchesVisiblePixelsInBothDirections() throws {
        let size = CGSize(width: 240, height: 200)
        for activity in CatActivity.allCases {
            for facing in [-1.0, 1.0] {
                var pose = CatPose()
                pose.activity = activity
                pose.facing = facing
                pose.reducedMotion = true
                let image = CatRenderer.image(design: .tuxedo, size: size, pose: pose, scale: 1)
                let bitmap = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(image.tiffRepresentation)))
                var mismatches = 0, samples = 0
                for y in stride(from: 4, to: 196, by: 6) {
                    for x in stride(from: 4, to: 236, by: 6) {
                        let alpha = bitmap.colorAt(x: x, y: y)!.alphaComponent
                        guard alpha < 0.1 || alpha > 0.9 else { continue }
                        let hit = CatRenderer.contains(CGPoint(x: x, y: y), size: size, design: .tuxedo, pose: pose)
                        if hit != (alpha > 0.9) { mismatches += 1 }
                        samples += 1
                    }
                }
                XCTAssertLessThan(Double(mismatches) / Double(samples), 0.03, "\(activity), facing \(facing)")
            }
        }
    }
}
