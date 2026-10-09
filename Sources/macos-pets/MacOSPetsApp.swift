import AppKit
import Foundation
import MacOSPetsKit

/// The main controller: owns the overlay windows, the simulation and the menu.
///
/// This is a menu-bar (accessory) app: no Dock icon, no main window. Each
/// display gets its own overlay window, and a display link drives the tick.
enum MacOSPetsApp {

    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let controller = AppController()
        objc_setAssociatedObject(ProcessInfo.processInfo, Unmanaged.passUnretained(controller).toOpaque(), controller, .OBJC_ASSOCIATION_RETAIN)
        controller.start()
        app.run()
    }
}

final class AppController: NSObject, NSApplicationDelegate {

    private var windows: [PetOverlayWindow] = []
    private var layout = DisplayLayout()
    private var world = PetWorld()
    private var ball = Ball(position: .zero)
    private let ballPhysics = BallPhysics()
    private var tickTimer: Timer?
    private var statusItem: NSStatusItem?

    // Ball interaction
    private var draggingBall = false
    private var dragOffset = PetPoint.zero
    private var dragVelocity = PetPoint.zero
    private var lastDragPoint = PetPoint.zero
    private var lastDragTime = CACurrentMediaTime()
    private var lastTickTime = CACurrentMediaTime()

    private let pixelScale = 3.0

    // MARK: - Lifecycle

    func start() {
        layout = DisplayLayout.current()
        world = PetWorld(displays: layout.rects)

        for (i, id) in ["dog-black", "crab", "duck"].enumerated() {
            if let species = PetCatalogue.species(id: id) {
                world.spawn(species, on: i % max(layout.count, 1))
            }
        }

        buildWindows()
        buildMenu()
        startDisplayLink()
        beginMouseTracking()
        resetBall()
    }

    private func buildWindows() {
        for w in windows { w.orderOut(nil) }
        windows.removeAll()

        for frame in layout.rects {
            let w = PetOverlayWindow(displayFrame: CGRect(
                x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height
            ))
            guard let view = w.contentView as? PetOverlayView else { continue }
            view.render = { [weak self, weak view] in
                guard let self, let view else { return }
                self.render(into: view)
            }
            w.orderFrontRegardless()
            windows.append(w)
        }
    }

    private func rebuildWindowsIfNeeded() {
        let fresh = DisplayLayout.current()
        if fresh.rects != layout.rects {
            layout = fresh
            world.displays = layout.rects
            buildWindows()
        }
    }

    // MARK: - Tick

    private func startDisplayLink() {
        // A plain timer is enough here and avoids pulling in CoreVideo. It runs
        // on the main run loop so rendering happens on the main thread.
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let tickTimer {
            RunLoop.main.add(tickTimer, forMode: .common)
        }
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let dt = min(now - lastTickTime, 1.0 / 20.0) // clamp so a hitch can't teleport things
        lastTickTime = now

        rebuildWindowsIfNeeded()

        if !draggingBall {
            ballPhysics.step(&ball, dt: dt, displays: layout.rects)
        }
        var ballOpt: Ball? = ball
        world.step(dt: dt, ball: &ballOpt, cursor: currentCursor())
        ball = ballOpt ?? ball

        for w in windows {
            w.contentView?.setNeedsDisplay(w.contentView!.bounds)
        }
    }

    private func currentCursor() -> PetPoint? {
        let p = NSEvent.mouseLocation
        let point = PetPoint(x: p.x, y: p.y)
        return layout.index(containing: point) != nil ? point : nil
    }

    private func resetBall() {
        guard !layout.rects.isEmpty else { return }
        let display = layout.rects[0]
        ball = Ball(position: PetPoint(x: display.midX, y: display.minY + 40))
        ball.state = .resting
        ball.restingOn = 0
    }

    // MARK: - Rendering

    private let renderer = OverlayRenderer()

    private func render(into view: PetOverlayView) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        guard let window = view.window as? PetOverlayWindow else { return }

