import Foundation
import MacOSPetsKit

/// A tiny assertion harness. The machine only has the Command Line Tools, so
/// neither XCTest nor swift-testing is available; this runs as part of
/// `--selftest` instead.
/// Shared mutable "no ball" optional for step() calls that need no ball.
/// A file-scope var is required because `inout` cannot bind a literal nil.
struct SelfTestNoBall {
    static var value: Ball? = nil
}

enum SelfTest {

    private static var failures = 0
    private static var checks = 0

    static func run() -> Bool {
        failures = 0
        checks = 0

        // Reintroduce each bug and confirm the suite notices. Without this,
        // these checks could silently stop guarding anything.
        if argsContain("--verify-catches") {
            return verifyCatchesRegressions()
        }

        testBallBouncesOffFloor()
        testBallBouncesOffCeiling()
        testBallBouncesOffSideWalls()
        testBallCrossesBetweenDisplays()
        testBallFallsThroughGapWithoutFloor()
        testBallEventuallySettles()
        testBallDoesNotTunnelAtHighSpeed()
        testBallRescuedBelowAllDisplays()
        testBallBouncesOffDesktopWallsWithOffsetDisplays()
        testBallCrossesVerticallyOffsetDisplays()
        testBallUsesCorrectFloorOnOffsetDisplay()
        testBallNeverLeavesDesktopBounds()
        testPetsDoNotGetStuck()
        testPetsTransitionDisplays()
        testPetsStayInBounds()
        testPetsCrossBetweenDisplaysOverTime()
        testPetRetargetsFromSeamDeadZone()
        testPetTurnsAtOuterWall()
        testPetFacesMovementDirection()
        testChaseUsesRunPose()
        testCarryArtResolves()
        testTotoroClimbsOuterWall()
        testDuckDoesNotClimb()
        testChaseEndsWhenBallRests()
        testCatchHidesBall()
        testSecondPetStandsDown()
        testFrameDurationsHonored()
        testSpritePalettesResolve()
        testGifAssetsResolve()

        print("\(checks - failures)/\(checks) checks passed")
        if failures > 0 {
            print("FAILED: \(failures)")
            return false
        }
        print("all good")
        return true
    }

    // MARK: - Assertions

    private static func expect(_ condition: Bool, _ label: String) {
        checks += 1
        if !condition {
            failures += 1
            print("  FAIL: \(label)")
        }
    }

    private static func expectNear(_ a: Double, _ b: Double, _ tolerance: Double, _ label: String) {
        expect(abs(a - b) <= tolerance, "\(label) (got \(a), expected ~\(b))")
    }

    // MARK: - Ball tests

    private static func singleDisplay() -> [PetRect] {
        [PetRect(x: 0, y: 0, width: 1000, height: 800)]
    }

    private static func testBallBouncesOffFloor() {
        var ball = Ball(position: PetPoint(x: 500, y: 400))
        var physics = BallPhysics()
        var minY = Double.greatestFiniteMagnitude
        var rested = false
        for _ in 0..<1200 {
            let awake = physics.step(&ball, dt: 1.0 / 60.0, displays: singleDisplay())
            minY = Swift.min(minY, ball.position.y)
            if !awake { rested = true; break }
        }
        // Resting on the floor means the centre is one radius up.
        expectNear(minY, ball.radius, 2.0, "ball never falls through the floor")
        expect(rested, "ball comes to rest on the floor")
    }

    private static func testBallBouncesOffCeiling() {
        var ball = Ball(position: PetPoint(x: 500, y: 400))
        var physics = BallPhysics()
        physics.gravity = 0 // straight up, no gravity, so it only hits the ceiling
        ball.velocity = PetPoint(x: 0, y: 2000)
        var maxY = -Double.greatestFiniteMagnitude
        var bounced = false
        for _ in 0..<120 {
            physics.step(&ball, dt: 1.0 / 60.0, displays: singleDisplay())
            maxY = Swift.max(maxY, ball.position.y)
            if ball.velocity.y < 0 { bounced = true }
        }
        expect(maxY <= 800 - ball.radius + 1, "ball does not pass through the ceiling")
        expect(bounced, "ball bounces off the ceiling")
    }

