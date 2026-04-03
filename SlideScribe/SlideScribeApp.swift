//
//  SlideScribeApp.swift
//  SlideScribe
//
//  Created by Pier Paolo Cirulli on 28/03/26.
//

import SwiftUI

@main
struct SlideScribeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 980, height: 690)
        .restorationBehavior(.disabled)
        .windowStyle(.hiddenTitleBar)
    }
}
