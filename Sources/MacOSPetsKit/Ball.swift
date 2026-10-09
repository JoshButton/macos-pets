import Foundation

/// The bounding box of the whole desktop formed by every attached display.
///
/// Used for the outer walls and ceiling: the ball should bounce off the edges
/// of the monitor arrangement as a whole rather than off each monitor's
/// individual edges, which would trap it at internal seams.
public func DesktopBounds(_ displays: [PetRect]) -> PetRect? {
    guard var result = displays.first else { return nil }
    for display in displays.dropFirst() {
        result = result.union(display)
    }
    return result
}

/// Lives in global Cocoa screen space so it can travel across every attached
/// display. Bouncing is resolved against each display's bounds independently,
/// which means a ball can leave one monitor, fly over the gap, and land on
/// another.
public struct Ball: Sendable {
    public enum State: Sendable, Equatable {
        /// Held by the pointer, following the drag.
        case held
        /// Free: integrating gravity and bouncing.
        case flying
        /// Landed and come to rest on a display's bottom edge.
        case resting
        /// Caught by a pet and being carried.
        case carried
    }

    public var position: PetPoint
    public var velocity: PetPoint
    public var radius: Double
    public var state: State

    /// Index of the display the ball is resting on, if any.
    public var restingOn: Int?

    public init(position: PetPoint, radius: Double = 9) {
        self.position = position
        self.velocity = .zero
        self.radius = radius
        self.state = .flying
        self.restingOn = nil
    }

    public var bounds: PetRect {
        PetRect(
            x: position.x - radius,
            y: position.y - radius,
            width: radius * 2,
            height: radius * 2
        )
    }
}

/// Tunables for the ball's motion. Exposed so they can be tweaked from settings.
public struct BallPhysics: Sendable {
    /// Test hook overriding `bouncesOffDisplayEdges` for the whole simulation,
    /// so the suite can verify the wall checks have teeth.
    nonisolated(unsafe) public static var bouncesOffDisplayEdgesForTest = true

    /// Downward acceleration, in points per second squared.
    public var gravity: Double = 2600
    /// Fraction of speed retained per bounce. Lower means the ball settles sooner.
    public var restitution: Double = 0.55
    /// Horizontal speed bled off per second while rolling along the ground.
    public var groundFriction: Double = 900
    /// Speeds below this while grounded count as at rest.
    public var sleepSpeed: Double = 12
    /// While the ball is in contact with the floor, vertical speed below this
    /// is zeroed outright so it settles instead of micro-bouncing forever.
    public var settleVerticalSpeed: Double = 60
    /// Hard cap so a violent flick can't fling the ball into orbit forever.
    public var maxSpeed: Double = 4200
    /// Bounce off the vertical edges of a display rather than passing through.
    public var bouncesOffDisplayEdges: Bool = true

    public init() {}