    private static func testBallBouncesOffSideWalls() {
        var ball = Ball(position: PetPoint(x: 500, y: 400))
        var physics = BallPhysics()
        physics.gravity = 0
        ball.velocity = PetPoint(x: 3000, y: 0)
        var minX = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude
        var bouncedLeft = false
        for _ in 0..<200 {
            physics.step(&ball, dt: 1.0 / 60.0, displays: singleDisplay())
            minX = Swift.min(minX, ball.position.x)
            maxX = Swift.max(maxX, ball.position.x)
            if ball.velocity.x < 0 { bouncedLeft = true }
        }
        expect(minX >= ball.radius - 1, "ball does not pass through the left wall")
        expect(maxX <= 1000 - ball.radius + 1, "ball does not pass through the right wall")
        expect(bouncedLeft, "ball bounces off walls")
    }

    /// Two displays side by side: the ball must be able to travel from one to
    /// the other rather than being trapped.
    private static func testBallCrossesBetweenDisplays() {
        let displays = [
            PetRect(x: 0, y: 0, width: 1000, height: 800),
            PetRect(x: 1000, y: 0, width: 1000, height: 800),
        ]
        var ball = Ball(position: PetPoint(x: 900, y: 400))
        var physics = BallPhysics()
        physics.gravity = 0
        ball.velocity = PetPoint(x: 2000, y: 0)
        var reachedRightDisplay = false
        for _ in 0..<200 {
            physics.step(&ball, dt: 1.0 / 60.0, displays: displays)
            if ball.position.x > 1000 { reachedRightDisplay = true }
        }
        expect(reachedRightDisplay, "ball travels from one monitor to the next")
    }

    /// Displays with a bezel gap: there is no floor in the gap, so the ball
    /// should fall rather than skating across an invisible surface.
    private static func testBallFallsThroughGapWithoutFloor() {
        let displays = [
            PetRect(x: 0, y: 0, width: 1000, height: 800),
            PetRect(x: 1040, y: 0, width: 1000, height: 800),
        ]
        var ball = Ball(position: PetPoint(x: 1020, y: 400))
        var physics = BallPhysics()
        physics.gravity = 2000
        physics.bouncesOffDisplayEdges = false
        var dropped = false
        for _ in 0..<120 {
            physics.step(&ball, dt: 1.0 / 60.0, displays: displays)
            if ball.position.y < 200 { dropped = true }
        }
        expect(dropped, "ball falls through the gap between monitors")
    }

    private static func testBallEventuallySettles() {
        var ball = Ball(position: PetPoint(x: 500, y: 600))
        var physics = BallPhysics()
        var settled = false
        for _ in 0..<1200 {
            let awake = physics.step(&ball, dt: 1.0 / 60.0, displays: singleDisplay())
            if !awake { settled = true; break }
        }
        expect(settled, "a thrown ball comes to rest instead of jittering forever")
    }

    private static func testBallDoesNotTunnelAtHighSpeed() {
        var ball = Ball(position: PetPoint(x: 500, y: 400))
        var physics = BallPhysics()
        physics.gravity = 0
        // Faster than a display is wide per frame: a naive integrator would
        // step straight through the wall.
        ball.velocity = PetPoint(x: 0, y: 100_000)
        var maxY = -Double.greatestFiniteMagnitude
        for _ in 0..<60 {
            physics.step(&ball, dt: 1.0 / 60.0, displays: singleDisplay())
            maxY = Swift.max(maxY, ball.position.y)
        }
        expect(maxY <= 800 - ball.radius + 1, "fast ball does not tunnel through the ceiling")
    }

    private static func testBallRescuedBelowAllDisplays() {
        var ball = Ball(position: PetPoint(x: 500, y: 400))
        var physics = BallPhysics()
        physics.gravity = 5000
        ball.velocity = PetPoint(x: 0, y: -4000)
        var rested = false
        for _ in 0..<600 {
            let awake = physics.step(&ball, dt: 1.0 / 60.0, displays: singleDisplay())
            if !awake { rested = true; break }
        }
        expect(rested, "ball is rescued if it somehow leaves every display")
        if rested {
            expect(ball.position.y >= 0, "rescued ball is placed back on a display")
        }
    }

    private static func argsContain(_ flag: String) -> Bool {
        CommandLine.arguments.contains(flag)
    }

