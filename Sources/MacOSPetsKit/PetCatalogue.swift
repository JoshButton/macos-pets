import Foundation

/// The animation states a pet can be in.
public enum PetPose: String, CaseIterable, Sendable {
    case idle
    case walk
    case sit
    case sleep
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
        case .idle: return idle
        case .walk: return walk
        case .sit: return sit
        case .sleep: return sleep
        }
    }

    /// Nominal width of the artwork, used for hit testing and scaling.
    public var pixelWidth: Int { idle.first?.width ?? 1 }
    public var pixelHeight: Int { idle.first?.height ?? 1 }
}

/// A pet species the user can spawn.
public struct PetSpecies: Identifiable, Sendable {
    public let id: String
    public let name: String
    /// Roughly how energetic this species is; higher walks further.
    public let energy: Double
    public let sprites: PetSpriteSet

    public init(id: String, name: String, energy: Double, sprites: PetSpriteSet) {
        self.id = id
        self.name = name
        self.energy = energy
        self.sprites = sprites
    }
}

// MARK: - Catalogue

public enum PetCatalogue {

    public static let all: [PetSpecies] = [
        cat(), dog(), duck(), snake(), crab(), penguin(), turtle(), frog(), turtle2(), robot(),
    ]

    public static func species(id: String) -> PetSpecies? {
        all.first { $0.id == id }
    }

    public static func randomName() -> String {
        all.randomElement()?.name ?? "Cat"
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