import AppKit
import Foundation
import ImageIO
import MacOSPetsKit

/// Loads verbatim upstream GIFs and vends individual frames.
///
/// Files are never modified: no recolouring, no mirrored pixel buffers. Facing
/// is applied by the renderer as a canvas transform only (see
/// OverlayRenderer), which keeps the ND licence intact.
final class GifFrameStore {
    static let shared = GifFrameStore()

    struct Entry {
        let frames: [CGImage]
        /// Points from the image bottom to the lowest opaque pixel, in image
        /// pixels. Used to sit feet exactly on the floor despite transparent
        /// padding varying per species and per frame.
        let bottomInsets: [CGFloat]
        let size: CGSize
    }

    private var cache: [String: Entry] = [:]
    private let lock = NSLock()

    /// Base directories to search for `media/...` GIFs. Bundle resources first
    /// (installed .app), then repo-relative paths (dev builds).
    private func candidateBases() -> [URL] {
        var bases: [URL] = []
        if let resources = Bundle.main.resourceURL {
            bases.append(resources.appendingPathComponent("vscode-pets"))
        }
        // Dev: executable is .build/debug/macos-pets, assets at repo root.
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        bases.append(cwd.appendingPathComponent("Assets/vscode-pets"))
        if let exec = Bundle.main.executableURL {
            // .build/<cfg>/macos-pets -> up 3 to package root
            let root = exec.deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            bases.append(root.appendingPathComponent("Assets/vscode-pets"))
        }
        return bases
    }

    func url(forRelativePath rel: String) -> URL? {
        for base in candidateBases() {
            let u = base.appendingPathComponent(rel)
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        return nil
    }

    /// Frames for a species + pose at the current animation clock.
    func frame(for species: PetSpecies, pose: PetPose, clock: Double) -> (image: CGImage, bottomInset: CGFloat, size: CGSize)? {
        guard let gif = species.gif, let rel = gif.relativePath(for: pose) else { return nil }
        guard let entry = entry(forRelativePath: rel) else { return nil }
        guard !entry.frames.isEmpty else { return nil }
        // GIFs are authored at 8fps; cycle on the animation clock.
        let idx = Int(clock * 8.0) % entry.frames.count
        return (entry.frames[idx], entry.bottomInsets[idx], entry.size)
    }

    func entry(forRelativePath rel: String) -> Entry? {
        lock.lock()
        if let e = cache[rel] { lock.unlock(); return e }
        lock.unlock()
        guard let url = url(forRelativePath: rel) else { return nil }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(src)
        guard count > 0 else { return nil }
        var frames: [CGImage] = []
        var insets: [CGFloat] = []
        var size = CGSize.zero
        for i in 0..<count {
            guard let img = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
            frames.append(img)
            if i == 0 { size = CGSize(width: img.width, height: img.height) }
            insets.append(Self.bottomInset(of: img))
        }
        let entry = Entry(frames: frames, bottomInsets: insets, size: size)
        lock.lock()
        cache[rel] = entry
        lock.unlock()
        return entry
    }

    /// Distance in image pixels from the image bottom to the lowest opaque row.
    /// Renders into a known RGBA buffer first so the alpha byte is always
    /// in a known position regardless of the GIF's native pixel format.
    static func bottomInset(of img: CGImage) -> CGFloat {
        let w = img.width, h = img.height
        guard w > 0, h > 0, w * h < 4_000_000 else { return 0 }
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return 0 }
        let ptr = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        for rowFromBottom in 0..<h {
            let y = h - 1 - rowFromBottom
            for x in 0..<w {
                if ptr[y * w * 4 + x * 4 + 3] > 8 { return CGFloat(rowFromBottom) }
            }
        }
        return 0
    }
}