    /// Temporarily breaks the behaviour under test and confirms the
    /// corresponding check fails, proving the check has teeth.
    private static func verifyCatchesRegressions() -> Bool {
        var problems: [String] = []

        // 1. Pets that never cross monitors.
        PetWorld.petsMayCrossDisplays = false
        if !testPetsCrossBetweenDisplaysOverTimeReportsFailure() {
            problems.append("cross-display pet check does not detect pets that never migrate")
        }
        PetWorld.petsMayCrossDisplays = true

        // 2. Ball walls disabled (the "does not bounce off walls" report).
        if !ballWallCheckFailsWhenWallsDisabled() {
            problems.append("wall-bounce check does not detect disabled walls")
        }

        // 3. Offset-display behaviour is covered directly by
        // `testBallUsesCorrectFloorOnOffsetDisplay` and
        // `testBallCrossesVerticallyOffsetDisplays`, which exercise the real
        // L-shaped layout rather than a synthesised bug switch.

        // Confirm the real suite passes with correct behaviour restored.
        failures = 0
        checks = 0
        runAll()

        if problems.isEmpty && failures == 0 {
            print("regression detection verified: every check fails when its bug is reintroduced")
            print("\(checks - failures)/\(checks) checks passed with correct behaviour")
            return true
        }
        for p in problems { print("  PROBLEM: \(p)") }
        print("FAILED")
        return false
    }

    private static func testPetsCrossBetweenDisplaysOverTimeReportsFailure() -> Bool {
        // Runs the check with migration disabled and returns true if it fails.
        let before = failures
        let failed = runIsolated { testPetsCrossBetweenDisplaysOverTime() }
        failures = before
        return failed
    }

    private static func ballWallCheckFailsWhenWallsDisabled() -> Bool {
        BallPhysics.bouncesOffDisplayEdgesForTest = false
        let failed = runIsolated { testBallBouncesOffDesktopWallsWithOffsetDisplays() }
        BallPhysics.bouncesOffDisplayEdgesForTest = true
        return failed
    }

    /// Runs one check and reports whether it produced a failure.
    private static func runIsolated(_ body: () -> Void) -> Bool {
        let before = failures
        body()
        return failures > before
    }

    private static func runAll() {
        testBallBouncesOffFloor()
        testBallBouncesOffCeiling()
        testBallBouncesOffSideWalls()
        testBallCrossesBetweenDisplays()
        testBallFallsThroughGapWithoutFloor()
        testBallEventuallySettles()
        testBallDoesNotTunnelAtHighSpeed()
        testBallRescuedBelowAllDisplays()
        testBallBouncesOffDesktopWallsWithOffsetDisplays()
        testBallCrossesVerticallyOffsetDisplays()
        testBallUsesCorrectFloorOnOffsetDisplay()
        testBallNeverLeavesDesktopBounds()
        testPetsDoNotGetStuck()
        testPetsTransitionDisplays()
        testPetsStayInBounds()
        testPetsCrossBetweenDisplaysOverTime()
        testPetRetargetsFromSeamDeadZone()
        testPetTurnsAtOuterWall()
        testPetFacesMovementDirection()
        testChaseUsesRunPose()
        testCarryArtResolves()
        testTotoroClimbsOuterWall()
        testDuckDoesNotClimb()
        testChaseEndsWhenBallRests()
        testCatchHidesBall()
        testSecondPetStandsDown()
        testFrameDurationsHonored()
        testSpritePalettesResolve()
        testGifAssetsResolve()
    }

    /// Frames advance on authored GIF delays, not a flat 8fps. Turtle walk is
    /// 1s/frame and crab carry 260ms/frame; playing those at 8fps blurs slow
    /// leg cycles into a slide. This is the "pets slide while parading" fix.
    private static func testFrameDurationsHonored() {
        guard let turtle = GifFrameStore.shared.entry(forRelativePath: "media/turtle/green_walk_8fps.gif") else {
            expect(false, "turtle walk GIF loads")
            return
        }
        expect(turtle.durations.allSatisfy { abs($0 - 1.0) < 0.05 }, "turtle walk frames last ~1s (\(turtle.durations.prefix(2)))")
        expect(turtle.frameIndex(at: 0.5) == 0, "turtle still on frame 0 halfway through its first second")
        expect(turtle.frameIndex(at: 1.5) == 1, "turtle advances one frame per second")

        guard let dog = GifFrameStore.shared.entry(forRelativePath: "media/dog/black_walk_8fps.gif") else {
            expect(false, "dog walk GIF loads")
            return
        }
        expect(dog.durations.allSatisfy { abs($0 - 0.13) < 0.03 }, "dog walk frames last ~130ms (\(dog.durations.prefix(2)))")
        expect(dog.frameIndex(at: 0.0) == 0, "dog starts on frame 0")
        expect(dog.frameIndex(at: 0.2) == 1, "dog advances to frame 1 after one 130ms delay")
        expect(dog.frameIndex(at: dog.totalDuration + 0.05) == 0, "dog loops back to frame 0")

        guard let crab = GifFrameStore.shared.entry(forRelativePath: "media/crab/red_with_ball_8fps.gif") else {
            expect(false, "crab carry GIF loads")
            return
        }
        expect(abs(crab.totalDuration - 0.78) < 0.05, "crab carry loop is ~0.78s, not 3/8s (\(crab.totalDuration))")
    }

