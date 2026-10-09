import Foundation
import MacOSPetsKit

// Entry point. The app is launched as a background agent (menu-bar only) and
// draws its pets into overlay windows that float above all other applications.
//
// A `--render-sheet` flag dumps a PNG contact sheet of every sprite instead,
// which is handy when iterating on the artwork.

let args = CommandLine.arguments

if args.contains("--selftest") {
    exit(SelfTest.run() ? 0 : 1)
}

if args.contains("--render-check") {
    exit(RenderCheck.run() ? 0 : 1)
}

if args.contains("--trace-ball") {
    DebugTrace.traceBall()
    exit(0)
}

if args.contains("--trace-pets") {
    DebugTrace.tracePets()
    exit(0)
}

if args.contains("--render-sheet") {
    if let data = SpriteSheetRenderer.render() {
        let path = args.last ?? "sprite-sheet.png"
        try? data.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    }
    exit(0)
}

// `--preview <out.png> [species...]` renders a zoomed strip of chosen species.
if let previewIndex = args.firstIndex(of: "--preview") {
    let out = args.count > previewIndex + 1 ? args[previewIndex + 1] : "preview.png"
    let ids = Array(args.dropFirst(previewIndex + 2))
    let species = ids.isEmpty ? PetCatalogue.all.map(\.id) : ids
    if PreviewRenderer.render(speciesIDs: species, out: out) {
        print("wrote \(out)")
    } else {
        print("no matching species")
        exit(1)
    }
    exit(0)
}

MacOSPetsApp.run()