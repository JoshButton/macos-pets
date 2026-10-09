import Foundation

/// The animation states a pet can be in. Mirrors the upstream pose set
/// (idle/walk/run/with_ball/lie/wallclimb/...) mapped onto our behaviour.
public enum PetPose: String, CaseIterable, Sendable {
    case idle
    case walk
    case run
    case carry
    case sit
    case sleep
    case climb
    case hang
    case land

    /// Fallback when a species has no GIF for a pose: e.g. only totoro ships
    /// wallclimb art, everyone else climbs with their walk cycle.
    public var fallback: PetPose {
        switch self {
        case .run: return .walk
        case .carry: return .walk
        case .climb: return .walk
        case .hang: return .idle
        case .land: return .idle
        case .idle, .walk, .sit, .sleep: return self
        }
    }

    /// Frames-per-second for each pose (upstream GIFs are authored at 8fps).
    public var fps: Double {
        switch self {
        case .run: return 10
        case .walk, .carry, .climb: return 8
        case .idle: return 1.6
        case .sit: return 1
        case .sleep, .hang: return 0.7
        case .land: return 4
        }
    }
}

/// A species' artwork: one sprite per frame, plus timing metadata.
public struct PetSpriteSet: Sendable {
    public let idle: [PixelSprite]
    public let walk: [PixelSprite]
    public let sit: [PixelSprite]
    public let sleep: [PixelSprite]

    public init(idle: [PixelSprite], walk: [PixelSprite], sit: [PixelSprite], sleep: [PixelSprite]) {
        self.idle = idle
        self.walk = walk
        self.sit = sit
        self.sleep = sleep
    }

    public func frames(for pose: PetPose) -> [PixelSprite] {
        switch pose {
        case .idle, .hang: return idle
        case .walk, .run, .carry, .climb: return walk
        case .sit, .land: return sit
        case .sleep: return sleep
        }
    }

    /// Nominal width of the artwork, used for hit testing and scaling.
    public var pixelWidth: Int { idle.first?.width ?? 1 }
    public var pixelHeight: Int { idle.first?.height ?? 1 }
}

/// Reference to verbatim upstream GIF artwork (tonybaloney/vscode-pets).
///
/// The files are shipped unmodified under CC BY-ND 4.0 with attribution (see
/// Assets/vscode-pets/ATTRIBUTION.md). Each pose maps to one animated GIF
/// file; `gifWidth`/`gifHeight` are the logical pixel dimensions of the art,
/// used to derive on-screen size without opening the files.
public struct GifAssetReference: Sendable, Equatable {
    /// Upstream media directory, e.g. "dog".
    public let speciesDir: String
    /// Colour variant, e.g. "black".
    public let variant: String
    /// Pose -> GIF filename (not path), e.g. [.idle: "black_idle_8fps.gif"].
    public let files: [PetPose: String]
    public let gifWidth: Int
    public let gifHeight: Int
    /// Desired on-screen height in points. Width follows aspect ratio.
    public let targetHeight: Double

    public init(speciesDir: String, variant: String, files: [PetPose: String], gifWidth: Int, gifHeight: Int, targetHeight: Double = 64) {
        self.speciesDir = speciesDir
        self.variant = variant
        self.files = files
        self.gifWidth = gifWidth
        self.gifHeight = gifHeight
        self.targetHeight = targetHeight
    }

    /// On-screen width preserving the GIF aspect ratio.
    public var displayWidth: Double {
        guard gifHeight > 0 else { return targetHeight }
        return targetHeight * Double(gifWidth) / Double(gifHeight)
    }

    /// Relative path of a pose's GIF inside Assets/vscode-pets, following the
    /// pose fallback chain so species without dedicated art (only totoro
    /// ships wallclimb frames) reuse their walk/idle cycles.
    public func relativePath(for pose: PetPose) -> String? {
        var current: PetPose? = pose
        while let p = current {
            if let file = files[p] { return "media/\(speciesDir)/\(file)" }
            let next = p.fallback
            current = next == p ? nil : next
        }
        return nil
    }
}

/// A pet species the user can spawn.
public struct PetSpecies: Identifiable, Sendable {
    public let id: String
    public let name: String
    /// Roughly how energetic this species is; higher walks further.
    public let energy: Double
    public let sprites: PetSpriteSet
    /// When non-nil, the renderer draws these verbatim GIFs instead of the
    /// procedural pixels. Facing is applied as a display-time transform only,
    /// never as modified pixel data, to respect the ND licence.
    public let gif: GifAssetReference?
    /// Whether this species climbs walls (upstream: cat, totoro). Our GIF set
    /// only includes climbing frames for totoro; others climb with their walk
    /// cycle. Non-climbers turn around at outer walls.
    public let canClimb: Bool

