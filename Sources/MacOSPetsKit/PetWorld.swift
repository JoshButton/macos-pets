import Foundation

/// A single living pet: position, facing, animation clock and current activity.
public struct Pet: Sendable {
    public enum Activity: Sendable, Equatable {
        /// Standing around, maybe glancing at the cursor.
        case idle
        /// Moving toward `target`.
        case walking(to: PetPoint)
        /// Heading for the ball to play with it.
        case chasing
        /// Carrying the ball back to the player.
        case fetching
        /// Sitting down.
        case sitting
        /// Curled up asleep.
        case sleeping
    }

    public let id: UUID
    public let species: PetSpecies
    public var position: PetPoint
    /// +1 facing right, -1 facing left.
    public var facing: Int
    public var activity: Activity
    /// Seconds accumulated for the current animation frame.
    public var animationClock: Double
    /// Index of the display this pet is standing on.
    public var displayIndex: Int

    public init(id: UUID = UUID(), species: PetSpecies, position: PetPoint, displayIndex: Int, facing: Int = 1) {
        self.id = id
        self.species = species
        self.position = position
        self.displayIndex = displayIndex
        self.facing = facing
        self.activity = .idle
        self.animationClock = 0
    }

    public var pose: PetPose {
        switch activity {
        case .idle: return .idle
        case .walking: return .walk
        case .chasing, .fetching: return .walk
        case .sitting: return .sit
        case .sleeping: return .sleep
        }
    }

    public var isAsleep: Bool { activity == .sleeping }
}

/// Walks pets around the bottom edge of a display and gives them something to do.
///
/// The world is intentionally simple: pets live along a horizontal "floor" at
/// the bottom of whichever display they were spawned on, and switch displays
/// only by walking off the edge and reappearing on the neighbour.
public struct PetWorld: Sendable {
    public var pets: [Pet]
    public var displays: [PetRect]

    /// Pixels per second for a fully energetic species.
    public var baseSpeed: Double = 34
    /// Height of the strip above the display's bottom edge that pets inhabit.
    public var groundInset: Double = 26
    /// Time between random idle decisions.
    public var idleCooldown: Double = 1.4
    /// Chance per idle decision that a pet falls asleep.
    public var sleepChance: Double = 0.22
    /// Chance that a wandering pet aims at a different display, so the pets
    /// spread out and migrate between monitors on their own.
    public var crossDisplayChance: Double = 0.35

    /// Test hook: when false, pets never target another display, reproducing
    /// the original "pets can't move between monitors" bug.
    nonisolated(unsafe) public static var petsMayCrossDisplays = true

    private var rng: SeededRandom

    public init(pets: [Pet] = [], displays: [PetRect] = [], seed: UInt64 = 0xC0FFEE) {
        self.pets = pets
        self.displays = displays
        self.rng = SeededRandom(seed: seed)
    }

    public mutating func spawn(_ species: PetSpecies, on displayIndex: Int) {
        guard !displays.isEmpty else { return }
        let idx = min(max(displayIndex, 0), displays.count - 1)
        let display = displays[idx]
        let x = display.minX + rng.nextDouble(in: 0.25...0.75) * display.width
        let y = display.minY + groundInset
        pets.append(Pet(species: species, position: PetPoint(x: x, y: y), displayIndex: idx, facing: rng.nextBool() ? 1 : -1))
    }

    public mutating func removeAll() { pets.removeAll() }

    /// Advances every pet by `dt` seconds.
    public mutating func step(dt: Double, ball: Ball?, cursor: PetPoint?) {
        guard !displays.isEmpty else { return }
        var nextPets = pets
        for i in nextPets.indices {
            stepPet(&nextPets[i], dt: dt, ball: ball, cursor: cursor)
        }
        pets = nextPets
    }