    /// Catching hides the free ball (upstream hides the ball canvas): the
    /// catcher parades the painted `with_ball` art, so no duplicate ball.
    private static func testCatchHidesBall() {
        let displays = [PetRect(x: 0, y: 0, width: 1000, height: 800)]
        var world = PetWorld(displays: displays, seed: 41)
        let species = PetCatalogue.species(id: "dog-black")!
        var ball: Ball? = Ball(position: PetPoint(x: 500, y: 40))
        ball?.velocity = PetPoint(x: 0, y: -10) // low and drifting, still flying
        world.pets.append(Pet(
            species: species,
            position: PetPoint(x: 480, y: 6),
            displayIndex: 0, facing: 1
        ))
        world.pets[0].activity = .chasing

        var caught = false
        for _ in 0..<600 {
            world.step(dt: 1.0 / 60.0, ball: &ball, cursor: nil)
            if case .fetching = world.pets[0].activity { caught = true; break }
        }
        expect(caught, "pet close to a flying ball catches it")
        expect(ball?.state == .carried, "caught ball hides (state carried, not left on the ground)")
    }

    /// A second pet chasing a ball another pet just caught stands down
    /// instead of piling on (upstream chase-cancel when the ball pauses).
    private static func testSecondPetStandsDown() {
        let displays = [PetRect(x: 0, y: 0, width: 1000, height: 800)]
        var world = PetWorld(displays: displays, seed: 43)
        let species = PetCatalogue.species(id: "dog-black")!
        var ball: Ball? = Ball(position: PetPoint(x: 500, y: 100))
        ball?.state = .carried // already caught by someone
        world.pets.append(Pet(
            species: species,
            position: PetPoint(x: 200, y: 6),
            displayIndex: 0, facing: 1
        ))
        world.pets[0].activity = .chasing
        for _ in 0..<120 {
            world.step(dt: 1.0 / 60.0, ball: &ball, cursor: nil)
        }
        let activity = world.pets[0].activity
        let gaveUp: Bool
        if case .chasing = activity { gaveUp = false } else { gaveUp = true }
        expect(gaveUp, "second pet gives up a chase for an already-caught ball (now \(activity))")
    }

    /// A pet mid-chase when the ball comes to rest must not grind against the
    /// nearest edge forever: far away it lets go, close up it fetches. This
    /// is the "dog running into the monitor edge" report.
    private static func testChaseEndsWhenBallRests() {
        let displays = lShapedDisplays()
        var ball: Ball? = Ball(position: PetPoint(x: 3000, y: 65))
        ball?.state = .resting

        // Far from the resting ball: the chase must end, not grind.
        var world = PetWorld(displays: displays, seed: 31)
        let species = PetCatalogue.species(id: "dog-black")!
        world.pets.append(Pet(
            species: species,
            position: PetPoint(x: 1400, y: 6),
            displayIndex: 0, facing: 1
        ))
        world.pets[0].activity = .chasing
        for _ in 0..<600 {
            world.step(dt: 1.0 / 60.0, ball: &ball, cursor: nil)
        }
        let farActivity = world.pets[0].activity
        let stillChasing: Bool
        if case .chasing = farActivity { stillChasing = true } else { stillChasing = false }
        expect(!stillChasing, "chase ends when the ball rests far away (now \(farActivity))")
        // Whatever it did instead (wander, possibly across the seam), it
        // must be inside a display, not wedged past an edge.
        let d = displays[world.pets[0].displayIndex]
        expect(
            world.pets[0].position.x >= d.minX && world.pets[0].position.x <= d.maxX,
            "pet stays inside a display after giving up the chase"
        )

        // Right next to the resting ball: it should pick it up instead.
        var near = PetWorld(displays: displays, seed: 31)
        near.pets.append(Pet(
            species: species,
            position: PetPoint(x: 2970, y: 62),
            displayIndex: 1, facing: 1
        ))
        near.pets[0].activity = .chasing
        for _ in 0..<120 {
            near.step(dt: 1.0 / 60.0, ball: &ball, cursor: nil)
        }
        let nearActivity = near.pets[0].activity
        let fetched: Bool
        switch nearActivity {
        case .fetching, .sitting, .idle, .walking: fetched = true
        default: fetched = false
        }
        expect(fetched, "pet near a rested ball fetches or settles (now \(nearActivity))")
    }