    public init(id: String, name: String, energy: Double, sprites: PetSpriteSet, gif: GifAssetReference? = nil, canClimb: Bool = false) {
        self.id = id
        self.name = name
        self.energy = energy
        self.sprites = sprites
        self.gif = gif
        self.canClimb = canClimb
    }

    /// On-screen footprint width in points, used for edge clamping so wide
    /// sprites (e.g. crab at 150x90) don't overhang monitor edges.
    public var footprintWidth: Double {
        if let gif { return gif.displayWidth }
        return Double(sprites.pixelWidth) * 3.0
    }

    /// How high above the floor the ball must come for this pet to catch it.
    public var catchHeight: Double {
        (gif?.targetHeight ?? 48) + 8
    }
}

// MARK: - Catalogue

public enum PetCatalogue {

    /// Placeholder for GIF-backed species: the renderer uses `gif` and never
    /// touches these pixels.
    public static let emptySprites = PetSpriteSet(idle: [], walk: [], sit: [], sleep: [])

    /// The default roster: verbatim upstream GIF artwork with attribution.
    /// Procedural originals remain available via `proceduralAll` as fallback.
    public static let all: [PetSpecies] = gifBackedAll

    public static let gifBackedAll: [PetSpecies] = [
        PetSpecies(id: "dog-black", name: "Dog", energy: 0.8, sprites: emptySprites, gif: GifAssetReference(
            speciesDir: "dog", variant: "black",
            files: [.idle: "black_idle_8fps.gif", .walk: "black_walk_8fps.gif", .run: "black_run_8fps.gif", .carry: "black_with_ball_8fps.gif", .sit: "black_idle_8fps.gif", .sleep: "black_lie_8fps.gif"],
            gifWidth: 120, gifHeight: 90)),
        PetSpecies(id: "dog-brown", name: "Dog (Brown)", energy: 0.8, sprites: emptySprites, gif: GifAssetReference(
            speciesDir: "dog", variant: "brown",
            files: [.idle: "brown_idle_8fps.gif", .walk: "brown_walk_8fps.gif", .run: "brown_run_8fps.gif", .carry: "brown_with_ball_8fps.gif", .sit: "brown_idle_8fps.gif", .sleep: "brown_lie_8fps.gif"],
            gifWidth: 120, gifHeight: 90)),
        PetSpecies(id: "dog-akita", name: "Akita", energy: 0.85, sprites: emptySprites, gif: GifAssetReference(
            speciesDir: "dog", variant: "akita",
            files: [.idle: "akita_idle_8fps.gif", .walk: "akita_walk_8fps.gif", .run: "akita_run_8fps.gif", .carry: "akita_with_ball_8fps.gif", .sit: "akita_idle_8fps.gif", .sleep: "akita_lie_8fps.gif"],
            gifWidth: 120, gifHeight: 90)),
        PetSpecies(id: "crab", name: "Crab", energy: 0.65, sprites: emptySprites, gif: GifAssetReference(
            speciesDir: "crab", variant: "red",
            files: [.idle: "red_idle_8fps.gif", .walk: "red_walk_8fps.gif", .run: "red_run_8fps.gif", .carry: "red_with_ball_8fps.gif", .sit: "red_idle_8fps.gif", .sleep: "red_idle_8fps.gif"],
            gifWidth: 150, gifHeight: 90)),
        PetSpecies(id: "turtle", name: "Turtle", energy: 0.25, sprites: emptySprites, gif: GifAssetReference(
            speciesDir: "turtle", variant: "green",
            files: [.idle: "green_idle_8fps.gif", .walk: "green_walk_8fps.gif", .run: "green_run_8fps.gif", .carry: "green_with_ball_8fps.gif", .sit: "green_idle_8fps.gif", .sleep: "green_lie_8fps.gif"],
            gifWidth: 115, gifHeight: 90)),
        PetSpecies(id: "snake", name: "Snake", energy: 0.3, sprites: emptySprites, gif: GifAssetReference(
            speciesDir: "snake", variant: "green",
            files: [.idle: "green_idle_8fps.gif", .walk: "green_walk_8fps.gif", .run: "green_run_8fps.gif", .carry: "green_with_ball_8fps.gif", .sit: "green_idle_8fps.gif", .sleep: "green_idle_8fps.gif"],
            gifWidth: 90, gifHeight: 90)),
        PetSpecies(id: "duck", name: "Duck", energy: 0.4, sprites: emptySprites, gif: GifAssetReference(
            speciesDir: "rubber-duck", variant: "yellow",
            files: [.idle: "yellow_idle_8fps.gif", .walk: "yellow_walk_8fps.gif", .run: "yellow_run_8fps.gif", .carry: "yellow_with_ball_8fps.gif", .sit: "yellow_idle_8fps.gif", .sleep: "yellow_idle_8fps.gif"],
            gifWidth: 90, gifHeight: 80)),
        PetSpecies(id: "clippy", name: "Clippy", energy: 0.45, sprites: emptySprites, gif: GifAssetReference(
            speciesDir: "clippy", variant: "yellow",
            files: [.idle: "yellow_idle_8fps.gif", .walk: "yellow_walk_8fps.gif", .run: "yellow_run_8fps.gif", .carry: "yellow_with_ball_8fps.gif", .sit: "yellow_idle_8fps.gif", .sleep: "yellow_idle_8fps.gif"],
            gifWidth: 112, gifHeight: 142)),
        PetSpecies(id: "fox", name: "Fox", energy: 0.6, sprites: emptySprites, gif: GifAssetReference(
            speciesDir: "fox", variant: "red",
            files: [.idle: "red_idle_8fps.gif", .walk: "red_walk_8fps.gif", .run: "red_run_8fps.gif", .carry: "red_with_ball_8fps.gif", .sit: "red_idle_8fps.gif", .sleep: "red_lie_8fps.gif"],
            gifWidth: 92, gifHeight: 75)),
        PetSpecies(id: "panda", name: "Panda", energy: 0.5, sprites: emptySprites, gif: GifAssetReference(
            speciesDir: "panda", variant: "black",
            files: [.idle: "black_idle_8fps.gif", .walk: "black_walk_8fps.gif", .run: "black_run_8fps.gif", .carry: "black_with_ball_8fps.gif", .sit: "black_idle_8fps.gif", .sleep: "black_lie_8fps.gif"],
            gifWidth: 96, gifHeight: 96)),
        PetSpecies(id: "chicken", name: "Chicken", energy: 0.55, sprites: emptySprites, gif: GifAssetReference(
            speciesDir: "chicken", variant: "brown",
            files: [.idle: "brown_idle_8fps.gif", .walk: "brown_walk_8fps.gif", .run: "brown_run_8fps.gif", .carry: "brown_with_ball_8fps.gif", .sit: "brown_idle_8fps.gif", .sleep: "brown_idle_8fps.gif"],
            gifWidth: 90, gifHeight: 80)),
        PetSpecies(id: "snail", name: "Snail", energy: 0.2, sprites: emptySprites, gif: GifAssetReference(
            speciesDir: "snail", variant: "brown",
            files: [.idle: "brown_idle_8fps.gif", .walk: "brown_walk_8fps.gif", .run: "brown_run_8fps.gif", .carry: "brown_with_ball_8fps.gif", .sit: "brown_idle_8fps.gif", .sleep: "brown_idle_8fps.gif"],
            gifWidth: 90, gifHeight: 80)),
        PetSpecies(id: "totoro", name: "Totoro", energy: 0.5, sprites: emptySprites, gif: GifAssetReference(
            speciesDir: "totoro", variant: "gray",
            files: [.idle: "gray_idle_8fps.gif", .walk: "gray_walk_8fps.gif", .run: "gray_run_8fps.gif", .carry: "gray_with_ball_8fps.gif", .sit: "gray_idle_8fps.gif", .sleep: "gray_lie_8fps.gif", .climb: "gray_wallclimb_8fps.gif", .hang: "gray_wallgrab_8fps.gif", .land: "gray_land_8fps.gif"],
            gifWidth: 100, gifHeight: 90), canClimb: true),
    ]

