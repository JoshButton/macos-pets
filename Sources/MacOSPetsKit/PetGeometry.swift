import Foundation

/// A point in global "Cocoa screen" space.
///
/// Origin is the bottom-left of the *main* display, +x right, +y up. This is
/// exactly `NSScreen.frame` space, so AppKit rectangles can be used directly
/// without conversion. The renderer owns translation to flipped GPU space.
public struct PetPoint: Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = PetPoint(x: 0, y: 0)
    public static func + (a: PetPoint, b: PetPoint) -> PetPoint { .init(x: a.x + b.x, y: a.y + b.y) }
    public static func - (a: PetPoint, b: PetPoint) -> PetPoint { .init(x: a.x - b.x, y: a.y - b.y) }
    public static func * (p: PetPoint, s: Double) -> PetPoint { .init(x: p.x * s, y: p.y * s) }
}

public struct PetSize: Equatable, Hashable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public static let zero = PetSize(width: 0, height: 0)
}

public struct PetRect: Equatable, Hashable, Sendable {
    public var origin: PetPoint
    public var size: PetSize

    public init(origin: PetPoint, size: PetSize) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: PetPoint(x: x, y: y), size: PetSize(width: width, height: height))
    }

    public var minX: Double { origin.x }
    public var minY: Double { origin.y }
    public var maxX: Double { origin.x + size.width }
    public var maxY: Double { origin.y + size.height }
    public var midX: Double { origin.x + size.width / 2 }
    public var midY: Double { origin.y + size.height / 2 }
    public var width: Double { size.width }
    public var height: Double { size.height }

    public func contains(_ p: PetPoint) -> Bool {
        p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY
    }

    /// True when an x coordinate falls within this display's horizontal span.
    /// Used to decide which monitor a ball crossing the desktop belongs to.
    public func horizontallyContains(_ x: Double) -> Bool {
        x >= minX && x <= maxX
    }

    /// True when a y coordinate falls within this display's vertical span.
    public func verticallyContains(_ y: Double) -> Bool {
        y >= minY && y <= maxY
    }

    public func intersects(_ other: PetRect) -> Bool {
        minX < other.maxX && maxX > other.minX && minY < other.maxY && maxY > other.minY
    }

    public func union(_ other: PetRect) -> PetRect {
        let x = Swift.min(minX, other.minX)
        let y = Swift.min(minY, other.minY)
        let x2 = Swift.max(maxX, other.maxX)
        let y2 = Swift.max(maxY, other.maxY)
        return PetRect(x: x, y: y, width: x2 - x, height: y2 - y)
    }

    public func insetBy(dx: Double, dy: Double) -> PetRect {
        PetRect(x: minX + dx, y: minY + dy, width: Swift.max(0, width - dx * 2), height: Swift.max(0, height - dy * 2))
    }
}