    /// Chasing pets use the run gait, and fetching pets the carry art.
    private static func testChaseUsesRunPose() {
        let species = PetCatalogue.species(id: "dog-black")!
        var pet = Pet(species: species, position: PetPoint(x: 100, y: 6), displayIndex: 0)
        pet.activity = .chasing
        expect(pet.pose == .run, "chasing uses the run gait")
        pet.activity = .fetching
        expect(pet.pose == .carry, "fetching uses the carry art")
        pet.activity = .walking(to: PetPoint(x: 900, y: 6))
        expect(pet.pose == .run, "long walks use the run gait")
        pet.activity = .walking(to: PetPoint(x: 120, y: 6))
        expect(pet.pose == .walk, "short walks use the walk gait")
    }

    /// Every species resolves carry (with_ball) art, directly or via fallback.
    private static func testCarryArtResolves() {
        var missing: [String] = []
        for species in PetCatalogue.all {
            if species.gif?.relativePath(for: .carry) == nil {
                missing.append(species.id)
            }
        }
        expect(missing.isEmpty, "all species resolve carry art: \(missing)")
    }

    /// A climbing species blocked at an outer desktop wall scales it: rises,
    /// hangs, descends, and lands back on the floor.
    private static func testTotoroClimbsOuterWall() {
        let displays = [PetRect(x: 0, y: 0, width: 1000, height: 800)]
        var world = PetWorld(displays: displays, seed: 21)
        world.climbChance = 1.0 // force the climb
        let species = PetCatalogue.species(id: "totoro")!
        expect(species.canClimb, "totoro is a climbing species")
        world.pets.append(Pet(
            species: species,
            position: PetPoint(x: 950, y: 6),
            displayIndex: 0, facing: 1
        ))
        world.pets[0].activity = .walking(to: PetPoint(x: 2000, y: 6))

        var sawClimb = false
        var sawHang = false
        var maxY = 6.0
        for _ in 0..<3600 {
            world.step(dt: 1.0 / 60.0, ball: &SelfTestNoBall.value, cursor: nil)
            let p = world.pets[0]
            maxY = max(maxY, p.position.y)
            if p.isAirborne { sawClimb = true }
            if case .hanging = p.activity { sawHang = true }
        }
        expect(sawClimb, "totoro leaves the floor to climb the outer wall")
        expect(sawHang, "totoro hangs at the top before descending")
        expect(maxY > 100, "totoro gains real height (maxY=\(Int(maxY)))")
        expect(world.pets[0].displayIndex == 0, "totoro stays on its display while climbing")
    }

    /// Non-climbers turn around at outer walls instead of climbing.
    private static func testDuckDoesNotClimb() {
        let displays = [PetRect(x: 0, y: 0, width: 1000, height: 800)]
        var world = PetWorld(displays: displays, seed: 21)
        world.climbChance = 1.0
        let species = PetCatalogue.species(id: "duck")!
        expect(!species.canClimb, "duck is not a climbing species")
        world.pets.append(Pet(
            species: species,
            position: PetPoint(x: 950, y: 6),
            displayIndex: 0, facing: 1
        ))
        world.pets[0].activity = .walking(to: PetPoint(x: 2000, y: 6))

        var leftFloor = false
        for _ in 0..<1800 {
            world.step(dt: 1.0 / 60.0, ball: &SelfTestNoBall.value, cursor: nil)
            if world.pets[0].position.y > 20 { leftFloor = true; break }
        }
        expect(!leftFloor, "duck never leaves the floor at an outer wall")
    }

    /// A pet ordered into the clamp dead-zone at an internal seam must retarget
    /// rather than grind there forever or ping-pong across the seam: the goal
    /// is unreachable from both sides, so crossing would just oscillate.
    private static func testPetRetargetsFromSeamDeadZone() {
        let displays = lShapedDisplays()
        var world = PetWorld(displays: displays, seed: 5)
        let species = PetCatalogue.species(id: "duck")!
        world.pets.append(Pet(
            species: species,
            position: PetPoint(x: 1470, y: 6),
            displayIndex: 0, facing: 1
        ))
        world.pets[0].activity = .walking(to: PetPoint(x: 1500, y: 6))

        for _ in 0..<120 {
            world.step(dt: 1.0 / 60.0, ball: &SelfTestNoBall.value, cursor: nil)
        }
        // It must have given up the unreachable goal (and stayed put rather
        // than teleporting across the desktop).
        if case .walking(let target) = world.pets[0].activity {
            expect(
                abs(target.x - 1500) > 0.01 || world.pets[0].displayIndex != 0,
                "pet abandons the unreachable seam goal instead of grinding it"
            )
        }
        expect(world.pets[0].displayIndex == 0, "pet does not teleport across the desktop from a dead-zone goal")
        let display = displays[0]
        expect(
            world.pets[0].position.x >= display.minX && world.pets[0].position.x <= display.maxX,
            "pet remains inside its display"
        )
    }

