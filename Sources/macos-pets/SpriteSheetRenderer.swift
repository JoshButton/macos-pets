import AppKit
import Foundation
import MacOSPetsKit

/// Renders every species' frames into a single contact-sheet PNG so the art can
/// be eyeballed. Run with: `macos-pets --render-sheet`
enum SpriteSheetRenderer {

    static func render(scale: Int = 4, padding: Int = 6) -> Data? {
        let species = PetCatalogue.all
        let cellW = 16 * scale
        let cellH = 16 * scale
        let cols = 4
        let rowsPerSpecies = 7

        let sheetW = cols * (cellW + padding) + padding
        let sheetH = species.count * rowsPerSpecies * (cellH + padding) + padding

        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: sheetW,
            pixelsHigh: sheetH,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        // Background so transparency is visible.
        NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: sheetW, height: sheetH).fill()

        for (i, sp) in species.enumerated() {
            let top = sheetH - (i * rowsPerSpecies * (cellH + padding) + padding)
            draw(sp.name, sp.sprites.idle, x: padding, yTop: top, scale: scale, padding: padding, cellH: cellH)
            draw("walk", sp.sprites.walk, x: padding, yTop: top - 2 * (cellH + padding), scale: scale, padding: padding, cellH: cellH)
            draw("sit", sp.sprites.sit, x: padding, yTop: top - 4 * (cellH + padding), scale: scale, padding: padding, cellH: cellH)
            draw("sleep", sp.sprites.sleep, x: padding, yTop: top - 6 * (cellH + padding), scale: scale, padding: padding, cellH: cellH)
        }

        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

    private static func draw(
        _ label: String, _ frames: [PixelSprite], x: Int, yTop: Int, scale: Int, padding: Int, cellH: Int
    ) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        NSAttributedString(string: label, attributes: attrs).draw(at: NSPoint(x: x, y: yTop - 14))

        for (i, f) in frames.enumerated() {
            let originX = x + i * (16 * scale + padding)
            let y = yTop - cellH - 14
            NSColor(calibratedWhite: 0.28, alpha: 1).setFill()
            NSRect(x: originX, y: y, width: 16 * scale, height: cellH).fill()
            drawSprite(f, at: NSPoint(x: originX, y: y), scale: scale)
        }
    }

    private static func drawSprite(_ s: PixelSprite, at point: NSPoint, scale: Int) {
        let scaleD = Double(scale)
        for py in 0..<s.height {
            let rowY: Double = point.y + Double(py) * scaleD
            for px in 0..<s.width {
                let c = s.color(x: px, y: py)
                if c.a <= 0 { continue }
                let fill = NSColor(calibratedRed: c.r, green: c.g, blue: c.b, alpha: c.a)
                fill.setFill()
                let cellX: Double = point.x + Double(px) * scaleD
                let rect = NSRect(x: cellX, y: rowY, width: scaleD, height: scaleD)
                rect.fill()
            }
        }
    }
}