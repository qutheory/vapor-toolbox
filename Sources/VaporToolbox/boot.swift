import ConsoleKit
import Foundation

final class Main: CommandGroup {
    struct Signature: CommandSignature {
        @Flag(name: "version", help: "Prints Vapor toolbox and framework versions.")
        var version: Bool
    }
    
    let commands: [String: AnyCommand] = [
        "clean": Clean(),
        "new": New(),
        "xcode": Xcode(),
        "build": Build(),
        "heroku": Heroku(),
        "run": Run(),
        "supervisor": Supervisor(),
    ]
    
    let help = "Vapor Toolbox (Server-side Swift web framework)"

    func run(using context: inout CommandContext) throws {
        let signature = try Signature(from: &context.input)
        if signature.version {
            do {
                let packageString = try Process.shell.run("cat", "Package.resolved")
                let package = try JSONDecoder().decode(PackageResolved.self, from: .init(packageString.utf8))
                if let vapor = package.object.pins.filter({ $0.package == "vapor" }).first {
                    context.console.output(key: "framework", value: vapor.state.version)
                } else {
                    context.console.output("\("note:", style: .warning) this Swift project does not depend on Vapor.")
                    context.console.output(key: "framework", value: "not found")
                }
            } catch {
                context.console.output("\("note:", style: .warning) no Package.resolved file was found.")
                context.console.output(key: "framework", value: "not found")
            }
            do {
                let brewString = try Process.shell.run("brew", "info", "vapor")
                context.console.output(key: "toolbox", value: "\(brewString.split(separator: "\n")[0])")
            } catch {
                context.console.output("\("note:", style: .warning) could not determine toolbox version.")
                context.console.output(key: "toolbox", value: "not found")
            }
        } else {
            try self.outputHelp(using: &context)
        }
    }
}

private struct PackageResolved: Codable {
    struct Object: Codable {
        struct Pin: Codable {
            struct State: Codable {
                var version: String
            }
            var package: String
            var state: State
        }
        var pins: [Pin]
    }
    var object: Object
}

public func run() throws {
    signal(SIGINT) { code in
        // kill any background processes running
        if let running = Process.running {
            running.interrupt()
        }
        // kill any foreground execs running
        if let running = execPid {
            kill(running, code)
        }
        exit(code)
    }
    let console = Terminal()
    let input = CommandInput(arguments: CommandLine.arguments)
    do {
        try console.run(Main(), input: input)
    }
    // Handle deprecated commands. Done this way instead of by implementing them as Commands because otherwise
    // there's no way to avoid them showing up in the --help, which is exactly the opposite of what we want.
    catch CommandError.unknownCommand(let command, _) where command == "update" {
        console.output(
            "\("Error:", style: .error) The \"\("update", style: .warning)\" command has been removed. " +
            "Use \"\("swift package update", style: .success)\" instead."
        )
    }
}
