import AppKit
import ImageIO

/// Replay the original illustrated poses without deformation or blending.
enum CatRenderer {
    private static var atlases: [CatDesign: CatAtlas] = [:]

    static func atlas(for design: CatDesign) -> CatAtlas {
        if let cached = atlases[design] { return cached }
        let atlas = CatAtlas(design: design)
        atlases[design] = atlas
        return atlas
    }

    static func frameIndex(activity: CatActivity, pose: CatPose) -> Int {
        let sample = CatFrameSampling.sample(activity: activity, pose: pose)
        return sample.fraction < 0.5 ? sample.from : sample.to
    }

    static func draw(in ctx: CGContext, size: CGSize, design: CatDesign, pose: CatPose) {
        let atlas = atlas(for: design)
        ctx.saveGState()
        defer { ctx.restoreGState() }
        let drawRect = spriteRect(size: size, design: design, pose: pose)
        let side = drawRect.width
        if pose.facing < 0 {
            ctx.translateBy(x: size.width, y: 0)
            ctx.scaleBy(x: -1, y: 1)
        }
        let current = CatFrameSampling.sample(activity: pose.activity, pose: pose)
        // Exactly one fully opaque sprite, including activity changes. Both
        // runtime crossfades and baked RGBA blends produced ghost outlines.
        drawFrame(atlas.frame(for: current), in: ctx, rect: drawRect)
        if pose.affection > 0 {
            ctx.setAlpha(pose.affection * 0.85)
            ctx.setFillColor(NSColor.hex("DFA6A0").cgColor)
            let h = size.height * 0.045
            let hx = size.width * 0.7, hy = max(8, drawRect.minY + side * 0.1)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: hx, y: hy + h))
            path.addCurve(to: CGPoint(x: hx, y: hy - h * 0.2),
                          control1: CGPoint(x: hx - h * 2, y: hy - h * 0.2),
                          control2: CGPoint(x: hx - h * 0.7, y: hy - h * 1.5))
            path.addCurve(to: CGPoint(x: hx, y: hy + h),
                          control1: CGPoint(x: hx + h * 0.7, y: hy - h * 1.5),
                          control2: CGPoint(x: hx + h * 2, y: hy - h * 0.2))
            ctx.addPath(path); ctx.fillPath()
        }
    }

    static func contains(_ point: CGPoint, size: CGSize, design: CatDesign, pose: CatPose) -> Bool {
        let rect = spriteRect(size: size, design: design, pose: pose)
        let px = pose.facing < 0 ? size.width - point.x : point.x
        let u = (px - rect.minX) / rect.width, v = (point.y - rect.minY) / rect.height
        guard u >= 0, u < 1, v >= 0, v < 1 else { return false }
        let atlas = atlas(for: design)
        return atlas.isOpaque(frame: frameIndex(activity: pose.activity, pose: pose), u: u, v: v)
    }

    /// Shared drawing/hit-test transform, with uniform pose scale and a fixed ground line.
    static func spriteRect(size: CGSize, design: CatDesign, pose: CatPose) -> CGRect {
        let base = min(size.width, size.height * 1.12)
        let side = base * IllustrationScale.factor(design: design, activity: pose.activity)
        let baseline = size.height * 0.91
        let ground = pose.activity == .walk ? 0.84
            : atlas(for: design).groundLine(frame: frameIndex(activity: pose.activity, pose: pose))
        var width = side, height = side
        if !pose.reducedMotion {
            if pose.activity == .sit {
                let inhale = 0.5 - 0.5 * cos(pose.stateTime * .pi * 2 / 3.8)
                height *= 1 + 0.012 * inhale
            } else if pose.activity == .sleep {
                // Slow belly rise and fall, with the underside resting in place.
                let inhale = 0.5 - 0.5 * cos(pose.stateTime * .pi * 2 / 4.8)
                height *= 1 + 0.025 * inhale
                width *= 1 + 0.006 * inhale
            } else if pose.activity == .stretch {
                let reach = CatFrameSampling.stretchAmount(at: pose.stateTime)
                width *= 1 + 0.025 * reach
                height *= 1 - 0.035 * reach
            }
        }
        let breath = pose.reducedMotion || [.walk, .carried, .sit, .sleep, .stretch].contains(pose.activity)
            ? 0 : sin(pose.time * 1.9) * size.height * 0.002
        // Reach from the planted front paws instead of sliding the whole cat.
        let x = pose.activity == .stretch
            ? (size.width - side) / 2 + (side - width) * 0.82
            : (size.width - width) / 2
        return CGRect(x: x, y: baseline - height * ground + breath,
                      width: width, height: height)
    }

    private static func drawFrame(_ image: CGImage, in ctx: CGContext, rect: CGRect) {
        ctx.saveGState()
        ctx.setAlpha(1)
        ctx.interpolationQuality = .high
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(origin: .zero, size: rect.size))
        ctx.restoreGState()
    }

    static func image(design: CatDesign, size: CGSize, pose: CatPose = CatPose(), scale: CGFloat = 2) -> NSImage {
        let width = Int(size.width * scale), height = Int(size.height * scale)
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)
        draw(in: context, size: size, design: design, pose: pose)
        return NSImage(cgImage: context.makeImage()!, size: size)
    }
}