    private mutating func stepPet(_ pet: inout Pet, dt: Double, ball: Ball?, cursor: PetPoint?) {
        // If the pet's display disappeared (monitor unplugged), relocate it to
        // the first available one instead of freezing it in place forever.
        guard displays.indices.contains(pet.displayIndex) else {
            guard let fallback = displays.first else { return }
            pet.displayIndex = 0
            pet.position = PetPoint(
                x: fallback.midX,
                y: fallback.minY + groundInset
            )
            pet.activity = .idle
            pet.animationClock = 0
            return
        }
        let display = displays[pet.displayIndex]

        pet.animationClock += dt

        // Chase the ball while it is moving. Note the explicit unwrapping: a
        // resting ball must not hold a pet in the chase state forever, or the
        // pet ends up permanently glued to it.
        if let ball, ball.state == .flying {
            let onThisDisplay = displays[pet.displayIndex].contains(ball.position)
            let distance = pet.position.distance(to: ball.position)
            if onThisDisplay && distance < 320 {
                pet.activity = .chasing
            }
        }

        switch pet.activity {
        case .chasing:
            if let ball {
                let toBall = ball.position - pet.position
                if abs(toBall.x) > 2 {
                    pet.facing = toBall.x > 0 ? 1 : -1
                }
                let distance = toBall.length
                if distance > 26 {
                    move(&pet, toward: ball.position, speed: baseSpeed * 1.9, dt: dt, display: display)
                } else {
                    // Reached it: pick the ball up and start bringing it home.
                    pet.activity = .fetching
                }
            } else {
                pet.activity = .idle
            }

        case .walking(let target):
            let targetDisplayIndex = displays.firstIndex { $0.contains(target) }
            let wantsOtherDisplay = targetDisplayIndex != nil && targetDisplayIndex != pet.displayIndex

            if wantsOtherDisplay, let targetDisplayIndex, displays.indices.contains(targetDisplayIndex) {
                // Walk up to the edge of the current display, then step across
                // onto the neighbour. Teleporting to the far end of the other
                // screen would look like the pet teleported, so it only crosses
                // when it has actually reached the shared boundary.
                let goingRight = target.x > pet.position.x
                let current = displays[pet.displayIndex]
                let half = max(12.0, pet.species.footprintWidth / 2)
                let edge = goingRight ? current.maxX - half : current.minX + half

                if abs(pet.position.x - edge) < 6 {
                    let newDisplay = displays[targetDisplayIndex]
                    // Step onto the neighbour at the shared seam.
                    let entryX = goingRight
                        ? max(newDisplay.minX + half, current.maxX - half)
                        : min(newDisplay.maxX - half, current.minX + half)
                    pet.displayIndex = targetDisplayIndex
                    pet.position = PetPoint(x: entryX, y: newDisplay.minY + groundInset)
                    pet.facing = goingRight ? 1 : -1
                } else {
                    move(&pet, toward: PetPoint(x: edge, y: current.minY + groundInset),
                         speed: baseSpeed * (0.5 + pet.species.energy * 0.9), dt: dt, display: current)
                }
            } else {
                let toTarget = target - pet.position
                if abs(toTarget.x) > 2 { pet.facing = toTarget.x > 0 ? 1 : -1 }

                let before = pet.position.x
                if abs(toTarget.x) <= 3 {
                    pet.activity = decideNextActivity(pet: pet, display: display, cursor: cursor)
                } else {
                    move(&pet, toward: target, speed: baseSpeed * (0.5 + pet.species.energy * 0.9), dt: dt, display: display)
                }
                // If clamping prevented any progress the target is effectively
                // unreachable: pick a new goal instead of grinding on a wall.
                if abs(pet.position.x - before) < 0.01 {
                    pet.activity = decideNextActivity(pet: pet, display: display, cursor: cursor)
                    pet.animationClock = 0
                }
            }

        case .fetching:
            // Head back toward the centre of the display, ball in mouth.
            let home = PetPoint(x: display.midX, y: display.minY + groundInset)
            let toHome = home - pet.position
            let before = pet.position.x
            if abs(toHome.x) > 4 {
                pet.facing = toHome.x > 0 ? 1 : -1
                move(&pet, toward: home, speed: baseSpeed * 1.2, dt: dt, display: display)
            } else {
                pet.activity = .sitting
                pet.animationClock = 0
            }
            if abs(pet.position.x - before) < 0.01 {
                pet.activity = .sitting
                pet.animationClock = 0
            }

        case .sitting:
            if pet.animationClock > 3 + rng.nextDouble(in: 0...2) {
                pet.activity = decideNextActivity(pet: pet, display: display, cursor: cursor)
                pet.animationClock = 0
            }

        case .sleeping:
            if pet.animationClock > 8 + rng.nextDouble(in: 0...6) {
                pet.activity = .idle
                pet.animationClock = 0
            }

        case .idle:
            if pet.animationClock > idleCooldown + rng.nextDouble(in: 0...idleCooldown) {
                pet.activity = decideNextActivity(pet: pet, display: display, cursor: cursor)
                pet.animationClock = 0
            }
        }

        // Keep the pet inside whichever display it now belongs to.
        if displays.indices.contains(pet.displayIndex) {
            clampToDisplay(&pet, display: displays[pet.displayIndex])
        }
    }