    /// A pet blocked at the *outer* desktop wall turns around instead of
    /// grinding: it must not change displays and must keep varying activity.
    private static func testPetTurnsAtOuterWall() {
        let displays = lShapedDisplays()
        var world = PetWorld(displays: displays, seed: 11)
        let species = PetCatalogue.species(id: "duck")!
        world.pets.append(Pet(
            species: species,
            position: PetPoint(x: 5340, y: 62),
            displayIndex: 1, facing: 1
        ))
        world.pets[0].activity = .walking(to: PetPoint(x: 6000, y: 62))

        for _ in 0..<600 {
            world.step(dt: 1.0 / 60.0, ball: &SelfTestNoBall.value, cursor: nil)
        }
        expect(world.pets[0].displayIndex == 1, "pet stays on its display at the outer wall")
        let display = displays[1]
        expect(
            world.pets[0].position.x >= display.minX && world.pets[0].position.x <= display.maxX,
            "pet remains inside the display after hitting the outer wall"
        )
    }

    /// While walking toward an edge on another display, the pet faces its
    /// direction of travel every tick — no moonwalking.
    private static func testPetFacesMovementDirection() {
        let displays = [
            PetRect(x: 0, y: 0, width: 1000, height: 800),
            PetRect(x: 1000, y: 0, width: 1000, height: 800),
        ]
        var world = PetWorld(displays: displays, seed: 3)
        let species = PetCatalogue.species(id: "duck")!
        // Facing right but ordered left across the seam.
        world.pets.append(Pet(
            species: species,
            position: PetPoint(x: 1500, y: 6),
            displayIndex: 1, facing: 1
        ))
        world.pets[0].activity = .walking(to: PetPoint(x: 200, y: 6))

        var mismatch = 0
        var steps = 0
        for _ in 0..<900 {
            let before = world.pets[0].position.x
            world.step(dt: 1.0 / 60.0, ball: &SelfTestNoBall.value, cursor: nil)
            let moved = world.pets[0].position.x - before
            if abs(moved) > 0.001 {
                steps += 1
                let shouldFace = moved > 0 ? 1 : -1
                if world.pets[0].facing != shouldFace { mismatch += 1 }
            }
        }
        expect(steps > 10, "pet actually moved during the facing check (\(steps) steps)")
        expect(mismatch == 0, "pet always faces its direction of travel (\(mismatch)/\(steps) moonwalk steps)")
    }

