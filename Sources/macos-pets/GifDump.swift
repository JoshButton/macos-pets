import AppKit
import Foundation
import ImageIO
import MacOSPetsKit

/// Dumps raw GIF frames (no overlay transform) to verify assets decode
/// upright, plus an overlay-composited version with a simulated flipped view.
enum GifDump {
    static func dump(out: String, speciesID: String, poseName: String) {
        guard let species = PetCatalogue.species(id: speciesID) else {
            print("unknown species \(speciesID)")
            return
        }
        let pose = PetPose(rawValue: poseName) ?? .idle
        guard let gif = species.gif, let rel = gif.relativePath(for: pose) else {
            print("no gif for \(speciesID)/\(poseName)")
            return
        }
        guard let entry = GifFrameStore.shared.entry(forRelativePath: rel) else {
            print("could not load \(rel)")
            return
        }

        // Composite: raw frames side by side on checker, plus overlay version.
        let n = min(entry.frames.count, 6)
        let cellW = Int(entry.size.width), cellH = Int(entry.size.height)
        let overlayW = 400, overlayH = 300
        let totalW = max(n * (cellW + 8) + 8, overlayW)
        let totalH = cellH + 16 + overlayH + 8

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: totalW, pixelsHigh: totalH,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { print("no bitmap"); return }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // NOTE: bitmap contexts are y-up. Draw raw frames directly (no flip).
        NSColor(calibratedWhite: 0.15, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: totalW, height: totalH).fill()
        for i in 0..<n {
            let x = 8 + i * (cellW + 8)
            let y = totalH - cellH - 8
            NSColor(calibratedWhite: 0.25, alpha: 1).setFill()
            NSRect(x: x, y: y, width: cellW, height: cellH).fill()
            ctx.saveGState()
            // CGImage is y-up; bitmap context is y-up: draw directly.
            ctx.draw(entry.frames[i], in: CGRect(x: x, y: y, width: cellW, height: cellH))
            ctx.restoreGState()
        }

        // Overlay version: simulate the flipped live view.
        ctx.saveGState()
        let oy = 8 // overlay strip at bottom of bitmap (y-up)
        ctx.translateBy(x: 0, y: CGFloat(oy + overlayH))
        ctx.scaleBy(x: 1, y: -1) // now y-down, like the live flipped view
        NSColor(calibratedWhite: 0.15, alpha: 1).setFill()
        CGRect(x: 0, y: 0, width: overlayW, height: overlayH).fill()
        // Floor line at global y=60 -> local y-down = overlayH - 60.
        NSColor(calibratedWhite: 0.5, alpha: 1).setFill()
        CGRect(x: 0, y: overlayH - 60, width: overlayW, height: 2).fill()

        var pet = Pet(species: species, position: PetPoint(x: 200, y: 60), displayIndex: 0)
        pet.animationClock = 0.3
        let view = PetOverlayView(frame: NSRect(x: 0, y: 0, width: overlayW, height: overlayH))
        OverlayRenderer().draw(
            into: view, context: ctx, origin: .zero,
            viewSize: PetSize(width: Double(overlayW), height: Double(overlayH)),
            ball: Ball(position: PetPoint(x: -100, y: -100)),
            pets: [pet], pixelScale: 3
        )
        ctx.restoreGState()

        NSGraphicsContext.restoreGraphicsState()
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: out))
            print("wrote \(out) frames=\(entry.frames.count) size=\(entry.size) bottomInsets=\(entry.bottomInsets.prefix(3))")
        }
    }
}