        // The view is flipped (top-left origin) so pixel sprites, which are
        // authored top-down, can be drawn directly.
        let frame = window.displayFrame
        renderer.draw(
            into: view,
            context: context,
            origin: PetPoint(x: frame.origin.x, y: frame.origin.y),
            viewSize: PetSize(width: frame.width, height: frame.height),
            ball: ball,
            pets: world.pets,
            displays: layout.rects,
            pixelScale: pixelScale
        )
    }


    // MARK: - Ball interaction
    //
    // The overlay windows are click-through, so the app watches global mouse
    // events instead. A grab only starts when the press lands on the ball,
    // which keeps normal clicking completely unaffected.

    private func handleMouseDown(at global: PetPoint) {
        // A carried ball is hidden in a pet's mouth: there is nothing to grab.
        // (Grabbing its stale position would steal it mid-parade.)
        guard ball.state != .carried else { return }
        let grabRadius = ball.radius + 14
        let delta = PetPoint(x: global.x - ball.position.x, y: global.y - ball.position.y)
        guard delta.length <= grabRadius else { return }

        draggingBall = true
        dragOffset = PetPoint(x: ball.position.x - global.x, y: ball.position.y - global.y)
        ball.state = .held
        lastDragPoint = ball.position
        lastDragTime = CACurrentMediaTime()
        dragVelocity = .zero
    }

    private func handleMouseDragged(to global: PetPoint) {
        guard draggingBall else { return }
        let target = global + dragOffset
        ball.position = target

        let now = CACurrentMediaTime()
        let dt = now - lastDragTime
        if dt > 0.008 {
            dragVelocity = PetPoint(
                x: (target.x - lastDragPoint.x) / dt,
                y: (target.y - lastDragPoint.y) / dt
            )
            lastDragPoint = target
            lastDragTime = now
        }
    }

    private func handleMouseUp() {
        guard draggingBall else { return }
        draggingBall = false
        let boosted = PetPoint(x: dragVelocity.x * 1.2, y: dragVelocity.y * 1.2)
        ballPhysics.throwBall(&ball, from: ball.position, velocity: boosted)
    }

    // MARK: - Menu

    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "macOS Pets")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        let throwItem = NSMenuItem(title: "Throw Ball", action: #selector(throwBallAction), keyEquivalent: "")
        throwItem.target = self
        menu.addItem(throwItem)

        let placeItem = NSMenuItem(title: "Place Ball at Cursor", action: #selector(placeBallAction), keyEquivalent: "")
        placeItem.target = self
        placeItem.toolTip = "The menu closes and the ball follows your cursor until you press to grab it."
        menu.addItem(placeItem)

        let addItem = NSMenuItem(title: "Add Pet", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for species in PetCatalogue.all {
            let item = NSMenuItem(title: species.name, action: #selector(addPetAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = species.id
            submenu.addItem(item)
        }
        let randomItem = NSMenuItem(title: "Random", action: #selector(addRandomPetAction), keyEquivalent: "")
        randomItem.target = self
        submenu.addItem(randomItem)
        addItem.submenu = submenu
        menu.addItem(addItem)

        let removeItem = NSMenuItem(title: "Remove Last Pet", action: #selector(removePetAction), keyEquivalent: "")
        removeItem.target = self
        menu.addItem(removeItem)

        menu.addItem(.separator())

        let clearItem = NSMenuItem(title: "Clear All Pets", action: #selector(clearPetsAction), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit macOS Pets", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func addPetAction(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let species = PetCatalogue.species(id: id) else { return }
        world.spawn(species, on: layout.mouseDisplayIndex ?? 0)
    }

    @objc private func addRandomPetAction() {
        guard let species = PetCatalogue.all.randomElement() else { return }
        world.spawn(species, on: layout.mouseDisplayIndex ?? 0)
    }

    @objc private func removePetAction() {
        _ = world.pets.popLast()
    }

    @objc private func clearPetsAction() {
        world.removeAll()
    }

    @objc private func placeBallAction() {
        // Arm placement mode: the menu closes on this click and the ball
        // starts riding the cursor (see pollMouse). The next press grabs it.
        draggingBall = false
        placingBall = true
    }

    @objc private func throwBallAction() {
        let index = layout.mouseDisplayIndex ?? 0
        guard layout.rects.indices.contains(index) else { return }
        let display = layout.rects[index]
        ballPhysics.throwBall(
            &ball,
            from: PetPoint(x: display.midX, y: display.minY + 60),
            velocity: PetPoint(x: 620, y: 1100)
        )
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    // MARK: - Global mouse tracking

    /// Installed by `MacOSPetsApp.run` via the app delegate. Polling the mouse
    /// state is simpler and more robust here than an event tap, which would
    /// need accessibility permissions.
    func beginMouseTracking() {
        Timer.scheduledTimer(withTimeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            self?.pollMouse()
        }
    }

    private var lastMouse = PetPoint.zero

    /// Armed by "Place Ball at Cursor": the menu has closed and the ball now
    /// follows the pointer until the next press grabs it for a throw.
    private var placingBall = false

    private func pollMouse() {
        let p = NSEvent.mouseLocation
        let now = PetPoint(x: p.x, y: p.y)
        let moved = now.distance(to: lastMouse) > 0.5
        let buttons = NSEvent.pressedMouseButtons

        if placingBall {
            // Preview: the ball rides the cursor so the user sees what the
            // next press will grab.
            ball.state = .held
            ball.velocity = .zero
            ball.position = now
            if buttons & 1 != 0 {
                placingBall = false
                draggingBall = true
                dragOffset = .zero
                lastDragPoint = now
                lastDragTime = CACurrentMediaTime()
                dragVelocity = .zero
            }
            lastMouse = now
            return
        }

        if buttons & 1 != 0 {
            if !draggingBall {
                handleMouseDown(at: lastMouse)
            }
            if draggingBall && moved {
                handleMouseDragged(to: now)
            }
        } else if draggingBall {
            handleMouseUp()
        }
        lastMouse = now
    }
}