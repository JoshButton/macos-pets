import AppKit
import Foundation
import MacOSPetsKit

/// Renders the overlay into an offscreen bitmap and inspects the pixels.
///
/// This catches drawing bugs that are invisible in code review: an unclipped
/// gradient, for example, floods the whole window with colour while still
/// compiling cleanly.
enum RenderCheck {

    static func run() -> Bool {
        // First prove the check can detect the bug it guards against, so a
        // silently-broken check can't give false confidence.
        OverlayRenderer.disableClipForTest = true
        if !detectsFlooding() {
            print("FAIL: render check does not detect an unclipped gradient")
            return false
        }
        OverlayRenderer.disableClipForTest = false
        print("  verified: check does detect the unclipped-gradient regression")

        var failures = 0
        let width = 800
        let height = 600

        guard let rep = makeBitmap(width: width, height: height) else {
            print("could not allocate bitmap")
            return false
        }
        drawOverlay(into: rep, width: width, height: height)

        // Corners and edges must remain fully transparent.
        let edges = [
            (3, 3), (width - 4, 3), (3, height - 4), (width - 4, height - 4),
            (width / 2, 4), (4, height / 2), (width / 2, height - 4),
        ]
        for (x, y) in edges {
            if let c = color(rep, x: x, y: y), c.a > 0.02 {
                failures += 1
                print("  FAIL: edge (\(x),\(y)) is not transparent: \(c)")
            }
        }

        // The centre of the canvas holds the ball, so it must be opaque and red.
        if let c = color(rep, x: width / 2, y: height / 2) {
            if !(c.r > 0.5 && c.g < 0.7 && c.a > 0.9) {
                failures += 1
                print("  FAIL: ball centre should be opaque red, got \(c)")
            }
        } else {
            failures += 1
            print("  FAIL: could not read the ball centre pixel")
        }

        // Sanity check that the pets were drawn too: something should exist in
        // the lower-left region where the cat stands.
        var petPixels = 0
        for y in stride(from: 0, to: height / 2, by: 2) {
            for x in stride(from: 100, to: 320, by: 2) {
                if let c = color(rep, x: x, y: y), c.a > 0.5 { petPixels += 1 }
            }
        }
        if petPixels < 20 {
            failures += 1
            print("  FAIL: expected the pet to be drawn, found only \(petPixels) opaque samples")
        } else {
            print("  pet pixels found: \(petPixels)")
        }

        let coverage = opaqueFraction(rep, width: width, height: height)
        if coverage > 0.25 {
            failures += 1
            print("  FAIL: \(Int(coverage * 100))% of the canvas is opaque; drawing is flooding")
        } else {
            print("  opaque coverage: \(String(format: "%.2f", coverage * 100))% (expected well under 25%)")
        }

        if failures > 0 {
            print("FAILED: \(failures)")
            return false
        }
        print("render check passed")
        return true
    }

    /// Renders one ball + pet and reports whether the canvas is flooded.
    private static func detectsFlooding() -> Bool {
        let width = 800
        let height = 600
        guard let rep = makeBitmap(width: width, height: height) else { return false }
        drawOverlay(into: rep, width: width, height: height)
        return opaqueFraction(rep, width: width, height: height) > 0.25
    }

    private static func makeBitmap(width: Int, height: Int) -> NSBitmapImageRep? {
        NSBitmapImageRep(
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
        )
    }

    private static func drawOverlay(into rep: NSBitmapImageRep, width: Int, height: Int) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        let renderer = OverlayRenderer()
        let ball = Ball(position: PetPoint(x: Double(width) / 2, y: Double(height) / 2))
        let pet = Pet(
            species: PetCatalogue.species(id: "cat")!,
            position: PetPoint(x: 200, y: 40),
            displayIndex: 0
        )
        let view = PetOverlayView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        if let context = NSGraphicsContext.current?.cgContext {
            renderer.draw(
                into: view,
                context: context,
                origin: .zero,
                viewSize: PetSize(width: Double(width), height: Double(height)),
                ball: ball,
                pets: [pet],
                pixelScale: 3
            )
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func opaqueFraction(_ rep: NSBitmapImageRep, width: Int, height: Int) -> Double {
        var opaque = 0
        var sampled = 0
        for y in stride(from: 0, to: height, by: 3) {
            for x in stride(from: 0, to: width, by: 3) {
                sampled += 1
                if let c = color(rep, x: x, y: y), c.a > 0.5 { opaque += 1 }
            }
        }
        return Double(opaque) / Double(max(sampled, 1))
    }

    private static func color(_ rep: NSBitmapImageRep, x: Int, y: Int) -> PetColor? {
        guard let c = rep.colorAt(x: x, y: y) else { return nil }
        return PetColor(
            r: Double(c.redComponent),
            g: Double(c.greenComponent),
            b: Double(c.blueComponent),
            a: Double(c.alphaComponent)
        )
    }
}