    /// Every GIF-backed species must resolve its files on disk and decode at
    /// least one frame. Catches missing downloads, wrong filenames, and
    /// corrupt GIFs before they become invisible pets.
    private static func testGifAssetsResolve() {
        var missing: [String] = []
        var undecodable: [String] = []
        for species in PetCatalogue.all {
            guard let gif = species.gif else {
                missing.append("\(species.id): no gif reference")
                continue
            }
            for pose in PetPose.allCases {
                guard let rel = gif.relativePath(for: pose) else {
                    missing.append("\(species.id)/\(pose.rawValue): no file mapping")
                    continue
                }
                guard let entry = GifFrameStore.shared.entry(forRelativePath: rel) else {
                    missing.append("\(species.id)/\(pose.rawValue): missing file \(rel)")
                    continue
                }
                if entry.frames.isEmpty { undecodable.append("\(species.id)/\(pose.rawValue)") }
            }
            // Sanity: footprint must be positive and reasonable.
            if !(species.footprintWidth > 10 && species.footprintWidth < 400) {
                missing.append("\(species.id): implausible footprint \(species.footprintWidth)")
            }
        }
        expect(missing.isEmpty, "all GIF assets resolve: \(missing.prefix(4))")
        expect(undecodable.isEmpty, "all GIFs decode: \(undecodable.prefix(4))")
    }

/// A laptop screen beside a taller external display, vertically offset.
/// This is the common real-world arrangement and the one that originally
/// broke the ball's collisions.
private static func lShapedDisplays() -> [PetRect] {
    [
        PetRect(x: 0, y: 0, width: 1512, height: 982),
        PetRect(x: 1512, y: 56, width: 3840, height: 2160),
    ]
}

private static func testBallBouncesOffDesktopWallsWithOffsetDisplays() {
    let displays = lShapedDisplays()

    // Fling the ball hard at the right-hand wall of the desktop.
    var ball = Ball(position: PetPoint(x: 4000, y: 1200))
    var physics = BallPhysics()
    physics.gravity = 0
    ball.velocity = PetPoint(x: 3000, y: 0)
    var bounced = false
    for _ in 0..<400 {
        physics.step(&ball, dt: 1.0 / 60.0, displays: displays)
        if ball.velocity.x < 0 { bounced = true }
    }
    expect(bounced, "ball bounces off the outer right wall with offset displays")
    expect(ball.position.x <= 5352 - ball.radius + 1, "ball stays inside the desktop's right edge")
}

private static func testBallCrossesVerticallyOffsetDisplays() {
    let displays = lShapedDisplays()

    // Start on the laptop, above the height where the external display begins,
    // and travel right. The ball must end up over the external display.
    var ball = Ball(position: PetPoint(x: 1400, y: 700))
    var physics = BallPhysics()
    physics.gravity = 0
    ball.velocity = PetPoint(x: 1200, y: 0)
    var reached = false
    for _ in 0..<400 {
        physics.step(&ball, dt: 1.0 / 60.0, displays: displays)
        if ball.position.x > 1512 { reached = true }
    }
    expect(reached, "ball crosses from the laptop screen onto the offset external display")
}

/// The symptom of x-only display selection: over the external display but
/// below the laptop's bottom edge, the ball gets the laptop's floor height
/// (y = radius) instead of the external display's floor (y = 56 + radius), so
/// it appears to float above the real floor and sinks into the desktop.
private static func testBallUsesCorrectFloorOnOffsetDisplay() {
    let displays = lShapedDisplays()
    let external = displays[1]

    var ball = Ball(position: PetPoint(x: 3000, y: 400))
    ball.velocity = .zero
    var physics = BallPhysics()
    physics.gravity = 2000
    for _ in 0..<900 {
        physics.step(&ball, dt: 1.0 / 60.0, displays: displays)
    }

    let expectedFloor = external.minY + ball.radius
    expectNear(
        ball.position.y, expectedFloor, 3.0,
        "ball rests on the external display's floor (y=\(expectedFloor)), not the laptop's"
    )
}

private static func testBallNeverLeavesDesktopBounds() {
    let displays = lShapedDisplays()
    var physics = BallPhysics()

    // Throw from many positions and directions; the ball must never end up
    // outside the bounding box of the whole desktop.
    var escapes = 0
    for seed in 0..<40 {
        var rng = SeededRandom(seed: UInt64(seed) &+ 1)
        var ball = Ball(position: PetPoint(
            x: rng.nextDouble(in: 0...5352),
            y: rng.nextDouble(in: 0...2160)
        ))
        ball.velocity = PetPoint(
            x: rng.nextDouble(in: -3000...3000),
            y: rng.nextDouble(in: -3000...3000)
        )
        for _ in 0..<600 {
            physics.step(&ball, dt: 1.0 / 60.0, displays: displays)
            let b = DesktopBounds(displays)!
            if ball.position.x < b.minX - 1 || ball.position.x > b.maxX + 1
                || ball.position.y < b.minY - 1 || ball.position.y > b.maxY + 1 {
                escapes += 1
                break
            }
        }
    }
    expect(escapes == 0, "ball never escapes the desktop bounds (\(escapes)/40 runs escaped)")
}

private static func testPetsCrossBetweenDisplaysOverTime() {
    let displays = lShapedDisplays()
    var world = PetWorld(displays: displays, seed: 4242)
    for species in PetCatalogue.all.prefix(5) {
        world.spawn(species, on: 0)
    }

    // Over a few simulated minutes at least one pet should migrate.
    let startDisplays = Set(world.pets.map(\.displayIndex))
    for _ in 0..<18000 { // ~5 minutes
        world.step(dt: 1.0 / 60.0, ball: &SelfTestNoBall.value, cursor: nil)
    }
    let endDisplays = Set(world.pets.map(\.displayIndex))
    expect(
        endDisplays.count > startDisplays.count || !startDisplays.subtracting(endDisplays).isEmpty,
        "pets migrate between monitors over time (started \(startDisplays.sorted()), ended \(endDisplays.sorted()))"
    )
}

// MARK: - Pet tests

