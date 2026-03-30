//
//  TerminalExecutor.swift
//  SlideScribe
//

import Foundation

enum TerminalExecutor {
    enum ExecutionError: LocalizedError {
        case emptyCommand
        case launchFailed(Error)

        var errorDescription: String? {
            switch self {
            case .emptyCommand:
                return "Il comando da eseguire è vuoto."
            case .launchFailed(let error):
                return "Impossibile avviare il processo.\n\(error.localizedDescription)"
            }
        }
    }

    enum Event {
        case stdout(String)
        case stderr(String)
        case finished(Int32)
    }

    @discardableResult
    static func execute(
        command: String,
        onEvent: @escaping @MainActor (Event) -> Void
    ) throws -> Process {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else {
            throw ExecutionError.emptyCommand
        }

        NSLog("Executing command directly: %@", trimmedCommand)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", trimmedCommand]

        var env = ProcessInfo.processInfo.environment
        let currentPATH = env["PATH"] ?? ""

        let extraPaths = [
            "/Users/corax/.local/bin",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]

        let mergedPATH = (extraPaths + [currentPATH])
            .filter { !$0.isEmpty }
            .joined(separator: ":")

        env["PATH"] = mergedPATH
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }

            Task { @MainActor in
                onEvent(.stdout(text))
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }

            Task { @MainActor in
                onEvent(.stderr(text))
            }
        }

        process.terminationHandler = { proc in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil

            let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            if !remainingStdout.isEmpty, let text = String(data: remainingStdout, encoding: .utf8), !text.isEmpty {
                Task { @MainActor in
                    onEvent(.stdout(text))
                }
            }

            let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            if !remainingStderr.isEmpty, let text = String(data: remainingStderr, encoding: .utf8), !text.isEmpty {
                Task { @MainActor in
                    onEvent(.stderr(text))
                }
            }

            Task { @MainActor in
                onEvent(.finished(proc.terminationStatus))
            }
        }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            throw ExecutionError.launchFailed(error)
        }

        return process
    }
}
