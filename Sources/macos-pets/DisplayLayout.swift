import AppKit
import Foundation
import MacOSPetsKit

/// Wraps the current `NSScreen` set as `PetRect`s in the kit's global
/// bottom-left-origin coordinate space.
struct DisplayLayout {
    var rects: [PetRect] = []

    static func current() -> DisplayLayout {
        var rects: [PetRect] = []
        for screen in NSScreen.screens {
            let f = screen.frame
            rects.append(PetRect(x: f.origin.x, y: f.origin.y, width: f.size.width, height: f.size.height))
        }
        return DisplayLayout(rects: rects)
    }

    var count: Int { rects.count }

    /// Index of the screen whose frame contains a global point, if any.
    func index(containing point: PetPoint) -> Int? {
        rects.firstIndex { $0.contains(point) }
    }

    /// The screen under the current mouse location.
    var mouseDisplayIndex: Int? {
        let p = NSEvent.mouseLocation
        return index(containing: PetPoint(x: p.x, y: p.y))
    }
}