import Foundation

/// Remote-control commands for the running app.
///
/// Transport is a command-queue directory (`~/.config/macos-pets/commands/`):
/// `macos-pets send ...` writes one line per command file, and the running
/// app drains the directory on its tick. No ports, sockets, URL schemes, or
/// notifyd — file delivery works from any sandbox, persists across restarts,
/// and is trivially scriptable from Raycast. (Darwin notify and distributed
/// notifications were both tried first; neither delivers from a short-lived
/// sender in all contexts.)
///
///     macos-pets send add dog-black
///     macos-pets send throw
///
/// Name format: `<prefix>.<action>[.<arg>]`, where arg may itself contain
/// dots (species ids use dashes, so this is unambiguous in practice).
public enum PetCommand: Sendable, Equatable {
    case add(speciesID: String)
    case addRandom
    case remove(speciesID: String)
    case removeLast
    case clear
    case throwBall
    case placeBall
    case hide
    case show
    case toggleHidden

    /// Notification name prefix shared by the sender and the app.
    public static let notifyPrefix = "dev.local.macos-pets.cmd"

    /// Parses a distributed-notification name into a command.
    public static func parse(notificationName: String) -> PetCommand? {
        guard notificationName.hasPrefix(notifyPrefix + ".") else { return nil }
        let rest = String(notificationName.dropFirst(notifyPrefix.count + 1))
        let action: String
        let arg: String?
        if let dot = rest.firstIndex(of: ".") {
            action = String(rest[..<dot])
            arg = String(rest[rest.index(after: dot)...])
        } else {
            action = rest
            arg = nil
        }
        switch action {
        case "add":
            guard let arg, !arg.isEmpty else { return nil }
            return .add(speciesID: arg)
        case "add-random": return .addRandom
        case "remove":
            guard let arg, !arg.isEmpty else { return nil }
            return .remove(speciesID: arg)
        case "remove-last": return .removeLast
        case "clear": return .clear
        case "throw": return .throwBall
        case "place": return .placeBall
        case "hide": return .hide
        case "show": return .show
        case "toggle": return .toggleHidden
        default: return nil
        }
    }

    /// Builds a command from CLI parts after `send`, e.g. ["add", "dog-black"].
    /// Accepts both `add dog-black` and `add-dog-black` spellings.
    public init?(cliParts: [String]) {
        guard let first = cliParts.first else { return nil }
        if first == "add", cliParts.count >= 2 {
            self = .add(speciesID: cliParts[1])
            return
        }
        if first == "remove", cliParts.count >= 2 {
            self = .remove(speciesID: cliParts[1])
            return
        }
        // Single-token form: the action, optionally with `-id` suffix for add.
        let token = first
        switch token {
        case "add-random": self = .addRandom
        case "remove-last": self = .removeLast
        case "clear": self = .clear
        case "throw": self = .throwBall
        case "place": self = .placeBall
        case "hide": self = .hide
        case "show": self = .show
        case "toggle": self = .toggleHidden
        default:
            if token.hasPrefix("add-") {
                self = .add(speciesID: String(token.dropFirst(4)))
            } else {
                return nil
            }
        }
    }

    /// One-line file encoding, e.g. "add dog-black" or "throw".
    public var fileLine: String {
        switch self {
        case .add(let id): return "add \(id)"
        case .addRandom: return "add-random"
        case .remove(let id): return "remove \(id)"
        case .removeLast: return "remove-last"
        case .clear: return "clear"
        case .throwBall: return "throw"
        case .placeBall: return "place"
        case .hide: return "hide"
        case .show: return "show"
        case .toggleHidden: return "toggle"
        }
    }

    public init?(fileLine line: String) {
        let parts = line.split(separator: " ").map(String.init)
        self.init(cliParts: parts)
    }

    /// Directory holding queued command files, created on demand.
    public static func queueDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/macos-pets/commands", isDirectory: true)
    }

    /// Reads and removes every queued command file, returning the commands
    /// in filename order. Unknown lines are skipped, never fatal.
    public static func drainQueue(at dir: URL? = nil) -> [PetCommand] {
        let dir = dir ?? queueDirectory()
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) else {
            return []
        }
        var commands: [PetCommand] = []
        for file in files {
            if let line = try? String(contentsOf: file, encoding: .utf8) {
                for raw in line.split(separator: "\n") {
                    let trimmed = raw.trimmingCharacters(in: .whitespaces)
                    if let cmd = PetCommand(fileLine: trimmed), !trimmed.isEmpty {
                        commands.append(cmd)
                    }
                }
            }
            try? fm.removeItem(at: file)
        }
        return commands
    }

    /// The notification name that carries this command.
    public var notificationName: String {
        switch self {
        case .add(let id): return "\(Self.notifyPrefix).add.\(id)"
        case .addRandom: return "\(Self.notifyPrefix).add-random"
        case .remove(let id): return "\(Self.notifyPrefix).remove.\(id)"
        case .removeLast: return "\(Self.notifyPrefix).remove-last"
        case .clear: return "\(Self.notifyPrefix).clear"
        case .throwBall: return "\(Self.notifyPrefix).throw"
        case .placeBall: return "\(Self.notifyPrefix).place"
        case .hide: return "\(Self.notifyPrefix).hide"
        case .show: return "\(Self.notifyPrefix).show"
        case .toggleHidden: return "\(Self.notifyPrefix).toggle"
        }
    }
}