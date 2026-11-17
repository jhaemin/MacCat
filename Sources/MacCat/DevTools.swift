import AppKit
import SwiftUI

enum DevTools {
    /// Reproducible playback of the original eight walking cels.
    /// Encode with ffmpeg -framerate 60 -i frame-%03d.png -c:v libx264 ...
    static func renderMotionComparison(to directory: String) throws {
        let url = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for frame in 0..<240 {
            try autoreleasepool {
                let t = Double(frame) / 60
                let output = bitmap(size: CGSize(width: 960, height: 400)) { ctx in
                    ctx.setFillColor(NSColor.hex("FAF8F3").cgColor)
                    ctx.fill(CGRect(x: 0, y: 0, width: 960, height: 400))
                    drawText("기본 일러스트 · 8프레임", at: CGPoint(x: 105, y: 34), size: 20, color: .hex("73766F"))
                    drawText("기본 일러스트 · 8프레임", at: CGPoint(x: 565, y: 34), size: 20, color: .hex("536B48"))
                    for side in 0..<2 {
                        var pose = CatPose()
                        pose.activity = .walk
                        pose.previousActivity = .walk
                        let distance = t * 38
                        let size = CGSize(width: 250, height: 250 * 200 / 240)
                        let strideLength = 48.0
                        pose.stride = distance / strideLength * 8
                        ctx.saveGState()
                        ctx.translateBy(x: CGFloat(side) * 460 + 30 + distance, y: 120)
                        CatRenderer.draw(in: ctx, size: size, design: side == 0 ? .peach : .tuxedo, pose: pose)
                        ctx.restoreGState()
                    }
                }
                try save(output, to: url.appendingPathComponent(String(format: "frame-%03d.png", frame)))
            }
        }
        print("Rendered 240 original walk frames at 60fps to \(directory)")
    }

