import AppKit
import Foundation
import MacOSPetsKit

/// Draws the pets and the ball for one display.
///
/// Kept separate from the controller so the drawing can be exercised against
/// an offscreen bitmap (see `RenderCheck`) rather than only on screen.
struct OverlayRenderer {

    /// Test hook: disables the ball's clip so the render check can prove it
    /// would actually catch the flooding regression.
    static var disableClipForTest = false

    /// Renders one display's overlay into `context`.
    ///
    /// The context is expected to be the flipped coordinate space of a view
    /// covering `viewSize`, with its origin at the display's global origin.
    func draw(
        into view: NSView,
        context: CGContext,
        origin: PetPoint,
        viewSize: PetSize,
        ball: Ball,
        pets: [Pet],
        displays: [PetRect] = [],
        pixelScale: Double,
        includeBall: Bool = true
    ) {
        context.clear(view.bounds)

        let width = CGFloat(viewSize.width)
        let height = CGFloat(viewSize.height)

        // Global (y-up) point -> view-local (y-down) point.
        func toLocal(_ p: PetPoint) -> CGPoint {
            CGPoint(x: p.x - origin.x, y: height - (p.y - origin.y))
        }

        // A carried ball is hidden: the catcher's `with_ball` art shows it in
        // the mouth, matching upstream hiding the ball canvas on catch. Pet
        // overlay windows also skip the ball now that it owns its window.
        if includeBall, ball.state != .carried,
           displays.isEmpty || displays.contains(where: { $0.intersects(ball.bounds) }) {
            drawBall(in: context, at: toLocal(ball.position), radius: ball.radius)
        }

        for pet in pets {
            draw(pet, in: context, at: toLocal(pet.position), pixelScale: pixelScale)
        }
    }

    /// Draws only the ball, for the dedicated ball window. The window frame
    /// already tracks the ball, so the ball renders centred in the view.
    func drawBallOnly(into view: NSView, context: CGContext, ball: Ball) {
        context.clear(view.bounds)
        guard ball.state != .carried else { return }
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        drawBall(in: context, at: center, radius: ball.radius)
    }