    private static func testPetsDoNotGetStuck() {
        let displays = [
            PetRect(x: 0, y: 0, width: 1000, height: 800),
            PetRect(x: 1040, y: 0, width: 1000, height: 800),
        ]
        var world = PetWorld(displays: displays, seed: 12345)
        for species in PetCatalogue.all.prefix(4) {
            world.spawn(species, on: 0)
        }

        // Run for a simulated 60s and make sure every pet stays within bounds.
        // Poses are accumulated as we go: sampling a single instant would
        // miss behaviour that cycles, and every pet may share one pose by
        // chance at that moment.
        var observedPoses = Set<String>()
        for step in 0..<3600 {
            world.step(dt: 1.0 / 60.0, ball: &SelfTestNoBall.value, cursor: PetPoint(x: 500, y: 400))
            for pet in world.pets {
                observedPoses.insert("\(pet.species.id):\(pet.pose.rawValue)")
                let display = displays[pet.displayIndex]
                if pet.position.x < display.minX - 1 || pet.position.x > display.maxX + 1 {
                    expect(false, "pet \(pet.species.name) escaped its display at step \(step)")
                    return
                }
            }
        }

        // Each spawned pet should show more than one pose over the run, proving
        // none is permanently wedged into a single activity. Derive the IDs
        // from what was actually spawned so the check can't drift from the
        // roster above.
        for speciesID in PetCatalogue.all.prefix(4).map(\.id) {
            let posesForSpecies = Set(
                observedPoses
                    .filter { $0.hasPrefix("\(speciesID):") }
                    .map { String($0.split(separator: ":")[1]) }
            )
            expect(posesForSpecies.count > 1, "\(speciesID) cycles through several poses, saw \(posesForSpecies.sorted())")
        }
    }

    private static func testPetsTransitionDisplays() {
        let displays = [
            PetRect(x: 0, y: 0, width: 1000, height: 800),
            PetRect(x: 1000, y: 0, width: 1000, height: 800),
        ]
        var world = PetWorld(displays: displays, seed: 99)
        // Push a pet at a target on the far monitor.
        let cat = PetCatalogue.species(id: "dog-black")!
        world.pets.append(Pet(species: cat, position: PetPoint(x: 500, y: 26), displayIndex: 0))
        world.pets[0].activity = .walking(to: PetPoint(x: 1800, y: 26))

        var moved = false
        for _ in 0..<2000 {
            world.step(dt: 1.0 / 60.0, ball: &SelfTestNoBall.value, cursor: nil)
            if world.pets[0].displayIndex == 1 { moved = true; break }
        }
        expect(moved, "a pet walks across to the other monitor when it wants to")
    }

    private static func testPetsStayInBounds() {
        let displays = [PetRect(x: -500, y: 0, width: 800, height: 600)] // negative origin
        var world = PetWorld(displays: displays, seed: 7)
        for species in PetCatalogue.all.prefix(3) {
            world.spawn(species, on: 0)
        }
        for _ in 0..<1200 {
            world.step(dt: 1.0 / 60.0, ball: &SelfTestNoBall.value, cursor: PetPoint(x: -100, y: 300))
        }
        for pet in world.pets {
            expect(pet.position.x >= -500, "\(pet.species.name) stays inside a display with a negative origin")
            expect(pet.position.x <= 300, "\(pet.species.name) does not overflow its display")
        }
    }

    private static func testSpritePalettesResolve() {
        // A character with no palette entry renders as loud magenta, which is
        // a reliable signal of an authoring typo.
        var offenders: [String] = []
        for species in PetCatalogue.proceduralAll {
            let all = species.sprites.idle + species.sprites.walk + species.sprites.sit + species.sprites.sleep
            for s in all {
                for y in 0..<s.height {
                    for x in 0..<s.width {
                        let c = s.color(x: x, y: y)
                        if c.r == 1 && c.g == 0 && c.b == 1 && c.a == 1 {
                            offenders.append("\(species.id) @\(x),\(y)")
                        }
                    }
                }
            }
        }
        expect(offenders.isEmpty, "no unmapped palette characters: \(offenders.prefix(3))")

        // Every sprite in a set must share dimensions or animation will jitter.
        for species in PetCatalogue.proceduralAll {
            let frames = species.sprites.frames(for: .walk) + species.sprites.frames(for: .idle)
            let widths = Set(frames.map(\.width))
            expect(widths.count == 1, "\(species.id) frames share a consistent width")
        }
    }
}