    static func renderPreviews(to directory: String) throws {
        let url = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for design in CatDesign.allCases {
            try save(CatRenderer.image(design: design, size: CGSize(width: 480, height: 400)), to: url.appendingPathComponent("cat-\(design.rawValue).png"))
        }
        let sheet = bitmap(size: CGSize(width: 1200, height: 650)) { ctx in
            ctx.setFillColor(NSColor.hex("FAF8F3").cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: 1200, height: 650))
            for design in CatDesign.allCases {
                let x = CGFloat(design.rawValue % 4) * 300
                let y = CGFloat(design.rawValue / 4) * 325
                ctx.saveGState(); ctx.translateBy(x: x + 20, y: y + 25)
                CatRenderer.draw(in: ctx, size: CGSize(width: 260, height: 217), design: design, pose: CatPose())
                ctx.restoreGState()
                drawText(design.name, at: CGPoint(x: x + 125, y: y + 253), size: 20, color: .hex("454C40"))
                drawText(design.subtitle, at: CGPoint(x: x + 65, y: y + 285), size: 12, color: .hex("8C8E80"))
            }
        }
        try save(sheet, to: url.appendingPathComponent("all-cats.png"))
        let darkSheet = bitmap(size: CGSize(width: 1200, height: 650)) { ctx in
            ctx.setFillColor(NSColor.hex("242932").cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: 1200, height: 650))
            for design in CatDesign.allCases {
                ctx.saveGState()
                ctx.translateBy(x: CGFloat(design.rawValue % 4) * 300 + 20,
                                y: CGFloat(design.rawValue / 4) * 325 + 25)
                CatRenderer.draw(in: ctx, size: CGSize(width: 260, height: 217), design: design, pose: CatPose())
                ctx.restoreGState()
            }
        }
        try save(darkSheet, to: url.appendingPathComponent("all-cats-dark.png"))

        let motionSheet = bitmap(size: CGSize(width: 1440, height: 420)) { ctx in
            ctx.setFillColor(NSColor.hex("FAF8F3").cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: 1440, height: 420))
            let activities: [CatActivity] = [.walk, .sit, .groom, .sleep, .stretch, .carried]
            for (index, activity) in activities.enumerated() {
                for row in 0..<2 {
                    var pose = CatPose(time: Double(row) * 0.5 + 1, stride: Double(row) * 1.7)
                    pose.activity = activity
                    pose.previousActivity = activity
                    pose.sitting = [.sit, .groom].contains(activity) ? 1 : 0
                    pose.walking = activity == .walk ? 1 : 0
                    pose.sleeping = activity == .sleep ? 1 : 0
                    pose.grooming = activity == .groom ? 1 : 0
                    pose.stretching = activity == .stretch ? 1 : 0
                    pose.carried = activity == .carried ? 1 : 0
                    pose.facing = row == 0 ? 1 : -1
                    ctx.saveGState(); ctx.translateBy(x: CGFloat(index) * 240, y: CGFloat(row) * 210)
                    CatRenderer.draw(in: ctx, size: CGSize(width: 240, height: 200), design: .cheese, pose: pose)
                    drawText(activity.rawValue, at: CGPoint(x: 100, y: 188), size: 11, color: .hex("8C8E80"))
                    ctx.restoreGState()
                }
            }
        }
        try save(motionSheet, to: url.appendingPathComponent("motions.png"))

        let scaleSheet = bitmap(size: CGSize(width: 1000, height: 1760)) { ctx in
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: 1000, height: 1760))
            for design in CatDesign.allCases {
                for (column, activity) in [CatActivity.walk, .sit, .carried, .sleep].enumerated() {
                    var pose = CatPose()
                    pose.activity = activity
                    pose.reducedMotion = true
                    ctx.saveGState()
                    ctx.translateBy(x: CGFloat(column * 250), y: CGFloat(design.rawValue * 220))
                    CatRenderer.draw(in: ctx, size: CGSize(width: 240, height: 200), design: design, pose: pose)
                    drawText("\(design.name) · \(activity.rawValue)", at: CGPoint(x: 70, y: 195), size: 12, color: .darkGray)
                    ctx.restoreGState()
                }
            }
        }
        try save(scaleSheet, to: url.appendingPathComponent("pose-scale.png"))
        let walkSheet = bitmap(size: CGSize(width: 1200, height: 440)) { ctx in
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: 1200, height: 440))
            for frame in 0..<8 {
                var pose = CatPose()
                pose.activity = .walk; pose.stride = Double(frame)
                ctx.saveGState(); ctx.translateBy(x: CGFloat(frame % 4) * 300, y: CGFloat(frame / 4) * 220)
                CatRenderer.draw(in: ctx, size: CGSize(width: 260, height: 217), design: .peach, pose: pose)
                drawText("Frame \(frame)", at: CGPoint(x: 100, y: 200), size: 12, color: .darkGray)
                ctx.restoreGState()
            }
        }
        try save(walkSheet, to: url.appendingPathComponent("peach-walk.png"))
        for (name, time) in [("sleep-exhale", 0.0), ("sleep-inhale", 2.4)] {
            var pose = CatPose()
            pose.activity = .sleep; pose.stateTime = time
            try save(CatRenderer.image(design: .peach, size: CGSize(width: 480, height: 400), pose: pose),
                     to: url.appendingPathComponent("\(name).png"))
        }

        let stretchSheet = bitmap(size: CGSize(width: 1200, height: 240)) { ctx in
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: 1200, height: 240))
            for (column, time) in [0.0, 0.45, 1.2, 2.8].enumerated() {
                var pose = CatPose()
                pose.activity = .stretch; pose.stateTime = time
                ctx.saveGState(); ctx.translateBy(x: CGFloat(column * 300), y: 0)
                CatRenderer.draw(in: ctx, size: CGSize(width: 280, height: 233), design: .peach, pose: pose)
                drawText("\(time)s", at: CGPoint(x: 130, y: 220), size: 12, color: .darkGray)
                ctx.restoreGState()
            }
        }
        try save(stretchSheet, to: url.appendingPathComponent("stretch-sequence.png"))

        let iconset = url.appendingPathComponent("AppIcon.iconset")
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        for base in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let dimension = CGFloat(base * scale)
                let icon = bitmap(size: CGSize(width: dimension, height: dimension)) { ctx in
                    ctx.scaleBy(x: dimension / 1024, y: dimension / 1024)
                    let rect = CGRect(x: 65, y: 65, width: 894, height: 894)
                    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 202, cornerHeight: 202, transform: nil))
                    ctx.setFillColor(NSColor.hex("E8EDDF").cgColor); ctx.fillPath()
                    ctx.translateBy(x: -24, y: 65)
                    CatRenderer.draw(in: ctx, size: CGSize(width: 1040, height: 867), design: .cheese, pose: CatPose())
                }
                let suffix = scale == 2 ? "@2x" : ""
                try save(icon, to: iconset.appendingPathComponent("icon_\(base)x\(base)\(suffix).png"))
            }
        }
        print("Rendered eight cats, motion sheet and app icon to \(directory)")
    }

    private static func bitmap(size: CGSize, draw: (CGContext) -> Void) -> NSImage {
        let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.translateBy(x: 0, y: size.height); ctx.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        draw(ctx)
        NSGraphicsContext.restoreGraphicsState()
        return NSImage(cgImage: ctx.makeImage()!, size: size)
    }

    private static func drawText(_ string: String, at point: CGPoint, size: CGFloat, color: NSColor) {
        (string as NSString).draw(at: point, withAttributes: [.font: NSFont.systemFont(ofSize: size), .foregroundColor: color])
    }

    private static func save(_ image: NSImage, to url: URL) throws {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "MacCat.Render", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
        }
        try data.write(to: url)
    }
}