    private func drawBall(in context: CGContext, at local: CGPoint, radius: Double) {
        let r = CGFloat(radius)

        // Contact shadow beneath the ball.
        context.saveGState()
        context.setFillColor(NSColor.black.withAlphaComponent(0.22).cgColor)
        context.fillEllipse(in: CGRect(
            x: local.x - r * 0.8,
            y: local.y + r * 0.55,
            width: r * 1.6,
            height: r * 0.45
        ))
        context.restoreGState()

        // Clip to the circle before drawing the gradient. A radial gradient
        // with the "draws before/after location" options extends infinitely,
        // so without this clip the ball floods the entire window with colour.
        context.saveGState()
        if !OverlayRenderer.disableClipForTest {
            context.addEllipse(in: CGRect(x: local.x - r, y: local.y - r, width: r * 2, height: r * 2))
            context.clip()
        }

        // Upstream green (#2ed851): the `with_ball` art carries a green ball, so
        // the free ball must match or the pet parades the wrong colour.
        let colors = [
            NSColor(calibratedRed: 0.18, green: 0.85, blue: 0.32, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.10, green: 0.55, blue: 0.20, alpha: 1).cgColor,
        ] as CFArray
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 1]
        ) {
            context.translateBy(x: local.x, y: local.y)
            context.scaleBy(x: 1, y: -1) // radial gradients are drawn in user space
            context.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: -r * 0.35, y: r * 0.35),
                startRadius: 0,
                endCenter: .zero,
                endRadius: r * 1.6,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }
        context.restoreGState()

        // Outline keeps the ball readable against light backgrounds.
        context.saveGState()
        context.setStrokeColor(NSColor(calibratedWhite: 0.1, alpha: 0.5).cgColor)
        context.setLineWidth(1.5)
        context.strokeEllipse(in: CGRect(x: local.x - r, y: local.y - r, width: r * 2, height: r * 2))
        context.restoreGState()
    }

    private func draw(_ pet: Pet, in context: CGContext, at local: CGPoint, pixelScale: Double) {
        // Verbatim GIF artwork takes precedence. Facing is a canvas transform
        // (translate + scale), never mirrored pixel data, to respect ND terms.
        if let gif = pet.species.gif,
           let got = GifFrameStore.shared.frame(for: pet.species, pose: pet.pose, clock: pet.animationClock) {
            let targetH = CGFloat(gif.targetHeight)
            let imgW = CGFloat(got.image.width), imgH = CGFloat(got.image.height)
            guard imgH > 0 else { return }
            let s = targetH / imgH
            let drawW = imgW * s
            let drawH = targetH
            // Feet sit on the floor. The view is y-down, so the sprite extends
            // *upward* (toward smaller y) from the floor point; the
            // transparent bottom inset lifts the rect so the feet land on it.
            let insetPts = got.bottomInset * s
            let rectBottom = local.y + insetPts
            let rectCenterY = rectBottom - drawH / 2

            // Ground shadow, width-aware so wide sprites read correctly.
            context.saveGState()
            context.setFillColor(NSColor.black.withAlphaComponent(0.20).cgColor)
            context.fillEllipse(in: CGRect(
                x: local.x - drawW * 0.32,
                y: local.y - 2,
                width: drawW * 0.64,
                height: max(drawW * 0.10, 4)
            ))
            context.restoreGState()

            context.saveGState()
            context.interpolationQuality = .none
            // Center-origin draw: vertical flip corrects CGImage (y-up) for
            // the flipped view (y-down); horizontal flip is facing, applied
            // as a display transform only — the asset bytes are untouched.
            context.translateBy(x: local.x, y: rectCenterY)
            context.scaleBy(x: pet.facing < 0 ? -1 : 1, y: -1)
            context.draw(got.image, in: CGRect(x: -drawW / 2, y: -drawH / 2, width: drawW, height: drawH))
            context.restoreGState()
            return
        }

        drawProcedural(pet, in: context, at: local, pixelScale: pixelScale)
    }

    /// Original hand-drawn fallback (our own art; pixel mirroring is fine).
    private func drawProcedural(_ pet: Pet, in context: CGContext, at local: CGPoint, pixelScale: Double) {
        let frames = pet.species.sprites.frames(for: pet.pose)
        guard !frames.isEmpty else { return }

        let fps = pet.pose.fps
        let frameIndex = Int(pet.animationClock * fps) % frames.count
        var frame = frames[frameIndex]
        if pet.facing < 0 { frame = flippedHorizontally(frame) }

        let scale = CGFloat(pixelScale)
        let pixelW = CGFloat(frame.width) * scale
        let pixelH = CGFloat(frame.height) * scale
        let x = local.x - pixelW / 2
        // Feet at the floor point; the sprite extends upward (smaller y).
        let top = local.y - pixelH

        // Ground shadow.
        context.saveGState()
        context.setFillColor(NSColor.black.withAlphaComponent(0.20).cgColor)
        context.fillEllipse(in: CGRect(
            x: local.x - pixelW * 0.32,
            y: local.y - 2,
            width: pixelW * 0.64,
            height: pixelW * 0.14
        ))
        context.restoreGState()

        context.saveGState()
        context.interpolationQuality = .none
        for rowInArt in 0..<frame.height {
            let artY = frame.height - 1 - rowInArt
            for px in 0..<frame.width {
                let c = frame.color(x: px, y: artY)
                guard c.a > 0 else { continue }
                context.setFillColor(CGColor(
                    red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(c.a)
                ))
                context.fill(CGRect(
                    x: x + CGFloat(px) * scale,
                    y: top + CGFloat(rowInArt) * scale,
                    width: scale,
                    height: scale
                ))
            }
        }
        context.restoreGState()
    }
}