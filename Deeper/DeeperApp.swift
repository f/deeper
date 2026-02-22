//
//  DeeperApp.swift
//  Deeper
//
//  Created by Fatih Kadir Akın on 22.02.2026.
//

import SwiftUI

@main
struct DeeperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)

        Settings {
            SettingsView(onConnect: { _ in }, closeOnDisconnect: true)
                .frame(width: 420, height: 460)
        }
    }
}
