import Foundation

/// An RGBA colour, components in 0...1.
public struct PetColor: Equatable, Hashable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public static let transparent = PetColor(r: 0, g: 0, b: 0, a: 0)

    /// Builds a colour from 0xRRGGBB, with optional alpha.
    public static func hex(_ value: UInt32, alpha: Double = 1) -> PetColor {
        PetColor(
            r: Double((value >> 16) & 0xFF) / 255.0,
            g: Double((value >> 8) & 0xFF) / 255.0,
            b: Double(value & 0xFF) / 255.0,
            a: alpha
        )
    }
}

/// A single frame of pixel art: a dense grid of colours with a fixed pixel size.
public struct PixelSprite: Equatable, Sendable {
    /// Colour of each pixel, row-major. Row 0 is the *bottom* row, which matches
    /// the y-up coordinate space used everywhere else in the kit.
    public let pixels: [PetColor]
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int, pixels: [PetColor]) {
        precondition(pixels.count == width * height, "pixel buffer size mismatch")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    @inlinable
    public func color(x: Int, y: Int) -> PetColor {
        guard x >= 0, x < width, y >= 0, y < height else { return .transparent }
        return pixels[y * width + x]
    }

    public var isEmpty: Bool { pixels.allSatisfy { $0.a == 0 } }
}

/// The palette used to turn ASCII art into pixel art.
///
/// Characters are shared across every sprite so that a colour letter always
/// means the same thing: `o` outline, `k` black, `w` white, and so on.
public struct PixelPalette: Sendable {
    public private(set) var map: [String: PetColor]

    public init(_ map: [String: PetColor]) {
        self.map = map
    }

    /// The shared palette. `.` is always transparent.
    public static let standard = PixelPalette([
        ".": .transparent,
        "o": .hex(0x1A1626),   // outline
        "k": .hex(0x2B2438),   // near-black
        "w": .hex(0xFFF8F0),   // white
        "g": .hex(0xC9C2D4),   // light grey
        "G": .hex(0x7C7488),   // mid grey
        "r": .hex(0xE8635A),   // red
        "R": .hex(0x9C3230),   // dark red
        "p": .hex(0xF2A0B5),   // pink
        "b": .hex(0x6BA8E5),   // blue
        "B": .hex(0x2F5F9E),   // dark blue
        "y": .hex(0xF5D259),   // yellow
        "Y": .hex(0xC79A2E),   // dark yellow
        "o_": .hex(0x8A5A2B),  // brown
        "n": .hex(0xC98A4B),   // tan / orange
        "N": .hex(0x8A5A2B),   // deep brown
        "e": .hex(0x5FD3A6),   // green
        "E": .hex(0x2E8B62),   // dark green
        "c": .hex(0x8FD9E8),   // cyan
        "m": .hex(0xB98BE0),   // purple
        "M": .hex(0x6D4BA8),   // dark purple
        "t": .hex(0x3E4459),   // shadow
    ])

    /// Parses ASCII art into a sprite.
    ///
    /// Rows are given top-down (like you'd read them in an editor) and flipped
    /// on load so that the resulting sprite is y-up. Every row must be the
    /// same length.
    public func sprite(_ rows: [String]) -> PixelSprite {
        precondition(!rows.isEmpty, "sprite needs at least one row")
        let w = rows[0].count
        precondition(rows.allSatisfy { $0.count == w }, "all sprite rows must be equal width")
        let h = rows.count
        var pixels = [PetColor](repeating: .transparent, count: w * h)
        for (rowIndex, row) in rows.enumerated() {
            let y = h - 1 - rowIndex // flip: art is authored top-down
            for (x, ch) in row.enumerated() {
                let key = String(ch)
                pixels[y * w + x] = map[key] ?? .hex(0xFF00FF) // loud magenta = authoring typo
            }
        }
        return PixelSprite(width: w, height: h, pixels: pixels)
    }
}

/// Convenience for authoring sprites inline.
public func sprite(_ rows: [String], palette: PixelPalette = .standard) -> PixelSprite {
    palette.sprite(rows)
}

/// Mirrors a sprite horizontally, for pets facing left instead of right.
public func flippedHorizontally(_ s: PixelSprite) -> PixelSprite {
    var out = [PetColor](repeating: .transparent, count: s.pixels.count)
    for y in 0..<s.height {
        for x in 0..<s.width {
            out[y * s.width + x] = s.color(x: s.width - 1 - x, y: y)
        }
    }
    return PixelSprite(width: s.width, height: s.height, pixels: out)
}