    /// Advances the ball by `dt` seconds against the given display layout.
    /// Mutates `ball` in place and returns whether it is still awake.
    @discardableResult
    public func step(_ ball: inout Ball, dt: Double, displays: [PetRect]) -> Bool {
        guard ball.state != .held && ball.state != .carried else { return true }
        guard dt > 0 else { return ball.state != .resting }

        var v = PetPoint(x: ball.velocity.x, y: ball.velocity.y - gravity * dt)
        var p = PetPoint(x: ball.position.x + v.x * dt, y: ball.position.y + v.y * dt)

        let r = ball.radius
        var touchedDisplay: Int?
        var onFloor = false

        // Decide which display governs the ball. A display only governs it if
        // the ball's centre is actually inside that display. Selecting purely
        // by x is wrong for monitors arranged in an L (very common: a laptop
        // screen with a taller external display beside it, offset vertically),
        // because it would apply the laptop's floor to a ball that is over the
        // external screen but far below the laptop's bottom edge.
        let governing = displays.firstIndex { $0.contains(p) }

        if let index = governing {
            let display = displays[index]
            touchedDisplay = index

            // Ceiling, then floor.
            let ceilingY = display.maxY - r
            if p.y > ceilingY {
                p.y = ceilingY
                if v.y > 0 {
                    v.y = -v.y * restitution
                    if abs(v.y) < settleVerticalSpeed { v.y = 0 }
                }
            }

            let floorY = display.minY + r
            if p.y < floorY {
                p.y = floorY
                onFloor = true
                if v.y < 0 { v.y = -v.y * restitution }
                // Zero out small residual vertical speed while grounded,
                // otherwise a bounce landing just above `sleepSpeed` makes the
                // ball micro-bounce by the same amount forever.
                if abs(v.y) < settleVerticalSpeed { v.y = 0 }
                v.x = decay(v.x, by: groundFriction * dt)
            }
        }

        // Walls are handled against the *desktop*, not per display: the ball
        // must bounce off the outer edges of the whole monitor arrangement
        // while passing freely across internal seams.
        if bouncesOffDisplayEdges && BallPhysics.bouncesOffDisplayEdgesForTest {
            let bounds = DesktopBounds(displays)
            if let bounds {
                if p.x - r < bounds.minX {
                    p.x = bounds.minX + r
                    if v.x < 0 { v.x = -v.x * restitution }
                } else if p.x + r > bounds.maxX {
                    p.x = bounds.maxX - r
                    if v.x > 0 { v.x = -v.x * restitution }
                }

                // Ceiling of the whole arrangement, so a ball can't escape
                // above the tallest display at a seam.
                if p.y + r > bounds.maxY {
                    p.y = bounds.maxY - r
                    if v.y > 0 { v.y = -v.y * restitution }
                }
            }
        }

        // Clamp to a sane speed.
        let speed = (v.x * v.x + v.y * v.y).squareRoot()
        if speed > maxSpeed {
            let s = maxSpeed / speed
            v = PetPoint(x: v.x * s, y: v.y * s)
        }

        // The ball is outside every display: it is over a gap between monitors, or
        // has left the desktop entirely. If some display sits directly below
        // its x position, drop it onto that one so it lands instead of
        // falling into the void between mismatched monitor edges.
        if governing == nil, let below = displays.firstIndex(where: { $0.horizontallyContains(p.x) }) {
            let floorY = displays[below].minY + r
            if p.y < floorY {
                p.y = floorY
                onFloor = true
                touchedDisplay = below
                if v.y < 0 { v.y = -v.y * restitution }
                if abs(v.y) < settleVerticalSpeed { v.y = 0 }
                v.x = decay(v.x, by: groundFriction * dt)
            }
        }

        // If the ball has fallen past the bottom of every display, rescue it
        // rather than letting it sink forever.
        if displays.allSatisfy({ p.y < $0.minY - 200 }) {
            ball.state = .resting
            ball.restingOn = displays.indices.first
            if let idx = ball.restingOn {
                ball.position = PetPoint(x: displays[idx].midX, y: displays[idx].minY + ball.radius)
            }
            ball.velocity = .zero
            return false
        }

        ball.position = p
        ball.velocity = v

        // Settle once it's resting on a floor and slow enough.
        if onFloor && abs(v.x) < sleepSpeed && abs(v.y) < sleepSpeed {
            ball.state = .resting
            ball.restingOn = touchedDisplay
            ball.velocity = .zero
            return false
        }

        ball.state = .flying
        ball.restingOn = nil
        return true
    }

    private func decay(_ value: Double, by amount: Double) -> Double {
        let sign: Double = value < 0 ? -1 : 1
        let magnitude = abs(value) - amount
        return magnitude <= 0 ? 0 : magnitude * sign
    }

    /// Launches the ball from a flick: `velocity` is in points/second.
    public func throwBall(_ ball: inout Ball, from origin: PetPoint, velocity: PetPoint) {
        ball.position = origin
        ball.velocity = velocity
        ball.state = .flying
        ball.restingOn = nil
    }
}