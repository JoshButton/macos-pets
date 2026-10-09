import AppKit
import Foundation
import MacOSPetsKit

/// Renders a zoomed preview of selected species so the artwork can be judged at
/// the size it will actually appear. Run with:
/// `macos-pets --preview cat dog duck`
enum PreviewRenderer {

    static func render(speciesIDs: [String], scale: Int = 12, out path: String) -> Bool {
        let species = speciesIDs.compactMap { PetCatalogue.species(id: $0) }
        guard !species.isEmpty else { return false }

        let cell = 16 * scale
        let gap = 8
        // idle(2) walk(2) sit(1) sleep(1) laid out in a row, one row per species.
        let framesPerRow = 6
        let cols = framesPerRow
        let labelW = 130

        let width = labelW + cols * (cell + gap) + gap
        let height = species.count * (cell + gap + 34) + gap

        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
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

        NSColor(calibratedWhite: 0.13, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()

        for (row, sp) in species.enumerated() {
            let top = height - row * (cell + gap + 34) - gap

            NSAttributedString(
                string: sp.name,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 20, weight: .bold),
                    .foregroundColor: NSColor.white,
                ]
            ).draw(at: NSPoint(x: gap, y: top - 24))

            var index = 0
            func place(_ frames: [PixelSprite], _ label: String) {
                for f in frames {
                    let x = labelW + index * (cell + gap)
                    let y = top - cell
                    NSColor(calibratedWhite: 0.22, alpha: 1).setFill()
                    NSRect(x: x, y: y, width: cell, height: cell).fill()
                    drawSprite(f, atX: x, y: y, scale: scale)
                    NSAttributedString(
                        string: label,
                        attributes: [
                            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                            .foregroundColor: NSColor(calibratedWhite: 0.7, alpha: 1),
                        ]
                    ).draw(at: NSPoint(x: x + 2, y: y - 16))
                    index += 1
                }
            }

            place(sp.sprites.idle, "idle")
            place(sp.sprites.walk, "walk")
            place(sp.sprites.sit, "sit")
            place(sp.sprites.sleep, "sleep")
        }

        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? data.write(to: URL(fileURLWithPath: path))) != nil
    }

    private static func drawSprite(_ s: PixelSprite, atX x: Int, y: Int, scale: Int) {
        let scaleD = Double(scale)
        // Sprites are stored bottom-up; NSGraphicsContext here is y-up, so
        // row 0 of storage is drawn at the bottom of the cell.
        for py in 0..<s.height {
            let cellY = Double(y + py * scale)
            for px in 0..<s.width {
                let c = s.color(x: px, y: py)
                if c.a <= 0 { continue }
                let color = NSColor(calibratedRed: c.r, green: c.g, blue: c.b, alpha: c.a)
                color.setFill()
                let rect = NSRect(x: Double(x + px * scale), y: cellY, width: scaleD, height: scaleD)
                rect.fill()
            }
        }
    }
}