import Foundation
import MacOSPetsKit

// Entry point. The app is launched as a background agent (menu-bar only) and
// draws its pets into overlay windows that float above all other applications.
//
// A `--render-sheet` flag dumps a PNG contact sheet of every sprite instead,
// which is handy when iterating on the artwork.

let args = CommandLine.arguments

// `macos-pets send <command> [arg]` queues a command file for the running
// app and exits. Plain file I/O: nothing to flush, safe to exit at once.
if let sendIndex = args.firstIndex(of: "send") {
    let parts = Array(args.dropFirst(sendIndex + 1))
    guard let command = PetCommand(cliParts: parts) else {
        fputs("usage: macos-pets send add <species-id> | add-random | remove-last | clear | throw | place | hide | show | toggle\n", stderr)
        exit(2)
    }
    do {
        let dir = PetCommand.queueDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = String(format: "%ld-%d.cmd", Int(Date().timeIntervalSince1970 * 1000), ProcessInfo.processInfo.processIdentifier)
        try (command.fileLine + "\n").write(
            to: dir.appendingPathComponent(name),
            atomically: true, encoding: .utf8
        )
    } catch {
        fputs("could not queue command: \(error)\n", stderr)
        exit(1)
    }
    exit(0)
}

if args.contains("--list-species") {
    for species in PetCatalogue.all {
        print("\(species.id)|\(species.name)")
    }
    exit(0)
}

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

if args.contains("--dump-gif") {
    // --dump-gif <out.png> <species-id> <pose>
    let i = args.firstIndex(of: "--dump-gif")!
    let out = args.count > i+1 ? args[i+1] : "/tmp/gif.png"
    let sid = args.count > i+2 ? args[i+2] : "dog-black"
    let poseName = args.count > i+3 ? args[i+3] : "idle"
    DebugTrace.dumpGif(out: out, speciesID: sid, poseName: poseName)
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