final class CatAtlas {
    let design: CatDesign
    let frames: [CGImage]
    private let masks: [[UInt8]]
    private let groundLines: [Double]
    private let maskSize = 96

    static var resourceBundle: Bundle {
        // A relocated .app uses its embedded bundle, not SwiftPM's build path.
        let embedded = Bundle.main.resourceURL?.appendingPathComponent("MacCat_MacCat.bundle")
        return embedded.flatMap { Bundle(url: $0) } ?? Bundle.module
    }

    init(design: CatDesign, subdirectory: String = "Cats") {
        self.design = design
        guard let url = Self.resourceBundle.url(forResource: design.assetName, withExtension: "png", subdirectory: subdirectory),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let sheet = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            preconditionFailure("Missing cat atlas: \(design.assetName)")
        }
        var extracted: [CGImage] = []
        var hitMasks: [[UInt8]] = []
        var grounds: [Double] = []
        for index in 0..<16 {
            let col = index % 4, row = index / 4
            let left = Int((Double(col) * Double(sheet.width) / 4).rounded())
            let top = Int((Double(row) * Double(sheet.height) / 4).rounded())
            let right = Int((Double(col + 1) * Double(sheet.width) / 4).rounded())
            let bottom = Int((Double(row + 1) * Double(sheet.height) / 4).rounded())
            let original = sheet.cropping(to: CGRect(x: left, y: top, width: right - left, height: bottom - top))!
            // Uniform resampling only; preserve the painted anatomy.
            let normalizer = CGContext(data: nil, width: 256, height: 256,
                                       bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            normalizer.interpolationQuality = .high
            normalizer.draw(original, in: CGRect(x: 0, y: 0, width: 256, height: 256))
            if design == .peach && [1, 5].contains(index),
               let correctionURL = Self.resourceBundle.url(forResource: "peach-\(index)", withExtension: "png", subdirectory: "PawCorrections"),
               let correctionSource = CGImageSourceCreateWithURL(correctionURL as CFURL, nil),
               let correction = CGImageSourceCreateImageAtIndex(correctionSource, 0, nil) {
                // Use only the corrected paw area; the original head, body,
                // tail and front legs remain pixel-for-pixel the original art.
                normalizer.saveGState()
                normalizer.clip(to: CGRect(x: 0.19 * 256, y: 0.15 * 256, width: 0.28 * 256, height: 0.19 * 256))
                normalizer.setBlendMode(.copy)
                normalizer.draw(correction, in: CGRect(x: 0, y: -0.02 * 256, width: 256, height: 256))
                normalizer.restoreGState()
            }
            let crop = normalizer.makeImage()!
            let fullBytes = normalizer.data!.assumingMemoryBound(to: UInt8.self)
            let lastRow: Int = (0..<256).reversed().first(where: { row in
                (0..<256).filter { fullBytes[row * normalizer.bytesPerRow + $0 * 4 + 3] > 180 }.count >= 3
            }) ?? 215
            grounds.append(Double(lastRow + 1) / 256)
            extracted.append(crop)
            let context = CGContext(data: nil, width: maskSize, height: maskSize, bitsPerComponent: 8,
                                    bytesPerRow: maskSize * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(crop, in: CGRect(x: 0, y: 0, width: maskSize, height: maskSize))
            let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
            hitMasks.append((0..<(maskSize * maskSize)).map { bytes[$0 * 4 + 3] })
        }
        frames = extracted
        masks = hitMasks
        groundLines = grounds
    }

    func frame(for sample: CatFrameSample) -> CGImage {
        frames[sample.fraction < 0.5 ? sample.from : sample.to]
    }

    func groundLine(frame: Int) -> Double { groundLines[frame] }

    func isOpaque(frame: Int, u: Double, v: Double) -> Bool {
        let x = min(maskSize - 1, max(0, Int(u * Double(maskSize))))
        let y = min(maskSize - 1, max(0, Int(v * Double(maskSize))))
        return masks[frame][y * maskSize + x] > 100
    }
}