    private mutating func decideNextActivity(pet: Pet, display: PetRect, cursor: PetPoint?) -> Pet.Activity {
        let petDisplayIndex = pet.displayIndex
        let roll = rng.nextDouble(in: 0...1)

        // Occasionally watch the cursor if it is nearby on the same display.
        if let cursor, display.contains(cursor), roll < 0.18 {
            return .walking(to: cursor)
        }
        if roll < 0.34 {
            return .sitting
        }
        if roll < 0.42 {
            return .sleeping
        }
        // Otherwise pick somewhere to wander to. Sometimes aim at a neighbouring
        // display so pets migrate between monitors on their own.
        let margin = 20.0
        let others = PetWorld.petsMayCrossDisplays
            ? displays.indices.filter { $0 != petDisplayIndex }
            : []
        let aimElsewhere = !others.isEmpty && rng.nextDouble(in: 0...1) < crossDisplayChance
        let targetDisplayIndex = aimElsewhere
            ? others[rng.nextInt(in: 0..<others.count)]
            : petDisplayIndex
        let targetDisplay = displays[targetDisplayIndex]

        let usable = max(targetDisplay.width - margin * 2, 1)
        let target = PetPoint(
            x: targetDisplay.minX + margin + rng.nextDouble(in: 0...1) * usable,
            y: targetDisplay.minY + groundInset
        )
        return .walking(to: target)
    }

    private mutating func move(_ pet: inout Pet, toward target: PetPoint, speed: Double, dt: Double, display: PetRect) {
        let delta = target - pet.position
        let distance = delta.length
        guard distance > 0.0001 else { return }
        let step = min(speed * dt, distance)
        pet.position = pet.position + (delta * (1 / distance) * step)
        // Stay on the floor of whichever display the pet currently occupies.
        // The floor height differs between monitors, so this must follow
        // `pet.displayIndex` rather than a display passed in by the caller.
        if displays.indices.contains(pet.displayIndex) {
            pet.position.y = displays[pet.displayIndex].minY + groundInset
        } else {
            pet.position.y = display.minY + groundInset
        }
    }

    /// Keeps a pet inside the display it currently belongs to. The margin is
    /// half the pet's on-screen footprint so wide sprites (crab ≈107pt) stay
    /// fully on screen instead of overhanging the edge.
    private func clampToDisplay(_ pet: inout Pet, display: PetRect) {
        let margin = max(12.0, pet.species.footprintWidth / 2)
        // Monitors can be narrower than 2*margin; never invert the range.
        let lower = display.minX + margin
        let upper = max(display.maxX - margin, lower)
        pet.position.x = min(max(pet.position.x, lower), upper)
        pet.position.y = display.minY + groundInset
    }
}

// MARK: - Deterministic RNG

/// Small deterministic PRNG so behaviour is reproducible when debugging.
public struct SeededRandom: Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    public mutating func next() -> UInt64 {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2_685_821_657_736_338_717
    }

    public mutating func nextDouble(in range: ClosedRange<Double> = 0...1) -> Double {
        let unit = Double(next() >> 11) / Double(1 << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }

    public mutating func nextBool() -> Bool { next() & 1 == 1 }

    public mutating func nextInt(in range: Range<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound)
        guard span > 0 else { return range.lowerBound }
        return range.lowerBound + Int(next() % span)
    }
}

extension PetPoint {
    public func distance(to other: PetPoint) -> Double {
        let dx = x - other.x, dy = y - other.y
        return (dx * dx + dy * dy).squareRoot()
    }

    public var length: Double {
        (x * x + y * y).squareRoot()
    }
}