    /// Original hand-drawn sprites, kept as offline fallback.
    public static let proceduralAll: [PetSpecies] = [
        cat(), dog(), duck(), snake(), crab(), penguin(), turtle(), frog(), turtle2(), robot(),
    ]

    public static func species(id: String) -> PetSpecies? {
        all.first { $0.id == id } ?? proceduralAll.first { $0.id == id }
    }

    public static func randomName() -> String {
        all.randomElement()?.name ?? "Dog"
    }

    // Cat ----------------------------------------------------------------
    static func cat() -> PetSpecies {
        PetSpecies(id: "cat", name: "Cat", energy: 0.55, sprites: PetSpriteSet(
            idle: [
                sprite([
                    "....oooo........",
                    "...okkkko.......",
                    "..okwwwwko......",
                    "..okwkkwko......",
                    "..okwwwwko.n....",
                    "..okwwwwkonnnn..",
                    "...okkkkkonnnno.",
                    "....oooooooooo..",
                    "...nno.onnno....",
                    "..nno...onnno...",
                    "..oo.....oooo...",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
                sprite([
                    "....oooo........",
                    "...okkkko.......",
                    "..okwwwwko......",
                    "..okwkkwko......",
                    "..okwwwwko.n....",
                    "..okwwwwkonnnn..",
                    "...okkkkkonnnno.",
                    "....oooooooooo..",
                    "...nno.onnno....",
                    "..nno...onnno...",
                    "..oo.....oooo...",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            walk: [
                sprite([
                    "....oooo........",
                    "...okkkko.......",
                    "..okwwwwko......",
                    "..okwkkwko......",
                    "..okwwwwko.n....",
                    "..okwwwwkonnnn..",
                    "...okkkkkonnnno.",
                    "....oooooooooo..",
                    "...nno.onnno....",
                    "..nno...onnnno..",
                    ".oo.......ooo...",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
                sprite([
                    "....oooo........",
                    "...okkkko.......",
                    "..okwwwwko......",
                    "..okwkkwko......",
                    "..okwwwwko.n....",
                    "..okwwwwkonnnn..",
                    "...okkkkkonnnno.",
                    "....oooooooooo..",
                    "...onno.onnno...",
                    "..onnno...onnno.",
                    "..ooo...........",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            sit: [
                sprite([
                    "................",
                    "................",
                    "....oooo........",
                    "...okkkko.......",
                    "..okwwwwko......",
                    "..okwkkwko......",
                    "..okwwwwkonnnn..",
                    "..okkkkkonnnno..",
                    "...oooooooooo...",
                    "..nno.onnno.....",
                    ".nno...onnnn....",
                    ".oo......oooo...",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            sleep: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "....oooo........",
                    "...okkkko.......",
                    "..okkkkkkonnnn..",
                    "..okkkkkkonnnno.",
                    "...oooooooooo...",
                    "..nno.onnno.....",
                    ".nno...onnnn....",
                    ".oo......oooo...",
                    "................",
                    "................",
                    "................",
                ]),
            ]
        ))
    }

    // Dog ----------------------------------------------------------------
    static func dog() -> PetSpecies {
        PetSpecies(id: "dog", name: "Dog", energy: 0.8, sprites: PetSpriteSet(
            idle: [
                sprite([
                    "...ooo..........",
                    "..okkkko........",
                    ".okwkkwko.......",
                    ".okwwwwko.......",
                    ".okwwwwkonnn....",
                    ".okkkkkonnnnno..",
                    "..ooooooonnnno..",
                    "...nnno.onnno...",
                    "..nnno...onnno..",
                    "..oo.....oooo...",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
                sprite([
                    "...ooo..........",
                    "..okkkko........",
                    ".okwkkwko.......",
                    ".okwwwwko.......",
                    ".okwwwwkonnn....",
                    ".okkkkkonnnnno..",
                    "..ooooooonnnno..",
                    "...nnno.onnno...",
                    "..nnno...onnno..",
                    "..oo.....oooo...",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            walk: [
                sprite([
                    "...ooo..........",
                    "..okkkko........",
                    ".okwkkwko.......",
                    ".okwwwwko.......",
                    ".okwwwwkonnn....",
                    ".okkkkkonnnnno..",
                    "..ooooooonnnno..",
                    "...nnno.onnno...",
                    "..nnno...onnnno.",
                    ".ooo.......oooo.",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
                sprite([
                    "...ooo..........",
                    "..okkkko........",
                    ".okwkkwko.......",
                    ".okwwwwko.......",
                    ".okwwwwkonnn....",
                    ".okkkkkonnnnno..",
                    "..ooooooonnnno..",
                    "...onno.onnno...",
                    "..onnno...onnno.",
                    "..ooo...........",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            sit: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "...ooo..........",
                    "..okkkko........",
                    ".okwkkwko.......",
                    ".okwwwwkonnnn...",
                    ".okkkkkonnnnno..",
                    "..ooooooonnnno..",
                    "...nnno.onnnno..",
                    "..nnno....ooooo.",
                    "..ooo...........",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            sleep: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "...ooo..........",
                    "..okkkko........",
                    ".okkkkkonnnnn...",
                    ".okkkkkonnnnno..",
                    "..ooooooonnnno..",
                    "...nnno.onnnn...",
                    "..nnno....ooooo.",
                    "..ooo...........",
                    "................",
                    "................",
                ]),
            ]
        ))
    }

    // Duck ----------------------------------------------------------------
    static func duck() -> PetSpecies {
        PetSpecies(id: "duck", name: "Duck", energy: 0.4, sprites: PetSpriteSet(
            idle: [
                sprite([
                    "....oooo........",
                    "...okyyko.......",
                    "..okyyyko.......",
                    "..okyyykoyy.....",
                    "..okkkkkoyyyyy..",
                    "...ooooooyyyyyo.",
                    "...owwwwyyyyyyo.",
                    "..oywwwwyyyyyno.",
                    "..oywwwwyyyynno.",
                    "...owwwwyyyyyyo.",
                    "...ooooooyyyyo..",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
                sprite([
                    "....oooo........",
                    "...okyyko.......",
                    "..okyyyko.......",
                    "..okyyykoyy.....",
                    "..okkkkkoyyyyy..",
                    "...ooooooyyyyyo.",
                    "...owwwwyyyyyyo.",
                    "..oywwwwyyyyyno.",
                    "..oywwwwyyyynno.",
                    "...owwwwyyyyyyo.",
                    "...ooooooyyyyo..",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            walk: [
                sprite([
                    "....oooo........",
                    "...okyyko.......",
                    "..okyyyko.......",
                    "..okyyykoyy.....",
                    "..okkkkkoyyyyy..",
                    "...ooooooyyyyyo.",
                    "...owwwwyyyyyyo.",
                    "..oywwwwyyyyyyo.",
                    "..oywwwwyyyyyno.",
                    "...owwwwyyyyyyyo",
                    "...ooooooyyyyyo.",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
                sprite([
                    "....oooo........",
                    "...okyyko.......",
                    "..okyyyko.......",
                    "..okyyykoyy.....",
                    "..okkkkkoyyyyy..",
                    "...ooooooyyyyyo.",
                    "...owwwwyyyyyyo.",
                    "..oywwwwyyyyyyo.",
                    "..oywwwwyyyynno.",
                    "...owwwwyyyyyyo.",
                    "...ooooooyyyyo..",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            sit: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "....oooo........",
                    "...okyyko.......",
                    "..okyyyko.......",
                    "..okyyykoyy.....",
                    "..okkkkkoyyyyy..",
                    "...ooooooyyyyyo.",
                    "...owwwwyyyyyyo.",
                    "..oywwwwyyyynno.",
                    "..oywwwwyyynnyo.",
                    "...owwwwyyyyyyo.",
                    "...ooooooyyyyo..",
                    "................",
                    "................",
                ]),
            ],
            sleep: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "....oooo........",
                    "...okyyko.......",
                    "..okyyykkkyyyyy.",
                    "..okkkkkkkynnyo.",
                    "...oooooooyynno.",
                    "...owwwwwyyynnyo",
                    "..oywwwwyyyynno.",
                    "..oywwwwyyynnyo.",
                    "...owwwwyyyyyyo.",
                    "...ooooooyyyyo..",
                ]),
            ]
        ))
    }

    // Snake ----------------------------------------------------------------
    static func snake() -> PetSpecies {
        PetSpecies(id: "snake", name: "Snake", energy: 0.3, sprites: PetSpriteSet(
            idle: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    ".....oooo.......",
                    "....oeekeo......",
                    "...oeeeeeeo.....",
                    "..oeeeeeeeeo....",
                    "..okweeeeeo.....",
                    "..oeeeeeeeeo....",
                    "...ooooooo......",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            walk: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    ".....oooo.......",
                    "....oeekeo......",
                    "...oeeeeeeo.....",
                    "..oeeeeeeeeo....",
                    "..okweeeeeo.....",
                    "..oeeeeeeeeo....",
                    "...ooooooo......",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
                sprite([
                    "................",
                    "................",
                    "................",
                    "....ooo.........",
                    "...oeekeo.......",
                    "..oeeeeeeo......",
                    ".oeeeeeeeeo.....",
                    ".okweeeeeo......",
                    ".oeeeeeeeeo.....",
                    "..oooooooo......",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            sit: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    ".....oooo.......",
                    "....oeekeo......",
                    "...oeeeeeeo.....",
                    "..oeeeeeeeeo....",
                    "..okweeeeeo.....",
                    "..oeeeeeeeeo....",
                    "...ooooooo......",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            sleep: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    ".....oooooo.....",
                    "...ooeeeeeeoo...",
                    "..okweeeeeeeo...",
                    "...oooooooooo...",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
            ]
        ))
    }

    // Crab ----------------------------------------------------------------
    static func crab() -> PetSpecies {
        PetSpecies(id: "crab", name: "Crab", energy: 0.65, sprites: PetSpriteSet(
            idle: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "....o......o....",
                    "...oro....oro...",
                    "..ororo..ororo..",
                    "..orrrroorrrro..",
                    "..orrrrrrrrrro..",
                    "..okrrrrrrrrko..",
                    "..orrrrrrrrrro..",
                    "...oooooooooo...",
                    "................",
                    "................",
                ]),
            ],
            walk: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "o..............o",
                    "oro..........oro",
                    "ororo......ororo",
                    "ororo......ororo",
                    "..orrrrrrrrrro..",
                    "..okrrrrrrrrko..",
                    "..orrrrrrrrrro..",
                    "...oooooooooo...",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "..o..........o..",
                    ".oro........oro.",
                    ".ororo....ororo.",
                    "..orrrrrrrrrro..",
                    "..okrrrrrrrrko..",
                    "..orrrrrrrrrro..",
                    "...oooooooooo...",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            sit: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "....o......o....",
                    "...oro....oro...",
                    "..ororo..ororo..",
                    "..orrrrrrrrrro..",
                    "..okrrrrrrrrko..",
                    "..orrrrrrrrrro..",
                    "...oooooooooo...",
                    "................",
                    "................",
                ]),
            ],
            sleep: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "....o......o....",
                    "...oro....oro...",
                    "..ororo..ororo..",
                    "..orrrrrrrrrro..",
                    "..okrrrrrrrrko..",
                    "..orrrrrrrrrro..",
                    "...oooooooooo...",
                    "................",
                ]),
            ]
        ))
    }

    // Penguin ----------------------------------------------------------------
    static func penguin() -> PetSpecies {
        PetSpecies(id: "penguin", name: "Penguin", energy: 0.35, sprites: PetSpriteSet(
            idle: [
                sprite([
                    "...oooo.........",
                    "..okkkko........",
                    "..okkkko........",
                    "..okwwko........",
                    "..okwkko........",
                    "..okwwkoyy......",
                    "..okkkkkoyyyy...",
                    "..okwwwwkyyyyy..",
                    "..okwwwwwwwwwko.",
                    "..okwwwwwwwwwwko",
                    "...okwwwwwwwwwko",
                    "...okkkkkkkkkkko",
                    "....oooooooooo..",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            walk: [
                sprite([
                    "...oooo.........",
                    "..okkkko........",
                    "..okkkko........",
                    "..okwwko........",
                    "..okwkko........",
                    "..okwwkoyy......",
                    "..okkkkkoyyyy...",
                    "..okwwwwkyyyyy..",
                    "..okwwwwwwwwwko.",
                    "..okwwwwwwwwwwko",
                    "...okwwwwwwwwwko",
                    "...okkkkkkkkkkko",
                    "...ooo......ooo.",
                    "................",
                    "................",
                    "................",
                ]),
                sprite([
                    "...oooo.........",
                    "..okkkko........",
                    "..okkkko........",
                    "..okwwko........",
                    "..okwkko........",
                    "..okwwkoyy......",
                    "..okkkkkoyyyy...",
                    "..okwwwwkyyyyy..",
                    "..okwwwwwwwwwko.",
                    "..okwwwwwwwwwwko",
                    "...okwwwwwwwwwko",
                    "...okkkkkkkkkkko",
                    "..ooo........ooo",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            sit: [
                sprite([
                    "................",
                    "................",
                    "...oooo.........",
                    "..okkkko........",
                    "..okkkko........",
                    "..okwwko........",
                    "..okwkko........",
                    "..okwwkoyy......",
                    "..okkkkkoyyyy...",
                    "..okwwwwkyyyyy..",
                    "..okwwwwwwwwwko.",
                    "..okwwwwwwwwwwko",
                    "...okkkkkkkkkkko",
                    "...oooooooooo...",
                    "................",
                    "................",
                ]),
            ],
            sleep: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "...oooo.........",
                    "..okkkko........",
                    "..okkkkkkkkyyy..",
                    "..okwwwwwwkyyyko",
                    "..okwwwwwwwwwwko",
                    "...okkkkkkkkkkko",
                    "...oooooooooooo.",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
            ]
        ))
    }

    // Turtle ----------------------------------------------------------------
    static func turtle() -> PetSpecies {
        PetSpecies(id: "turtle", name: "Turtle", energy: 0.2, sprites: PetSpriteSet(
            idle: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "....oooo........",
                    "...oeeeo........",
                    "..oeeeeeoooooo..",
                    ".oeeeeeeeeeeeeo.",
                    "oewwweewwweewwo.",
                    "oEoooooooooooEo.",
                    ".oEooooooooooEo.",
                    "..oooooooooooo..",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            walk: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "....oooo........",
                    "...oeeeo........",
                    "..oeeeeeoooooo..",
                    ".oeeeeeeeeeeeeo.",
                    "oewwweewwweewwo.",
                    "oEoooooooooooEo.",
                    ".oEooooooooooEo.",
                    "..oooooooooooo..",
                    "................",
                    "................",
                    "................",
                ]),
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "...oooo.........",
                    "..oeeeo.........",
                    ".oeeeeeoooooo...",
                    "oeeeeeeeeeeeeo..",
                    "oewwweewwweewwo.",
                    "oEoooooooooooEo.",
                    ".oEooooooooooEo.",
                    "..oooooooooooo..",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            sit: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "....oooo........",
                    "...oeeeo........",
                    "..oeeeeeoooooo..",
                    ".oeeeeeeeeeeeeo.",
                    "oewwweewwweewwo.",
                    "oEoooooooooooEo.",
                    ".oEooooooooooEo.",
                    "..oooooooooooo..",
                    "................",
                    "................",
                ]),
            ],
            sleep: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "..oooooooooooo..",
                    ".oeeeeeeeeeeeeo.",
                    "oewwweewwweewwo.",
                    "oEoooooooooooEo.",
                    ".oEooooooooooEo.",
                    "..oooooooooooo..",
                    "................",
                    "................",
                    "................",
                ]),
            ]
        ))
    }

    // Frog ----------------------------------------------------------------
    static func frog() -> PetSpecies {
        PetSpecies(id: "frog", name: "Frog", energy: 0.6, sprites: PetSpriteSet(
            idle: [
                sprite([
                    "................",
                    "................",
                    "..o..........o..",
                    ".owo........owo.",
                    ".owwo......owwo.",
                    "..owwoooooowwo..",
                    "..oewweewweewoo.",
                    "..oeeeeeeeeeeeo.",
                    ".oeeeeeeeeeeeeo.",
                    ".oewweewwweewwo.",
                    "oewweewwweewwewo",
                    "oewoeooeeooeoweo",
                    ".ooo......ooooo.",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            walk: [
                sprite([
                    "................",
                    "................",
                    "..o..........o..",
                    ".owo........owo.",
                    ".owwo......owwo.",
                    "..owwoooooowwo..",
                    "..oewweewweewoo.",
                    "..oeeeeeeeeeeeo.",
                    ".oeeeeeeeeeeeeo.",
                    ".oewweewwweewwo.",
                    "oewweewwweewwewo",
                    "oewoeooeeooeoweo",
                    ".oooooooooooooo.",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            sit: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "..o..........o..",
                    ".owo........owo.",
                    ".owwo......owwo.",
                    "..owwoooooowwo..",
                    "..oewweewweewoo.",
                    "..oeeeeeeeeeeeo.",
                    ".oeeeeeeeeeeeeo.",
                    ".oewweewwweewwo.",
                    "oewweewwweewwewo",
                    "oewoeooeeooeoweo",
                    ".oooooooooooooo.",
                    "................",
                    "................",
                ]),
            ],
            sleep: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "..o..........o..",
                    ".owwo......owwo.",
                    "..owwoooooowwo..",
                    "..oooooooooooooo",
                    ".oeeeeeeeeeeeeo.",
                    ".oewweewwweewwo.",
                    "oewweewwweewwewo",
                    "oewoeooeeooeoweo",
                    ".oooooooooooooo.",
                    "................",
                    "................",
                ]),
            ]
        ))
    }

    // Turtle2 ----------------------------------------------------------------
    static func turtle2() -> PetSpecies {
        PetSpecies(id: "turtle2", name: "Sea Turtle", energy: 0.25, sprites: PetSpriteSet(
            idle: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "..oo........oo..",
                    ".oeeo......oeeo.",
                    "oeeeeeeeeeeeeeee",
                    "oEewweEeweEwweEo",
                    "oeeeeeeeeeeeeeee",
                    "oEeeeeeeeeeeeeeo",
                    ".ooooooooooooooo",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            walk: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "..oo........oo..",
                    ".oeeo......oeeo.",
                    "oeeeeeeeeeeeeeee",
                    "oEewweEeweEwweEo",
                    "oeeeeeeeeeeeeeee",
                    "oEeeeeeeeeeeeeeo",
                    ".ooooooooooooooo",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            sit: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "..oo........oo..",
                    ".oeeo......oeeo.",
                    "oeeeeeeeeeeeeeee",
                    "oEewweEeweEwweEo",
                    "oeeeeeeeeeeeeeee",
                    "oEeeeeeeeeeeeeeo",
                    ".ooooooooooooooo",
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
            ],
            sleep: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    "..oo........oo..",
                    ".oeeo......oeeo.",
                    "oeeeeeeeeeeeeeee",
                    "oEewweEeweEwweEo",
                    "oeeeeeeeeeeeeeee",
                    "oEeeeeeeeeeeeeeo",
                    ".ooooooooooooooo",
                    "................",
                    "................",
                    "................",
                    "................",
                ]),
            ]
        ))
    }

    // Robot (a nod to Clippy) -----------------------------------------------
    static func robot() -> PetSpecies {
        PetSpecies(id: "robot", name: "Clippy", energy: 0.45, sprites: PetSpriteSet(
            idle: [
                sprite([
                    "................",
                    ".....oooooo.....",
                    "....obbbbbo.....",
                    "...obbbbbbbbo...",
                    "..obbooooooobbo.",
                    "..obowwoowwobbo.",
                    "..obowwooowobbo.",
                    "..obbooooooobbo.",
                    "..obbbbbbbbbbo..",
                    "..obbwwbbbbwwbo.",
                    "..obbwwbbbbwwbo.",
                    "..obbbbbbbbbbo..",
                    "...oobbbbbbboo..",
                    ".....oooooo.....",
                    "................",
                    "................",
                ]),
            ],
            walk: [
                sprite([
                    "................",
                    ".....oooooo.....",
                    "....obbbbbo.....",
                    "...obbbbbbbbo...",
                    "..obbooooooobbo.",
                    "..obowwoowwobbo.",
                    "..obowwooowobbo.",
                    "..obbooooooobbo.",
                    "..obbbbbbbbbbo..",
                    "..obbwwbbbbwwbo.",
                    "..obbwwbbbbwwbo.",
                    "..obbbbbbbbbbo..",
                    "...oobbbbbbboo..",
                    "..o..oooooo..o..",
                    "................",
                    "................",
                ]),
                sprite([
                    "................",
                    ".....oooooo.....",
                    "....obbbbbo.....",
                    "...obbbbbbbbo...",
                    "..obbooooooobbo.",
                    "..obowwoowwobbo.",
                    "..obowwooowobbo.",
                    "..obbooooooobbo.",
                    "..obbbbbbbbbbo..",
                    "..obbwwbbbbwwbo.",
                    "..obbwwbbbbwwbo.",
                    "..obbbbbbbbbbo..",
                    "...oobbbbbbboo..",
                    ".o..oooooo..o...",
                    "................",
                    "................",
                ]),
            ],
            sit: [
                sprite([
                    "................",
                    "................",
                    "................",
                    ".....oooooo.....",
                    "....obbbbbo.....",
                    "...obbbbbbbbo...",
                    "..obbooooooobbo.",
                    "..obowwoowwobbo.",
                    "..obowwooowobbo.",
                    "..obbooooooobbo.",
                    "..obbbbbbbbbbo..",
                    "..obbwwbbbbwwbo.",
                    "..obbwwbbbbwwbo.",
                    "...oooooooooo...",
                    "................",
                    "................",
                ]),
            ],
            sleep: [
                sprite([
                    "................",
                    "................",
                    "................",
                    "................",
                    "................",
                    ".....oooooo.....",
                    "....obbbbbo.....",
                    "...obbbbbbbbo...",
                    "..obbooooooobbo.",
                    "..obokkoookkobo.",
                    "..obbooooooobbo.",
                    "..obbbbbbbbbbo..",
                    "...oooooooooo...",
                    "................",
                    "................",
                    "................",
                ]),
            ]
        ))
    }
}