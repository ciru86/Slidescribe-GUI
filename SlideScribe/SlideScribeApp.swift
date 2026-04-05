//
//  SlideScribeApp.swift
//  SlideScribe
//
//  Created by Pier Paolo Cirulli on 28/03/26.
//

import SwiftUI

enum SlideScribeMenuAction: String {
    case openInput
    case openWorkdir
    case toggleOptions
    case runWorkflow
    case stopWorkflow
    case clearTerminal
    case generateCommand
    case switchToYouTubeURL
    case switchToLocalFile
    case focusYouTubeURLField
    case showManual

    static let userInfoKey = "action"
}

extension Notification.Name {
    static let slideScribeCommand = Notification.Name("SlideScribeCommand")
}

@main
struct SlideScribeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 980, height: 690)
        .restorationBehavior(.disabled)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("Input") {
                menuButton("Open Input", action: .openInput, shortcut: "o")
                menuButton("Choose Working Directory", action: .openWorkdir, shortcut: "o", modifiers: [.command, .shift])

                Divider()

                menuButton("YouTube URL", action: .switchToYouTubeURL, shortcut: "1")
                menuButton("Local File", action: .switchToLocalFile, shortcut: "2")
                menuButton("Focus YouTube URL Field", action: .focusYouTubeURLField, shortcut: "l")
            }

            CommandMenu("Workflow") {
                menuButton("Run Workflow", action: .runWorkflow, shortcut: "r")
                menuButton("Stop Process", action: .stopWorkflow, shortcut: ".", modifiers: [.command])
                menuButton("Generate Command", action: .generateCommand, shortcut: "g")

                Divider()

                menuButton("Options", action: .toggleOptions, shortcut: ",")
                menuButton("Clear Terminal", action: .clearTerminal, shortcut: "k")
            }

            CommandGroup(after: .help) {
                menuButton("SlideScribe Manual", action: .showManual, shortcut: "/", modifiers: [.command, .shift])
            }
        }
    }

    @ViewBuilder
    private func menuButton(
        _ title: String,
        action: SlideScribeMenuAction,
        shortcut: KeyEquivalent? = nil,
        modifiers: EventModifiers = [.command]
    ) -> some View {
        if let shortcut {
            Button(title) {
                postMenuAction(action)
            }
            .keyboardShortcut(shortcut, modifiers: modifiers)
        } else {
            Button(title) {
                postMenuAction(action)
            }
        }
    }

    private func postMenuAction(_ action: SlideScribeMenuAction) {
        NotificationCenter.default.post(
            name: .slideScribeCommand,
            object: nil,
            userInfo: [SlideScribeMenuAction.userInfoKey: action]
        )
    }
}
