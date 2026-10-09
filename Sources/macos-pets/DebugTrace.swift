import Foundation
import MacOSPetsKit

/// Prints a step-by-step trace of the ball simulation. Useful when a
/// collision behaves unexpectedly.
enum DebugTrace {

    static func tracePets() {
        let displays = [
            PetRect(x: 0, y: 0, width: 1000, height: 800),
            PetRect(x: 1040, y: 0, width: 1000, height: 800),
        ]
        var world = PetWorld(displays: displays, seed: 12345)
        for species in PetCatalogue.all.prefix(4) {
            world.spawn(species, on: 0)
        }
        var seen: [String: Int] = [:]
        for i in 0..<1800 {
            world.step(dt: 1.0 / 60.0, ball: nil, cursor: PetPoint(x: 500, y: 400))
            if i % 60 == 0 {
                let desc = world.pets.map { "\($0.species.name):\($0.pose)" }.joined(separator: " ")
                for part in desc.split(separator: " ") {
                    seen[String(part), default: 0] += 1
                }
                if i % 300 == 0 { print("t=\(i) \(desc)") }
            }
        }
        print("\npose counts:")
        for (k, v) in seen.sorted(by: { $0.value > $1.value }) {
            print("  \(k): \(v)")
        }
    }

    static func dumpGif(out: String, speciesID: String, poseName: String) {
        GifDump.dump(out: out, speciesID: speciesID, poseName: poseName)
    }

        static func traceBall() {
        var ball = Ball(position: PetPoint(x: 500, y: 400))
        let physics = BallPhysics()
        let displays = [PetRect(x: 0, y: 0, width: 1000, height: 800)]

        print("radius=\(ball.radius) gravity=\(physics.gravity) restitution=\(physics.restitution)")
        for i in 0..<1200 {
            let awake = physics.step(&ball, dt: 1.0 / 60.0, displays: displays)
            if i < 8 || !awake || i % 60 == 0 {
                print(String(
                    format: "%4d  y=%9.3f  vy=%10.3f  vx=%9.3f  state=%@",
                    i, ball.position.y, ball.velocity.y, ball.velocity.x, "\(ball.state)"
                ))
            }
            if !awake {
                print("settled at step \(i)")
                return
            }
        }
        print("never settled; final y=\(ball.position.y) vy=\(ball.velocity.y)")
    }
}